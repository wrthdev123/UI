-- VantaUI 2.0 standalone example
-- Five independent draggable panels; no main window and no dark backdrop.
-- Paste this ENTIRE file into a LocalScript in StarterPlayerScripts.
-- No ModuleScript, ReplicatedStorage setup or additional files are required.
-- In Roblox Studio use Play / Play Solo, not the server-only Run mode.

print("[VantaUI] Example is starting...")

local VantaUI = (function()
--[[
    VantaUI 2.0.0
    Independent, draggable column panels for Roblox, written in Luau.

    Interface only: no game logic, remotes, executor APIs or external assets.
    Place this file in a ModuleScript and see Example.client.lua for usage.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local VantaUI = {}
VantaUI.Version = "2.0.0"

local MOTION = {
    Instant = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Fast = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Medium = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Slow = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Spring = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local function create(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color,
        Transparency = transparency == nil and 0.75 or transparency,
        Thickness = thickness or 1,
    }, parent)
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
    }, parent)
end

local function tween(instance, info, properties)
    local animation = TweenService:Create(instance, info or MOTION.Fast, properties)
    animation:Play()
    return animation
end

local function blend(from, to, alpha)
    return Color3.new(
        from.R + (to.R - from.R) * alpha,
        from.G + (to.G - from.G) * alpha,
        from.B + (to.B - from.B) * alpha
    )
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[VantaUI] Callback error: " .. tostring(err))
    end
end

local function listen(window, signal, callback)
    local connection = signal:Connect(callback)
    table.insert(window._connections, connection)
    return connection
end

local function makeTheme(options)
    local overrides = options.Theme or {}
    local accent = options.Accent or overrides.Accent or Color3.fromRGB(237, 45, 72)
    local surface = overrides.Surface or Color3.fromRGB(31, 32, 42)

    local theme = {
        Column = Color3.fromRGB(20, 21, 28),
        Surface = surface,
        SurfaceHover = Color3.fromRGB(42, 44, 56),
        Inset = Color3.fromRGB(18, 19, 26),
        Track = Color3.fromRGB(66, 69, 84),
        Stroke = Color3.fromRGB(94, 98, 116),
        Text = Color3.fromRGB(250, 250, 253),
        SubText = Color3.fromRGB(181, 185, 201),
        Muted = Color3.fromRGB(128, 133, 151),
        White = Color3.fromRGB(255, 255, 255),
        Success = Color3.fromRGB(70, 211, 138),
        Warning = Color3.fromRGB(245, 183, 73),
        Danger = Color3.fromRGB(244, 82, 101),
        Info = Color3.fromRGB(91, 157, 245),
        Accent = accent,
    }

    theme.AccentDark = blend(accent, Color3.new(0, 0, 0), 0.46)
    theme.AccentSoft = blend(surface, accent, 0.26)
    theme.SurfaceActive = blend(surface, accent, 0.42)

    for key, value in pairs(overrides) do
        theme[key] = value
    end
    return theme
end

local function makeText(parent, text, size, color, font)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = tostring(text or ""),
        TextColor3 = color,
        TextSize = size or 13,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Active = false,
    }, parent)
end

local function makeChevron(parent, color, size)
    local root = create("Frame", {
        Name = "Chevron",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(size or 14, size or 14),
        Active = false,
    }, parent)

    local extent = (size or 14) / 14
    local function line(x1, y1, x2, y2)
        local dx = (x2 - x1) * extent
        local dy = (y2 - y1) * extent
        local length = math.sqrt(dx * dx + dy * dy)
        local object = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset((x1 + x2) * 0.5 * extent, (y1 + y2) * 0.5 * extent),
            Size = UDim2.fromOffset(length, 1.5),
            Rotation = math.deg(math.atan2(dy, dx)),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Active = false,
        }, root)
        corner(object, 2)
    end

    line(4, 3, 9, 7)
    line(9, 7, 4, 11)
    return root
end

local function keyName(key)
    if not key or key == Enum.KeyCode.None then
        return "None"
    end
    local aliases = {
        RightShift = "RShift",
        LeftShift = "LShift",
        RightControl = "RCtrl",
        LeftControl = "LCtrl",
        RightAlt = "RAlt",
        LeftAlt = "LAlt",
        Return = "Enter",
        Escape = "Esc",
        Space = "Space",
    }
    return aliases[key.Name] or key.Name
end

local Container = {}
Container.__index = Container

local Category = setmetatable({}, { __index = Container })
Category.__index = Category

local Component = {}
Component.__index = Component

local Window = {}
Window.__index = Window

local function nextOrder(container)
    container._order = container._order + 10
    return container._order
end

local function updateTextBounds(component)
    local reserve = component.RightWidth > 0 and component.RightWidth + 8 or 0
    local width = component.LeftPadding + reserve + 12
    local titleSize = component.Title.Size
    component.Title.Size = UDim2.new(1, -width, titleSize.Y.Scale, titleSize.Y.Offset)
    if component.Description then
        local descriptionSize = component.Description.Size
        component.Description.Size = UDim2.new(1, -width, descriptionSize.Y.Scale, descriptionSize.Y.Offset)
    end
end

local function addRightControl(component, control, width, order)
    if component.RightWidth > 0 then
        component.RightWidth = component.RightWidth + 6
    end
    component.RightWidth = component.RightWidth + width
    component.Right.Size = UDim2.new(0, component.RightWidth, 1, 0)
    control.LayoutOrder = order or 1
    control.Parent = component.Right
    updateTextBounds(component)
    return control
end

