-- lune run tests/multiplayer_presentation_validation.luau
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count = 0
local function check(value, label) assert(value, label); count += 1 end
local methods = {}
local function object(class, name)
	local props = {ClassName=class, Name=name or class, Parent=nil}
	return setmetatable({_props=props, _children={}, _attrs={}}, {
		__index=function(self, key)
			if methods[key] then return methods[key] end
			if key == "Position" and class == "Part" then return props.WorldPosition end
			return props[key]
		end,
		__newindex=function(self, key, value)
			if key == "Parent" then
				if props.Parent then local i=table.find(props.Parent._children,self); if i then table.remove(props.Parent._children,i) end end
				if value then table.insert(value._children,self) end
			end
			props[key]=value
		end,
	})
end
function methods:GetChildren() return table.clone(self._children) end
function methods:FindFirstChild(name) for _, child in self._children do if child.Name==name then return child end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:GetAttribute(name) return self._attrs[name] end
function methods:SetAttribute(name,value) self._attrs[name]=value end
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function methods:Destroy() self.Parent=nil end
local function child(parent,class,name)
	local item=object(class,name); item.Parent=parent; return item
end
local shared=object("Folder","Shared")
child(shared,"ModuleScript","TrackGeometry")
local storage=object("ReplicatedStorage")
shared.Parent=storage
local course={Samples={rb.Vector3.new(0,0,0),rb.Vector3.new(100,0,0),rb.Vector3.new(100,0,100)},
	Bounds={MinX=0,MaxX=100,MinZ=0,MaxZ=100}}
local driverMarker=luau.load(fs.readFile('src/client/MinimapDriverMarker.luau'),{environment={Instance={new=object},Vector2=rb.Vector2,UDim2=rb.UDim2,Color3=rb.Color3}})()
local rendererType=luau.load(fs.readFile("src/client/TrackMapRenderer.luau"), {environment={
	game={GetService=function() return storage end},
	script={Parent={MinimapDriverMarker='marker'}},
	require=function(m) return if m=='marker' then driverMarker else {getCourse=function() return course end} end,
	Instance={new=object},Vector2=rb.Vector2,UDim2=rb.UDim2,UDim=rb.UDim,
	Color3=rb.Color3,Enum=rb.Enum,
}})()
local parent=object("Frame","Map")
local renderer=rendererType.create(parent,{},true)
local canvas=parent:FindFirstChild("CourseCanvas")
renderer:setRacerMarker("local:1",rb.Vector3.new(10,0,10),"LOCAL",rb.Vector3.xAxis)
renderer:setRacerMarker("rival:2",rb.Vector3.new(90,0,90),"RIVAL")
local localDot=canvas:FindFirstChild("KartPosition")
local rivalDot=canvas:FindFirstChild("RivalPosition")
check(localDot.Rotation==90,'official marker points right for world +X')
check(localDot and rivalDot and localDot.Position~=rivalDot.Position,"two distinct independent markers")
check(localDot:GetAttribute('DirectionMarkerVersion')==1 and rivalDot:FindFirstChild("UICorner")
	and rivalDot.BackgroundTransparency==1 and rivalDot:FindFirstChild("UIStroke").Thickness==3
	and rivalDot.Size.X.Offset==16 and localDot.Size.X.Offset==14,
	"directional cyan triangle and unchanged orange hollow ring differ")
check(canvas:FindFirstChild("StartFinishMarker").ZIndex==1 and rivalDot.ZIndex==3 and localDot.ZIndex==4,
	"marker layering keeps local dot inside rival ring above start marker")
renderer:setRacerMarker("rival:2",rb.Vector3.new(10,0,10),"RIVAL")
check(rivalDot.Position==localDot.Position and rivalDot.Size.X.Offset>localDot.Size.X.Offset,
	"overlapped racers retain visible rival ring")
