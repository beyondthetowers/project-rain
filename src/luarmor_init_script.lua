--[[
    Frutiger — build-time primitive layer
    src/luarmor_init_script.lua

    In the shipped Luarmor build these symbols are injected by the obfuscator
    before any module runs. The OSS release shipped without them, so the whole
    codebase died on its first use of STR_TBL_SF_INVOKE / Feature / services.

    This restores the contract as plain passthroughs. Behaviour is identical to
    a deobfuscated build: every macro returns its argument unmangled.

    Loaded from src/init.lua line 3. Must run before anything else.
]]

local genv = getgenv();

-- ── legacy folder migration ────────────────────────────────────────────────
-- FRUTIGER was previously "Project Rain". This has to run before src/init.lua
-- creates any folder: its `if not isfolder(x) then makefolder(x) end` checks
-- would otherwise build an empty tree first and the migration would bail
-- thinking the install was already current.
pcall(function()
    require("@src/utility/frutiger/migrate").run();
end);

-- ── Luarmor / Luraph macros ────────────────────────────────────────────────
genv["LPH_OBFUSCATED"]      = false;                    -- take the readable branches
genv["LPH_ENCSTR"]          = function(s) return s end;  -- string decryptor
genv["LPH_JIT"]             = function(f) return f end;
genv["LPH_JIT_MAX"]         = function(f) return f end;
genv["LPH_NO_VIRTUALIZE"]   = function(f) return f end;  -- returns the function, not a call
genv["LRM_INIT_SCRIPT"]     = function(f) return f() end;
genv["PROT_OBF_STR_SAFE_MACRO"] = function(...) return ... end;
genv["AUTH_GET_CONSTANT"]   = function(...) return ... end;

-- String-table invoke. Used 60x across features/hooking + auto-parry.
genv["STR_TBL_SF_INVOKE"]   = function(key) return key end;

-- ── Frutiger globals ───────────────────────────────────────────────────
genv["LRM_ScriptName"]      = "Frutiger";
genv["builder_require"]     = require;
genv["base_require"]        = require;   -- require() on an Instance works in executors
genv["luarmor_preload_time"] = nil;
genv["luarmor_preload_time_debug"] = nil;

-- ── services cache (globals.lua expects this to exist already) ─────────────
if not genv.services then
    local cache = {};
    local get_service = game.GetService;
    genv.services = setmetatable({}, {
        __index = function(_, index)
            return cache[index] or (function()
                cache[index] = get_service(game, index);
                return cache[index];
            end)();
        end;
    });
end;
services = genv.services;

-- ── asset inliner ──────────────────────────────────────────────────────────
-- decode_asset() in init.lua expects base64( zstd_compress( raw_bytes ) ).
-- The Luarmor build inlined the raw bytes; here we read them from the repo's
-- assets folder. Drop `assets/` into the executor workspace, or pre-populate
-- Frutiger/Assets/Source/ with the same tree.
genv["inline_asset_b96"] = function(path)
    -- Bundled build: tools/bundle.js pre-encodes every asset as
    -- base64(zstd(bytes)) and drops it in __BUNDLED_ASSETS. No disk needed.
    local bundled = genv.__BUNDLED_ASSETS;
    if bundled and bundled[path] then
        return bundled[path];
    end;

    local EncodingService = game:GetService("EncodingService");
    local HttpService     = game:GetService("HttpService");

    local relative = path:gsub("^@assets/", "");

    local candidates = {
        "Frutiger/Assets/Source/" .. relative,
        "assets/" .. relative,
        relative,
    };

    local raw;
    for _, candidate in next, candidates do
        local ok, contents = pcall(readfile, candidate);
        if ok and contents then
            raw = contents;
            break;
        end;
    end;

    -- Nothing on disk: return a valid empty payload so the writefile calls in
    -- init.lua succeed instead of erroring out uncaught.
    if not raw then
        warn(string.format("[init] asset not found on disk: %s", relative));
        raw = "";
    end;

    local ok, encoded = pcall(function()
        local compressed = EncodingService:CompressBuffer(
            buffer.fromstring(raw),
            Enum.CompressionAlgorithm.Zstd
        );
        return HttpService:Base64Encode(buffer.tostring(compressed));
    end);

    if not ok then
        warn(string.format("[init] failed to encode asset %s: %s", relative, tostring(encoded)));
        return "";
    end;

    return encoded;
end;

-- globals.lua carries the remaining shims and the proximity-prompt wrapper.
-- It is not required anywhere else in the tree, so pull it in here, after the
-- primitives above exist.
local ok, err = pcall(require, "@src/globals");
if not ok then
    warn("[init] globals.lua failed to load:", err);
end;

return true;
