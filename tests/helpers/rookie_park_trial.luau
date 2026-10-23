local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
return function(layout)
 local progress=luau.load(fs.readFile('src/shared/RaceRouteProgress.luau'),{environment={Vector3=rb.Vector3}})()
 local config=luau.load(fs.readFile('src/shared/RaceConfig.luau'))()
 return luau.load(fs.readFile('src/shared/RookieParkTrial.luau'),{environment={Vector3=rb.Vector3,
  script={Parent={HubParkRookieLoopLayout='L',RaceRouteProgress='P',RaceConfig='C'}},
  require=function(k)return ({L=layout,P=progress,C=config})[k]end}})()
end
