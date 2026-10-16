-- KDM 3D Toy-Block / Arcade UI Style Helper (How To Drift / Mega Pack style)
local TweenService = game:GetService("TweenService")

local StyleHelper = {}

local function findChildOfClass(inst, className)
	if type(inst) == "table" or typeof(inst) == "Instance" then
		local hasMethod = pcall(function() return inst.FindFirstChildOfClass end)
		if hasMethod and inst.FindFirstChildOfClass then
			local ok, res = pcall(function() return inst:FindFirstChildOfClass(className) end)
			if ok and res then return res end
		end
		if inst.GetChildren then
			for _, child in inst:GetChildren() do
				if child.ClassName == className or (child.IsA and child:IsA(className)) then
					return child
				end
			end
		end
	end
	return nil
end

function StyleHelper.applyGradient(instance, topColor, midColor, bottomColor, rotation)
	local gradient = findChildOfClass(instance, "UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = instance
	end
	gradient.Rotation = rotation or 90
	pcall(function()
		local CS = ColorSequence
		local CSK = ColorSequenceKeypoint
		if CS and CSK then
			if midColor then
				gradient.Color = CS.new({
					CSK.new(0, topColor),
					CSK.new(0.5, midColor),
					CSK.new(1, bottomColor),
				})
			else
				gradient.Color = CS.new({
					CSK.new(0, topColor),
					CSK.new(1, bottomColor),
				})
			end
		elseif CS and CS.new then
			gradient.Color = CS.new(topColor, bottomColor)
		end
	end)
	return gradient
end

function StyleHelper.apply3DButton(button, topColor, midColor, bottomColor, cornerRadius, strokeThickness)
	button.BorderSizePixel = 0

	local corner = findChildOfClass(button, "UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = button
	end
	corner.CornerRadius = UDim.new(0, cornerRadius or 12)

	local stroke = findChildOfClass(button, "UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = button
	end
	stroke.Thickness = strokeThickness or 3
	stroke.Color = Color3.fromRGB(10, 15, 25)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local gradient = StyleHelper.applyGradient(button, topColor, midColor, bottomColor, 90)

	if button:IsA("TextButton") or button:IsA("TextLabel") then
		button.Font = Enum.Font.GothamBlack
		button.TextStrokeTransparency = 0.15
		button.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	end

	-- Find any child NavigationLabel or text label
	local label = button:FindFirstChild("NavigationLabel") or findChildOfClass(button, "TextLabel")
	if label and label:IsA("TextLabel") then
		label.Font = Enum.Font.GothamBlack
		label.TextStrokeTransparency = 0.15
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	end

	-- Bounce interaction via UIScale
	local scale = findChildOfClass(button, "UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = button
	end

	if TweenService and TweenService.Create then
		pcall(function()
			local hoverIn = TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 })
			local hoverOut = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
			local pressDown = TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 })

			if button.MouseEnter then
				button.MouseEnter:Connect(function() hoverIn:Play() end)
			end
			if button.MouseLeave then
				button.MouseLeave:Connect(function() hoverOut:Play() end)
			end
			if button.MouseButton1Down then
				button.MouseButton1Down:Connect(function() pressDown:Play() end)
			end
			if button.MouseButton1Up then
				button.MouseButton1Up:Connect(function() hoverIn:Play() end)
			end
		end)
	end

	return { corner = corner, stroke = stroke, gradient = gradient, scale = scale }
end

function StyleHelper.applyModalPanel(panel, strokeColor)
	panel.BorderSizePixel = 0

	local corner = findChildOfClass(panel, "UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = panel
	end
	corner.CornerRadius = UDim.new(0, 14)

	local stroke = findChildOfClass(panel, "UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = panel
	end
	stroke.Thickness = 3
	stroke.Color = strokeColor or Color3.fromRGB(60, 110, 180)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local gradient = StyleHelper.applyGradient(
		panel,
		Color3.fromRGB(38, 70, 125),
		Color3.fromRGB(28, 52, 95),
		Color3.fromRGB(18, 34, 64),
		45
	)
	return { corner = corner, stroke = stroke, gradient = gradient }
end

function StyleHelper.applyCloseButton(closeButton)
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.GothamBlack
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextStrokeTransparency = 0.15
	closeButton.TextStrokeColor3 = Color3.fromRGB(80, 0, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)

	return StyleHelper.apply3DButton(
		closeButton,
		Color3.fromRGB(255, 85, 85),
		Color3.fromRGB(235, 55, 55),
		Color3.fromRGB(210, 35, 35),
		12,
		3
	)
end

function StyleHelper.formatCash(amount)
	local str = tostring(math.floor(amount or 0))
	local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

return table.freeze(StyleHelper)
