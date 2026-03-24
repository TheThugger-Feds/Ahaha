local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local PFS = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")

local Environment = workspace:WaitForChild("Environment", 15)
local taxiStands = Environment and Environment:WaitForChild("TaxiStands", 15)

local HOVER_STIFFNESS = 50
local HOVER_DAMPING = 32
local MIN_SAFE_Y = -50

local CFG = {
    HOVER_OFFSET      = _G.TaxiHoverOffset    or 3.2,
    HOVER_SMOOTH      = 0.10,
    WP_REACH          = 6.0,
    LOOK_WP           = 2,
    WALL_DIST         = 8,
    WALL_RECHECK      = 0.6,
    CLOSE_DIST        = 3,
    CLOSE_RECHECK     = 0.05,
    STUCK_TIME        = _G.TaxiStuckTime      or 3.0,
    STUCK_VEL         = _G.TaxiStuckVel       or 2.0,
    STUCK_DIST        = 1.5,
    NUDGE_DUR         = 1.2,
    PATH_RETRIES      = 4,
    DRIVE_TIMEOUT     = _G.TaxiDriveTimeout   or 40,
    LOOP_INTERVAL     = 1.5,
    TAXI_SEARCH_R     = 100,
    TAXI_MIN_DOT      = 0.0,
    TOGGLE_COOLDOWN   = 5.0,
    ORIENT_TWEEN_TIME = 0.18,
    SWEEP_INTERVAL    = _G.TaxiSweepInterval  or 0.04,
    SWEEP_COUNT       = 6,
    SWEEP_HALF_ARC    = 55,
    SWEEP_RANGE       = _G.TaxiSweepRange     or 9,
    DCLICK_WINDOW     = 0.45,
}

local farmActive = false
local globalRerouteLock = false
local lastRerouteTime = 0
local REROUTE_COOLDOWN = 2.0
local MAX_REROUTES = 8

local function syncCFG()
    if _G.TaxiHoverOffset   then CFG.HOVER_OFFSET    = _G.TaxiHoverOffset   end
    if _G.TaxiStuckTime     then CFG.STUCK_TIME       = _G.TaxiStuckTime     end
    if _G.TaxiStuckVel      then CFG.STUCK_VEL        = _G.TaxiStuckVel      end
    if _G.TaxiDriveTimeout  then CFG.DRIVE_TIMEOUT    = _G.TaxiDriveTimeout  end
    if _G.TaxiSweepInterval then CFG.SWEEP_INTERVAL   = _G.TaxiSweepInterval end
    if _G.TaxiSweepRange    then CFG.SWEEP_RANGE      = _G.TaxiSweepRange    end
end

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
    bg.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
    bg.P = 8000
    bg.D = 600
    bg.CFrame = CFrame.new(p.Position)

    return lv
end

local function cleanupPhysics(p)
    if not p then return end
    for _, n in ipairs({"TaxiLV", "TaxiBG", "TaxiAtt"}) do
        local obj = p:FindFirstChild(n)
        if obj then obj:Destroy() end
    end
end

local function sampleGround(p, vehicle)
    local offsets = {
        Vector3.new(0, 0, 0),
        Vector3.new(3, 0, 4),
        Vector3.new(-3, 0, 4),
        Vector3.new(3, 0, -4),
        Vector3.new(-3, 0, -4),
    }
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local total, count = 0, 0
    for _, o in ipairs(offsets) do
        local r = workspace:Raycast(p.Position + Vector3.new(o.X, 1.5, o.Z), Vector3.new(0, -16, 0), params)
        if r then total = total + r.Position.Y; count = count + 1 end
    end
    return count > 0 and (total / count) or nil
end

local smoothV = 0
local function hoverVel(p, vehicle)
    if p.Position.Y < MIN_SAFE_Y then smoothV = 30; return 30 end
    local g = sampleGround(p, vehicle)
    local raw = -4
    if g then
        local err = (g + CFG.HOVER_OFFSET) - p.Position.Y
        local airborne = err < -3.5
        local ks = airborne and HOVER_STIFFNESS * 2 or HOVER_STIFFNESS
        local kd = airborne and HOVER_DAMPING * 1.6 or HOVER_DAMPING
        raw = math.clamp(err * ks - p.AssemblyLinearVelocity.Y * kd, -35, 35)
    end
    smoothV = smoothV + (raw - smoothV) * CFG.HOVER_SMOOTH
    return smoothV
