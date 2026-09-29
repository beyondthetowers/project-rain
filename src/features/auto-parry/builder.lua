--[[
    src/features/auto-parry/builder.lua  — STUB

    Stripped from the OSS release. Required by src/ui/tabs/combat.lua:654
    (`local timing_builder = require("@src/features/auto-parry/builder")`),
    where it built the custom parry-timing editor.

    Every method returns nothing so the tab can render without raising. Wire
    real behaviour here when the parry timing editor is rebuilt.
]]

local builder = {};

builder.new = function()
    return setmetatable({}, { __index = builder });
end;

setmetatable(builder, {
    __index = function()
        return function() return builder end;
    end;
});

return builder;
