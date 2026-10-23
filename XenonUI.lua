--[[
    XenonUI 3.0
    Self-contained interface library for Roblox.

    Scope: interface only. No game logic, no remotes, no character or network
    manipulation, no metamethod hooks, no executor specific globals.
]]

local XenonUI = {}
XenonUI._version = "3.0.0"
XenonUI.Version = XenonUI._version

local TweenService    = game:GetService("TweenService")
local UserInputService= game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local TextService     = game:GetService("TextService")
local Lighting        = game:GetService("Lighting")
local Players         = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Tween presets
--------------------------------------------------------------------------------
local T_FAST   = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local T_MED    = TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local T_SLOW   = TweenInfo.new(0.4,  Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local T_SPRING = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

--------------------------------------------------------------------------------
-- Util
--------------------------------------------------------------------------------
local Util = {}

function Util.Tween(object, info, props)
    local tween = TweenService:Create(object, info or T_FAST, props)
    tween:Play()
    return tween
end

function Util.New(className, props, children)
    local object = Instance.new(className)
    if props then
        for key, value in pairs(props) do
            object[key] = value
        end
    end
    if children then
        for index = 1, #children do
            children[index].Parent = object
        end
    end
    return object
end

function Util.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function Util.Round(value, step)
    if not step or step <= 0 then return value end
    return math.floor(value / step + 0.5) * step
end

function Util.LerpColor(from, to, alpha)
    return Color3.new(
        from.R + (to.R - from.R) * alpha,
        from.G + (to.G - from.G) * alpha,
        from.B + (to.B - from.B) * alpha
    )
end

function Util.ToHex(color)
    return string.format("%02X%02X%02X",
        math.floor(math.clamp(color.R, 0, 1) * 255 + 0.5),
        math.floor(math.clamp(color.G, 0, 1) * 255 + 0.5),
        math.floor(math.clamp(color.B, 0, 1) * 255 + 0.5))
end

function Util.FromHex(text)
    local hex = string.gsub(tostring(text), "#", "")
    if #hex ~= 6 then return nil end
    local r = tonumber(string.sub(hex, 1, 2), 16)
    local g = tonumber(string.sub(hex, 3, 4), 16)
    local b = tonumber(string.sub(hex, 5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end

function Util.TextWidth(text, size, font)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, font or Enum.Font.GothamMedium, Vector2.new(1e5, 1e5))
    end)
    if ok and bounds then return bounds.X end
    return #text * size * 0.55
end

--------------------------------------------------------------------------------
-- Maid (resource cleanup)
--------------------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _items = {} }, Maid)
end

function Maid:Add(item)
    if item then
        self._items[#self._items + 1] = item
    end
    return item
end

function Maid:Connect(signal, handler)
    return self:Add(signal:Connect(handler))
end

function Maid:Clean()
    local items = self._items
    for index = #items, 1, -1 do
        local item = items[index]
        items[index] = nil
        if typeof(item) == "RBXScriptConnection" then
            pcall(function() item:Disconnect() end)
        elseif type(item) == "function" then
            pcall(item)
        elseif typeof(item) == "Instance" then
            pcall(function() item:Destroy() end)
        end
    end
    self._items = {}
end

--------------------------------------------------------------------------------
-- Shared frame loop (single connection instead of dozens)
--------------------------------------------------------------------------------
local Scheduler = {}
Scheduler._tasks = {}
Scheduler._connection = nil

function Scheduler:Add(name, callback)
    self._tasks[name] = callback
    self:Start()
    return function() self._tasks[name] = nil end
end

function Scheduler:Start()
    if self._connection then return end
    local last = os.clock()
    self._connection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local delta = now - last
        last = now
        for name, callback in pairs(self._tasks) do
            local ok, err = pcall(callback, delta)
            if not ok then
                self._tasks[name] = nil
                warn("[XenonUI] task '" .. tostring(name) .. "' removed after error: " .. tostring(err))
            end
        end
    end)
end

function Scheduler:Stop()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end

--------------------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------------------
local Theme = {}
Theme._registry = setmetatable({}, { __mode = "k" })
Theme._listeners = {}

Theme.Mode            = "Dark"   -- Dark | Light | System
Theme.Accent          = Color3.fromRGB(140, 118, 255)
Theme.Glass           = true
Theme.GlassTransparency = 0.55
Theme.WorldBlur       = 0        -- 0..24, off by default so the world stays sharp
Theme.Rainbow         = false
Theme.RainbowSpeed    = 0.28
Theme._hue            = 0
Theme._resolvedMode   = "Dark"

local PALETTES = {
    Dark = {
        Backdrop   = Color3.fromRGB(9, 10, 14),
        Surface    = Color3.fromRGB(19, 21, 29),
        SurfaceAlt = Color3.fromRGB(26, 29, 39),
        Card       = Color3.fromRGB(24, 26, 35),
        CardHover  = Color3.fromRGB(31, 34, 45),
        Row        = Color3.fromRGB(22, 24, 32),
        RowHover   = Color3.fromRGB(29, 32, 42),
        Track      = Color3.fromRGB(44, 48, 62),
        Text       = Color3.fromRGB(236, 239, 248),
        SubText    = Color3.fromRGB(154, 160, 179),
        Muted      = Color3.fromRGB(108, 114, 133),
        Stroke     = Color3.fromRGB(255, 255, 255),
        Shadow     = Color3.fromRGB(0, 0, 0),
        Success    = Color3.fromRGB(62, 214, 141),
        Warning    = Color3.fromRGB(255, 189, 74),
        Danger     = Color3.fromRGB(255, 92, 104),
        Info       = Color3.fromRGB(112, 162, 255),
    },
    Light = {
        Backdrop   = Color3.fromRGB(226, 229, 238),
        Surface    = Color3.fromRGB(248, 249, 253),
        SurfaceAlt = Color3.fromRGB(236, 239, 247),
        Card       = Color3.fromRGB(252, 253, 255),
        CardHover  = Color3.fromRGB(240, 243, 251),
        Row        = Color3.fromRGB(246, 248, 253),
        RowHover   = Color3.fromRGB(233, 237, 247),
        Track      = Color3.fromRGB(212, 218, 232),
        Text       = Color3.fromRGB(24, 26, 34),
        SubText    = Color3.fromRGB(96, 102, 122),
        Muted      = Color3.fromRGB(140, 146, 166),
        Stroke     = Color3.fromRGB(16, 20, 34),
        Shadow     = Color3.fromRGB(40, 50, 80),
        Success    = Color3.fromRGB(22, 163, 96),
        Warning    = Color3.fromRGB(196, 132, 12),
        Danger     = Color3.fromRGB(219, 58, 70),
        Info       = Color3.fromRGB(58, 118, 232),
    },
}

local STROKE_ALPHA = { Dark = 0.90, Light = 0.88 }

Theme.Palette = PALETTES.Dark

local function detectSystemMode()
    local ok, theme = pcall(function()
        return settings().Studio.Theme
    end)
    if ok and theme then
        local name = tostring(theme.Name):lower()
        if name:find("dark") then return "Dark" end
        if name:find("light") then return "Light" end
    end
    local hour = tonumber(os.date("%H")) or 12
    if hour >= 8 and hour < 20 then return "Light" end
    return "Dark"
end

function Theme:ResolveMode()
    if self.Mode == "System" then
        return detectSystemMode()
    end
    return self.Mode
end

function Theme:Get(token)
    if token == "Accent" then return self.Accent end
    return self.Palette[token] or self.Palette.Text
end

function Theme:StrokeAlpha()
    return STROKE_ALPHA[self._resolvedMode] or 0.9
end

function Theme:Register(object, property, token)
    if not object then return end
    self._registry[object] = self._registry[object] or {}
    self._registry[object][property] = token
    local value = self:Get(token)
    if value then
        pcall(function() object[property] = value end)
    end
end

function Theme:Unregister(object)
    self._registry[object] = nil
end

function Theme:Refresh(animated)
    self._resolvedMode = self:ResolveMode()
    self.Palette = PALETTES[self._resolvedMode] or PALETTES.Dark
    local duration = animated and 0.28 or 0
    local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    for object, bindings in pairs(self._registry) do
        for property, token in pairs(bindings) do
            local value = self:Get(token)
            if value then
                if duration > 0 then
                    TweenService:Create(object, info, { [property] = value }):Play()
                else
                    pcall(function() object[property] = value end)
                end
            end
        end
    end

    for index = #self._listeners, 1, -1 do
        local ok = pcall(self._listeners[index], self)
        if not ok then table.remove(self._listeners, index) end
    end
end

