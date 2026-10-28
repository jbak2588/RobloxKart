local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local view=luau.load(fs.readFile('src/client/MobileControlView.luau'),{environment={Color3=rb.Color3,Vector2=rb.Vector2}})()
local layout=luau.load(fs.readFile('src/client/LobbyDriveLayout.luau'))()
local n=0
local function check(v,label) assert(v,label);n+=1 end
for _,size in {rb.Vector2.new(801,334),rb.Vector2.new(844,300),rb.Vector2.new(932,390),rb.Vector2.new(667,250),rb.Vector2.new(480,210),rb.Vector2.new(390,780)} do
 view.setViewportBottomInset(size.Y+34,size.Y)
 local l=layout.apply(view.layout(size),size)
 local shortcut=layout.shortcuts(size,view)
 local left=size.X-l.margin-l.padWidth-l.padInset
 local padTop=size.Y-l.padBottom-l.padHeight
 check(l.padBottom>=0 and padTop>=0,'entire driving pad within safe bounds')
 check(left>=0 and left+l.padWidth<=size.X,'pad horizontal bounds')
 check(shortcut.y+shortcut.height<=size.Y-l.steerBottom-l.steerHeight-4,'shortcuts above left steering')
 check(shortcut.x>=0 and shortcut.x+shortcut.width<=size.X,'shortcut horizontal bounds')
 local driftTop=size.Y-l.driftBottom-l.driftHitHeight
 check(driftTop-8-44>=0 and l.driftBottom>=0,'Exit and Drift fit safe height')
 check(l.driftX>=0 and l.driftX+l.driftHitWidth<=size.X,'complete Drift hitbox inside safe width')
 local hud=layout.trainingHud(size,16,58,l.driftX,l.driftHitWidth,l.driftWidth)
 check(hud.y>=58+12 and hud.x==16,'Boost label and bar below wallet')
 check(hud.x+hud.width<=size.X-12,'Boost bar safe width')
 check(math.abs(hud.exitX-l.driftX-(l.driftHitWidth-l.driftWidth)/2)<.01,'Exit aligned with visible Drift artwork')
 if l.driftX+l.driftHitWidth>left then check(size.Y-l.driftBottom<=padTop,'portrait Drift above actual right pad') end
 check(size.Y-l.driftBottom<=shortcut.y or driftTop>=shortcut.y+shortcut.height,'Drift and shortcut rectangles never overlap vertically')
 -- A Lobby layout must not mutate the shared race layout or inset behavior.
 check(view.layout(size).padBottom~=12,'race layout remains unchanged')
end
local server=fs.readFile('src/server/LobbyTestDriveService.luau')
check(server:find('r.drift=drift==true',1,true)~=nil,'server accepts only boolean Drift activation')
check(server:find('LobbyDrifting',1,true)~=nil,'Drift runtime state available')
local builder=fs.readFile('src/server/LobbyFrontDriveZoneBuilder.luau')
check(not builder:find('LobbyFrontDriveSign',1,true) and not builder:find('LobbyFrontForwardCue',1,true),'sign and lane cues removed')
check(builder:find('LobbyFrontFreeDriveRoad',1,true)~=nil,'full infield paved')
-- Geometric slab coverage: every point at least 2 studs inside the wall has pavement.
local policy=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
for z=-80,80,2 do
 local edge=math.max(math.abs(z),math.abs(z+2))
 local cap=math.sqrt(math.max(0,policy.OuterRadius^2-edge^2))
 for x=-200,200,4 do if policy.inside(x,z+1,2) then check(math.abs(x)<=policy.HalfStraight+cap,'continuous paved safe interior') end end
end
print('PASS: '..n..' Lobby mobile safe hitbox / paved interior checks')
