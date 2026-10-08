-- Reverse only exact authorized N2 presentation hunks before historical UI freezes.
-- A modified hunk no longer matches and is rejected by the full source comparison.
local fs,serde=require('@lune/fs'),require('@lune/serde')
local fixture=serde.decode('json',fs.readFile('tests/fixtures/n2_hud_presentation_changes.json'))
return function(source)
 source=source:gsub('\r\n','\n')
 for _,change in fixture.changes do
  if change.after~='' then
   local start=source:find(change.after,1,true)
   if start then source=source:sub(1,start-1)..change.before..source:sub(start+#change.after)end
  end
 end
 return source
end
