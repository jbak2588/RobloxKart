-- Retain every existing production-controller assertion, adding observer call evidence.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/four_player_race_validation.luau')
local anchor='local race=load("src/server/RaceController.luau",server,"RaceController")'
local insertion=[[
local recordCalls={begin={},finish={},lap=0,progress=0,start=0,invalidate=0}
child(server,"ModuleScript","RaceRecordService")
local outcomeListener
modules.PrototypeWorld.onDriftOutcome=function(callback) outcomeListener=callback end
modules.RaceRecordService={
 begin=function(s,course,cp)
  local ids={};for _,p in s:orderedParticipants() do table.insert(ids,p.UserId) end
  table.insert(recordCalls.begin,{round=s.roundId,roster=ids})
  check(s.phase=="RACING" and course and cp==2,"observer freezes GO actual roster")
 end,
 start=function(p) recordCalls.start+=1;check(p:GetAttribute("RaceState")=="RACING","record start after race unlock") end,
 progress=function(p) recordCalls.progress+=1;check(p:GetAttribute("RaceState")=="RACING","record progress only RACING") end,
 checkpoints=function(p,nextCp) check(nextCp==3,"official completion checkpoint sequence passed") end,
 lap=function(p) recordCalls.lap+=1;check(p:GetAttribute("RaceState")=="RACING","lap observer before FINISHING") end,
 invalidate=function() recordCalls.invalidate+=1 end,
 finish=function(p)
  check(p:GetAttribute("RaceState")=="FINISHED","save hook never FINISHING")
  recordCalls.finish[p:GetAttribute("RaceFinishPosition")]=true
 end,
 boost=function(p,id) check(id=="bridge-identity","BOOST identity forwarded without rewrite") end,
}
]]
local a,b=source:find(anchor,1,true);assert(a,'controller fixture insertion anchor')
source=source:sub(1,a-1)..insertion..source:sub(a)..[[
check(#recordCalls.begin>=3 and recordCalls.start>=7 and recordCalls.progress>0 and recordCalls.lap>=7,"observer integrated across rounds and racers")
for rank=1,4 do check(recordCalls.finish[rank],"all official finish positions eligible "..rank) end
for i=2,#recordCalls.begin do check(recordCalls.begin[i].round~=recordCalls.begin[i-1].round,"Rematch controller round identity distinct") end
check(#recordCalls.begin[1].roster==3,"room capacity four does not imply four starters")
outcomeListener(b,"BOOST","bridge-identity")
outcomeListener(b,"READY",nil);outcomeListener(b,"RESET",nil)
print("PASS: R8-A3 production RaceController hooks with all original assertions retained")
]]
local configHelper=require('./helpers/gameplay_config')
luau.load(source,{debugName='R8A3-controller-with-original-four-player-assertions',environment={require=function(path)
 if path=='./helpers/gameplay_config' then return configHelper end
 return require(path)
end}})()
