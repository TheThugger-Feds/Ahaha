local VirtualUser = game:GetService("VirtualUser")
local Player = game:GetService("Players").LocalPlayer

-- This event ONLY fires when you have been inactive for a long time
Player.Idled:Connect(function()
    if _G.AntiAFK then
        -- Simulates a slight camera movement to register activity
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new()) 
        
        warn("AhahaBurg: Prevented AFK Kick.")
        
        Rayfield:Notify({
            Title = "Anti-AFK",
            Content = "Activity simulated to stay in-game.",
            Duration = 3
        })
    end
end)

Rayfield:Notify({
    Title = "Anti-AFK Loaded",
    Content = "System will only activate when you are idle.",
    Duration = 5
})
