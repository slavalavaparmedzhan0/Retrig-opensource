local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CircleRadius = 170
local BulletSpeed = 2200
local TargetPlayer = nil
local RightMouseButtonHeld = false
local AimingEnabled = false
local CircleVisible = false
local OriginalCircleColor = Color3.fromRGB(107, 98, 155)
local GRAVITY = Workspace.Gravity
local VELOCITY_MULTIPLIER = 1.12
local GRAVITY_COMPENSATION = 1.15

local GrenadeESPEnabled = false
local VehicleESPEnabled = false
local grenadeESP = {}
local vehicleESPObjects = {}
local activeConnections = {}
local MAX_DISTANCE = 500
local ESP_UPDATE_INTERVAL = 0.5
local lastESPUpdate = 0

local currentKey = Enum.KeyCode.F2
local listening = false
local checkMark = nil
local grenadeCheckMark = nil
local vehicleCheckMark = nil
local namesCheckMark = nil
local boxesCheckMark = nil
local distanceCheckMark = nil
local miscCheckMark = nil
local lootCheckMark = nil
local mainFrame = nil
local contentFrame = nil

-- Hydra Aimbot Variables
local TargetLine = nil
local rainbowColor = OriginalCircleColor

local Circle = Drawing.new("Circle")
Circle.Visible = CircleVisible
Circle.Color = OriginalCircleColor
Circle.Thickness = 2
Circle.Radius = CircleRadius
Circle.Filled = false
Circle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

local FillColor = Color3.fromRGB(139,0,0)
local DepthMode = "AlwaysOnTop"
local FillTransparency = 0.5
local OutlineColor = Color3.fromRGB(139, 0,0)
local OutlineTransparency = 0
local CoreGui = game:GetService("CoreGui")
local connections = {}

local Storage = Instance.new("Folder")
Storage.Parent = CoreGui
Storage.Name = "Highlight_Storage"

local players = game:GetService("Players")
local client = players.LocalPlayer
local camera = workspace.CurrentCamera
local lighting = game:GetService("Lighting")

getgenv().global = getgenv()

function global.declare(self, index, value, check)
    if self[index] == nil then
        self[index] = value
    elseif check then
        local methods = { "remove", "Disconnect" }

        for _, method in methods do
            pcall(function()
                value[method](value)
            end)
        end
    end

    return self[index]
end

declare(global, "services", {})

function global.get(service)
    return services[service]
end

declare(declare(services, "loop", {}), "cache", {})

get("loop").new = function(self, index, func, disabled)
    if disabled == nil and (func == nil or typeof(func) == "boolean") then
        disabled = func func = index
    end

    self.cache[index] = {
        ["enabled"] = (not disabled),
        ["func"] = func,
        ["toggle"] = function(self, boolean)
            if boolean == nil then
                self.enabled = not self.enabled
            else
                self.enabled = boolean
            end
        end,
        ["remove"] = function()
            self.cache[index] = nil
        end
    }

    return self.cache[index]
end

declare(get("loop"), "connection", game:GetService("RunService").RenderStepped:Connect(function(delta)
    for _, loop in get("loop").cache do
        if loop.enabled then
            local success, result = pcall(function()
                loop.func(delta)
            end)

            if not success then
                warn(result)
            end
        end
    end
end), true)

declare(services, "new", {})

get("new").drawing = function(class, properties)
    local drawing = Drawing.new(class)
    for property, value in properties do
        pcall(function()
            drawing[property] = value
        end)
    end
    return drawing
end

declare(declare(services, "player", {}), "cache", {})

get("player").find = function(self, player)
    for character, data in self.cache do
        if data.player == player then
            return character
        end
    end
end

get("player").check = function(self, player)
    local success, check = pcall(function()
        local character = player:IsA("Player") and player.Character or player
        local children = {character:FindFirstChild('ServerCollider')}

        return children and character.Parent ~= nil
    end)

    return success and check
end

get("player").new = function(self, player)
    if player == game.Players.LocalPlayer then
        return
    end
    local function cache(character)
        self.cache[character] = {
            ["player"] = player,
            ["drawings"] = {
                ["box"] = get("new").drawing("Square", { Visible = false }),
                ["boxFilled"] = get("new").drawing("Square", { Visible = false, Filled = true }),
                ["boxOutline"] = get("new").drawing("Square", { Visible = false }),
                ["name"] = get("new").drawing("Text", { Visible = false, Center = true}),
                ["distance"] = get("new").drawing("Text", { Visible = false, Center = true}),
            },
            ["highlight"] = nil
        }

        local Highlight = Instance.new("Highlight")
        Highlight.Name = player.Name
        Highlight.FillColor = FillColor
        Highlight.DepthMode = DepthMode
        Highlight.FillTransparency = FillTransparency
        Highlight.OutlineColor = OutlineColor
        Highlight.OutlineTransparency = OutlineTransparency
        Highlight.Parent = Storage
        if character then
            Highlight.Adornee = character
        end

        self.cache[character].highlight = Highlight
        connections[player] = player.CharacterAdded:Connect(function(char)
            Highlight.Adornee = char
        end)
    end

    local function check(character)
        if self:check(character) then
            cache(character)
        else
            local listener
            listener = character.ChildAdded:Connect(function()
                if self:check(character) then
                    cache(character) listener:Disconnect()
                end
            end)
        end
    end

    if player.Character then check(player.Character) end
    player.CharacterAdded:Connect(check)
end

get("player").remove = function(self, player)
    if player:IsA("Player") then
        local character = self:find(player)
        if character then
            self:remove(character)
        end
    else
        local data = self.cache[player]
        local drawings = data.drawings
        local highlight = data.highlight

        self.cache[player] = nil

        for _, drawing in drawings do
            drawing:Remove()
        end

        if highlight then
            highlight:Destroy()
        end

        if connections[player] then
            connections[player]:Disconnect()
        end
    end
end

