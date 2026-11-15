--[[
    src/hub/criminality/init.lua

    Criminality hub entry point. Builds the interface, wires the features and
    exposes getgenv().criminality_hub for teardown.
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Anti-cheat bypass goes in before anything else touches the game.
local env = getgenv()

if env.criminality_skip_bypass ~= true then
    local Bypass = require("@src/hub/criminality/bypass")
    Bypass.install()
end

if env.criminality_hub and env.criminality_hub.destroy then
    pcall(function()
        env.criminality_hub:destroy()
    end)
end

local UI = require("@src/hub/criminality/ui")
local State = require("@src/hub/criminality/state")
local Config = require("@src/hub/criminality/config")
local Game = require("@src/hub/criminality/game")
local Aimbot = require("@src/hub/criminality/features/aimbot")
local Silent = require("@src/hub/criminality/features/silent")
local ESP = require("@src/hub/criminality/features/esp")
local Misc = require("@src/hub/criminality/features/misc")
local World = require("@src/hub/criminality/features/world")
local Gun = require("@src/hub/criminality/features/gun")
local Disablers = require("@src/hub/criminality/features/disablers")

State.define("config.name", "default")

-- drop a window left behind by an earlier failed boot
do
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    local previous = parent and parent:FindFirstChild("criminality_hub")

    if previous then
        previous:Destroy()
    end
end

local window = UI.new({
    title = "criminality  ·  hub",
    menuKey = Enum.KeyCode.RightShift,
    status = "booting",
})

local hub = {
    window = window,
    version = "1.0",
}

--------------------------------------------------------------------------
-- aimbot
--------------------------------------------------------------------------

do
    local tab = window:tab("aimbot", "Aimbot")
    local lock = tab:section("Lock", "camera aim with smoothing")

    lock:toggle("aimbot.enabled", "Enabled")
    lock:keybind("aimbot.key", "Keybind")
    lock:dropdown("aimbot.mode", "Mode", { "toggle", "hold", "always" })
    lock:dropdown("aimbot.part", "Target part", { "Head", "Torso", "HumanoidRootPart", "Closest" })
    lock:dropdown("aimbot.priority", "Priority", { "crosshair", "distance", "health" })

    local aim = tab:section("Aim behaviour", "how the camera moves")

    aim:slider("aimbot.fov", "FOV radius", 30, 600, 1)
    aim:slider("aimbot.smoothing", "Smoothing", 1, 50, 1)
    aim:slider("aimbot.max_distance", "Max distance", 50, 1500, 10)
    aim:toggle("aimbot.snap", "Instant snap")
    aim:toggle("aimbot.prediction", "Predict movement")
    aim:slider("aimbot.prediction_velocity", "Prediction strength", 1, 40, 1)
    aim:toggle("aimbot.visible_check", "Visible check")
    aim:toggle("aimbot.friends", "Ignore friends")
    aim:toggle("aimbot.team", "Ignore teammates")

    local visuals = tab:section("Overlay")

    visuals:toggle("aimbot.draw_fov", "Draw FOV ring")

    local travel = tab:section("Teleports", "map waypoints")

    travel:dropdown("teleport.target", "Location", Misc.positions())
    travel:button("Teleport", function()
        if Misc.teleport(State.get("teleport.target")) then
            window:notify("teleported to " .. tostring(State.get("teleport.target")))
        else
            window:notify("teleport on cooldown or no character", "error")
        end
    end)
end

--------------------------------------------------------------------------
-- silent aim
--------------------------------------------------------------------------

do
    local tab = window:tab("silent", "Silent")
    local core = tab:section("Silent aim", "redirects the shot, not the camera")

    core:toggle("silent.enabled", "Enabled")
    core:keybind("silent.key", "Keybind")
    core:dropdown("silent.mode", "Mode", { "toggle", "hold", "always" })
    core:dropdown("silent.part", "Hitbox", { "Head", "Torso", "HumanoidRootPart" })
    core:dropdown("silent.priority", "Priority", { "crosshair", "distance", "health" })

    local tuning = tab:section("Tuning")

    tuning:slider("silent.hitchance", "Hitchance", 1, 100, 1, nil, "%")
    tuning:slider("silent.fov", "FOV radius", 30, 900, 5)
    tuning:slider("silent.max_distance", "Max distance", 50, 1500, 10)
    tuning:toggle("silent.visible_check", "Visible check")
    tuning:toggle("silent.wallbang", "Wallbang")
    tuning:toggle("silent.friends", "Ignore friends")

    local visual = tab:section("Feedback")

    visual:toggle("silent.visualize", "Draw target")
    visual:toggle("silent.hook_mouse", "Hook mouse position")
    visual:label("Mouse hook only needed when the game reads Mouse.X/Y instead of raycasting.")
end

--------------------------------------------------------------------------
-- visuals
--------------------------------------------------------------------------

do
    local tab = window:tab("visuals", "Visuals")
    local players = tab:section("Players")

    players:toggle("esp.enabled", "Player ESP")
    players:toggle("esp.box", "Box")
    players:toggle("esp.name", "Name")
    players:toggle("esp.health", "Health bar")
    players:toggle("esp.distance", "Distance")
    players:toggle("esp.tool", "Held tool")
    players:toggle("esp.chams", "Chams")
    players:toggle("esp.through_walls", "Through walls")
    players:slider("esp.max_distance", "Max distance", 50, 1500, 10)

    local world = tab:section("World")

    world:toggle("world.enabled", "World ESP")
    world:toggle("world.safes", "Safes")
    world:toggle("world.piles", "Scrap piles")
    world:toggle("world.dealers", "Dealers")
    world:toggle("world.atms", "ATMs")
    world:toggle("world.cash", "Dropped cash")
    world:slider("world.max_distance", "Max distance", 50, 1500, 10)

    local earth = tab:section("World settings", "sky and light")

    earth:dropdown("world.skybox", "Skybox", { "none", "nebula", "vaporwave", "clouds", "twilight" })
    earth:toggle("world.color_correction", "Colour correction")
    earth:slider("world.saturation", "Saturation", 0, 100, 1)
    earth:toggle("world.force_time", "Force time of day")
    earth:slider("world.time", "Time", 0, 24, 1)
    earth:toggle("world.disable_clouds", "Disable clouds")

    local removals = tab:section("Removals", "strip effects")

    removals:toggle("world.remove_smoke", "Smoke")
    removals:toggle("world.remove_bullet_holes", "Bullet holes")
    removals:toggle("world.remove_blind", "Blind effect")
    removals:toggle("world.remove_smoke_vignette", "Smoke vignette")
    removals:toggle("world.remove_atm_blur", "ATM blur")
    removals:toggle("world.remove_blood_vignette", "Blood vignette")
end

--------------------------------------------------------------------------
-- misc
--------------------------------------------------------------------------

do
    local tab = window:tab("misc", "Misc")
    local character = tab:section("Character")

    character:toggle("misc.walkspeed", "Walk speed")
    character:slider("misc.speed", "Speed", 16, 120, 1)
    character:toggle("misc.noclip", "Noclip")
    character:toggle("misc.stamina", "Infinite stamina")
    character:toggle("misc.no_jump_cooldown", "No jump cooldown")
    character:toggle("misc.hbe", "Hitbox expander")
    character:slider("misc.hbe_multiplier", "Hitbox size", 100, 400, 5, nil, "%")

    local world = tab:section("World")
    world:toggle("misc.fullbright", "Fullbright")
    world:toggle("misc.fov_changer", "FOV changer")
    world:slider("misc.fov", "Field of view", 30, 120, 1)
    world:toggle("misc.show_chat", "Force chat visible")

    local utility = tab:section("Utility")
    utility:toggle("misc.no_fall", "No fall damage")
    utility:toggle("misc.lockpick", "Lockpick bars")
    utility:toggle("misc.autopickup", "Auto pickup")
    utility:slider("misc.autopickup_range", "Pickup range", 2, 20, 1)

    local weapons = tab:section("Gun mods", "config swap")

    weapons:toggle("gun.enabled", "Enabled")
    weapons:slider("gun.recoil", "Recoil", 0, 100, 1, nil, "%")
    weapons:slider("gun.firerate", "Fire rate", 1, 3, 0.1, nil, "x")
    weapons:toggle("gun.fast_equip", "Fast equip")
    weapons:toggle("gun.no_spread", "No spread")

    local disablers = tab:section("Disablers")

    disablers:toggle("disablers.down", "No down")
    disablers:toggle("disablers.ragdoll", "No ragdoll")
    disablers:toggle("disablers.zawarudo", "No za warudo")
    disablers:toggle("disablers.jailed", "No jailed")
    disablers:toggle("disablers.handcuffed", "No handcuffs")
end

--------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------

do
    local tab = window:tab("config", "Config")
    local profiles = tab:section("Profiles", "stored in " .. "criminality/Configs")

    profiles:text("config.name", "Profile name", "default")
    profiles:button("Save profile", function()
        local name = State.get("config.name")

        if type(name) ~= "string" or name == "" then
            window:notify("profile name is empty", "error")
            return
        end

        local ok, err = Config.save(name)

        if ok then
            window:notify("saved " .. name)
        else
            window:notify("save failed: " .. tostring(err), "error")
        end
    end)
    profiles:button("Load profile", function()
        local ok, message = Config.load(State.get("config.name"))

        if ok then
            window:notify("loaded " .. tostring(message) .. " settings")
        else
            window:notify(tostring(message), "error")
        end
    end)
    profiles:button("Delete profile", function()
        local ok = Config.delete(State.get("config.name"))

        if ok then
            window:notify("deleted")
        else
            window:notify("delete failed", "error")
        end
    end)

    local info = tab:section("Session")

    info:label("Right shift hides the window. Settings live in memory until saved.")
    info:button("Unload hub", function()
        hub:destroy()
    end, true)
end

--------------------------------------------------------------------------
-- boot
--------------------------------------------------------------------------

Config.autoload()

if env.criminality_ui_only ~= true then
    Aimbot.start(hub)
    Silent.start(hub)
    ESP.start(hub)
    Misc.start(hub)
    World.start(hub)
    Gun.start(hub)
    Disablers.start(hub)
end

window.status.Text = "ready"

task.spawn(function()
    while hub and window.screenGui and window.screenGui.Parent do
        local count = 0

        if State.get("aimbot.enabled") then
            count = #require("@src/hub/criminality/targeting").list
        end

        window.status.Text = "right shift  ·  " .. tostring(count) .. " targets"
        task.wait(0.5)
    end
end)

function hub:destroy()
    if self.destroyed then
        return
    end

    self.destroyed = true

    Aimbot.stop()
    Silent.stop()
    ESP.stop()
    Misc.stop()
    World.stop()
    Gun.stop()
    Disablers.stop()

    if self.window and self.window.screenGui then
        self.window.screenGui:Destroy()
    end

    if getgenv().criminality_hub == self then
        getgenv().criminality_hub = nil
    end
end

env.criminality_hub = hub

return hub
