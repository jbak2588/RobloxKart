local fs,rb=require('@lune/fs'),require('@lune/roblox')
local a=rb.deserializeModel(fs.readFile('src/assets/KDMTemplateResources.rbxmx'))[1]
local count=0
for _,o in a:GetDescendants() do
 assert(not o:IsA('LuaSourceContainer') and not o:IsA('RemoteEvent') and not o:IsA('VehicleSeat'),'unsafe template content')
 if o:IsA('MeshPart') then count+=1;end
end
assert(count==5,'three stand meshes plus original flat buggy ornament')
assert(a.Kiosk.Prompt.BillboardGui.Frame.TextLabel.Text=='SPAWN CAR')

for _,side in {'Left','Right'} do
 local att=a:FindFirstChild(side..'NitroEmitterAttachment')
 assert(#att:GetChildren()==4,'original three emitters and light')
 for _,name in {'RearEmitter','SparkEmitter','GlowEmitter'} do
  local p=att:FindFirstChild(name);assert(p.Rate==(if name=='GlowEmitter' then 30 else 80))
  assert(p.Size.Keypoints[1].Value==(if name=='GlowEmitter' then 2 else 1))
  assert(p.LightEmission==1 and p.LockedToPart and p.Lifetime.Max==rb.NumberRange.new(.1,.15).Max)
 end
 assert(att.PointLight.Brightness==2 and att.PointLight.Range==8)
end
local xml=fs.readFile('src/assets/KDMTemplateResources.rbxmx')
for _,id in {'9499084839','9499012935','9499012651','9663228697','9663228573','15424339197','15424681069'} do assert(xml:find(id,1,true),'original content ID '..id)end
assert(a.EngineAudio.EngineLoopPlayer.Looping)
local smoke=fs.readFile('src/client/KartWorldExhaustRenderer.luau')
assert(smoke:find('template:Clone()',1,true),'actual original assets used')
print('PASS: script-free original mesh/GUI/Nitro/audio asset contracts')
