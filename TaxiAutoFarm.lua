-- AhahaBurg | TaxiAutoFarm.lua v7.5 (Full 7.1 Engine)
-- FIXES v7.1 Integrated: Smart reroute, Close obstacle check, Waypoint cleanup, Wide search
-- UI Integrated: _G.TaxiToggle, _G.TaxiFarmSpeed

local player     = game.Players.LocalPlayer
local camera     = workspace.CurrentCamera
local PFS        = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local VIM        = game:GetService("VirtualInputManager")

local Environment = workspace:WaitForChild("Environment", 15)
local taxiStands  = Environment and Environment:WaitForChild("TaxiStands", 15)

local HOVER_STIFFNESS = 50
local HOVER_DAMPING   = 32
local MIN_SAFE_Y      = -50

local CFG = {
    -- DRIVE_SPEED is now dynamic via _G.TaxiFarmSpeed
    HOVER_OFFSET   = 3.2,
    HOVER_SMOOTH   = 0.10,

    WP_REACH       = 6.0,    -- studs to count waypoint as reached
    LOOK_WP        = 2,      -- lookahead for steering

    -- Primary wall check (far: triggers reroute to plan new route)
    WALL_DIST      = 8,
    WALL_RECHECK   = 0.6,

    -- Secondary close check (near: triggers immediate reroute before impact)
    CLOSE_DIST     = 3,
    CLOSE_RECHECK  = 0.15,

    STUCK_TIME     = 3.0,
    STUCK_VEL      = 2.0,
    STUCK_DIST     = 1.5,
    NUDGE_DUR      = 1.2,

    PATH_RETRIES   = 4,
    DRIVE_TIMEOUT  = 40,
    LOOP_INTERVAL  = 1.5,

    -- Entry
    TAXI_SEARCH_R  = 100,   -- wider search radius
    TAXI_MIN_DOT   = 0.0,   -- allow full 180° — anything not directly behind
}

--------------------------------------------------------------------------------
-- PHYSICS
--------------------------------------------------------------------------------

local function initPhysics(vehicle)
    if not vehicle or not vehicle.PrimaryPart then return nil end
    local p = vehicle.PrimaryPart
    p.Anchored = false
    local old = p:FindFirstChild("TaxiAlignO")
    if old then old:Destroy() end

    local att = p:FindFirstChild("TaxiAtt") or Instance.new("Attachment", p)
    att.Name = "TaxiAtt"

    local lv = p:FindFirstChild("TaxiLV") or Instance.new("LinearVelocity", p)
    lv.Name = "TaxiLV"
    lv.Attachment0 = att
    lv.MaxForce = 9e6
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = Vector3.new(0, 0, 0)

    local bg = p:FindFirstChild("TaxiBG") or Instance.new("BodyGyro", p)
    bg.Name = "TaxiBG"
    bg.MaxTorque = Vector3.new(4e5, 0, 4e5)
    bg.P = 8000; bg.D = 600
    bg.CFrame = CFrame.new(p.Position)

    return lv
end

--------------------------------------------------------------------------------
-- GROUND / HOVER
--------------------------------------------------------------------------------

local function sampleGround(p, vehicle)
    local offsets = {
        Vector3.new(0,0,0),  Vector3.new(3,0,4),  Vector3.new(-3,0,4),
        Vector3.new(3,0,-4), Vector3.new(-3,0,-4),
    }
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local total, count = 0, 0
    for _, o in ipairs(offsets) do
        local r = workspace:Raycast(p.Position + Vector3.new(o.X,1.5,o.Z), Vector3.new(0,-16,0), params)
        if r then total = total + r.Position.Y; count = count + 1 end
    end
    return count > 0 and (total/count) or nil
end