function Theme:OnChanged(callback)
    self._listeners[#self._listeners + 1] = callback
    return function()
        for index, listener in ipairs(self._listeners) do
            if listener == callback then
                table.remove(self._listeners, index)
                break
            end
        end
    end
end

function Theme:SetMode(mode)
    self.Mode = mode
    self:Refresh(true)
end

function Theme:SetAccent(color)
    self.Accent = color
    self:Refresh(true)
end

--------------------------------------------------------------------------------
-- Icons (drawn from primitives, no external assets and no emoji)
--------------------------------------------------------------------------------
local Icons = {}
Icons._overrides = {}
Icons._live = setmetatable({}, { __mode = "k" })

-- primitive constructors: line / circle / rounded rect, coordinates on a 24x24 grid
local function L(x1, y1, x2, y2, thickness)
    return { kind = "line", x1 = x1, y1 = y1, x2 = x2, y2 = y2, t = thickness or 2 }
end

local function C(cx, cy, r, filled, thickness)
    return { kind = "circle", cx = cx, cy = cy, r = r, filled = filled and true or false, t = thickness or 2 }
end

local function R(x, y, w, h, radius, filled, thickness)
    return { kind = "rect", x = x, y = y, w = w, h = h, r = radius or 0, filled = filled and true or false, t = thickness or 2 }
end

local function teeth(cx, cy, inner, outer, count, thickness, phase)
    local out = {}
    for index = 0, count - 1 do
        local angle = math.rad((phase or 0) + (360 / count) * index)
        local dx, dy = math.cos(angle), math.sin(angle)
        out[#out + 1] = L(cx + dx * inner, cy + dy * inner, cx + dx * outer, cy + dy * outer, thickness)
    end
    return out
end

local function merge(...)
    local out = {}
    for index = 1, select("#", ...) do
        local part = select(index, ...)
        if part then
            for i = 1, #part do out[#out + 1] = part[i] end
        end
    end
    return out
end

local ICON_DATA = {
    settings   = merge({ C(12, 12, 6.8, false, 2.1), C(12, 12, 2.6, false, 2.1) }, teeth(12, 12, 8.4, 10.6, 8, 2.1, 22.5)),
    sliders    = { L(4, 7, 20, 7, 2), L(4, 12, 20, 12, 2), L(4, 17, 20, 17, 2), C(15, 7, 2.3, true), C(9, 12, 2.3, true), C(16, 17, 2.3, true) },
    eye        = { L(2.5, 12, 7, 7.5, 2), L(7, 7.5, 17, 7.5, 2), L(17, 7.5, 21.5, 12, 2), L(21.5, 12, 17, 16.5, 2), L(17, 16.5, 7, 16.5, 2), L(7, 16.5, 2.5, 12, 2), C(12, 12, 3.1, false, 2) },
    eyeoff     = { L(2.5, 12, 7, 7.5, 2), L(7, 7.5, 17, 7.5, 2), L(17, 7.5, 21.5, 12, 2), L(21.5, 12, 17, 16.5, 2), L(17, 16.5, 7, 16.5, 2), L(7, 16.5, 2.5, 12, 2), C(12, 12, 3.1, false, 2), L(4, 20, 20, 4, 2) },
    user       = { C(12, 8, 4, false, 2), L(4.5, 20.5, 5, 16.8, 2), L(5, 16.8, 9, 14.6, 2), L(9, 14.6, 15, 14.6, 2), L(15, 14.6, 19, 16.8, 2), L(19, 16.8, 19.5, 20.5, 2) },
    users      = { C(9.2, 8.2, 3.7, false, 2), C(17, 9.4, 2.8, false, 2), L(3, 20.4, 3.6, 17.4, 2), L(3.6, 17.4, 9.2, 15.2, 2), L(9.2, 15.2, 14.6, 15.2, 2), L(14.6, 15.2, 15.4, 17.6, 2), L(15.4, 17.6, 15, 20.4, 2), L(15.6, 12.6, 21, 12.6, 2) },
    shield     = { L(12, 3, 4.2, 6.6, 2), L(4.2, 6.6, 4.2, 12.4, 2), L(4.2, 12.4, 12, 21, 2), L(12, 21, 19.8, 12.4, 2), L(19.8, 12.4, 19.8, 6.6, 2), L(19.8, 6.6, 12, 3, 2) },
    zap        = { L(14, 2.5, 6, 13, 2), L(6, 13, 11, 13, 2), L(11, 13, 9.5, 21.5, 2), L(9.5, 21.5, 18, 10, 2), L(18, 10, 13, 10, 2), L(13, 10, 14, 2.5, 2) },
    target     = { C(12, 12, 8.6, false, 2), C(12, 12, 4.6, false, 2), C(12, 12, 1.4, true) },
    bell       = { R(6, 9.4, 12, 9.6, 4.4, false, 2), C(12, 20, 1.5, true), C(12, 6.4, 1.7, false, 2) },
    bellOff    = { R(6, 9.4, 12, 9.6, 4.4, false, 2), C(12, 20, 1.5, true), C(12, 6.4, 1.7, false, 2), L(3, 21, 21, 3, 2) },
    search     = { C(10.6, 10.6, 6.4, false, 2), L(15.4, 15.4, 20, 20, 2.2) },
    chevronDown= { L(6, 9.6, 12, 15.6, 2.2), L(12, 15.6, 18, 9.6, 2.2) },
    chevronUp  = { L(6, 14.4, 12, 8.4, 2.2), L(12, 8.4, 18, 14.4, 2.2) },
    chevronRight = { L(9.6, 6, 15.6, 12, 2.2), L(15.6, 12, 9.6, 18, 2.2) },
    chevronLeft= { L(14.4, 6, 8.4, 12, 2.2), L(8.4, 12, 14.4, 18, 2.2) },
    check      = { L(4.6, 12.6, 9.6, 17.6, 2.3), L(9.6, 17.6, 19.4, 6.6, 2.3) },
    close      = { L(6, 6, 18, 18, 2.2), L(18, 6, 6, 18, 2.2) },
    plus       = { L(12, 5, 12, 19, 2.2), L(5, 12, 19, 12, 2.2) },
    minus      = { L(5, 12, 19, 12, 2.2) },
    info       = { C(12, 12, 9, false, 2), L(12, 11, 12, 16.6, 2.2), C(12, 7.6, 1.2, true) },
    alert      = { L(12, 3.4, 21, 19.4, 2), L(21, 19.4, 3, 19.4, 2), L(3, 19.4, 12, 3.4, 2), L(12, 9.4, 12, 14.4, 2.2), C(12, 17, 1.1, true) },
    alertCircle= { C(12, 12, 9, false, 2), L(12, 7.2, 12, 13.4, 2.2), C(12, 16.6, 1.1, true) },
    checkCircle= { C(12, 12, 9, false, 2), L(8, 12.4, 11, 15.4, 2.2), L(11, 15.4, 16, 9.4, 2.2) },
    palette    = { C(12, 12, 9, false, 2), C(8.6, 9.4, 1.5, true), C(12, 8, 1.5, true), C(15.4, 9.4, 1.5, true), C(8, 14.4, 1.5, true), C(12, 15.6, 1.5, true), C(16, 14.4, 1.5, true) },
    layers     = { L(12, 3, 3, 7.4, 2), L(12, 3, 21, 7.4, 2), L(3, 7.4, 12, 12, 2), L(21, 7.4, 12, 12, 2), L(3, 12.6, 12, 17.2, 2), L(21, 12.6, 12, 17.2, 2), L(3, 17.6, 12, 22, 2), L(21, 17.6, 12, 22, 2) },
    droplet    = { L(12, 3, 5.4, 12.6, 2), L(12, 3, 18.6, 12.6, 2), C(12, 15, 5.2, false, 2) },
    sun        = { C(12, 12, 4.2, false, 2), L(12, 1.8, 12, 4.4, 2), L(12, 19.6, 12, 22.2, 2), L(1.8, 12, 4.4, 12, 2), L(19.6, 12, 22.2, 12, 2), L(4.8, 4.8, 6.7, 6.7, 2), L(17.3, 17.3, 19.2, 19.2, 2), L(4.8, 19.2, 6.7, 17.3, 2), L(17.3, 6.7, 19.2, 4.8, 2) },
    moon       = { L(15.6, 3, 9.6, 15.4, 2), L(9.6, 15.4, 13.4, 19, 2), L(13.4, 19, 19.6, 13, 2), L(19.6, 13, 21, 8, 2), C(13.4, 9.6, 6.2, false, 2) },
    monitor    = { R(2.6, 4, 18.8, 12.6, 2.4, false, 2), L(9, 20.4, 15, 20.4, 2), L(12, 16.6, 12, 20.4, 2) },
    keyboard   = { R(2.4, 6.6, 19.2, 11, 2.4, false, 2), L(6, 10, 6, 10.01, 2), L(9.4, 10, 9.4, 10.01, 2), L(12.8, 10, 12.8, 10.01, 2), L(16.2, 10, 16.2, 10.01, 2), L(8, 14, 16, 14, 2.2) },
    mouse      = { R(7, 4, 10, 16, 5, false, 2), L(12, 7, 12, 10.4, 2) },
    camera     = { R(2.6, 7, 13.4, 10.4, 2.4, false, 2), L(16, 10.6, 21.4, 7.6, 2), L(21.4, 7.6, 21.4, 16.8, 2), L(21.4, 16.8, 16, 13.8, 2), L(16, 13.8, 16, 10.6, 2) },
    image      = { R(3, 4.6, 18, 14.8, 2.6, false, 2), C(8.4, 9.6, 1.6, false, 2), L(4, 17, 9.6, 11.4, 2), L(9.6, 17, 14, 13, 2), L(14, 17, 20, 9.6, 2) },
    text       = { L(5, 6, 19, 6, 2), L(12, 6, 12, 18, 2), L(9, 18, 15, 18, 2) },
    list       = { L(9, 6, 20, 6, 2), L(9, 12, 20, 12, 2), L(9, 18, 20, 18, 2), C(4.6, 6, 1.1, true), C(4.6, 12, 1.1, true), C(4.6, 18, 1.1, true) },
    grid       = { R(3.4, 3.4, 7, 7, 1.8, false, 2), R(13.6, 3.4, 7, 7, 1.8, false, 2), R(3.4, 13.6, 7, 7, 1.8, false, 2), R(13.6, 13.6, 7, 7, 1.8, false, 2) },
    columns    = { R(3, 4, 5.6, 16, 1.8, false, 2), R(9.8, 4, 5.6, 16, 1.8, false, 2), R(16.6, 4, 5.6, 16, 1.8, false, 2) },
    maximize   = { L(3.4, 9, 9, 3.4, 2), L(9, 3.4, 20.6, 3.4, 2), L(20.6, 3.4, 20.6, 15, 2), L(20.6, 15, 15, 15, 2), L(15, 20.6, 3.4, 20.6, 2), L(3.4, 20.6, 3.4, 9, 2) },
    minimize   = { L(20.6, 15, 15, 15, 2), L(15, 20.6, 3.4, 20.6, 2), L(3.4, 20.6, 3.4, 9, 2), L(3.4, 9, 9, 9, 2), L(9, 3.4, 20.6, 3.4, 2), L(20.6, 3.4, 20.6, 15, 2) },
    refresh    = { C(12, 12, 8.4, false, 2), L(12, 3.6, 17.4, 6.6, 2), L(17.4, 6.6, 20.4, 6.6, 2), L(20.4, 6.6, 20.4, 3.6, 2), L(12, 20.4, 6.6, 17.4, 2), L(6.6, 17.4, 3.6, 17.4, 2), L(3.6, 17.4, 3.6, 20.4, 2) },
    lock       = { R(5, 10.6, 14, 10, 2.4, false, 2), L(8.2, 10.6, 8.2, 7.4, 2), L(8.2, 7.4, 15.8, 7.4, 2), L(15.8, 7.4, 15.8, 10.6, 2), C(12, 15.4, 1.3, true) },
    unlock     = { R(5, 10.6, 14, 10, 2.4, false, 2), L(8.2, 10.6, 8.2, 7.4, 2), L(8.2, 7.4, 15.8, 7.4, 2), L(15.8, 7.4, 15.8, 9, 2), C(12, 15.4, 1.3, true) },
    trash      = { L(4, 6.6, 20, 6.6, 2), L(9.4, 6.6, 9.4, 3.4, 2), L(14.6, 6.6, 14.6, 3.4, 2), L(9.4, 3.4, 14.6, 3.4, 2), L(6, 6.6, 7, 20.6, 2), L(18, 6.6, 17, 20.6, 2), L(6, 20.6, 18, 20.6, 2) },
    copy       = { R(8, 8, 12, 12, 2.4, false, 2), L(16, 16, 19.4, 19.4, 2), L(19.4, 19.4, 19.4, 6, 2), L(19.4, 6, 6, 6, 2), L(6, 6, 6, 16, 2), L(6, 16, 8, 16, 2) },
    save       = { L(4, 4, 16, 4, 2), L(16, 4, 20, 8, 2), L(20, 8, 20, 20, 2), L(20, 20, 4, 20, 2), L(4, 20, 4, 4, 2), R(8, 4, 8, 7, 1.4, false, 2), R(8, 13, 8, 7, 1.4, false, 2) },
    clock      = { C(12, 12, 9, false, 2), L(12, 6.6, 12, 12.4, 2), L(12, 12.4, 16, 14, 2) },
    sparkles   = { L(12, 2.6, 12, 8, 2), L(12, 16, 12, 21.4, 2), L(2.6, 12, 8, 12, 2), L(16, 12, 21.4, 12, 2), L(6.4, 6.4, 9, 9, 1.8), L(15, 15, 17.6, 17.6, 1.8), L(17.6, 6.4, 15, 9, 1.8), L(9, 15, 6.4, 17.6, 1.8) },
    flame      = { L(12, 2.4, 6.6, 10, 2), L(12, 2.4, 17.4, 10, 2), L(6.6, 10, 7.6, 15, 2), L(7.6, 15, 12, 21.6, 2), L(12, 21.6, 16.4, 15, 2), L(16.4, 15, 17.4, 10, 2), L(9.4, 15, 12, 18, 1.8), L(12, 18, 14.6, 15, 1.8) },
    snowflake  = { L(12, 2.4, 12, 21.6, 2), L(3.6, 7, 20.4, 17, 2), L(3.6, 17, 20.4, 7, 2), L(9, 4.8, 7.4, 3.2, 1.8), L(15, 19.2, 16.6, 20.8, 1.8), L(15, 4.8, 16.6, 3.2, 1.8), L(9, 19.2, 7.4, 20.8, 1.8) },
    leaf       = { L(4, 20, 18, 5, 2), C(18, 5, 5, false, 2), L(8, 16, 8, 16.01, 2), L(11, 13, 11, 13.01, 2) },
    star       = { L(12, 2.6, 14.6, 9.4, 2), L(14.6, 9.4, 21.8, 10.4, 2), L(14.6, 10.4, 16.6, 17.4, 2), L(16.6, 17.4, 9.6, 13.4, 2), L(9.6, 13.4, 3.4, 17.4, 2), L(3.4, 17.4, 9.4, 10.4, 2), L(9.4, 10.4, 2.2, 10.4, 2), L(2.2, 10.4, 9.4, 9.4, 2), L(9.4, 9.4, 12, 2.6, 2) },
    globe      = { C(12, 12, 9, false, 2), L(3, 12, 21, 12, 2), L(12, 3, 12, 21, 2), L(4.6, 7, 19.4, 17, 2), L(19.4, 7, 4.6, 17, 2) },
    server     = { R(3, 4, 18, 6.4, 1.8, false, 2), R(3, 13.6, 18, 6.4, 1.8, false, 2), C(6.4, 7.2, 1, true), C(6.4, 16.8, 1, true) },
    cloud      = { C(8, 15, 4.4, false, 2), C(13.4, 16, 3.2, false, 2), L(4.6, 18.6, 4.6, 13, 2), L(4.6, 13, 9, 9.6, 2), L(9, 9.6, 14, 10, 2), L(14, 10, 17.6, 13.4, 2), L(17.6, 13.4, 17.6, 18.6, 2), L(17.6, 18.6, 4.6, 18.6, 2) },
    wind       = { L(3, 8.4, 14, 8.4, 2), C(16.6, 8.4, 2.6, false, 2), L(3, 15.6, 11, 15.6, 2), C(13.6, 15.6, 2.6, false, 2), L(17, 12, 21, 12, 2) },
    wand       = { L(4, 20, 13, 11, 2), L(13, 11, 16, 8, 2), L(11, 13, 8, 10, 2), L(18.4, 5.6, 18.4, 5.61, 2), L(20.6, 3.4, 20.6, 3.41, 2), L(16.4, 3.4, 16.4, 3.41, 2), L(14.4, 6.4, 14.4, 6.41, 2) },
    brush      = { L(4, 20, 11, 13, 2), L(11, 13, 15, 9, 2), L(8, 16, 12, 12, 2), L(13, 11, 19, 5, 2), L(19, 5, 21, 7, 2), L(21, 7, 15, 13, 2) },
    arrowRight = { L(4, 12, 19, 12, 2), L(14, 7, 19, 12, 2), L(19, 12, 14, 17, 2) },
    arrowDown  = { L(12, 4, 12, 19, 2), L(7, 14, 12, 19, 2), L(17, 14, 12, 19, 2) },
    arrowUp    = { L(12, 19, 12, 4, 2), L(7, 9, 12, 4, 2), L(17, 9, 12, 4, 2) },
    move       = { L(12, 3, 12, 21, 2), L(3, 12, 21, 12, 2), L(12, 3, 9.4, 6, 2), L(12, 3, 14.6, 6, 2), L(12, 21, 9.4, 18, 2), L(12, 21, 14.6, 18, 2), L(3, 12, 6, 9.4, 2), L(3, 12, 6, 14.6, 2), L(21, 12, 18, 9.4, 2), L(21, 12, 18, 14.6, 2) },
    crosshair  = { C(12, 12, 8.4, false, 2), L(12, 1.6, 12, 7, 2), L(12, 17, 12, 22.4, 2), L(1.6, 12, 7, 12, 2), L(17, 12, 22.4, 12, 2) },
    gamepad    = { R(3, 8, 18, 9.4, 4.4, false, 2), C(8, 12.6, 1.4, true), C(16, 12.6, 1.4, true), L(8, 12.6, 8, 12.61, 2) },
    wifi       = { L(3.4, 9, 8, 13.4, 2), L(8, 13.4, 12, 17.4, 2), L(12, 17.4, 16, 13.4, 2), L(16, 13.4, 20.6, 9, 2), L(7.4, 13.4, 12, 17.8, 2), L(12, 17.8, 16.6, 13.4, 2), C(12, 19.4, 1.2, true) },
    power      = { L(12, 3, 12, 11, 2), L(6.6, 6, 12, 21, 2), L(17.4, 6, 12, 21, 2) },
    block      = { C(12, 12, 9, false, 2), L(6, 6, 18, 18, 2) },
    dot        = { C(12, 12, 4, true) },
}

local function buildPrimitive(primitive, color, thicknessScale, parent)
    local thickness = math.max(0.6, (primitive.t or 2) * thicknessScale)

    if primitive.kind == "line" then
        local x1, y1, x2, y2 = primitive.x1, primitive.y1, primitive.x2, primitive.y2
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local rotation = math.deg(math.atan2(dy, dx))
        local line = Util.New("Frame", {
            Name = "l",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
            Size = UDim2.fromOffset(length + thickness, thickness),
            Rotation = rotation,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
        })
        local corner = Util.New("UICorner", { CornerRadius = UDim.new(0, math.ceil(thickness / 2)) })
        corner.Parent = line
        line.Parent = parent
        return
    end

    if primitive.kind == "circle" then
        local diameter = primitive.r * 2
        local circle = Util.New("Frame", {
            Name = "c",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(primitive.cx, primitive.cy),
            Size = UDim2.fromOffset(diameter, diameter),
            BackgroundColor3 = color,
            BackgroundTransparency = primitive.filled and 0 or 1,
            BorderSizePixel = 0,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }).Parent = circle
        if not primitive.filled then
            local stroke = Util.New("UIStroke", {
                Color = color,
                Thickness = thickness,
                Transparency = 0,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            })
            stroke.Parent = circle
        end
        circle.Parent = parent
        return
    end

    if primitive.kind == "rect" then
        local rect = Util.New("Frame", {
            Name = "r",
            Position = UDim2.fromOffset(primitive.x, primitive.y),
            Size = UDim2.fromOffset(primitive.w, primitive.h),
            BackgroundColor3 = color,
            BackgroundTransparency = primitive.filled and 0 or 1,
            BorderSizePixel = 0,
        })
        if primitive.r > 0 then
            Util.New("UICorner", { CornerRadius = UDim.new(0, primitive.r) }).Parent = rect
        end
        if not primitive.filled then
            local stroke = Util.New("UIStroke", {
                Color = color,
                Thickness = thickness,
                Transparency = 0,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            })
            stroke.Parent = rect
        end
        rect.Parent = parent
    end
end

--[[
    Icons.Build(name, size, colorToken) -> Frame
    Returns a square frame with the drawn glyph. Color token follows the theme.
]]
function Icons.Build(name, size, colorToken, thicknessScale)
    size = size or 18
    thicknessScale = thicknessScale or (size / 24)

    local override = Icons._overrides[name]
    if type(override) == "string" then
        local image = Util.New("ImageLabel", {
            Name = "Icon_" .. tostring(name),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(size, size),
            Image = override,
            ImageColor3 = Theme:Get(colorToken or "SubText"),
            ScaleType = Enum.ScaleType.Fit,
            BorderSizePixel = 0,
        })
        Theme:Register(image, "ImageColor3", colorToken or "SubText")
        return image
    end

    local glyph = override or ICON_DATA[name] or ICON_DATA.dot

    local host = Util.New("Frame", {
        Name = "Icon_" .. tostring(name),
        BackgroundTransparency = 1,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        BorderSizePixel = 0,
    })

    local canvas = Util.New("Frame", {
        Name = "canvas",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(24, 24),
        BorderSizePixel = 0,
    })
    canvas.Parent = host

    local token = colorToken or "SubText"
    host:SetAttribute("IconToken", token)
    local color = Theme:Get(token)
    for index = 1, #glyph do
        buildPrimitive(glyph[index], color, thicknessScale, canvas)
    end

    local scale = Util.New("UIScale", { Scale = size / 24 })
    scale.Parent = canvas

    Icons._live[host] = canvas
    return host
end

-- Override a glyph with an asset id string ("rbxassetid://123") or with a table
-- of primitives in the same format as ICON_DATA.
function Icons.Set(name, assetIdOrGlyph)
    Icons._overrides[name] = assetIdOrGlyph
end

-- Names available by default.
function Icons.List()
    local names = {}
    for key in pairs(ICON_DATA) do names[#names + 1] = key end
    table.sort(names)
    return names
end

-- Re-tint every live icon after a theme change.
Theme:OnChanged(function()
    for host, canvas in pairs(Icons._live) do
        local token = host:GetAttribute("IconToken") or "SubText"
        local color = Theme:Get(token)
        for _, child in ipairs(canvas:GetDescendants()) do
            if child:IsA("Frame") then
                child.BackgroundColor3 = color
            elseif child:IsA("UIStroke") then
                child.Color = color
            end
        end
    end
end)

XenonUI.Util      = Util
XenonUI.Theme     = Theme
XenonUI.Icons     = Icons
XenonUI.Scheduler = Scheduler
XenonUI.Maid      = Maid
XenonUI._Tween    = { Fast = T_FAST, Med = T_MED, Slow = T_SLOW, Spring = T_SPRING }
XenonUI._TweenService = TweenService
XenonUI._Services = {
    UserInputService = UserInputService,
    RunService = RunService,
    Lighting = Lighting,
    Players = Players,
    TextService = TextService,
}
--------------------------------------------------------------------------------
-- Liquid Glass
--------------------------------------------------------------------------------
local Glass = {}
Glass._fills  = setmetatable({}, { __mode = "k" })
Glass._sheens = setmetatable({}, { __mode = "k" })
Glass._borders= setmetatable({}, { __mode = "k" })

local function gradient(rotation, keypoints, transparency)
    local grad = Instance.new("UIGradient")
    grad.Rotation = rotation or 90
    grad.Color = ColorSequence.new(keypoints)
    if transparency then
        grad.Transparency = NumberSequence.new(transparency)
    end
    return grad
end

-- Fill transparency depends on the active palette so both themes stay readable
local function fillAlpha(token)
    local base = Theme.Glass and Theme.GlassTransparency or 0.08
    if token == "Card" or token == "Row" then
        base = base - 0.14
    elseif token == "SurfaceAlt" or token == "Track" then
        base = base - 0.05
    end
    if Theme._resolvedMode == "Light" then
        base = base * 0.55
    end
    return Util.Clamp(base, 0.02, 0.95)
end

--[[
    Glass.Apply(frame, options) -> content frame
    Options: Radius, Fill (token), Transparency, Inset, Sheen, Stroke, ZIndex
]]
function Glass.Apply(frame, options)
    options = options or {}
    local radius = options.Radius or 14
    local inset = options.Inset or 1
    local token = options.Fill or "Surface"
    local z = options.ZIndex or frame.ZIndex

    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = false

    if options.Shadow ~= false then
        Glass.Shadow(frame, radius)
    end

    local border = Util.New("Frame", {
        Name = "GlassBorder",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = z,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, radius) }).Parent = border
    local borderColor = Theme.Palette.Stroke or Color3.new(1, 1, 1)
    local borderGradient = gradient(135, {
        ColorSequenceKeypoint.new(0, borderColor),
        ColorSequenceKeypoint.new(0.45, Theme.Accent),
        ColorSequenceKeypoint.new(1, borderColor),
    }, {
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(0.5, 0.78),
        NumberSequenceKeypoint.new(1, 0.62),
    })
    borderGradient.Parent = border
    Glass._borders[borderGradient] = true
    border.Parent = frame

    local fill = Util.New("Frame", {
        Name = "GlassFill",
        Position = UDim2.fromOffset(inset, inset),
        Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
        BackgroundColor3 = Theme:Get(token),
        BackgroundTransparency = options.Transparency or fillAlpha(token),
        BorderSizePixel = 0,
        ZIndex = z + 1,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, math.max(0, radius - inset)) }).Parent = fill
    fill.Parent = frame

    Theme:Register(fill, "BackgroundColor3", token)
    Glass._fills[fill] = { token = token, custom = options.Transparency }

    if options.Sheen ~= false then
        local sheen = Util.New("Frame", {
            Name = "GlassSheen",
            Size = UDim2.new(1, 0, 0.6, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Visible = Theme.Glass,
            ZIndex = z + 2,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, math.max(0, radius - inset)) }).Parent = sheen
        gradient(90, {
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        }, {
            NumberSequenceKeypoint.new(0, 0.94),
            NumberSequenceKeypoint.new(1, 1),
        }).Parent = sheen
        sheen.Parent = fill

        local spec = Util.New("Frame", {
            Name = "GlassSpec",
            Position = UDim2.new(0.02, 0, 0.02, 0),
            Size = UDim2.new(0.5, 0, 0.42, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Visible = Theme.Glass,
            ZIndex = z + 2,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }).Parent = spec
        gradient(45, {
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        }, {
            NumberSequenceKeypoint.new(0, 0.95),
            NumberSequenceKeypoint.new(1, 1),
        }).Parent = spec
        spec.Parent = fill

        Glass._sheens[sheen] = true
        Glass._sheens[spec] = true
    end

    return fill
end

local function paintBorders()
    local edge = Theme.Palette.Stroke or Color3.new(1, 1, 1)
    for grad in pairs(Glass._borders) do
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, edge),
            ColorSequenceKeypoint.new(0.45, Theme.Accent),
            ColorSequenceKeypoint.new(1, edge),
        })
    end
