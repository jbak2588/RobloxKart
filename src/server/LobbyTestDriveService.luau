local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Physics=game:GetService("PhysicsService")
local Workspace=game:GetService("Workspace")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Policy=require(Shared:WaitForChild("LobbyDrivePolicy"))
local Geometry=require(Shared:WaitForChild("LobbyDriveGeometry")).create(Policy)
local KartConfig=require(Shared:WaitForChild("KartConfig"))
local Catalog=require(Shared:WaitForChild("KartCatalog"))
local Factory=require(Shared:WaitForChild("KartVisualFactory"))
local Drift=require(script.Parent.LobbyDriftSession)
local Practice=require(script.Parent.LobbyPracticeCombat)
local Qualification=require(script.Parent.TestDriveQualification)
local Presence=require(script.Parent.LobbyDrivePresence)
local StraightSpeedResolver=require(script.Parent.KDMStraightSpeedResolver)
local Service={}
local records,generations,bindings,lastRequest={},{},{},{}
local closing={}
local started,remote,zone,canEnter,straightCourse=false,nil,nil,nil,nil
local practice
local presence
local forwardSpeed=Policy.Forward
local function allowedHub()
 if zone and zone.GetAttribute and zone:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1'then
  return require(Shared:WaitForChild('HubParkRuntimePolicy')).enabled(Workspace,RunService:IsStudio(),game.GameId,game.PlaceId)
 end
 return Policy.isGlobalHub(Workspace:GetAttribute('KDMServerRole'),game.PrivateServerId,Workspace:GetAttribute('KDMEnableRaceBot')==true)
end
local function generation(player)
 generations[player]=(generations[player] or 0)+1
 player:SetAttribute("LobbyDriveGeneration",generations[player]);return generations[player]
end
function Service.configureCollision()
 for _,name in {"LobbyKart","LobbyAvatar","LobbyBoundary"} do
  if not Physics:IsCollisionGroupRegistered(name) then Physics:RegisterCollisionGroup(name) end
 end
 Physics:CollisionGroupSetCollidable("LobbyKart","LobbyKart",false)
 Physics:CollisionGroupSetCollidable("LobbyKart","LobbyAvatar",false)
 Physics:CollisionGroupSetCollidable("LobbyKart","Default",true)
 Physics:CollisionGroupSetCollidable("LobbyAvatar","Default",true)
 Physics:CollisionGroupSetCollidable("LobbyBoundary","Default",false)
 Physics:CollisionGroupSetCollidable("LobbyBoundary","LobbyAvatar",false)
 Physics:CollisionGroupSetCollidable("LobbyBoundary","LobbyKart",true)
 for _,name in {"RacerKart","RacerDriver"} do
  if Physics:IsCollisionGroupRegistered(name) then
   Physics:CollisionGroupSetCollidable("LobbyBoundary",name,false)
   Physics:CollisionGroupSetCollidable("LobbyKart",name,false)
  end
 end
end
local function restoreCharacter(player)
 local binding=bindings[player];if not binding then return end
 binding.added:Disconnect()
 for part,original in binding.parts do if part.Parent then part.CollisionGroup=original end end
 bindings[player]=nil
end
local function bindCharacter(player,character)
 restoreCharacter(player)
 if not started then return end
 local parts={}
 local function assign(part)
  if part:IsA("BasePart") then parts[part]=part.CollisionGroup;part.CollisionGroup="LobbyAvatar" end
 end
 for _,part in character:GetDescendants() do assign(part) end
 bindings[player]={parts=parts,added=character.DescendantAdded:Connect(assign)}
end
local function inside(position,margin)
 local c=zone:GetAttribute("Center");return Geometry.inside(position.X-c.X,position.Z-c.Z,margin)