get("player").update = function(self, character, data)
    if not self:check(character) then
        self:remove(character)
    end

    local player = data.player
    local root = character:FindFirstChild('ServerCollider')
    local drawings = data.drawings

    if not root then 
        for _, drawing in pairs(drawings) do
            drawing.Visible = false
        end
        return
    end

    if self:check(client) then
        data.distance = (client.Character.ServerCollider.CFrame.Position - root.CFrame.Position).Magnitude
    end
    task.spawn(function()
        local position, visible = camera:WorldToViewportPoint(root.CFrame.Position)

        local visuals = features.visuals

        local function check()
            local team
            if visuals.teamCheck then team = player.Team ~= client.Team else team = true end
            return visuals.enabled and data.distance and data.distance <= visuals.renderDistance and team
        end

        local function color(color)
            if visuals.teamColor then
                color = player.TeamColor.Color
            end
            return color
        end

        if visible and check() then
            local scale = 1 / (position.Z * math.tan(math.rad(camera.FieldOfView * 0.5)) * 2) * 1000
            local width, height = math.floor(4.5 * scale), math.floor(6 * scale)
            local x, y = math.floor(position.X), math.floor(position.Y)
            local xPosition, yPosition = math.floor(x - width * 0.5), math.floor((y - height * 0.5) + (0.5 * scale))

            drawings.box.Size = Vector2.new(width, height)
            drawings.box.Position = Vector2.new(xPosition, yPosition)
            drawings.boxFilled.Size = drawings.box.Size
            drawings.boxFilled.Position = drawings.box.Position
            drawings.boxOutline.Size = drawings.box.Size
            drawings.boxOutline.Position = drawings.box.Position

            drawings.box.Color = color(visuals.boxes.color)
            drawings.box.Thickness = 1
            drawings.boxFilled.Color = color(visuals.boxes.filled.color)
            drawings.boxFilled.Transparency = visuals.boxes.filled.transparency
            drawings.boxOutline.Color = visuals.boxes.outline.color
            drawings.boxOutline.Thickness = 3

            drawings.boxOutline.ZIndex = drawings.box.ZIndex - 1
            drawings.boxFilled.ZIndex = drawings.boxOutline.ZIndex - 1

            drawings.name.Text = `[ {player.Name} ]`
            drawings.name.Size = math.max(math.min(math.abs(12.5 * scale), 12.5), 10)
            drawings.name.Position = Vector2.new(x, (yPosition - drawings.name.TextBounds.Y) - 2)
            drawings.name.Color = color(visuals.names.color)
            drawings.name.Outline = visuals.names.outline.enabled
            drawings.name.OutlineColor = visuals.names.outline.color

            drawings.name.ZIndex = drawings.box.ZIndex + 1

            drawings.distance.Text = `[ {math.floor(data.distance)} ]`
            drawings.distance.Size = math.max(math.min(math.abs(11 * scale), 11), 10)
            drawings.distance.Position = Vector2.new(x, (yPosition + height) + (drawings.distance.TextBounds.Y * 0.25))
            drawings.distance.Color = color(visuals.distance.color)
            drawings.distance.Outline = visuals.distance.outline.enabled
            drawings.distance.OutlineColor = visuals.distance.outline.color
        end

        drawings.box.Visible = (check() and visible and visuals.boxes.enabled)
        drawings.boxFilled.Visible = (check() and drawings.box.Visible and visuals.boxes.filled.enabled)
        drawings.boxOutline.Visible = (check() and drawings.box.Visible and visuals.boxes.outline.enabled)
        drawings.name.Visible = (check() and visible and visuals.names.enabled)
        drawings.distance.Visible = (check() and visible and visuals.distance.enabled)
    end)
end

declare(get("player"), "loop", get("loop"):new(function ()
    for character, data in get("player").cache do
        get("player"):update(character, data)
    end
end), true)

declare(global, "features", {})

features.toggle = function(self, feature, boolean)
    if self[feature] then
        if boolean == nil then
            self[feature].enabled = not self[feature].enabled
        else
            self[feature].enabled = boolean
        end

        if self[feature].toggle then
            task.spawn(function()
                self[feature]:toggle()
            end)
        end
    end
end

declare(features, "visuals", {
    ["enabled"] = true,
    ["teamCheck"] = false,
    ["teamColor"] = true,
    ["renderDistance"] = 4000,

    ["boxes"] = {
        ["enabled"] = false,
        ["color"] = Color3.fromRGB(139, 0, 0),
        ["outline"] = {
            ["enabled"] = true,
            ["color"] = Color3.fromRGB(0, 0, 0),
        },
        ["filled"] = {
            ["enabled"] = false,
            ["color"] = Color3.fromRGB(139, 0, 0),
            ["transparency"] = 0.25
        },
    },
    ["names"] = {
        ["enabled"] = false,
        ["color"] = Color3.fromRGB(139, 0, 0),
        ["outline"] = {
            ["enabled"] = true,
            ["color"] = Color3.fromRGB(0, 0, 0),
        },
    },
    ["distance"] = {
        ["enabled"] = false,
        ["color"] = Color3.fromRGB(139, 0, 0),
        ["outline"] = {
            ["enabled"] = true,
            ["color"] = Color3.fromRGB(0, 0, 0),
        },
    },
    ["grenade"] = {
        ["enabled"] = true,
        ["color"] = Color3.fromRGB(255, 50, 50)
    },
    ["vehicle"] = {
        ["enabled"] = true,
        ["color"] = Color3.fromRGB(255, 255, 0)
    }
})

for _, player in players:GetPlayers() do
    if player ~= client and not get("player"):find(player) then
        get("player"):new(player)
    end
end

declare(get('player'), 'added', workspace.ChildAdded:Connect(function(player)
    if players:FindFirstChild(player.Name) then
        if not get("player"):find(players[player.Name]) then
            get("player"):new(players[player.Name])
        end
    end
end), true)

declare(get('player'), 'removing', workspace.ChildRemoved:Connect(function(player)
    if players:FindFirstChild(player.Name) then
        get("player"):remove(players[player.Name])
    end
end), true)

local function initializeAimbotDrawings()
    if not TargetLine then
        TargetLine = Drawing.new("Line")
        TargetLine.Visible = false
        TargetLine.Thickness = 1
        TargetLine.Transparency = 1
    end
end

local function getBulletSpeed()
    local character = LocalPlayer.Character
    if not character then return 2200 end
    
    local gun = character:FindFirstChild("CurrentSelectedObject")
    if not gun or not gun.Value then return 2200 end
    
    local weaponName = gun.Value.Value.Name
    local weaponData = ReplicatedStorage:FindFirstChild("GunData"):FindFirstChild(weaponName)
    return weaponData and weaponData.Stats.BulletSettings.BulletSpeed.Value or 2200
end

local function predictPosition(targetPosition, targetVelocity)
    local distance = (targetPosition - Camera.CFrame.Position).Magnitude
    if distance < 1 then return targetPosition end
    local travelTime = distance / BulletSpeed
    return targetPosition + 
           targetVelocity * travelTime * VELOCITY_MULTIPLIER + 
           Vector3.new(0, 0.5 * GRAVITY * GRAVITY_COMPENSATION * travelTime^2, 0)
end

local function aimAtTarget()
    if not TargetPlayer or not TargetPlayer.Character then return end
    
    local head = TargetPlayer.Character:FindFirstChild("Head") or 
                 TargetPlayer.Character:FindFirstChild("ServerColliderHead")
    
    if head and head:IsA("BasePart") then
        local futurePos = predictPosition(head.Position, head.Velocity)
        local screenPoint = Camera:WorldToViewportPoint(futurePos)
        
        if screenPoint.Z > 0 then
            local delta = (Vector2.new(screenPoint.X, screenPoint.Y) - Circle.Position)
            mousemoverel(delta.X, delta.Y)
        end
    end
