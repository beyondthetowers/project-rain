--[[
    src/utility/frutiger/chrome.lua

    Native chrome, borrowed widgets.

    The library keeps doing what it is good at -- toggles, sliders, dropdowns,
    dependency boxes, keybinds, config round-tripping. Rewriting that would mean
    reproducing 16 constructors, 16 Library methods and 103 option objects
    across 60 files.

    What it is bad at is being the frame around those widgets. Its chrome fights
    decoration: it re-tweens properties, rebuilds pieces on tab switch, and
    bakes a font per label, so fonts, torn borders and glitch effects can only
    be bolted on from outside. So the chrome is replaced and the widget tree
    transplanted into it.

    The shell lives INSIDE Outer, the library's window frame, and that is the
    whole trick:

    *   Outer already carries the UIScale, so the transplanted widgets render at
        the scale the user set without any of it being re-derived.

    *   Outer already carries the drag binding -- MakeUIDraggable(Outer, 21) at
        ui.lua:1297, a 21px grab zone at the top -- and this shell puts its title
        bar in exactly that strip, so dragging keeps working untouched.

    *   The theme overlay is also a child of Outer at scale 1,1, so it resizes
        with the new window instead of drifting away from it. Parenting the
        shell to the ScreenGui instead would have desynced all three.

    *   Outer.Visible is the library's own show/hide state (Library:Toggle sets
        it at ui.lua ~2369), so visibility needs no syncing at all --
        everything is inside it.

    How the pieces are moved:

    *   Tab switching is Tab:ShowTab() (ui.lua ~1882), which sets
        TabFrame.Visible. Those frames live inside the library's content frame,
        so the whole content frame moves in one piece.

    *   It is moved at its MEASURED size, never stretched. Every tab page inside
        uses fixed offsets and two 266px columns; letting it resize drags them
        out of position -- the trap the sidebar pass already fell into once.

    *   The library's own chrome (title, strip, separator, search) is hidden by
        hiding Inner, but LEFT ALIVE. Tab:ShowTab() still writes to
        TabButtonLabel, the underline and the registry, and those have to keep
        resolving.
]]

local chrome = {};

local SIDEBAR_WIDTH = 150;
local TITLE_HEIGHT = 26;
local TAB_HEIGHT = 26;
local TAB_PADDING = 2;

-- Palette source, so the shell is themed rather than hardcoded. pcall'd because
-- a missing theme should cost the colours, not the chrome.
local theme_module = nil;
pcall(function() theme_module = require("@src/utility/frutiger/theme") end);

