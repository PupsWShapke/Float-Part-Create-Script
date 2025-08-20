local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Camera = Workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

-- Set up ReplicatedStorage structure
local function setupReplicatedStorage()
    local settings = ReplicatedStorage:FindFirstChild("Settings") or Instance.new("Folder")
    settings.Name = "Settings"
    settings.Parent = ReplicatedStorage

    local movement = settings:FindFirstChild("Movement") or Instance.new("Folder")
    movement.Name = "Movement"
    movement.Parent = settings

    local cooldowns = settings:FindFirstChild("Cooldowns") or Instance.new("Folder")
    cooldowns.Name = "Cooldowns"
    cooldowns.Parent = settings

    local multipliers = settings:FindFirstChild("Multipliers") or Instance.new("Folder")
    multipliers.Name = "Multipliers"
    multipliers.Parent = settings

    local function createIntValue(parent, name, value)
        local intValue = parent:FindFirstChild(name) or Instance.new("IntValue")
        intValue.Name = name
        intValue.Value = value
        intValue.Parent = parent
        print("Created IntValue: ", parent.Name .. "." .. name) -- Debug output
    end

    createIntValue(movement, "Flight", 100)
    createIntValue(movement, "Speed", 100)
    createIntValue(movement, "CFrameSpeed", 100)
    createIntValue(cooldowns, "Dash", 100)
    createIntValue(cooldowns, "Melee", 100)
    createIntValue(cooldowns, "WallCombo", 100)
    createIntValue(multipliers, "FlightSpeed", 100)
    createIntValue(multipliers, "WalkSpeed", 100)
    createIntValue(multipliers, "CFrameSpeedValue", 100)
    createIntValue(multipliers, "DashSpeed", 100)
    createIntValue(multipliers, "MeleeSpeed", 100)
    createIntValue(multipliers, "RagdollTimer", 100)
    createIntValue(multipliers, "RagdollPower", 100)
end

setupReplicatedStorage()

-- State variables
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
    boundKeyRagdollPower = Enum.KeyCode.N,
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
    followDistance = 5,
    screenVisible = true,
    directionPartSize = Vector3.new(5, 1, 5),
    directionPartColor = BrickColor.new("Bright red"),
    directionPartTransparency = 0,
    directionPartCanCollide = true,
    directionPartAnchored = true,
    noDashCooldown = false,
    noMeleeCooldown = false,
    noWallComboCooldown = false,
    dashSpeedMultiplier = 100,
    meleeSpeedMultiplier = 100,
    ragdollTimerMultiplier = 100,
    ragdollPowerActive = false,
    guiVisible = false,
    originalRagdollTimer = 100
}

local connections = {}

-- Screen object handling
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
    print("Screen initialized: follows player at 7 units distance")
else
    print("Screen object not found!")
end

-- Update character on respawn
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

-- Utility functions
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
        print("Screen visibility: ", state.screenVisible and "On" or "Off")
    else
        print("Screen object not found for visibility toggle!")
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
    print("Deleted ", partsDeleted, " parts")
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
            print("Fling on ", state.targetPlayer.Name)
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
            state.followConnection = RunService.RenderStepped:Connect(function()
                if state.followTargetPlayer and state.followTargetPlayer.Character and state.followTargetPlayer.Character:FindFirstChild("HumanoidRootPart") and char and char:FindFirstChild("HumanoidRootPart") then
                    local targetRoot = state.followTargetPlayer.Character.HumanoidRootPart
                    local targetPos = targetRoot.Position
                    local playerPos = char.HumanoidRootPart.Position
                    local directionToTarget = (targetPos - playerPos).Unit
                    local followPos = targetPos - directionToTarget * state.followDistance
                    -- Keep player's Y position to avoid vertical movement
                    followPos = Vector3.new(followPos.X, playerPos.Y, followPos.Z)
                    -- Orient player to look at target
                    char.HumanoidRootPart.CFrame = CFrame.new(followPos, targetPos)
                    print("Following ", state.followTargetPlayer.Name, " at distance ", state.followDistance)
                else
                    state.followEnabled = false
                    if state.followConnection then state.followConnection:Disconnect() state.followConnection = nil end
                    state.followTargetPlayer = nil
                    print("Follow stopped: target not found")
                end
            end)
            table.insert(connections, state.followConnection)
            print("Follow mode enabled for ", targetName)
        else
            if state.followConnection then state.followConnection:Disconnect() state.followConnection = nil end
            state.followTargetPlayer = nil
            print("Follow mode disabled")
        end
    else
        print("Invalid player for follow: ", targetName)
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
    local settings = ReplicatedStorage:FindFirstChild("Settings")
    if settings then
        local cooldowns = settings:FindFirstChild("Cooldowns")
        if cooldowns then
            if cooldowns:FindFirstChild("Dash") then cooldowns.Dash.Value = 100 end
            if cooldowns:FindFirstChild("Melee") then cooldowns.Melee.Value = 100 end
            if cooldowns:FindFirstChild("WallCombo") then cooldowns.WallCombo.Value = 100 end
        end
        local multipliers = settings:FindFirstChild("Multipliers")
        if multipliers then
            if multipliers:FindFirstChild("DashSpeed") then multipliers.DashSpeed.Value = 100 end
            if multipliers:FindFirstChild("MeleeSpeed") then multipliers.MeleeSpeed.Value = 100 end
            if multipliers:FindFirstChild("RagdollTimer") then multipliers.RagdollTimer.Value = 100 end
            if multipliers:FindFirstChild("RagdollPower") then multipliers.RagdollPower.Value = 100 end
        end
    end
    print("All parts, GUI, and connections removed! Settings reset.")
