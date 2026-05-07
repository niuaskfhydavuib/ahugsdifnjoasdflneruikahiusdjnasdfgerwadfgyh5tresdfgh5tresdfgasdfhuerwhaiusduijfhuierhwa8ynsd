-- wipnu
local Fluent       = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager  = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local plr              = Players.LocalPlayer

getgenv().SecureMode = true

-- ============================================================
-- CONNECTION MANAGER
-- ============================================================
local ConnectionManager = { connections = {} }
function ConnectionManager:Add(name, conn)
    if self.connections[name] then self.connections[name]:Disconnect() end
    self.connections[name] = conn
end
function ConnectionManager:Remove(name)
    if self.connections[name] then self.connections[name]:Disconnect() self.connections[name] = nil end
end
function ConnectionManager:CleanupAll()
    for _, conn in pairs(self.connections) do if conn then conn:Disconnect() end end
    self.connections = {}
end

-- ============================================================
-- MECHMOD
-- ============================================================
local mechMod = ReplicatedStorage:FindFirstChild("Assets")
    and ReplicatedStorage.Assets:FindFirstChild("Modules")
    and ReplicatedStorage.Assets.Modules:FindFirstChild("Client")
    and ReplicatedStorage.Assets.Modules.Client:FindFirstChild("Mechanics")
if mechMod then mechMod = require(mechMod) end

-- ============================================================
-- STATE VARIABLES
-- ============================================================
local pullVectorEnabled         = false
local smoothPullEnabled         = false
local isPullingBall             = false
local isSmoothPulling           = false
local walkSpeedEnabled          = false
local cframeSpeedEnabled        = false
local isCFrameMoving            = false
local jumpPowerEnabled          = false
local flyEnabled                = false
local isFlying                  = false
local teleportForwardEnabled    = false
local kickingAimbotEnabled      = false
local bigheadEnabled            = false
local tackleReachEnabled        = false
local playerHitboxEnabled       = false
local staminaDepletionEnabled   = false
local infiniteStaminaEnabled    = false
local autoFollowBallCarrierEnabled = false
local jumpBoostEnabled          = false
local jumpBoostTradeMode        = false
local diveBoostEnabled          = false
local isSprinting               = false
local CanBoost                  = true
local autoSackEnabled           = false
local autoSackConnection        = nil
local enabled                   = false

-- Auto DB
local autoDBEnabled  = false
local autoDBTarget   = nil
local autoDBStrength = 0.5

-- Tunable values
local offsetDistance       = 15
local magnetSmoothness     = 0.01
local customWalkSpeed      = 25
local cframeSpeed          = 1.5
local flySpeed             = 50
local customJumpPower      = 50
local bigheadSize          = 1
local bigheadTransparency  = 0.5
local tackleReachDistance  = 5
local playerHitboxSize     = 5
local playerHitboxTransparency = 0.7
local playerHitboxRound    = false
local maxPullDistance      = 150
local autoFollowBlatancy   = 0.5
local BOOST_FORCE_Y        = 32
local BALL_DETECTION_RADIUS= 10
local BOOST_COOLDOWN       = 1
local DIVE_BOOST_COOLDOWN  = 2
local diveBoostPower       = 2.2
local staminaDepletionRate = 0
local OldStam              = 100
local pullStrength         = 2.0
local stickiness           = 2.0

local function isParkMap()
    return Workspace:FindFirstChild("ParkMap") ~= nil or Workspace:FindFirstChild("ParkMatchMap") ~= nil
end

-- Ball caching
local cachedBall = nil

-- Connections
local diveBoostConnection    = nil
local flyBodyVelocity        = nil
local flyBodyGyro            = nil
local jumpConnection         = nil
local bigheadConnection      = nil
local autoFollowConnection   = nil
local tackleReachConnection  = nil
local playerHitboxConnection = nil
local walkSpeedConnection    = nil
local autoDBRetargetConn     = nil

-- Character refs
local character       = plr.Character or plr.CharacterAdded:Wait()
local humanoidRootPart= character:WaitForChild("HumanoidRootPart")
local humanoid        = character:WaitForChild("Humanoid")
local head            = character:WaitForChild("Head")
local defaultHeadSize         = head.Size
local defaultHeadTransparency = head.Transparency
local defaultWalkSpeed        = humanoid.WalkSpeed
local defaultJumpPower        = humanoid.JumpPower

local function onCharacterAdded(char)
    character        = char
    humanoidRootPart = char:WaitForChild("HumanoidRootPart")
    humanoid         = char:WaitForChild("Humanoid")
    head             = char:WaitForChild("Head")
    defaultHeadSize         = head.Size
    defaultHeadTransparency = head.Transparency
    defaultWalkSpeed        = humanoid.WalkSpeed
    defaultJumpPower        = humanoid.JumpPower
end
ConnectionManager:Add("CharacterAdded", plr.CharacterAdded:Connect(onCharacterAdded))

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
local function getFootball()
    local gameId = plr:FindFirstChild("Replicated") and plr.Replicated:FindFirstChild("GameID")
    if not gameId then cachedBall = nil return nil end
    if cachedBall and cachedBall.Parent then return cachedBall end

    local parkMap = Workspace:FindFirstChild("ParkMap")
    if parkMap then
        local rep = parkMap:FindFirstChild("Replicated")
        if rep then
            local fields = rep:FindFirstChild("Fields")
            if fields then
                for _, name in ipairs({"LeftField","RightField","BLeftField","BRightField","HighField","TLeftField","TRightField"}) do
                    local field = fields:FindFirstChild(name)
                    if field then
                        local fieldRep = field:FindFirstChild("Replicated")
                        if fieldRep then
                            local fb = fieldRep:FindFirstChild("Football")
                            if fb and fb:IsA("BasePart") then cachedBall = fb return fb end
                        end
                    end
                end
            end
        end
    end

    local pmm = Workspace:FindFirstChild("ParkMatchMap")
    if pmm then
        local rep = pmm:FindFirstChild("Replicated")
        if rep then
            local fields = rep:FindFirstChild("Fields")
            if fields then
                for _, field in ipairs(fields:GetChildren()) do
                    local fb = field:FindFirstChild("Football")
                    if fb and fb:IsA("BasePart") then cachedBall = fb return fb end
                    local fieldRep = field:FindFirstChild("Replicated")
                    if fieldRep then
                        fb = fieldRep:FindFirstChild("Football")
                        if fb and fb:IsA("BasePart") then cachedBall = fb return fb end
                    end
                end
            end
        end
    end

    local gf = Workspace:FindFirstChild("Games")
    if gf then
        for _, gi in ipairs(gf:GetChildren()) do
            local rep = gi:FindFirstChild("Replicated")
            if rep then
                local kf = rep:FindFirstChild("918f5408-d86a-4fb8-a88c-5cab57410acf")
                if kf and kf:IsA("BasePart") then cachedBall = kf return kf end
                local fb = rep:FindFirstChild("Football")
                if fb and fb:IsA("BasePart") then cachedBall = fb return fb end
            end
        end
    end

    cachedBall = nil
    return nil
end

local function getBallCarrier()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr and p.Character and p.Character:FindFirstChild("Football") then
            return p
        end
    end
    return nil
end

local function isSameTeam(p1, p2)
    if not p1 or not p2 then return false end
    if p1.Team ~= nil and p2.Team ~= nil then return p1.Team == p2.Team end
    if p1.TeamColor ~= nil and p2.TeamColor ~= nil then return p1.TeamColor == p2.TeamColor end
    return false
end

local function findNearestPlayer()
    if not humanoidRootPart then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                if d < nearestDist then nearestDist = d nearest = p end
            end
        end
    end
    return nearest
end

local function teleportToBall()
    local ball = getFootball()
    if not ball or not humanoidRootPart then return end
    if isParkMap() then
        if (ball.Position - humanoidRootPart.Position).Magnitude > maxPullDistance then return end
    end
    local bv  = ball.Velocity
    local dir = bv.Unit
    local tp  = ball.Position + (dir * 12) - Vector3.new(0, 1.5, 0) + Vector3.new(0, 5.197499752044678/6, 0)
    local lk  = (ball.Position - humanoidRootPart.Position).Unit
    humanoidRootPart.CFrame = CFrame.new(tp, tp + lk)
end

local function smoothTeleportToBall()
    local ball = getFootball()
    if not ball or not humanoidRootPart then return end
    if isParkMap() then
        if (ball.Position - humanoidRootPart.Position).Magnitude > maxPullDistance then return end
    end
    local bv    = ball.Velocity
    local bs    = bv.Magnitude
    local offset= (bs > 0) and (bv.Unit * offsetDistance) or Vector3.new(0,0,0)
    local tp    = ball.Position + offset + Vector3.new(0, 3, 0)
    local lk    = (ball.Position - humanoidRootPart.Position).Unit
    humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(CFrame.new(tp, tp + lk), magnetSmoothness)