end

Theme:OnChanged(paintBorders)
Glass.PaintBorders = paintBorders

Glass.FillAlpha = fillAlpha

-- Soft layered shadow, drawn behind the glass panel
function Glass.Shadow(frame, radius)
    local layers = {
        { expand = 2,  offset = 0, transparency = 0.86 },
        { expand = 6,  offset = 2, transparency = 0.92 },
        { expand = 12, offset = 4, transparency = 0.965 },
    }
    for index, layer in ipairs(layers) do
        local shadow = Util.New("Frame", {
            Name = "GlassShadow" .. index,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, layer.offset),
            Size = UDim2.new(1, layer.expand * 2, 1, layer.expand * 2),
            BackgroundColor3 = Theme:Get("Shadow"),
            BackgroundTransparency = layer.transparency,
            BorderSizePixel = 0,
            ZIndex = math.max(1, frame.ZIndex - 1),
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, (radius or 14) + layer.expand) }).Parent = shadow
        Theme:Register(shadow, "BackgroundColor3", "Shadow")
        shadow.Parent = frame
    end
end

-- Subtle 1px divider line
function Glass.Divider(parent, transparency)
    local line = Util.New("Frame", {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme:Get("Stroke"),
        BackgroundTransparency = transparency or 0.92,
        BorderSizePixel = 0,
    })
    Theme:Register(line, "BackgroundColor3", "Stroke")
    line.Parent = parent
    return line
end

function Glass.SetEnabled(enabled)
    Theme.Glass = enabled and true or false
    for object in pairs(Glass._sheens) do
        object.Visible = Theme.Glass
    end
    for fill, data in pairs(Glass._fills) do
        fill.BackgroundTransparency = data.custom or fillAlpha(data.token)
    end
end

-- Keeps the world sharp: blur is optional and off by default
function Glass.SetWorldBlur(size)
    Theme.WorldBlur = Util.Clamp(size or 0, 0, 24)
    local blur = Lighting:FindFirstChild("XenonUIGlassBlur")
    if not blur then
        blur = Instance.new("BlurEffect")
        blur.Name = "XenonUIGlassBlur"
        blur.Parent = Lighting
    end
    blur.Size = Theme.WorldBlur
    blur.Enabled = Theme.WorldBlur > 0
end

--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------
local Tooltip = {}
Tooltip._gui = nil
Tooltip._box = nil
Tooltip._text = nil
Tooltip._target = nil
Tooltip._delay = 0.4
Tooltip._timer = 0
Tooltip._task = nil

local function ensureTooltipGui()
    if Tooltip._gui then return end
    if not XenonUI._container then XenonUI:ResolveContainer() end
    local gui = Util.New("ScreenGui", {
        Name = "XenonUI_Tooltip",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 2147483000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    gui.Parent = XenonUI._container

    local box = Util.New("Frame", {
        Name = "TooltipBox",
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 10,
    })
    local content = Glass.Apply(box, { Radius = 10, Fill = "SurfaceAlt", ZIndex = 10, Shadow = false })
    content.Name = "Content"
    content.AutomaticSize = Enum.AutomaticSize.XY
    Util.New("UISizeConstraint", { MaxSize = Vector2.new(260, 100000) }).Parent = content
    local padding = Util.New("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 7),
        PaddingBottom = UDim.new(0, 7),
    })
    padding.Parent = content

    local label = Util.New("TextLabel", {
        Name = "Text",
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromOffset(0, 0),
        ZIndex = 12,
    })
    Theme:Register(label, "TextColor3", "Text")
    label.Parent = content

    box.Parent = gui
    Tooltip._gui = gui
    Tooltip._box = box
    Tooltip._text = label
    Tooltip._content = content
end

local function tooltipFollow()
    local box = Tooltip._box
    if not box or not box.Visible then return end
    local mouse = UserInputService:GetMouseLocation()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local width = box.AbsoluteSize.X
    local height = box.AbsoluteSize.Y
    local x = Util.Clamp(mouse.X + 16, 8, viewport.X - width - 8)
    local y = Util.Clamp(mouse.Y + 18, 8, viewport.Y - height - 8)
    box.Position = UDim2.fromOffset(x, y)
end

function Tooltip:Attach(object, text)
    ensureTooltipGui()
    local hovering = false

    object.MouseEnter:Connect(function()
        hovering = true
        Tooltip._target = object
        Tooltip._label = text
        Tooltip._timer = 0
        if not Tooltip._remove then
            Tooltip._task = true
            Tooltip._remove = Scheduler:Add("XenonUI_Tooltip", function(delta)
                if not hovering or not Tooltip._target then
                    Tooltip:Hide()
                    return
                end
                Tooltip._timer = Tooltip._timer + delta
                if Tooltip._timer >= Tooltip._delay then
                    Tooltip:Show(Tooltip._label)
                end
                tooltipFollow()
            end)
        end
    end)

    object.MouseLeave:Connect(function()
        hovering = false
        Tooltip._target = nil
        Tooltip:Hide()
    end)
end

function Tooltip:Show(text)
    ensureTooltipGui()
    if not text or text == "" then
        Tooltip:Hide()
        return
    end
    if Tooltip._text.Text ~= text then
        Tooltip._text.Text = text
    end
    Tooltip._box.Visible = true
    Util.Tween(Tooltip._content, T_FAST, { BackgroundTransparency = fillAlpha("SurfaceAlt") })
end

function Tooltip:Hide()
    if Tooltip._box then
        Tooltip._box.Visible = false
    end
    if Tooltip._remove then
        Tooltip._remove()
        Tooltip._remove = nil
        Tooltip._task = nil
    end
end

--------------------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------------------
local Notify = {}
Notify.MaxVisible = 4
Notify.Corner = "BottomRight"
Notify.Width = 330
Notify._active = {}
Notify._queue = {}
Notify._holder = nil
Notify._gui = nil
Notify._offset = 0

local NOTIFY_TYPES = {
    Info    = { token = "Info",    icon = "info" },
    Success = { token = "Success", icon = "checkCircle" },
    Warning = { token = "Warning", icon = "alert" },
    Error   = { token = "Danger",  icon = "alertCircle" },
}

local function ensureNotifyGui()
    if Notify._gui then return end
    if not XenonUI._container then XenonUI:ResolveContainer() end
    local gui = Util.New("ScreenGui", {
        Name = "XenonUI_Notifications",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 2147482000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    gui.Parent = XenonUI._container

    local holder = Util.New("Frame", {
        Name = "Holder",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.new(0, Notify.Width, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    local layout = Util.New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
    })
    layout.Parent = holder
    holder.Parent = gui

    Notify._gui = gui
    Notify._holder = holder
end

local CORNERS = {
    BottomRight = { Vector2.new(1, 1), UDim2.new(1, -20, 1, -20), Enum.VerticalAlignment.Bottom, 1 },
    BottomLeft  = { Vector2.new(0, 1), UDim2.new(0, 20, 1, -20), Enum.VerticalAlignment.Bottom, 1 },
    TopRight    = { Vector2.new(1, 0), UDim2.new(1, -20, 0, 20), Enum.VerticalAlignment.Top, -1 },
    TopLeft     = { Vector2.new(0, 0), UDim2.new(0, 20, 0, 20), Enum.VerticalAlignment.Top, -1 },
    BottomCenter= { Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -20), Enum.VerticalAlignment.Bottom, 1 },
    TopCenter   = { Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 20), Enum.VerticalAlignment.Top, -1 },
}

function Notify:SetCorner(corner)
    ensureNotifyGui()
    local config = CORNERS[corner] or CORNERS.BottomRight
    Notify.Corner = corner
    Notify._holder.AnchorPoint = config[1]
    Notify._holder.Position = config[2]
    local layout = Notify._holder:FindFirstChildOfClass("UIListLayout")
    if layout then
        layout.VerticalAlignment = config[3]
    end
end

local function buildNotification(data)
    local accent = Theme:Get(data.Type.token)
    local wrapper = Util.New("Frame", {
        Name = "Slot",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = data.Order,
    })

    local card = Util.New("CanvasGroup", {
        Name = "Notification",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        GroupTransparency = 1,
    })
    card.Parent = wrapper

    local content = Glass.Apply(card, { Radius = 14, Fill = "Surface", ZIndex = 20 })
    content.AutomaticSize = Enum.AutomaticSize.Y

    local padding = Util.New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 11),
        PaddingBottom = UDim.new(0, 13),
    })
    padding.Parent = content

    local layout = Util.New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    })
    layout.Parent = content

    local header = Util.New("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        ZIndex = 22,
    })

    local iconBox = Util.New("Frame", {
        Name = "IconBox",
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = 23,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 6) }).Parent = iconBox
    local icon = Icons.Build(data.Icon or data.Type.icon, 13, data.Type.token, 0.62)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.ZIndex = 24
    icon.Parent = iconBox
    iconBox.Parent = header

    local title = Util.New("TextLabel", {
        Name = "Title",
        Position = UDim2.new(0, 28, 0, 0),
        Size = UDim2.new(1, -58, 1, 0),
        BackgroundTransparency = 1,
        Text = data.Title,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 23,
    })
    Theme:Register(title, "TextColor3", "Text")
    title.Parent = header

    local close = Util.New("TextButton", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 24,
    })
    local closeIcon = Icons.Build("close", 12, "Muted", 0.6)
    closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    closeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    closeIcon.ZIndex = 25
    closeIcon.Parent = close
    close.Parent = header
    header.Parent = content

    local body = Util.New("TextLabel", {
        Name = "Body",
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = data.Content or "",
        TextSize = 12.5,
        Font = Enum.Font.GothamMedium,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = (data.Content ~= nil and data.Content ~= ""),
        ZIndex = 22,
    })
    Theme:Register(body, "TextColor3", "SubText")
    body.Parent = content

    local action
    if data.Action then
        action = Util.New("TextButton", {
            Name = "Action",
            LayoutOrder = 3,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = accent,
            BackgroundTransparency = 0.85,
            Text = "  " .. tostring(data.Action.Text or "Action") .. "  ",
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false,
            ZIndex = 22,
        })
        Theme:Register(action, "BackgroundColor3", data.Type.token)
        Theme:Register(action, "TextColor3", data.Type.token)
        Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = action
        Util.New("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 5),
            PaddingBottom = UDim.new(0, 5),
        }).Parent = action
        action.Parent = content
    end

    local progressTrack = Util.New("Frame", {
        Name = "Progress",
        LayoutOrder = 4,
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Theme:Get("Track"),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Visible = data.Duration > 0,
        ZIndex = 22,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 2) }).Parent = progressTrack
    Theme:Register(progressTrack, "BackgroundColor3", "Track")

    local progressFill = Util.New("Frame", {
        Name = "Fill",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        ZIndex = 23,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 2) }).Parent = progressFill
    Theme:Register(progressFill, "BackgroundColor3", data.Type.token)
    progressFill.Parent = progressTrack
    progressTrack.Parent = content

    return wrapper, { card = card, content = content, progressFill = progressFill, close = close, action = action }
end

function Notify:Push(data)
    ensureNotifyGui()
    Notify._offset = Notify._offset + 1

    local entry = {
        Title = data.Title or "Notification",
        Content = data.Content or "",
        Type = NOTIFY_TYPES[data.Type] or NOTIFY_TYPES.Info,
        Duration = tonumber(data.Duration) or 4,
        Icon = data.Icon,
        Action = data.Action,
        Order = Notify._offset,
        Elapsed = 0,
        Hovering = false,
    }

    if #Notify._active >= Notify.MaxVisible then
        Notify._queue[#Notify._queue + 1] = entry
        return entry
    end

    local wrapper, parts = buildNotification(entry)
    wrapper.Parent = Notify._holder
    entry.Card = parts.card
    entry.Wrapper = wrapper
    entry.Parts = parts

    parts.close.MouseButton1Click:Connect(function()
        Notify:Dismiss(entry)
    end)
    if parts.action then
        parts.action.MouseButton1Click:Connect(function()
            if entry.Action and entry.Action.Callback then
                pcall(entry.Action.Callback)
            end
            Notify:Dismiss(entry)
        end)
    end

    parts.card.MouseEnter:Connect(function() entry.Hovering = true end)
    parts.card.MouseLeave:Connect(function() entry.Hovering = false end)
    parts.card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if entry.Action then return end
            Notify:Dismiss(entry)
        end
    end)

    local startX = (CORNERS[Notify.Corner] or CORNERS.BottomRight)[1].X > 0.5 and 28 or -28
    parts.card.Position = UDim2.fromOffset(startX, 0)
    Util.Tween(parts.card, T_SLOW, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })

    Notify._active[#Notify._active + 1] = entry
    return entry
end

function Notify:Dismiss(entry)
    if entry.Dismissed then return end
    entry.Dismissed = true

    for index, active in ipairs(Notify._active) do
        if active == entry then
            table.remove(Notify._active, index)
            break
        end
    end

    local exitX = (CORNERS[Notify.Corner] or CORNERS.BottomRight)[1].X > 0.5 and 40 or -40
    Util.Tween(entry.Card, T_MED, { GroupTransparency = 1, Position = UDim2.fromOffset(exitX, 0) })
    task.delay(0.32, function()
        if entry.Wrapper then
            entry.Wrapper:Destroy()
            entry.Wrapper = nil
            entry.Card = nil
        end
    end)

    local nextEntry = table.remove(Notify._queue, 1)
    if nextEntry then
        task.delay(0.12, function()
            Notify:Push(nextEntry)
        end)
    end
end

function Notify:Clear()
    for index = #Notify._active, 1, -1 do
        Notify:Dismiss(Notify._active[index])
    end
    Notify._queue = {}
end

Scheduler:Add("XenonUI_Notify", function(delta)
    if #Notify._active == 0 then return end
    for index = #Notify._active, 1, -1 do
        local entry = Notify._active[index]
        if entry.Duration > 0 and not entry.Hovering then
            entry.Elapsed = entry.Elapsed + delta
            local ratio = Util.Clamp(1 - entry.Elapsed / entry.Duration, 0, 1)
            entry.Parts.progressFill.Size = UDim2.new(ratio, 0, 1, 0)
            if entry.Elapsed >= entry.Duration then
                Notify:Dismiss(entry)
            end
        end
    end
end)

XenonUI.Glass = Glass
XenonUI.Tooltip = Tooltip
XenonUI.Notify = Notify

function XenonUI:Notify(options)
    return Notify:Push(options or {})
end

function XenonUI:Info(title, content, duration)
    return Notify:Push({ Title = title, Content = content, Type = "Info", Duration = duration })
end

function XenonUI:Success(title, content, duration)
    return Notify:Push({ Title = title, Content = content, Type = "Success", Duration = duration })
end

function XenonUI:Warn(title, content, duration)
    return Notify:Push({ Title = title, Content = content, Type = "Warning", Duration = duration })
end

function XenonUI:Error(title, content, duration)
    return Notify:Push({ Title = title, Content = content, Type = "Error", Duration = duration })
end

XenonUI.Notifications = Notify
--------------------------------------------------------------------------------
-- Collapsible container (used for inline settings and section bodies)
--------------------------------------------------------------------------------
local Collapse = {}
Collapse.__index = Collapse

function Collapse.new(parent, options)
    options = options or {}
    local self = setmetatable({}, Collapse)

    local wrapper = Util.New("Frame", {
        Name = options.Name or "Collapse",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ClipsDescendants = true,
        LayoutOrder = options.Order or 1,
        BorderSizePixel = 0,
    })
    wrapper.Parent = parent

    local panel
    if options.Plain then
        panel = Util.New("Frame", {
            Name = "Panel",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            ZIndex = options.ZIndex or 10,
        })
        panel.Parent = wrapper
    else
        panel = Glass.Apply(wrapper, {
            Radius = options.Radius or 12,
            Fill = options.Fill or "SurfaceAlt",
            ZIndex = options.ZIndex or 10,
            Shadow = false,
        })
        panel.Name = "Panel"
        panel.AutomaticSize = Enum.AutomaticSize.Y
        panel.Size = UDim2.new(1, 0, 0, 0)
    end

    Util.New("UIPadding", {
        PaddingLeft = UDim.new(0, options.PadX or 11),
        PaddingRight = UDim.new(0, options.PadX or 11),
        PaddingTop = UDim.new(0, options.PadY or 10),
        PaddingBottom = UDim.new(0, options.PadY or 10),
    }).Parent = panel

    local layout = Util.New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, options.Padding or 8),
    })
    layout.Parent = panel

    self.Wrapper = wrapper
    self.Panel = panel
    self.Layout = layout
    self.Open = false
    -- AbsoluteContentSize lives on the layout, not on the frame
    self._padding = (options.PadY or 10) * 2
    self._extra = options.Extra or 0

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if self.Open then
            wrapper.Size = UDim2.new(1, 0, 0, self:Measure())
        end
    end)

    function self:Measure()
        return layout.AbsoluteContentSize.Y + self._padding + self._extra
    end

    function self:SetOpen(state, instant)
        state = state and true or false
        self.Open = state
        local height = self:Measure()
        if state then
            wrapper.Visible = true
            if instant then
                wrapper.Size = UDim2.new(1, 0, 0, height)
            else
                Util.Tween(wrapper, T_MED, { Size = UDim2.new(1, 0, 0, height) })
            end
        else
            if instant then
                wrapper.Size = UDim2.new(1, 0, 0, 0)
                wrapper.Visible = false
            else
                Util.Tween(wrapper, T_MED, { Size = UDim2.new(1, 0, 0, 0) })
                task.delay(0.24, function()
                    if not self.Open then wrapper.Visible = false end
                end)
            end
        end
    end

    function self:Destroy()
        wrapper:Destroy()
    end

    return self
