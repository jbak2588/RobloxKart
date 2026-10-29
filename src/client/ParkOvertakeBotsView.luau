-- Seven local noncontact rivals follow the exact server-owned distance timeline.
-- No Humanoids, physical seats, ownership writes, remotes or shared audio loops.
local RS=game:GetService('ReplicatedStorage')
local P=require(RS.Shared.ParkOvertakePolicy)
local Layout=require(RS.Shared.HubParkRookieLoopLayout)
local Catalog=require(RS.Shared.KartCatalog)
local Factory=require(RS.Shared.KartVisualFactory)
local View={}
function View.new(player,zone)
 local api={};local bots={};local key;local building=false;local serial=0;local stopped=false
 local function clear()
  serial+=1;building=false;key=nil
  for _,model in bots do model:Destroy()end;table.clear(bots)
 end
 function api:destroy()stopped=true;clear()end
 local function frame(index,elapsed,start)
  local x,z,dx,dz=P.sample(start+P.botDistance(index,elapsed))
  local pos=zone:GetAttribute('Center')+Vector3.new(x,Layout.height(x,z)+1.75,z)
  return CFrame.lookAt(pos,pos+Vector3.new(dx,0,dz))
 end
 function api:update(active)
  if stopped then return end
  if not active or player:GetAttribute('ParkOvertakeActive')~=true then if key then clear()end;return end
  local phase=player:GetAttribute('ParkTrialPhase');local started=player:GetAttribute('ParkTrialStartedAt')
  local start=player:GetAttribute('ParkOvertakeStartArc');local go=player:GetAttribute('ParkTrialGoAt')
  if type(start)~='number'or type(go)~='number'then return end
  local nextKey=tostring(player:GetAttribute('LobbyDriveGeneration'))..':'..go
  if key~=nextKey then clear();key=nextKey end
  if #bots==0 and not building then
   building=true;local generation=serial
   task.spawn(function()
    for i,id in {'Kart05','Kart06','Kart07','Kart08','Kart09','Kart10','Kart11'}do
     local definition=Catalog.Entries[id];local model=Instance.new('Model');model.Name='ParkOvertakeBot_'..i
     local ok,visual=pcall(Factory.createVisual,definition,false)
     if not ok then model:Destroy();building=false;warn('[ParkOvertake] rival visual unavailable');return end
     visual.Parent=model
     local seat=Factory.getDriverSeatLocalCFrame(definition)
     for _,part in {{'Torso',Vector3.new(1.85,1.9,1),Vector3.new(0,1.67,0)},
      {'Helmet',Vector3.new(1.5,1.5,1.5),Vector3.new(0,3.17,-.05)},
      {'Visor',Vector3.new(1.3,.55,.25),Vector3.new(0,3.27,-.75)}}do
      local v=Instance.new('Part');v.Name=part[1];v.Size=part[2];v.CFrame=seat*CFrame.new(part[3])
      v.Color=if part[1]=='Visor'then Color3.fromRGB(20,29,44)else definition.DisplayColor
      if part[1]=='Helmet'then v.Shape=Enum.PartType.Ball end;v.Parent=model
     end
     -- Keep the factory's chassis-relative origin as the pivot (not its bounds).
     local root=Instance.new('Part');root.Name='RouteRoot';root.Transparency=1;root.Size=Vector3.one;root.Parent=model;model.PrimaryPart=root
     for _,v in model:GetDescendants()do
      if v:IsA('BasePart')then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false
      elseif v:IsA('LuaSourceContainer')or v:IsA('ProximityPrompt')then v:Destroy()end
     end
     if stopped or generation~=serial or not zone.Parent then model:Destroy();return end
     bots[i]=model;model:PivotTo(frame(i,0,start));model.Parent=zone
     task.wait() -- one model per frame; no seven-model allocation spike
    end
    if generation==serial then building=false end
   end)
  end
  local elapsed=if phase=='COUNTDOWN'then 0 elseif phase=='RUNNING'then math.max(0,workspace:GetServerTimeNow()-(started or go))
   else (player:GetAttribute('ParkTrialMilliseconds')or 0)/1000
  for i,model in bots do model:PivotTo(frame(i,elapsed,start))end
 end
 return api
end
return View
