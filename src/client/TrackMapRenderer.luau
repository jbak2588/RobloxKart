local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrackGeometry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackGeometry"))

local TrackMapRenderer = {}

function TrackMapRenderer.create(parent: GuiObject, definition, showKartMarker: boolean, previewRotationDegrees: number?)
	local course = TrackGeometry.getCourse(definition)
	local samples = course.Samples
	local bounds = course.Bounds
	local centerX = (bounds.MinX + bounds.MaxX) * 0.5
	local centerZ = (bounds.MinZ + bounds.MaxZ) * 0.5
	local extent = math.max(bounds.MaxX - bounds.MinX, bounds.MaxZ - bounds.MinZ) * (if showKartMarker then 1.14 else 1.04)
	local radians = math.rad(previewRotationDegrees or 0)
	local cosine, sine = math.cos(radians), math.sin(radians)
	local function mapPoint(point: Vector3): Vector2
		-- World +X goes right; world +Z goes up on the GUI.
		local x, y = (point.X - centerX) / extent, -(point.Z - centerZ) / extent
		return Vector2.new(0.5 + x * cosine - y * sine, 0.5 + x * sine + y * cosine)
	end

	local canvas = Instance.new("Frame")
	canvas.Name = "CourseCanvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, if showKartMarker then 0.5 else 0.48)
	canvas.Size = UDim2.fromScale(if showKartMarker then 0.92 else 0.96, if showKartMarker then 0.92 else 0.96)
	canvas.BackgroundTransparency = 1
	canvas.ClipsDescendants = true
	canvas.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = canvas

	for index = 1, #samples do
		local first = mapPoint(samples[index])
		local second = mapPoint(samples[index % #samples + 1])
		local delta = second - first
		local line = Instance.new("Frame")
		line.Name = "CourseSegment"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale((first.X + second.X) * 0.5, (first.Y + second.Y) * 0.5)
		line.Size = UDim2.new(delta.Magnitude, 1, 0, 3)
		line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		line.BackgroundColor3 = Color3.fromRGB(220, 228, 233)
		line.BorderSizePixel = 0
		line.Parent = canvas
		if not showKartMarker then
			-- A continuous road fill avoids per-sample end-border seams and extra UI.
			line.Size = UDim2.new(delta.Magnitude, 2, 0, 7)
			line.BackgroundColor3 = Color3.fromRGB(86, 142, 168)
			line.Active = false
			line:SetAttribute("GarageRoadRibbon", true)
		end
	end

	local start = mapPoint(samples[1])
	local startMark = Instance.new("Frame")
	startMark.Name = "StartFinishMarker"
	startMark.AnchorPoint = Vector2.new(0.5, 0.5)
	startMark.Position = UDim2.fromScale(start.X, start.Y)
	startMark.Size = UDim2.fromOffset(10, 10)
	startMark.BackgroundColor3 = Color3.fromRGB(255, 205, 55)
	startMark.BorderSizePixel = 0
	startMark.ZIndex = 1
	startMark.Parent = canvas
	local startCorner = Instance.new("UICorner")
	startCorner.CornerRadius = UDim.new(1, 0)
	startCorner.Parent = startMark

	local markers = {}
	local renderer = {}
	function renderer:setRacerMarker(key, position: Vector3?, style: string?)
		if not showKartMarker then return end
		if not position then
			self:removeRacerMarker(key)
			return
		end
		local marker = markers[key]
		if not marker then
			marker = Instance.new("Frame")
			marker.Name = if style == "RIVAL" then "RivalPosition" else "KartPosition"
			marker.AnchorPoint = Vector2.new(0.5, 0.5)
			marker.Size = UDim2.fromOffset(if style == "RIVAL" then 16 else 11, if style == "RIVAL" then 16 else 11)
			marker.BackgroundColor3 = if style == "RIVAL" then Color3.fromRGB(255, 165, 45) else Color3.fromRGB(65, 225, 245)
			marker.BackgroundTransparency = if style == "RIVAL" then 1 else 0
			marker.BorderSizePixel = 0
			marker.ZIndex = if style == "RIVAL" then 3 else 4
			marker.Parent = canvas
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = marker
			local stroke = Instance.new("UIStroke")
			stroke.Color = if style == "RIVAL" then Color3.fromRGB(255, 165, 45) else Color3.fromRGB(12, 25, 35)
			stroke.Thickness = if style == "RIVAL" then 3 else 2
			stroke.Parent = marker
			markers[key] = marker
		end
		local point = mapPoint(position)
		marker.Position = UDim2.fromScale(math.clamp(point.X, 0.02, 0.98), math.clamp(point.Y, 0.02, 0.98))
	end
	function renderer:removeRacerMarker(key)
		local marker = markers[key]
		if marker then marker:Destroy(); markers[key] = nil end
	end
	function renderer:clearRacerMarkers()
		for key in markers do self:removeRacerMarker(key) end
	end
	function renderer:setMarkerWorldPosition(position: Vector3?)
		self:setRacerMarker("local", position, "LOCAL")
	end
	function renderer:setVisible(visible: boolean)
		canvas.Visible = visible
	end
	function renderer:destroy()
		self:clearRacerMarkers()
		canvas:Destroy()
	end
	return renderer
end

return TrackMapRenderer
