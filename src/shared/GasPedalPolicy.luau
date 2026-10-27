-- Owner-approved held accelerator; explicit flag and exact release targets only.
local Policy={Speed=90}
function Policy.enabled(universeId,placeId,flag)
 return flag==true and ((universeId==10772198697 and placeId==106553302629620)
  or (universeId==10768420544 and placeId==127925465904803))
end
function Policy.cap(base,held,enabled,valid,onRoad,throttle,boost,nitro,blocked)
 local active=enabled==true and held==true and valid==true and onRoad==true
  and type(throttle)=='number' and throttle>0 and not boost and not nitro and not blocked
 return if active then math.max(base,Policy.Speed) else base,active
end
return Policy
