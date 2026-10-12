-- Reuse the rigid assembly fixture; compare PV620 configuration to D2 entry/counter action.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/r8_d1_slide_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find("for _,speed in {30,50,65}",1,true))-1)
luau.load(prefix..[[
local current=c;local baseline=table.clone(c);baseline.EntryExtraDegrees=0;baseline.SlipRateDegrees=60
local comparisons={}
for _,speed in {30,50,65} do for _,side in {-1,1} do
 c=baseline;local old=trial('ARCADE',speed,side,1/60)
 c=current;local new=trial('ARCADE',speed,side,1/60)
 assert(new.rearEntrySpeed>old.rearEntrySpeed,'real rear entry sweep improves')
 assert(math.abs(new.radius-old.radius)<.02,'steady radius retained')
 table.insert(comparisons,{speed=speed,side=side,oldRearSpeed=old.rearEntrySpeed,newRearSpeed=new.rearEntrySpeed,
  oldRadius=old.radius,newRadius=new.radius,exit=new.exitSeconds})
 trial('ARCADE',speed,side,1/30,true);trial('ARCADE',speed,side,1/120,true)
end end
fs.writeFile('artifacts/r8-d2/physics-comparison.json',serde.encode('json',{status='PASS',rows=comparisons,checks=checks}))
print('PASS: '..checks..' D2/PV620 entry, countersteer, frame-rate and stable radius comparisons')
]])()
