-- EDIT authoring only: Rojo cannot assign privileged MeshId / intrinsic geometry.
-- Rehydrate existing owned assets, never create meshes or change runtime security.
assert(game:GetService('RunService'):IsStudio()and not game:GetService('RunService'):IsRunning(),'Edit only')
assert((game.GameId==10768420544 and game.PlaceId==127925465904803)or(game.GameId==0 and game.PlaceId==0),'Exact official target or local preview only')
local ids={OuterLeaves='rbxassetid://11504219297',Trunk='rbxassetid://5553094293',
 SuperZ_Asphalt='rbxassetid://74480362127543',SuperZ_KerbWhite_0='rbxassetid://135028494263305',
 SuperZ_Edge_0='rbxassetid://103276107501548',SuperZ_KerbRed_0='rbxassetid://93004032813604',
 SuperZ_KerbWhite_1='rbxassetid://72862141196500',SuperZ_Edge_1='rbxassetid://79370398047265',SuperZ_KerbRed_1='rbxassetid://99183515249084'}
local source=game.ReplicatedStorage:WaitForChild('KDMSuperZResources');local templates={};local n=0
for _,p in source:GetDescendants()do if p:IsA('MeshPart')then
 local id=assert(ids[p.Name],'Unmanifested mesh '..p.Name)
 if p.MeshId~=id or p.MeshSize.X<=0 or p.MeshSize.Y<=0 or p.MeshSize.Z<=0 then
  local template=templates[id]
  if not template then template=game:GetService('InsertService'):CreateMeshPartAsync(id,Enum.CollisionFidelity.Box,Enum.RenderFidelity.Automatic);templates[id]=template end
  local size,cf,color,texture,material,variant,double=p.Size,p.CFrame,p.Color,p.TextureID,p.Material,p.MaterialVariant,p.DoubleSided
  p:ApplyMesh(template);p.Size=size;p.CFrame=cf;p.Color=color;p.TextureID=texture;p.Material=material;p.MaterialVariant=variant;p.DoubleSided=double
 end
 assert(p.MeshId==id and p.MeshSize.X>0 and p.MeshSize.Y>0 and p.MeshSize.Z>0,'Native mesh failed '..p.Name)
 n+=1;if n%30==0 then task.wait()end
end end
for _,p in templates do p:Destroy()end
assert(n==153,'Expected7 road +146 tree MeshParts')
return {nativeMeshPartsVerified=n}
