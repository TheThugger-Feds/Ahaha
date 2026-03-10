local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Your RAW GitHub link for the logic script
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
       Note = "Complete the checkpoints to get your key!",
       FileName = "AhahaBurgKey", 
       SaveKey = true, 
       GrabKeyFromSite = true, -- Now set to true to fetch keys from your link
       Key = {"https://your-raw-pastebin-or-github-link-with-keys.txt"}, -- REPLACE THIS with a link to a txt file containing valid keys
       Actions = {
            [1] = {
                Name = "Get Key",
                Callback = function()
                    -- This link opens Panda and includes the player's HWID
                    local KeyLink = "https://new.pandadevelopment.net/getkey/ahahaburg?hwid=" .. game:GetService("RbxAnalyticsService"):GetClientId()
                    
                    -- Copies to clipboard since Roblox has restrictions on opening browser tabs
                    setclipboard(KeyLink)
                    
                    Rayfield:Notify({
                        Title = "Key System",
                        Content = "Panda link copied to clipboard! Paste it in your browser.",
                        Duration = 5,
                        Image = 4483362458,
                    })
                end
            }
       }
    }
})

--- [[ TABS & SECTIONS ]] ---

local FarmTab = Window:CreateTab("Autofarm", 4483362458) 
local TaxiSection = FarmTab:CreateSection("Taxi Driver Farm")

local TaxiToggle = FarmTab:CreateToggle({
   Name = "Enable Taxi Farm",
   CurrentValue = false,
   Flag = "TaxiToggle", 
   Callback = function(Value)
      _G.TaxiToggle = Value
      if Value then
          if not _G.TaxiBotInitiated then
              -- Pulls the obfuscated/clean code from your GitHub
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
