local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(path,env)return luau.load(fs.readFile(path),{environment=env or {}})()end
local State=load('src/client/RacePresentationState.luau')
local E=load('src/client/BoostFlameEnvelope.luau')
local n=0;local function check(v,label)assert(v,label);n+=1 end
for total=2,100 do
 check(State.lapNotice(total,0)==nil,'no opening-lap spam')
 for completed=1,total do
  local expected=if completed==total then nil elseif completed==total-1 then 'FINAL LAP' else (total-completed)..' LAPS TO GO'
  check(State.lapNotice(total,completed)==expected,'remaining '..total..'/'..completed)
 end
end
for _,count in {6,9,12} do
 for index=1,count+1 do check(State.gateIndex('RACING',index,count)==(if index==count+1 then 0 else index),'one authoritative next gate')end
end
for _,state in {'COUNTDOWN','DNF','FINISHING','FINISHED','GARAGE'}do check(State.gateIndex(state,2,6)==nil,'terminal cleanup')end
for _,index in {-1,0,.5,8}do check(State.gateIndex('RACING',index,6)==nil,'invalid index fails closed')end
for _,nitro in {false,true}do
 for _,rate in {10,15,20}do
  local s=E.new();local expected=if nitro then 1 else .7
  check(E.step(s,.016,100,nitro,not nitro,false,false)==expected,'original active profile')
  local previous=expected
  for frame=1,180 do
   local speed=math.max(70,100-frame/60*rate)
   local weight=E.step(s,1/60,speed,false,false,frame==1,false)
   check(weight<=previous and weight>=0,'monotonic deceleration fade');previous=weight
   if speed<=82 then check(weight==0,'no tail at normal speed')end
  end
 end
 for _,speed in {50,82,100}do
  local s=E.new();E.step(s,.01,100,nitro,not nitro,false,false)
  check(E.step(s,.01,speed,false,false,false,false)==0,'cancellation never fades')
  E.step(s,.01,100,nitro,not nitro,false,false)
  E.step(s,.01,99,false,false,true,false)
  check(E.step(s,.01,99,false,false,false,true)==0,'emergency interrupts an existing tail')
 end
end
local bundle=rb.deserializeModel(fs.readFile('src/assets/KDMRacePresentationResources.rbxmx'))[1]
for _,o in bundle:GetDescendants()do check(not o:IsA('LuaSourceContainer') and not o:IsA('RemoteEvent') and not o:IsA('VehicleSeat'),'safe assets only')end
local xml=fs.readFile('src/assets/KDMRacePresentationResources.rbxmx')
check(xml:find('rbxassetid://15617817566',1,true) and not bundle.StartPlayer.Looping,'original one-shot GO player')
check(xml:find('rbxassetid://15617815911',1,true)~=nil,'tick kept as reference, countdown unchanged')
print('PASS: '..n..' production lap/next-gate/flame-tail decisions and safe original asset checks')
