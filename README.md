# VantaUI 3.2

A self-contained Roblox Luau interface library for **five independent, draggable columns** with inline settings. The dark-violet presentation uses separated rows, thin borders, readable BuilderSans typography and genuine Lucide sprite icons — without a full-window wrapper or a vertical selected-state strip.

`Example.client.lua` contains the **complete library and a five-column demo in one LocalScript**. It needs no ModuleScript, asset upload, package manager or additional file.

## Highlights

- Five separate `CanvasGroup` panels; each can be dragged independently.
- **Local blur behind the columns only** — no fullscreen `BlurEffect`.
- Exact critically damped drag motion with distinct pickup, movement and release states; no spring overshoot.
- Larger 230 px columns, 36 px rows, 15 px headings and a 400 px default minimum column height.
- Separated rows with 6 px corners and panels with 8 px corners.
- Configurable `Parallax`, linked bouncing `Particles`, `Image` or `None` background modes.
- Full HSV color picker with a saturation/value pad, hue bar and hex readout.
- Compact 46 px sliders with drag glow and direct input response.
- Hover descriptions use 17 px bottom-screen text without a background card.
- Columns are clamped to the viewport during drag, programmatic movement and resize.
- Inline settings use 7 px spacing and push following rows down in the same column.
- Roblox-hosted Lucide mappings, with BuilderSans UI fonts.
- Toggle, slider, dropdown, keybind, textbox, color picker, button, label, separator and notification APIs.
- Config flags, `GetFlag`, `SetFlag` and programmatic setters.
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

## Configurable background

The decorative background sits behind the five panels and does not add fullscreen blur. The default mode is `Parallax`.

```lua
window:SetBackgroundMode("Particles")
window:SetBackground({
    Mode = "Particles",
    ParticleCount = 40,   -- 0–80
    ParticleSpeed = 42,   -- Pixels per second
    ParticleLinkDistance = 110,
    ParticleLinks = true,
})

window:SetBackground({
    Mode = "Parallax",
    ParallaxStrength = 32,
})

window:SetBackground({
    Mode = "Image",
    Image = "rbxassetid://123456",
    ImageTransparency = 0.35,
    ImageDim = 0.22,      -- Darkens only the image for readability
})

window:SetBackgroundMode("None")
local current = window:GetBackground()
```

- **Parallax:** visible geometric rings follow `GetMouseLocation` with damped depth and slow ambient drift.
- **Particles:** independent particles reflect from viewport edges and connect with distance-faded lines inside `ParticleLinkDistance`. Set `ParticleLinks = false` to disable links.
- **Image:** a user-supplied Roblox image uses `Crop` scaling and subtle pointer parallax. No image asset is uploaded by the library.
- **None:** disables the decorative layer while preserving the interface and panel-local blur.

The standalone Miscellaneous column includes a mode dropdown, particle-count slider and image-asset input.

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
    ColumnWidth = 230,
    ColumnHeight = 540,
    MinColumnHeight = 400,
    ColumnGap = 10,
    ColumnY = 64,
    LocalBlur = true,
    Background = {
        Mode = "Parallax",
        ParticleCount = 28,
        ParticleSpeed = 42,
        ParticleLinkDistance = 110,
        ParticleLinks = true,
        ParallaxStrength = 32,
        -- Image = "rbxassetid://YOUR_IMAGE_ID",
    },
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
| `ColumnWidth` | `230` | Independent panel width |
| `ColumnHeight` | `540` | Maximum column height |
| `MinColumnHeight` | `400` | Minimum column height; capped by `ColumnHeight` |
| `ColumnGap` | `10` | Horizontal spacing |
| `ColumnY` | `64` | Initial Y position |
| `LocalBlur` | `true` | Panel-local Glass/DepthOfField blur |
| `Background` | `{ Mode = "Parallax" }` | Decorative background configuration; `false` disables it |
| `ToggleKey` | `RightShift` | Visibility key; `false` disables it |
| `Visible` | `true` | Initial visibility |
| `ReplaceExisting` | `true` | Replace a same-named ScreenGui |

Methods:

```lua
window:Toggle()
window:SetVisible(boolean, instant?)
window:SetBackgroundMode("Particles")
window:SetBackground({ Mode = "Image", Image = "rbxassetid://123456" })
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
    MinHeight = 400, -- Optional per-category override
})
```

