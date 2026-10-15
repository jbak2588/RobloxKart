local Policy={}
function Policy.allowed(config,ctx,userId,kind)
 if config.Enabled~=true or ctx.isStudio~=false or ctx.experienceId~=config.ExperienceId
  or ctx.placeId~=config.PlaceId or type(userId)~='number' or userId<=0 or userId%1~=0 then return false end
 local hub=ctx.role=='HUB' and ctx.privateServerId==''
 local race=ctx.role=='RACE' and type(ctx.privateServerId)=='string' and ctx.privateServerId~='' and ctx.privateServerOwnerId==0
 if not hub and not race then return false end
 local storage=config.StoragePublicEnabled==true or config.AllowedUserIds[userId]==true
 if kind=='shop' or kind=='voucher' then
  return storage and (config.ShopTransactionsPublicEnabled==true or config.AllowedUserIds[userId]==true)
   and (if kind=='voucher' then race else hub)
 end
 if kind=='reward' then return race and storage and (config.RewardsPublicEnabled==true or config.AllowedUserIds[userId]==true) end
 if kind=='read' or kind=='initialize' then return storage end
 -- Legacy owned-Wing equip / verified pass reconciliation are Hub-only.
 -- Cash purchases and voucher consumption still require their separate gates.
 if kind=='purchase' then return storage and hub end
 return false
end
return table.freeze(Policy)