end

local currentOrientTween = nil
local function tweenOrientation(p, bg, targetDir)
    if not bg or targetDir.Magnitude < 0.01 then return end
    if currentOrientTween then
        currentOrientTween:Cancel()
        currentOrientTween = nil
    end
    local targetCF = CFrame.lookAt(p.Position, p.Position + targetDir)
    local tweenInfo = TweenInfo.new(CFG.ORIENT_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    currentOrientTween = TweenService:Create(bg, tweenInfo, {CFrame = targetCF})
    currentOrientTween:Play()
end

local lastSweepTime = 0
local function dualSweepScan(p, vehicle, faceDir, maxDist)
    if faceDir.Magnitude < 0.01 then return nil, nil end
    local now = tick()
    if now - lastSweepTime < CFG.SWEEP_INTERVAL then return nil, nil end
    lastSweepTime = now

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local origin = p.Position + Vector3.new(0, 1.2, 0)
    local fwd = faceDir.Unit
    local right = Vector3.new(fwd.Z, 0, -fwd.X)

    local minDist, hitSide = nil, nil

    for i = 0, CFG.SWEEP_COUNT do
        local fraction = i / CFG.SWEEP_COUNT
        local deg = fraction * CFG.SWEEP_HALF_ARC

        local radL = math.rad(deg)
        local dirL = (fwd * math.cos(radL) - right * math.sin(radL)).Unit
        local hitL = workspace:Raycast(origin, dirL * maxDist, params)

        local radR = math.rad(-deg)
        local dirR = (fwd * math.cos(radR) - right * math.sin(radR)).Unit
        local hitR = workspace:Raycast(origin, dirR * maxDist, params)

        if hitL and (not minDist or hitL.Distance < minDist) then
            minDist = hitL.Distance
            hitSide = deg == 0 and "centre" or "left"
        end
        if hitR and (not minDist or hitR.Distance < minDist) then
            minDist = hitR.Distance
            hitSide = "right"
        end
    end

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
    local right = Vector3.new(faceDir.Z, 0, -faceDir.X)
    local fwd = faceDir.Unit
    for _, deg in ipairs({0, 10, -10, 20, -20}) do
        local rad = math.rad(deg)
        local d = (fwd * math.cos(rad) + right * math.sin(rad)).Unit
        if castRay(origin, d, dist, vehicle) then return true end
    end
    return false
end

local function findOpenStartPos(p, vehicle, goalPos, minClearance)
    minClearance = minClearance or 6
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local toGoal = goalPos and Vector3.new(goalPos.X - p.Position.X, 0, goalPos.Z - p.Position.Z) or nil
    local goalDir = (toGoal and toGoal.Magnitude > 1) and toGoal.Unit or Vector3.new(0, 0, -1)

    local bestDir, bestScore = nil, -math.huge

    for i = 0, 23 do
        local rad = math.rad(i * 15)
        local dir = Vector3.new(math.sin(rad), 0, math.cos(rad))
        local origin = p.Position + Vector3.new(0, 1.2, 0)
        local hit = workspace:Raycast(origin, dir * 32, params)
        local clearDist = 32

        if hit then
            if hit.Normal.Y > 0.7 then clearDist = 32 else clearDist = hit.Distance end
        end

        if clearDist >= minClearance then
            local goalDot = dir:Dot(goalDir)
            local score = clearDist + goalDot * 18
            if score > bestScore then
                bestScore = score
                bestDir = dir
            end
        end
    end

    if not bestDir then
        local perp = Vector3.new(-goalDir.Z, 0, goalDir.X)
        return p.Position + perp * 4
    end

    local hit2 = workspace:Raycast(p.Position + Vector3.new(0, 1.2, 0), bestDir * 32, params)
    local maxStep = (hit2 and hit2.Normal.Y <= 0.7) and hit2.Distance * 0.6 or 10
    return p.Position + bestDir * math.min(maxStep, 10)
end

local function cleanWaypoints(pts)
    if #pts < 2 then return pts end

    local deduped = {pts[1]}
    for i = 2, #pts do
        local prev = deduped[#deduped]
        local xzDist = Vector3.new(pts[i].X - prev.X, 0, pts[i].Z - prev.Z).Magnitude
        if xzDist > 1.5 then table.insert(deduped, pts[i]) end
    end

    local changed = true
    local passes = 0
    local cleaned = deduped
    while changed and passes < 6 do
        changed = false
        passes = passes + 1
        local out = {cleaned[1]}
        local i = 2
        while i <= #cleaned do
            local prev = out[#out]
            local curr = cleaned[i]
            local next = cleaned[i + 1]
            if next then
                local d1 = Vector3.new(curr.X - prev.X, 0, curr.Z - prev.Z)
                local d2 = Vector3.new(next.X - curr.X, 0, next.Z - curr.Z)
                if d1.Magnitude > 0.5 and d2.Magnitude > 0.5 then
                    if (d1.Unit):Dot(d2.Unit) < -0.3 then
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

local function catmullRomPoint(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2*p0 - 5*p1 + 4*p2 - p3) * t2 +
        (-p0 + 3*p1 - 3*p2 + p3) * t3
    )
end

local function smoothWaypoints(pts, steps)
    if #pts < 4 then return pts end
    steps = steps or 4
    local out = {}
    for i = 1, #pts - 1 do
        local p0 = pts[math.max(i - 1, 1)]
        local p1 = pts[i]
        local p2 = pts[i + 1]
        local p3 = pts[math.min(i + 2, #pts)]
        table.insert(out, p1)
        for s = 1, steps - 1 do
            local t = s / steps
            local sp = catmullRomPoint(p0, p1, p2, p3, t)
            table.insert(out, Vector3.new(sp.X, p1.Y, sp.Z))
        end
    end
    table.insert(out, pts[#pts])
    return out
end

local function makeStuck(p)
    local lastPos = p.Position
    local timer = 0
    local nudging = false

    local function update(dt)
        if nudging then return false, nil end
        local hv = Vector3.new(p.AssemblyLinearVelocity.X, 0, p.AssemblyLinearVelocity.Z).Magnitude
        local dist = (p.Position - lastPos).Magnitude
        if hv < CFG.STUCK_VEL and dist < CFG.STUCK_DIST then
            timer = timer + dt
        else
            timer = 0
            lastPos = p.Position
        end
        if timer >= CFG.STUCK_TIME then
            timer = 0
            lastPos = p.Position
            local best, bestD = Vector3.new(0, 0, 1), 0
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {player.Character}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            for a = 0, 315, 45 do
                local d = Vector3.new(math.sin(math.rad(a)), 0, math.cos(math.rad(a)))
                local h = workspace:Raycast(p.Position, d * 22, rp)
                local cd = h and h.Distance or 22
                if cd > bestD then bestD = cd; best = d end
            end
            nudging = true
            return true, best
        end
        return false, nil
    end

    return update, function(v) nudging = v end
end

local function computeWaypoints(fromPos, toPos)
    local jitter = {
        Vector3.new(0, -1.8, 0),
        Vector3.new(3, -1.8, 0),
        Vector3.new(-3, -1.8, 0),
        Vector3.new(0, -1.8, 3),
        Vector3.new(0, -1.8, -3),
        Vector3.new(5, -1.8, 5),
        Vector3.new(-5, -1.8, -5),
    }

    local agentSizes = {
        {AgentRadius = 10, AgentCanJump = false},
        {AgentRadius = 6, AgentCanJump = false},
        {AgentRadius = 4, AgentCanJump = false},
    }

    for _, agentCfg in ipairs(agentSizes) do
        for i = 1, math.min(CFG.PATH_RETRIES, #jitter) do
            local path = PFS:CreatePath(agentCfg)
            local target = toPos + (jitter[i] or Vector3.new())
            local ok, _ = pcall(function()
                path:ComputeAsync(fromPos, target)
            end)
            if ok and path.Status == Enum.PathStatus.Success then
                local pts = {}
                for _, w in ipairs(path:GetWaypoints()) do
                    table.insert(pts, w.Position)
                end
                pts = cleanWaypoints(pts)
                pts = smoothWaypoints(pts, 4)
                if #pts >= 2 then return pts end
            end
            task.wait(0.15)
        end
    end
    return nil
end

local function getVehicle()
    local char = player.Character
    if not char then return nil end
    local tag = char:FindFirstChild("Vehicle_TruFleet City Taxi")
    if not tag then return nil end
    local m = tag.Parent
    return (m and m.PrimaryPart) and m or nil
end

local function isSeated()
    return getVehicle() ~= nil
end

local TAXI_SPAWN = Vector3.new(142, 0, 88)

local function modelDoubleClick(model)
    if not model or not model.PrimaryPart then return end
    local sp = camera:WorldToScreenPoint(model.PrimaryPart.Position)
    local sx = math.floor(sp.X)
    local sy = math.floor(sp.Y)

    local function singleClick()
        VIM:SendMouseButtonEvent(sx, sy, 0, true, game, 0)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(sx, sy, 0, false, game, 0)
    end

    singleClick()
    task.wait(CFG.DCLICK_WINDOW * 0.5)
    singleClick()
end

local function findTaxiModel()
    local env = workspace:FindFirstChild("Environment")
    local stands = env and env:FindFirstChild("TaxiStands")
    if stands then
        local direct = stands:FindFirstChild("Taxi")
        if direct and direct:IsA("Model") then return direct end
        for _, v in ipairs(stands:GetChildren()) do
            if v:IsA("Model") then return v end
        end
    end
    return nil
end

local function tryEnterTaxi()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or isSeated() then return end

    hum:MoveTo(TAXI_SPAWN + Vector3.new(4, 0, 4))
    task.wait(1.5)

    local taxi = findTaxiModel()
    if not taxi then return end

    local deadline = tick() + 8
    while not isSeated() and tick() < deadline do
        modelDoubleClick(taxi)
        task.wait(0.35)
        if isSeated() then break end
    end
end

local function drive(vehicle, waypoints, goalPos, onDone, rerouteCount)
    rerouteCount = rerouteCount or 0

    local p = vehicle.PrimaryPart
    if not p then onDone(); return end

    local lv = initPhysics(vehicle)
    if not lv then onDone(); return end

    local bg = p:FindFirstChild("TaxiBG")
    local wpIndex = 1
    local startTime = tick()
    local lastWallCheck = 0
    local lastCloseCheck = 0
    local rerouting = false
    smoothV = 0

    local stuckUpdate, setNudging = makeStuck(p)
    local nudgeDir, nudgeUntil = nil, 0

    local function doReroute()
        if rerouting or globalRerouteLock then return end
        if tick() - lastRerouteTime < REROUTE_COOLDOWN then return end
        if rerouteCount >= MAX_REROUTES then
            cleanupPhysics(p)
            globalRerouteLock = false
            onDone()
            return
        end

        rerouting = true
        globalRerouteLock = true
        lastRerouteTime = tick()
        lv.VectorVelocity = Vector3.new(0, 0, 0)
        if currentOrientTween then currentOrientTween:Cancel(); currentOrientTween = nil end

        task.spawn(function()
            task.wait(0.3)
            local newWPs = computeWaypoints(p.Position, goalPos)
            if not newWPs then
                local openStart = findOpenStartPos(p, vehicle, goalPos, 8)
                newWPs = computeWaypoints(openStart, goalPos)
            end
            globalRerouteLock = false
            if not newWPs then
                cleanupPhysics(p)
                onDone()
            else
                drive(vehicle, newWPs, goalPos, onDone, rerouteCount + 1)
            end
        end)
    end

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        syncCFG()

        if not _G.TaxiToggle then
            conn:Disconnect()
            cleanupPhysics(p)
            onDone()
            return
        end

        if tick() - startTime > CFG.DRIVE_TIMEOUT or not isSeated() then
            conn:Disconnect()
            cleanupPhysics(p)
            onDone()
            return
        end

        if rerouting then return end

        while wpIndex <= #waypoints do
            local wp = waypoints[wpIndex]
            local d = Vector3.new(p.Position.X - wp.X, 0, p.Position.Z - wp.Z).Magnitude
            if d <= CFG.WP_REACH then wpIndex = wpIndex + 1 else break end
        end

        if wpIndex > #waypoints then
            conn:Disconnect()
            cleanupPhysics(p)
            onDone()
            return
        end

        local targetWP = waypoints[wpIndex]
        local lookWP = waypoints[math.min(wpIndex + CFG.LOOK_WP, #waypoints)]
        local rawFace = Vector3.new(lookWP.X - p.Position.X, 0, lookWP.Z - p.Position.Z)
        local faceDir = rawFace.Magnitude > 0.01 and rawFace.Unit or Vector3.new(0, 0, 1)

        local now = tick()

        local sweepDist, _ = dualSweepScan(p, vehicle, faceDir, CFG.SWEEP_RANGE)
        if sweepDist and sweepDist < CFG.SWEEP_RANGE then
            conn:Disconnect()
            doReroute()
            return
        end

        if now - lastWallCheck > CFG.WALL_RECHECK then
            lastWallCheck = now
            local wd, _ = dualSweepScan(p, vehicle, faceDir, CFG.WALL_DIST)
            if wd and wd < CFG.WALL_DIST then
                conn:Disconnect()
                doReroute()
                return
            end
        end

        if now - lastCloseCheck > CFG.CLOSE_RECHECK then
            lastCloseCheck = now
            if closeObstacleAhead(p, vehicle, faceDir, CFG.CLOSE_DIST) then
                conn:Disconnect()
                doReroute()
                return
            end
        end

        local isStuck, stuckDir = stuckUpdate(dt)
        if isStuck then
            nudgeDir = stuckDir
            nudgeUntil = tick() + CFG.NUDGE_DUR
            setNudging(false)
        end

        local useNudge = nudgeDir and tick() < nudgeUntil
        local hDir = useNudge and nudgeDir or Vector3.new(targetWP.X - p.Position.X, 0, targetWP.Z - p.Position.Z).Unit
        local vv = hoverVel(p, vehicle)
        local speed = _G.TaxiFarmSpeed or 36

        lv.VectorVelocity = Vector3.new(hDir.X * speed, vv, hDir.Z * speed)
        tweenOrientation(p, bg, faceDir)
    end)
end

task.spawn(function()
    local toggleCooldown = 0
    local lastToggle = nil

    while true do
        task.wait(1.5)

        local now = tick()
        local wantsOn = _G.TaxiToggle == true
        local cooldownOk = now - toggleCooldown > 5.0

        if wantsOn ~= lastToggle then
            if cooldownOk or lastToggle == nil then
                lastToggle = wantsOn
                toggleCooldown = now
                farmActive = wantsOn
            else
                _G.TaxiToggle = lastToggle
                continue
            end
        end

        if not farmActive then continue end

        if not isSeated() then
            tryEnterTaxi()
            task.wait(1)
            continue
        end

        local vehicle = getVehicle()
        if not vehicle or not vehicle.PrimaryPart then continue end

        local zone = workspace:FindFirstChild("TaxiZone")
        if not zone then continue end

        local goalPos
        if zone:IsA("Model") then
            goalPos = zone:GetPivot().Position
        elseif zone:IsA("BasePart") then
            goalPos = zone.Position
        else
            continue
        end

        local fromPos = vehicle.PrimaryPart.Position
        local wps = computeWaypoints(fromPos, goalPos)
        if not wps then continue end

        local done = false
        drive(vehicle, wps, goalPos, function() done = true end, 0)

        while not done do
            task.wait(0.3)
            if not _G.TaxiToggle then done = true end
        end

        task.wait(1)
    end
end)
