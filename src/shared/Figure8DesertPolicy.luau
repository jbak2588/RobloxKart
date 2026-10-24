-- Owner-authorized mobile test destination only; no production rollout.
local Policy={UniverseId=10772198697,PlaceId=106553302629620}
function Policy.enabled(workspace,isStudio,universeId,placeId)
 if universeId==Policy.UniverseId and placeId==Policy.PlaceId then return true end
 return isStudio==true and workspace:GetAttribute('KDMDesertPreviewEnabled')==true
end
return table.freeze(Policy)
