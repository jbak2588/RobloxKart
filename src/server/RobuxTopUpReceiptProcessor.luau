-- Dependency-injected runtime, including unknown-ACK and cross-server replay tests.
local P={}
function P.new(d)
 return function(receipt)
  local key=d.ops.identity(d.S,d.catalog,receipt)
  if not key or not d.allowed() then return d.pending end
  local player=d.player(receipt.PlayerId)
  if not player then return d.pending end
  local ok,result=pcall(function()
   local a=d.adapter(player);local userKey=d.S.userKey(receipt.PlayerId)
   for _=1,3 do
    local read=a.read(userKey)
    if d.ops.confirm(d.S,d.schema,d.catalog,read,receipt) then
     d.publish(player,read.value);return d.granted
    end
    if read.status~='FOUND' and read.status~='ABSENT' then return d.pending end
    if read.status=='FOUND' and read.value.deleted then return d.pending end
    a.commit(a.beginUpdate(userKey,d.ops.reduce(d.S,d.schema,d.catalog,receipt)))
    read=a.read(userKey)
    if d.ops.confirm(d.S,d.schema,d.catalog,read,receipt) then
     d.publish(player,read.value);return d.granted
    end
    -- Unknown writes stay pending. A retry always derives from persisted state.
   end
   return d.pending
  end)
  return if ok then result else d.pending
 end
end
return table.freeze(P)
