--[[
    src/hub/criminality/ui_arteria.lua

    Mounts the Deepwoken Arteria interface (src/arteria/ui.lua) for Criminality.
    The interface is driven by a runtime table; this adapter fills that table
    from the hub's State store so every toggle and option writes straight into
    the same values the features read.
]]

local Maid = require("@src/utility/maid")
local State = require("@src/hub/criminality/state")
local ArteriaUI = require("@src/arteria/ui")

local Adapter = {}

function Adapter.mount(catalog, callbacks)
    callbacks = callbacks or {}

    local runtime = {
        alive = true,
        busy = false,
        status = "ready",
        errors = {},
        reduce_motion = false,
        low_cost = getgenv().criminality_full_fx ~= true,
        flags = {},
        bindings = {},
        features = {},
        catalog = catalog,
        maid = Maid.new(),
        ac_loaded = type(getgenv().criminality_bypass) == "table",
        ui_key = Enum.KeyCode.RightShift,
    }

    local function sync(id)
        runtime.flags[id] = State.get(id)
    end

    function runtime:set(id, value)
        if id == "teleport.action" then
            if callbacks.teleport then
                callbacks.teleport(State.get("teleport.target"))
            end

            return
        end

        State.set(id, value)
        sync(id)
    end

    function runtime:option(option, value)
        State.set(option.id, value)
        sync(option.id)
    end

    for _, entry in next, catalog.entries do
        sync(entry.id)

        State.on(entry.id, function(value)
            runtime.flags[entry.id] = value

            if runtime.refresh then
                runtime.refresh()
            end
        end)

        for _, option in next, entry.settings do
            sync(option.id)

            State.on(option.id, function(value)
                runtime.flags[option.id] = value

                if runtime.refresh then
                    runtime.refresh()
                end
            end)
        end
    end

    pcall(function()
        writefile("criminality_boot.txt", "ui_arteria:mount")
    end)

    local ok, err = pcall(ArteriaUI.mount, runtime)

    if not ok then
        pcall(function()
            writefile("criminality_boot.txt", "ui error: " .. tostring(err))
        end)

        error(err, 0)
    end

    return runtime
end

return Adapter
