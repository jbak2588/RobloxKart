local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local standard=luau.load(fs.readFile('src/shared/TrackSurfaceStandard.luau'),{environment={Color3=rb.Color3,Vector3=rb.Vector3}})()
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment={CFrame=rb.CFrame}})()
local n=0;local function check(v,m)assert(v,m);n+=1 end
for _,id in catalog.Order do check(id~='Track02','retired V2B absent from selectable tracks')end
check(#catalog.Order==5 and catalog.Entries.Track02~=nil,'five selectable tracks / legacy ID retained for existing records')
for _,id in {'Track01','Track01Race','Track03'}do check(standard.eligible('RACE',id,false),'target '..id)end
for _,id in {'Track02','Track01Desert','Track01Metro'}do check(not standard.eligible('RACE',id,false),'other theme / retired track untouched '..id)end
check(standard.eligible('HUB',nil,true),'Park target');check(not standard.eligible('HUB','Track01',false),'legacy Hub excluded')
check(standard.RailSize==rb.Vector3.new(.5,4.5,20),'Park / Desert / Metro ad size')
check(standard.RoadTint==rb.Color3.fromRGB(226,220,188),'Desert road tint')
check(standard.Lighting.Brightness==2 and standard.Lighting.ExposureCompensation==-.2 and standard.Lighting.EnvironmentSpecularScale==.25,'Desert exposure / reflection reference')
local source=fs.readFile('src/assets/KDMDesertResources.rbxmx')
for _,id in {'15217440826','15217430764','15217430840'}do check(source:find('rbxassetid://'..id,1,true)~=nil,'original Desert map retained '..id)end
check(standard.Sun.ClockTime==13 and standard.Sun.GeographicLatitude==23.5,'high sun at 1 pm with tropical latitude')
check(standard.Lighting.ClockTime==standard.Sun.ClockTime and standard.Lighting.GeographicLatitude==standard.Sun.GeographicLatitude,'all official themes share sun settings')
check(standard.ParkRoadTint.R<standard.RoadTint.R*.8 and standard.ParkRoadTint.B>standard.ParkRoadTint.R,'Park dark neutral tint')
check(standard.MarkingLift>=.2,'distant paint clearance above asphalt')
local project=require('@lune/serde').decode('json',fs.readFile('default.project.json'))
local lighting=project.tree.Lighting['$properties']
check(lighting.ClockTime==standard.Sun.ClockTime and lighting.GeographicLatitude==standard.Sun.GeographicLatitude,'Rojo default sun matches runtime themes before client startup')
print('PASS: '..n..' surface reference / selected list / theme isolation checks')