end

local function toggleCooldown(name, enabled)
    local settings = ReplicatedStorage:FindFirstChild("Settings")
    if settings and settings:FindFirstChild("Cooldowns") then
        local cooldown = settings.Cooldowns:FindFirstChild(name)
        if cooldown then
            cooldown.Value = enabled and 0 or 100
            print(name .. " Cooldown: ", enabled and "Off" or "On")
        else
            warn("Cooldown not found: ", name)
        end
    else
        warn("Settings or Cooldowns folder not found in ReplicatedStorage!")
    end
end

local function updateMultiplier(name, value)
    local settings = ReplicatedStorage:FindFirstChild("Settings")
    if settings and settings:FindFirstChild("Multipliers") then
        local multiplier = settings.Multipliers:FindFirstChild(name)
        if multiplier then
            multiplier.Value = value
            print(name .. " set to: ", value)
        else
            warn("Multiplier not found: ", name)
        end
    else
        warn("Settings or Multipliers folder not found in ReplicatedStorage!")
    end
end

-- GUI setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui
print("ScreenGui initialized")

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 300, 0, 600)
frame.Position = UDim2.new(0.5, -150, 0.5, -300)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel = 2
frame.Active = true
frame.Visible = state.guiVisible
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = frame

local dragBar = Instance.new("Frame")
dragBar.Name = "DragBar"
dragBar.Size = UDim2.new(1, 0, 0, 30)
dragBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
dragBar.BackgroundTransparency = 0.2
dragBar.BorderSizePixel = 0
dragBar.Parent = frame

local dragCorner = Instance.new("UICorner")
dragCorner.CornerRadius = UDim.new(0, 10)
dragCorner.Parent = dragBar

local dragLabel = Instance.new("TextLabel")
dragLabel.Size = UDim2.new(1, -60, 1, 0)
dragLabel.Position = UDim2.new(0, 10, 0, 0)
dragLabel.BackgroundTransparency = 1
dragLabel.Text = "Admin Panel"
dragLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
dragLabel.TextSize = 18
dragLabel.Font = Enum.Font.SourceSansBold
dragLabel.TextXAlignment = Enum.TextXAlignment.Left
dragLabel.Parent = dragBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 25, 0, 25)
closeButton.Position = UDim2.new(1, -30, 0, 2.5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 14
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Parent = dragBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "TabsFrame"
tabsFrame.Size = UDim2.new(1, -10, 0, 30)
tabsFrame.Position = UDim2.new(0, 5, 0, 40)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = frame

local tabNames = {"Main", "Movement", "Parts", "Follow", "Cooldowns", "Multipliers", "Binds", "Settings"}
local tabFrames = {}
local currentTab = nil

for i, tabName in ipairs(tabNames) do
    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabName .. "Tab"
    tabButton.Size = UDim2.new(0.125, -5, 0, 25)
    tabButton.Position = UDim2.new((i-1)*0.125, 3, 0, 2)
    tabButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabButton.TextSize = 12
    tabButton.Font = Enum.Font.SourceSans
    tabButton.Parent = tabsFrame

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabButton

    local tabFrame = Instance.new("Frame")
    tabFrame.Name = tabName .. "Frame"
    tabFrame.Size = UDim2.new(1, -10, 1, -80)
    tabFrame.Position = UDim2.new(0, 5, 0, 75)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Visible = false
    tabFrame.Parent = frame
    tabFrames[tabName] = tabFrame

    tabButton.MouseEnter:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(80, 80, 80),
                Size = UDim2.new(0.125, -5, 0, 27)
            }):Play()
        end
    end)
    tabButton.MouseLeave:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                Size = UDim2.new(0.125, -5, 0, 25)
            }):Play()
        end
    end)

    tabButton.MouseButton1Click:Connect(function()
        if currentTab ~= tabName then
            if currentTab then
                tabFrames[currentTab].Visible = false
                local prevTab = tabsFrame:FindFirstChild(currentTab .. "Tab")
                TweenService:Create(prevTab, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                    Size = UDim2.new(0.125, -5, 0, 25)
                }):Play()
            end
            currentTab = tabName
            tabFrame.Visible = true
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(100, 100, 255),
                Size = UDim2.new(0.125, -5, 0, 27)
            }):Play()
            print("Switched to tab: ", tabName)
        end
    end)
