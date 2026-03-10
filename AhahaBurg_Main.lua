local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- REPLACEMENT: Use your RAW GitHub link for the TaxiAutoFarm.lua file here
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
       Note = "Complete the checkpoints!",
       FileName = "AhahaBurgKey", 
       SaveKey = true, 
       GrabKeyFromSite = true, 
       -- Replace YOUR_LINK_ID with your first LootLabs link ID
       Key = {"https://loot-link.com/s?YOUR_LINK_ID&hwid=" .. game:GetService("RbxAnalyticsService"):GetClientId()} 
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
      if Value then
          -- Checks if the bot code is already loaded; if not, it pulls it from GitHub
          if not _G.TaxiBotInitiated then
              loadstring(game:HttpGet(TaxiFarmURL))()
              _G.TaxiBotInitiated = true
          end
      end
   end,
})

local FarmSpeedSlider = FarmTab:CreateSlider({
   Name = "Farm Speed",
   Info = "Adjusts movement speed in real-time.",
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
