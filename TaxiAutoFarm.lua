-- TaxiBot v7.1 | Smart Reroute | Open-Side Start | Close Obstacle Check | Clean Waypoints | Wide Taxi Search
-- FIXES v7.1:
--   1. Smart reroute: scans 8 directions, picks most open side, starts reroute FROM there
--   2. Close obstacle check: 3-stud forward raycast triggers reroute before car hits anything
--   3. Waypoint cleanup: removes zigzags, duplicate points, and random shape detours
--   4. Taxi search: widened cone to 180° and scans all workspace descendants so nearby taxis are always found

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
    DRIVE_SPEED    = 36,
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
-- Two rays start from centre, one fans left and one fans right simultaneously,
-- creating a scanning sweep effect that repeats every frame.
-- scanAngle advances each call so rays alternate left/right over time.
-- Returns: hit distance (nil = clear), which side hit first ("left"/"right"/nil)
--------------------------------------------------------------------------------

local scanAngle = 0   -- advances each call, creates the sweep animation

local function fanScan(p, vehicle, faceDir, maxDist)
    if faceDir.Magnitude < 0.01 then return nil, nil end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local origin = p.Position + Vector3.new(0, 1.2, 0)
    local right  = Vector3.new(faceDir.Z, 0, -faceDir.X)
    local fwd    = faceDir.Unit

    -- Advance sweep angle (0→40° and back, cycling)
    -- This makes the two beams visibly sweep outward from centre
    scanAngle = (scanAngle + 8) % 82   -- 0-80° range, wraps
    local halfAngle = math.min(scanAngle, 80 - scanAngle) * 0.5 + 2  -- 2°-22° sweep

    -- LEFT beam: fwd rotated +halfAngle
    local lRad   = math.rad(halfAngle)
    local leftDir = (fwd * math.cos(lRad) - right * math.sin(lRad)).Unit

    -- RIGHT beam: fwd rotated -halfAngle
    local rRad    = math.rad(-halfAngle)
    local rightDir = (fwd * math.cos(rRad) - right * math.sin(rRad)).Unit

    -- Centre beam always fires too
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

