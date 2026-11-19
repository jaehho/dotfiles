-- Screens: which workspaces each monitor holds, and the display menu's
-- mirror and per-screen off.
--
-- Hyprland places monitors itself: the catch-all rule in hyprland.lua (each
-- monitor's own preferred mode, automatic position and scale) or the rules
-- nwg-displays saves to monitors.lua. This module only reads where they
-- ended up, and does what Hyprland will not: keep workspaces 1-9 spread
-- round-robin over the monitors, leftmost getting 1, and move them when a
-- monitor comes or goes (issue #9580 was closed as not planned). The closed
-- set is 1-9, never 10. Minting past 9 is a bug.
--
-- Mirror and off are runtime rules under the selector nwg-displays uses, so
-- they merge into its rule and keep its mode, position and scale. Any config
-- reload drops them, which is how Extend brings every screen back.

local LAPTOP_PATTERN = "eDP-"
local MAX_WORKSPACES = 9
local DEBOUNCE_MS    = 500

local function is_laptop(m)
    return m.name:sub(1, #LAPTOP_PATTERN) == LAPTOP_PATTERN
end

-- Outputs showing their own picture, or with `all` every connected one
-- (turned off and mirroring too). With none left Hyprland invents one called
-- FALLBACK; that is not a screen, so it is left out.
local function monitors(all)
    local list = all and hl.get_monitors({ all = true }) or hl.get_monitors()
    local out = {}
    for _, m in ipairs(list or {}) do
        if m.name ~= "FALLBACK" then out[#out + 1] = m end
    end
    return out
end

-- Left to right as Hyprland placed them.
local function ordered(list)
    local out = { table.unpack(list) }
    table.sort(out, function(a, b)
        if a.x ~= b.x then return a.x < b.x end
        if a.y ~= b.y then return a.y < b.y end
        return a.name < b.name
    end)
    return out
end

-- The rule selector for an override. nwg-displays (use-desc) keys a
-- monitor's rule as "desc:<description>"; hl.monitor merges into a rule
-- with the same selector, so the override changes only the fields it sets.
-- A headless output (the tablet) has no real description: its name.
local function selector(m)
    if m.backend == "drm" and (m.description or "") ~= "" then
        return "desc:" .. m.description
    end
    return m.name
end

local function override(m, fields)
    fields.output = selector(m)
    hl.monitor(fields)
end

-- Set below; apply() may need to retry after its oneshot is spent.
local schedule

-- Assign workspace slots to the monitors as placed, and move any workspace
-- that sits on the wrong one.
local function apply()
    local live = monitors()
    if #live == 0 then
        -- Nothing visible: the laptop was turned off and the last external
        -- just left. Turn the laptop (or any output) back on.
        local all = monitors(true)
        local target
        for _, m in ipairs(all) do
            if is_laptop(m) then target = m end
        end
        target = target or all[1]
        if target then override(target, { disabled = false, mirror = "" }) end
        return
    end
    -- A monitor mid-hotplug reports 0x0, and its position is not final
    -- either, so wait it out. The oneshot that got here is spent, so arm
    -- another — nothing else will.
    for _, m in ipairs(live) do
        if m.width == 0 or m.height == 0 then
            schedule()
            return
        end
    end

    local order = ordered(live)

    -- Round-robin 1..MAX_WORKSPACES. The first workspace each monitor receives
    -- becomes its default, so a fresh workspace opens where you expect.
    local count = #order
    local assigned, defaults = {}, {}
    for ws = 1, MAX_WORKSPACES do
        local idx = ((ws - 1) % count) + 1
        local name = order[idx].name
        local is_default = defaults[idx] == nil
        if is_default then
            defaults[idx] = ws
        end
        assigned[ws] = name
        -- Not persistent: an empty workspace must die when you leave it so
        -- workspace.removed fires and workspace_pack.lua ripples the holes
        -- closed (tmux renumber-windows). Super+N creates id N if missing.
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
    for _, m in ipairs(live) do
        if m.focused then focused = m.name end
    end

    local swept = false
    for idx, m in ipairs(order) do
        local now = hl.get_monitor(m.name)
        local active = now and now.active_workspace
        -- active_workspace is a userdata (not a table) on 0.57, so read .id
        -- off anything that is not already a number.
        local id = active and (type(active) == "number" and active or active.id)
        if id and assigned[id] ~= m.name and defaults[idx] then
            -- set_workspace({ workspace = "N" }) does nothing when N exists
            -- already (0.57.1, checked live); the workspace object works. The
            -- table form is only good for creating it.
            local home = hl.get_workspace(tostring(defaults[idx]))
            if home then
                now:set_workspace(home)
            else
                now:set_workspace({ workspace = tostring(defaults[idx]) })
            end
            swept = true
        end
    end

    if swept and focused then
        hl.dispatch(hl.dsp.focus({ monitor = focused }))
    end

    -- Closed set 1-9: fold any stray (temp leak, Super+scroll mint, 9003) back
    -- into the slots so the bar and Super+N only ever see 1-9.
    local pack = package.loaded["workspace_pack"]
    if pack and pack.reclaim then
        pack.reclaim()
    end
end

-- Slot ids each output owns under the live layout (same order and formula
-- as apply()). workspace_pack.lua packs only into these so the id ↔ monitor
-- map hypr-tab-nonempty and hypr-move-project assume survives.
local function slots_by_monitor()
    local live = monitors()
    if #live == 0 then return {} end
    for _, m in ipairs(live) do
        if m.width == 0 or m.height == 0 then return {} end
    end

    local order = ordered(live)
    local slots = {}
    for ws = 1, MAX_WORKSPACES do
        local name = order[((ws - 1) % #order) + 1].name
        slots[name] = slots[name] or {}
        slots[name][#slots[name] + 1] = ws
    end
    return slots
end

-- Trailing-edge debounce: hotplug fires several events in a burst.
-- opts.type is mandatory ("repeat" or "oneshot") and hl.timer returns nil
-- without it. Creating it armed also gives us the initial apply, since the
-- config is parsed before monitors can be queried; that covers startup and
-- every reload (no event fires on a reload).
local function new_timer()
    return hl.timer(function()
        apply()
    end, { timeout = DEBOUNCE_MS, type = "oneshot" })
end
local pending = new_timer()

-- While armed, set_enabled(true) restarts the countdown, which is the debounce.
-- A oneshot that has fired is spent (is_enabled() is nil and set_enabled
-- revives nothing), so that case needs a new timer.
schedule = function()
    if pending:is_enabled() then
        pending:set_enabled(true)
    else
        pending = new_timer()
    end
end

hl.on("monitor.added", schedule)
hl.on("monitor.removed", schedule)
-- Deliberately not monitor.layout_changed: moving workspaces changes the
-- layout, which would re-enter this.

-- "extend", "mirror", "external" (laptop off) or "laptop" (externals off).
-- Extend reloads the config, which drops every override and brings back the
-- configured rules. Returns false when the layout needs an external and
-- none is connected.
local function set_layout(layout)
    if layout == "extend" then
        hl.dispatch(hl.dsp.reload_config())
        return true
    end
    local laptop, externals = nil, {}
    for _, m in ipairs(monitors(true)) do
        if is_laptop(m) and laptop == nil then laptop = m else externals[#externals + 1] = m end
    end
    if laptop == nil or (#externals == 0 and layout ~= "laptop") then return false end
    override(laptop, { disabled = layout == "external", mirror = "" })
    for _, m in ipairs(externals) do
        override(m, {
            disabled = layout == "laptop",
            mirror = layout == "mirror" and laptop.name or "",
        })
    end
    return true
end

-- Turn one output off or back on. Refuses to turn off the last one showing
-- its own picture.
local function toggle_output(name)
    for _, m in ipairs(monitors(true)) do
        if m.name == name then
            if not m.enabled then
                override(m, { disabled = false })
                return true
            end
            for _, other in ipairs(monitors()) do
                if other.name ~= name then
                    override(m, { disabled = true })
                    return true
                end
            end
            return false
        end
    end
    return false
end

-- An output arriving or leaving by a path that fires no event (the headless
-- tablet): clear a turned-off state its rule may still carry, so a new one
-- under the same name comes up on, and re-apply.
local function forget(name)
    hl.monitor({ output = name, disabled = false })
    schedule()
end

return {
    apply = apply,
    schedule = schedule,
    set_layout = set_layout,
    toggle_output = toggle_output,
    forget = forget,
    slots_by_monitor = slots_by_monitor,
}
