-- Current-source binding and normal Builder generation, without historical projection.
local fs, luau, rb, serde = require('@lune/fs'), require('@lune/luau'), require('@lune/roblox'), require('@lune/serde')
local H = require('./helpers/track02_b_world')
local source = fs.readFile('src/shared/TrackCatalog.luau'):gsub('\r\n','\n')
assert(serde.hash('sha256',source) == '2febe32cea59b45e884b879f334b148e398d43268f158eacd5dff57ea6d65f3e', 'PV545 Catalog parity')
local catalog = luau.load(source,{environment={CFrame=rb.CFrame}})()
local t = catalog.Entries.Track02
assert(t.Id=='Track02' and t.GeometryId=='PrototypeCircuitV2B' and t.DisplayName=='Prototype V2B TEST')
assert(t.MatchType=='PUBLIC_RACE' and t.MaxPlayers==4 and t.TargetLaps==2)
assert(t.PreviewImageAssetId=='rbxassetid://104449535838897' and #t.GridSlots==4 and t.BotAllowed==nil)
local boundarySource = fs.readFile('tests/track_environment_validation.luau')
local cut = assert(boundarySource:find('local prototype=object("Folder")',1,true))
local real = luau.load(boundarySource:sub(1,cut-1)..'\nreturn {builder=builder,object=object}\n')()
local world = real.builder.build(real.object('Folder'),t,0)
for _,child in world:GetChildren() do world[child.Name]=child end
assert(world:GetAttribute('TrackId')=='Track02' and world:GetAttribute('GeometryId')=='PrototypeCircuitV2B')
assert(#world.Road:GetChildren()==303 and #world.BarrierTriggers:GetChildren()==76)
assert(world:GetAttribute('CheckpointCount')==6 and math.abs(world:GetAttribute('CenterlineLength')-4240.854)<.01)
assert(H.geometry.Definitions.PrototypeCircuitV2 and H.geometry.Definitions.PrototypeCircuitV2B, 'Legacy preserved')
for _,slot in t.GridSlots do assert(H.onRoad(world,slot.Position), 'unchanged grid on B road') end
print('PASS: actual PV545 Catalog → Track02 → real Builder; 303 Roads / 76 Triggers / 6 CP; Legacy retained')
