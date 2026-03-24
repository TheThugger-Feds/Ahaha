local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
getgenv().WindUI = WindUI

local Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
Junkie.service = "AhahaBurg"
Junkie.identifier = "1058056"
Junkie.provider = "AhahaBurg"

local ThemesURL   = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/Ui-themes.lua"
local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/main/TaxiAutoFarm.lua"
local AntiAFKURL  = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/Anti-Afk"
local DiscordWebhook = "https://discord.com/api/webhooks/1485718245410607147/6gRCPAhs6kJMMzg-eiYAoUN_rKqRzpRsU3pawtT8K8WeilLEKapRoplLm2ptvxVrxe08"
local SavedKeyFile = "AhahaBurg_key.txt"

_G.IsVerified    = false
_G.TaxiToggle    = false
_G.TaxiFarmSpeed = 36
_G.AntiAFK       = false
_G.KeyExpiry     = nil
_G.KeyStatusText = "Not verified yet."

_G.TaxiHoverOffset   = 3.2
_G.TaxiStuckTime     = 3.0
_G.TaxiStuckVel      = 2.0
_G.TaxiDriveTimeout  = 40
_G.TaxiSweepInterval = 0.05
_G.TaxiSweepRange    = 7

local REPORT_CONTEXTS = {
    ["get_key_link pcall"]=true, ["get_key_link response"]=true,
    ["check_key pcall failed"]=true, ["check_key nil result"]=true,
    ["check_key rejected"]=true, ["AntiAFK HttpGet"]=true,
    ["AntiAFK loadstring"]=true, ["TaxiFarm HttpGet"]=true,
    ["TaxiFarm loadstring"]=true,
}

local function reportError(context, err)
    warn("[AhahaBurg] " .. context .. ": " .. tostring(err))
    if not REPORT_CONTEXTS[context] then return end
    task.spawn(function()
        pcall(function()
            game:GetService("HttpService"):PostAsync(DiscordWebhook,
                game:GetService("HttpService"):JSONEncode({
                    embeds = {{
                        title = "⚠️ AhahaBurg Error", color = 15158332,
                        fields = {
                            { name="Error",    value="`"..context.."`",              inline=false },
                            { name="Details",  value=tostring(err),                  inline=false },
                            { name="Player",   value=game.Players.LocalPlayer.Name,  inline=true  },
                            { name="Place ID", value=tostring(game.PlaceId),         inline=true  },
                        },
                        footer = { text = "AhahaBurg Key System" },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                    }}
                }), "application/json"
            )
        end)
    end)
end

local function saveKey(key) if writefile then pcall(writefile, SavedKeyFile, key) end end
local function clearSavedKey() if writefile then pcall(writefile, SavedKeyFile, "") end end
local function loadSavedKey()
    if readfile and isfile and isfile(SavedKeyFile) then
        local ok, key = pcall(readfile, SavedKeyFile)
        if ok and key and #key > 5 then return key end
    end
    return nil
end

local function formatExpiry(expiry)
    if not expiry or expiry=="" or expiry=="null" then return "✅ Active — ∞ No Expiry" end
    local ts = tonumber(expiry)
    if ts then
        local r = ts - os.time()
        if r <= 0 then return "❌ Expired" end
        local d = math.floor(r/86400)
        local h = math.floor((r%86400)/3600)
        local m = math.floor((r%3600)/60)
        if d>0 then return string.format("✅ Active — %dd %dh %dm left",d,h,m)
        elseif h>0 then return string.format("✅ Active — %dh %dm left",h,m)
        else return string.format("✅ Active — %dm left",m) end
    end
    return "✅ Active — ∞ No Expiry"
end

