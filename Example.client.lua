-- VantaUI 3.3 standalone example
-- Separate Config Manager and Theme Editor windows, HSV colors and linked particles.
-- Paste this ENTIRE file into a LocalScript in StarterPlayerScripts.
-- No ModuleScript, ReplicatedStorage setup or additional files are required.
-- In Roblox Studio use Play / Play Solo, not the server-only Run mode.
-- Lucide / lucide-roblox license notices are embedded near the end of the module.

print("[VantaUI] Example is starting...")

local VantaUI = (function()
--[[
    VantaUI 3.3.0
    Independent, draggable column panels for Roblox, written in Luau.

    Interface only: no game logic, remotes, executor APIs or external HTTP requests.
    Icons use Roblox-hosted Lucide sprite sheets; see THIRD_PARTY_NOTICES.md.
    Place this file in a ModuleScript and see Example.client.lua for usage.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local VantaUI = {}
VantaUI.Version = "3.3.0"

local MOTION = {
    Instant = TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    Fast = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    Medium = TweenInfo.new(0.20, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Slow = TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Spring = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Drag = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    Reveal = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
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

local activeTweens = setmetatable({}, { __mode = "k" })

local function tween(instance, info, properties)
    local active = activeTweens[instance]
    if not active then
        active = {}
        activeTweens[instance] = active
    end
    for property in pairs(properties) do
        if active[property] then
            active[property]:Cancel()
        end
    end

    local animation = TweenService:Create(instance, info or MOTION.Fast, properties)
    for property in pairs(properties) do
        active[property] = animation
    end
    animation.Completed:Connect(function()
        for property in pairs(properties) do
            if active[property] == animation then
                active[property] = nil
            end
        end
    end)
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
    local accent = options.Accent or overrides.Accent or Color3.fromRGB(145, 116, 222)
    local surface = overrides.Surface or Color3.fromRGB(35, 31, 50)

    local theme = {
        Column = Color3.fromRGB(22, 20, 35),
        Header = Color3.fromRGB(25, 22, 39),
        Surface = surface,
        SurfaceHover = Color3.fromRGB(47, 40, 66),
        Inset = Color3.fromRGB(20, 18, 31),
        Track = Color3.fromRGB(67, 61, 86),
        Stroke = Color3.fromRGB(86, 73, 119),
        Text = Color3.fromRGB(235, 233, 246),
        SubText = Color3.fromRGB(174, 168, 194),
        Muted = Color3.fromRGB(126, 119, 150),
        White = Color3.fromRGB(255, 255, 255),
        Success = Color3.fromRGB(70, 211, 138),
        Warning = Color3.fromRGB(245, 183, 73),
        Danger = Color3.fromRGB(244, 82, 101),
        Info = Color3.fromRGB(91, 157, 245),
        Accent = accent,
    }

    theme.AccentDark = blend(accent, Color3.new(0, 0, 0), 0.38)
    theme.AccentSoft = blend(surface, accent, 0.16)
    theme.AccentText = blend(accent, Color3.new(1, 1, 1), 0.52)
    theme.SurfaceActive = blend(surface, accent, 0.13)

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
        Font = font or Enum.Font.BuilderSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Active = false,
    }, parent)
end

-- Lucide 0.363 sprite data: https://github.com/latte-soft/lucide-roblox
-- { asset id, rect x, rect y }; every source tile is 48 x 48.
local LUCIDE_ICONS = {
    combat = { 16898613777, 967, 759 }, -- swords
    sword = { 16898613777, 710, 967 },
    movement = { 16898613613, 453, 820 }, -- move
    speed = { 16898612819, 967, 710 }, -- chevrons-right
    player = { 16898613869, 661, 869 }, -- user
    user = { 16898613869, 661, 869 },
    visuals = { 16898613353, 771, 563 }, -- eye
    render = { 16898613353, 771, 563 },
    eye = { 16898613353, 771, 563 },
    settings = { 16898613777, 771, 257 },
    gear = { 16898613777, 771, 257 },
    utility = { 16898613777, 820, 355 }, -- sliders-horizontal
    sliders = { 16898613777, 820, 355 },
    camera = { 16898612819, 967, 563 },
    color = { 16898613613, 453, 918 }, -- palette
    palette = { 16898613613, 453, 918 },
    world = { 16898613509, 771, 563 }, -- globe
    misc = { 16898613509, 918, 404 }, -- layout-grid
    grid = { 16898613509, 918, 404 },
    ["chevron-right"] = { 16898612819, 869, 759 },
    ["chevron-down"] = { 16898612819, 196, 918 },
}

local function makeIcon(parent, name, color, size)
    local key = string.lower(tostring(name or "grid"))
    local asset = LUCIDE_ICONS[key] or LUCIDE_ICONS.grid
    local image = "rbxassetid://" .. tostring(asset[1])
    local rectSize = Vector2.new(48, 48)
    local rectOffset = Vector2.new(asset[2], asset[3])

    -- A direct asset URL can still be supplied by library users.
    if string.match(key, "^rbxassetid://%d+$") then
        image = key
        rectSize = Vector2.new()
        rectOffset = Vector2.new()
    end

    return create("ImageLabel", {
        Name = "Icon",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = image,
        ImageColor3 = color,
        ImageRectSize = rectSize,
        ImageRectOffset = rectOffset,
        Size = UDim2.fromOffset(size or 16, size or 16),
        Active = false,
    }, parent)
end

local function makeChevron(parent, color, size)
    return makeIcon(parent, "chevron-right", color, size or 14)
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

local function showHoverDescription(window, component)
    local frame = window._descriptionFrame
    local label = window._descriptionLabel
    local text = component._descriptionText
    if not frame or not label or not text or text == "" or not window._visible or window._destroyed then
        return
    end

    window._descriptionRevision = (window._descriptionRevision or 0) + 1
    window._descriptionOwner = component
    label.Text = text
    if not frame.Visible then
        frame.GroupTransparency = 1
        frame.Position = UDim2.new(0.5, 0, 1, -16)
        frame.Visible = true
    end
    tween(frame, MOTION.Fast, {
        GroupTransparency = 0,
        Position = UDim2.new(0.5, 0, 1, -24),
    })
end

local function hideHoverDescription(window, component, instant)
    local frame = window._descriptionFrame
    if not frame or (component ~= nil and window._descriptionOwner ~= component) then
        return
    end

    window._descriptionRevision = (window._descriptionRevision or 0) + 1
    local revision = window._descriptionRevision
    window._descriptionOwner = nil
    if instant then
        frame.Visible = false
        frame.GroupTransparency = 1
        return
    end

    tween(frame, MOTION.Fast, {
        GroupTransparency = 1,
        Position = UDim2.new(0.5, 0, 1, -16),
    })
    task.delay(0.13, function()
        if window._descriptionRevision == revision and not window._descriptionOwner and frame.Parent then
            frame.Visible = false
        end
    end)
end

local function createItem(container, options)
    local window = container.Window
    local theme = window.Theme
    local hasInlineDescription = options.Description ~= nil and options.Description ~= ""
        and options.InlineDescription == true
    local height = options.Height or 36

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
        Padding = UDim.new(0, 3),
    }, root)

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.26,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = 1,
        Active = false,
    }, root)
    corner(header, options.Radius or 6)
    local headerStroke = stroke(header, theme.Stroke, 0.76, 1)

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

    local left = options.LeftPadding or (options.Icon and 34 or 10)
    local itemIcon
    if options.Icon then
        itemIcon = makeIcon(header, options.Icon, theme.SubText, 15)
        itemIcon.Position = UDim2.fromOffset(9, (height - 15) * 0.5)
        itemIcon.ZIndex = 3
    end

    local title = makeText(header, options.Title, options.TextSize or 14, theme.Text, Enum.Font.BuilderSansMedium)
    title.Name = "Title"
    title.Position = UDim2.fromOffset(left, hasInlineDescription and 4 or 0)
    title.Size = UDim2.new(1, -(left + 10), 0, hasInlineDescription and 20 or height)
    title.ZIndex = 3

    local description
    if hasInlineDescription then
        description = makeText(header, options.Description, 12, theme.SubText, Enum.Font.BuilderSans)
        description.Name = "Description"
        description.Position = UDim2.fromOffset(left, 26)
        description.Size = UDim2.new(1, -(left + 10), 0, 16)
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
        Hitbox = hitbox,
        Title = title,
        Description = description,
        Icon = itemIcon,
        Right = right,
        RightWidth = 0,
        LeftPadding = left,
        Height = height,
        SearchText = string.lower(tostring(options.Title or "") .. " " .. tostring(options.Description or "")),
        _descriptionText = options.Description ~= nil and tostring(options.Description) or nil,
        _titleX = left,
        _titleY = hasInlineDescription and 4 or 0,
        _active = false,
        _hovered = false,
        _destroyed = false,
    }, Component)

    function self:RefreshBackground(animated)
        local color = theme.Surface
        local backgroundTransparency = 0.26
        local borderColor = theme.Stroke
        local borderTransparency = 0.76
        if self._active then
            color = self._hovered and blend(theme.SurfaceActive, theme.Accent, 0.025) or theme.SurfaceActive
            backgroundTransparency = self._hovered and 0.15 or 0.20
            borderColor = theme.Accent
            borderTransparency = 0.58
        elseif self._hovered then
            color = theme.SurfaceHover
            backgroundTransparency = 0.18
        end
        local titleColor = self._active and theme.AccentText or theme.Text
        local properties = {
            BackgroundColor3 = color,
            BackgroundTransparency = backgroundTransparency,
        }
        if animated == false then
            header.BackgroundColor3 = properties.BackgroundColor3
            header.BackgroundTransparency = properties.BackgroundTransparency
            headerStroke.Color = borderColor
            headerStroke.Transparency = borderTransparency
            self.Title.TextColor3 = titleColor
        else
            tween(header, MOTION.Fast, properties)
            tween(headerStroke, MOTION.Fast, {
                Color = borderColor,
                Transparency = borderTransparency,
            })
            tween(self.Title, MOTION.Fast, { TextColor3 = titleColor })
        end
    end

    listen(window, header.MouseEnter, function()
        if options.Interactive ~= false then
            self._hovered = true
            self:RefreshBackground(true)
        end
        if self._descriptionText and not options.InlineDescription then
            showHoverDescription(window, self)
        end
    end)
    listen(window, header.MouseLeave, function()
        if options.Interactive ~= false then
            self._hovered = false
            self:RefreshBackground(true)
        end
        if window._descriptionOwner == self then
            hideHoverDescription(window, self, false)
        end
    end)
    listen(window, root.Destroying, function()
        if window._descriptionOwner == self then
            hideHoverDescription(window, self, true)
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
        Position = UDim2.fromOffset(0, -4),
        BackgroundColor3 = theme.Inset,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
        Active = false,
    }, root)
    corner(content, 8)
    stroke(content, theme.Stroke, 0.78, 1)
    padding(content, pad, pad, pad, pad)

    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 7),
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
                content.Position = UDim2.fromOffset(0, -4)
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
                    Position = UDim2.fromOffset(0, -3),
                    GroupTransparency = 1,
                })
                task.delay(0.21, function()
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
        Size = UDim2.fromOffset(22, 22),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    addRightControl(self, gear, 22, 99)

    local icon = makeIcon(gear, "settings", theme.SubText, 14)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.ZIndex = 6

    local panel = createInlinePanel(self, "InlineSettings", 6)
    panel._onStateChanged = function(open)
        tween(icon, MOTION.Medium, {
            Rotation = open and 90 or 0,
            ImageColor3 = open and theme.AccentText or theme.SubText,
        })
    end

    listen(self.Window, gear.Activated, function()
        panel:Toggle()
    end)
    listen(self.Window, gear.MouseEnter, function()
        tween(icon, MOTION.Fast, { ImageColor3 = theme.Text })
    end)
    listen(self.Window, gear.MouseLeave, function()
        tween(icon, MOTION.Fast, { ImageColor3 = panel.Open and theme.AccentText or theme.SubText })
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
end

function Component:SetVisible(state)
    self.Root.Visible = state and true or false
    return self
end

function Component:SetTitle(text)
    self.Title.Text = tostring(text)
    self.SearchText = string.lower(tostring(text) .. " " .. (self._descriptionText or ""))
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
    component._configKey = options.Flag or ("component." .. tostring(#container.Window._components + 1))
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
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 6,
    })
    corner(track, 10)
    addRightControl(component, track, 38, 1)

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
        local rightText = makeText(component.Right, options.RightText, 11, theme.SubText, Enum.Font.BuilderSansMedium)
        rightText.Size = UDim2.fromOffset(56, 20)
        rightText.TextXAlignment = Enum.TextXAlignment.Right
        addRightControl(component, rightText, 56, 1)
    else
        local icon = makeChevron(component.Right, theme.Muted, 14)
        addRightControl(component, icon, 14, 1)
    end

    listen(self.Window, component.Hitbox.Activated, function()
        component:SetActive(true, true)
        task.delay(0.16, function()
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
    options.Height = options.Height or 46
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

    local valueText = makeText(component.Right, "", 12, theme.SubText, Enum.Font.BuilderSansMedium)
    valueText.Size = UDim2.fromOffset(46, 20)
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    addRightControl(component, valueText, 46, 1)

    component.Right.AnchorPoint = Vector2.new(1, 0)
    component.Right.Position = UDim2.new(1, -8, 0, 1)
    component.Right.Size = UDim2.new(0, component.RightWidth, 0, 20)
    component.Title.Position = UDim2.fromOffset(component.LeftPadding, 1)
    component.Title.Size = UDim2.new(1, -(component.LeftPadding + component.RightWidth + 20), 0, 20)
    if component.Description then
        component.Description.Position = UDim2.fromOffset(component.LeftPadding, 25)
        component.Description.Visible = false
    end

    local track = create("Frame", {
        Name = "Track",
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(0, 10, 0, 28),
        Size = UDim2.new(1, -20, 0, 4),
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        ZIndex = 3,
        Active = false,
    }, component.Header)
    corner(track, 4)
    local trackStroke = stroke(track, theme.Accent, 1, 1)

    local fill = create("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 4,
        Active = false,
    }, track)
    corner(fill, 4)

    local knob = create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = theme.White,
        BorderSizePixel = 0,
        ZIndex = 5,
        Active = false,
    }, track)
    corner(knob, 7)
    local knobScale = create("UIScale", { Scale = 1 }, knob)
    local halo = create("Frame", {
        Name = "DragGlow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 4,
    }, knob)
    corner(halo, 12)

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
    local hovering = false
    local dragInput

    local function refreshVisual()
        tween(halo, MOTION.Fast, {
            BackgroundTransparency = dragging and 0.64 or (hovering and 0.84 or 1),
        })
        tween(knobScale, MOTION.Fast, {
            Scale = dragging and 1.16 or (hovering and 1.08 or 1),
        })
        tween(trackStroke, MOTION.Fast, {
            Transparency = dragging and 0.35 or (hovering and 0.68 or 1),
        })
        tween(valueText, MOTION.Fast, {
            TextColor3 = dragging and theme.AccentText or (hovering and theme.Text or theme.SubText),
        })
    end

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
            refreshVisual()
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
            refreshVisual()
        end
    end)
    listen(self.Window, hitbox.MouseEnter, function()
        hovering = true
        refreshVisual()
    end)
    listen(self.Window, hitbox.MouseLeave, function()
        hovering = false
        refreshVisual()
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

    local valueText = makeText(component.Right, tostring(value or "None"), 11, theme.SubText, Enum.Font.BuilderSans)
    valueText.Size = UDim2.fromOffset(76, 20)
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    addRightControl(component, valueText, 76, 1)

    local icon = makeChevron(component.Right, theme.Muted, 14)
    addRightControl(component, icon, 14, 2)

    local panel = createInlinePanel(component, "DropdownOptions", 6)
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
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = theme.Surface,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
            }, panel.Content)
            corner(button, 6)

            local label = makeText(button, tostring(entryValue), 12, theme.SubText, Enum.Font.BuilderSans)
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
        Size = UDim2.fromOffset(62, 26),
        BackgroundColor3 = theme.Inset,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 6,
    })
    corner(keyBox, 6)
    local keyStroke = stroke(keyBox, theme.Stroke, 0.72, 1)
    addRightControl(component, keyBox, 62, 1)

    local label = makeText(keyBox, keyName(value), 11, theme.SubText, Enum.Font.BuilderSansMedium)
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
    options.Height = options.Height or 64
    options.Interactive = false
    local theme = self.Window.Theme
    local component = createItem(self, options)
    local value = tostring(options.Default or "")

    component.Title.Position = UDim2.fromOffset(component.LeftPadding, 4)
    component.Title.Size = UDim2.new(1, -(component.LeftPadding + 12), 0, 20)
    if component.Description then
        component.Description.Visible = false
    end

    local box = create("Frame", {
        Name = "Input",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -7),
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
        TextSize = 12,
        Font = Enum.Font.BuilderSans,
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
    local hue, saturation, brightness = Color3.toHSV(value)

    local preview = create("Frame", {
        Name = "Preview",
        Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = value,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 6,
    })
    corner(preview, 7)
    stroke(preview, theme.White, 0.70, 1)
    addRightControl(component, preview, 26, 1)

    local icon = makeChevron(component.Right, theme.Muted, 14)
    addRightControl(component, icon, 14, 2)

    local panel = createInlinePanel(component, "ColorSettings", 6)
    panel._onStateChanged = function(open)
        tween(icon, MOTION.Fast, {
            Rotation = open and 90 or 0,
            ImageColor3 = open and theme.AccentText or theme.Muted,
        })
        component:SetActive(open, true)
    end
    listen(self.Window, component.Hitbox.Activated, function()
        panel:Toggle()
    end)

    local picker = create("Frame", {
        Name = "HSVPicker",
        Size = UDim2.new(1, 0, 0, 174),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
    }, panel.Content)

    local saturationBox = create("Frame", {
        Name = "SaturationValue",
        Size = UDim2.new(1, 0, 0, 120),
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Active = false,
    }, picker)
    corner(saturationBox, 7)

    local saturationLayer = create("Frame", {
        Name = "Saturation",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Active = false,
    }, saturationBox)
    corner(saturationLayer, 7)
    create("UIGradient", {
        Rotation = 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, saturationLayer)

    local valueLayer = create("Frame", {
        Name = "Value",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Active = false,
    }, saturationBox)
    corner(valueLayer, 7)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, valueLayer)

    local cursorOuter = create("Frame", {
        Name = "CursorOuter",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 6,
    }, saturationBox)
    corner(cursorOuter, 8)
    stroke(cursorOuter, Color3.new(0, 0, 0), 0.15, 3)
    local cursorInner = create("Frame", {
        Name = "CursorInner",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 7,
    }, saturationBox)
    corner(cursorInner, 6)
    stroke(cursorInner, Color3.new(1, 1, 1), 0, 1.5)

    local svHitbox = create("TextButton", {
        Name = "SVHitbox",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 8,
    }, saturationBox)

    local hueBar = create("Frame", {
        Name = "Hue",
        Position = UDim2.fromOffset(0, 130),
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Active = false,
    }, picker)
    corner(hueBar, 7)
    create("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        }),
    }, hueBar)
    local hueCursor = create("Frame", {
        Name = "HueCursor",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(hue, 0, 0.5, 0),
        Size = UDim2.fromOffset(5, 20),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 6,
    }, hueBar)
    corner(hueCursor, 2)
    stroke(hueCursor, Color3.new(0, 0, 0), 0.30, 1)
    local hueHitbox = create("TextButton", {
        Name = "HueHitbox",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 7,
    }, hueBar)

    local hexLabel = makeText(picker, "", 12, theme.SubText, Enum.Font.BuilderSansMedium)
    hexLabel.Name = "Hex"
    hexLabel.Position = UDim2.fromOffset(0, 152)
    hexLabel.Size = UDim2.new(1, 0, 0, 18)
    hexLabel.TextXAlignment = Enum.TextXAlignment.Center

    local function refresh(newColor, notify, synchronize)
        value = newColor
        if synchronize then
            hue, saturation, brightness = Color3.toHSV(value)
        end
        preview.BackgroundColor3 = value
        saturationBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        cursorOuter.Position = UDim2.new(saturation, 0, 1 - brightness, 0)
        cursorInner.Position = cursorOuter.Position
        hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
        hexLabel.Text = string.format(
            "#%02X%02X%02X",
            math.floor(value.R * 255 + 0.5),
            math.floor(value.G * 255 + 0.5),
            math.floor(value.B * 255 + 0.5)
        )
        if notify then
            safeCallback(options.Callback, value)
        end
    end

    local draggingSV = false
    local draggingHue = false
    local dragInput

    local function updateSV(position)
        if saturationBox.AbsoluteSize.X <= 0 or saturationBox.AbsoluteSize.Y <= 0 then
            return
        end
        saturation = clamp((position.X - saturationBox.AbsolutePosition.X) / saturationBox.AbsoluteSize.X, 0, 1)
        brightness = 1 - clamp((position.Y - saturationBox.AbsolutePosition.Y) / saturationBox.AbsoluteSize.Y, 0, 1)
        refresh(Color3.fromHSV(hue, saturation, brightness), true, false)
    end

    local function updateHue(position)
        if hueBar.AbsoluteSize.X <= 0 then
            return
        end
        hue = clamp((position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
        refresh(Color3.fromHSV(hue, saturation, brightness), true, false)
    end

    listen(self.Window, svHitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV = true
            draggingHue = false
            dragInput = input
            updateSV(input.Position)
        end
    end)
    listen(self.Window, hueHitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            draggingSV = false
            dragInput = input
            updateHue(input.Position)
        end
    end)
    listen(self.Window, UserInputService.InputChanged, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= dragInput then
            return
        end
        if draggingSV then
            updateSV(input.Position)
        elseif draggingHue then
            updateHue(input.Position)
        end
    end)
    listen(self.Window, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragInput then
            draggingSV = false
            draggingHue = false
            dragInput = nil
        end
    end)

    function component:Get()
        return value
    end

    function component:Set(newColor)
        refresh(newColor, true, true)
        return component
    end

    function component:SetSilent(newColor)
        refresh(newColor, false, true)
        return component
    end

    refresh(value, false, true)
    return finalize(self, component, options)
end

function Container:AddLabel(options)
    options = options or {}
    options.Title = options.Title or options.Name or "Label"
    options.Interactive = false
    options.InlineDescription = true
    options.Height = options.Height or (options.Description and 48 or 34)
    local component = createItem(self, options)
    component.Header.BackgroundTransparency = 1
    component.HeaderStroke.Transparency = 1
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

local BACKGROUND_MODES = {
    parallax = "Parallax",
    particles = "Particles",
    image = "Image",
    none = "None",
}
local MAX_PARTICLES = 80
local MAX_PARTICLE_LINKS = 240

local function normalizeBackgroundMode(mode)
    local normalized = BACKGROUND_MODES[string.lower(tostring(mode or "Parallax"))]
    assert(normalized, "[VantaUI] Background mode must be Parallax, Particles, Image or None")
    return normalized
end

local function deterministicNoise(index, salt)
    local value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453
    return value - math.floor(value)
end

local function createBackground(window)
    local theme = window.Theme
    local root = create("CanvasGroup", {
        Name = "Backdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
        Active = false,
        ZIndex = 1,
    }, window.Gui)

    local groups = {}
    for _, name in ipairs({ "Parallax", "Particles", "Image" }) do
        groups[name] = create("CanvasGroup", {
            Name = name,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            GroupTransparency = 1,
            ClipsDescendants = true,
            Visible = false,
            Active = false,
            ZIndex = 1,
        }, root)
    end

    local parallaxItems = {}
    local ringSpecs = {
        { 0.06, 0.16, 190, 0.55 },
        { 0.23, 0.80, 110, 0.85 },
        { 0.42, 0.10, 84, 1.10 },
        { 0.57, 0.88, 220, 0.50 },
        { 0.75, 0.18, 130, 0.95 },
        { 0.93, 0.72, 180, 0.65 },
        { 0.87, 0.40, 72, 1.20 },
        { 0.13, 0.48, 66, 1.30 },
    }
    for index, spec in ipairs(ringSpecs) do
        local diameter = spec[3]
        local ring = create("Frame", {
            Name = "ParallaxRing" .. index,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(spec[1], spec[2]),
            Size = UDim2.fromOffset(diameter, diameter),
            BackgroundColor3 = index % 3 == 0 and theme.AccentText or theme.Accent,
            BackgroundTransparency = 0.92,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 1,
        }, groups.Parallax)
        corner(ring, diameter * 0.5)
        stroke(ring, theme.Accent, 0.70, 1)
        parallaxItems[index] = {
            Frame = ring,
            BaseX = spec[1],
            BaseY = spec[2],
            Depth = spec[4],
            Phase = index * 0.83,
        }
    end

    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local particles = {}
    for index = 1, MAX_PARTICLES do
        local diameter = 3 + math.floor(deterministicNoise(index, 1) * 4)
        local angle = deterministicNoise(index, 2) * math.pi * 2
        local particle = create("Frame", {
            Name = "Particle" .. index,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(diameter, diameter),
            BackgroundColor3 = index % 4 == 0 and theme.AccentText or theme.Accent,
            BackgroundTransparency = 0.40,
            BorderSizePixel = 0,
            Active = false,
            Visible = index <= 28,
            ZIndex = 2,
        }, groups.Particles)
        corner(particle, diameter * 0.5)
        particles[index] = {
            Frame = particle,
            X = 20 + deterministicNoise(index, 3) * math.max(viewport.X - 40, 1),
            Y = 20 + deterministicNoise(index, 4) * math.max(viewport.Y - 40, 1),
            DirectionX = math.cos(angle),
            DirectionY = math.sin(angle),
            Radius = diameter * 0.5,
            Phase = index * 0.61,
            BaseTransparency = 0.34 + deterministicNoise(index, 5) * 0.28,
        }
    end

    local image = create("ImageLabel", {
        Name = "BackgroundImage",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1.06, 0, 1.06, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "",
        ImageTransparency = 0.35,
        ScaleType = Enum.ScaleType.Crop,
        Active = false,
        ZIndex = 1,
    }, groups.Image)
    local imageShade = create("Frame", {
        Name = "ImageShade",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.78,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 2,
    }, groups.Image)

    window._backgroundRoot = root
    window._backgroundGroups = groups
    window._background = {
        Mode = "Parallax",
        Image = "",
        ImageTransparency = 0.35,
        ImageDim = 0.22,
        ParticleCount = 28,
        ParticleSpeed = 42,
        ParticleLinkDistance = 110,
        ParticleLinks = true,
        ParallaxStrength = 32,
    }
    window._backgroundMode = "None"
    window._backgroundRevision = 0
    window._backgroundTime = 0
    window._backgroundImage = image
    window._backgroundImageShade = imageShade
    window._parallaxItems = parallaxItems
    window._particles = particles
    window._particleLinks = {}
    window._pointer = nil
    window._smoothPointerX = 0
    window._smoothPointerY = 0
end

local function setBackgroundMode(window, mode, instant)
    mode = normalizeBackgroundMode(mode)
    instant = instant or not window._visible
    if window._backgroundMode == mode and not instant then
        return
    end

    window._backgroundMode = mode
    window._background.Mode = mode
    window._backgroundRevision = window._backgroundRevision + 1
    local revision = window._backgroundRevision
    local root = window._backgroundRoot
    if mode ~= "None" and window._visible and not root.Visible then
        root.GroupTransparency = 0
        root.Visible = true
    end

    for name, group in pairs(window._backgroundGroups) do
        if name == mode then
            group.Visible = true
            if instant then
                group.GroupTransparency = 0
            else
                group.GroupTransparency = 1
                tween(group, MOTION.Reveal, { GroupTransparency = 0 })
            end
        elseif group.Visible then
            if instant then
                group.Visible = false
                group.GroupTransparency = 1
            else
                tween(group, MOTION.Medium, { GroupTransparency = 1 })
                task.delay(0.21, function()
                    if window._backgroundRevision == revision and window._backgroundMode ~= name and group.Parent then
                        group.Visible = false
                    end
                end)
            end
        end
    end

    if mode == "None" then
        if instant then
            root.Visible = false
            root.GroupTransparency = 1
        else
            task.delay(0.21, function()
                if window._backgroundRevision == revision and window._backgroundMode == "None" and root.Parent then
                    root.Visible = false
                end
            end)
        end
    end
end

function Window:SetBackground(options)
    if self._destroyed then
        return self
    end
    if options == nil then
        options = {}
    elseif options == false then
        options = { Mode = "None" }
    elseif type(options) == "string" then
        options = { Mode = options }
    end
    assert(type(options) == "table", "[VantaUI] SetBackground expects a table, string or false")

    local config = self._background
    if options.Image ~= nil then
        config.Image = tostring(options.Image)
        self._backgroundImage.Image = config.Image
    end
    if options.ImageTransparency ~= nil then
        config.ImageTransparency = clamp(options.ImageTransparency, 0, 1)
        self._backgroundImage.ImageTransparency = config.ImageTransparency
    end
    if options.ImageDim ~= nil then
        config.ImageDim = clamp(options.ImageDim, 0, 1)
        self._backgroundImageShade.BackgroundTransparency = 1 - config.ImageDim
    end
    if options.ParticleCount ~= nil then
        config.ParticleCount = math.floor(clamp(options.ParticleCount, 0, MAX_PARTICLES))
        for index, particle in ipairs(self._particles) do
            particle.Frame.Visible = index <= config.ParticleCount
        end
    end
    if options.ParticleSpeed ~= nil then
        config.ParticleSpeed = clamp(options.ParticleSpeed, 0, 160)
    end
    if options.ParticleLinkDistance ~= nil then
        config.ParticleLinkDistance = clamp(options.ParticleLinkDistance, 40, 240)
    end
    if options.ParticleLinks ~= nil then
        config.ParticleLinks = options.ParticleLinks == true
    end
    if options.ParallaxStrength ~= nil then
        config.ParallaxStrength = clamp(options.ParallaxStrength, 0, 80)
    end
    if options.Mode ~= nil then
        setBackgroundMode(self, options.Mode, false)
    elseif self._backgroundMode == "None" and config.Mode ~= "None" then
        setBackgroundMode(self, config.Mode, false)
    end
    return self
end

function Window:SetBackgroundMode(mode)
    if not self._destroyed then
        setBackgroundMode(self, mode, false)
    end
    return self
end

function Window:GetBackground()
    local copy = {}
    for key, value in pairs(self._background) do
        copy[key] = value
    end
    return copy
end

local function setBackgroundVisible(window, state, instant)
    local root = window._backgroundRoot
    if not root then
        return
    end
    if state and window._backgroundMode ~= "None" then
        root.Visible = true
        if instant then
            root.GroupTransparency = 0
        else
            root.GroupTransparency = 1
            tween(root, MOTION.Reveal, { GroupTransparency = 0 })
        end
    elseif instant then
        root.Visible = false
        root.GroupTransparency = 1
    else
        tween(root, MOTION.Fast, { GroupTransparency = 1 })
        task.delay(0.13, function()
            if not window._visible and root.Parent then
                root.Visible = false
            end
        end)
    end
end

local function updateParticleLinks(window)
    local links = window._particleLinks
    local particles = window._particles
    local count = window._background.ParticleCount
    local maximumDistance = window._background.ParticleLinkDistance
    local maximumDistanceSquared = maximumDistance * maximumDistance
    local linkCount = 0

    if window._background.ParticleLinks then
        for first = 1, count - 1 do
            local a = particles[first]
            for second = first + 1, count do
                local b = particles[second]
                local deltaX = b.X - a.X
                local deltaY = b.Y - a.Y
                local distanceSquared = deltaX * deltaX + deltaY * deltaY
                if distanceSquared < maximumDistanceSquared then
                    linkCount = linkCount + 1
                    local line = links[linkCount]
                    if not line then
                        line = create("Frame", {
                            Name = "ParticleLink" .. linkCount,
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundColor3 = window.Theme.Accent,
                            BorderSizePixel = 0,
                            Active = false,
                            ZIndex = 1,
                        }, window._backgroundGroups.Particles)
                        links[linkCount] = line
                    end
                    local distance = math.sqrt(distanceSquared)
                    line.Position = UDim2.fromOffset((a.X + b.X) * 0.5, (a.Y + b.Y) * 0.5)
                    line.Size = UDim2.fromOffset(distance, 1)
                    line.Rotation = math.deg(math.atan2(deltaY, deltaX))
                    line.BackgroundTransparency = 0.70 + 0.28 * (distance / maximumDistance)
                    line.Visible = true
                    if linkCount >= MAX_PARTICLE_LINKS then
                        break
                    end
                end
            end
            if linkCount >= MAX_PARTICLE_LINKS then
                break
            end
        end
    end

    for index = linkCount + 1, #links do
        links[index].Visible = false
    end
end

local function updateBackground(window, deltaTime)
    if not window._visible or not window._backgroundRoot.Visible or window._backgroundMode == "None" then
        return
    end
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    if viewport.X <= 0 or viewport.Y <= 0 then
        return
    end

    local step = math.min(deltaTime, 0.05)
    window._backgroundTime = window._backgroundTime + step
    local time = window._backgroundTime
    local pointer = UserInputService:GetMouseLocation()
    window._pointer = pointer
    local targetX = (pointer.X / viewport.X - 0.5) * 2
    local targetY = (pointer.Y / viewport.Y - 0.5) * 2
    local smoothing = 1 - math.exp(-step * 10)
    window._smoothPointerX = window._smoothPointerX + (targetX - window._smoothPointerX) * smoothing
    window._smoothPointerY = window._smoothPointerY + (targetY - window._smoothPointerY) * smoothing

    if window._backgroundMode == "Parallax" then
        local strength = window._background.ParallaxStrength
        for _, item in ipairs(window._parallaxItems) do
            local driftX = math.sin(time * 0.22 + item.Phase) * 8
            local driftY = math.cos(time * 0.18 + item.Phase) * 7
            item.Frame.Position = UDim2.new(
                item.BaseX,
                window._smoothPointerX * strength * item.Depth + driftX,
                item.BaseY,
                window._smoothPointerY * strength * item.Depth + driftY
            )
        end
    elseif window._backgroundMode == "Particles" then
        local speed = window._background.ParticleSpeed
        for index = 1, window._background.ParticleCount do
            local particle = window._particles[index]
            particle.X = particle.X + particle.DirectionX * speed * step
            particle.Y = particle.Y + particle.DirectionY * speed * step
            if particle.X < particle.Radius then
                particle.X = particle.Radius
                particle.DirectionX = math.abs(particle.DirectionX)
            elseif particle.X > viewport.X - particle.Radius then
                particle.X = viewport.X - particle.Radius
                particle.DirectionX = -math.abs(particle.DirectionX)
            end
            if particle.Y < particle.Radius then
                particle.Y = particle.Radius
                particle.DirectionY = math.abs(particle.DirectionY)
            elseif particle.Y > viewport.Y - particle.Radius then
                particle.Y = viewport.Y - particle.Radius
                particle.DirectionY = -math.abs(particle.DirectionY)
            end
            particle.Frame.Position = UDim2.fromOffset(particle.X, particle.Y)
            particle.Frame.BackgroundTransparency = clamp(
                particle.BaseTransparency + math.sin(time * 1.5 + particle.Phase) * 0.08,
                0.18,
                0.82
            )
        end
        updateParticleLinks(window)
    elseif window._backgroundMode == "Image" then
        window._backgroundImage.Position = UDim2.new(
            0.5,
            -window._smoothPointerX * 8,
            0.5,
            -window._smoothPointerY * 8
        )
    end
end

function Window:Notify(options)
    options = options or {}
    if self._destroyed then
        return
    end

    local theme = self.Theme
    local kind = options.Type or "Info"
    local accent = theme[kind] or theme.Info
    local hasContent = options.Content ~= nil and options.Content ~= ""
    local height = hasContent and 66 or 48

    local wrapper = create("Frame", {
        Name = "NotificationWrapper",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
    }, self._notificationHolder)

    local toast = create("CanvasGroup", {
        Name = "Notification",
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
    }, wrapper)
    corner(toast, 10)
    stroke(toast, theme.Stroke, 0.58, 1)

    local dot = create("Frame", {
        Name = "AccentDot",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 14, 0, hasContent and 18 or 24),
        Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Active = false,
    }, toast)
    corner(dot, 4)

    local title = makeText(toast, options.Title or kind, 14, theme.Text, Enum.Font.BuilderSansBold)
    title.Position = UDim2.fromOffset(32, hasContent and 7 or 0)
    title.Size = UDim2.new(1, -46, 0, hasContent and 22 or height)

    local content
    if hasContent then
        content = makeText(toast, options.Content, 12, theme.SubText, Enum.Font.BuilderSans)
        content.Position = UDim2.fromOffset(32, 30)
        content.Size = UDim2.new(1, -44, 0, 28)
        content.TextWrapped = true
        content.TextTruncate = Enum.TextTruncate.None
        content.TextYAlignment = Enum.TextYAlignment.Top
    end

    local dismissed = false
    local record
    local function dismiss()
        if dismissed or self._destroyed or not wrapper.Parent then
            return
        end
        dismissed = true
        tween(toast, MOTION.Fast, {
            Position = UDim2.fromOffset(10, 4),
            GroupTransparency = 1,
        })
        task.delay(0.13, function()
            if wrapper.Parent then
                wrapper:Destroy()
            end
        end)
        if record then
            for index, notification in ipairs(self._notifications) do
                if notification == record then
                    table.remove(self._notifications, index)
                    break
                end
            end
        end
    end

    record = { Wrapper = wrapper, Dismiss = dismiss }
    table.insert(self._notifications, record)
    if #self._notifications > 4 then
        local oldest = table.remove(self._notifications, 1)
        oldest.Dismiss()
    end

    tween(toast, MOTION.Reveal, {
        Position = UDim2.fromOffset(0, 0),
        GroupTransparency = 0,
    })

    local duration = options.Duration or 4
    if duration > 0 then
        task.delay(duration, function()
            if not dismissed and not self._destroyed and wrapper.Parent then
                dismiss()
            end
        end)
    end

    return {
        Dismiss = dismiss,
        Wrapper = wrapper,
        Title = title,
        Content = content,
        Accent = dot,
    }
end

local SCREEN_MARGIN = 8

local function clampCategoryPosition(category, x, y)
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local frame = category.Root
    local width = frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.X or category._width
    local height = frame.AbsoluteSize.Y > 0 and frame.AbsoluteSize.Y
        or (category._targetHeight or frame.Size.Y.Offset)
    local maximumX = math.max(SCREEN_MARGIN, viewport.X - width - SCREEN_MARGIN)
    local maximumY = math.max(SCREEN_MARGIN, viewport.Y - height - SCREEN_MARGIN)
    return clamp(x, SCREEN_MARGIN, maximumX), clamp(y, SCREEN_MARGIN, maximumY)
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
            local positionX, positionY = clampCategoryPosition(category, x, self._columnY)
            category.Root.Position = UDim2.fromOffset(positionX, positionY)
            category._targetPosition = Vector2.new(positionX, positionY)
            category._velocityX = 0
            category._velocityY = 0
        else
            local currentX, currentY = clampCategoryPosition(
                category,
                category.Root.Position.X.Offset,
                category.Root.Position.Y.Offset
            )
            local target = category._targetPosition or Vector2.new(currentX, currentY)
            local targetX, targetY = clampCategoryPosition(category, target.X, target.Y)
            category.Root.Position = UDim2.fromOffset(currentX, currentY)
            category._targetPosition = Vector2.new(targetX, targetY)
            category._velocityX = 0
            category._velocityY = 0
        end
        x = x + category._width + self._columnGap
    end
end

local LOCAL_BLUR_DEPTH = 0.02
local LOCAL_BLUR_SCALE = 6.8
local LOCAL_GLASS_OPACITY = 0.02
local LOCAL_PART_THICKNESS = 0.001

local function updateCategoryMotion(category, deltaTime)
    local frame = category.Root
    local target = category._targetPosition
    if not target or not frame.Parent then
        return
    end

    local targetX, targetY = clampCategoryPosition(category, target.X, target.Y)
    if targetX ~= target.X or targetY ~= target.Y then
        target = Vector2.new(targetX, targetY)
        category._targetPosition = target
    end

    local currentX = frame.Position.X.Offset
    local currentY = frame.Position.Y.Offset
    local boundedX, boundedY = clampCategoryPosition(category, currentX, currentY)
    local clampedCurrent = boundedX ~= currentX or boundedY ~= currentY
    currentX, currentY = boundedX, boundedY
    local velocityX = category._velocityX or 0
    local velocityY = category._velocityY or 0
    if clampedCurrent then
        velocityX = 0
        velocityY = 0
    end

    local offsetX = currentX - target.X
    local offsetY = currentY - target.Y
    if math.abs(offsetX) < 0.02 and math.abs(offsetY) < 0.02
        and math.abs(velocityX) < 0.05 and math.abs(velocityY) < 0.05 then
        if clampedCurrent or currentX ~= target.X or currentY ~= target.Y then
            frame.Position = UDim2.fromOffset(target.X, target.Y)
        end
        category._velocityX = 0
        category._velocityY = 0
        return
    end

    -- Exact critically damped spring. Unlike explicit Euler integration this
    -- remains stable after frame spikes and never overshoots the pointer.
    local frequency = category._dragging and 34 or 26
    local step = math.min(deltaTime, 0.1)
    local decay = math.exp(-frequency * step)
    local coefficientX = velocityX + frequency * offsetX
    local coefficientY = velocityY + frequency * offsetY
    local nextOffsetX = (offsetX + coefficientX * step) * decay
    local nextOffsetY = (offsetY + coefficientY * step) * decay

    local nextVelocityX = (velocityX - frequency * coefficientX * step) * decay
    local nextVelocityY = (velocityY - frequency * coefficientY * step) * decay
    local nextX, nextY = clampCategoryPosition(
        category,
        target.X + nextOffsetX,
        target.Y + nextOffsetY
    )
    if nextX ~= target.X + nextOffsetX then
        nextVelocityX = 0
    end
    if nextY ~= target.Y + nextOffsetY then
        nextVelocityY = 0
    end
    category._velocityX = nextVelocityX
    category._velocityY = nextVelocityY
    frame.Position = UDim2.fromOffset(nextX, nextY)
end

local function makeLocalGlassPart(name, shape, parent)
    return create("Part", {
        Name = name,
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Color = Color3.new(0.64, 0.635, 0.65),
        Material = Enum.Material.Glass,
        Shape = shape,
        Size = Vector3.new(LOCAL_PART_THICKNESS, LOCAL_PART_THICKNESS, LOCAL_PART_THICKNESS),
        Transparency = 1,
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
    }, parent)
end

local function ensureLocalBlurContainer(window)
    if not window._localBlur or window._destroyed then
        return nil
    end
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end
    if not window._blurContainer or not window._blurContainer.Parent then
        window._blurContainer = create("Folder", {
            Name = window._blurName .. "_Geometry",
        }, camera)
    elseif window._blurContainer.Parent ~= camera then
        window._blurContainer.Parent = camera
    end
    return window._blurContainer
end

local function ensureCategoryBlur(category)
    if category._blur and not category._blur.Model.Parent then
        category._blur = nil
    end
    if category._blur then
        return category._blur
    end
    local window = category.Window
    local container = ensureLocalBlurContainer(window)
    if not container or not category.Root.Parent then
        return nil
    end

    local model = create("Model", {
        Name = category.Root.Name .. "_Backdrop",
    }, container)
    local data = {
        Model = model,
        Vertical = makeLocalGlassPart("Vertical", Enum.PartType.Block, model),
        Horizontal = makeLocalGlassPart("Horizontal", Enum.PartType.Block, model),
        Corners = {},
        Transparency = 1,
        Hidden = true,
    }
    for index = 1, 4 do
        data.Corners[index] = makeLocalGlassPart("Corner" .. index, Enum.PartType.Cylinder, model)
    end
    category._blur = data
    return data
end

local function setLocalBlurTransparency(data, transparency)
    if data.Transparency == transparency then
        return
    end
    data.Transparency = transparency
    data.Vertical.Transparency = transparency
    data.Horizontal.Transparency = transparency
    for _, part in ipairs(data.Corners) do
        part.Transparency = transparency
    end
end

local function setPartTransform(part, size, cframe)
    if part.Size ~= size then
        part.Size = size
    end
    if part.CFrame ~= cframe then
        part.CFrame = cframe
    end
end

local function updateCategoryBlur(category)
    local window = category.Window
    if not window._localBlur then
        return
    end
    local data = ensureCategoryBlur(category)
    if not data then
        return
    end

    local frame = category.Root
    local camera = Workspace.CurrentCamera
    local shouldRender = window._visible
        and category._visible
        and window._depthOfField ~= nil
        and window._depthOfField.Parent ~= nil
        and frame.Visible
        and frame.Parent ~= nil
        and camera ~= nil

    if not shouldRender then
        if not data.Hidden then
            setLocalBlurTransparency(data, 1)
            data.Hidden = true
        end
        return
    end

    local absolutePosition = frame.AbsolutePosition
    local absoluteSize = frame.AbsoluteSize
    if absoluteSize.X <= 0 or absoluteSize.Y <= 0 or camera.ViewportSize.Y <= 0 then
        setLocalBlurTransparency(data, 1)
        data.Hidden = true
        return
    end

    data.Hidden = false
    setLocalBlurTransparency(data, 1 - LOCAL_GLASS_OPACITY * (1 - frame.GroupTransparency))

    -- Only the projected glass geometry is near the camera. FarIntensity = 0
    -- keeps the actual game world sharp; there is no full-screen BlurEffect.
    local centerX = absolutePosition.X + absoluteSize.X * 0.5
    local centerY = absolutePosition.Y + absoluteSize.Y * 0.5
    local ray = camera:ScreenPointToRay(centerX, centerY, LOCAL_BLUR_DEPTH)
    local center = ray.Origin + ray.Direction * LOCAL_BLUR_DEPTH
    local scaleFactor = LOCAL_BLUR_SCALE
        * LOCAL_BLUR_DEPTH
        * math.tan(math.rad(camera.FieldOfView * 0.5))
        * 2
        / camera.ViewportSize.Y
    local width = absoluteSize.X * scaleFactor
    local height = absoluteSize.Y * scaleFactor
    local mainCFrame = CFrame.new(center, center - camera.CFrame.LookVector)
        * CFrame.Angles(0, 0, math.rad(frame.AbsoluteRotation))

    local cornerRadius = 0
    if category._corner then
        local radius = category._corner.CornerRadius
        cornerRadius = radius.Offset + radius.Scale * math.min(absoluteSize.X, absoluteSize.Y)
    end
    local radius = clamp(cornerRadius * scaleFactor, 0, math.min(width, height) * 0.5)
    radius = math.max(radius, LOCAL_PART_THICKNESS)

    setPartTransform(
        data.Vertical,
        Vector3.new(math.max(width - radius * 2, LOCAL_PART_THICKNESS), height, LOCAL_PART_THICKNESS),
        mainCFrame
    )
    setPartTransform(
        data.Horizontal,
        Vector3.new(width, math.max(height - radius * 2, LOCAL_PART_THICKNESS), LOCAL_PART_THICKNESS),
        mainCFrame
    )

    local cornerSize = Vector3.new(LOCAL_PART_THICKNESS, radius * 2, radius * 2)
    local offsetX = width * 0.5 - radius
    local offsetY = height * 0.5 - radius
    local signs = {
        { -1, 1 },
        { 1, 1 },
        { -1, -1 },
        { 1, -1 },
    }
    for index, part in ipairs(data.Corners) do
        local sign = signs[index]
        local cframe = mainCFrame
            * CFrame.new(sign[1] * offsetX, sign[2] * offsetY, 0)
            * CFrame.Angles(0, math.pi * 0.5, 0)
        setPartTransform(part, cornerSize, cframe)
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
        Size = UDim2.fromOffset(width, 53),
        BackgroundColor3 = theme.Column,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
        Active = true,
        ZIndex = 10 + index,
    }, self.Gui)
    local panelCorner = corner(frame, 8)
    local panelStroke = stroke(frame, theme.Stroke, 0.55, 1)
    local scale = create("UIScale", { Scale = 1 }, frame)

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 20,
    }, frame)

    -- A restrained flat header band; no gradient or tint on descendants.
    local headerBackground = create("Frame", {
        Name = "Background",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Header,
        BackgroundTransparency = 0.48,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 20,
    }, header)
    corner(headerBackground, 8)
    create("Frame", {
        Name = "Divider",
        Position = UDim2.fromOffset(0, 39),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = theme.Stroke,
        BackgroundTransparency = 0.58,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 21,
    }, header)

    if options.Icon then
        local icon = makeIcon(header, options.Icon, theme.AccentText, 18)
        icon.Position = UDim2.fromOffset(10, 11)
        icon.ZIndex = 23
    end

    local title = makeText(header, options.Title or "Category", 15, theme.Text, Enum.Font.BuilderSansMedium)
    title.Position = UDim2.new()
    title.Size = UDim2.fromScale(1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.ZIndex = 23

    local body = create("ScrollingFrame", {
        Name = "Items",
        Position = UDim2.fromOffset(4, 44),
        Size = UDim2.new(1, -8, 0, 0),
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
        Padding = UDim.new(0, 3),
    }, body)
    padding(body, 4, 4, 2, 6)

    local category = setmetatable({
        Window = self,
        Frame = body,
        Root = frame,
        Header = header,
        Title = title,
        Border = panelStroke,
        _corner = panelCorner,
        _scale = scale,
        _targetPosition = nil,
        _velocityX = 0,
        _velocityY = 0,
        _dragging = false,
        _width = width,
        _maxHeight = options.Height or self._columnHeight,
        _minHeight = options.MinHeight or self._minColumnHeight,
        _positioned = options.Position ~= nil,
        _visible = false,
        _visibilityRevision = 0,
        _order = 0,
        _items = {},
    }, Category)
    listen(self, frame.Destroying, function()
        if category._blur then
            category._blur.Model:Destroy()
            category._blur = nil
        end
    end)

    local function updateHeight(animated)
        if not frame.Parent then
            return
        end
        local contentHeight = bodyLayout.AbsoluteContentSize.Y + 8 -- UIPadding: 2 top + 6 bottom
        local minimumHeight = math.min(category._minHeight, category._maxHeight)
        local totalHeight = clamp(
            math.max(53, contentHeight + 48),
            minimumHeight,
            category._maxHeight
        )
        local bodyHeight = math.max(0, totalHeight - 48)
        category._targetHeight = totalHeight

        local frameSize = UDim2.fromOffset(width, totalHeight)
        local bodySize = UDim2.new(1, -8, 0, bodyHeight)
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

    local function setDragVisual(active)
        category._dragging = active
        tween(scale, MOTION.Drag, { Scale = active and 1.006 or 1 })
        tween(frame, MOTION.Drag, { BackgroundTransparency = active and 0.22 or 0.28 })
        tween(panelStroke, MOTION.Fast, {
            Color = active and theme.Accent or theme.Stroke,
            Transparency = active and 0.48 or 0.55,
        })
    end

    local function endDrag()
        if not dragging then
            return
        end
        dragging = false
        dragInput = nil
        setDragVisual(false)
    end
    category._cancelDrag = endDrag

    listen(self, header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPosition = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
            category._targetPosition = startPosition
            self._zOrder = self._zOrder + 1
            frame.ZIndex = 20 + self._zOrder
            setDragVisual(true)
        end
    end)
    listen(self, UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput then
            local delta = input.Position - dragStart
            category._positioned = true
            -- Only the spring target changes here. The rendered position is
            -- integrated on PreRender, so pickup, movement and release share
            -- one continuous motion instead of snapping to the pointer.
            local targetX, targetY = clampCategoryPosition(
                category,
                startPosition.X + delta.X,
                startPosition.Y + delta.Y
            )
            category._targetPosition = Vector2.new(targetX, targetY)
        end
    end)
    listen(self, UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragInput) then
            endDrag()
        end
    end)

    table.insert(self.Categories, category)
    self:LayoutCategories()
    if not category._targetPosition then
        category._targetPosition = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
    end
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
    if not state and self._cancelDrag then
        self._cancelDrag()
    end
    if self._visible == state and not instant then
        return self
    end
    self._visible = state
    self._visibilityRevision = self._visibilityRevision + 1
    local revision = self._visibilityRevision

    if state then
        self.Root.Visible = true
        self._updateHeight(false)
        self._scale.Scale = 1
        if instant then
            self.Root.GroupTransparency = 0
        else
            if self._targetPosition then
                self.Root.Position = UDim2.fromOffset(self._targetPosition.X, self._targetPosition.Y + 4)
                self._velocityX = 0
                self._velocityY = 0
            end
            self.Root.GroupTransparency = 1
            tween(self.Root, MOTION.Reveal, { GroupTransparency = 0 })
        end
    else
        if instant then
            self.Root.Visible = false
            self.Root.GroupTransparency = 1
        else
            tween(self.Root, MOTION.Fast, { GroupTransparency = 1 })
            task.delay(0.13, function()
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
    local x, y = clampCategoryPosition(self, position.X.Offset, position.Y.Offset)
    self._targetPosition = Vector2.new(x, y)
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

function Window:GetConfig()
    local config = {}
    for _, component in ipairs(self._components) do
        if not component._destroyed and component.Get and component._configKey then
            config[component._configKey] = component:Get()
        end
    end
    return config
end

function Window:ApplyConfig(config)
    assert(type(config) == "table", "[VantaUI] ApplyConfig expects a table")
    for _, component in ipairs(self._components) do
        local value = config[component._configKey]
        if not component._destroyed and value ~= nil and component.Set then
            component:Set(value)
        end
    end
    return self
end

local function colorsEqual(first, second)
    return typeof(first) == "Color3" and typeof(second) == "Color3"
        and math.abs(first.R - second.R) < 0.0001
        and math.abs(first.G - second.G) < 0.0001
        and math.abs(first.B - second.B) < 0.0001
end

local function shouldPreservePickerColor(instance, gui)
    local current = instance
    while current and current ~= gui do
        if current.Name == "HSVPicker" or current.Name == "Preview" then
            return true
        end
        current = current.Parent
    end
    return false
end

function Window:SetTheme(overrides)
    if self._destroyed then
        return self
    end
    assert(type(overrides) == "table", "[VantaUI] SetTheme expects a table")
    if overrides.Accent ~= nil then
        self._accent = overrides.Accent
    end
    for key, value in pairs(overrides) do
        if key ~= "Accent" then
            self._themeOverrides[key] = value
        end
    end

    local oldTheme = {}
    for key, value in pairs(self.Theme) do
        oldTheme[key] = value
    end
    local newTheme = makeTheme({
        Accent = self._accent,
        Theme = self._themeOverrides,
    })

    local function mappedColor(color)
        for key, oldColor in pairs(oldTheme) do
            if colorsEqual(color, oldColor) then
                return newTheme[key]
            end
        end
        return nil
    end

    for _, instance in ipairs(self.Gui:GetDescendants()) do
        if not shouldPreservePickerColor(instance, self.Gui) then
            if instance:IsA("UIStroke") then
                local mapped = mappedColor(instance.Color)
                if mapped then
                    instance.Color = mapped
                end
            elseif instance:IsA("GuiObject") then
                local mapped = mappedColor(instance.BackgroundColor3)
                if mapped then
                    instance.BackgroundColor3 = mapped
                end
                if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
                    mapped = mappedColor(instance.TextColor3)
                    if mapped then
                        instance.TextColor3 = mapped
                    end
                end
                if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
                    mapped = mappedColor(instance.ImageColor3)
                    if mapped then
                        instance.ImageColor3 = mapped
                    end
                end
                if instance:IsA("ScrollingFrame") then
                    mapped = mappedColor(instance.ScrollBarImageColor3)
                    if mapped then
                        instance.ScrollBarImageColor3 = mapped
                    end
                end
            end
        end
    end

    -- Mutate rather than replace: all existing control closures share this table.
    for key, value in pairs(newTheme) do
        self.Theme[key] = value
    end
    return self
end

function Window:SetAccent(color)
    return self:SetTheme({ Accent = color })
end

function Window:GetTheme()
    local copy = {}
    for key, value in pairs(self.Theme) do
        copy[key] = value
    end
    return copy
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

    if not state then
        hideHoverDescription(self, nil, true)
    end
    setBackgroundVisible(self, state, instant)
    for _, category in ipairs(self.Categories) do
        category:SetVisible(state, instant)
    end

    if state and self._localBlur then
        if not self._depthOfField or not self._depthOfField.Parent then
            self._depthOfField = create("DepthOfFieldEffect", {
                Name = self._blurName,
                FarIntensity = 0,
                FocusDistance = 0,
                InFocusRadius = 0,
                NearIntensity = 0,
                Enabled = true,
            }, Lighting)
        end
        if instant then
            self._depthOfField.NearIntensity = 1
        else
            tween(self._depthOfField, MOTION.Fast, { NearIntensity = 1 })
        end
    elseif not state and self._depthOfField then
        if instant then
            self._depthOfField:Destroy()
            self._depthOfField = nil
        else
            tween(self._depthOfField, MOTION.Fast, { NearIntensity = 0 })
            task.delay(0.13, function()
                if self._visibilityRevision == revision and not self._visible and self._depthOfField then
                    self._depthOfField:Destroy()
                    self._depthOfField = nil
                end
            end)
        end
    end
    for _, category in ipairs(self.Categories) do
        updateCategoryBlur(category)
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
    if window._depthOfField then
        window._depthOfField:Destroy()
        window._depthOfField = nil
    end
    if window._blurContainer then
        window._blurContainer:Destroy()
        window._blurContainer = nil
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
        _columnWidth = options.ColumnWidth or 230,
        _columnHeight = options.ColumnHeight or 540,
        _minColumnHeight = options.MinColumnHeight or 400,
        _columnGap = options.ColumnGap or 10,
        _columnY = options.ColumnY or options.Y or 64,
        _localBlur = true,
        _blurName = guiName .. "_LocalBlur",
        _depthOfField = nil,
        _blurContainer = nil,
        _zOrder = 0,
    }, Window)
    local blurOption = options.LocalBlur
    if blurOption == nil then
        blurOption = options.Blur -- Backward-compatible boolean/number option.
    end
    self._localBlur = blurOption ~= false and blurOption ~= 0
    self._accent = theme.Accent
    self._themeOverrides = {}
    for key, value in pairs(options.Theme or {}) do
        self._themeOverrides[key] = value
    end

    createBackground(self)
    self:SetBackground(options.Background)

    local descriptionFrame = create("CanvasGroup", {
        Name = "HoverDescription",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -16),
        Size = UDim2.fromOffset(580, 56),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
        Active = false,
        ZIndex = 900,
    }, gui)
    local descriptionLabel = makeText(descriptionFrame, "", 17, theme.Text, Enum.Font.BuilderSansMedium)
    descriptionLabel.Name = "Description"
    descriptionLabel.Position = UDim2.fromOffset(16, 0)
    descriptionLabel.Size = UDim2.new(1, -32, 1, 0)
    descriptionLabel.TextWrapped = true
    descriptionLabel.TextTruncate = Enum.TextTruncate.None
    descriptionLabel.TextXAlignment = Enum.TextXAlignment.Center
    descriptionLabel.ZIndex = 901
    stroke(descriptionLabel, Color3.new(0, 0, 0), 0.45, 1)
    self._descriptionFrame = descriptionFrame
    self._descriptionLabel = descriptionLabel
    self._descriptionOwner = nil
    self._descriptionRevision = 0

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
        Size = UDim2.fromOffset(340, 430),
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
        Padding = UDim.new(0, 10),
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
        ensureLocalBlurContainer(self)
        self:LayoutCategories()
    end)
    bindCamera()
    ensureLocalBlurContainer(self)
    listen(self, RunService.PreRender, function(deltaTime)
        if self._destroyed then
            return
        end
        updateBackground(self, deltaTime)
        for _, category in ipairs(self.Categories) do
            updateCategoryMotion(category, deltaTime)
            updateCategoryBlur(category)
        end
    end)

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

