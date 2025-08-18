local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Camera = Workspace.CurrentCamera

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

-- Переменные для состояния
local state = {
    isFlying = false,
    flySpeed = 50,
    bodyVelocity = nil,
    bodyGyro = nil,
    flightConnection = nil,
    boundKeyFly = Enum.KeyCode.F,
    boundKeyPartSpawn = Enum.KeyCode.P,
    boundKeyFloat = Enum.KeyCode.O,
    boundKeyDirection = Enum.KeyCode.U,
    boundKeyTeleport = Enum.KeyCode.T,
    boundKeySpeed = Enum.KeyCode.R,
    boundKeyCFrameSpeed = Enum.KeyCode.E,
    boundKeyScreenVisibility = Enum.KeyCode.V,
    spawnDirection = "Forward",
    spawnDistance = 5,
    underFeetPart = nil,
    directionPart = nil,
    renderConnection = nil,
    deathPosition = nil,
    teleportOnDeathEnabled = false,
    flingEnabled = false,
    targetPlayer = nil,
    walkSpeed = 16,
    speedEnabled = false,
    cframeSpeed = 2,
    cframeSpeedEnabled = false,
    cframeConnection = nil,
    touchConnection = nil,
    followEnabled = false,
    followConnection = nil,
    followTargetPlayer = nil,
    followDistance = 3,
    approachDistance = 10,
    screenVisible = true,
    directionPartSize = Vector3.new(5, 1, 5),
    directionPartColor = BrickColor.new("Bright red"),
    directionPartTransparency = 0,
    directionPartCanCollide = true,
    directionPartAnchored = true
}

local connections = {}

-- Объект Screen
local screen = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Screens") and Workspace.Map.Screens:FindFirstChild("Leaderboards") and Workspace.Map.Screens.Leaderboards:FindFirstChild("Total") and Workspace.Map.Screens.Leaderboards.Total:FindFirstChild("Screen")
local beam = screen and screen:FindFirstChild("Beam")
if beam then beam:Destroy() end
local surfacegui = screen and screen:FindFirstChild("SurfaceGui")
if surfacegui then surfacegui.Enabled = false end

if screen then
    if screen:IsA("BasePart") then
        screen.Size = Vector3.new(3, 3, 3)
        screen.CanCollide = true
        screen.Transparency = 0
        table.insert(connections, RunService.Heartbeat:Connect(function()
            if char and char:FindFirstChild("HumanoidRootPart") then
                screen.Position = char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 7
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
                screen:SetPrimaryPartCFrame(CFrame.new(char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 7))
            end
        end))
    end
    print("Screen initialized: follows player at 5 units")
else
    print("Screen object not found!")
end

-- Обновление персонажа при респавне
local function onCharacterAdded(newCharacter)
    char = newCharacter
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    
    if state.speedEnabled then
        humanoid.WalkSpeed = state.walkSpeed
    end
    if state.flingEnabled then
        if state.touchConnection then state.touchConnection:Disconnect() end
        state.touchConnection = rootPart.Touched:Connect(activateFlingOnTouch)
        table.insert(connections, state.touchConnection)
    end
    if state.isFlying then
        startFlying()
    end
    if state.cframeSpeedEnabled then
        toggleCFrameSpeed(true)
    end
    if state.followEnabled and state.followTargetPlayer then
        toggleFollow(state.followTargetPlayer.Name)
    end
    humanoid.Died:Connect(function()
        state.deathPosition = rootPart.Position
        if state.teleportOnDeathEnabled then
            task.spawn(function()
                task.wait(0.1)
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(state.deathPosition)
                    print("Teleported to death position: ", state.deathPosition)
                end
            end)
        end
    end)
    print("Character updated, rootPart: ", rootPart)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Функции
local function toggleScreenVisibility()
    state.screenVisible = not state.screenVisible
    local transparencyValue = state.screenVisible and 0 or 0.99
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
        print("Screen Visibility: ", state.screenVisible and "On" or "Off")
    else
        print("Screen object not found for toggling visibility!")
    end
end

local function startFlying()
    if state.isFlying then return end
    state.isFlying = true
    state.bodyVelocity = Instance.new("BodyVelocity")
    state.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    state.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    state.bodyVelocity.Parent = rootPart
    
    state.bodyGyro = Instance.new("BodyGyro")
    state.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    state.bodyGyro.CFrame = Camera.CFrame
    state.bodyGyro.Parent = rootPart
    
    humanoid.PlatformStand = true
    state.flightConnection = RunService.RenderStepped:Connect(function()
        if state.isFlying and char and rootPart then
            local moveDirection = Vector3.new(0, 0, 0)
            local camCFrame = Camera.CFrame
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
                state.bodyVelocity.Velocity = moveDirection.Unit * state.flySpeed
                state.bodyGyro.CFrame = camCFrame
            else
                state.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end
    end)
    table.insert(connections, state.flightConnection)
    print("Flight enabled! Use W, A, S, D, Space, LeftControl")
end

local function stopFlying()
    if not state.isFlying then return end
    state.isFlying = false
    if state.bodyVelocity then state.bodyVelocity:Destroy() state.bodyVelocity = nil end
    if state.bodyGyro then state.bodyGyro:Destroy() state.bodyGyro = nil end
    if state.flightConnection then state.flightConnection:Disconnect() state.flightConnection = nil end
    humanoid.PlatformStand = false
    print("Flight disabled!")
end

local function createPart()
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        local root = char.HumanoidRootPart
        local humanoid = char.Humanoid
        local offset = Vector3.new(0, 0, 0)
        if state.spawnDirection == "Forward" then
            offset = root.CFrame.LookVector * state.spawnDistance
        elseif state.spawnDirection == "Left" then
            offset = -root.CFrame.RightVector * state.spawnDistance
        elseif state.spawnDirection == "Right" then
            offset = root.CFrame.RightVector * state.spawnDistance
        elseif state.spawnDirection == "Back" then
            offset = -root.CFrame.LookVector * state.spawnDistance
        end
        local part = Instance.new("Part")
        part.Name = "GeneratedPart"
        part.Size = Vector3.new(5, 1, 5)
        part.Position = root.Position + offset - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight + part.Size.Y / 2, 0)
        part.Anchored = true
        part.BrickColor = BrickColor.new("Bright red")
        part.Parent = Workspace
        print("Part created in direction ", state.spawnDirection, ": ", part.Position)
    else
        print("Character or Humanoid not loaded!")
    end
end

local function createDirectionPart()
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        if state.directionPart then
            state.directionPart:Destroy()
            state.directionPart = nil
            print("Previous Direction Part destroyed!")
        end
        local root = char.HumanoidRootPart
        local humanoid = char.Humanoid
        local yPosition = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight + state.directionPartSize.Y / 2)
        state.directionPart = Instance.new("Part")
        state.directionPart.Name = "DirectionPart"
        state.directionPart.Size = state.directionPartSize
        state.directionPart.Position = Vector3.new(root.Position.X, yPosition, root.Position.Z)
        state.directionPart.BrickColor = state.directionPartColor
        state.directionPart.Transparency = state.directionPartTransparency
        state.directionPart.CanCollide = state.directionPartCanCollide
        state.directionPart.Anchored = state.directionPartAnchored
        state.directionPart.Parent = Workspace
        print("Direction Part created under feet: ", state.directionPart.Position)
    else
        print("Character or Humanoid not loaded!")
    end
end

local function toggleUnderFeetPart()
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        if not state.underFeetPart then
            local root = char.HumanoidRootPart
            local humanoid = char.Humanoid
            state.underFeetPart = Instance.new("Part")
            state.underFeetPart.Name = "UnderFeetPart"
            state.underFeetPart.Size = Vector3.new(5, 1, 5)
            local initialY = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight + state.underFeetPart.Size.Y / 2)
            state.underFeetPart.Position = Vector3.new(root.Position.X, initialY, root.Position.Z)
            state.underFeetPart.Anchored = true
            state.underFeetPart.BrickColor = BrickColor.new("Bright green")
            state.underFeetPart.Parent = Workspace
            state.renderConnection = RunService.RenderStepped:Connect(function()
                if state.underFeetPart and char and char:FindFirstChild("HumanoidRootPart") then
                    local rootPos = char.HumanoidRootPart.Position
                    state.underFeetPart.Position = Vector3.new(rootPos.X, initialY, rootPos.Z)
                end
            end)
            table.insert(connections, state.renderConnection)
            print("Float Part created at height ", initialY, ": ", state.underFeetPart.Position)
        else
            if state.renderConnection then
                state.renderConnection:Disconnect()
                state.renderConnection = nil
            end
            if state.underFeetPart then
                state.underFeetPart:Destroy()
                state.underFeetPart = nil
            end
            print("Float Part destroyed!")
        end
    else
        print("Character or Humanoid not loaded!")
    end
