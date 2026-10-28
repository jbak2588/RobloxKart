-- Current-release integrity is distinct from historical N1/N2 reconstruction.
-- Compare canonical LF bytes only; never normalize gameplay/presentation hunks.
local serde=require('@lune/serde')
local Freeze={}
function Freeze.canonical(source)
 local canonical=source:gsub('\r\n','\n')
 return canonical
end
function Freeze.accepts(manifest,path,source)
 local entry=manifest.files[path]
 if not entry or type(source)~='string' then return false,'missing/unprotected source' end
 source=Freeze.canonical(source)
 local hash=serde.hash('sha256',source)
 if hash==entry.sha256 then return true,'APPROVED_HEAD' end
 for _,r3 in {manifest.ownerR3PolicyPatch,manifest.ownerR3DisplayPatch}do
 if r3 and (path=='src/server/RaceRecordOperations.luau' or path=='src/shared/TrackCatalog.luau') and path==r3.path and hash==r3.sha256 then
  local first=source:find(r3.after,1,true)
  if first and not source:find(r3.after,first+#r3.after,true)then
   local restored=source:sub(1,first-1)..r3.before..source:sub(first+#r3.after)
   if serde.hash('sha256',restored)==entry.sha256 then return true,'OWNER_R3_POLICY_PATCH' end
  end
 end
 end
 if path==manifest.fovPhase1.path and hash==manifest.fovPhase1.sha256 then
  local restored=source
  for _,pair in {
   {'Speed.HIGH_SPEED_START = 50','Speed.HIGH_SPEED_START = 55'},
   {'Speed.HIGH_SPEED_FULL = 90','Speed.HIGH_SPEED_FULL = 80'},
   {'HIGH_SPEED = table.freeze({FovDelta=5,','HIGH_SPEED = table.freeze({FovDelta=3,'},
  }do
   local first=restored:find(pair[1],1,true)
   if not first or restored:find(pair[1],first+#pair[1],true)then return false,'FOV scope occurrence mismatch' end
   restored=restored:sub(1,first-1)..pair[2]..restored:sub(first+#pair[1])
  end
  if serde.hash('sha256',restored)==entry.sha256 then return true,'FOV_PHASE1' end
 end
 local speedV2=manifest.speedV2Phase1Patch
 if speedV2 and path==speedV2.path and hash==speedV2.sha256 then
  return true,'SPEED_V2_PHASE1'
 end
 return false,'unapproved full-file change'
end
function Freeze.collect(manifest,read)
 local errors,classes={},{}
 for path in manifest.files do
  local loaded,source=pcall(read,path)
  local ok,reason=false,'missing/unreadable source'
  if loaded then ok,reason=Freeze.accepts(manifest,path,source)end
  if ok then classes[path]=reason else table.insert(errors,path..': '..reason)end
 end
 table.sort(errors)
 return errors,classes
end
return Freeze
