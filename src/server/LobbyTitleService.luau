local Catalog=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LobbyTitleCatalog"))
local Service={}
Service.ERROR="LOBBY NAME COULDN'T BE USED - TRY ANOTHER"

function Service.resolve(player,mode,value,textService)
 if mode==nil then mode="DEFAULT" end
 if mode=="DEFAULT" then
  return "DEFAULT",Catalog.defaultTitle(if player.DisplayName and player.DisplayName~="" then player.DisplayName else player.Name)
 elseif mode=="PRESET" then
  local title=if type(value)=="string" then Catalog.Presets[value] else nil
  if title then return "PRESET",title end
  return nil
 elseif mode~="CUSTOM" then return nil end
 local normalized=Catalog.normalize(value)
 if not normalized then return nil end
 if normalized=="" then return Service.resolve(player,"DEFAULT") end
 if (utf8.len(normalized) or math.huge)>Catalog.MAX_CODEPOINTS then return nil end
 local ok,filtered=pcall(function()
  return textService:FilterStringAsync(normalized,player.UserId,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
 end)
 if not ok or type(filtered)~="string" then return nil end
 filtered=Catalog.normalize(filtered)
 if not filtered or filtered=="" or filtered:gsub("[#%s]","")=="" or (utf8.len(filtered) or math.huge)>Catalog.MAX_CODEPOINTS then return nil end
 return "CUSTOM",filtered
end

return Service
