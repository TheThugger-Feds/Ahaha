-- Load WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Store WindUI globally so themes file can access it
getgenv().WindUI = WindUI

-- Load Jnkie SDK
local Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
Junkie.service = "AhahaBurg"
Junkie.identifier = "1058056"
Junkie.provider = "AhahaBurg"

-- Load themes from raw
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/Ui-themes"))()
end)

-- Variables
local TaxiFarmURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/main/TaxiAutoFarm.lua"
local AntiAFKURL = "https://raw.githubusercontent.com/TheThugger-Feds/Ahaha/refs/heads/main/Anti-Afk"
local SavedKeyFile = "AhahaBurg_key.txt"
local DiscordWebhook = ""

_G.IsVerified = false
_G.TaxiToggle = false
_G.TaxiFarmSpeed = 36
_G.AntiAFK = false

local Themes = {"Dark", "Light", "Purple", "Ocean", "Cherry", "Forest"}

-- =====================
-- ERROR REPORTER
-- =====================
local function reportError(context, err)
    warn("[AhahaBurg Error] " .. context .. ": " .. tostring(err))
    if DiscordWebhook and #DiscordWebhook > 10 then
        task.spawn(function()
            pcall(function()
                game:GetService("HttpService"):PostAsync(DiscordWebhook, game:GetService("HttpService"):JSONEncode({
                    content = "**[AhahaBurg Error]** `" .. context .. "`: " .. tostring(err) ..
                              "\nPlayer: " .. game.Players.LocalPlayer.Name ..
                              " | PlaceId: " .. tostring(game.PlaceId)
                }))
            end)
        end)
    end
end

-- =====================
-- KEY SAVE/LOAD
-- =====================
local function saveKey(key)
    if writefile then pcall(writefile, SavedKeyFile, key) end
end

local function clearSavedKey()
    if writefile then pcall(writefile, SavedKeyFile, "") end
end

local function loadSavedKey()
    if readfile and isfile and isfile(SavedKeyFile) then
        local ok, key = pcall(readfile, SavedKeyFile)
        if ok and key and #key > 5 then return key end
    end
    return nil
end

-- =====================
-- WINDOW
-- =====================
local Window = WindUI:CreateWindow({
    Title = "AhahaBurg",
    Icon = "shield-check",
    Author = "by ahaha8686",
    Size = UDim2.fromOffset(480, 480),
    Transparent = true,
    Theme = "Dark",
})