end

local function teleportForward()
    if humanoidRootPart then
        humanoidRootPart.CFrame = humanoidRootPart.CFrame + (humanoidRootPart.CFrame.LookVector * 3)
    end
end

local function startCFrameSpeed()
    if isCFrameMoving then return end
    isCFrameMoving = true
    spawn(function()
        while cframeSpeedEnabled and isCFrameMoving do
            if humanoidRootPart and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                humanoidRootPart.CFrame = humanoidRootPart.CFrame + (humanoid.MoveDirection * cframeSpeed)
            end
            wait()
        end
        isCFrameMoving = false
    end)
end

local function stopCFrameSpeed()
    isCFrameMoving = false
    cframeSpeedEnabled = false
end

local function applyJumpBoost(rootPart)
    local bv = Instance.new("BodyVelocity")
    bv.Velocity  = Vector3.new(0, BOOST_FORCE_Y, 0)
    bv.MaxForce  = Vector3.new(0, math.huge, 0)
    bv.P = 5000
    bv.Parent = rootPart
    game:GetService("Debris"):AddItem(bv, 0.2)
end

local function setupJumpBoost(char)
    local root = char:WaitForChild("HumanoidRootPart")
    ConnectionManager:Add("JumpBoostTouch", root.Touched:Connect(function(hit)
        if not jumpBoostEnabled or not CanBoost then return end
        if root.Velocity.Y >= -2 then return end
        local oc  = hit:FindFirstAncestorWhichIsA("Model")
        local ohm = oc and oc:FindFirstChild("Humanoid")
        if oc and oc ~= char and ohm then
            if jumpBoostTradeMode then
                CanBoost = false
                applyJumpBoost(root)
                task.delay(BOOST_COOLDOWN, function() CanBoost = true end)
            else
                local fb = getFootball()
                if fb and (fb.Position - root.Position).Magnitude <= BALL_DETECTION_RADIUS then
                    CanBoost = false
                    applyJumpBoost(root)
                    task.delay(BOOST_COOLDOWN, function() CanBoost = true end)
                end
            end
        end
    end))
end

ConnectionManager:Add("CharacterJumpBoost", plr.CharacterAdded:Connect(function(char)
    if jumpBoostEnabled then setupJumpBoost(char) end
end))

local function updateDivePower()
    if not diveBoostEnabled then return end
    local gameId = plr:FindFirstChild("Replicated") and plr.Replicated:FindFirstChild("GameID")
    if not gameId then return end
    local gid = gameId.Value
    for _, folder in ipairs({ReplicatedStorage:FindFirstChild("Games"), ReplicatedStorage:FindFirstChild("MiniGames")}) do
        if folder then
            local gf2 = folder:FindFirstChild(gid)
            if gf2 then
                local gp = gf2:FindFirstChild("GameParams")
                if gp then
                    local dp = gp:FindFirstChild("DivePower")
                    if dp and dp:IsA("NumberValue") then dp.Value = diveBoostPower end
                end
            end
        end
    end
end

local function getReEvent()
    local gf = ReplicatedStorage:WaitForChild("Games")
    local gc = nil
    for _, c in ipairs(gf:GetChildren()) do
        if c:FindFirstChild("ReEvent") then gc = c break end
    end
    if not gc then gc = gf.ChildAdded:Wait() gc:WaitForChild("ReEvent") end
    return gc:WaitForChild("ReEvent")
end

local function onKick()
    local re = getReEvent()
    re:FireServer(unpack({"Mechanics","KickAngleChanged",1,60,1}))
    re:FireServer(unpack({"Mechanics","KickPowerSet",1}))
    re:FireServer(unpack({"Mechanics","KickHiked",60,1,1}))
    re:FireServer(unpack({"Mechanics","KickAccuracySet",60}))
end

local function getSprintingValue()
    for _, folder in ipairs({ReplicatedStorage:FindFirstChild("Games"), ReplicatedStorage:FindFirstChild("MiniGames")}) do
        if folder then
            for _, f in ipairs(folder:GetChildren()) do
                if f:IsA("Folder") then
                    local m = f:FindFirstChild("MechanicsUsed")
                    if m and m:FindFirstChild("Sprinting") and m.Sprinting:IsA("BoolValue") then
                        return m.Sprinting
                    end
                end
            end
        end
    end
    return nil
end

-- ============================================================
-- AUTO DB LOGIC
-- ============================================================
task.spawn(function()
    while true do
        task.wait(2)
        if autoDBEnabled then
            autoDBTarget = findNearestPlayer()
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not autoDBEnabled or not autoDBTarget or not autoDBTarget.Character then return end
    if not humanoidRootPart or not humanoid then return end
    local hrp = autoDBTarget.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local d  = 5 - (autoDBStrength * 4)
        local wp = (hrp.CFrame * CFrame.new(0, 0, d)).Position
        humanoid:MoveTo(wp)
    end
end)

-- ============================================================
-- INPUT HANDLING
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonR2) then
        if pullVectorEnabled then
            isPullingBall = true
            spawn(function() while isPullingBall do teleportToBall() wait(0.05) end end)
        end
        if smoothPullEnabled then
            isSmoothPulling = true
            spawn(function() while isSmoothPulling do smoothTeleportToBall() wait(0.05) end end)
        end
    end
   if input.UserInputType == Enum.UserInputType.Keyboard then
        if teleportForwardEnabled and input.KeyCode == Enum.KeyCode.Z then teleportForward() end
        if kickingAimbotEnabled and input.KeyCode == Enum.KeyCode.L then onKick() end
        if input.KeyCode == Enum.KeyCode.X then
            enabled = not enabled
            local toggle = Fluent.Options["StickyToggle"]
            if toggle then toggle:SetValue(enabled) end
        end
    end

    if input.UserInputType == Enum.UserInputType.Gamepad1
    and input.KeyCode == Enum.KeyCode.ButtonR1 then
        enabled = not enabled
        local toggle = Fluent.Options["StickyToggle"]
        if toggle then toggle:SetValue(enabled) end
    end

    local sv = getSprintingValue()
    if sv and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL3) then
        isSprinting = not isSprinting
        if isSprinting then
            sv.Value = true
            if infiniteStaminaEnabled then task.wait(0.1) sv.Value = false end
        else
            if infiniteStaminaEnabled then sv.Value = true task.wait(0.1) sv.Value = false end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonR2) then
        isPullingBall   = false
        isSmoothPulling = false
    end
end)

-- ============================================================
-- SKIES SYSTEM
-- ============================================================
local Lighting = game:GetService("Lighting")
local currentSky = nil
local skies = {
    ["Galaxy"]       = { Bk="rbxassetid://159454299", Dn="rbxassetid://159454296", Ft="rbxassetid://159454293", Lf="rbxassetid://159454286", Rt="rbxassetid://159454300", Up="rbxassetid://159454288" },
    ["Purple Night"] = { Bk="rbxassetid://433274085", Dn="rbxassetid://433274194", Ft="rbxassetid://433274131", Lf="rbxassetid://433274370", Rt="rbxassetid://433274429", Up="rbxassetid://433274285" },
    ["Cloudy Blue"]  = { Bk="rbxassetid://570557514", Dn="rbxassetid://570557775", Ft="rbxassetid://570557559", Lf="rbxassetid://570557620", Rt="rbxassetid://570557672", Up="rbxassetid://570557727" },
    ["Red Sunset"]   = { Bk="rbxassetid://600830446", Dn="rbxassetid://600831635", Ft="rbxassetid://600832720", Lf="rbxassetid://600886090", Rt="rbxassetid://600833862", Up="rbxassetid://600835177" },
}
local function removeSky() if currentSky and currentSky.Parent then currentSky:Destroy() end currentSky = nil end
local function loadSky(name)
    removeSky()
    local data = skies[name]; if not data then return end
    local sky = Instance.new("Sky"); sky.Name = "CustomSky"
    sky.SkyboxBk=data.Bk; sky.SkyboxDn=data.Dn; sky.SkyboxFt=data.Ft
    sky.SkyboxLf=data.Lf; sky.SkyboxRt=data.Rt; sky.SkyboxUp=data.Up
    sky.Parent = Lighting; currentSky = sky
end

-- ============================================================
-- FLUENT WINDOW
-- ============================================================
local Window = Fluent:CreateWindow({
    Title      = "Volzy hub | NFL Universe",
    SubTitle   = "by coldcomplxtion",
    TabWidth   = 160,
    Size       = UDim2.fromOffset(600, 480),
    Acrylic    = true,
    Theme      = "Dark",
    MinimizeKey= Enum.KeyCode.RightControl
})

