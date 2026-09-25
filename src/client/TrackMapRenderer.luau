local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrackGeometry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackGeometry"))

local TrackMapRenderer = {}

function TrackMapRenderer.create(parent: GuiObject, definition, showKartMarker: boolean)
	local course = TrackGeometry.getCourse(definition)
	local samples = course.Samples
	local bounds = course.Bounds
	local centerX = (bounds.MinX + bounds.MaxX) * 0.5
	local centerZ = (bounds.MinZ + bounds.MaxZ) * 0.5
	local extent = math.max(bounds.MaxX - bounds.MinX, bounds.MaxZ - bounds.MinZ) * 1.14
	local function mapPoint(point: Vector3): Vector2
		-- World +X goes right; world +Z goes up on the GUI.
		return Vector2.new(0.5 + (point.X - centerX) / extent, 0.5 - (point.Z - centerZ) / extent)
	end

	local canvas = Instance.new("Frame")
	canvas.Name = "CourseCanvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(0.92, 0.92)
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
	end

	local start = mapPoint(samples[1])
	local startMark = Instance.new("Frame")
	startMark.Name = "StartFinishMarker"
	startMark.AnchorPoint = Vector2.new(0.5, 0.5)
	startMark.Position = UDim2.fromScale(start.X, start.Y)
	startMark.Size = UDim2.fromOffset(10, 10)
	startMark.BackgroundColor3 = Color3.fromRGB(255, 205, 55)
	startMark.BorderSizePixel = 0
	startMark.Parent = canvas
	local startCorner = Instance.new("UICorner")
	startCorner.CornerRadius = UDim.new(1, 0)
	startCorner.Parent = startMark

	local kartMarker: Frame? = nil
	if showKartMarker then
		kartMarker = Instance.new("Frame")
		kartMarker.Name = "KartPosition"
		kartMarker.AnchorPoint = Vector2.new(0.5, 0.5)
		kartMarker.Size = UDim2.fromOffset(11, 11)
		kartMarker.BackgroundColor3 = Color3.fromRGB(65, 225, 245)
		kartMarker.BorderSizePixel = 0
		kartMarker.Visible = false
		kartMarker.Parent = canvas
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = kartMarker
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(12, 25, 35)
		stroke.Thickness = 2
		stroke.Parent = kartMarker
	end

	local renderer = {}
	function renderer:setMarkerWorldPosition(position: Vector3?)
		if not kartMarker then
			return
		end
		kartMarker.Visible = position ~= nil
		if position then
			local point = mapPoint(position)
			kartMarker.Position = UDim2.fromScale(math.clamp(point.X, 0.02, 0.98), math.clamp(point.Y, 0.02, 0.98))
		end
	end
	function renderer:setVisible(visible: boolean)
		canvas.Visible = visible
	end
	function renderer:destroy()
		canvas:Destroy()
	end
	return renderer
end

return TrackMapRenderer
