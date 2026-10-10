-- Pure policy: no client, Workspace attribute, or username controls authorization.
local Policy={}
function Policy.allowed(config,context,userId)
 return config.Enabled==true and context.isStudio==false and context.role=="HUB"
  and context.experienceId==config.ExperienceId and context.placeId==config.PlaceId
  and context.privateServerId=="" and type(userId)=="number" and userId>0 and userId%1==0
  and config.AllowedUserIds[userId]==true
end
return table.freeze(Policy)
