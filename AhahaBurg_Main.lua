local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- GET THE USER'S HWID FOR PANDA AUTH
local HWID = game:GetService("RbxAnalyticsService"):GetClientId()

-- REPLACE THIS WITH YOUR FIRST LOOTLABS LINK
local KeyLink = "https://loot-link.com/s?YOUR_LINK_1_ID&hwid=" .. HWID

-- REPLACE THIS WITH THE RAW GITHUB LINK TO YOUR TAXI FARM SCRIPT
local TaxiLogicURL = "https://raw.githubusercontent.com/TheThugger-Feds/Bloxburg-script/main/TaxiBot_v4_Fixed.lua"

local Window = Rayfield:CreateWindow({
    Name = "AhahaBurg",
    LoadingTitle = "Authenticating...",
    LoadingSubtitle = "by @ETOGA61",
    ConfigurationSaving = {
       Enabled = true,
       FolderName = "AhahaBurg_Configs",
       FileName = "MainConfig"
    },
    Discord = {
       Enabled = true,
       Invite = "YOUR_DISCORD_INVITE", -- Put just the code, e.g. "abcd"
       RememberJoins = true
    },
    KeySystem = true,
    KeySettings = {
       Title = "AhahaBurg | Key System",
       Subtitle = "Enter the key to continue",
       Note = "Checkpoints required for the key!",
       FileName = "AhahaBurgKey",
       SaveKey = true,
       GrabKeyFromSite = false,
       Key = {KeyLink} -- This makes the 'Get Key' button open your link
    }
})

-- AUTO FARM TAB
local FarmTab = Window:CreateTab("Autofarm", 4483362458) 

local TaxiSection = FarmTab:CreateSection("Taxi Driver Farm")

local TaxiToggle = FarmTab:CreateToggle({
   Name = "Enable Taxi Farm",
   CurrentValue = false,
   Flag = "TaxiToggle", 
   Callback = function(Value)
      if Value then
          _G.StopTaxiFarm = false
          loadstring(game:HttpGet(TaxiLogicURL))()
      else
          _G.StopTaxiFarm = true -- Your Taxi script should check this to stop loops
      end
   end,
})

local FarmSpeedSlider = FarmTab:CreateSlider({
   Name = "Farm Speed",
   Info = "Changes the movement speed of the autonomous taxi.",
   Range = {16, 100},
   Increment = 1,
   Suffix = " studs/sec",
   CurrentValue = 20,
   Flag = "SpeedSlider", 
   Callback = function(Value)
      _G.TaxiFarmSpeed = Value
   end,
})

Rayfield:LoadConfiguration()
