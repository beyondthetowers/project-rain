--[[
    src/hub/criminality/init.lua

    Criminality hub entry point. Mounts the Arteria interface with a
    Criminality catalog, wires the features and exposes
    getgenv().criminality_hub for teardown.
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Anti-cheat bypass goes in before anything else touches the game.
local env = getgenv()

if env.criminality_skip_bypass ~= true then
    local Bypass = require("@src/hub/criminality/bypass")
    Bypass.install()
end

if env.criminality_hub and env.criminality_hub.destroy then
    pcall(function()
        env.criminality_hub:destroy()
    end)
end

local Catalog = require("@src/hub/criminality/catalog")
local Adapter = require("@src/hub/criminality/ui_arteria")
local Aimbot = require("@src/hub/criminality/features/aimbot")
local Silent = require("@src/hub/criminality/features/silent")
local ESP = require("@src/hub/criminality/features/esp")
local Misc = require("@src/hub/criminality/features/misc")
local World = require("@src/hub/criminality/features/world")
local Gun = require("@src/hub/criminality/features/gun")
local Disablers = require("@src/hub/criminality/features/disablers")

local hub = {
    version = "1.1",
}

hub.ui = Adapter.mount(Catalog, {
    teleport = function(name)
        return Misc.teleport(name)
    end,
})

local ui = hub.ui

if env.criminality_ui_only ~= true then
    Aimbot.start(hub)
    Silent.start(hub)
    ESP.start(hub)
    Misc.start(hub)
    World.start(hub)
    Gun.start(hub)
    Disablers.start(hub)
end

ui.status = "ready"
ui.refresh()

function hub:destroy()
    if self.destroyed then
        return
    end

    self.destroyed = true

    Aimbot.stop()
    Silent.stop()
    ESP.stop()
    Misc.stop()
    World.stop()
    Gun.stop()
    Disablers.stop()

    if self.ui then
        self.ui.alive = false

        pcall(function()
            self.ui.maid:do_cleaning()
        end)

        if self.ui.gui then
            self.ui.gui:Destroy()
        end
    end

    if getgenv().criminality_hub == self then
        getgenv().criminality_hub = nil
    end
end

env.criminality_hub = hub

return hub