local function doValidateKey(key)
    if not key or #key < 5 then return false, "Key too short." end
    local ok, res = pcall(function() return Junkie.check_key(key) end)
    if not ok then reportError("check_key pcall failed", tostring(res)); return false, "Something went wrong. Try again." end
    if not res then reportError("check_key nil result", "nil for key: "..tostring(key)); return false, "Something went wrong. Try again." end
    if res.valid==true or res.message=="KEYLESS" then
        _G.IsVerified=true; getgenv().SCRIPT_KEY=key; saveKey(key)
        _G.KeyExpiry = res.expiry or res.expires_at or res.expires or res.expiration or res.expire or res.exp or nil
        _G.KeyStatusText = formatExpiry(_G.KeyExpiry)
        return true, "Key is valid!"
    else
        local errMsg = res.error or res.message or "Unknown"
        reportError("check_key rejected", errMsg)
        if errMsg=="KEY_INVALID" then clearSavedKey(); return false,"That key doesn't exist. Copy it again."
        elseif errMsg=="KEY_EXPIRED" then clearSavedKey(); return false,"Your key has expired. Get a new one."
        elseif errMsg=="HWID_BANNED" then
            task.delay(2, function() game.Players.LocalPlayer:Kick("Access denied.") end)
            return false,"You are not allowed to use this script."
        elseif errMsg=="HWID_MISMATCH" then return false,"This key is linked to a different device."
        elseif errMsg=="KEY_INVALIDATED" then clearSavedKey(); return false,"This key has been disabled. Get a new one."
        elseif errMsg=="ALREADY_USED" then return false,"This key has already been redeemed."
        elseif errMsg=="PREMIUM_REQUIRED" then return false,"This key requires a premium subscription."
        else return false,"Something went wrong. Try again." end
    end
end

WindUI.Services = WindUI.Services or {}
WindUI.Services.jnkie = {
    Name="Jnkie", Icon="key", Args={"ServiceName","ProviderName"},
    New = function(ServiceName, ProviderName)
        local function copyLink()
            task.spawn(function()
                local ok, link, err = pcall(Junkie.get_key_link)
                if not ok then
                    reportError("get_key_link pcall", tostring(link))
                    WindUI:Notify({Title="❌ Something went wrong", Content="Try again in a moment.", Duration=5})
                    return
                end
                if link then
                    setclipboard(link)
                    WindUI:Notify({Title="✅ Copied!", Content="Complete checkpoints then paste your key.", Duration=6})
                elseif err=="RATE_LIMITTED" then
                    WindUI:Notify({Title="⏳ Slow down!", Content="Wait 5 minutes before getting a new link.", Duration=6})
                else
                    reportError("get_key_link response", tostring(err))
                    WindUI:Notify({Title="❌ Something went wrong", Content="Try again in a moment.", Duration=5})
                end
            end)
        end
        return { Verify=doValidateKey, Copy=copyLink }
    end
}

task.spawn(function()
    local ok, result = pcall(game.HttpGet, game, ThemesURL)
    if ok and result and #result > 10 then
        local fn = loadstring(result)
        if fn then pcall(fn) end
    end
end)

local Window = WindUI:CreateWindow({
    Title = "AhahaBurg",
    Icon = "shield-check",
    Author = "by ahaha8686",
    Size = UDim2.fromOffset(460, 520),
    Transparent = true,
    Theme = "Dark",
    KeySystem = {
        Note = "Get your key by completing the checkpoints.\nJoin discord: discord.gg/hbJ8y4F3ge",
        SaveKey = false,
        API = {{
            Title="AhahaBurg Key", Desc="Click Copy to get your key link",
            Icon="key", Type="jnkie",
            ServiceName="AhahaBurg", ProviderName="AhahaBurg",
        }},
    },
})

local FarmTab     = Window:Tab({Title="Autofarm",  Icon="truck"   })
local MoodTab     = Window:Tab({Title="Auto Mood", Icon="smile"   })
local SettingsTab = Window:Tab({Title="Settings",  Icon="settings"})
local CreditTab   = Window:Tab({Title="Credits",   Icon="user"    })

-- =====================
-- FARM TAB
-- =====================
FarmTab:Section({Title="🚕 Taxi Autofarm"})

