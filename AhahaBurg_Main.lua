-- Load WindUI first, store globally so themes file can access it
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
getgenv().WindUI = WindUI

-- Load themes BEFORE CreateWindow
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/Ui-themes"))()
end)

-- Load Jnkie SDK
local Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
Junkie.service = "AhahaBurg"
Junkie.identifier = "1058056"
Junkie.provider = "AhahaBurg"

-- Variables
local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/main/TaxiAutoFarm.lua"
local AntiAFKURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/Anti-Afk"
local DiscordWebhook = "https://discord.com/api/webhooks/1485718245410607147/6gRCPAhs6kJMMzg-eiYAoUN_rKqRzpRsU3pawtT8K8WeilLEKapRoplLm2ptvxVrxe08"

_G.IsVerified = false
_G.TaxiToggle = false
_G.TaxiFarmSpeed = 36
_G.AntiAFK = false

local Themes = {"Dark", "Light", "Midnight", "Purple", "Ocean", "Cherry", "Forest", "Sunset"}

-- =====================
-- ERROR REPORTER
-- =====================
local REPORT_CONTEXTS = {
    ["get_key_link pcall"] = true,
    ["get_key_link response"] = true,
    ["check_key pcall failed"] = true,
    ["check_key nil result"] = true,
    ["check_key rejected"] = true,
    ["AntiAFK HttpGet"] = true,
    ["AntiAFK loadstring"] = true,
    ["TaxiFarm HttpGet"] = true,
    ["TaxiFarm loadstring"] = true,
}

local function reportError(context, err)
    warn("[AhahaBurg] " .. context .. ": " .. tostring(err))
    if not REPORT_CONTEXTS[context] then return end
    task.spawn(function()
        pcall(function()
            game:GetService("HttpService"):PostAsync(
                DiscordWebhook,
                game:GetService("HttpService"):JSONEncode({
                    embeds = {{
                        title = "⚠️ AhahaBurg Error",
                        color = 15158332,
                        fields = {
                            { name = "Error", value = "`" .. context .. "`", inline = false },
                            { name = "Details", value = tostring(err), inline = false },
                            { name = "Player", value = game.Players.LocalPlayer.Name, inline = true },
                            { name = "Place ID", value = tostring(game.PlaceId), inline = true },
                        },
                        footer = { text = "AhahaBurg Key System" },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                    }}
                }),
                "application/json"
            )
        end)
    end)
end

-- =====================
-- REGISTER JNKIE SERVICE BEFORE CREATEWINDOW
-- =====================
WindUI.Services = WindUI.Services or {}
WindUI.Services.jnkie = {
    Name = "Jnkie",
    Icon = "key",
    Args = { "ServiceName", "ProviderName" },
    New = function(ServiceName, ProviderName)

        local function validateKey(key)
            if not key or #key < 5 then
                return false, "Key too short."
            end
            local ok, res = pcall(function()
                return Junkie.check_key(key)
            end)
            if not ok then
                reportError("check_key pcall failed", tostring(res))
                return false, "Something went wrong. Try again."
            end
            if not res then
                reportError("check_key nil result", "nil for key: " .. tostring(key))
                return false, "Something went wrong. Try again."
            end
            if res.valid == true or res.message == "KEYLESS" then
                _G.IsVerified = true
                getgenv().SCRIPT_KEY = key
                return true, "Key is valid!"
            else
                local errMsg = res.error or res.message or "Unknown"
                reportError("check_key rejected", errMsg)
                if errMsg == "KEY_INVALID" then
                    return false, "That key doesn't exist. Copy it again."
                elseif errMsg == "KEY_EXPIRED" then
                    return false, "Your key has expired. Get a new one."
                elseif errMsg == "HWID_BANNED" then
                    task.delay(2, function()
                        game.Players.LocalPlayer:Kick("Access denied.")
                    end)
                    return false, "You are not allowed to use this script."
                elseif errMsg == "HWID_MISMATCH" then
                    return false, "This key is linked to a different device."
                elseif errMsg == "KEY_INVALIDATED" then
                    return false, "This key has been disabled. Get a new one."
                elseif errMsg == "ALREADY_USED" then
                    return false, "This key has already been redeemed."
                elseif errMsg == "PREMIUM_REQUIRED" then
                    return false, "This key requires a premium subscription."
                else
                    return false, "Something went wrong. Try again."
                end
            end
        end

        local function copyLink()
            task.spawn(function()
                local ok, link, err = pcall(Junkie.get_key_link)
                if not ok then
                    reportError("get_key_link pcall", tostring(link))
                    WindUI:Notify({ Title = "❌ Something went wrong", Content = "Try again in a moment.", Duration = 5 })
                    return
                end
                if link then
                    setclipboard(link)
                    WindUI:Notify({ Title = "✅ Copied!", Content = "Complete checkpoints then paste your key.", Duration = 6 })
                elseif err == "RATE_LIMITTED" then
                    WindUI:Notify({ Title = "⏳ Slow down!", Content = "Wait 5 minutes before getting a new link.", Duration = 6 })
                else
                    reportError("get_key_link response", tostring(err))
                    WindUI:Notify({ Title = "❌ Something went wrong", Content = "Try again in a moment.", Duration = 5 })
                end
            end)
        end

        return {
            Verify = validateKey,
            Copy = copyLink,
        }
    end
}

