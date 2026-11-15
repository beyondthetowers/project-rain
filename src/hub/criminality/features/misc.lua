--[[
    src/hub/criminality/features/misc.lua

    Character and world utilities: speed, noclip, stamina, hitbox expander,
    fullbright, no fall, chat visibility, lockpick bars, auto pickup, FOV.
]]

local Game = require("@src/hub/criminality/game")
local State = require("@src/hub/criminality/state")

local Misc = {}

local defaults = {
    ["misc.walkspeed"] = false,
    ["misc.speed"] = 32,
    ["misc.noclip"] = false,
    ["misc.stamina"] = false,
    ["misc.hbe"] = false,
    ["misc.hbe_multiplier"] = 150,
    ["misc.fullbright"] = false,
    ["misc.no_fall"] = false,
    ["misc.show_chat"] = false,
    ["misc.lockpick"] = false,
    ["misc.autopickup"] = false,
    ["misc.autopickup_range"] = 7,
    ["misc.fov_changer"] = false,
    ["misc.fov"] = 90,
    ["misc.no_jump_cooldown"] = false,
}

for key, value in next, defaults do
    State.define(key, value)
end

local teleportPositions = {
    ["tower"] = Vector3.new(-4475, 105, -850),
    ["vibe check"] = Vector3.new(-4848, -200, -875),
    ["subway"] = Vector3.new(-4619, -31, -814),
    ["sewers"] = Vector3.new(-4131, -91, -704),
    ["junkyard"] = Vector3.new(-3941, 5, -595),
    ["gas station"] = Vector3.new(-4373, 7, 215),
    ["motel"] = Vector3.new(-4638, 6, -983),
    ["grey wall"] = Vector3.new(-4901, 189, -779),
}

State.define("teleport.target", "tower")

local lastTeleport = 0

function Misc.positions()
    local names = {}

    for name in next, teleportPositions do
        table.insert(names, name)
    end

    table.sort(names)

    return names
end

function Misc.teleport(name)
    local root = Game.root()
    local destination = teleportPositions[name]

    if not root or not destination then
        return false
    end

    if tick() - lastTeleport < 3 then
        return false
    end

    lastTeleport = tick()
    root.CFrame = CFrame.new(destination)

    return true
end

local connections = {}
local originalSpeed
local originalFov
local lightingState
local staminaHook
local staminaAttempted = false

local function track(connection)
    table.insert(connections, connection)
    return connection
end

local function setChatVisible(visible)
    local ok = pcall(function()
        local service = game:GetService("TextChatService")
        service.ChatWindowConfiguration.Enabled = visible
        service.ChatInputBarConfiguration.Enabled = visible
    end)

    if not ok then
        local playerGui = Game.localPlayer:FindFirstChildOfClass("PlayerGui")
        local legacy = playerGui and playerGui:FindFirstChild("Chat")

        if legacy then
            local frame = legacy:FindFirstChild("Frame")

            if frame then
                frame.ChatChannelParentFrame.Visible = visible
            end
        end
    end
end

local function applyFullbright(enabled)
    local lighting = game:GetService("Lighting")

    if enabled then
        if not lightingState then
            lightingState = {
                ambient = lighting.Ambient,
                outdoor = lighting.OutdoorAmbient,
                brightness = lighting.Brightness,
                clock = lighting.ClockTime,
            }
        end

        lighting.Ambient = Color3.fromRGB(255, 255, 255)
        lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        lighting.Brightness = 2
        lighting.ClockTime = 12
    elseif lightingState then
        lighting.Ambient = lightingState.ambient
        lighting.OutdoorAmbient = lightingState.outdoor
        lighting.Brightness = lightingState.brightness
        lighting.ClockTime = lightingState.clock
    end
end

local function installStamina()
    if staminaHook or staminaAttempted then
        return
    end

    staminaAttempted = true

    local ok, target = pcall(function()
        return getrenv()._G.S_Take
    end)

    if not ok or not target then
        return
    end

    local okUpvalue, upvalue = pcall(getupvalue, target, 2)

    if not okUpvalue or not upvalue then
        return
    end

    local old
    old = hookfunction(upvalue, function(value, ...)
        if State.get("misc.stamina") then
            value = 0
        end

        return old(value, ...)
    end)

    staminaHook = old