end

-- Helper functions for UI creation
local function createButton(name, positionY, color, text, parent, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 280, 0, 30)
    button.Position = UDim2.new(0, 10, 0, positionY)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 16
    button.Font = Enum.Font.SourceSans
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    button.MouseButton1Click:Connect(callback)
    return button
end

local function createToggle(name, positionY, stateKey, path, folder, parent, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 280, 0, 30)
    button.Position = UDim2.new(0, 10, 0, positionY)
    button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    button.Text = name .. ": Off"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 16
    button.Font = Enum.Font.SourceSans
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button

    print("Created button: ", name, " in ", parent.Name) -- Debug output

    local isOn = false
    local intValue = ReplicatedStorage:FindFirstChild("Settings") and ReplicatedStorage.Settings:FindFirstChild(folder) and ReplicatedStorage.Settings[folder]:FindFirstChild(path)
    if not intValue or not intValue:IsA("IntValue") then
        warn("IntValue not found at ReplicatedStorage.Settings." .. folder .. "." .. path .. ". Create it in ReplicatedStorage!")
    end

    button.MouseButton1Click:Connect(function()
        isOn = not isOn
        state[stateKey] = isOn
        button.Text = name .. ": " .. (isOn and "On" or "Off")
        if intValue then
            toggleCooldown(path, isOn)
        end
        if callback then
            callback(isOn)
        end
        print(name .. " toggled: ", isOn and "On" or "Off")
    end)
    return button
end

