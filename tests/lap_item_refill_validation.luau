-- Reuse the production RaceController/ItemController transport fixture, then drive real gates.
-- No replacement lap/refill implementation and no authored completed-lap increment for valid laps.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local fixture = fs.readFile("tests/race_mode_validation.luau")
local boundary = assert(string.find(fixture, "local function crossFinishPlaneOutside", 1, true))
fixture = string.sub(fixture, 1, boundary - 1)
fixture = string.gsub(fixture, 'load%("src/server/RaceLoadout.luau",server,"RaceLoadout"%)', [[
local loadoutType=load("src/server/RaceLoadout.luau",server,"RaceLoadout")
local originalNew=loadoutType.new
local actualLoadout
loadoutType.new=function() actualLoadout=originalNew();return actualLoadout end
]])
local scenarios = [=[
local config=modules.RaceItemConfig
local balance=luau.load(fs.readFile("src/shared/KDMGameplayBalance.luau"))()
local policy=balance.ITEM_ECONOMY.LapRefill
check(table.isfrozen(policy) and table.isfrozen(policy.Eligible),"nested immutable policy")
check(config.LAP_REFILL_ENABLED and config.LAP_REFILL_TO==1 and config.LAP_REFILL_EMPTY_ONLY
 and config.LAP_REFILL_NON_FINAL_ONLY and config.LAP_REFILL_EXCLUDE_NITRO,"public policy adapter")
check(config.LAP_REFILL_ELIGIBLE.Shield and not config.LAP_REFILL_ELIGIBLE.Nitro,"eligible adapter")
local function empty(ids)
 for _,id in ids do assert(actualLoadout:useItem(id,function() return true end)) end
end
local function lap(dt)
 cross(checkpoints[1],nil,dt or 3);cross(checkpoints[2],nil,dt or 3);cross(finish,nil,dt or 3)
end
local function serial() return player:GetAttribute("RaceItemRefillSerial") or 0 end
local function charges(expected,label)
 for id,value in expected do check(actualLoadout.counts[id]==value,label.." "..id) end
end
for _,nitro in {0,1,2} do
 start("Track01Race")
 actualLoadout:prepare({"Nitro","Shield","Missile","Thunder"})
 actualLoadout.counts.Nitro=nitro;empty({"Shield","Missile"})
 actualLoadout.bonusProgress=5;actualLoadout.bonusPending=true
 actualLoadout.bonusAwardCount=3;actualLoadout.bonusEverAwarded=true
 local selected=actualLoadout.selected;local before=serial()
 cross(checkpoints[2]);cross(finish)
 check(serial()==before and player:GetAttribute("RaceCompletedLaps")==0,"missing checkpoint no refill")
 lap()
 charges({Nitro=nitro,Shield=1,Missile=1,Thunder=1,Slick=0,Smoke=0},"valid 1/2")
 check(serial()==before+1 and player:GetAttribute("RaceItemRefillCount")==2
  and player:GetAttribute("RaceItemRefillItems")=="Shield,Missile","one diagnostic for changed slots")
 check(player:GetAttribute("RaceChargeShield")==1 and player:GetAttribute("RaceChargeNitro")==nitro,"authoritative HUD mirrors")
 check(actualLoadout.selected==selected,"valid selection preserved")
 check(actualLoadout.bonusProgress==5 and actualLoadout.bonusPending and actualLoadout.bonusAwardCount==3
  and actualLoadout.bonusEverAwarded,"all repeatable Nitro state preserved")
 empty({"Shield","Missile"})
 kart:SetAttribute("RaceResetSerial",(kart:GetAttribute("RaceResetSerial") or 0)+1)
 charges({Shield=0,Missile=0},"recovery no refill")
 -- Attribute replay/rollback is not a valid new lap and cannot re-award after consumption.
 player:SetAttribute("RaceCompletedLaps",0);player:SetAttribute("RaceCompletedLaps",1)
 check(serial()==before+1 and actualLoadout.counts.Shield==0,"duplicate high-water mark")
 lap()
 check(player:GetAttribute("RaceCompletedLaps")==2 and serial()==before+1,"final lap no refill")
 charges({Nitro=0,Shield=0,Missile=0,Thunder=0},"existing finish teardown")
end
start("Track02")
actualLoadout:prepare({"Nitro","Slick","Smoke","Thunder"});empty({"Nitro","Slick","Smoke","Thunder"})
lap(.01)
check(player:GetAttribute("RaceCompletedLaps")==0 and actualLoadout.counts.Smoke==0,"too-fast rejected lap no refill")
local before=serial()
lap()
charges({Nitro=0,Slick=1,Smoke=1,Thunder=1,Shield=0,Missile=0},"V2 first transition")
check(actualLoadout.selected=="Slick","empty selection chooses first available slot")
empty({"Slick","Smoke","Thunder"});lap()
check(serial()==before+1 and player:GetAttribute("RaceCompletedLaps")==2
 and actualLoadout.counts.Thunder==0,"V2 second/final lap excluded")
start("Track01")
empty({"Shield","Slick","Missile"});before=serial();lap()
check(serial()==before+1 and actualLoadout.counts.Shield==1 and actualLoadout.counts.Slick==1 and actualLoadout.counts.Missile==1,"three-lap Practice uses existing non-final tactical refill")
empty({"Shield","Slick","Missile"});lap()
check(player:GetAttribute("RaceCompletedLaps")==2 and serial()==before+2 and actualLoadout.counts.Shield==1,"Practice second transition refills")
empty({"Shield","Slick","Missile"});lap()
check(player:GetAttribute("RaceCompletedLaps")==3 and serial()==before+2 and actualLoadout.counts.Shield==0,"Practice final lap has no refill")
-- Pure loadout boundary tests: disabled policy, cap, positive counts and hard Nitro exclusion.
local l=originalNew();l:prepare();l.counts.Shield=0;l.counts.Nitro=0
local ids,n=l:refillLapItems({Enabled=false,Eligible=policy.Eligible,RefillTo=1})
check(n==0 and l.counts.Shield==0,"disabled policy")
ids,n=l:refillLapItems({Enabled=true,Eligible={Nitro=true,Shield=true,Slick=true},RefillTo=99})
check(n==1 and ids[1]=="Shield" and l.counts.Shield==1 and l.counts.Nitro==0 and l.counts.Slick==1,"cap and hard empty/Nitro invariants")
ids,n=l:refillLapItems(policy);check(n==0,"no real change no diagnostic candidate")
print("PASS: "..count.." lap refill checks, real production lap/controller/loadout with mocked transport")
]=]
local loadConfig = require("./helpers/gameplay_config")
luau.load(fixture .. scenarios, {debugName="lap_item_refill_integration", environment={require=function(path)
	if path == "./helpers/gameplay_config" then return loadConfig end
	return require(path)
end}})()
-- Real active-effect/use-path integration shares the existing combat fixture.
local combat = fs.readFile("tests/race_item_reset_validation.luau")
combat = string.sub(combat, 1, assert(string.find(combat, "-- A: untouched production defaults.", 1, true)) - 1)
combat ..= [=[
prepare(owner,{"Shield","Missile","Thunder"})
owner:SetAttribute("RaceTotalLaps",3);owner:SetAttribute("RaceCompletedLaps",0)
owner:SetAttribute("RacePosition",1)
use(owner,"Nitro");use(owner,"Shield")
check(contexts[owner].kart:GetAttribute("KartShieldActive"),"real Shield effect active")
local serial=owner:GetAttribute("RaceItemRefillSerial") or 0
owner:SetAttribute("RaceCompletedLaps",1)
check(owner:GetAttribute("RaceChargeShield")==1 and owner:GetAttribute("RaceChargeNitro")==0,"active Shield inventory refilled")
check(contexts[owner].kart:GetAttribute("KartShieldActive"),"lap refill does not remove active Shield")
use(owner,"Shield")
check(owner:GetAttribute("RaceChargeShield")==1,"shield_active rejects use without consuming refilled charge")
use(owner,"Missile");use(owner,"Thunder")
check(owner:GetAttribute("RaceChargeMissile")==1 and owner:GetAttribute("RaceChargeThunder")==1,"no-target rejection preserves charge")
owner:SetAttribute("RaceCompletedLaps",0);owner:SetAttribute("RaceCompletedLaps",1)
check(owner:GetAttribute("RaceItemRefillSerial")==serial+1,"replay never increments diagnostic serial")
owner:SetAttribute("RaceCompletedLaps",2)
check(owner:GetAttribute("RaceItemRefillSerial")==serial+1,"positive inventory lap produces no diagnostic")
tick(config.SHIELD_DURATION+0.1);use(owner,"Shield")
check(owner:GetAttribute("RaceChargeShield")==0 and contexts[owner].kart:GetAttribute("KartShieldActive"),"refilled Shield usable after normal expiry")
local before=snapshot(owner);fall(owner);same(owner,before,"lap-refilled fall")
owner:SetAttribute("RaceCompletedLaps",1);owner:SetAttribute("RaceCompletedLaps",2)
check(owner:GetAttribute("RaceChargeShield")==0,"fall preserves processed-lap high-water mark")
local bot=child(services.Players,"Player","BotFixture");bot:SetAttribute("IsBot",true)
services.Players.PlayerAdded:Fire(bot)
bot:SetAttribute("RaceState","COUNTDOWN");bot:SetAttribute("RaceState","RACING")
bot:SetAttribute("RaceTotalLaps",2);bot:SetAttribute("RaceCompletedLaps",1)
check(bot:GetAttribute("RaceChargeNitro")==nil and bot:GetAttribute("RaceItemSlot1")==nil,"Bot receives no loadout")
print("PASS: "..checks.." production effect/refill/use/fall/Bot checks with mocked transport")
]=]
luau.load(combat, {debugName="lap_refill_effect_integration", environment={require=function(path)
	if path == "./helpers/gameplay_config" then return loadConfig end
	return require(path)
end}})()
