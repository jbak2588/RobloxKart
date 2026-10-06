-- Production RaceLoadout reward transaction, including four independent racers.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local modules={RaceItemCatalog=luau.load(fs.readFile("src/shared/RaceItemCatalog.luau"))()}
local node={WaitForChild=function(_,name) return {Name=name} end}
local env={script={Parent=node},game={GetService=function() return {WaitForChild=function() return node end} end},
 require=function(m) return assert(modules[m.Name],m.Name) end}
modules.RaceItemSlots=luau.load(fs.readFile("src/shared/RaceItemSlots.luau"),{environment=env})()
local Loadout=luau.load(fs.readFile("src/server/RaceLoadout.luau"),{environment=env})()
local required=require("./helpers/gameplay_config")("src/shared/RaceItemConfig.luau").DRIFT_BONUS_REQUIRED_BOOSTS
local checks=0
local function check(v,label) assert(v,label);checks+=1 end
local function boost(l,n) for _=1,n do l:recordBoost(required) end end
local function use(l,accepted) return l:useItem("Nitro",function() return accepted,"fixture" end) end
local l=Loadout.new();l:prepare()
check(required==5 and modules.RaceItemCatalog.Nitro.MaxCharges==2,"frozen requirement and held capacity")
check(not l:grantBonusNitro(),"server primitive cannot bypass a completed cycle")
for cycle=1,12 do
 boost(l,4);check(l.bonusProgress==4 and l.bonusAwardCount==cycle-1,"four successes do not award")
 boost(l,1);check(l.counts.Nitro==2 and l.bonusProgress==0 and not l.bonusPending
  and l.bonusAwardCount==cycle and l.bonusEverAwarded,"unlimited repeated completed cycle "..cycle)
 check(use(l,true) and l.counts.Nitro==1,"consume to make room for next cycle")
end
boost(l,5);local awards=l.bonusAwardCount
boost(l,5)
check(l.bonusProgress==5 and l.bonusPending and l.counts.Nitro==2 and l.bonusAwardCount==awards,"full stores pending without prematurely recording an award")
boost(l,20)
check(l.bonusProgress==5 and l.bonusPending and l.bonusAwardCount==awards,"pending freezes all further successes")
for _,badId in {"Unknown","Smoke",""} do
 check(not l:useItem(badId,function() error("bad selection reached activation") end),"invalid selection rejects")
end
for _=1,3 do check(not use(l,false) and l.counts.Nitro==2 and l.bonusPending and l.bonusProgress==5
 and l.bonusAwardCount==awards,"rejected activation cannot consume or settle") end
check(use(l,true) and l.counts.Nitro==2 and not l.bonusPending and l.bonusProgress==0
 and l.bonusAwardCount==awards+1,"accepted consumption and pending award settle in one transaction")
local racers={}
for i=1,4 do racers[i]=Loadout.new();racers[i]:prepare() end
boost(racers[1],4);boost(racers[2],10);boost(racers[4],2)
check(racers[1].bonusProgress==4 and racers[2].bonusPending and racers[3].bonusProgress==0
 and racers[4].bonusProgress==2,"four-racer distinct state fixture")
boost(racers[1],1)
check(racers[1].bonusAwardCount==1 and racers[2].bonusPending and racers[3].bonusAwardCount==0
 and racers[4].bonusProgress==2,"one BOOST affects only its owner")
check(use(racers[2],true) and racers[2].bonusAwardCount==2 and racers[1].bonusAwardCount==1
 and racers[3].counts.Nitro==1 and racers[4].bonusProgress==2,"pending settlement isolates inventory")
for _,racer in racers do
 racer:clear();check(racer.bonusProgress==0 and not racer.bonusPending and racer.bonusAwardCount==0
 and not racer.bonusEverAwarded and racer.counts.Nitro==0,"teardown resets all authoritative bonus state")
 racer:prepare();check(racer.counts.Nitro==1 and racer.bonusAwardCount==0,"rematch restores initial Nitro")
end
l:prepare({"Shield","Slick","Missile","Smoke"})
boost(l,20);check(l.counts.Nitro==0 and l.bonusProgress==0 and not l.bonusPending,"no hidden reward without Nitro slot")
print("PASS: "..checks.." repeated Nitro transaction checks")
