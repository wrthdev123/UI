-- VantaUI example
-- Place VantaUI.lua in ReplicatedStorage as a ModuleScript named "VantaUI".
-- Place this file in StarterPlayerScripts as a LocalScript.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VantaUI = require(ReplicatedStorage:WaitForChild("VantaUI"))

local window = VantaUI:CreateWindow({
    Title = "VANTA",
    Subtitle = "Right Shift  •  inline settings",
    Logo = "V",
    Accent = Color3.fromRGB(237, 45, 72),
    Size = Vector2.new(1140, 600),
    ColumnWidth = 214,
    ToggleKey = Enum.KeyCode.RightShift,
    Blur = 8,
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
    Title = "VantaUI 1.0",
    Description = "Self-contained Luau interface",
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
