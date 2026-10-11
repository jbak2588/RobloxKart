local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(p)return luau.load(fs.readFile(p))() end
local S=load('src/shared/KDMProgressionSchema.luau');local O=load('src/server/OfficialRaceRecords.luau');local V=load('src/client/PersonalRecordsController.luau')
local player={UserId=1,GetAttribute=function(_,k)return if k=='RaceState' then 'FINISHED' else false end}
local function run(fault,duration)
 local c=O.new(S,{utcMs=function()return 1791650000000 end});c.begin({RoundGuid='12345678-1234-1234-1234-000000000001',TrackId='Track01Race',GeometryId='PracticeFigure8V1',RulesetId='KDM_R8A3_RULES_V1',diagnostic=false,roster={{IsBot=false,UserId=1}}},{player},6,2,1000);c.start(player,0)
 duration=duration or 20
 for lap=1,2 do
  for i=0,100 do
   local f=(i/100)%1;local pos=rb.Vector3.new(math.cos(f*math.pi*2)*1000/(2*math.pi),0,math.sin(f*math.pi*2)*1000/(2*math.pi));local now=(lap-1)*duration+i/100*duration
   if lap==1 then
    if fault=='progress' then f=i/100*.5 end
    if fault=='anchor' and i==0 then f=.3 end
    if i==50 then
     if fault=='movement' then pos+=rb.Vector3.new(200,0,0)
     elseif fault=='route' then f=(f+.1)%1
     elseif fault=='clock' then now-=1
     elseif fault=='fraction' then f=nil
     elseif fault=='reset' then c.invalidate(player) end
    end
   end
   c.sample(player,now,pos,f);c.checkpoints(player,math.min(if fault=='checkpoint' and lap==1 then 5 else 7,math.floor(i/14)+1))
  end
  c.lap(player,lap*duration,duration)
 end
 local op=c.finish(player,{positionFinalized=true,position=1,totalTime=duration*2+(if fault=='total' then .01 else 0)});assert(op)
 return op.race
end
local checks=0;local function check(v,s)checks+=1;assert(v,s) end
for fault,code in {reset='TIMER_RESET',movement='MOVEMENT_DISCONTINUITY',route='ROUTE_DISCONTINUITY',clock='CLOCK_ORDER',fraction='INVALID_FRACTION',anchor='START_ANCHOR',checkpoint='CHECKPOINT_COUNT',progress='ROUTE_PROGRESS',total='TOTAL_LAP_MISMATCH'} do
 local r=run(fault);check(not r.eligible and r.eligibilityDetail:find(code,1,true),'bounded exact cause '..fault)
 check(S.raceSnapshotValid(r),'diagnostic snapshot schema valid '..fault)

end
local fast=run(nil,2);check(not fast.eligible and fast.eligibilityDetail:find('LAP_DURATION',1,true),'too fast remains rejected')
local slower=run(nil,30);check(slower.eligible and slower.eligibilityDetail=='','slower normal race is eligible')
local legacy=S.clone(slower);legacy.eligibilityDetail=nil;check(S.raceSnapshotValid(legacy),'old snapshots compatible')
legacy.eligibilityDetail=string.rep('x',257);check(not S.raceSnapshotValid(legacy),'oversized diagnostic rejected')
legacy.eligibilityDetail={};check(not S.raceSnapshotValid(legacy),'malformed diagnostic quarantined')
local r=run('movement');local text=table.concat(V.lines({status='FOUND',records={scoped={[r.recordScope]={}},races={a={lastRace=r}}}}),'\n')
check(text:find('Validation: L1 MOVEMENT_DISCONTINUITY',1,true)~=nil,'mobile shows actual first cause')
check(not text:find('timer reset.',1,true),'unrelated cause is not falsely labeled reset')
print('PASS: '..checks..' eligibility causes, slower valid race, bounded backward-compatible snapshots and mobile diagnostics')

