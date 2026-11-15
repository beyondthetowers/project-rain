--[[
    src/hub/criminality/game.lua

    Resolves the live game objects the hub touches, once, with safe lookups.
    Criminality and Da Hood share this layout; if a folder is missing the
    related feature simply finds nothing and stays quiet.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Game = {
    players = Players,
    localPlayer = Players.LocalPlayer,
    camera = workspace.CurrentCamera,
    mouse = Players.LocalPlayer:GetMouse(),
    replicatedStorage = ReplicatedStorage,
    runService = RunService,
    userInputService = UserInputService,
}

function Game.refresh()
    Game.map = workspace:FindFirstChild("Map")
    Game.dealers = Game.map and Game.map:FindFirstChild("Shopz")
    Game.atms = Game.map and Game.map:FindFirstChild("ATMz")
    Game.safes = Game.map and Game.map:FindFirstChild("BredMakurz")

    Game.filter = workspace:FindFirstChild("Filter")
    Game.piles = Game.filter and Game.filter:FindFirstChild("SpawnedPiles")
    Game.cash = Game.filter and Game.filter:FindFirstChild("SpawnedBread")

    Game.debris = workspace:FindFirstChild("Debris")

    Game.events = ReplicatedStorage:FindFirstChild("Events")
    Game.pilePickup = Game.events and Game.events:FindFirstChild("PIC_PU")
    Game.cashPickup = Game.events and Game.events:FindFirstChild("CZDPZUS")

    Game.charStats = ReplicatedStorage:FindFirstChild("CharStats")
    Game.modules = ReplicatedStorage:FindFirstChild("Modules")

    return Game
end

function Game.character(player)
    player = player or Game.localPlayer
    return player and player.Character
end

function Game.humanoid(player)
    local character = Game.character(player)

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

function Game.root(player)
    local character = Game.character(player)

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

function Game.head(player)
    local character = Game.character(player)

    if not character then
        return nil
    end

    return character:FindFirstChild("Head")
end

function Game.alive(player)
    local humanoid = Game.humanoid(player)

    if not humanoid then
        return false
    end

    return humanoid.Health > 0
end

function Game.localAlive()
    return Game.alive(Game.localPlayer)
end

function Game.isFriend(player)
    if player == Game.localPlayer then
        return true
    end

    local ok, result = pcall(function()
        return Game.localPlayer:IsFriendsWith(player.UserId)
    end)

    return ok and result
end

function Game.sameTeam(player)
    return player.Team ~= nil and player.Team == Game.localPlayer.Team
end

function Game.keyDown(name)
    if type(name) ~= "string" or name == "" then
        return true
    end

    local ok, keyCode = pcall(function()
        return Enum.KeyCode[name]
    end)

    if not ok or not keyCode then
        return true
    end

    if name == "Mouse1" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif name == "Mouse2" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    return UserInputService:IsKeyDown(keyCode)
end

Game.refresh()

return Game