local function createItem(container, options)
    local window = container.Window
    local theme = window.Theme
    local hasDescription = options.Description ~= nil and options.Description ~= ""
    local height = options.Height or (hasDescription and 52 or 38)

    local root = create("Frame", {
        Name = (options.Title or "Item") .. "Item",
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(container),
        Active = false,
    }, container.Frame)

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    }, root)

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = 1,
        Active = false,
    }, root)
    corner(header, options.Radius or 8)
    local headerStroke = stroke(header, theme.Stroke, 0.80, 1)
    local headerScale = create("UIScale", { Scale = 1 }, header)

    local accentBar = create("Frame", {
        Name = "ActiveBar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(2, 0),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4,
        Active = false,
    }, header)
    corner(accentBar, 2)

    local hitbox = create("TextButton", {
        Name = "Hitbox",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = options.Interactive ~= false,
        ZIndex = 2,
    }, header)

    local left = options.LeftPadding or 12
    local title = makeText(header, options.Title, options.TextSize or 12, theme.Text, Enum.Font.GothamMedium)
    title.Name = "Title"
    title.Position = UDim2.fromOffset(left, hasDescription and 6 or 0)
    title.Size = UDim2.new(1, -(left + 12), 0, hasDescription and 19 or height)
    title.ZIndex = 3

    local description
    if hasDescription then
        description = makeText(header, options.Description, 10, theme.SubText, Enum.Font.Gotham)
        description.Name = "Description"
        description.Position = UDim2.fromOffset(left, 26)
        description.Size = UDim2.new(1, -(left + 12), 0, 17)
        description.ZIndex = 3
    end

    local right = create("Frame", {
        Name = "Right",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Active = false,
    }, header)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, right)

    local self = setmetatable({
        Window = window,
        Container = container,
        Root = root,
        Header = header,
        HeaderStroke = headerStroke,
        HeaderScale = headerScale,
        AccentBar = accentBar,
        Hitbox = hitbox,
        Title = title,
        Description = description,
        Right = right,
        RightWidth = 0,
        LeftPadding = left,
        Height = height,
        SearchText = string.lower(tostring(options.Title or "") .. " " .. tostring(options.Description or "")),
        _active = false,
        _hovered = false,
        _destroyed = false,
    }, Component)

    function self:RefreshBackground(animated)
        local color = theme.Surface
        if self._active then
            color = self._hovered and blend(theme.SurfaceActive, theme.Accent, 0.08) or theme.SurfaceActive
        elseif self._hovered then
            color = theme.SurfaceHover
        end
        local borderColor = self._active and theme.Accent or theme.Stroke
        local borderTransparency = self._active and 0.48 or (self._hovered and 0.66 or 0.80)
        if animated == false then
            header.BackgroundColor3 = color
            headerStroke.Color = borderColor
            headerStroke.Transparency = borderTransparency
        else
            tween(header, MOTION.Fast, { BackgroundColor3 = color })
            tween(headerStroke, MOTION.Fast, {
                Color = borderColor,
                Transparency = borderTransparency,
            })
        end
    end

    listen(window, header.MouseEnter, function()
        self._hovered = true
        self:RefreshBackground(true)
    end)
    listen(window, header.MouseLeave, function()
        self._hovered = false
        self:RefreshBackground(true)
        tween(headerScale, MOTION.Fast, { Scale = 1 })
    end)
    listen(window, hitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._pressPosition = Vector2.new(input.Position.X, input.Position.Y)
            tween(headerScale, MOTION.Instant, { Scale = 0.988 })
        end
    end)
    listen(window, hitbox.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            tween(headerScale, MOTION.Spring, { Scale = 1 })
        end
    end)

    return self
end

local function createInlinePanel(component, name, paddingAmount)
    local window = component.Window
    local theme = window.Theme
    local pad = paddingAmount or 6

    component._panelOrder = (component._panelOrder or 0) + 1
    local root = create("Frame", {
        Name = name or "InlinePanel",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        LayoutOrder = 1 + component._panelOrder,
        Active = false,
    }, component.Root)

    local content = create("CanvasGroup", {
        Name = "Content",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, -6),
        BackgroundColor3 = theme.Inset,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
        Active = false,
    }, root)
    corner(content, 8)
    stroke(content, theme.Stroke, 0.84, 1)
    padding(content, pad, pad, pad, pad)

    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    }, content)

    local panel = {
        Root = root,
        Content = content,
        Layout = layout,
        Open = false,
        _revision = 0,
    }

    function panel:Measure()
        return layout.AbsoluteContentSize.Y + pad * 2
    end

    function panel:RefreshContent()
        local height = self:Measure()
        content.Size = UDim2.new(1, 0, 0, height)
        return height
    end

    function panel:SetOpen(state, instant)
        state = state and true or false
        if self.Open == state and not instant then
            return
        end
        self.Open = state
        self._revision = self._revision + 1
        local revision = self._revision
        local height = self:RefreshContent()

        if state then
            root.Visible = true
            if instant then
                root.Size = UDim2.new(1, 0, 0, height)
                content.Position = UDim2.fromOffset(0, 0)
                content.GroupTransparency = 0
            else
                root.Size = UDim2.new(1, 0, 0, math.min(root.Size.Y.Offset, height))
                content.Position = UDim2.fromOffset(0, -6)
                content.GroupTransparency = 1
                tween(root, MOTION.Medium, { Size = UDim2.new(1, 0, 0, height) })
                tween(content, MOTION.Medium, {
                    Position = UDim2.fromOffset(0, 0),
                    GroupTransparency = 0,
                })
            end
        else
            if instant then
                root.Size = UDim2.new(1, 0, 0, 0)
                root.Visible = false
                content.GroupTransparency = 1
            else
                tween(root, MOTION.Medium, { Size = UDim2.new(1, 0, 0, 0) })
                tween(content, MOTION.Fast, {
                    Position = UDim2.fromOffset(0, -4),
                    GroupTransparency = 1,
                })
                task.delay(0.27, function()
                    if self._revision == revision and not self.Open then
                        root.Visible = false
                    end
                end)
            end
        end

        if self._onStateChanged then
            self._onStateChanged(state)
        end
    end

    function panel:Toggle()
        self:SetOpen(not self.Open)
    end

    listen(window, layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        local height = panel:RefreshContent()
        if panel.Open then
            tween(root, MOTION.Fast, { Size = UDim2.new(1, 0, 0, height) })
        end
    end)

    panel.Container = setmetatable({
        Window = window,
        Frame = content,
        _order = 0,
        _items = {},
    }, Container)

    task.defer(function()
        if root.Parent then
            panel:RefreshContent()
        end
    end)

    return panel
end

function Component:AddSettings(builder)
    if self.Settings then
        return self.Settings.Container
    end

    local theme = self.Window.Theme
    local gear = create("TextButton", {
        Name = "SettingsButton",
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = theme.Inset,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    corner(gear, 6)
    addRightControl(self, gear, 24, 99)

    local icon = makeChevron(gear, theme.SubText, 14)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.ZIndex = 6

    local panel = createInlinePanel(self, "InlineSettings", 6)
    panel._onStateChanged = function(open)
        tween(icon, MOTION.Medium, { Rotation = open and 90 or 0 })
        tween(gear, MOTION.Fast, {
            BackgroundColor3 = open and theme.AccentSoft or theme.Inset,
            BackgroundTransparency = open and 0 or 0.15,
        })
    end

    listen(self.Window, gear.Activated, function()
        panel:Toggle()
    end)
    listen(self.Window, gear.MouseEnter, function()
        tween(gear, MOTION.Fast, { BackgroundTransparency = 0 })
    end)
    listen(self.Window, gear.MouseLeave, function()
        tween(gear, MOTION.Fast, { BackgroundTransparency = panel.Open and 0 or 0.15 })
    end)

    self.Settings = panel
    if type(builder) == "function" then
        local ok, err = pcall(builder, panel.Container)
        if not ok then
            warn("[VantaUI] Settings builder error: " .. tostring(err))
        end
    end
    panel:RefreshContent()
    return panel.Container
end

function Component:OpenSettings(state)
    if self.Settings then
        self.Settings:SetOpen(state ~= false)
    end
    return self
end

function Component:SetActive(state, animated)
    self._active = state and true or false
    self:RefreshBackground(animated)
    local properties = {
        Size = UDim2.fromOffset(2, self._active and math.min(18, self.Height - 12) or 0),
        BackgroundTransparency = self._active and 0 or 1,
    }
    if animated == false then
        self.AccentBar.Size = properties.Size
        self.AccentBar.BackgroundTransparency = properties.BackgroundTransparency
    else
        tween(self.AccentBar, MOTION.Medium, properties)
    end
end

function Component:Ripple()
    local theme = self.Window.Theme
    local position = self._pressPosition
    local x = position and position.X - self.Header.AbsolutePosition.X or self.Header.AbsoluteSize.X * 0.5
    local y = position and position.Y - self.Header.AbsolutePosition.Y or self.Header.AbsoluteSize.Y * 0.5
    local ripple = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        ZIndex = 1,
        Active = false,
    }, self.Header)
    corner(ripple, 100)
    tween(ripple, MOTION.Slow, {
        Size = UDim2.fromOffset(math.max(120, self.Header.AbsoluteSize.X * 1.2), math.max(120, self.Header.AbsoluteSize.X * 1.2)),
        BackgroundTransparency = 1,
    })
    task.delay(0.40, function()
        if ripple.Parent then
            ripple:Destroy()
        end
    end)
