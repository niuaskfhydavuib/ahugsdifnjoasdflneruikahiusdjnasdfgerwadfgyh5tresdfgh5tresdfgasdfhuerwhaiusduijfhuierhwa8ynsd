-- Basketball Legends Script
-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- Variables
local autoShootEnabled = false
local shootPower = 1.0
local autoGuardToggleEnabled = false
local autoGuardEnabled = false
local holdingG = false
local predictionTime = 0.3
local guardDistance = 10
local lastPositions = {}
local visibleConn = nil
local autoGuardConnection = nil

-- Create Fluent Window
local Window = Fluent:CreateWindow({
    Title = "Basketball Legends |  Volzy Hub",
    SubTitle = "by @coldcomplxtion",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Create Tabs
local Tabs = {
    Shooting = Window:AddTab({ Title = "Shooting", Icon = "target" }),
    Guard = Window:AddTab({ Title = "Guard", Icon = "shield" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "settings" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "sliders" })
}

-- Get shooting GUI
local visualGui = player.PlayerGui:WaitForChild("Visual")
local shootingElement = visualGui:WaitForChild("Shooting")
local Shoot = ReplicatedStorage.Packages.Knit.Services.ControlService.RE.Shoot

-- Helper Functions
local function IsPark()
    if workspace:WaitForChild("Game"):FindFirstChild("Courts") then
        return true
    else
        return false
    end
end

local isPark = IsPark()

local function getPlayerFromModel(model)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character == model then
            return plr
        end
    end
    return nil
end

local function isOnDifferentTeam(otherModel)
    local otherPlayer = getPlayerFromModel(otherModel)
    if not otherPlayer then return false end
    
    if not player.Team or not otherPlayer.Team then
        return otherPlayer ~= player
    end
    
    return player.Team ~= otherPlayer.Team
end

local function findPlayerWithBall()
    if isPark then
        local closestPlayer = nil
        local closestDistance = math.huge

        for _, model in pairs(workspace:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
                local tool = model:FindFirstChild("Basketball")
                if tool and tool:IsA("Tool") then
                    local hrp = model.HumanoidRootPart
                    local dist = (hrp.Position - player.Character.HumanoidRootPart.Position).Magnitude
                    if dist < closestDistance then
                        closestDistance = dist
                        closestPlayer = model
                    end
                end
            end
        end

        if closestPlayer then
            return closestPlayer, closestPlayer:FindFirstChild("HumanoidRootPart")
        end

        return nil, nil
    end

    local looseBall = workspace:FindFirstChild("Basketball")
    if looseBall and looseBall:IsA("BasePart") then
        local closestPlayer = nil
        local closestDistance = math.huge
        
        for _, model in pairs(workspace:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
                if isOnDifferentTeam(model) then
                    local rootPart = model:FindFirstChild("HumanoidRootPart")
                    local distance = (looseBall.Position - rootPart.Position).Magnitude
                    
                    if distance < closestDistance and distance < 15 then
                        closestDistance = distance
                        closestPlayer = model
                    end
                end
            end
        end
        
        if closestPlayer then
            return closestPlayer, closestPlayer:FindFirstChild("HumanoidRootPart")
        end
    end
    
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
            if isOnDifferentTeam(model) then
                local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
                local basketball = model:FindFirstChild("Basketball")
                
                if basketball and basketball:IsA("Tool") then
                    return model, humanoidRootPart
                end
            end
        end
    end
    
    return nil, nil
end

local function autoGuard()
    if not autoGuardEnabled then return end

-- 🛑 STOP GUARD DURING SHOOT
if shootingElement and shootingElement.Visible then return end

if Players.LocalPlayer:FindFirstChild("Basketball") then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    
    local ballCarrier, ballCarrierRoot = findPlayerWithBall()
    
    if ballCarrier and ballCarrierRoot then
        local distance = (rootPart.Position - ballCarrierRoot.Position).Magnitude
        local currentPos = ballCarrierRoot.Position
        local velocity = Vector3.new(0, 0, 0)
        
        if lastPositions[ballCarrier] then
            velocity = (currentPos - lastPositions[ballCarrier]) / task.wait()
        end
        lastPositions[ballCarrier] = currentPos
        
        local predictedPos = currentPos + (velocity * predictionTime * 60)
        local directionToOpponent = (predictedPos - rootPart.Position).Unit
        local defensiveOffset = directionToOpponent * 5
        local defensivePosition = predictedPos - defensiveOffset
        
        defensivePosition = Vector3.new(defensivePosition.X, rootPart.Position.Y, defensivePosition.Z)
        
        if distance <= guardDistance then
            humanoid:MoveTo(defensivePosition)
            
            local VirtualInputManager = game:GetService("VirtualInputManager")
            if distance <= 10 then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            else
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end
        else
            local VirtualInputManager = game:GetService("VirtualInputManager")
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
    else
        local VirtualInputManager = game:GetService("VirtualInputManager")
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end
end

-- Shooting Tab (clean + fixed)

local lastShot = 0
local shotDelay = 0.25

local lastShot = 0
local shotDelay = 0.25

Tabs.Shooting:AddToggle("AutoShoot", {
    Title = "Auto Shoot",
    Default = false,
    Callback = function(value)
        autoShootEnabled = value

        if autoShootEnabled then
            if not visibleConn then
                visibleConn = shootingElement:GetPropertyChangedSignal("Visible"):Connect(function()
                    if not autoShootEnabled then return end

                    if shootingElement.Visible then
                        if tick() - lastShot >= shotDelay then
                            lastShot = tick()
                            task.wait(0.25)
                            Shoot:FireServer(shootPower)
                        end
                    end
                end)
            end
        else
            if visibleConn then
                visibleConn:Disconnect()
                visibleConn = nil
            end
        end
    end
})

Tabs.Shooting:AddDropdown("ReleaseType", {
    Title = "Release Timing",
    Values = {"Perfect", "Great", "Good"},
    Default = "Perfect",
    Callback = function(value)
        if value == "Perfect" then
            shootPower = 1.0
        elseif value == "Great" then
            shootPower = 0.95
        elseif value == "Good" then
            shootPower = 0.90
        end
    end
})


-- Guard Tab
Tabs.Guard:AddToggle("AutoGuard", {
    Title = "Auto Guard",
    Description = "Enable auto guard (hold G to activate)",
    Default = false,
    Callback = function(value)
        autoGuardToggleEnabled = value
        
        if not value then
            autoGuardEnabled = false
            if autoGuardConnection then
                autoGuardConnection:Disconnect()
                autoGuardConnection = nil
            end
            
            lastPositions = {}
            
            local VirtualInputManager = game:GetService("VirtualInputManager")
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
    end
})

Tabs.Guard:AddSlider("GuardDistance", {
    Title = "Guard Distance",
    Description = "Maximum distance to start guarding",
    Default = 10,
    Min = 5,
    Max = 20,
    Rounding = 0,
    Callback = function(value)
        guardDistance = value
    end
})

Tabs.Guard:AddSlider("PredictionTime", {
    Title = "Prediction Time",
    Description = "How far ahead to predict movement",
    Default = 0.3,
    Min = 0.1,
    Max = 0.8,
    Rounding = 1,
    Callback = function(value)
        predictionTime = value
    end
})

Tabs.Guard:AddParagraph({
    Title = "How to Use",
    Content = "1. Enable Auto Guard toggle\n2. Hold G key to activate\n3. Will auto-position and hold F\n4. Release G to stop"
})

-- Input handlers for Auto Guard
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.G and not gameProcessed then
        if autoGuardToggleEnabled then
            holdingG = true
            autoGuardEnabled = true
            lastPositions = {}
            if not autoGuardConnection then
                autoGuardConnection = RunService.Heartbeat:Connect(autoGuard)
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.G then
        holdingG = false
        autoGuardEnabled = false
        
        if autoGuardConnection then
            autoGuardConnection:Disconnect()
            autoGuardConnection = nil
        end
        
        lastPositions = {}
        
        local VirtualInputManager = game:GetService("VirtualInputManager")
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end
end)

-- Misc Tab - Teleporter
local placesList = {}
local loadingPlaces = false

local PlaceDropdown = Tabs.Misc:AddDropdown("TeleportPlace", {
    Title = "Select Place",
    Description = "Choose a place to teleport to",
    Values = {"Loading places..."},
    Default = 1
})

local function loadPlaces()
    if loadingPlaces then return end
    loadingPlaces = true
    
    local Http = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or (request) or (http_request)
    
    if not Http then
        PlaceDropdown:SetValues({"Current Place"})
        placesList["Current Place"] = game.PlaceId
        loadingPlaces = false
        return
    end
    
    local universeId = game.GameId
    local url = "https://develop.roblox.com/v1/universes/" .. universeId .. "/places?limit=100"
    
    local success, response = pcall(function()
        return Http({
            Url = url,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Roblox/WinInet",
                ["Content-Type"] = "application/json"
            }
        })
    end)
    
    if success and response and response.Body then
        local decodeSuccess, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        
        if decodeSuccess and data and data.data then
            for _, place in ipairs(data.data) do
                if place.name and place.id then
                    local displayName = place.name
                    if place.isRootPlace then
                        displayName = displayName .. " (Root)"
                    end
                    placesList[displayName] = place.id
                end
            end
        end
    end
    
    local placeNames = {}
    for name, _ in pairs(placesList) do
        table.insert(placeNames, name)
    end
    table.sort(placeNames)
    
    if #placeNames > 0 then
        PlaceDropdown:SetValues(placeNames)
        PlaceDropdown:SetValue(placeNames[1])
    else
        PlaceDropdown:SetValues({"Current Place"})
        placesList["Current Place"] = game.PlaceId
    end
    
    loadingPlaces = false
end

task.spawn(loadPlaces)

Tabs.Misc:AddButton({
    Title = "Teleport to Place",
    Description = "Teleport to selected place",
    Callback = function()
        local selected = PlaceDropdown.Value
        local placeId = placesList[selected]
        
        if placeId then
            Fluent:Notify({
                Title = "Teleporting",
                Content = "Teleporting to " .. selected .. "...",
                Duration = 3
            })
            
            TeleportService:Teleport(placeId)
        end
    end
})

Tabs.Misc:AddButton({
    Title = "Rejoin Current Server",
    Description = "Rejoin your current server",
    Callback = function()
        Fluent:Notify({
            Title = "Rejoining",
            Content = "Rejoining current server...",
            Duration = 3
        })
        
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end
})

Tabs.Misc:AddButton({
    Title = "Server Hop",
    Description = "Join server with least players",
    Callback = function()
        Fluent:Notify({
            Title = "Server Hopping",
            Content = "Finding best server...",
            Duration = 3
        })
        
        local servers = {}
        local cursor = ""
        
        repeat
            local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. cursor
            
            local success, result = pcall(function()
                return game:HttpGet(url)
            end)
            
            if success then
                local decoded = HttpService:JSONDecode(result)
                cursor = decoded.nextPageCursor or ""
                
                for _, server in pairs(decoded.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        table.insert(servers, server)
                    end
                end
            else
                break
            end
        until cursor == ""
        
        if #servers > 0 then
            table.sort(servers, function(a, b)
                return a.playing < b.playing
            end)
            
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, player)
        else
            Fluent:Notify({
                Title = "Server Hop Failed",
                Content = "No available servers found",
                Duration = 3
            })
        end
    end
})

-- Settings
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("BasketballLegends")
SaveManager:SetFolder("BasketballLegends/Volzyhub")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)

SaveManager:LoadAutoloadConfig()

-- Notification
Fluent:Notify({
    Title = "Basketball Legends",
    Content = "Volzy hub loaded!",
    Duration = 3
})

-- Cleanup
game:GetService("Players").PlayerRemoving:Connect(function(plr)
    if plr == player then
        if visibleConn then
            visibleConn:Disconnect()
        end
        if autoGuardConnection then
            autoGuardConnection:Disconnect()
        end
    end
end)