-- Tabs
local AuthTab = Window:Tab({ Title = "Verify", Icon = "key" })
local FarmTab = Window:Tab({ Title = "Autofarm", Icon = "truck" })
local MoodTab = Window:Tab({ Title = "Auto Mood", Icon = "smile" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
local CreditTab = Window:Tab({ Title = "Credits", Icon = "user" })

-- =====================
-- AUTH TAB
-- =====================
AuthTab:Section({ Title = "Key System" })

-- We use a simple Paragraph and update its text via the label directly
local KeyStatusLabel = AuthTab:Paragraph({
    Title = "Key Status",
    Desc = "Not verified yet."
})

local function setKeyStatus(title, desc)
    -- Try multiple WindUI update methods since version may vary
    if KeyStatusLabel then
        if KeyStatusLabel.Set then
            pcall(KeyStatusLabel.Set, KeyStatusLabel, { Title = title, Desc = desc })
        elseif KeyStatusLabel.Update then
            pcall(KeyStatusLabel.Update, KeyStatusLabel, { Title = title, Desc = desc })
        end
        -- Also try direct label update as fallback
        pcall(function()
            if KeyStatusLabel.Instance then
                local titleLabel = KeyStatusLabel.Instance:FindFirstChild("Title", true)
                local descLabel = KeyStatusLabel.Instance:FindFirstChild("Desc", true)
                if titleLabel then titleLabel.Text = title end
                if descLabel then descLabel.Text = desc end
            end
        end)
    end
end

AuthTab:Button({
    Title = "1. Get Key Link",
    Desc = "Copies your checkpoint link to clipboard",
    Callback = function()
        task.spawn(function()
            WindUI:Notify({ Title = "Getting link...", Content = "Please wait.", Duration = 3 })
            local ok, a, b = pcall(Junkie.get_key_link)
            if not ok then
                reportError("get_key_link pcall", tostring(a))
                WindUI:Notify({ Title = "❌ Something went wrong", Content = "Try again in a moment.", Duration = 5 })
                return
            end
            -- get_key_link returns: link, err
            local link, err = a, b
            if link then
                setclipboard(link)
                WindUI:Notify({ Title = "✅ Copied!", Content = "Complete the checkpoints then paste your key below.", Duration = 6 })
            elseif err == "RATE_LIMITTED" then
                WindUI:Notify({ Title = "⏳ Slow down!", Content = "Wait 5 minutes before getting a new link.", Duration = 6 })
            else
                reportError("get_key_link response", tostring(err))
                WindUI:Notify({ Title = "❌ Something went wrong", Content = "Try again in a moment.", Duration = 5 })
            end
        end)
    end
})

local function formatExpiry(expiry)
    if not expiry or expiry == "" or expiry == "null" or expiry == nil then
        return "✅ Active — ∞ No Expiry"
    end
    local ts = tonumber(expiry)
    if ts then
        local remaining = ts - os.time()
        if remaining <= 0 then return "❌ Expired" end
        local days = math.floor(remaining / 86400)
        local hours = math.floor((remaining % 86400) / 3600)
        local mins = math.floor((remaining % 3600) / 60)
        if days > 0 then
            return string.format("✅ Active — %dd %dh %dm left", days, hours, mins)
        elseif hours > 0 then
            return string.format("✅ Active — %dh %dm left", hours, mins)
        else
            return string.format("✅ Active — %dm left", mins)
        end
    end
    return "✅ Active — ∞ No Expiry"
end

local function handleValidKey(key, result)
    _G.IsVerified = true
    getgenv().SCRIPT_KEY = key
    saveKey(key)

    -- Log full result so we can see what fields Jnkie actually returns
    reportError("DEBUG valid result", game:GetService("HttpService"):JSONEncode(result or {}))

    local expiry = result and (
        result.expiry or result.expires_at or result.expires or
        result.expiration or result.expire or result.exp
    )
    local timerText = formatExpiry(expiry)

    setKeyStatus("🔑 Key Status", timerText)

    -- Live countdown if expiry exists
    if expiry and tonumber(expiry) then
        task.spawn(function()
            while _G.IsVerified do
                task.wait(60)
                setKeyStatus("🔑 Key Status", formatExpiry(expiry))
            end
        end)
    end

    WindUI:Notify({ Title = "✅ Verified!", Content = "Script unlocked! " .. timerText, Duration = 6 })
end

local function validateKey(Text)
    if not Text or #Text < 5 then
        WindUI:Notify({ Title = "Invalid Key", Content = "That doesn't look right. Try copying it again.", Duration = 4 })
        return
    end

    task.spawn(function()
        WindUI:Notify({ Title = "Checking...", Content = "Validating your key.", Duration = 3 })

        -- Run check_key directly in this thread (no nested task.spawn)
        -- This fixes the timeout bug where done was never being read correctly
        local result = nil
        local ok, res = pcall(function()
            return Junkie.check_key(Text)
        end)

        if ok then
            result = res
        else
            reportError("check_key pcall failed", tostring(res))
            WindUI:Notify({ Title = "❌ Something went wrong", Content = "Try again in a moment.", Duration = 5 })
            return
        end

        if result == nil then
            reportError("check_key nil result", "returned nil for key: " .. Text)
            WindUI:Notify({ Title = "❌ Something went wrong", Content = "Try again in a moment.", Duration = 5 })
            return
        end

        -- Log raw result for debugging
        reportError("DEBUG raw result", tostring(result) .. " valid=" .. tostring(result and result.valid) .. " err=" .. tostring(result and result.error))

        if result.valid == true then
            handleValidKey(Text, result)
        else
            local errMsg = result.error or result.message or "Unknown"
            reportError("check_key rejected", errMsg)

            if errMsg == "KEY_INVALID" then
                WindUI:Notify({ Title = "❌ Invalid Key", Content = "That key doesn't exist. Make sure you copied it correctly.", Duration = 6 })
                clearSavedKey()
            elseif errMsg == "KEY_EXPIRED" then
                WindUI:Notify({ Title = "❌ Key Expired", Content = "Your key has expired. Get a new one.", Duration = 6 })
                clearSavedKey()
            elseif errMsg == "HWID_BANNED" then
                WindUI:Notify({ Title = "❌ Access Denied", Content = "You are not allowed to use this script.", Duration = 6 })
                task.wait(2)
                game.Players.LocalPlayer:Kick("Access denied.")
            elseif errMsg == "HWID_MISMATCH" then
                WindUI:Notify({ Title = "❌ Device Mismatch", Content = "This key is linked to a different device.", Duration = 6 })
            elseif errMsg == "KEY_INVALIDATED" then
                WindUI:Notify({ Title = "❌ Key Disabled", Content = "This key is no longer active. Get a new one.", Duration = 6 })
                clearSavedKey()
            elseif errMsg == "ALREADY_USED" then
                WindUI:Notify({ Title = "❌ Key Already Used", Content = "This key has already been redeemed.", Duration = 6 })
            elseif errMsg == "PREMIUM_REQUIRED" then
                WindUI:Notify({ Title = "❌ Premium Required", Content = "This key requires a premium subscription.", Duration = 6 })
            elseif errMsg == "KEYLESS" then
                -- Keyless mode counts as valid
                handleValidKey(Text, result)
            else
                WindUI:Notify({ Title = "❌ Something went wrong", Content = "Try again in a moment.", Duration = 5 })
            end
        end
    end)
end

AuthTab:Input({
    Title = "2. Enter Key",
    Placeholder = "Paste key here...",
    Callback = function(Text)
        validateKey(Text)
    end
})

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
    Desc = "Toggle the farm above. Adjust speed to your preference. Key must be verified first."
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
        if not _G.IsVerified then
            WindUI:Notify({ Title = "🔒 Locked", Content = "Verify your key first!", Duration = 5 })
            return
        end
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
            WindUI:SetTheme(theme)
            WindUI:Notify({ Title = "🎨 Theme", Content = "Switched to " .. theme, Duration = 3 })
        end
    })
end

SettingsTab:Section({ Title = "Key" })

SettingsTab:Button({
    Title = "Clear Saved Key",
    Desc = "Removes your saved key — you will need to re-enter it next time",
    Callback = function()
        clearSavedKey()
        WindUI:Notify({ Title = "🗑️ Cleared", Content = "Saved key removed.", Duration = 4 })
    end
})

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
        WindUI:Notify({ Title = "Copied", Content = "Discord invite link copied! Open Discord and paste it.", Duration = 5 })
    end
})

-- =====================
-- AUTO LOAD SAVED KEY
-- =====================
task.spawn(function()
    task.wait(1.5)
    local saved = loadSavedKey()
    if saved then
        WindUI:Notify({ Title = "🔑 Saved Key Found", Content = "Checking your key automatically...", Duration = 4 })
        validateKey(saved)
    end
end)