end

function Component:SetVisible(state)
    self.Root.Visible = state and true or false
    return self
end

function Component:SetTitle(text)
    self.Title.Text = tostring(text)
    self.SearchText = string.lower(tostring(text) .. " " .. (self.Description and self.Description.Text or ""))
    return self
end

function Component:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    if self.Flag and self.Window._flags[self.Flag] == self then
        self.Window._flags[self.Flag] = nil
    end
    for index, item in ipairs(self.Container._items) do
        if item == self then
            table.remove(self.Container._items, index)
            break
        end
    end
    for index, item in ipairs(self.Window._components) do
        if item == self then
            table.remove(self.Window._components, index)
            break
        end
    end
    self.Root:Destroy()
end

local function finalize(container, component, options)
    component.Flag = options.Flag
    if options.Flag then
        container.Window._flags[options.Flag] = component
    end
    table.insert(container._items, component)
    table.insert(container.Window._components, component)
    if type(options.Settings) == "function" then
        component:AddSettings(options.Settings)
    end
    return component
end

function Container:AddToggle(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Toggle"
    local theme = self.Window.Theme
    local component = createItem(self, options)
    local value = options.Default == true

    local track = create("Frame", {
        Name = "Switch",
        Size = UDim2.fromOffset(36, 20),
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 6,
    })
    corner(track, 10)
    addRightControl(component, track, 36, 1)

    local knob = create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = theme.SubText,
        BorderSizePixel = 0,
        ZIndex = 7,
        Active = false,
    }, track)
    corner(knob, 7)

    local function pulse()
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = knob.Position,
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 6,
            Active = false,
        }, track)
        corner(ring, 10)
        local ringStroke = stroke(ring, theme.Accent, 0.25, 1.5)
        tween(ring, MOTION.Slow, { Size = UDim2.fromOffset(42, 42) })
        tween(ringStroke, MOTION.Slow, { Transparency = 1 })
        task.delay(0.40, function()
            if ring.Parent then
                ring:Destroy()
            end
        end)
    end

    local function update(state, animated, notify)
        state = state and true or false
        local changed = value ~= state
        value = state
        component:SetActive(state, animated)
        local properties = {
            Position = state and UDim2.new(1, -10, 0.5, 0) or UDim2.new(0, 10, 0.5, 0),
            BackgroundColor3 = state and theme.White or theme.SubText,
        }
        if animated == false then
            track.BackgroundColor3 = state and theme.Accent or theme.Track
            knob.Position = properties.Position
            knob.BackgroundColor3 = properties.BackgroundColor3
        else
            tween(track, MOTION.Medium, { BackgroundColor3 = state and theme.Accent or theme.Track })
            tween(knob, MOTION.Spring, properties)
            if changed then
                pulse()
            end
        end
        if notify and changed then
            safeCallback(options.Callback, value)
        end
    end

    function component:Get()
        return value
    end

    function component:Set(state, noAnimation)
        update(state, noAnimation ~= true, true)
        return component
    end

    function component:SetSilent(state, noAnimation)
        update(state, noAnimation ~= true, false)
        return component
    end

    listen(self.Window, component.Hitbox.Activated, function()
        update(not value, true, true)
    end)

    update(value, false, false)
    return finalize(self, component, options)
end

