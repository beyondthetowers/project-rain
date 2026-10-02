--[[
    Frutiger — loader
    dist/loader.lua

    Paste this into your executor, or host it and run the one-liner at the
    bottom of this file. It pulls the bundle and executes it.

    SOURCE points at the built bundle:

      - raw.githubusercontent.com/beyondthetowers/project-rain/main/dist/frutiger.lua
      - a gist raw URL
      - any static host that returns text/plain

    Note: a plain GitHub blob URL will not work -- it returns HTML. Use raw.
]]

local SOURCE = "https://raw.githubusercontent.com/beyondthetowers/project-rain/main/dist/frutiger.lua";

local function fetch(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true);
    end);
    if not ok or type(body) ~= "string" or #body == 0 then
        return nil, tostring(body);
    end;
    -- GitHub returns a 404 page rather than failing, so check for that.
    if body:sub(1, 1) == "<" then
        return nil, "got HTML back -- that is a blob URL, not a raw one";
    end;
    return body;
end

local body, err = fetch(SOURCE);
if not body then
    return warn("[frutiger] could not fetch bundle: " .. tostring(err));
end;

print(string.format("[frutiger] bundle: %.2f MB", #body / 1024 / 1024));

local chunk, compile_err = loadstring(body, "=frutiger");
if not chunk then
    return warn("[frutiger] compile failed: " .. tostring(compile_err));
end;

local ok, run_err = xpcall(chunk, function(e)
    return tostring(e) .. "\n" .. debug.traceback();
end);

if not ok then
    return warn("[frutiger] runtime failed: " .. tostring(run_err));
end;

print("[frutiger] loaded");

--[[
    one-liner form:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/beyondthetowers/project-rain/main/dist/loader.lua"))()

    or skip the loader and go straight at the bundle:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/beyondthetowers/project-rain/main/dist/frutiger.lua"))()
]]
