-- Run from repository root: lune run tests/kart_visual_validation.luau
-- Uses Lune's Roblox data model, not the Studio physics/render engine.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame, Color3 = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3
local function loadModule(path)
    return luau.load(fs.readFile(path), { debugName=path, environment={Instance=Instance, Vector2=roblox.Vector2, Vector3=Vector3, CFrame=CFrame, Color3=Color3, Enum=roblox.Enum} })()
end
local factory = loadModule("src/shared/KartVisualFactory.luau")
local catalog = loadModule("src/shared/KartCatalog.luau")
-- This suite audits the native Sprint structure; V2/default is audited separately.
local definition = catalog.Entries.Kart01
local valid = factory.createVisual(definition)
local ok, diagnostics = factory.validateVisual(valid)
assert(ok, table.concat(diagnostics, "\n"))
local count = 1
local function rejects(label, mutate, expected)
    local model = valid:Clone()
    mutate(model)
    local passed, messages = factory.validateVisual(model)
    assert(not passed, label .. " incorrectly passed")
    assert(string.find(table.concat(messages, "\n"), expected, 1, true), label .. ": missing diagnostic")
    model:Destroy()
    count += 1
end
for _, name in { "StaticRoot", "WheelFLPivot", "WheelFRPivot", "WheelRLPivot", "WheelRRPivot", "SteeringPivot" } do
    rejects("missing " .. name, function(m) m[name]:Destroy() end, name)
    rejects("wrong class " .. name, function(m) m[name]:Destroy(); local f=Instance.new("Folder"); f.Name=name; f.Parent=m end, "must be a BasePart")
    rejects("visible " .. name, function(m) m[name].Transparency=0 end, "must be invisible")
end
rejects("duplicate root", function(m) m.WheelFLPivot:Clone().Parent=m end, "exactly one direct")
rejects("primary root", function(m) m.PrimaryPart=m.WheelFLPivot end, "PrimaryPart")
for _, name in { "WheelFLPivot", "WheelFRPivot", "WheelRLPivot", "WheelRRPivot" } do
    rejects("role", function(m) m[name]:SetAttribute("VisualMotionRole", "Wrong") end, "VisualMotionRole")
    rejects("side", function(m) m[name]:SetAttribute("WheelSide", "Wrong") end, "WheelSide")
    for _, attr in { "WheelRadius", "WheelWidth" } do
        for _, value in { 0, -1, math.huge, 0/0, "bad" } do
            rejects(attr, function(m) m[name]:SetAttribute(attr,value) end, attr)
        end
        rejects(attr .. " missing", function(m) m[name]:SetAttribute(attr,nil) end, attr)
    end
end
rejects("steering role", function(m) m.SteeringPivot:SetAttribute("VisualMotionRole",nil) end, "VisualMotionRole")
for _, role in { "ExhaustLeft", "ExhaustRight" } do
    rejects("missing exhaust", function(m) m.StaticRoot[role]:Destroy() end, role)
    rejects("duplicate exhaust", function(m) m.StaticRoot[role]:Clone().Parent=m.StaticRoot end, role)
    rejects("wrong exhaust class", function(m) m.StaticRoot[role]:Destroy(); local f=Instance.new("Folder"); f:SetAttribute("EffectRole",role); f.Parent=m.StaticRoot end, "must be an Attachment")
end
for property, value in { CanCollide=true, CanTouch=true, CanQuery=true, Massless=false } do
    rejects(property, function(m) m.StaticRoot.FloorPan[property]=value end, property)
end
rejects("loose visible part", function(m) m.StaticRoot.FloorPan.Parent=m end, "nested under")
rejects("extra visible physics seat", function(m) local seat=Instance.new("Seat"); seat.Parent=m.StaticRoot end, "physics seats")
rejects("extra motion root", function(m) m.StaticRoot.FloorPan:SetAttribute("VisualMotionRole","FrontWheel") end, "only on contracted pivots")
for _, part in valid:GetDescendants() do
    if part:IsA("BasePart") then part.Anchored=true end
