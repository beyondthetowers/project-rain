--[[
    src/utility/console/theme.lua

    The DECAY look. Palette, fonts, and a procedural overlay that sits inside
    the menu window.

    Scoping decisions:

    1.  The overlay is parented INTO Library.ConsoleWindow, not screenspaced over
        the game. It moves when you drag the window, resizes with it, and is
        clipped to it — the game world stays clean. An earlier version was a
        full-screen ScreenGui in gethui(); that was wrong.

    2.  Layer ZIndex is derived at build time from the window's own highest
        descendant ZIndex rather than hardcoded. The library uses 9999 for
        window content and 999999 for drag/tooltip layers, so a fixed value
        either gets buried or paints over tooltips. Deriving it means the grain
        sits above content and below tooltips automatically.

    3.  Nothing here is required to succeed. Every step is pcall'd and every
        lookup degrades to nil. A missing texture costs grain, not the client.

    Textures come from tools/gen-textures.js, are inlined into the bundle by
    tools/bundle.js as base64(zstd(bytes)), written out on first run and loaded
    with getcustomasset — the same path the fonts and sounds already use.
]]

local theme = {};

-- ── palette ────────────────────────────────────────────────────────────────
-- Near-absolute black, carbon grey, desaturated mould green, dirty beige,
-- rust. No saturated or clean values anywhere.

theme.palette = {
    FontColor       = "ffffff",   -- white text
    MainColor       = "000000",   -- black panels
    AccentColor     = "ffffff",   -- drives hover: ui.lua sets the hover fill
                                  -- straight from AccentColor, and the selected
                                  -- tab underline the same way
    BackgroundColor = "000000",   -- black background
    OutlineColor    = "ffffff",   -- drives BorderColor3, i.e. the corners
};

theme.extra = {
    white = Color3.fromRGB(255, 255, 255),
    grey  = Color3.fromRGB(150, 150, 150),
    black = Color3.fromRGB(0, 0, 0),
    ash   = Color3.fromRGB(38, 38, 38),
};

-- Condensed industrial for headings, technical mono for everything else.
theme.fonts = {
    heading = Enum.Font.Oswald,
    body    = Enum.Font.RobotoMono,
};

-- ── textures ───────────────────────────────────────────────────────────────
local TEXTURE_DIR = "Console/Textures";
local TEXTURE_NAMES = { "grain", "scanline", "scratch", "vignette", "stain" };

theme.textures = {};

local function ensure_folder(dir)
    if isfolder(dir) then
        return true;
    end;
    return (pcall(makefolder, dir));
end;

local function ensure_texture(name)
    local path = TEXTURE_DIR .. "/" .. name .. ".png";

    if not isfile(path) then
        if not ensure_folder(TEXTURE_DIR) then
            return nil;
        end;

        -- inline_asset_b96 and decode_asset are globals published by
        -- src/luarmor_init_script.lua and src/init.lua respectively.
        local ok, contents = pcall(function()
            return decode_asset(inline_asset_b96("@assets/Textures/" .. name .. ".png"));
        end);

        if not ok or type(contents) ~= "string" or #contents == 0 then
            return nil;
        end;

        if not pcall(writefile, path, contents) then
            return nil;
        end;
    end;

    local ok, asset = pcall(getcustomasset, path);
    return ok and asset or nil;
end;

function theme.load_textures()
    for _, name in next, TEXTURE_NAMES do
        theme.textures[name] = ensure_texture(name);
    end;
    return theme.textures;
end;

-- ── overlay ────────────────────────────────────────────────────────────────

-- Library.ConsoleWindow is the linoria Window OBJECT, not the frame — it carries
-- .Tabs, .TabOrder and a .Holder field. The actual GUI is Window.Holder
-- (ui.lua:2388 `Window.Holder = Outer`). Handing the object straight to
-- :GetDescendants() throws, and build_overlay then swallowed that, so resolve
-- it here and never let a table through.
local function as_instance(candidate)
    if typeof(candidate) == "Instance" then
        return candidate;
    end;
    if type(candidate) == "table" then
        for _, key in ipairs({ "Holder", "Frame", "Container", "Root" }) do
            local value = rawget(candidate, key);
            if typeof(value) == "Instance" then
                return value;
            end;
        end;
    end;
    return nil;
end;

