-- Same road-facing KDM rail artwork used by Rookie Racing Park.
local function attach(railPart: Part, normalVector: Vector3)
			local inwardFace = if railPart.CFrame.RightVector:Dot(-normalVector) > 0 then Enum.NormalId.Right else Enum.NormalId.Left
			local gui = Instance.new("SurfaceGui")
			gui.Name = "KDMBrandSurfaceGui"
			gui.Face = inwardFace
			gui.CanvasSize = Vector2.new(512, 128)
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.LightInfluence = 0
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			gui.Parent = railPart

			local panel = Instance.new("Frame")
			panel.Name = "BrandPanel"
			panel.Size = UDim2.new(0.82, 0, 0.72, 0)
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Position = UDim2.new(0.5, 0, 0.5, 0)
			panel.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
			panel.BorderSizePixel = 0
			panel.Parent = gui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = panel

			local flag = Instance.new("Frame")
			flag.Name = "CheckerFlag"
			flag.Size = UDim2.new(0.20, 0, 0.74, 0)
			flag.AnchorPoint = Vector2.new(0, 0.5)
			flag.Position = UDim2.new(0.04, 0, 0.5, 0)
			flag.BackgroundTransparency = 1
			flag.BorderSizePixel = 0
			flag.Parent = panel

			local rows, cols = 3, 4
			for r = 0, rows - 1 do
				for c = 0, cols - 1 do
					local cell = Instance.new("Frame")
					cell.Name = string.format("Cell_%d_%d", r, c)
					cell.Size = UDim2.new(1 / cols, 0, 1 / rows, 0)
					cell.Position = UDim2.new(c / cols, 0, r / rows, 0)
					cell.BackgroundColor3 = if (r + c) % 2 == 0 then Color3.fromRGB(250, 250, 250) else Color3.fromRGB(18, 20, 24)
					cell.BorderSizePixel = 0
					cell.Parent = flag
				end
			end

			local label = Instance.new("TextLabel")
			label.Name = "KDMText"
			label.Size = UDim2.new(0.68, 0, 0.82, 0)
			label.AnchorPoint = Vector2.new(0, 0.5)
			label.Position = UDim2.new(0.28, 0, 0.5, 0)
			label.BackgroundTransparency = 1
			label.Text = "KDM"
			label.Font = Enum.Font.GothamBold
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextScaled = true
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.Parent = panel
		end

return attach
