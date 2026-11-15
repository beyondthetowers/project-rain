--[[
    src/hub/criminality/state.lua

    Flat key/value store for every setting in the Criminality hub.
    Keys are dotted strings ("aimbot.fov"), values are plain Lua data so a
    profile can be encoded with HttpService:JSONEncode directly.
]]

local State = {
    values = {},
    defaults = {},
    listeners = {},
}

function State.define(key, default)
    if State.defaults[key] == nil then
        State.defaults[key] = default
    end

    if State.values[key] == nil then
        State.values[key] = default
    end

    return default
end

function State.get(key)
    local value = State.values[key]

    if value == nil then
        return State.defaults[key]
    end

    return value
end

function State.set(key, value, internal)
    local previous = State.values[key]
    State.values[key] = value

    if not internal and previous ~= value then
        local callbacks = State.listeners[key]

        if callbacks then
            for _, callback in next, callbacks do
                local ok, err = pcall(callback, value, previous)

                if not ok then
                    warn("[criminality] listener for " .. key .. " failed: " .. tostring(err))
                end
            end
        end
    end
end

function State.on(key, callback)
    local callbacks = State.listeners[key]

    if not callbacks then
        callbacks = {}
        State.listeners[key] = callbacks
    end

    table.insert(callbacks, callback)

    return function()
        local index = table.find(callbacks, callback)

        if index then
            table.remove(callbacks, index)
        end
    end
end

function State.reset()
    for key, default in next, State.defaults do
        State.set(key, default)
    end
end

function State.snapshot()
    local copy = {}

    for key, value in next, State.values do
        if type(value) ~= "table" and type(value) ~= "function" then
            copy[key] = value
        end
    end

    return copy
end

function State.apply(patch)
    if type(patch) ~= "table" then
        return 0
    end

    local applied = 0

    for key, value in next, patch do
        if State.defaults[key] ~= nil and type(value) == type(State.defaults[key]) then
            State.set(key, value)
            applied = applied + 1
        end
    end

    return applied
end

return State
