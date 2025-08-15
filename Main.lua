local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Переменные для бинда и направления
local boundKey = Enum.KeyCode.P -- Default key for spawning in direction
local boundKeyUnderFeet = Enum.KeyCode.O -- Default key for toggling under feet
local spawnDirection = "Forward" -- Default direction
local spawnDistance = 5 -- Spawn distance
local underFeetPart = nil -- Variable to store Part under feet
local renderConnection = nil -- Variable to store RenderStepped connection

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ToggleGui"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false -- Don't reset GUI on respawn

-- Create Frame
local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 300, 0, 450) -- Size 300x450
frame.Position = UDim2.new(0.5, -150, 0.5, -225) -- Center of screen
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Dark gray background
frame.BorderSizePixel = 2
frame.Visible = false -- Initially hidden
frame.Parent = screenGui

-- Text label for instructions
local label = Instance.new("TextLabel")
label.Name = "Instructions"
label.Size = UDim2.new(1, 0, 0, 30)
label.Position = UDim2.new(0, 0, 0, 0)
label.BackgroundTransparency = 1
label.Text = "Bind and Direction Settings"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextSize = 18
label.Parent = frame

-- TextBox for first key input (spawn in direction)
local keyInput = Instance.new("TextBox")
keyInput.Name = "KeyInputDirection"
keyInput.Size = UDim2.new(0.8, 0, 0, 30)
keyInput.Position = UDim2.new(0.1, 0, 0.05, 0)
keyInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInput.Text = "P" -- Default
keyInput.TextSize = 18
keyInput.Parent = frame

-- TextBox for second key input (toggle under feet)
local keyInputUnderFeet = Instance.new("TextBox")
keyInputUnderFeet.Name = "KeyInputUnderFeet"
keyInputUnderFeet.Size = UDim2.new(0.8, 0, 0, 30)
keyInputUnderFeet.Position = UDim2.new(0.1, 0, 0.15, 0)
keyInputUnderFeet.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputUnderFeet.Text = "O" -- Default
keyInputUnderFeet.TextSize = 18
keyInputUnderFeet.Parent = frame

-- Button to open dropdown
local directionButton = Instance.new("TextButton")
directionButton.Name = "DirectionButton"
directionButton.Size = UDim2.new(0.8, 0, 0, 30)
directionButton.Position = UDim2.new(0.1, 0, 0.25, 0)
directionButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
directionButton.Text = "Direction: " .. spawnDirection
directionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
directionButton.TextSize = 16
directionButton.Parent = frame

-- Frame for dropdown
local dropdownFrame = Instance.new("Frame")
dropdownFrame.Name = "DropdownFrame"
dropdownFrame.Size = UDim2.new(0.8, 0, 0, 120) -- Height for 4 directions
dropdownFrame.Position = UDim2.new(0.1, 0, 0.35, 0)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
dropdownFrame.BorderSizePixel = 1
dropdownFrame.Visible = false -- Initially hidden
dropdownFrame.Parent = frame

-- Direction options
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

-- Handler for opening/closing dropdown
directionButton.MouseButton1Click:Connect(function()
    dropdownFrame.Visible = not dropdownFrame.Visible
end)

-- Button to apply binds
local bindButton = Instance.new("TextButton")
bindButton.Name = "BindButton"
bindButton.Size = UDim2.new(0.8, 0, 0, 30)
bindButton.Position = UDim2.new(0.1, 0, 0.7, 0)
bindButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
bindButton.Text = "Apply Binds"
bindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
bindButton.TextSize = 18
bindButton.Parent = frame

-- Button: Delete all parts
local deletePartsButton = Instance.new("TextButton")
deletePartsButton.Name = "DeletePartsButton"
deletePartsButton.Size = UDim2.new(0.8, 0, 0, 30)
deletePartsButton.Position = UDim2.new(0.1, 0, 0.8, 0)
deletePartsButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
deletePartsButton.Text = "Delete All Parts"
deletePartsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deletePartsButton.TextSize = 18
deletePartsButton.Parent = frame

