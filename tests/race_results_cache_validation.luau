-- lune run tests/race_results_cache_validation.luau
-- Exercise the production cache with replicated Human/Bot snapshots.
local fs, luau = require('@lune/fs'), require('@lune/luau')
local Cache = luau.load(fs.readFile('src/client/RaceResultsCache.luau'))()
local count = 0
local function check(value, label) assert(value, label); count += 1 end
local function racer(id, state, bot)
 local p = {UserId=id, Name='Human'..tostring(id), DisplayName='Human '..tostring(id),
  attrs={RaceSessionId=901, RaceState=state, RacePosition=2, RaceFinalTime=123,
   RaceFinishPosition=if state=='FINISHED' then 2 else 0}}
 if bot then p.attrs.IsBot=true;p.attrs.BotId=id;p.attrs.DisplayName='KDM Rookie [BOT]' end
 function p:GetAttribute(name) return self.attrs[name] end
 return p
end
local function find(rows, key)
 for _,row in rows do if row.userId==key then return row end end
end
local h1,h2=racer(1,'FINISHED'),racer(2,'RACING')
h1.attrs.RaceFinishPosition=1;h1.attrs.RaceParticipantCount=2
local cache=Cache.new()
local bot=racer('Bot01','RACING',true)
check(#cache:collect(h1,{h1,h2},{bot})==3,'observe temporary live Bot without count truncation')
local rows=cache:collect(h1,{h1,h2},{})
check(#rows==h1:GetAttribute('RaceParticipantCount') and not find(rows,'bot:Bot01'),
 'field reproduction: absent RACING Bot pruned; exactly two Humans remain')
check(find(rows,2).state=='RACING','live unfinished rival retained')
for _,state in {'PRE_RACE','COUNTDOWN','RACING','FINISHING','GARAGE','UNKNOWN',false} do
 for _,isBot in {false,true} do
  local c=Cache.new()
  local p=racer(if isBot then 'Bot01' else 2,if state then state else nil,isBot)
  local key=if isBot then 'bot:Bot01' else 2
  local liveHumans=if isBot then {h1} else {h1,p}
  local liveBots=if isBot then {p} else {}
  check(find(c:collect(h1,liveHumans,liveBots),key)~=nil,'live nonterminal retained '..tostring(state))
  check(not find(c:collect(h1,{h1},{}),key),'absent nonterminal pruned '..tostring(state))
 end
end
for _,state in {'FINISHED','DNF'} do
 for _,isBot in {false,true} do
  local c=Cache.new()
  local p=racer(if isBot then 'Bot01' else 2,state,isBot)
  local key=if isBot then 'bot:Bot01' else 2
  c:collect(h1,if isBot then {h1} else {h1,p},if isBot then {p} else {})
  local terminal=find(c:collect(h1,{h1},{}),key)
  check(terminal and terminal.state==state and terminal.finalTime==123,'departed terminal preserved '..state)
  if state=='FINISHED' then check(terminal.finishPosition==2,'official finished position retained') end
  check(find(c:collect(h1,{h1},{}),key)==terminal,'terminal cache remains stable across collections')
 end
end
-- A source still replicated but moved to another session is not live in this round.
cache=Cache.new();bot=racer('Bot01','RACING',true);h2.attrs.RaceState='RACING'
cache:collect(h1,{h1,h2},{bot})
h2.attrs.RaceSessionId=902;bot.attrs.RaceSessionId=902
rows=cache:collect(h1,{h1,h2},{bot})
check(#rows==1 and rows[1].userId==1,'wrong-session nonterminal Humans and Bots pruned')
h2.attrs.RaceSessionId=901
-- Actual Human + Bot final results survive Bot replication loss, without name filtering.
cache=Cache.new();bot=racer('Bot01','FINISHED',true)
rows=cache:collect(h1,{h1},{bot})
check(#rows==2 and rows[1].userId==1 and rows[2].userId=='bot:Bot01','legitimate Human+Bot results sorted')
rows=cache:collect(h1,{h1},{})
check(#rows==2 and rows[2].isBot and rows[2].displayName=='KDM Rookie [BOT]','finished Bot result preserved')
h1.attrs.RaceSessionId=902
rows=cache:collect(h1,{h1,h2},{bot})
check(#rows==1 and rows[1].sessionId==902 and not find(rows,'bot:Bot01'),'session change clears terminal and live old rows')
for _,session in {0,false} do
 h1.attrs.RaceSessionId=if session then session else nil
 check(#cache:collect(h1,{h1},{bot})==0 and next(cache.entries)==nil,'zero/nil session clears results')
end
print('PASS: '..count..' production result-cache membership, terminal preservation and session checks')
