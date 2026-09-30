-- Executes the production loadout/slot contract, with one test-only future item.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local count = 0
local function check(v, label) assert(v, label); count += 1 end
local catalog = table.clone(luau.load(fs.readFile("src/shared/RaceItemCatalog.luau"))())
catalog.Deferred = {Id="Deferred", Implemented=false}
catalog.TestItem = {Id="TestItem", Implemented=true, InitialCharges=1, MaxCharges=1}
local modules = {RaceItemCatalog=catalog}
local shared = {WaitForChild=function(_, name) return {Name=name} end}
local env = {script={Parent=shared}, require=function(m) return assert(modules[m.Name]) end,
 game={GetService=function() return {WaitForChild=function() return shared end} end}}
local slots = luau.load(fs.readFile("src/shared/RaceItemSlots.luau"),{environment=env})()
modules.RaceItemSlots = slots
local Loadout = luau.load(fs.readFile("src/server/RaceLoadout.luau"),{environment=env})()
local l = Loadout.new()
check(l:prepare() and #l.slots==4 and slots.RACE_ITEM_SLOT_COUNT==4, "catalog expansion keeps exactly four slots")
for index,id in {"Nitro","Slick","Shield","Missile"} do
 check(l.slots[index]==id and l.counts[id]==1, "default slot/charge "..index)
end
check(l.counts.Smoke==0 and catalog.Smoke.Implemented==true, "implemented Smoke is still absent from default")
check(not l:prepare(false) and not l:prepare("Nitro"), "non-table explicit loadouts reject instead of silently defaulting")
for _,ids in {{"Nitro","Slick","Shield"}, {"Nitro","Slick","Shield","Missile","TestItem"},
 {"Nitro","Nitro","Shield","Missile"}, {"Nitro","Deferred","Shield","Missile"},
 {"Nitro","Unknown","Shield","Missile"}, {[1]="Nitro",[2]="Slick",[4]="Missile"},
 {"Nitro","Slick","Shield","Missile",extra="TestItem"}} do
 check(not l:prepare(ids) and l.slots[2]=="Slick" and l.counts.Nitro==1,
  "invalid preparation is atomic and retains existing loadout")
end
for _,id in {"Smoke","Unknown","TestItem"} do
 check(not l:select(id) and not l:useItem(id,function() error("inactive activation") end)
  and l.counts.Nitro==1, "catalog existence never authorizes inactive item "..id)
end
local order={"Shield","Nitro","Missile","Slick"}
check(l:prepare(order), "different valid four-item ordering")
order[1]="Smoke"
check(l.slots[1]=="Shield", "caller cannot mutate prepared slots")
check(l:select("Missile") and l:prepare(l.slots,true) and l.selected=="Missile", "GO refill preserves active order and desktop selection")
check(l:useItem("Shield",function(id) return id=="Shield" end) and l.counts.Shield==0,
 "direct use uses exact active item")
check(not l:useItem("Shield",function() error("duplicate") end), "duplicate use consumes no extra charge")
check(l:grantBonusNitro() and l.counts.Nitro==2 and not l:grantBonusNitro(), "default Nitro bonus cap remains two, once")
check(l:prepare({"Shield","TestItem","Missile","Slick"}) and not l:grantBonusNitro()
 and l.counts.Nitro==0, "future loadout without Nitro cannot create hidden charge")
l:clear()
check(#l.slots==0 and l.selected=="" and l.counts.TestItem==0 and not l:grantBonusNitro(), "clear removes slots and all temporary charges")
check(l:prepare() and l.slots[1]=="Nitro" and l.counts.Nitro==1, "next race/rematch restores production default")
catalog.TestItem.InitialCharges=nil
check(not l:prepare({"Shield","TestItem","Missile","Slick"}), "missing initial charge configuration rejects preparation")
print("PASS: "..count.." four-slot loadout checks")
