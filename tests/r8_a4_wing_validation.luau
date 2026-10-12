local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local env={Instance=rb.Instance,Vector3=rb.Vector3,CFrame=rb.CFrame,Enum=rb.Enum,Color3=rb.Color3}
local Wing=luau.load(fs.readFile('src/shared/KDMV2WingDefinition.luau'),{environment=env})()
local catalog=luau.load(fs.readFile('src/shared/KartCatalog.luau'),{environment=env})()
local checks=0
local function check(v,m)checks+=1;assert(v,m)end
local template=rb.deserializeModel(fs.readFile('src/shared/KDMV2Geometry.rbxmx'))[1]
local function worldSignature(m)
 local out={};for _,p in m:GetDescendants() do if p:IsA('BasePart') then table.insert(out,p.Name..'|'..tostring(p.CFrame)..'|'..tostring(p.Size)) end end
 table.sort(out);return table.concat(out,'\n')
end
local original=worldSignature(template)
for _,id in {'Kart05','Kart06','Kart07','Kart08','Kart09','Kart10','Kart11'} do
 local v=template:Clone();Wing.attach(v,catalog.Entries[id],true)
 local folder=v.StaticRoot.KDMV2Wing;local count=0
 for _,p in folder:GetChildren() do
  check(p:IsA('Part') and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery,'visual only')
  check(p.VisualWeld.Part0==v.StaticRoot and p.VisualWeld.Part1==p,'root attachment')
  check(p.Color==catalog.Entries[id].DisplayColor,'selected color');count+=1
 end
 check(count==9,'original nine part assembly')
 Wing.attach(v,catalog.Entries[id],true);check(#v.StaticRoot.KDMV2Wing:GetChildren()==9,'attach idempotent')
 Wing.attach(v,catalog.Entries[id],false);check(worldSignature(v)==original,'base geometry preserved')
end
Wing.attach(template,catalog.Entries.Kart01,true);check(not template.StaticRoot:FindFirstChild('KDMV2Wing'),'Sprint never receives V2 Wing')
print('PASS: '..checks..' wing visual, color, nonphysics and original geometry checks')