-- Button: Delete all (parts + GUI)
local deleteAllButton = Instance.new("TextButton")
deleteAllButton.Name = "DeleteAllButton"
deleteAllButton.Size = UDim2.new(0.8, 0, 0, 30)
deleteAllButton.Position = UDim2.new(0.1, 0, 0.9, 0)
deleteAllButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
deleteAllButton.Text = "Delete All (Parts + GUI)"
deleteAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deleteAllButton.TextSize = 18
deleteAllButton.Parent = frame

-- Handle key press to toggle frame visibility
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.L then
        frame.Visible = not frame.Visible
        dropdownFrame.Visible = false -- Close dropdown
    end
end)

-- Function to create Part in direction under feet (static)
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
        print("Part created under feet in direction " .. spawnDirection .. ": " .. tostring(part.Position))
    else
        print("Character or Humanoid not loaded!")
    end
end

-- Function to spawn/delete Part under feet with X, Z movement
local function toggleUnderFeetPart()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
        if underFeetPart == nil then
            local root = player.Character.HumanoidRootPart
            local humanoid = player.Character.Humanoid
            underFeetPart = Instance.new("Part")
            underFeetPart.Name = "UnderFeetPart"
            underFeetPart.Size = Vector3.new(5, 1, 5)
            local initialY = root.Position.Y - (root.Size.Y / 2 + underFeetPart.Size.Y / 2) -- Fix Y at creation height
            underFeetPart.Position = Vector3.new(root.Position.X, initialY, root.Position.Z)
            underFeetPart.Anchored = true -- Anchor to manage position manually
            underFeetPart.BrickColor = BrickColor.new("Bright green")
            underFeetPart.Parent = Workspace
            
            -- Update Part position on X and Z every frame
            renderConnection = RunService.RenderStepped:Connect(function()
                if underFeetPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local rootPos = player.Character.HumanoidRootPart.Position
                    underFeetPart.Position = Vector3.new(rootPos.X, initialY, rootPos.Z)
                end
            end)
            
            print("Part under feet created and bound to X, Z at height " .. initialY .. ": " .. tostring(underFeetPart.Position))
        else
            if renderConnection then
                renderConnection:Disconnect()
                renderConnection = nil
            end
            if underFeetPart then
                underFeetPart:Destroy()
                underFeetPart = nil
            end
            print("Part under feet destroyed!")
        end
    else
        print("Character or Humanoid not loaded!")
    end
end

-- Function to delete all GeneratedPart
local function deleteAllParts()
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Part") and child.Name == "GeneratedPart" then
            child:Destroy()
        end
    end
    print("All parts deleted!")
end

-- Function to delete all parts and GUI
local function deleteAll()
    deleteAllParts()
    if underFeetPart then
        underFeetPart:Destroy()
        underFeetPart = nil
    end
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    screenGui:Destroy()
    -- Disable key binds
    if keyPressConnection then
        keyPressConnection:Disconnect()
    end
    if keyPressUnderFeetConnection then
        keyPressUnderFeetConnection:Disconnect()
    end
    print("All parts and GUI deleted!")
end

-- Handle key press for spawning in direction
local function onKeyPress(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKey then
        createPart()
    end
end
local keyPressConnection = UserInputService.InputBegan:Connect(onKeyPress)

-- Handle key press for toggling Part under feet
local function onKeyPressUnderFeet(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == boundKeyUnderFeet then
        toggleUnderFeetPart()
    end
end
local keyPressUnderFeetConnection = UserInputService.InputBegan:Connect(onKeyPressUnderFeet)

-- Handle "Apply Binds" button
bindButton.MouseButton1Click:Connect(function()
    local keyText1 = keyInput.Text:upper()
    if Enum.KeyCode[keyText1] then
        boundKey = Enum.KeyCode[keyText1]
        print("First key bound: " .. keyText1)
    else
        print("Invalid first key! Enter a letter, e.g., P")
    end
    
    local keyText2 = keyInputUnderFeet.Text:upper()
    if Enum.KeyCode[keyText2] then
        boundKeyUnderFeet = Enum.KeyCode[keyText2]
        print("Second key bound: " .. keyText2)
    else
        print("Invalid second key! Enter a letter, e.g., O")
    end
end)

-- Handle "Delete All Parts" button
deletePartsButton.MouseButton1Click:Connect(function()
    deleteAllParts()
end)

-- Handle "Delete All (Parts + GUI)" button
deleteAllButton.MouseButton1Click:Connect(function()
    deleteAll()
end)