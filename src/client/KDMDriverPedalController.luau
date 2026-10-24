-- Seated leg presentation only. No SeatWeld, root, kart or ownership writes.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local Controller={}
local started=false
local profiles={KDMV2={hip=90,knee=0,ankle=0,spread=0},SprintV1={hip=90,knee=0,ankle=0,spread=0}}
function Controller.pose(kind,side,model,joint)
 local p=profiles[model];if not p then return CFrame.identity end
 local direction=if side=='Left' then -1 else 1
 if kind=='R6' then
  return joint.C0.Rotation:Inverse()*CFrame.Angles(math.rad(p.hip),0,math.rad(p.spread*direction))*joint.C1.Rotation
 end
 return if kind=='Hip' then CFrame.Angles(math.rad(p.hip),0,math.rad(p.spread*direction))
  elseif kind=='Knee' then CFrame.Angles(math.rad(p.knee),0,0) else CFrame.Angles(math.rad(p.ankle),0,0)
end
function Controller.context(player)
 local c=player.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local seat=h and h.SeatPart
 if not h or h.Health<=0 or not seat then return nil end
 local state=player:GetAttribute('RaceState')
 local race=seat:GetAttribute('PrototypeKartSeat')==true and (state=='PRE_RACE'or state=='COUNTDOWN'or state=='RACING'or state=='FINISHING'or state=='FINISHED')
 local park=seat:GetAttribute('LobbyKartSeat')==true and state=='GARAGE' and player:GetAttribute('LobbyDriveActive')==true
 local kart=seat.Parent;local visual=kart and kart:FindFirstChild('Visual');local model=visual and visual:GetAttribute('VisualModelName')
 if not (race or park)or not profiles[model]then return nil end
 if race and kart:GetAttribute('PrototypeKart')~=true or park and kart:GetAttribute('LobbyOwnerUserId')~=player.UserId then return nil end
 return c,h,seat,model
end
function Controller.create(character,humanoid,seat,model)
 local joints={}
 local function add(part,name,kind,side)
  local joint=part and part:FindFirstChild(name)
  if joint and(joint:IsA('Motor6D')or joint:IsA('AnimationConstraint'))then
   table.insert(joints,{joint=joint,original=joint.Transform,pose=Controller.pose(kind,side,model,joint)})
  end
 end
 for _,side in {'Left','Right'}do
  local upper=character:FindFirstChild(side..'UpperLeg')
  if upper then
   add(upper,side..'Hip','Hip',side)
   add(character:FindFirstChild(side..'LowerLeg'),side..'Knee','Knee',side)
   add(character:FindFirstChild(side..'Foot'),side..'Ankle','Ankle',side)
  else add(character:FindFirstChild('Torso'),side..' Hip','R6',side)end
 end
 if #joints==0 then return nil end
 local record={character=character,humanoid=humanoid,seat=seat,model=model}
 function record:step()
  if humanoid.Health<=0 or humanoid.SeatPart~=seat or not seat.Parent or not character.Parent then return false end
  for _,entry in joints do if not entry.joint.Parent then return false end;entry.joint.Transform=entry.pose end
  return true
 end
 function record:destroy()
  for _,entry in joints do if entry.joint.Parent then entry.joint.Transform=entry.original end end
  table.clear(joints)
 end
 return record
end
function Controller.start()
 if started then return end;started=true
 local records={}
 local function release(player)
  local r=records[player];if r then r:destroy();records[player]=nil end
 end
 Run.PreSimulation:Connect(function()
  for player,r in records do if not r:step()then release(player)end end
 end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.25 then return end;elapsed=0
  for _,player in Players:GetPlayers()do
   local character,h,seat,model=Controller.context(player);local r=records[player]
   if not character then release(player)
   elseif not r or r.character~=character or r.seat~=seat or r.model~=model then
    release(player);records[player]=Controller.create(character,h,seat,model)
   end
  end
 end)
 Players.PlayerRemoving:Connect(release)
end
return Controller
