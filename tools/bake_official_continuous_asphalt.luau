-- Offline geometry export for Studio 3D Importer. No runtime mesh/image APIs.
local fs,rb,luau=require('@lune/fs'),require('@lune/roblox'),require('@lune/luau')
local Vector3,Vector2=rb.Vector3,rb.Vector2
local G=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=Vector3,Vector2=Vector2,CFrame=rb.CFrame}})()
local metadata={}
for _,geometryId in {'PracticeFigure8V1','PracticeCircuitV1','HardCircuitV1'}do
local definition=G.getDefinition(geometryId)
local points=G.getCourse(definition).Samples
local kept={}
-- Match the existing ribbon's exact boundary stations, including float precision.
for i,p in points do
 local a,b=points[(i-2)%#points+1],points[i%#points+1]
 local u=(p-a).Unit
 local v=(b-p).Unit
 if u:Dot(v)<.99999999 then table.insert(kept,p)end
end
local lines={'o '..geometryId..'_Continuous_Asphalt'}
local positions,uvs,faces={},{},{}
local mesh={}
function mesh:AddVertex(v)table.insert(positions,v);return #positions end
function mesh:AddUV(v)table.insert(uvs,v);return #uvs end
function mesh:AddNormal()return 1 end
function mesh:AddTriangle(a,b,c)table.insert(faces,{a,b,c});return #faces end
function mesh:SetFaceNormals()end
function mesh:SetFaceUVs()end
local edges={};local half=definition.RoadWidth/2
local lo=Vector3.new(math.huge,.065,math.huge)
local hi=Vector3.new(-math.huge,.065,-math.huge)
local normal=mesh:AddNormal(Vector3.yAxis)
for i,p in kept do
 local a,b=kept[(i-2)%#kept+1],kept[i%#kept+1]
 local before=(p-a).Unit
 local after=(b-p).Unit
 local n1,n2=Vector3.new(-before.Z,0,before.X),Vector3.new(-after.Z,0,after.X)
 local n=(n1+n2).Unit;local off=n*(half/math.max(.5,n:Dot(n2)))
 local c=Vector3.new(p.X,.065,p.Z);edges[i]={}
 for j,v in {c-off,c+off}do
  lo=Vector3.new(math.min(lo.X,v.X),.065,math.min(lo.Z,v.Z))
  hi=Vector3.new(math.max(hi.X,v.X),.065,math.max(hi.Z,v.Z))
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

-- Preserve the two original elevated crossover overlays inside the same mesh.
if definition.Crossover then
 local crossing=definition.Crossover
 for branch,tangent in crossing.BranchTangents do
  local right=Vector3.new(-tangent.Z,0,tangent.X)
  local center=crossing.Position+Vector3.yAxis*(.105+(branch-1)*.015)
  local polygon={}
  for _,sign in {{-1,-1},{1,-1},{1,1},{-1,1}}do
   local v=center+tangent*crossing.VisualHalfLength*sign[1]+right*half*sign[2]
   table.insert(polygon,{vertex=mesh:AddVertex(v),uv=mesh:AddUV(Vector2.new(v.X/24,v.Z/24))})
  end
  -- Reverse tangent/right winding to face upward.
  face(polygon[1],polygon[3],polygon[2]);face(polygon[1],polygon[4],polygon[3])
 end
end
-- Give the planar ribbon a real intrinsic thickness, avoiding zero-axis mesh
-- normalization on ordinary clients. The visible top stays exactly at .065.
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
fs.writeFile('src/assets/'..geometryId..'ContinuousAsphalt.obj',table.concat(lines,'\n')..'\n')
local minY,maxY=math.huge,-math.huge
for _,v in positions do minY=math.min(minY,v.Y);maxY=math.max(maxY,v.Y)end
metadata[geometryId]={vertices=#positions,faces=#faces,topFaces=topFaces,
 center={(lo.X+hi.X)/2,(minY+maxY)/2,(lo.Z+hi.Z)/2},
 size={hi.X-lo.X,maxY-minY,hi.Z-lo.Z}}
end
fs.writeFile('src/assets/OfficialContinuousAsphaltGeometry.json',require('@lune/serde').encode('json',metadata,true))
print(require('@lune/serde').encode('json',metadata))
