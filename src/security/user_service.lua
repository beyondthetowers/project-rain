--[[
    src/security/user_service.lua

    Stripped from the OSS release — the whole src/security/ directory was
    removed, which is also why src/utility/security.lua shipped as 0 bytes.

    Required at init.lua:219 with no pcall around it, so it must return a table.
    The original handled identity / entitlement checks. Anything it exposes
    answers false here, which fails closed for gating and fails open for
    feature use.
]]

local user_service = {};

setmetatable(user_service, {
    __index = function(_, key)
        return function()
            return false;
        end;
    end;
});

function user_service:get()
    return nil;
end;

function user_service:is_valid()
    return false;
end;

return user_service;
