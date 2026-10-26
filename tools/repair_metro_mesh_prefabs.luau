-- Studio Edit authoring gate. Mesh IDs encoded in sanitized exterior part names.
assert(not game:GetService('RunService'):IsRunning(),'Edit mode only')
local resources=game.ReplicatedStorage:FindFirstChild('KDMMetroResources')
assert(resources,'Missing Metro palette')
local cache={};local count=0
for _,part in resources:GetDescendants()do if part:IsA('MeshPart')then
 local id=assert(part.Name:match('^Mesh_(%d+)_'),'Unexpected exterior part')
 local expected='rbxassetid://'..id
 if part.MeshId~=expected or math.min(part.MeshSize.X,part.MeshSize.Y,part.MeshSize.Z)<=0 then
  local mesh=cache[id]
  if not mesh then mesh=game:GetService('AssetService'):CreateMeshPartAsync(Content.fromUri(expected));cache[id]=mesh end
  local size,frame,texture=part.Size,part.CFrame,part.TextureID
  part:ApplyMesh(mesh);part.Size=size;part.CFrame=frame;part.TextureID=texture
 end
 assert(part.MeshId==expected,'Exterior mesh repair failed')
 assert(math.min(part.MeshSize.X,part.MeshSize.Y,part.MeshSize.Z)>0,'Exterior intrinsic size repair failed')
 count+=1;if count%16==0 then task.wait()end
end end
for _,mesh in cache do mesh:Destroy()end
return {verified=count}
