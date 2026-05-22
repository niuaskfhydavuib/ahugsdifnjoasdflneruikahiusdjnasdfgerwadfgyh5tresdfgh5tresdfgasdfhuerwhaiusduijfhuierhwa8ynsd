local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local plr = Players.LocalPlayer

local magnetEnabled = false
local touchRange = 15
local updateConnection = nil
local wsEnabled = false
local wsSpeed = 16
local wsConnection = nil

local cachedFootballs = {}
local lastScan = 0

local function scanFootballs()
    local now = tick()
    if now - lastScan < 0.5 then return end
    lastScan = now
    cachedFootballs = {}
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj.Anchored and obj.Name:lower():find("football") then
            table.insert(cachedFootballs, obj)
        end
    end
end

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("BasePart") and not obj.Anchored and obj.Name:lower():find("football") then
        table.insert(cachedFootballs, obj)
    end
end)

local function getCatchParts()
    local char = plr.Character
    if not char then return nil, nil end
    local ws = Workspace:FindFirstChild(plr.Name)
    local catchLeft = char:FindFirstChild("CatchLeft") or (ws and ws:FindFirstChild("CatchL"))
    local catchRight = char:FindFirstChild("CatchRight") or (ws and ws:FindFirstChild("CatchR"))
    return catchLeft, catchRight
end

local function getClosestCatchPart(pos)
    local catchLeft, catchRight = getCatchParts()
    if not catchLeft and not catchRight then return nil end
    if not catchRight then return catchLeft end
    if not catchLeft then return catchRight end
    if (catchLeft.Position - pos).Magnitude < (catchRight.Position - pos).Magnitude then
        return catchLeft
    end
    return catchRight
end

local function magnetFootball()
    if not magnetEnabled then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    scanFootballs()

    local hrpPos = hrp.Position

    for i = #cachedFootballs, 1, -1 do
        local football = cachedFootballs[i]
        if not football or not football.Parent then
            table.remove(cachedFootballs, i)
            continue
        end

        local ancestor = football:FindFirstAncestorOfClass("Model")
        if ancestor and Players:GetPlayerFromCharacter(ancestor) then continue end

        local dist = (football.Position - hrpPos).Magnitude
        if dist > touchRange then continue end

        local catch = getClosestCatchPart(football.Position)
        if not catch then continue end

        pcall(function()
            firetouchinterest(catch, football, 0)
            firetouchinterest(catch, football, 1)
        end)
    end
end

local hitboxBoxes = {}

local function clearHitboxes()
    for _, box in pairs(hitboxBoxes) do
        if box and box.Parent then box:Destroy() end
    end
    hitboxBoxes = {}
end

local hitboxConnection = nil

local function startWalkspeed()
    if wsConnection then wsConnection:Disconnect() end
    wsConnection = RunService.Heartbeat:Connect(function()
        if not wsEnabled then return end
        local char = plr.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        if hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (wsSpeed / 60))
        end
    end)
end

-- UI
local Window = Rayfield:CreateWindow({
    Name = "Football Fusion 3 | made by @coldcomplxtion",
    LoadingTitle = "Volzyhub",
    LoadingSubtitle = "by @coldcomplxtion",
    Theme = "Light",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "FootballFusion3",
        FileName = "Volzyhub"
    }
})

local Catching = Window:CreateTab("Catching", nil)
local MovementTab = Window:CreateTab("Movement", nil)
local SettingsTab = Window:CreateTab("Settings", nil)

-- Catching Tab
Catching:CreateToggle({
    Name = "Enable Magnets",
    CurrentValue = false,
    Flag = "MagnetToggle",
    Callback = function(Value)
        magnetEnabled = Value
        if Value then
            if updateConnection then updateConnection:Disconnect() end
            cachedFootballs = {}
            lastScan = 0
            updateConnection = RunService.Heartbeat:Connect(magnetFootball)
        else
            if updateConnection then updateConnection:Disconnect(); updateConnection = nil end
        end
    end,
})

Catching:CreateSlider({
    Name = "TouchInterest Range",
    Range = {1, 200},
    Increment = 1,
    CurrentValue = 15,
    Flag = "TouchRange",
    Callback = function(Value) touchRange = Value end,
})

-- Movement Tab
MovementTab:CreateToggle({
    Name = "CFrame Walkspeed",
    CurrentValue = false,
    Flag = "WSToggle",
    Callback = function(Value)
        wsEnabled = Value
        if Value then
            startWalkspeed()
        else
            if wsConnection then wsConnection:Disconnect(); wsConnection = nil end
        end
    end,
})

MovementTab:CreateSlider({
    Name = "CFrame Walkspeed",
    Range = {0.1, 2},
    Increment = 0.1,
    CurrentValue = 0.1,
    Flag = "WSSpeed",
    Callback = function(Value) wsSpeed = Value end,
})

-- Settings Tab
SettingsTab:CreateDropdown({
    Name = "UI Theme",
    Options = {"Default", "Ocean", "AmberGlow", "Light", "Amethyst", "Green", "Bloom", "DarkBlue", "Serenity"},
    CurrentOption = {"Light"},
    MultipleOptions = false,
    Flag = "ThemeDropdown",
    Callback = function(selected)
        Window.ModifyTheme(selected[1])
    end,
})

game.Players.PlayerRemoving:Connect(function(p)
    if p == plr then
        if updateConnection then updateConnection:Disconnect() end
        if hitboxConnection then hitboxConnection:Disconnect(); hitboxConnection = nil end
        if wsConnection then wsConnection:Disconnect() end
        clearHitboxes()
    end
end)