local Tabs = {
    Main      = Window:AddTab({ Title = "Catching",  Icon = "target" }),
    Player    = Window:AddTab({ Title = "Player",    Icon = "user" }),
    Hitbox    = Window:AddTab({ Title = "Hitbox",    Icon = "box" }),
    Defense   = Window:AddTab({ Title = "Defense",   Icon = "shield" }),
    Automatic = Window:AddTab({ Title = "Auto",      Icon = "cpu" }),
    Misc      = Window:AddTab({ Title = "Misc",      Icon = "wrench" }),
    Skies     = Window:AddTab({ Title = "Skies",     Icon = "cloud" }),
    Items     = Window:AddTab({ Title = "items",     Icon = "star" }),
    Emotes    = Window:AddTab({ Title = "Emotes",    Icon = "accessibility" }),
    Visuals   = Window:AddTab({ Title = "Visual",    Icon = "eye"  }),
    Settings  = Window:AddTab({ Title = "Settings",  Icon = "settings" }),
}

local Options = Fluent.Options

-- ============================================================
-- MAIN TAB (Catching)
-- ============================================================
Tabs.Main:AddParagraph({ Title = "Legit Pull Vector", Content = "Hold M1 or R2 to smoothly magnet to the ball." })
Tabs.Main:AddToggle("SmoothPull", { Title="Legit Pull Vector (M1 / R2)", Default=false, Callback=function(v) smoothPullEnabled=v end })
Tabs.Main:AddSlider("MagnetSmoothness", { Title="Vector Smoothing", Description="Lower = smoother pull", Default=0.20, Min=0.01, Max=1.0, Rounding=2, Callback=function(v) magnetSmoothness=v end })
Tabs.Main:AddParagraph({ Title = "Pull Vector", Content = "Hold M1 or R2 to instantly snap to the ball." })
Tabs.Main:AddToggle("PullVector", { Title="Pull Vector (M1 / R2)", Default=false, Callback=function(v) pullVectorEnabled=v end })
Tabs.Main:AddSlider("OffsetDistance", { Title="Offset Distance", Description="Studs ahead of the ball", Default=15, Min=0, Max=30, Rounding=0, Callback=function(v) offsetDistance=v end })
Tabs.Main:AddSlider("MaxPullDistance", { Title="Max Pull Distance", Description="Distance limit (Park mode only)", Default=150, Min=1, Max=300, Rounding=0, Callback=function(v) maxPullDistance=v end })

-- ============================================================
-- PLAYER TAB
-- ============================================================
Tabs.Player:AddParagraph({ Title = "Speed", Content = "Choose between WalkSpeed or CFrame-based speed." })
Tabs.Player:AddDropdown("SpeedType", { Title="Speed Type", Values={"WalkSpeed","CFrame Speed"}, Default="WalkSpeed", Multi=false })
Tabs.Player:AddToggle("SpeedToggle", {
    Title="Enable Speed", Default=false,
    Callback=function(v)
        local t = Options.SpeedType.Value
        if t == "WalkSpeed" then
            walkSpeedEnabled = v; cframeSpeedEnabled = false; stopCFrameSpeed()
            if walkSpeedConnection then walkSpeedConnection:Disconnect() walkSpeedConnection = nil end
            local function setSpd() local h=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=walkSpeedEnabled and customWalkSpeed or 16 end end
            if v then setSpd(); local h=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid"); if h then walkSpeedConnection=h:GetPropertyChangedSignal("WalkSpeed"):Connect(setSpd) end else setSpd() end
        elseif t == "CFrame Speed" then
            cframeSpeedEnabled = v; walkSpeedEnabled = false
            if walkSpeedConnection then walkSpeedConnection:Disconnect() walkSpeedConnection = nil end
            local h=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=16 end
            if v then startCFrameSpeed() else stopCFrameSpeed() end
        end
    end
})
Options.SpeedType:OnChanged(function() Options.SpeedToggle:SetValue(false) end)
Tabs.Player:AddSlider("WalkSpeedValue", { Title="WalkSpeed Value", Default=25, Min=16, Max=35, Rounding=0, Callback=function(v) customWalkSpeed=v; if walkSpeedEnabled then local h=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=v end end end })
Tabs.Player:AddSlider("CFrameSpeedValue", { Title="CFrame Speed Multiplier", Default=1.5, Min=1, Max=10, Rounding=1, Callback=function(v) cframeSpeed=v end })

Tabs.Player:AddParagraph({ Title = "Jump Power", Content = "Boosts your jump height on each jump." })
Tabs.Player:AddToggle("JumpPowerToggle", {
    Title="Jump Power", Default=false,
    Callback=function(v)
        jumpPowerEnabled=v
        if v then
            if jumpConnection then jumpConnection:Disconnect() end
            jumpConnection=humanoid.Jumping:Connect(function()
                if jumpPowerEnabled and humanoidRootPart then
                    humanoidRootPart.Velocity=Vector3.new(humanoidRootPart.Velocity.X,0,humanoidRootPart.Velocity.Z)+Vector3.new(0,customJumpPower,0)
                end
            end)
        else if jumpConnection then jumpConnection:Disconnect() end; jumpConnection=nil end
    end
})
Tabs.Player:AddSlider("JumpPowerValue", { Title="Jump Power Value", Default=50, Min=10, Max=200, Rounding=0, Callback=function(v) customJumpPower=v end })

Tabs.Player:AddParagraph({ Title = "Fly", Content = "Fly freely using WASD + Space/Shift." })
Tabs.Player:AddToggle("FlyToggle", {
    Title="Fly", Default=false,
    Callback=function(v)
        flyEnabled=v
        if v then
            if not flyBodyVelocity then
                flyBodyVelocity=Instance.new("BodyVelocity"); flyBodyVelocity.MaxForce=Vector3.new(1e5,1e5,1e5); flyBodyVelocity.Velocity=Vector3.new(0,0,0); flyBodyVelocity.Parent=humanoidRootPart
                flyBodyGyro=Instance.new("BodyGyro"); flyBodyGyro.MaxTorque=Vector3.new(1e5,1e5,1e5); flyBodyGyro.P=1000; flyBodyGyro.D=100; flyBodyGyro.Parent=humanoidRootPart
                isFlying=true
                spawn(function()
                    while isFlying do
                        local cam=Workspace.CurrentCamera; local md=Vector3.new(0,0,0)
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md=md+cam.CFrame.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md=md-cam.CFrame.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md=md-cam.CFrame.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md=md+cam.CFrame.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then md=md+Vector3.new(0,1,0) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md=md-Vector3.new(0,1,0) end
                        flyBodyVelocity.Velocity=md.Magnitude>0 and md.Unit*flySpeed or Vector3.new(0,0,0); wait()
                    end
                end)
            end
        else
            if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity=nil end
            if flyBodyGyro     then flyBodyGyro:Destroy()     flyBodyGyro=nil end
            isFlying=false
        end
    end
})
Tabs.Player:AddSlider("FlySpeed", { Title="Fly Speed", Default=50, Min=10, Max=200, Rounding=0, Callback=function(v) flySpeed=v end })

Tabs.Player:AddParagraph({ Title = "Jump Boost", Content = "Launches you upward when touching opponents." })
Tabs.Player:AddToggle("JumpBoostToggle", { Title="Jump Boost", Default=false, Callback=function(v) jumpBoostEnabled=v; if v then if plr.Character then setupJumpBoost(plr.Character) end else ConnectionManager:Remove("JumpBoostTouch") end end })
Tabs.Player:AddToggle("JumpBoostAlwaysMode", { Title="Always Boost Mode", Default=false, Callback=function(v) jumpBoostTradeMode=v end })
Tabs.Player:AddSlider("BoostForce", { Title="Boost Force", Default=32, Min=10, Max=100, Rounding=0, Callback=function(v) BOOST_FORCE_Y=v end })
Tabs.Player:AddSlider("BallDetectionRadius", { Title="Ball Detection Radius", Default=10, Min=5, Max=30, Rounding=0, Callback=function(v) BALL_DETECTION_RADIUS=v end })
Tabs.Player:AddSlider("BoostCooldown", { Title="Boost Cooldown (s)", Default=1, Min=0.1, Max=5, Rounding=1, Callback=function(v) BOOST_COOLDOWN=v end })

