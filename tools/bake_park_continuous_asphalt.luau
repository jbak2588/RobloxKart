-- Offline geometry export for Studio 3D Importer. No runtime mesh/image APIs.
local fs,rb,luau=require('@lune/fs'),require('@lune/roblox'),require('@lune/luau')
local Vector3,Vector2=rb.Vector3,rb.Vector2
local L=luau.load(fs.readFile('src/shared/HubParkRookieLoopLayout.luau'),{environment={Vector3=Vector3}})()
local points=L.sample(L.Segments);table.remove(points)
local kept={}
-- Match the existing ribbon's exact boundary stations, including float precision.
for i,p in points do
 local a,b=points[(i-2)%#points+1],points[i%#points+1]
 local u=Vector3.new(p.x-a.x,0,p.z-a.z).Unit
 local v=Vector3.new(b.x-p.x,0,b.z-p.z).Unit
 if u:Dot(v)<.99999999 then table.insert(kept,p)end
end
local lines={'o KDM_Park_Continuous_Asphalt'}
local positions,uvs,faces={},{},{}
local mesh={}
function mesh:AddVertex(v)table.insert(positions,v);return #positions end
function mesh:AddUV(v)table.insert(uvs,v);return #uvs end
function mesh:AddNormal()return 1 end
function mesh:AddTriangle(a,b,c)table.insert(faces,{a,b,c});return #faces end
function mesh:SetFaceNormals()end
function mesh:SetFaceUVs()end
local edges={};local half=(L.RoadWidth+2*L.KerbWidth+1)/2
local lo=Vector3.new(math.huge,.02,math.huge)
local hi=Vector3.new(-math.huge,.02,-math.huge)
local normal=mesh:AddNormal(Vector3.yAxis)
for i,p in kept do
 local a,b=kept[(i-2)%#kept+1],kept[i%#kept+1]
 local before=Vector3.new(p.x-a.x,0,p.z-a.z).Unit
 local after=Vector3.new(b.x-p.x,0,b.z-p.z).Unit
 local n1,n2=Vector3.new(-before.Z,0,before.X),Vector3.new(-after.Z,0,after.X)
 local n=(n1+n2).Unit;local off=n*(half/math.max(.5,n:Dot(n2)))
 local c=Vector3.new(p.x,.02,p.z);edges[i]={}
 for j,v in {c-off,c+off}do
  lo=Vector3.new(math.min(lo.X,v.X),.02,math.min(lo.Z,v.Z))
  hi=Vector3.new(math.max(hi.X,v.X),.02,math.max(hi.Z,v.Z))
  edges[i][j]={vertex=mesh:AddVertex(v),uv=mesh:AddUV(Vector2.new(v.X/24,v.Z/24))}
 end
end
local function face(a,b,c)
 local f=mesh:AddTriangle(a.vertex,b.vertex,c.vertex)
 mesh:SetFaceNormals(f,{normal,normal,normal});mesh:SetFaceUVs(f,{a.uv,b.uv,c.uv})
end
for i,a in edges do
 local b=edges[i%#edges+1]
 -- Reverse the original wedge vertex order to face upwards.
 face(a[1],b[2],b[1]);face(a[1],a[2],b[2])
end

-- Give the planar ribbon a real intrinsic thickness, avoiding zero-axis mesh
-- normalization on ordinary clients. The visible top stays exactly at .02.
local topVertices=#positions;local topFaces=#faces
for i=1,topVertices do
 table.insert(positions,positions[i]-Vector3.yAxis*.01);table.insert(uvs,uvs[i])
end
for i=1,topFaces do local f=faces[i]
 table.insert(faces,{f[3]+topVertices,f[2]+topVertices,f[1]+topVertices})
end
for i=1,#edges do local j=i%#edges+1
 for _,side in {1,2}do
  local a,b=(i-1)*2+side,(j-1)*2+side
  if side==1 then a,b=b,a end
  table.insert(faces,{a,b,b+topVertices});table.insert(faces,{a,b+topVertices,a+topVertices})
 end
end
for _,v in positions do table.insert(lines,string.format('v %.9f %.9f %.9f',v.X,v.Y,v.Z))end
for _,v in uvs do table.insert(lines,string.format('vt %.9f %.9f',v.X,v.Y))end
table.insert(lines,'vn 0 1 0')
for _,f in faces do table.insert(lines,string.format('f %d/%d/1 %d/%d/1 %d/%d/1',f[1],f[1],f[2],f[2],f[3],f[3]))end
fs.writeFile('src/assets/ParkContinuousAsphalt.obj',table.concat(lines,'\n')..'\n')
print(require('@lune/serde').encode('json',{vertices=#positions,faces=#faces,center={(lo.X+hi.X)/2,.015,(lo.Z+hi.Z)/2},size={hi.X-lo.X,.01,hi.Z-lo.Z}}))
