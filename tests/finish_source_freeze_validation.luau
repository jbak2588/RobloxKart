local fs,serde=require('@lune/fs'),require('@lune/serde')
local fixture=serde.decode('json',fs.readFile('tests/fixtures/n2_source_freeze.json'))
local count=0;local function check(v,label)assert(v,label);count+=1 end
for path,expected in fixture.frozenHashes do
 local actual=serde.hash('sha256',require('./helpers/l2_presentation_freeze')(fs.readFile(path),path))
 check(actual==expected or (path=='src/server/CompactHubBuilder.luau' and actual==fixture.hubException),'frozen server/gameplay/N1/cache/audio '..path)
end
for path,expected in fixture.candidateHashes do
 check(serde.hash('sha256',require('./helpers/l2_presentation_freeze')(fs.readFile(path),path))==expected,'exact N2 presentation candidate '..path)
end
local normalize=require('./helpers/n2_hud_presentation_freeze')
local source=fs.readFile('src/client/RaceHudController.luau')
check(normalize(source)~=normalize(source:gsub('finishBannerScale.Scale = .88','finishBannerScale.Scale = .77',1)),
 'unauthorized mutation inside presentation hunk remains detectable')
check(normalize(source)~=normalize(source:gsub('remoteEvent:FireServer%("ReturnGarage"%)','remoteEvent:FireServer("Rematch")',1)),
 'route semantics outside presentation remain frozen')
local config=fs.readFile('src/shared/RaceConfig.luau')
check(config:find('FINISH_ROLL_SECONDS = 2.4',1,true) and config:find('FINISH_SEQUENCE_SECONDS = 3.3',1,true)
 and config:find('FINISH_CAMERA_TRANSITION_SECONDS = 0.9',1,true),'finish timings unchanged')
print('PASS: '..count..' exact N2 scope/server/physics/N1/N1B source and freeze-rejection checks')
