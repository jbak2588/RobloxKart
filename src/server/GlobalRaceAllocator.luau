-- A fenced, short-lived universe-wide allocation lease. Never yield or perform
-- external work inside UpdateAsync: Roblox may retry the transform.
local Allocator={};Allocator.__index=Allocator
Allocator.MAP_NAME="KDM_GlobalRaceAllocation_v1"
Allocator.LEASE_SECONDS=30
function Allocator.new(map,now)
 return setmetatable({map=map,now=now or os.time},Allocator)
end
function Allocator:acquire(token)
 local now=self.now()
 local value=self.map:UpdateAsync("allocation",function(old)
  if old and old.owner and old.expiresAt>now and old.owner~=token then return nil end
  return {owner=token,expiresAt=now+self.LEASE_SECONDS,roomId=old and old.roomId}
 end,120)
 return value and value.owner==token and value or nil
end
function Allocator:finish(token,roomId)
 local now=self.now()
 return self.map:UpdateAsync("allocation",function(old)
  if not old or old.owner~=token or old.expiresAt<=now then return nil end
  return {roomId=roomId or old.roomId,expiresAt=0}
 end,120)
end
return Allocator