local smoothV = 0
local function hoverVel(p, vehicle)
    if p.Position.Y < MIN_SAFE_Y then smoothV = 30; return 30 end
    local g = sampleGround(p, vehicle)
    local raw = -4
    if g then
        local err = (g + CFG.HOVER_OFFSET) - p.Position.Y
        local airborne = err < -3.5
        local ks = airborne and HOVER_STIFFNESS*2 or HOVER_STIFFNESS
        local kd = airborne and HOVER_DAMPING*1.6 or HOVER_DAMPING
        raw = math.clamp(err*ks - p.AssemblyLinearVelocity.Y*kd, -35, 35)
    end
    smoothV = smoothV + (raw - smoothV) * CFG.HOVER_SMOOTH
    return smoothV
end

--------------------------------------------------------------------------------
-- SWEEPING FAN SCANNER
--------------------------------------------------------------------------------

local scanAngle = 0   

local function fanScan(p, vehicle, faceDir, maxDist)
    if faceDir.Magnitude < 0.01 then return nil, nil end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local origin = p.Position + Vector3.new(0, 1.2, 0)
    local right  = Vector3.new(faceDir.Z, 0, -faceDir.X)
    local fwd    = faceDir.Unit

    scanAngle = (scanAngle + 8) % 82   
    local halfAngle = math.min(scanAngle, 80 - scanAngle) * 0.5 + 2  

    local lRad   = math.rad(halfAngle)
    local leftDir = (fwd * math.cos(lRad) - right * math.sin(lRad)).Unit

    local rRad    = math.rad(-halfAngle)
    local rightDir = (fwd * math.cos(rRad) - right * math.sin(rRad)).Unit

    local hitC = workspace:Raycast(origin, fwd      * maxDist, params)
    local hitL = workspace:Raycast(origin, leftDir  * maxDist, params)
    local hitR = workspace:Raycast(origin, rightDir * maxDist, params)

    local minDist = nil
    local hitSide = nil

    if hitC then minDist = hitC.Distance; hitSide = "centre" end
    if hitL and (not minDist or hitL.Distance < minDist) then minDist = hitL.Distance; hitSide = "left" end
    if hitR and (not minDist or hitR.Distance < minDist) then minDist = hitR.Distance; hitSide = "right" end

    return minDist, hitSide
end

local function castRay(origin, dir, dist, vehicle)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    return workspace:Raycast(origin, dir.Unit * dist, params)
end

local function closeObstacleAhead(p, vehicle, faceDir, dist)
    if faceDir.Magnitude < 0.01 then return false end
    local origin = p.Position + Vector3.new(0, 1.2, 0)
    local right  = Vector3.new(faceDir.Z, 0, -faceDir.X)
    local fwd    = faceDir.Unit
    for _, deg in ipairs({0, 10, -10, 20, -20}) do
        local rad = math.rad(deg)
        local d   = (fwd * math.cos(rad) + right * math.sin(rad)).Unit
        if castRay(origin, d, dist, vehicle) then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- OPEN SIDE FINDER
--------------------------------------------------------------------------------

local function findOpenStartPos(p, vehicle, goalPos, minClearance)
    minClearance = minClearance or 6
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local toGoal  = goalPos and Vector3.new(goalPos.X-p.Position.X, 0, goalPos.Z-p.Position.Z) or nil
    local goalDir = (toGoal and toGoal.Magnitude > 1) and toGoal.Unit or Vector3.new(0,0,-1)

    local bestDir   = nil
    local bestScore = -math.huge

    for i = 0, 15 do
        local rad       = math.rad(i * 22.5)
        local dir       = Vector3.new(math.sin(rad), 0, math.cos(rad))
        local origin    = p.Position + Vector3.new(0, 1.2, 0)
        local hit       = workspace:Raycast(origin, dir * 32, params)
        local clearDist = 32

        if hit then
            if hit.Normal.Y > 0.7 then clearDist = 32 else clearDist = hit.Distance end
        end

        if clearDist >= minClearance then
            local goalDot = dir:Dot(goalDir)
            local score   = clearDist + goalDot * 12  
            if score > bestScore then
                bestScore = score
                bestDir   = dir
            end
        end
    end

    if not bestDir then
        local perp = Vector3.new(-goalDir.Z, 0, goalDir.X)
        return p.Position + perp * 4
    end

    local hit2    = workspace:Raycast(p.Position + Vector3.new(0,1.2,0), bestDir*32, params)
    local maxStep = (hit2 and hit2.Normal.Y <= 0.7) and hit2.Distance * 0.6 or 10
    return p.Position + bestDir * math.min(maxStep, 10)