-- Simple single-direction check used for the close (3-stud) alarm
local function castRay(origin, dir, dist, vehicle)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {vehicle, player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    return workspace:Raycast(origin, dir.Unit * dist, params)
end

-- Close-range check: 5 rays in a tight 30° cone directly ahead
local function closeObstacleAhead(p, vehicle, faceDir, dist)
    if faceDir.Magnitude < 0.01 then return false end
    local origin = p.Position + Vector3.new(0, 1.2, 0)
    local right  = Vector3.new(faceDir.Z, 0, -faceDir.X)
    local fwd    = faceDir.Unit
    -- 5 rays: centre, ±10°, ±20° — catches thin poles/signs at close range
    for _, deg in ipairs({0, 10, -10, 20, -20}) do
        local rad = math.rad(deg)
        local d   = (fwd * math.cos(rad) + right * math.sin(rad)).Unit
        if castRay(origin, d, dist, vehicle) then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- OPEN SIDE FINDER  (16-direction scan, goal-biased, ignores ground hits)
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

    -- 16-direction scan (22.5° steps) for finer resolution than 8-dir
    for i = 0, 15 do
        local rad       = math.rad(i * 22.5)
        local dir       = Vector3.new(math.sin(rad), 0, math.cos(rad))
        local origin    = p.Position + Vector3.new(0, 1.2, 0)
        local hit       = workspace:Raycast(origin, dir * 32, params)
        local clearDist = 32

        if hit then
            -- Ignore pure ground hits (normal pointing mostly up)
            if hit.Normal.Y > 0.7 then
                clearDist = 32   -- ground hit = treat as clear
            else
                clearDist = hit.Distance
            end
        end

        if clearDist >= minClearance then
            local goalDot = dir:Dot(goalDir)
            local score   = clearDist + goalDot * 12  -- bias toward goal
            if score > bestScore then
                bestScore = score
                bestDir   = dir
            end
        end
    end

    if not bestDir then
        -- Truly boxed in — back up a tiny bit perpendicular to goal
        local perp = Vector3.new(-goalDir.Z, 0, goalDir.X)
        return p.Position + perp * 4
    end

    local hit2    = workspace:Raycast(p.Position + Vector3.new(0,1.2,0), bestDir*32, params)
    local maxStep = (hit2 and hit2.Normal.Y <= 0.7) and hit2.Distance * 0.6 or 10
    return p.Position + bestDir * math.min(maxStep, 10)
end

--------------------------------------------------------------------------------
-- WAYPOINT CLEANUP
-- Removes: duplicates, near-duplicates, zigzags (>120° direction change)
-- This kills the "random shapes" caused by PFS inserting detour points
--------------------------------------------------------------------------------

local function cleanWaypoints(pts)
    if #pts < 2 then return pts end

    -- Pass 1: remove near-duplicate points (< 1.5 studs apart in XZ)
    local deduped = { pts[1] }
    for i = 2, #pts do
        local prev = deduped[#deduped]
        local xzDist = Vector3.new(pts[i].X - prev.X, 0, pts[i].Z - prev.Z).Magnitude
        if xzDist > 1.5 then
            table.insert(deduped, pts[i])
        end
    end

    -- Pass 2: remove zigzag points (direction reverses > 120°)
    -- Run multiple passes until stable
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
                    -- dot < -0.3 = more than ~107° turn = zigzag detour, remove point
                    if dot < -0.3 then
                        changed = true
                        i = i + 1  -- skip curr
                        continue
                    end
                end
            end
            table.insert(out, curr)
            i = i + 1
        end
        cleaned = out
    end

    -- Always keep the last point (destination)
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
-- PATH COMPUTE  (from a specific start position, with waypoint cleanup)
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
            print("[TaxiBot] Path OK attempt", i, "| waypoints after clean:", #pts)
            return pts
        end
        warn("[TaxiBot] Path attempt", i, "failed:", tostring(err or path.Status))
        task.wait(0.2)
    end
    return nil
end

--------------------------------------------------------------------------------
-- REROUTE KEY (for dedup tracking)
--------------------------------------------------------------------------------

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
-- TAXI ENTRY  (walk to X=142 Z=88, find "Taxi" in Environment/TaxiStands, interact)
--------------------------------------------------------------------------------

local TAXI_SPAWN = Vector3.new(142, 0, 88)

-- Interact UI refs (used by the interact loop below)
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

-- Fires E key + taps interact button once
local function pressInteract()
    VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game); task.wait(0.01)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    if indicator and (indicator.Visible or (tapButton and tapButton.Visible)) then
        pcall(function()
            physicalTap(tapButton)
            for _, c in ipairs(getconnections(tapButton.MouseButton1Click)) do
                c:Fire()
            end
        end)
    end
end

-- Finds the "Taxi" model inside Environment/TaxiStands (exact match preferred,
-- then any child named "Taxi"). Falls back to nearest taxi-named model anywhere.
local function findTaxiModel(root)
    -- Priority 1: Environment > TaxiStands > model literally named "Taxi"
    local env    = workspace:FindFirstChild("Environment")
    local stands = env and env:FindFirstChild("TaxiStands")
    if stands then
        local direct = stands:FindFirstChild("Taxi")
        if direct and direct:IsA("Model") then return direct end
        -- Any child of TaxiStands
        for _, v in ipairs(stands:GetChildren()) do
            if v:IsA("Model") then return v end
        end
    end

    -- Priority 2: nearest taxi-named model with an unanchored part (real car)
    local bestModel, bestDist = nil, math.huge
    local function scan(obj, depth)
        if depth > 4 then return end
        for _, v in ipairs(obj:GetChildren()) do
            if v:IsA("Model") then
                local n = v.Name:lower()
                if (n == "taxi" or n:find("trufleet") or n:find("cab"))
                and not (n:find("stand") or n:find("shelter") or n:find("stop") or n:find("zone") or n:find("dispatch")) then
                    local hasMover = false
                    for _, d in ipairs(v:GetDescendants()) do
                        if d:IsA("BasePart") and not d.Anchored then hasMover = true; break end
                    end
                    if hasMover then
                        local d = (v:GetPivot().Position - root.Position).Magnitude
                        if d < bestDist then bestDist = d; bestModel = v end
                    end
                end
                scan(v, depth + 1)
            elseif v:IsA("Folder") then
                scan(v, depth + 1)
            end
        end
    end
    scan(workspace, 0)
    return bestModel
end

local function tryEnterTaxi()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or isSeated() then return end

    -- Resolve Y at spawn coords
    local spawnY   = root.Position.Y
    local rp       = RaycastParams.new()
    rp.FilterType  = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {player.Character}
    local gHit = workspace:Raycast(Vector3.new(TAXI_SPAWN.X, 500, TAXI_SPAWN.Z), Vector3.new(0,-600,0), rp)
    if gHit then spawnY = gHit.Position.Y + 3 end
    local walkTarget = Vector3.new(TAXI_SPAWN.X, spawnY, TAXI_SPAWN.Z)

    -- Walk to spawn
    print("[TaxiBot] Walking to taxi spawn (142, 88)...")
    local walkDeadline = tick() + 20
    while not isSeated() and tick() < walkDeadline do
        local xzDist = Vector3.new(root.Position.X - walkTarget.X, 0, root.Position.Z - walkTarget.Z).Magnitude
        if xzDist <= 4 then break end
        hum:MoveTo(walkTarget)
        task.wait(0.15)
    end

    if isSeated() then return end

    local taxiModel = findTaxiModel(root)
    if not taxiModel then print("[TaxiBot] No taxi model found"); return end
    print("[TaxiBot] Found taxi:", taxiModel.Name)

    -- Interact loop: runs until seated (max 12s)
    -- Presses E + taps mobile button every 0.1s, double-taps screen on mobile
    print("[TaxiBot] Pressing interact...")
    local entryDeadline = tick() + 12
    while not isSeated() and tick() < entryDeadline do
        pressInteract()

        -- Also tap the taxi's screen position (double-tap for mobile)
        local sp, onScreen = camera:WorldToScreenPoint(taxiModel:GetPivot().Position)
        if onScreen then
            VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, true,  game, 0); task.wait(0.03)
            VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, false, game, 0); task.wait(0.03)
            VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, true,  game, 0); task.wait(0.03)
            VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, false, game, 0)
        end

        task.wait(0.1)
    end

    print(isSeated() and "[TaxiBot] Seated!" or "[TaxiBot] Could not enter taxi")