end

local function updateRainbowColor()
    local time = tick()
    local frequency = 2
    local r = (math.sin(time * frequency) * 0.5 + 0.5)
    local g = (math.sin(time * frequency + 2) * 0.5 + 0.5)
    local b = (math.sin(time * frequency + 4) * 0.5 + 0.5)
    rainbowColor = Color3.new(r, g, b)
end

local function getMainPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    for _, child in pairs(model:GetChildren()) do
        if child:IsA("BasePart") then return child end
    end
    return nil
end

local function isGrenadeModel(obj)
    if not obj:IsA("Model") then return false end
    local name = obj.Name:lower()
    return name:find("grenade") or name:find("frag")
end

local function createESP(model)
    if not GrenadeESPEnabled then return end
    
    local mainPart = getMainPart(model)
    if not mainPart or grenadeESP[model] then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GrenadeESP"
    billboard.Size = UDim2.new(0, 200, 0, 30)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Adornee = mainPart
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Enabled = false
    billboard.Parent = mainPart

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextSize = 14
    label.Font = Enum.Font.SourceSansBold
    label.TextColor3 = features.visuals.grenade.color
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Text = "GRENADE"
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = billboard

    grenadeESP[model] = {
        Billboard = billboard,
        MainPart = mainPart,
        LastUpdate = 0
    }

    model.Destroying:Connect(function()
        if grenadeESP[model] and grenadeESP[model].Billboard then
            grenadeESP[model].Billboard:Destroy()
            grenadeESP[model] = nil
        end
    end)
end

local function updateESP()
    if not GrenadeESPEnabled then return end
    
    local currentTime = os.clock()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    for model, esp in pairs(grenadeESP) do
        if currentTime - esp.LastUpdate > ESP_UPDATE_INTERVAL then
            esp.LastUpdate = currentTime
            
            if model.Parent and esp.MainPart.Parent then
                if rootPart then
                    local distance = (esp.MainPart.Position - rootPart.Position).Magnitude
                    esp.Billboard.Enabled = distance <= MAX_DISTANCE
                    if esp.Billboard:FindFirstChild("Label") then
                        esp.Billboard.Label.TextColor3 = features.visuals.grenade.color
                    end
                end
            else
                if esp.Billboard then esp.Billboard:Destroy() end
                grenadeESP[model] = nil
            end
        end
    end
end

local function setupGrenadeESP()
    for model, esp in pairs(grenadeESP) do
        if esp.Billboard then esp.Billboard:Destroy() end
    end
    grenadeESP = {}

    if not GrenadeESPEnabled then return end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isGrenadeModel(obj) then createESP(obj) end
    end

    Workspace.DescendantAdded:Connect(function(obj)
        if isGrenadeModel(obj) then createESP(obj) end
    end)
end

local function createVehicleESP(chassis)
    local vehicleESP = Drawing.new("Text")
    vehicleESP.Visible = false
    vehicleESP.Center = true
    vehicleESP.Outline = true
    vehicleESP.OutlineColor = Color3.new(0, 0, 0)
    vehicleESP.Font = 2
    vehicleESP.Color = features.visuals.vehicle.color
    vehicleESP.Size = 14

    vehicleESPObjects[chassis] = vehicleESP
    return vehicleESP
end

local function updateVehicleESP()
    if not VehicleESPEnabled or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local playerPos = LocalPlayer.Character.HumanoidRootPart.Position
    
    for chassis, vehicleESP in pairs(vehicleESPObjects) do
        if chassis and chassis:IsDescendantOf(workspace) then
            local pos = chassis.Position
            local screenPos, onScreen = camera:WorldToViewportPoint(pos)

            if onScreen then
                local distance = (pos - playerPos).Magnitude
                vehicleESP.Position = Vector2.new(screenPos.X, screenPos.Y)
                vehicleESP.Text = features.visuals.distance.enabled and string.format("(Car) %d studs", math.floor(distance)) or "🚗 Vehicle"
                vehicleESP.Visible = true
            else
                vehicleESP.Visible = false
            end
        else
            vehicleESP.Visible = false
        end
    end
end

local function refreshVehicles()
    for chassis, esp in pairs(vehicleESPObjects) do
        if not chassis or not chassis:IsDescendantOf(workspace) then
            esp:Remove()
            vehicleESPObjects[chassis] = nil
        end
    end
    
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Chassis") then
            if not vehicleESPObjects[model.Chassis] then
                createVehicleESP(model.Chassis)
            end
        end
    end
end

local function initializeVehicleESP()
    activeConnections.render = RunService.RenderStepped:Connect(updateVehicleESP)
    activeConnections.heartbeat = RunService.Heartbeat:Connect(refreshVehicles)
    
    activeConnections.added = workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") and child:FindFirstChild("Chassis") then
            createVehicleESP(child.Chassis)
        end
    end)
    
    refreshVehicles()
end

local function cleanupVehicleESP()
    for _, connection in pairs(activeConnections) do
        connection:Disconnect()
    end
    
    for _, esp in pairs(vehicleESPObjects) do
        esp:Remove()
    end
    
    vehicleESPObjects = {}
    activeConnections = {}
end

local DetectionCircle = Drawing.new("Circle")
DetectionCircle.Visible = false
DetectionCircle.Color = Color3.new(1, 1, 1)
DetectionCircle.Thickness = 1
DetectionCircle.Radius = CircleRadius
DetectionCircle.Filled = false
DetectionCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

local InventoryGUI = Instance.new("ScreenGui")
InventoryGUI.Name = "PlayerInventoryGUI"
InventoryGUI.ResetOnSpawn = false
InventoryGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
InventoryGUI.Parent = LocalPlayer:WaitForChild("PlayerGui")

local InventoryFrame = Instance.new("Frame")
InventoryFrame.Name = "InventoryFrame"
InventoryFrame.BackgroundColor3 = Color3.fromRGB(48, 3, 85)
InventoryFrame.BackgroundTransparency = 0.7
InventoryFrame.BorderSizePixel = 0
InventoryFrame.Size = UDim2.new(0, 220, 0, 180)
InventoryFrame.Position = UDim2.new(1, -230, 1, -190)
InventoryFrame.AnchorPoint = Vector2.new(1, 1)
InventoryFrame.Visible = false
InventoryFrame.Parent = InventoryGUI

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = InventoryFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Text = "Player Inventory"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 5)
Title.Parent = InventoryFrame

