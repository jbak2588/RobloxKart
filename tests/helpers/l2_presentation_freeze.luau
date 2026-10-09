-- Reverse exact approved L2 hunks only; any altered hunk stays detectable.
local fs,serde=require('@lune/fs'),require('@lune/serde')
local fixture=serde.decode('json',fs.readFile('tests/fixtures/l2_presentation_changes.json'))
return function(source,path)
 source=source:gsub('\r\n','\n')
 local function reverse(changes)
  for _,change in changes do
   local at=source:find(change.after,1,true)
   if at then source=source:sub(1,at-1)..change.before..source:sub(at+#change.after) end
  end
 end
 if path then if fixture.files[path] then reverse(fixture.files[path]) end
 else for _,changes in fixture.files do reverse(changes) end end
 return source
end