end

--------------------------------------------------------------------------------
-- Container mixin (sections and inline settings panels share these methods)
--------------------------------------------------------------------------------
local Container = {}
Container.__index = Container

function Container.new(frame, zIndex, window)
    local self = setmetatable({}, Container)
    self.Frame = frame
    self.ZIndex = zIndex or 10
    self.Window = window
    self._order = 0
    self._items = {}
    return self
end

function Container:NextOrder()
    self._order = self._order + 100
    return self._order
end

--------------------------------------------------------------------------------
-- Row scaffolding
--------------------------------------------------------------------------------
local function makeRow(container, options)
    options = options or {}
    local z = container.ZIndex
    local hasDesc = options.Desc ~= nil and options.Desc ~= ""
    local height = options.Height or (hasDesc and 56 or 44)

    local interactive = options.Interactive and true or false
    local row = Util.New(interactive and "TextButton" or "Frame", {
        Name = options.Name or "Row",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = container:NextOrder(),
        ClipsDescendants = false,
        ZIndex = z,
    })
    if interactive then
        row.AutoButtonColor = false
        row.Text = ""
    end
    row.Parent = container.Frame

    local card = Glass.Apply(row, { Radius = 12, Fill = "Row", ZIndex = z, Shadow = false })
    card.ClipsDescendants = true

    if interactive and options.Hover ~= false then
        row.MouseEnter:Connect(function()
            Util.Tween(card, T_FAST, { BackgroundColor3 = Theme:Get("RowHover") })
        end)
        row.MouseLeave:Connect(function()
            Util.Tween(card, T_FAST, { BackgroundColor3 = Theme:Get("Row") })
        end)
    end

    local leftPad = options.Icon and 46 or 14

    if options.Icon then
        local iconBox = Util.New("Frame", {
            Name = "IconBox",
            Position = UDim2.fromOffset(12, (height - 28) / 2),
            Size = UDim2.fromOffset(28, 28),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.84,
            BorderSizePixel = 0,
            ZIndex = z + 2,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = iconBox
        local glyph = Icons.Build(options.Icon, 16, options.IconToken or "Accent", 0.7)
        glyph.AnchorPoint = Vector2.new(0.5, 0.5)
        glyph.Position = UDim2.new(0.5, 0, 0.5, 0)
        glyph.ZIndex = z + 3
        glyph.Parent = iconBox
        iconBox.Parent = card
        Theme:Register(iconBox, "BackgroundColor3", "Accent")
    end

    local title = Util.New("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(leftPad, hasDesc and 9 or 0),
        Size = UDim2.new(1, -(leftPad + (options.RightWidth or 90) + 12), 0, hasDesc and 17 or height),
        BackgroundTransparency = 1,
        Text = options.Title or "",
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = z + 2,
    })
    Theme:Register(title, "TextColor3", "Text")
    title.Parent = card

    local desc
    if hasDesc then
        desc = Util.New("TextLabel", {
            Name = "Desc",
            Position = UDim2.fromOffset(leftPad, 27),
            Size = UDim2.new(1, -(leftPad + (options.RightWidth or 90) + 12), 0, 15),
            BackgroundTransparency = 1,
            Text = options.Desc,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = z + 2,
        })
        Theme:Register(desc, "TextColor3", "Muted")
        desc.Parent = card
    end

    local right = Util.New("Frame", {
        Name = "Right",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(options.RightInset or 12), 0.5, 0),
        Size = UDim2.new(0, options.RightWidth or 90, 0, height - 14),
        BackgroundTransparency = 1,
        ZIndex = z + 2,
    })
    right.Parent = card

    local layout = nil
    if options.RightLayout ~= false then
        layout = Util.New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        })
        layout.Parent = right
    end

    return {
        Row = row,
        Card = card,
        Title = title,
        Desc = desc,
        Right = right,
        RightLayout = layout,
        Height = height,
        ZIndex = z,
    }
end

--------------------------------------------------------------------------------
-- Component base
--------------------------------------------------------------------------------
local Component = {}
Component.__index = Component

function Component:RegisterFlag(flag)
    if not flag then return end
    self.Flag = flag
    local window = self.Container and self.Container.Window
    if window then
        window._flags[flag] = self
    end
    return self
end

function Component:SetTitle(text)
    self._title = text
    if self.Title then self.Title.Text = text end
    return self
end

function Component:SetDesc(text)
    self._desc = text
    if self.Desc then
        self.Desc.Text = text or ""
        self.Desc.Visible = text ~= nil and text ~= ""
    end
    return self
end

function Component:SetVisible(state)
    self.Row.Visible = state and true or false
    if self.Settings and not state then
        self.Settings.Wrapper.Visible = false
    end
    return self
end

function Component:SetDisabled(state)
    self._disabled = state and true or false
    local alpha = self._disabled and 0.55 or 0
    Util.Tween(self.Card, T_FAST, { BackgroundTransparency = self._disabled and 0.6 or Glass.FillAlpha("Row") })
    if self.Title then Util.Tween(self.Title, T_FAST, { TextTransparency = alpha }) end
    if self.Desc then Util.Tween(self.Desc, T_FAST, { TextTransparency = alpha }) end
    if self.Right then Util.Tween(self.Right, T_FAST, { BackgroundTransparency = 1 }) end
    return self
end

function Component:Tooltip(text)
    Tooltip:Attach(self.Row, text)
    return self
end

-- Settings expand directly under the row, never in a separate window
function Component:AddSettings(builder)
    if self.Settings then
        builder(self.Settings.Sub)
        return self.Settings.Sub
    end

    local collapse = Collapse.new(self.Container.Frame, {
        Name = "InlineSettings",
        Order = self.Order + 1,
        Fill = "SurfaceAlt",
        Radius = 12,
        ZIndex = self.ZIndex,
        Padding = 8,
        PadX = 12,
        PadY = 12,
    })

    local sub = Container.new(collapse.Panel, self.ZIndex + 1, self.Container.Window)
    sub._order = 0
    collapse.Sub = sub
    collapse.Builder = builder

    local gear = Util.New("TextButton", {
        Name = "SettingsButton",
        Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = Theme:Get("SurfaceAlt"),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 99,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = gear
    Theme:Register(gear, "BackgroundColor3", "SurfaceAlt")

    local gearIcon = Icons.Build("settings", 14, "SubText", 0.72)
    gearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    gearIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    gearIcon.ZIndex = self.ZIndex + 4
    gearIcon.Parent = gear
    local reserve = self.Right and self.Right.Size.X.Offset or 0
    if reserve > 0 then
        gear.Parent = self.Right
    else
        gear.AnchorPoint = Vector2.new(1, 0.5)
        gear.Position = UDim2.new(1, -12, 0.5, 0)
        gear.Parent = self.Card
        if self._onGear then self._onGear(true) end
    end

    local open = false
    local function apply()
        open = not open
        collapse:SetOpen(open)
        Util.Tween(gearIcon, T_MED, { Rotation = open and 90 or 0 })
        Util.Tween(gear, T_FAST, { BackgroundTransparency = open and 0.1 or 0.5 })
        if open then
            Theme:Register(gear, "BackgroundColor3", "Accent")
        else
            Theme:Register(gear, "BackgroundColor3", "SurfaceAlt")
        end
        gear.BackgroundColor3 = Theme:Get(open and "Accent" or "SurfaceAlt")
    end

    gear.MouseButton1Click:Connect(apply)
    gear.MouseEnter:Connect(function()
        Util.Tween(gearIcon, T_FAST, { Rotation = open and 90 or 45 })
    end)
    gear.MouseLeave:Connect(function()
        Util.Tween(gearIcon, T_FAST, { Rotation = open and 90 or 0 })
    end)

    self.Gear = gear
    self.Settings = collapse
    collapse.Toggle = apply

    if builder then
        builder(sub)
    end
    return sub
end

function Component:OpenSettings(state)
    if self.Settings then
        if self.Settings.Open ~= state then
            self.Settings.Toggle()
        end
    end
    return self
end

function Component:Destroy()
    if self.Settings then self.Settings:Destroy() end
    self.Row:Destroy()
end

local function bindComponent(container, options, row)
    local self = setmetatable({}, Component)
    self.Container = container
    self.Row = row.Row
    self.Card = row.Card
    self.Title = row.Title
    self.Desc = row.Desc
    self.Right = row.Right
    self.RightLayout = row.RightLayout
    self.ZIndex = row.ZIndex
    self.Window = container.Window
    self.Order = self.Row.LayoutOrder
    self._title = options.Title or ""
    self._desc = options.Desc
    self._searchText = string.lower((options.Title or "") .. " " .. (options.Desc or ""))
    return self
end

--------------------------------------------------------------------------------
-- Toggle
--------------------------------------------------------------------------------
function Container:AddToggle(options)
    options = options or {}
    local row = makeRow(self, {
        Icon = options.Icon,
        IconToken = options.IconToken,
        Title = options.Title,
        Desc = options.Desc,
        RightWidth = options.SettingsOnly and 34 or 78,
        Interactive = true,
    })

    local self = bindComponent(self, options, row)
    self.Kind = "Toggle"
    local value = options.Default and true or false
    local callback = options.Callback

    local switch = Util.New("TextButton", {
        Name = "Switch",
        Size = UDim2.fromOffset(44, 24),
        BackgroundColor3 = Theme:Get("Track"),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 1,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 12) }).Parent = switch
    switch.Parent = row.Right

    local knob = Util.New("Frame", {
        Name = "Knob",
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Theme:Get("SubText"),
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 4,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 9) }).Parent = knob
    knob.Parent = switch

    local function paint(instant)
        local duration = instant and 0 or 0.18
        local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if value then
            Util.Tween(switch, info, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.12 })
            Util.Tween(knob, info, { Position = UDim2.fromOffset(23, 3), BackgroundColor3 = Color3.new(1, 1, 1) })
        else
            Util.Tween(switch, info, { BackgroundColor3 = Theme:Get("Track"), BackgroundTransparency = 0.25 })
            Util.Tween(knob, info, { Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Theme:Get("SubText") })
        end
    end
    paint(true)

    function self:Set(state, silent)
        value = state and true or false
        paint(false)
        if not silent and callback then
            pcall(callback, value)
        end
        if self.Flag then
            self.Window:SetFlagValue(self.Flag, value)
        end
        return self
    end

    function self:Get()
        return value
    end

    local function toggle()
        if self._disabled then return end
        self:Set(not value)
    end

    switch.MouseButton1Click:Connect(toggle)
    row.Row.MouseButton1Click:Connect(toggle)
    self._switch = switch

    Theme:OnChanged(function() paint(true) end)

    if options.Settings then
        self:AddSettings(options.Settings)
    end
    self:RegisterFlag(options.Flag)
    table.insert(self.Container._items, self)
    return self
end

--------------------------------------------------------------------------------
-- Button
--------------------------------------------------------------------------------
function Container:AddButton(options)
    options = options or {}
    local row = makeRow(self, {
        Icon = options.Icon,
        IconToken = options.IconToken,
        Title = options.Title,
        Desc = options.Desc,
        RightWidth = (options.SettingsOnly and 34) or (options.RightText and 90 or 34),
        Interactive = true,
    })

    local self = bindComponent(self, options, row)
    self.Kind = "Button"

    if options.RightText then
        local label = Util.New("TextLabel", {
            Name = "Value",
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = options.RightText,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            LayoutOrder = 1,
            ZIndex = self.ZIndex + 3,
        })
        Theme:Register(label, "TextColor3", "SubText")
        label.Parent = row.Right
        self.ValueLabel = label
    end

    local chevron = Icons.Build("chevronRight", 14, "Muted", 0.7)
    chevron.AnchorPoint = Vector2.new(0, 0.5)
    chevron.Position = UDim2.new(1, -18, 0.5, 0)
    chevron.ZIndex = self.ZIndex + 3
    chevron.Parent = row.Card
    self.Chevron = chevron

    local function ripple(x, y)
        local circle = Util.New("Frame", {
            Name = "Ripple",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(x - row.Card.AbsolutePosition.X, y - row.Card.AbsolutePosition.Y),
            Size = UDim2.fromOffset(0, 0),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.7,
            BorderSizePixel = 0,
            ZIndex = self.ZIndex + 1,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }).Parent = circle
        circle.Parent = row.Card
        local size = math.max(row.Card.AbsoluteSize.X, row.Card.AbsoluteSize.Y) * 2.2
        Util.Tween(circle, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(size, size),
            BackgroundTransparency = 1,
        })
        task.delay(0.5, function() circle:Destroy() end)
    end

    row.Row.MouseButton1Down:Connect(function(x, y)
        if self._disabled then return end
        ripple(x, y)
        Util.Tween(row.Row, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, row.Height - 2),
        })
    end)

    row.Row.MouseButton1Up:Connect(function()
        Util.Tween(row.Row, T_FAST, { Size = UDim2.new(1, 0, 0, row.Height) })
    end)

    row.Row.MouseButton1Click:Connect(function()
        if self._disabled then return end
        if options.Callback then
            pcall(options.Callback, self)
        end
    end)

    row.Row.MouseEnter:Connect(function()
        Util.Tween(row.Card, T_FAST, { BackgroundColor3 = Theme:Get("RowHover") })
        Util.Tween(chevron, T_FAST, { Position = UDim2.new(1, -14, 0.5, 0) })
    end)
    row.Row.MouseLeave:Connect(function()
        Util.Tween(row.Card, T_FAST, { BackgroundColor3 = Theme:Get("Row") })
        Util.Tween(chevron, T_FAST, { Position = UDim2.new(1, -18, 0.5, 0) })
    end)

    function self:SetRightText(text)
        if self.ValueLabel then self.ValueLabel.Text = text end
        return self
    end

    if options.Settings then
        self:AddSettings(options.Settings)
    end
    self:RegisterFlag(options.Flag)
    table.insert(self.Container._items, self)
    return self
end

