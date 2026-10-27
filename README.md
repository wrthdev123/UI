# VantaUI

Колоночная UI-библиотека для Roblox на **Luau**, собранная по мотивам присланных референсов. Все настройки раскрываются **прямо внутри своей колонки** и плавно сдвигают остальные элементы — без отдельных окон и внешних изображений.

## Файлы

- [`VantaUI.lua`](VantaUI.lua) — самодостаточная библиотека, оформляется как **ModuleScript**.
- [`Example.client.lua`](Example.client.lua) — готовый **LocalScript** с пятью категориями и всеми основными компонентами.

## Установка

1. В Roblox Studio создайте `ModuleScript` в `ReplicatedStorage`, назовите его `VantaUI` и вставьте содержимое `VantaUI.lua`.
2. Создайте `LocalScript` в `StarterPlayer > StarterPlayerScripts` и вставьте содержимое `Example.client.lua`.
3. Запустите игру. `Right Shift` скрывает и снова показывает интерфейс.

Библиотека использует только обычные Roblox API. Не нужны executor-функции, HTTP-запросы, asset ID или дополнительные зависимости.

## Минимальный пример

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VantaUI = require(ReplicatedStorage:WaitForChild("VantaUI"))

local window = VantaUI:CreateWindow({
    Title = "VANTA",
    Subtitle = "Right Shift  •  inline settings",
    Accent = Color3.fromRGB(237, 45, 72),
    ToggleKey = Enum.KeyCode.RightShift,
    Blur = 8,
})

local combat = window:AddCategory({
    Title = "Combat",
    Icon = "C",
})

local aura = combat:AddToggle({
    Title = "Kill Aura",
    Description = "Click the chevron for settings",
    Default = true,
    Flag = "combat.aura",
    Callback = function(enabled)
        print("Enabled:", enabled)
    end,
})

aura:AddSettings(function(settings)
    settings:AddDropdown({
        Title = "Mode",
        Values = { "Single", "Multi", "Priority" },
        Default = "Priority",
    })

    settings:AddSlider({
        Title = "Range",
        Min = 1,
        Max = 12,
        Step = 0.25,
        Default = 4.5,
        Suffix = " m",
    })
end)
```

## Что реализовано

- Независимые колонки с вертикальной прокруткой и горизонтальной прокруткой всего набора на узких экранах.
- Плавное открытие и закрытие окна, затемнение фона и необязательный blur.
- Перетаскивание окна мышью или касанием.
- Hover, press, ripple, toggle pulse, spring-движение переключателей и slider-ручек.
- Inline settings с одновременной анимацией высоты, прозрачности и положения содержимого.
- Dropdown также раскрывается внутри колонки.
- Поиск по элементам всех категорий.
- Уведомления с enter/exit-анимацией и индикатором времени.
- Flags для чтения и изменения значений из другого кода.
- Очистка соединений, GUI и blur через `window:Destroy()`.

## API

### `VantaUI:CreateWindow(options)`

| Параметр | Тип / значение по умолчанию | Назначение |
|---|---|---|
| `Title` | `"Vanta UI"` | Заголовок окна |
| `Subtitle` | `"Column interface"` | Подзаголовок |
| `Logo` | `"V"` | Короткий текст логотипа |
| `Accent` | `Color3.fromRGB(237, 45, 72)` | Акцентный цвет |
| `Theme` | `nil` | Таблица переопределений цветов |
| `Size` | `Vector2.new(1140, 600)` | Максимальный размер окна |
| `ColumnWidth` | `214` | Ширина новых колонок |
| `ToggleKey` | `RightShift` | Клавиша видимости; `false` отключает |
| `Blur` | `0` | Сила blur от `0` до `24` |
| `Search` | `true` | Строка поиска |
| `Visible` | `true` | Показать окно после создания |
| `Parent` | `PlayerGui` | Другой контейнер для ScreenGui |

Методы окна:

```lua
window:SetVisible(true)       -- второй аргумент true отключает анимацию
window:Toggle()
window:Notify({
    Title = "Saved",
    Content = "Configuration saved",
    Type = "Success",        -- Info | Success | Warning | Danger
    Duration = 4,
})
local value = window:GetFlag("combat.aura")
window:SetFlag("combat.aura", false)
window:Destroy()
```

### Категории

```lua
local category = window:AddCategory({
    Title = "Movement",
    Icon = "M",       -- необязательный короткий glyph
    Width = 214,      -- необязательное переопределение
})

