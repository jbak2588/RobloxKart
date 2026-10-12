local Policy={}
function Policy.allowed(config,ctx,userId,kind)
 if config.Enabled~=true or ctx.isStudio~=false or ctx.experienceId~=config.ExperienceId
  or ctx.placeId~=config.PlaceId or type(userId)~='number' or userId<=0 or userId%1~=0 then return false end
 local hub=ctx.role=='HUB' and ctx.privateServerId==''
 local race=ctx.role=='RACE' and ctx.privateServerId~='' and ctx.privateServerOwnerId==0
 if not hub and not race then return false end
 local storage=config.StoragePublicEnabled==true or config.AllowedUserIds[userId]==true
 if kind=='reward' then return race and storage and (config.RewardsPublicEnabled==true or config.AllowedUserIds[userId]==true) end
 return storage and (kind=='read' or hub)
end
return table.freeze(Policy)
