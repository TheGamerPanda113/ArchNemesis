--[[
    Client-Side Combat Assistant System (Universal Compatibility)
    Features: High-Strength Target Lock-On & Automated Clicking
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local isFeatureEnabled = true
local lockStrength = 0.6
local reactionTime = 0.15
local autoClickButton = "LMB"
local currentTarget = nil
local lastTarget = nil
local targetAcquiredTime = 0.0
local isClicking = false
local menuVisible = true
local MAX_RAY_DISTANCE = 600
local MAX_LOCK_ANGLE_DEG = 45
local CLICK_INTERVAL = 0.05 

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function getTargetParts(character)
	return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

local function isValidTarget(character)
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local targetPart = getTargetParts(character)
	
	if humanoid and humanoid.Health > 0 and targetPart then
		return true
	end
	return false
end

local function isWithinLockAngle(targetPosition)
	local camCFrame = camera.CFrame
	local toTarget = (targetPosition - camCFrame.Position).Unit
	local dotProduct = camCFrame.LookVector:Dot(toTarget)
	local angleRad = math.acos(math.clamp(dotProduct, -1, 1))
	return math.deg(angleRad) <= MAX_LOCK_ANGLE_DEG
end

local function scanForTarget()
	local viewportSize = camera.ViewportSize
	local centerRay = camera:ViewportPointToRay(viewportSize.X / 2, viewportSize.Y / 2)
	
	local excludeList = {localPlayer.Character}
	raycastParams.FilterDescendantsInstances = excludeList
	
	local raycastResult = Workspace:Raycast(centerRay.Origin, centerRay.Direction * MAX_RAY_DISTANCE, raycastParams)
	
	if raycastResult and raycastResult.Instance then
		local hitInstance = raycastResult.Instance
		local model = hitInstance:FindFirstAncestorOfClass("Model")
		
		if model and model:FindFirstChildOfClass("Humanoid") and model ~= localPlayer.Character then
			return model
		end
	end
	return nil
end

local function simulateMouseClick(button, isPressed)
	local mouseLocation = UserInputService:GetMouseLocation()
	local inputType = Enum.UserInputType.MouseButton1
	
	if button == "RMB" then
		inputType = Enum.UserInputType.MouseButton2
	elseif button == "MMB" then
		inputType = Enum.UserInputType.MouseButton3
	end
	
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(mouseLocation.X, mouseLocation.Y, inputType.Value, isPressed, game, 1)
	end)
end

local function handleAutoClicking()
	if isClicking then return end
	isClicking = true
	
	task.spawn(function()
		while isFeatureEnabled and currentTarget and autoClickButton ~= "None" and isValidTarget(currentTarget) do
			if os.clock() - targetAcquiredTime < reactionTime then
				task.wait()
				continue
			end
			
			simulateMouseClick(autoClickButton, true)
			task.wait(CLICK_INTERVAL)
			simulateMouseClick(autoClickButton, false)
			task.wait(CLICK_INTERVAL)
		end
		isClicking = false
	end)
end

local function onRenderStep(deltaTime)
	if not isFeatureEnabled then 
		currentTarget = nil
		lastTarget = nil
		return 
	end
	
	if not isValidTarget(currentTarget) then
		currentTarget = scanForTarget()
	end
	
	if currentTarget ~= lastTarget then
		if currentTarget then
			targetAcquiredTime = os.clock()
		end
		lastTarget = currentTarget
	end
	
	if currentTarget and isValidTarget(currentTarget) then
		local targetPart = getTargetParts(currentTarget)
		if targetPart then
			local targetPos = targetPart.Position
			
			if not isWithinLockAngle(targetPos) then
				currentTarget = nil
				return
			end
			
			local camCFrame = camera.CFrame
			local targetRotation = CFrame.lookAt(camCFrame.Position, targetPos)
			
			if lockStrength >= 0.95 then
				camera.CFrame = targetRotation
			else
				local alpha = math.clamp(1 - math.exp(-lockStrength * deltaTime * 25), 0, 1)
				camera.CFrame = camCFrame:Lerp(targetRotation, alpha)
			end
			
			if autoClickButton ~= "None" then
				handleAutoClicking()
			end
		end
	end
end

RunService:BindToRenderStep("CombatAssistantCamera", Enum.RenderPriority.Camera.Value + 1, onRenderStep)

local function initializeUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	
	local existingGui = playerGui:FindFirstChild("CombatAssistantGui")
	if existingGui then existingGui:Destroy() end
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CombatAssistantGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 280, 0, 310)
	mainFrame.Position = UDim2.new(0, 20, 0.5, -155)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = true
	mainFrame.Parent = screenGui
	
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = mainFrame
	
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(45, 45, 55)
	uiStroke.Thickness = 1
	uiStroke.Parent = mainFrame
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Combat System Config"
	titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.Parent = mainFrame
	
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 240, 0, 35)
	toggleBtn.Position = UDim2.new(0, 20, 0, 45)
	toggleBtn.BackgroundColor3 = isFeatureEnabled and Color3.fromRGB(46, 117, 89) or Color3.fromRGB(117, 46, 46)
	toggleBtn.Text = "System Lock: " .. (isFeatureEnabled and "ENABLED" or "DISABLED")
	toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleBtn.Font = Enum.Font.GothamMedium
	toggleBtn.TextSize = 12
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Parent = mainFrame
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = toggleBtn
	
	toggleBtn.MouseButton1Click:Connect(function()
		isFeatureEnabled = not isFeatureEnabled
		toggleBtn.Text = "System Lock: " .. (isFeatureEnabled and "ENABLED" or "DISABLED")
		TweenService:Create(toggleBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = isFeatureEnabled and Color3.fromRGB(46, 117, 89) or Color3.fromRGB(117, 46, 46)
		}):Play()
	end)
	
	local strengthLabel = Instance.new("TextLabel")
	strengthLabel.Size = UDim2.new(0, 240, 0, 20)
	strengthLabel.Position = UDim2.new(0, 20, 0, 95)
	strengthLabel.BackgroundTransparency = 1
	strengthLabel.Text = string.format("Lock Strength: %.2f", lockStrength)
	strengthLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	strengthLabel.Font = Enum.Font.Gotham
	strengthLabel.TextSize = 11
	strengthLabel.TextXAlignment = Enum.TextXAlignment.Left
	strengthLabel.Parent = mainFrame
	
	local strengthTrack = Instance.new("Frame")
	strengthTrack.Size = UDim2.new(0, 240, 0, 6)
	strengthTrack.Position = UDim2.new(0, 20, 0, 120)
	strengthTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	strengthTrack.BorderSizePixel = 0
	strengthTrack.Parent = mainFrame
	
	local strengthFill = Instance.new("Frame")
	strengthFill.Size = UDim2.new(lockStrength, 0, 1, 0)
	strengthFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	strengthFill.BorderSizePixel = 0
	strengthFill.Parent = strengthTrack
	
	local strengthThumb = Instance.new("ImageButton")
	strengthThumb.Size = UDim2.new(0, 14, 0, 14)
	strengthThumb.Position = UDim2.new(lockStrength, -7, 0.5, -7)
	strengthThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	strengthThumb.BorderSizePixel = 0
	strengthThumb.Parent = strengthTrack
	
	local strengthThumbCorner = Instance.new("UICorner")
	strengthThumbCorner.CornerRadius = UDim.new(1, 0)
	strengthThumbCorner.Parent = strengthThumb
	
	local reactionLabel = Instance.new("TextLabel")
	reactionLabel.Size = UDim2.new(0, 240, 0, 20)
	reactionLabel.Position = UDim2.new(0, 20, 0, 145)
	reactionLabel.BackgroundTransparency = 1
	reactionLabel.Text = string.format("Reaction Delay: %.2fs", reactionTime)
	reactionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	reactionLabel.Font = Enum.Font.Gotham
	reactionLabel.TextSize = 11
	reactionLabel.TextXAlignment = Enum.TextXAlignment.Left
	reactionLabel.Parent = mainFrame
	
	local reactionTrack = Instance.new("Frame")
	reactionTrack.Size = UDim2.new(0, 240, 0, 6)
	reactionTrack.Position = UDim2.new(0, 20, 0, 170)
	reactionTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	reactionTrack.BorderSizePixel = 0
	reactionTrack.Parent = mainFrame
	
	local reactionFill = Instance.new("Frame")
	local initialReactionPercentage = math.clamp(reactionTime / 0.5, 0, 1)
	reactionFill.Size = UDim2.new(initialReactionPercentage, 0, 1, 0)
	reactionFill.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
	reactionFill.BorderSizePixel = 0
	reactionFill.Parent = reactionTrack
	
	local reactionThumb = Instance.new("ImageButton")
	reactionThumb.Size = UDim2.new(0, 14, 0, 14)
	reactionThumb.Position = UDim2.new(initialReactionPercentage, -7, 0.5, -7)
	reactionThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	reactionThumb.BorderSizePixel = 0
	reactionThumb.Parent = reactionTrack
	
	local reactionThumbCorner = Instance.new("UICorner")
	reactionThumbCorner.CornerRadius = UDim.new(1, 0)
	reactionThumbCorner.Parent = reactionThumb
	
	local activeSlider = nil
	
	local function processSliderMovement(input)
		if not activeSlider then return end
		local relativeX = input.Position.X - activeSlider.AbsolutePosition.X
		local percentage = math.clamp(relativeX / activeSlider.AbsoluteSize.X, 0, 1)
		
		if activeSlider == strengthTrack then
			lockStrength = math.clamp(percentage, 0.05, 1.0)
			strengthFill.Size = UDim2.new(lockStrength, 0, 1, 0)
			strengthThumb.Position = UDim2.new(lockStrength, -7, 0.5, -7)
			strengthLabel.Text = string.format("Lock Strength: %.2f", lockStrength)
		elseif activeSlider == reactionTrack then
			reactionTime = percentage * 0.5 
			reactionFill.Size = UDim2.new(percentage, 0, 1, 0)
			reactionThumb.Position = UDim2.new(percentage, -7, 0.5, -7)
			reactionLabel.Text = string.format("Reaction Delay: %.2fs", reactionTime)
		end
	end
	
	local function connectSliderSignals(thumb, track)
		thumb.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				activeSlider = track
			end
		end)
	end
	
	connectSliderSignals(strengthThumb, strengthTrack)
	connectSliderSignals(reactionThumb, reactionTrack)
	
	UserInputService.InputChanged:Connect(function(input)
		if activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			processSliderMovement(input)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeSlider = nil
		end
	end)
	
	local clickCycleBtn = Instance.new("TextButton")
	clickCycleBtn.Size = UDim2.new(0, 240, 0, 35)
	clickCycleBtn.Position = UDim2.new(0, 20, 0, 200)
	clickCycleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	clickCycleBtn.Text = "Auto Fire Event: " .. autoClickButton
	clickCycleBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
	clickCycleBtn.Font = Enum.Font.GothamMedium
	clickCycleBtn.TextSize = 12
	clickCycleBtn.BorderSizePixel = 0
	clickCycleBtn.Parent = mainFrame
	
	local cycleCorner = Instance.new("UICorner")
	cycleCorner.CornerRadius = UDim.new(0, 6)
	cycleCorner.Parent = clickCycleBtn
	
	local buttonModes = { "LMB", "RMB", "MMB", "None" }
	clickCycleBtn.MouseButton1Click:Connect(function()
		local currentIndex = table.find(buttonModes, autoClickButton) or 1
		local nextIndex = (currentIndex % #buttonModes) + 1
		autoClickButton = buttonModes[nextIndex]
		clickCycleBtn.Text = "Auto Fire Event: " .. autoClickButton
	end)
	
	local footerLabel = Instance.new("TextLabel")
	footerLabel.Size = UDim2.new(1, 0, 0, 25)
	footerLabel.Position = UDim2.new(0, 0, 1, -25)
	footerLabel.BackgroundTransparency = 1
	footerLabel.Text = "Press [M] to Toggle Menu Visibility"
	footerLabel.TextColor3 = Color3.fromRGB(110, 110, 120)
	-- FIX APPLIED HERE: Replaced Enum.Font.GothamItalic with FontFace to keep the italic styling legally
	footerLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	footerLabel.TextSize = 10
	footerLabel.Parent = mainFrame
	
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.M then
			menuVisible = not menuVisible
			mainFrame.Visible = menuVisible
		end
	end)
end

initializeUI()