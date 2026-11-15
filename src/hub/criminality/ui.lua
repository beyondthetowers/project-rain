--[[
    src/hub/criminality/ui.lua

    Self-contained window toolkit for the Criminality hub: tabs, sections,
    toggles, sliders, dropdowns, keybinds, text fields and buttons.
    No external UI library, no image assets, no fonts to download.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local State = require("@src/hub/criminality/state")

local UI = {}
UI.__index = UI

local Tween = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local THEME = {
    window = Color3.fromRGB(12, 12, 17),
    panel = Color3.fromRGB(18, 18, 25),
    panel2 = Color3.fromRGB(23, 23, 32),
    stroke = Color3.fromRGB(38, 38, 51),
    text = Color3.fromRGB(232, 232, 240),
    muted = Color3.fromRGB(138, 138, 158),
    accent = Color3.fromRGB(84, 101, 255),
    accent2 = Color3.fromRGB(61, 220, 151),
    danger = Color3.fromRGB(255, 92, 92),
}

local function create(class, props, parent)
    local instance = Instance.new(class)

    for property, value in next, props or {} do
        if property ~= "Parent" then
            instance[property] = value
        end
    end

    if parent then
        instance.Parent = parent
    end

    return instance
end

local function corner(instance, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, instance)
end

local function stroke(instance, color, thickness)
    return create("UIStroke", {
        Color = color or THEME.stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, instance)
end

local function label(parent, text, size, color, font)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextSize = size or 13,
        TextColor3 = color or THEME.text,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end

local function tween(instance, props)
    TweenService:Create(instance, Tween, props):Play()
end

-- parents popups here so they are never clipped by a scrolling frame
local function popupLayer(screenGui, windowFrame)
    local layer = create("Frame", {
        Name = "Popups",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 50,
        Visible = false,
    }, screenGui)

    return layer
end

--------------------------------------------------------------------------
-- controls
--------------------------------------------------------------------------

local Control = {}
Control.__index = Control

function Control:set(value, internal)
    State.set(self.key, value, internal)
    self:render(value)
end

function Control:onChanged(callback)
    State.on(self.key, callback)

    return self
end

function Control:addToggle(parent, key, text, callback)
    local control = setmetatable({ key = key, kind = "toggle" }, Control)
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 26),
        LayoutOrder = #parent.rows,
    }, parent.body)

    table.insert(parent.rows, row)

    local caption = label(row, text, 13, THEME.muted)
    caption.Size = UDim2.new(1, -60, 1, 0)
    caption.Position = UDim2.fromOffset(0, 0)

    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(34, 18),
        BackgroundColor3 = THEME.panel2,
    }, row)
    corner(pill, 9)
    stroke(pill, THEME.stroke)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = THEME.muted,
    }, pill)
    corner(knob, 7)

    local click = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
    }, pill)

    function control:render(value)
        local on = value == true

        tween(pill, { BackgroundColor3 = on and THEME.accent or THEME.panel2 })
        tween(knob, {
            Position = UDim2.new(0, on and 18 or 2, 0.5, 0),
            BackgroundColor3 = on and Color3.new(1, 1, 1) or THEME.muted,
        })
        tween(caption, { TextColor3 = on and THEME.text or THEME.muted })
    end

    click.MouseButton1Click:Connect(function()
        local next_value = not State.get(key)
        control:set(next_value)

        if callback then
            task.spawn(callback, next_value)
        end
    end)

    control:render(State.get(key))

    return control
end