end

local function deleteAllParts()
    local partsDeleted = 0
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Part") and (child.Name == "GeneratedPart" or child.Name == "UnderFeetPart" or child.Name == "DirectionPart") then
            child:Destroy()
            partsDeleted = partsDeleted + 1
        end
    end
    state.directionPart = nil
    state.underFeetPart = nil
    if state.renderConnection then
        state.renderConnection:Disconnect()
        state.renderConnection = nil
    end
    print("Deleted ", partsDeleted, " Part(s)")
end

local function activateFlingOnTouch(hit)
    local targetHumanoid = hit.Parent:FindFirstChild("Humanoid")
    if targetHumanoid and hit.Parent:FindFirstChild("HumanoidRootPart") and Players:GetPlayerFromCharacter(hit.Parent) ~= player and state.flingEnabled then
        state.targetPlayer = Players:GetPlayerFromCharacter(hit.Parent)
        if state.targetPlayer and state.targetPlayer.Character and state.targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = state.targetPlayer.Character.HumanoidRootPart
            local direction = (targetRoot.Position - char.HumanoidRootPart.Position).Unit
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Velocity = direction * 100
            bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bodyVelocity.Parent = targetRoot
            task.wait(0.1)
            bodyVelocity:Destroy()
            print("Flinged ", state.targetPlayer.Name)
        end
    end
end

local function toggleFollow(targetName)
    local newTarget = Players:FindFirstChild(targetName)
    if newTarget and newTarget.Character and newTarget.Character:FindFirstChild("HumanoidRootPart") and newTarget ~= player then
        state.followTargetPlayer = newTarget
        state.followEnabled = not state.followEnabled
        if state.followEnabled then
            if state.followConnection then state.followConnection:Disconnect() end
            humanoid.PlatformStand = true
            state.followConnection = RunService.Heartbeat:Connect(function()
                if state.followTargetPlayer and state.followTargetPlayer.Character and state.followTargetPlayer.Character:FindFirstChild("HumanoidRootPart") and char and char:FindFirstChild("HumanoidRootPart") then
                    local targetRoot = state.followTargetPlayer.Character.HumanoidRootPart
                    local distance = (rootPart.Position - targetRoot.Position).Magnitude
                    local targetCFrame = targetRoot.CFrame * CFrame.new(0, 0, state.followDistance) * CFrame.Angles(0, math.pi, 0)
                    if distance > state.approachDistance then
                        rootPart.CFrame = targetCFrame
                        print("Teleported to ", state.followTargetPlayer.Name, " at distance ", state.followDistance, " units")
                    else
                        rootPart.CFrame = targetCFrame
                    end
                    Camera.CFrame = CFrame.new(rootPart.Position, targetRoot.Position)
                else
                    state.followEnabled = false
                    if state.followConnection then state.followConnection:Disconnect() state.followConnection = nil end
                    humanoid.PlatformStand = false
                    Camera.CameraSubject = char and char.Humanoid or nil
                    print("Target lost, follow disabled!")
                end
            end)
            table.insert(connections, state.followConnection)
            print("Follow enabled for ", targetName)
        else
            if state.followConnection then state.followConnection:Disconnect() state.followConnection = nil end
            humanoid.PlatformStand = false
            state.followTargetPlayer = nil
            Camera.CameraSubject = char and char.Humanoid or nil
            print("Follow disabled!")
        end
    else
        print("Invalid target player: ", targetName)
    end
end

local function toggleCFrameSpeed(enabled)
    state.cframeSpeedEnabled = enabled
    if enabled then
        if state.cframeConnection then state.cframeConnection:Disconnect() end
        state.cframeConnection = RunService.Heartbeat:Connect(function(step)
            if char and char:FindFirstChild("HumanoidRootPart") and humanoid.MoveDirection.Magnitude > 0 then
                char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + humanoid.MoveDirection * state.cframeSpeed * step
            end
        end)
        table.insert(connections, state.cframeConnection)
        print("CFrame Speed: On")
    else
        if state.cframeConnection then
            state.cframeConnection:Disconnect()
            state.cframeConnection = nil
        end
        print("CFrame Speed: Off")
    end
end

local function deleteAll()
    stopFlying()
    deleteAllParts()
    if state.cframeConnection then state.cframeConnection:Disconnect() state.cframeConnection = nil end
    if state.touchConnection then state.touchConnection:Disconnect() state.touchConnection = nil end
    if state.flightConnection then state.flightConnection:Disconnect() state.flightConnection = nil end
    if state.followConnection then state.followConnection:Disconnect() state.followConnection = nil end
    state.followEnabled = false
    state.followTargetPlayer = nil
    humanoid.PlatformStand = false
    Camera.CameraSubject = char and char.Humanoid or nil
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
        print("ScreenGui destroyed")
    end
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    connections = {}
    print("All parts, GUI, and connections deleted!")
end

-- GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui
print("ScreenGui initialized")

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 600, 0, 400)
frame.Position = UDim2.new(0.5, -300, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BackgroundTransparency = 0.5
frame.BorderSizePixel = 0
frame.Active = true
frame.Visible = false
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 12)
uiCorner.Parent = frame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(100, 100, 100)
uiStroke.Thickness = 2
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Parent = frame

local dragBar = Instance.new("Frame")
dragBar.Name = "DragBar"
dragBar.Size = UDim2.new(1, 0, 0, 40)
dragBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
dragBar.BackgroundTransparency = 0.3
dragBar.BorderSizePixel = 0
dragBar.Parent = frame

local dragCorner = Instance.new("UICorner")
dragCorner.CornerRadius = UDim.new(0, 12)
dragCorner.Parent = dragBar

local dragLabel = Instance.new("TextLabel")
dragLabel.Size = UDim2.new(1, -80, 1, 0)
dragLabel.Position = UDim2.new(0, 40, 0, 0)
dragLabel.BackgroundTransparency = 1
dragLabel.Text = "Control Panel"
dragLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
dragLabel.TextSize = 20
dragLabel.Font = Enum.Font.GothamBold
dragLabel.Parent = dragBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 16
closeButton.Parent = dragBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "TabsFrame"
tabsFrame.Size = UDim2.new(1, -20, 0, 40)
tabsFrame.Position = UDim2.new(0, 10, 0, 50)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = frame

local tabNames = {"Parts", "Functions", "Flight", "Follow", "Settings", "Properties", "PartBinds", "FunctionBinds"}
local tabFrames = {}
local currentTab = nil

for i, tabName in ipairs(tabNames) do
    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabName .. "Tab"
    tabButton.Size = UDim2.new(0.125, -5, 0, 30)
    tabButton.Position = UDim2.new((i-1)*0.125, 5, 0, 5)
    tabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabButton.TextSize = 14
    tabButton.Font = Enum.Font.Gotham
    tabButton.Parent = tabsFrame

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 8)
    tabCorner.Parent = tabButton

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Color = Color3.fromRGB(100, 100, 100)
    tabStroke.Thickness = 1
    tabStroke.Parent = tabButton

    local tabFrame = Instance.new("Frame")
    tabFrame.Name = tabName .. "Frame"
    tabFrame.Size = UDim2.new(1, -20, 1, -100)
    tabFrame.Position = UDim2.new(0, 10, 0, 100)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Visible = false
    tabFrame.Parent = frame
    tabFrames[tabName] = tabFrame

    tabButton.MouseEnter:Connect(function()
        TweenService:Create(tabButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(70, 70, 70),
            Size = UDim2.new(0.125, -5, 0, 32)
        }):Play()
    end)
    tabButton.MouseLeave:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                Size = UDim2.new(0.125, -5, 0, 30)
            }):Play()
        end
    end)

    tabButton.MouseButton1Click:Connect(function()
        if currentTab ~= tabName then
            if currentTab then
                tabFrames[currentTab].Visible = false
                local prevTab = tabsFrame:FindFirstChild(currentTab .. "Tab")
                TweenService:Create(prevTab, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                    Size = UDim2.new(0.125, -5, 0, 30)
                }):Play()
            end
            currentTab = tabName
            tabFrame.Visible = true
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(100, 100, 255),
                Size = UDim2.new(0.125, -5, 0, 32)
            }):Play()
            print("Switched to tab: ", tabName)
        end
    end)
