local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0;local function check(v,m)assert(v,m);n+=1 end
local allocated=0;local methods={}
local function object(class)
 allocated+=1
 return setmetatable({ClassName=class,children={},attrs={}}, {__index=methods,__newindex=function(self,k,v)
  if k=='Parent' and v then table.insert(v.children,self)end;rawset(self,k,v)
 end})
end
function methods:SetAttribute(k,v)self.attrs[k]=v end
function methods:GetAttribute(k)return self.attrs[k]end
function methods:Destroy()self.destroyed=true end
local env={Instance={new=object},Vector2=rb.Vector2,UDim2=rb.UDim2,Color3=rb.Color3}
local M=luau.load(fs.readFile('src/client/MinimapDriverMarker.luau'),{environment=env})()
local p=object('Frame');local marker=M.new(p,'Driver',4)
check(marker.AnchorPoint==rb.Vector2.new(.5,.5) and marker.Size==rb.UDim2.fromOffset(14,14),'centered bounded14px marker')
check(marker.Active==false and marker.BackgroundTransparency==1,'no input capture or opaque backing square')
check(#marker.children==20,'fixed20 UI rows built once')
local outlines,fills=0,0
for _,r in marker.children do
 check(not r.Active and r.Size.Y.Offset==1,'fixed noninteractive row')
 if r.Name=='Outline'then outlines+=1;check(r.BackgroundColor3==rb.Color3.fromRGB(240,250,255),'bright border')
 else fills+=1;check(r.BackgroundColor3==rb.Color3.fromRGB(65,225,245),'accepted cyan fill')end
end
check(outlines==12 and fills==8,'white-edged triangular silhouette')
for _,a in {{rb.Vector3.new(0,0,1),0},{rb.Vector3.new(1,0,0),90},{rb.Vector3.new(0,0,-1),180},{rb.Vector3.new(-1,0,0),-90}}do
 check(math.abs(M.rotation(a[1])-a[2])<1e-6,'world axes match map projection')
end
local before=allocated
for _,rotation in {0,90,-45,180}do for degrees=-180,180,3 do
 local a=math.rad(degrees);local direction=rb.Vector3.new(math.sin(a),.1,math.cos(a))
 M.update(marker,direction,rotation)
 local theta=math.rad(marker.Rotation)
 local projected=rb.Vector2.new(direction.X,-direction.Z)
 local r=math.rad(rotation);local expected=rb.Vector2.new(projected.X*math.cos(r)-projected.Y*math.sin(r),projected.X*math.sin(r)+projected.Y*math.cos(r)).Unit
 local arrow=rb.Vector2.new(math.sin(theta),-math.cos(theta))
 check(arrow:Dot(expected)>.999999,'triangle matches projected forward vector across headings and map rotations')
end end
check(allocated==before,'heading updates allocate no UI objects')
local old=marker.Rotation
for _,bad in {rb.Vector3.zero,rb.Vector3.yAxis,rb.Vector3.new(0/0,0,0),rb.Vector3.new(math.huge,0,0)}do
 M.update(marker,bad);check(marker.Rotation==old,'invalid/vertical heading preserves previous orientation')
end
M.update(marker,nil);check(marker.Rotation==old,'missing direction preserves last orientation')
local official=fs.readFile('src/client/RaceHudController.luau');local park=fs.readFile('src/client/LobbyTestDriveController.luau')
check(official:find('chassis.CFrame.LookVector',1,true) and park:find('parkMarker.update(parkDot,body.CFrame.LookVector)',1,true),'both ordinary driving callers use chassis forward, not velocity')
for _,path in {'src/client/TrackMapRenderer.luau','src/client/RaceHudController.luau','src/client/LobbyTestDriveController.luau','src/client/TouchDrivingController.luau'}do check(pcall(luau.load,fs.readFile(path)),'runtime compiles '..path)end
print('PASS '..n..' minimap cardinal/full-turn/rotated-map/stopped heading, fixed budget and UI isolation checks')
