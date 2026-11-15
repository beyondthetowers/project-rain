--[[
    src/hub/criminality/catalog.lua

    Entry list for the Arteria interface. Entry ids are State keys, so a toggle
    in the UI writes straight into the same store the features read.

    Settings arrays follow the Arteria catalog schema:
      number(id, label, low, high)  -> numeric field
      choice(id, label, values)     -> cycling button
]]

local State = require("@src/hub/criminality/state")

local Catalog = {
    sections = { "Movement", "Combat", "Visuals", "World", "Removals", "Misc" },
    entries = {},
}

local function number(id, label, low, high)
    return { id = id, label = label, low = low, high = high }
end

local function choice(id, label, values)
    return { id = id, label = label, values = values }
end

local function add(section, id, label, note, settings, kind)
    table.insert(Catalog.entries, {
        section = section,
        id = id,
        label = label,
        note = note or "",
        settings = settings or {},
        kind = kind or "module",
    })
end

-- Combat -------------------------------------------------------------------

add("Combat", "aimbot.enabled", "Aimbot / camera lock", "Smooth or snap lock, FOV and prediction", {
    choice("aimbot.mode", "Mode", { "toggle", "hold", "always" }),
    choice("aimbot.part", "Target part", { "Head", "Torso", "HumanoidRootPart", "Closest" }),
    choice("aimbot.priority", "Priority", { "crosshair", "distance", "health" }),
    number("aimbot.fov", "FOV radius", 30, 600),
    number("aimbot.smoothing", "Smoothing", 1, 50),
    number("aimbot.max_distance", "Max distance", 50, 1500),
})

add("Combat", "aimbot.snap", "Instant snap")
add("Combat", "aimbot.prediction", "Predict movement", nil, { number("aimbot.prediction_velocity", "Prediction strength", 1, 40) })
add("Combat", "aimbot.visible_check", "Aimbot visible check")
add("Combat", "aimbot.draw_fov", "Draw FOV ring")

add("Combat", "silent.enabled", "Silent aim", "Redirects the shot, not the camera", {
    choice("silent.mode", "Mode", { "toggle", "hold", "always" }),
    choice("silent.part", "Hitbox", { "Head", "Torso", "HumanoidRootPart" }),
    number("silent.hitchance", "Hitchance", 1, 100),
    number("silent.fov", "FOV radius", 30, 900),
    number("silent.max_distance", "Max distance", 50, 1500),
})

add("Combat", "silent.wallbang", "Silent wallbang")
add("Combat", "silent.visualize", "Silent target line")
add("Combat", "silent.hook_mouse", "Silent mouse hook", "Only for games reading Mouse.X/Y")
add("Combat", "silent.visible_check", "Silent visible check")

add("Combat", "disablers.down", "No down")
add("Combat", "disablers.ragdoll", "No ragdoll")
add("Combat", "disablers.zawarudo", "No za warudo")
add("Combat", "disablers.jailed", "No jailed")
add("Combat", "disablers.handcuffed", "No handcuffs")

add("Combat", "teleport.action", "Teleport", "Uses the selected waypoint", {
    choice("teleport.target", "Waypoint", { "tower", "vibe check", "subway", "sewers", "junkyard", "gas station", "motel", "grey wall" }),
}, "action")

-- Visuals ------------------------------------------------------------------

add("Visuals", "esp.enabled", "Player ESP", "Boxes, health, names, distance", {
    number("esp.max_distance", "Maximum range", 50, 1500),
})
add("Visuals", "esp.box", "Player boxes")
add("Visuals", "esp.name", "Player names")
add("Visuals", "esp.health", "Health bar")
add("Visuals", "esp.distance", "Distance")
add("Visuals", "esp.tool", "Held tool")
add("Visuals", "esp.chams", "Chams")
add("Visuals", "esp.through_walls", "Chams through walls")

add("Visuals", "world.enabled", "World ESP", "Safes, scrap, dealers, ATMs, cash", {
    number("world.max_distance", "Maximum range", 50, 1500),
})
add("Visuals", "world.safes", "Safes")
add("Visuals", "world.piles", "Scrap piles")
add("Visuals", "world.dealers", "Dealers")
add("Visuals", "world.atms", "ATMs")
add("Visuals", "world.cash", "Dropped cash")

-- World --------------------------------------------------------------------

add("World", "world.color_correction", "Colour correction", nil, {
    number("world.saturation", "Saturation", 0, 100),
})
add("World", "world.force_time", "Force time of day", nil, {
    number("world.time", "Time", 0, 24),
})
add("World", "world.disable_clouds", "Sky", "Preset and cloud toggle", {
    choice("world.skybox", "Skybox", { "none", "nebula", "vaporwave", "clouds", "twilight" }),
})

-- Removals -----------------------------------------------------------------

add("Removals", "world.remove_smoke", "Smoke")
add("Removals", "world.remove_bullet_holes", "Bullet holes")
add("Removals", "world.remove_blind", "Blind effect")
add("Removals", "world.remove_smoke_vignette", "Smoke vignette")
add("Removals", "world.remove_atm_blur", "ATM blur")
add("Removals", "world.remove_blood_vignette", "Blood vignette")

-- Misc ---------------------------------------------------------------------

add("Movement", "misc.walkspeed", "Walk speed", nil, {
    number("misc.speed", "Speed", 16, 120),
})
add("Movement", "misc.noclip", "Noclip")
add("Movement", "misc.stamina", "Infinite stamina")
add("Movement", "misc.no_jump_cooldown", "No jump cooldown")
add("Movement", "misc.hbe", "Hitbox expander", nil, {
    number("misc.hbe_multiplier", "Hitbox size %", 100, 400),
})
add("Misc", "misc.fullbright", "Fullbright")
add("Misc", "misc.fov_changer", "FOV changer", nil, {
    number("misc.fov", "Field of view", 30, 120),
})
add("Misc", "misc.show_chat", "Force chat visible")
add("Misc", "misc.no_fall", "No fall damage")
add("Misc", "misc.lockpick", "Lockpick bars")
add("Misc", "misc.autopickup", "Auto pickup", nil, {
    number("misc.autopickup_range", "Pickup range", 2, 20),
})

add("Misc", "gun.enabled", "Gun mods", "Config swap", {
    number("gun.recoil", "Recoil %", 0, 100),
    number("gun.firerate", "Fire rate", 1, 3),
})
add("Misc", "gun.fast_equip", "Fast equip")
add("Misc", "gun.no_spread", "No spread")

-- make sure every option has a backing value
for _, entry in next, Catalog.entries do
    State.define(entry.id, false)

    for _, option in next, entry.settings do
        if option.values then
            State.define(option.id, option.values[1])
        else
            State.define(option.id, option.low or 0)
        end
    end
end

return Catalog
