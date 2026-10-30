local fs,luau,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/serde')
local n=0;local function check(v,m)assert(v,m);n+=1 end
local function load(p)return luau.load(fs.readFile(p))()end
local function signal()local list={};return {Connect=function(_,f)table.insert(list,f)end,Fire=function(_,...)for _,f in list do f(...)end end}end
local S=load('src/shared/KDMProgressionSchema.luau');local C=load('src/shared/KDMRobuxTopUpCatalog.luau')
local karts={DefaultId='Kart05',Entries={Kart05={}}}
local schema=S.new(karts)
local stored=nil;local writes=0;local prompts={};local studio=false;local role='HUB';local closing={}
local players={PlayerRemoving=signal()}
local p={UserId=7,Parent=players,attrs={RaceState='GARAGE'}}
function p:GetAttribute(k)return self.attrs[k]end
function p:SetAttribute(k,v)self.attrs[k]=v end
function players:GetPlayerByUserId(id)return if id==7 and p.Parent==players then p else nil end
local a={read=function()return if stored then {status='FOUND',value=S.clone(stored)}else {status='ABSENT'}end,
 beginUpdate=function(_,reducer)return reducer end,commit=function(reducer)local value=reducer(stored);if value then stored=S.clone(value);writes+=1 end;return {status='SAVED'}end}
local economy={allowed=function(_,kind)return kind~='shop' or role=='HUB'end,
 accountAdapter=function(_,kind)check(kind=='initialize','receipt storage authorized in Hub and reserved Race');return a end,
 getProfile=function()return {status=if stored then 'FOUND'else 'GUEST',cash=if stored then stored.wallet.cash else 0}end,
 publishProfile=function(_,profile)p:SetAttribute('KDMWalletCash',profile.wallet.cash)end}
local market={GetProductInfoAsync=function(_,id)return {PriceInRobux=if id==C.Entries.Cash25000.ProductId then 50 else 100,IsForSale=true}end,
 PromptProductPurchase=function(_,player,id)table.insert(prompts,{player,id})end}
local shared={KDMProgressionSchema='schema',KDMRobuxTopUpCatalog='catalog',KartCatalog='karts'}
local rs={Shared=shared};local modules={schema=S,catalog=C,karts=karts,EconomyService=economy,
 RobuxTopUpOperations=load('src/server/RobuxTopUpOperations.luau'),RobuxTopUpReceiptProcessor=load('src/server/RobuxTopUpReceiptProcessor.luau')}
local gameMock={GameId=C.ExperienceId,PlaceId=C.PlaceId,GetService=function(_,name)
 return ({ReplicatedStorage=rs,Players=players,MarketplaceService=market,RunService={IsStudio=function()return studio end},
 HttpService={JSONEncode=function(_,v)return serde.encode('json',v)end,GenerateGUID=function()return 'server-preflight'end}})[name]
end,BindToClose=function(_,f)table.insert(closing,f)end}
local remote
local service=luau.load(fs.readFile('src/server/RobuxTopUpService.luau'),{environment={game=gameMock,
 workspace={GetAttribute=function()return role end},DateTime={now=function()return {UnixTimestampMillis=1000000000}end},
 script={Parent=setmetatable({},{__index=function(_,k)return k end})},require=function(m)return assert(modules[m],m)end,
 Enum={ProductPurchaseDecision={NotProcessedYet='PENDING',PurchaseGranted='GRANTED'},InfoType={Product='Product'}},
 Instance={new=function()remote={};return remote end},task={wait=function()end}}})()
service.start();local receiptHandler=market.ProcessReceipt;service.start()
check(market.ProcessReceipt==receiptHandler,'single registration')
local offers=remote.OnServerInvoke(p,'LIST');check(offers.canPurchase and #offers.offers==2,'only two configured products')
check(remote.OnServerInvoke(p,'PROMPT','Cash25000').status=='PROMPTED' and #prompts==1,'guarded native prompt')
check(stored==nil and writes==0,'prompt/preflight cannot grant or create guest account')
check(remote.OnServerInvoke(p,'CREDIT',60000).status=='UNAVAILABLE','no client credit action')
check(remote.OnServerInvoke(p,'PROMPT','Cash25000',60000).status=='UNAVAILABLE','extra amount payload rejected')
local receipt={PlayerId=7,ProductId=C.Entries.Cash25000.ProductId,PurchaseId='native-receipt-A'}
check(market.ProcessReceipt(receipt)=='GRANTED' and stored.wallet.cash==25000,'actual runtime receipt credits persistent profile')
check(p:GetAttribute('KDMTopUpState')=='SAVED' and p:GetAttribute('KDMWalletCash')==25000,'saved profile published')
role='RACE';p.attrs.RaceState='RACING'
receipt.PurchaseId='native-receipt-B';receipt.ProductId=C.Entries.Cash60000.ProductId
check(market.ProcessReceipt(receipt)=='GRANTED' and stored.wallet.cash==85000,'delayed receipt settles after player enters reserved race')
check(not remote.OnServerInvoke(p,'LIST').canPurchase,'race cannot start a purchase')
check(market.ProcessReceipt(receipt)=='GRANTED' and writes==2,'duplicate is confirmed without a new write')
studio=true;check(market.ProcessReceipt(receipt)=='PENDING' and not remote.OnServerInvoke(p,'LIST').canPurchase,'Studio never processes live payment')
studio=false;gameMock.PlaceId=1;check(market.ProcessReceipt(receipt)=='PENDING','exact production pair enforced')
gameMock.PlaceId=C.PlaceId;p.Parent=nil;check(market.ProcessReceipt(receipt)=='PENDING','leave defers')
print('PASS '..n..' actual top-up service prompt, no client grant, receipt, reserved-race, rejoin and live-scope checks')