end
function Service.stop(player,reason,returnToHub)
 local pending=closing[player]
 if pending then
  if not returnToHub then pending.returnToHub=false end
  while closing[player]==pending do RunService.Heartbeat:Wait() end
  return true,pending.returned==true
 end
 local record=records[player]
 if not record then return true,false end
 if practice then practice:remove(player)end
 record.returnToHub=returnToHub;closing[player]=record
 records[player]=nil;generation(player)
 record.throttle,record.steering,record.speed=0,0,0
 player:SetAttribute("LobbyDrivePending",true);player:SetAttribute("LobbyDriveActive",false)
 if presence then presence:refresh() end
 if record.destroying then record.destroying:Disconnect() end
 if record.occupantConnection then record.occupantConnection:Disconnect() end
 if record.kart.Parent then
  record.body.AssemblyLinearVelocity=Vector3.zero;record.body.AssemblyAngularVelocity=Vector3.zero
  record.body.Anchored=true
 end
 if record.humanoid.Parent then record.humanoid.Sit=false;record.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
 -- Seat ownership must settle before character placement. A timed-out seat is
 -- destroyed, then two physics frames drain its deferred weld/occupant updates.
 local deadline=os.clock()+.5
 while record.humanoid.Parent and (record.humanoid.SeatPart==record.seat or record.seat.Occupant==record.humanoid) and os.clock()<deadline do RunService.Heartbeat:Wait() end
 record.kart:Destroy()
 RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()
 local function validReturn()
  return record.returnToHub and player.Parent and player.Character==record.character
   and record.character.Parent and record.humanoid.Health>0 and not record.humanoid.SeatPart
   and player:GetAttribute("RaceState")=="GARAGE" and player:GetAttribute("KDMRoutePending")~="RACE_LAUNCH"
 end
 if validReturn() then
  local hub=Workspace:FindFirstChild("KDMHub");local spawn=hub and hub:FindFirstChild("HubSpawn")
  if spawn then
   local root=record.character:FindFirstChild("HumanoidRootPart")
   if root then root:SetNetworkOwner(nil) end
   record.character:PivotTo(spawn.CFrame*CFrame.new(0,3,0))
   if root then root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
   record.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
   RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()
   if root and root.Parent then root:SetNetworkOwnershipAuto() end
   if validReturn() then
   record.returned=true
   player:SetAttribute("HubArrivalSerial",(player:GetAttribute("HubArrivalSerial") or 0)+1)
   end
  end
 end
 player:SetAttribute("LobbyDriveKartId",nil);player:SetAttribute("LobbyDrivePending",false)
 closing[player]=nil
 return true,record.returned==true
end
local function createKart(player,definition,frame)
 local kart=Instance.new("Model");kart.Name="LobbyKart_"..player.UserId
 kart:SetAttribute("LobbyKart",true);kart:SetAttribute("LobbyOwnerUserId",player.UserId)
 kart:SetAttribute("KartId",definition.Id);kart:SetAttribute("KartVisualSteering",0)
 local body=Instance.new("Part");body.Name="Chassis";body.Size=Vector3.new(6,1,8)
 body.CFrame=frame;body.Transparency=1;body.CanCollide=true;body.CanTouch=false
 body.RootPriority=127;body.CustomPhysicalProperties=PhysicalProperties.new(1,.05,0,100,100);body.Parent=kart
 kart.PrimaryPart=body
 local function join(part,motor)
  local joint=Instance.new(if motor then "Motor6D" else "WeldConstraint")
  joint.Name=if motor then "VisualMotor" else "LobbyWeld"
  joint.Part0=body;joint.Part1=part
  if motor then joint.C0=body.CFrame:ToObjectSpace(part.CFrame);joint.C1=CFrame.identity end
  joint.Parent=part
 end
 local visual=Factory.createVisual(definition,player:GetAttribute('KDMWingOwned')==true and player:GetAttribute('KDMWingEquipped')==true);visual:PivotTo(frame);visual.Parent=kart
 for _,part in visual:GetChildren() do if part:IsA("BasePart") then
  if part.Name=="StaticRoot" then join(part,false) elseif part:GetAttribute("VisualMotionRole") then join(part,true) end
 end end
 local seat=Instance.new("Seat");seat.Name="Seat";seat.Size=Vector3.new(2.5,0.1,2.5)
 seat.CFrame=frame*Factory.getDriverSeatLocalCFrame(definition)
 seat.Transparency=1;seat.CanCollide=false;seat.CanTouch=false;seat.CanQuery=false;seat.Massless=true
 seat:SetAttribute("LobbyKartSeat",true);seat.Parent=kart;join(seat,false)
 for _,part in kart:GetDescendants() do if part:IsA("BasePart") then part.CollisionGroup="LobbyKart" end end
 kart.Parent=zone;body:SetNetworkOwner(nil)
 return kart,body,seat
