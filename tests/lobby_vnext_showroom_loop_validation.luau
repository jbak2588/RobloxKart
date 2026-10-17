local fs,luau=require('@lune/fs'),require('@lune/luau')
local p=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local g=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))().create(p)
local n=0;local function check(v,label)assert(v,label);n+=1 end
local function probe(x,z,fx,fz)
 check(p.fits(g,x-120,z-766,fx,fz),'complete chassis fits forward')
 check(p.fits(g,x-120,z-766,-fx,-fz),'complete chassis fits reverse')
 local paved=false
 for _,span in g.intervals(z-766,true) do if x-120>=span[1] and x-120<=span[2] then paved=true end end
 check(paved,'loop center remains on asphalt')
end
for x=-55,115,2 do probe(x,821,1,0);probe(x,981,-1,0) end
for _,arc in {{115,901,-math.pi/2,math.pi/2},{-55,901,math.pi/2,3*math.pi/2}} do
 for i=0,200 do local a=arc[3]+(arc[4]-arc[3])*i/200
  probe(arc[1]+80*math.cos(a),arc[2]+80*math.sin(a),-math.sin(a),math.cos(a))
 end
end
for _,e in g.boundaries do check(math.abs(g.contact((e.a.x+e.b.x)/2,(e.a.z+e.b.z)/2))<1e-5,'no false internal walls') end
check(g.bounds.maxZ+766==1018,'native baseplate limit')
print('PASS: '..n..' bidirectional reference oval / asphalt / no internal wall checks')
