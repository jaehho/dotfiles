-- Workspace gap-filling: pack each monitor's live workspaces into its
-- round-robin slot ids when one of them is removed (tmux renumber-windows).
--
-- Per-monitor on purpose: renumbering never moves a window across outputs.
-- Super+N still means workspace id N, so Super+9 can open an intentional hole;
-- that hole fills only when the workspace is destroyed. Packing runs on
-- workspace.removed, not on window.close — an empty workspace you are still
-- looking at stays until you leave it.
--
-- Renumbering uses hl.dsp.workspace.change_id (same workspace object, windows
-- stay). The target id must be free globally, so movers go through temp ids
-- first; a plain low-to-high walk is not enough when off-slot ids swap.
-- Each change_id is followed by a same-name rename so waybar hears the name
-- (see the comment in pack_now; hyprland renames silently). Quickshell (dash)
-- has no changeworkspaceid handler either; dash's shell.qml confirms
-- emptiness with hyprctl so a stale toplevels list cannot draw over windows.

local M = {}

-- Two-phase change_id temps. Must sit outside 1..9 so a leak is visible as a
-- stray (reclaim_strays eats id > 9). 9003 on Spotify was a leftover temp from
-- an interrupted pack.
local TEMP_BASE = 9000
local DEBOUNCE_MS = 300

-- The closed set Super+N and Super+0 (scratchpad) address. Anything else with
-- id > 0 is a stray and gets packed in or destroyed.
local MAX_SLOT = 9

-- Pure planner. live: {{id=n, monitor=name}, ...}. slots_by_mon:
-- { [monitor_name] = {slot_id, ...} }. Returns ordered {from=, to=} pairs
-- (temps included). Untouched when a monitor has no slots recorded.
function M.plan_pack(live, slots_by_mon)
    local by_mon = {}
    for _, ws in ipairs(live) do
        if type(ws.id) == "number" and ws.id > 0 and not ws.special then
            local list = by_mon[ws.monitor]
            if not list then
                list = {}
                by_mon[ws.monitor] = list
            end
            list[#list + 1] = ws.id
        end
    end

    local finals = {} -- {from=, to=}
    for mon, ids in pairs(by_mon) do
        table.sort(ids)
        local slots = slots_by_mon[mon]
        if slots and #slots > 0 then
            for k, from in ipairs(ids) do
                local to = slots[k] or from -- extras past the slot list keep their id (reclaim_strays merges those)
                if to ~= from then
                    finals[#finals + 1] = { from = from, to = to }
                end
            end
        end
    end

    table.sort(finals, function(a, b) return a.from < b.from end)

    -- Two-phase via temps so a target is never requested while still occupied
    -- (swap-shaped plans exist once Super+N puts an id off its round-robin slot).
    local steps = {}
    for i, mv in ipairs(finals) do
        steps[#steps + 1] = { from = mv.from, to = TEMP_BASE + i }
    end
    for i, mv in ipairs(finals) do
        steps[#steps + 1] = { from = TEMP_BASE + i, to = mv.to }
    end
    return steps
end

local packing = false

-- Ids outside 1..9 (including leftover TEMP_BASE temps). Merge their windows
-- onto a real slot on the same monitor, then leave — the empty non-persistent
-- workspace is destroyed when unfocused. Keeps Super+N / Super+Tab / waybar on
-- the closed set.
local function reclaim_strays()
    local monitors = package.loaded["monitors"]
    local slots_by_mon = monitors and monitors.slots_by_monitor and monitors.slots_by_monitor() or {}
    if not next(slots_by_mon) then return end

    local valid = {}
    for _, slots in pairs(slots_by_mon) do
        for _, id in ipairs(slots) do valid[id] = true end
    end

    local strays = {}
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        if not ws.special and type(ws.id) == "number" and ws.id > 0 and (ws.id > MAX_SLOT or not valid[ws.id]) then
            strays[#strays + 1] = ws
        end
    end

    -- Windows already claimed by a live slot, so a stray folds into the first
    -- empty slot when there is one and only piles onto 1 when the monitor is full.
    local occupied = {}
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        if type(ws.id) == "number" then occupied[ws.id] = (ws.windows or 0) > 0 end
    end

    for _, ws in ipairs(strays) do
        local mon = ws.monitor
        local name = type(mon) == "string" and mon or (mon and mon.name)
        local slots = name and slots_by_mon[name] or nil
        local target = nil
        for _, id in ipairs(slots or {}) do
            if not occupied[id] then target = id; break end
        end
        if target == nil then target = slots and slots[1] end
        if target == nil then
            for _, s in pairs(slots_by_mon) do
                if s[1] then target = s[1]; break end
            end
        end
        if target and target ~= ws.id then
            for _, win in ipairs(hl.get_workspace_windows(ws.id) or {}) do
                hl.dispatch(hl.dsp.window.move({
                    workspace = target,
                    window    = "address:" .. win.address,
                    follow    = false,
                }))
            end
            -- If the stray is on screen, hop to its replacement so Hyprland
            -- reaps the empty one.
            local live = name and hl.get_monitor(name)
            local active = live and live.active_workspace
            local id = active and (type(active) == "table" and active.id or active)
            if id == ws.id then
                live:set_workspace({ workspace = tostring(target) })
            end
        end
    end
end

local function pack_now()
    if packing then return end

    local monitors = package.loaded["monitors"]
    local slots_by_mon = monitors and monitors.slots_by_monitor and monitors.slots_by_monitor() or {}
    if not next(slots_by_mon) then return end

    local live = {}
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        if not ws.special and type(ws.id) == "number" and ws.id > 0 then
            local mon = ws.monitor
            local name = type(mon) == "string" and mon or (mon and mon.name)
            if name then
                live[#live + 1] = { id = ws.id, monitor = name, special = ws.special }
            end
        end
    end

    local steps = M.plan_pack(live, slots_by_mon)
    if #steps > 0 then
        packing = true
        for _, mv in ipairs(steps) do
            hl.dispatch(hl.dsp.workspace.change_id({ workspace = mv.from, id = mv.to }))
            -- Hyprland renames numeric workspaces to tostring(new id) but does not
            -- emit renameworkspace, and waybar's changeworkspaceid handler only
            -- setId — so {name} labels and active-by-name go stale (double-active
            -- pills, missing numbers). A same-name rename is a no-op for us and
            -- still emits renameworkspace>>id,name, which waybar does handle.
            hl.dispatch(hl.dsp.workspace.rename({ workspace = mv.to, name = tostring(mv.to) }))
        end
        packing = false
    end
    reclaim_strays()
end

-- Trailing-edge debounce: workspace.removed and the events change_id itself
-- fires arrive in a burst. opts.type is mandatory; a spent oneshot cannot be
-- re-armed (same new_timer/schedule shape as monitors.lua). No timer is armed
-- at load — packing must not run on reload, or it would fill Super+N holes.
local pending = nil

local function new_timer()
    return hl.timer(pack_now, { timeout = DEBOUNCE_MS, type = "oneshot" })
end

local function schedule()
    if pending and pending:is_enabled() then
        pending:set_enabled(true)
    else
        pending = new_timer()
    end
end

hl.on("workspace.removed", schedule)

M.pack = pack_now
M.reclaim = reclaim_strays
M.schedule = schedule
return M
