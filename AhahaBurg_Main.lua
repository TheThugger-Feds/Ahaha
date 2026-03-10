local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/TaxiAutoFarm.lua"

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
       Subtitle = "Enter the key to continue",
       Note = "Get your key from the link below!",
       FileName = "AhahaBurgKey", 
       SaveKey = true, 
       GrabKeyFromSite = true, 
       Key = {"https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/main/keys.txt"}, 
       Actions = {
            [1] = {
                Name = "Get Key",
                Callback = function()
                    local HWID = game:GetService("RbxAnalyticsService"):GetClientId()
                    local KeyLink = "https://new.pandadevelopment.net/getkey/ahahaburg?hwid=" .. HWID
                    setclipboard(KeyLink)
                    Rayfield:Notify({
                        Title = "Key System",
                        Content = "Panda link copied to clipboard!",
                        Duration = 5,
                    })
                end
            }
       }
    }
})

local FarmTab = Window:CreateTab("Autofarm", 4483362458) 
local TaxiSection = FarmTab:CreateSection("Taxi Driver Farm")

local TaxiToggle = FarmTab:CreateToggle({
   Name = "Enable Taxi Farm",
   CurrentValue = false,
   Flag = "TaxiToggle", 
   Callback = function(Value)
      _G.TaxiToggle = Value
      if Value and not _G.TaxiBotInitiated then
          loadstring(game:HttpGet(TaxiFarmURL))()
          _G.TaxiBotInitiated = true
      end
   end,
})

local FarmSpeedSlider = FarmTab:CreateSlider({
   Name = "Farm Speed",
   Info = "Adjusts movement speed.",
   Range = {16, 100},
   Increment = 1,
   Suffix = " studs/sec",
   CurrentValue = 36,
   Flag = "TaxiSpeed", 
   Callback = function(Value)
      _G.TaxiFarmSpeed = Value
   end,
})

Rayfield:LoadConfiguration()
