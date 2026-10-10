-- B-only exact-source inverse. Original historical tests and fixtures are untouched.
local fs,luau,serde,process=require('@lune/fs'),require('@lune/luau'),require('@lune/serde'),require('@lune/process')
local rows=serde.decode('json',fs.readFile('artifacts/r7-n3-a1b/exact-b-inverses.json'))
local function project(source,path)
 local row=rows[path];if not row then return source end
 source=source:gsub('\r\n','\n')
 assert(serde.hash('sha256',source)==row.candidateHash,'unexpected B candidate bytes '..path)
 for i=#row.hunks,1,-1 do
  local h=row.hunks[i];assert(source:sub(h.start+1,h.finish)==h.after,'B exact inverse hunk changed')
  source=source:sub(1,h.start)..h.before..source:sub(h.finish+1)
 end
 assert(serde.hash('sha256',source)==row.baselineHash,'inverse differs from preserved baseline')
 return source
end
for path,row in rows do
 local source=fs.readFile(path);project(source,path)
 assert(not pcall(project,source..'\n-- unauthorized',path),'suffix mutation allowed')
 assert(not pcall(project,'-- unauthorized\n'..source,path),'prefix mutation allowed')
 for _,h in row.hunks do
  local normalized=source:gsub('\r\n','\n')
  local changed=normalized:sub(1,h.start)..'-- invalid approved hunk\n'..normalized:sub(h.finish+1)
  assert(not pcall(project,changed,path),'approved block mutation allowed')
 end
end
if process.args[1]=='--self-test' then print('PASS: B exact inverse and mutation rejection; current candidate tested directly');return end
local target=process.args[1];local args={};for i=2,#process.args do table.insert(args,process.args[i]) end
assert(target=='artifacts/r7-l3-integrated-checkpoint/strict_freeze_runner.luau' or target=='tests/practice_public_bot_validation.luau' or target=='tests/v2_public_multiplayer_validation.luau','unreviewed historical target')
local proxy=setmetatable({readFile=function(path)return project(fs.readFile(path),path)end},{__index=fs})
local proc=setmetatable({args=args},{__index=process})
local directory=target:match('^(.*)/[^/]+$')
local function req(name)
 if name=='@lune/fs' then return proxy end
 if name=='@lune/process' then return proc end
 if name:sub(1,1)=='.' then return require('../../'..directory..'/'..name) end
 return require(name)
end
luau.load(fs.readFile(target),{environment={require=req}})()
print('PASS: original historical assertions via exact B compatibility; no fixture changes')