end

-- Вкладка Parts
local partsFrame = tabFrames.Parts
local partSpawnButton = Instance.new("TextButton")
partSpawnButton.Name = "PartSpawnButton"
partSpawnButton.Size = UDim2.new(0.5, -10, 0, 40)
partSpawnButton.Position = UDim2.new(0, 5, 0, 10)
partSpawnButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
partSpawnButton.Text = "Spawn Part (" .. state.boundKeyPartSpawn.Name .. ")"
partSpawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
partSpawnButton.TextSize = 16
partSpawnButton.Parent = partsFrame
local partSpawnCorner = Instance.new("UICorner")
partSpawnCorner.CornerRadius = UDim.new(0, 8)
partSpawnCorner.Parent = partSpawnButton
partSpawnButton.MouseButton1Click:Connect(createPart)

local floatButton = Instance.new("TextButton")
floatButton.Name = "FloatButton"
floatButton.Size = UDim2.new(0.5, -10, 0, 40)
floatButton.Position = UDim2.new(0, 5, 0, 60)
floatButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
floatButton.Text = "Float: Off (" .. state.boundKeyFloat.Name .. ")"
floatButton.TextColor3 = Color3.fromRGB(255, 255, 255)
floatButton.TextSize = 16
floatButton.Parent = partsFrame
local floatCorner = Instance.new("UICorner")
floatCorner.CornerRadius = UDim.new(0, 8)
floatCorner.Parent = floatButton
floatButton.MouseButton1Click:Connect(function()
    toggleUnderFeetPart()
    floatButton.Text = state.underFeetPart and "Float: On (" .. state.boundKeyFloat.Name .. ")" or "Float: Off (" .. state.boundKeyFloat.Name .. ")"
end)

local directionPartButton = Instance.new("TextButton")
directionPartButton.Name = "DirectionPartButton"
directionPartButton.Size = UDim2.new(0.5, -10, 0, 40)
directionPartButton.Position = UDim2.new(0, 5, 0, 110)
directionPartButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
directionPartButton.Text = "Direction Part (" .. state.boundKeyDirection.Name .. ")"
directionPartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
directionPartButton.TextSize = 16
directionPartButton.Parent = partsFrame
local directionPartCorner = Instance.new("UICorner")
directionPartCorner.CornerRadius = UDim.new(0, 8)
directionPartCorner.Parent = directionPartButton
directionPartButton.MouseButton1Click:Connect(createDirectionPart)

local deletePartsButton = Instance.new("TextButton")
deletePartsButton.Name = "DeletePartsButton"
deletePartsButton.Size = UDim2.new(0.5, -10, 0, 40)
deletePartsButton.Position = UDim2.new(0, 5, 0, 160)
deletePartsButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
deletePartsButton.Text = "Delete All Parts"
deletePartsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deletePartsButton.TextSize = 16
deletePartsButton.Parent = partsFrame
local deletePartsCorner = Instance.new("UICorner")
deletePartsCorner.CornerRadius = UDim.new(0, 8)
deletePartsCorner.Parent = deletePartsButton
deletePartsButton.MouseButton1Click:Connect(function()
    deleteAllParts()
    floatButton.Text = "Float: Off (" .. state.boundKeyFloat.Name .. ")"
end)

local directionButton = Instance.new("TextButton")
directionButton.Name = "DirectionButton"
directionButton.Size = UDim2.new(0.5, -10, 0, 40)
directionButton.Position = UDim2.new(0.5, 5, 0, 10)
directionButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
directionButton.Text = "Direction: " .. state.spawnDirection
directionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
directionButton.TextSize = 16
directionButton.Parent = partsFrame
local directionCorner = Instance.new("UICorner")
directionCorner.CornerRadius = UDim.new(0, 8)
directionCorner.Parent = directionButton

local dropdownFrame = Instance.new("Frame")
dropdownFrame.Name = "DropdownFrame"
dropdownFrame.Size = UDim2.new(0.5, -10, 0, 120)
dropdownFrame.Position = UDim2.new(0.5, 5, 0, 60)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
dropdownFrame.BorderSizePixel = 1
dropdownFrame.Visible = false
dropdownFrame.Parent = partsFrame
local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, 8)
dropdownCorner.Parent = dropdownFrame

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
    local dirCorner = Instance.new("UICorner")
    dirCorner.CornerRadius = UDim.new(0, 8)
    dirCorner.Parent = dirButton
    dirButton.MouseButton1Click:Connect(function()
        state.spawnDirection = dir
        directionButton.Text = "Direction: " .. dir
        dropdownFrame.Visible = false
        print("Direction selected: ", dir)
    end)
end
directionButton.MouseButton1Click:Connect(function()
    dropdownFrame.Visible = not dropdownFrame.Visible
end)

-- Вкладка Functions
local functionsFrame = tabFrames.Functions
local screenVisibilityToggle = Instance.new("TextButton")
screenVisibilityToggle.Name = "ScreenVisibilityToggle"
screenVisibilityToggle.Size = UDim2.new(0.5, -10, 0, 40)
screenVisibilityToggle.Position = UDim2.new(0, 5, 0, 10)
screenVisibilityToggle.BackgroundColor3 = Color3.fromRGB(150, 0, 200)
screenVisibilityToggle.Text = "Screen Visibility: On (" .. state.boundKeyScreenVisibility.Name .. ")"
screenVisibilityToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
screenVisibilityToggle.TextSize = 16
screenVisibilityToggle.Parent = functionsFrame
local screenVisibilityCorner = Instance.new("UICorner")
screenVisibilityCorner.CornerRadius = UDim.new(0, 8)
screenVisibilityCorner.Parent = screenVisibilityToggle
screenVisibilityToggle.MouseButton1Click:Connect(function()
    toggleScreenVisibility()
    screenVisibilityToggle.Text = "Screen Visibility: " .. (state.screenVisible and "On (" .. state.boundKeyScreenVisibility.Name .. ")" or "Off (" .. state.boundKeyScreenVisibility.Name .. ")")
end)

local teleportToggle = Instance.new("TextButton")
teleportToggle.Name = "TeleportToggle"
teleportToggle.Size = UDim2.new(0.5, -10, 0, 40)
teleportToggle.Position = UDim2.new(0, 5, 0, 60)
teleportToggle.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
teleportToggle.Text = "Teleport on Death: Off (" .. state.boundKeyTeleport.Name .. ")"
teleportToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
teleportToggle.TextSize = 16
teleportToggle.Parent = functionsFrame
local teleportCorner = Instance.new("UICorner")
teleportCorner.CornerRadius = UDim.new(0, 8)
teleportCorner.Parent = teleportToggle
teleportToggle.MouseButton1Click:Connect(function()
    state.teleportOnDeathEnabled = not state.teleportOnDeathEnabled
    teleportToggle.Text = "Teleport on Death: " .. (state.teleportOnDeathEnabled and "On (" .. state.boundKeyTeleport.Name .. ")" or "Off (" .. state.boundKeyTeleport.Name .. ")")
    print("Teleport on Death: ", state.teleportOnDeathEnabled and "On" or "Off")
end)

local flingButton = Instance.new("TextButton")
flingButton.Name = "FlingButton"
flingButton.Size = UDim2.new(0.5, -10, 0, 40)
flingButton.Position = UDim2.new(0, 5, 0, 110)
flingButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
flingButton.Text = "Fling: Off"
flingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
flingButton.TextSize = 16
flingButton.Parent = functionsFrame
local flingCorner = Instance.new("UICorner")
flingCorner.CornerRadius = UDim.new(0, 8)
flingCorner.Parent = flingButton
flingButton.MouseButton1Click:Connect(function()
    state.flingEnabled = not state.flingEnabled
    flingButton.Text = "Fling: " .. (state.flingEnabled and "On" or "Off")
    if state.flingEnabled then
        if state.touchConnection then state.touchConnection:Disconnect() end
        state.touchConnection = rootPart.Touched:Connect(activateFlingOnTouch)
        table.insert(connections, state.touchConnection)
    else
        if state.touchConnection then state.touchConnection:Disconnect() state.touchConnection = nil end
        state.targetPlayer = nil
    end
    print("Fling toggled: ", state.flingEnabled and "On" or "Off")
end)

