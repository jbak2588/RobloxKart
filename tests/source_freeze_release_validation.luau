local fs,serde=require('@lune/fs'),require('@lune/serde')
local manifest=serde.decode('json',fs.readFile('tests/fixtures/source_freeze_release_f5ebec8.json'))
local freeze=require('./helpers/release_source_freeze')
local n=0
local function check(ok,label)assert(ok,label);n+=1 end
check(manifest.schema==1 and manifest.approvedHead=='f5ebec8c7f86dac5c488f90a0a01041d147cf4a2','explicit owner-approved release')
local protected={}
local n1=serde.decode('json',fs.readFile('tests/fixtures/speed_sensation_starting_hashes.json'))
local n2=serde.decode('json',fs.readFile('tests/fixtures/n2_source_freeze.json'))
for path in n1.hashes do protected[path]=true end
for path in n2.frozenHashes do protected[path]=true end
for path in n2.candidateHashes do protected[path]=true end
for path in protected do check(manifest.files[path]~=nil,'historical target remains protected '..path)end
for _,path in {'src/shared/GasPedalPolicy.luau','src/client/MobileControlView.luau','src/server/LobbyTestDriveService.luau'}do
 check(manifest.files[path]~=nil,'current mobile release protected '..path)
end
for path,hash in manifest.historicalArtifacts do
 check(serde.hash('sha256',freeze.canonical(fs.readFile(path)))==hash,'historical fixture/validator unchanged '..path)
end
local errors,classes=freeze.collect(manifest,fs.readFile)
-- Aggregate all targets, then fail: never hide later mismatches behind the first.
check(#errors==0,'Current release mismatches:\n'..table.concat(errors,'\n'))
local paths={}
for path,entry in manifest.files do
 table.insert(paths,path)
 local source=fs.readFile(path)
 check(type(entry.lastCommit)=='string' and #entry.lastCommit==40,'Git provenance '..path)
 check(not freeze.accepts(manifest,path,source..'\n-- unauthorized mutation\n'),'reject extra source bytes '..path)
 check(not freeze.accepts(manifest,path,source:sub(2)),'reject deleted bytes '..path)
 check(freeze.accepts(manifest,path,freeze.canonical(source):gsub('\n','\r\n')),'LF/CRLF parity '..path)
end
table.sort(paths)
check(#paths==133,'reviewed protected set size')
for path,hash in manifest.parkOvertakePatches do
 local source=fs.readFile(path)
 check(serde.hash('sha256',freeze.canonical(source))==(manifest.hubArrivalUiPatches[path]or manifest.timeAttackRewardPatches[path]or manifest.parkItemsKioskPatches[path]or hash),'exact reviewed overtake or follow-up source '..path)
 check(not freeze.accepts(manifest,path,source..'\n-- unauthorized'), 'reject overtake mutation '..path)
 if not manifest.files[path]then table.insert(paths,path)end
end
for path,hash in manifest.parkItemsKioskPatches do
 local source=fs.readFile(path)
 check(serde.hash('sha256',freeze.canonical(source))==(manifest.hubArrivalUiPatches[path]or manifest.timeAttackRewardPatches[path]or hash),'exact item/kiosk/terminology follow-up '..path)
 check(not freeze.accepts(manifest,path,source..'\n-- unauthorized'),'reject follow-up mutation '..path)
 if not table.find(paths,path)then table.insert(paths,path)end
end
for path,hash in manifest.timeAttackRewardPatches do
 local source=fs.readFile(path)
 check(serde.hash('sha256',freeze.canonical(source))==(manifest.hubArrivalUiPatches[path]or hash),'exact finish-only reward/top HUD change '..path)
 check(not freeze.accepts(manifest,path,source..'\n-- unauthorized'),'reject reward/HUD mutation '..path)
 if not table.find(paths,path)then table.insert(paths,path)end
end
for path,hash in manifest.hubArrivalUiPatches do
 local source=fs.readFile(path)
 check(serde.hash('sha256',freeze.canonical(source))==hash,'exact arrival/UI approval '..path)
 check(not freeze.accepts(manifest,path,source..'\n-- unauthorized'),'reject arrival/UI mutation '..path)
 check(not freeze.accepts(manifest,path,source:sub(2)),'reject arrival/UI deletion '..path)
 if not table.find(paths,path)then table.insert(paths,path)end
end
table.sort(paths)
local p='src/shared/KDMSpeedSensation.luau'
local candidate=fs.readFile(p)
check(classes[p]=='FOV_PHASE1','working FOV is exact approved Phase1')
check(classes['src/client/KartWorldSpeedRenderer.luau']=='SPEED_V2_PHASE1','speed renderer is exact approved Speed V2 Phase 1')
local original=candidate:gsub('HIGH_SPEED_START = 50','HIGH_SPEED_START = 55',1):gsub('HIGH_SPEED_FULL = 90','HIGH_SPEED_FULL = 80',1):gsub('HIGH_SPEED = table.freeze%({FovDelta=5,','HIGH_SPEED = table.freeze({FovDelta=3,',1)
check(freeze.accepts(manifest,p,original),'original approved profile also accepted for rollback')
for _,mutation in {
 candidate:gsub('HIGH_SPEED_START = 50','HIGH_SPEED_START = 49',1),
 candidate:gsub('HIGH_SPEED_FULL = 90','HIGH_SPEED_FULL = 91',1),
 candidate:gsub('HIGH_SPEED = table.freeze%({FovDelta=5,','HIGH_SPEED = table.freeze({FovDelta=6,',1),
 candidate:gsub('MINI_BOOST = table.freeze%({FovDelta=6,','MINI_BOOST = table.freeze({FovDelta=7,',1),
 candidate:gsub('Speed.MAX_FOV = 87','Speed.MAX_FOV = 88',1),
 candidate:gsub('Speed.ATTACK_RESPONSE = 10','Speed.ATTACK_RESPONSE = 11',1),
 candidate:gsub('HIGH_SPEED_START = 50','HIGH_SPEED_START = 55',1),
} do check(not freeze.accepts(manifest,p,mutation),'reject wrong/partial FOV, Boost, MAX_FOV or easing change')end
check(not freeze.accepts(manifest,'src/unreviewed.luau','return true'),'unknown file is not implicitly approved')
local badA,badB=paths[1],paths[#paths]
local collected=freeze.collect(manifest,function(path)
 if path==badA then error('missing')end
 return fs.readFile(path)..(if path==badB then '\n-- unauthorized'else '')
end)
check(#collected==2 and collected[1]:find(badA,1,true) and collected[2]:find(badB,1,true),'report all missing/mutated targets, not only first')
print('PASS: '..n..' current release integrity, historical preservation, exact FOV approval and mutation rejection checks across '..#paths..' files')
