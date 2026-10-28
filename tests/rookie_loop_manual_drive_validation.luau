local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local layout=luau.load(fs.readFile('src/shared/HubParkRookieLoopLayout.luau'))()
local geom=luau.load(fs.readFile('src/shared/RookieLoopDriveGeometry.luau'),{environment={script={Parent={HubParkRookieLoopLayout='layout'}},require=function()return layout end}})().create()
local n=0;local function check(v,l)assert(v,l);n+=1 end
for _,route in {layout.Segments,layout.Pit.segments}do
 local points=layout.sample(route)
 for i,a in points do
  check(geom.inside(a.x,a.z,7),'road/pit chassis footprint inside current course')
  if i>1 then local b=points[i-1];check(not geom.crossesBoundary(a.x,a.z,b.x,b.z),'all local joins continuous')end
 end
end
for _,s in layout.Slots do check(geom.inside(s.x,s.z,7),'manual spawn on pit, not grass')end
print('R3_TRACE origin',geom.inside(0,0),geom.contact(0,0))
check(geom.inside(0,0) and geom.contact(0,0)<0,'origin is island land but outside drivable road contact')
check(not geom.inside(2000,2000),'outside rejected')
check(geom.crossesBoundary(0,0,layout.Island.maxX+100,0),'jump through island rejected')
check(math.abs(layout.Plaza.z+58)<.01 and layout.Walkway.z+layout.Walkway.length/2>=-24,'short walkway reaches building entrance')
local policy=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
for _,s in layout.Slots do check(policy.fits(geom,s.x,s.z,1,0),'full rectangular kart fits start')end
print('PASS '..n..' RookieLoop manual drive corridor / pit / start / containment checks')
