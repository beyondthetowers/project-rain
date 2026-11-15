--[[
    src/hub/criminality/bypass.lua

    Adonis anti-cheat bypass. Scans the GC for the Detected / Kill closures,
    replaces them, and hides the hooked Detected function from the anti-cheat's
    own debug.info integrity check.

    Runs before the hub touches anything else. Silent by default; set
    getgenv().criminality_bypass_verbose = true to see what it catches.
]]

local Bypass = {
    installed = false,
    verbose = false,
    detected = nil,
    kill = nil,
    originals = {},
}

local function say(message)
    if Bypass.verbose or getgenv().criminality_bypass_verbose then
        warn("[bypass] " .. message)
    end
end

local function scan()
    if not getgc then
        return
    end

    for _, value in next, getgc(true) do
        if typeof(value) == "table" then
            local detected = rawget(value, "Detected")
            local kill = rawget(value, "Kill")

            if not Bypass.detected and typeof(detected) == "function" then
                Bypass.detected = detected
            end

            if not Bypass.kill
                and rawget(value, "Variables")
                and rawget(value, "Process")
                and typeof(kill) == "function"
            then
                Bypass.kill = kill
            end

            if Bypass.detected and Bypass.kill then
                return
            end
        end
    end
end

local function hookDetected()
    if not Bypass.detected or not hookfunction then
        return false
    end

    local original = Bypass.detected

    Bypass.originals.detected = hookfunction(original, function(method, info)
        if method ~= "_" then
            say("flagged  method=" .. tostring(method) .. "  info=" .. tostring(info))
        end

        return true
    end)

    return true
end

local function hookKill()
    if not Bypass.kill or not hookfunction then
        return false
    end

    Bypass.originals.kill = hookfunction(Bypass.kill, function(reason)
        say("blocked kill  reason=" .. tostring(reason))
    end)

    return true
end

local function hideFromIntegrityCheck()
    if not Bypass.detected or not hookfunction or not getrenv or not getrenv().debug then
        return false
    end

    local debugInfo = getrenv().debug.info

    if type(debugInfo) ~= "function" then
        return false
    end

    local original
    original = hookfunction(debugInfo, newcclosure(function(...)
        local target = ...

        if Bypass.detected and target == Bypass.detected then
            say("integrity check deflected")
            return coroutine.yield(coroutine.running())
        end

        return original(...)
    end))

    Bypass.originals.debug_info = original

    return true
end

function Bypass.install()
    if Bypass.installed then
        return Bypass
    end

    -- The standalone autoexec copy may already have installed it.
    if type(getgenv().criminality_bypass) == "table" then
        Bypass.installed = true
        Bypass.originals = getgenv().criminality_bypass
        return Bypass
    end

    if not getgc or not hookfunction then
        say("executor missing getgc/hookfunction, bypass not installed")
        return Bypass
    end

    Bypass.installed = true

    if setthreadidentity then
        pcall(setthreadidentity, 2)
    end

    local ok, err = pcall(function()
        scan()
        hookDetected()
        hookKill()
        hideFromIntegrityCheck()
    end)

    if not ok then
        say("install failed: " .. tostring(err))
    end

    if setthreadidentity then
        pcall(setthreadidentity, 7)
    end

    getgenv().criminality_bypass = {
        detected = Bypass.originals.detected,
        kill = Bypass.originals.kill,
        debug_info = Bypass.originals.debug_info,
    }

    say("installed  detected=" .. tostring(Bypass.detected ~= nil) .. "  kill=" .. tostring(Bypass.kill ~= nil))

    return Bypass
end

function Bypass.uninstall()
    return Bypass
end

return Bypass
