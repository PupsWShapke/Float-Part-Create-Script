local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local char = player.Character or player.CharacterAdded:Wait() -- Определяем char здесь для доступа к Screen

-- Переменные для бинда и направления
local boundKey = Enum.KeyCode.P -- Default key for spawning in direction
local boundKeyUnderFeet = Enum.KeyCode.O -- Default key for toggling under feet
local spawnDirection = "Forward" -- Default direction
local spawnDistance = 5 -- Spawn distance
local underFeetPart = nil -- Variable to store Part under feet
local renderConnection = nil -- Variable to store RenderStepped connection
local deathPosition = nil -- Сохраняем позицию смерти
local teleportOnDeathEnabled = false -- Переключатель телепорта
local flingEnabled = false -- Переключатель флинга
local targetPlayer = nil -- Хранит игрока для флинга
local walkSpeed = 16 -- Начальная скорость бега
local speedEnabled = false -- Переключатель скорости
local cframeSpeed = 2 -- Начальная скорость CFrame
local cframeSpeedEnabled = false -- Переключатель CFrame speed
local cframeConnection = nil -- Коннекшн для CFrame loop
local touchConnection = nil -- Коннекшн для touch fling
local movingPart = nil -- Переменная для Part перед игроком
local movingPartConnection = nil -- Коннекшн для движения Part
local movingPartEnabled = false -- Переключатель для Part перед игроком
local movingPartDistance = 5 -- Расстояние Part от игрока

-- Переменные для объекта Screen
local screen = Workspace:FindFirstChild("Map"):FindFirstChild("Screens"):FindFirstChild("Leaderboards"):FindFirstChild("Total"):FindFirstChild("Screen")
local screenVisible = true -- Начальное состояние видимости экрана

-- Инициализация объекта Screen (из первого скрипта)
if screen then
    if screen:IsA("BasePart") then
        screen.Size = Vector3.new(5, 5, 5)
        screen.CanCollide = true -- Всегда true, как запрошено
        screen.Transparency = 0 -- Изначально виден
        RunService.Heartbeat:Connect(function()
            if char and char:FindFirstChild("HumanoidRootPart") then
                screen.Position = char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 8
            end
        end)
    elseif screen:IsA("Model") then
        for _, child in pairs(screen:GetChildren()) do
            if child:IsA("BasePart") then
                child.Size = Vector3.new(2, 2, 1)
                child.CanCollide = true -- Всегда true, как запрошено
                child.Transparency = 0 -- Изначально виден
            end
        end
        RunService.Heartbeat:Connect(function()
            if char and char:FindFirstChild("HumanoidRootPart") then
                screen:SetPrimaryPartCFrame(CFrame.new(char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 5))
            end
        end)
    end
    print("Screen уменьшен до 2, 2, 1 и следует перед персонажем с CanCollide = true!")
else
    print("Объект по пути Workspace.Map.Screens.Leaderboards.Total.Screen не найден!")
end

-- Функция для переключения видимости Screen
local function toggleScreenVisibility()
    screenVisible = not screenVisible
    local transparencyValue = screenVisible and 0 or 0.99 -- 0 для видимого, 1 для невидимого

    if screen then
        if screen:IsA("BasePart") then
            screen.Transparency = transparencyValue
            -- CanCollide остается true, как запрошено
        elseif screen:IsA("Model") then
            for _, child in pairs(screen:GetChildren()) do
                if child:IsA("BasePart") then
                    child.Transparency = transparencyValue
                    -- CanCollide остается true, как запрошено
                end
            end
        end
        print("Screen Visible: " .. tostring(screenVisible))
    else
        print("Screen object not found for toggling visibility!")
    end
end


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
            local initialY = root.Position.Y - (root.Size.Y / 2 + underFeetPart.Size.Y / 2)
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
    local partsDeleted = 0
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Part") and (child.Name == "GeneratedPart" or child.Name == "MovingPart") then
            child:Destroy()
            partsDeleted = partsDeleted + 1
        end
    end
    print("Deleted " .. partsDeleted .. " GeneratedPart(s) and MovingPart(s)")
end

-- Function to activate fling on touched player
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
            print("Flinged " .. targetPlayer.Name .. ", мать его!")
        end
    end
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ToggleGui"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false -- Don't reset GUI on respawn

