--[[
    src/hub/criminality/targeting.lua

    One scan per frame, shared by the aimbot, silent aim and the ESP.
]]

local Game = require("@src/hub/criminality/game")
local State = require("@src/hub/criminality/state")

local Targeting = {
    list = {},
    options = {},
    scanId = 0,
}

local function resolvePart(character, partName, mouseLocation)
    if partName == "Head" then
        return character:FindFirstChild("Head")
    elseif partName == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
    elseif partName == "Closest" then
        local head = character:FindFirstChild("Head")
        local root = character:FindFirstChild("HumanoidRootPart")

        if head and root and mouseLocation then
            local headScreen = Game.camera:WorldToViewportPoint(head.Position)
            local rootScreen = Game.camera:WorldToViewportPoint(root.Position)
            local headDistance = (Vector2.new(headScreen.X, headScreen.Y) - mouseLocation).Magnitude
            local rootDistance = (Vector2.new(rootScreen.X, rootScreen.Y) - mouseLocation).Magnitude

            return headDistance <= rootDistance and head or root
        end

        return head or root
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function visible(hitbox)
    local character = Game.character()

    if not character then
        return true
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    params.FilterDescendantsInstances = { Game.camera, character }

    local origin = Game.camera.CFrame.Position
    local direction = hitbox.Position - origin
    local result = workspace:Raycast(origin, direction, params)

    if not result then
        return true
    end

    return result.Instance:IsDescendantOf(hitbox.Parent)
end

function Targeting.scan(options)
    options = options or {}
    local list = {}
    local camera = Game.camera
    local localCharacter = Game.character()
    local mouseLocation = Game.userInputService:GetMouseLocation() + Vector2.new(0, 36)
    local maxDistance = options.maxDistance or 15000
    local partName = options.part or "HumanoidRootPart"
    local visibleCheck = options.visibleCheck == true
    local skipFriends = options.friends == true
    local skipTeam = options.team == true
    local includeLocal = options.includeLocal == true

    for _, player in next, Game.players:GetPlayers() do
        if player ~= Game.localPlayer or includeLocal then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")

            if character and humanoid and root and humanoid.Health > 0 then
                local skip = false

                if not includeLocal and player == Game.localPlayer then
                    skip = true
                end

                if not skip and skipFriends and player ~= Game.localPlayer and Game.isFriend(player) then
                    skip = true
                end

                if not skip and skipTeam and Game.sameTeam(player) then
                    skip = true
                end

                if not skip then
                    local distance = (camera.CFrame.Position - root.Position).Magnitude

                    if distance <= maxDistance then
                        local hitbox = resolvePart(character, partName, mouseLocation)
                        local screen, onScreen = camera:WorldToViewportPoint(root.Position)
                        local onScreenDistance = (Vector2.new(screen.X, screen.Y) - mouseLocation).Magnitude
                        local ok = true

                        if visibleCheck and hitbox then
                            ok = visible(hitbox)
                        end

                        if ok and hitbox then
                            table.insert(list, {
                                player = player,
                                character = character,
                                humanoid = humanoid,
                                root = root,
                                hitbox = hitbox,
                                distance = distance,
                                screen = Vector2.new(screen.X, screen.Y),
                                onScreen = onScreen,
                                crosshairDistance = onScreenDistance,
                                health = humanoid.Health,
                                closest = closest == true,
                            })
                        end
                    end
                end
            end
        end
    end

    local priority = options.priority or "crosshair"

    if priority == "distance" then
        table.sort(list, function(a, b)
            return a.distance < b.distance
        end)
    elseif priority == "health" then
        table.sort(list, function(a, b)
            return a.health < b.health
        end)
    else
        table.sort(list, function(a, b)
            return a.crosshairDistance < b.crosshairDistance
        end)
    end

    Targeting.list = list
    Targeting.scanId = Targeting.scanId + 1

    return list
end

function Targeting.best(options)
    local list = Targeting.scan(options)

    return list[1]
end

function Targeting.inFov(entry, radius)
    if not entry then
        return false
    end

    return entry.crosshairDistance <= radius
end

return Targeting
