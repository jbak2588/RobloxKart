local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local function load(p,env) return luau.load(fs.readFile(p),{environment=env or {},debugName=p})() end
local S=load('src/shared/KDMProgressionSchema.luau')
local schema=S.new(load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum}))
local Ops=load('src/server/RaceRecordOperations.luau')
local Collector=load('src/server/OfficialRaceRecords.luau')
local Policy=load('src/server/RaceRecordPolicy.luau');local Config=load('src/server/RaceRecordConfig.luau')
local count=0
local function check(value,label) count+=1;assert(value,label) end
local guid='12345678-1234-1234-1234-123456789012'
local guid2='12345678-1234-1234-1234-123456789013'
local function player(id)
 local p={UserId=id,attrs={RaceState='RACING'}}
 function p:GetAttribute(k) return self.attrs[k] end
 function p:SetAttribute(k,v) self.attrs[k]=v end
 return p
end
local function round(roster,geometry,id)
 return S.freezeRound({RoundGuid=id or guid,TrackId='Track02',GeometryId=geometry or 'PrototypeCircuitV2B',
  RulesetId=Config.RulesetId,diagnostic=false,roster=roster or {{IsBot=false,UserId=1}}})
end
local function op(lap,boost,id,r)
 return {kind='OFFICIAL_RECORD',round=r or round(nil,nil,id),userId=1,bestLapMilliseconds=lap,bestRaceBoosts=boost,
  achievedAt=1791650000000,verification={serverAccepted=true,state='FINISHED',targetLaps=2,completedLaps=2,
   fullLapValid=lap~=nil,provenance='FULL_ROUTE_V1',boostIdentity='SERVER_SERIAL_V1'}}
end
for n=1,4 do
 local roster={};for id=1,n do table.insert(roster,{IsBot=false,UserId=id}) end
 check(round(roster).RaceCategory==(if n==1 then 'SOLO_1H_0B' else 'HUMAN_'..n..'H_0B'),'actual humans '..n)
end
check(round({{IsBot=false,UserId=1},{IsBot=true,BotId='Bot01'}}).RaceCategory=='BOT_1H_1B','Bot isolated')
check(round({{IsBot=false,UserId=1},{IsBot=false,UserId=2},{IsBot=true,BotId='Bot01'}}).RaceCategory=='BOT_ASSISTED_2H_1B','Bot assisted')
check(round().recordScope~=round(nil,'PrototypeCircuitV2').recordScope,'legacy and B distinct')
check(S.recordScope('Track01','PrototypeCircuitV2B',Config.RulesetId,'SOLO_1H_0B')~=round().recordScope,'tracks separate')
check(S.recordScope('Track02','PrototypeCircuitV2B','rules2','SOLO_1H_0B')~=round().recordScope,'rules separate')
local p=schema.default(1);p.selection.kartId='Kart07';p.wallet.cash=123;p.cosmetics.ownedPartIds.wheel=true
p.receipts['selection:old']={signature='old'};p.extraFuture={preserve=true}
local original=S.clone(p)
local a=op(50000,7)
local reduced,status=Ops.reduce(S,schema,a)(p)
check(status=='APPLIED' and schema.validate(reduced,'u:1'),'new record schema valid')
local scope=a.round.recordScope
check(reduced.records.scoped[scope].bestLapMilliseconds==50000,'single lap ms')
check(reduced.records.scoped[scope].bestRaceBoosts==7 and reduced.records.scoped[scope].officialBoostLifetime==7,'Drift and lifetime')
check(S.canonical(reduced.selection)==S.canonical(original.selection) and S.canonical(reduced.wallet)==S.canonical(original.wallet)
 and S.canonical(reduced.cosmetics)==S.canonical(original.cosmetics) and reduced.extraFuture.preserve,'A2 and future fields retained')
