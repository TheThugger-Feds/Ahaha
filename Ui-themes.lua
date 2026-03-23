local WindUI = getgenv().WindUI
if not WindUI then return end

WindUI:AddTheme({
    Name = "Dark",
    Accent = Color3.fromHex("#18181b"),
    Background = Color3.fromHex("#101010"),
    Outline = Color3.fromHex("#27272a"),
    Text = Color3.fromHex("#FFFFFF"),
    Placeholder = Color3.fromHex("#7a7a7a"),
    Button = Color3.fromHex("#52525b"),
    Icon = Color3.fromHex("#a1a1aa"),
})

WindUI:AddTheme({
    Name = "Light",
    Accent = Color3.fromHex("#e4e4e7"),
    Background = Color3.fromHex("#f4f4f5"),
    Outline = Color3.fromHex("#d4d4d8"),
    Text = Color3.fromHex("#09090b"),
    Placeholder = Color3.fromHex("#71717a"),
    Button = Color3.fromHex("#a1a1aa"),
    Icon = Color3.fromHex("#52525b"),
})

WindUI:AddTheme({
    Name = "Midnight",
    Accent = Color3.fromHex("#1e1e3a"),   -- lighter accent
    Background = Color3.fromHex("#0f0f1a"), -- darker background
    Outline = Color3.fromHex("#2d2d5a"),
    Text = Color3.fromHex("#e2e8f0"),
    Placeholder = Color3.fromHex("#6b7280"),
    Button = Color3.fromHex("#3730a3"),
    Icon = Color3.fromHex("#818cf8"),
})

WindUI:AddTheme({
    Name = "Purple",
    Accent = Color3.fromHex("#3b2f6b"),   -- lighter accent
    Background = Color3.fromHex("#13111f"), -- darker background
    Outline = Color3.fromHex("#4c3a8a"),
    Text = Color3.fromHex("#e9d5ff"),
    Placeholder = Color3.fromHex("#9d88c2"),
    Button = Color3.fromHex("#6d28d9"),
    Icon = Color3.fromHex("#a78bfa"),
})

WindUI:AddTheme({
    Name = "Ocean",
    Accent = Color3.fromHex("#164e63"),   -- lighter accent
    Background = Color3.fromHex("#0a1a20"), -- darker background
    Outline = Color3.fromHex("#0e7490"),
    Text = Color3.fromHex("#e0f2fe"),
    Placeholder = Color3.fromHex("#67a8c0"),
    Button = Color3.fromHex("#0284c7"),
    Icon = Color3.fromHex("#38bdf8"),
})

WindUI:AddTheme({
    Name = "Cherry",
    Accent = Color3.fromHex("#7f1d1d"),   -- lighter accent
    Background = Color3.fromHex("#150606"), -- darker background
    Outline = Color3.fromHex("#991b1b"),
    Text = Color3.fromHex("#fee2e2"),
    Placeholder = Color3.fromHex("#c08080"),
    Button = Color3.fromHex("#dc2626"),
    Icon = Color3.fromHex("#f87171"),
})

WindUI:AddTheme({
    Name = "Forest",
    Accent = Color3.fromHex("#14532d"),   -- lighter accent
    Background = Color3.fromHex("#061206"), -- darker background
    Outline = Color3.fromHex("#15803d"),
    Text = Color3.fromHex("#dcfce7"),
    Placeholder = Color3.fromHex("#6aaf7a"),
    Button = Color3.fromHex("#16a34a"),
    Icon = Color3.fromHex("#4ade80"),
})

WindUI:AddTheme({
    Name = "Sunset",
    Accent = Color3.fromHex("#7c2d12"),   -- lighter accent
    Background = Color3.fromHex("#140d08"), -- darker background
    Outline = Color3.fromHex("#c2410c"),
    Text = Color3.fromHex("#ffedd5"),
    Placeholder = Color3.fromHex("#c49a7a"),
    Button = Color3.fromHex("#ea580c"),
    Icon = Color3.fromHex("#fb923c"),
})

print("[AhahaBurg] Themes loaded successfully")
