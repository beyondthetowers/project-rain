--[[
    src/hub/criminality/features/world.lua

    World settings ported from the old scripts: skybox presets, colour
    correction, forced time of day, cloud toggle and the removals list
    (smoke, bullet holes, blind effect, smoke vignette, ATM blur, blood
    vignette).
]]

local Game = require("@src/hub/criminality/game")
local State = require("@src/hub/criminality/state")

local World = {}

local defaults = {
    ["world.skybox"] = "none",
    ["world.color_correction"] = false,
    ["world.saturation"] = 0,
    ["world.fullbright"] = false,
    ["world.force_time"] = false,
    ["world.time"] = 12,
    ["world.disable_clouds"] = false,
    ["world.remove_smoke"] = false,
    ["world.remove_bullet_holes"] = false,
    ["world.remove_blind"] = false,
    ["world.remove_smoke_vignette"] = false,
    ["world.remove_atm_blur"] = false,
    ["world.remove_blood_vignette"] = false,
}

for key, value in next, defaults do
    State.define(key, value)
end

local skyboxes = {
    none = {
        SkyboxLf = "rbxassetid://252760980",
        SkyboxBk = "rbxassetid://252760981",
        SkyboxDn = "rbxassetid://252763035",
        SkyboxFt = "rbxassetid://252761439",
        SkyboxRt = "rbxassetid://252760986",
        SkyboxUp = "rbxassetid://252762652",
    },
    nebula = {
        SkyboxLf = "rbxassetid://159454286",
        SkyboxBk = "rbxassetid://159454299",
        SkyboxDn = "rbxassetid://159454296",
        SkyboxFt = "rbxassetid://159454293",
        SkyboxRt = "rbxassetid://159454300",
        SkyboxUp = "rbxassetid://159454288",
    },
    vaporwave = {
        SkyboxLf = "rbxassetid://1417494402",
        SkyboxBk = "rbxassetid://1417494030",
        SkyboxDn = "rbxassetid://1417494146",
        SkyboxFt = "rbxassetid://1417494253",
        SkyboxRt = "rbxassetid://1417494499",
        SkyboxUp = "rbxassetid://1417494643",
    },
    clouds = {
        SkyboxLf = "rbxassetid://570557620",
        SkyboxBk = "rbxassetid://570557514",
        SkyboxDn = "rbxassetid://570557775",
        SkyboxFt = "rbxassetid://570557559",
        SkyboxRt = "rbxassetid://570557672",
        SkyboxUp = "rbxassetid://570557727",
    },
    twilight = {
        SkyboxLf = "rbxassetid://264909758",
        SkyboxBk = "rbxassetid://264908339",
        SkyboxDn = "rbxassetid://264907909",
        SkyboxFt = "rbxassetid://264909420",
        SkyboxRt = "rbxassetid://264908886",
        SkyboxUp = "rbxassetid://264907379",
    },
}

local connections = {}
local lighting = game:GetService("Lighting")
local colorCorrection
local originalTime

local function applySkybox(name)
    local preset = skyboxes[name]

    if not preset then
        return
    end

    local sky = lighting:FindFirstChildOfClass("Sky")

    if not sky then
        sky = Instance.new("Sky")
        sky.Parent = lighting
    end

    for property, value in next, preset do
        sky[property] = value
    end
end

local function track(connection)
    table.insert(connections, connection)

    return connection
end

local function matchesName(name, wanted)
    return name == wanted
end

local function installRemovals()
    if State.get("world.remove_smoke") then
        track(Game.debris and Game.debris.ChildAdded:Connect(function(child)
            if State.get("world.remove_smoke") and matchesName(child.Name, "SmokeExplosion") then
                child:Destroy()
            end
        end) or { Disconnect = function() end })
    end

    if State.get("world.remove_bullet_holes") then
        track(Game.debris and Game.debris.ChildAdded:Connect(function(child)
            if State.get("world.remove_bullet_holes") and matchesName(child.Name, "BulletHole") then
                child:Destroy()
            end
        end) or { Disconnect = function() end })
    end

    if State.get("world.remove_blind") then
        track(Game.camera.ChildAdded:Connect(function(child)
            if State.get("world.remove_blind") and child.Name == "BlindEffect" then
                child.Enabled = false
            end
        end))
    end

    if State.get("world.remove_smoke_vignette") then
        track(Game.localPlayer.PlayerGui.ChildAdded:Connect(function(child)
            if State.get("world.remove_smoke_vignette") and child.Name == "SmokeScreenGUI" then
                for _, descendant in next, child:GetChildren() do
                    descendant.ImageTransparency = 1
                end
            end
        end))
    end
end

function World.start(ctx)
    originalTime = lighting.ClockTime

    colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "criminality_cc"
    colorCorrection.Enabled = false
    colorCorrection.Parent = Game.camera

    track(Game.runService.Heartbeat:Connect(function()
        lighting.ClockTime = State.get("world.force_time") and State.get("world.time") or originalTime

        local clouds = workspace:FindFirstChild("Terrain") and workspace.Terrain:FindFirstChild("Clouds")

        if clouds then
            clouds.Enabled = not State.get("world.disable_clouds")
        end

        colorCorrection.Enabled = State.get("world.color_correction")
        colorCorrection.Saturation = (tonumber(State.get("world.saturation")) or 0) / 50
    end))

    State.on("world.skybox", function(value)
        applySkybox(value)
    end)

    State.on("world.remove_smoke", function() installRemovals() end)
    State.on("world.remove_bullet_holes", function() installRemovals() end)
    State.on("world.remove_blind", function() installRemovals() end)
    State.on("world.remove_smoke_vignette", function() installRemovals() end)

    installRemovals()
end

function World.stop()
    for _, connection in next, connections do
        pcall(function()
            connection:Disconnect()
        end)
    end

    connections = {}

    if colorCorrection then
        colorCorrection:Destroy()
        colorCorrection = nil
    end

    lighting.ClockTime = originalTime
end

return World