end
local function drive(player,previewKartId)
 if not started or not allowedHub()
  or player:GetAttribute("RaceState")~="GARAGE" or player:GetAttribute("KDMRoutePending")=="RACE_LAUNCH"
  or player:GetAttribute("LobbyDrivePending")==true or (canEnter and not canEnter(player)) then return false,"DRIVE UNAVAILABLE" end
 -- Showroom previews are temporary, free V2 visuals; selection/persistence is
 -- still owned by Garage. Reject unknown ids, payloads and non-showroom families.
 if previewKartId~=nil and (type(previewKartId)~="string" or not Catalog.Entries[previewKartId]
  or Catalog.Entries[previewKartId].VisualModelName~="KDMV2")then return false,"SELECT A KART"end
 if records[player] then return true end
 local character=player.Character;local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not humanoid or humanoid.Health<=0 or humanoid.SeatPart or not root then return false,"DRIVE UNAVAILABLE" end
 local hub=zone.Parent;local spawn=hub:FindFirstChild("HubSpawn")
 if not inside(root.Position,0) and (not spawn or (root.Position-spawn.Position).Magnitude>140) then return false,"RETURN TO LOBBY" end
 local definition=Catalog.Entries[player:GetAttribute("SelectedKartId") or Catalog.DefaultId]
 if previewKartId then definition=Catalog.Entries[previewKartId] end
 if not definition then return false,"SELECT A KART" end
 local gen=generation(player);player:SetAttribute("LobbyDrivePending",true)
 local frame=zone.LobbyFrontDriveStart.CFrame
 -- Side-by-side/non-contact start slots, all on the straight, never at the display anchor.
 local occupied={};for _,r in records do occupied[r.slot]=true end
 local slot=0;while occupied[slot] do slot+=1 end
 local starts=zone:FindFirstChild('StartSlots')
 if starts then
  local a=starts:FindFirstChild(tostring(slot+1))
  if not a then player:SetAttribute('LobbyDrivePending',false);return false,'DRIVE ZONE BUSY'end
  frame=a.CFrame
 else frame=frame*CFrame.new((slot%3-1)*8,0,-math.floor(slot/3)*16)end
 if not inside(frame.Position,Policy.FootprintMargin) then player:SetAttribute("LobbyDrivePending",false);return false,"DRIVE ZONE BUSY" end
 local ok,kart,body,seat=pcall(createKart,player,definition,frame)
 if not ok then player:SetAttribute("LobbyDrivePending",false);warn("[LobbyDrive] "..tostring(kart));return false,"DRIVE UNAVAILABLE" end
 local record={qualification=Qualification.new(),kart=kart,body=body,seat=seat,humanoid=humanoid,character=character,generation=gen,
  throttle=0,steering=0,speed=0,yaw=0,lastInput=os.clock(),safe=frame,boundaryPrevious=frame.Position,slot=slot,seated=false,training=Drift.new()}
 records[player]=record
 record.occupantConnection=seat:GetPropertyChangedSignal("Occupant"):Connect(function()
  local occupant=seat.Occupant
  if occupant and occupant~=humanoid then occupant.Sit=false;Service.stop(player,"wrong_occupant",true)
  elseif not occupant and record.seated then Service.stop(player,"unseated",true) end
 end)
 record.destroying=kart.Destroying:Connect(function() Service.stop(player,"destroyed",false) end)
 seat:Sit(humanoid)
 local deadline=os.clock()+1.5
 while records[player]==record and player.Character==character and humanoid.Health>0
  and not (seat.Occupant==humanoid and humanoid.SeatPart==seat) and os.clock()<deadline do RunService.Heartbeat:Wait() end
 if records[player]~=record then return false,"DRIVE CANCELLED" end
 if seat.Occupant~=humanoid or humanoid.SeatPart~=seat or player.Character~=character or humanoid.Health<=0 then
  Service.stop(player,"sit_failed",true);return false,"COULD NOT ENTER KART"
 end
 record.seated=true;if practice then practice:add(player,record)end;player:SetAttribute("LobbyDriveKartId",definition.Id)
 player:SetAttribute("LobbyDriveActive",true);player:SetAttribute("LobbyDrivePending",false)
 if presence then presence:refresh() end
 return true
