local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

-- Переменные для полёта
local isFlying = false
local flySpeed = 50
local bodyVelocity = nil
local bodyGyro = nil
local flightConnection = nil
local draggingFlight = false
local boundKeyFly = Enum.KeyCode.F

-- Переменные для биндов
local boundKeyPartSpawn = Enum.KeyCode.P
local boundKeyFloat = Enum.KeyCode.O
local boundKeyDirection = Enum.KeyCode.U
local boundKeyTeleport = Enum.KeyCode.T
local boundKeySpeed = Enum.KeyCode.R
local boundKeyCFrameSpeed = Enum.KeyCode.E
local boundKeyScreenVisibility = Enum.KeyCode.V
local spawnDirection = "Forward"
local spawnDistance = 5
local underFeetPart = nil
local directionPart = nil
local renderConnection = nil
local deathPosition = nil
local teleportOnDeathEnabled = false
local flingEnabled = false
local targetPlayer = nil
local walkSpeed = 16
local speedEnabled = false
local cframeSpeed = 2
local cframeSpeedEnabled = false
local cframeConnection = nil
local touchConnection = nil
local movingPart = nil
local movingPartConnection = nil
local movingPartEnabled = false
local movingPartDistance = 5

-- Переменные для следования за игроком
local followEnabled = false
local followConnection = nil
local followTargetPlayer = nil
local followDistance = 3 -- Расстояние сзади игрока
local approachDistance = 10 -- Дистанция, с которой начинается подлёт

-- Переменные для объекта Screen
local screen = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Screens") and Workspace.Map.Screens:FindFirstChild("Leaderboards") and Workspace.Map.Screens.Leaderboards:FindFirstChild("Total") and Workspace.Map.Screens.Leaderboards.Total:FindFirstChild("Screen")
local screenVisible = true
local beam = screen:FindFirstChild("Beam")
if beam then beam:Destroy() end
local surfacegui = screen and screen:FindFirstChild("SurfaceGui")
if surfacegui then surfacegui.Enabled = false end

-- Переменные для свойств Direction Part
local directionPartSize = Vector3.new(5, 1, 5)
local directionPartColor = BrickColor.new("Bright red")
local directionPartTransparency = 0
local directionPartCanCollide = true
local directionPartAnchored = true

-- Таблица для хранения соединений
local connections = {}

-- Инициализация объекта Screen
if screen then
    if screen:IsA("BasePart") then
        screen.Size = Vector3.new(3, 3, 3)
        screen.CanCollide = true
        screen.Transparency = 0
        table.insert(connections, RunService.Heartbeat:Connect(function()
            if char and char:FindFirstChild("HumanoidRootPart") then
                screen.Position = char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 5
            end
        end))
    elseif screen:IsA("Model") then
        for _, child in pairs(screen:GetChildren()) do
            if child:IsA("BasePart") then
                child.Size = Vector3.new(3, 3, 3)
                child.CanCollide = true
                child.Transparency = 0
            end
        end
        table.insert(connections, RunService.Heartbeat:Connect(function()
            if char and char:FindFirstChild("HumanoidRootPart") then
                screen:SetPrimaryPartCFrame(CFrame.new(char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 5))
            end
        end))
    end
    print("Screen resized to 3,3,3 and follows player with CanCollide = true!")
else
    print("Object at Workspace.Map.Screens.Leaderboards.Total.Screen not found!")
end

-- Функция для переключения видимости Screen
local function toggleScreenVisibility()
    screenVisible = not screenVisible
    local transparencyValue = screenVisible and 0 or 0.99
    if screen then
        if screen:IsA("BasePart") then
            screen.Transparency = transparencyValue
        elseif screen:IsA("Model") then
            for _, child in pairs(screen:GetChildren()) do
                if child:IsA("BasePart") then
                    child.Transparency = transparencyValue
                end
            end
        end
        print("Screen Visibility: " .. (screenVisible and "On" or "Off"))
    else
        print("Screen object not found for toggling visibility!")
    end
end

-- Функция для включения полёта
local function startFlying()
    if isFlying then return end
    isFlying = true
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = rootPart
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.CFrame = workspace.CurrentCamera.CFrame
    bodyGyro.Parent = rootPart
    
    humanoid.PlatformStand = true
    flightConnection = RunService.RenderStepped:Connect(function()
        if isFlying and char and rootPart then
            local moveDirection = Vector3.new(0, 0, 0)
            local camera = workspace.CurrentCamera
            local camCFrame = camera.CFrame
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection = moveDirection + camCFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection = moveDirection - camCFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDirection = moveDirection - camCFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDirection = moveDirection + camCFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDirection = moveDirection + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                moveDirection = moveDirection - Vector3.new(0, 1, 0)
            end
            
            if moveDirection.Magnitude > 0 then
                bodyVelocity.Velocity = moveDirection.Unit * flySpeed
                bodyGyro.CFrame = camCFrame
            else
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end
    end)
    table.insert(connections, flightConnection)
    print("Flight enabled! Use W, A, S, D, Space, LeftControl, and mouse!")
end

-- Функция для выключения полёта
local function stopFlying()
    if not isFlying then return end
    isFlying = false
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if flightConnection then flightConnection:Disconnect() flightConnection = nil end
    humanoid.PlatformStand = false
    print("Flight disabled!")
end

-- Функция для создания парта в направлении (Part Spawn)
local function createPart()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
        local root = player.Character.HumanoidRootPart
        local humanoid = player.Character.Humanoid
        local offset = Vector3.new(0, 0, 0)
        
        if spawnDirection == "Forward" then
            offset = root.CFrame.LookVector * spawnDistance
        elseif spawnDirection == "Left" then
            offset = -root.CFrame.RightVector * spawnDistance
        elseif spawnDirection == "Right" then
            offset = root.CFrame.RightVector * spawnDistance
        elseif spawnDirection == "Back" then
            offset = -root.CFrame.LookVector * spawnDistance
        end
        
        local part = Instance.new("Part")
        part.Name = "GeneratedPart"
        part.Size = Vector3.new(5, 1, 5)
        part.Position = root.Position + offset - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight + part.Size.Y / 2, 0)
        part.Anchored = true
        part.BrickColor = BrickColor.new("Bright red")
        part.Parent = Workspace
        print("Part created in direction " .. spawnDirection .. ": " .. tostring(part.Position))
    else
        print("Character or Humanoid not loaded!")
    end
end

-- Функция для создания парта под ногами (Direction Part)
local function createDirectionPart()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
        if directionPart then
            directionPart:Destroy()
            directionPart = nil
            print("Previous Direction Part destroyed!")
        end
        local root = player.Character.HumanoidRootPart
        local humanoid = player.Character.Humanoid
        local yPosition = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight + directionPartSize.Y / 2)
        
        directionPart = Instance.new("Part")
        directionPart.Name = "DirectionPart"
        directionPart.Size = directionPartSize
        directionPart.Position = Vector3.new(root.Position.X, yPosition, root.Position.Z)
        directionPart.BrickColor = directionPartColor
        directionPart.Transparency = directionPartTransparency
        directionPart.CanCollide = directionPartCanCollide
        directionPart.Anchored = directionPartAnchored
        directionPart.Parent = Workspace
        print("Direction Part created under feet: " .. tostring(directionPart.Position))
    else
        print("Character or Humanoid not loaded!")
    end
end

-- Функция для спавна/удаления парта под ногами с движением по X, Z (Float)
local function toggleUnderFeetPart()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
        if underFeetPart == nil then
            local root = player.Character.HumanoidRootPart
            local humanoid = player.Character.Humanoid
            underFeetPart = Instance.new("Part")
            underFeetPart.Name = "UnderFeetPart"
            underFeetPart.Size = Vector3.new(5, 1, 5)
            local initialY = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight + underFeetPart.Size.Y / 2)
            underFeetPart.Position = Vector3.new(root.Position.X, initialY, root.Position.Z)
            underFeetPart.Anchored = true
            underFeetPart.BrickColor = BrickColor.new("Bright green")
            underFeetPart.Parent = Workspace
            
            renderConnection = RunService.RenderStepped:Connect(function()
                if underFeetPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local rootPos = player.Character.HumanoidRootPart.Position
                    underFeetPart.Position = Vector3.new(rootPos.X, initialY, rootPos.Z)
                end
            end)
            table.insert(connections, renderConnection)
            print("Float Part created and bound to X, Z at height " .. initialY .. ": " .. tostring(underFeetPart.Position))
        else
            if renderConnection then
                renderConnection:Disconnect()
                renderConnection = nil
            end
            if underFeetPart then
                underFeetPart:Destroy()
                underFeetPart = nil
            end
            print("Float Part destroyed!")
        end
    else
        print("Character or Humanoid not loaded!")
    end
