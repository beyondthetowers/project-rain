--[[
    src/hub/criminality/features/disablers.lua

    Character disablers from the old script: down, ragdoll, zawarudo, jailed,
    handcuffed. Installs one __index hook the first time any disabler is
    enabled; while they are all off the hook returns immediately.
]]

local Game = require("@src/hub/criminality/game")
local State = require("@src/hub/criminality/state")

local Disablers = {}

local defaults = {
    ["disablers.down"] = false,
    ["disablers.ragdoll"] = false,
    ["disablers.zawarudo"] = false,
    ["disablers.jailed"] = false,
    ["disablers.handcuffed"] = false,
}

for key, value in next, defaults do
    State.define(key, value)
end

local installed = false

local function anyEnabled()
    return State.get("disablers.down")
        or State.get("disablers.ragdoll")
        or State.get("disablers.zawarudo")
        or State.get("disablers.jailed")
        or State.get("disablers.handcuffed")
end

local function install()
    if installed or not hookmetamethod then
        return
    end

    installed = true

    local old
    old = hookmetamethod(game, "__index", function(self, key)
        if checkcaller() or not anyEnabled() then
            return old(self, key)
        end

        if key == "Value" then
            local name = self.Name

            if name == "Downed" and State.get("disablers.down") then
                return false
            end

            if name == "RagdollTime" or name == "RagdollTime2" then
                if State.get("disablers.ragdoll") then return 0 end
            elseif name == "RagdollSwitch" or name == "RagdollSwitch2" or name == "SRagdolled" then
                if State.get("disablers.ragdoll") then return false end
            elseif name == "ZaWarudo" then
                if State.get("disablers.zawarudo") then return false end
            elseif name == "Jailed" then
                if State.get("disablers.jailed") then return false end
            elseif name == "Handcuffed" then
                if State.get("disablers.handcuffed") then return false end
            end
        elseif key == "PlatformStand" then
            if State.get("disablers.ragdoll") then
                return false
            end
        end

        return old(self, key)
    end)
end

function Disablers.start(ctx)
    for key in next, defaults do
        State.on(key, function(value)
            if value then
                pcall(install)
            end
        end)
    end
end

function Disablers.stop() end

return Disablers