function Container:AddButton(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Button"
    local theme = self.Window.Theme
    local component = createItem(self, options)

    if options.RightText then
        local rightText = makeText(component.Right, options.RightText, 10, theme.SubText, Enum.Font.GothamMedium)
        rightText.Size = UDim2.fromOffset(56, 20)
        rightText.TextXAlignment = Enum.TextXAlignment.Right
        addRightControl(component, rightText, 56, 1)
    else
        local icon = makeChevron(component.Right, theme.Muted, 14)
        addRightControl(component, icon, 14, 1)
    end

    listen(self.Window, component.Hitbox.Activated, function()
        component:Ripple()
        component:SetActive(true, true)
        task.delay(0.18, function()
            if not component._destroyed and not component.Window._destroyed then
                component:SetActive(false, true)
            end
        end)
        safeCallback(options.Callback)
    end)

    function component:Fire()
        safeCallback(options.Callback)
        return component
    end

    return finalize(self, component, options)
end

function Container:AddSlider(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Slider"
    options.Height = options.Height or 58
    options.Interactive = false
    local theme = self.Window.Theme
    local component = createItem(self, options)

    local minimum = options.Min or options.Minimum or 0
    local maximum = options.Max or options.Maximum or 100
    if maximum <= minimum then
        maximum = minimum + 1
    end
    local step = options.Step or 1
    if step <= 0 then
        step = 1
    end
    local value = clamp(options.Default or minimum, minimum, maximum)

    local valueText = makeText(component.Right, "", 10, theme.SubText, Enum.Font.GothamMedium)
    valueText.Size = UDim2.fromOffset(46, 20)
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    addRightControl(component, valueText, 46, 1)

    component.Title.Position = UDim2.fromOffset(component.LeftPadding, 5)
    component.Title.Size = UDim2.new(1, -(component.LeftPadding + component.RightWidth + 20), 0, 23)
    if component.Description then
        component.Description.Position = UDim2.fromOffset(component.LeftPadding, 25)
        component.Description.Visible = false
    end

    local track = create("Frame", {
        Name = "Track",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 12, 1, -12),
        Size = UDim2.new(1, -24, 0, 4),
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        ZIndex = 3,
        Active = false,
    }, component.Header)
    corner(track, 3)

    local fill = create("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 4,
        Active = false,
    }, track)
    corner(fill, 3)

    local knob = create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = theme.White,
        BorderSizePixel = 0,
        ZIndex = 5,
        Active = false,
    }, track)
    corner(knob, 6)
    local knobScale = create("UIScale", { Scale = 1 }, knob)

    local hitbox = create("TextButton", {
        Name = "SliderHitbox",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
    }, track)

    local decimals = 0
    local stepText = tostring(step)
    local fraction = string.match(stepText, "%.(%d+)")
    if fraction then
        decimals = math.min(#fraction, 4)
    end

    local function rounded(raw)
        local result = math.floor((raw - minimum) / step + 0.5) * step + minimum
        return clamp(result, minimum, maximum)
    end

    local function formatted(current)
        if type(options.Format) == "function" then
            local ok, result = pcall(options.Format, current)
            if ok then
                return tostring(result)
            end
        elseif type(options.Format) == "string" then
            local ok, result = pcall(string.format, options.Format, current)
            if ok then
                return result
            end
        end
        return string.format("%." .. tostring(decimals) .. "f", current) .. tostring(options.Suffix or "")
    end

    local function update(raw, animated, notify)
        local nextValue = rounded(raw)
        local changed = nextValue ~= value
        value = nextValue
        local alpha = (value - minimum) / (maximum - minimum)
        valueText.Text = formatted(value)
        local fillSize = UDim2.new(alpha, 0, 1, 0)
        local knobPosition = UDim2.new(alpha, 0, 0.5, 0)
        if animated == false then
            fill.Size = fillSize
            knob.Position = knobPosition
        else
            tween(fill, MOTION.Fast, { Size = fillSize })
            tween(knob, MOTION.Fast, { Position = knobPosition })
        end
        if notify and changed then
            safeCallback(options.Callback, value)
        end
    end

    local dragging = false
    local dragInput

    local function updateFromX(x)
        if track.AbsoluteSize.X <= 0 then
            return
        end
        local alpha = clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        update(minimum + (maximum - minimum) * alpha, false, true)
    end

    listen(self.Window, hitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            updateFromX(input.Position.X)
            tween(knobScale, MOTION.Spring, { Scale = 1.25 })
            tween(component.HeaderStroke, MOTION.Fast, { Color = theme.Accent, Transparency = 0.45 })
        end
    end)
    listen(self.Window, UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput then
            updateFromX(input.Position.X)
        end
    end)
    listen(self.Window, UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragInput) then
            dragging = false
            dragInput = nil
            tween(knobScale, MOTION.Spring, { Scale = 1 })
            component:RefreshBackground(true)
        end
    end)
    listen(self.Window, hitbox.MouseEnter, function()
        tween(knobScale, MOTION.Fast, { Scale = 1.12 })
    end)
    listen(self.Window, hitbox.MouseLeave, function()
        if not dragging then
            tween(knobScale, MOTION.Fast, { Scale = 1 })
        end
    end)

    function component:Get()
        return value
    end

    function component:Set(newValue, noAnimation)
        update(newValue, noAnimation ~= true, true)
        return component
    end

    function component:SetSilent(newValue, noAnimation)
        update(newValue, noAnimation ~= true, false)
        return component
    end

    update(value, false, false)
    return finalize(self, component, options)
end

function Container:AddDropdown(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Dropdown"
    local theme = self.Window.Theme
    local component = createItem(self, options)
    local values = {}
    for index, entry in ipairs(options.Values or options.Options or {}) do
        values[index] = entry
    end
    local value = options.Default
    if value == nil then
        value = values[1]
    end

    local valueText = makeText(component.Right, tostring(value or "None"), 10, theme.SubText, Enum.Font.Gotham)
    valueText.Size = UDim2.fromOffset(76, 20)
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    addRightControl(component, valueText, 76, 1)

    local icon = makeChevron(component.Right, theme.Muted, 14)
    addRightControl(component, icon, 14, 2)

    local panel = createInlinePanel(component, "DropdownOptions", 5)
    local optionButtons = {}

    local function update(valueTextOnly)
        valueText.Text = tostring(value or "None")
        for _, entry in ipairs(optionButtons) do
            local selected = entry.Value == value
            local targetColor = selected and theme.AccentSoft or theme.Surface
            if valueTextOnly then
                entry.Button.BackgroundColor3 = targetColor
                entry.Label.TextColor3 = selected and theme.Text or theme.SubText
                entry.Marker.BackgroundTransparency = selected and 0 or 1
            else
                tween(entry.Button, MOTION.Fast, { BackgroundColor3 = targetColor })
                tween(entry.Label, MOTION.Fast, { TextColor3 = selected and theme.Text or theme.SubText })
                tween(entry.Marker, MOTION.Fast, { BackgroundTransparency = selected and 0 or 1 })
            end
        end
    end

    local function set(newValue, notify)
        local changed = value ~= newValue
        value = newValue
        update(false)
        if notify and changed then
            safeCallback(options.Callback, value)
        end
    end

    local function rebuild()
        for _, entry in ipairs(optionButtons) do
            entry.Button:Destroy()
        end
        optionButtons = {}

        for index, entryValue in ipairs(values) do
            local button = create("TextButton", {
                Name = "Option",
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = theme.Surface,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
            }, panel.Content)
            corner(button, 6)

            local label = makeText(button, tostring(entryValue), 11, theme.SubText, Enum.Font.Gotham)
            label.Position = UDim2.fromOffset(9, 0)
            label.Size = UDim2.new(1, -32, 1, 0)

            local marker = create("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(5, 5),
                BackgroundColor3 = theme.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Active = false,
            }, button)
            corner(marker, 3)

            local entry = {
                Button = button,
                Label = label,
                Marker = marker,
                Value = entryValue,
            }
            table.insert(optionButtons, entry)

            button.Activated:Connect(function()
                set(entryValue, true)
                panel:SetOpen(false)
            end)
            button.MouseEnter:Connect(function()
                if value ~= entryValue then
                    tween(button, MOTION.Fast, { BackgroundColor3 = theme.SurfaceHover })
                end
            end)
            button.MouseLeave:Connect(function()
                if value ~= entryValue then
                    tween(button, MOTION.Fast, { BackgroundColor3 = theme.Surface })
                end
            end)
        end
        update(true)
        panel:RefreshContent()
    end

    panel._onStateChanged = function(open)
        tween(icon, MOTION.Medium, { Rotation = open and 90 or 0 })
        component:SetActive(open, true)
    end
    listen(self.Window, component.Hitbox.Activated, function()
        panel:Toggle()
    end)

    function component:Get()
        return value
    end

    function component:Set(newValue)
        set(newValue, true)
        return component
    end

    function component:SetSilent(newValue)
        set(newValue, false)
        return component
    end

    function component:Refresh(newValues, keepSelection)
        values = {}
        for index, entry in ipairs(newValues or {}) do
            values[index] = entry
        end
        local found = false
        for _, entry in ipairs(values) do
            if entry == value then
                found = true
                break
            end
        end
        if not keepSelection or not found then
            value = values[1]
        end
        rebuild()
        return component
    end

    rebuild()
    return finalize(self, component, options)
end

