local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0;local function check(v,m)assert(v,m);n+=1 end
local function load(p)return luau.load(fs.readFile(p))()end
local S=load('src/shared/KDMProgressionSchema.luau')
local now=1000000000
local schema=S.new({DefaultId='Kart05',Entries={Kart01={},Kart05={}}},{utcMs=function()return now end})
local actual=load('src/shared/KDMRobuxTopUpCatalog.luau')
check(actual.Entries.Cash25000.Amount==25000 and actual.Entries.Cash25000.BaseRobux==50,'owner50 offer')
check(actual.Entries.Cash60000.Amount==60000 and actual.Entries.Cash60000.BaseRobux==100,'owner100 offer')
local catalog={byProductId=function(id)return if id==1 then actual.Entries.Cash25000 elseif id==2 then actual.Entries.Cash60000 else nil end}
local O=load('src/server/RobuxTopUpOperations.luau')
local P=load('src/server/RobuxTopUpReceiptProcessor.luau')
local receipt={PlayerId=7,ProductId=1,PurchaseId='paid-A'}
local userKey=S.userKey(7)
local p=schema.default(7);p.wallet.cash=123;p.wallet.lifetimeEarned=456
p.cosmetics.ownedPartIds.OLD_ITEM=true;p.selection.kartId='Kart05';p.onboarding.firstFinishClaimed=true
p.historicalExtension={preserved='yes'}
local first,why=O.reduce(S,schema,catalog,receipt)(p)
check(why=='CREDITED' and first.wallet.cash==25123 and first.wallet.ledgerRevision==1,'atomic credit')
check(p.wallet.cash==123 and p.robuxTopUps==nil,'callback does not mutate input')
local compare=S.clone(first);compare.wallet=S.clone(p.wallet);compare.robuxTopUps=nil
check(S.canonical(compare)==S.canonical(p),'all historical fields unchanged except cash/revision/permanent marker')
check(first.wallet.lifetimeEarned==456,'paid money never enters race earnings')
local replay=O.reduce(S,schema,catalog,receipt)(first)
check(S.canonical(replay)==S.canonical(first),'receipt redelivery idempotent')
local other=S.clone(receipt);other.ProductId=2
check(O.reduce(S,schema,catalog,other)(first)==nil,'same purchase identity cannot become a different offer')
other.PurchaseId='paid-B';local second=O.reduce(S,schema,catalog,other)(first)
check(second.wallet.cash==85123 and second.wallet.ledgerRevision==2,'repeat purchases of separate SKUs')
local guest=O.reduce(S,schema,catalog,receipt)(nil)
check(guest.wallet.cash==25000 and not guest.onboarding.firstFinishClaimed and guest.activity==nil,'guest starts0 plus paid grant; no activity or first-finish bonus')
for _,bad in {{},{PlayerId=0,ProductId=1,PurchaseId='A'},{PlayerId=7,ProductId=3,PurchaseId='A'},
 {PlayerId=7,ProductId=1,PurchaseId=''},{PlayerId=7,ProductId=1,PurchaseId='x\n'},
 {PlayerId=7,ProductId=1,PurchaseId=string.rep('x',257)}}do
 check(O.reduce(S,schema,catalog,bad)(p)==nil,'invalid identity fails closed')
end
local deleted=S.clone(p);deleted.deleted=true;check(O.reduce(S,schema,catalog,receipt)(deleted)==nil,'no deleted account resurrection')
local future=S.clone(p);future.schemaVersion=2;check(O.reduce(S,schema,catalog,receipt)(future)==nil,'future schema protected')
local full=S.clone(p);full.wallet.cash=schema.maxCash-24999;check(O.reduce(S,schema,catalog,receipt)(full)==nil,'overflow never clamps paid grant')
local corrupt=S.clone(first);corrupt.robuxTopUps={broken='bad'};check(not schema.validate(corrupt,userKey),'malformed permanent map rejected')
now+=500*86400000
local aged=schema.prepare(first,schema.issueTransaction())
check(aged and S.canonical(aged.robuxTopUps)==S.canonical(first.robuxTopUps),'500-day gameplay receipt GC never removes payment marker')
check(O.reduce(S,schema,catalog,receipt)(aged).wallet.cash==25123,'very late redelivery cannot pay twice')
local stored=nil;local writes=0;local failRead=false;local unknownAck=false;local published=0
local adapter={read=function()
 if failRead then return {status='ERROR'}end
 return if stored then {status='FOUND',value=S.clone(stored)}else {status='ABSENT'}
end,beginUpdate=function(_,reducer)return reducer end,commit=function(reducer)
 local nextValue=reducer(stored);writes+=1;if nextValue then stored=S.clone(nextValue)end
 if unknownAck then failRead=true;return {status='PENDING'}end
 return {status='SAVED'}
end}
local allowed,online=true,true
local processor=P.new({S=S,schema=schema,catalog=catalog,ops=O,granted='GRANTED',pending='PENDING',
 allowed=function()return allowed end,player=function(id)return if online and id==7 then {}else nil end,
 adapter=function()return adapter end,publish=function(_,profile)check(profile.wallet.cash==25000,'publish only verified saved cash');published+=1 end})
unknownAck=true
check(processor(receipt)=='PENDING' and stored.wallet.cash==25000 and published==0,'unknown write ACK not falsely granted')
unknownAck=false;failRead=false
check(processor(receipt)=='GRANTED' and stored.wallet.cash==25000 and writes==1,'rejoin retry proves saved receipt without another credit')
for _=1,20 do check(processor(receipt)=='GRANTED','multiple servers/redeliveries converge')end
check(writes==1 and stored.wallet.cash==25000,'single atomic grant across callback replays')
allowed=false;check(processor(receipt)=='PENDING','unapproved place/Studio fail closed');allowed=true
online=false;check(processor(receipt)=='PENDING','departed player defers until next join');online=true
failRead=true;check(processor(receipt)=='PENDING','failed storage reads never initialize over existing account')
local ui=load('src/client/RobuxTopUpController.luau')
for _,size in {rb.Vector2.new(600,240),rb.Vector2.new(740,360),rb.Vector2.new(320,600),rb.Vector2.new(1600,739)}do
 local l=ui.layout(size)
 check(l.width<=size.X-24 and l.height<=size.Y-16 and l.height>=204,'mobile safe bounded panel')
 check(108+44<=l.height-46,'both44px targets clear bottom message')
end
for _,path in {'src/server/RobuxTopUpService.luau','src/server/init.server.luau','src/client/HubUiController.luau','src/client/GarageShopController.luau'}do
 check(pcall(luau.load,fs.readFile(path)), 'runtime compiles '..path)
end
print('PASS '..n..' Robux top-up grant, permanent replay, unknown ACK, guest, preservation, authority and layout checks')
