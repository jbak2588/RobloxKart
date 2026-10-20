-- Typed transport and failure cleanup for the local maintenance patch.
local rb,luau,fs=require('@lune/roblox'),require('@lune/luau'),require('@lune/fs')
local patch=require('../tools/maintenance/rojo_asset_preload_patch')
local n=0;local function check(v,label)assert(v,label);n+=1 end
for _,fails in {false,true}do
 local sounds={};local image='rbxassetid://5981360418';local audio='rbxassetid://203785492'
 local assets={Images={Logo=image},Sounds={Notification=audio},Slices={Nested={Image=image}}}
 local provider={PreloadAsync=function(_,list)
  local images,typed=0,0
  for _,item in list do
   check(item~=audio,'audio ID never sent as raw image string')
   if type(item)=='string' then check(item==image,'image dependency preserved');images+=1
   else check(item.ClassName=='Sound' and item.SoundId==audio,'audio retains typed SoundId context');typed+=1 end
  end
  check(images==2 and typed==1,'image and audio dependencies both preloaded')
  if fails then error('injected preload failure')end
 end}
 local script={Parent={Assets='Assets',Parent={Packages={Log='Log'}}}}
 local preload=luau.load(patch.source,{environment={script=script,
  game={GetService=function(_,name)assert(name=='ContentProvider');return provider end},
  require=function(module)return if module=='Assets' then assets else {trace=function()end}end,
  typeof=type,Instance={new=function(class)
   local sound={ClassName=class};function sound:Destroy()self.destroyed=true end
   table.insert(sounds,sound);return sound
  end}}})()
 local ok=pcall(preload)
 check(ok~=fails,'original preload failure visibility preserved')
 check(#sounds==1 and sounds[1].destroyed,'temporary Sound cleaned on success and failure')
 check(assets.Sounds.Notification==audio,'shared Assets table unchanged')
end
local root=rb.Instance.new('Folder');root.Name='Rojo'
local plugin=rb.Instance.new('Folder');plugin.Name='Plugin';plugin.Parent=root
local module=rb.Instance.new('ModuleScript');module.Name='preloadAssets';module.Parent=plugin
module.Source='return function() end'
check(not pcall(patch.apply,{root}) and module.Source=='return function() end','unknown plugin version rejected without mutation')
module.Source=patch.source
check(not patch.apply({root}),'patched source is idempotent')
check(not patch.apply(rb.deserializeModel(rb.serializeModel({root}))),'plugin binary round-trip keeps repaired source')
local before=fs.readFile('src/server/PrototypeWorld.luau')
check(not before:find('203785492',1,true) and not before:find('GetClassName',1,true),'no gameplay workaround for editor errors')
print('PASS: '..n..' local Rojo asset preload/cleanup/version guard checks')