local function deleteAll()
    deleteAllParts()
    if underFeetPart then
        underFeetPart:Destroy()
        underFeetPart = nil
        print("UnderFeetPart destroyed")
    end
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
        print("Render connection disconnected")
    end
    if movingPartConnection then
        movingPartConnection:Disconnect()
        movingPartConnection = nil
        print("Moving Part connection disconnected")
    end
    if cframeConnection then
        cframeConnection:Disconnect()
        cframeConnection = nil
        print("CFrame connection disconnected")
    end
    if touchConnection then
        touchConnection:Disconnect()
        touchConnection = nil
        print("Touch connection disconnected")
    end
    if screenGui then
        print("Attempting to destroy ScreenGui, parent is: " .. tostring(screenGui.Parent))
        if screenGui.Parent then
            screenGui:Destroy()
            print("ScreenGui destroyed")
        else
            print("ScreenGui not found or already destroyed")
        end
    end
    if keyPressConnection then
        keyPressConnection:Disconnect()
        print("KeyPress connection disconnected")
    end
    if keyPressUnderFeetConnection then
        keyPressUnderFeetConnection:Disconnect()
        print("KeyPressUnderFeet connection disconnected")
    end
    print("All parts, GUI, and connections deleted!")
end

-- Create Main Frame
local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 900, 0, 500) -- Шире для трех колонок
frame.Position = UDim2.new(0.5, -450, 0.5, -250) -- Центр
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Dark gray background
frame.BorderSizePixel = 2
frame.Visible = false -- Initially hidden
frame.Parent = screenGui

-- Левая колонка для биндов (Binds Column)
local bindsColumn = Instance.new("Frame")
bindsColumn.Name = "BindsColumn"
bindsColumn.Size = UDim2.new(0.33, -10, 1, -10)
bindsColumn.Position = UDim2.new(0, 5, 0, 5)
bindsColumn.BackgroundTransparency = 1
bindsColumn.Parent = frame

local bindsLabel = Instance.new("TextLabel")
bindsLabel.Name = "BindsLabel"
bindsLabel.Size = UDim2.new(1, 0, 0, 30)
bindsLabel.Position = UDim2.new(0, 0, 0, 0)
bindsLabel.BackgroundTransparency = 1
bindsLabel.Text = "Binds"
bindsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
bindsLabel.TextSize = 18
bindsLabel.Parent = bindsColumn

local keyInput = Instance.new("TextBox")
keyInput.Name = "KeyInputDirection"
keyInput.Size = UDim2.new(1, 0, 0, 30)
keyInput.Position = UDim2.new(0, 0, 0.1, 0)
keyInput.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInput.Text = "P" -- Default
keyInput.TextSize = 18
keyInput.Parent = bindsColumn

local keyInputUnderFeet = Instance.new("TextBox")
keyInputUnderFeet.Name = "KeyInputUnderFeet"
keyInputUnderFeet.Size = UDim2.new(1, 0, 0, 30)
keyInputUnderFeet.Position = UDim2.new(0, 0, 0.2, 0)
keyInputUnderFeet.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
keyInputUnderFeet.Text = "O" -- Default
keyInputUnderFeet.TextSize = 18
keyInputUnderFeet.Parent = bindsColumn

local directionButton = Instance.new("TextButton")
directionButton.Name = "DirectionButton"
directionButton.Size = UDim2.new(1, 0, 0, 30)
directionButton.Position = UDim2.new(0, 0, 0.3, 0)
directionButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
directionButton.Text = "Direction: " .. spawnDirection
directionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
directionButton.TextSize = 16
directionButton.Parent = bindsColumn

local dropdownFrame = Instance.new("Frame")
dropdownFrame.Name = "DropdownFrame"
dropdownFrame.Size = UDim2.new(1, 0, 0, 120)
dropdownFrame.Position = UDim2.new(0, 0, 0.4, 0)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
dropdownFrame.BorderSizePixel = 1
dropdownFrame.Visible = false
dropdownFrame.Parent = bindsColumn

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

