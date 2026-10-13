local fs,luau=require('@lune/fs'),require('@lune/luau')
local config=require('./gameplay_config')('src/shared/KartConfig.luau')
local slide=luau.load(fs.readFile('src/server/ArcadeDrift.luau'))()
return luau.load(fs.readFile('src/server/LobbyDriftSession.luau'),{environment={
 game={GetService=function()return {Shared={KartConfig='config'}}end},script={Parent={ArcadeDrift='slide'}},require=function(k)return if k=='config' then config else slide end}})()