FarmTab:Toggle({
    Title="Enable Taxi Farm",
    Value=false,
    Callback=function(Value)
        if not _G.IsVerified then
            WindUI:Notify({Title="🔒 Locked", Content="Verify your key first!", Duration=5})
            return
        end
        _G.TaxiToggle = Value
        if Value then
            task.spawn(function()
                local ok, result = pcall(game.HttpGet, game, TaxiFarmURL)
                if ok and result and #result > 10 then
                    local fn, err = loadstring(result)
                    if fn then pcall(fn)
                    else reportError("TaxiFarm loadstring", tostring(err))
                        WindUI:Notify({Title="❌ Farm failed to load", Content="Try again.", Duration=5})
                    end
                else
                    reportError("TaxiFarm HttpGet", tostring(result))
                    WindUI:Notify({Title="❌ Farm failed to download", Content="Try again.", Duration=5})
                end
            end)
        end
    end
})

FarmTab:Section({Title="⚙️ Taxi Settings"})

FarmTab:Slider({
    Title="Drive Speed",
    Desc="How fast the taxi drives (studs/sec)",
    Value={Min=16, Max=100, Default=36},
    Callback=function(v) _G.TaxiFarmSpeed=v end
})

FarmTab:Slider({
    Title="Hover Height",
    Desc="How high the car floats above ground",
    Value={Min=1, Max=8, Default=3},
    Callback=function(v) _G.TaxiHoverOffset=v+0.2 end
})

FarmTab:Slider({
    Title="Stuck Timer (s)",
    Desc="Seconds before car decides it's stuck",
    Value={Min=1, Max=10, Default=3},
    Callback=function(v) _G.TaxiStuckTime=v end
})

FarmTab:Slider({
    Title="Stuck Sensitivity",
    Desc="Min speed to not count as stuck — lower reacts sooner",
    Value={Min=1, Max=8, Default=2},
    Callback=function(v) _G.TaxiStuckVel=v end
})

FarmTab:Slider({
    Title="Drive Timeout (s)",
    Desc="Max seconds allowed per trip before giving up",
    Value={Min=15, Max=120, Default=40},
    Callback=function(v) _G.TaxiDriveTimeout=v end
})

FarmTab:Slider({
    Title="Obstacle Scan Range",
    Desc="How far ahead to scan for obstacles (studs)",
    Value={Min=4, Max=20, Default=7},
    Callback=function(v) _G.TaxiSweepRange=v end
})

FarmTab:Slider({
    Title="Scan Frequency",
    Desc="Ray fire rate — lower = more responsive (heavier)",
    Value={Min=1, Max=10, Default=5},
    Callback=function(v) _G.TaxiSweepInterval=v/100 end
})

FarmTab:Section({Title="➕ More Autofarms"})

FarmTab:Paragraph({
    Title="Coming Soon",
    Desc="Additional autofarm modules will appear here."
})

-- =====================
-- AUTO MOOD TAB
-- =====================
MoodTab:Section({Title="Auto Mood"})
MoodTab:Paragraph({Title="🚧 Coming Soon", Desc="Auto Mood is under development."})
MoodTab:Toggle({
    Title="Auto Mood (Unavailable)", Value=false,
    Callback=function()
        WindUI:Notify({Title="🚧 Coming Soon", Content="This feature isn't ready yet.", Duration=4})
    end
})

-- =====================
-- SETTINGS TAB
-- =====================
SettingsTab:Section({Title="Key Info"})

local KeyStatusParagraph = SettingsTab:Paragraph({
    Title="🔑 Key Status",
    Desc="Checking saved key..."
})

local function updateKeyLabel()
    pcall(function()
        local text = _G.IsVerified and _G.KeyStatusText or "❌ Not verified."
        if KeyStatusParagraph.Set then
            KeyStatusParagraph:Set({Title="🔑 Key Status", Desc=text})
        elseif KeyStatusParagraph.Update then
            KeyStatusParagraph:Update({Title="🔑 Key Status", Desc=text})
        end
    end)
