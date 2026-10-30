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
 if type(source)~='string'then return false,'missing/unprotected source'end
 source=Freeze.canonical(source)
 local hash=serde.hash('sha256',source)
 if manifest.officialRoadContinuityPatches and manifest.officialRoadContinuityPatches[path]==hash then return true,'OFFICIAL_ROAD_CONTINUITY'end
 if manifest.multiplayerFallbackPatches and manifest.multiplayerFallbackPatches[path]==hash then return true,'MULTIPLAYER_FALLBACK'end
 if manifest.hubArrivalUiPatches and manifest.hubArrivalUiPatches[path]==hash then return true,'HUB_ARRIVAL_UI'end
 if manifest.timeAttackRewardPatches and manifest.timeAttackRewardPatches[path]==hash then return true,'TIME_ATTACK_REWARD'end
 if manifest.parkItemsKioskPatches and manifest.parkItemsKioskPatches[path]==hash then return true,'PARK_ITEMS_KIOSK'end
 if manifest.parkOvertakePatches and manifest.parkOvertakePatches[path]==hash then return true,'PARK_OVERTAKE'end
 if not entry then return false,'missing/unprotected source'end
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
 local park=manifest.parkDriverCollisionPatch
 local vfxOpt=manifest.vfxOptimizationPatches
 if park and path=='src/server/LobbyTestDriveService.luau' and path==park.path and hash==park.sha256 then
  return true,'PARK_DRIVER_COLLISION'
 end
 if speedV2 and path==speedV2.path and hash==speedV2.sha256 then
  return true,'SPEED_V2_PHASE1'
 end
 if vfxOpt and vfxOpt[path] and hash==vfxOpt[path] then
  return true,'VFX_OPTIMIZATION'
 end
 return false,'unapproved full-file change'
end
function Freeze.collect(manifest,read)
 local errors,classes={},{}
 local paths=table.clone(manifest.files)
 for path in manifest.parkOvertakePatches or {}do paths[path]=true end
 for path in manifest.parkItemsKioskPatches or {}do paths[path]=true end
 for path in manifest.timeAttackRewardPatches or {}do paths[path]=true end
 for path in manifest.hubArrivalUiPatches or {}do paths[path]=true end
 for path in manifest.multiplayerFallbackPatches or {}do paths[path]=true end
 for path in manifest.officialRoadContinuityPatches or {}do paths[path]=true end
 for path in paths do
  local loaded,source=pcall(read,path)
  local ok,reason=false,'missing/unreadable source'
  if loaded then ok,reason=Freeze.accepts(manifest,path,source)end
  if ok then classes[path]=reason else table.insert(errors,path..': '..reason)end
 end
 table.sort(errors)
 return errors,classes
end
return Freeze