local ItemsFrame = Instance.new("ScrollingFrame")
ItemsFrame.Name = "ItemsFrame"
ItemsFrame.BackgroundTransparency = 1
ItemsFrame.Size = UDim2.new(1, -10, 1, -40)
ItemsFrame.Position = UDim2.new(0, 5, 0, 35)
ItemsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ItemsFrame.ScrollBarThickness = 5
ItemsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y 
ItemsFrame.Parent = InventoryFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ItemsFrame
UIListLayout.Padding = UDim.new(0, 5)

local function GetPlayerInventory(player)
    local inventoryNames = {"GunInventory", "Weapons", "InventorySystem", "PlayerGuns"}
    
    for _, name in pairs(inventoryNames) do
        local inventory = player:FindFirstChild(name)
        if inventory then
            local slots = {}
            for _, child in pairs(inventory:GetChildren()) do
                if child:IsA("ObjectValue") and child.Value ~= nil then
                    table.insert(slots, child.Value.Name)
                end
            end
            
            table.sort(slots, function(a, b)
                local numA = tonumber(a:match("%d+")) or 0
                local numB = tonumber(b:match("%d+")) or 0
                return numA < numB
            end)
            
            return slots
        end
    end
    return nil
end

local function UpdateInventoryGUI(player)
    for _, child in ipairs(ItemsFrame:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end

    local inventory = GetPlayerInventory(player)
    if not inventory or #inventory == 0 then
        InventoryFrame.Visible = false
        return
    end

    Title.Text = player.Name .. "'s Inventory"

    for i, item in ipairs(inventory) do
        local itemLabel = Instance.new("TextLabel")
        itemLabel.Name = "Item_"..i
        itemLabel.Text = string.format("Slot %d: %s", i, item)
        itemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        itemLabel.TextSize = 14
        itemLabel.Font = Enum.Font.Gotham
        itemLabel.BackgroundTransparency = 1
        itemLabel.Size = UDim2.new(1, -5, 0, 22)
        itemLabel.TextXAlignment = Enum.TextXAlignment.Left
        itemLabel.Parent = ItemsFrame
    end

    InventoryFrame.Visible = true
end

local function CheckPlayersInRadius()
    local center = DetectionCircle.Position
    local closestPlayer = nil
    local closestDistance = CircleRadius

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head") or 
                         player.Character:FindFirstChild("HumanoidRootPart") or
                         player.Character:FindFirstChild("Torso") or
                         player.Character:FindFirstChildWhichIsA("BasePart")
            
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end

    if closestPlayer then
        UpdateInventoryGUI(closestPlayer)
    else
        InventoryFrame.Visible = false
    end
end

local function ClearContent()
    for _, child in ipairs(contentFrame:GetChildren()) do
        child:Destroy()
    end
end

local function CreateColorPicker(parent, position, currentColor, callback)
    local colorFrame = Instance.new("Frame")
    colorFrame.BackgroundTransparency = 1
    colorFrame.Size = UDim2.new(0, 100, 0, 30)
    colorFrame.Position = position
    colorFrame.Parent = parent

    local colorButton = Instance.new("TextButton")
    colorButton.Size = UDim2.new(0, 80, 0, 25)
    colorButton.BackgroundColor3 = currentColor
    colorButton.Text = "Color"
    colorButton.TextColor3 = Color3.new(1, 1, 1)
    colorButton.Font = Enum.Font.Gotham
    colorButton.TextSize = 12
    colorButton.Parent = colorFrame

    local colorPicker = nil
    local isPickerOpen = false

    colorButton.MouseButton1Click:Connect(function()
        if isPickerOpen then
            if colorPicker then
                colorPicker:Destroy()
                colorPicker = nil
            end
            isPickerOpen = false
            return
        end

        isPickerOpen = true
        colorPicker = Instance.new("Frame")
        colorPicker.Name = "ColorPicker"
        colorPicker.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        colorPicker.BorderSizePixel = 0
        colorPicker.Size = UDim2.new(0, 200, 0, 200)
        colorPicker.Position = UDim2.new(1, 5, 0, 0)
        colorPicker.ZIndex = 100 
        colorPicker.Parent = colorButton

        local hueMap = Instance.new("ImageButton")
        hueMap.Size = UDim2.new(0, 180, 0, 180)
        hueMap.Position = UDim2.new(0, 10, 0, 10)
        hueMap.Image = "rbxassetid://126680563510447"
        hueMap.ZIndex = 101
        hueMap.Parent = colorPicker

        local function updateColor()
            colorButton.BackgroundColor3 = currentColor
            callback(currentColor)
        end

        hueMap.MouseButton1Down:Connect(function()
            local mousePos = UserInputService:GetMouseLocation()
            local mapPos = hueMap.AbsolutePosition
            local mapSize = hueMap.AbsoluteSize
            
            local x = math.clamp((mousePos.X - mapPos.X) / mapSize.X, 0, 1)
            local y = math.clamp((mousePos.Y - mapPos.Y) / mapSize.Y, 0, 1)
            
            local h = x
            local s = 1 - y
            local v = 1
            
            currentColor = Color3.fromHSV(h, s, v)
            updateColor()
        end)

        local closeConnection
        closeConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mousePos = UserInputService:GetMouseLocation()
                if not colorPicker or not colorPicker:IsDescendantOf(game) then
                    if closeConnection then closeConnection:Disconnect() end
                    return
                end
                
                local pickerPos = colorPicker.AbsolutePosition
                local pickerSize = colorPicker.AbsoluteSize
                
                if mousePos.X < pickerPos.X or mousePos.X > pickerPos.X + pickerSize.X or
                   mousePos.Y < pickerPos.Y or mousePos.Y > pickerPos.Y + pickerSize.Y then
                    colorPicker:Destroy()
                    colorPicker = nil
                    isPickerOpen = false
                    if closeConnection then closeConnection:Disconnect() end
                end
            end
        end)

        colorPicker.Destroying:Connect(function()
            isPickerOpen = false
            if closeConnection then closeConnection:Disconnect() end
        end)
    end)

    return colorButton
end