function Control:addSlider(parent, key, text, min, max, step, callback, suffix)
    local control = setmetatable({ key = key, kind = "slider" }, Control)
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 40),
        LayoutOrder = #parent.rows,
    }, parent.body)

    table.insert(parent.rows, row)

    local caption = label(row, text, 13, THEME.muted)
    caption.Size = UDim2.new(1, -80, 0, 18)
    caption.Position = UDim2.fromOffset(0, 0)

    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(74, 18),
        Position = UDim2.new(1, -74, 0, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = THEME.text,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "",
    }, row)

    local track = create("Frame", {
        BackgroundColor3 = THEME.panel2,
        Position = UDim2.fromOffset(0, 27),
        Size = UDim2.new(1, 0, 0, 4),
    }, row)
    corner(track, 2)
    stroke(track, THEME.stroke)

    local fill = create("Frame", {
        BackgroundColor3 = THEME.accent,
        Size = UDim2.fromScale(0, 1),
    }, track)
    corner(fill, 2)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 2,
    }, track)
    corner(knob, 5)

    local hitbox = create("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 15),
        Size = UDim2.new(1, 0, 0, 25),
        Text = "",
    }, row)

    local function format(value)
        local rounded = math.floor(value * 100 + 0.5) / 100
        local text_value = tostring(rounded)

        if rounded == math.floor(rounded) then
            text_value = tostring(math.floor(rounded))
        end

        return text_value .. (suffix or "")
    end

    local function snap(value)
        if step and step > 0 then
            value = math.floor(value / step + 0.5) * step
        end

        return math.clamp(value, min, max)
    end

    function control:render(value)
        local alpha = (value - min) / math.max(max - min, 0.0001)
        fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
        knob.Position = UDim2.new(math.clamp(alpha, 0, 1), 0, 0.5, 0)
        valueLabel.Text = format(value)
    end

    local dragging = false

    local function applyFromInput(input)
        local relative = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
        local value = snap(min + (max - min) * math.clamp(relative, 0, 1))
        control:set(value)

        if callback then
            callback(value)
        end
    end

    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            applyFromInput(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            applyFromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    control:render(State.get(key))

    return control
end

function Control:addDropdown(parent, key, text, options, callback)
    local control = setmetatable({ key = key, kind = "dropdown" }, Control)
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 26),
        LayoutOrder = #parent.rows,
    }, parent.body)

    table.insert(parent.rows, row)

    local caption = label(row, text, 13, THEME.muted)
    caption.Size = UDim2.new(1, -150, 1, 0)

    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(140, 22),
        BackgroundColor3 = THEME.panel2,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = THEME.text,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(button, 4)
    stroke(button, THEME.stroke)

    local arrow = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 22),
        Position = UDim2.new(1, -20, 0, 0),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = THEME.muted,
        Text = "v",
    }, button)

    local current = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = THEME.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "",
    }, button)

    local popup
    local blocker
    local layer = parent.tab.window.popupLayer

    local function closePopup()
        if popup then
            popup:Destroy()
            popup = nil
        end

        if blocker then
            blocker:Destroy()
            blocker = nil
        end

        layer.Visible = false
    end

    local function openPopup()
        closePopup()
        layer.Visible = true

        blocker = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 55,
        }, layer)

        blocker.MouseButton1Click:Connect(closePopup)

        local height = math.min(#options, 8) * 22 + 8
        popup = create("Frame", {
            BackgroundColor3 = THEME.panel,
            Size = UDim2.fromOffset(button.AbsoluteSize.X, height),
            Position = UDim2.fromOffset(button.AbsolutePosition.X, button.AbsolutePosition.Y + button.AbsoluteSize.Y + 4),
            ZIndex = 60,
        }, layer)
        corner(popup, 4)
        stroke(popup, THEME.stroke)

        local scroll = create("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(0, 0, 0, #options * 22),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = THEME.stroke,
            ZIndex = 60,
        }, popup)

        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

        for index, option in ipairs(options) do
            local item = create("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -6, 0, 22),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextColor3 = State.get(key) == option and THEME.accent or THEME.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "  " .. tostring(option),
                LayoutOrder = index,
                ZIndex = 60,
            }, scroll)

            item.MouseEnter:Connect(function()
                item.BackgroundTransparency = 0.9
            end)

            item.MouseLeave:Connect(function()
                item.BackgroundTransparency = 1
            end)

            item.MouseButton1Click:Connect(function()
                control:set(option)
                closePopup()

                if callback then
                    task.spawn(callback, option)
                end
            end)
        end
    end

    button.MouseButton1Click:Connect(function()
        if popup then
            closePopup()
        else
            openPopup()
        end
    end)

    function control:render(value)
        current.Text = tostring(value)
    end

    control:render(State.get(key))

    return control
end

