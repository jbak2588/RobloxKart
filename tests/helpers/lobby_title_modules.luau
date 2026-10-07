local fs,luau=require("@lune/fs"),require("@lune/luau")
local catalog=luau.load(fs.readFile("src/shared/LobbyTitleCatalog.luau"))()
local node={WaitForChild=function(self)return self end}
local env={game={GetService=function()return node end},require=function()return catalog end,Enum={TextFilterContext={PublicChat="PublicChat"}}}
local service=luau.load(fs.readFile("src/server/LobbyTitleService.luau"),{environment=env})()
return {catalog=catalog,service=service,environment=function(enum)return {game=env.game,require=env.require,Enum=enum} end}
