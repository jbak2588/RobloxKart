local luau, rb = require("@lune/luau"), require("@lune/roblox")
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end

local function signal()
	local list = {}
	return {
		Connect = function(_, f)
			local c = { active = true }
			function c:Disconnect() self.active = false end
			table.insert(list, { c, f })
			return c
		end,
		Fire = function(_, ...)
			for _, p in table.clone(list) do
				if p[1].active then p[2](...) end
			end
		end,
	}
end

local function mockObject(className, name)
	local props = {
		ClassName = className,
		Name = name or className,
		children = {},
		Parent = nil,
		Position = rb.Vector3.zero,
		Size = rb.Vector3.new(10, 10, 10),
		CFrame = rb.CFrame.identity,
		Anchored = false,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
		CastShadow = true,
		ChildAdded = signal(),
		ChildRemoved = signal(),
		Destroying = signal(),
	}

	local proxy = {}
	local methods = {
		GetChildren = function() return props.children end,
		FindFirstChild = function(_, childName)
			for _, c in props.children do if c.Name == childName then return c end end
			return nil
		end,
		WaitForChild = function(self, childName)
			return self:FindFirstChild(childName)
		end,
		IsA = function(_, c) return props.ClassName == c end,
		Destroy = function(self)
			props.Destroying:Fire()
			self.Parent = nil
		end,
	}

	setmetatable(proxy, {
		__index = function(_, k)
			if methods[k] then return methods[k] end
			return props[k]
		end,
		__newindex = function(self, k, v)
			local old = props[k]
			props[k] = v
			if k == "Parent" then
				if old and old.children then
					local idx = table.find(old.children, self)
					if idx then table.remove(old.children, idx) end
					if old.ChildRemoved then old.ChildRemoved:Fire(self) end
				end
				if v and v.children then
					table.insert(v.children, self)
					if v.ChildAdded then v.ChildAdded:Fire(self) end
				end
			end
		end,
	})

	return proxy
end

-- Setup Mock Roblox Environment
local workspace = mockObject("Workspace", "Workspace")
local prototype = mockObject("Folder", "Prototype")
prototype.Parent = workspace
table.insert(workspace.children, prototype)

local players = { LocalPlayer = mockObject("Player", "LocalPlayer") }
local services = {
	Workspace = workspace,
	Players = players,
}

local fs = require("@lune/fs")
local source = fs.readFile("src/client/TrackHorizonController.luau")
local controller = luau.load(source, {
	environment = {
		game = { GetService = function(_, name) return services[name] end },
		Instance = {
			new = function(className)
				local o = mockObject(className)
				return o
			end,
		},
		Vector3 = rb.Vector3,
		CFrame = rb.CFrame,
		Color3 = rb.Color3,
		Enum = {
			Material = { SmoothPlastic = "SmoothPlastic" },
		},
		math = math,
		table = table,
	},
})()

-- 1. Start controller without active track
controller.start()
check(prototype:FindFirstChild("ClientHorizonEnvironment") == nil, "no horizon without active track")

-- 2. Simulate Track loaded (Practice Track)
local testTrack = mockObject("Model", "TestTrack")
local road = mockObject("Folder", "Road")
road.Parent = testTrack
table.insert(testTrack.children, road)

-- Add road segments around (-100, 100) to (-100, -100) etc.
for _, pos in { rb.Vector3.new(-120, 0, -100), rb.Vector3.new(120, 0, 100), rb.Vector3.new(0, 0, 0) } do
	local p = mockObject("Part", "RoadPart")
	p.Position = pos
	p.Size = rb.Vector3.new(20, 1, 20)
	p.Parent = road
	table.insert(road.children, p)
end

testTrack.Parent = prototype
table.insert(prototype.children, testTrack)
prototype.ChildAdded:Fire(testTrack)

local horizonModel = testTrack:FindFirstChild("ClientHorizonEnvironment")
check(horizonModel ~= nil, "ClientHorizonEnvironment created under TestTrack")

-- 3. Verify Scenery Structure & Performance Flags
local parts = horizonModel:GetChildren()
check(#parts == (18 * 2) + (18 * 2) + 18, "exact scenery budget (36 outer mountain wedges, 36 inner hill wedges, 18 skirt blocks)")

local outerCount = 0
local innerCount = 0
local skirtCount = 0
for _, p in parts do
	check(p.Anchored == true, "anchored scenery")
	check(p.CanCollide == false, "non-collidable (no physics cost)")
	check(p.CanTouch == false, "no touch query cost")
	check(p.CanQuery == false, "no raycast query cost")
	check(p.CastShadow == false, "no shadow map cost")
	check(p.Material == "SmoothPlastic", "smooth low-poly plastic material")

	if p.Name:find("Mountain") then
		outerCount += 1
		check(p.ClassName == "WedgePart", "mountain peaks use wedges")
		check(p.Size.Y >= 75 and p.Size.Y <= 110, "majestic mountain heights (75~110 studs)")
	elseif p.Name:find("Hill") then
		innerCount += 1
		check(p.ClassName == "WedgePart", "rolling hills use wedges")
		check(p.Size.Y >= 35 and p.Size.Y <= 60, "rolling hill heights (35~60 studs)")
	elseif p.Name:find("Skirt") then
		skirtCount += 1
		check(p.ClassName == "Part", "perimeter base skirt blocks")
	end
end

check(outerCount == 36, "36 outer mountain wedge slopes")
check(innerCount == 36, "36 inner hill wedge slopes")
check(skirtCount == 18, "18 perimeter base skirt segments")

-- 4. Test Track Unload / Transition Lifecycle
testTrack:Destroy()
check(horizonModel.Parent == nil, "horizon destroyed when track is removed")

controller.destroy()
print("PASS: " .. checks .. " client low-poly horizon mountains, hills and lifecycle checks")