-- =====================
-- WINDOW — key system now works because jnkie is registered above
-- =====================
local Window = WindUI:CreateWindow({
    Title = "AhahaBurg",
    Icon = "shield-check",
    Author = "by ahaha8686",
    Size = UDim2.fromOffset(480, 480),
    Transparent = true,
    Theme = "Dark",

    KeySystem = {
        Note = "Get your key by completing the checkpoints.\nJoin discord: discord.gg/hbJ8y4F3ge",
        SaveKey = true,
        API = {
            {
                Title = "AhahaBurg Key",
                Desc = "Click Copy to get your key link",
                Icon = "key",
                Type = "jnkie",
                ServiceName = "AhahaBurg",
                ProviderName = "AhahaBurg",
            },
        },
    },
})

-- Tabs
local FarmTab = Window:Tab({ Title = "Autofarm", Icon = "truck" })
local MoodTab = Window:Tab({ Title = "Auto Mood", Icon = "smile" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
local CreditTab = Window:Tab({ Title = "Credits", Icon = "user" })

-- =====================
-- FARM TAB
-- =====================
FarmTab:Section({ Title = "Taxi Autofarm" })

FarmTab:Toggle({
    Title = "Enable Taxi Farm",
    Desc = "Automated Bloxburg Taxi",
    Value = false,
    Callback = function(Value)
        if not _G.IsVerified then
            WindUI:Notify({ Title = "🔒 Locked", Content = "Verify your key first!", Duration = 5 })
            return
        end
        _G.TaxiToggle = Value
        if Value then
            task.spawn(function()
                local ok, result = pcall(game.HttpGet, game, TaxiFarmURL)
                if ok and result and #result > 10 then
                    local fn, err = loadstring(result)
                    if fn then
                        pcall(fn)
                    else
                        reportError("TaxiFarm loadstring", tostring(err))
                        WindUI:Notify({ Title = "❌ Something went wrong", Content = "Farm failed to load. Try again.", Duration = 5 })
                    end
                else
                    reportError("TaxiFarm HttpGet", tostring(result))
                    WindUI:Notify({ Title = "❌ Something went wrong", Content = "Farm failed to download. Try again.", Duration = 5 })
                end
            end)
        end
    end
})

FarmTab:Slider({
    Title = "Farm Speed",
    Value = { Min = 16, Max = 100, Default = 36 },
    Callback = function(Value)
        _G.TaxiFarmSpeed = Value
    end
})

FarmTab:Paragraph({
    Title = "Info",
    Desc = "Toggle the farm above. Adjust speed to your preference."
})

-- =====================
-- AUTO MOOD TAB
-- =====================
MoodTab:Section({ Title = "Auto Mood" })

MoodTab:Paragraph({
    Title = "🚧 Coming Soon",
    Desc = "Auto Mood features are under development. Check back for updates!"
})

MoodTab:Toggle({
    Title = "Auto Mood (Unavailable)",
    Desc = "Not yet available",
    Value = false,
    Callback = function()
        WindUI:Notify({ Title = "🚧 Coming Soon", Content = "This feature isn't ready yet.", Duration = 4 })
    end
})

-- =====================
-- SETTINGS TAB
-- =====================
SettingsTab:Section({ Title = "Anti AFK" })

SettingsTab:Toggle({
    Title = "Anti AFK",
    Desc = "Prevents Roblox from kicking you for inactivity",
    Value = false,
    Callback = function(Value)
        _G.AntiAFK = Value
        if Value then
            task.spawn(function()
                local ok, result = pcall(game.HttpGet, game, AntiAFKURL)
                if ok and result and #result > 10 then
                    local fn, err = loadstring(result)
                    if fn then
                        pcall(fn)
                        WindUI:Notify({ Title = "✅ Anti AFK", Content = "Anti AFK enabled.", Duration = 4 })
                    else
                        reportError("AntiAFK loadstring", tostring(err))
                        WindUI:Notify({ Title = "❌ Something went wrong", Content = "Anti AFK failed to load.", Duration = 5 })
                    end
                else
                    reportError("AntiAFK HttpGet", tostring(result))
                    WindUI:Notify({ Title = "❌ Something went wrong", Content = "Anti AFK failed to download.", Duration = 5 })
                end
            end)
        else
            if getgenv().StopAntiAFK then
                getgenv().StopAntiAFK = true
            end
            WindUI:Notify({ Title = "Anti AFK", Content = "Anti AFK disabled.", Duration = 4 })
        end
    end
})

SettingsTab:Section({ Title = "Themes" })

for _, theme in ipairs(Themes) do
    SettingsTab:Button({
        Title = theme,
        Desc = "Switch UI to " .. theme .. " theme",
        Callback = function()
            local ok, err = pcall(WindUI.SetTheme, WindUI, theme)
            if ok then
                WindUI:Notify({ Title = "🎨 Theme", Content = "Switched to " .. theme, Duration = 3 })
            else
                warn("[AhahaBurg] SetTheme failed: " .. tostring(err))
                WindUI:Notify({ Title = "❌ Theme Error", Content = "Could not apply " .. theme .. " theme.", Duration = 4 })
            end
        end
    })
end

-- =====================
-- CREDITS TAB
-- =====================
CreditTab:Section({ Title = "Developer" })

CreditTab:Paragraph({
    Title = "AhahaBurg",
    Desc = "Automated Bloxburg script. Use responsibly."
})

CreditTab:Button({
    Title = "Discord: ahaha8686",
    Desc = "Click to copy Discord username",
    Callback = function()
        setclipboard("ahaha8686")
        WindUI:Notify({ Title = "Copied", Content = "Discord username copied.", Duration = 3 })
    end
})

CreditTab:Button({
    Title = "Join Discord Server",
    Desc = "Click to copy invite link",
    Callback = function()
        setclipboard("https://discord.gg/hbJ8y4F3ge")
        WindUI:Notify({ Title = "Copied", Content = "Discord invite copied! Open Discord and paste it.", Duration = 5 })
    end
})
