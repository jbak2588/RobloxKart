-- A short presentation replay, not a second live Workspace camera.
-- Coordinates are supplied by the accepted server deployment only.
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RaceItemConfig"))
local Preview = {}
local DURATION = 0.9

local function part(parent, name, size, frame, color, rounded)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, frame, color
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	if rounded then p.Shape = Enum.PartType.Ball end
	p.Parent = parent
	return p
end

function Preview.new(gui, onFinished)
	local panel = Instance.new("Frame")
	panel.Name = "SlickRearPreview"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.BackgroundColor3 = Color3.fromRGB(16, 25, 35)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local viewport = Instance.new("ViewportFrame")
	viewport.Position = UDim2.fromOffset(4, 24)
	viewport.Size = UDim2.new(1, -8, 1, -28)
	viewport.BackgroundColor3 = Color3.fromRGB(35, 47, 61)
	viewport.Ambient = Color3.fromRGB(185, 185, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.Parent = panel
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.new(1, -8, 0, 24)
	caption.Position = UDim2.fromOffset(4, 0)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBold
	caption.TextSize = 12
	caption.TextColor3 = Color3.fromRGB(150, 220, 255)
	caption.Text = "REAR / SLICK DEPLOYED"
	caption.Parent = panel
	local camera = Instance.new("Camera")
	camera.FieldOfView = 55
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local scene, connection
	local self = {}
	function self:isVisible() return panel.Visible end
	function self:layout(compact, position)
		panel.Position = position
		panel.Size = UDim2.fromOffset(if compact then 176 else 248, if compact then 112 else 152)
	end
	function self:stop()
		if connection then connection:Disconnect(); connection = nil end
		if scene then scene:Destroy(); scene = nil end
		panel.Visible = false
	end
	function self:show(frame, eject)
		self:stop()
		if typeof(frame) ~= "CFrame" or typeof(eject) ~= "Vector3" then return end
		scene = Instance.new("WorldModel")
		scene.Parent = viewport
		-- Work in the authoritative pad's local coordinates to avoid large-world precision.
		local start = frame:PointToObjectSpace(eject)
		part(scene, "RoadContext", Vector3.new(24, 0.1, 40), CFrame.new(0, -0.17, 0), Color3.fromRGB(61, 64, 70))
		local pad = part(scene, "OilPad", Vector3.new(Config.SLICK_WIDTH, 0.16, Config.SLICK_LENGTH), CFrame.identity, Color3.fromRGB(30, 24, 43))
		local edges = {}
		for i = 1, 4 do
			local edge = part(scene, "OilEdge"..i, Vector3.one, CFrame.identity, Color3.fromRGB(180, 125, 255))
			edge.Material = Enum.Material.Neon
			table.insert(edges, edge)
		end
		-- Lightweight matching kart silhouette, copied only for this short preview.
		local prototype = workspace:FindFirstChild("Prototype")
		local kart = prototype and prototype:FindFirstChild("Kart")
		local visual = kart and kart:FindFirstChild("Visual")
		local chassis = kart and kart:FindFirstChild("Chassis")
		if visual and chassis then
			local copied = 0
			for _, original in visual:GetDescendants() do
				if original:IsA("BasePart") and original.Transparency < 1 and copied < 64 then
					local clone = original:Clone()
					clone:ClearAllChildren()
					clone.Anchored = true
					clone.CanCollide, clone.CanTouch, clone.CanQuery = false, false, false
					-- Reconstruct the deployment chassis frame from the ejection offset.
					clone.CFrame = CFrame.new(start - Vector3.new(0,5,3)) * chassis.CFrame:ToObjectSpace(original.CFrame)
					clone.Parent = scene
					copied += 1
				end
			end
		end
		local drop = part(scene, "OilDrop", Vector3.new(1.7, 2, 1.7), CFrame.new(start), Color3.fromRGB(115, 75, 150), true)
		local droplets = {}
		for i = 1, 4 do
			table.insert(droplets, part(scene, "Splash", Vector3.new(0.7, 0.15, 0.5), CFrame.identity, Color3.fromRGB(100, 70, 120), true))
		end
		-- Fixed rear-facing view holds the landing point in frame while driving continues.
		camera.CFrame = CFrame.lookAt(Vector3.new(10, 10, -15), Vector3.new(0, 1.5, -2))
		local began = time()
		local function render()
			local elapsed = time() - began
			if elapsed >= DURATION then self:stop(); onFinished(); return end
			-- Slowed presentation replay makes the short world animation readable.
			local age = elapsed * 0.8
			local flight = math.clamp(age/0.2, 0, 1)
			drop.CFrame = CFrame.new(start:Lerp(Vector3.zero, flight) + Vector3.new(0, math.sin(flight*math.pi)*2.2, 0))
			drop.Transparency = if flight >= 1 then 1 else 0
			local reveal = math.clamp((age-0.2)/0.16, 0, 1)
			local scale = 0.08 + 0.92*(1-(1-reveal)^3)
			pad.Size = Vector3.new(Config.SLICK_WIDTH*scale, 0.16, Config.SLICK_LENGTH*scale)
			pad.Transparency = 1-reveal
			for i, edge in edges do
				local side = if i%2==1 then -1 else 1
				if i <= 2 then
					edge.Size = Vector3.new(0.25*scale, 0.20, Config.SLICK_LENGTH*scale)
					edge.CFrame = CFrame.new(side*(Config.SLICK_WIDTH*.5-.125)*scale, 0.04, 0)
				else
					edge.Size = Vector3.new(Config.SLICK_WIDTH*scale, 0.20, 0.25*scale)
					edge.CFrame = CFrame.new(0, 0.04, side*(Config.SLICK_LENGTH*.5-.125)*scale)
				end
				edge.Transparency = 1-reveal
			end
			local splash = math.clamp((age-0.2)/0.22, 0, 1)
			for i, droplet in droplets do
				local angle = i*math.pi/2
				droplet.CFrame = CFrame.new(math.cos(angle)*3.5*splash, 0.12+math.sin(splash*math.pi)*0.65, math.sin(angle)*2.5*splash)
				droplet.Transparency = if age<0.2 then 1 else 0.1+0.9*splash
			end
		end
		render()
		panel.Visible = true
		connection = RunService.RenderStepped:Connect(render)
	end
	gui.Destroying:Connect(function() self:stop() end)
	return self
end

return Preview
