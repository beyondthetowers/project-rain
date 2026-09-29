--[[
    Project Rain — loader
    dist/loader.lua

    Paste this into your executor, or host it and run the one-liner at the
    bottom of this file. It pulls the bundle and executes it.

    Set SOURCE to wherever dist/project-rain.lua ends up:

      - raw.githubusercontent.com/<you>/<repo>/main/dist/project-rain.lua
      - a gist raw URL
      - any static host that returns text/plain

    Note: a plain GitHub blob URL will not work — it returns HTML. Use raw.
]]

local SOURCE = "https://raw.githubusercontent.com/CHANGE_ME/CHANGE_ME/main/dist/project-rain.lua";

local function fetch(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true);
    end);
    if not ok or type(body) ~= "string" or #body == 0 then
        return nil, tostring(body);
    end;
    -- GitHub returns a 404 page rather than failing, so check for that.
    if body:sub(1, 1) == "<" then
        return nil, "got HTML back — that is a blob URL, not a raw one";
    end;
    return body;
end;

local body, err = fetch(SOURCE);
if not body then
    return warn("[pr] could not fetch bundle: " .. tostring(err));
end;

print(string.format("[pr] bundle: %.2f MB", #body / 1024 / 1024));

local chunk, compile_err = loadstring(body, "=project-rain");
if not chunk then
    return warn("[pr] compile failed: " .. tostring(compile_err));
end;

local ok, run_err = xpcall(chunk, function(e)
    return tostring(e) .. "\n" .. debug.traceback();
end);

if not ok then
    return warn("[pr] runtime failed: " .. tostring(run_err));
end;

print("[pr] loaded");

--[[
    one-liner form:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/CHANGE_ME/CHANGE_ME/main/dist/loader.lua"))()

    or skip the loader and go straight at the bundle:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/CHANGE_ME/CHANGE_ME/main/dist/project-rain.lua"))()
]]
