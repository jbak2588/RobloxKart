local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local checks=0
local function check(ok,label) checks+=1;assert(ok,label) end
local function node(name)
 local n={Name=name,children={}}
 function n:WaitForChild(k) return assert(self.children[k],k) end
 function n:FindFirstChild(k) return self.children[k] end
 return n
end
local shared,server=node('Shared'),node('Server')
local nodes,cache={},{}
for _,p in {'src/shared/KDMProgressionSchema.luau','src/shared/KartCatalog.luau','src/shared/TrackCatalog.luau',
 'src/server/OfficialRaceRecords.luau','src/server/RaceRecordConfig.luau','src/server/RaceRecordPolicy.luau',
 'src/server/RaceRecordOperations.luau','src/server/RaceRecordRuntime.luau','src/server/RaceRecordService.luau','src/server/ProgressionDataStoreAdapter.luau'} do
 local name=p:match('/([^/]+)%.luau$');local parent=if p:find('/shared/',1,true) then shared else server
 local n=node(name);n.Parent=parent;n.path=p;parent.children[name]=n;parent[name]=n;nodes[name]=n
end
local studio=false;local role='RACE';local calls=0;local serial=0;local queue={};local remote;local value;local index={};local indexCalls=0
local workspace={GetAttribute=function(_,k) return if k=='KDMServerRole' then role else nil end}
local ds={}
function ds:GetRequestBudgetForRequestType() return 100 end
function ds:GetDataStore(name)
 check(name=='KDM_PlayerProgress_v1','same A2 Profile store')
 return {GetAsync=function(_,key,opts) check(key=='u:11700555357' and opts.UseCache==false,'correct uncached user key');return value end,
  UpdateAsync=function(_,key,cb) local result=cb(value);if result then value=result end;return result end}
end
function ds:GetOrderedDataStore(name,scope)
 check(scope=='Track02_V2B_R1_SOLO_1H_0B','short exact geometry/category scope')
 return {UpdateAsync=function(_,key,cb) indexCalls+=1;check(key=='11700555357','same canary index key');index[name]=cb(index[name]);return index[name] end}
end
local services={ReplicatedStorage={WaitForChild=function() return shared end},RunService={IsStudio=function() return studio end},
 HttpService={GenerateGUID=function() serial+=1;return string.format('12345678-1234-1234-1234-%012d',serial) end},
 Players={PlayerRemoving={Connect=function() end}}}
local game={GameId=10768420544,PlaceId=127925465904803,PrivateServerId='reserved',PrivateServerOwnerId=0,
 GetService=function(_,name) if name=='DataStoreService' then calls+=1;return ds end;return assert(services[name],name) end,
 BindToClose=function() end}
local mockEnum=setmetatable({DataStoreRequestType={StandardRead=1,StandardWrite=2,OrderedRead=3,OrderedWrite=4}},{__index=rb.Enum})
local env={game=game,workspace=workspace,Color3=rb.Color3,CFrame=rb.CFrame,Vector3=rb.Vector3,Enum=mockEnum,
 DateTime={now=function() return {UnixTimestampMillis=1791650000000} end},print=function() end,
 Instance={new=function(class) if class=='RemoteFunction' then remote={};return remote end;return {} end},
 task={spawn=function(f) table.insert(queue,f) end,delay=function(_,f) table.insert(queue,f) end,wait=function() end}}
local function requireNode(n)
 if not cache[n] then local e=table.clone(env);e.script=n;e.require=requireNode;cache[n]=luau.load(fs.readFile(n.path),{environment=e,debugName=n.path})() end
 return cache[n]
end
local S=requireNode(nodes.KDMProgressionSchema);local schema=S.new(requireNode(nodes.KartCatalog))
value=schema.default(11700555357);value.selection.kartId='Kart07';value.wallet.cash=123
local Service=requireNode(nodes.RaceRecordService);check(calls==0,'module load zero DataStore lookup')
Service.startQuery();check(calls==0 and remote.Name=='KDMGetPersonalRecords','query registration lazy')
local p={UserId=11700555357,attrs={RaceState='RACING'}}
function p:GetAttribute(k) return self.attrs[k] end
function p:SetAttribute(k,v) self.attrs[k]=v end
local session={trackId='Track02',targetLaps=2,orderedParticipants=function() return {p} end}
local function runRound()
 p.attrs.RaceState='RACING';Service.begin(session,{CenterlineLength=1000},6);Service.start(p,0)
 local guid=p.attrs.OfficialRoundGuid
 Service.boost(p,guid..':boost:1');Service.boost(p,guid..':boost:1')
 for lap=1,2 do
  for i=0,100 do
   local f=(i/100)%1;local pos=rb.Vector3.new(math.cos(f*2*math.pi)*1000/(2*math.pi),0,math.sin(f*2*math.pi)*1000/(2*math.pi))
   Service.progress(p,(lap-1)*20+i*.2,pos,f,math.min(7,math.floor(i/14)+1))
  end
  Service.lap(p,lap*20)
 end
 p.attrs.RaceState='FINISHING';Service.finish(p);check(#queue==0,'real service no I/O during FINISHING')
 p.attrs.RaceState='FINISHED';Service.finish(p)
 return guid
end
local firstGuid=runRound();check(p.attrs.RaceRecordSaveState=='SAVE_PENDING','Reserved submission pending')
while #queue>0 do table.remove(queue,1)() end
check(calls>0 and p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED' and indexCalls==2,'actual service live binding mocked standard/ordered I/O')
local scope=S.recordScope('Track02','PrototypeCircuitV2B','KDM_R8A3_RULES_V1','SOLO_1H_0B')
check(value.records.scoped[scope].bestLapMilliseconds==20000 and value.records.scoped[scope].officialBoostLifetime==1,'service official stored PB and actual event dedup')
check(value.selection.kartId=='Kart07' and value.wallet.cash==123,'service A2 data retained')
local secondGuid=runRound();check(firstGuid~=secondGuid,'real service generates fresh RoundGuid on Rematch')
while #queue>0 do table.remove(queue,1)() end
check(value.records.scoped[scope].officialBoostLifetime==2,'two different official Rounds exactly twice')
role='HUB';game.PrivateServerId=''
local reply=remote.OnServerInvoke(p)
check(reply.status=='FOUND' and reply.records.scoped[scope].bestLapMilliseconds==20000 and reply.receipts==nil,'returning HUB personal query, no sensitive profile')
check(remote.OnServerInvoke(p).status=='RATE_LIMITED','query rate limited')
local other={UserId=2};local before=calls
check(remote.OnServerInvoke(other).status=='ACCESS_BLOCKED' and calls==before,'ordinary user zero records API calls')
studio=true;role='RACE';game.PrivateServerId='reserved';before=calls
runRound();while #queue>0 do table.remove(queue,1)() end
check(calls==before and remote.OnServerInvoke(p).status=='ACCESS_BLOCKED','Studio API OFF no actual DataStore lookup')
print('PASS: '..checks..' actual server service HUB/Reserved wiring checks with injected Roblox API mocks; live calls zero')
