local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local fixture=require('./hub_park_rookie_loop_validation')
local root,L=fixture.root,fixture.layout
local geometry=luau.load(fs.readFile('src/shared/RookieLoopDriveGeometry.luau'),{environment={script={Parent={HubParkRookieLoopLayout='layout'}},require=function()return L end}})().create()
local n=0;local function check(v,m)assert(v,m);n+=1 end
check(L.height(0,0)==0 and L.height(0,-58)==0,'Lobby/T plaza lowest, unchanged')
check(L.height(0,-1150)==0 and L.height(600,-820)==0,'far and right roads stay flat')
local nx,ny,nz=L.normal(600,-550)
check(nx==0 and ny==1 and nz==0,'all driving normals are vertical')
local roadGeometry=fs.readFile('src/server/LobbyTestDriveService.luau')
check(roadGeometry:find('pos.Y<groundY-4 or pos.Y>groundY+18',1,true)~=nil,'height-aware recovery retains existing vertical margins')
local source=fs.readFile('src/server/LobbyPracticeCombat.luau')
local drop=assert(source:match('(function Combat:dropFrame.-)\nfunction Combat:use'))
-- Lune's non-horizontal lookAt returns the opposite pitch sign; native Studio
-- was checked separately. Bridge this API with Roblox's documented basis math.
local cframe=table.clone(rb.CFrame)
function cframe.lookAt(position,target,up)
 local forward=(target-position).Unit;local right=forward:Cross(up or rb.Vector3.yAxis).Unit
 return rb.CFrame.fromMatrix(position,right,right:Cross(forward).Unit,-forward)
end
local method=luau.load('local Combat={}\n'..drop..'\nreturn Combat.dropFrame',{environment={Vector3=rb.Vector3,CFrame=cframe,Config={SLICK_WIDTH=16,SLICK_LENGTH=5}}})()
local self={driveGeometry=geometry,zone={GetAttribute=function()return rb.Vector3.zero end}}
local frame=method(self,{Position=rb.Vector3.new(600,L.height(600,-550)+.5,-550),CFrame=rb.CFrame.lookAt(rb.Vector3.zero,-rb.Vector3.zAxis)},10,16,5)
check(frame~=nil and math.abs(frame.Position.Y-(L.height(frame.Position.X,frame.Position.Z)+.12))<.001,'real item drop clears the flat .02-stud asphalt skin')
local legacy=method({driveGeometry={inside=function()return true end},zone=self.zone},{Position=rb.Vector3.new(0,.5,0),CFrame=rb.CFrame.identity},10,16,5)
check(math.abs(legacy.Position.Y-.25)<.001,'legacy item drop height unchanged')
check(frame.UpVector.Y>.999999 and math.abs(frame.UpVector.Z)<.000001,'real item drop aligned to flat normal: '..tostring(frame.UpVector))
local total,waterTiles=0,0
for _,v in root.IslandScenery:GetChildren()do
 if v:IsA('BasePart')then total+=1;check(v.Anchored and not v.CanTouch,'static scenery, no touch listeners')end
 if v.Name=='IslandGrass'then
  check(not v.CanCollide and not v.CanQuery,'grass is visual only')
  local top=v.CFrame.Position+v.CFrame.UpVector*v.Size.Y/2
  check(math.abs(top.Y-(L.height(top.X,top.Z)-.2))<.001,'grass skin .2 below shoulder prevents coplanar flicker')
 elseif v.Name=='IslandWater'then
  waterTiles+=1
  check(v.Size.X<=2048 and v.Size.Z<=2048,'ocean tiles below native Part size limit')
  check(not v.CanCollide and not v.CanQuery and v.CFrame.Position.Y< -50,'water below cliffs, never a driving collider')
 elseif v.Name=='IslandEdgeGuard'then
  check(geometry.contact(v.CFrame.Position.X,v.CFrame.Position.Z)<-30,'outer guard cannot intrude into driving corridor')
 end
end
check(waterTiles==49,'14,000-stud ocean uses 49 explicit native-safe tiles')
check(total<400,'bounded native island scenery budget')
-- Flat terrain cannot occlude a standing observer's road view.
for _,far in L.sample(L.Segments)do if far.z<-1000 then
 local targetY=L.height(far.x,far.z)+2
 for i=1,20 do local t=i/20
  check(5+(targetY-5)*t>=L.height(far.x*t,far.z*t)+.5,'terrain does not occlude far-road kart from Lobby')
 end
end end
print(string.format('PASS %d flat island/item-grounding/visibility checks; %d scenery parts; grade 0',n,total))