function Container:AddKeybind(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Keybind"
    local theme = self.Window.Theme
    local component = createItem(self, options)
    local value = options.Default or Enum.KeyCode.None
    local listeningForKey = false

    local keyBox = create("Frame", {
        Name = "Key",
        Size = UDim2.fromOffset(58, 24),
        BackgroundColor3 = theme.Inset,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 6,
    })
    corner(keyBox, 6)
    local keyStroke = stroke(keyBox, theme.Stroke, 0.72, 1)
    addRightControl(component, keyBox, 58, 1)

    local label = makeText(keyBox, keyName(value), 10, theme.SubText, Enum.Font.GothamMedium)
    label.Size = UDim2.fromScale(1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Center

    local function stopListening()
        listeningForKey = false
        component.Window._capturing = false
        label.Text = keyName(value)
        tween(keyBox, MOTION.Fast, { BackgroundColor3 = theme.Inset })
        tween(keyStroke, MOTION.Fast, { Color = theme.Stroke, Transparency = 0.72 })
    end

    local function startListening()
        if listeningForKey then
            return
        end
        listeningForKey = true
        component.Window._capturing = true
        label.Text = "..."
        tween(keyBox, MOTION.Fast, { BackgroundColor3 = theme.AccentSoft })
        tween(keyStroke, MOTION.Fast, { Color = theme.Accent, Transparency = 0.30 })
    end

    local function set(newKey, notify)
        local changed = value ~= newKey
        value = newKey or Enum.KeyCode.None
        label.Text = keyName(value)
        if notify and changed then
            safeCallback(options.Changed, value)
        end
    end

    listen(self.Window, component.Hitbox.Activated, startListening)
    listen(self.Window, UserInputService.InputBegan, function(input, gameProcessed)
        if listeningForKey then
            if input.KeyCode == Enum.KeyCode.Escape then
                stopListening()
                return
            end
            if input.KeyCode == Enum.KeyCode.Backspace then
                set(Enum.KeyCode.None, true)
                stopListening()
                return
            end
            if input.KeyCode ~= Enum.KeyCode.None then
                set(input.KeyCode, true)
                stopListening()
            end
            return
        end

        if gameProcessed or component.Window._capturing or UserInputService:GetFocusedTextBox() then
            return
        end
        if value ~= Enum.KeyCode.None and input.KeyCode == value then
            safeCallback(options.Callback, value)
        end
    end)

    function component:Get()
        return value
    end

    function component:Set(newKey)
        set(newKey, true)
        return component
    end

    function component:SetSilent(newKey)
        set(newKey, false)
        return component
    end

    return finalize(self, component, options)
end

function Container:AddTextbox(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Textbox"
    options.Height = options.Height or 60
    options.Interactive = false
    local theme = self.Window.Theme
    local component = createItem(self, options)
    local value = tostring(options.Default or "")

    component.Title.Position = UDim2.fromOffset(component.LeftPadding, 4)
    component.Title.Size = UDim2.new(1, -(component.LeftPadding + 12), 0, 21)
    if component.Description then
        component.Description.Visible = false
    end

    local box = create("Frame", {
        Name = "Input",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -8),
        Size = UDim2.new(1, -20, 0, 28),
        BackgroundColor3 = theme.Inset,
        BorderSizePixel = 0,
        ZIndex = 3,
        Active = false,
    }, component.Header)
    corner(box, 6)
    local boxStroke = stroke(box, theme.Stroke, 0.80, 1)

    local textbox = create("TextBox", {
        Name = "Textbox",
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = value,
        PlaceholderText = options.Placeholder or "Type here...",
        TextColor3 = theme.Text,
        PlaceholderColor3 = theme.Muted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
        ZIndex = 4,
    }, box)

    listen(self.Window, textbox.Focused, function()
        tween(boxStroke, MOTION.Fast, { Color = theme.Accent, Transparency = 0.35 })
        tween(box, MOTION.Fast, { BackgroundColor3 = theme.SurfaceHover })
    end)
    listen(self.Window, textbox.FocusLost, function(enterPressed)
        value = textbox.Text
        tween(boxStroke, MOTION.Fast, { Color = theme.Stroke, Transparency = 0.80 })
        tween(box, MOTION.Fast, { BackgroundColor3 = theme.Inset })
        safeCallback(options.Callback, value, enterPressed)
    end)

    function component:Get()
        return value
    end

    function component:Set(text)
        value = tostring(text or "")
        textbox.Text = value
        safeCallback(options.Callback, value, false)
        return component
    end

    function component:SetSilent(text)
        value = tostring(text or "")
        textbox.Text = value
        return component
    end

    return finalize(self, component, options)
end

function Container:AddColorPicker(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Color"
    local component = createItem(self, options)
    local theme = self.Window.Theme
    local value = options.Default or theme.Accent

    local preview = create("Frame", {
        Name = "Preview",
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = value,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 6,
    })
    corner(preview, 6)
    stroke(preview, theme.White, 0.75, 1)
    addRightControl(component, preview, 24, 1)

    local icon = makeChevron(component.Right, theme.Muted, 14)
    addRightControl(component, icon, 14, 2)

    local panel = createInlinePanel(component, "ColorSettings", 6)
    panel._onStateChanged = function(open)
        tween(icon, MOTION.Medium, { Rotation = open and 90 or 0 })
        component:SetActive(open, true)
    end
    listen(self.Window, component.Hitbox.Activated, function()
        panel:Toggle()
    end)

    local red, green, blue

    local function colorFromSliders()
        return Color3.fromRGB(red:Get(), green:Get(), blue:Get())
    end

    local function update(newColor, notify, syncSliders)
        value = newColor
        tween(preview, MOTION.Fast, { BackgroundColor3 = value })
        if syncSliders and red and green and blue then
            red:SetSilent(math.floor(value.R * 255 + 0.5), true)
            green:SetSilent(math.floor(value.G * 255 + 0.5), true)
            blue:SetSilent(math.floor(value.B * 255 + 0.5), true)
        end
        if notify then
            safeCallback(options.Callback, value)
        end
    end

    local function sliderChanged()
        update(colorFromSliders(), true, false)
    end

    red = panel.Container:AddSlider({
        Title = "Red",
        Min = 0,
        Max = 255,
        Step = 1,
        Default = math.floor(value.R * 255 + 0.5),
        Callback = sliderChanged,
    })
    green = panel.Container:AddSlider({
        Title = "Green",
        Min = 0,
        Max = 255,
        Step = 1,
        Default = math.floor(value.G * 255 + 0.5),
        Callback = sliderChanged,
    })
    blue = panel.Container:AddSlider({
        Title = "Blue",
        Min = 0,
        Max = 255,
        Step = 1,
        Default = math.floor(value.B * 255 + 0.5),
        Callback = sliderChanged,
    })

    function component:Get()
        return value
    end

    function component:Set(newColor)
        update(newColor, true, true)
        return component
    end

    function component:SetSilent(newColor)
        update(newColor, false, true)
        return component
    end

    return finalize(self, component, options)
end

function Container:AddLabel(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Label"
    options.Interactive = false
    options.Height = options.Height or (options.Description and 48 or 30)
    local component = createItem(self, options)
    component.Header.BackgroundTransparency = 0.25
    return finalize(self, component, options)
end

function Container:AddSeparator(options)
    options = options or {}
    local root = create("Frame", {
        Name = "Separator",
        Size = UDim2.new(1, 0, 0, options.Height or 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(self),
        Active = false,
    }, self.Frame)
    create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = self.Window.Theme.Stroke,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        Active = false,
    }, root)

    local separator = {
        Root = root,
        SearchText = "",
        SetVisible = function(_, state)
            root.Visible = state and true or false
        end,
        Destroy = function()
            root:Destroy()
        end,
    }
    table.insert(self._items, separator)
    return separator
end

function Window:Notify(options)
    options = options or {}
    if self._destroyed then
        return
    end

    local theme = self.Theme
    local kind = options.Type or "Info"
    local accent = theme[kind] or theme.Info
    local height = options.Content and 72 or 54

    local wrapper = create("Frame", {
        Name = "NotificationWrapper",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
    }, self._notificationHolder)

    local toast = create("CanvasGroup", {
        Name = "Notification",
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
    }, wrapper)
    corner(toast, 10)
    stroke(toast, theme.Stroke, 0.65, 1)

    local bar = create("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Active = false,
    }, toast)

    local title = makeText(toast, options.Title or kind, 12, theme.Text, Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(14, options.Content and 9 or 0)
    title.Size = UDim2.new(1, -48, 0, options.Content and 20 or height)

    local content
    if options.Content then
        content = makeText(toast, options.Content, 10, theme.SubText, Enum.Font.Gotham)
        content.Position = UDim2.fromOffset(14, 31)
        content.Size = UDim2.new(1, -28, 0, 28)
        content.TextWrapped = true
        content.TextTruncate = Enum.TextTruncate.None
        content.TextYAlignment = Enum.TextYAlignment.Top
    end

    local progress = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Active = false,
    }, toast)

    local dismissed = false
    local progressTween
    local function dismiss()
        if dismissed or self._destroyed or not wrapper.Parent then
            return
        end
        dismissed = true
        if progressTween then
            progressTween:Cancel()
        end
        tween(toast, MOTION.Medium, {
            Position = UDim2.fromOffset(30, 0),
            GroupTransparency = 1,
        })
        task.delay(0.27, function()
            if wrapper.Parent then
                wrapper:Destroy()
            end
        end)
    end

    tween(toast, MOTION.Medium, {
        Position = UDim2.fromOffset(0, 0),
        GroupTransparency = 0,
    })

    local duration = options.Duration or 4
    if duration > 0 then
        progressTween = TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            Size = UDim2.new(0, 0, 0, 2),
        })
        progressTween:Play()
        task.delay(duration, function()
            if not dismissed and not self._destroyed and wrapper.Parent then
                dismiss()
            end
        end)
    else
        progress.Visible = false
    end

    table.insert(self._notifications, { Wrapper = wrapper, Dismiss = dismiss })
    if #self._notifications > 4 then
        local oldest = table.remove(self._notifications, 1)
        oldest.Dismiss()
    end

    return {
        Dismiss = dismiss,
        Wrapper = wrapper,
        Title = title,
        Content = content,
        Bar = bar,
    }
