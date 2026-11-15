--[[
    src/hub/criminality/features/gun.lua

    Gun modifiers ported from the old script: recoil, fire rate, equip time and
    spread, applied by swapping the game's Config module for a filtered copy.
    The require hook is installed the first time the feature is enabled and is
    inert while disabled.
]]

local Game = require("@src/hub/criminality/game")
local State = require("@src/hub/criminality/state")

local Gun = {}

local defaults = {
    ["gun.enabled"] = false,
    ["gun.recoil"] = 0,
    ["gun.firerate"] = 1,
    ["gun.fast_equip"] = false,
    ["gun.no_spread"] = false,
}

for key, value in next, defaults do
    State.define(key, value)
end

local installed = false
local fakeConfig

local function buildFakeConfig()
    return {
        GetConfig = function(_, tool)
            local settings = {}
            local ok, config = pcall(function()
                return require(tool:WaitForChild("Config"))
            end)

            if not ok or type(config) ~= "table" then
                return settings
            end

            local recoil = tonumber(State.get("gun.recoil")) or 100
            local firerate = tonumber(State.get("gun.firerate")) or 1

            for setting, value in next, config do
                if State.get("gun.enabled") then
                    if setting == "Recoil" and type(value) == "number" then
                        value = value * (recoil / 100)
                    elseif setting == "FireRate" and type(value) == "number" then
                        value = value * firerate
                    elseif setting == "EquipTime" and State.get("gun.fast_equip") then
                        value = 0.1
                    elseif setting == "Spread" and State.get("gun.no_spread") then
                        value = 0
                    end
                end

                settings[setting] = value
            end

            return settings
        end,
    }
end

local function install()
    if installed or not hookfunction or not getrenv then
        return
    end

    local realConfig = Game.modules and Game.modules:FindFirstChild("Config")

    if not realConfig then
        return
    end

    installed = true
    fakeConfig = buildFakeConfig()

    local original
    original = hookfunction(getrenv().require, function(target, ...)
        if target == realConfig and State.get("gun.enabled") then
            return fakeConfig
        end

        return original(target, ...)
    end)
end

function Gun.start(ctx)
    State.on("gun.enabled", function(value)
        if value then
            local ok, err = pcall(install)

            if not ok then
                warn("[criminality] gun hook failed: " .. tostring(err))
            end
        end
    end)
end

function Gun.stop() end

return Gun