end

local noFallInstalled = false

local function installNoFall()
    if noFallInstalled then
        return
    end

    noFallInstalled = true

    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if checkcaller() then
            return old(self, ...)
        end

        if getnamecallmethod() == "FireServer" and State.get("misc.no_fall") and self.Name == "__DFfDD" then
            return
        end

        return old(self, ...)
    end)
end

local function hbe()
    local multiplier = math.max(tonumber(State.get("misc.hbe_multiplier")) or 150, 100) / 100
    local base = Vector3.new(1.2, 1, 1)

    for _, player in next, Game.players:GetPlayers() do
        if player ~= Game.localPlayer then
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if head and humanoid and humanoid.Health > 0 then
                if State.get("misc.hbe") then
                    head.Size = base * multiplier
                    head.Transparency = 0.6
                    head.CanCollide = false
                else
                    head.Size = base
                    head.Transparency = 0
                end
            end
        end
    end
end

local function autoPickup()
    local character = Game.character()
    local root = Game.root()
    local range = tonumber(State.get("misc.autopickup_range")) or 7

    if not character or not root or not State.get("misc.autopickup") then
        return
    end

    if Game.pilePickup and Game.piles then
        for _, pile in next, Game.piles:GetChildren() do
            local part = pile:FindFirstChild("MeshPart")

            if part and (root.Position - part.Position).Magnitude <= range then
                pcall(function()
                    Game.pilePickup:FireServer(part)
                end)
            end
        end
    end

    if Game.cashPickup and Game.cash then
        for _, cash in next, Game.cash:GetChildren() do
            if (root.Position - cash.Position).Magnitude <= range then
                pcall(function()
                    Game.cashPickup:FireServer(cash)
                end)
            end
        end
    end
end

local function lockpickBars()
    if not State.get("misc.lockpick") then
        return
    end

    local playerGui = Game.localPlayer:FindFirstChildOfClass("PlayerGui")
    local gui = playerGui and playerGui:FindFirstChild("LockpickGUI")

    if not gui then
        return
    end

    local frame = gui:FindFirstChild("MF") and gui.MF:FindFirstChild("LP_Frame")

    if not frame then
        return
    end

    local frames = frame:FindFirstChild("Frames")

    if not frames then
        return
    end

    for index = 1, 3 do
        local bar = frames:FindFirstChild("B" .. index)

        if bar and bar:FindFirstChild("Bar") then
            bar.Bar.Size = UDim2.new(0, 35, 0, 500)
        end
    end
end

function Misc.start(ctx)
    local character = Game.localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    originalSpeed = humanoid and humanoid.WalkSpeed or 16
    originalFov = Game.camera.FieldOfView

    track(Game.runService.Heartbeat:Connect(function()
        local localCharacter = Game.localPlayer.Character
        local localHumanoid = localCharacter and localCharacter:FindFirstChildOfClass("Humanoid")
        local root = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

        if localHumanoid then
            if State.get("misc.walkspeed") then
                localHumanoid.WalkSpeed = State.get("misc.speed")
            elseif localHumanoid.WalkSpeed ~= originalSpeed then
                localHumanoid.WalkSpeed = originalSpeed
            end

            if State.get("misc.no_jump_cooldown") then
                localHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            end
        end

        if localCharacter and State.get("misc.noclip") then
            for _, part in next, localCharacter:GetDescendants() do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end

        Game.camera.FieldOfView = State.get("misc.fov_changer") and State.get("misc.fov") or originalFov

        hbe()
        autoPickup()
        lockpickBars()
    end))

    track(Game.runService.RenderStepped:Connect(function()
        if State.get("misc.stamina") then
            installStamina()
        end
    end))

    State.on("misc.no_fall", function(value)
        if value then
            pcall(installNoFall)
        end
    end)

    State.on("misc.fullbright", function(value)
        applyFullbright(value)
    end)

    State.on("misc.show_chat", function(value)
        setChatVisible(value)
    end)
end

function Misc.stop()
    for _, connection in next, connections do
        connection:Disconnect()
    end

    connections = {}

    applyFullbright(false)
    setChatVisible(true)
end

return Misc