end

function Window:LayoutCategories()
    if #self.Categories == 0 then
        return
    end

    local viewport = Vector2.new(1280, 720)
    local camera = Workspace.CurrentCamera
    if camera and camera.ViewportSize.X > 0 then
        viewport = camera.ViewportSize
    end

    local totalWidth = 0
    for index, category in ipairs(self.Categories) do
        totalWidth = totalWidth + category._width
        if index > 1 then
            totalWidth = totalWidth + self._columnGap
        end
    end

    local x = math.max(16, (viewport.X - totalWidth) * 0.5)
    for _, category in ipairs(self.Categories) do
        if not category._positioned then
            category.Root.Position = UDim2.fromOffset(x, self._columnY)
        end
        x = x + category._width + self._columnGap
    end
end

function Window:AddCategory(options)
    options = options or {}
    local theme = self.Theme
    local width = options.Width or self._columnWidth
    local index = #self.Categories + 1

    -- Each category is a top-level panel. There is deliberately no shared
    -- window, full-screen backdrop or gradient applied to this CanvasGroup.
    local frame = create("CanvasGroup", {
        Name = (options.Title or "Category") .. "Category",
        Position = options.Position or UDim2.fromOffset(16, self._columnY),
        Size = UDim2.fromOffset(width, 55),
        BackgroundColor3 = theme.Column,
        BackgroundTransparency = 0.025,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
        Active = true,
        ZIndex = 10 + index,
    }, self.Gui)
    corner(frame, 9)
    stroke(frame, theme.Stroke, 0.48, 1)
    local scale = create("UIScale", { Scale = 0.97 }, frame)

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 20,
    }, frame)

    -- The gradient has its own background object, so it can never tint the
    -- title or any other descendant of the category CanvasGroup.
    local headerBackground = create("Frame", {
        Name = "Background",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 20,
    }, header)
    corner(headerBackground, 9)
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, blend(theme.Accent, theme.White, 0.08)),
            ColorSequenceKeypoint.new(1, theme.AccentDark),
        }),
        Rotation = 20,
    }, headerBackground)

    local titleX = 12
    if options.Icon then
        local badge = create("Frame", {
            Position = UDim2.fromOffset(10, 9),
            Size = UDim2.fromOffset(22, 22),
            BackgroundColor3 = theme.White,
            BackgroundTransparency = 0.82,
            BorderSizePixel = 0,
            ZIndex = 22,
            Active = false,
        }, header)
        corner(badge, 6)
        local icon = makeText(badge, options.Icon, 11, theme.White, Enum.Font.GothamBold)
        icon.Size = UDim2.fromScale(1, 1)
        icon.TextXAlignment = Enum.TextXAlignment.Center
        icon.ZIndex = 23
        titleX = 40
    end

    local title = makeText(header, options.Title or "Category", 13, theme.White, Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(titleX, 0)
    title.Size = UDim2.new(1, -(titleX + 12), 1, 0)
    title.TextXAlignment = options.Icon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
    title.ZIndex = 23

    local body = create("ScrollingFrame", {
        Name = "Items",
        Position = UDim2.fromOffset(5, 44),
        Size = UDim2.new(1, -10, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Accent,
        ScrollBarImageTransparency = 0.20,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        Active = true,
        ZIndex = 15,
    }, frame)
    local bodyLayout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
    }, body)
    padding(body, 1, 3, 0, 5)

    local category = setmetatable({
        Window = self,
        Frame = body,
        Root = frame,
        Header = header,
        Title = title,
        _scale = scale,
        _width = width,
        _maxHeight = options.Height or self._columnHeight,
        _positioned = options.Position ~= nil,
        _visible = false,
        _visibilityRevision = 0,
        _order = 0,
        _items = {},
    }, Category)

    local function updateHeight(animated)
        if not frame.Parent then
            return
        end
        local contentHeight = bodyLayout.AbsoluteContentSize.Y + 5
        local bodyHeight = clamp(contentHeight, 0, math.max(40, category._maxHeight - 50))
        local totalHeight = math.max(55, bodyHeight + 50)
        category._targetHeight = totalHeight

        local frameSize = UDim2.fromOffset(width, totalHeight)
        local bodySize = UDim2.new(1, -10, 0, bodyHeight)
        if animated ~= false and category._visible then
            tween(frame, MOTION.Medium, { Size = frameSize })
            tween(body, MOTION.Medium, { Size = bodySize })
        else
            frame.Size = frameSize
            body.Size = bodySize
        end
    end
    category._updateHeight = updateHeight
    listen(self, bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        updateHeight(true)
    end)

    local dragging = false
    local dragInput
    local dragStart
    local startPosition
    listen(self, header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPosition = frame.Position
            self._zOrder = self._zOrder + 1
            frame.ZIndex = 20 + self._zOrder
        end
    end)
    listen(self, UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput then
            local delta = input.Position - dragStart
            category._positioned = true
            frame.Position = UDim2.fromOffset(
                startPosition.X.Offset + delta.X,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
    listen(self, UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragInput) then
            dragging = false
            dragInput = nil
        end
    end)

    table.insert(self.Categories, category)
    self:LayoutCategories()
    updateHeight(false)
    task.defer(function()
        if frame.Parent then
            updateHeight(false)
            if self._visible and not self._destroyed then
                category:SetVisible(true)
            end
        end
    end)
    return category
end

function Category:SetVisible(state, instant)
    state = state and true or false
    if self._visible == state and not instant then
        return self
    end
    self._visible = state
    self._visibilityRevision = self._visibilityRevision + 1
    local revision = self._visibilityRevision

    if state then
        self.Root.Visible = true
        self._updateHeight(false)
        if instant then
            self.Root.GroupTransparency = 0
            self._scale.Scale = 1
        else
            self.Root.GroupTransparency = 1
            self._scale.Scale = 0.97
            tween(self.Root, MOTION.Medium, { GroupTransparency = 0 })
            tween(self._scale, MOTION.Slow, { Scale = 1 })
        end
    else
        if instant then
            self.Root.Visible = false
            self.Root.GroupTransparency = 1
        else
            tween(self.Root, MOTION.Fast, { GroupTransparency = 1 })
            tween(self._scale, MOTION.Fast, { Scale = 0.98 })
            task.delay(0.18, function()
                if self._visibilityRevision == revision and not self._visible then
                    self.Root.Visible = false
                end
            end)
        end
    end
    return self
end

function Category:SetPosition(position)
    self._positioned = true
    self.Root.Position = position
    return self
end

function Category:SetTitle(text)
    self.Title.Text = tostring(text)
    return self
end

function Window:GetFlag(flag)
    local component = self._flags[flag]
    if component and component.Get then
        return component:Get()
    end
    return nil
end

function Window:SetFlag(flag, value)
    local component = self._flags[flag]
    if component and component.Set then
        component:Set(value)
    end
end

function Window:SetVisible(state, instant)
    if self._destroyed then
        return self
    end
    state = state and true or false
    if self._visible == state and not instant then
        return self
    end
    self._visible = state
    self._visibilityRevision = self._visibilityRevision + 1
    local revision = self._visibilityRevision

    for index, category in ipairs(self.Categories) do
        local delay = instant and 0 or (index - 1) * (state and 0.025 or 0.015)
        if delay > 0 then
            task.delay(delay, function()
                if self._visibilityRevision == revision and not self._destroyed then
                    category:SetVisible(state)
                end
            end)
        else
            category:SetVisible(state, instant)
        end
    end

    if state and self._blurSize > 0 then
        if not self._blur or not self._blur.Parent then
            self._blur = create("BlurEffect", {
                Name = self._blurName,
                Size = 0,
                Enabled = true,
            }, Lighting)
        end
        if instant then
            self._blur.Size = self._blurSize
        else
            tween(self._blur, MOTION.Medium, { Size = self._blurSize })
        end
    elseif not state and self._blur then
        if instant then
            self._blur:Destroy()
            self._blur = nil
        else
            tween(self._blur, MOTION.Fast, { Size = 0 })
            task.delay(0.18, function()
                if self._visibilityRevision == revision and not self._visible and self._blur then
                    self._blur:Destroy()
                    self._blur = nil
                end
            end)
        end
    end
    return self
end

function Window:Toggle()
    return self:SetVisible(not self._visible)
end

local function cleanupWindow(window)
    window._destroyed = true
    for _, connection in ipairs(window._connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    window._connections = {}
    if window._blur then
        window._blur:Destroy()
        window._blur = nil
    end
end

function Window:Destroy()
    if self._destroyed then
        return
    end
    cleanupWindow(self)
    if self.Gui then
        self.Gui:Destroy()
    end
end

local nextWindowId = 0

function VantaUI:CreateWindow(options)
    options = options or {}
    nextWindowId = nextWindowId + 1

    local player = Players.LocalPlayer
    local parent = options.Parent
    if not parent and player then
        parent = player:WaitForChild("PlayerGui")
    end
    assert(parent, "[VantaUI] A PlayerGui or custom Parent is required")

    local guiName = options.Name or "VantaUI"
    if options.ReplaceExisting ~= false then
        local existing = parent:FindFirstChild(guiName)
        if existing and existing:IsA("ScreenGui") then
            existing:Destroy()
        end
    end

    local theme = makeTheme(options)
    local gui = create("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = options.DisplayOrder or 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)

    local self = setmetatable({
        Gui = gui,
        Theme = theme,
        Categories = {},
        _components = {},
        _flags = {},
        _connections = {},
        _notifications = {},
        _id = nextWindowId,
        _visible = false,
        _visibilityRevision = 0,
        _capturing = false,
        _destroyed = false,
        _columnWidth = options.ColumnWidth or 196,
        _columnHeight = options.ColumnHeight or 500,
        _columnGap = options.ColumnGap or 10,
        _columnY = options.ColumnY or options.Y or 64,
        _blurSize = clamp(options.Blur or 0, 0, 24),
        _blurName = guiName .. "_Blur",
        _zOrder = 0,
    }, Window)

    listen(self, gui.Destroying, function()
        if not self._destroyed then
            cleanupWindow(self)
        end
    end)

    -- The only full-size visual container is the ScreenGui itself. Category
    -- panels are direct children, so there is no invisible window hitbox.
    local notifications = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.fromOffset(320, 410),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 1000,
    }, gui)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    }, notifications)
    self._notificationHolder = notifications

    local function bindCamera()
        local camera = Workspace.CurrentCamera
        if camera then
            listen(self, camera:GetPropertyChangedSignal("ViewportSize"), function()
                self:LayoutCategories()
            end)
        end
    end
    listen(self, Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
        bindCamera()
        self:LayoutCategories()
    end)
    bindCamera()

    local toggleKey = Enum.KeyCode.RightShift
    if options.ToggleKey ~= nil then
        toggleKey = options.ToggleKey
    end
    if toggleKey ~= false then
        listen(self, UserInputService.InputBegan, function(input, gameProcessed)
            if gameProcessed or self._capturing or UserInputService:GetFocusedTextBox() then
                return
            end
            if input.KeyCode == toggleKey then
                self:Toggle()
            end
        end)
    end

    task.defer(function()
        if not self._destroyed then
            self:LayoutCategories()
            if options.Visible ~= false then
                self:SetVisible(true)
            end
        end
    end)

    return self