local function CreateAimbotControls()
    ClearContent()
    
    local container = Instance.new("Frame")
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 1, 0)
    container.Parent = contentFrame

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Text = "Aimbot Configuration"
    headerLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    headerLabel.TextSize = 18
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.BackgroundTransparency = 1
    headerLabel.Size = UDim2.new(1, -20, 0, 30)
    headerLabel.Position = UDim2.new(0, 10, 0, 10)
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Parent = container

    local toggleFrame = Instance.new("Frame")
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Size = UDim2.new(1, -20, 0, 30)
    toggleFrame.Position = UDim2.new(0, 10, 0, 50)
    toggleFrame.Parent = container

    local checkBox = Instance.new("TextButton")
    checkBox.Size = UDim2.new(0, 20, 0, 20)
    checkBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    checkBox.BorderSizePixel = 0
    checkBox.Text = ""
    checkBox.Parent = toggleFrame

    checkMark = Instance.new("TextLabel")
    checkMark.Text = "✓"
    checkMark.TextColor3 = OriginalCircleColor
    checkMark.TextSize = 18
    checkMark.BackgroundTransparency = 1
    checkMark.Size = UDim2.new(1, 0, 1, 0)
    checkMark.Visible = AimingEnabled
    checkMark.Parent = checkBox

    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Text = "Aimbot"
    toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleLabel.TextSize = 14
    toggleLabel.Font = Enum.Font.Gotham
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Position = UDim2.new(0, 30, 0, 0)
    toggleLabel.Size = UDim2.new(0, 100, 1, 0)
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    toggleLabel.Parent = toggleFrame

    local keybindFrame = Instance.new("Frame")
    keybindFrame.BackgroundTransparency = 1
    keybindFrame.Size = UDim2.new(1, -20, 0, 30)
    keybindFrame.Position = UDim2.new(0, 10, 0, 100)
    keybindFrame.Parent = container

    local keybindButton = Instance.new("TextButton")
    keybindButton.Size = UDim2.new(0.5, 0, 1, 0)
    keybindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    keybindButton.Text = "Bind Key: " .. tostring(currentKey):gsub("Enum%.KeyCode%.", "")
    keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindButton.TextSize = 14
    keybindButton.Font = Enum.Font.Gotham
    keybindButton.Parent = keybindFrame

    local sliderFrame = Instance.new("Frame")
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Size = UDim2.new(1, -20, 0, 60)
    sliderFrame.Position = UDim2.new(0, 10, 0, 150)
    sliderFrame.Parent = container

    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Text = "Aimbot Radius: " .. math.floor(CircleRadius)
    sliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sliderLabel.TextSize = 14
    sliderLabel.Font = Enum.Font.Gotham
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Size = UDim2.new(1, 0, 0, 20)
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    sliderLabel.Parent = sliderFrame

    local sliderTrack = Instance.new("Frame")
    sliderTrack.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    sliderTrack.BorderSizePixel = 0
    sliderTrack.Size = UDim2.new(1, -10, 0, 4)
    sliderTrack.Position = UDim2.new(0, 5, 0, 35)
    sliderTrack.Parent = sliderFrame

    local sliderThumb = Instance.new("TextButton")
    sliderThumb.Size = UDim2.new(0, 16, 0, 16)
    sliderThumb.BackgroundColor3 = OriginalCircleColor
    sliderThumb.BorderSizePixel = 0
    sliderThumb.Text = ""
    sliderThumb.Position = UDim2.new((CircleRadius - 50)/250, -8, 0, 28)
    sliderThumb.Parent = sliderFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = sliderThumb

    local sliding = false
    local minRadius = 50
    local maxRadius = 300

    local function UpdateRadius(value)
        CircleRadius = math.clamp(value, minRadius, maxRadius)
        sliderLabel.Text = "Aimbot Radius: " .. math.floor(CircleRadius)
        local ratio = (CircleRadius - minRadius) / (maxRadius - minRadius)
        sliderThumb.Position = UDim2.new(ratio, -8, 0, 28)
    end

    sliderThumb.MouseButton1Down:Connect(function()
        sliding = true
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)

    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            local absoluteX = input.Position.X - sliderTrack.AbsolutePosition.X
            local ratio = math.clamp(absoluteX / sliderTrack.AbsoluteSize.X, 0, 1)
            UpdateRadius(minRadius + ratio * (maxRadius - minRadius))
        end
    end)

    sliderThumb.MouseMoved:Connect(function(x)
        if sliding then
            local absoluteX = x - sliderTrack.AbsolutePosition.X
            local ratio = math.clamp(absoluteX / sliderTrack.AbsoluteSize.X, 0, 1)
            UpdateRadius(minRadius + ratio * (maxRadius - minRadius))
        end
    end)

    checkBox.MouseButton1Click:Connect(function()
        AimingEnabled = not AimingEnabled
        CircleVisible = AimingEnabled
        Circle.Visible = CircleVisible
        checkMark.Visible = AimingEnabled
        if TargetLine then
            TargetLine.Visible = AimingEnabled
        end
    end)

    keybindButton.MouseButton1Click:Connect(function()
        if not listening then
            listening = true
            keybindButton.Text = "Press any key..."
            keybindButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
            
            local connection
            connection = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    currentKey = input.KeyCode
                    keybindButton.Text = "Bind Key: " .. tostring(currentKey):gsub("Enum%.KeyCode%.", "")
                    listening = false
                    keybindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                    connection:Disconnect()
                end
            end)
        end
    end)
end