end

-- Функция для удаления всех партов
local function deleteAllParts()
    local partsDeleted = 0
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Part") and (child.Name == "GeneratedPart" or child.Name == "MovingPart" or child.Name == "UnderFeetPart" or child.Name == "DirectionPart") then
            child:Destroy()
            partsDeleted = partsDeleted + 1
        end
    end
    directionPart = nil
    underFeetPart = nil
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    print("Deleted " .. partsDeleted .. " Part(s)")
end

-- Функция для активации флинга при касании
local function activateFlingOnTouch(hit)
    local humanoid = hit.Parent:FindFirstChild("Humanoid")
    if humanoid and hit.Parent:FindFirstChild("HumanoidRootPart") and Players:GetPlayerFromCharacter(hit.Parent) ~= player and flingEnabled then
        targetPlayer = Players:GetPlayerFromCharacter(hit.Parent)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = targetPlayer.Character.HumanoidRootPart
            local direction = (targetRoot.Position - player.Character.HumanoidRootPart.Position).Unit
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Velocity = direction * 100
            bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bodyVelocity.Parent = targetRoot
            wait(0.1)
            bodyVelocity:Destroy()
            print("Flinged " .. targetPlayer.Name)
        end
    end
end

-- Функция для переключения следования за игроком с автоматическим подлётом
local function toggleFollow(targetName)
    local newTarget = Players:FindFirstChild(targetName)
    if newTarget and newTarget.Character and newTarget.Character:FindFirstChild("HumanoidRootPart") and newTarget ~= player then
        followTargetPlayer = newTarget
        followEnabled = not followEnabled
        if followEnabled then
            if followConnection then followConnection:Disconnect() end
            humanoid.PlatformStand = true -- Включаем "полёт"
            followConnection = RunService.Heartbeat:Connect(function()
                if followTargetPlayer and followTargetPlayer.Character and followTargetPlayer.Character:FindFirstChild("HumanoidRootPart") and char and char:FindFirstChild("HumanoidRootPart") then
                    local targetRoot = followTargetPlayer.Character.HumanoidRootPart
                    local distance = (rootPart.Position - targetRoot.Position).Magnitude
                    if distance > approachDistance then
                        -- Телепортация на 5 юнитов сзади, если далеко
                        rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5) * CFrame.Angles(0, math.pi, 0)
                        print("Teleported to " .. followTargetPlayer.Name .. " at distance 5 units")
                    else
                        -- Следование на 3 юнита сзади
                        rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, followDistance) * CFrame.Angles(0, math.pi, 0)
                    end
                else
                    followEnabled = false
                    if followConnection then followConnection:Disconnect() followConnection = nil end
                    humanoid.PlatformStand = false
                    print("Target lost, follow disabled!")
                end
            end)
            table.insert(connections, followConnection)
            print("Follow enabled for " .. targetName)
        else
            if followConnection then followConnection:Disconnect() followConnection = nil end
            humanoid.PlatformStand = false
            followTargetPlayer = nil
            print("Follow disabled!")
        end
    else
        print("Invalid target player: " .. targetName)
    end
end

-- Функция для удаления всего
local function deleteAll()
    stopFlying()
    deleteAllParts()
    if movingPartConnection then movingPartConnection:Disconnect() movingPartConnection = nil end
    if cframeConnection then cframeConnection:Disconnect() cframeConnection = nil end
    if touchConnection then touchConnection:Disconnect() touchConnection = nil end
    if flightConnection then flightConnection:Disconnect() flightConnection = nil end
    if followConnection then followConnection:Disconnect() followConnection = nil end
    followEnabled = false
    followTargetPlayer = nil
    humanoid.PlatformStand = false
    if screenGui then
        screenGui:Destroy()
        print("ScreenGui destroyed")
    end
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    connections = {}
    print("All parts, GUI, and connections deleted!")
end

-- Создание ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ToggleGui"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

-- Создание главного фрейма
local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 1200, 0, 600)
frame.Position = UDim2.new(0.5, -600, 0.5, -300)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BorderSizePixel = 2
frame.Visible = true
frame.Parent = screenGui

-- Колонка для биндов партов (Part Binds Column)
local partBindsColumn = Instance.new("Frame")
partBindsColumn.Name = "PartBindsColumn"
partBindsColumn.Size = UDim2.new(0.2, -10, 1, -10)
partBindsColumn.Position = UDim2.new(0, 5, 0, 5)
partBindsColumn.BackgroundTransparency = 1
partBindsColumn.Parent = frame

local partBindsLabel = Instance.new("TextLabel")
partBindsLabel.Name = "PartBindsLabel"
partBindsLabel.Size = UDim2.new(1, 0, 0, 30)
partBindsLabel.Position = UDim2.new(0, 0, 0, 0)
partBindsLabel.BackgroundTransparency = 1
partBindsLabel.Text = "Part Binds"
partBindsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
partBindsLabel.TextSize = 18
partBindsLabel.Parent = partBindsColumn

local keyInputPartSpawnLabel = Instance.new("TextLabel")
keyInputPartSpawnLabel.Name = "KeyInputPartSpawnLabel"
keyInputPartSpawnLabel.Size = UDim2.new(1, 0, 0, 20)
keyInputPartSpawnLabel.Position = UDim2.new(0, 0, 0.1, 0)
keyInputPartSpawnLabel.BackgroundTransparency = 1
keyInputPartSpawnLabel.Text = "Part Spawn"
keyInputPartSpawnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInputPartSpawnLabel.TextSize = 14
keyInputPartSpawnLabel.Parent = partBindsColumn

local keyInputPartSpawn = Instance.new("TextBox")
keyInputPartSpawn.Name = "KeyInputPartSpawn"
keyInputPartSpawn.Size = UDim2.new(1, 0, 0, 30)
keyInputPartSpawn.Position = UDim2.new(0, 0, 0.15, 0)
keyInputPartSpawn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputPartSpawn.Text = "P"
keyInputPartSpawn.TextSize = 18
keyInputPartSpawn.Parent = partBindsColumn

local keyInputFloatLabel = Instance.new("TextLabel")
keyInputFloatLabel.Name = "KeyInputFloatLabel"
keyInputFloatLabel.Size = UDim2.new(1, 0, 0, 20)
keyInputFloatLabel.Position = UDim2.new(0, 0, 0.25, 0)
keyInputFloatLabel.BackgroundTransparency = 1
keyInputFloatLabel.Text = "Float"
keyInputFloatLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInputFloatLabel.TextSize = 14
keyInputFloatLabel.Parent = partBindsColumn

local keyInputFloat = Instance.new("TextBox")
keyInputFloat.Name = "KeyInputFloat"
keyInputFloat.Size = UDim2.new(1, 0, 0, 30)
keyInputFloat.Position = UDim2.new(0, 0, 0.3, 0)
keyInputFloat.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputFloat.Text = "O"
keyInputFloat.TextSize = 18
keyInputFloat.Parent = partBindsColumn

local keyInputDirectionLabel = Instance.new("TextLabel")
keyInputDirectionLabel.Name = "KeyInputDirectionLabel"
keyInputDirectionLabel.Size = UDim2.new(1, 0, 0, 20)
keyInputDirectionLabel.Position = UDim2.new(0, 0, 0.4, 0)
keyInputDirectionLabel.BackgroundTransparency = 1
keyInputDirectionLabel.Text = "Direction Part"
keyInputDirectionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInputDirectionLabel.TextSize = 14
keyInputDirectionLabel.Parent = partBindsColumn

local keyInputDirection = Instance.new("TextBox")
keyInputDirection.Name = "KeyInputDirection"
keyInputDirection.Size = UDim2.new(1, 0, 0, 30)
keyInputDirection.Position = UDim2.new(0, 0, 0.45, 0)
keyInputDirection.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputDirection.Text = "U"
keyInputDirection.TextSize = 18
keyInputDirection.Parent = partBindsColumn

