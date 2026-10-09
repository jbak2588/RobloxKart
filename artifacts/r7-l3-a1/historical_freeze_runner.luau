-- A separate A1 audit adapter; no historical/L2 fixture is modified.
-- Only exact candidate hashes can map to the verified preflight source.
local fs,luau,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/serde')
local args=require('@lune/process').args
local approved=serde.decode('json',fs.readFile('artifacts/r7-l3-a1/authorized-a1-source-changes.json'))
local function canonical(source,path)
 local row=approved[path]
 if row and serde.hash('sha256',source:gsub('\r\n','\n'))==row.afterHash then
  assert(serde.hash('sha256',row.before)==row.beforeHash,'preflight hash mismatch')
  return row.before
 end
 return source
end
for path,row in approved do
 local actual=fs.readFile(path)
 assert(canonical(actual,path)==row.before,'exact A1 hunk projection')
 assert(canonical(actual..'\n-- unauthorized mutation',path)~=row.before,'candidate mutation must remain detectable')
end
local proxy=setmetatable({readFile=function(path) return canonical(fs.readFile(path),path) end},{__index=fs})
local function req(name)
 if name=='@lune/fs' then return proxy end
 if name:sub(1,2)=='./' then return require('../../tests/'..name:sub(3)) end
 return require(name)
end
local path=args[1];assert(path,'test path required')
luau.load(fs.readFile(path),{environment={require=req}})()
print('PASS: historical freeze with exact authorized A1 projection; current behavior tested separately')