local function CreateVisualControls()
    ClearContent()
    
    local container = Instance.new("Frame")
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 1, 0)
    container.Parent = contentFrame

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Text = "Visual Settings"
    headerLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    headerLabel.TextSize = 18
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.BackgroundTransparency = 1
    headerLabel.Size = UDim2.new(1, -20, 0, 30)
    headerLabel.Position = UDim2.new(0, 10, 0, 10)
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Parent = container

    local grenadeFrame = Instance.new("Frame")
    grenadeFrame.BackgroundTransparency = 1
    grenadeFrame.Size = UDim2.new(1, -20, 0, 30)
    grenadeFrame.Position = UDim2.new(0, 10, 0, 50)
    grenadeFrame.Parent = container

    local grenadeCheckBox = Instance.new("TextButton")
    grenadeCheckBox.Size = UDim2.new(0, 20, 0, 20)
    grenadeCheckBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    grenadeCheckBox.BorderSizePixel = 0
    grenadeCheckBox.Text = ""
    grenadeCheckBox.Parent = grenadeFrame

    grenadeCheckMark = Instance.new("TextLabel")
    grenadeCheckMark.Text = "✓"
    grenadeCheckMark.TextColor3 = OriginalCircleColor
    grenadeCheckMark.TextSize = 18
    grenadeCheckMark.BackgroundTransparency = 1
    grenadeCheckMark.Size = UDim2.new(1, 0, 1, 0)
    grenadeCheckMark.Visible = GrenadeESPEnabled
    grenadeCheckMark.Parent = grenadeCheckBox

    local grenadeLabel = Instance.new("TextLabel")
    grenadeLabel.Text = "Grenade ESP"
    grenadeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    grenadeLabel.TextSize = 14
    grenadeLabel.Font = Enum.Font.Gotham
    grenadeLabel.BackgroundTransparency = 1
    grenadeLabel.Position = UDim2.new(0, 30, 0, 0)
    grenadeLabel.Size = UDim2.new(0, 100, 1, 0)
    grenadeLabel.TextXAlignment = Enum.TextXAlignment.Left
    grenadeLabel.Parent = grenadeFrame

    local grenadeColorButton = CreateColorPicker(grenadeFrame, UDim2.new(0, 140, 0, 0), features.visuals.grenade.color, function(color)
        features.visuals.grenade.color = color
        grenadeCheckMark.TextColor3 = OriginalCircleColor
        
        for model, esp in pairs(grenadeESP) do
            if esp.Billboard and esp.Billboard:FindFirstChild("Label") then
                esp.Billboard.Label.TextColor3 = color
            end
        end
    end)


    local separator1 = Instance.new("Frame")
    separator1.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    separator1.BorderSizePixel = 0
    separator1.Position = UDim2.new(0, 10, 0, 90)
    separator1.Size = UDim2.new(1, -20, 0, 1)
    separator1.Parent = container


    local vehicleFrame = Instance.new("Frame")
    vehicleFrame.BackgroundTransparency = 1
    vehicleFrame.Size = UDim2.new(1, -20, 0, 30)
    vehicleFrame.Position = UDim2.new(0, 10, 0, 100)
    vehicleFrame.Parent = container

    local vehicleCheckBox = Instance.new("TextButton")
    vehicleCheckBox.Size = UDim2.new(0, 20, 0, 20)
    vehicleCheckBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    vehicleCheckBox.BorderSizePixel = 0
    vehicleCheckBox.Text = ""
    vehicleCheckBox.Parent = vehicleFrame

    vehicleCheckMark = Instance.new("TextLabel")
    vehicleCheckMark.Text = "✓"
    vehicleCheckMark.TextColor3 = OriginalCircleColor
    vehicleCheckMark.TextSize = 18
    vehicleCheckMark.BackgroundTransparency = 1
    vehicleCheckMark.Size = UDim2.new(1, 0, 1, 0)
    vehicleCheckMark.Visible = VehicleESPEnabled
    vehicleCheckMark.Parent = vehicleCheckBox

    local vehicleLabel = Instance.new("TextLabel")
    vehicleLabel.Text = "Vehicle ESP"
    vehicleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    vehicleLabel.TextSize = 14
    vehicleLabel.Font = Enum.Font.Gotham
    vehicleLabel.BackgroundTransparency = 1
    vehicleLabel.Position = UDim2.new(0, 30, 0, 0)
    vehicleLabel.Size = UDim2.new(0, 100, 1, 0)
    vehicleLabel.TextXAlignment = Enum.TextXAlignment.Left
    vehicleLabel.Parent = vehicleFrame

    local vehicleColorButton = CreateColorPicker(vehicleFrame, UDim2.new(0, 140, 0, 0), features.visuals.vehicle.color, function(color)
        features.visuals.vehicle.color = color
        vehicleCheckMark.TextColor3 = OriginalCircleColor
        
        for _, esp in pairs(vehicleESPObjects) do
            esp.Color = color
        end
    end)

    local separator2 = Instance.new("Frame")
    separator2.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    separator2.BorderSizePixel = 0
    separator2.Position = UDim2.new(0, 10, 0, 140)
    separator2.Size = UDim2.new(1, -20, 0, 1)
    separator2.Parent = container

    local namesFrame = Instance.new("Frame")
    namesFrame.BackgroundTransparency = 1
    namesFrame.Size = UDim2.new(1, -20, 0, 30)
    namesFrame.Position = UDim2.new(0, 10, 0, 150)
    namesFrame.Parent = container

    local namesCheckBox = Instance.new("TextButton")
    namesCheckBox.Size = UDim2.new(0, 20, 0, 20)
    namesCheckBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    namesCheckBox.BorderSizePixel = 0
    namesCheckBox.Text = ""
    namesCheckBox.Parent = namesFrame

    namesCheckMark = Instance.new("TextLabel")
    namesCheckMark.Text = "✓"
    namesCheckMark.TextColor3 = OriginalCircleColor
    namesCheckMark.TextSize = 18
    namesCheckMark.BackgroundTransparency = 1
    namesCheckMark.Size = UDim2.new(1, 0, 1, 0)
    namesCheckMark.Visible = features.visuals.names.enabled
    namesCheckMark.Parent = namesCheckBox

    local namesLabel = Instance.new("TextLabel")
    namesLabel.Text = "Player Names"
    namesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    namesLabel.TextSize = 14
    namesLabel.Font = Enum.Font.Gotham
    namesLabel.BackgroundTransparency = 1
    namesLabel.Position = UDim2.new(0, 30, 0, 0)
    namesLabel.Size = UDim2.new(0, 100, 1, 0)
    namesLabel.TextXAlignment = Enum.TextXAlignment.Left
    namesLabel.Parent = namesFrame

    local boxesFrame = Instance.new("Frame")
    boxesFrame.BackgroundTransparency = 1
    boxesFrame.Size = UDim2.new(1, -20, 0, 30)
    boxesFrame.Position = UDim2.new(0, 10, 0, 190)
    boxesFrame.Parent = container

    local boxesCheckBox = Instance.new("TextButton")
    boxesCheckBox.Size = UDim2.new(0, 20, 0, 20)
    boxesCheckBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    boxesCheckBox.BorderSizePixel = 0
    boxesCheckBox.Text = ""
    boxesCheckBox.Parent = boxesFrame

    boxesCheckMark = Instance.new("TextLabel")
    boxesCheckMark.Text = "✓"
    boxesCheckMark.TextColor3 = OriginalCircleColor
    boxesCheckMark.TextSize = 18
    boxesCheckMark.BackgroundTransparency = 1
    boxesCheckMark.Size = UDim2.new(1, 0, 1, 0)
    boxesCheckMark.Visible = features.visuals.boxes.enabled
    boxesCheckMark.Parent = boxesCheckBox

    local boxesLabel = Instance.new("TextLabel")
    boxesLabel.Text = "Player Boxes"
    boxesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    boxesLabel.TextSize = 14
    boxesLabel.Font = Enum.Font.Gotham
    boxesLabel.BackgroundTransparency = 1
    boxesLabel.Position = UDim2.new(0, 30, 0, 0)
    boxesLabel.Size = UDim2.new(0, 100, 1, 0)
    boxesLabel.TextXAlignment = Enum.TextXAlignment.Left
    boxesLabel.Parent = boxesFrame

    local distanceFrame = Instance.new("Frame")
    distanceFrame.BackgroundTransparency = 1
    distanceFrame.Size = UDim2.new(1, -20, 0, 30)
    distanceFrame.Position = UDim2.new(0, 10, 0, 230)
    distanceFrame.Parent = container

    local distanceCheckBox = Instance.new("TextButton")
    distanceCheckBox.Size = UDim2.new(0, 20, 0, 20)
    distanceCheckBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    distanceCheckBox.BorderSizePixel = 0
    distanceCheckBox.Text = ""
    distanceCheckBox.Parent = distanceFrame

    distanceCheckMark = Instance.new("TextLabel")
    distanceCheckMark.Text = "✓"
    distanceCheckMark.TextColor3 = OriginalCircleColor
    distanceCheckMark.TextSize = 18
    distanceCheckMark.BackgroundTransparency = 1
    distanceCheckMark.Size = UDim2.new(1, 0, 1, 0)
    distanceCheckMark.Visible = features.visuals.distance.enabled
    distanceCheckMark.Parent = distanceCheckBox

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Text = "Player Distance"
    distanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distanceLabel.TextSize = 14
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Position = UDim2.new(0, 30, 0, 0)
    distanceLabel.Size = UDim2.new(0, 100, 1, 0)
    distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    distanceLabel.Parent = distanceFrame

    grenadeCheckBox.MouseButton1Click:Connect(function()
        GrenadeESPEnabled = not GrenadeESPEnabled
        grenadeCheckMark.Visible = GrenadeESPEnabled
        setupGrenadeESP()
    end)

    vehicleCheckBox.MouseButton1Click:Connect(function()
        VehicleESPEnabled = not VehicleESPEnabled
        vehicleCheckMark.Visible = VehicleESPEnabled
        if VehicleESPEnabled then
            initializeVehicleESP()
        else
            cleanupVehicleESP()
        end
    end)

    namesCheckBox.MouseButton1Click:Connect(function()
        features.visuals.names.enabled = not features.visuals.names.enabled
        namesCheckMark.Visible = features.visuals.names.enabled
    end)

    boxesCheckBox.MouseButton1Click:Connect(function()
        features.visuals.boxes.enabled = not features.visuals.boxes.enabled
        boxesCheckMark.Visible = features.visuals.boxes.enabled
    end)

    distanceCheckBox.MouseButton1Click:Connect(function()
        features.visuals.distance.enabled = not features.visuals.distance.enabled
        distanceCheckMark.Visible = features.visuals.distance.enabled
    end)
