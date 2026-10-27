# VantaUI 3.0

A self-contained Roblox Luau interface library for **five independent, draggable columns** with inline settings. The dark-violet presentation uses flat rows, thin borders, readable BuilderSans typography and genuine Lucide sprite icons — without a full-window wrapper or a vertical selected-state strip.

`Example.client.lua` contains the **complete library and a five-column demo in one LocalScript**. It needs no ModuleScript, asset upload, package manager or additional file.

## Highlights

- Five separate `CanvasGroup` panels; each can be dragged independently.
- **Local blur behind the columns only** — no fullscreen `BlurEffect`.
- Exact critically damped drag motion with distinct pickup, movement and release states; no spring overshoot.
- Flat 34 px rows, 46 px descriptive rows, 13 px labels and 42 px toggles.
- Inline settings push following rows down in the same column.
- 14 Roblox-hosted Lucide mappings, with BuilderSans UI fonts.
- Toggle, slider, dropdown, keybind, textbox, color picker, button, label, separator and notification APIs.
- Config flags, `GetFlag`, `SetFlag`, programmatic setters and automatic theme-color tracking.
- Complete cleanup of input/render connections, camera geometry and lighting effects.

## Local blur: what it does

VantaUI 3 uses a client-only projected Glass renderer instead of `Lighting.BlurEffect`:

- Each panel owns two thin Glass rectangles and four rounded-corner pieces.
- Those six parts are projected in front of the current camera and follow the panel's absolute position, size, rotation and drag scale in `RunService.PreRender`.
- A near-only `DepthOfFieldEffect` uses `FarIntensity = 0`, so the rest of the 3D viewport is not globally blurred.
- Hidden panels make their backdrop transparent. `Destroy()` removes all models and the post-effect.

### Roblox rendering limitations

This is a Glass/DepthOfField technique, not the unreleased native `UIBlur` API:

- A visible Glass blur generally requires **Roblox graphics quality 8 or higher**. Lower quality levels may show little or no blur.
- It blurs the **3D scene behind a panel**, not other ordinary `ScreenGui` elements drawn over that scene.
- Glass can pick up environment reflections. VantaUI uses 98% transparency and a neutral color to keep this subtle.
- Set `LocalBlur = false` to disable the projected geometry and DepthOfField effect entirely; the interface remains fully usable.

No Studio rendering claim is made by the command-line tests: final Glass appearance and sprite loading should still be checked in Roblox Studio Play mode on the target graphics settings.

## Fastest start — one LocalScript

1. Open the complete [`Example.client.lua`](Example.client.lua).
2. Copy the **entire file**, including the embedded library and Lucide notices.
3. In Roblox Studio, create a **LocalScript** in `StarterPlayer > StarterPlayerScripts`.
4. Paste and use **Play / Play Solo**, not the server-only Run mode.

The demo creates Combat, Movement, Visuals, Player and Miscellaneous columns. It includes working inline settings, controls, notifications and drag interactions.

A minimal standalone setup looks like this when the library is already available:

```lua
local VantaUI = require(game.ReplicatedStorage.VantaUI)

local window = VantaUI:CreateWindow({
    Name = "VantaUI",
    Accent = Color3.fromRGB(145, 116, 222),
    ColumnWidth = 210,
    ColumnHeight = 500,
    ColumnGap = 10,
    ColumnY = 64,
    LocalBlur = true,
    ToggleKey = Enum.KeyCode.RightShift,
})

local combat = window:AddCategory({ Title = "Combat", Icon = "combat" })
local movement = window:AddCategory({ Title = "Movement", Icon = "movement" })
local visuals = window:AddCategory({ Title = "Visuals", Icon = "visuals" })
local player = window:AddCategory({ Title = "Player", Icon = "player" })
local misc = window:AddCategory({ Title = "Miscellaneous", Icon = "misc" })

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
    settings:AddKeybind({
        Title = "Toggle bind",
        Default = Enum.KeyCode.R,
        Callback = function()
            aura:Set(not aura:Get())
        end,
    })
end)
```

`Blur = 10` from VantaUI 2 is accepted only as a backward-compatible on/off option. It no longer creates a fullscreen blur; new code should use `LocalBlur = true` or `false`.

## Module installation

If you prefer separate files:

1. Create a **ModuleScript** named `VantaUI` in `ReplicatedStorage` and paste `VantaUI.lua`.
2. Create a **LocalScript** in `StarterPlayerScripts`.
3. Require the module and call `CreateWindow` as above.

To run the library from a GitHub raw URL, replace the commit below with the revision you intentionally want to pin:

```lua
local REVISION = "PIN_A_COMMIT_SHA"
local VantaUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/wrthdev123/UI/" .. REVISION .. "/VantaUI.lua"
))()
```

HTTP loading requires an environment that permits `loadstring` and `HttpGet`. Copying the source into Studio needs neither.

## Window API

### `VantaUI:CreateWindow(options)`

Important options:

| Option | Default | Purpose |
| --- | --- | --- |
| `Parent` | `LocalPlayer.PlayerGui` | Custom GUI parent, useful for tests |
| `Name` | `VantaUI` | ScreenGui name |
| `Accent` | `Color3.fromRGB(145, 116, 222)` | Main violet accent |
| `Font` | `Enum.Font.BuilderSans` | Body font |
| `MediumFont` | `Enum.Font.BuilderSansMedium` | Labels and titles |
| `BoldFont` | `Enum.Font.BuilderSansBold` | Emphasis |
| `ColumnWidth` | `210` | Independent panel width |
| `ColumnHeight` | `500` | Maximum column height; columns grow with content |
| `ColumnGap` | `10` | Horizontal spacing |
| `ColumnY` | `64` | Initial Y position |
| `LocalBlur` | `true` | Panel-local Glass/DepthOfField backdrop |
| `ToggleKey` | `RightShift` | Visibility key; `false` disables it |
| `Visible` | `true` | Initial visibility |
| `ReplaceExisting` | `true` | Replace a same-named ScreenGui |