local speedToggle = Instance.new("TextButton")
speedToggle.Name = "SpeedToggle"
speedToggle.Size = UDim2.new(0.5, -10, 0, 40)
speedToggle.Position = UDim2.new(0.5, 5, 0, 10)
speedToggle.BackgroundColor3 = Color3.fromRGB(0, 0, 255)
speedToggle.Text = "Speed Toggle: Off (" .. state.boundKeySpeed.Name .. ")"
speedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
speedToggle.TextSize = 16
speedToggle.Parent = functionsFrame
local speedToggleCorner = Instance.new("UICorner")
speedToggleCorner.CornerRadius = UDim.new(0, 8)
speedToggleCorner.Parent = speedToggle
speedToggle.MouseButton1Click:Connect(function()
    state.speedEnabled = not state.speedEnabled
    speedToggle.Text = "Speed Toggle: " .. (state.speedEnabled and "On (" .. state.boundKeySpeed.Name .. ")" or "Off (" .. state.boundKeySpeed.Name .. ")")
    if char and char:FindFirstChild("Humanoid") then
        humanoid.WalkSpeed = state.speedEnabled and state.walkSpeed or 16
    end
    print("Speed toggle: ", state.speedEnabled and "On" or "Off")
end)

local speedSliderFrame = Instance.new("Frame")
speedSliderFrame.Name = "SpeedSliderFrame"
speedSliderFrame.Size = UDim2.new(0.5, -10, 0, 50)
speedSliderFrame.Position = UDim2.new(0.5, 5, 0, 60)
speedSliderFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
speedSliderFrame.Parent = functionsFrame
local speedSliderCorner = Instance.new("UICorner")
speedSliderCorner.CornerRadius = UDim.new(0, 8)
speedSliderCorner.Parent = speedSliderFrame

local speedSlider = Instance.new("TextButton")
speedSlider.Name = "SpeedSlider"
speedSlider.Size = UDim2.new(0, 20, 0, 20)
speedSlider.Position = UDim2.new(0, 0, 0, 15)
speedSlider.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
speedSlider.Text = ""
speedSlider.ZIndex = 2
speedSlider.Parent = speedSliderFrame
local speedSliderCornerBtn = Instance.new("UICorner")
speedSliderCornerBtn.CornerRadius = UDim.new(0, 8)
speedSliderCornerBtn.Parent = speedSlider

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
speedLabel.Position = UDim2.new( 0, 0, 0, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Walk Speed: " .. state.walkSpeed
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.TextSize = 14
speedLabel.Parent = speedSliderFrame

local draggingSpeed = false
speedSlider.MouseButton1Down:Connect(function()
    draggingSpeed = true
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingSpeed and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouseX = math.clamp(input.Position.X - speedSliderFrame.AbsolutePosition.X, 0, speedSliderFrame.AbsoluteSize.X - speedSlider.Size.X.Offset)
        speedSlider.Position = UDim2.new(0, mouseX, 0, 15)
        state.walkSpeed = math.floor(16 + (mouseX / (speedSliderFrame.AbsoluteSize.X - speedSlider.Size.X.Offset)) * 284)
        speedLabel.Text = "Walk Speed: " .. state.walkSpeed
        if char and char:FindFirstChild("Humanoid") and state.speedEnabled then
            humanoid.WalkSpeed = state.walkSpeed
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSpeed = false
    end
end)

local cframeSpeedToggle = Instance.new("TextButton")
cframeSpeedToggle.Name = "CFrameSpeedToggle"
cframeSpeedToggle.Size = UDim2.new(0.5, -10, 0, 40)
cframeSpeedToggle.Position = UDim2.new(0.5, 5, 0, 110)
cframeSpeedToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
cframeSpeedToggle.Text = "CFrame Speed: Off (" .. state.boundKeyCFrameSpeed.Name .. ")"
cframeSpeedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
cframeSpeedToggle.TextSize = 16
cframeSpeedToggle.Parent = functionsFrame
local cframeSpeedToggleCorner = Instance.new("UICorner")
cframeSpeedToggleCorner.CornerRadius = UDim.new(0, 8)
cframeSpeedToggleCorner.Parent = cframeSpeedToggle
cframeSpeedToggle.MouseButton1Click:Connect(function()
    toggleCFrameSpeed(not state.cframeSpeedEnabled)
    cframeSpeedToggle.Text = "CFrame Speed: " .. (state.cframeSpeedEnabled and "On (" .. state.boundKeyCFrameSpeed.Name .. ")" or "Off (" .. state.boundKeyCFrameSpeed.Name .. ")")
end)

local cframeSpeedSliderFrame = Instance.new("Frame")
cframeSpeedSliderFrame.Name = "CFrameSpeedSliderFrame"
cframeSpeedSliderFrame.Size = UDim2.new(0.5, -10, 0, 50)
cframeSpeedSliderFrame.Position = UDim2.new(0.5, 5, 0, 160)
cframeSpeedSliderFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
cframeSpeedSliderFrame.Parent = functionsFrame
local cframeSpeedSliderCorner = Instance.new("UICorner")
cframeSpeedSliderCorner.CornerRadius = UDim.new(0, 8)
cframeSpeedSliderCorner.Parent = cframeSpeedSliderFrame

local cframeSpeedSlider = Instance.new("TextButton")
cframeSpeedSlider.Name = "CFrameSpeedSlider"
cframeSpeedSlider.Size = UDim2.new(0, 20, 0, 20)
cframeSpeedSlider.Position = UDim2.new(0, 0, 0, 15)
cframeSpeedSlider.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
cframeSpeedSlider.Text = ""
cframeSpeedSlider.ZIndex = 2
cframeSpeedSlider.Parent = cframeSpeedSliderFrame
local cframeSpeedSliderCornerBtn = Instance.new("UICorner")
cframeSpeedSliderCornerBtn.CornerRadius = UDim.new(0, 8)
cframeSpeedSliderCornerBtn.Parent = cframeSpeedSlider

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
cframeSpeedLabel.Text = "CFrame Speed: " .. state.cframeSpeed
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
        state.cframeSpeed = math.floor(1 + (mouseX / (cframeSpeedSliderFrame.AbsoluteSize.X - cframeSpeedSlider.Size.X.Offset)) * 39)
        cframeSpeedLabel.Text = "CFrame Speed: " .. state.cframeSpeed
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingCframe = false
    end
end)

-- Вкладка Flight
local flightFrame = tabFrames.Flight
local flightToggle = Instance.new("TextButton")
flightToggle.Name = "FlightToggle"
flightToggle.Size = UDim2.new(0.5, -10, 0, 40)
flightToggle.Position = UDim2.new(0, 5, 0, 10)
flightToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
flightToggle.Text = "Flight: Off (" .. state.boundKeyFly.Name .. ")"
flightToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
flightToggle.TextSize = 16
flightToggle.Parent = flightFrame
local flightToggleCorner = Instance.new("UICorner")
flightToggleCorner.CornerRadius = UDim.new(0, 8)
flightToggleCorner.Parent = flightToggle
flightToggle.MouseButton1Click:Connect(function()
    if state.isFlying then
        stopFlying()
        flightToggle.Text = "Flight: Off (" .. state.boundKeyFly.Name .. ")"
    else
        startFlying()
        flightToggle.Text = "Flight: On (" .. state.boundKeyFly.Name .. ")"
    end
end)

local flightSpeedSliderFrame = Instance.new("Frame")
flightSpeedSliderFrame.Name = "FlightSpeedSliderFrame"
flightSpeedSliderFrame.Size = UDim2.new(0.5, -10, 0, 50)
flightSpeedSliderFrame.Position = UDim2.new(0, 5, 0, 60)
flightSpeedSliderFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
flightSpeedSliderFrame.Parent = flightFrame
local flightSpeedSliderCorner = Instance.new("UICorner")
flightSpeedSliderCorner.CornerRadius = UDim.new(0, 8)
flightSpeedSliderCorner.Parent = flightSpeedSliderFrame

