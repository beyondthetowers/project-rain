--[[
    src/utility/frutiger/dress.lua

    Applies the material kit across the existing tree. Nothing is rebuilt and no
    logic is touched -- this only reads geometry and sets appearance.

    It is deliberately conservative. An earlier attempt at classifying "buttons"
    by shape matched 589 elements, because almost every row in this UI is a
    small frame with a fill and a label: toggle rows, slider rows, dropdown
    rows, section headers. Styling all of them as buttons would have made the
    interface look like a wall of pills.

    So it only touches things it can identify without ambiguity:

      dividers   hairline frames. The brief asks for fewer strong lines and this
                 is where most of them are -- there are 341 of them in the live
                 tree, drawn in the theme's edge colour at full opacity.
      cards      large fills, 155 of them. These become layered glass: softer
                 border, vertical light, corner, and a soft shadow underneath.
      spacing    list padding, so rows stop touching.

    Buttons, toggles, sliders and dropdowns are NOT in this pass. They need to
    be matched by their actual structure rather than by size, and getting that
    wrong is how you end up with everything styled the same.
]]

local dress = {};

local theme_module = nil;
pcall(function() theme_module = require("@src/utility/frutiger/theme") end);

local kit = nil;
pcall(function() kit = require("@src/utility/frutiger/material") end);

local visible = nil;
pcall(function() visible = require("@src/utility/frutiger/visible") end);

if not visible then
    visible = { menu = function() return true end, on_open = function() end };
end;

local COLORS = (kit and kit.colors) or {};

local DIVIDER_MAX_HEIGHT = 3;
local DIVIDER_TRANSPARENCY = 0.72;

local CARD_MIN_WIDTH = 200;
local CARD_MIN_HEIGHT = 80;

local is_panel = function(object)
    return object:GetAttribute("glass_panel") == true;
end;

-- The chrome and the overlay are authored in their own modules and already have
-- their look; dressing them here would fight those modules.
--
-- The check stops at the chrome's DIRECT children, not anywhere beneath it. The
-- library's whole widget tree was transplanted into FRUTIGER_CHROME by
-- chrome.lua, so excluding anything under the chrome excluded the entire
-- interface -- which is what happened: only 36 of 341 dividers were softened
-- and the rest were silently skipped as "owned".
local function owned_elsewhere(object)
    local node = object;
    local depth = 0;

    while node do
        local name = node.Name;

        if name == "FRUTIGER_OVERLAY"
            or name == "glass_shadow"
            or name == "glass_specular" then
            return true;
        end;

        if name == "FRUTIGER_CHROME" then
            -- depth 0 is the shell itself; depth 1 is its own furniture (title,
            -- sidebar, rules). Deeper than that is transplanted content, which
            -- must be dressed.
            return depth <= 1;
        end;

        depth = depth + 1;
        node = node.Parent;
    end;

    return false;
end;

-- ── dividers ───────────────────────────────────────────────────────────────
-- The brief: reduce the amount of strong divider lines. There are 341 of these
-- and they are drawn at full opacity in the edge colour, which is most of why
-- the interface reads as busy. Softened rather than deleted -- they still do
-- the job of separating rows, they just stop competing with the content.
function dress.dividers()
    local softened = 0;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        if descendant:IsA("Frame") then
            local size = descendant.AbsoluteSize;

            if size.X >= 60 and size.Y > 0 and size.Y <= DIVIDER_MAX_HEIGHT
                and descendant.BackgroundTransparency < 0.9
                and not owned_elsewhere(descendant) then

                pcall(function()
                    descendant.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
                    descendant.BackgroundTransparency = DIVIDER_TRANSPARENCY;
                end);
                softened = softened + 1;
            end;
        end;
    end;

    return softened;
end;

-- ── cards ──────────────────────────────────────────────────────────────────
function dress.cards()
    local dressed = 0;
    if not kit then
        return 0;
    end;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        if descendant:IsA("Frame")
            and not is_panel(descendant)
            and not owned_elsewhere(descendant) then

            local size = descendant.AbsoluteSize;

            if size.X >= CARD_MIN_WIDTH and size.Y >= CARD_MIN_HEIGHT
                and descendant.BackgroundTransparency > 0
                and descendant.BackgroundTransparency < 0.6 then

                local ok = pcall(function()
                    kit.panel(descendant, {
                        radius = 12,
                        stroke_transparency = 0.62,
                        depth = 3,
                        top_transparency = 0.60,
                        mid_transparency = 0.94,
                        bottom_transparency = 0.86,
                    });
                end);
                if ok then
                    dressed = dressed + 1;
                end;
            end;
        end;
    end;

    return dressed;
end;

-- ── spacing ────────────────────────────────────────────────────────────────
-- OFF, and deliberately left off.
--
-- The brief asks for more vertical breathing room and the obvious lever is
-- UIListLayout padding. The library does not size containers from the layout,
-- though -- it computes each section's height from its own row metrics. So
-- widening the padding makes rows overflow a container whose height was already
-- decided, and the overflow lands on whatever comes next.
--
-- Measured: padding at 6px produced 52946 overlapping text pairs across 1938
-- labels. Setting every layout's padding back to 0 in the same session dropped
-- it to 0. That is not a subtle regression, it is the entire interface drawn on
-- top of itself.
--
-- Real spacing means moving the container heights with it, which is a change to
-- how the library lays sections out rather than restyling after the fact. Not
-- worth the risk just for padding, so it stays at the library's own value.
local MIN_ROW_PADDING = 0;

function dress.spacing()
    local loosened = 0;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        local layout = descendant:IsA("UIListLayout") and descendant or nil;
        if layout and not owned_elsewhere(layout.Parent) then
            local ok = pcall(function()
                local current = layout.Padding
                if current.Offset < MIN_ROW_PADDING then
                    layout.Padding = UDim.new(0, MIN_ROW_PADDING)
                    loosened = loosened + 1
                end
            end)
        end
    end

    return loosened
end;

-- ── contrast follow-up ─────────────────────────────────────────────────────
-- Dressing changes fills, so anything the contrast guard fixed earlier can end
-- up light-on-light again. Cheap to re-run; it only touches text that is still
-- unreadable.
function dress.recheck()
    if theme_module and theme_module.fix_contrast then
        pcall(theme_module.fix_contrast);
    end;
end;

function dress.apply()
    if dress.applied then
        return true;
    end;
    if not Library or not Library.ScreenGui then
        return false;
    end;

    dress.softened_dividers = dress.dividers();
    dress.dressed_cards = dress.cards();
    dress.loosened_layouts = dress.spacing();
    dress.recheck();

    dress.applied = true;

    -- Lazy content (tab pages, dropdown options, dependency boxes) is built on
    -- first visit, so keep re-dressing for a while as it appears.
    -- Gated on visibility for the same reason as the theme guard: four
    -- full-tree walks every 2 seconds is real cost, and all of it is invisible
    -- while the menu is shut.
    task.spawn(function()
        for _ = 1, 20 do
            task.wait(2);
            if visible.menu() then
                pcall(dress.dividers);
                pcall(dress.cards);
                pcall(dress.spacing);
                pcall(dress.recheck);
            end;
        end;
    end);

    -- Lazy content is built on first visit, so re-dress on each open rather
    -- than hoping a timer happened to catch it.
    visible.on_open(function()
        pcall(dress.dividers);
        pcall(dress.cards);
        pcall(dress.recheck);
    end);

    return true;
end;

return dress;
