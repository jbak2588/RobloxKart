-- Owner-approved dual-theme release: desert has its own track identity.
local Policy={UniverseId=10772198697,PlaceId=106553302629620,TrackId="Track01Desert"}
function Policy.enabled(workspace,isStudio,universeId,placeId)
 if universeId==10768420544 and placeId==127925465904803 then return true end
 if universeId==Policy.UniverseId and placeId==Policy.PlaceId then return true end
 return isStudio==true and workspace:GetAttribute('KDMDesertPreviewEnabled')==true
end
return table.freeze(Policy)