local bindButton = Instance.new("TextButton")
bindButton.Name = "BindButton"
bindButton.Size = UDim2.new(1, 0, 0, 30)
bindButton.Position = UDim2.new(0, 0, 0.6, 0)
bindButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
bindButton.Text = "Apply Binds"
bindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
bindButton.TextSize = 18
bindButton.Parent = bindsColumn

-- Средняя колонка для функций (Functions Column)
local functionsColumn = Instance.new("Frame")
functionsColumn.Name = "FunctionsColumn"
functionsColumn.Size = UDim2.new(0.33, -10, 1, -10)
functionsColumn.Position = UDim2.new(0.33, 5, 0, 5)
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
teleportToggle.BackgroundColor3 = Color3.fromRGB(255, 165, 0) -- Оранжевый
teleportToggle.Text = "Teleport on Death: Off"
teleportToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
teleportToggle.TextSize = 16
teleportToggle.Parent = functionsColumn

teleportToggle.MouseButton1Click:Connect(function()
    teleportOnDeathEnabled = not teleportOnDeathEnabled
    teleportToggle.Text = "Teleport on Death: " .. (teleportOnDeathEnabled and "On" or "Off")
    print("Teleport on Death: " .. (teleportOnDeathEnabled and "On" or "Off"))
end)

local flingButton = Instance.new("TextButton")
flingButton.Name = "FlingButton"
flingButton.Size = UDim2.new(1, 0, 0, 30)
flingButton.Position = UDim2.new(0, 0, 0.2, 0)
flingButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Красный
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
speedToggle.BackgroundColor3 = Color3.fromRGB(0, 0, 255) -- Синий
speedToggle.Text = "Speed Toggle: Off"
speedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
speedToggle.TextSize = 16
speedToggle.Parent = functionsColumn