local flightSpeedSlider = Instance.new("TextButton")
flightSpeedSlider.Name = "FlightSpeedSlider"
flightSpeedSlider.Size = UDim2.new(0, 20, 0, 20)
flightSpeedSlider.Position = UDim2.new(0, 0, 0, 15)
flightSpeedSlider.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
flightSpeedSlider.Text = ""
flightSpeedSlider.ZIndex = 2
flightSpeedSlider.Parent = flightSpeedSliderFrame
local flightSpeedSliderCornerBtn = Instance.new("UICorner")
flightSpeedSliderCornerBtn.CornerRadius = UDim.new(0, 8)
flightSpeedSliderCornerBtn.Parent = flightSpeedSlider

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
flightSpeedLabel.Text = "Flight Speed: " .. state.flySpeed
flightSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
flightSpeedLabel.TextSize = 14
flightSpeedLabel.Parent = flightSpeedSliderFrame

local draggingFlight = false
flightSpeedSlider.MouseButton1Down:Connect(function()
    draggingFlight = true
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingFlight and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouseX = math.clamp(input.Position.X - flightSpeedSliderFrame.AbsolutePosition.X, 0, flightSpeedSliderFrame.AbsoluteSize.X - flightSpeedSlider.Size.X.Offset)
        flightSpeedSlider.Position = UDim2.new(0, mouseX, 0, 15)
        state.flySpeed = math.floor(20 + (mouseX / (flightSpeedSliderFrame.AbsoluteSize.X - flightSpeedSlider.Size.X.Offset)) * 280)
        flightSpeedLabel.Text = "Flight Speed: " .. state.flySpeed
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingFlight = false
    end
end)

-- Вкладка Follow
local followFrame = tabFrames.Follow
local followTargetInput = Instance.new("TextBox")
followTargetInput.Name = "FollowTargetInput"
followTargetInput.Size = UDim2.new(0.5, -10, 0, 40)
followTargetInput.Position = UDim2.new(0, 5, 0, 10)
followTargetInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
followTargetInput.Text = "Enter player name"
followTargetInput.TextSize = 16
followTargetInput.Parent = followFrame
local followTargetCorner = Instance.new("UICorner")
followTargetCorner.CornerRadius = UDim.new(0, 8)
followTargetCorner.Parent = followTargetInput

local followToggle = Instance.new("TextButton")
followToggle.Name = "FollowToggle"
followToggle.Size = UDim2.new(0.5, -10, 0, 40)
followToggle.Position = UDim2.new(0, 5, 0, 60)
followToggle.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
followToggle.Text = "Follow: Off"
followToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
followToggle.TextSize = 16
followToggle.Parent = followFrame
local followToggleCorner = Instance.new("UICorner")
followToggleCorner.CornerRadius = UDim.new(0, 8)
followToggleCorner.Parent = followToggle
followToggle.MouseButton1Click:Connect(function()
    toggleFollow(followTargetInput.Text)
    followToggle.Text = "Follow: " .. (state.followEnabled and "On" or "Off")
end)

-- Вкладка Settings
local settingsFrame = tabFrames.Settings
local unloadButton = Instance.new("TextButton")
unloadButton.Name = "UnloadButton"
unloadButton.Size = UDim2.new(0.5, -10, 0, 40)
unloadButton.Position = UDim2.new(0, 5, 0, 10)
unloadButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
unloadButton.Text = "Unload Script"
unloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadButton.TextSize = 16
unloadButton.Parent = settingsFrame
local unloadCorner = Instance.new("UICorner")
unloadCorner.CornerRadius = UDim.new(0, 8)
unloadCorner.Parent = unloadButton
unloadButton.MouseButton1Click:Connect(deleteAll)

local toggleGuiButton = Instance.new("TextButton")
toggleGuiButton.Name = "ToggleGuiButton"
toggleGuiButton.Size = UDim2.new(0.5, -10, 0, 40)
toggleGuiButton.Position = UDim2.new(0, 5, 0, 60)
toggleGuiButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
toggleGuiButton.Text = "Hide GUI"
toggleGuiButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleGuiButton.TextSize = 16
toggleGuiButton.Parent = settingsFrame
local toggleGuiCorner = Instance.new("UICorner")
toggleGuiCorner.CornerRadius = UDim.new(0, 8)
toggleGuiCorner.Parent = toggleGuiButton

-- Вкладка Properties
local propertiesFrame = tabFrames.Properties
local sizeXLabel = Instance.new("TextLabel")
sizeXLabel.Name = "SizeXLabel"
sizeXLabel.Size = UDim2.new(0.5, -10, 0, 20)
sizeXLabel.Position = UDim2.new(0, 5, 0, 10)
sizeXLabel.BackgroundTransparency = 1
sizeXLabel.Text = "Size X: 5"
sizeXLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeXLabel.TextSize = 14
sizeXLabel.Parent = propertiesFrame

local sizeXInput = Instance.new("TextBox")
sizeXInput.Name = "SizeXInput"
sizeXInput.Size = UDim2.new(0.5, -10, 0, 30)
sizeXInput.Position = UDim2.new(0, 5, 0, 35)
sizeXInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
sizeXInput.Text = "5"
sizeXInput.TextSize = 16
sizeXInput.Parent = propertiesFrame
local sizeXCorner = Instance.new("UICorner")
sizeXCorner.CornerRadius = UDim.new(0, 8)
sizeXCorner.Parent = sizeXInput

local sizeYLabel = Instance.new("TextLabel")
sizeYLabel.Name = "SizeYLabel"
sizeYLabel.Size = UDim2.new(0.5, -10, 0, 20)
sizeYLabel.Position = UDim2.new(0, 5, 0, 70)
sizeYLabel.BackgroundTransparency = 1
sizeYLabel.Text = "Size Y: 1"
sizeYLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeYLabel.TextSize = 14
sizeYLabel.Parent = propertiesFrame

local sizeYInput = Instance.new("TextBox")
sizeYInput.Name = "SizeYInput"
sizeYInput.Size = UDim2.new(0.5, -10, 0, 30)
sizeYInput.Position = UDim2.new(0, 5, 0, 95)
sizeYInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
sizeYInput.Text = "1"
sizeYInput.TextSize = 16
sizeYInput.Parent = propertiesFrame
local sizeYCorner = Instance.new("UICorner")
sizeYCorner.CornerRadius = UDim.new(0, 8)
sizeYCorner.Parent = sizeYInput

local sizeZLabel = Instance.new("TextLabel")
sizeZLabel.Name = "SizeZLabel"
sizeZLabel.Size = UDim2.new(0.5, -10, 0, 20)
sizeZLabel.Position = UDim2.new(0, 5, 0, 130)
sizeZLabel.BackgroundTransparency = 1
sizeZLabel.Text = "Size Z: 5"
sizeZLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeZLabel.TextSize = 14
sizeZLabel.Parent = propertiesFrame

local sizeZInput = Instance.new("TextBox")
sizeZInput.Name = "SizeZInput"
sizeZInput.Size = UDim2.new(0.5, -10, 0, 30)
sizeZInput.Position = UDim2.new(0, 5, 0, 155)
sizeZInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
sizeZInput.Text = "5"
sizeZInput.TextSize = 16
sizeZInput.Parent = propertiesFrame
local sizeZCorner = Instance.new("UICorner")
sizeZCorner.CornerRadius = UDim.new(0, 8)
sizeZCorner.Parent = sizeZInput

local colorLabel = Instance.new("TextLabel")
colorLabel.Name = "ColorLabel"
colorLabel.Size = UDim2.new(0.5, -10, 0, 20)
colorLabel.Position = UDim2.new(0, 5, 0, 190)
colorLabel.BackgroundTransparency = 1
colorLabel.Text = "Color: Bright red"
colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
colorLabel.TextSize = 14
colorLabel.Parent = propertiesFrame

