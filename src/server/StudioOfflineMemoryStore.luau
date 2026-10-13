-- Only used by unpublished local Studio files (PlaceId=0). No cloud API calls.
assert(game.PlaceId==0 and game:GetService('RunService'):IsStudio(),'offline Studio only')
local maps={}
local service={}
function service:GetSortedMap(name)
 if maps[name] then return maps[name] end
 local entries={};local map={}
 function map:GetAsync(key)
  local e=entries[key];if e and e.expires>os.clock() then return e.value end
  entries[key]=nil;return nil
 end
 function map:SetAsync(key,value,ttl,sortKey)entries[key]={value=value,sortKey=sortKey,expires=os.clock()+(ttl or 60)}end
 function map:RemoveAsync(key)entries[key]=nil end
 function map:UpdateAsync(key,f,ttl)
  local value,sortKey=f(self:GetAsync(key));if value~=nil then self:SetAsync(key,value,ttl,sortKey)end;return value
 end
 function map:GetRangeAsync(_direction,count)
  local rows={};for key,e in entries do if self:GetAsync(key) then table.insert(rows,{key=key,value=e.value,sortKey=e.sortKey})end end
  table.sort(rows,function(a,b)return tostring(a.key)<tostring(b.key)end)
  while #rows>(count or #rows) do table.remove(rows)end;return rows
 end
 maps[name]=map;return map
end
service.GetHashMap=service.GetSortedMap
return service