--------------------------------------------------------------------------------
-- Slider
--------------------------------------------------------------------------------
function Container:AddSlider(options)
    options = options or {}
    local min = tonumber(options.Min) or 0
    local max = tonumber(options.Max) or 100
    local step = tonumber(options.Step) or 1
    local decimals = options.Decimals or (step < 1 and 2 or 0)

    local row = makeRow(self, {
        Icon = options.Icon,
        IconToken = options.IconToken,
        Title = options.Title,
        Desc = options.Desc,
        Height = (options.Desc and 70 or 58),
        RightWidth = 0,
        RightLayout = false,
        Interactive = true,
    })

    local self = bindComponent(self, options, row)
    self.Kind = "Slider"
    local value = Util.Clamp(tonumber(options.Default) or min, min, max)
    local callback = options.Callback
    local suffix = options.Suffix or ""

    local track = Util.New("Frame", {
        Name = "Track",
        Position = UDim2.new(0, 14, 1, -22),
        Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = Theme:Get("Track"),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 3) }).Parent = track
    Theme:Register(track, "BackgroundColor3", "Track")
    track.Parent = row.Card

    local fill = Util.New("Frame", {
        Name = "Fill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 4,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 3) }).Parent = fill
    Theme:Register(fill, "BackgroundColor3", "Accent")
    fill.Parent = track

    local knob = Util.New("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 5,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 7) }).Parent = knob
    local knobStroke = Util.New("UIStroke", { Color = Theme.Accent, Thickness = 2, Transparency = 0.25 })
    Theme:Register(knobStroke, "Color", "Accent")
    knobStroke.Parent = knob
    knob.Parent = track

    local valueBox = Util.New("TextBox", {
        Name = "Value",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, options.Desc and 24 or 12),
        Size = UDim2.fromOffset(64, 18),
        BackgroundColor3 = Theme:Get("SurfaceAlt"),
        BackgroundTransparency = 0.45,
        Text = "",
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 6) }).Parent = valueBox
    Theme:Register(valueBox, "BackgroundColor3", "SurfaceAlt")
    Theme:Register(valueBox, "TextColor3", "Text")
    valueBox.Parent = row.Card

    local hit = Util.New("TextButton", {
        Name = "Hit",
        Position = UDim2.new(0, 0, 0, -12),
        Size = UDim2.new(1, 0, 1, 24),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = self.ZIndex + 6,
    })
    hit.Parent = track

    local function layout(gearShift)
        local shift = gearShift or 0
        valueBox.Position = UDim2.new(1, -(14 + shift), 0, options.Desc and 24 or 12)
        local width = UDim2.new(1, -(28 + 78 + shift), 0, 17)
        row.Title.Size = width
        if row.Desc then row.Desc.Size = width end
    end
    layout(0)
    self._onGear = function() layout(30) end

    local function format(v)
        local text = string.format("%." .. decimals .. "f", v)
        return text .. suffix
    end

    local function paint()
        local ratio = (value - min) / math.max(0.0001, max - min)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0.5, 0)
        valueBox.Text = format(value)
    end

    function self:Set(v, silent)
        v = tonumber(v) or min
        v = Util.Clamp(Util.Round(v, step), min, max)
        if v == value and silent then return self end
        value = v
        paint()
        if not silent and callback then
            pcall(callback, value)
        end
        if self.Flag then
            self.Window:SetFlagValue(self.Flag, value)
        end
        return self
    end

    function self:Get()
        return value
    end

    local function fromX(x)
        local ratio = Util.Clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        self:Set(min + (max - min) * ratio)
    end

    local dragConn, releaseConn
    hit.MouseButton1Down:Connect(function(x)
        if self._disabled then return end
        fromX(x)
        Util.Tween(knob, T_FAST, { Size = UDim2.fromOffset(17, 17) })
        dragConn = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                fromX(input.Position.X)
            end
        end)
        releaseConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragConn then dragConn:Disconnect() dragConn = nil end
                if releaseConn then releaseConn:Disconnect() releaseConn = nil end
                Util.Tween(knob, T_FAST, { Size = UDim2.fromOffset(14, 14) })
            end
        end)
    end)

    hit.MouseEnter:Connect(function()
        Util.Tween(knob, T_FAST, { Size = UDim2.fromOffset(16, 16) })
    end)
    hit.MouseLeave:Connect(function()
        if not dragConn then
            Util.Tween(knob, T_FAST, { Size = UDim2.fromOffset(14, 14) })
        end
    end)

    valueBox.FocusLost:Connect(function(enterPressed)
        local number = tonumber(string.gsub(valueBox.Text, "[^%d%.%-]", ""))
        if number then
            self:Set(number)
        else
            valueBox.Text = format(value)
        end
    end)

    valueBox.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = input.KeyCode
        if key == Enum.KeyCode.Up or key == Enum.KeyCode.Right then
            self:Set(value + step)
        elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.Left then
            self:Set(value - step)
        end
    end)

    row.Row.MouseWheelForward:Connect(function()
        if self._disabled then return end
        self:Set(value + step)
    end)
    row.Row.MouseWheelBackward:Connect(function()
        if self._disabled then return end
        self:Set(value - step)
    end)

    paint()
    Theme:OnChanged(function() paint() end)

    if options.Settings then
        self:AddSettings(options.Settings)
    end
    self:RegisterFlag(options.Flag)
    table.insert(self.Container._items, self)
    return self
end

--------------------------------------------------------------------------------
-- Dropdown
--------------------------------------------------------------------------------
function Container:AddDropdown(options)
    options = options or {}
    local multi = options.Multi and true or false
    local values = options.Values or options.Options or {}

    local row = makeRow(self, {
        Icon = options.Icon,
        IconToken = options.IconToken,
        Title = options.Title,
        Desc = options.Desc,
        RightWidth = 148,
        Interactive = true,
    })

    local self = bindComponent(self, options, row)
    self.Kind = "Dropdown"
    local callback = options.Callback
    local selected = {}
    if options.Default ~= nil then
        if multi and type(options.Default) == "table" then
            for _, item in ipairs(options.Default) do selected[item] = true end
        else
            selected[options.Default] = true
        end
    end

    local value = Util.New("TextLabel", {
        Name = "Selected",
        Size = UDim2.new(1, -22, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 11.5,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
        ZIndex = self.ZIndex + 3,
    })
    Theme:Register(value, "TextColor3", "SubText")
    value.Parent = row.Right

    local chevron = Icons.Build("chevronDown", 14, "Muted", 0.7)
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, 0, 0.5, 0)
    chevron.LayoutOrder = 2
    chevron.ZIndex = self.ZIndex + 3
    chevron.Parent = row.Right

    local collapse = Collapse.new(self.Container.Frame, {
        Name = "DropdownPanel",
        Order = self.Order + 1,
        Fill = "SurfaceAlt",
        Radius = 12,
        ZIndex = self.ZIndex,
        Padding = 4,
        PadX = 6,
        PadY = 6,
    })

    local list = Util.New("ScrollingFrame", {
        Name = "List",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 4,
        ScrollBarImageTransparency = 0.6,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = self.ZIndex + 2,
    })
    Theme:Register(list, "ScrollBarImageColor3", "Stroke")
    list.ScrollBarImageColor3 = Theme:Get("Stroke")
    Util.New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
    }).Parent = list
    list.LayoutOrder = 1
    list.Parent = collapse.Panel

    local searchBox
    if options.Search ~= false and #values > 6 then
        searchBox = Util.New("TextBox", {
            Name = "Search",
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = Theme:Get("Surface"),
            BackgroundTransparency = 0.4,
            PlaceholderText = "Search",
            PlaceholderColor3 = Theme:Get("Muted"),
            Text = "",
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            ClearTextOnFocus = false,
            LayoutOrder = 0,
            ZIndex = self.ZIndex + 2,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = searchBox
        Util.New("UIPadding", { PaddingLeft = UDim.new(0, 10) }).Parent = searchBox
        Theme:Register(searchBox, "BackgroundColor3", "Surface")
        Theme:Register(searchBox, "TextColor3", "Text")
        Theme:Register(searchBox, "PlaceholderColor3", "Muted")
        searchBox.Parent = collapse.Panel
    end

    local rows = {}

    local function displayText()
        local names = {}
        for _, item in ipairs(values) do
            if selected[item] then names[#names + 1] = tostring(item) end
        end
        if #names == 0 then return options.NoneText or "None" end
        if #names == 1 then return names[1] end
        if multi then
            return string.format("%d selected", #names)
        end
        return names[1]
    end

    local function refresh()
        value.Text = displayText()
    end

    local function apply()
        refresh()
        if callback then
            if multi then
                local list_ = {}
                for _, item in ipairs(values) do
                    if selected[item] then list_[#list_ + 1] = item end
                end
                pcall(callback, list_)
            else
                local only = nil
                for _, item in ipairs(values) do
                    if selected[item] then only = item break end
                end
                pcall(callback, only)
            end
        end
        if self.Flag then
            if multi then
                local list_ = {}
                for _, item in ipairs(values) do
                    if selected[item] then list_[#list_ + 1] = item end
                end
                self.Window:SetFlagValue(self.Flag, list_)
            else
                local only = nil
                for _, item in ipairs(values) do
                    if selected[item] then only = item break end
                end
                self.Window:SetFlagValue(self.Flag, only)
            end
        end
    end

    local function buildRows()
        for _, rowFrame in ipairs(rows) do
            rowFrame:Destroy()
        end
        rows = {}

        for index, item in ipairs(values) do
            local option = Util.New("TextButton", {
                Name = "Option",
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = Theme:Get("Row"),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = index,
                ZIndex = self.ZIndex + 3,
            })
            Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = option

            local mark = Icons.Build(multi and "check" or "check", 13, "Accent", 0.68)
            mark.AnchorPoint = Vector2.new(0, 0.5)
            mark.Position = UDim2.fromOffset(9, 15)
            mark.Visible = selected[item] == true
            mark.ZIndex = self.ZIndex + 4
            mark.Parent = option

            local label = Util.New("TextLabel", {
                Name = "Label",
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -40, 1, 0),
                BackgroundTransparency = 1,
                Text = tostring(item),
                TextSize = 12,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = self.ZIndex + 4,
            })
            Theme:Register(label, "TextColor3", "SubText")
            label.Parent = option

            option.MouseEnter:Connect(function()
                Util.Tween(option, T_FAST, { BackgroundTransparency = 0.55, BackgroundColor3 = Theme:Get("RowHover") })
            end)
            option.MouseLeave:Connect(function()
                Util.Tween(option, T_FAST, { BackgroundTransparency = 1 })
            end)
            option.MouseButton1Click:Connect(function()
                if self._disabled then return end
                if multi then
                    selected[item] = not selected[item]
                else
                    local cleared = true
                    for key in pairs(selected) do
                        if key ~= item then selected[key] = nil end
                    end
                    if not selected[item] then
                        selected[item] = true
                        cleared = false
                    elseif options.AllowNone then
                        selected[item] = nil
                    end
                    if cleared and not options.AllowNone then
                        selected[item] = true
                    end
                end
                for _, other in ipairs(rows) do
                    for _, child in ipairs(other:GetChildren()) do
                        if child:IsA("Frame") and child.Name ~= "Label" then
                            child.Visible = selected[child:GetAttribute("Value")] == true
                        end
                    end
                end
                apply()
                if not multi then
                    collapse:SetOpen(false)
                    Util.Tween(chevron, T_MED, { Rotation = 0 })
                end
            end)

            mark:SetAttribute("Value", item)
            option.Parent = list
            rows[#rows + 1] = option
        end
    end

    local function layoutList()
        local layout = list:FindFirstChildOfClass("UIListLayout")
        local height = layout and layout.AbsoluteContentSize.Y or 0
        list.Size = UDim2.new(1, 0, 0, math.min(height, options.MaxHeight or 190))
    end

    local function filter(text)
        text = string.lower(text or "")
        for index, rowFrame in ipairs(rows) do
            local label = rowFrame:FindFirstChild("Label")
            local name = label and string.lower(label.Text) or ""
            rowFrame.Visible = text == "" or string.find(name, text, 1, true) ~= nil
        end
        layoutList()
    end

    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            filter(searchBox.Text)
        end)
    end

    buildRows()
    refresh()

    local open = false
    local function toggle()
        if self._disabled then return end
        open = not open
        layoutList()
        collapse:SetOpen(open)
        Util.Tween(chevron, T_MED, { Rotation = open and 180 or 0 })
    end

    row.Row.MouseButton1Click:Connect(toggle)

    function self:Set(item, silent)
        selected = {}
        if multi and type(item) == "table" then
            for _, entry in ipairs(item) do selected[entry] = true end
        elseif item ~= nil then
            selected[item] = true
        end
        for _, rowFrame in ipairs(rows) do
            for _, child in ipairs(rowFrame:GetChildren()) do
                if child:IsA("Frame") and child.Name ~= "Label" then
                    child.Visible = selected[child:GetAttribute("Value")] == true
                end
            end
        end
        refresh()
        if not silent then apply() end
        return self
    end

    function self:Get()
        if multi then
            local list_ = {}
            for _, item in ipairs(values) do
                if selected[item] then list_[#list_ + 1] = item end
            end
            return list_
        end
        for _, item in ipairs(values) do
            if selected[item] then return item end
        end
        return nil
    end

    function self:Refresh(newValues, keepSelection)
        values = newValues or values
        local layout = list:FindFirstChildOfClass("UIListLayout")
        if not keepSelection then selected = {} end
        buildRows()
        layoutList()
        refresh()
        return self
    end

    function self:SetOpen(state)
        if open ~= state then toggle() end
        return self
    end

    self._collapse = collapse
    if options.Settings then
        self:AddSettings(options.Settings)
    end
    self:RegisterFlag(options.Flag)
    table.insert(self.Container._items, self)
    return self
end

--------------------------------------------------------------------------------
-- Textbox
--------------------------------------------------------------------------------
function Container:AddTextbox(options)
    options = options or {}
    local row = makeRow(self, {
        Icon = options.Icon,
        IconToken = options.IconToken,
        Title = options.Title,
        Desc = options.Desc,
        RightWidth = options.Width or 150,
        Interactive = false,
    })

    local self = bindComponent(self, options, row)
    self.Kind = "Textbox"
    local callback = options.Callback

    local input = Util.New("TextBox", {
        Name = "Input",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme:Get("SurfaceAlt"),
        BackgroundTransparency = 0.4,
        PlaceholderText = options.Placeholder or "",
        PlaceholderColor3 = Theme:Get("Muted"),
        Text = options.Default or "",
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        ClearTextOnFocus = options.ClearOnFocus and true or false,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = input
    Util.New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }).Parent = input
    local stroke = Util.New("UIStroke", { Color = Theme:Get("Stroke"), Transparency = 0.92, Thickness = 1 })
    Theme:Register(stroke, "Color", "Stroke")
    stroke.Parent = input
    Theme:Register(input, "BackgroundColor3", "SurfaceAlt")
    Theme:Register(input, "TextColor3", "Text")
    Theme:Register(input, "PlaceholderColor3", "Muted")
    input.Parent = row.Right

    input.Focused:Connect(function()
        Util.Tween(stroke, T_FAST, { Color = Theme.Accent, Transparency = 0.35 })
    end)
    input.FocusLost:Connect(function(enterPressed)
        Util.Tween(stroke, T_FAST, { Color = Theme:Get("Stroke"), Transparency = 0.92 })
        if callback and (enterPressed or options.FireOnFocusLost ~= false) then
            pcall(callback, input.Text, enterPressed)
        end
        if self.Flag then
            self.Window:SetFlagValue(self.Flag, input.Text)
        end
    end)

    function self:Set(text, silent)
        input.Text = tostring(text)
        if not silent and callback then pcall(callback, input.Text, false) end
        return self
    end

    function self:Get()
        return input.Text
    end

    if options.Settings then
        self:AddSettings(options.Settings)
    end
    self:RegisterFlag(options.Flag)
    table.insert(self.Container._items, self)
    return self
end

--------------------------------------------------------------------------------
-- Keybind
--------------------------------------------------------------------------------
function Container:AddKeybind(options)
    options = options or {}
    local row = makeRow(self, {
        Icon = options.Icon,
        IconToken = options.IconToken,
        Title = options.Title,
        Desc = options.Desc,
        RightWidth = 108,
        Interactive = true,
    })

    local self = bindComponent(self, options, row)
    self.Kind = "Keybind"
    local callback = options.Callback
    local key = options.Default or options.Key

    local pill = Util.New("TextButton", {
        Name = "Key",
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = Theme:Get("SurfaceAlt"),
        BackgroundTransparency = 0.35,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 1,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = pill
    Util.New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }).Parent = pill
    Theme:Register(pill, "BackgroundColor3", "SurfaceAlt")

    local label = Util.New("TextLabel", {
        Name = "Label",
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 11.5,
        Font = Enum.Font.GothamBold,
        ZIndex = self.ZIndex + 4,
    })
    Theme:Register(label, "TextColor3", "Text")
    label.Parent = pill
    pill.Parent = row.Right

    local captureConn
    self._capturingKey = false

    local function paint()
        label.Text = key and key.Name or "None"
    end
    paint()

    local function finish()
        if captureConn then
            captureConn:Disconnect()
            captureConn = nil
        end
        self._capturingKey = false
        if self.Container.Window then
            self.Container.Window._capturing = false
        end
    end

    pill.MouseButton1Click:Connect(function()
        if self._disabled then return end
        if captureConn then finish() end
        label.Text = "Press..."
        self._capturingKey = true
        if self.Container.Window then
            self.Container.Window._capturing = true
        end
        captureConn = UserInputService.InputBegan:Connect(function(input, processed)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    key = nil
                    paint()
                    finish()
                end
                return
            end
            if input.KeyCode == Enum.KeyCode.Escape then
                paint()
                finish()
                return
            end
            if input.KeyCode == Enum.KeyCode.Backspace then
                key = nil
                paint()
                finish()
                if self.Flag then self.Window:SetFlagValue(self.Flag, nil) end
                return
            end
            key = input.KeyCode
            paint()
            finish()
            if self.Flag then self.Window:SetFlagValue(self.Flag, key.Name) end
        end)
    end)

    function self:Set(newKey, silent)
        key = newKey
        paint()
        if not silent and callback then pcall(callback, key) end
        return self
    end

    function self:Get()
        return key
    end

    XenonUI._registerKeybind(self)

    function self:_fire()
        if self._capturingKey then return end
        if callback and key then pcall(callback, key) end
    end

    self._getKey = function() return key end

    if options.Settings then
        self:AddSettings(options.Settings)
    end
    self:RegisterFlag(options.Flag)
    table.insert(self.Container._items, self)
    return self
end

--------------------------------------------------------------------------------
-- Color picker
--------------------------------------------------------------------------------
function Container:AddColorPicker(options)
    options = options or {}
    local row = makeRow(self, {
        Icon = options.Icon,
        IconToken = options.IconToken,
        Title = options.Title,
        Desc = options.Desc,
        RightWidth = 78,
        Interactive = true,
    })

    local self = bindComponent(self, options, row)
    self.Kind = "ColorPicker"
    local callback = options.Callback
    local color = options.Default or Color3.fromRGB(255, 255, 255)
    local alpha = options.Alpha ~= nil and options.Alpha or (options.UseAlpha and 0 or 1)
    local useAlpha = options.UseAlpha and true or false
    local rainbow = false

    local swatch = Util.New("TextButton", {
        Name = "Swatch",
        Size = UDim2.fromOffset(56, 24),
        BackgroundColor3 = color,
        BackgroundTransparency = useAlpha and (1 - alpha) or 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 1,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 7) }).Parent = swatch
    local swatchStroke = Util.New("UIStroke", { Color = Theme:Get("Stroke"), Transparency = 0.85, Thickness = 1 })
    Theme:Register(swatchStroke, "Color", "Stroke")
    swatchStroke.Parent = swatch
    swatch.Parent = row.Right

    local collapse = Collapse.new(self.Container.Frame, {
        Name = "ColorPanel",
        Order = self.Order + 1,
        Fill = "SurfaceAlt",
        Radius = 12,
        ZIndex = self.ZIndex,
        Padding = 8,
        PadX = 11,
        PadY = 11,
    })
    local panel = collapse.Panel

    local svArea = Util.New("TextButton", {
        Name = "SVArea",
        Size = UDim2.new(1, 0, 0, 110),
        BackgroundColor3 = Color3.fromHSV(0, 1, 1),
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 1,
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 2,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = svArea

    local satOverlay = Util.New("Frame", {
        Name = "Saturation",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = satOverlay
    Util.New("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new(Color3.new(1, 1, 1)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }).Parent = satOverlay
    satOverlay.Parent = svArea

    local valOverlay = Util.New("Frame", {
        Name = "Value",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 4,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = valOverlay
    Util.New("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(0, 0, 0)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }).Parent = valOverlay
    valOverlay.Parent = svArea

    local svKnob = Util.New("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 6,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 6) }).Parent = svKnob
    Util.New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.55, Thickness = 1.5 }).Parent = svKnob
    svKnob.Parent = svArea
    svArea.Parent = panel

    local function makeBar(name, order, height)
        local bar = Util.New("TextButton", {
            Name = name,
            Size = UDim2.new(1, 0, 0, height or 12),
            BackgroundColor3 = Color3.new(1, 1, 1),
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = order,
            BorderSizePixel = 0,
            ZIndex = self.ZIndex + 2,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 6) }).Parent = bar
        local knob = Util.New("Frame", {
            Name = "Knob",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0.5, 0),
            Size = UDim2.fromOffset(height and height + 4 or 16, height and height + 4 or 16),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = self.ZIndex + 6,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }).Parent = knob
        Util.New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.55, Thickness = 1.5 }).Parent = knob
        knob.Parent = bar
        bar.Parent = panel
        return bar, knob
    end

    local hueBar, hueKnob = makeBar("Hue", 2, 12)
    local hueGradient = Util.New("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
            ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
            ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
            ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1, 1, 1)),
        }),
    })
    hueGradient.Parent = hueBar

    local alphaBar, alphaKnob
    if useAlpha then
        alphaBar, alphaKnob = makeBar("Alpha", 3, 12)
        local checker = Util.New("Frame", {
            Name = "Checker",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Theme:Get("Muted"),
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0,
            ZIndex = self.ZIndex + 3,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 6) }).Parent = checker
        checker.Parent = alphaBar
        local alphaGradient = Util.New("UIGradient", {
            Rotation = 0,
            Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(1, color) }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
        })
        alphaGradient.Parent = alphaBar
        self._alphaGradient = alphaGradient
    end

    local hexRow = Util.New("Frame", {
        Name = "HexRow",
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 4,
        ZIndex = self.ZIndex + 2,
    })
    local hexBox = Util.New("TextBox", {
        Name = "Hex",
        Size = UDim2.new(0, 96, 1, 0),
        BackgroundColor3 = Theme:Get("Surface"),
        BackgroundTransparency = 0.4,
        Text = Util.ToHex(color),
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = hexBox
    Theme:Register(hexBox, "BackgroundColor3", "Surface")
    Theme:Register(hexBox, "TextColor3", "Text")
    hexBox.Parent = hexRow

    local rainbowButton = Util.New("TextButton", {
        Name = "Rainbow",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 84, 1, 0),
        BackgroundColor3 = Theme:Get("Surface"),
        BackgroundTransparency = 0.4,
        Text = "Rainbow",
        TextSize = 11.5,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 8) }).Parent = rainbowButton
    Theme:Register(rainbowButton, "BackgroundColor3", "Surface")
    Theme:Register(rainbowButton, "TextColor3", "SubText")
    rainbowButton.Parent = hexRow
    hexRow.Parent = panel

    if options.Presets then
        local presetRow = Util.New("Frame", {
            Name = "Presets",
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            LayoutOrder = 5,
            ZIndex = self.ZIndex + 2,
        })
        local presetLayout = Util.New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        })
        presetLayout.Parent = presetRow
        for index, preset in ipairs(options.Presets) do
            local button = Util.New("TextButton", {
                Name = "Preset",
                Size = UDim2.fromOffset(22, 22),
                BackgroundColor3 = preset,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = index,
                ZIndex = self.ZIndex + 3,
            })
            Util.New("UICorner", { CornerRadius = UDim.new(0, 6) }).Parent = button
            button.MouseButton1Click:Connect(function()
                rainbow = false
                self:Set(preset)
            end)
            button.Parent = presetRow
        end
        presetRow.Parent = panel
    end

    local function paint(noCallback)
        local h, s, v = color:ToHSV()
        svArea.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svKnob.Position = UDim2.new(s, 0, 1 - v, 0)
        hueKnob.Position = UDim2.new(h, 0.5, 0)
        swatch.BackgroundColor3 = color
        if useAlpha then
            swatch.BackgroundTransparency = 1 - alpha
            alphaKnob.Position = UDim2.new(alpha, 0.5, 0)
            if self._alphaGradient then
                self._alphaGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, color),
                    ColorSequenceKeypoint.new(1, color),
                })
            end
        end
        if hexBox.Text ~= Util.ToHex(color) and not hexBox:IsFocused() then
            hexBox.Text = Util.ToHex(color)
        end
        if not noCallback and callback then
            pcall(callback, color, alpha)
        end
        if self.Flag then
            self.Window:SetFlagValue(self.Flag, { Util.ToHex(color), alpha })
        end
    end

    function self:Set(newColor, silent)
        color = newColor or color
        paint(silent)
        return self
    end

    function self:SetAlpha(value, silent)
        alpha = Util.Clamp(tonumber(value) or 1, 0, 1)
        paint(silent)
        return self
    end

    function self:Get()
        return color, alpha
    end

    local function dragBar(bar, onUpdate)
        local conn, release
        local function update(x)
            local ratio = Util.Clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
            onUpdate(ratio)
        end
        bar.MouseButton1Down:Connect(function(x)
            update(x)
            conn = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    update(input.Position.X)
                end
            end)
            release = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if conn then conn:Disconnect() conn = nil end
                    if release then release:Disconnect() release = nil end
                end
            end)
        end)
    end

    local function dragArea(area, onUpdate)
        local conn, release
        local function update(x, y)
            local ratioX = Util.Clamp((x - area.AbsolutePosition.X) / math.max(1, area.AbsoluteSize.X), 0, 1)
            local ratioY = Util.Clamp((y - area.AbsolutePosition.Y) / math.max(1, area.AbsoluteSize.Y), 0, 1)
            onUpdate(ratioX, 1 - ratioY)
        end
        area.MouseButton1Down:Connect(function(x, y)
            update(x, y)
            conn = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    update(input.Position.X, input.Position.Y)
                end
            end)
            release = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if conn then conn:Disconnect() conn = nil end
                    if release then release:Disconnect() release = nil end
                end
            end)
        end)
    end

    dragArea(svArea, function(s, v)
        local h = select(1, color:ToHSV())
        rainbow = false
        color = Color3.fromHSV(h, s, v)
        paint()
    end)

    dragBar(hueBar, function(h)
        local _, s, v = color:ToHSV()
        rainbow = false
        color = Color3.fromHSV(h, s, v)
        paint()
    end)

    if alphaBar then
        dragBar(alphaBar, function(value)
            alpha = value
            paint()
        end)
    end

    hexBox.FocusLost:Connect(function()
        local parsed = Util.FromHex(hexBox.Text)
        if parsed then
            rainbow = false
            color = parsed
            paint()
        else
            hexBox.Text = Util.ToHex(color)
        end
    end)

    rainbowButton.MouseButton1Click:Connect(function()
        rainbow = not rainbow
        Theme:Register(rainbowButton, "TextColor3", rainbow and "Accent" or "SubText")
        rainbowButton.TextColor3 = Theme:Get(rainbow and "Accent" or "SubText")
    end)

    local open = false
    local function toggle()
        open = not open
        collapse:SetOpen(open)
    end

    row.Row.MouseButton1Click:Connect(toggle)
    swatch.MouseButton1Click:Connect(function() toggle() end)

    self._collapse = collapse
    self._rainbowCheck = function()
        return rainbow
    end
    self._rainbowStep = function(h)
        local _, s, v = color:ToHSV()
        color = Color3.fromHSV(h % 1, s, v)
        paint()
    end

    XenonUI._registerRainbow(self)
    paint(true)
    if options.Settings then
        self:AddSettings(options.Settings)
    end
    self:RegisterFlag(options.Flag)
    table.insert(self.Container._items, self)
    return self