category:SetTitle("Player Movement")
category:SetVisible(false)
```

### Общие параметры компонентов

Большинство компонентов принимает:

- `Title` (или `Name`), `Description`, `Flag`;
- `Default` и `Callback`, если применимо;
- `Settings = function(settings) ... end` для inline-панели сразу при создании.

Компоненты возвращают объект с `Get()`, `Set(value)`, `SetSilent(value)` там, где есть значение, а также `SetVisible()`, `SetTitle()`, `AddSettings()`, `OpenSettings()` и `Destroy()`.

### Toggle

```lua
local toggle = category:AddToggle({
    Title = "Auto Sprint",
    Default = true,
    Callback = function(enabled) print(enabled) end,
})
toggle:Set(false)          -- с Callback
toggle:SetSilent(true)     -- без Callback
```

### Slider

```lua
local slider = category:AddSlider({
    Title = "Speed",
    Min = 0,
    Max = 100,
    Step = 0.5,
    Default = 16,
    Suffix = "%",
    -- Format = function(value) return string.format("%.1f", value) end,
    Callback = function(value) print(value) end,
})
```

### Dropdown

```lua
local dropdown = category:AddDropdown({
    Title = "Mode",
    Values = { "Smooth", "Instant" },
    Default = "Smooth",
    Callback = function(value) print(value) end,
})
dropdown:Refresh({ "One", "Two", "Three" }, true)
```

### Keybind

```lua
category:AddKeybind({
    Title = "Toggle bind",
    Default = Enum.KeyCode.R,
    Changed = function(newKey) print("New bind:", newKey) end,
    Callback = function() print("Bind pressed") end,
})
```

При назначении: `Escape` отменяет выбор, `Backspace` очищает bind.

### Textbox

```lua
category:AddTextbox({
    Title = "Display name",
    Placeholder = "Enter a name...",
    Default = "",
    Callback = function(text, enterPressed)
        print(text, enterPressed)
    end,
})
```

### ColorPicker

```lua
category:AddColorPicker({
    Title = "Highlight",
    Default = Color3.fromRGB(237, 45, 72),
    Callback = function(color) print(color) end,
})
```

RGB-слайдеры цвета открываются внутри элемента.

### Button, Label, Separator

```lua
category:AddButton({
    Title = "Save config",
    RightText = "Save",
    Callback = function() print("Saved") end,
})
category:AddLabel({ Title = "Section", Description = "Description" })
category:AddSeparator()
```

## Цветовая тема

`Accent` автоматически создаёт производные оттенки. При необходимости можно переопределить отдельные цвета:

```lua
local window = VantaUI:CreateWindow({
    Accent = Color3.fromRGB(42, 211, 137),
    Theme = {
        Window = Color3.fromRGB(10, 15, 15),
        Column = Color3.fromRGB(13, 20, 20),
        Surface = Color3.fromRGB(20, 29, 29),
        Text = Color3.fromRGB(240, 255, 250),
    },
})
```

Доступные ключи: `Backdrop`, `Window`, `Column`, `Surface`, `SurfaceHover`, `SurfaceActive`, `Inset`, `Track`, `Stroke`, `Text`, `SubText`, `Muted`, `White`, `Success`, `Warning`, `Danger`, `Info`, `Accent`, `AccentDark`, `AccentSoft`.
