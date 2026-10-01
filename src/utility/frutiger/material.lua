--[[
    src/utility/frutiger/material.lua

    The styling kit. Every visual in this theme comes from here rather than being
    set per element, so the material stays consistent and a change to the
    language is one edit instead of two hundred.

    What it provides, and why each exists:

      corner      rounded geometry. Glass has no sharp edges.
      stroke      a soft border. Bright, never a hard coloured outline -- heavy
                  borders are what make a glass UI read as a flat dashboard with
                  blue trim rather than as layered panes.
      gradient    the vertical light. Top edge brighter (reflected light),
                  middle clear, bottom faintly cyan. This is what sells a flat
                  fill as a curved surface.
      shadow      depth. Roblox cannot blur, so this is a translucent offset
                  frame behind the element. It reads as a soft drop shadow at
                  small depths and avoids looking like a hard cast.
      specular    a small radial white highlight from the orb texture, placed
                  off-centre. Individually barely visible; collectively it is
                  what makes the surfaces feel wet.
      hover       brightness and tint on MouseEnter / MouseLeave. Tweened, so it
                  feels like light moving rather than a state flip.
      press       a small scale and dim on click, so buttons feel physical.

    Everything is instance-driven and pcall-guarded: a missing texture or a
    locked property costs one highlight, never the interface.
]]

local material = {};

local TWEEN = game:GetService("TweenService");

-- ── palette ────────────────────────────────────────────────────────────────
local theme_module = nil;
pcall(function() theme_module = require("@src/utility/frutiger/theme") end);

local extra = (theme_module and theme_module.extra) or {};

material.colors = {
    glass    = extra.glass or Color3.fromRGB(234, 251, 255),
    bgGlass  = extra.bgGlass or Color3.fromRGB(220, 245, 255),
    sky      = extra.sky or Color3.fromRGB(216, 243, 255),
    cyan     = extra.aqua or Color3.fromRGB(55, 199, 255),
    cyan2    = extra.cyan2 or Color3.fromRGB(93, 216, 255),
    cyan3    = extra.cyan3 or Color3.fromRGB(123, 229, 255),
    white    = Color3.fromRGB(255, 255, 255),
    ink      = extra.ink or Color3.fromRGB(32, 56, 74),
    muted    = extra.muted or Color3.fromRGB(85, 115, 131),
    shadow   = Color3.fromRGB(78, 150, 180),
};

-- standard timings
material.FAST = 0.15;
material.SOFT = 0.22;

-- ── primitives ─────────────────────────────────────────────────────────────
local function find_class(object, class)
    for _, child in ipairs(object:GetChildren()) do
        if child:IsA(class) then
            return child;
        end;
    end;
    return nil;
end;

function material.corner(object, radius)
    radius = radius or 12;
    local existing = find_class(object, "UICorner");
    if existing then
        pcall(function() existing.CornerRadius = UDim.new(0, radius) end);
        return existing;
    end;

    local corner = Instance.new("UICorner");
    corner.CornerRadius = UDim.new(0, radius);
    corner.Parent = object;
    return corner;
end;

function material.stroke(object, options)
    options = options or {};
    local stroke = find_class(object, "UIStroke");
    if not stroke then
        stroke = Instance.new("UIStroke");
        stroke.Parent = object;
    end;

    pcall(function()
        stroke.Color = options.color or material.colors.white;
        stroke.Thickness = options.thickness or 1;
        stroke.Transparency = options.transparency or 0.55;
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
    end);

    return stroke;
end;

-- top brighter, middle clear, bottom faint cyan. Left subtle on purpose: an
-- aggressive ramp looks like a plastic gradient rather than glass.
function material.gradient(object, options)
    options = options or {};
    local gradient = find_class(object, "UIGradient");
    if not gradient then
        gradient = Instance.new("UIGradient");
        gradient.Name = "glass";
        gradient.Parent = object;
    end;

    pcall(function()
        gradient.Rotation = options.rotation or 90;
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, options.top or material.colors.white),
            ColorSequenceKeypoint.new(0.50, options.middle or material.colors.glass),
            ColorSequenceKeypoint.new(1.00, options.bottom or material.colors.cyan3),
        });
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, options.top_transparency or 0.55),
            NumberSequenceKeypoint.new(0.45, options.mid_transparency or 0.90),
            NumberSequenceKeypoint.new(1.00, options.bottom_transparency or 0.80),
        });
    end);

    return gradient;
end;