end

return VantaUI

end)()

local window = VantaUI:CreateWindow({
    Name = "VantaUI",
    Accent = Color3.fromRGB(237, 45, 72),
    ColumnWidth = 196,
    ColumnHeight = 500,
    ColumnGap = 10,
    ColumnY = 64,
    ToggleKey = Enum.KeyCode.RightShift,
    Blur = 0,
})

local combat = window:AddCategory({ Title = "Combat", Icon = "C" })
local movement = window:AddCategory({ Title = "Movement", Icon = "M" })
local player = window:AddCategory({ Title = "Player", Icon = "P" })
local utility = window:AddCategory({ Title = "Utility", Icon = "U" })
local render = window:AddCategory({ Title = "Render", Icon = "R" })

-- Every component can own an inline settings panel. The panel pushes the
-- following rows down inside this exact column; no popup window is created.
local aura = combat:AddToggle({
    Title = "Kill Aura",
    Description = "Click the chevron for settings",
    Default = true,
    Flag = "combat.aura",
    Callback = function(enabled)
        print("Kill Aura:", enabled)
    end,
})

aura:AddSettings(function(settings)
    settings:AddDropdown({
        Title = "Mode",
        Values = { "Single", "Multi", "Priority" },
        Default = "Priority",
        Flag = "combat.auraMode",
    })
    settings:AddSlider({
        Title = "Range",
        Min = 1,
        Max = 12,
        Step = 0.25,
        Default = 4.5,
        Suffix = " m",
        Flag = "combat.range",
    })
    settings:AddSlider({
        Title = "Attack speed",
        Min = 1,
        Max = 20,
        Step = 1,
        Default = 8,
        Suffix = "/s",
    })
    settings:AddToggle({
        Title = "Auto block",
        Default = false,
    })
    settings:AddKeybind({
        Title = "Toggle bind",
        Default = Enum.KeyCode.R,
        Callback = function()
            aura:Set(not aura:Get())
        end,
    })
end)