end

--------------------------------------------------------------------------------
-- DRIVE  (two-tier obstacle check, smart open-side reroute, dedup)
--------------------------------------------------------------------------------

-- GLOBAL reroute lock: only ONE reroute can be in-flight at a time across all
-- recursive drive() calls. This is what caused the x217/x659 loop — each
-- heartbeat was spawning a new reroute before the previous one finished.
local globalRerouteLock  = false
local lastRerouteTime    = 0
local REROUTE_COOLDOWN   = 2.0   -- seconds between reroutes
local MAX_REROUTES       = 8     -- hard cap per drive session before giving up

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

    -- Smart reroute: finds open side, starts path from there
    local function doReroute(reason)
        -- Hard guards: local flag, global lock, cooldown, max cap
        if rerouting then return end
        if globalRerouteLock then return end
        if tick() - lastRerouteTime < REROUTE_COOLDOWN then return end
        if rerouteCount >= MAX_REROUTES then
            warn("[TaxiBot] Max reroutes ("..MAX_REROUTES..") hit — restarting path from main loop")
            lv.VectorVelocity = Vector3.new(0,0,0)
            globalRerouteLock = false
            onDone(); return
        end

        rerouting        = true
        globalRerouteLock = true
        lastRerouteTime  = tick()
        lv.VectorVelocity = Vector3.new(0, 0, 0)

        task.spawn(function()
            task.wait(0.3)   -- slightly longer wait so car stops before repathing
            warn("[TaxiBot]", reason, "— smart reroute #"..(rerouteCount+1))

            -- Find the most open side that still faces roughly toward the goal
            local openStart = findOpenStartPos(p, vehicle, goalPos, 8)
            local fromPos   = openStart

            local function tryFromPos(start, extraGoalOffset)
                local dest = goalPos + (extraGoalOffset or Vector3.new())
                local path = PFS:CreatePath({AgentRadius=10, AgentCanJump=false})
                local ok   = pcall(function() path:ComputeAsync(start, dest) end)
                if ok and path.Status == Enum.PathStatus.Success then
                    local pts = {}
                    for _, w in ipairs(path:GetWaypoints()) do table.insert(pts, w.Position) end
                    pts = cleanWaypoints(pts)
                    if #pts > 1 then return pts end
                end
                return nil
            end

            -- Try from open position first, then fall back to current pos
            local newWPs = tryFromPos(fromPos)
                        or tryFromPos(p.Position)
                        or tryFromPos(p.Position, Vector3.new(5,-1.8,0))
                        or tryFromPos(p.Position, Vector3.new(-5,-1.8,0))

            if not newWPs then
                warn("[TaxiBot] Reroute failed completely")
                globalRerouteLock = false
                onDone(); return
            end

            local key   = waypointKey(newWPs)
            local count = (rerouteHistory[key] or 0) + 1
            rerouteHistory[key] = count

            if count >= 3 then
                warn("[TaxiBot] Same reroute x"..count.." — forcing alternate corridor")
                local sideOffsets = {
                    Vector3.new(15,0,0), Vector3.new(-15,0,0),
                    Vector3.new(0,0,15), Vector3.new(0,0,-15),
                    Vector3.new(15,0,15),Vector3.new(-15,0,-15),
                }
                for _, sOff in ipairs(sideOffsets) do
                    local alt = tryFromPos(fromPos, sOff)
                              or tryFromPos(p.Position, sOff)
                    if alt then
                        local altKey = waypointKey(alt)
                        if altKey ~= key then
                            rerouteHistory[altKey] = (rerouteHistory[altKey] or 0) + 1
                            print("[TaxiBot] Alternate corridor:", altKey)
                            newWPs = alt
                            break
                        end
                    end
                end
            end

            globalRerouteLock = false   -- release BEFORE starting new drive
            drive(vehicle, newWPs, goalPos, onDone, rerouteHistory, rerouteCount + 1)
        end)
    end

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if tick() - startTime > CFG.DRIVE_TIMEOUT then
            warn("[TaxiBot] Drive timeout")
            lv.VectorVelocity = Vector3.new(0,0,0)
            globalRerouteLock = false
            conn:Disconnect(); onDone(); return
        end

        if not isSeated() or not vehicle.Parent then
            lv.VectorVelocity = Vector3.new(0,0,0)
            globalRerouteLock = false
            conn:Disconnect(); onDone(); return
        end

        -- Advance waypoint index
        while wpIndex <= #waypoints do
            local wp = waypoints[wpIndex]
            local d  = Vector3.new(p.Position.X - wp.X, 0, p.Position.Z - wp.Z).Magnitude
            if d <= CFG.WP_REACH then wpIndex = wpIndex + 1 else break end
        end

        if wpIndex > #waypoints then
            lv.VectorVelocity = Vector3.new(0,0,0)
            globalRerouteLock = false
            conn:Disconnect(); onDone(); return
        end

        local targetWP = waypoints[wpIndex]
        local lookWP   = waypoints[math.min(wpIndex + CFG.LOOK_WP, #waypoints)]
        local rawFace  = Vector3.new(lookWP.X - p.Position.X, 0, lookWP.Z - p.Position.Z)
        local faceDir  = rawFace.Magnitude > 0.1 and rawFace.Unit
                         or Vector3.new(targetWP.X - p.Position.X, 0, targetWP.Z - p.Position.Z).Unit

        if not rerouting then
            local now = tick()

            -- PRIMARY: sweeping fan scanner (8-stud range)
            -- Two beams fan left+right from centre, repeating sweep pattern
            if now - lastWallCheck > CFG.WALL_RECHECK then
                lastWallCheck = now
                local hitDist, hitSide = fanScan(p, vehicle, faceDir, CFG.WALL_DIST)
                if hitDist and hitDist < CFG.WALL_DIST then
                    conn:Disconnect()
                    doReroute("Fan scan hit ("..tostring(hitSide)..") at "..string.format("%.1f", hitDist).." studs")
                    return
                end
            end

            -- SECONDARY: tight 5-ray cone at 3 studs — catches thin poles/signs
            if now - lastCloseCheck > CFG.CLOSE_RECHECK then
                lastCloseCheck = now
                if closeObstacleAhead(p, vehicle, faceDir, CFG.CLOSE_DIST) then
                    conn:Disconnect()
                    doReroute("Close obstacle at 3 studs")
                    return
                end
            end
        end

        -- Stuck nudge
        local isStuck, stuckDir = stuckUpdate(dt)
        if isStuck and stuckDir then
            nudgeDir = stuckDir; nudgeUntil = tick() + CFG.NUDGE_DUR
            print("[TaxiBot] Stuck — nudging")
        end

        local now2 = tick()
        local hDir

        if nudgeDir and now2 < nudgeUntil then
            hDir = nudgeDir; faceDir = nudgeDir
        else
            if nudgeDir then nudgeDir = nil; setNudging(false) end
            local mv = Vector3.new(targetWP.X - p.Position.X, 0, targetWP.Z - p.Position.Z)
            hDir = mv.Magnitude > 0.01 and mv.Unit or faceDir
        end

        local vv = hoverVel(p, vehicle)
        lv.VectorVelocity = Vector3.new(hDir.X*CFG.DRIVE_SPEED, vv, hDir.Z*CFG.DRIVE_SPEED)

        if faceDir and faceDir.Magnitude > 0.01 then
            local cf     = p.CFrame
            local target = CFrame.new(cf.Position)
                         * CFrame.lookAt(Vector3.new(0,0,0), Vector3.new(faceDir.X,0,faceDir.Z))
            p.CFrame = cf:Lerp(target, 0.15)
        end

        if bg then bg.CFrame = CFrame.new(p.Position) end
    end)
end

--------------------------------------------------------------------------------
-- MAIN LOOP  — only drives if already in taxi (Vehicle_TruFleet City Taxi tag)
--              calls tryEnterTaxi once when not seated, then waits
--------------------------------------------------------------------------------

task.spawn(function()
    print("[TaxiBot] v7.4 | Fan Scanner | 5-Ray Close Check | 16-Dir Open Side | Thin Object Detection")

    -- Entry phase: keep trying until seated
    while not isSeated() do
        local ok, err = pcall(tryEnterTaxi)
        if not ok then warn("[TaxiBot] Entry error:", err) end
        if not isSeated() then task.wait(2) end
    end

    print("[TaxiBot] Seated — starting drive loop")

    -- Drive phase: only runs while seated
    while isSeated() do
        local ok, err = pcall(function()
            local vehicle = getVehicle()
            if not vehicle then return end

            globalRerouteLock = false

            local zone = workspace:FindFirstChild("TaxiZone")
            if not zone then print("[TaxiBot] No TaxiZone"); return end

            local goalPos = zone:IsA("Model") and zone:GetPivot().Position or zone.Position

            local wps = computeWaypoints(vehicle.PrimaryPart.Position, goalPos)
            if not wps or #wps < 2 then
                warn("[TaxiBot] Path failed — retrying"); return
            end

            local done     = false
            local watchdog = tick()
            drive(vehicle, wps, goalPos, function() done = true end)

            while not done do
                task.wait(0.5)
                if tick() - watchdog > CFG.DRIVE_TIMEOUT + 5 then
                    warn("[TaxiBot] Watchdog fired"); done = true
                end
            end
        end)

        if not ok then warn("[TaxiBot] Loop error:", err) end
        task.wait(CFG.LOOP_INTERVAL)
    end

    print("[TaxiBot] No longer seated — stopped")
end)
