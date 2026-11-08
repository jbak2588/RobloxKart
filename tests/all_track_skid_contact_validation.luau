local rb=require('@lune/roblox')
local fs, luau = require('@lune/fs'), require('@lune/luau')
require('./helpers/world_vfx_harness')(1,1,function(h)
 local track=h.prototype:FindFirstChild('TestTrack')
 local road=track:FindFirstChild('Road'):GetChildren()[1]
 road.Position=rb.Vector3.new(0,-.5,0);road.CanQuery=false
 local kart=h.karts[1]
 for _,row in {{'Track01','PracticeFigure8V1'},{'Track01Desert','PracticeFigure8V1'},{'Track01Race','PracticeCircuitV1'},{'Track01Metro','PracticeCircuitV1'},{'Track03','HardCircuitV1'}}do
  track:SetAttribute('TrackId',row[1]);track:SetAttribute('GeometryId',row[2]);h.workspace.noGround=true
  kart:SetAttribute('KartDrifting',true);kart.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.new(20,0,-50)
  local renderer=h.modules.exhaust.new(kart);local before=h.workspace.rayCount or 0
  renderer:update(.05,true);local enabled=0
  for _,t in kart:GetDescendants()do if t.Name=='DriftTireTrail'and t.Enabled then enabled+=1;assert(math.abs(t.Attachment0.WorldPosition.Y-.04)<.001)end end
  assert(enabled==2,row[1]..' two grounded tire marks');assert((h.workspace.rayCount or 0)==before,'no raycast requirement')
  kart.PrimaryPart.CFrame=rb.CFrame.new(0,10,0);renderer:update(.05,true)
  for _,t in kart:GetDescendants()do if t.Name=='DriftTireTrail'then assert(not t.Enabled,'no airborne mark')end end
  kart.PrimaryPart.CFrame=rb.CFrame.new(150,0,0);renderer:update(.05,true)
  for _,t in kart:GetDescendants()do if t.Name=='DriftTireTrail'then assert(not t.Enabled,'no off-road mark')end end
  renderer:destroy();kart.PrimaryPart.CFrame=rb.CFrame.identity
  print('PASS skid:',row[1])
 end
 local shared = h.object("Folder")
 shared.Name, shared.Parent = "Shared", h.replicatedStorage
 local function loadShared(name)
  local node = h.object("ModuleScript")
  node.Name, node.Parent = name, shared
  local result = luau.load(fs.readFile("src/shared/" .. name .. ".luau"), {environment = {
   Vector3 = rb.Vector3, Vector2 = rb.Vector2, script = {Parent = shared},
   require = function(module) return assert(h.modules[module]) end,
  }})()
  h.modules[node] = result
  return result
 end
 loadShared("TrackGeometry")
 local nose = loadShared("EliphantGeometry")
 loadShared("SuperZRoadPolicy")
 loadShared("EliphantRoadPolicy")
 local function enabledTrails(expectedY)
  local count = 0
  for _, trail in kart:GetDescendants() do
   if trail.Name == "DriftTireTrail" and trail.Enabled then
    count += 1
    assert(math.abs(trail.Attachment0.WorldPosition.Y - expectedY) < .001, "mark above visible asphalt")
   end
  end
  return count
 end
 for _, case in {
  {"SuperZV1", rb.Vector3.new(150, 0, 12), .02},
  {"SuperZV1", rb.Vector3.new(620, 0, 486), .02},
  {"EliphantNoseR2", nose.A[2].P, .0625},
  {"EliphantNoseR2", nose.B[2].P, .0625},
 } do
  local geometryId, point, offset = table.unpack(case)
  track:SetAttribute("GeometryId", geometryId)
  track:SetAttribute("GroundTop", nil)
  local renderer = h.modules.exhaust.new(kart)
  kart.PrimaryPart.CFrame = rb.CFrame.new(point + rb.Vector3.yAxis * 3)
  local rayCount = h.workspace.rayCount or 0
  renderer:update(.05, true)
  assert(enabledTrails(0) == 0, "wait for the replicated asphalt height")
  track:SetAttribute("GroundTop", 3)
  renderer:update(.05, true)
  assert(enabledTrails(3 + offset + .04) == 2, geometryId .. " two marks on the paved domain")
  kart.PrimaryPart.CFrame = rb.CFrame.new(point + rb.Vector3.yAxis * 13)
  renderer:update(.05, true)
  assert(enabledTrails(0) == 0, "no marks while airborne")
  kart.PrimaryPart.CFrame = rb.CFrame.new(2000, 3, 2000)
  renderer:update(.05, true)
  assert(enabledTrails(0) == 0, "no marks on off-track ground")
  assert((h.workspace.rayCount or 0) == rayCount, "flat road contact uses no raycasts")
  renderer:destroy()
  kart.PrimaryPart.CFrame = rb.CFrame.identity
 end
 print("PASS skid: Super Z straight and widened corner, Eliphant Nose A/B")
 local park=h.object('Folder');park.Name='HubParkRookieLoopG2';park:SetAttribute('DriveGeometry','ROOKIE_LOOP_V1');park.Parent=h.workspace
 local support=h.object('Folder');support.Name='G2SafetyGround';support.Parent=park
 kart.Parent=park;kart:SetAttribute('LobbyKart',true);h.workspace.noGround=false
 local renderer=h.modules.exhaust.new(kart);renderer:update(.05,true);local enabled=0
 for _,t in kart:GetDescendants()do if t.Name=='DriftTireTrail'and t.Enabled then enabled+=1;assert(math.abs(t.Attachment0.WorldPosition.Y-.06)<.001,'current Park road .02 + .04 trail lift')end end
 assert(enabled==2,'Park two marks');renderer:destroy();kart.Parent=h.prototype;kart:SetAttribute('LobbyKart',false);kart:SetAttribute('KartDrifting',false);kart.PrimaryPart.AssemblyLinearVelocity=rb.Vector3.zero
 print('PASS skid: Park .02 surface height')
end)
