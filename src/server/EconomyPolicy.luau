local Policy={}
function Policy.allowed(config,ctx,userId,kind)
 if config.Enabled~=true or type(userId)~='number' or userId<=0 or userId%1~=0 then return false end
 local inStudio = ctx.isStudio == true
 if not inStudio then
  if ctx.experienceId~=config.ExperienceId or ctx.placeId~=config.PlaceId then return false end
 end
 local hub = (ctx.role=='HUB' and ctx.privateServerId=='') or (inStudio and (ctx.role=='HUB' or ctx.role==nil))
 local race = (ctx.role=='RACE' and type(ctx.privateServerId)=='string' and ctx.privateServerId~='' and ctx.privateServerOwnerId==0)
  or (inStudio and ctx.role=='RACE')
 if not hub and not race then return false end
 local storage = inStudio or config.StoragePublicEnabled==true or (config.AllowedUserIds and config.AllowedUserIds[userId]==true)
 if kind=='shop' or kind=='voucher' then
  return storage and (inStudio or config.ShopTransactionsPublicEnabled==true or (config.AllowedUserIds and config.AllowedUserIds[userId]==true))
   and (if kind=='voucher' then race else hub)
 end
 if kind=='reward' then return race and storage and (inStudio or config.RewardsPublicEnabled==true or (config.AllowedUserIds and config.AllowedUserIds[userId]==true)) end
 if kind=='read' or kind=='initialize' then return storage end
 if kind=='purchase' then return storage and hub end
 return false
end
return table.freeze(Policy)
