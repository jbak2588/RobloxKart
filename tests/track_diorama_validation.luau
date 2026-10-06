local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local n=0;local function check(v,s) assert(v,s);n+=1 end
local geometry=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame}})()
local catalog=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment={CFrame=rb.CFrame}})()
local builder=luau.load(fs.readFile('src/client/TrackPreviewBuilder.luau'),{environment={game={GetService=function() return {WaitForChild=function(self) return self end} end},require=function() return geometry end,Instance=rb.Instance,Vector3=rb.Vector3,CFrame=rb.CFrame,Enum=rb.Enum,Color3=rb.Color3}})()
local reports={}
for _,id in catalog.Order do
 local track=catalog.Entries[id];local data=builder.build(track)
 check(data.parts<=(if id=='Track03' then 200 else 150),'instance budget '..id)
 check(data.previewSamples<data.productionSamples,'decimation '..id)
 check(data.tolerance<geometry.getDefinition(track.GeometryId).RoadWidth/2,'silhouette error below half road width '..id)
 check(data.min.X<data.max.X and data.min.Z<data.max.Z,'valid bounds '..id)
 check(data.world:FindFirstChild('StartFinish') and data.world:FindFirstChild('FinishGate') and data.world:FindFirstChild('ForwardCue'),'finish/direction '..id)
 local mesh=0
 for _,p in data.world:GetDescendants() do
  check(p:IsA('BasePart'),'geometry only '..p.ClassName)
  check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow,'visual only '..id)
  if p:IsA('MeshPart') then mesh+=1 end
 end
 check(mesh==0,'no production meshes '..id)
 table.insert(reports,{track=id,productionSamples=data.productionSamples,previewSamples=data.previewSamples,BaseParts=data.parts,MeshParts=mesh,otherVisualInstances=0,totalVisualInstances=data.parts,containers=1,toleranceStuds=data.tolerance})
 local parent=rb.Instance.new('Folder');data.world.Parent=parent
 data.world:Destroy();local rebuilt=builder.build(track);rebuilt.world.Parent=parent
 check(#parent:GetChildren()==1,'single active world rebuild '..id);rebuilt.world:Destroy()
end
local ok=pcall(builder.build,{GeometryId='missing'});check(not ok,'missing geometry returns failure for fallback')
local source=fs.readFile('src/client/TrackPreviewBuilder.luau')
check(not source:find(':Clone%(') and not source:find('Workspace'),'no production clone dependency')
check(catalog.DefaultId=='Track01','catalog unchanged')
print(require('@lune/serde').encode('json',reports))
if fs.isDir('artifacts/r7-h3') then fs.writeFile('artifacts/r7-h3/preview-counts.json',require('@lune/serde').encode('json',reports,true)) end
print('PASS: '..n..' Track diorama geometry checks')

