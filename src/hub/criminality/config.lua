--[[
    src/hub/criminality/config.lua

    Named profiles on disk: criminality/Configs/<name>.json
    Only keys that exist in State.defaults are accepted back.
]]

local HttpService = game:GetService("HttpService")
local State = require("@src/hub/criminality/state")

local Config = {}

local folder = "criminality\\Configs"

local function ensureFolder()
    if isfolder and not isfolder("criminality") then
        pcall(makefolder, "criminality")
    end

    if isfolder and not isfolder(folder) then
        pcall(makefolder, folder)
    end
end

local function path(name)
    return folder .. "\\" .. name .. ".json"
end

function Config.list()
    ensureFolder()

    local names = {}

    if listfiles then
        local ok, files = pcall(listfiles, folder)

        if ok and files then
            for _, file in next, files do
                local name = tostring(file):match("([^/\\]+)%.json$")

                if name then
                    table.insert(names, name)
                end
            end
        end
    end

    table.sort(names)

    return names
end

function Config.save(name)
    if type(name) ~= "string" or name == "" then
        return false, "empty name"
    end

    ensureFolder()

    local payload = HttpService:JSONEncode(State.snapshot())
    local ok, err = pcall(writefile, path(name), payload)

    return ok, ok and nil or tostring(err)
end

function Config.load(name)
    local ok, data = pcall(readfile, path(name))

    if not ok then
        return false, "missing profile"
    end

    local okDecode, decoded = pcall(function()
        return HttpService:JSONDecode(data)
    end)

    if not okDecode then
        return false, "invalid json"
    end

    local applied = State.apply(decoded)

    return true, applied
end

function Config.delete(name)
    if not name or name == "" then
        return false
    end

    if isfile and not isfile(path(name)) then
        return false
    end

    local ok = pcall(function()
        if delfile then
            delfile(path(name))
        end
    end)

    return ok
end

function Config.autoload()
    local names = Config.list()

    if table.find(names, "default") then
        return Config.load("default")
    end

    return false
end

return Config
