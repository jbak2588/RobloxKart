local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local shared={WaitForChild=function(_,n)return n end}
local env={game={GetService=function()return {WaitForChild=function()return shared end}end},require=function(n)
 return luau.load(fs.readFile('src/shared/'..n..'.luau'),{environment={Color3=rb.Color3,CFrame=rb.CFrame,Vector3=rb.Vector3}})()
end}
local Session=luau.load(fs.readFile('src/server/RaceSession.luau'),{environment=env})()
local function player(bot,state)
 local p={attrs={IsBot=bot,RaceState=state or 'FINISHED'}}
 function p:GetAttribute(k)return self.attrs[k]end
 function p:SetAttribute(k,v)self.attrs[k]=v end
 return p
end
local session=Session.new('Track01Race','PUBLIC_RACE',2)
local bot,h1,h2=player(true),player(false),player(false)
session.startTime=100;session.finishOrder={{player=bot,time=20},{player=h1,time=22},{player=h2,time=25}}
session.participants={[bot]={raceStartTime=100},[h1]={raceStartTime=100},[h2]={raceStartTime=100}}
assert(session:finalizedFinish(h1,121)==nil,'clock prefix not final')
assert(session:finalizedFinish(h1,123).humanPosition==1,'Bot cannot steal human first-place payout')
assert(session:finalizedFinish(h2,126).humanPosition==2,'second human excludes Bot')
h2.attrs.RaceState='RACING';session.participants[h2].raceStartTime=101
assert(session:finalizedFinish(h1,123)==nil,'unequal GO blocks finality')
print('PASS: 4 actual RaceSession settled-prefix and human-rank checks')
