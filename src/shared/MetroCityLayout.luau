-- Pure, deterministic planning for the original city-template exterior palette.
local Layout={TrackId='Track01Metro',GeometryId='PracticeCircuitV1',
 Stations=52,MaxBuildings=96,
 ShoulderClearance=24,Names={'6_BLDG','15_bldg','17_bldg','31_BLDG','33_BLDG','34_BLDG','41_BLDG','43_BLDG','45_BLDG'}}
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
function Layout.plan(geometry,course,width,profiles)
 local sites={};local minimum=width/2+Layout.ShoulderClearance
 for station=0,Layout.Stations-1 do
  local fraction=(station+.35)/Layout.Stations
  local point=geometry.getSampleAtFraction(course.Samples,fraction)
  local forward=geometry.getTangentAtFraction(course.Samples,fraction)
  local right=Vector3.new(-forward.Z,0,forward.X).Unit
  for column,side in {-1,1}do
   local name=Layout.Names[(station*5+column*3-1)%#Layout.Names+1]
   local profile=profiles[name]
   if not profile then continue end
   local scale=1.55+((station*7+column*3)%5)*.1
   local size=profile*scale
   local center=point+right*(side*(minimum+4+size.Z/2))
   local frame=CFrame.lookAt(Vector3.new(center.X,0,center.Z),Vector3.new(point.X,0,point.Z))
   local clear=true;local clearance=math.huge
   -- Check corners and edge midpoints against every course segment.
   for _,x in {-1,0,1}do for _,z in {-1,0,1}do
    local v=frame:PointToWorldSpace(Vector3.new(x*size.X/2,0,z*size.Z/2))
    local distance=Layout.roadDistance(course.Samples,v.X,v.Z)
    clearance=math.min(clearance,distance)
    if distance<minimum then clear=false end
   end end
   local radius=math.sqrt(size.X^2+size.Z^2)/2
   for _,prior in sites do
    if (frame.Position-prior.frame.Position).Magnitude<radius+prior.radius+5 then clear=false;break end
   end
   if clear then clearance=Layout.footprintDistance(course.Samples,frame,size);clear=clearance>=minimum end
   if clear and #sites<Layout.MaxBuildings then
    table.insert(sites,{name=name,frame=frame,size=size,scale=scale,radius=radius,clearance=clearance,station=station,side=side})
   end
  end
 end
 return sites
end
return table.freeze(Layout)