-- The frame everything hangs off. Returns nil if nothing resolves, so the
-- caller can skip cleanly instead of erroring.
local function find_window()
    if not Library then
        return nil;
    end;

    for _, candidate in ipairs({ Library.ConsoleWindow, Library.Window, Library.ScreenGui }) do
        local instance = as_instance(candidate);
        if instance then
            return instance;
        end;
    end;

    return nil;
end;

-- Highest ZIndex anywhere under the window. The overlay has to clear the
-- window's own content without hardcoding a number that goes stale.
local function max_zindex(root)
    local highest = 0;
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("GuiObject") and descendant.ZIndex > highest then
            highest = descendant.ZIndex;
        end;
    end;
    return highest;
end;

-- A previous build (or a previous injection) may have left a screenspaced
-- overlay behind. Clear it before building the scoped one.
function theme.destroy_previous()
    for _, container in ipairs({
        (type(gethui) == "function" and pcall(gethui) and gethui()) or nil,
        game:GetService("CoreGui"),
    }) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child.Name == "CONSOLE_OVERLAY" then
                    pcall(function() child:Destroy() end);
                end;
            end;
        end;
    end;
end;

local function layer(parent, name, image, props)
    if not image then
        return nil;
    end;

    local frame = Instance.new("ImageLabel");
    frame.Name = name;
    frame.BackgroundTransparency = 1;
    frame.BorderSizePixel = 0;
    frame.Image = image;
    frame.Size = UDim2.fromScale(1, 1);
    frame.Position = UDim2.fromScale(0, 0);

    for key, value in next, props do
        frame[key] = value;
    end;

    frame.Parent = parent;
    return frame;
end;

function theme.build_overlay()
    if theme.overlay and theme.overlay.Parent then
        return theme.overlay;
    end;

    local window = find_window();
    if not window then
        return nil;
    end;

    pcall(theme.destroy_previous);

    local base = math.min(max_zindex(window) + 1, 999990);

    -- The holder is what clips: the grain tiles and the vignette get cut to the
    -- window's rectangle, so nothing bleeds over the game or over other windows.
    local holder = Instance.new("Frame");
    holder.Name = "CONSOLE_OVERLAY";
    holder.BackgroundTransparency = 1;
    holder.BorderSizePixel = 0;
    holder.Size = UDim2.fromScale(1, 1);
    holder.Position = UDim2.fromScale(0, 0);
    holder.ClipsDescendants = true;
    holder.Active = false;
    holder.ZIndex = base;

    local ok = pcall(function()
        holder.Parent = window;
    end);
    if not ok then
        holder:Destroy();
        return nil;
    end;

    theme.overlay = holder;
    theme.window = window;
    theme.base_zindex = base;

    theme.vignette = layer(holder, "vignette", theme.textures.vignette, {
        ZIndex = base + 1,
        ImageTransparency = 0.28,
        ScaleType = Enum.ScaleType.Stretch,
    });

    theme.stains = {};
    if theme.textures.stain then
        local rnd = Random.new(0xDECA7);
        for i = 1, 3 do
            theme.stains[i] = layer(holder, "stain" .. i, theme.textures.stain, {
                ZIndex = base + 2,
                ImageTransparency = 0.70,
                Size = UDim2.fromScale(0.26, 0.34),
                Position = UDim2.fromScale(rnd:NextNumber(0.1, 0.7), rnd:NextNumber(0.1, 0.6)),
            });
        end;
    end;

    theme.grain = layer(holder, "grain", theme.textures.grain, {
        ZIndex = base + 3,
        ImageTransparency = 0.87,
        TileSize = UDim2.fromOffset(128, 128),
        ResampleMode = Enum.ResamplerMode.Pixelated,
    });

    theme.scratch = layer(holder, "scratch", theme.textures.scratch, {
        ZIndex = base + 4,
        ImageTransparency = 0.78,
        TileSize = UDim2.fromOffset(256, 256),
    });

    theme.scanline = layer(holder, "scanline", theme.textures.scanline, {
        ZIndex = base + 5,
        ImageTransparency = 0.55,
        TileSize = UDim2.fromOffset(4, 4),
        ResampleMode = Enum.ResamplerMode.Pixelated,
    });

    local sweep = Instance.new("Frame");
    sweep.Name = "sweep";
    sweep.BackgroundColor3 = theme.extra.white;
    sweep.BorderSizePixel = 0;
    sweep.Size = UDim2.new(1, 0, 0, 2);
    sweep.Position = UDim2.new(0, 0, -0.05, 0);
    sweep.BackgroundTransparency = 0.82;
    sweep.ZIndex = base + 6;
    sweep.Active = false;
    sweep.Parent = holder;
    theme.sweep = sweep;

    return holder;