local directionButton = Instance.new("TextButton")
directionButton.Name = "DirectionButton"
directionButton.Size = UDim2.new(1, 0, 0, 30)
directionButton.Position = UDim2.new(0, 0, 0.55, 0)
directionButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
directionButton.Text = "Direction: " .. spawnDirection
directionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
directionButton.TextSize = 16
directionButton.Parent = partBindsColumn

local dropdownFrame = Instance.new("Frame")
dropdownFrame.Name = "DropdownFrame"
dropdownFrame.Size = UDim2.new(1, 0, 0, 120)
dropdownFrame.Position = UDim2.new(0, 0, 0.65, 0)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
dropdownFrame.BorderSizePixel = 1
dropdownFrame.Visible = false
dropdownFrame.Parent = partBindsColumn

local directions = {"Forward", "Left", "Right", "Back"}
for i, dir in ipairs(directions) do
    local dirButton = Instance.new("TextButton")
    dirButton.Name = dir .. "Option"
    dirButton.Size = UDim2.new(1, 0, 0, 30)
    dirButton.Position = UDim2.new(0, 0, (i-1) * 0.25, 0)
    dirButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    dirButton.Text = dir
    dirButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    dirButton.TextSize = 16
    dirButton.Parent = dropdownFrame
    
    dirButton.MouseButton1Click:Connect(function()
        spawnDirection = dir
        directionButton.Text = "Direction: " .. dir
        dropdownFrame.Visible = false
        print("Direction selected: " .. dir)
    end)
end

directionButton.MouseButton1Click:Connect(function()
    dropdownFrame.Visible = not dropdownFrame.Visible
end)

local partBindButton = Instance.new("TextButton")
partBindButton.Name = "PartBindButton"
partBindButton.Size = UDim2.new(1, 0, 0, 30)
partBindButton.Position = UDim2.new(0, 0, 0.85, 0)
partBindButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
partBindButton.Text = "Apply Part Binds"
partBindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
partBindButton.TextSize = 18
partBindButton.Parent = partBindsColumn

-- Колонка для биндов функций (Function Binds Column)
local functionBindsColumn = Instance.new("Frame")
functionBindsColumn.Name = "FunctionBindsColumn"
functionBindsColumn.Size = UDim2.new(0.2, -10, 1, -10)
functionBindsColumn.Position = UDim2.new(0.2, 5, 0, 5)
functionBindsColumn.BackgroundTransparency = 1
functionBindsColumn.Parent = frame

local functionBindsLabel = Instance.new("TextLabel")
functionBindsLabel.Name = "FunctionBindsLabel"
functionBindsLabel.Size = UDim2.new(1, 0, 0, 30)
functionBindsLabel.Position = UDim2.new(0, 0, 0, 0)
functionBindsLabel.BackgroundTransparency = 1
functionBindsLabel.Text = "Function Binds"
functionBindsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
functionBindsLabel.TextSize = 18
functionBindsLabel.Parent = functionBindsColumn

local keyInputTeleportLabel = Instance.new("TextLabel")
keyInputTeleportLabel.Name = "KeyInputTeleportLabel"
keyInputTeleportLabel.Size = UDim2.new(1, 0, 0, 20)
keyInputTeleportLabel.Position = UDim2.new(0, 0, 0.1, 0)
keyInputTeleportLabel.BackgroundTransparency = 1
keyInputTeleportLabel.Text = "Teleport on Death"
keyInputTeleportLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInputTeleportLabel.TextSize = 14
keyInputTeleportLabel.Parent = functionBindsColumn

local keyInputTeleport = Instance.new("TextBox")
keyInputTeleport.Name = "KeyInputTeleport"
keyInputTeleport.Size = UDim2.new(1, 0, 0, 30)
keyInputTeleport.Position = UDim2.new(0, 0, 0.15, 0)
keyInputTeleport.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputTeleport.Text = "T"
keyInputTeleport.TextSize = 18
keyInputTeleport.Parent = functionBindsColumn

local keyInputFlyLabel = Instance.new("TextLabel")
keyInputFlyLabel.Name = "KeyInputFlyLabel"
keyInputFlyLabel.Size = UDim2.new(1, 0, 0, 20)
keyInputFlyLabel.Position = UDim2.new(0, 0, 0.25, 0)
keyInputFlyLabel.BackgroundTransparency = 1
keyInputFlyLabel.Text = "Fly"
keyInputFlyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInputFlyLabel.TextSize = 14
keyInputFlyLabel.Parent = functionBindsColumn

local keyInputFly = Instance.new("TextBox")
keyInputFly.Name = "KeyInputFly"
keyInputFly.Size = UDim2.new(1, 0, 0, 30)
keyInputFly.Position = UDim2.new(0, 0, 0.3, 0)
keyInputFly.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputFly.Text = "F"
keyInputFly.TextSize = 18
keyInputFly.Parent = functionBindsColumn

local keyInputSpeedLabel = Instance.new("TextLabel")
keyInputSpeedLabel.Name = "KeyInputSpeedLabel"
keyInputSpeedLabel.Size = UDim2.new(1, 0, 0, 20)
keyInputSpeedLabel.Position = UDim2.new(0, 0, 0.4, 0)
keyInputSpeedLabel.BackgroundTransparency = 1
keyInputSpeedLabel.Text = "Speed Toggle"
keyInputSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInputSpeedLabel.TextSize = 14
keyInputSpeedLabel.Parent = functionBindsColumn

local keyInputSpeed = Instance.new("TextBox")
keyInputSpeed.Name = "KeyInputSpeed"
keyInputSpeed.Size = UDim2.new(1, 0, 0, 30)
keyInputSpeed.Position = UDim2.new(0, 0, 0.45, 0)
keyInputSpeed.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputSpeed.Text = "R"
keyInputSpeed.TextSize = 18
keyInputSpeed.Parent = functionBindsColumn

local keyInputCFrameSpeedLabel = Instance.new("TextLabel")
keyInputCFrameSpeedLabel.Name = "KeyInputCFrameSpeedLabel"
keyInputCFrameSpeedLabel.Size = UDim2.new(1, 0, 0, 20)
keyInputCFrameSpeedLabel.Position = UDim2.new(0, 0, 0.55, 0)
keyInputCFrameSpeedLabel.BackgroundTransparency = 1
keyInputCFrameSpeedLabel.Text = "CFrame Speed"
keyInputCFrameSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInputCFrameSpeedLabel.TextSize = 14
keyInputCFrameSpeedLabel.Parent = functionBindsColumn

local keyInputCFrameSpeed = Instance.new("TextBox")
keyInputCFrameSpeed.Name = "KeyInputCFrameSpeed"
keyInputCFrameSpeed.Size = UDim2.new(1, 0, 0, 30)
keyInputCFrameSpeed.Position = UDim2.new(0, 0, 0.6, 0)
keyInputCFrameSpeed.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputCFrameSpeed.Text = "E"
keyInputCFrameSpeed.TextSize = 18
keyInputCFrameSpeed.Parent = functionBindsColumn

local keyInputScreenVisibilityLabel = Instance.new("TextLabel")
keyInputScreenVisibilityLabel.Name = "KeyInputScreenVisibilityLabel"
keyInputScreenVisibilityLabel.Size = UDim2.new(1, 0, 0, 20)
keyInputScreenVisibilityLabel.Position = UDim2.new(0, 0, 0.7, 0)
keyInputScreenVisibilityLabel.BackgroundTransparency = 1
keyInputScreenVisibilityLabel.Text = "Screen Visibility"
keyInputScreenVisibilityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInputScreenVisibilityLabel.TextSize = 14
keyInputScreenVisibilityLabel.Parent = functionBindsColumn

local keyInputScreenVisibility = Instance.new("TextBox")
keyInputScreenVisibility.Name = "KeyInputScreenVisibility"
keyInputScreenVisibility.Size = UDim2.new(1, 0, 0, 30)
keyInputScreenVisibility.Position = UDim2.new(0, 0, 0.75, 0)
keyInputScreenVisibility.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputScreenVisibility.Text = "V"
keyInputScreenVisibility.TextSize = 18
keyInputScreenVisibility.Parent = functionBindsColumn

