-- Pure, deterministic planning for the original city-template exterior palette.
local Layout={TrackId='Track01Metro',GeometryId='PracticeCircuitV1',
 MaxBuildings=68,ShoulderClearance=24,
 Names={'Kit_A','Kit_B','Kit_C','Kit_D','Kit_E','Kit_F','Kit_G','Kit_H','Kit_H_2','Kit_I','Kit_J','Shop_14_bldg','Shop_28_bldg'},
 Bridges={{point=Vector3.new(-350,0,100),forward=Vector3.new(0,0,-1),name='Skybridge1'},
          {point=Vector3.new(-690,0,-100),forward=Vector3.new(0,0,1),name='Skybridge2'}},
 Boulevards={{Vector3.new(-350,0,370),Vector3.new(-350,0,-240)},
 {Vector3.new(10,0,-240),Vector3.new(10,0,140)},
 {Vector3.new(210,0,140),Vector3.new(210,0,-500)},
 {Vector3.new(10,0,-700),Vector3.new(-490,0,-700)},
 {Vector3.new(-690,0,-500),Vector3.new(-690,0,390)}}}
function Layout.eligible(role,trackId,geometryId)
 return role=='RACE' and trackId==Layout.TrackId and geometryId==Layout.GeometryId
end
function Layout.roadDistance(samples,x,z)
 local best=math.huge
 for i,a in samples do
  local b=samples[i%#samples+1];local dx,dz=b.X-a.X,b.Z-a.Z
  local t=math.clamp(((x-a.X)*dx+(z-a.Z)*dz)/math.max(.001,dx*dx+dz*dz),0,1)
  best=math.min(best,math.sqrt((x-a.X-dx*t)^2+(z-a.Z-dz*t)^2))
 end
 return best
end
-- Exact planar segment-to-rectangle distance, including edge crossings.
function Layout.footprintDistance(samples,frame,size)
 local best=math.huge;local hx,hz=size.X/2,size.Z/2
 local function endpoint(x,z)return math.sqrt(math.max(0,math.abs(x)-hx)^2+math.max(0,math.abs(z)-hz)^2)end
 for i,point in samples do
  local a=frame:PointToObjectSpace(point);local b=frame:PointToObjectSpace(samples[i%#samples+1])
  local dx,dz=b.X-a.X,b.Z-a.Z;local lo,hi=0,1;local intersects=true
  for _,axis in {{a.X,dx,hx},{a.Z,dz,hz}}do
   if math.abs(axis[2])<1e-8 then
    if math.abs(axis[1])>axis[3]then intersects=false end
   else
    local t,u=(-axis[3]-axis[1])/axis[2],(axis[3]-axis[1])/axis[2]
    lo=math.max(lo,math.min(t,u));hi=math.min(hi,math.max(t,u))
   end
  end
  if intersects and lo<=hi then return 0 end
  best=math.min(best,endpoint(a.X,a.Z),endpoint(b.X,b.Z))
  for _,x in {-hx,hx}do for _,z in {-hz,hz}do
   local t=math.clamp(((x-a.X)*dx+(z-a.Z)*dz)/math.max(1e-8,dx*dx+dz*dz),0,1)
   best=math.min(best,math.sqrt((x-a.X-dx*t)^2+(z-a.Z-dz*t)^2))
  end end
 end
 return best
end

local function separated(a,b,gap)
 local delta=b.frame.Position-a.frame.Position
 for _,axis in {a.frame.RightVector,a.frame.LookVector,b.frame.RightVector,b.frame.LookVector}do
  local ar=(math.abs(axis:Dot(a.frame.RightVector))*a.size.X+math.abs(axis:Dot(a.frame.LookVector))*a.size.Z)/2
  local br=(math.abs(axis:Dot(b.frame.RightVector))*b.size.X+math.abs(axis:Dot(b.frame.LookVector))*b.size.Z)/2
  if math.abs(delta:Dot(axis))>=ar+br+gap then return true end
 end
 return false
end
Layout.separated=separated
function Layout.plan(geometry,course,width,profiles)
 local sites={};local minimum=width/2+Layout.ShoulderClearance
 local function place(name,point,forward,side,scale,block,bridge)
  local size=profiles[name]*scale;local right=Vector3.new(-forward.Z,0,forward.X)
  local center=point+right*(side*(minimum+4+size.Z/2))
  local frame=CFrame.lookAt(center,center-right*side)
  local site={name=name,frame=frame,size=size,scale=scale,block=block,side=side,forward=forward,bridge=bridge}
  site.clearance=Layout.footprintDistance(course.Samples,frame,size)
  if site.clearance<minimum then return end
  for _,prior in sites do if not separated(site,prior,.15)then return end end
  if #sites>=Layout.MaxBuildings then return end
  table.insert(sites,site)
 end
 -- Reserve paired native high-rises before filling the continuous street blocks.
 for i,b in Layout.Bridges do for _,side in {-1,1}do place('Kit_I',b.point,b.forward,side,1,'Bridge'..i,i)end end
 local regular={'Kit_A','Kit_B','Kit_C','Kit_D','Kit_E','Kit_F','Kit_G','Kit_H','Kit_H_2','Kit_J'}
 for avenue,ends in Layout.Boulevards do
  local forward=(ends[2]-ends[1]).Unit;local length=(ends[2]-ends[1]).Magnitude
  for _,side in {-1,1}do for block=1,2 do
   local specs={};local span=0
   for j=1,3 do
    local name=if j==3 then (if (avenue+block)%2==0 then 'Shop_14_bldg'else 'Shop_28_bldg')else regular[(avenue*3+block*2+j+(if side==1 then 2 else 0))%#regular+1]
    local scale=1+((avenue+block+j)%3)*.04
    table.insert(specs,{name=name,scale=scale,width=profiles[name].X*scale});span+=profiles[name].X*scale+.6
   end
   local cursor=length*(if block==1 then .25 else .75)-span/2
   for _,spec in specs do
    local d=cursor+spec.width/2
    if d>20 and d<length-20 then place(spec.name,ends[1]+forward*d,forward,side,spec.scale,avenue..':'..side..':'..block,nil)end
    cursor+=spec.width+.6
   end
  end end
 end
 for _,site in sites do
  local left,right=false,false
  for _,other in sites do if other~=site and other.block==site.block then
   local delta=(other.frame.Position-site.frame.Position):Dot(site.forward)
   local gap=math.abs(delta)-(site.size.X+other.size.X)/2
   if gap<1 and gap>0 and other.size.Y>=site.size.Y-8 then
    if delta<0 then left=true else right=true end
   end
  end end
  site.exposedSide=not left or not right
  site.exposedRear=false
  for _,point in course.Samples do
   local localPoint=site.frame:PointToObjectSpace(point)
   if localPoint.Z>site.size.Z/2 and (point-site.frame.Position).Magnitude<320 then site.exposedRear=true;break end
  end
 end
 return sites
end
function Layout.forestPlan(geometry,course,width,sites,treeSize)
 local groups={};local radius=math.sqrt(treeSize.X^2+treeSize.Z^2)/2
 for station=0,39 do
  local point=geometry.getSampleAtFraction(course.Samples,(station+.5)/40)
  local forward=geometry.getTangentAtFraction(course.Samples,(station+.5)/40)
  local right=Vector3.new(-forward.Z,0,forward.X)
  for _,side in {-1,1}do
   local group={}
   for j,offset in {{0,0},{-18,25},{18,25},{-30,48},{30,48}}do
    local scale=1.2+((station+j)%4)*.08
    local center=point+right*(side*(width/2+28+radius*scale+offset[2]))+forward*offset[1]
    local site={frame=CFrame.new(center),size=Vector3.new(radius*2*scale,1,radius*2*scale)}
    local clear=Layout.roadDistance(course.Samples,center.X,center.Z)>=width/2+24+radius*scale
    for _,b in sites do if not separated(site,b,9)then clear=false;break end end
    if clear then table.insert(group,{position=center,scale=scale,yaw=station*1.71+j,station=station})end
   end
   if #group>=3 then table.insert(groups,group)end
  end
 end
 local trees={};local pick=math.min(20,#groups)
 for i=1,pick do
  local index=math.floor((i-.5)*#groups/pick)+1
  for _,site in groups[index]do
   local clear=true
   for _,prior in trees do if (prior.position-site.position).Magnitude<radius*1.8 then clear=false;break end end
   if clear then table.insert(trees,site)end
  end
 end
 return trees
end
return table.freeze(Layout)
