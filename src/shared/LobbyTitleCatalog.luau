local Catalog = {}
Catalog.MAX_CODEPOINTS = 32
Catalog.MAX_RAW_BYTES = 1024
Catalog.Presets = table.freeze({
 LETS_RACE = "Let's Race!",
 BEGINNERS_WELCOME = "Beginners Welcome",
 DRIFT_PRACTICE = "Drift Practice",
})
Catalog.Order = table.freeze({"LETS_RACE", "BEGINNERS_WELCOME", "DRIFT_PRACTICE"})

function Catalog.defaultTitle(displayName)
 return (if type(displayName)=="string" and displayName~="" then displayName else "Racer").."'s Lobby"
end

-- Pure input normalization. Filtering belongs exclusively to the server.
function Catalog.normalize(value)
 if type(value)~="string" or #value>Catalog.MAX_RAW_BYTES then return nil end
 local ok,result=pcall(function()
  local pieces={}
  for _,code in utf8.codes(value) do
   local whitespace=code<=32 or code==127 or code==0x85 or code==0xA0 or code==0x1680
    or (code>=0x2000 and code<=0x200A) or code==0x2028 or code==0x2029 or code==0x202F or code==0x205F or code==0x3000
   table.insert(pieces,if whitespace then " " else utf8.char(code))
  end
  return table.concat(pieces):gsub(" +"," "):gsub("^ +",""):gsub(" +$","")
 end)
 return if ok then result else nil
end

function Catalog.publicTitle(record)
 local kind=record.lobbyTitleKind
 if (kind=="PRESET" or kind=="CUSTOM") and type(record.lobbyTitle)=="string" and record.lobbyTitle~="" then
  return record.lobbyTitle,kind
 end
 return Catalog.defaultTitle(record.hostName),"DEFAULT"
end

return table.freeze(Catalog)
