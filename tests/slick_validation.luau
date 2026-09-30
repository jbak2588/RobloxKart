-- Production geometry/visual/motion probes. Workspace ancestry is a replication
-- contract, not proof of live networking; Studio 2-client checks remain separate.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local V, CF = rb.Vector3, rb.CFrame
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end
-- Lune Instances do not derive Position from CFrame; model that engine contract
-- here, while executing the unmodified production geometry and visual modules.
local methods={}
local function instance(class)
	local props={ClassName=class,Name=class,CFrame=CF.identity,Size=V.one}
	return setmetatable({props=props,children={}}, {
		__index=function(self,key)
			if methods[key] then return methods[key] end
			if key=="Position" then return props.CFrame.Position end
			if props[key]~=nil then return props[key] end
			return self:FindFirstChild(key)
		end,
		__newindex=function(self,key,value)
			if key=="Parent" then
				if props.Parent then table.remove(props.Parent.children,table.find(props.Parent.children,self)) end
				if value then table.insert(value.children,self) end
			end
			props[key]=value
		end,
	})
end
function methods:GetChildren() return table.clone(self.children) end
function methods:FindFirstChild(name) for _,c in self.children do if c.Name==name then return c end end end
function methods:IsA(class) return self.ClassName==class or class=="BasePart" and self.ClassName=="Part" end
function methods:Destroy() self.Parent=nil end
local function load(path)
	return luau.load(fs.readFile(path), {debugName=path, environment={
		Vector3=V, CFrame=CF, Color3=rb.Color3, Enum=rb.Enum, Instance={new=instance},
	}})()
end
local config = load("src/shared/RaceItemConfig.luau")
local geometry = load("src/server/RaceItemGeometry.luau")
local visuals = load("src/server/RaceItemVisuals.luau")
local motionType = load("src/server/SlickMotion.luau")
local function child(parent, class, name)
	local item = instance(class); item.Name=name; item.Parent=parent; return item
end
local workspace = instance("Workspace")
local prototype = child(workspace,"Folder","Prototype")
local roads = child(child(prototype,"Model","TestTrack"),"Folder","Road")
local road = child(roads,"Part","Road1")
road.Size=V.new(60,.05,500); road.CFrame=CF.identity
local folder = child(prototype,"Folder","RaceItemHazards")
local chassis = instance("Part")
chassis.Size=V.new(6,2,8); chassis.CFrame=CF.new(-12,1.75,0)
local frame = assert(geometry.dropFrame(prototype,chassis,config.SLICK_DROP_DISTANCE))
local model, trigger, deploy = visuals.slick(folder,frame,config,chassis.CFrame)
check(config.SLICK_WIDTH==16 and config.SLICK_LENGTH==5 and road.Size.X==60,
	"R2 16x5 occupies 26.7 percent of the 60-stud road, not the whole road")
check(model.Parent==folder and folder.Parent==prototype and prototype.Parent==workspace,
	"real hazard is under shared server Workspace, not a PlayerGui/ViewportFrame")
check(model.Name=="SlickHazard" and model:FindFirstChild("SlickSurface")~=nil,
	"shared hazard model and oil surface exist")
check(trigger.Size==V.new(16,4,5) and trigger.Transparency==1,
	"swept trigger has exactly the configured dimensions")
check(trigger.Position.X==frame.Position.X and trigger.Position.Z==frame.Position.Z,
	"trigger and visible patch have the same planar center")
check(not visuals.updateSlick(deploy,.1) and deploy.surface.Transparency==1,
	"initial oil flight has a bounded reveal delay")
visuals.updateSlick(deploy,.36)
check(deploy.surface.Transparency<.00001 and deploy.surface.Size==V.new(16,.16,5),
	"surface reaches full opacity and full trigger footprint at .36 seconds")
check(visuals.updateSlick(deploy,.43) and model.Parent==folder,
	"animation completes without destroying the real hazard")
check(#model:GetChildren()==6,"only trigger, surface and four complete edges survive animation")
for i, edge in deploy.edges do
	check(edge.Parent==model and edge.Material==rb.Enum.Material.Neon and edge.Transparency<.00001,
		"replicated bright perimeter edge "..i)
	local localPosition=frame:PointToObjectSpace(edge.Position)
	check(math.abs(localPosition.X)+edge.Size.X/2<=8.00001
		and math.abs(localPosition.Z)+edge.Size.Z/2<=2.50001,
		"edge stays inside visible/trigger footprint "..i)
end
for _,part in model:GetChildren() do
	check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,
		"replicated native geometry has no physics or Touched authority "..part.Name)
end
visuals.updateSlick(deploy,9.5)
check(model.Parent==folder and deploy.surface.Transparency==0,
	"animation does not hide or destroy the patch near lifetime end")
local function crossing(x, speed, dt)
	local start=frame.Position+V.new(x,1.7, speed*dt/2)
	chassis.CFrame=CF.new(frame.Position+V.new(x,1.7,-speed*dt/2))
	return geometry.crosses(trigger.CFrame,trigger.Size,start,chassis)
end
for _,speed in {55,70,100} do
	check(crossing(0,speed,.5),"high-speed swept center contact "..speed)
	check(crossing(-10.9,speed,.5),"chassis overlaps left visible edge "..speed)
	check(crossing(10.9,speed,.5),"chassis overlaps right visible edge "..speed)
	check(not crossing(-11.2,speed,.5) and not crossing(11.2,speed,.5),
		"clear chassis miss outside both patch edges "..speed)
end
-- Leader x=-12, follower x=+12: opposite lane is avoidable. Moving toward the
-- leader's lane to x=-3 overlaps the wider patch; the old 7-wide patch missed.
check(not crossing(24,70,.5),"opposite-side follower remains safe on a 60-stud road")
check(crossing(9,70,.5),"changing toward the leader's line crosses 16-wide lane denial")
check(not geometry.crosses(trigger.CFrame,V.new(7,4,5),frame.Position+V.new(9,1.7,20),chassis),
	"the same changed racing line missed the old 7-wide patch")
check(config.SLICK_LIFETIME==10 and config.SLICK_EFFECT_DURATION==.70
	and config.SLICK_SPEED_RETAIN==.55 and config.SLICK_YAW_AMPLITUDE==math.rad(60),
	"lifetime and effect tuning unchanged")
local motion=motionType.new(config)
motion:start("driver",0,V.new(0,0,-1),V.new(0,0,-1),70)
local velocity,yaw,done=motion:sample(.175,V.new(0,0,-1))
check(math.abs(velocity.Magnitude-38.5)<.00001 and yaw>0 and not done,
	"true hit retains 55 percent speed with controlled yaw")
check(select(3,motion:sample(.70,V.new(0,0,-1))),"motion ends at .70 seconds")
motion:stop();check(not motion.active,"motion cleanup stops effect")
print("PASS: "..checks.." Slick footprint, shared Workspace visuals, swept contact and motion checks (not live replication)")