end

--------------------------------------------------------------------------------
-- Label, paragraph, divider, progress
--------------------------------------------------------------------------------
function Container:AddLabel(options)
    options = options or {}
    local row = makeRow(self, {
        Title = options.Title,
        Desc = options.Desc,
        RightWidth = 0,
        Interactive = false,
        Height = options.Height or (options.Desc and 56 or 38),
    })
    local self = bindComponent(self, options, row)
    self.Kind = "Label"
    row.Title.Font = Enum.Font.GothamMedium
    row.Title.TextSize = options.TextSize or 12.5
    if options.Center then
        row.Title.TextXAlignment = Enum.TextXAlignment.Center
    end
    if options.ColorToken then
        Theme:Register(row.Title, "TextColor3", options.ColorToken)
    end
    function self:Set(text)
        row.Title.Text = text
        return self
    end
    table.insert(self.Container._items, self)
    return self
end

function Container:AddDivider(options)
    options = options or {}
    local container = Util.New("Frame", {
        Name = "DividerRow",
        Size = UDim2.new(1, 0, 0, options.Height or 10),
        BackgroundTransparency = 1,
        LayoutOrder = self:NextOrder(),
    })
    container.Parent = self.Frame
    local line = Glass.Divider(container, 0.9)
    line.Position = UDim2.new(0, 0, 0.5, 0)
    local object = { Row = container }
    function object:SetVisible(state) container.Visible = state end
    return object
end

