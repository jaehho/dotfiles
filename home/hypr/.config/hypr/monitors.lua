-- Monitor layout + workspace assignment.
--
-- Replaces the hypr-monitor daemon (retired 2026-09-01). That tool existed to
-- generate monitors.conf/workspaces.conf because hyprlang could not compute
-- anything; Lua can, so there is no generated file, no socket watcher, and no
-- `hyprctl reload` (and therefore none of the post-reload races the daemon had
-- to poll around). hl.monitor/hl.workspace_rule mutate live config state.
--
-- Layout rules, unchanged from the daemon:
--   0 externals   [laptop]
--   1 external    [laptop, external]      external to the right
--   2+ externals  [externals..., laptop]  laptop rightmost
-- Externals sort by EXTERNAL_ORDER preference (substring of description or
-- serial), then alphabetically by connector name. Workspaces 1-10 are assigned
-- round-robin, leftmost monitor getting workspace 1.

local LAPTOP_PATTERN = "eDP-"
local EXTERNAL_ORDER = { "FT36ZS2", "B946ZS2" }
local MAX_WORKSPACES = 10
local DEBOUNCE_MS    = 500

-- Display state, set from the display menu (F1) through set_layout() and
-- toggle_output(). `mirror`: every external shows the laptop. `off`: outputs the
-- user turned off. A disabled or mirrored output drops out of hl.get_monitors(),
-- so the names needed to bring them back are remembered in `seen`.
local state = { mirror = false, off = {} }
local seen = { laptop = nil, externals = {} }

-- Format a number the way the old Rust writer did: 60.0 -> "60", not "60.0".
-- Hyprland parses either, but mode strings are compared as text elsewhere.
local function num(n)
    if n == math.floor(n) then
        return string.format("%d", n)
    end
    return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end

local function mode_string(m)
    return string.format("%dx%d@%sHz", m.width, m.height, num(math.floor(m.refresh_rate * 100) / 100))
end

local function logical_width(m)
    return math.floor(m.width / m.scale)
end