end

local gasMaskConnection = nil
local function hideEffects()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local BackgroundUI = PlayerGui:FindFirstChild("GameUI") and PlayerGui.GameUI:FindFirstChild("BackgroundUI")
    
    if BackgroundUI then
        for _, effect in ipairs(BackgroundUI:GetChildren()) do
            if effect.Name == "GasMaskUI" then
                effect.Vignette.ImageTransparency = 1
            end
        end
    end
end

local AltynUIEnabled = false
local LootCheckerEnabled = false

local function CreateMiscControls()
    ClearContent()
    
    local container = Instance.new("Frame")
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 1, 0)
    container.Parent = contentFrame

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Text = "Miscellaneous Settings"
    headerLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    headerLabel.TextSize = 18
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.BackgroundTransparency = 1
    headerLabel.Size = UDim2.new(1, -20, 0, 30)
    headerLabel.Position = UDim2.new(0, 10, 0, 10)
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Parent = container

    local gasMaskFrame = Instance.new("Frame")
    gasMaskFrame.BackgroundTransparency = 1
    gasMaskFrame.Size = UDim2.new(1, -20, 0, 30)
    gasMaskFrame.Position = UDim2.new(0, 10, 0, 50)
    gasMaskFrame.Parent = container

    local gasMaskCheckBox = Instance.new("TextButton")
    gasMaskCheckBox.Size = UDim2.new(0, 20, 0, 20)
    gasMaskCheckBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    gasMaskCheckBox.BorderSizePixel = 0
    gasMaskCheckBox.Text = ""
    gasMaskCheckBox.Parent = gasMaskFrame

    local miscCheckMark = Instance.new("TextLabel")
    miscCheckMark.Text = "✓"
    miscCheckMark.TextColor3 = OriginalCircleColor
    miscCheckMark.TextSize = 18
    miscCheckMark.BackgroundTransparency = 1
    miscCheckMark.Size = UDim2.new(1, 0, 1, 0)
    miscCheckMark.Visible = AltynUIEnabled
    miscCheckMark.Parent = gasMaskCheckBox

    local gasMaskLabel = Instance.new("TextLabel")
    gasMaskLabel.Text = "Remove Altyn UI"
    gasMaskLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    gasMaskLabel.TextSize = 14
    gasMaskLabel.Font = Enum.Font.Gotham
    gasMaskLabel.BackgroundTransparency = 1
    gasMaskLabel.Position = UDim2.new(0, 30, 0, 0)
    gasMaskLabel.Size = UDim2.new(0, 150, 1, 0)
    gasMaskLabel.TextXAlignment = Enum.TextXAlignment.Left
    gasMaskLabel.Parent = gasMaskFrame

    local separator1 = Instance.new("Frame")
    separator1.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    separator1.BorderSizePixel = 0
    separator1.Position = UDim2.new(0, 10, 0, 90)
    separator1.Size = UDim2.new(1, -20, 0, 1)
    separator1.Parent = container

    local lootFrame = Instance.new("Frame")
    lootFrame.BackgroundTransparency = 1
    lootFrame.Size = UDim2.new(1, -20, 0, 30)
    lootFrame.Position = UDim2.new(0, 10, 0, 100)
    lootFrame.Parent = container

    local lootCheckBox = Instance.new("TextButton")
    lootCheckBox.Size = UDim2.new(0, 20, 0, 20)
    lootCheckBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    lootCheckBox.BorderSizePixel = 0
    lootCheckBox.Text = ""
    lootCheckBox.Parent = lootFrame

    lootCheckMark = Instance.new("TextLabel")
    lootCheckMark.Text = "✓"
    lootCheckMark.TextColor3 = OriginalCircleColor
    lootCheckMark.TextSize = 18
    lootCheckMark.BackgroundTransparency = 1
    lootCheckMark.Size = UDim2.new(1, 0, 1, 0)
    lootCheckMark.Visible = LootCheckerEnabled
    lootCheckMark.Parent = lootCheckBox

    local lootLabel = Instance.new("TextLabel")
    lootLabel.Text = "Checker Loot"
    lootLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    lootLabel.TextSize = 14
    lootLabel.Font = Enum.Font.Gotham
    lootLabel.BackgroundTransparency = 1
    lootLabel.Position = UDim2.new(0, 30, 0, 0)
    lootLabel.Size = UDim2.new(0, 150, 1, 0)
    lootLabel.TextXAlignment = Enum.TextXAlignment.Left
    lootLabel.Parent = lootFrame

    gasMaskCheckBox.MouseButton1Click:Connect(function()
        AltynUIEnabled = not AltynUIEnabled
        miscCheckMark.Visible = AltynUIEnabled
        
        if AltynUIEnabled then
            hideEffects()
            gasMaskConnection = LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
                if child.Name == "GameUI" then
                    child:WaitForChild("BackgroundUI")
                    hideEffects()
                end
            end)
        else
            if gasMaskConnection then
                gasMaskConnection:Disconnect()
                gasMaskConnection = nil
            end

            local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
            local BackgroundUI = PlayerGui:FindFirstChild("GameUI") and PlayerGui.GameUI:FindFirstChild("BackgroundUI")
            if BackgroundUI then
                for _, effect in ipairs(BackgroundUI:GetChildren()) do
                    if effect.Name == "GasMaskUI" then
                        effect.Vignette.ImageTransparency = 0
                    end
                end
            end
        end
    end)

    lootCheckBox.MouseButton1Click:Connect(function()
        LootCheckerEnabled = not LootCheckerEnabled
        lootCheckMark.Visible = LootCheckerEnabled
        InventoryFrame.Visible = LootCheckerEnabled
    end)
