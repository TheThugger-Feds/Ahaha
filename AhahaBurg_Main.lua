local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- GitHub Links
local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/main/TaxiAutoFarm.lua"
local AntiAfkURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/Anti-Afk"

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
        -- THIS SECTION HANDLES THE EXTERNAL API CHECK
        Key = function(InputKey)
            local ApiUrl = "https://api.pandadevelopment.net/v1/key/verify?service=ahahaburg&hwid=" .. HWID .. "&key=" .. InputKey
            local Success, Response = pcall(function()
                return game:HttpGet(ApiUrl)
            end)
            
            if Success and Response:find("success") then -- Adjust based on Panda's actual API response string
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
    Range = {16, 60},
    Increment = 1,
    CurrentValue = 30,
    Flag = "TaxiSpeed",
    Callback = function(Value)
        _G.TaxiFarmSpeed = Value
    end
})

Rayfield:LoadConfiguration()