check(reduced.receipts['selection:old'] == nil, 'old receipts pruned')
check(reduced.records.metadata[scope].lap.roundGuid==guid and reduced.records.metadata[scope].boost.achievedAt==a.achievedAt,'evidence retained')
local replay,rs=Ops.reduce(S,schema,a)(reduced)
check(rs=='REPLAY' and S.canonical(replay)==S.canonical(reduced),'same Round retry idempotent')
local twice=Ops.reduce(S,schema,a)(p);check(S.canonical(twice)==S.canonical(reduced),'UpdateAsync callback replay deterministic')
local b=op(55000,4,guid2)
local slow=Ops.reduce(S,schema,b)(reduced)
check(slow.records.scoped[scope].bestLapMilliseconds==50000 and slow.records.scoped[scope].bestRaceBoosts==7,'slower/worse cannot overwrite')
check(slow.records.scoped[scope].officialBoostLifetime==11,'new Rematch increments once')
local reverse=Ops.reduce(S,schema,a)(Ops.reduce(S,schema,b)(p))
check(S.canonical(reverse.records.scoped)==S.canonical(slow.records.scoped),'cross server reverse ordering min/max/lifetime')
local better=op(49000,8,'12345678-1234-1234-1234-123456789014')
local improved=Ops.reduce(S,schema,better)(slow)
check(improved.records.scoped[scope].bestLapMilliseconds==49000 and improved.records.scoped[scope].bestRaceBoosts==8,'better record replaces')
check(Ops.confirm(S,schema,{status='FOUND',value=improved},better)~=nil,'current receipt survives other server improvement')
check(not Ops.confirm(S,schema,{status='ERROR'},a),'failed read never confirmation')
local mutation=S.clone(a);mutation.bestRaceBoosts=9
check(select(2,Ops.reduce(S,schema,mutation)(reduced))=='IDENTITY_MISMATCH','same identity different payload rejected')
local bad=S.clone(a);bad.verification.state='FINISHING';check(not Ops.valid(S,bad),'FINISHING excluded')
bad=S.clone(a);bad.round.diagnostic=true;check(not Ops.valid(S,bad),'diagnostic excluded')
bad=S.clone(a);bad.userId=2;check(not Ops.valid(S,bad),'not starter excluded')
bad=S.clone(a);bad.bestLapMilliseconds=0;check(not Ops.valid(S,bad),'zero lap rejected')
check(select(2,Ops.reduce(S,schema,a)(nil))=='PROFILE_ABSENT','race cannot create default overwrite')
local deleted=S.clone(p);deleted.deleted=true;check(select(2,Ops.reduce(S,schema,a)(deleted))=='DELETED','deleted protected')
local future=S.clone(p);future.schemaVersion=2;check(select(2,Ops.reduce(S,schema,a)(future))=='READ_ONLY','future protected')
local corrupt=S.clone(p);corrupt.selection.kartId='bad';check(select(2,Ops.reduce(S,schema,a)(corrupt))=='READ_ONLY','corrupt protected')
local bot=op(51000,6,nil,round({{IsBot=false,UserId=1},{IsBot=true,BotId='Bot01'}}))
local botProfile=Ops.reduce(S,schema,bot)(p)
check(next(botProfile.pendingIndex)==nil and botProfile.records.scoped[bot.round.recordScope].bestRaceBoosts==6,'Bot personal only, no human index')
local cleared=Ops.clearIndex(S,schema,1,scope,reduced.pendingIndex[scope])(reduced)
check(cleared.pendingIndex[scope]==nil,'repair removes acknowledged snapshot')
check(select(2,Ops.clearIndex(S,schema,1,scope,reduced.pendingIndex[scope])(improved))=='INDEX_ADVANCED','stale repair cannot clear newer dirty score')
local capSchema=S.new(load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum}),{maxReceipts=1})
check(select(2,Ops.reduce(S,capSchema,a)(p))=='RECEIPT_CAPACITY','receipt full fails closed')
local metaBad=S.clone(reduced);metaBad.records.metadata[scope].lap.roundGuid='bad'
check(not schema.validate(metaBad,'u:1'),'malformed evidence quarantined')
local ctx={isStudio=false,role='RACE',experienceId=Config.ExperienceId,placeId=Config.PlaceId,privateServerId='reserved',privateServerOwnerId=0}
check(Policy.allowed(Config,ctx,11700555357,'write'),'approved Reserved RACE write')
for _,id in {1,11700555358} do check(not Policy.allowed(Config,ctx,id,'write'),'other account denied') end
ctx.isStudio=true;check(not Policy.allowed(Config,ctx,11700555357,'write'),'Studio blocked');ctx.isStudio=false
ctx.privateServerOwnerId=123;check(not Policy.allowed(Config,ctx,11700555357,'write'),'VIP blocked');ctx.privateServerOwnerId=0
ctx.role='HUB';ctx.privateServerId='';check(Policy.allowed(Config,ctx,11700555357,'read') and not Policy.allowed(Config,ctx,11700555357,'write'),'Hub read, no result submission')
check(Policy.indexScope(Config,reduced.pendingIndex[scope])~=nil and Policy.indexScope(Config,{geometryId='unknown'})==nil,'strict index registry')
local wrongPair=S.clone(reduced.pendingIndex[scope]);wrongPair.trackId='Track01'
check(Policy.indexScope(Config,wrongPair)==nil,'geometry cannot index under an unrelated track')
local function fixture()
 local u=player(1);local collector=Collector.new(S,{utcMs=function() return 1791650000000 end})
 collector.begin(S.clone(round()),{u},6,2,1000);collector.start(u,0);return collector,u
