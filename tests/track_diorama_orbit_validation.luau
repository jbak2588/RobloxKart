local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local orbit=luau.load(fs.readFile('src/client/TrackDioramaOrbit.luau'),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame}})()
local n=0;local function check(v,s) assert(v,s);n+=1 end
check(orbit.PITCH>=math.rad(25) and orbit.PITCH<=math.rad(40),'oblique initial perspective')
check(orbit.STEP>0 and -orbit.STEP<0,'left/right opposite yaw')
check(orbit.drag(0,20)<0 and orbit.drag(0,-20)>0,'horizontal swipe yaw')
local geometry=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame}})()
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment={CFrame=rb.CFrame}})()
local builder=luau.load(fs.readFile('src/client/TrackPreviewBuilder.luau'),{environment={game={GetService=function() return {WaitForChild=function(self) return self end} end},require=function() return geometry end,Instance=rb.Instance,Vector3=rb.Vector3,CFrame=rb.CFrame,Enum=rb.Enum,Color3=rb.Color3}})()
for _,id in catalog.Order do
 local d=builder.build(catalog.Entries[id])
 for _,aspect in {.46,.75,1,4/3,16/9,19.5/9,3.2} do
  local distance=orbit.fit(d,aspect);check(distance>0 and distance<10000,'bounded distance')
  for yaw=0,359,5 do
   local f=orbit.frame(d.center,math.rad(yaw),distance)
   check(f.LookVector:Dot((d.center-f.Position).Unit)>.999,'center aim')
   check(f.RightVector:Cross(f.UpVector):Dot(-f.LookVector)>.999,'no mirror')
   for _,x in {d.min.X,d.max.X} do for _,y in {d.min.Y,d.max.Y} do for _,z in {d.min.Z,d.max.Z} do
    local p=f:PointToObjectSpace(rb.Vector3.new(x,y,z))
    local tan=math.tan(math.rad(orbit.FOV)/2)
    check(-p.Z>0 and math.abs(p.X)<-p.Z*tan*aspect*.85 and math.abs(p.Y)<-p.Z*tan*.85,'all-yaw fit '..id)
   end end end
  end
 end
 d.world:Destroy()
end
local source=fs.readFile('src/client/TrackDioramaController.luau')
check(not source:find('Heartbeat') and source:find('if alpha==1 then stopTween()',1,true),'no continuous auto spin')
check(source:find('Orbit.THRESHOLD',1,true) and source:find('math.abs(y-startY)',1,true),'jitter / vertical drag gate')
print('PASS: '..n..' Track diorama orbit / fit checks')

