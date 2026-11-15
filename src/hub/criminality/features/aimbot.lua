--[[
    src/hub/criminality/features/aimbot.lua

    Camera aimbot with smoothing, FOV, prediction, target-part choice and a
    drawable FOV ring. Follows the same approach the old Legitinality script
    proved working in this game, with the maths exposed as settings.
]]

local Game = require("@src/hub/criminality/game")
local State = require("@src/hub/criminality/state")
local Targeting = require("@src/hub/criminality/targeting")

local Aimbot = {}

local defaults = {
    ["aimbot.enabled"] = false,
    ["aimbot.mode"] = "toggle",
    ["aimbot.key"] = "Y",
    ["aimbot.part"] = "Head",
    ["aimbot.priority"] = "crosshair",
    ["aimbot.fov"] = 120,
    ["aimbot.max_distance"] = 600,
    ["aimbot.smoothing"] = 6,
    ["aimbot.snap"] = false,
    ["aimbot.prediction"] = true,
    ["aimbot.prediction_velocity"] = 15,
    ["aimbot.visible_check"] = false,
    ["aimbot.friends"] = false,
    ["aimbot.team"] = false,
    ["aimbot.draw_fov"] = true,
    ["aimbot.fov_color"] = "84,101,255",
}

for key, value in next, defaults do
    State.define(key, value)
end

local circle
local toggled = false
local keyWasDown = false

local function ensureCircle()
    if not circle and Drawing then
        circle = Drawing.new("Circle")
        circle.Thickness = 1
        circle.NumSides = 64
        circle.Filled = false
        circle.Transparency = 0.85
        circle.Visible = false
    end

    return circle
end

local function colorFromString(value)
    local parts = string.split(tostring(value or ""), ",")

    if #parts == 3 then
        return Color3.fromRGB(tonumber(parts[1]) or 84, tonumber(parts[2]) or 101, tonumber(parts[3]) or 255)
    end

    return Color3.fromRGB(84, 101, 255)
end

local function predictionOffset(entry)
    if not State.get("aimbot.prediction") then
        return Vector3.zero
    end

    local velocity = entry.hitbox.AssemblyLinearVelocity
    local factor = math.max(tonumber(State.get("aimbot.prediction_velocity")) or 15, 1)

    return velocity / factor
end

local function active()
    if not State.get("aimbot.enabled") then
        return false
    end

    local mode = State.get("aimbot.mode")
    local key = State.get("aimbot.key")
    local down = Game.keyDown(key)

    if mode == "always" then
        return true
    elseif mode == "hold" then
        return down
    end

    if down and not keyWasDown then
        toggled = not toggled
    end

    keyWasDown = down

    return toggled
end

local function drawFov(entryCount)
    local ring = ensureCircle()

    if not ring then
        return
    end

    local show = State.get("aimbot.draw_fov") and State.get("aimbot.enabled") == true
    ring.Visible = show and true or false

    if not show then
        return
    end

    local mouse = Game.userInputService:GetMouseLocation()
    ring.Position = Vector2.new(mouse.X, mouse.Y + 36)
    ring.Radius = State.get("aimbot.fov")
    ring.Color = colorFromString(State.get("aimbot.fov_color"))
    ring.Transparency = entryCount > 0 and 1 or 0.75
end

local connection

function Aimbot.start(ctx)
    local camera = Game.camera

    connection = Game.runService.RenderStepped:Connect(function(delta)
        if not Game.localAlive() then
            drawFov(0)
            return
        end

        if not active() then
            drawFov(0)
            return
        end

        local list = Targeting.scan({
            part = State.get("aimbot.part"),
            priority = State.get("aimbot.priority"),
            maxDistance = State.get("aimbot.max_distance"),
            visibleCheck = State.get("aimbot.visible_check"),
            friends = State.get("aimbot.friends"),
            team = State.get("aimbot.team"),
        })

        local target = list[1]

        if not target or target.crosshairDistance > State.get("aimbot.fov") then
            drawFov(#list)
            return
        end

        drawFov(#list)

        local aimPoint = target.hitbox.Position + predictionOffset(target)
        local origin = camera.CFrame.Position
        local wanted = CFrame.lookAt(origin, aimPoint)

        if State.get("aimbot.snap") then
            camera.CFrame = wanted
        else
            local smoothing = math.max(tonumber(State.get("aimbot.smoothing")) or 1, 1)
            local alpha = 1 - math.exp(-delta * (60 / smoothing))
            camera.CFrame = camera.CFrame:Lerp(wanted, math.clamp(alpha, 0, 1))
        end
    end)
end

function Aimbot.stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end

    if circle then
        circle.Visible = false
    end
end

return Aimbot
