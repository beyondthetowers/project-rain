-- ScreenGui > CanvasGroup / Sidebar / Editorial header / Scroll / Echoes / Profiles.
local theme = require("@src/arteria/theme")
local UI = {}

function UI.mount(runtime)
    local input = game:GetService("UserInputService")
    local gui_service = game:GetService("GuiService")
    local tweens = game:GetService("TweenService")
    local C, F = theme.color, theme.font
    local active_tweens, buttons, actions, delayed = {}, {}, {}, {}
    local selected, capture, compact = "Movement", nil, false
    local bindings = runtime.bindings or { fly = Enum.KeyCode.F, speed = Enum.KeyCode.G, infinite_jump = Enum.KeyCode.J }
    runtime.bindings = bindings
    local system_reduced = false

    local function read_motion()
        local ok, value = pcall(function() return gui_service.ReducedMotionEnabled end)
        system_reduced = ok and value == true
    end
    read_motion()

    local function connect(signal, callback) return runtime.maid:give_task(signal:Connect(callback)) end

    local function later(seconds, callback)
        local thread
        thread = task.delay(seconds, function()
            delayed[thread] = nil
            if runtime.alive then callback() end
        end)
        delayed[thread] = true
        return thread
    end
    runtime.maid:give_task(function()
        for thread in pairs(delayed) do pcall(task.cancel, thread) end
        table.clear(delayed)
    end)

    local function create(class, props, parent)
        local object = Instance.new(class)
        if object:IsA("GuiObject") then object.BorderSizePixel = 0 end
        for key, value in pairs(props) do object[key] = value end
        object.Parent = parent
        return object
    end

    local function animate(object, props, duration)
        if active_tweens[object] then active_tweens[object].tween:Cancel(); active_tweens[object] = nil end
        if system_reduced or runtime.reduce_motion then
            for key, value in pairs(props) do object[key] = value end
        else
            local tween = tweens:Create(object, TweenInfo.new(duration or theme.motion.hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
            active_tweens[object] = { tween = tween, goals = props }
            tween:Play()
        end
    end
    runtime.maid:give_task(function()
        for _, animation in pairs(active_tweens) do animation.tween:Cancel() end
        table.clear(active_tweens)
    end)

    local function finish_motion()
        for object, animation in pairs(active_tweens) do
            animation.tween:Cancel()
            for key, value in pairs(animation.goals) do object[key] = value end
        end
        table.clear(active_tweens)
    end

    -- Real optical neon bloom for buttons, badges and indicators
    local function add_neon_bloom(parent, color, layers)
        if runtime.low_cost then return {} end
        layers = layers or {
            { size = 4, alpha = 0.74 },
            { size = 8, alpha = 0.85 },
            { size = 14, alpha = 0.93 },
            { size = 22, alpha = 0.97 },
        }
        local bloom_frames = {}
        for idx, layer in ipairs(layers) do
            local glow = create("Frame", {
                Name = "NeonBloom_" .. idx,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(1, layer.size, 1, layer.size),
                BackgroundColor3 = color or C.neon,
                BackgroundTransparency = layer.alpha,
                BorderSizePixel = 0,
                ZIndex = math.max(0, (parent.ZIndex or 1) - 1),
                Visible = parent.Visible,
            }, parent)
            table.insert(bloom_frames, glow)
        end
        return bloom_frames
    end

    -- Real optical neon bloom aura for large titles and logos
    local function add_text_bloom(label, color)
        if runtime.low_cost then return {} end
        local parent = label.Parent
        local layers = {
            { thickness = 2, alpha = 0.45 },
            { thickness = 5, alpha = 0.70 },
            { thickness = 10, alpha = 0.88 },
        }
        local bloom_labels = {}
        for idx, layer in ipairs(layers) do
            local glow = create("TextLabel", {
                Name = "TextBloom_" .. idx,
                Text = label.Text,
                TextSize = label.TextSize,
                Font = label.Font,
                TextXAlignment = label.TextXAlignment,
                TextYAlignment = label.TextYAlignment,
                TextTruncate = label.TextTruncate,
                Position = label.Position,
                Size = label.Size,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = math.max(0, (label.ZIndex or 1) - 1),
                TextColor3 = color or C.neon,
                TextTransparency = layer.alpha,
                TextStrokeColor3 = color or C.neon,
                TextStrokeTransparency = layer.alpha,
            }, parent)
            table.insert(bloom_labels, glow)
        end
        return bloom_labels
    end

    local function text(parent, value, size, color, font)
        return create("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = value,
            TextSize = size or 14,
            TextColor3 = color or C.text,
            Font = font or F.body,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, parent)
    end

    local function place(object, x, y, width, height)
        object.Position = UDim2.fromOffset(x, y)
        object.Size = UDim2.fromOffset(width, height)
        return object
    end

    local function line(parent, y)
        return create("Frame", {
            BorderSizePixel = 0,
            BackgroundColor3 = C.line,
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, 1),
        }, parent)
    end

    local focus_image = create("Frame", {
        Name = "MonochromeFocus",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    })
    create("UIStroke", { Color = C.neon, Thickness = 1.5 }, focus_image)
    runtime.maid:give_task(focus_image)

    local function button(parent, name, label, callback)
        local is_rail = parent and parent.Name == "Navigation"
        local control = create("TextButton", {
            Name = name,
            Text = label,
            TextSize = 13,
            Font = F.body,
            TextColor3 = is_rail and C.muted or C.text,
            BackgroundColor3 = is_rail and C.rail or C.surface,
            BackgroundTransparency = is_rail and 1 or 0,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Selectable = true,
            SelectionImageObject = focus_image,
            SelectionOrder = #buttons + 1,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, parent)
        table.insert(buttons, control)

        local edge, glow
        if not is_rail then
            edge = create("UIStroke", {
                Name = "ButtonEdge",
                Color = C.neon,
                Transparency = 0.75,
                Thickness = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, control)

            glow = create("UIStroke", {
                Name = "ButtonGlow",
                Color = C.neon,
                Transparency = 0.96,
                Thickness = 4,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, control)
        end

        local press = create("UIScale", { Name = "Press", Scale = 1 }, control)

        local function activate()
            if not control.Active then return end
            if not system_reduced and not runtime.reduce_motion then
                animate(press, { Scale = 0.975 }, theme.motion.press)
                later(theme.motion.press, function()
                    if control.Parent then animate(press, { Scale = 1 }, theme.motion.hover) end
                end)
            end
            callback()
        end
        actions[control] = activate
        connect(control.Activated, activate)

        local function hover(on)
            if not control.Active then return end
            local inverted = control:GetAttribute("Inverted")
            if is_rail then
                local chosen = control:GetAttribute("Selected")
                animate(control, { TextColor3 = chosen and C.neon or (on and C.neon or C.muted) })
            else
                local color = inverted and C.ink or (on and C.neon or C.text)
                local base = C.surface
                animate(control, {
                    TextColor3 = color,
                    BackgroundColor3 = inverted and C.neon or (on and C.surface_hover or base),
                })
                if edge then animate(edge, { Transparency = on and 0.15 or 0.75 }) end
                if glow then animate(glow, { Transparency = on and 0.82 or 0.96 }) end
            end
        end
        connect(control.MouseEnter, function() hover(true) end)
        connect(control.MouseLeave, function() hover(false) end)
        connect(control.SelectionGained, function() hover(true) end)
        connect(control.SelectionLost, function() hover(false) end)
        return control
    end

    local function field(parent, name, placeholder)
        local control = create("TextBox", {
            Name = name,
            Text = "",
            PlaceholderText = placeholder or "",
            ClearTextOnFocus = false,
            Font = F.mono,
            TextSize = 13,
            TextColor3 = C.text,
            PlaceholderColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = C.surface,
            BorderSizePixel = 0,
            Selectable = true,
        }, parent)
        create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10) }, control)
        control.SelectionImageObject, control.SelectionOrder = focus_image, #buttons + 1
        table.insert(buttons, control)
        actions[control] = function() control:CaptureFocus() end

        local stroke = create("UIStroke", {
            Color = C.neon,
            Transparency = 0.75,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, control)
        local glow = create("UIStroke", {
            Color = C.neon,
            Transparency = 0.97,
            Thickness = 4,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, control)

        connect(control.Focused, function()
            animate(stroke, { Transparency = 0.1 })
            animate(glow, { Transparency = 0.82 })
        end)
        connect(control.FocusLost, function()
            animate(stroke, { Transparency = 0.75 })
            animate(glow, { Transparency = 0.97 })
        end)
        return control
    end

    local gui = create("ScreenGui", {
        Name = "Arteria",
        ResetOnSpawn = false,
        DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = false,
    }, game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
    runtime.gui = gui

    local panel = create(runtime.low_cost and "Frame" or "CanvasGroup", {
        Name = "Panel",
        BackgroundColor3 = C.ink,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(theme.width, theme.height),
        Active = true,
        ClipsDescendants = true,
    }, gui)

    -- Window Neon Bloom Glow Borders
    create("UIStroke", { Color = C.neon, Transparency = 0.45, Thickness = 1.5 }, panel)
    create("UIStroke", { Color = C.neon_glow, Transparency = 0.80, Thickness = 4 }, panel)
    create("UIStroke", { Color = C.neon_glow, Transparency = 0.94, Thickness = 10 }, panel)

    local sidebar = create("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = C.rail,
        BorderSizePixel = 0,
        Size = UDim2.new(0, theme.sidebar, 1, 0),
    }, panel)

    local rail_line = create("Frame", {
        BackgroundColor3 = C.line,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
    }, sidebar)

    local brand = text(sidebar, "ARTERIA", 28, C.neon, F.heading)
    brand.ZIndex = 2
    local brand_bloom = add_text_bloom(brand, C.neon)

    local edition = text(sidebar, "NEON LUXURY / 04", 10, C.muted, F.mono)

    local sections = table.clone(runtime.catalog.sections)
    table.insert(sections, "Automation")
    table.insert(sections, "Settings")

    local nav, rows = {}, {}
    local nav_list = create("ScrollingFrame", {
        Name = "Navigation",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, sidebar)

    -- Animated sliding active indicator pill in sidebar
    local active_pill = create("Frame", {
        Name = "ActiveIndicator",
        BackgroundColor3 = C.rail_active,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -24, 0, 40),
        Position = UDim2.fromOffset(12, 0),
        Visible = true,
        ZIndex = 1,
    }, nav_list)

    local pill_neon_bar = create("Frame", {
        Name = "NeonBar",
        BackgroundColor3 = C.neon,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.fromOffset(0, 6),
        ZIndex = 2,
    }, active_pill)
    add_neon_bloom(pill_neon_bar, C.neon, {
        { size = 4, alpha = 0.70 },
        { size = 8, alpha = 0.85 },
        { size = 14, alpha = 0.94 },
    })

    local content = create(runtime.low_cost and "Frame" or "CanvasGroup", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(theme.sidebar, 0),
        Size = UDim2.new(1, -theme.sidebar, 1, 0),
    }, panel)
    local content_home = UDim2.fromOffset(theme.sidebar, 0)

    local header = create("Frame", { Name = "Header", BackgroundTransparency = 1, Active = true }, content)
    local overline = text(header, "OPERATIONS / 01", 10, C.muted, F.mono)

    local title = text(header, "MOVEMENT", 46, C.neon, F.heading)
    title.ZIndex = 2
    local title_bloom = add_text_bloom(title, C.neon)

    local subtitle = text(header, "Control, without excess.", 13, C.muted)
    local search = field(content, "Search", "Search the collection")
    local scroll = create("ScrollingFrame", {
        Name = "Features",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.muted,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, content)
    create("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

    local empty = text(content, "Nothing matches.\nTry a feature name or another section.", 14, C.muted)
    empty.TextWrapped, empty.Visible = true, false

    local status = text(content, "INITIALIZING", 10, C.muted, F.mono)
    local ac = text(sidebar, "CLIENT LAYER\nPENDING", 10, C.muted, F.mono)
    ac.TextWrapped = true

    local motion_button = button(sidebar, "ReducedMotion", "REDUCE MOTION / OFF", function()
        runtime.reduce_motion = not runtime.reduce_motion
        if runtime.reduce_motion then
            finish_motion()
        end
        runtime.refresh()
    end)

    local entrance_version = 0
    local function stagger_rows()
        entrance_version += 1
        local version, count = entrance_version, 0
        for _, entry in ipairs(runtime.catalog.entries) do
            local item = rows[entry.id]
            if item then
                item.label.TextTransparency, item.toggle.TextTransparency = 0, 0
                if item.frame.Visible and count < 8 and not system_reduced and not runtime.reduce_motion then
                    count += 1
                    item.label.TextTransparency, item.toggle.TextTransparency = 0.65, 0.65
                    later(count * 0.018, function()
                        if version ~= entrance_version or not item.frame.Visible then return end
                        animate(item.label, { TextTransparency = 0 }, theme.motion.page)
                        animate(item.toggle, { TextTransparency = 0 }, theme.motion.page)
                    end)
                end
            end
        end
    end

    local function page(section)
        if not nav[section] then return end
        selected, capture = section, nil
        search.Text = ""
        scroll.CanvasPosition = Vector2.zero
        if section == "Settings" and runtime.config then
            local ok, err = pcall(runtime.config.list, runtime.config)
            if not ok then runtime.config.message = "ERROR / " .. tostring(err) end
        end
        runtime.refresh()
        if not system_reduced and not runtime.reduce_motion and not runtime.low_cost then
            content.GroupTransparency = 0.25
            content.Position = UDim2.fromOffset(content_home.X.Offset + 10, 0)
        end
        if runtime.low_cost then
            content.Position = content_home
        else
            animate(content, { GroupTransparency = 0, Position = content_home }, theme.motion.page)
        end
        title.TextTransparency = (system_reduced or runtime.reduce_motion) and 0 or 0.35
        animate(title, { TextTransparency = 0 }, theme.motion.page)
        stagger_rows()
    end
    runtime.navigate_ui = page

    for index, section in ipairs(sections) do
        local control = button(nav_list, "Nav" .. section, string.format("%02d   %s", index, string.upper(section)), function() page(section) end)
        control.TextXAlignment = Enum.TextXAlignment.Left
        control:SetAttribute("Rail", true)
        control.ZIndex = 3
        control.BackgroundTransparency = 1
        control.BackgroundColor3 = C.rail
        create("UIPadding", { PaddingLeft = UDim.new(0, 26) }, control)
        local marker = create("Frame", {
            Name = "Marker",
            BackgroundColor3 = C.neon,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 3, 1, -14),
            Position = UDim2.fromOffset(0, 7),
            Visible = false,
            ZIndex = 4,
        }, control)
        create("UIStroke", { Color = C.neon, Transparency = 0.88, Thickness = 3 }, marker)
        nav[section] = { control = control, marker = marker, index = index }
    end

    local visible_wanted, hide_thread = true, nil
    local visibility_version = 0
    local function show(visible)
        visible_wanted = visible
        visibility_version += 1
        local version = visibility_version
        if hide_thread then pcall(task.cancel, hide_thread); hide_thread = nil end
        if visible then panel.Visible = true end
        if not runtime.low_cost then
            animate(panel, { GroupTransparency = visible and 0 or 1 }, theme.motion.window)
        end
        if not visible then
            capture = nil
            if gui_service.SelectedObject and gui_service.SelectedObject:IsDescendantOf(panel) then gui_service.SelectedObject = nil end
            if system_reduced or runtime.reduce_motion then panel.Visible = false
            else hide_thread = task.delay(theme.motion.window, function() if visibility_version == version then panel.Visible = false end end) end
        end
    end
    runtime.maid:give_task(function() if hide_thread then pcall(task.cancel, hide_thread) end end)
    runtime.show_ui = show

    place(button(header, "Hide", "HIDE", function() show(false) end), 0, 0, 48, 36).AnchorPoint = Vector2.new(1, 0)
    local hide_button = header:FindFirstChild("Hide")

    local function can_edit(id)
        return runtime.status == "ready" and not runtime.busy and not (runtime.config and runtime.config.busy)
            and not (runtime.echo and runtime.echo.running and runtime.echo.owned[id] ~= nil)
    end

    for index, entry in ipairs(runtime.catalog.entries) do
        local frame = create("Frame", {
            Name = entry.id,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -6, 0, 72),
            LayoutOrder = index,
            ClipsDescendants = true,
        }, scroll)
        local label = text(frame, entry.label, 15)
        label.TextWrapped, label.TextTruncate = true, Enum.TextTruncate.None
        local note = text(frame, entry.note or "", 13, C.muted)
        local item = { frame = frame, label = label, note = note, entry = entry, expanded = false, fields = {} }
        rows[entry.id] = item

        local key = button(frame, "Bind", bindings[entry.id] and bindings[entry.id].Name or "—", function()
            if can_edit(entry.id) then capture = entry.id; runtime.refresh() end
        end)
        key.Font = F.mono

        local is_action = entry.kind == "action"
        local toggle = button(frame, "Toggle", is_action and "TP /" or "OFF", function()
            if can_edit(entry.id) then runtime:set(entry.id, not runtime.flags[entry.id]) end
        end)
        toggle.Font = F.mono
        toggle.ZIndex = 3

        -- Real optical neon bloom for active toggle state
        local toggle_bloom = add_neon_bloom(toggle, C.neon)
        item.toggle_bloom = toggle_bloom

        local details = button(frame, "Details", "+", function()
            item.expanded = not item.expanded
            runtime.refresh()
        end)
        details.Visible = #entry.settings > 0
        item.key, item.toggle, item.details = key, toggle, details

        local settings = create("Frame", { Name = "Settings", BackgroundTransparency = 1, Visible = false }, frame)
        item.settings = settings
        item.divider = line(frame, 71)

        for option_index, option in ipairs(entry.settings) do
            local y = (option_index - 1) * 42
            local caption = text(settings, option.label, 12, C.muted)
            caption.Position, caption.Size = UDim2.fromOffset(0, y), UDim2.new(0.5, -10, 0, 36)
            local control
            if option.values then
                control = button(settings, option.id, tostring(runtime.flags[option.id]), function()
                    if not can_edit(entry.id) then return end
                    local current = table.find(option.values, runtime.flags[option.id]) or 1
                    runtime:option(option, option.values[current % #option.values + 1])
                    runtime.refresh()
                end)
            else
                control = field(settings, option.id)
                control.Text = tostring(runtime.flags[option.id])
                connect(control.FocusLost, function()
                    local value = tonumber(control.Text)
                    if can_edit(entry.id) and value and value == value and math.abs(value) < math.huge then
                        value = math.clamp(math.floor(value * 100 + 0.5) / 100, option.low, option.high)
                        if option.id == "min_speed_mult" or option.id == "max_speed_mult" then value = math.floor(value) end
                        runtime:option(option, value)
                    end
                    control.Text = tostring(runtime.flags[option.id])
                end)
            end
            control.Position, control.Size = UDim2.new(0.5, 0, 0, y), UDim2.new(0.5, 0, 0, 36)
            table.insert(item.fields, { control = control, option = option })
        end
    end

    -- Automation / Echoes
    local echo_page = create("ScrollingFrame", {
        Name = "Automation",
        Visible = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
    }, content)

    local echo_body = create("Frame", { Name = "Cycle", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 510) }, echo_page)
    local echo_title = text(echo_body, "A controlled reset.", 30, C.neon, F.heading)
    echo_title.Position, echo_title.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 48)

    local warning = text(echo_body, "SOUP ECHO CYCLE\nCollect ingredients. Craft soup. Reset and repeat.\n\nThis routine intentionally kills, WIPES and recreates the selected character slot. Use only a disposable slot. Stop cannot undo a wipe already sent.", 13, C.muted)
    warning.TextWrapped, warning.TextYAlignment, warning.TextTruncate = true, Enum.TextYAlignment.Top, Enum.TextTruncate.None
    warning.Position, warning.Size = UDim2.fromOffset(0, 58), UDim2.new(1, 0, 0, 144)
    line(echo_body, 214)

    local metrics = text(echo_body, "00 CYCLES / 00 ECHOES", 15, C.neon, F.mono)
    metrics.Position, metrics.Size = UDim2.fromOffset(0, 230), UDim2.new(1, 0, 0, 28)

    local farm_state = text(echo_body, "IDLE", 12, C.muted, F.mono)
    farm_state.Position, farm_state.Size = UDim2.fromOffset(0, 262), UDim2.new(1, 0, 0, 30)

    local slot_label = text(echo_body, "CONFIRM CURRENT SLOT", 10, C.muted, F.mono)
    slot_label.Position, slot_label.Size = UDim2.fromOffset(0, 307), UDim2.new(1, 0, 0, 18)

    local slot_field = field(echo_body, "SlotConfirmation", "Type the slot shown above")
    slot_field.Position, slot_field.Size = UDim2.fromOffset(0, 335), UDim2.new(1, 0, 0, 38)

    local acknowledged = false
    local acknowledge = button(echo_body, "AcknowledgeWipe", "[ ] I ACCEPT SLOT DELETION AND RECREATION", function()
        acknowledged = not acknowledged
        runtime.refresh()
    end)
    acknowledge.TextXAlignment = Enum.TextXAlignment.Left
    acknowledge.TextWrapped = true
    acknowledge.Position, acknowledge.Size = UDim2.fromOffset(0, 381), UDim2.new(1, 0, 0, 40)

    local start = button(echo_body, "StartEcho", "START CYCLE", function()
        if not runtime.echo or not acknowledged then return end
        local slot = tostring(game:GetService("Players").LocalPlayer:GetAttribute("DataSlot") or "")
        if slot == "" or slot_field.Text ~= slot then return end
        runtime.echo:start(slot_field.Text)
        acknowledged, slot_field.Text = false, ""
        runtime.refresh()
    end)
    start.Position, start.Size = UDim2.fromOffset(0, 435), UDim2.new(0.5, -6, 0, 42)

    local stop = button(echo_body, "StopEcho", "STOP CYCLE", function()
        if runtime.echo then runtime.echo:stop("stopped") end
    end)
    stop.Position, stop.Size = UDim2.new(0.5, 6, 0, 435), UDim2.new(0.5, -6, 0, 42)
    connect(slot_field:GetPropertyChangedSignal("Text"), function() runtime.refresh() end)

    -- Settings Page (Art-directed matching preview)
    local settings_page = create("ScrollingFrame", {
        Name = "SettingsPage",
        Visible = false,
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, content)

    local settings_body = create("Frame", {
        Name = "Profiles",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 560 + #runtime.catalog.entries * 50),
    }, settings_page)

    local profile_title = text(settings_body, "YOUR CONFIGURATION", 30, C.neon, F.heading)
    profile_title.Position, profile_title.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 42)

    local profile_note = text(settings_body, "One-click profile selection, instant save/load, and startup autoloading.\nAutoload automatically applies your saved profile on launch.", 13, C.muted)
    profile_note.TextWrapped, profile_note.TextTruncate = true, Enum.TextTruncate.None
    profile_note.Position, profile_note.Size = UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 48)

    local chips_label = text(settings_body, "SAVED PROFILES (CLICK TO SELECT)", 10, C.neon, F.mono)
    chips_label.Position, chips_label.Size = UDim2.fromOffset(0, 102), UDim2.new(1, 0, 0, 18)

    local chips_scroll = create("ScrollingFrame", {
        Name = "ProfileChips",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 124),
        Size = UDim2.new(1, 0, 0, 36),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
    }, settings_body)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, chips_scroll)

    local chip_buttons = {}

    local name_label = text(settings_body, "ACTIVE PROFILE NAME", 10, C.neon, F.mono)
    name_label.Position, name_label.Size = UDim2.fromOffset(0, 168), UDim2.new(1, 0, 0, 18)

    local profile_name = field(settings_body, "ProfileName", "e.g. combat or movement")
    profile_name.Position, profile_name.Size = UDim2.fromOffset(0, 190), UDim2.new(1, 0, 0, 40)

    local delete_armed, restore_flags = nil, false
    local function config_action(callback)
        if not runtime.config or runtime.config.busy then return end
        capture, runtime.config.busy = nil, true
        local ok, err = pcall(callback)
        runtime.config.busy = false
        if not ok then runtime.config.message = "ERROR / " .. tostring(err) end
        runtime.refresh()
    end

    local save = button(settings_body, "SaveProfile", "SAVE / UPDATE", function()
        config_action(function() runtime.config:save(profile_name.Text) end)
    end)
    save.Position, save.Size = UDim2.fromOffset(0, 238), UDim2.new(0.32, -4, 0, 42)
    save:SetAttribute("Inverted", true)
    save.BackgroundColor3, save.TextColor3 = C.neon, C.ink
    save.ZIndex = 3
    add_neon_bloom(save, C.neon)

    local load = button(settings_body, "LoadProfile", "LOAD", function()
        config_action(function() runtime.config:load(profile_name.Text, restore_flags) end)
    end)
    load.Position, load.Size = UDim2.new(0.33, 2, 0, 238), UDim2.new(0.32, -4, 0, 42)

    local delete = button(settings_body, "DeleteProfile", "DELETE", function()
        if delete_armed ~= profile_name.Text then delete_armed = profile_name.Text; runtime.refresh(); return end
        config_action(function() runtime.config:delete(profile_name.Text); delete_armed = nil end)
    end)
    delete.Position, delete.Size = UDim2.new(0.66, 6, 0, 238), UDim2.new(0.34, -6, 0, 42)
    delete.TextColor3 = C.alert

    local autoload_btn = button(settings_body, "AutoloadButton", "SET AS AUTOLOAD", function()
        config_action(function()
            local auto_name = runtime.config:get_autoload()
            if auto_name == profile_name.Text then
                runtime.config:clear_autoload()
            else
                runtime.config:set_autoload(profile_name.Text, restore_flags)
            end
        end)
    end)
    autoload_btn.Position, autoload_btn.Size = UDim2.fromOffset(0, 288), UDim2.new(0.48, -4, 0, 38)

    local restore = button(settings_body, "RestoreToggles", "[ ] RESTORE TOGGLES", function()
        restore_flags = not restore_flags
        runtime.refresh()
    end)
    restore.Position, restore.Size = UDim2.new(0.50, 4, 0, 288), UDim2.new(0.50, -4, 0, 38)
    restore.TextWrapped, restore.TextXAlignment = true, Enum.TextXAlignment.Left

    local config_status = text(settings_body, "", 13, C.neon)
    config_status.TextWrapped, config_status.TextTruncate = true, Enum.TextTruncate.None
    config_status.Position, config_status.Size = UDim2.fromOffset(0, 334), UDim2.new(1, 0, 0, 36)
    line(settings_body, 378)

    local bind_title = text(settings_body, "KEYBINDS / CLICK TO REBIND", 11, C.neon, F.mono)
    bind_title.Position, bind_title.Size = UDim2.fromOffset(0, 392), UDim2.new(1, 0, 0, 24)

    local ui_bind = button(settings_body, "MenuKey", "UI KEY / RIGHTSHIFT", function()
        capture = "__menu"
        runtime.refresh()
    end)
    ui_bind.Position, ui_bind.Size = UDim2.fromOffset(0, 422), UDim2.new(1, 0, 0, 42)

    local bind_rows = {}
    for index, entry in ipairs(runtime.catalog.entries) do
        local y = 478 + (index - 1) * 48
        local label = text(settings_body, entry.label, 14)
        label.Position, label.Size = UDim2.fromOffset(0, y), UDim2.new(1, -100, 0, 36)
        label.TextWrapped, label.TextTruncate = true, Enum.TextTruncate.None
        local control = button(settings_body, "ConfigBind_" .. entry.id, "—", function()
            capture = entry.id
            runtime.refresh()
        end)
        control.Position, control.Size = UDim2.new(1, -92, 0, y), UDim2.fromOffset(92, 36)
        bind_rows[entry.id] = control
    end
    connect(profile_name:GetPropertyChangedSignal("Text"), function() delete_armed = nil; runtime.refresh() end)

    local function layout_rows(instant)
        for _, item in pairs(rows) do
            local base = compact and 120 or 80
            local height = base + (item.expanded and (#item.entry.settings * 42 + 12) or 0)
            if item.height ~= height then
                if item.height and not instant then
                    animate(item.frame, { Size = UDim2.new(1, -6, 0, height) }, theme.motion.expand)
                else
                    item.frame.Size = UDim2.new(1, -6, 0, height)
                end
                item.height = height
            elseif instant then
                item.frame.Size = UDim2.new(1, -6, 0, height)
            end
            item.label.Position, item.label.Size = UDim2.fromOffset(0, 12), UDim2.new(1, -146, 0, compact and 56 or 26)
            item.note.Position, item.note.Size = UDim2.fromOffset(0, compact and 78 or 46), UDim2.new(1, -8, 0, 28)
            item.key.Position, item.key.Size = UDim2.new(1, -136, 0, 13), UDim2.fromOffset(36, 36)
            item.details.Position, item.details.Size = UDim2.new(1, -96, 0, 13), UDim2.fromOffset(30, 36)
            item.toggle.Position, item.toggle.Size = UDim2.new(1, -62, 0, 13), UDim2.fromOffset(62, 36)
            item.settings.Position, item.settings.Size = UDim2.fromOffset(0, base), UDim2.new(1, 0, 0, #item.entry.settings * 42)
            item.settings.Visible = item.expanded
            item.divider.Position = UDim2.fromOffset(0, height - 1)
        end
    end

    local function fit()
        finish_motion()
        local viewport = gui.AbsoluteSize
        local width, height = math.max(1, math.min(theme.width, viewport.X - 24)), math.max(1, math.min(theme.height, viewport.Y - 24))
        compact = width < 600 or height < 440
        local rail, pad = compact and theme.compact_sidebar or theme.sidebar, compact and 16 or 30
        panel.Size = UDim2.fromOffset(width, height)
        panel.Position = UDim2.fromScale(0.5, 0.5)
        sidebar.Size = UDim2.new(0, rail, 1, 0)
        content_home = UDim2.fromOffset(rail, 0)
        content.Position, content.Size = content_home, UDim2.new(1, -rail, 1, 0)

        place(brand, compact and 15 or 24, 25, rail - (compact and 15 or 32), 40)
        brand.Text = compact and "A" or "ARTERIA"
        for _, b_label in ipairs(brand_bloom) do place(b_label, compact and 15 or 24, 25, rail - (compact and 15 or 32), 40); b_label.Text = brand.Text end
        place(edition, 24, 70, rail - 30, 18); edition.Visible = not compact and height >= 480

        local nav_gap = math.min(46, math.max(28, (height - 180) / #sections))
        local nav_top = height < 480 and 80 or 125
        nav_list.Position, nav_list.Size = UDim2.fromOffset(0, nav_top), UDim2.new(1, 0, 0, math.max(1, height - nav_top - (compact and 60 or 118)))
        nav_list.CanvasSize = UDim2.fromOffset(0, #sections * nav_gap)

        active_pill.Size = UDim2.new(1, compact and -8 or -24, 0, math.min(42, nav_gap - 4))
        active_pill.Position = UDim2.fromOffset(compact and 4 or 12, (nav[selected].index - 1) * nav_gap)

        for section, item in pairs(nav) do
            place(item.control, compact and 4 or 12, (item.index - 1) * nav_gap, rail - (compact and 8 or 24), math.min(42, nav_gap - 4))
            local short = { Movement = "MOV", Combat = "CBT", Visuals = "VIS", World = "WRL", Removals = "REM", Automation = "AUT", Settings = "SET" }
            item.control.Text = compact and short[section] or string.format("%02d   %s", item.index, string.upper(section))
            item.control.Font = compact and F.mono or F.body
            item.control:FindFirstChild("UIPadding").PaddingLeft = UDim.new(0, compact and 12 or 26)
        end

        ac.Position, ac.Size, ac.Visible = UDim2.new(0, 24, 1, -102), UDim2.fromOffset(rail - 32, 40), not compact and height >= 480
        motion_button.Position, motion_button.Size = UDim2.new(0, compact and 4 or 24, 1, -48), UDim2.fromOffset(rail - (compact and 8 or 36), 32)
        header.Position, header.Size = UDim2.fromOffset(pad, 0), UDim2.new(1, -pad * 2, 0, 128)
        place(overline, 0, 25, width - rail - pad * 2 - 50, 18)
        title.Position, title.Size = UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 52)
        title.TextSize = compact and 34 or 46
        for _, t_label in ipairs(title_bloom) do
            t_label.Position, t_label.Size, t_label.TextSize = title.Position, title.Size, title.TextSize
        end

        subtitle.Position, subtitle.Size = UDim2.fromOffset(0, 104), UDim2.new(1, 0, 0, 22)
        hide_button.Position = UDim2.new(1, 0, 0, 20)
        search.Position, search.Size = UDim2.fromOffset(pad, 148), UDim2.new(1, -pad * 2, 0, 38)
        scroll.Position, scroll.Size = UDim2.fromOffset(pad, 200), UDim2.new(1, -pad * 2, 1, -244)
        echo_page.Position, echo_page.Size = UDim2.fromOffset(pad, 148), UDim2.new(1, -pad * 2, 1, -192)
        settings_page.Position, settings_page.Size = echo_page.Position, echo_page.Size
        empty.Position, empty.Size = UDim2.fromOffset(pad, 218), UDim2.new(1, -pad * 2, 0, 72)
        status.Position, status.Size = UDim2.new(0, pad, 1, -32), UDim2.new(1, -pad * 2, 0, 20)
        profile_title.TextSize, profile_note.TextSize = compact and 24 or 30, compact and 13 or 14
        layout_rows(true)
    end

    function runtime.refresh()
        if not runtime.alive then return end
        if runtime.reduce_motion or system_reduced then finish_motion() end
        local query, shown, active = string.lower(search.Text), 0, 0
        local focused = input:GetFocusedTextBox()
        local is_echo, is_settings = selected == "Automation", selected == "Settings"
        local is_custom = is_echo or is_settings

        for id, item in pairs(rows) do
            local enabled = runtime.flags[id] == true
            if enabled then active += 1 end
            item.frame.Visible = not is_custom and (query ~= "" or item.entry.section == selected)
                and (query == "" or string.find(string.lower(item.entry.label), query, 1, true) ~= nil)
            if item.frame.Visible then shown += 1 end

            if item.entry.kind == "action" then
                item.toggle.Text = "TP /"
                item.toggle:SetAttribute("Inverted", false)
                item.toggle.BackgroundColor3, item.toggle.TextColor3 = C.surface, C.neon
                if item.toggle_bloom then for _, b in ipairs(item.toggle_bloom) do b.Visible = false end end
            else
                item.toggle.Text = enabled and "ON /" or "OFF"
                item.toggle:SetAttribute("Inverted", enabled)
                if item.last_enabled ~= nil and item.last_enabled ~= enabled then
                    animate(item.toggle, { BackgroundColor3 = enabled and C.neon or C.surface, TextColor3 = enabled and C.ink or C.text }, theme.motion.hover)
                elseif item.last_enabled == nil then
                    item.toggle.BackgroundColor3, item.toggle.TextColor3 = enabled and C.neon or C.surface, enabled and C.ink or C.text
                end
                if item.toggle_bloom then
                    for _, b in ipairs(item.toggle_bloom) do b.Visible = enabled end
                end
                item.last_enabled = enabled
            end

            item.toggle.Active, item.key.Active = can_edit(id), can_edit(id)
            item.key.Text = capture == id and "…" or (bindings[id] and bindings[id].Name or "—")
            item.details.Text = item.expanded and "−" or "+"
            item.note.Text = runtime.errors[id] and ("UNAVAILABLE / " .. (tostring(runtime.errors[id]):match("[^\n]+") or "Unknown error"))
                or (runtime.echo and runtime.echo.running and runtime.echo.owned[id] ~= nil and "ECHO CYCLE / managed until stopped") or item.entry.note or ""

            for _, value in ipairs(item.fields) do
                if value.control ~= focused then value.control.Text = tostring(runtime.flags[value.option.id]) end
                if not value.option.values then value.control.TextEditable = can_edit(id) end
            end
        end

        for section, item in pairs(nav) do
            local chosen = section == selected
            item.control:SetAttribute("Selected", chosen)
            item.control.TextColor3 = chosen and C.neon or C.muted
            item.control.BackgroundColor3 = C.rail
            item.control.BackgroundTransparency = 1
        end

        if nav[selected] then
            local target_y = (nav[selected].index - 1) * math.min(46, math.max(28, (panel.AbsoluteSize.Y - 180) / #sections))
            animate(active_pill, { Position = UDim2.fromOffset(compact and 4 or 12, target_y) }, theme.motion.page)
        end

        local index = nav[selected] and nav[selected].index or 1
        title.Text = query ~= "" and not is_custom and "COLLECTION" or string.upper(selected)
        for _, t_label in ipairs(title_bloom) do t_label.Text = title.Text end

        overline.Text = string.format("OPERATIONS / %02d", index)
        subtitle.Text = capture and "Press a key. Escape cancels. Backspace clears."
            or (is_echo and "ECHO FARM / SOUP CYCLE" or (is_settings and "One-click profile selection, instant save/load, and startup autoloading." or "Control, without excess."))

        scroll.Visible, search.Visible, echo_page.Visible, settings_page.Visible = not is_custom, not is_custom, is_echo, is_settings
        empty.Visible = not is_custom and shown == 0

        status.Text = string.format("%s  /  %02d ENABLED  /  %02d SHOWN", string.upper(runtime.busy and "loading module" or runtime.status), active, shown)
        ac.Text = runtime.ac_loaded and "CLIENT LAYER\nLOADED · UNVERIFIED" or "CLIENT LAYER\nPENDING"
        motion_button.Text = compact and ((runtime.reduce_motion or system_reduced) and "RM ON" or "RM —")
            or ((runtime.reduce_motion or system_reduced) and "REDUCE MOTION / ON" or "REDUCE MOTION / OFF")

        local echo = runtime.echo
        if echo then
            local slot = tostring(game:GetService("Players").LocalPlayer:GetAttribute("DataSlot") or "unavailable")
            slot_label.Text = "CONFIRM CURRENT SLOT / " .. slot
            metrics.Text = string.format("%02d CYCLES / %02d ECHOES", echo.session.cycles or 0, echo.session.echoes or 0)
            farm_state.Text = echo.error or string.upper(echo.running and (echo.farm and echo.farm.state_machine.current or echo.state) or echo.state)
            acknowledge.Text = (acknowledged and "[X] " or "[ ] ") .. "I ACCEPT SLOT DELETION AND RECREATION"
            start.Active = not echo.running and acknowledged and slot_field.Text == slot and slot ~= "unavailable" and runtime.status == "ready" and not runtime.busy
            start.Text = echo.running and "RUNNING" or ("START / WIPE " .. slot)
            start.BackgroundColor3, start.TextColor3 = start.Active and C.neon or C.surface, start.Active and C.ink or C.muted
            start:SetAttribute("Inverted", start.Active)
            stop.Active = echo.running or echo.session.enabled == true
            stop.TextColor3 = stop.Active and C.text or C.muted
        end

        local menu_key = runtime.ui_key or Enum.KeyCode.RightShift
        ui_bind.Text = capture == "__menu" and "UI KEY / PRESS A KEY" or ("UI KEY / " .. string.upper(menu_key.Name))
        for id, control in pairs(bind_rows) do control.Text = capture == id and "…" or (bindings[id] and bindings[id].Name or "—") end

        delete.Text = delete_armed == profile_name.Text and delete_armed ~= nil and "CONFIRM" or "DELETE"
        delete.TextColor3 = C.alert
        restore.Text = (restore_flags and "[X] " or "[ ] ") .. "RESTORE TOGGLES"

        local auto_name, auto_flags = runtime.config and runtime.config:get_autoload()
        if auto_name and auto_name == profile_name.Text then
            autoload_btn.Text = "AUTOLOAD: ON (★)"
            autoload_btn:SetAttribute("Inverted", true)
            autoload_btn.BackgroundColor3, autoload_btn.TextColor3 = C.neon, C.ink
        else
            autoload_btn.Text = auto_name and ("SET AS AUTOLOAD (CURRENT: " .. auto_name .. ")") or "SET AS AUTOLOAD"
            autoload_btn:SetAttribute("Inverted", false)
            autoload_btn.BackgroundColor3, autoload_btn.TextColor3 = C.surface, C.neon
        end

        local profiles_list = runtime.config and runtime.config.profiles or {}
        for idx, p_name in ipairs(profiles_list) do
            local chip = chip_buttons[idx]
            if not chip then
                chip = button(chips_scroll, "Chip_" .. idx, p_name, function()
                    profile_name.Text = p_name
                    delete_armed = nil
                    runtime.refresh()
                end)
                chip.Size = UDim2.fromOffset(92, 32)
                chip.Font = F.mono
                chip.TextSize = 11
                table.insert(chip_buttons, chip)
            end
            local is_sel = profile_name.Text == p_name
            local is_auto = auto_name == p_name
            chip.Text = (is_auto and "★ " or "") .. p_name
            chip:SetAttribute("Inverted", is_sel)
            chip.BackgroundColor3, chip.TextColor3 = is_sel and C.neon or C.surface, is_sel and C.ink or (is_auto and C.neon or C.text)
            chip.Visible = true
        end
        for idx = #profiles_list + 1, #chip_buttons do
            chip_buttons[idx].Visible = false
        end

        local message = runtime.config and runtime.config.message or "Configuration storage is unavailable."
        config_status.Text = "STATUS: " .. message

        layout_rows()
    end

    connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function() fit(); runtime.refresh() end)
    connect(search:GetPropertyChangedSignal("Text"), function() scroll.CanvasPosition = Vector2.zero; capture = nil; runtime.refresh() end)
    pcall(function()
        connect(gui_service:GetPropertyChangedSignal("ReducedMotionEnabled"), function()
            read_motion()
            if system_reduced then finish_motion() end
            runtime.refresh()
        end)
    end)

    local function selectable(control)
        if not control.Active or not control.Selectable then return false end
        local ancestor = control
        while ancestor and ancestor ~= gui do
            if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
            ancestor = ancestor.Parent
        end
        return ancestor == gui and panel.Visible
    end

    local function focus_next()
        local list = {}
        for _, control in ipairs(buttons) do if selectable(control) then table.insert(list, control) end end
        if #list > 0 then
            local current = table.find(list, gui_service.SelectedObject) or 0
            local direction = input:IsKeyDown(Enum.KeyCode.LeftShift) and -1 or 1
            local index = current == 0 and (direction == 1 and 1 or #list) or ((current - 1 + direction) % #list + 1)
            gui_service.SelectedObject = list[index]
        end
    end

    connect(input.InputBegan, function(event, processed)
        local focused = input:GetFocusedTextBox()
        if event.KeyCode == Enum.KeyCode.Tab and panel.Visible and not capture
            and ((focused and focused:IsDescendantOf(panel)) or (not focused and not processed)) then
            if focused then focused:ReleaseFocus() end
            focus_next()
            return
        end
        if focused then return end

        if capture and event.UserInputType == Enum.UserInputType.Keyboard then
            if event.KeyCode == Enum.KeyCode.Escape then capture = nil; runtime.refresh(); return end
            if event.KeyCode == Enum.KeyCode.Backspace then if capture ~= "__menu" then bindings[capture] = nil end; capture = nil; runtime.refresh(); return end
            if processed or event.KeyCode == Enum.KeyCode.Unknown or event.KeyCode == Enum.KeyCode.V or event.KeyCode == Enum.KeyCode.Tab or event.KeyCode == Enum.KeyCode.Return then return end
            if capture ~= "__menu" and event.KeyCode == (runtime.ui_key or Enum.KeyCode.RightShift) then return end
            for other, key in pairs(bindings) do if other ~= capture and key == event.KeyCode then return end end
            if capture == "__menu" then runtime.ui_key = event.KeyCode else bindings[capture] = event.KeyCode end
            capture = nil
            runtime.refresh()
            return
        end

        if processed then return end
        if event.KeyCode == (runtime.ui_key or Enum.KeyCode.RightShift) then show(not visible_wanted); return end
        if event.KeyCode == Enum.KeyCode.Escape and panel.Visible then show(false); return end
        if event.KeyCode == Enum.KeyCode.Return and panel.Visible then
            local selected_control = gui_service.SelectedObject
            if selected_control and actions[selected_control] and selectable(selected_control) then actions[selected_control]() end
            return
        end
        if event.KeyCode == Enum.KeyCode.V then
            local feature_inst = runtime.features.auto_dustlunge
            if feature_inst and runtime.flags.auto_dustlunge then feature_inst.held = true end
            return
        end
        for id, key in pairs(bindings) do
            if event.KeyCode == key and can_edit(id) then runtime:set(id, not runtime.flags[id]); return end
        end
    end)

    local dragging, origin, initial
    connect(header.InputBegan, function(event)
        if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
            dragging, origin, initial = event, event.Position, panel.AbsolutePosition + panel.AbsoluteSize / 2
        end
    end)
    connect(input.InputChanged, function(event)
        if not dragging or (event.UserInputType ~= Enum.UserInputType.MouseMovement and event ~= dragging) then return end
        local delta, size, half = event.Position - origin, gui.AbsoluteSize, panel.AbsoluteSize / 2
        panel.Position = UDim2.fromOffset(
            math.clamp(initial.X + delta.X, half.X, math.max(half.X, size.X - half.X)),
            math.clamp(initial.Y + delta.Y, half.Y, math.max(half.Y, size.Y - half.Y))
        )
    end)
    connect(input.InputEnded, function(event)
        if event == dragging then dragging = nil end
        if event.KeyCode == Enum.KeyCode.V and runtime.features.auto_dustlunge then runtime.features.auto_dustlunge.held = false end
    end)
    connect(input.WindowFocusReleased, function()
        dragging = nil
        if runtime.features.auto_dustlunge then runtime.features.auto_dustlunge.held = false end
        if runtime.features.m1_hold then runtime.features.m1_hold.held = false end
    end)

    fit()
    runtime.refresh()

    if not runtime.low_cost then
        panel.GroupTransparency = (system_reduced or runtime.reduce_motion) and 0 or 1
        animate(panel, { GroupTransparency = 0 }, theme.motion.window)
    end
end

return UI
