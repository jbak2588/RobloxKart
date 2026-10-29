# Park Hub world rankings — implementation contract, 2026-10-29

## Approval and scope

Owner approved implementation of the recommended left-building / adjacent-lot
layout. Owner explicitly confirmed **lifetime earned K$**, not wallet balance,
and **valid official races with 2–4 starting human racers and no bots**, merged
per track and separate from Solo. No Roblox Publish approval was given for this
initial task. The subsequent owner screenshot review explicitly authorizes
12% enlargement, 45-degree standalone placement, commit/push and official Publish.
Initial baseline local/origin `prototype/kart-physics`:
`b429106c3de210c3f204187d2a31726c3f67f660`.

## Visible result

| Board | Default view | Position relative to RookieParkOrigin |
| --- | --- | --- |
| Left building upper facade | Rookie Racing Park Solo best **one lap**, Top 5 | (71, 28, -27.7), 42.56 × 21.28 |
| Adjacent building corner, yaw45° | Base Circuit multiplayer best lap, Top 5 | (105.7, 12, -38), 28 × 16 |
| Continuation of angled pair, yaw45° | Lifetime K$ earned, Top 5 | (126.913203, 12, -59.213203), 28 × 16 |

The standalone boards continue diagonally from the building corner, with a
two-stud gap between their faces' adjacent edges. Both face Spawn at45° yaw;
the legs, top rails and approach anchors follow the same rotation. The original
rock at(150,3.7,-60) remains untouched and clear of both cash-board legs. The wall
board's width and height are each increased12%, staying within the upper facade.
No scenery is removed and the boards do not enter the pit lane. All13 new parts
are anchored, non-colliding, non-touching
and non-queryable. Three approach prompts open a DeviceSafeInsets detail panel:
Solo / Multiplayer / K$ tabs, track cycling, Top 50, own score and own rank if
present in that loaded page. Outside Top 50, no fabricated global rank is shown.
No panel opens automatically; it closes when driving or race launch begins.
Minimum button targets are 44 pixels. No forest/start-line billboard was added.

## Record contract

| Category | Source and admission |
| --- | --- |
| Park Solo | `parkTimeTrial.bestMilliseconds`, existing accepted one-lap PB, minimum 10 seconds; not the two-lap run total |
| Official Solo | Eligible, server-accepted, finalized FINISHED snapshot; SOLO_1H_0B; one starting human and zero bots |
| Official multiplayer | Same full-finish evidence; HUMAN_2H_0B / 3H / 4H with matching starting counts and zero bots |
| Money | `wallet.lifetimeEarned`, descending, including existing Park/race/bonus earnings; purchases do not subtract from this rank |

Current track identity/geometry/ruleset/lap count must match: Green and Desert
three laps; Base, Metro and Hard two. Track02 is excluded. Every lap must be a
positive integer and the saved total must agree with lap sum within the existing
millisecond rounding tolerance. Another user's evidence, invalid finishes, bots,
old lap counts and mixed categories cannot contribute. Best individual lap is
selected from eligible complete-race snapshots, not the full race duration.

**Historical coverage is deliberately conservative.** `records.races.lastRace`
and `bestRace` provide complete eligibility evidence. Older standalone lap PBs
without a surviving eligible full-race snapshot are not imported automatically.
Existing users are indexed when their confirmed profile next loads or updates;
there was no production-wide profile scan/migration. New observed valid snapshots
accumulate the faster lap through atomic min. Exact ties use the order of the
loaded page, with user-ID ordering inside that page; no cross-page tie rank claim.

## Storage and security

Seven new source files provide independent server/client bootstraps, policy,
pure queue/cache runtime, world builder, service and detail controller. Existing
driving, initialization, account, purchase, reward and geometry sources are
unchanged. Original N1/N2 fixtures and current-release manifest are unchanged.

`KDM_HubRanks_v1` is a separate **derived** OrderedDataStore, with scopes per
mode/track/rules/laps and a separate EARNED_R1 scope. Atomic UpdateAsync uses min
for time and max for lifetime earnings; no increments or blind overwrites.
The account store `KDM_PlayerProgress_v1` is only read using uncached GetAsync
after existing server profile qualification/revision signals and schema validation.
It is never initialized or written by this feature. A confirmed deleted profile
seen by the index worker queues removal from the derived stores. This is not a
new global account-deletion sweep or an offline-user deletion service.

One pending profile and one index write are serviced per worker tick; retries use
bounded exponential backoff. Sorted reads are globally spaced 12 seconds per
server, cached for approximately 60 seconds, and preserve stale rows on errors.
At most Top 50 is returned. Names resolve asynchronously with a bounded cache.
An interrupted index write is recoverable on subsequent profile loading; the
account remains the source of truth. Shutdown drains pending writes for up to
five seconds, without promising durability of every derived write on a crash.

Remote queries accept only known board IDs, return cache only, enforce Hub
GARAGE/not-driving/not-launch state and rate-limit each user to one second.
Clients cannot submit a score, another account ID, store name or scope.

