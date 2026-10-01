--[[
    src/utility/frutiger/theme.lua

    The DECAY look. Palette, fonts, and a procedural overlay that sits inside
    the menu window.

    Scoping decisions:

    1.  The overlay is parented INTO Library.FrutigerWindow, not screenspaced over
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

-- Frutiger Aero / liquid glass. Bright, airy, watery, translucent.
--
-- The palette is deliberately low-contrast between its own slots: everything is
-- a pale cyan or an ice white, and the ONLY strong values are the cyan accent
-- and the text. Structure comes from transparency and highlights, not from
-- outlines -- heavy borders are what makes a glass UI read as a flat dashboard
-- with blue trim.
--
-- Text is the one place contrast is allowed to be strong, because it has to sit
-- on translucent surfaces over arbitrary scenery.
theme.palette = {
    FontColor       = "20384a",   -- primary text: navy-grey, not black
    MainColor       = "eafbff",   -- glass card fill
    AccentColor     = "37c7ff",   -- cyan accent: selections, toggles, sliders
    BackgroundColor = "dcf5ff",   -- window glass
    OutlineColor    = "ffffff",   -- soft white border, never a hard blue line
};

theme.extra = {
    -- glass fills, lightest to deepest
    glass   = Color3.fromRGB(234, 251, 255),   -- #EAFBFF
    bgGlass = Color3.fromRGB(220, 245, 255),   -- #DCF5FF
    sky     = Color3.fromRGB(216, 243, 255),   -- #D8F3FF

    -- cyan family, for accents and glows
    aqua    = Color3.fromRGB(55, 199, 255),    -- #37C7FF
    cyan2   = Color3.fromRGB(93, 216, 255),    -- #5DD8FF
    cyan3   = Color3.fromRGB(123, 229, 255),   -- #7BE5FF

    -- text
    ink     = Color3.fromRGB(32, 56, 74),      -- #20384A primary
    text2   = Color3.fromRGB(41, 72, 90),      -- #29485A
    muted   = Color3.fromRGB(85, 115, 131),    -- #557383 secondary, e.g. "N/A"

    white   = Color3.fromRGB(255, 255, 255),
    lime    = Color3.fromRGB(126, 200, 80),
};

-- Condensed industrial for headings, technical mono for everything else.
theme.fonts = {
    heading = Enum.Font.Oswald,
    body    = Enum.Font.RobotoMono,
};

-- ── textures ───────────────────────────────────────────────────────────────
local visible = nil;
pcall(function() visible = require("@src/utility/frutiger/visible") end);

-- Guard against the module failing to load: without it nothing would ever run,
-- which is worse than running too often.
if not visible then
    visible = { menu = function() return true end, on_open = function() end };
end;

local TEXTURE_DIR = "Frutiger/Textures";
local TEXTURE_NAMES = { "gloss", "frost", "bubbles", "sheen", "orb" };

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

-- Library.FrutigerWindow is the linoria Window OBJECT, not the frame — it carries
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

    for _, candidate in ipairs({ Library.FrutigerWindow, Library.Window, Library.ScreenGui }) do
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
                if child.Name == "FRUTIGER_OVERLAY" then
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
    holder.Name = "FRUTIGER_OVERLAY";
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

    -- Frutiger Aero stacks four things, in this order:
    --
    --   gloss    the curved-glass highlight across the top. Static, stretched.
    --   bubbles  translucent spheres, tiled, drifting slowly upward.
    --   sheen    a soft highlight band that sweeps down the panel occasionally.
    --
    -- No grain, no scanlines, no vignette. All three read as damage or CRT on a
    -- light glossy surface, which is the opposite of what this theme is.

    theme.gloss = layer(holder, "gloss", theme.textures.gloss, {
        ZIndex = base + 1,
        ImageTransparency = 0.42,
        ScaleType = Enum.ScaleType.Stretch,
    });

    -- Frost sits under the bubbles. It is the diffusion that makes the pane read
    -- as glass rather than as a plain see-through hole.
    theme.frost = layer(holder, "frost", theme.textures.frost, {
        ZIndex = base + 2,
        ImageTransparency = 0.55,
        TileSize = UDim2.fromOffset(128, 128),
    });

    theme.bubbles = layer(holder, "bubbles", theme.textures.bubbles, {
        ZIndex = base + 3,
        ImageTransparency = 0.52,
        TileSize = UDim2.fromOffset(256, 256),
    });

    theme.sheen = layer(holder, "sheen", theme.textures.sheen, {
        ZIndex = base + 4,
        ImageTransparency = 0.35,
        ScaleType = Enum.ScaleType.Stretch,
        Size = UDim2.new(1, 0, 0, 96),
        Position = UDim2.new(0, 0, -1, 0),
        Visible = false,
    });

    return holder;
end;

-- ── motion ─────────────────────────────────────────────────────────────────
-- Slow and calm, which is the opposite of what was here before. The previous
-- pass deliberately jittered grain at 12fps and jolted the pane sideways to
-- read as a failing monitor. On Frutiger that is just a broken UI.

function theme.start_motion()
    if theme.motion_started then
        return;
    end;
    theme.motion_started = true;

    local RunService = game:GetService("RunService");
    local rnd = Random.new();

    -- Bubbles rise. Each step nudges the tile offset upward so the whole field
    -- drifts, then wraps -- cheaper than animating instances and seamless
    -- because the texture tiles.
    task.spawn(function()
        local offset = 0;
        while theme.overlay and theme.overlay.Parent do
            if not visible.menu() then
                -- Nothing to animate while hidden, and RenderStepped:Wait()
                -- wakes every single frame. Sleep instead.
                task.wait(0.25);
            else
                if theme.bubbles then
                    offset = (offset - 0.35) % 256;
                    theme.bubbles.Position = UDim2.fromOffset(0, offset);
                end;
                RunService.RenderStepped:Wait();
            end;
        end;
    end);

    -- The sheen sweeps down over ~2.4s, then waits 9-22s. It is hidden between
    -- passes rather than parked off-screen, so it cannot flash at the edges.
    task.spawn(function()
        while theme.overlay and theme.overlay.Parent do
            task.wait(rnd:NextNumber(9, 22));

            if not visible.menu() then
                task.wait(1);
                continue;
            end;

            local height = theme.overlay.AbsoluteSize.Y;
            if theme.sheen and height > 0 then
                theme.sheen.Visible = true;
                local start = tick();
                local duration = 2.4;

                while tick() - start < duration and theme.overlay.Parent do
                    local t = (tick() - start) / duration;
                    theme.sheen.Position = UDim2.fromOffset(0, t * (height + 96) - 96);
                    -- fade in and out so it never pops
                    theme.sheen.ImageTransparency = 0.35 + math.abs(t - 0.5) * 0.5;
                    RunService.RenderStepped:Wait();
                end;

                theme.sheen.Visible = false;
            end;
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

-- Which old palette entry each PROPERTY should be matched against.
--
-- The first version built one flat old-value -> new-value table and matched any
-- property against any entry, first hit wins. That is ambiguous whenever the
-- outgoing palette repeats a value, and the CONSOLE palette repeated two:
-- FontColor, AccentColor and OutlineColor were all #ffffff, and MainColor and
-- BackgroundColor were both #000000. So a white-filled toggle knob could be
-- matched through FontColor and repainted dark navy -- 693 elements came out
-- dark that way when switching to a light theme.
--
-- Matching per property removes the ambiguity: a fill is only ever compared
-- against the old fills, text against the old text, and so on.
local PROPERTY_SOURCE = {
    -- OutlineColor belongs here too: the library paints dividers and separators
    -- with BorderColor3 = OutlineColor, i.e. OutlineColor IS their background, so
    -- leaving it out meant every divider kept the previous theme's edge colour.
    BackgroundColor3  = { "MainColor", "BackgroundColor", "OutlineColor" };
    TextColor3        = { "FontColor", "AccentColor" };
    PlaceholderColor3 = { "FontColor" };
    BorderColor3      = { "OutlineColor" };
    Color             = { "OutlineColor", "AccentColor" };   -- UIStroke
};

function theme.recolor(previous)
    if not Library or not Library.ScreenGui or type(previous) ~= "table" then
        return 0;
    end;

    -- build a lookup per source key, so each property knows where to look
    local by_key = {};
    for key, old in next, previous do
        local hex = theme.palette[key];
        if hex and typeof(old) == "Color3" then
            by_key[key] = { old = old, new = Color3.fromHex(hex) };
        end;
    end;

    local function luminance_of(color)
        return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B;
    end;

    -- which way round the palette being applied is, for the polarity fallback
    local theme_luminance = luminance_of(Color3.fromHex(theme.palette.MainColor));

    local function remap(object, property)
        local sources = PROPERTY_SOURCE[property];
        if not sources then
            return false;
        end;

        -- Read directly. All five properties exist on every GuiObject, so the
        -- guarded read was five wasted pcalls per object -- across 15742
        -- descendants that is ~78000 calls per pass, which is a visible hitch
        -- every time the pass ran rather than a rounding error.
        local current = object[property];
        if typeof(current) ~= "Color3" then
            return false;
        end;

        for _, key in ipairs(sources) do
            local pair = by_key[key];
            if pair and colors_close(current, pair.old) then
                object[property] = pair.new;
                return true;
            end;
        end;

        -- Polarity fallback, for elements the library paints with a LITERAL
        -- black or white instead of a palette colour.
        --
        -- Measured: with a light palette applied, 688 elements stayed pure
        -- #000000 -- toggle knobs and slider thumbs among them. They match no
        -- palette entry, so the loop above cannot see them, and they are not
        -- created late either, so the tree watcher cannot either. They are
        -- simply hardcoded, and they only look wrong when the theme's polarity
        -- is the opposite of theirs.
        if property == "BackgroundColor3" and theme_luminance > 0.5 then
            if luminance_of(current) < 0.15 then
                object[property] = Color3.fromHex(theme.palette.MainColor);
                return true;
            end;
        end;
        if property == "TextColor3" and theme_luminance < 0.5 then
            if luminance_of(current) > 0.85 then
                object[property] = Color3.fromHex(theme.palette.FontColor);
                return true;
            end;
        end;

        return false;
    end;

    if next(by_key) == nil then
        return 0;
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
-- fill at full opacity behind #ffffff text.
--
-- The guard darkens the TEXT, not the fill. It used to darken the fill, which
-- was wrong for the common case: the library paints AccentColor as a BACKGROUND
-- for hover fills, dropdown selections and toggles, and with a white accent that
-- is a white fill. Blacking those out would erase the accent entirely and you
-- could no longer see what is selected. Inverting the text instead keeps the
-- white fill and puts black on it, which is readable AND still shows selection.
--
-- Safe against the hover inversion, which produces the same pairing
-- deliberately: white fill, black text.

local function luminance(color)
    return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B;
end;

local CONTRAST_DARK = Color3.fromRGB(12, 12, 12);

-- The nearest ancestor that actually paints something, walking up until a fill
-- is found. This is the whole point: text is very rarely a direct child of the
-- thing it sits on. A toggle label lives inside a row with
-- BackgroundTransparency = 1, inside a groupbox, inside the panel. Checking only
-- the label's own parent finds nothing and the guard does nothing -- which is
-- exactly what happened, and why the toggle labels stayed white on a light
-- panel while the slider labels (which sit on a filled track) came out dark.
local function nearest_fill(object)
    local node = object.Parent;

    while node and node ~= Library.ScreenGui do
        if node:IsA("GuiObject") then
            local transparency = node.BackgroundTransparency;
            if transparency and transparency < 0.6 then
                return node.BackgroundColor3;
            end;
        end;

        node = node.Parent;
    end;

    return nil;
end;

-- Pick whichever of the palette's text colour and a hard dark reads better on
-- the fill behind it. Using FontColor keeps the result on-theme; the hard
-- constant is the fallback for a palette whose own text colour is light.
local function readable_text_on(background)
    local candidates = { CONTRAST_DARK };

    local ok, hex = pcall(function() return theme.palette.FontColor end);
    if ok and hex then
        candidates[#candidates + 1] = Color3.fromHex(hex);
    end;

    local background_luminance = luminance(background);
    local best;

    for _, candidate in ipairs(candidates) do
        local distance = math.abs(luminance(candidate) - background_luminance);
        if not best or distance > best.distance then
            best = { color = candidate, distance = distance };
        end;
    end;

    return best and best.color or CONTRAST_DARK;
end;

function theme.fix_contrast()
    if not Library or not Library.ScreenGui then
        return 0;
    end;

    local fixed = 0;

    for _, descendant in ipairs(Library.ScreenGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextBox") then
            local text_luminance = luminance(descendant.TextColor3);

            -- only text that is currently light is at risk
            if text_luminance > 0.7 then
                local fill = nearest_fill(descendant);

                -- ...and only when what is behind it is also light
                if fill and luminance(fill) > 0.5 then
                    local replacement = readable_text_on(fill);
                    descendant.TextColor3 = replacement;
                    fixed = fixed + 1;
                end;
            end;
        end;
    end;

    return fixed;
end;

-- ── reactive guard ─────────────────────────────────────────────────────────
-- The guard used to run on a fixed schedule -- a few passes over the first 30
-- seconds. Dropdown options, tooltips and dependency-box children are built
-- when they are first OPENED, which can be minutes later, so they were never
-- covered: their option labels stayed white on the white accent fill and were
-- unreadable until a hover inverted them.
--
-- Instead of guessing when, react to the tree changing. Debounced, because
-- building a dropdown adds a burst of instances and one pass at the end is
-- enough for all of them.

function theme.watch()
    if theme.watching or not Library or not Library.ScreenGui then
        return false;
    end;
    theme.watching = true;

    local queued = false;

    local function schedule()
        if queued then
            return;
        end;
        queued = true;

        task.delay(0.35, function()
            queued = false;

            -- THE GATE. Everything below exists to style the window, and while
            -- it is shut none of it is visible. In a live game instances are
            -- added constantly -- ESP, nametags, notifications -- so this was
            -- running several times a second across ~2000 elements for nothing.
            -- That is the framerate complaint.
            if not visible.menu() then
                return;
            end;

            pcall(function() theme.recolor(theme.previous_palette) end);
            pcall(theme.fix_contrast);
        end);
    end;

    pcall(function()
        Library.ScreenGui.DescendantAdded:Connect(schedule);
    end);

    -- Backstop for repaints that do not add instances: the library re-applies
    -- registry colours on theme changes and on show, which can put white text
    -- back on a light fill without anything being added.
    -- Backstop only. While the menu is shut this costs one comparison every
    -- 5s. It used to do two full-tree passes on that schedule regardless.
    task.spawn(function()
        for _ = 1, 60 do
            task.wait(5);
            if visible.menu() then
                pcall(function() theme.recolor(theme.previous_palette) end);
                pcall(theme.fix_contrast);
            end;
        end;
    end);

    -- The useful half: do the work when it actually becomes visible, instead of
    -- guessing on a timer.
    visible.on_open(schedule);

    return true;
end;

-- Makes CONSOLE selectable in the theme dropdown, not just forced on.
function theme.register()
    local ok, ThemeManager = pcall(require, "@src/utility/librarys/managers/ThemeManager");
    if not ok or type(ThemeManager) ~= "table" or type(ThemeManager.BuiltInThemes) ~= "table" then
        return false;
    end;

    local HttpService = game:GetService("HttpService");
    ThemeManager.BuiltInThemes["FRUTIGER"] = { 22, HttpService:JSONDecode(HttpService:JSONEncode(theme.palette)) };
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

    -- Everything the library builds AFTER this point -- dropdown options,
    -- tooltips, dependency-box children, notifications -- is covered by the
    -- reactive guard rather than a fixed schedule. The old schedule ran for 30s
    -- and by definition missed anything opened later, which is how dropdown
    -- options stayed white-on-white until a hover inverted them.
    pcall(theme.watch);

    return colors and recoloured;
end;

return theme;
