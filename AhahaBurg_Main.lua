local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- GitHub Links
local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/main/TaxiAutoFarm.lua"
local AntiAfkURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/Anti-Afk"

-- Panda Auth Configuration
local PandaAPIKey = "81550b0b-2a1b-41ef-a3ce-c9f662097444"
local ServiceName = "ahahaburg"
local HWID = game:GetService("RbxAnalyticsService"):GetClientId()
local KeyLink = "https://new.pandadevelopment.net/getkey/" .. ServiceName .. "?hwid=" .. HWID

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
        -- THIS HANDLES THE ACTUAL PANDA AUTH VERIFICATION
        Key = function(InputKey)
            local VerifyURL = "https://api.pandadevelopment.net/v1/key/verify?service=" .. ServiceName .. "&hwid=" .. HWID .. "&key=" .. InputKey
            
            local Success, Response = pcall(function()
                return game:HttpGet(VerifyURL)
            end)
            
            -- Panda usually returns a string containing "success" or "valid" if the key is good
            if Success and (string.find(Response:lower(), "success") or string.find(Response:lower(), "valid")) then
                return true
            else
                return false
            end
        end,
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

local AntiAFKToggle = FarmTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Flag = "AntiAFK",
    Callback = function(Value)
        _G.AntiAFK = Value
        if Value and not _G.AntiAFKInitiated then
            _G.AntiAFKInitiated = true
            loadstring(game:HttpGet(AntiAfkURL))()
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