Tabs.Player:AddParagraph({ Title = "Dive Boost", Content = "Increases your dive distance." })
Tabs.Player:AddToggle("DiveBoostToggle", {
    Title="Dive Boost", Default=false,
    Callback=function(v)
        diveBoostEnabled=v
        if diveBoostConnection then diveBoostConnection:Disconnect() diveBoostConnection=nil end
        if v then
            updateDivePower(); diveBoostConnection=RunService.Heartbeat:Connect(updateDivePower)
        else
            local gid_inst=plr:FindFirstChild("Replicated") and plr.Replicated:FindFirstChild("GameID")
            if gid_inst then
                local gid=gid_inst.Value
                for _,folder in ipairs({ReplicatedStorage:FindFirstChild("Games"),ReplicatedStorage:FindFirstChild("MiniGames")}) do
                    if folder then local gf=folder:FindFirstChild(gid); if gf then local gp=gf:FindFirstChild("GameParams"); if gp then local dp=gp:FindFirstChild("DivePower"); if dp and dp:IsA("NumberValue") then dp.Value=2.2 end end end end
                end
            end
        end
    end
})
Tabs.Player:AddSlider("DivePower", { Title="Dive Power", Description="Default: 2.2", Default=2.2, Min=2.2, Max=10, Rounding=1, Callback=function(v) diveBoostPower=v end })

Tabs.Player:AddParagraph({ Title = "Stamina", Content = "Reduce stamina drain or get infinite stamina." })
Tabs.Player:AddToggle("StaminaDepletion", {
    Title="(High Unc) Stamina Depletion", Default=false,
    Callback=function(v)
        staminaDepletionEnabled=v
        spawn(function()
            while staminaDepletionEnabled do task.wait(); if mechMod and OldStam>mechMod.Stamina then mechMod.Stamina=mechMod.Stamina+(staminaDepletionRate*0.001) end end
        end)
    end
})
Tabs.Player:AddSlider("StaminaRate", { Title="Stamina Depletion Rate", Default=1, Min=1, Max=100, Rounding=1, Callback=function(v) staminaDepletionRate=v end })
Tabs.Player:AddToggle("InfiniteStamina", { Title="(Low Unc) Infinite Stamina", Default=false, Callback=function(v) infiniteStaminaEnabled=v end })

Tabs.Player:AddParagraph({ Title = "Teleport", Content = "Teleport around the field." })
Tabs.Player:AddToggle("TeleportForward", { Title="Teleport Forward (Z key)", Default=false, Callback=function(v) teleportForwardEnabled=v end })

-- ============================================================
-- HITBOX TAB
-- ============================================================
Tabs.Hitbox:AddToggle("StickyToggle", {
    Title = "Sticky Head",
    Description = "Press x or R1 to toggle. When enabled, your character will be pulled toward the heads of nearby opponents for easier catching.",
    Default = false,
    Callback = function(value)
        enabled = value
    end
})

Tabs.Hitbox:AddSlider("PullSlider", {
    Title = "Pull Strength",
    Description = "How aggressively you are pulled toward the target head",
    Default = 2.0,
    Min = 1.0,
    Max = 4.0,
    Rounding = 1,
    Callback = function(value)
        pullStrength = value
    end
})

Tabs.Hitbox:AddSlider("StickySlider", {
    Title = "Stickiness",
    Description = "How strongly you lock onto the target head when close",
    Default = 2.0,
    Min = 1.0,
    Max = 4.0,
    Rounding = 1,
    Callback = function(value)
        stickiness = value
    end
})

local function closestPlayer()
    local nearest
    local dist = 35
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= plr and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 and humanoidRootPart then
                local d = (hrp.Position - humanoidRootPart.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = p
                end
            end
        end
    end
    return nearest
end

RunService.RenderStepped:Connect(function()
    if not enabled then return end
    if not humanoidRootPart or not humanoid then return end
    local target = closestPlayer()
    if not target or not target.Character then return end

    local targetHead = target.Character:FindFirstChild("Head")
    if not targetHead then return end

    if humanoid.FloorMaterial == Enum.Material.Air then
        local headPos = targetHead.Position + Vector3.new(0, 1.6, 0)
        local offset = headPos - humanoidRootPart.Position
        local dist = offset.Magnitude
        local vel = humanoidRootPart.AssemblyLinearVelocity

        if dist > 2.5 then
            local multiplier = pullStrength * 18
            local desired = offset.Unit * multiplier
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
                vel.X + (desired.X - vel.X) * 0.25,
                vel.Y,
                vel.Z + (desired.Z - vel.Z) * 0.25
            )
        end

        if dist <= 3 then
            local centerDir = (headPos - humanoidRootPart.Position)
            local horizontal = Vector3.new(centerDir.X, 0, centerDir.Z)
            if horizontal.Magnitude > 0 then
                humanoidRootPart.AssemblyLinearVelocity = humanoidRootPart.AssemblyLinearVelocity + horizontal.Unit * (stickiness * 5)
            end
        end

        if dist <= 2 then
            local boostOffset = headPos - humanoidRootPart.Position
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
                boostOffset.X * (stickiness * 5),
                humanoidRootPart.AssemblyLinearVelocity.Y,
                boostOffset.Z * (stickiness * 5)
            )
        end

        if dist <= 1.2 then
            local lock = headPos - humanoidRootPart.Position
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
                lock.X * (stickiness * 6),
                humanoidRootPart.AssemblyLinearVelocity.Y,
                lock.Z * (stickiness * 6)
            )
        end
    end
end)

Tabs.Hitbox:AddParagraph({ Title = "Bighead", Content = "Enlarges other players' heads for easier collision." })
Tabs.Hitbox:AddToggle("BigheadToggle", {
    Title="Bighead", Default=false,
    Callback=function(v)
        bigheadEnabled=v
        if v then
            if bigheadConnection then bigheadConnection:Disconnect() end
            bigheadConnection=RunService.RenderStepped:Connect(function()
                for _,p in pairs(Players:GetPlayers()) do
                    if p~=plr and p.Character then
                        local h=p.Character:FindFirstChild("Head")
                        if h and h:IsA("BasePart") then h.Size=Vector3.new(bigheadSize,bigheadSize,bigheadSize); h.Transparency=bigheadTransparency; h.CanCollide=true; local face=h:FindFirstChild("face"); if face then face:Destroy() end end
                    end
                end
            end)
        else
            if bigheadConnection then bigheadConnection:Disconnect() bigheadConnection=nil end
            for _,p in pairs(Players:GetPlayers()) do if p~=plr and p.Character then local h=p.Character:FindFirstChild("Head"); if h and h:IsA("BasePart") then h.Size=defaultHeadSize; h.Transparency=defaultHeadTransparency; h.CanCollide=false end end end
        end
    end
})
Tabs.Hitbox:AddSlider("HeadSize", { Title="Head Size", Default=1, Min=1, Max=10, Rounding=0, Callback=function(v) bigheadSize=v end })
Tabs.Hitbox:AddSlider("HeadTransparency", { Title="Head Transparency", Default=0.5, Min=0, Max=1, Rounding=2, Callback=function(v) bigheadTransparency=v end })

