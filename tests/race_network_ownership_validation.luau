-- Production context lifecycle; the queue models SeatWeld settling after Occupant.
local fs, luau = require('@lune/fs'), require('@lune/luau')
local source = fs.readFile('tests/race_item_validation.luau') .. [[
local queue, writes = {}, 0
environment.task.defer = function(callback) table.insert(queue, callback) end
function methods:SetNetworkOwner(owner)
 self._p.networkAutomatic = false
 self._p.networkOwner = owner
 writes += 1
end
local function flush()
 local callbacks=queue; queue={}
 for _,callback in callbacks do callback() end
end
local driver=child(services.Players,'Player','OwnershipDriver');driver.UserId=910
driver.Character=object('Model','OwnershipCharacter')
local humanoid=child(driver.Character,'Humanoid','Humanoid');humanoid.Health=100
local ctx=assert(world.acquireKartContext(driver,CF.new(0,1.75,0)))
local ownershipChecks=0
local function verify(value,label) assert(value,label);ownershipChecks+=1 end
local function sit()
 -- Native SeatWeld can merge the automatic character assembly.
 ctx.chassis._p.networkAutomatic=true;ctx.chassis._p.networkOwner=driver
 ctx.seat.Occupant=humanoid
 humanoid.SeatPart=ctx.seat
end
local function leave()
 ctx.seat.Occupant=nil;humanoid.SeatPart=nil
end
for attempt=1,4 do
 local before=writes
 sit()
 verify(#queue==1 and writes==before,'seating defers until weld settles')
 flush()
 verify(writes==before+1 and ctx.chassis._p.networkOwner==nil
  and not ctx.chassis._p.networkAutomatic,'each seated driver retains manual server authority')
 flush();verify(writes==before+1,'no polling or repeated deferred writes')
 leave()
end
sit();local before=writes;leave();flush()
verify(writes==before,'leaving before deferred callback cannot take ownership')
sit();humanoid.SeatPart=nil;flush()
verify(writes==before,'incomplete seating cannot take ownership')
leave();sit();ctx:clearOwner();flush()
verify(writes==before,'released owner rejects deferred work')
leave();assert(ctx:assignOwner(driver));sit()
ctx.chassis.Parent=nil;flush()
verify(writes==before,'removed chassis rejects deferred work')
ctx.chassis.Parent=ctx.kart;leave();sit()
world.releaseKartContext(driver);flush()
verify(writes==before,'destroyed context rejects deferred work')
print('PASS: '..ownershipChecks..' deferred driver network ownership lifecycle checks')
]]
local helper=require('./helpers/gameplay_config')
luau.load(source,{debugName='race-network-ownership',environment={require=function(name)
 if name=='./helpers/gameplay_config' then return helper end
 return require(name)
end}})()
