-- Public display/index contract; never changes rewards, race admission or physics.
local P={StoreName='KDM_HubRanks_v1',RefreshSeconds=60,ReadInterval=12,PageSize=50,
 CashEnabled=true,MultiEnabled=true,Ruleset='KDM_R8A3_RULES_V1'}
P.Tracks={
 {id='Park',name='ROOKIE RACING PARK',geometry='ROOKIE_LOOP_V1',laps=2},
 {id='Track01',name='GREEN ISLAND',geometry='PracticeFigure8V1',laps=3},
 {id='Track01Desert',name='DESERT CANYON',geometry='PracticeFigure8V1',laps=3},
 {id='Track01Race',name='BASE CIRCUIT',geometry='PracticeCircuitV1',laps=2},
 {id='Track01Metro',name='METRO CITY',geometry='PracticeCircuitV1',laps=2},
 {id='Track03',name='HARD CIRCUIT',geometry='HardCircuitV1',laps=2},
}
P.Boards={};P.Order={}
for _,track in P.Tracks do
 for _,mode in (if track.id=='Park'then {'SOLO'}else {'SOLO','MULTI'})do
  local id=mode..'_'..track.id
  P.Boards[id]={id=id,mode=mode,track=track.id,title=track.name,ascending=true,
   laps=track.laps,scope=id..'_TOTAL_R2_L'..track.laps,enabled=mode=='SOLO'or P.MultiEnabled}
  table.insert(P.Order,id)
 end
end
P.Boards.CASH={id='CASH',mode='CASH',track='ALL',title='LIFETIME K$ EARNED',ascending=false,scope='EARNED_R1',enabled=P.CashEnabled}
table.insert(P.Order,'CASH')
function P.integer(v)return type(v)=='number'and v==v and v%1==0 and v>=0 and v<=9007199254740991 end
function P.allowed(ctx)
 if ctx.isStudio then return false end
 return ctx.universe==10768420544 and ctx.place==127925465904803
  and ((ctx.role=='HUB'and ctx.privateId=='')or(ctx.role=='RACE'and ctx.privateId~=''and ctx.ownerId==0))
end
function P.format(board,score)
 if not P.integer(score)then return '--'end
 if board.mode=='CASH'then local s=tostring(score);local out=s:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','');return 'K$ '..out end
 return string.format('%d:%06.3f',math.floor(score/60000),score%60000/1000)
end
function P.project(profile)
 local out={};if type(profile)~='table'or profile.deleted then return out end
 local park=profile.parkTwoLapTrial
 if park and P.integer(park.bestMilliseconds)and park.bestMilliseconds>=20000 then out.SOLO_Park=park.bestMilliseconds end
 if P.CashEnabled and profile.wallet and P.integer(profile.wallet.lifetimeEarned)then out.CASH=profile.wallet.lifetimeEarned end
 -- A single valid lap inside an invalid finish is not sufficient. Only saved,
 -- eligible complete-race evidence contributes to the public official index.
 for _,entry in (profile.records and profile.records.races)or {}do
  for _,race in {entry.lastRace,entry.bestRace}do
   if race and race.eligible==true and race.serverAccepted==true and race.state=='FINISHED'and race.positionFinalized==true
    and race.rulesetId==P.Ruleset and race.startingBots==0 and race.userId==profile.userId and type(race.laps)=='table'then
    local mode=if race.category=='SOLO_1H_0B'and race.startingHumans==1 then 'SOLO'
     elseif P.integer(race.startingHumans)and race.startingHumans>=2 and race.startingHumans<=4
      and race.category=='HUMAN_'..race.startingHumans..'H_0B'then 'MULTI'else nil
    for _,track in P.Tracks do
     if mode and race.trackId==track.id and race.geometryId==track.geometry and race.targetLaps==track.laps and #race.laps==track.laps then
      local valid,total=true,0
      for _,ms in race.laps do if not P.integer(ms)or ms<=0 then valid=false;break end;total+=ms end
      local id=mode..'_'..track.id
      if valid and P.integer(race.totalMilliseconds)and math.abs(total-race.totalMilliseconds)<=track.laps and P.Boards[id].enabled then out[id]=math.min(out[id]or math.huge,race.totalMilliseconds)end
     end
    end
   end
  end
 end
 return out
end
return P
