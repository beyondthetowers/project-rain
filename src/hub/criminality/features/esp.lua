--[[
    src/hub/criminality/features/esp.lua

    Drawing-based player ESP with pooled objects, Highlight-based chams, and a
    world layer for safes, piles, dealers, ATMs and dropped cash.
]]

local Game = require("@src/hub/criminality/game")
local State = require("@src/hub/criminality/state")

local ESP = {}

local defaults = {
    ["esp.enabled"] = false,
    ["esp.box"] = true,
    ["esp.name"] = true,
    ["esp.health"] = true,
    ["esp.distance"] = true,
    ["esp.tool"] = false,
    ["esp.chams"] = false,
    ["esp.through_walls"] = false,
    ["esp.max_distance"] = 600,

    ["world.enabled"] = false,
    ["world.safes"] = true,
    ["world.piles"] = true,
    ["world.dealers"] = true,
    ["world.atms"] = false,
    ["world.cash"] = false,
    ["world.max_distance"] = 600,
}

for key, value in next, defaults do
    State.define(key, value)
end

local pools = {
    box = { objects = {}, active = 0 },
    name = { objects = {}, active = 0 },
    health = { objects = {}, active = 0 },
    distance = { objects = {}, active = 0 },
    tool = { objects = {}, active = 0 },
    world = { objects = {}, active = 0 },
}

local highlights = {}
local connection

local WHITE = Color3.fromRGB(235, 235, 245)
local ACCENT = Color3.fromRGB(84, 101, 255)
local GREEN = Color3.fromRGB(61, 220, 151)
local YELLOW = Color3.fromRGB(255, 209, 102)

local function acquire(pool, kind)
    pool.active = pool.active + 1

    local object = pool.objects[pool.active]

    if not object then
        object = Drawing.new(kind)

        if kind == "Square" then
            object.Thickness = 1
            object.Filled = false
        elseif kind == "Text" then
            object.Center = false
            object.Outline = true
            object.Size = 13
            object.Font = 2
        end

        pool.objects[pool.active] = object
    end

    object.Visible = true

    return object
end

local function release(pool)
    for index = pool.active + 1, #pool.objects do
        pool.objects[index].Visible = false
    end

    pool.active = 0
end

local function clearPool(pool)
    for _, object in next, pool.objects do
        object:Remove()
    end

    pool.objects = {}
    pool.active = 0
end

local function applyChams(character, enabled, throughWalls)
    local highlight = highlights[character]

    if enabled then
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "criminality_cham"
            highlight.FillColor = ACCENT
            highlight.FillTransparency = 0.55
            highlight.OutlineColor = WHITE
            highlight.OutlineTransparency = 0
            highlight.DepthMode = throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            highlight.Adornee = character
            highlight.Parent = character
            highlights[character] = highlight
        else
            highlight.DepthMode = throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            highlight.Enabled = true
        end
    elseif highlight then
        highlight.Enabled = false
    end
end

local function cleanHighlights()
    for character, highlight in next, highlights do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end

        highlights[character] = nil
    end
end

