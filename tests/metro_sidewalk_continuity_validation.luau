local fs,rb,luau,serde=require('@lune/fs'),require('@lune/roblox'),require('@lune/luau'),require('@lune/serde')
local V=rb.Vector3
local n=0;local function check(v,m)assert(v,m);n+=1 end
local meta=serde.decode('json',fs.readFile('src/assets/MetroContinuousSidewalkGeometry.json')).PracticeCircuitV1
local asset=rb.deserializeModel(fs.readFile('src/assets/KDMMetroSidewalk.rbxmx'))[1]
local vertices,faces={},{ }
for line in fs.readFile('src/assets/MetroContinuousSidewalk.obj'):gmatch('[^\r\n]+')do
 local x,y,z=line:match('^v ([%d%.%-]+) ([%d%.%-]+) ([%d%.%-]+)')
 if x then table.insert(vertices,V.new(tonumber(x),tonumber(y),tonumber(z)))end
 local a,b,c=line:match('^f (%d+)/%d+/%d+ (%d+)/%d+/%d+ (%d+)/%d+/%d+')
 if a then table.insert(faces,{tonumber(a),tonumber(b),tonumber(c)})end
end
check(#vertices==meta.vertices and #faces==meta.faces,'reviewable offline mesh topology')
local edges={};local topEdges={}
for i,f in faces do
 local a,b,c=vertices[f[1]],vertices[f[2]],vertices[f[3]]
 check((b-a):Cross(c-a).Magnitude>1e-7,'no degenerate faces')
 if i<=meta.topFaces then check((b-a):Cross(c-a).Y>0,'visible faces upward')end
 for j=1,3 do
  local x,y=f[j],f[j%3+1];local key=math.min(x,y)..':'..math.max(x,y)
  edges[key]=(edges[key]or 0)+1
  if i<=meta.topFaces then topEdges[key]=(topEdges[key]or 0)+1 end
 end
end
for _,count in edges do check(count==2,'closed shared edges without disconnected endcaps')end
for _,count in topEdges do check(count<=2,'no stacked overlapping top faces')end
local low,high=V.new(math.huge,math.huge,math.huge),V.new(-math.huge,-math.huge,-math.huge)
for _,v in vertices do low=low:Min(v);high=high:Max(v)end
check((high-low-asset.Size).Magnitude<.0001 and ((low+high)/2-asset.CFrame.Position).Magnitude<.0001,'positive intrinsic dimensions and native axis compensation')
check(math.abs(high.Y-.12)<.000001,'single level sidewalk top')
check(not asset.CanCollide and not asset.CanTouch and not asset.CanQuery and not asset.CastShadow,'presentation only')
local G=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=V,Vector2=rb.Vector2,CFrame=rb.CFrame}})()
local course=G.getCourse(G.getDefinition('PracticeCircuitV1'))
local oldParts=math.ceil(#course.Samples/2)*2
check(oldParts>1 and #faces<oldParts*12,'one mesh and fewer triangles than previous sidewalk cuboids')
check(asset.RenderFidelity==rb.Enum.RenderFidelity.Precise,'curved boundary preserved at distance')
print('PASS '..n..' sidewalk topology/height/inert asset checks; '..oldParts..' parts -> 1, '..(oldParts*12)..' -> '..#faces..' triangles')
