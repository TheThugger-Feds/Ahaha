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
    Name = "Purple",
    Accent = Color3.fromHex("#1e1b2e"),
    Background = Color3.fromHex("#13111f"),
    Outline = Color3.fromHex("#3b2f6b"),
    Text = Color3.fromHex("#e9d5ff"),
    Placeholder = Color3.fromHex("#7c6fa0"),
    Button = Color3.fromHex("#4c3a8a"),
    Icon = Color3.fromHex("#a78bfa"),
})

WindUI:AddTheme({
    Name = "Ocean",
    Accent = Color3.fromHex("#0f2027"),
    Background = Color3.fromHex("#0a1a20"),
    Outline = Color3.fromHex("#164e63"),
    Text = Color3.fromHex("#e0f2fe"),
    Placeholder = Color3.fromHex("#4a8fa8"),
    Button = Color3.fromHex("#0e7490"),
    Icon = Color3.fromHex("#38bdf8"),
})

WindUI:AddTheme({
    Name = "Cherry",
    Accent = Color3.fromHex("#1f0a0a"),
    Background = Color3.fromHex("#150606"),
    Outline = Color3.fromHex("#7f1d1d"),
    Text = Color3.fromHex("#fee2e2"),
    Placeholder = Color3.fromHex("#9f6060"),
    Button = Color3.fromHex("#991b1b"),
    Icon = Color3.fromHex("#f87171"),
})

WindUI:AddTheme({
    Name = "Forest",
    Accent = Color3.fromHex("#0a1f0a"),
    Background = Color3.fromHex("#061206"),
    Outline = Color3.fromHex("#14532d"),
    Text = Color3.fromHex("#dcfce7"),
    Placeholder = Color3.fromHex("#4a7a5a"),
    Button = Color3.fromHex("#15803d"),
    Icon = Color3.fromHex("#4ade80"),
})

WindUI:AddTheme({
    Name = "Sunset",
    Accent = Color3.fromHex("#1f1410"),
    Background = Color3.fromHex("#140d08"),
    Outline = Color3.fromHex("#7c2d12"),
    Text = Color3.fromHex("#ffedd5"),
    Placeholder = Color3.fromHex("#9a6a50"),
    Button = Color3.fromHex("#c2410c"),
    Icon = Color3.fromHex("#fb923c"),
})

WindUI:AddTheme({
    Name = "Midnight",
    Accent = Color3.fromHex("#0f0f1a"),
    Background = Color3.fromHex("#080810"),
    Outline = Color3.fromHex("#1e1e3a"),
    Text = Color3.fromHex("#e2e8f0"),
    Placeholder = Color3.fromHex("#4a5568"),
    Button = Color3.fromHex("#2d2d5a"),
    Icon = Color3.fromHex("#818cf8"),
})

print("[AhahaBurg] Themes loaded successfully")