end

SettingsTab:Section({Title="Anti AFK"})

SettingsTab:Toggle({
    Title="Anti AFK",
    Desc="Prevents Roblox from kicking you for inactivity",
    Value=false,
    Callback=function(Value)
        _G.AntiAFK = Value
        if Value then
            task.spawn(function()
                local ok, result = pcall(game.HttpGet, game, AntiAFKURL)
                if ok and result and #result > 10 then
                    local fn, err = loadstring(result)
                    if fn then pcall(fn); WindUI:Notify({Title="✅ Anti AFK", Content="Enabled.", Duration=4})
                    else reportError("AntiAFK loadstring", tostring(err))
                        WindUI:Notify({Title="❌ Anti AFK failed to load", Content="", Duration=5})
                    end
                else
                    reportError("AntiAFK HttpGet", tostring(result))
                    WindUI:Notify({Title="❌ Anti AFK failed to download", Content="", Duration=5})
                end
            end)
        else
            if getgenv().StopAntiAFK then getgenv().StopAntiAFK=true end
            WindUI:Notify({Title="Anti AFK", Content="Disabled.", Duration=4})
        end
    end
})

SettingsTab:Section({Title="🎨 Themes"})

local themeNames = {"Dark","Light","Midnight","Purple","Ocean","Cherry","Forest","Sunset"}
for _, themeName in ipairs(themeNames) do
    SettingsTab:Button({
        Title=themeName,
        Callback=function()
            local ok = pcall(function() WindUI:SetTheme(themeName) end)
            if ok then
                WindUI:Notify({Title="🎨 Theme Changed", Content=themeName.." applied.", Duration=3})
            else
                WindUI:Notify({Title="❌ Theme Error", Content="Could not apply "..themeName, Duration=3})
            end
        end
    })
end

-- =====================
-- CREDITS TAB
-- =====================
CreditTab:Section({Title="Developer"})
CreditTab:Paragraph({Title="AhahaBurg", Desc="Automated Bloxburg script. Use responsibly."})
CreditTab:Button({
    Title="Discord: ahaha8686", Desc="Click to copy Discord username",
    Callback=function()
        setclipboard("ahaha8686")
        WindUI:Notify({Title="Copied", Content="Discord username copied.", Duration=3})
    end
})
CreditTab:Button({
    Title="Join Discord Server", Desc="Click to copy invite link",
    Callback=function()
        setclipboard("https://discord.gg/hbJ8y4F3ge")
        WindUI:Notify({Title="Copied", Content="Paste in Discord to join.", Duration=5})
    end
})

-- =====================
-- SAVED KEY + STATUS
-- =====================
task.spawn(function()
    local saved = loadSavedKey()
    if saved then
        WindUI:Notify({Title="🔑 Saved Key Found", Content="Checking your key...", Duration=4})
        local valid, msg = doValidateKey(saved)
        if valid then WindUI:Notify({Title="✅ Key Valid", Content=_G.KeyStatusText, Duration=5})
        else WindUI:Notify({Title="❌ Saved Key Failed", Content=msg, Duration=5}) end
        updateKeyLabel()
    else
        WindUI:Notify({Title="🔑 Key Required", Content="Please enter your key.", Duration=5})
        updateKeyLabel()
    end
    while true do
        task.wait(60)
        if _G.IsVerified and _G.KeyExpiry then
            _G.KeyStatusText = formatExpiry(_G.KeyExpiry)
            updateKeyLabel()
        end
    end
end)

task.spawn(function()
    local wasVerified = false
    while true do
        task.wait(0.5)
        if _G.IsVerified and not wasVerified then
            wasVerified = true; task.wait(0.3)
            updateKeyLabel()
            WindUI:Notify({Title="✅ Verified!", Content=_G.KeyStatusText, Duration=5})
        end
    end
end)