Live indexing is restricted to Universe **10768420544**, Place
**127925465904803**, public HUB or Roblox-reserved RACE (owner ID 0).
QA, Studio, mixed IDs and paid private servers cannot access live ranking data.
Studio uses memory only and visibly says **STUDIO PREVIEW — NO LIVE DATA**.

## Verification

- Dedicated policy/runtime test: **50 checks PASS**, including deliberate invalid
  scores, bot/invalid/mismatched evidence, stale/out-of-order updates, retry,
  deletion, min/max sorting, fair queued reads, disabled-policy and environment
  rejection paths.
- Full regression: **251 tests, 231 PASS, 20 historical FAIL**. Failure names
  exactly match the preceding Park collision release; **zero new failing tests**.
  This is not FULL_SUITE_PASS. See the companion results JSON and the unchanged
  historical list in `park_driver_collision_results_20261028.json`.
- Current-release independent manifest audit: **133 entries PASS**; existing
  source integrity test PASS. Camera/GAS/Touch/Ownership/economy regression tests
  remain within the passing current-release set.
- Rojo build and `git diff --check` PASS.
- Native ordinary startup in QA Studio Universe 10772198697 / Place
  106553302629620 created the three boards, three prompts, query remote and GUI.
  Exact native enum budget names were checked. Real prompt opened the detail
  panel; actual query produced READY for empty multiplayer/money caches,
  INVALID_BOARD and RATE_LIMITED for rejected requests. Driving-state injection
  closed the panel and returned NOT_IN_LOBBY. Injection was Play-only and discarded.
- Native 13-part visual/collision audit PASS. iPhone 17 Pro and small iPhone 7
  landscape simulator layouts fit the viewport. A Play-only 50-row demo verified
  scrolling canvas/own-score layout, then was discarded; no sample rows are in
  source or saved data. Final smoke used the original real cache handler.
- Native mouse/gamepad input automation did not activate tab buttons reliably
  under the simulator; **real-device tab/touch/scroll acceptance remains pending**.
  Prompt opening, data response and layout checks do not substitute for it.
- Pre-existing QA Studio asset permission / PlayerPreferences API-disabled
  messages remain separate; Studio API access was not enabled.

## Review, deployment and rollback

QA Studio retains the seven new sources in Edit mode for ordinary Play preview;
temporary fixtures/injected state are discarded and device simulation stopped.
The initial implementation made no production Studio edit, live profile migration,
Roblox Publish, access-setting
change or server restart was performed. Production-wide sorted persistence and
real simultaneous users remain unverified until an approved deployment/test.

Revert this task's scoped commit to remove the two bootstraps and modules/UI.
Do not reset the branch or revert unrelated approved releases. Derived ranking
stores can remain inert; the account store and original records are unaffected.
The historical fixtures must remain intact.

## Owner-approved official release follow-up

- Follow-up baseline: `5384f6cd7e6a81bdcb165538f58ffee5b15fe437`.
- Native QA validates exact12% dimensions, both45° rotations, positive Spawn
  facing dots(0.6911 /0.5670), rotated approach anchors,13 visual-only parts,
  and no rock/leg overlap. Overview capture confirms the joined corner placement.
- Full251-test rerun:231 PASS /20 same historical FAIL; new failures0.
  Independent133-entry audit, Rojo build and diff checks PASS.
- Official Studio verified Universe10768420544 / Place127925465904803;
  loaded version1240. All222 existing project sources match local before adding
  the seven new leaderboard scripts. All three Hub/mobile/GAS release flags true.
- Before mutation, native File > Download a Copy saved
  `C:/Users/OWNER/AppData/Local/Temp/KDM-official-before-leaderboards-20261029-v1240.rbxl`.
  Studio output confirms download completion; source-hash inventory retained.
- Loaded version1240 is a baseline, not a new publication receipt. The Dashboard's
  initial permission/loading screen resolved once its version table loaded.

### Verified official publication receipt

- **PRODUCTION_PUBLISHED: Place version1242**, October29,2026,2:24PM
  (Dashboard local display). Verified in **Show published only** with the
  Published Version checkmark. The preceding published version1239 remains
  recoverable;1240/1241 saved revisions are distinct from published versions.
- Target Universe10768420544 / Place127925465904803. Source/layout commit
  `72f5a598d040d7651134d3776fe46ce9ea72602a` was pushed before publication.
- Post-Publish238-script inventory matches the pre-Publish candidate exactly:
  no changed existing scripts,229/229 local project sources match. All three
  Workspace Hub/mobile/GAS flags remain true. QA Play stopped; no QA Publish,
  access-setting mutation or server restart.
- Screenshot proof:
  `C:/Users/OWNER/AppData/Local/Temp/KDM-leaderboards-published-v1242-20261029.png`.
- [Official published version history](https://create.roblox.com/dashboard/creations/experiences/10768420544/places/127925465904803/version-history)
- [Official experience](https://www.roblox.com/games/127925465904803/)
- Real-device touch/scroll and production sorted-index persistence still require
  normal player acceptance; publication does not establish those outcomes.
- Operational rollback: restore published1239 in the same official Place and
  publish from Studio, or use the exact pre-change1240 local backup. Revert the
  two leaderboard source commits for Git rollback, preserving unrelated releases.
