-- Production orbit-safe hero fit: visible-corner containment, hidden-pivot rejection,
-- and mobile-first slot/action geometry. No accounts, network or live purchases.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0
local function check(v,label)assert(v,label);n+=1 end
local source=fs.readFile('src/client/GarageShopController.luau')
local framing=luau.load(fs.readFile('src/shared/KartPreviewFraming.luau'),{environment={Vector3=rb.Vector3,CFrame=rb.CFrame}})()
local model=rb.Instance.new('Model')
for _,d in {{rb.Vector3.new(6.2,2.2,9.3),rb.CFrame.new(0,.8,-.3)},
 {rb.Vector3.new(3.3,.8,1.2),rb.CFrame.new(0,2.4,4)*rb.CFrame.Angles(0,.1,0)},
 {rb.Vector3.new(1.2,1.5,1.5),rb.CFrame.new(2.8,.34,2.7)}}do
 local p=rb.Instance.new('Part');p.Size=d[1];p.CFrame=d[2];p.Transparency=0;p.Parent=model
end
local viewport={AbsoluteSize=rb.Vector2.new(384,121)};local camera={FieldOfView=36}
local function fitter() camera.CFrame=framing.fit(model,viewport.AbsoluteSize.X/viewport.AbsoluteSize.Y,camera.FieldOfView,true) end
for _,size in {{384,121},{410,164},{348,95},{600,300},{192,80}}do
 viewport.AbsoluteSize=rb.Vector2.new(size[1],size[2]);fitter()
 local tangent=math.tan(math.rad(camera.FieldOfView)*.5);local aspect=size[1]/size[2]
 for _,p in model:GetChildren()do for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
  local q=camera.CFrame:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size*rb.Vector3.new(x,y,z)*.5))
  check(q.Z<0,'all hero corners in front of camera')
  check(math.abs(q.X/(-q.Z*tangent*aspect))<=.80001,'full width including wing remains in frame')
  check(math.abs(q.Y/(-q.Z*tangent))<=.94001,'full height including wing remains in frame')
 end end end end
 local before=camera.CFrame
 local hidden=rb.Instance.new('Part');hidden.Size=rb.Vector3.new(1000,1000,1000);hidden.Transparency=1;hidden.Parent=model
 fitter();check(camera.CFrame==before,'hidden structural pivot cannot shrink hero');hidden:Destroy()
end
local layout=luau.load(fs.readFile('src/client/ShopLayout.luau'))()
for _,size in {{706,281},{750,324},{648,223},{1142,628},{1280,662},{1920,1022}}do
 local l=layout.itemsForSize({X=size[1],Y=size[2]})
 check(l.height>=44,'slot remains a full touch target')
 check(math.ceil(6/l.columns)*(l.height+l.gap)-l.gap<=l.gridHeight,'six choices without scroll')
 check(l.detailHeight>=44 and l.detailX+l.detailWidth<=size[1],'fixed action inside safe width')
 local icon=if l.height<100 then math.max(28,l.height-8)else math.min(104,l.height-58)
 check(icon>=36 and icon<=l.height-8,'large art stays inside slot')
end
print('PASS R2 visual geometry: '..n..' checks; design acceptance still requires Studio captures/user review')