local function trimConfigName(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function VantaUI:CreateConfigManager(target, options)
    assert(type(target) == "table" and target.Gui, "[VantaUI] A target window is required")
    options = options or {}
    local manager = VantaUI:CreateWindow({
        Name = options.Name or target.Gui.Name .. "_Configs",
        Parent = options.Parent or target.Gui.Parent,
        Accent = options.Accent or target.Theme.Accent,
        ColumnWidth = options.Width or 300,
        ColumnHeight = options.Height or 480,
        MinColumnHeight = options.MinHeight or 0,
        Background = false,
        LocalBlur = options.LocalBlur ~= false,
        ToggleKey = false,
        Visible = false,
        DisplayOrder = target.Gui.DisplayOrder + 2,
    })
    local panel = manager:AddCategory({
        Title = options.Title or "Config Manager",
        Icon = "utility",
        Width = options.Width or 300,
        Height = options.Height or 480,
        MinHeight = 0,
        Position = options.Position or UDim2.fromOffset(24, 104),
    })

    local configs = { Default = target:GetConfig() }
    local order = { "Default" }
    local selected = "Default"
    local selector
    local nameInput
    local status

    local function refreshSelection()
        selector:Refresh(order, true)
        selector:SetSilent(selected)
    end

    local function save()
        local name = trimConfigName(nameInput:Get())
        if name == "" then
            name = selected
        end
        if name == "" then
            status:SetTitle("Enter a config name")
            return
        end
        if not configs[name] then
            table.insert(order, name)
        end
        configs[name] = target:GetConfig()
        selected = name
        refreshSelection()
        nameInput:SetSilent("")
        status:SetTitle("Saved · " .. name)
    end

    local function load()
        local config = configs[selected]
        if not config then
            status:SetTitle("Config not found")
            return
        end
        target:ApplyConfig(config)
        status:SetTitle("Loaded · " .. selected)
    end

    local function delete()
        if selected == "Default" then
            status:SetTitle("Default is protected")
            return
        end
        if not configs[selected] then
            return
        end
        local deleted = selected
        configs[selected] = nil
        for index, name in ipairs(order) do
            if name == selected then
                table.remove(order, index)
                break
            end
        end
        selected = "Default"
        refreshSelection()
        status:SetTitle("Deleted · " .. deleted)
    end

    selector = panel:AddDropdown({
        Title = "Config",
        Values = order,
        Default = selected,
        Callback = function(value)
            selected = value
        end,
    })
    nameInput = panel:AddTextbox({
        Title = "New config name",
        Placeholder = "Leave empty to overwrite",
        Default = "",
    })
    panel:AddButton({ Title = "Save / Create", RightText = "Save", Callback = save })
    panel:AddButton({ Title = "Load selected", RightText = "Load", Callback = load })
    panel:AddButton({ Title = "Delete selected", RightText = "Delete", Callback = delete })
    status = panel:AddLabel({ Title = "Default ready" })
    panel:AddButton({
        Title = "Close config manager",
        RightText = "Close",
        Callback = function()
            manager:SetVisible(false)
        end,
    })

    target.Gui.Destroying:Connect(function()
        if not manager._destroyed then
            manager:Destroy()
        end
    end)

    local api = { Window = manager, Panel = panel, Configs = configs, Order = order }
    function api:Show()
        manager:SetVisible(true)
        return self
    end
    function api:Hide()
        manager:SetVisible(false)
        return self
    end
    function api:Save(name)
        if name ~= nil then
            nameInput:SetSilent(name)
        end
        save()
        return self
    end
    function api:Load(name)
        if name ~= nil then
            if not configs[name] then
                status:SetTitle("Config not found")
                return self
            end
            selected = name
            refreshSelection()
        end
        load()
        return self
    end
    function api:Delete(name)
        if name ~= nil then
            if not configs[name] then
                return self
            end
            selected = name
            refreshSelection()
        end
        delete()
        return self
    end
    return api
end

local THEME_PRESETS = {
    Violet = {
        Accent = Color3.fromRGB(145, 116, 222), Column = Color3.fromRGB(22, 20, 35),
        Header = Color3.fromRGB(25, 22, 39), Surface = Color3.fromRGB(35, 31, 50),
        SurfaceHover = Color3.fromRGB(47, 40, 66), Inset = Color3.fromRGB(20, 18, 31),
        Track = Color3.fromRGB(67, 61, 86), Stroke = Color3.fromRGB(86, 73, 119),
    },
    Lavender = {
        Accent = Color3.fromRGB(165, 138, 228), Column = Color3.fromRGB(25, 22, 38),
        Header = Color3.fromRGB(29, 25, 43), Surface = Color3.fromRGB(39, 33, 53),
        SurfaceHover = Color3.fromRGB(52, 43, 71), Inset = Color3.fromRGB(22, 19, 34),
        Track = Color3.fromRGB(70, 62, 91), Stroke = Color3.fromRGB(96, 80, 130),
    },
    Blue = {
        Accent = Color3.fromRGB(90, 148, 224), Column = Color3.fromRGB(19, 24, 36),
        Header = Color3.fromRGB(22, 28, 42), Surface = Color3.fromRGB(29, 37, 52),
        SurfaceHover = Color3.fromRGB(38, 49, 68), Inset = Color3.fromRGB(17, 22, 34),
        Track = Color3.fromRGB(52, 70, 94), Stroke = Color3.fromRGB(62, 88, 124),
    },
    Rose = {
        Accent = Color3.fromRGB(214, 112, 150), Column = Color3.fromRGB(30, 22, 33),
        Header = Color3.fromRGB(35, 26, 39), Surface = Color3.fromRGB(43, 31, 45),
        SurfaceHover = Color3.fromRGB(57, 39, 59), Inset = Color3.fromRGB(25, 19, 29),
        Track = Color3.fromRGB(82, 58, 78), Stroke = Color3.fromRGB(112, 71, 94),
    },
    Emerald = {
        Accent = Color3.fromRGB(82, 181, 145), Column = Color3.fromRGB(18, 28, 28),
        Header = Color3.fromRGB(22, 34, 33), Surface = Color3.fromRGB(28, 41, 39),
        SurfaceHover = Color3.fromRGB(36, 54, 50), Inset = Color3.fromRGB(16, 25, 25),
        Track = Color3.fromRGB(48, 76, 68), Stroke = Color3.fromRGB(58, 99, 86),
    },
}
local THEME_PRESET_ORDER = { "Violet", "Lavender", "Blue", "Rose", "Emerald" }

function VantaUI:CreateThemeEditor(target, options)
    assert(type(target) == "table" and target.Gui, "[VantaUI] A target window is required")
    options = options or {}
    local editor = VantaUI:CreateWindow({
        Name = options.Name or target.Gui.Name .. "_Theme",
        Parent = options.Parent or target.Gui.Parent,
        Accent = options.Accent or target.Theme.Accent,
        ColumnWidth = options.Width or 320,
        ColumnHeight = options.Height or 520,
        MinColumnHeight = options.MinHeight or 0,
        Background = false,
        LocalBlur = options.LocalBlur ~= false,
        ToggleKey = false,
        Visible = false,
        DisplayOrder = target.Gui.DisplayOrder + 3,
    })
    local panel = editor:AddCategory({
        Title = options.Title or "Theme Editor",
        Icon = "color",
        Width = options.Width or 320,
        Height = options.Height or 520,
        MinHeight = 0,
        Position = options.Position or UDim2.fromOffset(920, 104),
    })

    local accentPicker
    local panelPicker
    local surfacePicker
    local strokePicker
    local selector
    local status

    local function syncPickers(preset)
        accentPicker:SetSilent(preset.Accent or target.Theme.Accent)
        panelPicker:SetSilent(preset.Column or target.Theme.Column)
        surfacePicker:SetSilent(preset.Surface or target.Theme.Surface)
        strokePicker:SetSilent(preset.Stroke or target.Theme.Stroke)
    end

    local function applyPreset(name)
        local preset = THEME_PRESETS[name]
        if not preset then
            return
        end
        target:SetTheme(preset)
        syncPickers(preset)
        status:SetTitle(name .. " applied")
    end

    selector = panel:AddDropdown({
        Title = "Theme preset",
        Values = THEME_PRESET_ORDER,
        Default = "Violet",
        Callback = applyPreset,
    })
    accentPicker = panel:AddColorPicker({
        Title = "Accent",
        Default = target.Theme.Accent,
        Callback = function(color)
            target:SetTheme({ Accent = color })
            status:SetTitle("Custom accent")
        end,
    })
    panelPicker = panel:AddColorPicker({
        Title = "Panel background",
        Default = target.Theme.Column,
        Callback = function(color)
            target:SetTheme({ Column = color })
            status:SetTitle("Custom panel color")
        end,
    })
    surfacePicker = panel:AddColorPicker({
        Title = "Row surface",
        Default = target.Theme.Surface,
        Callback = function(color)
            target:SetTheme({ Surface = color })
            status:SetTitle("Custom row color")
        end,
    })
    strokePicker = panel:AddColorPicker({
        Title = "Borders",
        Default = target.Theme.Stroke,
        Callback = function(color)
            target:SetTheme({ Stroke = color })
            status:SetTitle("Custom border color")
        end,
    })
    panel:AddButton({
        Title = "Reset to Violet",
        RightText = "Reset",
        Callback = function()
            selector:SetSilent("Violet")
            applyPreset("Violet")
        end,
    })
    status = panel:AddLabel({ Title = "Live theme preview" })
    panel:AddButton({
        Title = "Close theme editor",
        RightText = "Close",
        Callback = function()
            editor:SetVisible(false)
        end,
    })

    target.Gui.Destroying:Connect(function()
        if not editor._destroyed then
            editor:Destroy()
        end
    end)

    local api = { Window = editor, Panel = panel, Presets = THEME_PRESETS }
    function api:Show()
        editor:SetVisible(true)
        return self
    end
    function api:Hide()
        editor:SetVisible(false)
        return self
    end
    function api:Apply(preset)
        if type(preset) == "string" then
            if THEME_PRESETS[preset] then
                selector:SetSilent(preset)
                applyPreset(preset)
            end
        elseif type(preset) == "table" then
            target:SetTheme(preset)
            syncPickers(preset)
            status:SetTitle("Custom theme applied")
        end
        return self
    end
    return api
end

--[[
THIRD-PARTY NOTICES — Lucide / lucide-roblox
Source: https://github.com/latte-soft/lucide-roblox

lucide-roblox — MIT License
Copyright (c) 2023 Latte Softworks <https://latte.to>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Lucide — ISC License
Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part
of Feather (MIT). All other copyright (c) for Lucide are held by Lucide
Contributors 2022.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
]]

return VantaUI

end)()

