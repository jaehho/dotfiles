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
-- emptiness with hyprctl so a stale toplevels list cannot hide waybar.

local M = {}

local TEMP_BASE = 9000
local DEBOUNCE_MS = 300

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
                local to = slots[k] or from -- extras past the slot list keep their id
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
    if #steps == 0 then return end

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
M.schedule = schedule
return M