Tabs.Hitbox:AddParagraph({ Title = "Tackle Reach", Content = "Extends your tackle range." })
Tabs.Hitbox:AddToggle("TackleReachToggle", {
    Title="Tackle Reach", Default=false,
    Callback=function(v)
        tackleReachEnabled=v
        if tackleReachConnection then tackleReachConnection:Disconnect() end
        if v then
            tackleReachConnection=RunService.Heartbeat:Connect(function()
                for _,tp in ipairs(Players:GetPlayers()) do
                    if tp~=plr and tp.Character then
                        for _,desc in ipairs(tp.Character:GetDescendants()) do
                            if desc.Name=="FootballGrip" then
                                local gid=plr:FindFirstChild("Replicated") and plr.Replicated:FindFirstChild("GameID") and plr.Replicated.GameID.Value
                                if gid then
                                    local gf=(Workspace:FindFirstChild("Games") and Workspace.Games:FindFirstChild(gid)) or (Workspace:FindFirstChild("MiniGames") and Workspace.MiniGames:FindFirstChild(gid))
                                    if gf then local hbf=gf:FindFirstChild("Replicated") and gf.Replicated:FindFirstChild("Hitboxes"); if hbf then local hb=hbf:FindFirstChild(tp.Name); if hb and humanoidRootPart and (hb.Position-humanoidRootPart.Position).Magnitude<=(tonumber(tackleReachDistance) or 1) then hb.Position=humanoidRootPart.Position; task.wait(0.1); local hrp=tp.Character:FindFirstChild("HumanoidRootPart"); if hrp then hb.Position=hrp.Position end end end end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
})
Tabs.Hitbox:AddSlider("TackleDistance", { Title="Tackle Reach Distance", Default=5, Min=1, Max=10, Rounding=0, Callback=function(v) tackleReachDistance=v end })

Tabs.Hitbox:AddParagraph({ Title = "Player Hitbox", Content = "Expands other players hitboxes." })
Tabs.Hitbox:AddToggle("PlayerHitboxToggle", {
    Title="Player Hitbox Expander", Default=false,
    Callback=function(v)
        playerHitboxEnabled=v
        if playerHitboxConnection then playerHitboxConnection:Disconnect() playerHitboxConnection=nil end
        if v then
            playerHitboxConnection=RunService.RenderStepped:Connect(function()
                for _,tp in ipairs(Players:GetPlayers()) do
                    if tp~=plr and tp.Character then
                        local hrp=tp.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and hrp:IsA("BasePart") then hrp.Size=Vector3.new(playerHitboxSize,playerHitboxSize,playerHitboxSize); hrp.Transparency=playerHitboxTransparency; hrp.CanCollide=true; hrp.Shape=playerHitboxRound and Enum.PartType.Ball or Enum.PartType.Block end
                    end
                end
            end)
        else
            for _,tp in ipairs(Players:GetPlayers()) do if tp~=plr and tp.Character then local hrp=tp.Character:FindFirstChild("HumanoidRootPart"); if hrp and hrp:IsA("BasePart") then hrp.Size=Vector3.new(2,2,1); hrp.Transparency=1; hrp.CanCollide=false; hrp.Shape=Enum.PartType.Block end end end
        end
    end
})
Tabs.Hitbox:AddSlider("HitboxSize", { Title="Hitbox Size", Default=5, Min=2, Max=20, Rounding=0, Callback=function(v) playerHitboxSize=v end })
Tabs.Hitbox:AddSlider("HitboxTransparency", { Title="Transparency", Default=0.7, Min=0, Max=1, Rounding=2, Callback=function(v) playerHitboxTransparency=v end })
Tabs.Hitbox:AddToggle("RoundHitbox", { Title="Round Hitbox", Default=false, Callback=function(v) playerHitboxRound=v end })

-- ============================================================
-- DEFENSE TAB
-- ============================================================
Tabs.Defense:AddParagraph({ Title = "Auto DB", Content = "Automatically follows and defends against the nearest player. Retargets every 2 seconds." })
Tabs.Defense:AddToggle("AutoDB", {
    Title    = "Enable Auto DB",
    Default  = false,
    Callback = function(v)
        autoDBEnabled = v
        if v then
            autoDBTarget = findNearestPlayer()
        else
            autoDBTarget = nil
        end
    end
})
Tabs.Defense:AddSlider("AutoDBStrength", {
    Title       = "Follow Strength",
    Description = "0 = stay far, 1 = get very close",
    Default     = 0.5, Min = 0, Max = 1, Rounding = 1,
    Callback    = function(v) autoDBStrength = v end
})

Tabs.Defense:AddParagraph({ Title = "Auto Rush", Content = "Automatically chases and cuts off the ball carrier." })
Tabs.Defense:AddToggle("AutoFollowToggle", {
    Title="Auto Follow Ball Carrier", Default=false,
    Callback=function(v)
        autoFollowBallCarrierEnabled=v
        if autoFollowConnection then autoFollowConnection:Disconnect() autoFollowConnection=nil end
        if v then
            autoFollowConnection=RunService.Heartbeat:Connect(function()
                local bc=getBallCarrier()
                if bc and bc.Character and humanoidRootPart and humanoid then
                    local cr=bc.Character:FindFirstChild("HumanoidRootPart")
                    if cr then
                        local cv=cr.Velocity; local dist=(cr.Position-humanoidRootPart.Position).Magnitude
                        local ttr=dist/(humanoid.WalkSpeed or 16); local pred=cr.Position+(cv*ttr)
                        local dir=pred-humanoidRootPart.Position
                        humanoid:MoveTo(humanoidRootPart.Position+dir*math.clamp(autoFollowBlatancy,0,1))
                    end
                end
            end)
        end
    end
})
Tabs.Defense:AddSlider("AutoFollowBlatancy", { Title="Follow Blatancy", Description="How aggressively it predicts / cuts off the carrier", Default=0.5, Min=0, Max=1, Rounding=2, Callback=function(v) autoFollowBlatancy=v end })

-- ============================================================
-- AUTOMATIC TAB
-- ============================================================
Tabs.Automatic:AddParagraph({ Title = "Kick Aimbot", Content = "Press L for max power + accuracy kick." })
Tabs.Automatic:AddToggle("KickAimbot", { Title="Kick Aimbot (L key)", Default=false, Callback=function(v) kickingAimbotEnabled=v end })

Tabs.Automatic:AddParagraph({ Title = "Teleport", Content = "Quick teleport to each endzone." })
Tabs.Automatic:AddButton({ Title="Teleport to Endzone 1", Callback=function() local r=humanoidRootPart or (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")); if r then r.CFrame=CFrame.new(161,4,-2) end end })
Tabs.Automatic:AddButton({ Title="Teleport to Endzone 2", Callback=function() local r=humanoidRootPart or (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")); if r then r.CFrame=CFrame.new(-166,4,0) end end })

-- ============================================================
-- MISC TAB
-- ============================================================
Tabs.Misc:AddButton({ Title="Rejoin Server", Callback=function() game:GetService("TeleportService"):Teleport(game.PlaceId,plr) end })
Tabs.Misc:AddButton({
    Title="Server Hop",
    Callback=function()
        local hs=game:GetService("HttpService"); local ts=game:GetService("TeleportService")
        local ok,servers=pcall(function() return hs:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")) end)
        if ok and servers and servers.data then for _,s in ipairs(servers.data) do if s.playing<s.maxPlayers then ts:TeleportToPlaceInstance(game.PlaceId,s.id,plr); break end end end
    end
})
Tabs.Misc:AddToggle("AntiAFK", {
    Title="Anti-AFK", Default=false,
    Callback=function(v)
        if v then getgenv().AntiAFKConnection=plr.Idled:Connect(function() local vu=game:GetService("VirtualUser"); vu:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame); task.wait(1); vu:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame) end)
        else if getgenv().AntiAFKConnection then getgenv().AntiAFKConnection:Disconnect(); getgenv().AntiAFKConnection=nil end end
    end
})
Tabs.Misc:AddButton({
    Title="FPS Boost",
    Callback=function()
        for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("BasePart") then v.Material=Enum.Material.Plastic; v.Reflectance=0 elseif v:IsA("Decal") or v:IsA("Texture") then v:Destroy() end end
        settings().Rendering.QualityLevel=Enum.QualityLevel.Level01
    end
})

-- ============================================================
-- SKIES TAB
-- ============================================================
Tabs.Skies:AddParagraph({ Title="Sky Themes", Content="Change the skybox to different themes." })
local skyEnabled=false; local selectedSky="Galaxy"
Tabs.Skies:AddToggle("SkyToggle", { Title="Enable Sky", Default=false, Callback=function(v) skyEnabled=v; if v then loadSky(selectedSky) else removeSky() end end })
Tabs.Skies:AddDropdown("SelectSky", { Title="Select Sky", Values={"Galaxy","Purple Night","Cloudy Blue","Red Sunset"}, Default="Galaxy", Callback=function(v) selectedSky=v; if skyEnabled then loadSky(v) end end })

-- ============================================================
-- EMOTES TAB
-- ============================================================
local function PlayEmote(id)
    local character=plr.Character; local humanoid=character and character:FindFirstChildOfClass("Humanoid"); local animator=humanoid and humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _,track in pairs(animator:GetPlayingAnimationTracks()) do track:Stop(0.1) end
        local anim=Instance.new("Animation"); anim.AnimationId="rbxassetid://"..tostring(id)
        local success,loadAnim=pcall(function() return animator:LoadAnimation(anim) end)
        if success and loadAnim then loadAnim.Priority=Enum.AnimationPriority.Action4; loadAnim.Looped=true; loadAnim:Play() end
    end
end

Tabs.Emotes:AddParagraph({ Title="Player Animations", Content="Select an emote below. Use 'Stop Emote' to reset movement." })
local emoteList = {
    {"Bop",2178463446},{"BlocBoy Shoot",2178463446},{"Hacker's Delight",10714364213},{"Ball Spin",14215798544},
    {"Head dribble",11006158861},{"The griddy",8028694339},{"Penguin Dance",5439075558},{"Goopie",5439090599},
    {"Headless",5704065738},{"Worm",3471311681},{"Speed dance",94471347736309},{"Peanut Butter Jelly Time",5433555683},
    {"Moon",14216002323},{"Inner child",14215788817},{"Neighborly hang",11006145037},{"Headspin",14920821886},
    {"Take the L",2293391158},{"Couldnt care less",107875941017127},{"Memphis pregame",14138482621},{"Rocket landing",103979887627824},
}
for _,e in ipairs(emoteList) do
    local name,id=e[1],e[2]
    Tabs.Emotes:AddButton({ Title=name, Callback=function() PlayEmote(id) end })
end
Tabs.Emotes:AddButton({ Title="Stop Emote", Description="Cancel all animations", Callback=function() if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then for _,track in pairs(plr.Character.Humanoid:GetPlayingAnimationTracks()) do track:Stop() end end end })

-- ============================================================
-- ITEMS TAB DATA
-- ============================================================
local equipped     = {}
local EquippedHats = {}

local MESH_ITEMS = {
    Coldstare    = { mesh="rbxassetid://5028704943", tex="rbxassetid://5047708728", par="UpperTorso", scl=Vector3.new(1,1,1),        off=CFrame.new(0,0.15,0.65)*CFrame.Angles(0,math.rad(180),0) },
    DesertVest   = { mesh="rbxassetid://11755494017",tex="rbxassetid://11755494031",par="UpperTorso", scl=Vector3.new(0.73,1.13,0.75),off=CFrame.new(0,0,-0.05) },
    SeeingStars  = { mesh="rbxassetid://62139052",   tex="rbxassetid://62139103",   par="Head",      scl=Vector3.new(1.05,1.05,1.05),off=CFrame.new(0,0.05,-0.45) },
    TacticalVest = { mesh="rbxassetid://11754584493",tex="rbxassetid://11754584535",par="UpperTorso", scl=Vector3.new(0.73,1.13,0.75),off=CFrame.new(0,0,-0.05) },
}
local CLOTHING_ITEMS = {
    ["Black World Tour Shirt"]={type="Shirt",assetId=15335037852},["Pink World Tour Shirt"]={type="Shirt",assetId=15334978300},
    ["White World Tour"]={type="Shirt",assetId=15334975460},["King Shirt"]={type="Shirt",assetId=6296265575},
    ["King Pants"]={type="Pants",assetId=10725550576},["Black Bandana Shorts"]={type="Pants",assetId=15020463274},
    ["Grey Flare"]={type="Shirt",assetId=15345367906},["Black Flare"]={type="Shirt",assetId=15345348842},
    ["Red Flare"]={type="Shirt",assetId=15345347397},["Acid Flare"]={type="Shirt",assetId=15345352095},
    ["Pastel Flare"]={type="Shirt",assetId=15345355082},["Orange Flare"]={type="Shirt",assetId=15345357354},
    ["Hooded Jean Jacket"]={type="Shirt",assetId=15334917844},
}
local Hats = {
    {Name="Ushanka",Id=12710415119,Type="Normal",Attach="Head"},
    {Name="Subarctic Commando",Id=100235743603545,Type="Commando",Attach="Head"},
    {Name="Dark Ruby Crown",Id=7912127597,Type="Normal",Attach="Head"},
    {Name="Midnight Commando",Id=259424866,Type="Commando",Attach="Head"},
    {Name="Arctic Commando",Id=87396780155106,Type="Commando",Attach="Head"},
    {Name="Blue CW Headphones",Id=1743903423,Type="Headphones",Attach="Head"},
    {Name="White CW Headphones",Id=97230132426750,Type="Headphones",Attach="Head"},
    {Name="Designer Keffyeh",Id=14157118140,Type="Normal",Attach="Head"},
    {Name="Royal Crown",Id=11453654,Type="Normal",Attach="Head"},
}
local HatOffsets = {
    [100235743603545]=CFrame.new(0,0.2,0)*CFrame.Angles(0,math.rad(180),0),
    [259424866]=CFrame.new(0,0.1,0),
    [7912127597]=CFrame.new(0,0.8,0.1)*CFrame.Angles(0,math.rad(90),0),
    [87396780155106]=CFrame.new(0,0.1,0)*CFrame.Angles(0,math.rad(180),0),
}

local function ResetHats() for _,obj in ipairs(EquippedHats) do if obj and obj.Parent then obj:Destroy() end end table.clear(EquippedHats) end
local function EquipHat(assetId,hatType,attachTo)
    local ok,model=pcall(function() return game:GetObjects("rbxassetid://"..tostring(assetId))[1] end)
    if not ok or not model then return end
    local offset=HatOffsets[assetId] or (hatType=="Commando" and CFrame.new(0,0.2,0)*CFrame.Angles(0,math.rad(180),0) or CFrame.new(0,0.3,0)*CFrame.Angles(0,math.rad(180),0))
    for _,part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored=false; part.CanCollide=false; part.Massless=true; part.CFrame=head.CFrame*offset; part.Parent=character
            local weld=Instance.new("WeldConstraint"); weld.Part0=head; weld.Part1=part; weld.Parent=part
            table.insert(EquippedHats,part)
        end
    end
end

local function guessSlot(name) local nm=name:lower(); if nm:find("shade") or nm:find("glass") then return "FaceAccessory" end; if nm:find("hair") or nm:find("scene") or nm:find("lava") or nm:find("alt") then return "HairAccessory" end; if nm:find("chain") then return "NeckAccessory" end; return "HatAccessory" end

local function equipMesh(name)
    if equipped[name] then return end; local d=MESH_ITEMS[name]; if not d then return end; local char=plr.Character; if not char then return end
    local par=char:FindFirstChild(d.par) or (d.par=="UpperTorso" and char:FindFirstChild("Torso")) or (d.par=="LowerTorso" and char:FindFirstChild("Torso")); if not par then return end
    local part=Instance.new("Part"); part.Name=name; part.Size=Vector3.new(1,1,1); part.CanCollide=false; part.Anchored=false; part.Massless=true; part.Parent=char
    local m=Instance.new("SpecialMesh"); m.MeshType=Enum.MeshType.FileMesh; m.MeshId=d.mesh; m.TextureId=d.tex; m.Scale=d.scl; m.Parent=part
    local w=Instance.new("Motor6D"); w.Part0=par; w.Part1=part; w.C0=d.off; w.Parent=par
    part.CFrame=par.CFrame*d.off; equipped[name]={part}
end

local function equipClothing(name)
    if equipped[name] then return end; local d=CLOTHING_ITEMS[name]; if not d then return end; local char=plr.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); local idStr=tostring(d.assetId); local parts={}
    local ok,result=pcall(function() return game:GetObjects("rbxassetid://"..idStr) end)
    if ok and result then
        for _,obj in pairs(result) do
            local items={obj}; pcall(function() for _,c in pairs(obj:GetDescendants()) do table.insert(items,c) end end)
            for _,item in pairs(items) do
                if item:IsA("Shirt") and d.type=="Shirt" then local old=char:FindFirstChildOfClass("Shirt"); if old then old:Destroy() end; item.Parent=char; table.insert(parts,item); break
                elseif item:IsA("Pants") and d.type=="Pants" then local old=char:FindFirstChildOfClass("Pants"); if old then old:Destroy() end; item.Parent=char; table.insert(parts,item); break
                elseif (item:IsA("Accessory") or item:IsA("Accoutrement")) and d.type=="Accessory" then item.Parent=char; table.insert(parts,item); break end
            end
            if #parts>0 then break end
        end
    end
    if #parts==0 and d.type=="Accessory" then pcall(function() local desc=Instance.new("HumanoidDescription"); desc[guessSlot(name)]=idStr; local dummy=Players:CreateHumanoidModelFromDescription(desc,Enum.HumanoidRigType.R15,Enum.AssetTypeVerification.ClientOnly); desc:Destroy(); if dummy then for _,ch in pairs(dummy:GetChildren()) do if ch:IsA("Accessory") then ch.Parent=char; table.insert(parts,ch) end end; dummy:Destroy() end end) end
    if #parts==0 then
        if d.type=="Shirt" then local old=char:FindFirstChildOfClass("Shirt"); if old then old:Destroy() end; local s=Instance.new("Shirt"); s.ShirtTemplate="rbxassetid://"..idStr; s.Parent=char; table.insert(parts,s)
        elseif d.type=="Pants" then local old=char:FindFirstChildOfClass("Pants"); if old then old:Destroy() end; local p=Instance.new("Pants"); p.PantsTemplate="rbxassetid://"..idStr; p.Parent=char; table.insert(parts,p) end
    end
    if #parts>0 then equipped[name]=parts end
end

local function equipItem(n) if MESH_ITEMS[n] then equipMesh(n) elseif CLOTHING_ITEMS[n] then equipClothing(n) end end
local function unequipItem(n) if not equipped[n] then return end; for _,p in ipairs(equipped[n]) do if typeof(p)=="Instance" and p.Parent then p:Destroy() end end; equipped[n]=nil end

-- ============================================================
-- ITEMS TAB UI
-- ============================================================
Tabs.Items:AddParagraph({ Title="hats", Content="click to equip" })
for _,hat in ipairs(Hats) do local h=hat; Tabs.Items:AddButton({ Title=h.Name, Callback=function() EquipHat(h.Id,h.Type,h.Attach) end }) end
Tabs.Items:AddButton({ Title="reset hats", Callback=function() ResetHats() end })
Tabs.Items:AddParagraph({ Title="clothes", Content="click to equip" })
local allNames={}; for k in pairs(MESH_ITEMS) do table.insert(allNames,k) end; for k in pairs(CLOTHING_ITEMS) do table.insert(allNames,k) end; table.sort(allNames)
for _,n in ipairs(allNames) do local name=n; Tabs.Items:AddToggle("Acc_"..name,{ Title=name, Default=false, Callback=function(v) if v then equipItem(name) else unequipItem(name) end end }) end
Tabs.Items:AddButton({ Title="unequip all", Callback=function() local r={}; for n in pairs(equipped) do table.insert(r,n) end; for _,n in ipairs(r) do unequipItem(n) end end })

-- ============================================================
-- BANNERS DATA
-- ============================================================
local banners = {
    { name = "Default",                  id = 112295040558500  },
    { name = "Superbowl Stars",          id = 126094925053129  },
    { name = "Superbowl LX",             id = 121341076041829  },
    { name = "Superbowl City",           id = 110894574866000  },
    { name = "Superbowl Fresh",          id = 124763510166769  },
    { name = "Santa's Pass",             id = 90716099171823   },
    { name = "Six Santa",                id = 127624902123209  },
    { name = "Santa's Sleigh",           id = 87802662008505   },
    { name = "Chimney Ball",             id = 114151150562047  },
    { name = "Crow Ball",                id = 95842591799672   },
    { name = "Jack o' Ball",             id = 84669845678590   },
    { name = "Frontline Zombie",         id = 120813027794791  },
    { name = "Zombie Scrim",             id = 88178249725436   },
    { name = "Statue of Liberty",        id = 80257847701468   },
    { name = "Mount Rushmore",           id = 108911196712133  },
    { name = "Running Bunny",            id = 111967528103280  },
    { name = "Cracked Egg",              id = 100342824875125  },
    { name = "Bunny Hop",                id = 16884078157      },
    { name = "Easter Eggs",              id = 16884145047      },
    { name = "The Hunt",                 id = 16736725418      },
    { name = "Flurry",                   id = 15698354555      },
    { name = "Candy Stripes",            id = 15698354299      },
    { name = "Falling Leaves",           id = 15374548396      },
    { name = "Autumn Brush",             id = 15374548753      },
    { name = "Zombie Flesh",             id = 15190661655      },
    { name = "Fresh Brainzzz",           id = 15190661390      },
    { name = "Global Rank",              id = 13223858189      },
    { name = "All-Stars",                id = 14381436809      },
    { name = "Diamond Subscriber",       id = 14609114766      },
    { name = "Amethyst Subscriber",      id = 14609115033      },
    { name = "Brain Rot Banner",         id = 79392620471575   },
    { name = "Dead Eye Badge",           id = 13200974246      },
    { name = "Hall of Fame QB Badge",    id = 13200973681      },
    { name = "Magnet Badge",             id = 13200990824      },
    { name = "Hall of Fame WR Badge",    id = 13200990344      },
    { name = "Train Badge",              id = 13201007101      },
    { name = "Hall of Fame RB Badge",    id = 13201006582      },
    { name = "Hawkeye Badge",            id = 13201014142      },
    { name = "Hall of Fame CB Badge",    id = 13201014569      },
    { name = "Not Here Badge",           id = 13201024500      },
    { name = "Hall of Fame Tackler",     id = 13201024079      },
    { name = "Mr. Accuracy Badge",       id = 13191645181      },
    { name = "Hall of Fame Kicker",      id = 13191644670      },
    { name = "50M RAP",                  id = 13200847176      },
    { name = "Tutorial Badge",           id = 13200848635      },
    { name = "MVP OVR Badge",            id = 13191646278      },
    { name = "Legend OVR Badge",         id = 13191646767      },
    { name = "Hall of Fame OVR Badge",   id = 13191647168      },
    { name = "25x Pickup Streak",        id = 14123761844      },
    { name = "50x Pickup Streak",        id = 14123762825      },
    { name = "100x Pickup Streak",       id = 14123761136      },
    { name = "250x Pickup Streak",       id = 14123760585      },
    { name = "S22 Bronze",               id = 74894795486850   },
    { name = "S22 Silver",               id = 72536998042728   },
    { name = "S22 Gold",                 id = 91889521667861   },
    { name = "S22 Ruby",                 id = 121879282384659  },
    { name = "S22 Amethyst",             id = 133263903693331  },
    { name = "S22 Diamond",              id = 111861095468580  },
    { name = "S21 Bronze",               id = 123224847372033  },
    { name = "S21 Silver",               id = 99829570604682   },
    { name = "S21 Gold",                 id = 113656454685593  },
    { name = "S21 Ruby",                 id = 122119472462210  },
    { name = "S21 Amethyst",             id = 122108685734913  },
    { name = "S21 Diamond",              id = 101449031497845  },
    { name = "S20 Bronze",               id = 84074499871161   },
    { name = "S20 Silver",               id = 98702528026592   },
    { name = "S20 Gold",                 id = 116288231239199  },
    { name = "S20 Ruby",                 id = 78230623062968   },
    { name = "S20 Amethyst",             id = 82857029903524   },
    { name = "S20 Diamond",              id = 133250093302191  },
    { name = "S18 Bronze",               id = 138865094072965  },
    { name = "S18 Silver",               id = 74140927177572   },
    { name = "S18 Gold",                 id = 115702810329945  },
    { name = "S18 Ruby",                 id = 92476097898404   },
    { name = "S18 Amethyst",             id = 80278833808536   },
    { name = "S18 Diamond",              id = 97660917274307   },
    { name = "S17 Bronze",               id = 76160243656768   },
    { name = "S17 Silver",               id = 85862069325534   },
    { name = "S17 Gold",                 id = 117623911481469  },
    { name = "S17 Ruby",                 id = 117818637090228  },
    { name = "S17 Amethyst",             id = 71469317761062   },
    { name = "S17 Diamond",              id = 130518815889879  },
    { name = "S16 Bronze",               id = 82561011735388   },
    { name = "S16 Silver",               id = 118558170065579  },
    { name = "S16 Gold",                 id = 127783798974973  },
    { name = "S16 Ruby",                 id = 124794322397250  },
    { name = "S16 Amethyst",             id = 135481980512177  },
    { name = "S16 Diamond",              id = 104843296246576  },
    { name = "S15 Bronze",               id = 115478997568677  },
    { name = "S15 Silver",               id = 101961810406810  },
    { name = "S15 Gold",                 id = 137488860360656  },
    { name = "S15 Ruby",                 id = 135742471654314  },
    { name = "S15 Amethyst",             id = 84843935717350   },
    { name = "S15 Diamond",              id = 123822213591241  },
    { name = "S14 Bronze",               id = 71453219899116   },
    { name = "S14 Silver",               id = 128622100078792  },
    { name = "S14 Gold",                 id = 89119756630307   },
    { name = "S14 Ruby",                 id = 123368190913288  },
    { name = "S14 Amethyst",             id = 72004408552553   },
    { name = "S14 Diamond",              id = 86077856254167   },
    { name = "S13 Bronze",               id = 88252265440518   },
    { name = "S13 Silver",               id = 123709512603188  },
    { name = "S13 Gold",                 id = 126380847903396  },
    { name = "S13 Ruby",                 id = 135781578921878  },
    { name = "S13 Amethyst",             id = 111891729673888  },
    { name = "S13 Diamond",              id = 119382474315638  },
    { name = "S12 Bronze",               id = 72032268123816   },
    { name = "S12 Silver",               id = 134848020835906  },
    { name = "S12 Gold",                 id = 125185481052489  },
    { name = "S12 Ruby",                 id = 112351835222343  },
    { name = "S12 Amethyst",             id = 89280743424541   },
    { name = "S12 Diamond",              id = 99463365545177   },
    { name = "S11 Bronze",               id = 128083109569569  },
    { name = "S11 Silver",               id = 75235634092054   },
    { name = "S11 Gold",                 id = 124963755433657  },
    { name = "S11 Ruby",                 id = 120987599176464  },
    { name = "S11 Amethyst",             id = 115076741889428  },
    { name = "S11 Diamond",              id = 117973703088191  },
    { name = "S10 Bronze",               id = 134175797968591  },
    { name = "S10 Silver",               id = 132736181536588  },
    { name = "S10 Gold",                 id = 78248158623744   },
    { name = "S10 Ruby",                 id = 77637590866893   },
    { name = "S10 Amethyst",             id = 124277936853751  },
    { name = "S10 Diamond",              id = 106376678056593  },
    { name = "S9 Bronze",                id = 18635949397      },
    { name = "S9 Silver",                id = 18635948865      },
    { name = "S9 Gold",                  id = 18635949101      },
    { name = "S9 Ruby",                  id = 18635949835      },
    { name = "S9 Amethyst",              id = 18635948527      },
    { name = "S9 Diamond",               id = 18635950072      },
    { name = "S8 Bronze",                id = 17734405916      },
    { name = "S8 Silver",                id = 17734404096      },
    { name = "S8 Gold",                  id = 17734404919      },
    { name = "S8 Ruby",                  id = 17734404546      },
    { name = "S8 Amethyst",              id = 17734406386      },
    { name = "S8 Diamond",               id = 17734405387      },
    { name = "S7 Bronze",                id = 16262053405      },
    { name = "S7 Silver",                id = 16262054200      },
    { name = "S7 Gold",                  id = 16262053766      },
    { name = "S7 Ruby",                  id = 16262053907      },
    { name = "S7 Amethyst",              id = 16262053273      },
    { name = "S7 Diamond",               id = 16262053580      },
    { name = "S4 Bronze",                id = 14886347179      },
    { name = "S4 Silver",                id = 14886348676      },
    { name = "S4 Gold",                  id = 14886347968      },
    { name = "S4 Ruby",                  id = 14886348321      },
    { name = "S4 Amethyst",              id = 14886346828      },
    { name = "S4 Diamond",               id = 14886347562      },
    { name = "S3 Bronze",                id = 14123730472      },
    { name = "S3 Silver",                id = 14123732862      },
    { name = "S3 Gold",                  id = 14123731567      },
    { name = "S3 Ruby",                  id = 14123732251      },
    { name = "S3 Amethyst",              id = 14123729878      },
    { name = "S3 Diamond",               id = 14123731049      },
    { name = "S2 Bronze",                id = 13623689876      },
    { name = "S2 Silver",                id = 13623688544      },
    { name = "S2 Gold",                  id = 13623689162      },
    { name = "S2 Ruby",                  id = 13623688828      },
    { name = "S2 Amethyst",              id = 13623690243      },
    { name = "S2 Diamond",               id = 13623689625      },
    { name = "S1 Bronze",                id = 13181358124      },
    { name = "S1 Silver",                id = 13181356403      },
    { name = "S1 Gold",                  id = 13225419878      },
    { name = "S1 Ruby",                  id = 13181356660      },
    { name = "S1 Amethyst",              id = 13181358632      },
    { name = "S1 Diamond",               id = 13181357760      },
    { name = "Alpha Tester",             id = 13284242200      },
    { name = "Beta Tester",              id = 13200846561      },
    { name = "Content Creator",          id = 13181356130      },
    { name = "Content Creator (Twitch)", id = 13284240977      },
    { name = "Content Creator (TikTok)", id = 14308515186      },
    { name = "Owner (clxr)",             id = 13284241627      },
    { name = "Developer",                id = 13400894306      },
    { name = "Staff",                    id = 13284239964      },
    { name = "Alabama Black Bears",      id = 14123680598      },
    { name = "Arizona Firebirds",        id = 14123701297      },
    { name = "Atlantis Tridents",        id = 14123683088      },
    { name = "Barton Bruisers",          id = 14124071977      },
    { name = "Birmingham Bluebirds",     id = 14123679379      },
    { name = "Canton Bulldogs",          id = 14124072715      },
    { name = "Charlotte Monarchs",       id = 14124080856      },
    { name = "Colorado Blizzards",       id = 14123680210      },
    { name = "Dallas Dragons",           id = 14123684671      },
    { name = "Honolulu Volcanoes",       id = 14221131675      },
    { name = "Houston Hornets",          id = 14123700844      },
    { name = "Korblox Kobras",           id = 14123691704      },
    { name = "Las Vegas Jackpots",       id = 14123698117      },
    { name = "Los Angeles Tigers",       id = 14124076399      },
    { name = "Lua Lions",                id = 14123693587      },
    { name = "Mexico City Aztecs",       id = 14123682485      },
    { name = "Miami Sunshine",           id = 14124077325      },
    { name = "Minnesota Huskies",        id = 14124075334      },
    { name = "Nashville Nightmares",     id = 14124080102      },
    { name = "Nevada Miners",            id = 14124074796      },
    { name = "New England Musketeers",   id = 14123704771      },
    { name = "New York Knights",         id = 14123697249      },
    { name = "Oklahoma Storm Chasers",   id = 14124077846      },
    { name = "Orlando Lightning",        id = 14123694270      },
    { name = "Pemberley Punishers",      id = 14124078468      },
    { name = "Philadelphia Liberties",   id = 14123696611      },
    { name = "Roblox Warriors",          id = 14124075847      },
    { name = "Salt Lake City Stallions", id = 14123712644      },
    { name = "San Diego Cruisers",       id = 14124074052      },
    { name = "San Francisco Comets",     id = 14124073327      },
    { name = "Santa Fe Outlaws",         id = 14124079232      },
    { name = "Seattle Evergreens",       id = 14123683879      },
}

-- ============================================================
-- BANNER EQUIP FUNCTION (fixed: uses plr instead of LocalPlayer)
-- ============================================================
local function equipBanner(id)
    local imageIdStr = "rbxassetid://" .. tostring(id)
    for _, gui in pairs(plr.PlayerGui:GetDescendants()) do
        if gui.Name == "BaseImage" and gui:IsA("ImageLabel") then
            pcall(function() gui.Image = imageIdStr end)
        end
    end
    local char = plr.Character
    if char then
        for _, v in pairs(char:GetDescendants()) do
            if v.Name == "BaseImage" and v:IsA("ImageLabel") then
                pcall(function() v.Image = imageIdStr end)
            end
        end
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("Decal") then
                local part = desc.Parent
                if part and (
                    part.Name:lower():find("banner") or
                    part.Name:lower():find("tag") or
                    part.Name:lower():find("street")
                ) then
                    pcall(function() desc.Texture = imageIdStr end)
                end
            end
        end
    end
    for _, gui in pairs(plr.PlayerGui:GetDescendants()) do
        if gui.Name == "Content" and gui:IsA("ImageLabel") then
            local parent = gui.Parent
            if parent and parent.Name == "Icons" then
                pcall(function() gui.Image = imageIdStr end)
            end
        end
    end
end

-- ============================================================
-- VISUALS TAB (Banners)
-- ============================================================
local bannerNames = {}
for _, b in ipairs(banners) do
    table.insert(bannerNames, b.name)
end

Tabs.Visuals:AddParagraph({ Title = "Banners", Content = "Select a banner from the dropdown and click Apply." })
Tabs.Visuals:AddDropdown("BannerSelect", {
    Title = "Select Banner",
    Values = bannerNames,
    Default = bannerNames[1],
    Multi = false,
    Callback = function(v)
        for _, b in ipairs(banners) do
            if b.name == v then
                equipBanner(b.id)
                break
            end
        end
    end
})
Tabs.Visuals:AddButton({
    Title = "Apply Banner",
    Callback = function()
        local selected = Options.BannerSelect.Value
        for _, b in ipairs(banners) do
            if b.name == selected then
                equipBanner(b.id)
                break
            end
        end
    end
})

-- ============================================================
-- SETTINGS TAB
-- ============================================================
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:SetFolder("Volzy")
SaveManager:SetIgnoreIndexes({})
SaveManager:LoadAutoloadConfig()

-- ============================================================
-- CLEANUP
-- ============================================================
plr.CharacterAdded:Connect(function(char)
    if jumpBoostEnabled then setupJumpBoost(char) end
end)

game.Players.PlayerRemoving:Connect(function(p)
    if p == plr then
        ConnectionManager:CleanupAll()
        if diveBoostConnection  then diveBoostConnection:Disconnect()  end
        if autoFollowConnection then autoFollowConnection:Disconnect() end
    end
    if autoDBTarget == p then
        autoDBTarget = nil
        if autoDBEnabled then autoDBTarget = findNearestPlayer() end
    end
end)

Fluent:Notify({ Title="Volzy hub", Content="NFL Universe loaded! Press RCtrl to toggle.", Duration=5 })