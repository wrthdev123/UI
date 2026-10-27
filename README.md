# VantaUI 2.2

UI-библиотека для Roblox на **Luau**, собранная по мотивам присланных референсов. Каждая категория — **отдельная независимая панель**, а не колонка внутри общего окна. Панели можно перетаскивать за заголовки: pickup, движение и release объединены в непрерывную spring-анимацию. Настройки раскрываются прямо внутри своей панели и плавно сдвигают остальные элементы. В версии 2.2 увеличена типографика, добавлены полупрозрачный glass-фон, заметный blur и настоящие Lucide-иконки.

## Файлы

- [`VantaUI.lua`](VantaUI.lua) — самодостаточная библиотека для подключения через `require` как **ModuleScript**.
- [`Example.client.lua`](Example.client.lua) — **полностью автономный LocalScript**: библиотека уже встроена в файл, поэтому для демо нужен только он.
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — attribution и лицензии Lucide / lucide-roblox. Те же notices встроены в оба Lua-файла, поэтому они сохраняются при копировании одного standalone-скрипта.

## Быстрый запуск демо

1. В Roblox Studio создайте `LocalScript` в `StarterPlayer > StarterPlayerScripts`.
2. Вставьте в него **весь** `Example.client.lua`. Отдельно копировать `VantaUI.lua` и создавать `ModuleScript` для этого варианта не нужно.
3. Нажмите **Play / Play Solo**, а не серверный режим **Run**.
4. После появления интерфейса используйте `Right Shift`, чтобы скрыть или снова показать его.

В `Output` должны появиться сообщения `[VantaUI] Example is starting...` и `[VantaUI] Example ready...`.

## Подключение библиотеки к своему проекту

1. Создайте `ModuleScript` в `ReplicatedStorage`, назовите его `VantaUI` и вставьте содержимое `VantaUI.lua`.
2. Подключите модуль из своего LocalScript-а через `require`, как показано ниже.

Библиотека использует только обычные Roblox API. Не нужны executor-функции, HTTP-запросы или дополнительные зависимости. Lucide-спрайты загружаются через уже встроенные Roblox-hosted `rbxassetid://` и координаты `ImageRectOffset`; внешние SVG-URL не используются.

## Минимальный модульный пример

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VantaUI = require(ReplicatedStorage:WaitForChild("VantaUI"))

local window = VantaUI:CreateWindow({
    Name = "VantaUI",
    Accent = Color3.fromRGB(145, 116, 222),
    ColumnWidth = 210,
    ColumnHeight = 500,
    ColumnY = 64,
    ToggleKey = Enum.KeyCode.RightShift,
    Blur = 10,
})

local combat = window:AddCategory({
    Title = "Combat",
    Icon = "combat",
})

local aura = combat:AddToggle({
    Title = "Kill Aura",
    Description = "Use the gear for inline settings",
    Icon = "combat",
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

- Пять независимых панелей без общего окна, backdrop или затемняющего градиента.
- Читаемая тёмно-фиолетовая тема, Builder Sans, основной текст 13 px, увеличенные строки и контролы.
- Спокойный selected-state без сплошной яркой заливки и без вертикальной полоски слева.
- Настоящие Lucide-иконки категорий, компонентов и настроек через Roblox-hosted 48 px sprite sheets.
- Полупрозрачные панели и animated `BlurEffect`; в примере `Blur = 10`.
- Перетаскивание каждой панели за её заголовок мышью или касанием.
- Pickup scale/highlight, инерционное движение на `RunService.Heartbeat` и плавное доведение позиции после release.
- Автоматическая высота панели и вертикальная прокрутка после достижения `ColumnHeight`.
- Stagger-анимация показа и скрытия всех панелей через `Right Shift`.
- Hover, press, ripple, toggle pulse, spring-движение переключателей и slider-ручек.
- Inline settings с одновременной анимацией высоты, прозрачности и положения содержимого.
- Dropdown также раскрывается внутри своей панели.
- Уведомления с enter/exit-анимацией и индикатором времени.
- Flags для чтения и изменения значений из другого кода.
- Очистка соединений, GUI и blur через `window:Destroy()`.


## Glass, blur и перетаскивание

Каждая категория остаётся отдельным top-level `CanvasGroup`. Её фон частично прозрачен, поэтому размытый мир виден сквозь панель. `BlurEffect` в Roblox размывает 3D-мир глобально, а не создаёт отдельный render target для каждого столбца; эффект автоматически удаляется при скрытии интерфейса и `Destroy()`.

Во время drag изменяется только целевая позиция. Фактическая позиция интегрируется на каждом `Heartbeat` с сохранением скорости между кадрами. Поэтому резкая смена направления не даёт скачка, а после отпускания панель продолжает движение и мягко останавливается. При захвате добавляются небольшие scale и подсветка границы; при отпускании они возвращаются к обычному состоянию.

## Лицензии иконок

Использованы sprite mappings из [lucide-roblox](https://github.com/latte-soft/lucide-roblox) (MIT, Latte Softworks) и иконки [Lucide](https://lucide.dev) (ISC). Полные notices находятся в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) и встроены непосредственно в `VantaUI.lua` / `Example.client.lua`.

## API

### `VantaUI:CreateWindow(options)`

| Параметр | Тип / значение по умолчанию | Назначение |
|---|---|---|
| `Name` | `"VantaUI"` | Имя ScreenGui |
| `Accent` | `Color3.fromRGB(145, 116, 222)` | Акцентный цвет |
| `Theme` | `nil` | Таблица переопределений цветов |
| `ColumnWidth` | `210` | Ширина новых панелей |
| `ColumnHeight` | `500` | Максимальная высота панели |
| `ColumnGap` | `10` | Расстояние между панелями |
| `ColumnY` | `64` | Вертикальная позиция автоматического ряда |
| `ToggleKey` | `RightShift` | Клавиша видимости; `false` отключает |
| `Blur` | `8` | Blur мира от `0` до `24`; `0` отключает |
| `Visible` | `true` | Показать панели после создания |
| `ReplaceExisting` | `true` | Удалить предыдущий ScreenGui с тем же именем |
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
    Icon = "movement", -- необязательная Lucide-иконка
    Width = 210,      -- необязательная ширина
    Height = 500,     -- необязательная максимальная высота
    -- Position = UDim2.fromOffset(80, 64),
})

category:SetTitle("Player Movement")
category:SetPosition(UDim2.fromOffset(100, 80))
category:SetVisible(false)
```

Доступные имена иконок: `combat`, `sword`, `movement`, `speed`, `player`, `user`, `visuals`, `render`, `eye`, `settings`, `gear`, `utility`, `sliders`, `camera`, `color`, `palette`, `world`, `misc`/`grid`.

### Общие параметры компонентов

Большинство компонентов принимает:

- `Title` (или `Name`), `Description`, `Icon`, `Flag`;
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
    Default = Color3.fromRGB(145, 116, 222),
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
        Column = Color3.fromRGB(17, 24, 24),
        Surface = Color3.fromRGB(27, 37, 37),
        Text = Color3.fromRGB(240, 255, 250),
    },
})
```

Доступные ключи: `Column`, `Header`, `Surface`, `SurfaceHover`, `SurfaceActive`, `Inset`, `Track`, `Stroke`, `Text`, `SubText`, `Muted`, `White`, `Success`, `Warning`, `Danger`, `Info`, `Accent`, `AccentDark`, `AccentSoft`, `AccentText`.
