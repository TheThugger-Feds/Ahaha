local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()

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
       Note = "Link: new.pandadevelopment.net/getkey/ahahaburg",
       FileName = "AhahaBurgKey",
       SaveKey = true,
       GrabKeyFromSite = false,
       Key = {"Ahaha_Success"},
       Actions = {
            [1] = {
                Name = "Get Key (Copy Link)",
                Callback = function()
                    local HWID = game:GetService("RbxAnalyticsService"):GetClientId()
                    setclipboard("https://new.pandadevelopment.net/getkey/ahahaburg?hwid=" .. HWID)
                end
            }
       }
    }
})

local KeyTab = Window:CreateTab("Key", 4483362458)

KeyTab:CreateButton({
   Name = "Get Key",
   Callback = function()
      local HWID = game:GetService("RbxAnalyticsService"):GetClientId()
      setclipboard("https://new.pandadevelopment.net/getkey/ahahaburg?hwid=" .. HWID)
   end,
})

local FarmTab = Window:CreateTab("Autofarm", 4483362458)

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
   Range = {16, 100},
   Increment = 1,
   CurrentValue = 36,
   Flag = "TaxiSpeed",
   Callback = function(Value)
      _G.TaxiFarmSpeed = Value
   end,
})

Rayfield:LoadConfiguration()