local colorInput = Instance.new("TextBox")
colorInput.Name = "ColorInput"
colorInput.Size = UDim2.new(0.5, -10, 0, 30)
colorInput.Position = UDim2.new(0, 5, 0, 215)
colorInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
colorInput.Text = "Bright red"
colorInput.TextSize = 16
colorInput.Parent = propertiesFrame
local colorCorner = Instance.new("UICorner")
colorCorner.CornerRadius = UDim.new(0, 8)
colorCorner.Parent = colorInput

local transparencyLabel = Instance.new("TextLabel")
transparencyLabel.Name = "TransparencyLabel"
transparencyLabel.Size = UDim2.new(0.5, -10, 0, 20)
transparencyLabel.Position = UDim2.new(0.5, 5, 0, 10)
transparencyLabel.BackgroundTransparency = 1
transparencyLabel.Text = "Transparency: 0"
transparencyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
transparencyLabel.TextSize = 14
transparencyLabel.Parent = propertiesFrame

local transparencyInput = Instance.new("TextBox")
transparencyInput.Name = "TransparencyInput"
transparencyInput.Size = UDim2.new(0.5, -10, 0, 30)
transparencyInput.Position = UDim2.new(0.5, 5, 0, 35)
transparencyInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
transparencyInput.Text = "0"
transparencyInput.TextSize = 16
transparencyInput.Parent = propertiesFrame
local transparencyCorner = Instance.new("UICorner")
transparencyCorner.CornerRadius = UDim.new(0, 8)
transparencyCorner.Parent = transparencyInput

local canCollideToggle = Instance.new("TextButton")
canCollideToggle.Name = "CanCollideToggle"
canCollideToggle.Size = UDim2.new(0.5, -10, 0, 40)
canCollideToggle.Position = UDim2.new(0.5, 5, 0, 70)
canCollideToggle.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
canCollideToggle.Text = "CanCollide: On"
canCollideToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
canCollideToggle.TextSize = 16
canCollideToggle.Parent = propertiesFrame
local canCollideCorner = Instance.new("UICorner")
canCollideCorner.CornerRadius = UDim.new(0, 8)
canCollideCorner.Parent = canCollideToggle

local anchoredToggle = Instance.new("TextButton")
anchoredToggle.Name = "AnchoredToggle"
anchoredToggle.Size = UDim2.new(0.5, -10, 0, 40)
anchoredToggle.Position = UDim2.new(0.5, 5, 0, 120)
anchoredToggle.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
anchoredToggle.Text = "Anchored: On"
anchoredToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
anchoredToggle.TextSize = 16
anchoredToggle.Parent = propertiesFrame
local anchoredCorner = Instance.new("UICorner")
anchoredCorner.CornerRadius = UDim.new(0, 8)
anchoredCorner.Parent = anchoredToggle

local function updateDirectionPartProperties()
    if state.directionPart then
        local newSizeX = tonumber(sizeXInput.Text) or state.directionPartSize.X
        local newSizeY = tonumber(sizeYInput.Text) or state.directionPartSize.Y
        local newSizeZ = tonumber(sizeZInput.Text) or state.directionPartSize.Z
        state.directionPartSize = Vector3.new(newSizeX, newSizeY, newSizeZ)
        state.directionPart.Size = state.directionPartSize
        sizeXLabel.Text = "Size X: " .. newSizeX
        sizeYLabel.Text = "Size Y: " .. newSizeY
        sizeZLabel.Text = "Size Z: " .. newSizeZ

        local newColor = BrickColor.new(colorInput.Text)
        if newColor then
            state.directionPartColor = newColor
            state.directionPart.BrickColor = state.directionPartColor
            colorLabel.Text = "Color: " .. colorInput.Text
        end

        local newTransparency = tonumber(transparencyInput.Text) or state.directionPartTransparency
        if newTransparency >= 0 and newTransparency <= 1 then
            state.directionPartTransparency = newTransparency
            state.directionPart.Transparency = state.directionPartTransparency
            transparencyLabel.Text = "Transparency: " .. newTransparency
        end

        state.directionPart.CanCollide = state.directionPartCanCollide
        state.directionPart.Anchored = state.directionPartAnchored
        print("Direction Part properties updated!")
    end
end

sizeXInput.FocusLost:Connect(updateDirectionPartProperties)
sizeYInput.FocusLost:Connect(updateDirectionPartProperties)
sizeZInput.FocusLost:Connect(updateDirectionPartProperties)
colorInput.FocusLost:Connect(updateDirectionPartProperties)
transparencyInput.FocusLost:Connect(updateDirectionPartProperties)

canCollideToggle.MouseButton1Click:Connect(function()
    state.directionPartCanCollide = not state.directionPartCanCollide
    canCollideToggle.Text = "CanCollide: " .. (state.directionPartCanCollide and "On" or "Off")
    if state.directionPart then
        state.directionPart.CanCollide = state.directionPartCanCollide
    end
    print("Direction Part CanCollide: ", state.directionPartCanCollide and "On" or "Off")
end)

anchoredToggle.MouseButton1Click:Connect(function()
    state.directionPartAnchored = not state.directionPartAnchored
    anchoredToggle.Text = "Anchored: " .. (state.directionPartAnchored and "On" or "Off")
    if state.directionPart then
        state.directionPart.Anchored = state.directionPartAnchored
    end
    print("Direction Part Anchored: ", state.directionPartAnchored and "On" or "Off")
end)

-- Вкладка Part Binds
local partBindsFrame = tabFrames.PartBinds
local partBindLabel = Instance.new("TextLabel")
partBindLabel.Name = "PartBindLabel"
partBindLabel.Size = UDim2.new(0.5, -10, 0, 20)
partBindLabel.Position = UDim2.new(0, 5, 0, 10)
partBindLabel.BackgroundTransparency = 1
partBindLabel.Text = "Part Spawn Key: " .. state.boundKeyPartSpawn.Name
partBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
partBindLabel.TextSize = 14
partBindLabel.Parent = partBindsFrame

local partBindInput = Instance.new("TextBox")
partBindInput.Name = "PartBindInput"
partBindInput.Size = UDim2.new(0.5, -10, 0, 30)
partBindInput.Position = UDim2.new(0, 5, 0, 35)
partBindInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
partBindInput.Text = state.boundKeyPartSpawn.Name
partBindInput.TextSize = 16
partBindInput.Parent = partBindsFrame
local partBindCorner = Instance.new("UICorner")
partBindCorner.CornerRadius = UDim.new(0, 8)
partBindCorner.Parent = partBindInput

local floatBindLabel = Instance.new("TextLabel")
floatBindLabel.Name = "FloatBindLabel"
floatBindLabel.Size = UDim2.new(0.5, -10, 0, 20)
floatBindLabel.Position = UDim2.new(0, 5, 0, 70)
floatBindLabel.BackgroundTransparency = 1
floatBindLabel.Text = "Float Key: " .. state.boundKeyFloat.Name
floatBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
floatBindLabel.TextSize = 14
floatBindLabel.Parent = partBindsFrame

local floatBindInput = Instance.new("TextBox")
floatBindInput.Name = "FloatBindInput"
floatBindInput.Size = UDim2.new(0.5, -10, 0, 30)
floatBindInput.Position = UDim2.new(0, 5, 0, 95)
floatBindInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
floatBindInput.Text = state.boundKeyFloat.Name
floatBindInput.TextSize = 16
floatBindInput.Parent = partBindsFrame
local floatBindCorner = Instance.new("UICorner")
floatBindCorner.CornerRadius = UDim.new(0, 8)
floatBindCorner.Parent = floatBindInput

local directionBindLabel = Instance.new("TextLabel")
directionBindLabel.Name = "DirectionBindLabel"
directionBindLabel.Size = UDim2.new(0.5, -10, 0, 20)
directionBindLabel.Position = UDim2.new(0, 5, 0, 130)
directionBindLabel.BackgroundTransparency = 1
directionBindLabel.Text = "Direction Part Key: " .. state.boundKeyDirection.Name
directionBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
directionBindLabel.TextSize = 14
directionBindLabel.Parent = partBindsFrame