end
assert(factory.validateVisual(valid), "Anchored Garage preview must validate")
count += 1
local mesh=Instance.new("MeshPart")
mesh.CanCollide=false; mesh.CanTouch=false; mesh.CanQuery=false; mesh.Massless=true; mesh.Parent=valid.StaticRoot
assert(factory.validateVisual(valid), "Nested production mesh must validate")
count += 1
print("PASS: " .. count .. " contract cases (creation, malformed structures, Garage preview, nested MeshPart)")

local sprint = factory.createVisual(definition)
local visible, hidden, welds = 0, 0, 0
for _, part in sprint:GetDescendants() do
    if part:IsA("BasePart") then
        assert(not part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and part.Massless)
        if part.Transparency < 1 then
            visible += 1
            local weld = part:FindFirstChildOfClass("WeldConstraint")
            assert(weld and weld.Part0==part.Parent and weld.Part1==part, "Unbound geometry: "..part.Name)
            welds += 1
        else hidden += 1 end
    end
    assert(not part:IsA("MeshPart") and not part:IsA("SpecialMesh") and not part:IsA("Decal"), "External asset dependency")
end
assert(visible==40 and hidden==6 and welds==40)
print("PASS: 40 visible parts, six invisible pivots, all internal welds; no mesh/decal assets")
for _, row in { {"WheelFLPivot",-3.25,-2.55,0.925,0.9}, {"WheelFRPivot",3.25,-2.55,0.925,0.9}, {"WheelRLPivot",-3.3,2.65,1.025,1.05}, {"WheelRRPivot",3.3,2.65,1.025,1.05} } do
    local pivot=sprint[row[1]]
    assert((pivot.CFrame.Position-Vector3.new(row[2],row[4]+0.065+0.025-0.5,row[3])).Magnitude < 0.00001)
    assert(pivot:GetAttribute("WheelRadius")==row[4] and pivot:GetAttribute("WheelWidth")==row[5])
    local parts=0
    for _, child in pivot:GetChildren() do if child:IsA("BasePart") then parts+=1 end end
    assert(parts==3, "Each wheel must have tire/rim/hub")
end
print("PASS: four original wheel anchors/radii/widths and three-part wheel assemblies")
for _, row in { {"ExhaustLeft",-1}, {"ExhaustRight",1} } do
    local anchor=sprint.StaticRoot[row[1]]
    local pipe=sprint.StaticRoot["Exhaust"..row[2]]
    local rearTip=pipe.CFrame:PointToWorldSpace(Vector3.new(-pipe.Size.X/2,0,0))
    assert((rearTip-anchor.Position).Magnitude < 0.00001, "Pipe/FX origin mismatch")
end
assert(sprint.PrimaryPart==sprint.StaticRoot and sprint.StaticRoot.CFrame==CFrame.identity)
assert((sprint.SteeringPivot.CFrame.Position-Vector3.new(0,.85,-.95)).Magnitude < 0.00001)
print("PASS: two exhaust tips/anchors and unchanged chassis-local/steering origins")
local root=sprint.StaticRoot
assert(root.FrontBumper.Color==definition.BodyColor and root.Nose.Color==definition.AccentColor)
print("PASS: catalog red/white palette compatibility")
local materials = { BodyPrimary=roblox.Enum.Material.SmoothPlastic, BodySecondary=roblox.Enum.Material.SmoothPlastic,
    Accent=roblox.Enum.Material.SmoothPlastic, Trim=roblox.Enum.Material.SmoothPlastic, Tire=roblox.Enum.Material.Rubber,
    Rim=roblox.Enum.Material.Metal, Metal=roblox.Enum.Material.Metal, Seat=roblox.Enum.Material.SmoothPlastic }
local materialCount=0
for _, part in sprint:GetDescendants() do
    if part:IsA("BasePart") and part.Transparency<1 then
        assert(part.Material==materials[part:GetAttribute("MaterialRole")] and part.Reflectance==0)
        materialCount+=1
    end