function Control:addKeybind(parent, key, text, default)
    local control = setmetatable({ key = key, kind = "keybind" }, Control)
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 26),
        LayoutOrder = #parent.rows,
    }, parent.body)

    table.insert(parent.rows, row)

    local caption = label(row, text, 13, THEME.muted)
    caption.Size = UDim2.new(1, -100, 1, 0)

    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(88, 22),
        BackgroundColor3 = THEME.panel2,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = THEME.text,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(button, 4)
    stroke(button, THEME.stroke)

    local listening = false

    function control:render(value)
        button.Text = value and string.upper(tostring(value)) or "NONE"
    end

    button.MouseButton1Click:Connect(function()
        listening = true
        button.Text = "..."
        button.TextColor3 = THEME.accent
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if not listening then
            return
        end

        if processed and input.UserInputType == Enum.UserInputType.Keyboard then
            return
        end

        local name

        if input.UserInputType == Enum.UserInputType.Keyboard then
            name = input.KeyCode.Name
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            name = "Mouse1"
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            name = "Mouse2"
        end

        if name then
            listening = false
            button.TextColor3 = THEME.text
            control:set(name == "Unknown" and nil or name)
        end
    end)

    control:render(State.get(key))

    return control
end

function Control:addText(parent, key, text, placeholder)
    local control = setmetatable({ key = key, kind = "text" }, Control)
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 26),
        LayoutOrder = #parent.rows,
    }, parent.body)

    table.insert(parent.rows, row)

    local caption = label(row, text, 13, THEME.muted)
    caption.Size = UDim2.new(1, -150, 1, 0)

    local box = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(140, 22),
        BackgroundColor3 = THEME.panel2,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = THEME.text,
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = THEME.muted,
        Text = "",
        ClearTextOnFocus = false,
    }, row)
    corner(box, 4)
    stroke(box, THEME.stroke)

    box.FocusLost:Connect(function()
        control:set(box.Text)
    end)

    function control:render(value)
        if not box:IsFocused() then
            box.Text = tostring(value or "")
        end
    end

    control:render(State.get(key))

    return control
end

function Control:addButton(parent, text, callback, danger)
    local button = create("TextButton", {
        BackgroundColor3 = THEME.panel2,
        Size = UDim2.new(1, -20, 0, 26),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = danger and THEME.danger or THEME.text,
        Text = text,
        AutoButtonColor = false,
        LayoutOrder = #parent.rows,
    }, parent.body)
    corner(button, 4)
    stroke(button, THEME.stroke)

    table.insert(parent.rows, button)

    button.MouseEnter:Connect(function()
        tween(button, { BackgroundColor3 = THEME.panel })
    end)

    button.MouseLeave:Connect(function()
        tween(button, { BackgroundColor3 = THEME.panel2 })
    end)

    button.MouseButton1Click:Connect(function()
        if callback then
            task.spawn(callback)
        end
    end)

    return button
end

--------------------------------------------------------------------------
-- window
--------------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Window:tab(name, caption)
    local tab = {}
    tab.window = self
    tab.name = name

    local button = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = THEME.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "  " .. caption,
        AutoButtonColor = false,
        LayoutOrder = #self.tabs + 1,
    }, self.sidebar)

    local marker = create("Frame", {
        BackgroundColor3 = THEME.accent,
        Size = UDim2.new(0, 3, 0, 16),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Visible = false,
    }, button)
    corner(marker, 2)

    local page = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = THEME.stroke,
        Visible = false,
    }, self.content)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    }, page)

    create("UIPadding", {
        PaddingRight = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 8),
    }, page)

    tab.page = page
    tab.button = button
    tab.marker = marker

    button.MouseButton1Click:Connect(function()
        self:select(tab)
    end)

    table.insert(self.tabs, tab)

    if #self.tabs == 1 then
        self:select(tab)
    end

    function tab:section(title, subtitle)
        local section = { tab = self, rows = {} }
        self.sectionCount = (self.sectionCount or 0) + 1

        local frame = create("Frame", {
            BackgroundColor3 = THEME.panel,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = self.sectionCount,
        }, self.page)
        corner(frame, 8)
        stroke(frame, THEME.stroke)

        create("UIPadding", {
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
        }, frame)

        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0),
        }, frame)

        local titleLabel = label(frame, title, 13, THEME.text, Enum.Font.GothamBold)
        titleLabel.Size = UDim2.new(1, 0, 0, 18)
        titleLabel.LayoutOrder = 1

        if subtitle then
            local sub = label(frame, subtitle, 11, THEME.muted)
            sub.Size = UDim2.new(1, 0, 0, 14)
            sub.LayoutOrder = 2
        end

        local body = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 3,
        }, frame)

        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        }, body)

        section.frame = frame
        section.body = body

        function section:toggle(key, text, callback)
            return Control.addToggle(self, key, text, callback)
        end

        function section:slider(key, text, min, max, step, callback, suffix)
            return Control.addSlider(self, key, text, min, max, step, callback, suffix)
        end

        function section:dropdown(key, text, options, callback)
            return Control.addDropdown(self, key, text, options, callback)
        end

        function section:keybind(key, text, callback)
            return Control.addKeybind(self, key, text, callback)
        end

        function section:text(key, caption, placeholder)
            return Control.addText(self, key, caption, placeholder)
        end

        function section:button(text, callback, danger)
            return Control.addButton(self, text, callback, danger)
        end

        function section:label(caption, color)
            local row = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -20, 0, 16),
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = color or THEME.muted,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                Text = caption,
                LayoutOrder = #self.rows,
            }, body)

            table.insert(self.rows, row)

            return row
        end

        return section
    end

    return tab