local function createSliderToggle(name, positionY, stateKey, path, minValue, maxValue, parent)
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = name .. "Toggle"
    toggleButton.Size = UDim2.new(0, 280, 0, 30)
    toggleButton.Position = UDim2.new(0, 10, 0, positionY)
    toggleButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    toggleButton.Text = name .. ": Off (Value: " .. state[stateKey] .. ")"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 16
    toggleButton.Font = Enum.Font.SourceSans
    toggleButton.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = toggleButton

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = name .. "SliderFrame"
    sliderFrame.Size = UDim2.new(0, 280, 0, 20)
    sliderFrame.Position = UDim2.new(0, 10, 0, positionY + 35)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    sliderFrame.Parent = parent
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 6)
    sliderCorner.Parent = sliderFrame

    local sliderBar = Instance.new("Frame")
    sliderBar.Name = "SliderBar"
    sliderBar.Size = UDim2.new(1, 0, 0, 5)
    sliderBar.Position = UDim2.new(0, 0, 0.5, -2.5)
    sliderBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    sliderBar.Parent = sliderFrame

    local sliderKnob = Instance.new("TextButton")
    sliderKnob.Name = "SliderKnob"
    sliderKnob.Size = UDim2.new(0, 20, 0, 20)
    sliderKnob.Position = UDim2.new((state[stateKey] - minValue) / (maxValue - minValue), -10, 0, 0)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    sliderKnob.Text = ""
    sliderKnob.Parent = sliderFrame
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0, 10)
    knobCorner.Parent = sliderKnob

    local isOn = false
    local intValue = ReplicatedStorage:FindFirstChild("Settings") and ReplicatedStorage.Settings:FindFirstChild("Multipliers") and ReplicatedStorage.Settings.Multipliers:FindFirstChild(path)
    if not intValue or not intValue:IsA("IntValue") then
        warn("IntValue not found at ReplicatedStorage.Settings.Multipliers." .. path)
    end

    toggleButton.MouseButton1Click:Connect(function()
        isOn = not isOn
        toggleButton.Text = name .. ": " .. (isOn and "On" or "Off") .. " (Value: " .. state[stateKey] .. ")"
        if isOn then
            if intValue then
                intValue.Value = state[stateKey]
            end
        else
            if intValue then
                intValue.Value = 100
            end
        end
        print(name .. " toggled: " .. (isOn and "On" or "Off") .. " (Value = " .. (isOn and state[stateKey] or 100) .. ")")
    end)

    local dragging = false
    sliderKnob.MouseButton1Down:Connect(function()
        dragging = true
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mouseX = math.clamp(input.Position.X - sliderFrame.AbsolutePosition.X, 0, sliderFrame.AbsoluteSize.X - sliderKnob.Size.X.Offset)
            sliderKnob.Position = UDim2.new(0, mouseX, 0, 0)
            state[stateKey] = math.floor(minValue + (mouseX / (sliderFrame.AbsoluteSize.X - sliderKnob.Size.X.Offset)) * (maxValue - minValue))
            toggleButton.Text = name .. ": " .. (isOn and "On" or "Off") .. " (Value: " .. state[stateKey] .. ")"
            if isOn and intValue then
                intValue.Value = state[stateKey]
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return toggleButton, intValue
end

-- Main tab
local mainFrame = tabFrames.Main
createButton("Spawn Part", 10, Color3.fromRGB(100, 100, 255), "Spawn Part (" .. state.boundKeyPartSpawn.Name .. ")", mainFrame, createPart)
createButton("Float", 50, Color3.fromRGB(0, 200, 0), "Float: Off (" .. state.boundKeyFloat.Name .. ")", mainFrame, function()
    toggleUnderFeetPart()
    mainFrame.Float.Text = "Float: " .. (state.underFeetPart and "On" or "Off") .. " (" .. state.boundKeyFloat.Name .. ")"
end)
createButton("Direction Part", 90, Color3.fromRGB(255, 100, 100), "Direction Part (" .. state.boundKeyDirection.Name .. ")", mainFrame, createDirectionPart)
createButton("Delete All Parts", 130, Color3.fromRGB(200, 50, 50), "Delete All Parts", mainFrame, function()
    deleteAllParts()
    mainFrame.Float.Text = "Float: Off (" .. state.boundKeyFloat.Name .. ")"
end)

-- Movement tab
local movementFrame = tabFrames.Movement
createToggle("Flight", 10, "isFlying", "Flight", "Movement", movementFrame, function(enabled)
    if enabled then startFlying() else stopFlying() end
    if movementFrame:FindFirstChild("Flight") then
        movementFrame.Flight.Text = "Flight: " .. (state.isFlying and "On" or "Off") .. " (" .. state.boundKeyFly.Name .. ")"
    end
end)
createSliderToggle("Flight Speed", 50, "flySpeed", "FlightSpeed", 20, 300, movementFrame)
createToggle("Speed", 110, "speedEnabled", "Speed", "Movement", movementFrame, function(enabled)
    humanoid.WalkSpeed = enabled and state.walkSpeed or 16
    print("Speed toggled: ", enabled and "On" or "Off")
end)
createSliderToggle("Walk Speed", 150, "walkSpeed", "WalkSpeed", 16, 300, movementFrame)
createToggle("CFrame Speed", 210, "cframeSpeedEnabled", "CFrameSpeed", "Movement", movementFrame, function(enabled)
    toggleCFrameSpeed(enabled)
    if movementFrame:FindFirstChild("CFrame Speed") then
        movementFrame["CFrame Speed"].Text = "CFrame Speed: " .. (state.cframeSpeedEnabled and "On" or "Off") .. " (" .. state.boundKeyCFrameSpeed.Name .. ")"
    end
end)
createSliderToggle("CFrame Speed", 250, "cframeSpeed", "CFrameSpeedValue", 1, 40, movementFrame)

-- Debug: Print all children of movementFrame
print("Children of movementFrame:")
for _, child in ipairs(movementFrame:GetChildren()) do
    print(child.Name)
end

-- Parts tab
local partsFrame = tabFrames.Parts
local directionButton = createButton("Direction", 10, Color3.fromRGB(100, 100, 255), "Direction: " .. state.spawnDirection, partsFrame, function()
    partsFrame.DropdownFrame.Visible = not partsFrame.DropdownFrame.Visible
end)
local dropdownFrame = Instance.new("Frame")
dropdownFrame.Name = "DropdownFrame"
dropdownFrame.Size = UDim2.new(0, 280, 0, 100)
dropdownFrame.Position = UDim2.new(0, 10, 0, 50)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
dropdownFrame.Visible = false
dropdownFrame.Parent = partsFrame
local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, 6)
dropdownCorner.Parent = dropdownFrame

local directions = {"Forward", "Left", "Right", "Back"}
for i, dir in ipairs(directions) do
    local dirButton = Instance.new("TextButton")
    dirButton.Name = dir .. "Option"
    dirButton.Size = UDim2.new(1, 0, 0, 25)
    dirButton.Position = UDim2.new(0, 0, (i-1) * 0.25, 0)
    dirButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    dirButton.Text = dir
    dirButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    dirButton.TextSize = 12
    dirButton.Font = Enum.Font.SourceSans
    dirButton.Parent = dropdownFrame
    local dirCorner = Instance.new("UICorner")
    dirCorner.CornerRadius = UDim.new(0, 6)
    dirCorner.Parent = dirButton
    dirButton.MouseButton1Click:Connect(function()
        state.spawnDirection = dir
        directionButton.Text = "Direction: " .. dir
        dropdownFrame.Visible = false
        print("Selected direction: ", dir)
    end)
