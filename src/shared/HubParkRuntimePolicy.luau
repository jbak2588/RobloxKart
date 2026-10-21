-- User-approved staging pair; flag OFF remains the default everywhere.
local Policy={ApprovedStaging=table.freeze({[10772198697]=106553302629620})}
function Policy.enabled(workspace,isStudio,gameId,placeId)
 if workspace:GetAttribute('KDMServerRole')~='HUB' or workspace:GetAttribute('HubParkV1Enabled')~=true
  or workspace:GetAttribute('KDMEnableRaceBot')==true then return false end
 if isStudio==true then return true end
 -- Production KDM can never become staging by setting an attribute.
 if gameId==10768420544 or placeId==127925465904803 then return false end
 return type(gameId)=='number' and type(placeId)=='number' and gameId>0 and placeId>0
  and Policy.ApprovedStaging[gameId]==placeId
end
return Policy