end
function Service.start(driveZone,eligibility)
 if started then return end
 if not driveZone then return end
 zone=driveZone
 if not allowedHub()then zone=nil;return end
 forwardSpeed=Policy.forwardSpeed(driveZone:GetAttribute('DriveGeometry'),KartConfig)
 Geometry=if zone.GetAttribute and zone:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1'then require(Shared:WaitForChild('RookieLoopDriveGeometry')).create()else require(Shared:WaitForChild('LobbyDriveGeometry')).create(Policy)
 if zone.GetAttribute and zone:GetAttribute('DriveGeometry')=='ROOKIE_LOOP_V1' and KartConfig.STRAIGHT_SPEED_ENABLED then
  local Layout=require(Shared:WaitForChild('HubParkRookieLoopLayout'))
  local pts=Layout.sample(Layout.Segments)
  local samples={}
  for i=1,#pts-1 do table.insert(samples,Vector3.new(pts[i].x,0,pts[i].z)) end
  straightCourse=StraightSpeedResolver.precompute(samples,KartConfig,Layout.RoadWidth)
 else straightCourse=nil end
 started,zone,canEnter=true,driveZone,eligibility
 presence=Presence.new(zone,records)
 Service.configureCollision()
 practice=Practice.new(zone,records,Geometry)
 remote=Instance.new("RemoteEvent");remote.Name="LobbyDriveControl";remote.Parent=ReplicatedStorage
 local connections={}
 zone.Destroying:Connect(function()
  started=false
  for _,player in Players:GetPlayers() do
   Service.stop(player,"zone_removed",false);restoreCharacter(player)
   player:SetAttribute("LobbyDriveAvailable",false)
  end
  practice:destroy();practice=nil
 end)
 local function bind(player)
  generation(player);player:SetAttribute("LobbyDriveAvailable",true)
  player:SetAttribute("LobbyDriveActive",false);player:SetAttribute("LobbyDrivePending",false)
  if player.Character then bindCharacter(player,player.Character) end
  local list={
   player.CharacterAdded:Connect(function(character) Service.stop(player,"respawn",false);bindCharacter(player,character) end),
   player.CharacterRemoving:Connect(function() Service.stop(player,"character_removed",false);restoreCharacter(player) end),
   player:GetAttributeChangedSignal("RaceState"):Connect(function() if player:GetAttribute("RaceState")~="GARAGE" then Service.stop(player,"state",false) end end),
   player:GetAttributeChangedSignal("KDMRoutePending"):Connect(function() if player:GetAttribute("KDMRoutePending")=="RACE_LAUNCH" then Service.stop(player,"launch",false) end end),
   player:GetAttributeChangedSignal("SelectedKartId"):Connect(function() Service.stop(player,"selection",true) end),
  };connections[player]=list
 end
 for _,player in Players:GetPlayers() do bind(player) end
 Players.PlayerAdded:Connect(bind)
 Players.PlayerRemoving:Connect(function(player)
  Service.stop(player,"leave",false);restoreCharacter(player)
  for _,c in connections[player] or {} do c:Disconnect() end
  connections[player],generations[player],lastRequest[player]=nil,nil,nil
 end)
 remote.OnServerEvent:Connect(function(player,action,id,first,second,drift,...)
  if action=='UseItem'then
   if second~=nil or drift~=nil or select('#',...)>0 then return end
   if practice then practice:use(player,id,first)end;return
  end
  if action=="Input" then
   local r=records[player]
   if not r or not r.seated or id~=r.generation or not Policy.validAxes(first,second)
    or player.Character~=r.character or r.humanoid.Health<=0 or r.seat.Occupant~=r.humanoid or r.humanoid.SeatPart~=r.seat
    or player:GetAttribute("RaceState")~="GARAGE" or player:GetAttribute("KDMRoutePending")=="RACE_LAUNCH" then return end
   -- Preserve release/press edges even between regular input packets, as in race.
   if os.clock()-r.lastInput<1/90 and (drift==true)==r.drift then return end
   Drift.input(r.training,drift==true,os.clock(),os.clock()-r.lastInput<=Policy.InputTimeout)
   r.throttle,r.steering,r.lastInput=math.clamp(first,-1,1),math.clamp(second,-1,1),os.clock();r.drift=drift==true;return
  end
  if type(id)~="number" or id~=id or id<0 or id>1e9 or id%1~=0 then return end
  if action=="Drive" then
   local now=os.clock();if now-(lastRequest[player] or -1e9)<.6 then remote:FireClient(player,"Reply",id,generations[player],false,"PLEASE WAIT");return end
   lastRequest[player]=now;local ok,message=drive(player,first)
   remote:FireClient(player,"Reply",id,generations[player],ok,message)
  elseif action=="Stop" then
   local _,returned=Service.stop(player,"exit",true)
   local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   local deadline=os.clock()+.5
   while h and h.Parent and h.SeatPart and os.clock()<deadline do RunService.Heartbeat:Wait() end
   remote:FireClient(player,"Reply",id,generations[player],h==nil or h.SeatPart==nil,"EXIT KART",returned)
  end
 end)
 -- Keep containment and the existing barrier response independent of an item
 -- update error. Roblox dispatches the driving listener separately.
 RunService.Heartbeat:Connect(function(dt)
  if started and practice then practice:update(os.clock(),math.min(dt,.05)) end
 end)
 RunService.Heartbeat:Connect(function(dt)
  dt=math.min(dt,.05)
  if not started or not practice then return end
  for player,r in records do
   if not r.seated then continue end
   if not r.body.Parent or player.Character~=r.character or r.humanoid.Health<=0
    or r.humanoid.SeatPart~=r.seat or r.seat.Occupant~=r.humanoid then Service.stop(player,"seat_lost",true);continue end
   local body=r.body;local pos=body.Position;local c=zone:GetAttribute("Center")
   local groundY=c.Y+(if Geometry.height then Geometry.height(pos.X-c.X,pos.Z-c.Z)else 0)
   local previous=r.boundaryPrevious
   local crossed=previous and Geometry.crossesBoundary(previous.X-c.X,previous.Z-c.Z,pos.X-c.X,pos.Z-c.Z)
   r.boundaryPrevious=pos
   if crossed or not inside(pos,0) or pos.Y<groundY-4 or pos.Y>groundY+18 or body.CFrame.UpVector.Y<.55 then
    practice:recover(player)
    body.AssemblyLinearVelocity=Vector3.zero;body.AssemblyAngularVelocity=Vector3.zero
    r.kart:PivotTo(r.safe);r.boundaryPrevious=r.safe.Position;r.speed,r.yaw,r.throttle,r.steering=0,0,0,0;r.lastInput=0;r.crashEnd=nil;r.crashCooldown=nil;Drift.clear(r.training);r.kart:SetAttribute("LobbyDrifting",false);r.kart:SetAttribute("KartDrifting",false);r.kart:SetAttribute("KartBoosting",false);r.kart:SetAttribute("LobbyDriftCharge",0)
    player:SetAttribute("LobbyDriveResetSerial",(player:GetAttribute("LobbyDriveResetSerial") or 0)+1);continue
   end
   if Qualification.step(r.qualification,dt,pos.X,pos.Z,true) and not r.qualificationSaved and not r.qualificationSaving
    and os.clock()>=(r.nextQualificationSave or 0) then
    r.qualificationSaving=true
    task.spawn(function()
     local result=require(script.Parent.EconomyService).qualifyActivity(player,'TEST_DRIVE',Qualification.proof(r.qualification))
     r.qualificationSaving=false;r.qualificationSaved=result.status=='FOUND';r.nextQualificationSave=os.clock()+5
    end)
   end
   if not r.qualificationSaved then
    player:SetAttribute('KDMTestDriveMovingSeconds',math.floor(r.qualification.seconds))
    player:SetAttribute('KDMTestDriveDistance',math.floor(r.qualification.distance))
   end
   local throttle,steering=r.throttle,r.steering
   local drifting=false
   if os.clock()-r.lastInput>Policy.InputTimeout then throttle,steering,drifting=0,0,false end
   local f=body.CFrame.LookVector;f=Vector3.new(f.X,0,f.Z).Unit
   local right=Vector3.new(-f.Z,0,f.X)
   local physical=Vector3.new(body.AssemblyLinearVelocity.X,0,body.AssemblyLinearVelocity.Z)
   -- Respect actual wall stops: never keep accelerating into a rail with stale commanded speed.
   if math.abs(r.speed)>5 and math.abs(physical:Dot(f))<math.abs(r.speed)*.3 then r.speed=physical:Dot(f) end
   if throttle<=0 then
    local target=if throttle<0 then -Policy.Reverse*-throttle else 0
    local rate=if throttle<0 then Policy.Brake else Policy.Coast
    r.speed+=math.clamp(target-r.speed,-rate*dt,rate*dt)
   end
   local now=os.clock()
   local localPos=pos-c
   local clearance,nx,nz=Geometry.contact(localPos.X,localPos.Z)
   local normal=Vector3.new(nx,0,nz)
   local approach=physical:Dot(normal)
   if not r.crashEnd then
    if clearance<=Policy.FootprintMargin and math.abs(f:Dot(normal))>Policy.GlancingNormal and approach>KartConfig.BARRIER_CONTACT_MIN_SPEED
     and now>=(r.crashCooldown or 0) then
     local impact=Policy.barrierImpact(approach,KartConfig)
     local inward=-normal;local tangent=Vector3.new(-normal.Z,0,normal.X)
     if tangent:Dot(f)<0 then tangent=-tangent end
     r.crashVelocity=(inward*.75+tangent*.4).Unit*impact.rebound
     r.crashForward=tangent
     local cross=physical:Cross(inward).Y
     r.crashSpin=(if cross<0 then -1 else 1)*impact.turns*2*math.pi/impact.duration
     r.crashEnd=now+impact.duration;r.crashCooldown=r.crashEnd+KartConfig.BARRIER_CRASH_COOLDOWN
     r.crashAlignStart=r.crashEnd-math.min(.35,impact.duration*.54);r.crashAlignDeadline=r.crashEnd+.2
     r.speed,r.yaw=0,0;r.kart:SetAttribute("LobbyBarrierSerial",(r.kart:GetAttribute("LobbyBarrierSerial") or 0)+1)
     r.kart:SetAttribute("LobbyBarrierRebound",impact.rebound)
    end
   end
   if r.crashEnd then
    practice:isNitro(player,now,throttle,true)
    local headingError=math.atan2(f:Cross(r.crashForward).Y,f:Dot(r.crashForward))
    if now>=r.crashEnd and (math.abs(headingError)<=math.rad(20) or now>=r.crashAlignDeadline) then
     r.crashEnd=nil;body.AssemblyLinearVelocity=Vector3.new(0,body.AssemblyLinearVelocity.Y,0);body.AssemblyAngularVelocity=Vector3.zero
    else
     r.crashVelocity*=math.exp(-KartConfig.BARRIER_CRASH_DAMPING*dt)
     body.AssemblyLinearVelocity=r.crashVelocity+Vector3.new(0,body.AssemblyLinearVelocity.Y,0)
     local spinWeight=math.clamp((r.crashAlignStart+.08-now)/.08,0,1)
     local alignment=math.clamp(headingError*16,-12,12)
     body.AssemblyAngularVelocity=Vector3.new(0,r.crashSpin*spinWeight+alignment*(1-spinWeight),0)
    end
    Drift.clear(r.training);r.kart:SetAttribute("LobbyDrifting",false);r.kart:SetAttribute("KartDrifting",false);r.kart:SetAttribute("KartBoosting",false);r.kart:SetAttribute("LobbyDriftCharge",0);r.kart:SetAttribute("KartVisualSteering",0);continue
   end
   -- Use the approved race slide solver; training owns only transient charge.
   local radius=KartConfig.TURN_RADIUS_LOW_SPEED+(KartConfig.TURN_RADIUS_HIGH_SPEED-KartConfig.TURN_RADIUS_LOW_SPEED)*math.clamp(math.abs(r.speed)/KartConfig.MAX_FORWARD_SPEED,0,1)
   local normalYaw=-r.training.steer*r.speed/radius
   local slideCap = if nitro then KartConfig.NITRO_MAX_SPEED else KartConfig.MINI_BOOST_MAX_SPEED
   if r.training.slide.active or r.training.slide.recovering then
    local currentSpeed=physical.Magnitude
    if r.training.active and throttle>0 then currentSpeed=math.max(currentSpeed,KartConfig.DRIFT_MAX_SPEED)end
    r.speed=math.min(currentSpeed,slideCap)
   end
   local wasBoost,boostEnd=r.training.boost,r.training.boostEnd
   local hit=practice:physical(player,now)
   if hit then
    -- Combat cancels Drift/Boost, while normal steering/throttle stay available.
    local steer=r.training.steer;Drift.clear(r.training);r.training.steer=steer
   end
   local nitro=practice:isNitro(player,now,throttle,clearance<=Policy.FootprintMargin)
   if straightCourse then
    local lp=Vector3.new(localPos.X,0,localPos.Z)
    StraightSpeedResolver.update(r,straightCourse,lp,now,true)
    forwardSpeed=if r.straightEligible then KartConfig.STRAIGHT_MAX_SPEED else KartConfig.MAX_FORWARD_SPEED
    if nitro or r.training.boost then r.straightBoostReturnActive=true end
    if r.straightBoostReturnActive then r.straightExitActive=false end
    r.training.straightExitActive=r.straightExitActive
    if r.speed<=forwardSpeed then r.straightExitActive=false;r.straightBoostReturnActive=false end
   else r.training.straightExitActive=false end
   local slideLateral,slideYaw,projected,budget=Drift.step(r.training,now,dt,physical:Dot(f),physical:Dot(right),r.speed,throttle,steering,now-r.lastInput<=Policy.InputTimeout,normalYaw,r.yaw,forwardSpeed,nitro,not inside(pos,0))
   if r.training.boost and r.training.boostPress~=r.practiceBoostPress then
    r.practiceBoostPress=r.training.boostPress;practice:boost(player)
   end
   if not wasBoost and r.training.boost then r.kart:SetAttribute('KartBoostEndReason','')
   elseif wasBoost and not r.training.boost then
    r.kart:SetAttribute('KartBoostEndReason',if now>=boostEnd and throttle>0 and not r.training.active then 'duration_complete' else 'cancelled')
   end
   if budget then r.speed=budget end
   drifting=r.training.active
   local lateral=right*(slideLateral or (physical:Dot(right)*math.exp(-KartConfig.LATERAL_GRIP*dt)))
   local velocity=f*(projected or r.speed)+lateral
   local nearWall=clearance<=Policy.EscapeClearance
   if nearWall and math.abs(f:Dot(normal))<=Policy.GlancingNormal then
    local x,z=Policy.slide(velocity.X,velocity.Z,nx,nz);velocity=Vector3.new(x,0,z)
   end
   local maxCap = if nitro then KartConfig.NITRO_MAX_SPEED else KartConfig.MINI_BOOST_MAX_SPEED
   if velocity.Magnitude>maxCap then velocity=velocity.Unit*maxCap end
   -- At most three small server corrections per contact episode. Every proposed
   -- position clears the complete rectangular chassis and the concave outline.
   if nearWall and physical.Magnitude<Policy.EscapeSpeed and (math.abs(throttle)>.1 or math.abs(steering)>.1) then
    r.stuckTime=(r.stuckTime or 0)+dt
    if r.stuckTime>=Policy.EscapeDelay and now>=(r.escapeNext or 0) then
     r.escapeNext=now+Policy.EscapeCooldown;r.stuckTime=0
     local footprint=Policy.footprint(f.X,f.Z,nx,nz)
     local distance=Policy.escapeDistance(clearance,footprint)
     local proposed=pos-normal*distance
     if (r.escapeCount or 0)<Policy.EscapeLimit and distance>0 and inside(proposed,footprint)
      and Policy.fits(Geometry,proposed.X-c.X,proposed.Z-c.Z,f.X,f.Z) then
      r.kart:PivotTo(body.CFrame-normal*distance);r.escapeCount=(r.escapeCount or 0)+1
      r.kart:SetAttribute("LobbyEscapeSerial",(r.kart:GetAttribute("LobbyEscapeSerial") or 0)+1)
      r.kart:SetAttribute("LobbyEscapeDistance",distance)
     else
      practice:recover(player)
      r.kart:PivotTo(r.safe);r.boundaryPrevious=r.safe.Position;r.speed,r.yaw=0,0;velocity=Vector3.zero;r.escapeCount=Policy.EscapeLimit;Drift.clear(r.training)
      player:SetAttribute("LobbyDriveResetSerial",(player:GetAttribute("LobbyDriveResetSerial") or 0)+1)
     end
    end
   else r.stuckTime=0 end
   if clearance>Policy.EscapeClearance+4 then r.escapeCount=0 end
   local target=if math.abs(r.speed)>2 then -r.training.steer*math.abs(r.speed)/radius*math.sign(r.speed) else 0
   if nearWall and physical.Magnitude<Policy.EscapeSpeed and math.abs(steering)>.1 then
    local direction=if math.abs(r.speed)>.1 then math.sign(r.speed) elseif throttle<0 then -1 else 1
    local assist=Policy.escapeSteering(f.X,f.Z,nx,nz,steering,direction)
    if assist~=0 then target=assist end
   end
   r.yaw=slideYaw or (r.yaw+math.clamp(target-r.yaw,-KartConfig.YAW_ACCELERATION*dt,KartConfig.YAW_ACCELERATION*dt))
   velocity,r.yaw=practice:motion(player,now,dt,f,right,velocity,r.yaw)
   body.AssemblyLinearVelocity=velocity+Vector3.new(0,body.AssemblyLinearVelocity.Y,0);body.AssemblyAngularVelocity=Vector3.new(0,r.yaw,0)
   r.kart:SetAttribute("KartVisualSteering",steering)
   r.kart:SetAttribute("LobbyDrifting",drifting)
   r.kart:SetAttribute("KartDrifting",drifting);r.kart:SetAttribute("KartBoosting",r.training.boost)
   r.kart:SetAttribute("LobbyDriftReady",r.training.ready)
   r.kart:SetAttribute("LobbyDriftCharge",math.min(r.training.duration/KartConfig.DRIFT_CHARGE_MIN_DURATION,r.training.qualified/KartConfig.DRIFT_CHARGE_REQUIRED_TIME))
   if inside(pos,Policy.FootprintMargin+4) and math.abs(pos.Y-(groundY+1.75))<3 and body.CFrame.UpVector.Y>.95 then r.safe=body.CFrame end
  end
 end)
end
return Service
