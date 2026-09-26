-- Run from repository root: lune run tests/kart_visual_validation.luau
-- Uses Lune's Roblox data model, not the Studio physics/render engine.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame, Color3 = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3
local function loadModule(path)
    return luau.load(fs.readFile(path), { debugName=path, environment={Instance=Instance, Vector3=Vector3, CFrame=CFrame, Color3=Color3, Enum=roblox.Enum} })()
end
local factory = loadModule("src/shared/KartVisualFactory.luau")
local catalog = loadModule("src/shared/KartCatalog.luau")
local definition = catalog.Entries[catalog.DefaultId]
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
assert((sprint.SteeringPivot.CFrame.Position-Vector3.new(0,1.65,-1.05)).Magnitude < 0.00001)
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