local directionBindInput = Instance.new("TextBox")
directionBindInput.Name = "DirectionBindInput"
directionBindInput.Size = UDim2.new(0.5, -10, 0, 30)
directionBindInput.Position = UDim2.new(0, 5, 0, 155)
directionBindInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
directionBindInput.Text = state.boundKeyDirection.Name
directionBindInput.TextSize = 16
directionBindInput.Parent = partBindsFrame
local directionBindCorner = Instance.new("UICorner")
directionBindCorner.CornerRadius = UDim.new(0, 8)
directionBindCorner.Parent = directionBindInput

local partBindButton = Instance.new("TextButton")
partBindButton.Name = "PartBindButton"
partBindButton.Size = UDim2.new(0.5, -10, 0, 40)
partBindButton.Position = UDim2.new(0, 5, 0, 190)
partBindButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
partBindButton.Text = "Apply Part Binds"
partBindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
partBindButton.TextSize = 16
partBindButton.Parent = partBindsFrame
local partBindButtonCorner = Instance.new("UICorner")
partBindButtonCorner.CornerRadius = UDim.new(0, 8)
partBindButtonCorner.Parent = partBindButton

-- Вкладка Function Binds
local functionBindsFrame = tabFrames.FunctionBinds
local teleportBindLabel = Instance.new("TextLabel")
teleportBindLabel.Name = "TeleportBindLabel"
teleportBindLabel.Size = UDim2.new(0.5, -10, 0, 20)
teleportBindLabel.Position = UDim2.new(0, 5, 0, 10)
teleportBindLabel.BackgroundTransparency = 1
teleportBindLabel.Text = "Teleport Key: " .. state.boundKeyTeleport.Name
teleportBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
teleportBindLabel.TextSize = 14
teleportBindLabel.Parent = functionBindsFrame

local teleportBindInput = Instance.new("TextBox")
teleportBindInput.Name = "TeleportBindInput"
teleportBindInput.Size = UDim2.new(0.5, -10, 0, 30)
teleportBindInput.Position = UDim2.new(0, 5, 0, 35)
teleportBindInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
teleportBindInput.Text = state.boundKeyTeleport.Name
teleportBindInput.TextSize = 16
teleportBindInput.Parent = functionBindsFrame
local teleportBindCorner = Instance.new("UICorner")
teleportBindCorner.CornerRadius = UDim.new(0, 8)
teleportBindCorner.Parent = teleportBindInput

local speedBindLabel = Instance.new("TextLabel")
speedBindLabel.Name = "SpeedBindLabel"
speedBindLabel.Size = UDim2.new(0.5, -10, 0, 20)
speedBindLabel.Position = UDim2.new(0, 5, 0, 70)
speedBindLabel.BackgroundTransparency = 1
speedBindLabel.Text = "Speed Key: " .. state.boundKeySpeed.Name
speedBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedBindLabel.TextSize = 14
speedBindLabel.Parent = functionBindsFrame

local speedBindInput = Instance.new("TextBox")
speedBindInput.Name = "SpeedBindInput"
speedBindInput.Size = UDim2.new(0.5, -10, 0, 30)
speedBindInput.Position = UDim2.new(0, 5, 0, 95)
speedBindInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
speedBindInput.Text = state.boundKeySpeed.Name
speedBindInput.TextSize = 16
speedBindInput.Parent = functionBindsFrame
local speedBindCorner = Instance.new("UICorner")
speedBindCorner.CornerRadius = UDim.new(0, 8)
speedBindCorner.Parent = speedBindInput

local cframeSpeedBindLabel = Instance.new("TextLabel")
cframeSpeedBindLabel.Name = "CFrameSpeedBindLabel"
cframeSpeedBindLabel.Size = UDim2.new(0.5, -10, 0, 20)
cframeSpeedBindLabel.Position = UDim2.new(0, 5, 0, 130)
cframeSpeedBindLabel.BackgroundTransparency = 1
cframeSpeedBindLabel.Text = "CFrame Speed Key: " .. state.boundKeyCFrameSpeed.Name
cframeSpeedBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
cframeSpeedBindLabel.TextSize = 14
cframeSpeedBindLabel.Parent = functionBindsFrame

local cframeSpeedBindInput = Instance.new("TextBox")
cframeSpeedBindInput.Name = "CFrameSpeedBindInput"
cframeSpeedBindInput.Size = UDim2.new(0.5, -10, 0, 30)
cframeSpeedBindInput.Position = UDim2.new(0, 5, 0, 155)
cframeSpeedBindInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
cframeSpeedBindInput.Text = state.boundKeyCFrameSpeed.Name
cframeSpeedBindInput.TextSize = 16
cframeSpeedBindInput.Parent = functionBindsFrame
local cframeSpeedBindCorner = Instance.new("UICorner")
cframeSpeedBindCorner.CornerRadius = UDim.new(0, 8)
cframeSpeedBindCorner.Parent = cframeSpeedBindInput

local screenVisibilityBindLabel = Instance.new("TextLabel")
screenVisibilityBindLabel.Name = "ScreenVisibilityBindLabel"
screenVisibilityBindLabel.Size = UDim2.new(0.5, -10, 0, 20)
screenVisibilityBindLabel.Position = UDim2.new(0, 5, 0, 190)
screenVisibilityBindLabel.BackgroundTransparency = 1
screenVisibilityBindLabel.Text = "Screen Visibility Key: " .. state.boundKeyScreenVisibility.Name
screenVisibilityBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
screenVisibilityBindLabel.TextSize = 14
screenVisibilityBindLabel.Parent = functionBindsFrame

local screenVisibilityBindInput = Instance.new("TextBox")
screenVisibilityBindInput.Name = "ScreenVisibilityBindInput"
screenVisibilityBindInput.Size = UDim2.new(0.5, -10, 0, 30)
screenVisibilityBindInput.Position = UDim2.new(0, 5, 0, 215)
screenVisibilityBindInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
screenVisibilityBindInput.Text = state.boundKeyScreenVisibility.Name
screenVisibilityBindInput.TextSize = 16
screenVisibilityBindInput.Parent = functionBindsFrame
local screenVisibilityBindCorner = Instance.new("UICorner") -- Это строка 1401
screenVisibilityBindCorner.CornerRadius = UDim.new(0, 8)
screenVisibilityBindCorner.Parent = screenVisibilityBindInput

local flightBindLabel = Instance.new("TextLabel")
flightBindLabel.Name = "FlightBindLabel"
flightBindLabel.Size = UDim2.new(0.5, -10, 0, 20)
flightBindLabel.Position = UDim2.new(0, 5, 0, 250)
flightBindLabel.BackgroundTransparency = 1
flightBindLabel.Text = "Flight Key: " .. state.boundKeyFly.Name
flightBindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
flightBindLabel.TextSize = 14
flightBindLabel.Parent = functionBindsFrame

local flightBindInput = Instance.new("TextBox")
flightBindInput.Name = "FlightBindInput"
flightBindInput.Size = UDim2.new(0.5, -10, 0, 30)
flightBindInput.Position = UDim2.new(0, 5, 0, 275)
flightBindInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
flightBindInput.Text = state.boundKeyFly.Name
flightBindInput.TextSize = 16
flightBindInput.Parent = functionBindsFrame
local flightBindCorner = Instance.new("UICorner")
flightBindCorner.CornerRadius = UDim.new(0, 8)
flightBindCorner.Parent = flightBindInput

local functionBindButton = Instance.new("TextButton")
functionBindButton.Name = "FunctionBindButton"
functionBindButton.Size = UDim2.new(0.5, -10, 0, 40)
functionBindButton.Position = UDim2.new(0, 5, 0, 310)
functionBindButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
functionBindButton.Text = "Apply Function Binds"
functionBindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
functionBindButton.TextSize = 16
functionBindButton.Parent = functionBindsFrame
local functionBindButtonCorner = Instance.new("UICorner")
functionBindButtonCorner.CornerRadius = UDim.new(0, 8)
functionBindButtonCorner.Parent = functionBindButton