renderer:setRacerMarker("rival:2",rb.Vector3.new(90,0,90),"RIVAL")
renderer:setRacerMarker("rival:3",rb.Vector3.new(80,0,20),"RIVAL")
renderer:setRacerMarker("rival:4",rb.Vector3.new(20,0,80),"RIVAL")
local rivalMarkers=0
for _, marker in canvas:GetChildren() do
	if marker.Name=="RivalPosition" then rivalMarkers+=1 end
end
check(rivalMarkers==3,"map renders three independent rival rings")
local oldRivalPosition=rivalDot.Position
renderer:setRacerMarker("local:1",rb.Vector3.new(40,0,40),"LOCAL")
check(localDot.Rotation==90,'position updates without direction preserve last heading')
check(localDot.Position~=rivalDot.Position and rivalDot.Position==oldRivalPosition,"moving self leaves rival in place")
renderer:setRacerMarker("rival:2",rb.Vector3.new(70,0,70),"RIVAL")
check(rivalDot.Position~=oldRivalPosition,"rival moves independently")
renderer:removeRacerMarker("rival:2")
local remainingRivals=0
for _, marker in canvas:GetChildren() do
	if marker.Name=="RivalPosition" then remainingRivals+=1 end
end
check(remainingRivals==2 and canvas:FindFirstChild("KartPosition"),
	"one rival removal preserves local and two other rival markers")
renderer:clearRacerMarkers()
check(not canvas:FindFirstChild("KartPosition"),"clear removes all racer markers")
local preview=rendererType.create(parent,{},false)
preview:setRacerMarker("local:1",rb.Vector3.new(10,0,10),"LOCAL")
check(not parent._children[2]:FindFirstChild("KartPosition"),"Garage preview has no racer marker")
local rotated=rendererType.create(parent,{},false,90)
local originalStart=parent._children[1]:FindFirstChild("StartFinishMarker").Position
local rotatedStart=parent._children[3]:FindFirstChild("StartFinishMarker").Position
check(originalStart.X.Scale<0.5 and originalStart.Y.Scale>0.5
 and rotatedStart.X.Scale<0.5 and rotatedStart.Y.Scale<0.5,
 "Base preview rotates clockwise while gameplay map remains unrotated")
rotated:destroy()
preview:destroy();renderer:destroy()

local rivals=luau.load(fs.readFile("src/client/RaceMinimapRivals.luau"))()
local localPlayer=object("Player","A");localPlayer.UserId=1
local other=object("Player","B");other.UserId=2
localPlayer:SetAttribute("RaceSessionId",5)
other:SetAttribute("RaceSessionId",5);other:SetAttribute("RaceState","RACING")
local localPosition=rb.Vector3.new(10,0,15)
local otherPosition=rb.Vector3.new(25,0,50)
localPlayer:SetAttribute("RaceMapPosition",localPosition);localPlayer:SetAttribute("RaceMapActive",true)
other:SetAttribute("RaceMapPosition",otherPosition);other:SetAttribute("RaceMapActive",true)
check(rivals.collect(localPlayer,{localPlayer,other},2)[2]==otherPosition
	and rivals.collect(other,{localPlayer,other},2)[1]==localPosition,
	"each client resolves the other racer from server attributes")
check(next(rivals.collect(localPlayer,{localPlayer,other},1))==nil,"solo race has no rival")
other:SetAttribute("RaceSessionId",6)
check(next(rivals.collect(localPlayer,{localPlayer,other},2))==nil,"different round filtered")
other:SetAttribute("RaceSessionId",5);other:SetAttribute("RaceState","GARAGE")
check(next(rivals.collect(localPlayer,{localPlayer,other},2))==nil,"Garage rival filtered")
other:SetAttribute("RaceState","RACING");other:SetAttribute("RaceMapActive",false)
check(next(rivals.collect(localPlayer,{localPlayer,other},2))==nil,"inactive rival filtered")
other:SetAttribute("RaceMapActive",true);other:SetAttribute("RaceMapPosition","invalid")
check(next(rivals.collect(localPlayer,{localPlayer,other},2))==nil,"invalid position filtered")
other:SetAttribute("RaceMapPosition",otherPosition)
other:SetAttribute("RaceState","RACING")
local third=object("Player","C");third.UserId=3
local fourth=object("Player","D");fourth.UserId=4
for _, racer in {third,fourth} do
	racer:SetAttribute("RaceSessionId",5)
	racer:SetAttribute("RaceState","RACING")
	racer:SetAttribute("RaceMapActive",true)
	racer:SetAttribute("RaceMapPosition",rb.Vector3.new(racer.UserId*10,0,30))