end
local function point(f) return rb.Vector3.new(math.cos(f*math.pi*2)*1000/(2*math.pi),0,math.sin(f*math.pi*2)*1000/(2*math.pi)) end
local function lap(c,u,start,invalid,shortcut)
 for i=0,100 do
  local f=(i/100)%1
  if not shortcut or i<30 or i>70 then c.sample(u,start+i*0.2,point(f),f) end
  if invalid and i==50 then c.invalidate(u) end
  c.checkpoints(u,math.min(7,math.floor(i/14)+1))
 end
 return c.lap(u,start+20)
end
local c,u=fixture()
check(c.boost(u,guid..':boost:1') and not c.boost(u,guid..':boost:1') and not c.boost(u,nil),'actual identity and duplicate rejection')
check(lap(c,u,0,false,false),'full valid lap accepted')
check(lap(c,u,20,false,false),'second full valid lap accepted')
u:SetAttribute('RaceState','FINISHING');check(not c.finish(u),'no finish envelope during roll')
u:SetAttribute('RaceState','FINISHED');local result=c.finish(u)
check(result.bestLapMilliseconds==20000 and result.bestRaceBoosts==1,'valid single lap, success count envelope')
check(not c.finish(u) and not c.boost(u,'e2'),'finish callback/event dedup')
c,u=fixture();check(not lap(c,u,0,true,false),'fall timer reset lap never PB')
check(lap(c,u,20,false,false),'next full start/finish lap can qualify')
u:SetAttribute('RaceState','FINISHED');check(c.finish(u).bestLapMilliseconds==20000,'invalid partial lap cannot win')
c,u=fixture();check(not lap(c,u,0,false,true),'shortcut/discontinuity excluded')
check(not lap(c,u,20,true,false),'second invalid lap excluded');u:SetAttribute('RaceState','FINISHED')
check(c.finish(u).bestLapMilliseconds==nil,'finished without eligible lap does not invent PB')
c,u=fixture();u:SetAttribute('RaceState','DNF');check(not c.finish(u),'DNF cannot produce official result')
check(c.round().RaceCategory=='SOLO_1H_0B','manifest frozen')
c.begin(S.clone(round(nil,nil,guid2)),{u},6,2,1000);c.start(u,0);u:SetAttribute('RaceState','RACING')
check(not c.boost(u,guid..':boost:100') and c.boost(u,guid2..':boost:101'),'late old Round success cannot count in Rematch')
local Geometry=load('src/shared/TrackGeometry.luau',{Vector2=rb.Vector2,Vector3=rb.Vector3,CFrame=rb.CFrame})
for _,geometryId in {'PracticeFigure8V1','PracticeCircuitV1','PrototypeCircuitV2','PrototypeCircuitV2B','HardCircuitV1'} do
 local course=Geometry.getCourse(Geometry.getDefinition(geometryId))
 local racer=player(1);local observer=Collector.new(S,{utcMs=function() return 1791650000000 end})
 observer.begin(S.clone(round(nil,geometryId)),{racer},6,1,course.CenterlineLength);observer.start(racer,0)
 for i=0,#course.Samples do
  local idx=i%#course.Samples+1;local f=(i/#course.Samples)%1
  observer.sample(racer,i*.4,course.Samples[idx],f)
  observer.checkpoints(racer,math.min(7,math.floor(i/#course.Samples*6)+1))
 end
 check(observer.lap(racer,#course.Samples*.4),'actual geometry full-route provenance '..geometryId)
end
print('PASS: '..count..' official category, fairness, min/max, receipt and preservation checks')
