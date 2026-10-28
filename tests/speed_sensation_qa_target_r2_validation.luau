local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tools/apply_speed_sensation_phase1_private_qa_r2.luau'):gsub('\r\n','\n')
local before=assert(source:match('local before=%[====%[(.-)%]====%]'))
local after=assert(source:match('local after=%[====%[(.-)%]====%]'))
local checks=0
local function check(ok,label)assert(ok,label);checks+=1 end
local function trial(universe,place,current,studio,running)
 local writes,services=0,0
 local module=setmetatable({IsA=function(_,class)return class=='ModuleScript'end},{
  __index=function(_,key)if key=='Source'then return current end end,
  __newindex=function(_,key,value)assert(key=='Source');writes+=1;current=value end})
 local shared={FindFirstChild=function(_,name)assert(name=='KDMSpeedSensation');return module end}
 local game={GameId=universe,PlaceId=place,GetService=function(_,name)
  services+=1
  if name=='RunService'then return {IsStudio=function()return studio end,IsRunning=function()return running end}end
  assert(name=='ReplicatedStorage');return {FindFirstChild=function(_,name)assert(name=='Shared');return shared end}
 end}
 local ok,result=pcall(luau.load(source,{environment={game=game}}))
 return ok,writes,current,services,result
end
for _,ids in {{10768420544,127925465904803},{10768420544,106553302629620},{10772198697,127925465904803},{1,2}}do
 local ok,writes,_,services=trial(ids[1],ids[2],before,true,false)
 check(not ok and writes==0 and services==0,'wrong destination rejected before any source/service access')
end
local ok,writes,current,_,result=trial(10772198697,106553302629620,before,true,false)
check(ok and writes==1 and current==after,'only QA Edit receives exact candidate: '..tostring(result))
ok,writes=trial(10772198697,106553302629620,after,true,false)
check(ok and writes==0,'idempotent candidate does not rewrite source')
for _,mode in {{false,false},{true,true}}do
 ok,writes=trial(10772198697,106553302629620,before,mode[1],mode[2])
 check(not ok and writes==0,'live/Play rejected')
end
ok,writes=trial(10772198697,106553302629620,before..'\n-- other change',true,false)
check(not ok and writes==0,'unknown QA source never overwritten')
check(after==fs.readFile('src/shared/KDMSpeedSensation.luau'):gsub('\r\n','\n'),'patch equals preserved FOV candidate')
local manifest=require('@lune/serde').decode('json',fs.readFile('tests/fixtures/source_freeze_release_f5ebec8.json'))
local freeze=require('./helpers/release_source_freeze')
check(freeze.accepts(manifest,'src/shared/KDMSpeedSensation.luau',before),'patch rollback source equals approved release')
check(freeze.accepts(manifest,'src/shared/KDMSpeedSensation.luau',after),'patch changes only approved FOV trio')
print('PASS '..checks..' prepared private-QA patch target/isolation/scope checks; script NOT executed in Studio')
