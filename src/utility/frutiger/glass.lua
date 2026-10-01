--[[
    src/utility/frutiger/glass.lua

    Makes the shell read as glass rather than as a painted panel.

    Four things do that, and they only work together:

    1.  TRANSLUCENCY. An opaque fill is a wall. The window root drops to ~80%
        opacity so the game shows through it. Without this nothing else matters.

    2.  DIFFUSION. Plain transparency looks like a hole, not a pane. The frost
        layer (theme.lua) supplies the faint speckle that reads as frosted glass.
        It is deliberately at single-digit alpha -- the grunge theme ran grain at
        4-5x this strength and it read as dirt rather than diffusion.

    3.  GRADIENT. Real glass is not evenly lit. A vertical UIGradient lightens
        the top and cools the bottom, which is what makes a flat fill look like
        a curved surface catching light.

    4.  EDGE. A glass edge catches the light, so the border is brighter than the
        fill, not darker. A darker outline is the tell that something is painted
        rather than transparent.

    Panels inside get a much smaller transparency than the root. The root is
    behind everything so it can afford to be clear; the panels carry text, and a
    panel that is too clear puts dark text on whatever the player happens to be
    standing in front of.
]]

local glass = {};

-- Dials. The root can be quite clear because nothing sits directly on it; the
-- panels cannot, because text does.
local ROOT_TRANSPARENCY = 0.20;
local PANEL_TRANSPARENCY = 0.12;
local MIN_PANEL_WIDTH = 150;
local MIN_PANEL_HEIGHT = 120;

local theme_module = nil;
pcall(function() theme_module = require("@src/utility/frutiger/theme") end);

local function luminance(color)
    return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B;
end;

local function colors_close(a, b)
    return math.abs(a.R - b.R) < 0.04
       and math.abs(a.G - b.G) < 0.04
       and math.abs(a.B - b.B) < 0.04;
end;

function glass.apply()
    if glass.applied then
        return true;
    end;
    if not Library or not Library.ScreenGui then
        return false;
    end;

    local WHITE = Color3.fromRGB(255, 255, 255);
    local SKY = Color3.fromRGB(198, 230, 248);

    local outer = Library.FrutigerWindow and Library.FrutigerWindow.Holder;
    local chrome = outer and outer:FindFirstChild("FRUTIGER_CHROME");

    -- ── the window pane ────────────────────────────────────────────────────
    if chrome then
        pcall(function()
            chrome.BackgroundTransparency = ROOT_TRANSPARENCY;
        end);

        -- vertical light: bright at the top, cooler toward the bottom
        pcall(function()
            local gradient = chrome:FindFirstChildOfClass("UIGradient");
            if not gradient then
                gradient = Instance.new("UIGradient");
                gradient.Name = "glass_gradient";
                gradient.Parent = chrome;
            end;
            gradient.Rotation = 90;
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.45, Color3.fromRGB(243, 251, 255)),
                ColorSequenceKeypoint.new(1.00, SKY),
            });
        end);

        -- catch the light on the edge rather than darkening it
        pcall(function()
            local stroke = chrome:FindFirstChildOfClass("UIStroke");
            if stroke then
                stroke.Color = WHITE;
                stroke.Thickness = 1.5;
                stroke.Transparency = 0.10;
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
            end;
        end);

        glass.chrome = chrome;
    end;

    -- ── inner panels ───────────────────────────────────────────────────────
    -- Only large, flat, palette-coloured fills, and only ones that are currently
    -- fully opaque. Small elements (toggle knobs, slider thumbs, dividers) are
    -- left alone: they need to stay solid to read, and translucency there just
    -- muddies them.
    local softened = 0;
    local main = Library.MainColor;
    local background = Library.BackgroundColor;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        local ok = pcall(function()
            if not descendant:IsA("Frame") then
                return;
            end;
            if descendant.BackgroundTransparency ~= 0 then
                return;
            end;

            local size = descendant.AbsoluteSize;
            if size.X < MIN_PANEL_WIDTH or size.Y < MIN_PANEL_HEIGHT then
                return;
            end;

            local fill = descendant.BackgroundColor3;
            if not (colors_close(fill, main) or colors_close(fill, background)) then
                return;
            end;

            -- Do not soften the shell itself; it already has its own value, and
            -- softening an opaque ancestor of everything would compound.
            if descendant.Name == "FRUTIGER_CHROME" then
                return;
            end;

            descendant.BackgroundTransparency = PANEL_TRANSPARENCY;

            -- give panels the same vertical light as the window, at a gentler
            -- strength, so they read as the same material
            if not descendant:FindFirstChildOfClass("UIGradient") then
                local gradient = Instance.new("UIGradient");
                gradient.Name = "glass_gradient";
                gradient.Rotation = 90;
                gradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(232, 246, 254)),
                });
                gradient.Parent = descendant;
            end;

            softened = softened + 1;
        end);
    end;

    glass.applied = true;
    glass.softened = softened;
    glass.transparency = { root = ROOT_TRANSPARENCY, panel = PANEL_TRANSPARENCY };

    return true;
end;

return glass;