end
assert(materialCount==40 and root.EngineBlock.Material==roblox.Enum.Material.Metal)
local beforeMaterial=root.EngineBlock.Material
factory.applyColors(sprint, definition)
assert(root.EngineBlock.Material==beforeMaterial, "Colors must not overwrite material")
print("PASS: 40 material assignments; color/material separation and dark metal engine")
local framing=loadModule("src/shared/KartPreviewFraming.luau")
local frameCases=0
for _, scale in { 0.4, 1, 3 } do
    local model=sprint:Clone()
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Size*=scale
            part.CFrame=CFrame.new(part.CFrame.Position*scale)*part.CFrame.Rotation
        end
    end
    -- Deliberately distant invisible helpers must not affect the fit.
    local base=framing.fit(model, 4, 40)
    model.StaticRoot.CFrame=CFrame.new(10000,10000,10000)
    assert(framing.fit(model,4,40)==base)
    for _, aspect in { 0.75, 2, 4, 5 } do
        local camera=framing.fit(model,aspect,40)
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") and part.Transparency<1 then
                for _, x in {-1,1} do for _, y in {-1,1} do for _, z in {-1,1} do
                    local world=part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*0.5)
                    local point=camera:PointToObjectSpace(world)
                    assert(point.Z<0)
                    local projectedX=math.abs(point.X)/(-point.Z*math.tan(math.rad(20))*aspect)
                    local projectedY=math.abs(point.Y)/(-point.Z*math.tan(math.rad(20)))
                    assert(projectedX<=0.6501 and projectedY<=0.8801,string.format("Preview clips safety bounds scale=%s aspect=%s part=%s x=%s y=%s",scale,aspect,part.Name,projectedX,projectedY))
                end end end
            end
        end
        frameCases+=1
    end
    model:Destroy()
end
assert(framing.fit(sprint,0,40)==nil)
print("PASS: "..frameCases.." framing cases across sizes/aspects; invisible helpers ignored")
-- Garage orbit fit: wheels/bumper/rear stay in frame at a fixed distance for 360 degrees.
local orbitChecks=0
for _, aspect in {.9,1.5,2.4} do
 local fitted,target=framing.fit(sprint,aspect,40,true)
 local offset=fitted.Position-target
 local distance,pitch=offset.Magnitude,math.asin(offset.Y/offset.Magnitude)
 local maxWidth=0
 for degrees=0,355,5 do
  local yaw=math.rad(degrees)
  local direction=Vector3.new(math.sin(yaw)*math.cos(pitch),math.sin(pitch),math.cos(yaw)*math.cos(pitch))
  local right=Vector3.yAxis:Cross(direction).Unit
  local camera=CFrame.fromMatrix(target+direction*distance,right,direction:Cross(right),direction)
  for _,part in sprint:GetDescendants() do if part:IsA("BasePart") and part.Transparency<1 then
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    local point=camera:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5))
    assert(point.Z<0)
    local nx,ny=math.abs(point.X)/(-point.Z*math.tan(math.rad(20))*aspect),math.abs(point.Y)/(-point.Z*math.tan(math.rad(20)))
    assert(nx<=.801 and ny<=.941,"Kart orbit clips visible geometry")
    maxWidth=math.max(maxWidth,nx); orbitChecks+=1
   end end end
  end end
 end
 assert(maxWidth>=.65,"Kart orbit width must use stage: " .. maxWidth)
 print("KART ORBIT aspect=" .. aspect .. " width=" .. maxWidth)
