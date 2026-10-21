-- Racing Park stage 1. Coordinates are relative to HubSpawn, world X/Z axes.
-- User-approved final cross section: transfer half of each shoulder to road.
-- Total corridor and all guardrail positions stay unchanged (25+2+9 = 36).
local Layout = { DefaultEnabled=false, RoadWidth=50, KerbWidth=2, Shoulder=9,
 SampleLength=4, MinimumRadius=50, PrototypeName="HubParkRookieLoopG2" }
local function p(x,z) return {x=x,z=z} end
local k=.5522847498307936
-- T plaza front edge is -70. A 1-stud gap to the 22-stud pit puts
-- slot centers 12 studs away: approximately two walking steps.
local pitZ=-82
local startZ=pitZ-55
Layout.PitLaneZ=pitZ;Layout.StartStraightZ=startZ;Layout.PitShift=63
-- User pen sketch: every main-road section lies in FRONT of the lobby.
-- Start east along the pit, go north on the outer right, descend the inner
-- right, take the central folded hairpin/S, then return down the outer left.
-- F60 building/entry stay fixed; the pit-side edge moves toward the T plaza.
local corners={
 {x=-500,z=startZ,r=100,name="PitApproach"},
 {x=600,z=startZ,r=130,name="EntryCurve"},
 {x=600,z=-820,r=130,name="OuterEast"},
 {x=180,z=-820,r=100,name="UpperRight"},
 {x=180,z=-600,r=60,name="RightInset"},
 {x=380,z=-600,r=60,name="InnerRight"},
 {x=380,z=-400,r=100,name="LowerBowlEast"},
 {x=-250,z=-400,r=80,name="LowerBowlWest"},
 {x=-250,z=-600,r=80,name="HairpinEntry"},
 {x=100,z=-600,r=60,name="HairpinApex"},
 {x=100,z=-760,r=60,name="HairpinExit"},
 {x=-120,z=-760,r=60,name="S1"},
 {x=-120,z=-920,r=60,name="S2"},
 {x=-340,z=-920,r=60,name="UpperLeftEntry"},
 {x=-340,z=-1150,r=100,name="UpperLeftApex"},
 {x=-700,z=-1150,r=100,name="OuterWest"},
 {x=-700,z=-550,r=100,name="ReturnChicaneEntry"},
 {x=-500,z=-550,r=80,name="ReturnChicaneExit"},
}
local function unit(a,b)
 local dx,dz=b.x-a.x,b.z-a.z;local l=math.sqrt(dx*dx+dz*dz)
 return dx/l,dz/l,l
