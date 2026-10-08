local fs,luau,process=require('@lune/fs'),require('@lune/luau'),require('@lune/process')
local normalize=require('./helpers/p2a_bot_controller_freeze')
local source=fs.readFile('src/server/PrototypeWorld.luau'):gsub('\r\n','\n')
local baseline=process.exec('git',{'show','c815d2fd0ef174e20631a9f034f43c3d7f75c9cc:src/server/PrototypeWorld.luau'})
assert(baseline.ok and normalize(source)==baseline.stdout:gsub('\r\n','\n'),'entire human input/physics/items unchanged; only exact Bot extension excluded')
local count=1
local function check(v,label)assert(v,label);count+=1 end
local a=assert(source:find('function context:setServerControl',1,true))
local b=assert(source:find('local function occupantDriver',a,true))
local studio,enabled,role=true,true,'RACE'
local env={RaceConfig={INVITEABLE_BOT_ENABLED=true},Workspace={GetAttribute=function(_,key)return if key=='KDMServerRole' then role else enabled end},
 RunService={IsStudio=function()return studio end},time=function()return 123 end}
local install=luau.load('return function(context,seat,kart)\n'..source:sub(a,b-1)..'\nreturn context end',{environment=env})()
local humanoid={};local seat={Occupant=humanoid};humanoid.SeatPart=seat
local phase='RACING';local kart={SetAttribute=function()end}
local context=install({botSource='STUDIO_TEST',botParticipant={GetAttribute=function()return phase end},
 botDriver={FindFirstChildOfClass=function()return humanoid end},crashActive=false,slick={active=false}},seat,kart)
for _,pair in {{.4,nil},{.4,1},{.4,0},{2,2},{-2,-2}}do
 check(context:setServerControl(pair[1],pair[2]),'valid server Bot input')
 check(context.control.throttle==math.clamp(pair[2] or 1,0,1) and context.control.steering==math.clamp(pair[1],-1,1)
  and not context.control.driftRequested,'old default/new coast/clamping')
end
for _,invalid in {0/0,math.huge,-math.huge,'1',false,{}}do
 local previous=context.control
 check(not context:setServerControl(.4,invalid) and context.control==previous,'reject invalid throttle safely')
 check(not context:setServerControl(invalid,1) and context.control==previous,'reject invalid steering safely')
end
phase='WAITING';check(not context:setServerControl(.4,0) and context.control==nil,'locked phase rejects input')
phase='RACING';enabled=false;check(not context:setServerControl(.4,0),'Studio gate preserved')
enabled=true;studio=false;check(not context:setServerControl(.4,0),'non-Studio harness denied')
context.botSource='PRODUCTION_ROOM';check(context:setServerControl(.4,0),'authorized race server Bot coasts')
role='LOBBY';check(not context:setServerControl(.4,0),'Lobby denies production Bot')
role='RACE';context.botParticipant=nil;check(not context:setServerControl(.4,0),'human context denies internal Bot input')
for _,pair in {{'throttle = math.clamp(throttle, -1, 1)','throttle = math.clamp(throttle, 0, 1)'},
 {'KartConfig.COAST_DECELERATION * deltaTime','999 * deltaTime'},
 {'RaceConfig.INVITEABLE_BOT_ENABLED and Workspace','true and Workspace'}}do
 local start=assert(source:find(pair[1],1,true));local changed=source:sub(1,start-1)..pair[2]..source:sub(start+#pair[1])
 check(normalize(changed)~=normalize(source),'freeze rejects unrelated input/physics/authority changes')
end
print('PASS: '..count..' actual Bot internal controls and complete human physics freeze checks')
