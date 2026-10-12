-- Explicitly authorized one-account maintenance, invoked only by the live HUB.
-- Back up and verify before a compare-and-swap reset; never replace the profile.
local Reset={}
function Reset.run(S,schema,deps)
 local previous=deps.read()
 if previous==nil then return 'ABSENT' end
 if type(previous)~='table' or previous.schemaVersion~=1 or previous.userId~=deps.userId or previous.deleted~=false then return 'PROFILE_PROTECTED' end
 if previous.recordReset and previous.recordReset.id==deps.id then return 'ALREADY_RESET' end
 local signature=S.canonical(previous)
 local nextValue=S.clone(previous)
 nextValue.records={scoped={}};nextValue.pendingIndex={};nextValue.pendingRaceIndex={}
 for key in nextValue.receipts or {} do if type(key)=='string' and key:sub(1,12)=='race-record:' then nextValue.receipts[key]=nil end end
 nextValue.recordReset={id=deps.id,completedAt=deps.utcMs(),backupRef=deps.backupRef}
 local valid,reason=schema.validate(nextValue,S.userKey(deps.userId))
 if not valid then return 'PROFILE_PROTECTED',reason end
 deps.backup({userId=deps.userId,resetId=deps.id,profile=previous})
 local backup=deps.readBackup()
 if type(backup)~='table' or backup.userId~=deps.userId or backup.resetId~=deps.id
  or S.canonical(backup.profile)~=signature then return 'BACKUP_UNCONFIRMED' end
 local outcome='RESET_CONFLICT'
 deps.update(function(current)
  if current and current.recordReset and current.recordReset.id==deps.id then outcome='ALREADY_RESET';return nil end
  if S.canonical(current)~=signature then return nil end
  outcome='RESET_APPLIED';return S.clone(nextValue)
 end)
 -- ACK loss is handled by the caller's pcall and a subsequent uncached query.
 local saved=deps.read()
 if saved and saved.recordReset and saved.recordReset.id==deps.id then
  local expected=S.clone(saved);expected.records=previous.records;expected.pendingIndex=previous.pendingIndex
  expected.pendingRaceIndex=previous.pendingRaceIndex;expected.receipts=previous.receipts;expected.recordReset=previous.recordReset
  if S.canonical(expected)~=signature then return 'PRESERVATION_UNCONFIRMED' end
  return 'RESET_CONFIRMED'
 end
 return outcome
end
return table.freeze(Reset)
