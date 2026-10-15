local fs,luau=require('@lune/fs'),require('@lune/luau')
local p=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local g=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))().create(p)
local n=0;local function check(v,label)assert(v,label);n+=1 end
local function probe(x,z,fx,fz)
 check(p.fits(g,x-120,z-766,fx,fz),'complete production chassis fits forward')
 check(p.fits(g,x-120,z-766,-fx,-fz),'complete production chassis fits reverse direction')
end
for x=-95,265,2 do probe(x,994,-1,0)end
for z=868,934,2 do probe(325,z,0,1)end
for z=898,934,2 do probe(-155,z,0,-1)end
for _,a in {{265,868,60,-math.pi/2,0},{265,934,60,0,math.pi/2},{-95,934,60,math.pi/2,math.pi},{-65,898,90,math.pi,3*math.pi/2}} do
 for i=0,100 do local t=a[4]+(a[5]-a[4])*i/100;probe(a[1]+a[3]*math.cos(t),a[2]+a[3]*math.sin(t),-math.sin(t),math.cos(t))end
end
for z=875,950,2 do for x=-65,95,2 do check(not g.inside(x-120,z-766),'protected building and pedestrian rear stay excluded')end end
for x=-90,160,2 do
 check(g.inside(x-120,988-766,20),'rear road has at least twenty studs center clearance')
 if x>=-65 and x<=95 then check(not g.inside(x-120,956-766),'building-side boundary remains closed')end
end
for _,e in g.boundaries do
 local x,z=(e.a.x+e.b.x)/2,(e.a.z+e.b.z)/2
 -- Every retained wall is a real admission boundary, with no internal join wall.
 check(math.abs(g.contact(x,z))<1e-5,'no false internal barrier')
end
check(g.rear.maxZ+766==1018 and g.rear.minZ+766==958,'rear footprint fits native baseplate')
print('PASS '..n..' complete-chassis bidirectional loop / protected building / no false join barrier checks')
