-- Run actual PrototypeWorld dynamics and all existing race-item integration assertions.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/race_item_validation.luau')
local anchor='world.start()'
local a,b=source:find(anchor,1,true);assert(a,'actual world startup anchor')
source=source:sub(1,b)..[[
local observedRecordBoosts,observedEventIds=0,{}
local recordGuid='12345678-1234-1234-1234-123456789012'
player:SetAttribute('OfficialRoundGuid',recordGuid)
world.onDriftOutcome(function(who,outcome,eventId)
 if who~=player then return end
 if outcome=='BOOST' then
  local context=world.getKartContext(who)
  check(context.boostActive and context.kart:GetAttribute('KartBoosting')==true,'record event only after actual Mini Boost starts')
  check(eventId:sub(1,43)==recordGuid..':boost:' and not observedEventIds[eventId],'server boost identity round scoped and unique')
  observedEventIds[eventId]=true;observedRecordBoosts+=1
 else check(eventId==nil,'charge/reset/failure have no success identity') end
end)
]]..source:sub(b+1)..[[
check(observedRecordBoosts>0,'actual successful Mini Boost observed in production world')
print('PASS: '..observedRecordBoosts..' actual Mini Boost events have unique record identities; all original item/physics assertions retained')
]]
local configHelper=require('./helpers/gameplay_config')
luau.load(source,{debugName='R8A3-actual-boost-wire',environment={require=function(path)
 if path=='./helpers/gameplay_config' then return configHelper end
 return require(path)
end}})()
