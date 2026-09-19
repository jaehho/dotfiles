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

-- Display mode, set by the display key (F1) through set_mode(). It only means
-- something while an external is connected, and falls back to "extend" when the
-- last one leaves. "mirror": externals show the laptop. "external": laptop off.
local mode = "extend"
-- A mirrored or disabled output may drop out of hl.get_monitors(), so the names
-- it needs to be brought back by are remembered here.
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

-- Undo "mirror" and "external": plain rules for every remembered output. Each
-- one that comes back fires monitor.added, which re-applies the layout.
local function release()
    if seen.laptop then
        hl.monitor({ output = seen.laptop, mode = "preferred", position = "auto", scale = "auto" })
    end
    for name in pairs(seen.externals) do
        hl.monitor({ output = name, mode = "preferred", position = "auto", scale = "auto" })
    end
end

-- Recompute and apply monitor positions and workspace rules.
local function apply()
    local monitors = hl.get_monitors()
    if monitors == nil or #monitors == 0 then
        -- The laptop was off and the last external just left.
        if mode ~= "extend" then
            mode = "extend"
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

    local ordered = order_monitors(monitors)

    local laptop, externals = nil, {}
    for _, m in ipairs(ordered) do
        if is_laptop(m) then laptop = m else externals[#externals + 1] = m end
    end
    if laptop then seen.laptop = laptop.name end
    for _, m in ipairs(externals) do seen.externals[m.name] = true end

    -- Mirrored externals may be listed only under the laptop's `mirrors`.
    local mirrored = laptop and type(laptop.mirrors) == "table" and next(laptop.mirrors) ~= nil

    if #externals == 0 and not mirrored then
        if mode ~= "extend" then
            mode = "extend"
            release()
        end
    elseif #externals == 0 then
        ordered = { laptop }
    elseif mode == "mirror" and laptop then
        for _, m in ipairs(externals) do
            hl.monitor({ output = m.name, mode = "preferred", position = "auto", scale = "auto", mirror = laptop.name })
        end
        ordered = { laptop }
    elseif mode == "external" and laptop then
        hl.monitor({ output = laptop.name, disabled = true })
        ordered = externals
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

-- Switch display mode. Leaving "mirror" or "external" brings outputs back
-- asynchronously, so the new layout waits for their monitor.added.
local function set_mode(new)
    if new == mode then return end
    local old = mode
    mode = new
    if old ~= "extend" then
        release()
        schedule()
    else
        apply()
    end
end

local function has_external()
    for _, m in ipairs(hl.get_monitors() or {}) do
        if not is_laptop(m) then return true end
        if type(m.mirrors) == "table" and next(m.mirrors) ~= nil then return true end
    end
    return false
end

return {
    apply = apply,
    schedule = schedule,
    set_mode = set_mode,
    mode = function() return mode end,
    has_external = has_external,
}
