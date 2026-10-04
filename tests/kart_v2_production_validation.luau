local fs = require('@lune/fs')
local luau = require('@lune/luau')
local rb = require('@lune/roblox')
local serde = require('@lune/serde')
rb.implementMethod('Model','PivotTo',function(model, frame)
 local delta=frame*model.PrimaryPart.CFrame:Inverse()
 for _,part in model:GetDescendants() do
  if part:IsA('BasePart') then part.CFrame=delta*part.CFrame end
 end
end)
rb.implementProperty('Seat','Occupant',function() return nil end)
local checks = 0
local function check(value, label)
 assert(value, label); checks += 1
end
local env = {Instance=rb.Instance,Vector3=rb.Vector3,Vector2=rb.Vector2,
 CFrame=rb.CFrame,Color3=rb.Color3,Enum=rb.Enum}
local shared = rb.Instance.new('Folder')
local template = rb.deserializeModel(fs.readFile('src/shared/KDMV2Geometry.rbxmx'))[1]
template.Parent = shared
local definitionScript = rb.Instance.new('ModuleScript')
definitionScript.Name = 'KDMV2VisualDefinition'; definitionScript.Parent = shared
env.script = definitionScript
local builder = luau.load(fs.readFile('src/shared/KDMV2VisualDefinition.luau'),{environment=env})()
env.require = function(module) assert(module == definitionScript); return builder end
local factory = luau.load(fs.readFile('src/shared/KartVisualFactory.luau'),{environment=env})()
local catalog = luau.load(fs.readFile('src/shared/KartCatalog.luau'),{environment=env})()
check(catalog.DefaultId=='Kart01' and #catalog.Order==11,'fallback and eleven selections')
local sprintSeat=rb.CFrame.new(0,1.5,.5)
local v2Seat=builder.DriverSeatLocalCFrame
check(v2Seat:FuzzyEq(rb.CFrame.new(0,.06000018119812012,.5),.000001),'measured source-to-bucket Seat contract')
check(v2Seat~=sprintSeat,'V2 cannot accidentally retain Sprint Seat')
for index=1,4 do
 check(factory.getDriverSeatLocalCFrame(catalog.Entries['Kart0'..index])==sprintSeat,'Sprint Seat unchanged')
end
check(factory.getDriverSeatLocalCFrame(catalog.Entries.Kart05)==v2Seat
 and factory.getDriverSeatLocalCFrame(catalog.Entries.Kart06)==v2Seat
 and factory.getDriverSeatLocalCFrame(catalog.Entries.Kart07)==v2Seat
 and factory.getDriverSeatLocalCFrame(catalog.Entries.Kart08)==v2Seat,'all four KDM V2 colours share one Seat contract')
check(not pcall(factory.getDriverSeatLocalCFrame,{VisualModelName='Unknown'}),'unknown model rejects accidental Seat fallback')
local fixture = serde.decode('json',fs.readFile('tests/fixtures/kart_v2_geometry.json'))
local function atPath(model, path)
 local result = model
 for _, name in path do result = assert(result:FindFirstChild(name),name) end
 return result
end
local cyan = factory.createVisual(catalog.Entries.Kart05)
local red = factory.createVisual(catalog.Entries.Kart06)
local v2Ids={'Kart05','Kart06','Kart07','Kart08','Kart09','Kart10','Kart11'}
local expectedTextures={Kart05='rbxassetid://125161174512041',Kart06='rbxassetid://72401332261563',Kart07='rbxassetid://78740378285144',Kart08='rbxassetid://89811969782185',Kart09='rbxassetid://93538186999394',Kart10='rbxassetid://71205439249164',Kart11='rbxassetid://79376379465815'}
local builtVisuals={Kart05=cyan,Kart06=red,Kart07=factory.createVisual(catalog.Entries.Kart07),Kart08=factory.createVisual(catalog.Entries.Kart08)}
for _,id in {'Kart09','Kart10','Kart11'} do builtVisuals[id]=factory.createVisual(catalog.Entries[id]) end
for _, id in v2Ids do
 check(factory.getDriverSeatLocalCFrame(catalog.Entries[id])==v2Seat,'seven variants preserve Seat contract')
 local entry = catalog.Entries[id]
 local visual = builtVisuals[id]
 check(entry.VisualModelName=='KDMV2','shared geometry identity')
 check(factory.validateVisual(visual),'production motion/exhaust root contract')
 check(visual:GetAttribute('VisualVariant')==entry.VisualVariant,'variant identity')
 local body=visual.StaticRoot.CurvedBody
 check(body.TextureID==expectedTextures[id],'exact uploaded R2F texture')
 check(body.Material==(if id=='Kart06' or id=='Kart09' or id=='Kart10' or id=='Kart11' then rb.Enum.Material.Metal else rb.Enum.Material.SmoothPlastic),'exact variant material')
 check(body.Color==rb.Color3.new(1,1,1) and body.Reflectance==0,'no multiplied tint')
 local parts, meshes, exhaust = 0,0,{ExhaustLeft=0,ExhaustRight=0}
 for _, instance in visual:GetDescendants() do
  check(not instance:IsA('LuaSourceContainer') and not instance:IsA('RemoteEvent')
   and not instance:IsA('RemoteFunction') and not instance:IsA('Seat')
   and not instance:IsA('VehicleSeat') and not instance:IsA('BodyMover')
   and not instance:IsA('SurfaceGui'),'sanitized visual')
  if instance:IsA('BasePart') then
   parts+=1
   check(not instance.CanCollide and not instance.CanTouch and not instance.CanQuery
    and instance.Massless and not instance.Anchored,'visual has no physics contribution')
  end
  if instance:IsA('MeshPart') then meshes+=1 end
  if instance:IsA('Attachment') and exhaust[instance:GetAttribute('EffectRole')] then
   exhaust[instance:GetAttribute('EffectRole')]+=1
  end
 end
 check(parts==22 and meshes==11,'locked 22 BaseParts / 11 MeshParts')
 check(exhaust.ExhaustLeft==1 and exhaust.ExhaustRight==1,'exact exhaust attachment counts')
 for _, row in fixture do
  if row.size then
   local part=atPath(visual,row.path)
   check(part.ClassName==row.class and part.Size:FuzzyEq(rb.Vector3.new(table.unpack(row.size)),.00001),'approved size/class')
   check(part.CFrame:FuzzyEq(rb.CFrame.new(table.unpack(row.cf)),.00001),'approved local position/orientation')
   if row.mesh then
    check(part.MeshContent.Uri==row.mesh,'approved original mesh')
    check(part.InitialSize:FuzzyEq(rb.Vector3.new(table.unpack(row.meshSize)),.00002),'native serialized mesh size is preserved')
   end
   if part.Name=='Engine' or part.Name=='Link' or part.Name=='Frame' then
    local expectedColor=if id=='Kart06' then rb.Color3.fromRGB(18,20,24) elseif part.Name=='Engine' then rb.Color3.fromRGB(215,28,38) else rb.Color3.fromRGB(205,211,218)
    check(part.Material==rb.Enum.Material.Metal and part.Color==expectedColor,'explicit mechanical palette')
    check(part.TextureContent.Uri==atPath(template,row.path).TextureContent.Uri,'mechanical source texture preserved')
   elseif part.Name~='CurvedBody' then
    check(part.Material==rb.Enum.Material[row.material]
     and part.Color==rb.Color3.new(table.unpack(row.color)),'mechanical materials preserved')
   end
   for name,value in row.attributes do
    if name~='AuditSourcePath' then check(part:GetAttribute(name)==value,'approved wheel/motion metrics') end
   end
  elseif row.class=='Attachment' then
   check(atPath(visual,row.path).CFrame:FuzzyEq(rb.CFrame.new(table.unpack(row.cf)),.00001),'approved exhaust anchor')
  end
 end
end
local engineBefore=cyan.StaticRoot.Engine.Color
factory.applyAppearance(cyan,catalog.Entries.Kart06)
check(cyan.StaticRoot.CurvedBody.TextureID==red.StaticRoot.CurvedBody.TextureID,'appearance switches texture')
check(cyan.StaticRoot.Engine.Color==rb.Color3.fromRGB(18,20,24),'Red keeps red body with black engine')
factory.applyAppearance(cyan,catalog.Entries.Kart05)
check(cyan.StaticRoot.Engine.Color==engineBefore and cyan.StaticRoot.Link.Color==rb.Color3.fromRGB(205,211,218),'switching back restores red/silver palette')
for index=1,4 do
 local entry=catalog.Entries['Kart0'..index]
 check(entry.VisualModelName=='SprintV1' and factory.validateVisual(factory.createVisual(entry)),'Sprint fallback remains valid')
end

-- Execute the actual production assembly-binding and vacant-context selection
-- helpers, with real Instances. The source guards also cover their callers so
-- an always-DefaultId regression at create/acquire cannot pass this model probe.
local source=fs.readFile('src/server/PrototypeWorld.luau')
local start=assert(source:find('local function weldToChassis',1,true))
local finish=assert(source:find('local function createKart(',start,true))
local helpers=source:sub(start,finish-1)..'\nreturn {bind=bindVisual,select=selectVisual,definition=kartDefinition}'
env.KartVisualFactory=factory; env.KartCatalog=catalog
local binding=luau.load(helpers,{environment=env})()
local kart=rb.Instance.new('Model')
local chassis=rb.Instance.new('Part'); chassis.Name='Chassis'; chassis.Parent=kart
local seat=rb.Instance.new('Seat'); seat.Parent=kart
seat.CFrame=chassis.CFrame*rb.CFrame.new(0,1.5,.5)
local context={kart=kart,chassis=chassis,seat=seat}
binding.bind(kart,chassis,catalog.Entries.Kart01)
for _,id in {'Kart05','Kart06','Kart07','Kart08','Kart09','Kart10','Kart11','Kart01','Kart05'} do
 check(binding.select(context,binding.definition(id)),'vacant context accepts selected kart')
 local visual=kart.Visual
 check(visual:GetAttribute('VisualModelName')==catalog.Entries[id].VisualModelName,'selected geometry is actually rebound')
 check(kart:GetAttribute('KartId')==id,'context selection identity')
 check(seat.Parent==kart and seat.CFrame:FuzzyEq(chassis.CFrame*factory.getDriverSeatLocalCFrame(catalog.Entries[id]),.00001),'same Seat adopts selected model contract')
 check(chassis.CFrame==rb.CFrame.identity,'vacant Seat rebind does not move Chassis')
 local welds=0
 for _,joint in seat:GetChildren() do
  if joint:IsA('WeldConstraint') then
   welds+=1;check(joint.Part0==chassis and joint.Part1==seat,'Seat weld stays on original Chassis')
  end
 end
 check(welds==1,'Seat rebind leaves exactly one weld')
 for _,root in visual:GetChildren() do
  if root:GetAttribute('VisualMotionRole') then
   check(root.VisualMotor.Part0==chassis and root.VisualMotor.Part1==root,'production animated root binding')
  end
 end
end
local proxy={kart=kart,chassis=chassis,seat={Occupant={}}}
check(not binding.select(proxy,catalog.Entries.Kart06),'occupied mismatched context is rejected')
check(kart:GetAttribute('KartId')=='Kart05','rejection preserves occupied visual')
check(binding.definition('invalid')==catalog.Entries.Kart01,'invalid selection safely falls back')
check(source:find('local definition = kartDefinition(kartId)',1,true)~=nil
 and source:find('bindVisual(kart, chassis, definition)',1,true)~=nil,'createKart uses requested definition')
check(source:find('seat.CFrame = spawnCFrame * KartVisualFactory.getDriverSeatLocalCFrame(definition)',1,true)~=nil,'actual new Seat uses centralized contract')
check(source:find('selectVisual(existing, definition)',1,true)~=nil
 and source:find('selectVisual(defaultContext, definition)',1,true)~=nil,'owned and prebuilt contexts validate selection')
check(source:find('createKart(prototype, startCFrame, "Kart", definition.Id)',1,true)~=nil
 and source:find('"Kart_" .. tostring(player.UserId), kartId)',1,true)~=nil,'new contexts pass selection to actual createKart')
check(fs.readFile('src/server/RaceServerBootstrap.luau'):find('acquireKartContext(player, spawnCFrame, plan.kartId)',1,true)~=nil,'reserved arrival forwards validated kartId')
check(fs.readFile('src/server/GarageController.luau'):find('acquireKartContext(player, gridCFrame, kartSelection.Id)',1,true)~=nil,'Garage race launch forwards selection')
print('PASS: '..checks..' V2 production checks; geometry 22/22, MeshParts 11/11, variants, safety, binding and selection')