end;

-- ── motion ─────────────────────────────────────────────────────────────────
-- Slow and wrong rather than smooth and pleasant. Grain drifts a couple of
-- pixels, the pane occasionally jolts sideways for one frame, opacity never
-- quite settles.

function theme.start_motion()
    if theme.motion_started then
        return;
    end;
    theme.motion_started = true;

    local RunService = game:GetService("RunService");
    local rnd = Random.new();

    -- grain + scratch drift, ~12fps so it reads as film rather than noise
    task.spawn(function()
        while theme.overlay and theme.overlay.Parent do
            local dx = rnd:NextInteger(-2, 2);
            local dy = rnd:NextInteger(-2, 2);

            if theme.grain then
                theme.grain.Position = UDim2.fromOffset(dx, dy);
                theme.grain.ImageTransparency = 0.87 + rnd:NextNumber(-0.03, 0.03);
            end;
            if theme.scratch then
                theme.scratch.Position = UDim2.fromOffset(-dx, -dy * 2);
            end;

            -- 1-2 frame jolt
            if rnd:NextNumber() > 0.93 then
                local shift = rnd:NextInteger(-3, 3);
                for _, child in ipairs(theme.overlay:GetChildren()) do
                    if child:IsA("ImageLabel") and child.Name ~= "vignette" then
                        child.Position = UDim2.fromOffset(shift, 0);
                    end;
                end;
                task.wait(0.033);
            end;

            task.wait(0.08);
        end;
    end);

    -- the sweep crosses the window in 7s, then waits 5-18s
    task.spawn(function()
        while theme.overlay and theme.overlay.Parent do
            local height = theme.overlay.AbsoluteSize.Y;
            if theme.sweep and height > 0 then
                theme.sweep.Position = UDim2.fromOffset(0, -4);
                local start = tick();
                while tick() - start < 7 and theme.overlay.Parent do
                    local t = (tick() - start) / 7;
                    theme.sweep.Position = UDim2.fromOffset(0, t * height);
                    theme.sweep.BackgroundTransparency = 0.72 + math.abs(t - 0.5) * 0.3;
                    RunService.RenderStepped:Wait();
                end;
            end;
            task.wait(rnd:NextNumber(5, 18));
        end;
    end);
end;

-- ── library integration ────────────────────────────────────────────────────
function theme.apply_colors()
    if not Library then
        return false;
    end;

    for key, hex in next, theme.palette do
        local ok = pcall(function()
            Library[key] = Color3.fromHex(hex);
        end);
        if not ok then
            return false;
        end;
    end;

    pcall(function()
        Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);
    end);

    return true;
end;

-- ── recolour pass ──────────────────────────────────────────────────────────
-- Setting Library.MainColor and calling ApplyTheme is not enough. The library
-- only repaints elements it registered via AddToRegistry; the window chrome
-- (the outer Frame, the inner container, the hairline separator, UIStrokes)
-- bakes its colours at creation and is never revisited. Measured after a
-- palette change: Library.MainColor was #434343 while Inner still rendered
-- #1b2b34, the old PR blue.
--
-- So capture the palette that was live when the UI was built, then walk the
-- tree and swap any colour that still matches one of those values.

local function colors_close(a, b)
    return math.abs(a.R - b.R) < 0.02
       and math.abs(a.G - b.G) < 0.02
       and math.abs(a.B - b.B) < 0.02;
end;

function theme.recolor(previous)
    if not Library or not Library.ScreenGui or type(previous) ~= "table" then
        return 0;
    end;

    local mapping = {};
    for key, old in next, previous do
        local hex = theme.palette[key];
        if hex and typeof(old) == "Color3" then
            mapping[#mapping + 1] = { old = old, new = Color3.fromHex(hex) };
        end;
    end;
    if #mapping == 0 then
        return 0;
    end;

    local function remap(object, property)
        local ok, current = pcall(function() return object[property] end);
        if not ok or typeof(current) ~= "Color3" then
            return false;
        end;

        for _, pair in ipairs(mapping) do
            if colors_close(current, pair.old) then
                pcall(function() object[property] = pair.new end);
                return true;
            end;
        end;
        return false;
    end;

    local changed = 0;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        if descendant:IsA("GuiObject") then
            for _, property in ipairs({
                "BackgroundColor3", "TextColor3", "ImageColor3",
                "PlaceholderColor3", "BorderColor3",
            }) do
                if remap(descendant, property) then
                    changed = changed + 1;
                end;
            end;
        end;

        if descendant:IsA("UIStroke") then
            if remap(descendant, "Color") then
                changed = changed + 1;
            end;
        end;
    end;

    return changed;
end;

-- ── contrast guard ─────────────────────────────────────────────────────────
-- With a white accent, the library's derived shades (AccentColorDark and its
-- relatives) come out light grey. Anything that ends up light-filled with white
-- text on top is unreadable.
--
-- Measured on the "enable Ping Compensation" notification: a stable #a3a2a5
-- fill at full opacity behind #ffffff text. Rather than work out which derived
-- field each element reads, darken the fill wherever that pairing occurs.
--
-- Safe against the hover inversion: that produces white-on-black or
-- black-on-white, neither of which is a light fill with light text.

