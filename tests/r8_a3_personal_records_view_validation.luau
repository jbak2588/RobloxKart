local fs,luau=require('@lune/fs'),require('@lune/luau')
local touched=0
local C=luau.load(fs.readFile('src/client/PersonalRecordsController.luau'),{environment={game={GetService=function() touched+=1;return {LocalPlayer={UserId=42}} end}}})()
local function check(v,label) assert(v,label) end
C.start();check(touched==1,'noncanary exits before UI/services/remote access')
for _,status in {'ERROR','READ_ONLY','ABSENT','ACCESS_BLOCKED','RATE_LIMITED'} do
 check(C.lines({status=status})[1]=='RECORDS: '..status,'never turn failure into saved values')
end
check(C.lines(nil)[1]=='RECORDS: ERROR','lost response')
check(#C.lines({status='FOUND',records={scoped={}}})==2,'empty profile')
local response={status='FOUND',records={scoped={a={bestLapMilliseconds=73245,bestRaceBoosts=8,officialBoostLifetime=19}},
 metadata={a={lap={trackId='Track02',geometryId='PrototypeCircuitV2B',category='SOLO_1H_0B'}}}}}
local text=table.concat(C.lines(response),'\n')
check(text:find('PB LAP 1:13.245',1,true)~=nil,'milliseconds formatted accurately')
check(text:find('BEST BOOSTS 8',1,true)~=nil and text:find('TOTAL OFFICIAL BOOSTS 19',1,true)~=nil,'separate best/lifetime counts')
check(text:find('Prototype Circuit V2B / Solo',1,true)~=nil,'scope identity visible')
response.records.scoped.a.bestLapMilliseconds=nil
check(table.concat(C.lines(response),'\n'):find('PB LAP --',1,true)~=nil,'invalid lap not fabricated')
print('PASS personal records viewer: 12 checks')