end
local entries,exits={},{}
for i,c in corners do
 local prev,next=corners[(i-2)%#corners+1],corners[i%#corners+1]
 local ix,iz=unit(prev,c);local ox,oz=unit(c,next)
 entries[i]=p(c.x-ix*c.r,c.z-iz*c.r)
 exits[i]=p(c.x+ox*c.r,c.z+oz*c.r)
end
Layout.Segments={}
for i,c in corners do
 local j=i%#corners+1;local a,b=exits[i],entries[j]
 local dx,dz,l=unit(a,b);assert(l>0,"rounded corners consume straight")
 table.insert(Layout.Segments,{name=if i==1 then "StartStraight" else c.name.."Link",
  a,p(a.x+dx*l/3,a.z+dz*l/3),p(b.x-dx*l/3,b.z-dz*l/3),b})
 local next=corners[j];local finish=exits[j]
 local ox,oz=unit(next,corners[j%#corners+1])
 table.insert(Layout.Segments,{name=next.name,b,
  p(b.x+dx*next.r*k,b.z+dz*next.r*k),
  p(finish.x-ox*next.r*k,finish.z-oz*next.r*k),finish})
end
Layout.Stage="PARK_2_ISLAND"
-- One continuous uphill plane beyond the unchanged T plaza. All course and
-- pit surfaces share it; there are no ramps/joins between individual road slices.
Layout.Island={minX=-820,maxX=720,minZ=-1270,maxZ=220,chamfer=150,
 baseZ=-70,slope=.04,waterY=-58,waterSize=14000}
function Layout.height(_x,z)
 return math.max(0,(Layout.Island.baseZ-z)*Layout.Island.slope)
end
function Layout.normal(_x,z)
 local slope=if z<Layout.Island.baseZ then Layout.Island.slope else 0
 local length=math.sqrt(1+slope*slope)
 return 0,1/length,slope/length
end
Layout.MainStraightLength=870
Layout.NitroStraightLength=360+Layout.PitShift -- Extend outside straight with pit approach.
Layout.Pit={width=22,segments={
 {name="PitEntry",p(-180,startZ),p(-145,startZ),p(-130,pitZ),p(-95,pitZ)},
 {name="PitLane",p(-95,pitZ),p(-30,pitZ),p(35,pitZ),p(100,pitZ)},
 {name="PitExit",p(100,pitZ),p(135,pitZ),p(145,startZ),p(180,startZ)},
}}
Layout.Protected={minX=-90,maxX=90,minZ=-85,maxZ=95}
Layout.Plaza={x=0,z=-58,width=120,length=24}
Layout.Walkway={x=0,z=-36,width=12,length=24}
-- The service fills the lowest free slot index first. Travel is +X, so
-- index 1 must be the leading bracket, then fill backward without moving paint.
Layout.Slots={p(45,pitZ),p(15,pitZ),p(-15,pitZ),p(-45,pitZ)}
function Layout.evaluate(s,t)
 local a,b,c,d=s[1],s[2],s[3],s[4];local u=1-t
 local x=u^3*a.x+3*u*u*t*b.x+3*u*t*t*c.x+t^3*d.x
 local z=u^3*a.z+3*u*u*t*b.z+3*u*t*t*c.z+t^3*d.z
 local dx=3*u*u*(b.x-a.x)+6*u*t*(c.x-b.x)+3*t*t*(d.x-c.x)
 local dz=3*u*u*(b.z-a.z)+6*u*t*(c.z-b.z)+3*t*t*(d.z-c.z)
 local ddx=6*u*(c.x-2*b.x+a.x)+6*t*(d.x-2*c.x+b.x)
 local ddz=6*u*(c.z-2*b.z+a.z)+6*t*(d.z-2*c.z+b.z)
 local speed=math.sqrt(dx*dx+dz*dz);local cross=math.abs(dx*ddz-dz*ddx)
 return {x=x,z=z,fx=dx/speed,fz=dz/speed,
  radius=if cross<1e-9 then math.huge else speed^3/cross,section=s.name,t=t}
end
function Layout.sample(segments)
 local out={}
 for _,s in segments do
  local length=0
  for i=1,3 do length+=math.sqrt((s[i+1].x-s[i].x)^2+(s[i+1].z-s[i].z)^2) end
  local steps=math.ceil(length/Layout.SampleLength)
  for i=0,steps-1 do table.insert(out,Layout.evaluate(s,i/steps)) end
 end
 table.insert(out,Layout.evaluate(segments[#segments],1))
 return out
end
function Layout.pitOpening(a)
 return a.section=="StartStraight" and ((a.x>=-190 and a.x<=-80) or (a.x>=90 and a.x<=190))
end
function Layout.measure()
 local points=Layout.sample(Layout.Segments)
 local length,minRadius=0,math.huge
 local bounds={minX=math.huge,maxX=-math.huge,minZ=math.huge,maxZ=-math.huge}
 for i,a in points do
  bounds.minX=math.min(bounds.minX,a.x);bounds.maxX=math.max(bounds.maxX,a.x)
  bounds.minZ=math.min(bounds.minZ,a.z);bounds.maxZ=math.max(bounds.maxZ,a.z)
  minRadius=math.min(minRadius,a.radius)
  if i>1 then local b=points[i-1];length+=math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
 end
 return {length=length,minRadius=minRadius,bounds=bounds,roadStrips=#points-1}
end
return Layout