-- Roblox has no blur, so a shadow is a translucent offset copy sitting behind.
-- Small depths only: at large offsets the lack of blur becomes obvious and it
-- looks like a dupe rather than a shadow.
function material.shadow(object, options)
    options = options or {};
    if object:FindFirstChild("glass_shadow") then
        return;
    end;

    local depth = options.depth or 3;
    local shadow = Instance.new("Frame");
    shadow.Name = "glass_shadow";
    shadow.BackgroundColor3 = options.color or material.colors.shadow;
    shadow.BackgroundTransparency = options.transparency or 0.86;
    shadow.BorderSizePixel = 0;
    shadow.Active = false;
    shadow.ZIndex = math.max(0, (object.ZIndex or 1) - 1);
    shadow.Size = object.Size;
    shadow.Position = object.Position + UDim2.fromOffset(0, depth);
    shadow.AnchorPoint = object.AnchorPoint;
    shadow.Parent = object.Parent;

    local radius = options.radius or 12;
    local corner = Instance.new("UICorner");
    corner.CornerRadius = UDim.new(0, radius);
    corner.Parent = shadow;

    object:GetPropertyChangedSignal("Size"):Connect(function()
        pcall(function() shadow.Size = object.Size end);
    end);
    object:GetPropertyChangedSignal("Position"):Connect(function()
        pcall(function() shadow.Position = object.Position + UDim2.fromOffset(0, depth) end);
    end);

    return shadow;
end;

function material.specular(object, options)
    options = options or {};
    local texture = theme_module and theme_module.textures and theme_module.textures.orb;
    if not texture then
        return nil;
    end;

    local dot = Instance.new("ImageLabel");
    dot.Name = "glass_specular";
    dot.BackgroundTransparency = 1;
    dot.BorderSizePixel = 0;
    dot.Image = texture;
    dot.ImageColor3 = material.colors.white;
    dot.ImageTransparency = options.transparency or 0.80;
    dot.AnchorPoint = options.anchor or Vector2.new(0, 0);
    dot.Position = options.position or UDim2.new(0, 3, 0, 2);
    dot.Size = options.size or UDim2.fromOffset(14, 14);
    dot.ZIndex = (object.ZIndex or 1) + 1;
    dot.Active = false;
    dot.Parent = object;

    return dot;
end;

-- ── motion ─────────────────────────────────────────────────────────────────
local function tween(object, properties, duration, style)
    local info = TweenInfo.new(
        duration or material.SOFT,
        style or Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    );
    local ok, result = pcall(function()
        return TWEEN:Create(object, info, properties);
    end);
    if ok and result then
        result:Play();
    end;
    return result;
end;

material.tween = tween;

-- Adds a soft light-up on hover. Written to record the element's CURRENT values
-- at enter rather than at attach: the library repaints colours on theme change,
-- so a snapshot taken at attach time goes stale and leaving would restore an
-- older theme's colour.
function material.hover(object, options)
    options = options or {};
    if object:GetAttribute("glass_hover") then
        return;
    end;
    object:SetAttribute("glass_hover", true);

    local state = {};

    object.MouseEnter:Connect(function()
        state.bg = object.BackgroundColor3;
        state.transparency = object.BackgroundTransparency;

        local target = options.tint or material.colors.cyan2;
        tween(object, {
            BackgroundColor3 = state.bg:Lerp(target, options.strength or 0.45),
            BackgroundTransparency = math.max(0, state.transparency - (options.lift or 0.10)),
        }, material.FAST);
    end);

    object.MouseLeave:Connect(function()
        if not state.bg then
            return;
        end;
        tween(object, {
            BackgroundColor3 = state.bg,
            BackgroundTransparency = state.transparency,
        }, material.FAST);
    end);
end;

function material.press(object, options)
    options = options or {};
    if object:GetAttribute("glass_press") then
        return;
    end;
    object:SetAttribute("glass_press", true);

    local base = options.scale or 0.985;

    -- Captured on press, not at attach and not on release. At attach it is stale
    -- by the time anything is clicked; on release the size is already the
    -- shrunken one, so restoring it would leave the button permanently small.
    local before = nil;

    object.MouseButton1Down:Connect(function()
        before = object.Size;
        tween(object, { Size = UDim2.new(
            before.X.Scale * base, before.X.Offset * base,
            before.Y.Scale * base, before.Y.Offset * base
        ) }, 0.08);
    end);

    object.MouseButton1Up:Connect(function()
        if before then
            tween(object, { Size = before }, 0.14);
        end;
    end);
end;

-- ── composites ─────────────────────────────────────────────────────────────
function material.panel(object, options)
    options = options or {};
    material.corner(object, options.radius or 12);
    material.stroke(object, {
        color = options.stroke_color,
        transparency = options.stroke_transparency or 0.55,
        thickness = options.stroke_thickness or 1,
    });
    material.gradient(object, options);
    if options.shadow ~= false then
        material.shadow(object, { radius = options.radius or 12, depth = options.depth or 3 });
    end;
    if options.specular ~= false then
        material.specular(object, options.specular_options);
    end;
    object:SetAttribute("glass_panel", true);
    return object;
end;

-- A button is a panel that reacts: brighter on hover, smaller on press.
function material.button(object, options)
    options = options or {};
    options.radius = options.radius or 10;
    material.panel(object, options);
    material.hover(object, options);
    material.press(object, options);
    object:SetAttribute("glass_button", true);
    return object;
end;

-- A pill is a button with full rounding -- used for compact controls where the
-- radius should read as a capsule rather than a card.
function material.pill(object, options)
    options = options or {};
    options.radius = math.huge;   -- clamped by Roblox to half the height
    return material.button(object, options);
end;

return material;