end

function Window:select(target)
    for _, tab in next, self.tabs do
        tab.page.Visible = tab == target
        tab.marker.Visible = tab == target
        tab.button.TextColor3 = tab == target and THEME.text or THEME.muted
    end
end

function Window:setVisible(visible)
    self.screenGui.Enabled = visible
    self.visible = visible
    self.popupLayer.Visible = false
end

function Window:toggle()
    self:setVisible(not self.visible)
end

function Window:notify(message, tone)
    local toast = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 8 + #self.toasts * 34),
        Size = UDim2.fromOffset(320, 28),
        BackgroundColor3 = THEME.panel,
        ZIndex = 80,
    }, self.screenGui)
    corner(toast, 6)
    stroke(toast, tone == "error" and THEME.danger or THEME.stroke)

    local textLabel = label(toast, message, 12, THEME.text)
    textLabel.Size = UDim2.new(1, -16, 1, 0)
    textLabel.Position = UDim2.fromOffset(8, 0)

    table.insert(self.toasts, toast)

    task.delay(3.2, function()
        local index = table.find(self.toasts, toast)

        if index then
            table.remove(self.toasts, index)
        end

        if toast.Parent then
            toast:Destroy()
        end
    end)
end

function UI.new(options)
    options = options or {}

    local screenGui = create("ScreenGui", {
        Name = "criminality_hub",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = true,
    })

    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    screenGui.Parent = parent

    local window = setmetatable({
        screenGui = screenGui,
        tabs = {},
        toasts = {},
        visible = true,
    }, Window)

    local root = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(620, 430),
        BackgroundColor3 = THEME.window,
        BorderSizePixel = 0,
    }, screenGui)
    corner(root, 10)
    stroke(root, THEME.stroke)

    window.root = root

    local header = create("Frame", {
        Name = "Header",
        BackgroundColor3 = THEME.panel,
        Size = UDim2.new(1, 0, 0, 38),
        BorderSizePixel = 0,
    }, root)
    corner(header, 10)

    local headerMask = create("Frame", {
        BackgroundColor3 = THEME.panel,
        Position = UDim2.fromOffset(0, 20),
        Size = UDim2.new(1, 0, 0, 18),
        BorderSizePixel = 0,
    }, header)

    local title = label(header, options.title or "criminality", 14, THEME.text, Enum.Font.GothamBold)
    title.Size = UDim2.new(0, 300, 1, 0)
    title.Position = UDim2.fromOffset(14, 0)

    local accentBar = create("Frame", {
        BackgroundColor3 = THEME.accent,
        Size = UDim2.new(0, 3, 0, 16),
        Position = UDim2.fromOffset(0, 11),
    }, header)
    corner(accentBar, 2)

    local status = create("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -44, 0.5, 0),
        Size = UDim2.fromOffset(160, 20),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = THEME.muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = options.status or "",
    }, header)

    local closeButton = create("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = THEME.muted,
        Text = "x",
        AutoButtonColor = false,
    }, header)

    closeButton.MouseButton1Click:Connect(function()
        window:setVisible(false)
    end)

    local sidebar = create("Frame", {
        Name = "Sidebar",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 48),
        Size = UDim2.fromOffset(136, 372),
    }, root)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    }, sidebar)

    local content = create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(154, 48),
        Size = UDim2.new(1, -164, 1, -58),
    }, root)

    window.sidebar = sidebar
    window.content = content
    window.popupLayer = popupLayer(screenGui, root)

    -- drag
    local dragging, dragStart, startPosition

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    -- menu key
    local menuKey = options.menuKey or Enum.KeyCode.RightShift

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end

        if input.KeyCode == menuKey then
            window:toggle()
        end
    end)

    window.status = status

    return window
end

UI.THEME = THEME

return UI