local functionBindButton = Instance.new("TextButton")
functionBindButton.Name = "FunctionBindButton"
functionBindButton.Size = UDim2.new(1, 0, 0, 30)
functionBindButton.Position = UDim2.new(0, 0, 0.85, 0)
functionBindButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
functionBindButton.Text = "Apply Function Binds"
functionBindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
functionBindButton.TextSize = 18
functionBindButton.Parent = functionBindsColumn

-- Колонка для партов (Parts Column)
local partsColumn = Instance.new("Frame")
partsColumn.Name = "PartsColumn"
partsColumn.Size = UDim2.new(0.2, -10, 1, -10)
partsColumn.Position = UDim2.new(0.4, 5, 0, 5)
partsColumn.BackgroundTransparency = 1
partsColumn.Parent = frame

local partsLabel = Instance.new("TextLabel")
partsLabel.Name = "PartsLabel"
partsLabel.Size = UDim2.new(1, 0, 0, 30)
partsLabel.Position = UDim2.new(0, 0, 0, 0)
partsLabel.BackgroundTransparency = 1
partsLabel.Text = "Parts"
partsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
partsLabel.TextSize = 18
partsLabel.Parent = partsColumn

local partSpawnButton = Instance.new("TextButton")
partSpawnButton.Name = "PartSpawnButton"
partSpawnButton.Size = UDim2.new(1, 0, 0, 30)
partSpawnButton.Position = UDim2.new(0, 0, 0.1, 0)
partSpawnButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
partSpawnButton.Text = "Spawn Part (P)"
partSpawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
partSpawnButton.TextSize = 16
partSpawnButton.Parent = partsColumn

partSpawnButton.MouseButton1Click:Connect(function()
    createPart()
end)

local floatButton = Instance.new("TextButton")
floatButton.Name = "FloatButton"
floatButton.Size = UDim2.new(1, 0, 0, 30)
floatButton.Position = UDim2.new(0, 0, 0.2, 0)
floatButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
floatButton.Text = "Float: Off (O)"
floatButton.TextColor3 = Color3.fromRGB(255, 255, 255)
floatButton.TextSize = 16
floatButton.Parent = partsColumn

floatButton.MouseButton1Click:Connect(function()
    toggleUnderFeetPart()
    floatButton.Text = underFeetPart and "Float: On (O)" or "Float: Off (O)"
end)

local directionPartButton = Instance.new("TextButton")
directionPartButton.Name = "DirectionPartButton"
directionPartButton.Size = UDim2.new(1, 0, 0, 30)
directionPartButton.Position = UDim2.new(0, 0, 0.3, 0)
directionPartButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
directionPartButton.Text = "Direction Part (U)"
directionPartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
directionPartButton.TextSize = 16
directionPartButton.Parent = partsColumn

directionPartButton.MouseButton1Click:Connect(function()
    createDirectionPart()
end)

local deletePartsButton = Instance.new("TextButton")
deletePartsButton.Name = "DeletePartsButton"
deletePartsButton.Size = UDim2.new(1, 0, 0, 30)
deletePartsButton.Position = UDim2.new(0, 0, 0.4, 0)
deletePartsButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
deletePartsButton.Text = "Delete All Parts"
deletePartsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deletePartsButton.TextSize = 16
deletePartsButton.Parent = partsColumn

deletePartsButton.MouseButton1Click:Connect(function()
    deleteAllParts()
    floatButton.Text = "Float: Off (O)"
end)

local propertiesToggle = Instance.new("TextButton")
propertiesToggle.Name = "PropertiesToggle"
propertiesToggle.Size = UDim2.new(0, 30, 0, 30)
propertiesToggle.Position = UDim2.new(1, -35, 0, 5)
propertiesToggle.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
propertiesToggle.Text = ">"
propertiesToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
propertiesToggle.TextSize = 16
propertiesToggle.Parent = partsColumn

-- Колонка для полёта (Flight Column)
local flightColumn = Instance.new("Frame")
flightColumn.Name = "FlightColumn"
flightColumn.Size = UDim2.new(0.2, -10, 1, -10)
flightColumn.Position = UDim2.new(0.6, 5, 0, 5)
flightColumn.BackgroundTransparency = 1
flightColumn.Parent = frame

local flightLabel = Instance.new("TextLabel")
flightLabel.Name = "FlightLabel"
flightLabel.Size = UDim2.new(1, 0, 0, 30)
flightLabel.Position = UDim2.new(0, 0, 0, 0)
flightLabel.BackgroundTransparency = 1
flightLabel.Text = "Flight"
flightLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
flightLabel.TextSize = 18
flightLabel.Parent = flightColumn

local flightToggle = Instance.new("TextButton")
flightToggle.Name = "FlightToggle"
flightToggle.Size = UDim2.new(1, 0, 0, 30)
flightToggle.Position = UDim2.new(0, 0, 0.1, 0)
flightToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
flightToggle.Text = "Flight: Off (F)"
flightToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
flightToggle.TextSize = 16
flightToggle.Parent = flightColumn

flightToggle.MouseButton1Click:Connect(function()
    if isFlying then
        stopFlying()
        flightToggle.Text = "Flight: Off (F)"
    else
        startFlying()
        flightToggle.Text = "Flight: On (F)"
    end
end)

local flightSpeedSliderFrame = Instance.new("Frame")
flightSpeedSliderFrame.Name = "FlightSpeedSliderFrame"
flightSpeedSliderFrame.Size = UDim2.new(1, 0, 0, 50)
flightSpeedSliderFrame.Position = UDim2.new(0, 0, 0.2, 0)
flightSpeedSliderFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
flightSpeedSliderFrame.Parent = flightColumn

local flightSpeedSlider = Instance.new("TextButton")
flightSpeedSlider.Name = "FlightSpeedSlider"
flightSpeedSlider.Size = UDim2.new(0, 20, 0, 20)
flightSpeedSlider.Position = UDim2.new(0, 0, 0, 15)
flightSpeedSlider.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
flightSpeedSlider.Text = ""
flightSpeedSlider.ZIndex = 2
flightSpeedSlider.Parent = flightSpeedSliderFrame

local flightSliderBar = Instance.new("Frame")
flightSliderBar.Name = "FlightSliderBar"
flightSliderBar.Size = UDim2.new(1, 0, 0, 5)
flightSliderBar.Position = UDim2.new(0, 0, 0, 25)
flightSliderBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
flightSliderBar.ZIndex = 1
flightSliderBar.Parent = flightSpeedSliderFrame

local flightSpeedLabel = Instance.new("TextLabel")
flightSpeedLabel.Name = "FlightSpeedLabel"
flightSpeedLabel.Size = UDim2.new(1, 0, 0, 20)
flightSpeedLabel.Position = UDim2.new(0, 0, 0, 0)
flightSpeedLabel.BackgroundTransparency = 1
flightSpeedLabel.Text = "Flight Speed: " .. flySpeed
flightSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
flightSpeedLabel.TextSize = 14
flightSpeedLabel.Parent = flightSpeedSliderFrame

flightSpeedSlider.MouseButton1Down:Connect(function()
    draggingFlight = true
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingFlight and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouseX = math.clamp(input.Position.X - flightSpeedSliderFrame.AbsolutePosition.X, 0, flightSpeedSliderFrame.AbsoluteSize.X - flightSpeedSlider.Size.X.Offset)
        flightSpeedSlider.Position = UDim2.new(0, mouseX, 0, 15)
        flySpeed = math.floor(20 + (mouseX / (flightSpeedSliderFrame.AbsoluteSize.X - flightSpeedSlider.Size.X.Offset)) * 280)
        flightSpeedLabel.Text = "Flight Speed: " .. flySpeed
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingFlight = false
    end
end)

-- Колонка для функций (Functions Column)
local functionsColumn = Instance.new("Frame")
functionsColumn.Name = "FunctionsColumn"
functionsColumn.Size = UDim2.new(0.2, -10, 1, -10)
functionsColumn.Position = UDim2.new(0.8, 5, 0, 5)
functionsColumn.BackgroundTransparency = 1
functionsColumn.Parent = frame

local functionsLabel = Instance.new("TextLabel")
functionsLabel.Name = "FunctionsLabel"
functionsLabel.Size = UDim2.new(1, 0, 0, 30)
functionsLabel.Position = UDim2.new(0, 0, 0, 0)
functionsLabel.BackgroundTransparency = 1
functionsLabel.Text = "Functions"
functionsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
functionsLabel.TextSize = 18
functionsLabel.Parent = functionsColumn