end

local function createPropertyInput(labelName, inputName, positionY, defaultValue, parent, callback)
    local label = Instance.new("TextLabel")
    label.Name = labelName
    label.Size = UDim2.new(0, 280, 0, 20)
    label.Position = UDim2.new(0, 10, 0, positionY)
    label.BackgroundTransparency = 1
    label.Text = labelName .. ": " .. defaultValue
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 12
    label.Font = Enum.Font.SourceSans
    label.Parent = parent

    local input = Instance.new("TextBox")
    input.Name = inputName
    input.Size = UDim2.new(0, 280, 0, 25)
    input.Position = UDim2.new(0, 10, 0, positionY + 20)
    input.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    input.Text = tostring(defaultValue)
    input.TextColor3 = Color3.fromRGB(200, 200, 200)
    input.TextSize = 12
    input.Font = Enum.Font.SourceSans
    input.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = input

    input.FocusLost:Connect(function()
        callback(input.Text, label)
    end)
    return input, label
end

local function updateDirectionPartProperties()
    if state.directionPart then
        local newSizeX = tonumber(partsFrame.SizeXInput.Text) or state.directionPartSize.X
        local newSizeY = tonumber(partsFrame.SizeYInput.Text) or state.directionPartSize.Y
        local newSizeZ = tonumber(partsFrame.SizeZInput.Text) or state.directionPartSize.Z
        state.directionPartSize = Vector3.new(newSizeX, newSizeY, newSizeZ)
        state.directionPart.Size = state.directionPartSize
        partsFrame.SizeXLabel.Text = "Size X: " .. newSizeX
        partsFrame.SizeYLabel.Text = "Size Y: " .. newSizeY
        partsFrame.SizeZLabel.Text = "Size Z: " .. newSizeZ

        local newColor = BrickColor.new(partsFrame.ColorInput.Text)
        if newColor then
            state.directionPartColor = newColor
            state.directionPart.BrickColor = state.directionPartColor
            partsFrame.ColorLabel.Text = "Color: " .. partsFrame.ColorInput.Text
        end

        local newTransparency = tonumber(partsFrame.TransparencyInput.Text) or state.directionPartTransparency
        if newTransparency >= 0 and newTransparency <= 1 then
            state.directionPartTransparency = newTransparency
            state.directionPart.Transparency = state.directionPartTransparency
            partsFrame.TransparencyLabel.Text = "Transparency: " .. newTransparency
        end

        state.directionPart.CanCollide = state.directionPartCanCollide
        state.directionPart.Anchored = state.directionPartAnchored
        print("Direction Part properties updated!")
    end
end

createPropertyInput("Size X", "SizeXInput", 160, 5, partsFrame, function(text, label)
    local value = tonumber(text) or state.directionPartSize.X
    state.directionPartSize = Vector3.new(value, state.directionPartSize.Y, state.directionPartSize.Z)
    label.Text = "Size X: " .. value
    updateDirectionPartProperties()
end)
createPropertyInput("Size Y", "SizeYInput", 210, 1, partsFrame, function(text, label)
    local value = tonumber(text) or state.directionPartSize.Y
    state.directionPartSize = Vector3.new(state.directionPartSize.X, value, state.directionPartSize.Z)
    label.Text = "Size Y: " .. value
    updateDirectionPartProperties()
end)
createPropertyInput("Size Z", "SizeZInput", 260, 5, partsFrame, function(text, label)
    local value = tonumber(text) or state.directionPartSize.Z
    state.directionPartSize = Vector3.new(state.directionPartSize.X, state.directionPartSize.Y, value)
    label.Text = "Size Z: " .. value
    updateDirectionPartProperties()
end)
createPropertyInput("Color", "ColorInput", 310, "Bright red", partsFrame, function(text, label)
    local newColor = BrickColor.new(text)
    if newColor then
        state.directionPartColor = newColor
        label.Text = "Color: " .. text
        updateDirectionPartProperties()
    end
end)
createToggle("CanCollide", 360, "directionPartCanCollide", "CanCollide", "Parts", partsFrame, function(enabled)
    if state.directionPart then
        state.directionPart.CanCollide = enabled
    end
    print("CanCollide: ", enabled and "On" or "Off")
end)
createToggle("Anchored", 400, "directionPartAnchored", "Anchored", "Parts", partsFrame, function(enabled)
    if state.directionPart then
        state.directionPart.Anchored = enabled
    end
    print("Anchored: ", enabled and "On" or "Off")
end)

