--[[
    src/features/auto-parry/data/custom_timings.lua

    Stripped from the OSS release. Required by
    src/features/auto-parry/handlers/animator-handler.lua:20, which calls two
    methods on it:

        custom_timings:lookup(id)  -> custom, custom_name   (nil = no override)
        custom_timings:sync()      -> iterator of names, consumed by
                                      `for name in custom_timings:sync() do`

    A bare `return {}` satisfies neither. `lookup` raised
    "attempt to call missing method 'lookup' of table" on every animator tick
    — thousands of warnings a second — and `sync` returning nothing makes the
    generic-for try to call nil.

    Both are stubbed to report "no override", which is the state the handler
    already falls back to.
]]

local custom_timings = {};
custom_timings.__index = custom_timings;

function custom_timings:lookup(id)
    return nil, nil;
end;

function custom_timings:sync()
    return function()
        return nil;
    end;
end;

-- Named override file count. Animator-handler polls nothing here, but the UI
-- timing editor guards on it.
function custom_timings:count()
    return 0;
end;

return setmetatable({}, custom_timings);
