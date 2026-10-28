-- Production KartContext and the actual RaceController GO adapter, using existing physics mocks.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/race_item_validation.luau'):gsub('\r\n','\n')
source=source:sub(1,assert(source:find('startRace()\ncheck',1,true))-1)
-- Keep service initialization, omit the unrelated historical four-item/tuning assertions.
local first=assert(source:find('local catalog=load',1,true))
local last=assert(source:find('-- Capture server state',1,true))
source=source:sub(1,first-1)..[=[
load('src/shared/RaceItemCatalog.luau',shared,'RaceItemCatalog')
load('src/shared/RaceItemSlots.luau',shared,'RaceItemSlots')
local loadoutType=load('src/server/RaceLoadout.luau',server,'RaceLoadout')
]=]..source:sub(last)
local scenario=[=[
local outcomes=0;world.onDriftOutcome(function(_,outcome)if outcome=='BOOST'then outcomes+=1 end end)
local ctx=world.getKartContext(player)
local adapter=fs.readFile('src/server/RaceController.luau'):match('(function racer:startRace%(startTime: number%).-\n\t\tend)')
assert(adapter,'real race GO adapter')
local racer={};local env={PrototypeWorld=world,racer=racer,context=ctx,kart=kart,chassis=chassis,player=player,
 resetOffTrackState=function()end,clearGateState=function()end,setRaceState=function(p,v)p:SetAttribute('RaceState',v)end,record=function()end}
luau.load(adapter,{environment=env})()
for _,id in {'Track01','Track01Race','Track02','Track03'}do
 player:SetAttribute('RaceState','COUNTDOWN');kart:SetAttribute('RaceControlsLocked',true);step(0)
 seat.Occupant=human;human.SeatPart=seat;ctx.commandedSpeed=0;chassis.AssemblyLinearVelocity=V.zero
 player:SetAttribute('SelectedTrackId',id)
 local charge=player:GetAttribute('RaceChargeNitro');local progress=player:GetAttribute('DriftBonusProgress')
 racer:startRace(now)
 check(ctx.boostActive and kart:GetAttribute('KartBoosting'),'GO starts actual Mini Boost '..id)
 check(not ctx:launchBoost(player),'duplicate GO cannot extend boost '..id)
 local peak=0
 for i=1,110 do peak=math.max(peak,step(0));check(ctx.commandedSpeed<=100.001,'launch never exceeds existing 100 cap')end
 check(peak>99,'automatic launch accelerates despite no forward press '..id)
 check(player:GetAttribute('RaceChargeNitro')==charge and player:GetAttribute('DriftBonusProgress')==progress and outcomes==0,'launch grants no Drift credit or Nitro consume '..id)
 step(-1);check(not ctx.boostActive,'Brake cancels launch '..id)
end
player:SetAttribute('RaceState','COUNTDOWN');kart:SetAttribute('RaceControlsLocked',true)
check(not ctx:launchBoost(player),'locked countdown cannot launch')
print('PASS '..count..' actual GO / Mini Boost / no-input / Brake / inventory checks on all four tracks')
]=]
local deps={['@lune/fs']=fs,['@lune/luau']=luau,['@lune/roblox']=require('@lune/roblox'),['./helpers/gameplay_config']=require('./helpers/gameplay_config')}
luau.load(source..scenario,{environment={require=function(id)return assert(deps[id],id)end}})()
