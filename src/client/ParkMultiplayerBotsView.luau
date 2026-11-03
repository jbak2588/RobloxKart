-- One local noncontact fleet per participant, using the Overtake kart palette.
local RS=game:GetService('ReplicatedStorage')
local P=require(RS.Shared.ParkMultiplayerPolicy)
local Layout=require(RS.Shared.HubParkRookieLoopLayout)
local Catalog=require(RS.Shared.KartCatalog)
local Factory=require(RS.Shared.KartVisualFactory)
local ItemConfig=require(RS.Shared.RaceItemConfig)
local View={}
function View.new(player,zone)
 local api={};local bots={};local key;local building=false;local serial=0;local stopped=false
 local ids={'Kart05','Kart06','Kart07','Kart08','Kart09','Kart10','Kart11'}
 local function clear()
  serial+=1;building=false;key=nil
  for _,entry in bots do entry.model:Destroy()end;table.clear(bots)
 end
 function api:destroy()stopped=true;clear()end
 local function pose(model,proxy,now)
  local slot=proxy:GetAttribute('Slot');if type(slot)~='number'then return end
  local d=proxy:GetAttribute('RaceDistance')or P.startProgress(slot)
  local sampled=proxy:GetAttribute('RaceSampledAt')or now
  d=math.min(P.finishProgress(),d+math.clamp(now-sampled,0,.3)*(proxy:GetAttribute('RaceSpeed')or 0))
  local x,z,dx,dz=P.sample(d,slot);local spin=0
  if (proxy:GetAttribute('RaceSpeed')or 0)==0 and not proxy:GetAttribute('FinishedAt')then
   local phase=player:GetAttribute('ParkRacePhase')
   if phase=='WAITING'or phase=='FILLING'or phase=='COUNTDOWN'then local s=Layout.Slots[slot+1];x,z,dx,dz=s.x,s.z,1,0 end
  end
  for _,k in {'KartSlickActive','KartMissileHitActive','KartThunderHitActive','KartSmokeObscuredActive'}do
   local value=proxy:GetAttribute(k)==true;if model:GetAttribute(k)~=value then model:SetAttribute(k,value)end
  end
  if proxy:GetAttribute('KartSlickActive')then
   local duration=ItemConfig.SLICK_EFFECT_DURATION
   spin=2*math.pi*math.clamp((now-(proxy:GetAttribute('LobbySlickStartedAt')or now))/duration,0,1)
  end
  local c=zone:GetAttribute('Center');local pos=c+Vector3.new(x,Layout.height(x,z)+1.75,z)
  model:PivotTo(CFrame.lookAt(pos,pos+Vector3.new(dx,0,dz))*CFrame.Angles(0,spin,0))
 end
 function api:update(active)
  local id=player:GetAttribute('ParkRaceId')
  if stopped then return end
  if not active or not id then if key then clear()end;return end
  if key~=id then clear();key=id end
  local effects=zone:FindFirstChild('LobbyPracticeEffects');local room=effects and effects:FindFirstChild(id)
  if not room then return end
  for proxy,entry in bots do if not proxy.Parent then entry.model:Destroy();bots[proxy]=nil else pose(entry.model,proxy,workspace:GetServerTimeNow())end end
  if building then return end
  for _,proxy in room:GetChildren()do if proxy:GetAttribute('ParkRaceBot')and not bots[proxy]then
   local index=proxy:GetAttribute('BotIndex');local slot=proxy:GetAttribute('Slot')
   if type(index)~='number'or index%1~=0 or index<1 or index>7 or type(slot)~='number'or slot%1~=0 or slot<0 or slot>7 then continue end
   building=true;local generation=serial
   task.spawn(function()
    local definition=Catalog.Entries[ids[index]]
    local model=Instance.new('Model');model.Name='ParkMultiplayerBot_'..index;model:SetAttribute('LobbyPracticeBot',true)
    local ok,visual=pcall(Factory.createVisual,definition,false)
    if not ok then model:Destroy();building=false;warn('[ParkRace] rival visual unavailable');return end
    visual.Parent=model
    local seat=Factory.getDriverSeatLocalCFrame(definition)
    for _,spec in {{'Torso',Vector3.new(1.85,1.9,1),Vector3.new(0,1.67,0)},
     {'Helmet',Vector3.new(1.5,1.5,1.5),Vector3.new(0,3.17,-.05)},
     {'Visor',Vector3.new(1.3,.55,.25),Vector3.new(0,3.27,-.75)}}do
     local part=Instance.new('Part');part.Name=spec[1];part.Size=spec[2];part.CFrame=seat*CFrame.new(spec[3])
     part.Color=if spec[1]=='Visor'then Color3.fromRGB(20,29,44)else definition.DisplayColor
     if spec[1]=='Helmet'then part.Shape=Enum.PartType.Ball end;part.Parent=model
    end
    local root=Instance.new('Part');root.Name='RouteRoot';root.Transparency=1;root.Size=Vector3.one;root.Parent=model;model.PrimaryPart=root
    for _,v in model:GetDescendants()do if v:IsA('BasePart')then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false
     elseif v:IsA('LuaSourceContainer')or v:IsA('ProximityPrompt')then v:Destroy()end end
    if stopped or generation~=serial or not proxy.Parent or not zone.Parent then model:Destroy();return end
    bots[proxy]={model=model};pose(model,proxy,workspace:GetServerTimeNow());model.Parent=zone
    task.wait();if generation==serial then building=false end
   end)
   break -- At most one new kart visual per frame, including late replication.
  end end
 end
 return api
end
return View
