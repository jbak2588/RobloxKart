-- R8-A1 pure contract. No service lookup; catalog and trusted mock inputs are injected.
local Schema = {}
local MAX_INTEGER = 9007199254740991

function Schema.integer(value, maximum)
 return type(value) == "number" and value == value and value >= 0
  and value <= (maximum or MAX_INTEGER) and value % 1 == 0
end

function Schema.clone(value)
 if type(value) ~= "table" then return value end
 local result = {}
 for key, item in value do result[key] = Schema.clone(item) end
 return result
end

function Schema.freeze(value)
 if type(value) == "table" then
  for _, item in value do Schema.freeze(item) end
  if not table.isfrozen(value) then table.freeze(value) end
 end
 return value
end

-- Length framing avoids delimiter collisions. This is a canonical string, not a crypto hash.
function Schema.frame(value)
 return tostring(#value) .. ":" .. value
end

function Schema.canonical(value)
 local seen, nodes = {}, 0
 local function visit(item, depth)
  nodes += 1
  assert(depth <= 16 and nodes <= 32768, "structure_limit")
  if type(item) == "string" then return "s" .. Schema.frame(item) end
  if type(item) == "boolean" then return if item then "b1" else "b0" end
  if type(item) == "number" then
   assert(item == item and math.abs(item) <= MAX_INTEGER, "nonfinite_number")
   return "n" .. Schema.frame(string.format("%.17g", item))
  end
  if item == nil then return "z" end
  assert(type(item) == "table" and getmetatable(item) == nil and not seen[item], "unsafe_structure")
  seen[item] = true
  local parts = {}
  for key, child in item do
   assert(type(key) == "string" or (Schema.integer(key) and key > 0), "invalid_key")
   table.insert(parts, visit(key, depth+1) .. visit(child, depth+1))
  end
  table.sort(parts)
  seen[item] = nil
  return "t" .. Schema.frame(table.concat(parts))
 end
 return visit(value, 0)
end

function Schema.count(value)
 local count = 0
 for _ in value do count += 1 end
 return count
end

-- JSON byte bound after canonical structure validation. Escape only bytes that
-- require escaping; multiplying the entire canonical receipt/profile by six
-- rejects ordinary ASCII profiles long before their actual size limit.
function Schema.jsonByteBound(value)
 local function quoted(s)
  local n=2
  for i=1,#s do local b=s:byte(i);n+=if b<32 then 6 elseif b==34 or b==92 then 2 else 1 end
  return n
 end
 local function size(v)
  if type(v)=='string' then return quoted(v) end
  if type(v)=='boolean' then return if v then 4 else 5 end
  if type(v)=='number' then return 32 end -- bound finite number formatting
  if v==nil then return 4 end
  local n=2;local count=0;local array=true;local highest=0
  for k in v do count+=1;if type(k)~='number' then array=false else highest=math.max(highest,k) end end
  array=array and highest==count
  for k,child in v do
   if not array then n+=quoted(tostring(k))+1 end
   n+=size(child)+1
  end
  return n
 end
 return size(value)
end

function Schema.userKey(userId)
 assert(Schema.integer(userId) and userId > 0, "invalid_user_id")
 return "u:" .. string.format("%.0f", userId)
end

function Schema.guid(value)
 return type(value) == "string" and #value == 36
  and value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

function Schema.eventId(roundGuid, userId, rewardKind)
 assert(Schema.guid(roundGuid), "global_round_guid_required")
 assert(type(rewardKind) == "string" and #rewardKind > 0 and #rewardKind <= 48, "invalid_reward_kind")
 return "event:v1|" .. Schema.frame(roundGuid:lower()) .. Schema.frame(Schema.userKey(userId)) .. Schema.frame(rewardKind)
end

function Schema.utcDay(utcMs)
 assert(Schema.integer(utcMs), "invalid_utc_time")
 return "UTC_DAY:" .. string.format("%.0f", math.floor(utcMs / 86400000))
end

function Schema.classify(roster)
 if type(roster) ~= "table" or #roster < 1 or #roster > 4 then return "UNCLASSIFIED", 0, 0 end
 local humans, bots, seen = 0, 0, {}
 if Schema.count(roster) ~= #roster then return "UNCLASSIFIED", 0, 0 end
 for i = 1, #roster do
  local member = roster[i]
  if type(member) ~= "table" or type(member.IsBot) ~= "boolean" then return "UNCLASSIFIED", 0, 0 end
  if member.IsBot then
   if type(member.BotId) ~= "string" or member.BotId == "" or seen["b:" .. member.BotId] then return "UNCLASSIFIED", 0, 0 end
   seen["b:" .. member.BotId] = true; bots += 1
  else
   if not Schema.integer(member.UserId) or member.UserId == 0 or seen[member.UserId] then return "UNCLASSIFIED", 0, 0 end
   seen[member.UserId] = true; humans += 1
  end
 end
 if humans == 0 then return "UNCLASSIFIED", humans, bots end
 if bots > 0 then
  return if humans == 1 and bots == 1 then "BOT_1H_1B" else "BOT_ASSISTED_" .. humans .. "H_" .. bots .. "B", humans, bots
 end
 return if humans == 1 then "SOLO_1H_0B" else "HUMAN_" .. humans .. "H_0B", humans, bots
end

function Schema.recordScope(trackId, geometryId, rulesetId, category)
 for _, id in {trackId, geometryId, rulesetId, category} do
  assert(type(id) == "string" and #id > 0 and #id <= 128, "invalid_scope_component")
 end
 assert(category ~= "UNCLASSIFIED", "unclassified_scope")
 return "record:v1|" .. Schema.frame(trackId) .. Schema.frame(geometryId) .. Schema.frame(rulesetId) .. Schema.frame(category)
end

function Schema.freezeRound(input)
 assert(type(input) == "table" and Schema.guid(input.RoundGuid), "invalid_round")
 assert(pcall(Schema.canonical,input), "invalid_round_structure")
 assert(type(input.diagnostic) == "boolean", "explicit_diagnostic_required")
 local category, humans, bots = Schema.classify(input.roster)
 assert(category ~= "UNCLASSIFIED", "unclassified_roster")
 local result = {RoundGuid=input.RoundGuid:lower(),TrackId=input.TrackId,GeometryId=input.GeometryId,
  RulesetId=input.RulesetId,diagnostic=input.diagnostic,roster={}}
 for _, member in input.roster do
  table.insert(result.roster,if member.IsBot then {IsBot=true,BotId=member.BotId} else {IsBot=false,UserId=member.UserId})
 end
 result.RaceCategory, result.humanCount, result.botCount = category, humans, bots
 result.recordScope = Schema.recordScope(result.TrackId, result.GeometryId, result.RulesetId, category)
 return Schema.freeze(result)
end

function Schema.officialCandidate(round, userId, finish)
 if type(round) ~= "table" or not table.isfrozen(round) or type(round.roster) ~= "table"
  or round.diagnostic or round.RaceCategory == "UNCLASSIFIED" then return false end
 local human = false
 for _, member in round.roster do
  if not member.IsBot and member.UserId == userId then human = true end
 end
 return human and type(finish) == "table" and finish.serverAccepted == true
  and finish.state == "FINISHED" and finish.fullLapValid == true
end

function Schema.globalCandidate(round, userId, finish)
 -- Candidate only: public board selection awaits A3/A5; nothing writes a score here.
 return Schema.officialCandidate(round, userId, finish) and round.botCount == 0
end

-- Optional v1 extension: old numeric records and receipts remain byte-for-byte compatible.
function Schema.raceScope(scope, laps)
 assert(type(scope)=="string" and scope:sub(1,10)=="record:v1|" and Schema.integer(laps,3) and laps>0,"invalid_race_scope")
 return "race:v1|"..Schema.frame(scope)..tostring(laps)
end

function Schema.raceSnapshotValid(value)
 if type(value)~="table" or not Schema.integer(value.userId) or value.userId==0
  or not Schema.guid(value.roundGuid) or not Schema.integer(value.finishedAt)
  or not Schema.integer(value.targetLaps,3) or value.targetLaps==0
  or not Schema.integer(value.totalMilliseconds,86400000) or value.totalMilliseconds==0
  or not Schema.integer(value.raceBoosts,10000) or type(value.laps)~="table"
  or #value.laps~=value.targetLaps or Schema.count(value.laps)~=#value.laps
  or not Schema.integer(value.startingHumans,4) or value.startingHumans==0
  or not Schema.integer(value.startingBots,3) or value.startingHumans+value.startingBots>4
  or not Schema.integer(value.finishPosition,value.startingHumans+value.startingBots) or value.finishPosition==0
  or type(value.eligible)~="boolean" or type(value.reason)~="string"
  or value.serverAccepted~=true or value.state~="FINISHED" or value.positionFinalized~=true then return false end
 if value.eligibilityDetail~=nil and (type(value.eligibilityDetail)~="string" or #value.eligibilityDetail>256) then return false end
 local category=if value.startingBots>0 then (if value.startingHumans==1 and value.startingBots==1 then "BOT_1H_1B"
  else "BOT_ASSISTED_"..value.startingHumans.."H_"..value.startingBots.."B")
  else (if value.startingHumans==1 then "SOLO_1H_0B" else "HUMAN_"..value.startingHumans.."H_0B")
 if value.category~=category then return false end
 local ok,scope=pcall(Schema.recordScope,value.trackId,value.geometryId,value.rulesetId,value.category)
 if not ok or value.recordScope~=scope then return false end
 local sum=0
 for _,ms in value.laps do if not Schema.integer(ms,86400000) or ms==0 then return false end;sum+=ms end
 return if value.eligible then value.reason=="FULL_ROUTE_V1" and math.abs(sum-value.totalMilliseconds)<=value.targetLaps
  else value.reason=="INVALID_ROUTE_OR_TIMER_RESET" or value.reason=="TOTAL_LAP_MISMATCH"
end

function Schema.new(catalog, options)
 assert(type(catalog) == "table" and catalog.DefaultId == "Kart05" and catalog.Entries[catalog.DefaultId], "catalog_contract")
 options = options or {}
 local supported = {}
 for id in catalog.Entries do supported[id] = true end
 local api = {maxCash=2147483647, maxReceipts=options.maxReceipts or 4096, maxBytes=options.maxBytes or 262144}
 function api.default(userId)
  Schema.userKey(userId)
  return {schemaVersion=1,userId=userId,selection={kartId=catalog.DefaultId,revision=0,lastOpId=""},
   wallet={cash=0,ledgerRevision=0},cosmetics={ownedPartIds={},equippedPartIdsBySlot={}},
   records={scoped={}},daily={claimBuckets={}},receipts={},pendingIndex={},deleted=false}
 end
 function api.supportsKart(id) return type(id) == "string" and supported[id] == true end
 function api.validate(profile, key)
  local ok, encoded = pcall(Schema.canonical, profile)
  if not ok then
   local detail=if tostring(encoded):find('structure_limit',1,true) then 'STRUCTURE_LIMIT'
    elseif tostring(encoded):find('nonfinite_number',1,true) then 'NONFINITE_NUMBER'
    elseif tostring(encoded):find('invalid_key',1,true) then 'INVALID_KEY' else 'UNSAFE_STRUCTURE'
   return false,detail
  end
  local bytes
  if options.jsonEncode then
   local jsonOK,json=pcall(options.jsonEncode,profile)
   if not jsonOK or type(json)~='string' then return false,'JSON_ENCODING_FAILED' end
   bytes=#json
  else bytes=Schema.jsonByteBound(profile) end
  if bytes>api.maxBytes then return false,'PROFILE_CAPACITY' end
  if type(profile) ~= "table" then return false, "CORRUPT" end
  if profile.schemaVersion ~= 1 then return false, "UNSUPPORTED_SCHEMA" end
  if not Schema.integer(profile.userId) or profile.userId == 0 or Schema.userKey(profile.userId) ~= key then return false, "WRONG_USER_KEY" end
  if type(profile.deleted) ~= "boolean" then return false, "CORRUPT_DELETION" end
  local s, w, c = profile.selection, profile.wallet, profile.cosmetics
  if type(s) ~= "table" or not api.supportsKart(s.kartId) or not Schema.integer(s.revision)
   or type(s.lastOpId) ~= "string" or #s.lastOpId > 128 then return false, "CORRUPT_SELECTION" end
  if type(w) ~= "table" or not Schema.integer(w.cash,api.maxCash) or not Schema.integer(w.ledgerRevision) then return false, "CORRUPT_WALLET" end
  if type(c) ~= "table" or type(c.ownedPartIds) ~= "table" or type(c.equippedPartIdsBySlot) ~= "table" then return false, "CORRUPT_INVENTORY" end
  if Schema.count(c.ownedPartIds) > 256 or Schema.count(c.equippedPartIdsBySlot) > 16 then return false, "INVENTORY_CAPACITY" end
  for id, owned in c.ownedPartIds do
   if type(id) ~= "string" or #id == 0 or #id > 128 or owned ~= true then return false, "CORRUPT_ENTITLEMENT" end
  end
  for slot, id in c.equippedPartIdsBySlot do
   if type(slot) ~= "string" or #slot == 0 or #slot > 64 or type(id) ~= "string" or c.ownedPartIds[id] ~= true then return false, "UNOWNED_EQUIP" end
  end
  if type(profile.records) ~= "table" or type(profile.records.scoped) ~= "table" or Schema.count(profile.records.scoped) > 64
   or type(profile.daily) ~= "table" or type(profile.daily.claimBuckets) ~= "table"
   or type(profile.receipts) ~= "table" or type(profile.pendingIndex) ~= "table" then return false, "CORRUPT_FIELDS" end
  if Schema.count(profile.pendingIndex) > 64 or Schema.count(profile.receipts) > api.maxReceipts then return false, "RECEIPT_CAPACITY" end
  for id, receipt in profile.receipts do
   if type(id) ~= "string" or #id > 512 or type(receipt) ~= "table" or type(receipt.signature) ~= "string" then return false, "CORRUPT_RECEIPT" end
  end
  -- Numeric records remain compatible with A1/A2; A3 evidence is optional and separate.
  for scope, record in profile.records.scoped do
   if type(scope) ~= "string" or scope:sub(1,10) ~= "record:v1|" or type(record) ~= "table" then return false, "CORRUPT_RECORD" end
   for metric, score in record do
    if (metric ~= "bestLapMilliseconds" and metric ~= "bestRaceBoosts" and metric ~= "officialBoostLifetime")
     or not Schema.integer(score) or (metric == "bestLapMilliseconds" and score == 0) then return false, "CORRUPT_RECORD" end
   end
  end
  if profile.records.metadata~=nil then
   if type(profile.records.metadata)~="table" or Schema.count(profile.records.metadata)>64 then return false,"CORRUPT_RECORD_METADATA" end
   for scope,meta in profile.records.metadata do
    if not profile.records.scoped[scope] or type(meta)~="table" then return false,"CORRUPT_RECORD_METADATA" end
    for metric,evidence in meta do
     if (metric~="lap" and metric~="boost") or type(evidence)~="table" or not Schema.integer(evidence.achievedAt)
      or not Schema.guid(evidence.roundGuid) or type(evidence.verification)~="table"
      or evidence.verification.state~="FINISHED" or evidence.verification.serverAccepted~=true
      or evidence.verification.provenance~="FULL_ROUTE_V1" then return false,"CORRUPT_RECORD_METADATA" end
     local ok,expected=pcall(Schema.recordScope,evidence.trackId,evidence.geometryId,evidence.rulesetId,evidence.category)
     if not ok or expected~=scope then return false,"CORRUPT_RECORD_SCOPE" end
    end
   end
  end
  for scope,entry in profile.pendingIndex do
   if type(entry)~="table" or not profile.records.scoped[scope] or not Schema.integer(entry.boost)
    or (entry.lap~=nil and (not Schema.integer(entry.lap) or entry.lap==0)) then return false,"CORRUPT_INDEX" end
   local ok,expected=pcall(Schema.recordScope,entry.trackId,entry.geometryId,entry.rulesetId,entry.category)
   if not ok or expected~=scope then return false,"CORRUPT_INDEX_SCOPE" end
  end
  if profile.records.races~=nil then
   if type(profile.records.races)~="table" or Schema.count(profile.records.races)>64 then return false,"CORRUPT_RACES" end
   for scope,entry in profile.records.races do
    if type(entry)~="table" or not Schema.raceSnapshotValid(entry.lastRace) then return false,"CORRUPT_RACES" end
    for _,snapshot in {entry.lastRace,entry.bestRace} do
     if not Schema.raceSnapshotValid(snapshot) or snapshot.userId~=profile.userId
      or Schema.raceScope(snapshot.recordScope,snapshot.targetLaps)~=scope then return false,"CORRUPT_RACE_SCOPE" end
    end
    if entry.bestRace and not entry.bestRace.eligible then return false,"INELIGIBLE_BEST_RACE" end
   end
  end
  if profile.pendingRaceIndex~=nil then
   if type(profile.pendingRaceIndex)~="table" or Schema.count(profile.pendingRaceIndex)>64 then return false,"CORRUPT_RACE_INDEX" end
   for scope,entry in profile.pendingRaceIndex do
    local race=profile.records.races and profile.records.races[scope]
    if not race or not race.bestRace or type(entry)~="table" or entry.kind~="RACE"
     or Schema.canonical(entry.snapshot)~=Schema.canonical(race.bestRace) or entry.snapshot.startingBots~=0 then return false,"CORRUPT_RACE_INDEX" end
   end
  end
  if Schema.count(profile.daily.claimBuckets) > 8 then return false, "DAILY_CAPACITY" end
  for day, claims in profile.daily.claimBuckets do
   if type(day) ~= "string" or not day:match("^UTC_DAY:%d+$") or type(claims) ~= "table" then return false, "CORRUPT_DAILY" end
   for kind, claimed in claims do
    if type(kind) ~= "string" or claimed ~= true then return false, "CORRUPT_DAILY" end
   end
  end
  return true, "VALID"
 end
 return table.freeze(api)
end

return table.freeze(Schema)