speedToggle.MouseButton1Click:Connect(function()
    speedEnabled = not speedEnabled
    speedToggle.Text = "Speed Toggle: " .. (speedEnabled and "On" or "Off")
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
speedSlider.Position = UDim2.new(0, 0, 0, 15) -- Центр слайдера
speedSlider.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
speedSlider.Text = ""
speedSlider.ZIndex = 2 -- Выше бара
speedSlider.Parent = speedSliderFrame

local sliderBar = Instance.new("Frame")
sliderBar.Name = "SliderBar"
sliderBar.Size = UDim2.new(1, 0, 0, 5)
sliderBar.Position = UDim2.new(0, 0, 0, 25)
sliderBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
sliderBar.ZIndex = 1 -- Ниже слайдера
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

-- Логика ползунка
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

-- Кнопка для CFrame speed переключателя
local cframeSpeedToggle = Instance.new("TextButton")
cframeSpeedToggle.Name = "CFrameSpeedToggle"
cframeSpeedToggle.Size = UDim2.new(1, 0, 0, 30)
cframeSpeedToggle.Position = UDim2.new(0, 0, 0.5, 0)
cframeSpeedToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Зеленый
cframeSpeedToggle.Text = "CFrame Speed: Off"
cframeSpeedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
cframeSpeedToggle.TextSize = 16
cframeSpeedToggle.Parent = functionsColumn

cframeSpeedToggle.MouseButton1Click:Connect(function()
    cframeSpeedEnabled = not cframeSpeedEnabled
    cframeSpeedToggle.Text = "CFrame Speed: " .. (cframeSpeedEnabled and "On" or "Off")
    if cframeSpeedEnabled then
        if cframeConnection then cframeConnection:Disconnect() end
        cframeConnection = RunService.Heartbeat:Connect(function(step)
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.Humanoid.MoveDirection.Magnitude > 0 then
                player.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame + player.Character.Humanoid.MoveDirection * cframeSpeed * step
            end
        end)
    else
        if cframeConnection then
            cframeConnection:Disconnect()
            cframeConnection = nil
        end
    end
    print("CFrame Speed: " .. (cframeSpeedEnabled and "On" or "Off"))
end)

-- Ползунок для CFrame Speed
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
cframeSpeedSlider.BackgroundColor3 = Color3.fromRGB(255, 165, 0) -- Оранжевый для отличия
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

-- Логика ползунка для CFrame Speed
local draggingCframe = false
cframeSpeedSlider.MouseButton1Down:Connect(function()
    draggingCframe = true
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingCframe and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouseX = math.clamp(input.Position.X - cframeSpeedSliderFrame.AbsolutePosition.X, 0, cframeSpeedSliderFrame.AbsoluteSize.X - cframeSpeedSlider.Size.X.Offset)
        cframeSpeedSlider.Position = UDim2.new(0, mouseX, 0, 15)
        cframeSpeed = math.floor(1 + (mouseX / (cframeSpeedSliderFrame.AbsoluteSize.X - cframeSpeedSlider.Size.X.Offset)) * 39) -- От 1 до 40
        cframeSpeedLabel.Text = "CFrame Speed: " .. cframeSpeed
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingCframe = false
    end
end)

-- Новый переключатель видимости для Screen
local screenVisibilityToggle = Instance.new("TextButton")
screenVisibilityToggle.Name = "ScreenVisibilityToggle"
screenVisibilityToggle.Size = UDim2.new(1, 0, 0, 30)
screenVisibilityToggle.Position = UDim2.new(0, 0, 0.8, 0) -- Размещаем под Moving Part Toggle
screenVisibilityToggle.BackgroundColor3 = Color3.fromRGB(150, 0, 200) -- Пурпурный
screenVisibilityToggle.Text = "Screen Visibility: On" -- Изначально On
screenVisibilityToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
screenVisibilityToggle.TextSize = 16
screenVisibilityToggle.Parent = functionsColumn

screenVisibilityToggle.MouseButton1Click:Connect(function()
    toggleScreenVisibility()
    screenVisibilityToggle.Text = "Screen Visibility: " .. (screenVisible and "On" or "Off")
end)


-- Правая колонка для настроек (Settings Column)
local settingsColumn = Instance.new("Frame")
settingsColumn.Name = "SettingsColumn"
settingsColumn.Size = UDim2.new(0.33, -10, 1, -10)
settingsColumn.Position = UDim2.new(0.66, 5, 0, 5)
settingsColumn.BackgroundTransparency = 1
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

local deletePartsButton = Instance.new("TextButton")
deletePartsButton.Name = "DeletePartsButton"
deletePartsButton.Size = UDim2.new(1, 0, 0, 30)
deletePartsButton.Position = UDim2.new(0, 0, 0.1, 0)
deletePartsButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- Красный
deletePartsButton.Text = "Delete All Parts"
deletePartsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deletePartsButton.TextSize = 16
deletePartsButton.Parent = settingsColumn

local unloadButton = Instance.new("TextButton")
unloadButton.Name = "UnloadButton"
unloadButton.Size = UDim2.new(1, 0, 0, 30)
unloadButton.Position = UDim2.new(0, 0, 0.2, 0)
unloadButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Темно-красный
unloadButton.Text = "Unload Script"
unloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadButton.TextSize = 16
unloadButton.Parent = settingsColumn

-- Привязка функций к кнопкам
deletePartsButton.MouseButton1Click:Connect(function()
    deleteAllParts()
end)

unloadButton.MouseButton1Click:Connect(function()
    deleteAll()
end)

-- Handle key press to toggle frame visibility
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.L then
        frame.Visible = not frame.Visible
        dropdownFrame.Visible = false -- Close dropdown
    end
end)

if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
    touchConnection = player.Character.HumanoidRootPart.Touched:Connect(activateFlingOnTouch)
end
player.CharacterAdded:Connect(function(char)
    if char:FindFirstChild("HumanoidRootPart") then
        touchConnection = char.HumanoidRootPart.Touched:Connect(activateFlingOnTouch)
    end
end)

-- Handle death and teleport
local function onCharacterAdded(newCharacter)
    local humanoid = newCharacter:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            deathPosition = player.Character.HumanoidRootPart.Position
            print("Death position saved: " .. tostring(deathPosition))
        end
    end)

    if teleportOnDeathEnabled and deathPosition then
        wait(0.1)
        if newCharacter and newCharacter:FindFirstChild("HumanoidRootPart") then
            newCharacter.HumanoidRootPart.CFrame = CFrame.new(deathPosition)
            print("Teleported to death position: " .. tostring(deathPosition))
        end
    end
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
    onCharacterAdded(player.Character)
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