-- Follow tab
local followFrame = tabFrames.Follow
local followToggle = createButton("FollowToggle", 10, Color3.fromRGB(100, 100, 100), "Follow Mode: Off", followFrame, function()
    if state.followTargetPlayer then
        toggleFollow(state.followTargetPlayer.Name)
        followToggle.Text = "Follow Mode: " .. (state.followEnabled and "On" or "Off")
    else
        print("No player selected for follow!")
    end
end)
local updatePlayersButton = createButton("UpdatePlayers", 50, Color3.fromRGB(0, 200, 0), "Update Players List", followFrame, function()
    for _, child in ipairs(followFrame.PlayerList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    local layoutOrder = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 0, 30)
            button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            button.Text = p.Name
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 14
            button.Font = Enum.Font.SourceSans
            button.LayoutOrder = layoutOrder
            button.Parent = followFrame.PlayerList
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = button
            button.MouseButton1Click:Connect(function()
                state.followTargetPlayer = p
                print("Selected player for follow: ", p.Name)
            end)
            layoutOrder = layoutOrder + 1
        end
    end
    followFrame.PlayerList.CanvasSize = UDim2.new(0, 0, 0, layoutOrder * 35)
end)
local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Name = "PlayerList"
playerListFrame.Size = UDim2.new(0, 280, 0, 100)
playerListFrame.Position = UDim2.new(0, 10, 0, 90)
playerListFrame.BackgroundTransparency = 1
playerListFrame.ScrollBarThickness = 8
playerListFrame.Parent = followFrame
local playerListLayout = Instance.new("UIListLayout")
playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
playerListLayout.Padding = UDim.new(0, 5)
playerListLayout.Parent = playerListFrame
-- Removed updatePlayersButton:Fire() to prevent automatic list update

-- Cooldowns tab
local cooldownsFrame = tabFrames.Cooldowns
createToggle("No Dash Cooldown", 10, "noDashCooldown", "Dash", "Cooldowns", cooldownsFrame)
createToggle("No Melee Cooldown", 50, "noMeleeCooldown", "Melee", "Cooldowns", cooldownsFrame)
createToggle("No WallCombo Cooldown", 90, "noWallComboCooldown", "WallCombo", "Cooldowns", cooldownsFrame)

-- Multipliers tab
local multipliersFrame = tabFrames.Multipliers
createSliderToggle("Dash Speed", 10, "dashSpeedMultiplier", "DashSpeed", 0, 200, multipliersFrame)
createSliderToggle("Melee Speed", 65, "meleeSpeedMultiplier", "MeleeSpeed", 0, 200, multipliersFrame)
local ragdollTimerButton, ragdollTimerIntValue = createSliderToggle("Ragdoll Timer", 120, "ragdollTimerMultiplier", "RagdollTimer", 0, 200, multipliersFrame)
local ragdollNote = Instance.new("TextLabel")
ragdollNote.Name = "RagdollPowerNotice"
ragdollNote.Size = UDim2.new(0, 280, 0, 30)
ragdollNote.Position = UDim2.new(0, 10, 0, 175)
ragdollNote.BackgroundTransparency = 1
ragdollNote.Text = "Note: RagdollPower instantly kills after 4 hits or any ragdoll"
ragdollNote.TextColor3 = Color3.fromRGB(255, 0, 0)
ragdollNote.TextSize = 12
ragdollNote.TextWrapped = true
ragdollNote.Font = Enum.Font.SourceSans
ragdollNote.Parent = multipliersFrame

-- RagdollPower
local ragdollPowerIntValue = ReplicatedStorage:WaitForChild("Settings"):WaitForChild("Multipliers"):WaitForChild("RagdollPower")
local keyBindTextBox = Instance.new("TextBox")
keyBindTextBox.Name = "RagdollPowerBind"
keyBindTextBox.Size = UDim2.new(0, 280, 0, 30)
keyBindTextBox.Position = UDim2.new(0, 10, 0, 210)
keyBindTextBox.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyBindTextBox.Text = state.boundKeyRagdollPower.Name
keyBindTextBox.TextColor3 = Color3.fromRGB(0, 0, 0)
keyBindTextBox.TextSize = 16
keyBindTextBox.Font = Enum.Font.SourceSans
keyBindTextBox.Parent = multipliersFrame
local keyBindCorner = Instance.new("UICorner")
keyBindCorner.CornerRadius = UDim.new(0, 6)
keyBindCorner.Parent = keyBindTextBox

