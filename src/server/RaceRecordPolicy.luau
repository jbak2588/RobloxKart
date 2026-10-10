local Policy={}
function Policy.allowed(config,context,userId,kind)
 if config.Enabled~=true or context.isStudio~=false or context.experienceId~=config.ExperienceId
  or context.placeId~=config.PlaceId or config.AllowedUserIds[userId]~=true then return false end
 if context.role=="HUB" then return (kind=="read" or kind=="repair") and context.privateServerId=="" end
 return context.role=="RACE" and type(context.privateServerId)=="string"
  and context.privateServerId~="" and context.privateServerOwnerId==0
end
function Policy.indexScope(config,entry)
 local token=config.GeometryTokens[entry.geometryId]
 local geometries={Track01={PracticeFigure8V1=true},Track01Race={PracticeCircuitV1=true},
  Track02={PrototypeCircuitV2=true,PrototypeCircuitV2B=true},Track03={HardCircuitV1=true}}
 if not token or entry.rulesetId~=config.RulesetId
  or not geometries[entry.trackId] or not geometries[entry.trackId][entry.geometryId]
  or not ({SOLO_1H_0B=true,HUMAN_2H_0B=true,HUMAN_3H_0B=true,HUMAN_4H_0B=true})[entry.category] then return nil end
 return entry.trackId.."_"..token.."_R1_"..entry.category
end
return table.freeze(Policy)