-- ── helpers ────────────────────────────────────────────────────────────────
local function gui_children(parent)
    local out = {};
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then
            out[#out + 1] = child;
        end;
    end;
    return out;
end;

local function make(class, props)
    local object = Instance.new(class);
    for key, value in next, props do
        object[key] = value;
    end;
    return object;
end;

-- ── locate the library's pieces ────────────────────────────────────────────
local function find_window_body(outer)
    for _, child in ipairs(gui_children(outer)) do
        if child.Name ~= "FRUTIGER_OVERLAY" then
            return child;
        end;
    end;
    return nil;
end;

local function find_strip(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("Frame") then
            local layout = descendant:FindFirstChildOfClass("UIListLayout");
            if layout
                and layout.FillDirection == Enum.FillDirection.Horizontal
                and descendant.AbsoluteSize.X > descendant.AbsoluteSize.Y * 4 then
                return descendant;
            end;
        end;
    end;
    return nil;
end;

-- ── build ──────────────────────────────────────────────────────────────────
local function build(outer)
    local inner = find_window_body(outer);
    if not inner then
        return false, "no window body";
    end;

    local strip = find_strip(inner);
    if not strip then
        return false, "no tab strip";
    end;

    local holder = strip.Parent;
    local container = holder and holder.Parent;
    if not holder or not container then
        return false, "no frame chain";
    end;

    local content;
    for _, sibling in ipairs(gui_children(holder)) do
        if sibling ~= strip and sibling.AbsoluteSize.Y > 100 then
            content = content or sibling;
        end;
    end;
    if not content then
        return false, "no content frame";
    end;

    -- measure BEFORE moving, and restore at exactly this size
    local content_size = content.AbsoluteSize;

    -- ── the shell ──────────────────────────────────────────────────────────
    local window_width = SIDEBAR_WIDTH + content_size.X;
    local window_height = TITLE_HEIGHT + content_size.Y;

    -- Colours come from the palette rather than literals. These were hardcoded
    -- black/white during the CONSOLE pass and were never updated, so the shell
    -- root stayed #000000 behind a light theme -- the whole UI sat on black.
    local theme = theme_module;
    local palette = (theme and theme.extra) or {};
    local GLASS = palette.glass or Color3.fromRGB(244, 251, 255);
    local EDGE  = Color3.fromRGB(255, 255, 255);   -- soft white edge, per the brief
    local SKY   = palette.sky   or Color3.fromRGB(159, 212, 239);
    local AQUA  = palette.aqua  or Color3.fromRGB(41, 168, 224);
    local INK   = palette.ink   or Color3.fromRGB(14, 61, 92);

    local root = make("Frame", {
        Name = "FRUTIGER_CHROME",
        BackgroundColor3 = GLASS,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        ZIndex = 1,
        Parent = outer,
    });

    make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = root });

    local stroke = make("UIStroke", {
        Color = EDGE,
        Thickness = 1,
        Parent = root,
    });
    make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = stroke });

    -- title bar. sits inside Outer's existing 21px drag zone.
    local title_bar = make("Frame", {
        Name = "title",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
        ZIndex = 2,
        Parent = root,
    });

    local title_label = make("TextLabel", {
        Name = "title_text",
        BackgroundTransparency = 1,
        Font = Enum.Font.RobotoMono,
        Text = string.format("FRUTIGER // USER_%03d", math.random(1, 999)),
        TextColor3 = INK,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        ZIndex = 2,
        Parent = title_bar,
    });

    make("Frame", {
        Name = "title_rule",
        BackgroundColor3 = EDGE,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, TITLE_HEIGHT - 1),
        ZIndex = 2,
        Parent = root,
    });

    -- sidebar
    local sidebar = make("Frame", {
        Name = "sidebar",
        BackgroundTransparency = 1,
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -TITLE_HEIGHT),
        Position = UDim2.fromOffset(0, TITLE_HEIGHT),
        ZIndex = 2,
        Parent = root,
    });

    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, TAB_PADDING),
        Parent = sidebar,
    });
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 6),
        Parent = sidebar,
    });

    make("Frame", {
        Name = "sidebar_rule",
        BackgroundColor3 = EDGE,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 1, 1, -TITLE_HEIGHT),
        Position = UDim2.new(0, SIDEBAR_WIDTH, 0, TITLE_HEIGHT),
        ZIndex = 2,
        Parent = root,
    });

    -- content host
    local host = make("Frame", {
        Name = "content_host",
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Size = UDim2.fromOffset(content_size.X, content_size.Y),
        Position = UDim2.fromOffset(SIDEBAR_WIDTH + 1, TITLE_HEIGHT),
        ZIndex = 1,
        Parent = root,
    });

    -- ── transplant ─────────────────────────────────────────────────────────
    content.Parent = host;
    content.Position = UDim2.fromOffset(0, 0);
    content.Size = UDim2.fromOffset(content_size.X, content_size.Y);

    -- ── hide the library chrome, keep it alive ─────────────────────────────
    pcall(function() inner.Visible = false end);
    pcall(function() outer.BackgroundTransparency = 1 end);

    -- ── resize the library window around the new chrome ────────────────────
    -- Outer keeps its UIScale, its drag binding and the theme overlay child,
    -- all of which follow this size.
    pcall(function()
        outer.Size = UDim2.fromOffset(window_width, window_height);
    end);

    -- ── tabs ───────────────────────────────────────────────────────────────
    local window = Library.FrutigerWindow;
    local entries = {};

    local function sorted_tabs()
        -- Window.TabOrder is the library's authoritative order, and it is an
        -- array of Tab OBJECTS in creation order (ui.lua:2290).
        --
        -- The first version sorted by tab.LayoutOrder, which does not exist:
        -- Tab:SetLayoutOrder writes to TabButton.LayoutOrder, not to the Tab.
        -- So the comparator compared nil with nil and returned false every
        -- time, and table.sort produced arbitrary order.
        local order = window.TabOrder;
        if type(order) == "table" and #order > 0 then
            local ordered = {};
            for _, tab in ipairs(order) do
                if tab then
                    ordered[#ordered + 1] = tab;
                end;
            end;
            return ordered;
        end;

        -- fallback for a window built without TabOrder
        local tabs = window.Tabs or {};
        local names = {};
        for name in next, tabs do
            names[#names + 1] = name;
        end;
        table.sort(names);

        local out = {};
        for _, name in ipairs(names) do
            if tabs[name] then
                out[#out + 1] = tabs[name];
            end;
        end;
        return out;
    end;

    local function paint_active(active)
        for tab, entry in next, entries do
            local is_active = (tab == active);
            pcall(function()
                entry.frame.BackgroundColor3 = is_active and AQUA or GLASS;
                entry.label.TextColor3 = INK;
            end);
        end;
    end;

    local function build_entries()
        local ordered = sorted_tabs();

        for index, tab in ipairs(ordered) do
            if not entries[tab] then
                local row = make("Frame", {
                    Name = "tab_" .. index,
                    BackgroundColor3 = GLASS,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
                    LayoutOrder = index,
                    ZIndex = 3,
                    Parent = sidebar,
                });
                make("UICorner", { CornerRadius = UDim.new(0, 4), Parent = row });
                make("UIStroke", {
                    Color = EDGE,
                    Thickness = 1,
                    Parent = row,
                });

                local label = make("TextLabel", {
                    Name = "label",
                    BackgroundTransparency = 1,
                    Font = Enum.Font.RobotoMono,
                    Text = tostring(tab.Name or ("TAB_" .. index)):upper(),
                    TextColor3 = INK,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, -12, 1, 0),
                    Position = UDim2.fromOffset(8, 0),
                    ZIndex = 4,
                    Parent = row,
                });

                entries[tab] = { frame = row, label = label };

                -- clicking drives the library's own tab switch, so its internal
                -- state (ActiveTab, search refresh, registry) stays correct
                row.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        pcall(function() tab:ShowTab() end);
                        paint_active(tab);
                    end
                end);
            end
        end;

        if window.ActiveTab then
            paint_active(window.ActiveTab);
        elseif ordered[1] then
            pcall(function() ordered[1]:ShowTab() end);
            paint_active(ordered[1]);
        end;
    end;

    build_entries();

    -- The library can add or rebuild tabs (search, config load), so re-sync for
    -- a while rather than assuming the set is fixed.
    task.spawn(function()
        for _ = 1, 10 do
            task.wait(1);
            pcall(build_entries);
            pcall(function() paint_active(Library.FrutigerWindow.ActiveTab) end);
        end;
    end);

    chrome.root = root;
    chrome.sidebar = sidebar;
    chrome.host = host;
    chrome.title = title_label;
    chrome.entries = entries;
    chrome.transplanted = content;
    chrome.outer = outer;

    return true;
end;

function chrome.apply()
    if chrome.applied then
        return true;
    end;

    if not Library or not Library.ScreenGui or not Library.FrutigerWindow then
        return false;
    end;

    local outer = Library.FrutigerWindow.Holder;
    if not outer then
        return false;
    end;

    local ok, result, reason = pcall(build, outer);
    if not ok then
        warn("[frutiger] chrome failed:", result);
        return false;
    end;
    if not result then
        warn("[frutiger] chrome skipped:", reason);
        return false;
    end;

    chrome.applied = true;
    return true;
end;

-- ── keybind list ───────────────────────────────────────────────────────────
-- Library.KeybindFrame (ui.lua:1246) is a PanelComponent panel: four nested
-- fills with the text buried inside them.
--
--     Outer    accent-coloured, BorderSizePixel 1   <- the border you see
--       Inner  main fill
--         Header   background fill, 22px
--           HeaderLabel  "Keybinds", centred
--         Divider  outline-coloured 1px
--         Content  (transparent) <- the entries live here
--
-- So stripping the background is a walk: every Frame in the panel loses its
-- fill and its classic border. The labels are untouched, which is the point --
-- text only, no box.
--
-- The header is centred because it used to sit inside a filled bar. With the
-- bar gone it reads as a stray float in the middle of nothing, so it is aligned
-- left to line up with the entries under it.

-- Which corner the bind list sits in. Bottom-left: the anchor is the bottom
-- edge, so the list grows upward as binds are added and the bottom stays put.
--
-- Flip these two to move it -- Vector2.new(0, 0) is top-left, Vector2.new(1, 1)
-- is bottom-right. Note the bottom-anchored Y value (1) is also what tells
-- toggle.lua to skip its vertical-centre compensation; a centre anchor (0.5)
-- would drag the list down as it grows.
local KEYBIND_ANCHOR = Vector2.new(0, 1);
local KEYBIND_MARGIN = 10;

-- Corner position, computed from the camera viewport in OFFSETS rather than
-- from scale.
--
-- Scale-1 Y does not mean "the bottom of the screen" here: the library's
-- ScreenGui has IgnoreGuiInset = false and GuiService reports a 58px inset, so
-- ScreenGui.AbsoluteSize is 1920x1022 against a 1920x1080 viewport. Anchoring
-- at scale 1 left the panel 68px above the physical bottom -- measured. Offsets
-- are absolute screen pixels, so they land where you actually want.
--
-- Offsets also suit the library: toggle.lua's resize code reads
-- Position.Y.Offset, and SaveManager stores the position as a UDim2 anyway.
local function corner_position()
    local camera = workspace.CurrentCamera;
    local viewport = (camera and camera.ViewportSize) or Vector2.new(1920, 1080);

    local x = (KEYBIND_ANCHOR.X == 1)
        and (viewport.X - KEYBIND_MARGIN)
        or KEYBIND_MARGIN;

    local y = (KEYBIND_ANCHOR.Y == 1)
        and (viewport.Y - KEYBIND_MARGIN)
        or KEYBIND_MARGIN;

    return UDim2.fromOffset(x, y);
end;

function chrome.restyle_keybinds()
    if not Library or not Library.KeybindFrame then
        return false;
    end;

    local frame = Library.KeybindFrame;

    -- bottom-left. The list reads as an overlay on the game rather than a
    -- panel, and the left edge is otherwise clear once the quest tracker is
    -- dismissed.
    pcall(function()
        frame.AnchorPoint = KEYBIND_ANCHOR;
        frame.Position = corner_position();
    end);

    local stripped = 0;

    for _, descendant in ipairs(frame:GetDescendants()) do
        if descendant:IsA("Frame") then
            local ok = pcall(function()
                descendant.BackgroundTransparency = 1;
                descendant.BorderSizePixel = 0;
            end);
            if ok then
                stripped = stripped + 1;
            end;
        elseif descendant:IsA("TextLabel") then
            -- the panel title, once centred in its bar
            if descendant.Text and descendant.Text:lower():find("keybind") then
                pcall(function()
                    descendant.TextXAlignment = Enum.TextXAlignment.Left;
                end);
            end;
        end;
    end;

    pcall(function()
        frame.BackgroundTransparency = 1;
        frame.BorderSizePixel = 0;
    end);

    chrome.keybind_frame = frame;
    chrome.keybinds_stripped = stripped;

    -- SaveManager persists and restores a keybindPosition (SaveManager.lua:149
    -- saves, :266 restores), and that restore can land after this runs. An older
    -- saved position is offset-based, which under this anchor puts the panel off
    -- screen. So re-assert for a few seconds; once the position has been saved
    -- back as ours, later launches restore correctly on their own.
    task.spawn(function()
        for _, delay in ipairs({ 0.5, 1.5, 3, 5, 8 }) do
            task.wait(delay);
            local current = chrome.keybind_frame;
            if current and current.Parent then
                pcall(function()
                    current.AnchorPoint = KEYBIND_ANCHOR;
                    current.Position = corner_position();
                end);
            end;
        end;
    end);

    return true;
end;

return chrome;
