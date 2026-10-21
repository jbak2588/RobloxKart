local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local gauge=luau.load(fs.readFile('src/client/V2DonorGauge.luau'),{environment={Vector2=rb.Vector2,Enum=rb.Enum}})()
local mobile=luau.load(fs.readFile('src/client/MobileControlView.luau'),{environment={Vector2=rb.Vector2,Color3=rb.Color3,Enum=rb.Enum,UDim2=rb.UDim2}})()
local lobby=luau.load(fs.readFile('src/client/LobbyDriveLayout.luau'))()
local presentation=luau.load(fs.readFile('src/client/V2GaugePresentation.luau'))()
local n=0;local function check(v,m)assert(v,m);n+=1 end
for _,s in {{844,390,true},{932,430,true},{1102,485,true},{1920,1080,false}}do
 local size=rb.Vector2.new(s[1],s[2]);local g=gauge.layout(s[1],s[2],s[3])
 check(g.visible and g.width>=190,'both dials readable in requested landscape viewport')
 check(g.x-g.width/2>=0 and g.x+g.width/2<=s[1] and g.y<=s[2],'inside viewport')
 if s[3] then
  local l=lobby.apply(mobile.layout(size),size)
  check(g.x-g.width/2>=l.driftX+l.driftHitWidth,'clear left drift hitbox')
  check(g.x+g.width/2<=size.X-l.margin-l.padWidth-l.padInset,'clear right driving controls')
 end
end
local p=presentation.new()
for _,speed in {0,30,70,100,120,70,0}do
 local state=p:update(speed,1/60,speed==100,speed==120)
 check(math.abs(state.speedKmh-speed*1.008)<.001,'same measured-speed display contract as official race')
 check(state.rpm==state.rpm and state.rpm>=700 and state.rpm<=7000,'finite analog presentation')
end
print('PASS '..n..' Lobby digital/analog speed presentation and PC/mobile thumb-lane checks')