local teleportToggle = Instance.new("TextButton")
teleportToggle.Name = "TeleportToggle"
teleportToggle.Size = UDim2.new(1, 0, 0, 30)
teleportToggle.Position = UDim2.new(0, 0, 0.1, 0)
teleportToggle.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
teleportToggle.Text = "Teleport on Death: Off (T)"
teleportToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
teleportToggle.TextSize = 16
teleportToggle.Parent = functionsColumn

teleportToggle.MouseButton1Click:Connect(function()
    teleportOnDeathEnabled = not teleportOnDeathEnabled
    teleportToggle.Text = "Teleport on Death: " .. (teleportOnDeathEnabled and "On (T)" or "Off (T)")
    print("Teleport on Death: " .. (teleportOnDeathEnabled and "On" or "Off"))
end)

local flingButton = Instance.new("TextButton")
flingButton.Name = "FlingButton"
flingButton.Size = UDim2.new(1, 0, 0, 30)
flingButton.Position = UDim2.new(0, 0, 0.2, 0)
flingButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
flingButton.Text = "Fling: Off"
flingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
flingButton.TextSize = 16
flingButton.Parent = functionsColumn

flingButton.MouseButton1Click:Connect(function()
    flingEnabled = not flingEnabled
    flingButton.Text = "Fling: " .. (flingEnabled and "On" or "Off")
    if not flingEnabled then
        targetPlayer = nil
    end
    print("Fling toggled: " .. (flingEnabled and "On" or "Off"))
end)

local speedToggle = Instance.new("TextButton")
speedToggle.Name = "SpeedToggle"
speedToggle.Size = UDim2.new(1, 0, 0, 30)
speedToggle.Position = UDim2.new(0, 0, 0.3, 0)
speedToggle.BackgroundColor3 = Color3.fromRGB(0, 0, 255)
speedToggle.Text = "Speed Toggle: Off (R)"
speedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
speedToggle.TextSize = 16
speedToggle.Parent = functionsColumn

speedToggle.MouseButton1Click:Connect(function()
    speedEnabled = not speedEnabled
    speedToggle.Text = "Speed Toggle: " .. (speedEnabled and "On (R)" or "Off (R)")
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        if not speedEnabled then
            player.Character.Humanoid.WalkSpeed = 16
        else
            player.Character.Humanoid.WalkSpeed = walkSpeed
        end
    end
    print("Speed toggle: " .. (speedEnabled and "On" or "Off"))
end)

local speedSliderFrame = Instance.new("Frame")
speedSliderFrame.Name = "SpeedSliderFrame"
speedSliderFrame.Size = UDim2.new(1, 0, 0, 50)
speedSliderFrame.Position = UDim2.new(0, 0, 0.4, 0)
speedSliderFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
speedSliderFrame.Parent = functionsColumn

local speedSlider = Instance.new("TextButton")
speedSlider.Name = "SpeedSlider"
speedSlider.Size = UDim2.new(0, 20, 0, 20)
speedSlider.Position = UDim2.new(0, 0, 0, 15)
speedSlider.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
speedSlider.Text = ""
speedSlider.ZIndex = 2
speedSlider.Parent = speedSliderFrame

local sliderBar = Instance.new("Frame")
sliderBar.Name = "SliderBar"
sliderBar.Size = UDim2.new(1, 0, 0, 5)
sliderBar.Position = UDim2.new(0, 0, 0, 25)
sliderBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
sliderBar.ZIndex = 1
sliderBar.Parent = speedSliderFrame