local autoPotion = combat:AddToggle({
    Title = "Auto Potion",
    Default = false,
    Callback = function(enabled)
        print("Auto Potion:", enabled)
    end,
})
autoPotion:AddSettings(function(settings)
    settings:AddSlider({
        Title = "Health threshold",
        Min = 10,
        Max = 100,
        Step = 5,
        Default = 45,
        Suffix = "%",
    })
    settings:AddDropdown({
        Title = "Potion",
        Values = { "Normal", "Strong", "Splash" },
        Default = "Strong",
    })
end)

combat:AddToggle({ Title = "Auto Armor", Default = true })
combat:AddToggle({ Title = "Criticals", Default = false })
combat:AddButton({
    Title = "Test notification",
    RightText = "Run",
    Callback = function()
        window:Notify({
            Title = "Combat",
            Content = "Buttons include press, ripple and state animations.",
            Type = "Success",
            Duration = 3,
        })
    end,
})

local flight = movement:AddToggle({
    Title = "Flight",
    Description = "Inline motion settings",
    Default = false,
})
flight:AddSettings(function(settings)
    settings:AddSlider({
        Title = "Speed",
        Min = 0.5,
        Max = 5,
        Step = 0.1,
        Default = 1.8,
        Suffix = "×",
    })
    settings:AddDropdown({
        Title = "Mode",
        Values = { "Smooth", "Instant", "Glide" },
    })
    settings:AddToggle({ Title = "Vertical control", Default = true })
end)

movement:AddToggle({ Title = "Auto Sprint", Default = true })
movement:AddToggle({ Title = "No Slow Down", Default = false })
movement:AddSlider({
    Title = "Walk Speed",
    Min = 8,
    Max = 32,
    Step = 1,
    Default = 16,
    Flag = "movement.walkSpeed",
})
movement:AddKeybind({
    Title = "Panic key",
    Default = Enum.KeyCode.X,
    Callback = function()
        window:Notify({ Title = "Panic key pressed", Type = "Warning", Duration = 2 })
    end,
})

player:AddTextbox({
    Title = "Display name",
    Placeholder = "Enter a name...",
    Default = "Player",
    Callback = function(text, enterPressed)
        print("Name:", text, "Submitted with Enter:", enterPressed)
    end,
})
player:AddToggle({ Title = "Auto Leave", Default = false })
player:AddToggle({ Title = "Free Camera", Default = false })
player:AddDropdown({
    Title = "Camera mode",
    Values = { "First person", "Third person", "Orbit" },
    Default = "Third person",
})
player:AddButton({
    Title = "Read a flag",
    RightText = "Print",
    Callback = function()
        print("combat.range =", window:GetFlag("combat.range"))
    end,
})

utility:AddColorPicker({
    Title = "Interface accent preview",
    Default = Color3.fromRGB(237, 45, 72),
    Callback = function(color)
        print("Selected RGB:", color)
    end,
})
utility:AddDropdown({
    Title = "Config",
    Values = { "Default", "Legit", "Custom" },
    Default = "Default",
})
utility:AddToggle({ Title = "Client Sounds", Default = true })
utility:AddToggle({ Title = "Middle Click", Default = false })
utility:AddSeparator()
utility:AddLabel({
    Title = "VantaUI 2.0",
    Description = "Independent draggable panels",
})

render:AddToggle({
    Title = "ESP",
    Default = true,
    Settings = function(settings)
        settings:AddToggle({ Title = "Names", Default = true })
        settings:AddToggle({ Title = "Distance", Default = true })
        settings:AddSlider({
            Title = "Max distance",
            Min = 50,
            Max = 1000,
            Step = 50,
            Default = 400,
            Suffix = " studs",
        })
        settings:AddColorPicker({
            Title = "Highlight",
            Default = Color3.fromRGB(237, 45, 72),
        })
    end,
})
render:AddToggle({ Title = "Trails", Default = false })
render:AddToggle({ Title = "World Ambience", Default = true })
render:AddToggle({ Title = "HUD", Default = true })
render:AddButton({
    Title = "Success toast",
    Callback = function()
        window:Notify({
            Title = "Settings saved",
            Content = "The demo configuration is ready.",
            Type = "Success",
        })
    end,
})

window:Notify({
    Title = "VantaUI loaded",
    Content = "Open a chevron to see settings slide directly into its column.",
    Type = "Info",
    Duration = 5,
})


print("[VantaUI] Example ready. Press Right Shift to toggle the interface.")
