--[[
    src/utility/frutiger/visible.lua

    Whether the menu is actually open.

    Every expensive thing the theme does -- recolouring the tree, checking
    contrast, dressing dividers and cards, attaching hover handlers, rounding
    corners -- exists purely to style a window that is, most of the time, not on
    screen. Running any of it while the menu is closed costs framerate and buys
    nothing, because nobody can see the result.

    That was the reported problem: framerate tanking during play, with the menu
    shut. The theme had a DescendantAdded hook that reran a full-tree recolour
    and contrast pass whenever anything was added, debounced by 0.2s. In a live
    game instances are added constantly, so it was firing several times a second
    across ~2000 elements, forever, while hidden.

    The gate is also how the work gets scheduled properly: instead of guessing
    when to re-run, run once whenever the window becomes visible.
]]

local visible = {};

local function holder()
    local library = Library or (getgenv and getgenv().Library);
    if not library then
        return nil;
    end;

    local window = library.FrutigerWindow or library.DecayWindow or library.Window;
    return window and window.Holder or nil;
end;

function visible.menu()
    local object = holder();
    if not object then
        return false;
    end;

    local ok, value = pcall(function() return object.Visible end);
    return ok and value == true;
end;

-- Calls `callback` each time the menu transitions to visible. Returns the
-- connection, or nil if there is nothing to watch yet.
function visible.on_open(callback)
    local object = holder();
    if not object then
        return nil;
    end;

    local ok, connection = pcall(function()
        return object:GetPropertyChangedSignal("Visible"):Connect(function()
            if object.Visible then
                pcall(callback);
            end;
        end);
    end);

    return ok and connection or nil;
end;

return visible;
