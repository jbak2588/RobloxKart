# Private Park combat poses / session lifecycle — 2026-10-30

Owner requests removal of unnecessary Overtake replication. Follow-up confirms
new TIME ATTACK users disappear from Roblox's player list, not just the scene.
Baseline48d6c7c6999e9d79bb30a0c6fa0f80436d3dea6e, fetched equal/clean.

## Changes

Shared demo and per-driver Overtake authority pose Parts are now unparented,
server-retained inert handles. Their CFrame/Position/Size still drive full-rate
combat acquisition, relative sweeps, Smoke/Slick geometry and final integrated
distances. Public metadata Models retain the same names, effect attributes and
10Hz timeline protocol. There is no moving physical proxy in the replicated
tree. Explicitly destroy private handles at rival/session teardown. Local rival
rendering, pace, hit tuning and immutable reward proof are unchanged. Removing
the shared seven proxies also reduces the background workload in TIME ATTACK.

Garage's deferred initial arrival placement previously checked only RaceState
GARAGE, which Park drivers also use. It could set Humanoid.Sit=false and stage an
already-active/pending Park driver. Guard both entry and post-yield placement
against LobbyDriveActive/Pending. This is a verified seating race hazard, **not
proof that it caused an actual player disconnection**.

Add event-only server logs `[ParkSession]`: seated, GO, invalid, finish, save ACK,
actual kart teardown reason/phase/input age/health/seat match/route, and actual
PlayerRemoving with Roblox exitReason and route. No per-frame logs, new remotes,
profile fields, account writes or diagnostic UI. Unknown exit reason cannot
distinguish voluntary quit, connection loss or an app crash; do not label it as
one. Existing .5s input timeout and server ownership policy remain unchanged.

## Disappearance investigation / production read-only evidence

TIME ATTACK has no Kick or Teleport call. Its teardown can remove a kart for
unseating, character removal/death, selection, explicit exit or race routing;
none alone proves the Player left the server. Actual player-list disappearance
requires connection/session exit, app termination, external platform action,
voluntary quit or another route. Exact cause remains unconfirmed until the new
lifecycle events are correlated with a reproduction.

Authenticated Creator Dashboard Error report, exact Place, Last1Day:27 total
errors/warnings, four groups.24 server errors are `Character is not a valid member
of Folder ReplicatedStorage.KDMBotRacers.Bot01`, stack PrototypeWorld102. That is
the separate official bot authority helper accessing a synthetic Folder's
Character, not the Park service. Other groups: one GameEnded teleport failure,
one sound HTTP502, one ROOM_START_REJECTED warning. These aggregated rows have
historical first-seen versions; they do not identify the departing TIME ATTACK
users or establish a current-release root cause. This separate bot guard issue
is recorded, not silently treated as a Park disconnect repair.

The overview's realtime crash rate displayed0.00%, but this aggregate is not a
device-specific exclusion of crashes. No player account or datastore was edited.

The owner's205 KDM_PlayerProgress_v1 keys are205 stored user profiles, not205
finishes. Existing-profile finishes update the same key. A constant key count
therefore cannot establish zero finishers, and a Top5 only shows PBs, not every
completed run. parkTwoLapTrial.completedRuns is cumulative; today's exact count
needs a prior snapshot or timestamped immutable completion/save evidence. No
claim of a production full-profile audit or zero today's finishes is made here.

## Validation

- Production practice combat508 checks, including17 private-pose/protocol checks
  added across existing fixture paths; existing actual Missile/Thunder/Slick/
  Smoke targeting, hit effects, expiry, isolation and final distances retained.
- New delayed-arrival test16 checks: idle placement, pending/COUNTDOWN/RUNNING
  no-unseat and activation during a yield; no false Hub arrival event.
- Existing Park lifecycle23, Overtake235 plus actual GUI and9 challenge-session
  checks; bot acquisition23, mobile safe-hitbox7820, drive policy1186 and Return
  Lobby27 checks pass.
- Native ordinary Overtake startup then runtime-only18s module observation:
  1080 updates,14 private poses,9711 moving pose samples, presentation timeline
  present. Ordinary client sees14 metadata Models with **zero proxy BaseParts**
  and all seven local Overtake rivals. Prior native run had30,268 replicated-tree
  pose notifications/40s. Removed proxy transform replication is structural;
  these are not packet counts or a measured mobile bandwidth percentage gain.
- Full261-process regression:241PASS, same20 historical failures, zero new
  failures. No FULL_SUITE_PASS claim. Baseline failure list compared exactly.
- Integrity886 checks; four exact source hashes and mutation/deletion rejection;
  all old manifest fields and historical artifacts unchanged. Rojo build/diff
  check pass. No real multi-human/mobile disconnect acceptance claimed.

Runtime probes discarded on Stop. Trees, human physics, ownership, course,
controls, balances and reward eligibility preserved. Continuing owner release
workflow uses exact Universe10768420544 / Place127925465904803; no server restart.

Release receipt: source commit7905523 pushed. Native backup238 source files
match candidate, all three release flags true; SHA256
5a226dc182107a78c0051a3600db8104a9ddc0aa76e0a6b1c5b3abd6eff987fc.
Native Publish confirmed PV1287; independent Creator Dashboard published-only
history lists1287 then1285. No server restart. Existing servers retain old code.
Proof: C:/Users/OWNER/AppData/Local/Temp/kdm-pv1287-published.png.