keyBindTextBox.FocusLost:Connect(function()
    local keyText = keyBindTextBox.Text:upper()
    if Enum.KeyCode[keyText] then
        state.boundKeyRagdollPower = Enum.KeyCode[keyText]
        print("RagdollPower bound to key: ", keyText)
    else
        keyBindTextBox.Text = state.boundKeyRagdollPower.Name
        print("Invalid key for RagdollPower! Use a letter, e.g., N")
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == state.boundKeyRagdollPower then
        state.ragdollPowerActive = true
        ragdollPowerIntValue.Value = 2147483647
        state.originalRagdollTimer = ragdollTimerIntValue.Value
        ragdollTimerIntValue.Value = 100
        print("RagdollPower held: Value = 2147483647, RagdollTimer = 100")
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == state.boundKeyRagdollPower then
        state.ragdollPowerActive = false
        ragdollPowerIntValue.Value = 100
        ragdollTimerIntValue.Value = state.originalRagdollTimer
        print("RagdollPower released: Value = 100, RagdollTimer restored")
    end
end)

-- Binds tab
local bindsFrame = tabFrames.Binds
local function createBindInput(labelName, inputName, positionY, stateKey, buttonToUpdate, parent)
    local label = Instance.new("TextLabel")
    label.Name = labelName
    label.Size = UDim2.new(0, 280, 0, 20)
    label.Position = UDim2.new(0, 10, 0, positionY)
    label.BackgroundTransparency = 1
    label.Text = labelName .. ": " .. state[stateKey].Name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 12
    label.Font = Enum.Font.SourceSans
    label.Parent = parent

    local input = Instance.new("TextBox")
    input.Name = inputName
    input.Size = UDim2.new(0, 280, 0, 25)
    input.Position = UDim2.new(0, 10, 0, positionY + 20)
    input.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    input.Text = state[stateKey].Name
    input.TextColor3 = Color3.fromRGB(200, 200, 200)
    input.TextSize = 12
    input.Font = Enum.Font.SourceSans
    input.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = input

    input.FocusLost:Connect(function()
        local newKey = Enum.KeyCode[input.Text:upper()]
        if newKey then
            state[stateKey] = newKey
            label.Text = labelName .. ": " .. newKey.Name
            if buttonToUpdate and buttonToUpdate.Parent then
                buttonToUpdate.Text = buttonToUpdate.Text:match("^(.-):") .. ": " .. (state[stateKey .. "Enabled"] and "On" or "Off") .. " (" .. newKey.Name .. ")"
            end
            print(labelName .. " updated to: ", newKey.Name)
        else
            input.Text = state[stateKey].Name
            print("Invalid key for ", labelName)
        end
    end)
    return input
end

createBindInput("Fly Key", "FlyBindInput", 10, "boundKeyFly", movementFrame.Flight, bindsFrame)
createBindInput("Part Spawn Key", "PartSpawnBindInput", 60, "boundKeyPartSpawn", mainFrame["Spawn Part"], bindsFrame)
createBindInput("Float Key", "FloatBindInput", 110, "boundKeyFloat", mainFrame.Float, bindsFrame)
createBindInput("Direction Part Key", "DirectionPartBindInput", 160, "boundKeyDirection", mainFrame["Direction Part"], bindsFrame)
createBindInput("Teleport Key", "TeleportBindInput", 210, "boundKeyTeleport", nil, bindsFrame)
createBindInput("Speed Key", "SpeedBindInput", 260, "boundKeySpeed", movementFrame.Speed, bindsFrame)
createBindInput("CFrame Speed Key", "CFrameSpeedBindInput", 310, "boundKeyCFrameSpeed", movementFrame["CFrame Speed"], bindsFrame)
createBindInput("Screen Visibility Key", "ScreenVisibilityBindInput", 360, "boundKeyScreenVisibility", nil, bindsFrame)
createBindInput("RagdollPower Key", "RagdollPowerBindInput", 410, "boundKeyRagdollPower", nil, bindsFrame)