end
local fourRivals=rivals.collect(localPlayer,{localPlayer,other,third,fourth},4)
check(fourRivals[2]==otherPosition and fourRivals[3] and fourRivals[4],
	"four-player session exposes all three server-published rival positions")
third:SetAttribute("RaceState","DNF")
check(rivals.collect(localPlayer,{localPlayer,other,third,fourth},4)[3]==nil,
	"DNF rival marker is filtered")
fourth:SetAttribute("RaceMapActive",false)
check(rivals.collect(localPlayer,{localPlayer,other,third,fourth},4)[4]==nil,
	"leaving rival marker is removed without clearing active opponent")

local presence=luau.load(fs.readFile("src/client/GaragePresence.luau"))()
localPlayer.DisplayName="";localPlayer.Name="A"
other.DisplayName="Other Racer";other:SetAttribute("RaceState","GARAGE")
local total,entries=presence.snapshot({localPlayer},localPlayer)
check(total==1 and entries[1].name=="A" and entries[1].status=="GARAGE","one online uses username fallback")
total,entries=presence.snapshot({localPlayer,other},localPlayer)
check(total==2 and entries[2].name=="Other Racer","two online use display name")
third.DisplayName="Zed";fourth.DisplayName="Aaron"
third:SetAttribute("ReadyOrder",2);fourth:SetAttribute("ReadyOrder",1)
total,entries=presence.snapshot({third,other,localPlayer,fourth},localPlayer)
check(entries[1].userId==localPlayer.UserId and entries[2].userId==fourth.UserId
 and entries[3].userId==third.UserId,"presence keeps local first then deterministic ReadyOrder")
other:SetAttribute("RaceState","RACING")
total,entries=presence.snapshot({localPlayer,other},localPlayer)
check(entries[2].status=="RACING","RaceState change updates status snapshot")
total=presence.snapshot({localPlayer},localPlayer)
check(total==1,"removed player lowers online count")
for _, population in {3,10,50} do
	local synthetic={localPlayer}
	for index=2,population do
		local racer={UserId=index+100,Name=string.format("Racer%02d",index),DisplayName="",
			GetAttribute=function(_,name) return if name=="RaceState" then "GARAGE" else 0 end}
		table.insert(synthetic,racer)
	end
	total,entries=presence.snapshot(synthetic,localPlayer)
	check(total==population and #entries==population and entries[1].userId==localPlayer.UserId
		and entries[#entries].userId==population+100,"presence retains all "..population.." connected players")
	local canvas=presence.canvasHeight(population,16,2)
	check(canvas==population*16+(population-1)*2,"presence scroll canvas covers "..population.." rows")
end
other:SetAttribute("RaceState","GARAGE")
local availableCount,available=presence.availableSnapshot({localPlayer,other,third,fourth},localPlayer,4)
check(availableCount==1 and available[1].userId==other.UserId,
 "only another Garage racer is available, excluding lobby and racing states")
third:SetAttribute("RaceState","GARAGE")
availableCount,available=presence.availableSnapshot({localPlayer,other,third,fourth},localPlayer,4)
check(availableCount==2 and available[1].userId==other.UserId and available[2].userId==third.UserId,
 "available racers update and sort by user ID")
print("PASS: "..count.." multiplayer presentation checks")