local function luminance(color)
    return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B;
end;

function theme.fix_contrast()
    if not Library or not Library.ScreenGui then
        return 0;
    end;

    local fixed = 0;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        if descendant:IsA("GuiObject")
            and descendant.BackgroundTransparency < 0.5
            and luminance(descendant.BackgroundColor3) > 0.5 then

            local light_text = false;
            for _, child in ipairs(descendant:GetDescendants()) do
                if (child:IsA("TextLabel") or child:IsA("TextBox"))
                    and luminance(child.TextColor3) > 0.7 then
                    light_text = true;
                    break;
                end;
            end;

            if light_text then
                pcall(function() descendant.BackgroundColor3 = theme.extra.black end);
                fixed = fixed + 1;
            end;
        end;
    end;

    return fixed;
end;

-- Makes CONSOLE selectable in the theme dropdown, not just forced on.
function theme.register()
    local ok, ThemeManager = pcall(require, "@src/utility/librarys/managers/ThemeManager");
    if not ok or type(ThemeManager) ~= "table" or type(ThemeManager.BuiltInThemes) ~= "table" then
        return false;
    end;

    local HttpService = game:GetService("HttpService");
    ThemeManager.BuiltInThemes["CONSOLE"] = { 22, HttpService:JSONDecode(HttpService:JSONEncode(theme.palette)) };
    return true;
end;

function theme.apply()
    if theme.applied then
        return true;
    end;

    pcall(theme.load_textures);
    pcall(theme.register);

    -- Capture the palette that was live when the UI was built, before
    -- apply_colors overwrites it. This is the "from" set for the recolour pass.
    local previous = {};
    if Library then
        for key in next, theme.palette do
            pcall(function() previous[key] = Library[key] end);
        end;
    end;

    local colors = pcall(theme.apply_colors);

    -- repaint the live UI if the manager is reachable
    pcall(function()
        local ThemeManager = require("@src/utility/librarys/managers/ThemeManager");
        ThemeManager:ApplyTheme(theme.palette);
        if aztup and aztup.tabs then
            for _, tab in next, aztup.tabs do
                if tab and tab.Tab then
                    ThemeManager:ApplyToTab(tab.Tab);
                end;
            end;
        end;
    end);

    -- apply_colors + ApplyTheme only cover registered elements. This catches
    -- the window chrome, separators and strokes that the library bakes once and
    -- never revisits.
    local recoloured = pcall(function()
        return theme.recolor(previous);
    end);

    -- Then re-run the registry itself. Some properties are produced by
    -- registered FUNCTIONS, not stored values -- the window title builds its
    -- string from Library.AccentColor at evaluation time and is only evaluated
    -- when the registry updates. Nothing re-ran it after the palette change, so
    -- the title kept rendering the old accent (#6699cc, the PR blue) behind a
    -- white AccentColor.
    pcall(function()
        if type(Library.UpdateColorsUsingRegistry) == "function" then
            Library:UpdateColorsUsingRegistry();
        end;
    end);

    pcall(theme.fix_contrast);

    pcall(theme.build_overlay);
    pcall(theme.start_motion);

    theme.applied = true;
    theme.previous_palette = previous;

    -- The library repaints from its own state when the UI is shown, and creates
    -- some elements long after init -- notifications, toasts, dropdown options.
    -- So keep re-running the remap and the contrast guard rather than doing it
    -- once and hoping. Cheap: a single descendant walk every 2s.
    task.spawn(function()
        for _ = 1, 15 do
            task.wait(2);
            pcall(function() theme.recolor(previous) end);
            pcall(theme.fix_contrast);
        end;
    end);

    return colors and recoloured;
end;

return theme;