local function is_laptop(m)
    return m.name:sub(1, #LAPTOP_PATTERN) == LAPTOP_PATTERN
end

-- The outputs Hyprland has now. With none left it invents one called FALLBACK;
-- that is not a screen, so it is left out and "nothing visible" stays true.
local function live_monitors()
    local out = {}
    for _, m in ipairs(hl.get_monitors() or {}) do
        if m.name ~= "FALLBACK" then out[#out + 1] = m end
    end
    return out
end

-- Index in EXTERNAL_ORDER whose pattern appears in the monitor's description or
-- serial, or nil. Plain substring match (find with `plain`), as before.
local function rank(m)
    for i, pat in ipairs(EXTERNAL_ORDER) do
        if (m.description or ""):find(pat, 1, true) or (m.serial or ""):find(pat, 1, true) then
            return i
        end
    end
    return nil
end

-- Left-to-right ordering of the currently connected monitors.
local function order_monitors(monitors)
    local laptop, externals = nil, {}
    for _, m in ipairs(monitors) do
        if laptop == nil and is_laptop(m) then
            laptop = m
        else
            externals[#externals + 1] = m
        end
    end

    table.sort(externals, function(a, b)
        local ra, rb = rank(a), rank(b)
        if ra and rb then return ra < rb end
        if ra then return true end
        if rb then return false end
        return a.name < b.name
    end)

    if laptop == nil then
        return externals
    elseif #externals == 0 then
        return { laptop }
    elseif #externals == 1 then
        return { laptop, externals[1] }
    end
    externals[#externals + 1] = laptop
    return externals
end

local function reset_state()
    state.mirror = false
    state.off = {}
end

local function pristine()
    return not state.mirror and next(state.off) == nil
end

-- Undo mirroring and turned-off outputs: plain rules for every remembered
-- output. Each real one that comes back fires monitor.added, which re-applies
-- the layout.
local function release()
    if seen.laptop then
        -- disabled = false because a plain rule leaves a disabled output disabled.
        hl.monitor({ output = seen.laptop, mode = "preferred", position = "auto", scale = "auto", disabled = false })
    end
    for name in pairs(seen.externals) do
        -- mirror = "" because a headless output never fires monitor.added, so
        -- nothing else would clear its mirror rule.
        hl.monitor({ output = name, mode = "preferred", position = "auto", scale = "auto", mirror = "", disabled = false })
    end
end

-- The outputs that make up the layout now, left to right. Outputs the user
-- turned off are left out. Mirrored externals are not in `live`, so a mirrored
-- layout is the laptop alone. Returns ordered, laptop, externals, and the
-- externals still to be mirrored (nil once they are).
local function plan(live)
    local active = {}
    for _, m in ipairs(live) do
        if not state.off[m.name] then active[#active + 1] = m end
    end

    local ordered = order_monitors(active)
    local laptop, externals = nil, {}
    for _, m in ipairs(ordered) do
        if is_laptop(m) then laptop = m else externals[#externals + 1] = m end
    end

    local mirrored = laptop and type(laptop.mirrors) == "table" and next(laptop.mirrors) ~= nil
    if #externals == 0 then
        if mirrored then ordered = { laptop } end
    elseif state.mirror and laptop then
        return { laptop }, laptop, externals, externals
    end
    return ordered, laptop, externals, nil
end

-- Recompute and apply monitor positions and workspace rules.
local function apply()
    local monitors = live_monitors()
    if #monitors == 0 then
        -- Nothing visible: the laptop was off and the last external just left.
        if not pristine() then
            reset_state()
            release()
        end
        return
    end
    -- A monitor mid-hotplug reports 0x0. Positioning off that produces a
    -- garbage layout that sticks until the next event, so wait it out.
    for _, m in ipairs(monitors) do
        if m.width == 0 or m.height == 0 then
            return
        end
    end

    for _, m in ipairs(monitors) do
        if is_laptop(m) then seen.laptop = m.name else seen.externals[m.name] = true end
        if state.off[m.name] then hl.monitor({ output = m.name, disabled = true }) end
    end

    local ordered, laptop, externals, to_mirror = plan(monitors)
    if #ordered == 0 then
        reset_state()
        release()
        return
    end
    -- The externals are gone (unplugged), so there is nothing left to mirror.
    if state.mirror and #externals == 0 and not (laptop and type(laptop.mirrors) == "table" and next(laptop.mirrors) ~= nil) then
        state.mirror = false
    end

    for _, m in ipairs(to_mirror or {}) do
        hl.monitor({ output = m.name, mode = "preferred", position = "auto", scale = "auto", mirror = laptop.name })
    end

    local x = 0
    for _, m in ipairs(ordered) do
        hl.monitor({
            output   = m.name,
            mode     = mode_string(m),
            position = string.format("%dx0", x),
            scale    = num(m.scale),
        })
        x = x + logical_width(m)
    end

    -- Round-robin 1..MAX_WORKSPACES. The first workspace each monitor receives
    -- becomes its default, so a fresh workspace opens where you expect.
    local count = #ordered
    local assigned, defaults = {}, {}
    for ws = 1, MAX_WORKSPACES do
        local idx = ((ws - 1) % count) + 1
        local name = ordered[idx].name
        local is_default = defaults[idx] == nil
        if is_default then
            defaults[idx] = ws
        end
        assigned[ws] = name
        hl.workspace_rule({ workspace = tostring(ws), monitor = name, default = is_default })
    end

    -- Rules only bind workspaces at creation time, so existing ones have to be
    -- moved. Hyprland will not do this itself: issue #9580 was closed as not
    -- planned.
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        local target = assigned[ws.id]
        if target then
            local mon = ws.monitor
            local current = type(mon) == "string" and mon or (mon and mon.name)
            if current ~= target then
                hl.dispatch(hl.dsp.workspace.move({ workspace = ws.id, monitor = target }))
            end
        end
    end

    -- Sweep monitors sitting on a workspace that is no longer theirs back to
    -- their default, then restore focus.
    local focused
    for _, m in ipairs(monitors) do
        if m.focused then focused = m.name end
    end

    local swept = false
    for idx, m in ipairs(ordered) do
        local live = hl.get_monitor(m.name)
        local active = live and live.active_workspace
        local id = active and (type(active) == "table" and active.id or active)
        if id and assigned[id] ~= m.name and defaults[idx] then
            local target = hl.get_monitor(m.name)
            if target then
                target:set_workspace({ workspace = tostring(defaults[idx]) })
                swept = true
            end
        end
    end

    if swept and focused then
        hl.dispatch(hl.dsp.focus({ monitor = focused }))
    end
end

-- Slot ids each output owns under the live layout (round-robin, same formula
-- and plan() as apply()). workspaces.lua packs only into these so the
-- id ↔ monitor map hypr-tab-nonempty and hypr-move-project assume survives.
local function slots_by_monitor()
    local monitors = live_monitors()
    if #monitors == 0 then return {} end
    for _, m in ipairs(monitors) do
        if m.width == 0 or m.height == 0 then return {} end
    end

    local ordered = plan(monitors)

    local slots = {}
    local count = #ordered
    if count == 0 then return {} end
    for ws = 1, MAX_WORKSPACES do
        local name = ordered[((ws - 1) % count) + 1].name
        slots[name] = slots[name] or {}
        slots[name][#slots[name] + 1] = ws
    end
    return slots
end

-- Trailing-edge debounce: hotplug fires several events in a burst.
-- opts.type is mandatory ("repeat" or "oneshot") and hl.timer returns nil
-- without it. Creating it armed also gives us the initial apply, since the
-- config is parsed before monitors can be queried.
local function new_timer()
    return hl.timer(function()
        apply()
    end, { timeout = DEBOUNCE_MS, type = "oneshot" })
end
local pending = new_timer()

-- While armed, set_enabled(true) restarts the countdown, which is the debounce.
-- A oneshot that has fired is spent (is_enabled() is nil and set_enabled
-- revives nothing), so that case needs a new timer.
local function schedule()
    if pending:is_enabled() then
        pending:set_enabled(true)
    else
        pending = new_timer()
    end
end

hl.on("monitor.added", schedule)
hl.on("monitor.removed", schedule)
-- Deliberately not monitor.layout_changed: applying rules changes the layout,
-- which would re-enter this.

-- The timer above is created armed, so the initial apply happens ~500ms after
-- the config is parsed. That covers startup and `hyprctl reload` alike; no
-- event fires on a reload, and hyprland.start fires only on the first parse.

-- Change the state. From a plain extend, every output is already live and
-- apply() can act now. Otherwise some outputs are mirrored or off, so they are
-- brought back first and the new layout waits for their monitor.added. A
-- headless output never fires it, hence the explicit schedule().
local function change(fn)
    local was_pristine = pristine()
    fn()
    if was_pristine then
        apply()
    else
        release()
        schedule()
    end
end

local function laptop_name()
    for _, m in ipairs(live_monitors()) do
        if is_laptop(m) then return m.name end
    end
    return seen.laptop
end

-- "extend", "mirror", "external" (laptop off) or "laptop" (externals off).
local function set_layout(layout)
    change(function()
        reset_state()
        if layout == "mirror" then
            state.mirror = true
        elseif layout == "external" then
            state.off[laptop_name() or ""] = true
        elseif layout == "laptop" then
            for name in pairs(seen.externals) do state.off[name] = true end
        end
    end)
end

-- Turn one output off or back on. Refuses to turn off the last one on.
local function toggle_output(name)
    local on = {}
    for _, m in ipairs(live_monitors()) do on[m.name] = true end
    if state.off[name] then
        change(function() state.off[name] = nil end)
    elseif on[name] then
        local others = 0
        for other in pairs(on) do
            if other ~= name and not state.off[other] then others = others + 1 end
        end
        if others == 0 then return false end
        change(function() state.off[name] = true end)
    end
    return true
end

-- An output is leaving or arriving by a path that fires no event (a headless
-- one): forget that it was ever turned off, and re-apply.
local function forget(name)
    state.off[name] = nil
    seen.externals[name] = nil
    schedule()
end

-- Back to a plain extend, now. For callers that are about to remove an output
-- (tablet-display off) and must not leave the laptop panel disabled.
local function reset()
    change(reset_state)
end

return {
    apply = apply,
    schedule = schedule,
    set_layout = set_layout,
    toggle_output = toggle_output,
    reset = reset,
    forget = forget,
    slots_by_monitor = slots_by_monitor,
}
