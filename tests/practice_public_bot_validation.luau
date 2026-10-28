-- P2B catalog authority, exact checkpoint freeze and BOTH production Bot lifecycles.
local fs,luau,rb,process=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/process')
local inverse=require('./helpers/p2b_track_capability_freeze')
local serde=require('@lune/serde')
-- Canonical LF SHA256 from accepted 749f8726; no Git or local evidence dependency.
local acceptedHashes={
 ["src/shared/TrackCatalog.luau"]="625807a861d1aaf9aa512a9ca6178966668558df6f64998a05afd8cf48f59355",
 ["src/server/RaceBotController.luau"]="1802aad12c4f8070f3e1393c701e1f6d82518f1c251621d64498b9f686ae1e6e",
 ["src/server/RaceRoomCoordinator.luau"]="d6c4a9dfa94b9276be7e26bd7aaae9b6e1c38366309219739e0490c4a9433565",
 ["src/server/ActiveMatchDirectory.luau"]="a984c011d488c0af02b5cfc62cab2a599f450929dbb724d35b1e8febbdd809c3",
 ["src/server/RaceController.luau"]="bcf763d3b52498b2e3b3e30dbd880ce797d84e0be9adae61a08b955ba9505b56",
 ["src/shared/TrackGeometry.luau"]="948529127458727a6b1ad44e33fdcc2cf59a0ca7df64e8c18865e0a2689f75b9",
 ["src/server/TrackBuilder.luau"]="1d5c2aa7ede3d8eb754ac2aee27c8b5ca00cdd36aa0acaf6b91a83ad9e015eca",
 ["src/server/RaceBotSteering.luau"]="ac791bc076f553d2976b3cc9f41c5fb58e6e279094680377d31435acc14c78a7",
 ["src/server/PrototypeWorld.luau"]="eaf5d827d7088ec03893d1a3818510e20ccdd8d08a54f733687e4dea6815c16a",
 ["src/shared/KartConfig.luau"]="3334742ce602f3de524c3930ab3d7027f5873a94f34fa98380c9c9a6fa829c1f",
 ["src/shared/KDMGameplayBalance.luau"]="75c5a17623f3d58f4afeada496f3dd00c5a49fec031ed2c37acb1a183dd001a1",
 ["src/server/RacerCollisionIsolation.luau"]="00c72c2aecaa1cb7e7cde6f4bfab80e7596ebd5c4f4f6be005cc31f6713e4eb9",
}
local historical=table.find(process.args,'--historical')~=nil
local release=require('./helpers/release_source_freeze')
local manifest=serde.decode('json',fs.readFile('tests/fixtures/source_freeze_release_f5ebec8.json'))
local n=0
local function check(v,label)assert(v,label);n+=1 end
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment={CFrame=rb.CFrame}})()
for _,id in catalog.Order do
 local t=catalog.Entries[id]
 check(t.MatchType=='PUBLIC_RACE' and t.MinPlayers==1 and t.MaxPlayers==4,'public 1–4 '..id)
 check(t.TargetLaps==(if id=='Track01' or id=='Track01Desert' then 3 else 2),'lap authority '..id)
 check(catalog.botAllowed(id)==(id=='Track01' or id=='Track01Desert' or id=='Track01Race' or id=='Track01Metro'),'single Bot capability '..id)
end
check(not catalog.botAllowed('Unknown') and not catalog.botAllowed(nil),'unknown denied')
check(catalog.capabilityLabel(catalog.Entries.Track01)=='PUBLIC RACE • 1–4 RACERS • 3 LAPS','natural Practice label')
for _,path in {'src/shared/TrackCatalog.luau','src/server/RaceBotController.luau','src/server/RaceRoomCoordinator.luau','src/server/ActiveMatchDirectory.luau','src/server/RaceController.luau',
 'src/shared/TrackGeometry.luau','src/server/TrackBuilder.luau','src/server/RaceBotSteering.luau','src/server/PrototypeWorld.luau','src/shared/KartConfig.luau','src/shared/KDMGameplayBalance.luau','src/server/RacerCollisionIsolation.luau'} do
 local current=fs.readFile(path)
 if historical then
 check(serde.hash('sha256',inverse(current))==acceptedHashes[path],'historical P2B bytes '..path)
 else check(release.accepts(manifest,path,current),'current approved release integrity '..path)end
 local mutation=current..'\n-- unrelated change\n'
 if historical then
 check(serde.hash('sha256',inverse(mutation))~=acceptedHashes[path],'historical mutation rejection '..path)
 else check(not release.accepts(manifest,path,mutation),'current mutation rejection '..path)end
end
for _,id in {'Track01Race','Track01'} do
 local result=process.exec('lune',{'run','tests/production_bot_validation.luau',id})
 check(result.ok,'same actual production Bot/Directory/Coordinator lifecycle '..id..': '..result.stderr)
 print(result.stdout)
end
print('PASS: '..n..' P2B capability/exact freeze checks + both authoritative production lifecycles')