function Container:AddProgress(options)
    options = options or {}
    local row = makeRow(self, {
        Title = options.Title,
        Desc = options.Desc,
        RightWidth = 120,
        Interactive = false,
    })
    local self = bindComponent(self, options, row)
    self.Kind = "Progress"

    local track = Util.New("Frame", {
        Name = "Track",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Theme:Get("Track"),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 3,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 3) }).Parent = track
    Theme:Register(track, "BackgroundColor3", "Track")

    local fill = Util.New("Frame", {
        Name = "Fill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = self.ZIndex + 4,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 3) }).Parent = fill
    Theme:Register(fill, "BackgroundColor3", "Accent")
    fill.Parent = track
    track.Parent = row.Right

    local percent = Util.New("TextLabel", {
        Name = "Percent",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -6, 0, 0),
        Size = UDim2.new(0, 40, 1, 0),
        BackgroundTransparency = 1,
        Text = "0%",
        TextSize = 11.5,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = self.ZIndex + 4,
    })
    Theme:Register(percent, "TextColor3", "SubText")
    percent.Parent = row.Right
    row.Right.Size = UDim2.new(0, 120, 0, 18)
    track.Size = UDim2.new(1, -46, 0, 6)

    function self:Set(value, text)
        local ratio = Util.Clamp(tonumber(value) or 0, 0, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        percent.Text = text or string.format("%d%%", math.floor(ratio * 100 + 0.5))
        return self
    end

    table.insert(self.Container._items, self)
    return self
end

XenonUI.Collapse = Collapse
XenonUI.Container = Container
XenonUI.Component = Component
--------------------------------------------------------------------------------
-- Registries
--------------------------------------------------------------------------------
XenonUI._keybindComponents = {}
XenonUI._rainbowPickers = {}

function XenonUI._registerKeybind(component)
    for _, existing in ipairs(XenonUI._keybindComponents) do
        if existing == component then return end
    end
    XenonUI._keybindComponents[#XenonUI._keybindComponents + 1] = component
end

function XenonUI._registerRainbow(component)
    for _, existing in ipairs(XenonUI._rainbowPickers) do
        if existing == component then return end
    end
    XenonUI._rainbowPickers[#XenonUI._rainbowPickers + 1] = component
end

--------------------------------------------------------------------------------
-- Theme helpers
--------------------------------------------------------------------------------
function Theme:RefreshAccent()
    for object, bindings in pairs(self._registry) do
        for property, token in pairs(bindings) do
            if token == "Accent" then
                pcall(function() object[property] = self.Accent end)
            end
        end
    end
    if Glass.PaintBorders then Glass.PaintBorders() end
end

local _rainbowClock = 0
Scheduler:Add("XenonUI_Rainbow", function(delta)
    local active = Theme.Rainbow
    for _, picker in ipairs(XenonUI._rainbowPickers) do
        if picker._rainbowCheck and picker._rainbowCheck() then
            active = true
            break
        end
    end
    if not active then
        _rainbowClock = 0
        return
    end

    Theme._hue = (Theme._hue + delta * Theme.RainbowSpeed) % 1
    for _, picker in ipairs(XenonUI._rainbowPickers) do
        if picker._rainbowCheck and picker._rainbowCheck() then
            picker._rainbowStep(Theme._hue)
        end
    end

    if Theme.Rainbow then
        _rainbowClock = _rainbowClock + delta
        if _rainbowClock >= 0.05 then
            _rainbowClock = 0
            Theme.Accent = Color3.fromHSV(Theme._hue, 0.68, 1)
            Theme:RefreshAccent()
        end
    end
end)

--------------------------------------------------------------------------------
-- Config storage (UI state only)
--------------------------------------------------------------------------------
local Config = {}
local CONFIG_FOLDER = "XenonUI/configs"

local function hasFileSystem()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function configPath(name)
    return CONFIG_FOLDER .. "/" .. tostring(name) .. ".json"
end

function Config.Serialize(window)
    local data = {}
    for flag, component in pairs(window._flags) do
        if component.Get then
            local kind = component.Kind
            local value = component:Get()
            if kind == "Keybind" then
                value = value and value.Name or nil
            elseif kind == "ColorPicker" then
                local color, alpha = component:Get()
                value = { Util.ToHex(color), alpha }
            elseif typeof(value) == "Color3" then
                value = Util.ToHex(value)
            end
            if value ~= nil then
                data[flag] = value
            end
        end
    end
    return data
end

function Config.Apply(window, data)
    if type(data) ~= "table" then return 0 end
    local applied = 0
    for flag, component in pairs(window._flags) do
        local value = data[flag]
        if value ~= nil then
            local kind = component.Kind
            if kind == "Toggle" and type(value) == "boolean" then
                component:Set(value); applied = applied + 1
            elseif kind == "Slider" and type(value) == "number" then
                component:Set(value); applied = applied + 1
            elseif kind == "Dropdown" then
                component:Set(value); applied = applied + 1
            elseif kind == "Textbox" and type(value) == "string" then
                component:Set(value); applied = applied + 1
            elseif kind == "Keybind" and type(value) == "string" then
                local ok, code = pcall(function() return Enum.KeyCode[value] end)
                if ok and code then component:Set(code, true); applied = applied + 1 end
            elseif kind == "ColorPicker" then
                if type(value) == "table" then
                    local color = Util.FromHex(value[1])
                    if color then
                        component:Set(color, true)
                        component:SetAlpha(value[2], true)
                        applied = applied + 1
                    end
                elseif type(value) == "string" then
                    local color = Util.FromHex(value)
                    if color then component:Set(color, true); applied = applied + 1 end
                end
            end
        end
    end
    return applied
end

function Config.List()
    if not hasFileSystem() or type(listfiles) ~= "function" then return {} end
    local ok, files = pcall(listfiles, CONFIG_FOLDER)
    if not ok or type(files) ~= "table" then return {} end
    local names = {}
    for _, path in ipairs(files) do
        local name = string.match(tostring(path), "([^/\\]+)%.json$")
        if name then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

function Config.Save(window, name)
    local data = Config.Serialize(window)
    local ok, encoded = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    if not ok then
        XenonUI:Error("Config", "Failed to encode the configuration.", 3)
        return false
    end
    if not hasFileSystem() then
        window._memoryConfigs[name] = encoded
        return true
    end
    local success, err = pcall(function()
        if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        writefile(configPath(name), encoded)
    end)
    if not success then
        XenonUI:Error("Config", "Unable to write file: " .. tostring(err), 4)
        return false
    end
    return true
end

function Config.Load(window, name)
    local encoded = window._memoryConfigs[name]
    if not encoded and hasFileSystem() then
        local ok, content = pcall(function()
            if isfile(configPath(name)) then return readfile(configPath(name)) end
            return nil
        end)
        if ok then encoded = content end
    end
    if not encoded then return false end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(encoded)
    end)
    if not ok or type(data) ~= "table" then return false end
    Config.Apply(window, data)
    return true
end

function Config.Delete(window, name)
    window._memoryConfigs[name] = nil
    if not hasFileSystem() then return true end
    local ok = pcall(function()
        if isfile(configPath(name)) then
            if type(delfile) == "function" then
                delfile(configPath(name))
            else
                writefile(configPath(name), "")
            end
        end
    end)
    return ok
end

--------------------------------------------------------------------------------
-- Tab
--------------------------------------------------------------------------------
local function tintIcon(host, token)
    if not host then return end
    host:SetAttribute("IconToken", token)
    local canvas = host:FindFirstChild("canvas")
    if not canvas then return end
    local color = Theme:Get(token)
    for _, child in ipairs(canvas:GetDescendants()) do
        if child:IsA("Frame") then
            child.BackgroundColor3 = color
        elseif child:IsA("UIStroke") then
            child.Color = color
        end
    end
end

local Tab = {}
Tab.__index = Tab

function Tab:AddSection(options)
    options = options or {}
    local window = self.Window
    local z = 12

    local outer = Util.New("Frame", {
        Name = "Section",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = #self.Sections + 1,
    })

    local column
    if options.Column and self.Columns[options.Column] then
        column = self.Columns[options.Column]
    else
        column = self.Columns[1]
        local best = nil
        for _, candidate in ipairs(self.Columns) do
            local layout = candidate.Layout
            local height = layout and layout.AbsoluteContentSize.Y or 0
            local score = (candidate._sectionCount or 0) * 100000 + height
            if not best or score < best then
                best = score
                column = candidate
            end
        end
    end
    column._sectionCount = (column._sectionCount or 0) + 1
    outer.Parent = column

    local card = Glass.Apply(outer, { Radius = 16, Fill = "Card", ZIndex = z })
    Util.New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    }).Parent = card
    Util.New("UIPadding", {
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
    }).Parent = card

    local header = Util.New("TextButton", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 1,
        ZIndex = z + 2,
    })
    header.Parent = card

    local titleX = 14
    if options.Icon then
        local glyph = Icons.Build(options.Icon, 15, "Accent", 0.72)
        glyph.Position = UDim2.fromOffset(12, 11)
        glyph.ZIndex = z + 3
        glyph.Parent = header
        titleX = 34
    end

    local title = Util.New("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(titleX, 0),
        Size = UDim2.new(1, -(titleX + 34), 1, 0),
        BackgroundTransparency = 1,
        Text = options.Title or "Section",
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = z + 3,
    })
    Theme:Register(title, "TextColor3", "Text")
    title.Parent = header

    local body = Collapse.new(card, {
        Name = "Body",
        Order = 2,
        Plain = true,
        Padding = 7,
        PadX = 10,
        PadY = 8,
        ZIndex = z,
    })
    body:SetOpen(true, true)

    local section = Container.new(body.Panel, z + 2, window)
    section.Outer = outer
    section.Body = body
    section.TitleLabel = title
    section.Kind = "Section"
    section.Window = window

    local chevron = Icons.Build("chevronDown", 14, "Muted", 0.7)
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, -12, 0.5, 0)
    chevron.ZIndex = z + 3
    chevron.Parent = header

    local open = true
    local collapsible = options.Collapsible ~= false
    if not collapsible then
        chevron.Visible = false
    end

    header.MouseButton1Click:Connect(function()
        if not collapsible then return end
        open = not open
        body:SetOpen(open)
        Util.Tween(chevron, T_MED, { Rotation = open and 0 or -90 })
    end)

    function section:SetOpen(state)
        if not collapsible then return self end
        open = state and true or false
        body:SetOpen(open)
        Util.Tween(chevron, T_MED, { Rotation = open and 0 or -90 })
        return self
    end

    function section:SetTitle(text)
        title.Text = text
        return self
    end

    self.Sections[#self.Sections + 1] = section
    window._sections[#window._sections + 1] = section
    return section
end

function Tab:Select()
    self.Window:SelectTab(self)
end

function Tab:SetTitle(text)
    self.Button.Title.Text = text
    return self
end

function Tab:SetBadge(text)
    self.Button.Badge.Text = text or ""
    self.Button.Badge.Visible = text ~= nil and text ~= ""
    return self
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
local Window = {}
Window.__index = Window

function XenonUI:CreateWindow(options)
    options = options or {}

    if XenonUI._window then
        XenonUI._window:Destroy()
    end

    Theme:Refresh(false)
    if options.Accent then Theme.Accent = options.Accent end
    if options.Theme then Theme.Mode = options.Theme end
    Theme:Refresh(false)

    local container = XenonUI:ResolveContainer()
    XenonUI._container = container

    local gui = Util.New("ScreenGui", {
        Name = options.Name or "XenonUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = options.DisplayOrder or 1000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    gui.Parent = container
    XenonUI._rootGui = gui

    local launcher = Util.New("ScreenGui", {
        Name = "XenonUI_Launcher",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 1001,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    launcher.Parent = container

    local self = setmetatable({}, Window)
    self.Gui = gui
    self.Launcher = launcher
    self.Tabs = {}
    self.Columns = options.Columns or 2
    self.Scale = options.Scale or 1
    self.ToggleKey = options.ToggleKey or Enum.KeyCode.RightShift
    self._flags = {}
    self._sections = {}
    self._memoryConfigs = {}
    self._flagValues = {}
    self._capturing = false
    self._open = false
    self._maid = Maid.new()

    local size = options.Size or Vector2.new(920, 600)

    local root = Util.New("Frame", {
        Name = "Root",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    })
    root.Parent = gui

    local backdrop = Util.New("TextButton", {
        Name = "Backdrop",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 1,
    })
    backdrop.Parent = root
    if options.CloseOnBackdropClick then
        backdrop.MouseButton1Click:Connect(function() self:SetOpen(false) end)
    end

    local main = Util.New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(size.X, size.Y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,
    })
    main.Parent = root

    local uiScale = Util.New("UIScale", { Scale = self.Scale })
    uiScale.Parent = main
    self.UIScale = uiScale

    local content = Glass.Apply(main, { Radius = 20, Fill = "Surface", ZIndex = 10 })
    content.ClipsDescendants = true
    self.Content = content

    ---------------------------------------------------------------- sidebar
    local sidebar = Util.New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, options.SidebarWidth or 226, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 12,
    })
    sidebar.Parent = content

    local sidebarLine = Util.New("Frame", {
        Name = "Line",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Theme:Get("Stroke"),
        BackgroundTransparency = 0.92,
        BorderSizePixel = 0,
        ZIndex = 13,
    })
    Theme:Register(sidebarLine, "BackgroundColor3", "Stroke")
    sidebarLine.Parent = sidebar

    local brand = Util.New("TextButton", {
        Name = "Brand",
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 13,
    })
    brand.Parent = sidebar

    local logo = Util.New("Frame", {
        Name = "Logo",
        Position = UDim2.fromOffset(16, 14),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 14,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 10) }).Parent = logo
    Util.New("UIGradient", {
        Rotation = 135,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(1, Util.LerpColor(Theme.Accent, Color3.new(1, 1, 1), 0.35)),
        }),
    }).Parent = logo
    Theme:Register(logo, "BackgroundColor3", "Accent")
    local logoIcon = Icons.Build(options.Logo or "layers", 18, "Text", 0.72)
    logoIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    logoIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    logoIcon.ZIndex = 15
    logoIcon.Parent = logo
    logo.Parent = brand
    self.Logo = logo

    local titleLabel = Util.New("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(60, 13),
        Size = UDim2.new(1, -74, 0, 18),
        BackgroundTransparency = 1,
        Text = options.Title or "XenonUI",
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })
    Theme:Register(titleLabel, "TextColor3", "Text")
    titleLabel.Parent = brand

    local subtitleLabel = Util.New("TextLabel", {
        Name = "SubTitle",
        Position = UDim2.fromOffset(60, 31),
        Size = UDim2.new(1, -74, 0, 15),
        BackgroundTransparency = 1,
        Text = options.SubTitle or "",
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })
    Theme:Register(subtitleLabel, "TextColor3", "Muted")
    subtitleLabel.Parent = brand

    local searchWrap = Util.New("Frame", {
        Name = "SearchWrap",
        Position = UDim2.fromOffset(0, 62),
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        ZIndex = 13,
    })
    searchWrap.Parent = sidebar

    local searchBox = Util.New("TextBox", {
        Name = "Search",
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -32, 0, 30),
        BackgroundColor3 = Theme:Get("SurfaceAlt"),
        BackgroundTransparency = 0.5,
        PlaceholderText = "Search",
        PlaceholderColor3 = Theme:Get("Muted"),
        Text = "",
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        ClearTextOnFocus = false,
        ZIndex = 14,
    })
    Util.New("UICorner", { CornerRadius = UDim.new(0, 9) }).Parent = searchBox
    Util.New("UIPadding", { PaddingLeft = UDim.new(0, 32), PaddingRight = UDim.new(0, 10) }).Parent = searchBox
    Theme:Register(searchBox, "BackgroundColor3", "SurfaceAlt")
    Theme:Register(searchBox, "TextColor3", "Text")
    Theme:Register(searchBox, "PlaceholderColor3", "Muted")
    searchBox.Parent = searchWrap

    local searchIcon = Icons.Build("search", 14, "Muted", 0.72)
    searchIcon.Position = UDim2.fromOffset(10, 8)
    searchIcon.ZIndex = 15
    searchIcon.Parent = searchBox

    local tabScroll = Util.New("ScrollingFrame", {
        Name = "TabScroll",
        Position = UDim2.fromOffset(0, 106),
        Size = UDim2.new(1, 0, 1, -106 - 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.7,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 13,
    })
    tabScroll.ScrollBarImageColor3 = Theme:Get("Stroke")
    Util.New("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 8),
    }).Parent = tabScroll
    Util.New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    }).Parent = tabScroll
    tabScroll.Parent = sidebar

    local footer = Util.New("TextLabel", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -10),
        Size = UDim2.new(1, -32, 0, 16),
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 10.5,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    })
    Theme:Register(footer, "TextColor3", "Muted")
    footer.Parent = sidebar
    self.Footer = footer

    ---------------------------------------------------------------- content
    local bodyArea = Util.New("Frame", {
        Name = "BodyArea",
        Position = UDim2.new(0, options.SidebarWidth or 226, 0, 0),
        Size = UDim2.new(1, -(options.SidebarWidth or 226), 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 12,
    })
    bodyArea.Parent = content

    local topbar = Util.New("TextButton", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 13,
    })
    topbar.Parent = bodyArea

    local pageTitle = Util.New("TextLabel", {
        Name = "PageTitle",
        Position = UDim2.fromOffset(22, 10),
        Size = UDim2.new(1, -160, 0, 20),
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 17,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })
    Theme:Register(pageTitle, "TextColor3", "Text")
    pageTitle.Parent = topbar

    local pageDesc = Util.New("TextLabel", {
        Name = "PageDesc",
        Position = UDim2.fromOffset(22, 31),
        Size = UDim2.new(1, -160, 0, 15),
        BackgroundTransparency = 1,
        Text = "",
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })
    Theme:Register(pageDesc, "TextColor3", "Muted")
    pageDesc.Parent = topbar

    local controls = Util.New("Frame", {
        Name = "Controls",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 30),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 14,
    })
    Util.New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }).Parent = controls
    controls.Parent = topbar

    local function controlButton(iconName, order, callback)
        local button = Util.New("TextButton", {
            Name = "Control",
            Size = UDim2.fromOffset(30, 30),
            BackgroundColor3 = Theme:Get("SurfaceAlt"),
            BackgroundTransparency = 0.55,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = order,
            ZIndex = 15,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 9) }).Parent = button
        Theme:Register(button, "BackgroundColor3", "SurfaceAlt")
        local glyph = Icons.Build(iconName, 15, "SubText", 0.72)
        glyph.AnchorPoint = Vector2.new(0.5, 0.5)
        glyph.Position = UDim2.new(0.5, 0, 0.5, 0)
        glyph.ZIndex = 16
        glyph.Parent = button
        button.MouseEnter:Connect(function()
            Util.Tween(button, T_FAST, { BackgroundTransparency = 0.25 })
        end)
        button.MouseLeave:Connect(function()
            Util.Tween(button, T_FAST, { BackgroundTransparency = 0.55 })
        end)
        button.MouseButton1Click:Connect(callback)
        button.Parent = controls
        return button
    end

    controlButton("minimize", 1, function() self:SetOpen(false) end)
    controlButton("close", 2, function()
        self:SetOpen(false)
        XenonUI:Success("XenonUI", "Interface hidden. Press the toggle key to bring it back.", 3)
    end)

    local topLine = Glass.Divider(bodyArea, 0.92)
    topLine.Position = UDim2.fromOffset(0, 58)

    local scroll = Util.New("ScrollingFrame", {
        Name = "PageScroll",
        Position = UDim2.fromOffset(0, 59),
        Size = UDim2.new(1, 0, 1, -59),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageTransparency = 0.65,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 13,
    })
    scroll.ScrollBarImageColor3 = Theme:Get("Stroke")
    Util.New("UIPadding", {
        PaddingLeft = UDim.new(0, 18),
        PaddingRight = UDim.new(0, 18),
        PaddingTop = UDim.new(0, 16),
        PaddingBottom = UDim.new(0, 18),
    }).Parent = scroll
    scroll.Parent = bodyArea

    local pages = Util.New("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 14,
    })
    pages.Parent = scroll

    ---------------------------------------------------------------- resize grip
    local grip = Util.New("TextButton", {
        Name = "ResizeGrip",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -4, 1, -4),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Visible = options.Resizable ~= false,
        ZIndex = 40,
    })
    local gripLines = {}
    for index = 1, 3 do
        local line = Util.New("Frame", {
            Name = "Line",
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.fromOffset(-2 - (index - 1) * 5, -2),
            Size = UDim2.fromOffset(2, 4 + index * 4),
            BackgroundColor3 = Theme:Get("Muted"),
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            ZIndex = 41,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 1) }).Parent = line
        Theme:Register(line, "BackgroundColor3", "Muted")
        line.Parent = grip
        gripLines[#gripLines + 1] = line
    end
    grip.Parent = content

    ---------------------------------------------------------------- launcher pill
    local pill = Util.New("TextButton", {
        Name = "Launcher",
        Position = UDim2.new(0, 20, 1, -20),
        AnchorPoint = Vector2.new(0, 1),
        Size = UDim2.fromOffset(46, 46),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Visible = true,
        ZIndex = 10,
    })
    local pillFill = Glass.Apply(pill, { Radius = 14, Fill = "Surface", ZIndex = 10 })
    local pillIcon = Icons.Build(options.Logo or "layers", 20, "Text", 0.72)
    pillIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    pillIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    pillIcon.ZIndex = 12
    pillIcon.Parent = pillFill
    pill.Parent = launcher
    pill.MouseButton1Click:Connect(function() self:SetOpen(true) end)
    pill.MouseEnter:Connect(function() Util.Tween(pill, T_FAST, { Size = UDim2.fromOffset(50, 50) }) end)
    pill.MouseLeave:Connect(function() Util.Tween(pill, T_FAST, { Size = UDim2.fromOffset(46, 46) }) end)
    self.Pill = pill

    ---------------------------------------------------------------- behaviour
    local function makeDraggable(handle)
        local dragging = false
        local startMouse = Vector2.new(0, 0)
        local startPos = Vector2.new(0, 0)
        local moveConn, releaseConn

        handle.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            dragging = true
            startMouse = Vector2.new(input.Position.X, input.Position.Y)
            startPos = main.AbsolutePosition
            if moveConn then moveConn:Disconnect() end
            moveConn = UserInputService.InputChanged:Connect(function(changed)
                if not dragging then return end
                if changed.UserInputType ~= Enum.UserInputType.MouseMovement and changed.UserInputType ~= Enum.UserInputType.Touch then return end
                local camera = workspace.CurrentCamera
                local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
                local delta = Vector2.new(changed.Position.X, changed.Position.Y) - startMouse
                local scaled = main.AbsoluteSize
                local x = Util.Clamp(startPos.X + delta.X, scaled.X / 2 - 40, viewport.X - scaled.X / 2 + 40)
                local y = Util.Clamp(startPos.Y + delta.Y, scaled.Y / 2 - 40, viewport.Y - scaled.Y / 2 + 40)
                main.Position = UDim2.fromOffset(x + scaled.X / 2, y + scaled.Y / 2)
            end)
            if releaseConn then releaseConn:Disconnect() end
            releaseConn = UserInputService.InputEnded:Connect(function(ended)
                if ended.UserInputType == Enum.UserInputType.MouseButton1 or ended.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                    if moveConn then moveConn:Disconnect() moveConn = nil end
                    if releaseConn then releaseConn:Disconnect() releaseConn = nil end
                end
            end)
        end)
    end

    makeDraggable(brand)
    makeDraggable(topbar)

    if options.Resizable ~= false then
        local resizing = false
        local moveConn, releaseConn
        grip.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            resizing = true
            local startMouse = Vector2.new(input.Position.X, input.Position.Y)
            local startSize = main.AbsoluteSize
            if moveConn then moveConn:Disconnect() end
            moveConn = UserInputService.InputChanged:Connect(function(changed)
                if not resizing then return end
                if changed.UserInputType ~= Enum.UserInputType.MouseMovement and changed.UserInputType ~= Enum.UserInputType.Touch then return end
                local delta = Vector2.new(changed.Position.X, changed.Position.Y) - startMouse
                local width = Util.Clamp(startSize.X + delta.X, 620, 1600)
                local height = Util.Clamp(startSize.Y + delta.Y, 380, 1000)
                main.Size = UDim2.fromOffset(width, height)
            end)
            if releaseConn then releaseConn:Disconnect() end
            releaseConn = UserInputService.InputEnded:Connect(function(ended)
                if ended.UserInputType == Enum.UserInputType.MouseButton1 or ended.UserInputType == Enum.UserInputType.Touch then
                    resizing = false
                    if moveConn then moveConn:Disconnect() moveConn = nil end
                    if releaseConn then releaseConn:Disconnect() releaseConn = nil end
                end
            end)
        end)
    end

    local searchClock = 0
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local now = os.clock()
        if now - searchClock < 0.08 then
            task.delay(0.1, function() self:ApplySearch(searchBox.Text) end)
            return
        end
        searchClock = now
        self:ApplySearch(searchBox.Text)
    end)

    self._maid:Connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if self._capturing then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if UserInputService:GetFocusedTextBox() then return end

        for _, component in ipairs(XenonUI._keybindComponents) do
            if component._getKey and component._getKey() == input.KeyCode then
                component:_fire()
            end
        end

        if self.ToggleKey and input.KeyCode == self.ToggleKey then
            self:Toggle()
        end
    end)

    ---------------------------------------------------------------- api
    self.Root = root
    self.Main = main
    self.Backdrop = backdrop
    self.TabScroll = tabScroll
    self.Pages = pages
    self.PageTitle = pageTitle
    self.PageDesc = pageDesc
    self.Scroll = scroll

    function self:AddSidebarLabel(text, order)
        local label = Util.New("TextLabel", {
            Name = "SidebarLabel",
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Text = string.upper(text or ""),
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = order or 0,
            ZIndex = 14,
        })
        Theme:Register(label, "TextColor3", "Muted")
        Util.New("UIPadding", { PaddingLeft = UDim.new(0, 6) }).Parent = label
        label.Parent = tabScroll
        return label
    end

    function self:AddTab(tabOptions)
        tabOptions = tabOptions or {}
        local tab = setmetatable({}, Tab)
        tab.Window = self
        tab.Sections = {}
        tab.Columns = {}
        tab.Name = tabOptions.Title or "Tab"

        local button = Util.New("TextButton", {
            Name = "TabButton",
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Theme:Get("Row"),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = tabOptions.Order or (#self.Tabs + 1),
            ZIndex = 14,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 10) }).Parent = button

        local indicator = Util.New("Frame", {
            Name = "Indicator",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromOffset(0, 18),
            Size = UDim2.fromOffset(3, 0),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 15,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 2) }).Parent = indicator
        Theme:Register(indicator, "BackgroundColor3", "Accent")
        indicator.Parent = button

        local glyph = Icons.Build(tabOptions.Icon or "layers", 17, "Muted", 0.72)
        glyph.Position = UDim2.fromOffset(12, 9)
        glyph.ZIndex = 15
        glyph.Parent = button

        local label = Util.New("TextLabel", {
            Name = "Title",
            Position = UDim2.fromOffset(38, 0),
            Size = UDim2.new(1, -80, 1, 0),
            BackgroundTransparency = 1,
            Text = tabOptions.Title or "Tab",
            TextSize = 12.5,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 15,
        })
        Theme:Register(label, "TextColor3", "SubText")
        label.Parent = button

        local badge = Util.New("TextLabel", {
            Name = "Badge",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 0, 16),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.82,
            Text = "",
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            Visible = false,
            ZIndex = 15,
        })
        Util.New("UICorner", { CornerRadius = UDim.new(0, 5) }).Parent = badge
        Util.New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }).Parent = badge
        Theme:Register(badge, "BackgroundColor3", "Accent")
        Theme:Register(badge, "TextColor3", "Accent")
        badge.Parent = button

        button.Parent = tabScroll
        tab.Button = { Button = button, Indicator = indicator, Icon = glyph, Title = label, Badge = badge }

        local page = Util.New("Frame", {
            Name = "Page",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Visible = false,
            LayoutOrder = tabOptions.Order or #self.Tabs + 1,
            ZIndex = 14,
        })
        local pageLayout = Util.New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 14),
        })
        pageLayout.Parent = page
        page.Parent = pages

        tab.Page = page
        tab:BuildColumns(self.Columns)
        tab.Desc = tabOptions.Desc or ""

        button.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
        button.MouseEnter:Connect(function()
            if self.Selected == tab then return end
            Util.Tween(button, T_FAST, { BackgroundTransparency = 0.6, BackgroundColor3 = Theme:Get("RowHover") })
        end)
        button.MouseLeave:Connect(function()
            if self.Selected == tab then return end
            Util.Tween(button, T_FAST, { BackgroundTransparency = 1 })
        end)

        self.Tabs[#self.Tabs + 1] = tab
        if not self.Selected or self.Selected._builtin then
            self:SelectTab(tab)
        end
        return tab
    end

    function self:SelectTab(tab)
        if self.Selected == tab then return end
        if self.Selected then
            local previous = self.Selected
            previous.Page.Visible = false
            Util.Tween(previous.Button.Button, T_FAST, { BackgroundTransparency = 1 })
            Util.Tween(previous.Button.Indicator, T_MED, { Size = UDim2.fromOffset(3, 0) })
            Theme:Register(previous.Button.Title, "TextColor3", "SubText")
            previous.Button.Title.TextColor3 = Theme:Get("SubText")
            tintIcon(previous.Button.Icon, "Muted")
        end
        self.Selected = tab
        tab.Page.Visible = true
        Util.Tween(tab.Button.Button, T_FAST, { BackgroundTransparency = 0.35, BackgroundColor3 = Theme:Get("RowHover") })
        Util.Tween(tab.Button.Indicator, T_MED, { Size = UDim2.fromOffset(3, 20) })
        Theme:Register(tab.Button.Title, "TextColor3", "Text")
        tab.Button.Title.TextColor3 = Theme:Get("Text")
        tintIcon(tab.Button.Icon, "Accent")
        pageTitle.Text = tab.Name
        pageDesc.Text = tab.Desc or ""
        scroll.CanvasPosition = Vector2.new(0, 0)
    end

    function self:ApplySearch(text)
        text = string.lower(text or "")
        for _, section in ipairs(self._sections) do
            local any = false
            for _, item in ipairs(section._items) do
                local match = text == "" or string.find(item._searchText or "", text, 1, true) ~= nil
                if item.Row then item.Row.Visible = match end
                if match then any = true end
            end
            if section.Outer then
                section.Outer.Visible = any or text == ""
            end
            if any and text ~= "" then
                section:SetOpen(true)
            end
        end
    end

    function self:SetColumns(count)
        count = math.max(1, math.min(3, math.floor(count or 1)))
        self.Columns = count
        for _, tab in ipairs(self.Tabs) do
            local sections = {}
            for _, columnFrame in ipairs(tab.Columns) do
                for _, child in ipairs(columnFrame:GetChildren()) do
                    if child:IsA("Frame") then
                        sections[#sections + 1] = child
                        child.Parent = nil
                    end
                end
                columnFrame:Destroy()
            end
            tab.Columns = {}
            tab:BuildColumns(count)
            for index, sectionFrame in ipairs(sections) do
                local target = tab.Columns[((index - 1) % count) + 1]
                target._sectionCount = (target._sectionCount or 0) + 1
                sectionFrame.Parent = target
            end
        end
    end

    function self:SetScale(scale)
        self.Scale = Util.Clamp(tonumber(scale) or 1, 0.7, 1.4)
        Util.Tween(uiScale, T_MED, { Scale = self.Scale })
    end

    function self:SetToggleKey(key)
        self.ToggleKey = key
        self:UpdateFooter()
    end

    function self:UpdateFooter()
        footer.Text = string.format("%s   |   %s", self.ToggleKey and self.ToggleKey.Name or "None", "v" .. XenonUI._version)
    end

    function self:SetOpen(state)
        state = state and true or false
        if self._open == state then return end
        self._open = state
        pill.Visible = not state

        if state then
            gui.Enabled = true
            main.Visible = true
            self.UIScale.Scale = self.Scale * 0.94
            Util.Tween(self.UIScale, T_SPRING, { Scale = self.Scale })
            Util.Tween(backdrop, T_MED, { BackgroundTransparency = options.BackdropTransparency or 0.45 })
            pcall(function()
                UserInputService.MouseIconEnabled = true
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end)
        else
            Util.Tween(self.UIScale, T_MED, { Scale = self.Scale * 0.94 })
            Util.Tween(backdrop, T_FAST, { BackgroundTransparency = 1 })
            task.delay(0.24, function()
                if not self._open then
                    gui.Enabled = false
                end
            end)
        end
    end

    function self:Toggle()
        self:SetOpen(not self._open)
    end

    function self:Notify(notifyOptions)
        return XenonUI:Notify(notifyOptions)
    end

    function self:SetFlagValue(flag, value)
        self._flagValues[flag] = value
    end

    function self:SaveConfig(name)
        name = tostring(name or "default")
        if Config.Save(self, name) then
            XenonUI:Success("Config", "Saved: " .. name, 2.5)
            return true
        end
        return false
    end

    function self:LoadConfig(name)
        name = tostring(name or "default")
        if Config.Load(self, name) then
            XenonUI:Success("Config", "Loaded: " .. name, 2.5)
            return true
        end
        XenonUI:Warn("Config", "Not found: " .. name, 3)
        return false
    end

    function self:ListConfigs()
        local names = Config.List()
        for name in pairs(self._memoryConfigs) do
            local found = false
            for _, existing in ipairs(names) do
                if existing == name then found = true break end
            end
            if not found then names[#names + 1] = name end
        end
        table.sort(names)
        return names
    end

    function self:DeleteConfig(name)
        Config.Delete(self, name)
    end

    function self:Destroy()
        self._maid:Clean()
        if gui then gui:Destroy() end
        if launcher then launcher:Destroy() end
        XenonUI._keybindComponents = {}
        XenonUI._rainbowPickers = {}
        XenonUI._window = nil
        XenonUI._rootGui = nil
    end

    XenonUI._window = self
    self:UpdateFooter()

    if options.SettingsTab ~= false then
        local settingsTab = XenonUI:BuildSettingsTab(self, options)
        settingsTab._builtin = true
    end

    self:SetOpen(options.StartOpen ~= false)
    return self
end

--------------------------------------------------------------------------------
-- Tab columns
--------------------------------------------------------------------------------
function Tab:BuildColumns(count)
    for _, existing in ipairs(self.Columns) do
        existing:Destroy()
    end
    self.Columns = {}
    for index = 1, count do
        local columnFrame = Util.New("Frame", {
            Name = "Column" .. index,
            Size = UDim2.new(1 / count, -((count - 1) * 14) / count, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = index,
            ZIndex = 14,
        })
        local columnLayout = Util.New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 14),
        })
        columnLayout.Parent = columnFrame
        columnFrame.Layout = columnLayout
        columnFrame.Parent = self.Page
        self.Columns[index] = columnFrame
    end
end

--------------------------------------------------------------------------------
-- Built-in settings tab
--------------------------------------------------------------------------------
function XenonUI:BuildSettingsTab(window, options)
    local tab = window:AddTab({
        Title = options.SettingsTabTitle or "Settings",
        Icon = "settings",
        Desc = "Appearance, input and configuration",
        Order = 999,
    })

    local appearance = tab:AddSection({ Title = "Appearance", Icon = "palette" })
    appearance:AddDropdown({
        Title = "Theme",
        Desc = "System follows the client theme",
        Values = { "Dark", "Light", "System" },
        Default = Theme.Mode,
        Flag = "ui.theme",
        Callback = function(value)
            Theme:SetMode(value)
            XenonUI:Info("Theme", "Mode: " .. tostring(value), 2)
        end,
    })
    appearance:AddColorPicker({
        Title = "Accent",
        Desc = "Primary interface colour",
        Default = Theme.Accent,
        Flag = "ui.accent",
        Presets = {
            Color3.fromRGB(140, 118, 255),
            Color3.fromRGB(88, 168, 255),
            Color3.fromRGB(64, 214, 153),
            Color3.fromRGB(255, 176, 74),
            Color3.fromRGB(255, 96, 120),
            Color3.fromRGB(255, 255, 255),
        },
        Callback = function(color)
            Theme:SetAccent(color)
        end,
    })
    appearance:AddToggle({
        Title = "Rainbow accent",
        Desc = "Cycles the accent colour",
        Default = Theme.Rainbow,
        Flag = "ui.rainbow",
        Callback = function(state)
            Theme.Rainbow = state
        end,
        Settings = function(sub)
            sub:AddSlider({
                Title = "Speed", Min = 0.05, Max = 1.5, Step = 0.05, Decimals = 2,
                Default = Theme.RainbowSpeed, Flag = "ui.rainbowSpeed",
                Callback = function(value) Theme.RainbowSpeed = value end,
            })
        end,
    })

    local glass = tab:AddSection({ Title = "Liquid Glass", Icon = "droplet" })
    glass:AddToggle({
        Title = "Glass surfaces",
        Desc = "Refraction highlights on panels",
        Default = Theme.Glass,
        Flag = "ui.glass",
        Callback = function(state) Glass.SetEnabled(state) end,
        Settings = function(sub)
            sub:AddSlider({
                Title = "Panel transparency", Min = 0.1, Max = 0.9, Step = 0.05, Decimals = 2,
                Default = Theme.GlassTransparency, Flag = "ui.glassAlpha",
                Callback = function(value)
                    Theme.GlassTransparency = value
                    Glass.SetEnabled(Theme.Glass)
                end,
            })
        end,
    })
    glass:AddSlider({
        Title = "World blur",
        Desc = "0 keeps the game sharp",
        Min = 0, Max = 24, Step = 1, Default = Theme.WorldBlur,
        Flag = "ui.worldBlur",
        Callback = function(value) Glass.SetWorldBlur(value) end,
    })
    glass:AddSlider({
        Title = "Interface scale",
        Min = 0.75, Max = 1.3, Step = 0.05, Decimals = 2,
        Default = window.Scale, Flag = "ui.scale",
        Callback = function(value) window:SetScale(value) end,
    })

    local notifications = tab:AddSection({ Title = "Notifications", Icon = "bell" })
    notifications:AddDropdown({
        Title = "Corner",
        Values = { "BottomRight", "BottomLeft", "TopRight", "TopLeft", "BottomCenter", "TopCenter" },
        Default = Notify.Corner,
        Flag = "ui.notifyCorner",
        Callback = function(value) Notify:SetCorner(value) end,
    })
    notifications:AddSlider({
        Title = "Visible at once",
        Min = 1, Max = 8, Step = 1, Default = Notify.MaxVisible,
        Flag = "ui.notifyCount",
        Callback = function(value) Notify.MaxVisible = value end,
    })
    notifications:AddButton({
        Title = "Send test notification",
        Icon = "sparkles",
        RightText = "Test",
        Callback = function()
            XenonUI:Success("XenonUI", "Notifications are working.", 3)
        end,
    })
    notifications:AddButton({
        Title = "Clear all notifications",
        Icon = "trash",
        Callback = function()
            Notify:Clear()
        end,
    })

    local input = tab:AddSection({ Title = "Input", Icon = "keyboard" })
    input:AddKeybind({
        Title = "Menu toggle",
        Desc = "Shows or hides the interface",
        Default = window.ToggleKey,
        Flag = "ui.toggleKey",
        Callback = function(key)
            window:SetToggleKey(key)
        end,
    })
    input:AddDropdown({
        Title = "Columns",
        Desc = "Layout of every tab",
        Values = { "1", "2", "3" },
        Default = tostring(window.Columns),
        Flag = "ui.columns",
        Callback = function(value) window:SetColumns(tonumber(value) or 2) end,
    })

    local config = tab:AddSection({ Title = "Configuration", Icon = "save" })
    local configName = config:AddTextbox({
        Title = "Config name",
        Placeholder = "default",
        Default = "default",
        Flag = "ui.configName",
    })
    local configList = config:AddDropdown({
        Title = "Saved configs",
        Values = window:ListConfigs(),
        AllowNone = true,
        NoneText = "Empty",
    })
    config:AddButton({
        Title = "Save",
        Icon = "save",
        Callback = function()
            local name = configName:Get()
            if name == "" then
                XenonUI:Warn("Config", "Enter a name first.", 3)
                return
            end
            window:SaveConfig(name)
            configList:Refresh(window:ListConfigs(), true)
        end,
    })
    config:AddButton({
        Title = "Load",
        Icon = "refresh",
        Callback = function()
            local name = configList:Get()
            if not name then
                XenonUI:Warn("Config", "Select a config first.", 3)
                return
            end
            window:LoadConfig(name)
        end,
    })
    config:AddButton({
        Title = "Delete",
        Icon = "trash",
        Callback = function()
            local name = configList:Get()
            if not name then
                XenonUI:Warn("Config", "Select a config first.", 3)
                return
            end
            window:DeleteConfig(name)
            configList:Refresh(window:ListConfigs(), true)
            XenonUI:Info("Config", "Removed: " .. tostring(name), 2.5)
        end,
    })

    if options.AllowUnload ~= false then
        local danger = tab:AddSection({ Title = "Session", Icon = "power" })
        danger:AddButton({
            Title = "Unload interface",
            Desc = "Removes every XenonUI element",
            Icon = "close",
            RightText = "Unload",
            Callback = function()
                window:Destroy()
                Notify:Clear()
                XenonUI:Info("XenonUI", "Interface unloaded.", 2.5)
            end,
        })
    end

    return tab
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
function XenonUI:ResolveContainer()
    if XenonUI._container then return XenonUI._container end
    local container
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then container = result end
    end
    if not container then
        local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
        if ok and coreGui then container = coreGui end
    end
    if not container and LocalPlayer then
        local ok, playerGui = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 3) end)
        if ok and playerGui then container = playerGui end
    end
    XenonUI._container = container
    return container
end

function XenonUI:SetTheme(mode)
    Theme:SetMode(mode)
end

function XenonUI:SetAccent(color)
    Theme:SetAccent(color)
end

function XenonUI:SetWorldBlur(size)
    Glass.SetWorldBlur(size)
end

function XenonUI:SetNotificationCorner(corner)
    Notify:SetCorner(corner)
end

function XenonUI:Destroy()
    if XenonUI._window then
        XenonUI._window:Destroy()
    end
    Notify:Clear()
    if Notify._gui then Notify._gui:Destroy() Notify._gui = nil end
    if Tooltip._gui then Tooltip._gui:Destroy() Tooltip._gui = nil end
    local blur = Lighting:FindFirstChild("XenonUIGlassBlur")
    if blur then blur:Destroy() end
    Scheduler:Stop()
    XenonUI._keybindComponents = {}
    XenonUI._rainbowPickers = {}
end

return XenonUI