local window = VantaUI:CreateWindow({
    Name = "VantaUI",
    Accent = Color3.fromRGB(145, 116, 222),
    ColumnWidth = 230,
    ColumnHeight = 540,
    MinColumnHeight = 400,
    ColumnGap = 10,
    ColumnY = 64,
    ToggleKey = Enum.KeyCode.RightShift,
    LocalBlur = true,
    Background = {
        Mode = "Parallax", -- "Parallax", "Particles", "Image" or "None"
        ParticleCount = 28,
        ParticleSpeed = 42,
        ParticleLinkDistance = 110,
        ParticleLinks = true,
        ParallaxStrength = 32,
        -- Image = "rbxassetid://YOUR_IMAGE_ID",
        ImageTransparency = 0.35,
        ImageDim = 0.22,
    },
})

local combat = window:AddCategory({ Title = "Combat", Icon = "combat" })
local movement = window:AddCategory({ Title = "Movement", Icon = "movement" })
local render = window:AddCategory({ Title = "Visuals", Icon = "visuals" })
local player = window:AddCategory({ Title = "Player", Icon = "player" })
local utility = window:AddCategory({ Title = "Miscellaneous", Icon = "misc" })

local configManager, themeEditor

-- Every component can own an inline settings panel. The panel pushes the
-- following rows down inside this exact column; no popup window is created.
local aura = combat:AddToggle({
    Title = "Kill Aura",
    Description = "Use the gear for inline settings",
    Icon = "combat",
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
combat:AddToggle({ Title = "Auto Explosion", Default = false })
combat:AddToggle({ Title = "Fast Bow", Default = true })
combat:AddToggle({ Title = "Hit Boxes", Default = false })
combat:AddToggle({ Title = "Auto Totem", Default = true })
combat:AddButton({
    Title = "Test notification",
    RightText = "Run",
    Callback = function()
        window:Notify({
            Title = "Combat",
            Content = "Buttons use short, quiet state transitions.",
            Type = "Success",
            Duration = 3,
        })
    end,
})

local flight = movement:AddToggle({
    Title = "Flight",
    Description = "Inline motion settings",
    Icon = "movement",
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
movement:AddToggle({ Title = "Edge Jump", Default = true })
movement:AddToggle({ Title = "No Jump Delay", Default = false })
movement:AddToggle({ Title = "No Push", Default = false })
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
player:AddToggle({ Title = "Auto Eat", Default = true })
player:AddToggle({ Title = "Auto Tool", Default = false })
player:AddToggle({ Title = "Anti AFK", Default = true })
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

utility:AddDropdown({
    Title = "Backdrop",
    Description = "Choose what moves behind the interface",
    Values = { "Parallax", "Particles", "Image", "None" },
    Default = "Parallax",
    Flag = "ui.backdrop",
    Callback = function(mode)
        window:SetBackgroundMode(mode)
    end,
})
utility:AddSlider({
    Title = "Particle count",
    Description = "Particles bounce off the screen edges",
    Min = 8,
    Max = 64,
    Step = 1,
    Default = 28,
    Callback = function(count)
        window:SetBackground({ ParticleCount = count })
    end,
})
utility:AddTextbox({
    Title = "Backdrop image",
    Description = "Paste a Roblox image asset and press Enter",
    Placeholder = "rbxassetid://...",
    Default = "",
    Callback = function(asset, enterPressed)
        if enterPressed and asset ~= "" then
            window:SetBackground({ Mode = "Image", Image = asset })
        end
    end,
})

utility:AddButton({
    Title = "Config Manager",
    Description = "Open named configs in a separate window",
    RightText = "Open",
    Callback = function()
        configManager:Show()
    end,
})
utility:AddButton({
    Title = "Theme Editor",
    Description = "Open live themes in a separate window",
    RightText = "Open",
    Callback = function()
        themeEditor:Show()
    end,
})
utility:AddToggle({ Title = "Client Sounds", Default = true })
utility:AddToggle({ Title = "Middle Click", Default = false })
utility:AddToggle({ Title = "Auto Respawn", Default = true })
utility:AddToggle({ Title = "Click Teleport", Default = false })
utility:AddSeparator()
utility:AddLabel({
    Title = "VantaUI 3.3",
    Description = "Independent draggable panels",
})

render:AddToggle({
    Title = "ESP",
    Icon = "visuals",
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
            Default = Color3.fromRGB(145, 116, 222),
        })
    end,
})
render:AddToggle({ Title = "Trails", Default = false })
render:AddToggle({ Title = "World Ambience", Default = true })
render:AddToggle({ Title = "HUD", Default = true })
render:AddToggle({ Title = "Nametags", Default = true })
render:AddToggle({ Title = "Tracers", Default = false })
render:AddToggle({ Title = "Entity ESP", Default = true })
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

configManager = VantaUI:CreateConfigManager(window)
themeEditor = VantaUI:CreateThemeEditor(window)

window:Notify({
    Title = "VantaUI loaded",
    Content = "Configs and themes now open in separate windows.",
    Type = "Info",
    Duration = 5,
})


print("[VantaUI] Example ready. Press Right Shift to toggle the interface.")
