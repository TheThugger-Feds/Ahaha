local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()

local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/TaxiAutoFarm.lua"
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
Subtitle = "Press Enter to copy key link",
Note = "Press the button or Enter to copy the key link",
FileName = "AhahaBurgKey",
SaveKey = true,
GrabKeyFromSite = false,
Key = {"Ahaha_Success"},
Actions = {
[1] = {
Name = "Copy Key Link",
Callback = function()
setclipboard(KeyLink)
Rayfield:Notify({
Title = "Link Copied",
Content = "Key link copied to clipboard",
Duration = 4
})
end
}
}
}
})

local KeyTab = Window:CreateTab("Key", 4483362458)

KeyTab:CreateButton({
Name = "Copy Key Link",
Callback = function()
setclipboard(KeyLink)
Rayfield:Notify({
Title = "Link Copied",
Content = "Key link copied to clipboard",
Duration = 4
})
end
})

local FarmTab = Window:CreateTab("Autofarm", 4483362458)

FarmTab:CreateToggle({
Name = "Enable Taxi Farm",
CurrentValue = false,
Flag = "TaxiToggle",
Callback = function(Value)
_G.TaxiToggle = Value
if Value and not _G.TaxiBotInitiated then
loadstring(game:HttpGet(TaxiFarmURL))()
_G.TaxiBotInitiated = true
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
