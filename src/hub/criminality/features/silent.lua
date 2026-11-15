--[[
    src/hub/criminality/features/silent.lua

    Silent aim: redirects the game's raycasts (and optionally the mouse
    coordinates the gun script reads) toward the best target, without touching
    the camera. Everything is gated behind checkcaller() and a two-string
    method check so the hook costs almost nothing when the feature is off.
]]

local Game = require("@src/hub/criminality/game")
local State = require("@src/hub/criminality/state")
local Targeting = require("@src/hub/criminality/targeting")

local Silent = {}

local defaults = {
    ["silent.enabled"] = false,
    ["silent.mode"] = "toggle",
    ["silent.key"] = "C",
    ["silent.part"] = "Head",
    ["silent.priority"] = "crosshair",
    ["silent.hitchance"] = 100,
    ["silent.fov"] = 200,
    ["silent.max_distance"] = 600,
    ["silent.visible_check"] = false,
    ["silent.wallbang"] = false,
    ["silent.visualize"] = true,
    ["silent.hook_mouse"] = false,
    ["silent.friends"] = false,
}

for key, value in next, defaults do
    State.define(key, value)
end

local currentTarget
local toggled = false
local keyWasDown = false
local originals = {}
local line
local dot

local function active()
    if not State.get("silent.enabled") then
        return false
    end

    local mode = State.get("silent.mode")
    local down = Game.keyDown(State.get("silent.key"))

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

local function ensureDrawings()
    if not line and Drawing then
        line = Drawing.new("Line")
        line.Thickness = 1
        line.Transparency = 0.9
        line.Visible = false

        dot = Drawing.new("Circle")
        dot.Thickness = 1
        dot.NumSides = 24
        dot.Radius = 6
        dot.Filled = false
        dot.Transparency = 0.9
        dot.Visible = false
    end

    return line, dot
end

local function targetPoint(entry)
    if not entry then
        return nil
    end

    return entry.hitbox.Position
end

local function hitchance()
    local chance = tonumber(State.get("silent.hitchance")) or 100

    if chance >= 100 then
        return true
    end

    return math.random(1, 100) <= chance
end

local function installNamecall()
    if originals.namecall then
        return
    end

    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if checkcaller() then
            return old(self, ...)
        end

        local method = getnamecallmethod()

        if method ~= "Raycast" and method ~= "FindPartOnRay" and method ~= "FindPartOnRayWithIgnoreList" then
            return old(self, ...)
        end

        if not active() or not currentTarget or not hitchance() then
            return old(self, ...)
        end

        local args = { ... }
        local point = targetPoint(currentTarget)

        if not point then
            return old(self, ...)
        end

        local camera = Game.camera

        if method == "Raycast" then
            local origin = args[1]
            local direction = args[2]

            if type(origin) == "Vector3" and type(direction) == "Vector3" then
                args[2] = (point - origin).Unit * direction.Magnitude
            end

            local params = args[3]

            if State.get("silent.wallbang") and typeof(params) == "RaycastParams" then
                params.FilterType = Enum.RaycastFilterType.Include
                params.FilterDescendantsInstances = { currentTarget.character }
            end

            return old(self, table.unpack(args))
        elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
            local ray = args[1]

            if typeof(ray) == "Ray" then
                args[1] = Ray.new(ray.Origin, (point - ray.Origin).Unit * (ray.Direction.Magnitude > 0 and ray.Direction.Magnitude or 1000))
            end

            return old(self, table.unpack(args))
        end

        return old(self, ...)
    end)

    originals.namecall = old
end

local function installMouse()
    if originals.index or not State.get("silent.hook_mouse") then
        return
    end

    local mouse = Game.mouse
    local old

    old = hookmetamethod(game, "__index", function(self, key)
        if self ~= mouse then
            return old(self, key)
        end

        if checkcaller() or not active() or not currentTarget or not hitchance() then
            return old(self, key)
        end

        if key == "X" or key == "Y" then
            local point = targetPoint(currentTarget)

            if point then
                local screen = Game.camera:WorldToViewportPoint(point)

                if screen.Z > 0 then
                    return screen[key]
                end
            end
        end

        return old(self, key)
    end)

    originals.index = old
end

local connection

function Silent.start(ctx)
    State.on("silent.enabled", function(value)
        if value then
            pcall(installNamecall)
        end
    end)

    connection = Game.runService.RenderStepped:Connect(function()
        local enabled = active()

        if State.get("silent.hook_mouse") then
            installMouse()
        end

        if not enabled or not Game.localAlive() then
            currentTarget = nil

            if line then
                line.Visible = false
                dot.Visible = false
            end

            return
        end

        local list = Targeting.scan({
            part = State.get("silent.part"),
            priority = State.get("silent.priority"),
            maxDistance = State.get("silent.max_distance"),
            visibleCheck = State.get("silent.visible_check"),
            friends = State.get("silent.friends"),
        })

        local best = list[1]

        if best and best.crosshairDistance <= State.get("silent.fov") then
            currentTarget = best
        else
            currentTarget = nil
        end

        local targetLine, targetDot = ensureDrawings()

        if targetLine and targetDot then
            local show = State.get("silent.visualize") and currentTarget ~= nil
            targetLine.Visible = show and true or false
            targetDot.Visible = show and true or false

            if show then
                local screen = Game.camera:WorldToViewportPoint(currentTarget.hitbox.Position)
                local viewport = Game.camera.ViewportSize

                targetLine.From = Vector2.new(viewport.X / 2, viewport.Y)
                targetLine.To = Vector2.new(screen.X, screen.Y)
                targetLine.Color = Color3.fromRGB(84, 101, 255)
                targetDot.Position = Vector2.new(screen.X, screen.Y)
                targetDot.Color = Color3.fromRGB(84, 101, 255)
            end
        end
    end)
end

function Silent.stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end

    currentTarget = nil

    if line then
        line:Remove()
        line = nil
    end

    if dot then
        dot:Remove()
        dot = nil
    end
end

return Silent

