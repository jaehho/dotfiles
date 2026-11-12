-- Workspace gap-filling: pack each monitor's live workspaces into its
-- round-robin slot ids when one of them is removed (tmux renumber-windows).
--
-- Per-monitor on purpose: renumbering never moves a window across outputs.
-- Super+N still means workspace id N, so Super+9 can open an intentional hole;
-- that hole fills only when the workspace is destroyed. Packing runs on
-- workspace.removed, not on window.close — an empty workspace you are still
-- looking at stays until you leave it.
--
-- A workspace whose id is another monitor's slot is not a hole here. Leave it
-- for monitors.lua to move whole (windows follow). Packing it onto this
-- monitor's slots is what kept windows on the same output when a display was
-- plugged in: workspace 2 would renumber onto a laptop slot before apply()
-- could send it to the tablet.
--
-- Renumbering uses hl.dsp.workspace.change_id (same workspace object, windows
-- stay). The target id must be free globally, so movers go through temp ids
-- first; a plain low-to-high walk is not enough when off-slot ids swap.
-- Each change_id is followed by a same-name rename so the bars hear the name
-- (see the comment in pack_now; hyprland renames silently). Waybar did not
-- handle changeworkspaceid. Quickshell 0.3.2 did not either, so the bar lost
-- window icons after a pack; quickshell-git (upstream 4befab5) follows the id
-- change. dash's shell.qml still confirms emptiness with hyprctl, from before.

local M = {}

-- Two-phase change_id temps. Must sit outside 1..9 so a leak is visible as a
-- stray (reclaim_strays eats id > 9). 9003 on Spotify was a leftover temp from
-- an interrupted pack.
local TEMP_BASE = 9000
local DEBOUNCE_MS = 300

-- The closed set Super+N addresses. Anything else with
-- id > 0 is a stray and gets packed in or destroyed.
local MAX_SLOT = 9