-- Settings tab
local settingsFrame = tabFrames.Settings
createToggle("Teleport on Death", 10, "teleportOnDeathEnabled", "TeleportOnDeath", "Settings", settingsFrame)
createToggle("Fling", 50, "flingEnabled", "Fling", "Settings", settingsFrame, function(enabled)
    if enabled then
        if state.touchConnection then state.touchConnection:Disconnect() end
        state.touchConnection = rootPart.Touched:Connect(activateFlingOnTouch)
        table.insert(connections, state.touchConnection)
    else
        if state.touchConnection then state.touchConnection:Disconnect() state.touchConnection = nil end
        state.targetPlayer = nil
    end
    print("Fling: ", enabled and "On" or "Off")
end)
createToggle("Screen Visibility", 90, "screenVisible", "ScreenVisibility", "Settings", settingsFrame, function(enabled)
    toggleScreenVisibility()
end)
createButton("Delete All", 130, Color3.fromRGB(200, 50, 50), "Delete All and Reset", settingsFrame, deleteAll)
local toggleGuiButton = createButton("Toggle GUI", 170, Color3.fromRGB(255, 100, 100), "Show GUI", settingsFrame, function()
    state.guiVisible = not state.guiVisible
    frame.Visible = state.guiVisible
    toggleGuiButton.Text = state.guiVisible and "Hide GUI" or "Show GUI"
end)

-- GUI dragging
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

-- Close GUI
closeButton.MouseButton1Click:Connect(function()
    state.guiVisible = false
    frame.Visible = false
    toggleGuiButton.Text = "Show GUI"
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.L then
            state.guiVisible = not state.guiVisible
            frame.Visible = state.guiVisible
            toggleGuiButton.Text = state.guiVisible and "Hide GUI" or "Show GUI"
            print("GUI visibility: ", state.guiVisible and "On" or "Off")
        elseif input.KeyCode == state.boundKeyFly then
            state.isFlying = not state.isFlying
            if state.isFlying then startFlying() else stopFlying() end
            if movementFrame:FindFirstChild("Flight") then
                movementFrame.Flight.Text = "Flight: " .. (state.isFlying and "On" or "Off") .. " (" .. state.boundKeyFly.Name .. ")"
            else
                warn("Flight button not found in movementFrame!")
            end
        elseif input.KeyCode == state.boundKeyPartSpawn then
            createPart()
        elseif input.KeyCode == state.boundKeyFloat then
            toggleUnderFeetPart()
            if mainFrame:FindFirstChild("Float") then
                mainFrame.Float.Text = "Float: " .. (state.underFeetPart and "On" or "Off") .. " (" .. state.boundKeyFloat.Name .. ")"
            else
                warn("Float button not found in mainFrame!")
            end
        elseif input.KeyCode == state.boundKeyDirection then
            createDirectionPart()
        elseif input.KeyCode == state.boundKeyTeleport then
            state.teleportOnDeathEnabled = not state.teleportOnDeathEnabled
            if settingsFrame:FindFirstChild("Teleport on Death") then
                settingsFrame["Teleport on Death"].Text = "Teleport on Death: " .. (state.teleportOnDeathEnabled and "On" or "Off") .. " (" .. state.boundKeyTeleport.Name .. ")"
            else
                warn("Teleport on Death button not found in settingsFrame!")
            end
            print("Teleport on Death: ", state.teleportOnDeathEnabled and "On" or "Off")
        elseif input.KeyCode == state.boundKeySpeed then
            state.speedEnabled = not state.speedEnabled
            humanoid.WalkSpeed = state.speedEnabled and state.walkSpeed or 16
            if movementFrame:FindFirstChild("Speed") then
                movementFrame.Speed.Text = "Speed: " .. (state.speedEnabled and "On" or "Off") .. " (" .. state.boundKeySpeed.Name .. ")"
            else
                warn("Speed button not found in movementFrame!")
            end
            print("Speed toggled: ", state.speedEnabled and "On" or "Off")
        elseif input.KeyCode == state.boundKeyCFrameSpeed then
            toggleCFrameSpeed(not state.cframeSpeedEnabled)
            if movementFrame:FindFirstChild("CFrame Speed") then
                movementFrame["CFrame Speed"].Text = "CFrame Speed: " .. (state.cframeSpeedEnabled and "On" or "Off") .. " (" .. state.boundKeyCFrameSpeed.Name .. ")"
            else
                warn("CFrame Speed button not found in movementFrame!")
            end
            print("CFrame Speed: ", state.cframeSpeedEnabled and "On" or "Off")
        elseif input.KeyCode == state.boundKeyScreenVisibility then
            toggleScreenVisibility()
            if settingsFrame:FindFirstChild("Screen Visibility") then
                settingsFrame["Screen Visibility"].Text = "Screen Visibility: " .. (state.screenVisible and "On" or "Off") .. " (" .. state.boundKeyScreenVisibility.Name .. ")"
            else
                warn("Screen Visibility button not found in settingsFrame!")
            end
        end
    end
end)

-- Initialize first tab
if currentTab == nil then
    currentTab = "Main"
    tabFrames.Main.Visible = true
    tabsFrame.MainTab.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    tabsFrame.MainTab.Size = UDim2.new(0.125, -5, 0, 27)
end

print("Script initialized successfully!")
