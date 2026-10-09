-- Gate-only inverse layer. Executes the ORIGINAL historical adapter and tests unchanged.
local fs,luau,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/serde')
local specification=fs.readFile('artifacts/r7-l3-integrated-checkpoint/exact-inverses.json')
assert(serde.hash('sha256',(specification:gsub('\r\n','\n')))=='d82ea925d8e7f763198f949422c1459e2dc4cd112ef48230fbb0e59844072e39','reviewed inverse specification changed')
local rows=serde.decode('json',specification)
local function normalized(s) return s:gsub('\r\n','\n') end
local function inverse(source,hunks,expected)
 local previous=#source+1
 for i=#hunks,1,-1 do
  local h=hunks[i]
  assert(h.start>=0 and h.finish>=h.start and h.finish<previous,'ambiguous/overlapping inverse')
  assert(source:sub(h.start+1,h.finish)==h.after,'exact inverse bytes differ')
  source=source:sub(1,h.start)..h.before..source:sub(h.finish+1)
  previous=h.start+1
 end
 assert(serde.hash('sha256',source)==expected,'inverse result differs from verified historical source')
 return source
end
local function project(source,path)
 local row=rows[path]
 if not row then return source end
 source=normalized(source)
 assert(serde.hash('sha256',source)==row.currentHash,'UNEXPECTED CURRENT SOURCE: '..path)
 return inverse(source,row.followupInverse,row.a1Hash)
end
local count=0
for path,row in rows do
 local current=normalized(fs.readFile(path))
 local a1=project(current,path)
 inverse(a1,row.a1Inverse,row.beforeHash)
 assert(not pcall(project,current..'\n-- unauthorized mutation',path),'appended mutation escaped')
 assert(not pcall(project,'-- unauthorized\n'..current,path),'protected prefix mutation escaped')
 for _,h in row.followupInverse do
  local mutated=current:sub(1,h.start)..'-- altered approved hunk\n'..current:sub(h.finish+1)
  assert(not pcall(project,mutated,path),'approved hunk mutation escaped')
 end
 count+=1
end
print('PASS: strict inverse / mutation rejection for '..count..' verified A1 paths')
if require('@lune/process').args[1]=='--self-test' then return end
local proxy=setmetatable({readFile=function(path) return project(fs.readFile(path),path) end},{__index=fs})
local function req(name)
 if name=='@lune/fs' then return proxy end
 -- Palette's nested CURRENT Garage functional check needs the existing registration harness.
 -- Keep its assertions intact and its production reads current (not projected).
 if name=='../../tests/garage_transition_validation' then return require('../r7-l3-a1-mobile-fix/garage_harness') end
 return require(name)
end
luau.load(fs.readFile('artifacts/r7-l3-a1/historical_freeze_runner.luau'),{environment={require=req}})()
