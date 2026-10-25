-- Run in Studio EDIT mode after a Rojo asset sync and before Publish.
-- MeshContent is immutable through normal property sync; ApplyMesh retains PBR children.
assert(not game:GetService('RunService'):IsRunning(), 'Edit mode only')
local expected={Cactus_a='rbxassetid://15491325754',Agave_a='rbxassetid://15169965752',Racing_Boulder_a='rbxassetid://15171684910'}
local natural=game.ReplicatedStorage.KDMDesertResources.Natural
local checked=0
for _,part in natural:GetDescendants()do
 if part:IsA('MeshPart')then
  local id=assert(expected[part.Name], 'Unexpected desert mesh')
  if part.MeshId~=id then
   local size,frame,texture=part.Size,part.CFrame,part.TextureID
   local mesh=game:GetService('AssetService'):CreateMeshPartAsync(Content.fromUri(id))
   part:ApplyMesh(mesh);part.Size=size;part.CFrame=frame;part.TextureID=texture
   mesh:Destroy()
  end
  assert(part.MeshId==id, 'Desert mesh repair failed: '..part.Name)
  checked+=1
 end
end
assert(checked==3, 'Expected exactly three source natural meshes')
return {verified=checked}