-- Final {from=, to=} renumbers as change_id steps, two-phase via temps so a
-- target is never requested while still occupied (change_id refuses a taken
-- id; swaps and rotations always hit one).
local function two_phase(finals)
    local steps = {}
    for i, mv in ipairs(finals) do
        steps[#steps + 1] = { from = mv.from, to = TEMP_BASE + i }
    end
    for i, mv in ipairs(finals) do
        steps[#steps + 1] = { from = TEMP_BASE + i, to = mv.to }
    end
    return steps
end

-- Pure planner. live: {{id=n, monitor=name}, ...}. slots_by_mon:
-- { [monitor_name] = {slot_id, ...} }. Returns ordered {from=, to=} pairs
-- (temps included). Untouched when a monitor has no slots recorded.
function M.plan_pack(live, slots_by_mon)
    -- Slot id -> output that owns it. Used to tell a real hole apart from a
    -- workspace that is merely waiting for monitors.lua to move it home.
    local owner = {}
    for mon, slots in pairs(slots_by_mon) do
        for _, id in ipairs(slots) do
            owner[id] = mon
        end
    end

    local stay, by_mon = {}, {}
    for _, ws in ipairs(live) do
        if type(ws.id) == "number" and ws.id > 0 and not ws.special then
            local home = owner[ws.id]
            if home ~= nil and home ~= ws.monitor then
                stay[ws.id] = true
            else
                local list = by_mon[ws.monitor]
                if not list then
                    list = {}
                    by_mon[ws.monitor] = list
                end
                list[#list + 1] = ws.id
            end
        end
    end

    local finals = {} -- {from=, to=}
    for mon, ids in pairs(by_mon) do
        table.sort(ids)
        local slots = slots_by_mon[mon]
        if slots and #slots > 0 then
            local k = 1
            for _, slot in ipairs(slots) do
                if k > #ids then break end
                -- Skip slots held by a foreign workspace (stay) so the plan
                -- never claims an id another output still owns.
                if not stay[slot] then
                    local from = ids[k]
                    if slot ~= from then
                        finals[#finals + 1] = { from = from, to = slot }
                    end
                    k = k + 1
                end
            end
            -- extras past the slot list keep their id (reclaim_strays merges those)
        end
    end

    table.sort(finals, function(a, b) return a.from < b.from end)

    -- Swap-shaped plans exist once Super+N puts an id off its round-robin slot.
    return two_phase(finals)
end

-- Pure planners for Super+Ctrl+[ / ] and Super+Ctrl+0, which move the whole
-- workspace here within its monitor's order. order: the ids of the
-- workspaces on that monitor, ascending. Both return change_id steps (empty
-- when it is already at that edge). Only ids in order trade places, so the
-- set of ids stays the same and a hole stays a hole.

-- One place earlier (dir = -1) or later (dir = 1): trade ids with that
-- neighbour.
function M.plan_swap(order, here, dir)
    for i, id in ipairs(order) do
        if id == here then
            local other = order[i + dir]
            if other == nil then return {} end
            return two_phase({ { from = here, to = other }, { from = other, to = here } })
        end
    end
    return {}
end

-- To the end: here takes the last id and each workspace after it moves back
-- one.
function M.plan_to_end(order, here)
    for i, id in ipairs(order) do
        if id == here then
            local finals = {}
            if i < #order then
                finals[1] = { from = here, to = order[#order] }
                for j = i + 1, #order do
                    finals[#finals + 1] = { from = order[j], to = order[j - 1] }
                end
            end
            return two_phase(finals)
        end
    end
    return {}
end

-- Pure planner for Super+Shift+[ / ]: give one window a workspace of its
-- own right before (dir = -1) or after (dir = 1) the one it is on, the
-- others shifting to make room. slots: the monitor's slot ids in order.
-- busy: { [id] = true } for ids holding windows. here: the window's
-- workspace id. lone: it is the only window there.
--
-- Returns moves, target. moves is an ordered list of {from=, to=} stack
-- moves, each into an id that is empty by the time it runs; target is
-- where the window ends up. The run beside the gap shifts away from it
-- up to the nearest empty slot, toward the far end first, so a hole
-- elsewhere survives. Returns nil, "full" when every slot is busy.
--
-- A lone window already has a workspace of its own there, so it trades
-- places with the next busy workspace that way instead; nil when there
-- is none (a lone window at the edge).
function M.plan_insert(slots, busy, here, dir, lone)
    local idx
    for i, id in ipairs(slots) do
        if id == here then idx = i; break end
    end
    if idx == nil then return nil end

    if lone then
        local j = idx + dir
        while slots[j] and not busy[slots[j]] do j = j + dir end
        if slots[j] == nil then return nil end
        return { { from = slots[j], to = here } }, slots[j]
    end

    -- The new workspace goes right after position g (0 = before all).
    local g = dir > 0 and idx or idx - 1
    if slots[g + 1] and not busy[slots[g + 1]] then
        return {}, slots[g + 1]
    end
    for f = g + 2, #slots do
        if not busy[slots[f]] then
            local moves = {}
            for p = f - 1, g + 1, -1 do
                moves[#moves + 1] = { from = slots[p], to = slots[p + 1] }
            end
            return moves, slots[g + 1]
        end
    end
    for f = g, 1, -1 do
        if not busy[slots[f]] then
            local moves = {}
            for p = f + 1, g do
                moves[#moves + 1] = { from = slots[p], to = slots[p - 1] }
            end
            return moves, slots[g]
        end
    end
    return nil, "full"
end

local packing = false

-- Ids outside 1..9 (including leftover TEMP_BASE temps). Merge their windows
-- onto a real slot on the same monitor, then leave — the empty non-persistent
-- workspace is destroyed when unfocused. Keeps Super+N / Super+Tab / the bar on
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

-- Run change_id steps. The workspace object keeps its windows, layout and
-- monitor; only its id moves.
local function renumber(steps)
    if #steps == 0 then return end
    packing = true
    for _, mv in ipairs(steps) do
        hl.dispatch(hl.dsp.workspace.change_id({ workspace = mv.from, id = mv.to }))
        -- Hyprland renames numeric workspaces to tostring(new id) but does not
        -- emit renameworkspace, and waybar's changeworkspaceid handler only
        -- setId — so {name} labels and active-by-name go stale (double-active
        -- pills, missing numbers). A same-name rename is a no-op for us and
        -- still emits renameworkspace>>id,name, which waybar does handle.
        -- Reusing a freed id can also collide with waybar's queued destroy
        -- and drop the live button (issue #62); patched in
        -- ~/projects/upstream/waybar (onWorkspaceIdChanged).
        -- Keep it regardless: a renamed workspace no longer takes its new
        -- id as its name (CHLWorkspace::changeID skips m_name once
        -- m_wasRenamed), so every change_id needs its rename from here on.
        hl.dispatch(hl.dsp.workspace.rename({ workspace = mv.to, name = tostring(mv.to) }))
    end
    packing = false
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

    renumber(M.plan_pack(live, slots_by_mon))
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

local function monitor_name(mon)
    return type(mon) == "string" and mon or (mon and mon.name)
end

-- Super+Shift+[ / ]: the focused window gets a workspace of its own
-- right before (dir = -1) or after (dir = 1) its current one, per
-- plan_insert, and focus follows it. Stacks shift by moving their
-- windows (follow = false), not by change_id: Quickshell 0.3.2 drops a
-- renumbered workspace's window icons. A shifted stack's dwindle tree
-- is rebuilt as its windows land, as with Super+Alt+N. It all runs in
-- this one call, so the packer's debounced timer sees only the result.
function M.move_window_beside(dir)
    local win = hl.get_active_window()
    if not win or win.pinned then return end
    local ws = win.workspace
    local here = ws and tonumber(ws.id)
    local name = ws and monitor_name(ws.monitor)
    if not here or not name then return end

    local monitors = package.loaded["monitors"]
    local slots_by_mon = monitors and monitors.slots_by_monitor and monitors.slots_by_monitor() or {}
    local slots = slots_by_mon[name]
    if not slots then return end

    local busy = {}
    for _, w in ipairs(hl.get_workspaces() or {}) do
        if type(w.id) == "number" and (w.windows or 0) > 0 then
            busy[w.id] = true
        end
    end

    -- Windows a stack move carries: all but this one and pinned ones
    -- (a pinned window rides along with whatever is on screen).
    local function stack(id)
        local out = {}
        for _, w in ipairs(hl.get_workspace_windows(id) or {}) do
            if w.address ~= win.address and not w.pinned then
                out[#out + 1] = w.address
            end
        end
        return out
    end

    local moves, target = M.plan_insert(slots, busy, here, dir, #stack(here) == 0)
    if moves == nil then
        if target == "full" then
            hl.notification.create({ text = "No free workspace on this display", timeout = 1500, icon = "info" })
        end
        return
    end

    -- Snapshot every stack first: each move lands on the id the next one
    -- empties.
    local stacks = {}
    for i, mv in ipairs(moves) do
        stacks[i] = stack(mv.from)
    end
    for i, mv in ipairs(moves) do
        for _, addr in ipairs(stacks[i]) do
            hl.dispatch(hl.dsp.window.move({
                workspace = mv.to,
                window    = "address:" .. addr,
                follow    = false,
            }))
        end
    end
    -- The window stays put when its old workspace's other windows were
    -- the ones that moved.
    if target ~= here then
        hl.dispatch(hl.dsp.window.move({ workspace = target, window = "address:" .. win.address }))
    end
end

-- The focused workspace and the ascending ids of the workspaces on its
-- monitor within that monitor's slots (a foreign id waiting for monitors.lua
-- is not in its order).
local function focused_order()
    local ws = hl.get_active_workspace()
    local here = ws and tonumber(ws.id)
    local name = ws and monitor_name(ws.monitor)
    if not here or not name then return end

    local monitors = package.loaded["monitors"]
    local slots_by_mon = monitors and monitors.slots_by_monitor and monitors.slots_by_monitor() or {}
    local mine = {}
    for _, id in ipairs(slots_by_mon[name] or {}) do mine[id] = true end

    local order = {}
    for _, w in ipairs(hl.get_workspaces() or {}) do
        if not w.special and mine[w.id] and monitor_name(w.monitor) == name then
            order[#order + 1] = w.id
        end
    end
    table.sort(order)
    return here, order
end

-- Super+Ctrl+[ / ]: the workspace here trades places with the one before
-- (dir = -1) or after (dir = 1) it. Super+Ctrl+0: it moves to the end and
-- the ones after it close up. The view stays on it under its new id.
function M.move_workspace(dir)
    local here, order = focused_order()
    if here then renumber(M.plan_swap(order, here, dir)) end
end

function M.move_workspace_to_end()
    local here, order = focused_order()
    if here then renumber(M.plan_to_end(order, here)) end
end

M.pack = pack_now
M.reclaim = reclaim_strays
M.schedule = schedule
return M