local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "SpeedLabel"
speedLabel.Size = UDim2.new(1, 0, 0, 20)
speedLabel.Position = UDim2.new(0, 0, 0, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Walk Speed: " .. walkSpeed
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.TextSize = 14
speedLabel.Parent = speedSliderFrame

local dragging = false
speedSlider.MouseButton1Down:Connect(function()
    dragging = true
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouseX = math.clamp(input.Position.X - speedSliderFrame.AbsolutePosition.X, 0, speedSliderFrame.AbsoluteSize.X - speedSlider.Size.X.Offset)
        speedSlider.Position = UDim2.new(0, mouseX, 0, 15)
        walkSpeed = math.floor(16 + (mouseX / (speedSliderFrame.AbsoluteSize.X - speedSlider.Size.X.Offset)) * 284)
        speedLabel.Text = "Walk Speed: " .. walkSpeed
        if player.Character and player.Character:FindFirstChild("Humanoid") and speedEnabled then
            player.Character.Humanoid.WalkSpeed = walkSpeed
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local cframeSpeedToggle = Instance.new("TextButton")
cframeSpeedToggle.Name = "CFrameSpeedToggle"
cframeSpeedToggle.Size = UDim2.new(1, 0, 0, 30)
cframeSpeedToggle.Position = UDim2.new(0, 0, 0.5, 0)
cframeSpeedToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
cframeSpeedToggle.Text = "CFrame Speed: Off (E)"
cframeSpeedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
cframeSpeedToggle.TextSize = 16
cframeSpeedToggle.Parent = functionsColumn

cframeSpeedToggle.MouseButton1Click:Connect(function()
    cframeSpeedEnabled = not cframeSpeedEnabled
    cframeSpeedToggle.Text = "CFrame Speed: " .. (cframeSpeedEnabled and "On (E)" or "Off (E)")
    if cframeSpeedEnabled then
        if cframeConnection then cframeConnection:Disconnect() end
        cframeConnection = RunService.Heartbeat:Connect(function(step)
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.Humanoid.MoveDirection.Magnitude > 0 then
                player.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame + player.Character.Humanoid.MoveDirection * cframeSpeed * step
            end
        end)
        table.insert(connections, cframeConnection)
    else
        if cframeConnection then
            cframeConnection:Disconnect()
            cframeConnection = nil
        end
    end
    print("CFrame Speed: " .. (cframeSpeedEnabled and "On" or "Off"))
end)

local cframeSpeedSliderFrame = Instance.new("Frame")
cframeSpeedSliderFrame.Name = "CFrameSpeedSliderFrame"
cframeSpeedSliderFrame.Size = UDim2.new(1, 0, 0, 50)
cframeSpeedSliderFrame.Position = UDim2.new(0, 0, 0.6, 0)
cframeSpeedSliderFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
cframeSpeedSliderFrame.Parent = functionsColumn

local cframeSpeedSlider = Instance.new("TextButton")
cframeSpeedSlider.Name = "CFrameSpeedSlider"
cframeSpeedSlider.Size = UDim2.new(0, 20, 0, 20)
cframeSpeedSlider.Position = UDim2.new(0, 0, 0, 15)
cframeSpeedSlider.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
cframeSpeedSlider.Text = ""
cframeSpeedSlider.ZIndex = 2
cframeSpeedSlider.Parent = cframeSpeedSliderFrame

local cframeSliderBar = Instance.new("Frame")
cframeSliderBar.Name = "CFrameSliderBar"
cframeSliderBar.Size = UDim2.new(1, 0, 0, 5)
cframeSliderBar.Position = UDim2.new(0, 0, 0, 25)
cframeSliderBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
cframeSliderBar.ZIndex = 1
cframeSliderBar.Parent = cframeSpeedSliderFrame

local cframeSpeedLabel = Instance.new("TextLabel")
cframeSpeedLabel.Name = "CFrameSpeedLabel"
cframeSpeedLabel.Size = UDim2.new(1, 0, 0, 20)
cframeSpeedLabel.Position = UDim2.new(0, 0, 0, 0)
cframeSpeedLabel.BackgroundTransparency = 1
cframeSpeedLabel.Text = "CFrame Speed: " .. cframeSpeed
cframeSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
cframeSpeedLabel.TextSize = 14
cframeSpeedLabel.Parent = cframeSpeedSliderFrame

local draggingCframe = false
cframeSpeedSlider.MouseButton1Down:Connect(function()
    draggingCframe = true
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingCframe and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouseX = math.clamp(input.Position.X - cframeSpeedSliderFrame.AbsolutePosition.X, 0, cframeSpeedSliderFrame.AbsoluteSize.X - cframeSpeedSlider.Size.X.Offset)
        cframeSpeedSlider.Position = UDim2.new(0, mouseX, 0, 15)
        cframeSpeed = math.floor(1 + (mouseX / (cframeSpeedSliderFrame.AbsoluteSize.X - cframeSpeedSlider.Size.X.Offset)) * 39)
        cframeSpeedLabel.Text = "CFrame Speed: " .. cframeSpeed
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingCframe = false
    end
end)

local screenVisibilityToggle = Instance.new("TextButton")
screenVisibilityToggle.Name = "ScreenVisibilityToggle"
screenVisibilityToggle.Size = UDim2.new(1, 0, 0, 30)
screenVisibilityToggle.Position = UDim2.new(0, 0, 0.7, 0)
screenVisibilityToggle.BackgroundColor3 = Color3.fromRGB(150, 0, 200)
screenVisibilityToggle.Text = "Screen Visibility: On (V)"
screenVisibilityToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
screenVisibilityToggle.TextSize = 16
screenVisibilityToggle.Parent = functionsColumn

screenVisibilityToggle.MouseButton1Click:Connect(function()
    toggleScreenVisibility()
    screenVisibilityToggle.Text = "Screen Visibility: " .. (screenVisible and "On (V)" or "Off (V)")
end)

-- Колонка для свойств Direction Part
local propertiesColumn = Instance.new("Frame")
propertiesColumn.Name = "PropertiesColumn"
propertiesColumn.Size = UDim2.new(0.2, -10, 1, -10)
propertiesColumn.Position = UDim2.new(1.0, 5, 0, 5)
propertiesColumn.BackgroundTransparency = 1
propertiesColumn.Visible = false
propertiesColumn.Parent = frame

local propertiesLabel = Instance.new("TextLabel")
propertiesLabel.Name = "PropertiesLabel"
propertiesLabel.Size = UDim2.new(1, 0, 0, 30)
propertiesLabel.Position = UDim2.new(0, 0, 0, 0)
propertiesLabel.BackgroundTransparency = 1
propertiesLabel.Text = "Direction Part Properties"
propertiesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
propertiesLabel.TextSize = 18
propertiesLabel.Parent = propertiesColumn

local sizeXLabel = Instance.new("TextLabel")
sizeXLabel.Name = "SizeXLabel"
sizeXLabel.Size = UDim2.new(1, 0, 0, 20)
sizeXLabel.Position = UDim2.new(0, 0, 0.1, 0)
sizeXLabel.BackgroundTransparency = 1
sizeXLabel.Text = "Size X: 5"
sizeXLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeXLabel.TextSize = 14
sizeXLabel.Parent = propertiesColumn

local sizeXInput = Instance.new("TextBox")
sizeXInput.Name = "SizeXInput"
sizeXInput.Size = UDim2.new(1, 0, 0, 30)
sizeXInput.Position = UDim2.new(0, 0, 0.15, 0)
sizeXInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
sizeXInput.Text = "5"
sizeXInput.TextSize = 16
sizeXInput.Parent = propertiesColumn

local sizeYLabel = Instance.new("TextLabel")
sizeYLabel.Name = "SizeYLabel"
sizeYLabel.Size = UDim2.new(1, 0, 0, 20)
sizeYLabel.Position = UDim2.new(0, 0, 0.25, 0)
sizeYLabel.BackgroundTransparency = 1
sizeYLabel.Text = "Size Y: 1"
sizeYLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeYLabel.TextSize = 14
sizeYLabel.Parent = propertiesColumn

local sizeYInput = Instance.new("TextBox")
sizeYInput.Name = "SizeYInput"
sizeYInput.Size = UDim2.new(1, 0, 0, 30)
sizeYInput.Position = UDim2.new(0, 0, 0.3, 0)
sizeYInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
sizeYInput.Text = "1"
sizeYInput.TextSize = 16
sizeYInput.Parent = propertiesColumn

local sizeZLabel = Instance.new("TextLabel")
sizeZLabel.Name = "SizeZLabel"
sizeZLabel.Size = UDim2.new(1, 0, 0, 20)
sizeZLabel.Position = UDim2.new(0, 0, 0.4, 0)
sizeZLabel.BackgroundTransparency = 1
sizeZLabel.Text = "Size Z: 5"
sizeZLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeZLabel.TextSize = 14
sizeZLabel.Parent = propertiesColumn

local sizeZInput = Instance.new("TextBox")
sizeZInput.Name = "SizeZInput"
sizeZInput.Size = UDim2.new(1, 0, 0, 30)
sizeZInput.Position = UDim2.new(0, 0, 0.45, 0)
sizeZInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
sizeZInput.Text = "5"
sizeZInput.TextSize = 16
sizeZInput.Parent = propertiesColumn

local colorLabel = Instance.new("TextLabel")
colorLabel.Name = "ColorLabel"
colorLabel.Size = UDim2.new(1, 0, 0, 20)
colorLabel.Position = UDim2.new(0, 0, 0.55, 0)
colorLabel.BackgroundTransparency = 1
colorLabel.Text = "Color: Bright red"
colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
colorLabel.TextSize = 14
colorLabel.Parent = propertiesColumn

local colorInput = Instance.new("TextBox")
colorInput.Name = "ColorInput"
colorInput.Size = UDim2.new(1, 0, 0, 30)
colorInput.Position = UDim2.new(0, 0, 0.6, 0)
colorInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
colorInput.Text = "Bright red"
colorInput.TextSize = 16
colorInput.Parent = propertiesColumn

local transparencyLabel = Instance.new("TextLabel")
transparencyLabel.Name = "TransparencyLabel"
transparencyLabel.Size = UDim2.new(1, 0, 0, 20)
transparencyLabel.Position = UDim2.new(0, 0, 0.7, 0)
transparencyLabel.BackgroundTransparency = 1
transparencyLabel.Text = "Transparency: 0"
transparencyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
transparencyLabel.TextSize = 14
transparencyLabel.Parent = propertiesColumn

local transparencyInput = Instance.new("TextBox")
transparencyInput.Name = "TransparencyInput"
transparencyInput.Size = UDim2.new(1, 0, 0, 30)
transparencyInput.Position = UDim2.new(0, 0, 0.75, 0)
transparencyInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
transparencyInput.Text = "0"
transparencyInput.TextSize = 16
transparencyInput.Parent = propertiesColumn

local canCollideToggle = Instance.new("TextButton")
canCollideToggle.Name = "CanCollideToggle"
canCollideToggle.Size = UDim2.new(1, 0, 0, 30)
canCollideToggle.Position = UDim2.new(0, 0, 0.85, 0)
canCollideToggle.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
canCollideToggle.Text = "CanCollide: On"
canCollideToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
canCollideToggle.TextSize = 16
canCollideToggle.Parent = propertiesColumn

local anchoredToggle = Instance.new("TextButton")
anchoredToggle.Name = "AnchoredToggle"
anchoredToggle.Size = UDim2.new(1, 0, 0, 30)
anchoredToggle.Position = UDim2.new(0, 0, 0.95, 0)
anchoredToggle.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
anchoredToggle.Text = "Anchored: On"
anchoredToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
anchoredToggle.TextSize = 16
anchoredToggle.Parent = propertiesColumn

-- Функция для обновления свойств Direction Part
local function updateDirectionPartProperties()
    if directionPart then
        local newSizeX = tonumber(sizeXInput.Text) or directionPartSize.X
        local newSizeY = tonumber(sizeYInput.Text) or directionPartSize.Y
        local newSizeZ = tonumber(sizeZInput.Text) or directionPartSize.Z
        directionPartSize = Vector3.new(newSizeX, newSizeY, newSizeZ)
        directionPart.Size = directionPartSize
        sizeXLabel.Text = "Size X: " .. newSizeX
        sizeYLabel.Text = "Size Y: " .. newSizeY
        sizeZLabel.Text = "Size Z: " .. newSizeZ

        local newColor = BrickColor.new(colorInput.Text)
        if newColor then
            directionPartColor = newColor
            directionPart.BrickColor = directionPartColor
            colorLabel.Text = "Color: " .. colorInput.Text
        end

        local newTransparency = tonumber(transparencyInput.Text) or directionPartTransparency
        if newTransparency >= 0 and newTransparency <= 1 then
            directionPartTransparency = newTransparency
            directionPart.Transparency = directionPartTransparency
            transparencyLabel.Text = "Transparency: " .. newTransparency
        end

        directionPart.CanCollide = directionPartCanCollide
        directionPart.Anchored = directionPartAnchored
        print("Direction Part properties updated!")
    end
end

sizeXInput.FocusLost:Connect(updateDirectionPartProperties)
sizeYInput.FocusLost:Connect(updateDirectionPartProperties)
sizeZInput.FocusLost:Connect(updateDirectionPartProperties)
colorInput.FocusLost:Connect(updateDirectionPartProperties)
transparencyInput.FocusLost:Connect(updateDirectionPartProperties)

canCollideToggle.MouseButton1Click:Connect(function()
    directionPartCanCollide = not directionPartCanCollide
    canCollideToggle.Text = "CanCollide: " .. (directionPartCanCollide and "On" or "Off")
    if directionPart then
        directionPart.CanCollide = directionPartCanCollide
    end
    print("Direction Part CanCollide: " .. (directionPartCanCollide and "On" or "Off"))
end)

anchoredToggle.MouseButton1Click:Connect(function()
    directionPartAnchored = not directionPartAnchored
    anchoredToggle.Text = "Anchored: " .. (directionPartAnchored and "On" or "Off")
    if directionPart then
        directionPart.Anchored = directionPartAnchored
    end
    print("Direction Part Anchored: " .. (directionPartAnchored and "On" or "Off"))
end)

propertiesToggle.MouseButton1Click:Connect(function()
    propertiesColumn.Visible = not propertiesColumn.Visible
    propertiesToggle.Text = propertiesColumn.Visible and "<" or ">"
end)

-- Колонка для настроек (Settings Column)
local settingsColumn = Instance.new("Frame")
settingsColumn.Name = "SettingsColumn"
settingsColumn.Size = UDim2.new(0.2, -10, 1, -10)
settingsColumn.Position = UDim2.new(1.2, 5, 0, 5)
settingsColumn.BackgroundTransparency = 1
settingsColumn.Visible = true
settingsColumn.Parent = frame

local settingsLabel = Instance.new("TextLabel")
settingsLabel.Name = "SettingsLabel"
settingsLabel.Size = UDim2.new(1, 0, 0, 30)
settingsLabel.Position = UDim2.new(0, 0, 0, 0)
settingsLabel.BackgroundTransparency = 1
settingsLabel.Text = "Settings"
settingsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
settingsLabel.TextSize = 18
settingsLabel.Parent = settingsColumn

local unloadButton = Instance.new("TextButton")
unloadButton.Name = "UnloadButton"
unloadButton.Size = UDim2.new(1, 0, 0, 30)
unloadButton.Position = UDim2.new(0, 0, 0.1, 0)
unloadButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
unloadButton.Text = "Unload Script"
unloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadButton.TextSize = 16
unloadButton.Visible = true
unloadButton.ZIndex = 2
unloadButton.Parent = settingsColumn

unloadButton.MouseButton1Click:Connect(function()
    deleteAll()
end)

local toggleGuiButton = Instance.new("TextButton")
toggleGuiButton.Name = "ToggleGuiButton"
toggleGuiButton.Size = UDim2.new(1, 0, 0, 30)
toggleGuiButton.Position = UDim2.new(0, 0, 0.2, 0)
toggleGuiButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
toggleGuiButton.Text = "Hide GUI"
toggleGuiButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleGuiButton.TextSize = 16
toggleGuiButton.ZIndex = 2
toggleGuiButton.Parent = settingsColumn

local redButton = Instance.new("TextButton")
redButton.Name = "RedButton"
redButton.Size = UDim2.new(1, 0, 0, 30)
redButton.Position = UDim2.new(0, 0, 0.3, 0)
redButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
redButton.Text = "Very Red Button"
redButton.TextColor3 = Color3.fromRGB(255, 255, 255)
redButton.TextSize = 16
redButton.Visible = true
redButton.ZIndex = 2
redButton.Parent = settingsColumn

redButton.MouseButton1Click:Connect(function()
    print("Very Red Button clicked!")
end)

local followTargetInput = Instance.new("TextBox")
followTargetInput.Name = "FollowTargetInput"
followTargetInput.Size = UDim2.new(1, 0, 0, 30)
followTargetInput.Position = UDim2.new(0, 0, 0.4, 0)
followTargetInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
followTargetInput.Text = "Enter player name"
followTargetInput.TextSize = 16
followTargetInput.ZIndex = 2
followTargetInput.Parent = settingsColumn

local followToggle = Instance.new("TextButton")
followToggle.Name = "FollowToggle"
followToggle.Size = UDim2.new(1, 0, 0, 30)
followToggle.Position = UDim2.new(0, 0, 0.5, 0)
followToggle.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
followToggle.Text = "Follow: Off"
followToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
followToggle.TextSize = 16
followToggle.ZIndex = 2
followToggle.Parent = settingsColumn

followToggle.MouseButton1Click:Connect(function()
    toggleFollow(followTargetInput.Text)
    followToggle.Text = "Follow: " .. (followEnabled and "On" or "Off")
end)

toggleGuiButton.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
    toggleGuiButton.Text = frame.Visible and "Hide GUI" or "Show GUI"
end)

-- Обработка нажатий клавиш
local function onKeyPressPartSpawn(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeyPartSpawn then
        createPart()
    end
end
local keyPressPartSpawnConnection = UserInputService.InputBegan:Connect(onKeyPressPartSpawn)
table.insert(connections, keyPressPartSpawnConnection)

local function onKeyPressFloat(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeyFloat then
        toggleUnderFeetPart()
        floatButton.Text = underFeetPart and "Float: On (O)" or "Float: Off (O)"
    end
end
local keyPressFloatConnection = UserInputService.InputBegan:Connect(onKeyPressFloat)
table.insert(connections, keyPressFloatConnection)

local function onKeyPressDirection(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeyDirection then
        createDirectionPart()
    end
end
local keyPressDirectionConnection = UserInputService.InputBegan:Connect(onKeyPressDirection)
table.insert(connections, keyPressDirectionConnection)

local function onKeyPressTeleport(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeyTeleport then
        teleportOnDeathEnabled = not teleportOnDeathEnabled
        teleportToggle.Text = "Teleport on Death: " .. (teleportOnDeathEnabled and "On (T)" or "Off (T)")
        print("Teleport on Death: " .. (teleportOnDeathEnabled and "On" or "Off"))
    end
end
local keyPressTeleportConnection = UserInputService.InputBegan:Connect(onKeyPressTeleport)
table.insert(connections, keyPressTeleportConnection)

local function onKeyPressFly(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeyFly then
        if isFlying then
            stopFlying()
            flightToggle.Text = "Flight: Off (F)"
        else
            startFlying()
            flightToggle.Text = "Flight: On (F)"
        end
    end
end
local keyPressFlyConnection = UserInputService.InputBegan:Connect(onKeyPressFly)
table.insert(connections, keyPressFlyConnection)

local function onKeyPressSpeed(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeySpeed then
        speedEnabled = not speedEnabled
        speedToggle.Text = "Speed Toggle: " .. (speedEnabled and "On (R)" or "Off (R)")
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            if not speedEnabled then
                player.Character.Humanoid.WalkSpeed = 16
            else
                player.Character.Humanoid.WalkSpeed = walkSpeed
            end
        end
        print("Speed toggle: " .. (speedEnabled and "On" or "Off"))
    end
end
local keyPressSpeedConnection = UserInputService.InputBegan:Connect(onKeyPressSpeed)
table.insert(connections, keyPressSpeedConnection)

local function onKeyPressCFrameSpeed(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeyCFrameSpeed then
        cframeSpeedEnabled = not cframeSpeedEnabled
        cframeSpeedToggle.Text = "CFrame Speed: " .. (cframeSpeedEnabled and "On (E)" or "Off (E)")
        if cframeSpeedEnabled then
            if cframeConnection then cframeConnection:Disconnect() end
            cframeConnection = RunService.Heartbeat:Connect(function(step)
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.Humanoid.MoveDirection.Magnitude > 0 then
                    player.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame + player.Character.Humanoid.MoveDirection * cframeSpeed * step
                end
            end)
            table.insert(connections, cframeConnection)
        else
            if cframeConnection then
                cframeConnection:Disconnect()
                cframeConnection = nil
            end
        end
        print("CFrame Speed: " .. (cframeSpeedEnabled and "On" or "Off"))
    end
end
local keyPressCFrameSpeedConnection = UserInputService.InputBegan:Connect(onKeyPressCFrameSpeed)
table.insert(connections, keyPressCFrameSpeedConnection)


local function onKeyPressScreenVisibility(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeyScreenVisibility then
        toggleScreenVisibility()
        screenVisibilityToggle.Text = "Screen Visibility: " .. (screenVisible and "On (V)" or "Off (V)")
    end
end
local keyPressScreenVisibilityConnection = UserInputService.InputBegan:Connect(onKeyPressScreenVisibility)
table.insert(connections, keyPressScreenVisibilityConnection)

-- Обработка биндов для Part Binds
partBindButton.MouseButton1Click:Connect(function()
    local newKeyPartSpawn = Enum.KeyCode[keyInputPartSpawn.Text]
    local newKeyFloat = Enum.KeyCode[keyInputFloat.Text]
    local newKeyDirection = Enum.KeyCode[keyInputDirection.Text]
    
    if newKeyPartSpawn then
        boundKeyPartSpawn = newKeyPartSpawn
        partSpawnButton.Text = "Spawn Part (" .. keyInputPartSpawn.Text .. ")"
        print("Part Spawn key bound to: " .. keyInputPartSpawn.Text)
    else
        print("Invalid key for Part Spawn: " .. keyInputPartSpawn.Text)
    end
    
    if newKeyFloat then
        boundKeyFloat = newKeyFloat
        floatButton.Text = underFeetPart and "Float: On (" .. keyInputFloat.Text .. ")" or "Float: Off (" .. keyInputFloat.Text .. ")"
        print("Float key bound to: " .. keyInputFloat.Text)
    else
        print("Invalid key for Float: " .. keyInputFloat.Text)
    end
    
    if newKeyDirection then
        boundKeyDirection = newKeyDirection
        directionPartButton.Text = "Direction Part (" .. keyInputDirection.Text .. ")"
        print("Direction Part key bound to: " .. keyInputDirection.Text)
    else
        print("Invalid key for Direction Part: " .. keyInputDirection.Text)
    end
end)

-- Обработка биндов для Function Binds
functionBindButton.MouseButton1Click:Connect(function()
    local newKeyTeleport = Enum.KeyCode[keyInputTeleport.Text]
    local newKeyFly = Enum.KeyCode[keyInputFly.Text]
    local newKeySpeed = Enum.KeyCode[keyInputSpeed.Text]
    local newKeyCFrameSpeed = Enum.KeyCode[keyInputCFrameSpeed.Text]
    local newKeyScreenVisibility = Enum.KeyCode[keyInputScreenVisibility.Text]
    
    if newKeyTeleport then
        boundKeyTeleport = newKeyTeleport
        teleportToggle.Text = "Teleport on Death: " .. (teleportOnDeathEnabled and "On (" .. keyInputTeleport.Text .. ")" or "Off (" .. keyInputTeleport.Text .. ")")
        print("Teleport key bound to: " .. keyInputTeleport.Text)
    else
        print("Invalid key for Teleport: " .. keyInputTeleport.Text)
    end
    
    if newKeyFly then
        boundKeyFly = newKeyFly
        flightToggle.Text = isFlying and "Flight: On (" .. keyInputFly.Text .. ")" or "Flight: Off (" .. keyInputFly.Text .. ")"
        print("Fly key bound to: " .. keyInputFly.Text)
    else
        print("Invalid key for Fly: " .. keyInputFly.Text)
    end
    
    if newKeySpeed then
        boundKeySpeed = newKeySpeed
        speedToggle.Text = "Speed Toggle: " .. (speedEnabled and "On (" .. keyInputSpeed.Text .. ")" or "Off (" .. keyInputSpeed.Text .. ")")
        print("Speed key bound to: " .. keyInputSpeed.Text)
    else
        print("Invalid key for Speed: " .. keyInputSpeed.Text)
    end
    
    if newKeyCFrameSpeed then
        boundKeyCFrameSpeed = newKeyCFrameSpeed
        cframeSpeedToggle.Text = "CFrame Speed: " .. (cframeSpeedEnabled and "On (" .. keyInputCFrameSpeed.Text .. ")" or "Off (" .. keyInputCFrameSpeed.Text .. ")")
        print("CFrame Speed key bound to: " .. keyInputCFrameSpeed.Text)
    else
        print("Invalid key for CFrame Speed: " .. keyInputCFrameSpeed.Text)
    end
    
    if newKeyScreenVisibility then
        boundKeyScreenVisibility = newKeyScreenVisibility
        screenVisibilityToggle.Text = "Screen Visibility: " .. (screenVisible and "On (" .. keyInputScreenVisibility.Text .. ")" or "Off (" .. keyInputScreenVisibility.Text .. ")")
        print("Screen Visibility key bound to: " .. keyInputScreenVisibility.Text)
    else
        print("Invalid key for Screen Visibility: " .. keyInputScreenVisibility.Text)
    end
end)

-- Обработка смерти персонажа для телепортации
local function onCharacterDeath()
    if teleportOnDeathEnabled and deathPosition and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = CFrame.new(deathPosition)
        print("Teleported to death position: " .. tostring(deathPosition))
    end
end

-- Обработка добавления персонажа
local function onCharacterAdded(newCharacter)
    char = newCharacter
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    
    humanoid.Died:Connect(function()
        deathPosition = rootPart.Position
        onCharacterDeath()
    end)
    
    if flingEnabled then
        if touchConnection then
            touchConnection:Disconnect()
        end
        touchConnection = rootPart.Touched:Connect(activateFlingOnTouch)
        table.insert(connections, touchConnection)
    end
    
    if speedEnabled and humanoid then
        humanoid.WalkSpeed = walkSpeed
    end
    
    if followEnabled and followTargetPlayer then
        toggleFollow(followTargetPlayer.Name) -- Восстановить следование после респавна
    end
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Инициализация флинга при старте, если включено
if flingEnabled and char and char:FindFirstChild("HumanoidRootPart") then
    touchConnection = char.HumanoidRootPart.Touched:Connect(activateFlingOnTouch)
    table.insert(connections, touchConnection)
end

-- Обработка движущихся партов
local function toggleMovingPart()
    if movingPartEnabled then
        if movingPart then
            movingPart:Destroy()
            movingPart = nil
        end
        if movingPartConnection then
            movingPartConnection:Disconnect()
            movingPartConnection = nil
        end
        movingPartEnabled = false
        print("Moving Part disabled")
    else
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            movingPart = Instance.new("Part")
            movingPart.Name = "MovingPart"
            movingPart.Size = Vector3.new(5, 1, 5)
            movingPart.Position = player.Character.HumanoidRootPart.Position + player.Character.HumanoidRootPart.CFrame.LookVector * movingPartDistance
            movingPart.Anchored = true
            movingPart.BrickColor = BrickColor.new("Bright blue")
            movingPart.Parent = Workspace
            
            movingPartConnection = RunService.Heartbeat:Connect(function()
                if movingPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    movingPart.Position = player.Character.HumanoidRootPart.Position + player.Character.HumanoidRootPart.CFrame.LookVector * movingPartDistance
                end
            end)
            table.insert(connections, movingPartConnection)
            movingPartEnabled = true
            print("Moving Part enabled")
        else
            print("Character or HumanoidRootPart not found for Moving Part")
        end
    end
end

-- Обработчик для клавиши L для переключения GUI
local function onKeyPressToggleGui(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.L then
        frame.Visible = not frame.Visible
        toggleGuiButton.Text = frame.Visible and "Hide GUI" or "Show GUI"
        print("GUI Visibility: " .. (frame.Visible and "Shown" or "Hidden"))
    end
end
local keyPressToggleGuiConnection = UserInputService.InputBegan:Connect(onKeyPressToggleGui)
table.insert(connections, keyPressToggleGuiConnection)

-- Инициализация GUI
frame.Visible = true
settingsColumn.Visible = true
unloadButton.Visible = true
followToggle.Text = "Follow: Off"
print("GUI initialized and visible. Press L to toggle GUI.")

-- Конец скрипта
print("Script loaded successfully!")