end
print("PASS: "..orbitChecks.." production Kart full-orbit corner checks")
local priorFraming=luau.load(fs.readFile("src/shared/KartPreviewFraming.luau"):gsub("aspect%*%.80","aspect*.72"),{environment={Vector3=Vector3,CFrame=CFrame}})()
local oldFrame,target=priorFraming.fit(sprint,1.5,40,true)
local newFrame=framing.fit(sprint,1.5,40,true)
assert((newFrame.Position-target).Magnitude<(oldFrame.Position-target).Magnitude,"R1 expands actual kart beyond Phase 1B width fit")
-- The Garage-only map padding enlarges all three previews; racing minimaps retain the original fit.
local geometry=loadModule("src/shared/TrackGeometry.luau")
local tracks=loadModule("src/shared/TrackCatalog.luau")
local token={WaitForChild=function(self) return self end}
local renderer=luau.load(fs.readFile("src/client/TrackMapRenderer.luau"), {environment={
 Instance=Instance,Vector3=Vector3,Vector2=roblox.Vector2,UDim2=roblox.UDim2,UDim=roblox.UDim,
 Color3=Color3,Enum=roblox.Enum,game={GetService=function() return token end},script={Parent={MinimapDriverMarker='driver'}},
 require=function(m)return if m=='driver' then {} else geometry end}})()
for _,id in tracks.Order do
 local entry=tracks.Entries[id]
 local definition=geometry.getDefinition(entry.GeometryId)
 local panel=Instance.new("Frame")
 local preview=renderer.create(panel,definition,false,entry.PreviewRotationDegrees)
 local canvas=panel.CourseCanvas
 assert(canvas.Size==roblox.UDim2.fromScale(.96,.96) and canvas.Position==roblox.UDim2.fromScale(.5,.48))
 local course=geometry.getCourse(definition)
 local point=course.Samples[1]
 local b=course.Bounds
 local extent=math.max(b.MaxX-b.MinX,b.MaxZ-b.MinZ)*1.04
 local x,y=(point.X-(b.MinX+b.MaxX)*.5)/extent,-(point.Z-(b.MinZ+b.MaxZ)*.5)/extent
 local angle=math.rad(entry.PreviewRotationDegrees or 0)
 local mark=canvas.StartFinishMarker.Position
 assert(math.abs(mark.X.Scale-(.5+x*math.cos(angle)-y*math.sin(angle)))<.0001)
 assert(math.abs(mark.Y.Scale-(.5+x*math.sin(angle)+y*math.cos(angle)))<.0001)
 for _,segment in canvas:GetChildren() do if segment.Name=="CourseSegment" then
  assert(segment.Position.X.Scale>=.015 and segment.Position.X.Scale<=.985 and segment.Position.Y.Scale>=.015 and segment.Position.Y.Scale<=.985)
  assert(segment.Size.Y.Offset==7 and segment.BorderSizePixel==0 and segment:GetAttribute("GarageRoadRibbon"))
  assert(not segment.Active and #segment:GetChildren()==0,"Garage ribbon has zero additional segment instances")
 end end
 preview:destroy(); panel:Destroy()
 local racePanel=Instance.new("Frame"); local race=renderer.create(racePanel,definition,true,0)
 assert(racePanel.CourseCanvas.Size==roblox.UDim2.fromScale(.92,.92),"gameplay minimap geometry unchanged")
 for _,segment in racePanel.CourseCanvas:GetChildren() do if segment.Name=="CourseSegment" then
  assert(segment.Size.Y.Offset==3 and segment.BackgroundColor3==Color3.fromRGB(220,228,233)
   and #segment:GetChildren()==0,"race minimap retains original thin-line style")
 end end
 race:destroy(); racePanel:Destroy()
end
assert(tracks.Entries.Track01Race.PreviewRotationDegrees==90)
print("PASS: three enlarged track previews, Start/Finish orientation and unchanged racing minimap")
-- Compile all current scripts: rojo packages source but does not parse Luau.
local compiled=0
local function compileTree(dir)
    for _, name in fs.readDir(dir) do
        local path=dir.."/"..name
        if fs.isDir(path) then compileTree(path)
        elseif string.match(name,"%.luau$") then luau.compile(fs.readFile(path)); compiled+=1 end
    end
end
compileTree("src")
print("PASS: "..compiled.." Luau scripts compiled")