end

--------------------------------------------------------------------------------
-- WAYPOINT CLEANUP
--------------------------------------------------------------------------------

local function cleanWaypoints(pts)
    if #pts < 2 then return pts end

    local deduped = { pts[1] }
    for i = 2, #pts do
        local prev = deduped[#deduped]
        local xzDist = Vector3.new(pts[i].X - prev.X, 0, pts[i].Z - prev.Z).Magnitude
        if xzDist > 1.5 then
            table.insert(deduped, pts[i])
        end
    end

    local changed = true
    local passes  = 0
    local cleaned = deduped
    while changed and passes < 6 do
        changed = false
        passes  = passes + 1
        local out = { cleaned[1] }
        local i   = 2
        while i <= #cleaned do
            local prev = out[#out]
            local curr = cleaned[i]
            local next = cleaned[i + 1]
            if next then
                local d1 = Vector3.new(curr.X - prev.X, 0, curr.Z - prev.Z)
                local d2 = Vector3.new(next.X - curr.X, 0, next.Z - curr.Z)
                if d1.Magnitude > 0.5 and d2.Magnitude > 0.5 then
                    local dot = (d1.Unit):Dot(d2.Unit)
                    if dot < -0.3 then
                        changed = true
                        i = i + 1  
                        continue
                    end
                end
            end
            table.insert(out, curr)
            i = i + 1
        end
        cleaned = out
    end

    if cleaned[#cleaned] ~= pts[#pts] then
        table.insert(cleaned, pts[#pts])
    end

    return cleaned
end

--------------------------------------------------------------------------------
-- STUCK DETECTION
--------------------------------------------------------------------------------

local function makeStuck(p)
    local lastPos = p.Position
    local timer   = 0
    local nudging = false

    local function update(dt)
        if nudging then return false, nil end
        local hv   = Vector3.new(p.AssemblyLinearVelocity.X,0,p.AssemblyLinearVelocity.Z).Magnitude
        local dist = (p.Position - lastPos).Magnitude
        if hv < CFG.STUCK_VEL and dist < CFG.STUCK_DIST then
            timer = timer + dt
        else
            timer = 0; lastPos = p.Position
        end
        if timer >= CFG.STUCK_TIME then
            timer = 0; lastPos = p.Position
            local best, bestD = Vector3.new(0,0,1), 0
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {player.Character}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            for a = 0, 315, 45 do
                local d = Vector3.new(math.sin(math.rad(a)),0,math.cos(math.rad(a)))
                local h = workspace:Raycast(p.Position, d*22, rp)
                local cd = h and h.Distance or 22
                if cd > bestD then bestD=cd; best=d end
            end
            nudging = true
            return true, best
        end
        return false, nil
    end

    return update, function(v) nudging = v end
end

--------------------------------------------------------------------------------
-- PATH COMPUTE
--------------------------------------------------------------------------------

local function computeWaypoints(fromPos, toPos)
    local jitter = {
        Vector3.new(0,-1.8,0),  Vector3.new(3,-1.8,0),
        Vector3.new(-3,-1.8,0), Vector3.new(0,-1.8,3),
    }
    for i = 1, CFG.PATH_RETRIES do
        local path = PFS:CreatePath({AgentRadius=10, AgentCanJump=false})
        local ok, err = pcall(function()
            path:ComputeAsync(fromPos, toPos + (jitter[i] or Vector3.new()))
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            local pts = {}
            for _, w in ipairs(path:GetWaypoints()) do
                table.insert(pts, w.Position)
            end
            pts = cleanWaypoints(pts)
            return pts
        end
        task.wait(0.2)
    end
    return nil
end

local function waypointKey(wps)
    if not wps or #wps == 0 then return "" end
    local function snap(v) return math.floor(v/4)*4 end
    local function fmt(w)  return snap(w.X)..","..snap(w.Z) end
    local mid = wps[math.ceil(#wps/2)]
    return fmt(wps[1]).."|"..fmt(mid).."|"..fmt(wps[#wps])
end

--------------------------------------------------------------------------------
-- VEHICLE HELPERS
--------------------------------------------------------------------------------

local function getVehicle()
    local char = player.Character; if not char then return nil end
    local tag = char:FindFirstChild("Vehicle_TruFleet City Taxi"); if not tag then return nil end
    local m = tag.Parent
    return (m and m.PrimaryPart) and m or nil
end

local function isSeated() return getVehicle() ~= nil end

--------------------------------------------------------------------------------
-- TAXI ENTRY
--------------------------------------------------------------------------------

local TAXI_SPAWN = Vector3.new(142, 0, 88)
local interactUI = player.PlayerGui:WaitForChild("_interactUI", 5)
local indicator  = interactUI and interactUI:WaitForChild("InteractIndicator", 2)
local tapButton  = indicator  and indicator:WaitForChild("TapButton", 2)

local function physicalTap(obj)
    if obj and obj.AbsolutePosition then
        local x = obj.AbsolutePosition.X + (obj.AbsoluteSize.X / 2)
        local y = obj.AbsolutePosition.Y + (obj.AbsoluteSize.Y / 2) + 36
        VIM:SendMouseButtonEvent(x, y, 0, true,  game, 0); task.wait(0.02)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end
end

local function pressInteract()
    VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game); task.wait(0.01)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    if indicator and (indicator.Visible or (tapButton and tapButton.Visible)) then
        pcall(function()
            physicalTap(tapButton)
            for _, c in ipairs(getconnections(tapButton.MouseButton1Click)) do c:Fire() end
        end)
    end
end

local function findTaxiModel(root)
    local env    = workspace:FindFirstChild("Environment")
    local stands = env and env:FindFirstChild("TaxiStands")
    if stands then
        local direct = stands:FindFirstChild("Taxi")
        if direct and direct:IsA("Model") then return direct end
        for _, v in ipairs(stands:GetChildren()) do if v:IsA("Model") then return v end end
    end
    return nil
end

local function tryEnterTaxi()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or isSeated() then return end

    hum:MoveTo(TAXI_SPAWN)
    task.wait(2)

    local taxiModel = findTaxiModel(root)
    if not taxiModel then return end

    local entryDeadline = tick() + 10
    while not isSeated() and tick() < entryDeadline do
        pressInteract()
        task.wait(0.1)
    end
end

--------------------------------------------------------------------------------
-- DRIVE CORE (7.1 Logic + UI Hooks)
--------------------------------------------------------------------------------

local globalRerouteLock  = false
local lastRerouteTime    = 0
local REROUTE_COOLDOWN   = 2.0   
local MAX_REROUTES       = 8     

local function drive(vehicle, waypoints, goalPos, onDone, rerouteHistory, rerouteCount)
    rerouteHistory = rerouteHistory or {}
    rerouteCount   = rerouteCount   or 0

    local p  = vehicle.PrimaryPart
    local lv = initPhysics(vehicle)
    if not lv then onDone(); return end

    local bg        = p:FindFirstChild("TaxiBG")
    local wpIndex   = 1
    local startTime = tick()
    local lastWallCheck  = 0
    local lastCloseCheck = 0
    local rerouting = false
    smoothV = 0

    local stuckUpdate, setNudging = makeStuck(p)
    local nudgeDir, nudgeUntil = nil, 0

    local function doReroute(reason)
        if rerouting or globalRerouteLock or tick() - lastRerouteTime < REROUTE_COOLDOWN then return end
        if rerouteCount >= MAX_REROUTES then
            lv.VectorVelocity = Vector3.new(0,0,0)
            globalRerouteLock = false
            onDone(); return
        end

        rerouting = true
        globalRerouteLock = true
        lastRerouteTime = tick()
        lv.VectorVelocity = Vector3.new(0, 0, 0)

        task.spawn(function()
            task.wait(0.3)
            local openStart = findOpenStartPos(p, vehicle, goalPos, 8)
            local newWPs = computeWaypoints(openStart, goalPos)
            
            globalRerouteLock = false
            if not newWPs then onDone() else
                drive(vehicle, newWPs, goalPos, onDone, rerouteHistory, rerouteCount + 1)
            end
        end)
    end

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        -- UI CHECK: If toggle is off, kill physics and disconnect
        if _G.TaxiToggle == false then
            if lv then lv.VectorVelocity = Vector3.new(0,0,0) end
            local parts = {"TaxiLV", "TaxiBG", "TaxiAtt"}
            for _, n in ipairs(parts) do if p:FindFirstChild(n) then p[n]:Destroy() end end
            conn:Disconnect()
            onDone()
            return
        end

        if tick() - startTime > CFG.DRIVE_TIMEOUT or not isSeated() then
            conn:Disconnect(); onDone(); return
        end

        while wpIndex <= #waypoints do
            local wp = waypoints[wpIndex]
            local d  = Vector3.new(p.Position.X - wp.X, 0, p.Position.Z - wp.Z).Magnitude
            if d <= CFG.WP_REACH then wpIndex = wpIndex + 1 else break end
        end

        if wpIndex > #waypoints then
            conn:Disconnect(); onDone(); return
        end

        local targetWP = waypoints[wpIndex]
        local lookWP   = waypoints[math.min(wpIndex + CFG.LOOK_WP, #waypoints)]
        local faceDir  = (Vector3.new(lookWP.X - p.Position.X, 0, lookWP.Z - p.Position.Z)).Unit

        if not rerouting then
            local now = tick()
            if now - lastWallCheck > CFG.WALL_RECHECK then
                lastWallCheck = now
                if fanScan(p, vehicle, faceDir, CFG.WALL_DIST) then
                    conn:Disconnect(); doReroute("Fan Hit"); return
                end
            end
            if now - lastCloseCheck > CFG.CLOSE_RECHECK then
                lastCloseCheck = now
                if closeObstacleAhead(p, vehicle, faceDir, CFG.CLOSE_DIST) then
                    conn:Disconnect(); doReroute("Close Hit"); return
                end
            end
        end

        local isStuck, stuckDir = stuckUpdate(dt)
        if isStuck then nudgeDir = stuckDir; nudgeUntil = tick() + CFG.NUDGE_DUR end

        local hDir = (nudgeDir and tick() < nudgeUntil) and nudgeDir or (Vector3.new(targetWP.X - p.Position.X, 0, targetWP.Z - p.Position.Z)).Unit
        local vv = hoverVel(p, vehicle)
        
        -- DYNAMIC SPEED FROM UI
        local driveSpeed = _G.TaxiFarmSpeed or 36
        lv.VectorVelocity = Vector3.new(hDir.X * driveSpeed, vv, hDir.Z * driveSpeed)

        p.CFrame = p.CFrame:Lerp(CFrame.new(p.Position, p.Position + Vector3.new(hDir.X, 0, hDir.Z)), 0.15)
    end)
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

task.spawn(function()
    while true do
        task.wait(CFG.LOOP_INTERVAL)
        if _G.TaxiToggle == true then
            if not isSeated() then
                tryEnterTaxi()
            else
                local vehicle = getVehicle()
                local zone = workspace:FindFirstChild("TaxiZone")
                if vehicle and zone then
                    local goalPos = zone:IsA("Model") and zone:GetPivot().Position or zone.Position
                    local wps = computeWaypoints(vehicle.Position, goalPos)
                    if wps then
                        local done = false
                        drive(vehicle.Parent, wps, goalPos, function() done = true end)
                        repeat task.wait(0.5) until done or _G.TaxiToggle == false
                    end
                end
            end
        end
    end
end)
