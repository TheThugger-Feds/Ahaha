local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/main/TaxiAutoFarm.lua"
local HWID = game:GetService("RbxAnalyticsService"):GetClientId()
local KeyLink = "https://new.pandadevelopment.net/getkey/ahahaburg?hwid=" .. HWID

-- This copies the link the SECOND you execute, just in case the button vanishes
setclipboard(KeyLink)

local Window = Rayfield:CreateWindow({
    Name = "AhahaBurg",
    LoadingTitle = "Authenticating...",
    LoadingSubtitle = "by @ETOGA61",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AhahaBurg_Configs",
        FileName = "MainUI"
    },
    KeySystem = true,
    KeySettings = {
        Title = "AhahaBurg | Key System",
        Subtitle = "Panda Auth Required",
        -- FORCING THE LINK INTO THE TEXT BOX HERE:
        Note = "LINK COPIED! If not, visit: new.pandadevelopment.net/getkey/ahahaburg",
        FileName = "AhahaBurgKey",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"Ahaha_Success"}, 
        Actions = {
            [1] = {
                Name = "Copy Key Link",
                Callback = function()
                    setclipboard(KeyLink)
                end
            }
        }
    }
})

local FarmTab = Window:CreateTab("Autofarm", 4483362458)

FarmTab:CreateToggle({
    Name = "Enable Taxi Farm",
    CurrentValue = false,
    Flag = "TaxiToggle",
    Callback = function(Value)
        _G.TaxiToggle = Value
        if Value and not _G.TaxiBotInitiated then
            _G.TaxiBotInitiated = true
            loadstring(game:HttpGet(TaxiFarmURL))()
        end
    end
})

FarmTab:CreateSlider({
    Name = "Farm Speed",
    Range = {16, 100},
    Increment = 1,
    CurrentValue = 36,
    Flag = "TaxiSpeed",
    Callback = function(Value)
        _G.TaxiFarmSpeed = Value
    end
})

Rayfield:LoadConfiguration()
