local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/main/TaxiAutoFarm.lua"
local HWID = game:GetService("RbxAnalyticsService"):GetClientId()
local KeyLink = "https://new.pandadevelopment.net/getkey/ahahaburg?hwid=" .. HWID

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
        Note = "Copy the link, complete the steps, and paste your key here!",
        FileName = "AhahaBurgKey",
        SaveKey = true,
        GrabKeyFromSite = false,
        -- We use a custom function below to check if the key is valid with Panda
        Key = {"https://api.pandadevelopment.net/v1/key/verify?service=ahahaburg&hwid=" .. HWID .. "&key="}, 
        Actions = {
            [1] = {
                Name = "Copy Key Link",
                Callback = function()
                    setclipboard(KeyLink)
                    Rayfield:Notify({
                        Title = "Link Copied",
                        Content = "Panda link copied to clipboard!",
                        Duration = 5
                    })
                end
            }
        }
    }
})

--- [[ TABS ]] ---

local FarmTab = Window:CreateTab("Autofarm", 4483362458)

local TaxiToggle = FarmTab:CreateToggle({
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

local FarmSpeedSlider = FarmTab:CreateSlider({
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