Methods: `SetTitle`, `SetVisible`, `SetPosition`, `GetRow`. Panels are direct children of the ScreenGui, so there is no invisible shared-window hitbox.

### `category:AddToggle(options)`

```lua
local toggle = category:AddToggle({
    Title = "Auto Sprint",
    Description = "Shown at the bottom on hover",
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

Every component has `AddSettings(function(settings) ... end)`. A toggle may instead pass `Settings = function(settings) ... end` in its options. The gear rotates and the settings body expands inside the same column. Nested rows use 7 px gaps and 6 px content padding.

```lua
aura:AddSettings(function(settings)
    settings:AddToggle({ Title = "Auto block", Default = false })
    settings:AddDropdown({ Title = "Mode", Values = { "Single", "Multi" } })
    settings:AddSlider({ Title = "Range", Min = 1, Max = 12, Default = 4 })
    settings:AddKeybind({ Title = "Bind", Default = Enum.KeyCode.R })
end)
```

Settings support toggle, slider, dropdown, keybind, textbox, color picker and button controls.

### Hover descriptions

For normal controls, `Description` no longer consumes a second line in the row. Hovering reveals centered 17 px text at the bottom of the screen with no background panel or border; a subtle text outline preserves readability. Leaving the row, hiding the window or destroying the control dismisses it. `AddLabel` is the exception and keeps its description inline.

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

Color pickers use a true HSV saturation/value surface and hue strip rather than RGB sliders. Notifications are compact cards with a small type-colored dot, without a vertical bar or progress line.

## Lucide icons

Available aliases:

| Alias group | Icons |
| --- | --- |
| Categories | `combat`, `movement`, `visuals`, `player`, `misc` |
| Common aliases | `sword`, `speed`, `user`, `render`, `eye`, `world`, `grid` |
| Controls | `settings`, `gear`, `utility`, `sliders`, `camera`, `color`, `palette` |
| Chevrons | `chevron-right`, `chevron-down` |

Icons use Roblox-hosted Lucide sprite sheets and sprite offsets. They are not hand-drawn approximations. Icons are rendered from Roblox-hosted sprite sheets with source tile offsets; VantaUI does not fetch SVG files.

## Motion and lifecycle

- Drag pickup uses a subtle `1.006` scale, quiet border emphasis and background response.
- Position uses an exact critically damped spring: 34 Hz while dragging and 26 Hz after release, integrated in `PreRender` with a capped timestep.
- Pointer input changes only the spring target; it never snaps the panel directly.
- Panel visibility combines opacity with a restrained 4 px critically damped rise; there is no scale-in or staggered entrance.
- Interaction transitions are short (0.12–0.22 seconds); inline panels use a 4 px settle.
- Overlapping tweens are cancelled per property, preventing hover and release animations from fighting each other.
- Hover descriptions and background modes crossfade instead of appearing abruptly.
- Drag targets and rendered panel positions are clamped inside an 8 px screen margin.
- Rows do not create ripple objects, press-scale containers or toggle pulses.
- `Destroy()` disconnects listeners and removes notifications, Glass models and DepthOfField effects.

## Validation

The revision is checked with the official Roblox Luau compiler/interpreter and API-derived strict mocks:

- module and exact standalone source compilation;
- five-category standalone construction;
- six local Glass parts per panel, near-only DepthOfField settings and no `BlurEffect`;
- backdrop projection updates and hide/show cleanup;
- critically damped drag behavior without input snapping or overshoot;
- inline settings height and spacing changes;
- all four background modes, image configuration, particle edge bouncing and distance-based links;
- bottom hover-description show/hide behavior;
- toggles, compact slider drag/glow, dropdowns, keybinds and textboxes;
- two-axis HSV picking, hue selection, hex synchronization and color callbacks;
- notifications, transparent settings icons and background-free hover descriptions;
- viewport clamping for dragged and programmatically positioned columns;
- final destruction cleanup.

Mocks do **not** validate real Roblox Glass rendering, image loading or physical input. Use Studio Play mode for that final platform check.

## Repository files

- `VantaUI.lua` — distributable ModuleScript source.
- `Example.client.lua` — complete standalone LocalScript with embedded library and demo.
- `README.md` — usage and API documentation.
- `THIRD_PARTY_NOTICES.md` — Lucide attribution/licenses and the local-blur implementation reference.
