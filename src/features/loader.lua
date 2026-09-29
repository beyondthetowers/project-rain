--[[
    src/features/loader.lua

    The OSS release shipped this file as `-- Omitted. Do this yourself. <3`.

    It carries two things the rest of the tree cannot run without:

      1. the global `Feature` — used 123 times, e.g.
             return Feature:new("no_shadows", scheduler:add_task(2.5), fn)
         every feature module in src/features calls it at load time.

      2. aztup.features — the id -> Feature table that
         src/utility/ui/wrapper.lua reads when a toggle flips:
             local feature = aztup.features[ID]
         with it empty, every one of the 109 UI toggles is inert.

    This stub restores (1) so the tree loads and the anti-cheat layer in
    src/features/hooking.lua can be exercised. (2) is deliberately left empty —
    populating it is the real reconstruction job, and it needs the id list out
    of src/ui/tabs/* (note the aliases: UI says "tickrate", the file is
    src/features/movement/tick_rate.lua).
]]

Feature = require("@src/features/generic_feature");

local loader = {};

-- Glob -> module lists. The bundle provides these; on a file-system loader
-- (list_modules from the executor) this is a no-op fallback.
local FEATURE_GLOBS = {
    "features/*/*",
};

function loader.initialize()
    -- Intentionally empty. See the note above: registering feature modules
    -- requires the id -> module map, which is the piece the release stripped.
    -- Loading them here without it would only raise on the modules that touch
    -- aztup_options before the UI exists.
end;

function loader.get(id)
    return aztup.features[id];
end;

return loader;
