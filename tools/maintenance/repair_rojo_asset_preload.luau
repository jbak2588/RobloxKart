-- lune run tools/maintenance/repair_rojo_asset_preload.luau [plugin path]
-- Backs up the original outside Plugins; refuses unknown preloader versions.
local fs,rb,serde,process=require('@lune/fs'),require('@lune/roblox'),require('@lune/serde'),require('@lune/process')
local patch=require('./rojo_asset_preload_patch')
local path=process.args[1] or assert(process.env.LOCALAPPDATA,'LOCALAPPDATA required')..'/Roblox/Plugins/RojoManagedPlugin.rbxm'
local original=fs.readFile(path)
local roots=rb.deserializeModel(original)
if not patch.apply(roots)then print('PASS: Rojo audio preloader already repaired');return end
local backupDir='artifacts/studio-open-errors'
if not fs.isDir(backupDir)then fs.writeDir(backupDir)end
local backup=backupDir..'/RojoManagedPlugin.'..serde.hash('sha256',original)..'.bak'
if fs.isFile(backup)then assert(fs.readFile(backup)==original,'Existing backup differs')else fs.writeFile(backup,original)end
local updated=rb.serializeModel(roots)
assert(not patch.apply(rb.deserializeModel(updated)),'Repaired model must round-trip idempotently')
fs.writeFile(path,updated)
print('PASS: repaired local Rojo preloader; backup: '..backup)
print('Open a new Studio instance to load the repaired plugin. No game source or Publish changed.')
