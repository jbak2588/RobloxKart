local fs,luau=require('@lune/fs'),require('@lune/luau')
local n=0
local function scan(path)
 for _,entry in fs.readDir(path) do
  local file=path..'/'..entry
  if fs.isDir(file) then scan(file)
  elseif file:sub(-5)=='.luau' then luau.load(fs.readFile(file));n+=1 end
 end
end
scan('src')
print('PASS: '..n..' production Luau sources compile')
