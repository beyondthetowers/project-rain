--[[
    src/hub/init.lua — single entry point for both products.

    Criminality / Da Hood family  -> @src/hub/criminality/init
    everything else               -> @src/arteria/init  (Deepwoken)

    Detection runs on the game name first, then on the world layout, so a
    re-uploaded place or a renamed server still lands on the right hub.
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = getgenv()

local function hasStructure()
    local map = workspace:FindFirstChild("Map")

    if not map then
        return false
    end

    local dealears = map:FindFirstChild("Shopz")
    local safes = map:FindFirstChild("BredMakurz")

    return dealears ~= nil and safes ~= nil
end

local function isCriminality()
    if env.criminality_force == true then
        return true
    end

    if env.criminality_force == false then
        return false
    end

    -- Criminality (CRIMCORP): start place or any SECTOR sub-place.
    if game.PlaceId == 4588604953 or game.GameId == 1494262959 then
        return true
    end

    local name = string.lower(tostring(game.Name))

    if string.find(name, "criminality", 1, true) then
        return true
    end

    if string.find(name, "da hood", 1, true) then
        return true
    end

    return hasStructure()
end

if isCriminality() then
    if env.arteria and env.arteria.destroy then
        pcall(function()
            env.arteria:destroy()
        end)
    end

    return require("@src/hub/criminality/init")
end

if env.criminality_hub and env.criminality_hub.destroy then
    pcall(function()
        env.criminality_hub:destroy()
    end)
end

return require("@src/arteria/init")