end

local function CreateGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "RetrigGUI"
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 100
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BorderColor3 = Color3.fromRGB(60, 60, 80)
    mainFrame.BorderSizePixel = 2
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 400, 0, 600)
    mainFrame.Visible = true
    mainFrame.Parent = gui

    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    topBar.BorderSizePixel = 0
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "RetriG: V2 [STOLEN SOURCE PUBLISHED BY KYSS]\n https://github.com/slavalavaparmedzhan0/Retrig-opensource/blob/main/RetriG-source.lua"
    titleLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(0.9, 0, 0.8, 0)
    titleLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.Parent = topBar

    local buttonContainer = Instance.new("Frame")
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Position = UDim2.new(0, 15, 0, 35)
    buttonContainer.Size = UDim2.new(1, -30, 0, 40)
    buttonContainer.Parent = mainFrame

    local buttonNames = {"Exploits", "Visual", "Misc", "Info"}
    
    for i = 1, 4 do
        local button = Instance.new("TextButton")
        button.Name = buttonNames[i]
        button.Text = buttonNames[i]
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 13
        button.Font = Enum.Font.Gotham
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        button.BorderSizePixel = 0
        
        local buttonWidth = (buttonContainer.AbsoluteSize.X - 24) / 4
        button.Position = UDim2.new(0, (i-1)*(buttonWidth + 8), 0, 0)
        button.Size = UDim2.new(0, buttonWidth, 1, 0)
        button.Parent = buttonContainer

        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {
                Size = UDim2.new(0, buttonWidth + 10, 1.1, 0),
                Position = UDim2.new(0, (i-1)*(buttonWidth + 8) - 5, 0, -3),
                BackgroundColor3 = Color3.fromRGB(80, 80, 100)
            }):Play()
        end)
        
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {
                Size = UDim2.new(0, buttonWidth, 1, 0),
                Position = UDim2.new(0, (i-1)*(buttonWidth + 8), 0, 0),
                BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            }):Play()
        end)
        
        button.MouseButton1Click:Connect(function()
            if buttonNames[i] == "Exploits" then
                CreateAimbotControls()
            elseif buttonNames[i] == "Visual" then
                CreateVisualControls()
            elseif buttonNames[i] == "Misc" then
                CreateMiscControls()
            else
                ClearContent()
            end
        end)
    end

    local separator = Instance.new("Frame")
    separator.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    separator.BorderSizePixel = 0
    separator.Position = UDim2.new(0, 0, 0, 80)
    separator.Size = UDim2.new(1, 0, 0, 1)
    separator.Parent = mainFrame

    contentFrame = Instance.new("Frame")
    contentFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    contentFrame.BorderSizePixel = 0
    contentFrame.Position = UDim2.new(0, 0, 0, 81)
    contentFrame.Size = UDim2.new(1, 0, 1, -81)
    contentFrame.Parent = mainFrame

    local dragging = false
    local dragStart, startPos

    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)

    mainFrame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    mainFrame.InputEnded:Connect(function()
        dragging = false
    end)
end

local function handleFocus(focused)
    if focused then
        Circle.Visible = CircleVisible
        if TargetLine then
            TargetLine.Visible = AimingEnabled and TargetPlayer ~= nil
        end
    else
        Circle.Visible = false
        if TargetLine then
            TargetLine.Visible = false
        end
    end
end

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        RightMouseButtonHeld = true
    elseif input.KeyCode == currentKey then
        AimingEnabled = not AimingEnabled
        CircleVisible = AimingEnabled
        Circle.Visible = CircleVisible
        if checkMark then checkMark.Visible = AimingEnabled end
        TargetPlayer = nil
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        RightMouseButtonHeld = false
        TargetPlayer = nil
        Circle.Color = OriginalCircleColor
    end
end)

RunService.RenderStepped:Connect(function()
    updateRainbowColor()
    
    Circle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    Circle.Radius = CircleRadius
    BulletSpeed = getBulletSpeed()

    Circle.Color = rainbowColor


    local closestDistance = math.huge
    local currentTarget = nil
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head") or 
                         player.Character:FindFirstChild("ServerColliderHead")
            
            if head and head:IsA("BasePart") then
                local screenPos = Camera:WorldToViewportPoint(head.Position)
                
                if screenPos.Z > 0 then
                    local center = Circle.Position
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    
                    if distance < CircleRadius and distance < closestDistance then
                        closestDistance = distance
                        currentTarget = player
                    end
                end
            end
        end
    end
    
    TargetPlayer = currentTarget

    if TargetPlayer and AimingEnabled then
        if not TargetLine then
            initializeAimbotDrawings()
        end
        
        local head = TargetPlayer.Character:FindFirstChild("Head") or 
                     TargetPlayer.Character:FindFirstChild("ServerColliderHead")
        if head then
            local targetScreenPos = Camera:WorldToViewportPoint(head.Position)
            if targetScreenPos.Z > 0 then
                TargetLine.From = Circle.Position
                TargetLine.To = Vector2.new(targetScreenPos.X, targetScreenPos.Y)
                TargetLine.Visible = true
                TargetLine.Color = rainbowColor
            else
                TargetLine.Visible = false
            end
        end
        
        if RightMouseButtonHeld then
            aimAtTarget()
        end
    elseif TargetLine then
        TargetLine.Visible = false
    end
    
    if LootCheckerEnabled then
        CheckPlayersInRadius()
    end
end)

spawn(function()
    while true do
        updateESP()
        wait(ESP_UPDATE_INTERVAL)
    end
end)

local function setupPlayer(player)
    player.CharacterAdded:Connect(function(character)
        wait(1)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        setupPlayer(player)
    end
end

Players.PlayerAdded:Connect(setupPlayer)


initializeAimbotDrawings()
UserInputService.WindowFocused:Connect(handleFocus)
UserInputService.WindowFocusReleased:Connect(function()
    handleFocus(false)
end)

CreateGUI()
CreateAimbotControls()
setupGrenadeESP()
initializeVehicleESP()