local function playerEsp()
    local camera = Game.camera
    local localPlayer = Game.localPlayer

    for _, player in next, Game.players:GetPlayers() do
        if player ~= localPlayer then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local head = character and character:FindFirstChild("Head")

            if character and humanoid and root and head and humanoid.Health > 0 then
                local distance = (camera.CFrame.Position - root.Position).Magnitude

                if distance <= State.get("esp.max_distance") then
                    local top, topOn = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
                    local bottom, bottomOn = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.6, 0))

                    if topOn and bottomOn then
                        local height = math.abs(bottom.Y - top.Y)
                        local width = height * 0.55
                        local left = math.min(top.X, bottom.X) - width / 2
                        local topY = math.min(top.Y, bottom.Y)

                        if State.get("esp.box") then
                            local box = acquire(pools.box, "Square")
                            box.Position = Vector2.new(left, topY)
                            box.Size = Vector2.new(width, height)
                            box.Color = player.Team and player.TeamColor and player.TeamColor.Color or ACCENT
                        end

                        local healthRatio = humanoid.Health / math.max(humanoid.MaxHealth, 1)

                        if State.get("esp.health") then
                            local bar = acquire(pools.health, "Square")
                            bar.Filled = true
                            bar.Position = Vector2.new(left - 4, topY)
                            bar.Size = Vector2.new(2, height * math.clamp(healthRatio, 0, 1))
                            bar.Color = healthRatio > 0.6 and GREEN or (healthRatio > 0.3 and YELLOW or Color3.fromRGB(255, 92, 92))
                        end

                        local textY = topY

                        if State.get("esp.name") then
                            local name = acquire(pools.name, "Text")
                            name.Text = player.Name
                            name.Size = 13
                            name.Position = Vector2.new(left + width / 2 - name.TextBounds.X / 2, textY - 15)
                            name.Color = WHITE
                        end

                        if State.get("esp.distance") then
                            local distanceText = acquire(pools.distance, "Text")
                            distanceText.Text = tostring(math.floor(distance)) .. "m"
                            distanceText.Size = 12
                            distanceText.Position = Vector2.new(left + width / 2 - distanceText.TextBounds.X / 2, topY + height + 2)
                            distanceText.Color = ACCENT
                        end

                        if State.get("esp.tool") then
                            local tool = character:FindFirstChildOfClass("Tool")

                            if tool then
                                local toolText = acquire(pools.tool, "Text")
                                toolText.Text = tool.Name
                                toolText.Size = 12
                                toolText.Position = Vector2.new(left + width / 2 - toolText.TextBounds.X / 2, topY - 30)
                                toolText.Color = YELLOW
                            end
                        end

                        applyChams(character, State.get("esp.chams"), State.get("esp.through_walls"))
                    end
                end
            end
        end
    end
end

local function worldLabel(position, text, color)
    local screen, onScreen = Game.camera:WorldToViewportPoint(position)

    if onScreen then
        local object = acquire(pools.world, "Text")
        object.Text = text
        object.Size = 12
        object.Position = Vector2.new(screen.X - object.TextBounds.X / 2, screen.Y)
        object.Color = color
    end
end

local function worldEsp()
    local camera = Game.camera
    local maxDistance = State.get("world.max_distance")
    local origin = camera.CFrame.Position

    local function near(position)
        return (origin - position).Magnitude <= maxDistance
    end

    if State.get("world.safes") and Game.safes then
        for _, safe in next, Game.safes:GetChildren() do
            local part = safe:FindFirstChild("MainPart") or safe.PrimaryPart

            if part and near(part.Position) then
                worldLabel(part.Position, safe.Name, Color3.fromRGB(255, 115, 115))
            end
        end
    end

    if State.get("world.piles") and Game.piles then
        for _, pile in next, Game.piles:GetChildren() do
            local part = pile:FindFirstChild("MeshPart") or pile.PrimaryPart

            if part and near(part.Position) then
                worldLabel(part.Position, "Scrap", Color3.fromRGB(235, 235, 245))
            end
        end
    end

    if State.get("world.dealers") and Game.dealers then
        for _, dealer in next, Game.dealers:GetChildren() do
            local part = dealer:FindFirstChild("MainPart") or dealer.PrimaryPart

            if part and near(part.Position) then
                worldLabel(part.Position, "Dealer", Color3.fromRGB(255, 115, 255))
            end
        end
    end

    if State.get("world.atms") and Game.atms then
        for _, atm in next, Game.atms:GetChildren() do
            local part = atm:FindFirstChild("MainPart") or atm.PrimaryPart

            if part and near(part.Position) then
                worldLabel(part.Position, "ATM", Color3.fromRGB(115, 115, 255))
            end
        end
    end

    if State.get("world.cash") and Game.cash then
        for _, cash in next, Game.cash:GetChildren() do
            if near(cash.Position) then
                worldLabel(cash.Position, "Cash", Color3.fromRGB(115, 255, 115))
            end
        end
    end
end

local function tick()
    pools.box.active = 0
    pools.name.active = 0
    pools.health.active = 0
    pools.distance.active = 0
    pools.tool.active = 0
    pools.world.active = 0

    if State.get("esp.enabled") then
        playerEsp()
    end

    if State.get("world.enabled") then
        worldEsp()
    end

    release(pools.box)
    release(pools.name)
    release(pools.health)
    release(pools.distance)
    release(pools.tool)
    release(pools.world)

    if not State.get("esp.chams") then
        cleanHighlights()
    end
end

function ESP.start(ctx)
    connection = Game.runService.RenderStepped:Connect(tick)
end

function ESP.stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end

    for _, pool in next, pools do
        clearPool(pool)
    end

    cleanHighlights()
end

return ESP