Methods:

```lua
window:Toggle()
window:SetVisible(boolean, instant?)
window:SetAccent(color3)
window:Notify({ Title = "Saved", Content = "Done", Type = "Success" })
window:GetFlag("combat.range")
window:SetFlag("combat.range", 6)
window:Destroy()
```

### `window:AddCategory(options)`

```lua
local category = window:AddCategory({
    Title = "Combat",
    Icon = "combat",       -- Optional Lucide alias
    Visible = true,
})
```

Methods: `SetTitle`, `SetVisible`, `SetPosition`, `GetRow`. Panels are direct children of the ScreenGui, so there is no invisible shared-window hitbox.

### `category:AddToggle(options)`

```lua
local toggle = category:AddToggle({
    Title = "Auto Sprint",
    Description = "Optional second line",
    Icon = "movement", -- Optional Lucide icon
    Default = false,
    Flag = "movement.sprint",
    RightText = "Optional hint",
    Callback = function(value) end,
})

toggle:Set(true)              -- Animated, invokes Callback
toggle:SetSilent(true)        -- No Callback
toggle:Get()
toggle:OpenSettings(true)     -- Only if settings exist
toggle:SetActive(true)        -- Row highlight without changing its value
```

### Inline settings

Every component has `AddSettings(function(settings) ... end)`. A toggle may instead pass `Settings = function(settings) ... end` in its options. The gear rotates and the settings body expands inside the same column.

```lua
aura:AddSettings(function(settings)
    settings:AddToggle({ Title = "Auto block", Default = false })
    settings:AddDropdown({ Title = "Mode", Values = { "Single", "Multi" } })
    settings:AddSlider({ Title = "Range", Min = 1, Max = 12, Default = 4 })
    settings:AddKeybind({ Title = "Bind", Default = Enum.KeyCode.R })
end)
```

Settings support toggle, slider, dropdown, keybind, textbox, color picker and button controls.

### Other controls

```lua
category:AddSlider({
    Title = "Walk Speed", Min = 8, Max = 32, Step = 1,
    Default = 16, Suffix = " studs", Flag = "movement.speed",
    Callback = function(value) end,
})

category:AddDropdown({
    Title = "Camera mode",
    Values = { "First person", "Third person", "Orbit" },
    Default = "Third person",
    Flag = "camera.mode",
    Callback = function(value) end,
})

category:AddKeybind({
    Title = "Panic key",
    Default = Enum.KeyCode.X,
    Flag = "panic",
    Callback = function(key) end,
})

category:AddTextbox({
    Title = "Display name",
    Placeholder = "Enter a name...",
    Default = "Player",
    Numeric = false,
    ClearOnFocus = true,
    Flag = "player.name",
    Callback = function(text, enterPressed) end,
})

category:AddColorPicker({
    Title = "Accent",
    Default = Color3.fromRGB(145, 116, 222),
    Flag = "ui.color",
    Callback = function(color) end,
})

category:AddButton({
    Title = "Save",
    Description = "Optional description",
    RightText = "Run",
    Callback = function() end,
})

category:AddLabel({ Title = "Label", Description = "Optional description" })
category:AddSeparator()
```

## Lucide icons

Available aliases:

| Alias | Meaning |
| --- | --- |
| `combat` | Swords |
| `movement` | Person standing |
| `visuals` | Eye |
| `player` | User round |
| `misc` | Shapes |
| `settings` | Settings |
| `search` | Search |
| `dropdown` | Chevron down |
| `check` | Check |
| `keybind` | Keyboard |
| `close` | X |
| `color` | Palette |
| `cursor` | Mouse pointer 2 |
| `question` | Circle question mark |

Icons use Roblox-hosted Lucide sprite sheets and sprite offsets. They are not hand-drawn approximations. Color defaults are tracked per window, so `SetAccent` recolors only the elements intended to follow the accent.

## Motion and lifecycle

- Drag pickup uses a subtle `1.006` scale, quiet border emphasis and background response.
- Position uses an exact critically damped spring: 34 Hz while dragging and 26 Hz after release, integrated in `PreRender` with a capped timestep.
- Pointer input changes only the spring target; it never snaps the panel directly.
- Panel visibility uses opacity only, without scale-in or staggered entrances.
- Rows do not create ripple objects, press-scale containers or toggle pulses.
- `Destroy()` disconnects listeners and removes notifications, Glass models and DepthOfField effects.

## Validation

The revision is checked with the official Roblox Luau compiler/interpreter and API-derived strict mocks:

- module and exact standalone source compilation;
- five-category standalone construction;
- six local Glass parts per panel, near-only DepthOfField settings and no `BlurEffect`;
- backdrop projection updates and hide/show cleanup;
- critically damped drag behavior without input snapping or overshoot;
- inline settings height changes;
- toggles, sliders, dropdowns, keybinds, textboxes, color pickers, buttons and flags;
- final destruction cleanup.

Mocks do **not** validate real Roblox Glass rendering, image loading or physical input. Use Studio Play mode for that final platform check.

## Repository files

- `VantaUI.lua` — distributable ModuleScript source.
- `Example.client.lua` — complete standalone LocalScript with embedded library and demo.
- `README.md` — usage and API documentation.
- `THIRD_PARTY_NOTICES.md` — Lucide attribution/licenses and the local-blur implementation reference.
