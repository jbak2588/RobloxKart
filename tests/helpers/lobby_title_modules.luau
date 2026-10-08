local fs,luau=require("@lune/fs"),require("@lune/luau")
local catalog=luau.load(fs.readFile("src/shared/LobbyTitleCatalog.luau"))()
local tracks=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment={CFrame=require("@lune/roblox").CFrame}})()
local function node(name)return {Name=name,WaitForChild=function(_,child)return node(child)end}end
local env={game={GetService=function(name)return node(name)end},require=function(module)
 if module.Name=="TrackCatalog" then return tracks end
 assert(module.Name=="LobbyTitleCatalog",module.Name)
 return catalog
end,Enum={TextFilterContext={PublicChat="PublicChat"}}}
local service=luau.load(fs.readFile("src/server/LobbyTitleService.luau"),{environment=env})()
return {catalog=catalog,service=service,environment=function(enum)return {game=env.game,require=env.require,Enum=enum} end}