-- Привязка клавиш
local function updatePartBinds()
    local newKeyPart = Enum.KeyCode[partBindInput.Text]
    if newKeyPart then
        state.boundKeyPartSpawn = newKeyPart
        partBindLabel.Text = "Part Spawn Key: " .. state.boundKeyPartSpawn.Name
        partSpawnButton.Text = "Spawn Part (" .. state.boundKeyPartSpawn.Name .. ")"
        print("Part Spawn Key updated to: ", state.boundKeyPartSpawn.Name)
    else
        partBindInput.Text = state.boundKeyPartSpawn.Name
        print("Invalid key for Part Spawn!")
    end

    local newKeyFloat = Enum.KeyCode[floatBindInput.Text]
    if newKeyFloat then
        state.boundKeyFloat = newKeyFloat
        floatBindLabel.Text = "Float Key: " .. state.boundKeyFloat.Name
        floatButton.Text = "Float: " .. (state.underFeetPart and "On" or "Off") .. " (" .. state.boundKeyFloat.Name .. ")"
        print("Float Key updated to: ", state.boundKeyFloat.Name)
    else
        floatBindInput.Text = state.boundKeyFloat.Name
        print("Invalid key for Float!")
    end

    local newKeyDirection = Enum.KeyCode[directionBindInput.Text]
    if newKeyDirection then
        state.boundKeyDirection = newKeyDirection
        directionBindLabel.Text = "Direction Part Key: " .. state.boundKeyDirection.Name
        directionPartButton.Text = "Direction Part (" .. state.boundKeyDirection.Name .. ")"
        print("Direction Part Key updated to: ", state.boundKeyDirection.Name)
    else
        directionBindInput.Text = state.boundKeyDirection.Name
        print("Invalid key for Direction Part!")
    end
end

local function updateFunctionBinds()
    local newKeyTeleport = Enum.KeyCode[teleportBindInput.Text]
    if newKeyTeleport then
        state.boundKeyTeleport = newKeyTeleport
        teleportBindLabel.Text = "Teleport Key: " .. state.boundKeyTeleport.Name
        teleportToggle.Text = "Teleport on Death: " .. (state.teleportOnDeathEnabled and "On" or "Off") .. " (" .. state.boundKeyTeleport.Name .. ")"
        print("Teleport Key updated to: ", state.boundKeyTeleport.Name)
    else
        teleportBindInput.Text = state.boundKeyTeleport.Name
        print("Invalid key for Teleport!")
    end

    local newKeySpeed = Enum.KeyCode[speedBindInput.Text]
    if newKeySpeed then
        state.boundKeySpeed = newKeySpeed
        speedBindLabel.Text = "Speed Key: " .. state.boundKeySpeed.Name
        speedToggle.Text = "Speed Toggle: " .. (state.speedEnabled and "On" or "Off") .. " (" .. state.boundKeySpeed.Name .. ")"
        print("Speed Key updated to: ", state.boundKeySpeed.Name)
    else
        speedBindInput.Text = state.boundKeySpeed.Name
        print("Invalid key for Speed!")
    end

    local newKeyCFrameSpeed = Enum.KeyCode[cframeSpeedBindInput.Text]
    if newKeyCFrameSpeed then
        state.boundKeyCFrameSpeed = newKeyCFrameSpeed
        cframeSpeedBindLabel.Text = "CFrame Speed Key: " .. state.boundKeyCFrameSpeed.Name
        cframeSpeedToggle.Text = "CFrame Speed: " .. (state.cframeSpeedEnabled and "On" or "Off") .. " (" .. state.boundKeyCFrameSpeed.Name .. ")"
        print("CFrame Speed Key updated to: ", state.boundKeyCFrameSpeed.Name)
    else
        cframeSpeedBindInput.Text = state.boundKeyCFrameSpeed.Name
        print("Invalid key for CFrame Speed!")
    end

    local newKeyScreenVisibility = Enum.KeyCode[screenVisibilityBindInput.Text]
    if newKeyScreenVisibility then
        state.boundKeyScreenVisibility = newKeyScreenVisibility
        screenVisibilityBindLabel.Text = "Screen Visibility Key: " .. state.boundKeyScreenVisibility.Name
        screenVisibilityToggle.Text = "Screen Visibility: " .. (state.screenVisible and "On" or "Off") .. " (" .. state.boundKeyScreenVisibility.Name .. ")"
        print("Screen Visibility Key updated to: ", state.boundKeyScreenVisibility.Name)
    else
        screenVisibilityBindInput.Text = state.boundKeyScreenVisibility.Name
        print("Invalid key for Screen Visibility!")
    end

    local newKeyFlight = Enum.KeyCode[flightBindInput.Text]
    if newKeyFlight then
        state.boundKeyFly = newKeyFlight
        flightBindLabel.Text = "Flight Key: " .. state.boundKeyFly.Name
        flightToggle.Text = "Flight: " .. (state.isFlying and "On" or "Off") .. " (" .. state.boundKeyFly.Name .. ")"
        print("Flight Key updated to: ", state.boundKeyFly.Name)
    else
        flightBindInput.Text = state.boundKeyFly.Name
        print("Invalid key for Flight!")
    end
end

partBindButton.MouseButton1Click:Connect(updatePartBinds)
functionBindButton.MouseButton1Click:Connect(updateFunctionBinds)

-- Обработка нажатий клавиш
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == state.boundKeyFly then
                if state.isFlying then
                    stopFlying()
                    flightToggle.Text = "Flight: Off (" .. state.boundKeyFly.Name .. ")"
                else
                    startFlying()
                    flightToggle.Text = "Flight: On (" .. state.boundKeyFly.Name .. ")"
                end
            elseif input.KeyCode == state.boundKeyPartSpawn then
                createPart()
            elseif input.KeyCode == state.boundKeyFloat then
                toggleUnderFeetPart()
                floatButton.Text = state.underFeetPart and "Float: On (" .. state.boundKeyFloat.Name .. ")" or "Float: Off (" .. state.boundKeyFloat.Name .. ")"
            elseif input.KeyCode == state.boundKeyDirection then
                createDirectionPart()
            elseif input.KeyCode == state.boundKeyTeleport then
                state.teleportOnDeathEnabled = not state.teleportOnDeathEnabled
                teleportToggle.Text = "Teleport on Death: " .. (state.teleportOnDeathEnabled and "On (" .. state.boundKeyTeleport.Name .. ")" or "Off (" .. state.boundKeyTeleport.Name .. ")")
                print("Teleport on Death: ", state.teleportOnDeathEnabled and "On" or "Off")
            elseif input.KeyCode == state.boundKeySpeed then
                state.speedEnabled = not state.speedEnabled
                speedToggle.Text = "Speed Toggle: " .. (state.speedEnabled and "On (" .. state.boundKeySpeed.Name .. ")" or "Off (" .. state.boundKeySpeed.Name .. ")")
                if char and char:FindFirstChild("Humanoid") then
                    humanoid.WalkSpeed = state.speedEnabled and state.walkSpeed or 16
                end
                print("Speed toggle: ", state.speedEnabled and "On" or "Off")
            elseif input.KeyCode == state.boundKeyCFrameSpeed then
                toggleCFrameSpeed(not state.cframeSpeedEnabled)
                cframeSpeedToggle.Text = "CFrame Speed: " .. (state.cframeSpeedEnabled and "On (" .. state.boundKeyCFrameSpeed.Name .. ")" or "Off (" .. state.boundKeyCFrameSpeed.Name .. ")")
            elseif input.KeyCode == state.boundKeyScreenVisibility then
                toggleScreenVisibility()
                screenVisibilityToggle.Text = "Screen Visibility: " .. (state.screenVisible and "On (" .. state.boundKeyScreenVisibility.Name .. ")" or "Off (" .. state.boundKeyScreenVisibility.Name .. ")")
            elseif input.KeyCode == Enum.KeyCode.L then
                frame.Visible = not frame.Visible
                toggleGuiButton.Text = frame.Visible and "Hide GUI" or "Show GUI"
            end
        end
    end
end)

-- Обработка перетаскивания GUI
local dragging = false
local dragStart = nil
local startPos = nil

dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Закрытие GUI
closeButton.MouseButton1Click:Connect(function()
    frame.Visible = false
    toggleGuiButton.Text = "Show GUI"
end)

toggleGuiButton.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
    toggleGuiButton.Text = frame.Visible and "Hide GUI" or "Show GUI"
end)

-- Инициализация первой вкладки
if currentTab == nil then
    currentTab = "Parts"
    tabFrames.Parts.Visible = true
    tabsFrame.PartsTab.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    tabsFrame.PartsTab.Size = UDim2.new(0.125, -5, 0, 32)
end

print("Script initialized successfully!")
