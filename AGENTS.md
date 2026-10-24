# AGENTS.md — Kart Drift Masters

Read this before editing the project.

## Current race items / launch override — 2026-10-19

The user-approved six-item flow supersedes historical four-slot/tactical-prep
requirements below. Race loadouts contain Slick / Missile / Smoke / Thunder
on row one and Nitro / Shield on row two. Desktop keys 1–6 select those slots;
Q uses the selected item. Mobile taps use the exact item directly.
There is no tactical-selection UI, item-prep countdown, or item-ready start gate.
Host Start immediately begins the normal race countdown. Play Together waits
6 seconds for initial arrivals, then auto-starts with at least one human, subject
to authoritative cross-server reservation/admission checks. Explicit invitations
retain response waiting and the host's start decision.
The existing non-final-lap empty-only refill to 1 applies to all five non-Nitro
items. Nitro keeps the five-successful-BOOST repeatable award/pending contract.
Physics, combat effect tuning, and race capacity are unchanged by this override.

## Server kart authority principle — accepted on mobile 2026-10-21

Published PV931 (`0e50d51`) fixes recurring motion stalls by retaining **manual
server network ownership after human seating**. Creating the kart with
`SetNetworkOwner(nil)` alone is insufficient: SeatWeld can join the automatic
character assembly afterward. PrototypeWorld reasserts server ownership in a
deferred Occupant callback after verifying the current owner, live kart/chassis
and both sides of the Seat/Humanoid relationship. Keep this lifecycle guard on
every seating; do not replace it with automatic/client ownership or repeated
per-frame ownership writes while the server commands kart velocities.

The defect reproduced with one human + bot: approximately three-second ownership
pulses and 0.17–0.20-second client position stalls despite normal rendering FPS.
After repair, matched local 40-second bot and bot-free solo runs had zero motion
stalls or client ownership pulses. This timing is diagnostic evidence, not a
universal Roblox handoff interval or a guarantee of zero network jitter.

**User-confirmed published mobile acceptance:** driving is now natural and very
smooth, described as "like watching HD video." Preserve this accepted feel as a
server-driving invariant. Do not trade it away when changing seating, recovery,
respawn, kart creation, bot integration or network ownership. Physics tuning,
items and economy were not changed by this repair. See
[the investigation](docs/testing/race_network_ownership_hitch_review.md).

**Open follow-up, 2026-10-21:** the user reports renewed periodic hitches after
approximately 5–15 human-plus-bot Rematches, cleared by returning to the Lobby
and launching another race. The earlier 40-second captures and four mocked
reseatings do not establish long-session Rematch acceptance. Preserve the PV931
authority repair; do not declare this recurrence resolved or make speculative
camera/physics changes without a correlated capture. See
[the follow-up](docs/testing/rematch_hitch_followup.md).

## Mission

Commercial mobile-first Roblox arcade kart racing game.

Player-facing product name: Kart Drift Masters.

RobloxKart remains the internal project and repository name.

Initial commercial milestone:

approximately USD 500/month.

Optimize for:

1. immediate fun
2. mobile usability
3. short replay loop
4. skillful Drift
5. strategic race items
6. multiplayer
7. cosmetic / collection monetization

Do not optimize for technical novelty.

## Repository

Repo:

jbak2588/RobloxKart

Development branch:

prototype/kart-physics

Before every task, fetch origin and verify local HEAD equals
`origin/prototype/kart-physics`. The remote branch HEAD is the review baseline.

## Git Hard Rules

Do NOT:

- modify main
- merge main
- push main
- force push
- rebase
- git reset --hard
- git restore .
- git clean -fd
- blindly git add .
- publish/deploy Roblox without explicit user approval

Always inspect exact changes and selectively stage files.

After a scoped task passes validation, commit and push to
`origin/prototype/kart-physics` by default, then verify matching local and remote
HEADs. Main merge/push and Roblox Publish require explicit user approval.
Keep unrelated `.vscode/settings.json` out of commits.

## C2-A Status

Historical C2-A fixed-location Nitro Reward Challenge is DEFERRED and was not
approved for commit. This is distinct from implemented R7-A1-R4 Repeatable Nitro;
do not treat Drift reward cycles as deferred. The earlier
local experimental files have been removed; no C2-A cleanup is currently required.
Inspect git status/diff and preserve unrelated changes before development.

## Approved Current Flow

**CURRENT IMPLEMENTED FLOW (R7-H1 local candidate):** Compact Hub →
Kart / Track transitional overlay → Ready / Room →
Item Prep (public waiting room) / Countdown → RACING → FINISHING (ROLL → PRESENT)
→ FINISHED / Results → Rematch or return to Garage. Off-track DNF is separate.
Driver Select UI is removed in the H1 candidate. Roblox Avatar appearance is
preserved; legacy driverId / DriverCatalog remain protocol compatibility only.
Hub uses RaceState=GARAGE, native movement/respawn and initially closed overlay.
Studio and mobile Hub acceptance remain NOT VERIFIED; no H1 Publish.
Do not re-add a Driving License flow.

**APPROVED NEXT PRODUCT FLOW (not implemented):** Hub → Kart Garage / Track Board /
Quick Race → Room or Solo Entry → Item Prep / Race → Results → Rematch or Return Hub.

### Current Tracks

| Catalog ID | Name | Race mode | Racers | Laps |
| --- | --- | --- | --- | --- |
| Track01 | Practice Circuit | SOLO_PRACTICE | 1 | 1 |
| Track01Race | Base Circuit | PUBLIC_RACE | 1–4 | 2 |
| Track02 | Prototype Circuit V2 — Legacy V2 | PUBLIC_RACE | 1–4 | 2 |
| Track03 | KDM Hard Circuit | PUBLIC_RACE | 1–4 | 2 |

Track03 itself is the public track; do not create a separate Track03Race.
Legacy V2 remains preserved as Track02. Room / Invite / Queue / Launch are
track-aware; retain selected-track identity throughout routing and Rematch.

## Current R7-A1-R4 Contract and Acceptance

These current rules take precedence over historical milestone descriptions below.
At the R7-H0 documentation checkpoint, R3B / R3C / R4 production changes are
local and uncommitted; H0 records
accepted working-tree behavior, not a new Git or Publish checkpoint.

- Automated checkpoint: **53/53 PASS**; Touch, Joystick, Track03 4P controller
  simulation, Room/Reserved routing, Repeatable Nitro, Rojo and diff checks PASS.
  These are recorded R4 results; H0 documentation editing does not rerun the suite.
- User mobile acceptance supplied in R7-H0: **Repeatable Nitro PASS**, repeated
  five-BOOST cycles PASS, held 2 PASS, pending 1 PASS, accepted Nitro consume →
  pending automatic refill PASS, and Track03 solo/mobile driving PASS.
- **ACTUAL 4 HUMAN RACERS: NOT YET VERIFIED.** Controller simulation and solo
  mobile acceptance do not establish published four-human acceptance. This newer
  user acceptance supersedes the earlier R4 report's pending Nitro/solo status.

**H1 local candidate:** Compact Hub Foundation + Roblox Avatar = Driver stage 1.
After Studio/mobile Hub acceptance: H2 Garage, H3 Track Board and H4 runtime
acceptance. H0 architectural decisions remain preserved; no capacity expansion.

### Repeatable Nitro — single owner: RaceLoadout

Count five actual successful Mini Boost outcomes (`BOOST`), not charged/failed
Drifts, for each Nitro +1 cycle. Awards per race are unlimited; held Nitro max is
2 and pending bonus max is 1. Nitro must be an active loadout slot.

At held 2 plus 5/5, latch pending=true and keep progress=5. Additional BOOSTs
freeze progress while pending; no second pending award or hidden charge. Accepted
Nitro activation consumes 2→1, then settles pending 1→2 atomically and resets
progress to 0/5. Rejected activation neither consumes nor settles pending.

RaceLoadout alone owns `bonusProgress`, `bonusPending`, `bonusAwardCount` and
`bonusEverAwarded`; the old bonusClaimed latch and duplicate controller counters
are removed. `DriftBonusNitroAwarded` is an ever-awarded compatibility mirror only,
never a gameplay gate. Same-race fall recovery and combat interruption preserve
accumulated reward state. Recovery itself neither refills nor grants a reward.
New race / Countdown / Rematch / Garage / new session / clear / teardown reset
reward state through existing lifecycle and refill policy.

## KDM Track Visual & Safety Standard v1

Mandatory for **ALL NEW / REWORKED KDM TRACKS**; other existing tracks receive a
retrofit only in a separately approved task. Preserve accepted Track03 geometry,
kerbs, barriers, SafetyGround and minimap in H0.

- Continuous kerbs on BOTH road edges. Standard sections use single kerbs;
  sharp sustained corners use outward double kerbs without RoadWidth incursion.
- Kerb/marking visuals: Anchored=true, CanCollide=false, CanTouch=false,
  CanQuery=false, CastShadow=false.
- Order: ROAD → KERB → DRIFT SAFETY SHOULDER → BARRIER/TRIGGER. Barriers are
  never road boundaries. Both visible barriers and collision triggers respect
  minimum shoulder clearance: normal ≥12 studs; major Drift ≥16; Drift exit
  ≥18 or omit the trigger.
- Arrows mean RACE FORWARD, following the actual course centerline tangent:
  arrow-forward dot tangent ≥0.95, zero reverse/lateral arrows. Remove a marker
  when its direction cannot be guaranteed.
- Each two-lane station has one cue at each lane center, never over the center
  divider. Accepted Track03 example: **47 stations / 94 lane-centered clusters**.

See [the detailed standard](docs/audits/kdm_track_visual_safety_standard_v1.md).

## Next Product Architecture — Compact Lobby

Approved next architecture; **not implemented by R7-H0**. Direction:
**COMPACT / FAST / SOCIAL / RACE-FIRST**. Use a small racing plaza, paddock or
stadium-entry hub. Driving Empire supplies product lessons only: Roblox Avatar
presence, visible other players, physical Garage/race access, world interaction
plus UI shortcuts, social presence and separate reserved races. Do not copy its
assets, style, branding or layout. No large Open World, long traversal, vehicle
RP city or large-world exploration.

Hub areas: SPAWN PLAZA, GARAGE, TRACK / RACE BOARD, QUICK RACE, PODIUM / TROPHY,
EVENT BOARD; future SHOP / COSMETICS. Target core access within approximately
5–10 seconds of walking, without forcing walking. Keep QUICK RACE / GARAGE /
TRACK UI shortcuts. Social goals are seeing avatars, showing karts and entering
races, with future podium/event/cosmetic access.

Conceptual layout only:

```text
                  PODIUM
GARAGE         KDM PLAZA         TRACK BOARD
                QUICK RACE
          EVENT BOARD / FUTURE SHOP
```

Exact Hub dimensions, building models and Spawn coordinates are R7-H1 design
work, not approved final geometry.

### Roblox Avatar = Driver — staged migration

H1 local candidate removes Driver Select UI; the player's Roblox Avatar becomes the
driver. Do not build a separate Character Creator or prioritize identity-override
KDM Driver sales. Migration order:

1. Remove Driver Select UI first; keep SelectedDriverId or equivalent internal
   payload with a safe default for compatibility.
2. Stop DriverAppearance body recolor, hat hiding and other forced themes;
   preserve the user's Roblox Avatar.
3. After runtime, payload and tests stabilize, gradually remove DriverCatalog
   dependencies. Data/protocol cleanup follows UI removal.

Prioritize Kart, skin, wheel, Drift trail, victory animation, Garage cosmetic and
emote options. A future racing helmet may be additive, subject to separate review.

### Kart Garage and Track Board

Retain Kart Select: **2 chassis families / 11 color choices**. Sprint V1 has
Red / White / Blue / Yellow (4); KDM V2 has Cyan / Red / White / Yellow /
Metal Blue / Metal Pink / Black (7). Move selection into the Lobby Garage with
actual 3D karts, turntable, left/right selection and existing validated
horizontal touch/mouse orbit behavior reused where possible.

**Current preview:** 2D top-down course map.
**Future primary 3D Track Preview:** miniature TRACK MODEL / DIORAMA with
oblique/side perspective. Horizontal swipe/drag and/or LEFT / RIGHT buttons
rotate the track around its vertical axis. Show name, race mode, racer capacity,
lap count, difficulty/category when available and Start / Finish. Keep 2D maps
as optional secondary selection maps or race minimaps. The future primary
selection visual must be the 3D diorama. Derive simplified Hard Circuit previews
from actual production geometry; do not redesign Track03 for a preview.

Retain the track-aware Room Browser: Track Board → Public Track → Room Browser
overlay → Room / Queue / Invite; Solo Track → Start Solo. Preserve room, queue,
invite, reserved race server, RaceSession and Rematch architecture. Migration
changes pre-race presentation/navigation. Fullscreen 4/4 Ready summary is a
future compact/removal candidate; Kart + Track confirmation or direct RACE /
JOIN ROOM entry remains an implementation decision.

Quick Race must reach a race path in 1–2 actions. Automatic track/match policy
is undecided; do not invent or hardcode it. Shop layout, Podium rewards, XP and
persistent Inventory remain undecided/deferred.

### Multiplayer roadmap: 4P → 6P → 8P

Stabilize 4P and obtain actual four-human runtime acceptance before 6P, then 8P.
Keep capacity expansion separate from Lobby implementation.

| R4 audit category | Capacity extension work |
| --- | --- |
| READY foundation | Room directory, Invite, Queue, reserved arrival, RaceSession, Ranking |
| NEEDS CHANGE | GridSlots, TrackCatalog MaxPlayers, HUD rows, Result UI, Bot fill policy |
| RUNTIME TEST | Thunder target load, Smoke/Slick hazard load, network ownership, mobile performance |

Use catalog MaxPlayers and available GridSlots as capacity sources of truth;
do not add another hardcoded four-racer limit. Current explicit invited Bot is
Base-only; no automatic Bot fill on Base or Track03. Decide future fill policy
separately before capacity extension.

## Park two-lap results / Replay reward override — 2026-10-24

This newer owner request supersedes the one-lap Park contract below. A Park attempt now requires **two ordered six-checkpoint laps**, with no finish/reward after lap one. The server resets route progress at the first finish crossing and owns the total time. Award K$5,000 for the first completed two-lap attempt, then K$10,000 (X2), K$15,000 (X3), etc. for consecutive completed Replay attempts in the same drive visit. Return Lobby/new drive resets to X1; invalid attempts reset the chain. Saving/ACK failure never blocks Replay or changes the frozen earlier receipt. Replicated reward amount/multiplier are display-only; no remote accepts reward proof or amount. Keep read-back confirmation before REWARD EARNED.

Preserve historical single-lap PB and completed-lap data in parkTimeTrial; store the separate two-lap total PB/run count in additive parkTwoLapTrial. A version-2 server proof requires two laps / twelve ordered checkpoints; idempotent receipt retry cannot duplicate the multiplier reward. Official race economy, physics, GO boost and network authority remain unchanged.

Park shares the existing speed-trail renderer, FINISH banner and winner-style finish presentation. Successful Park/official finishes use FINISH! with a thick black outline, the Park-style translucent blue result panel/white border/cyan buttons, and two bounded native celebration emitters plus seated waving until Replay/Rematch/Return Lobby or teardown. Preserve official multiplayer standings, readiness/waiting and action authority. Mobile/hardware acceptance must be reported separately from route and GUI simulation.

## Rookie Racing Park solo trial override - 2026-10-23

RookieLoop TEST DRIVE now enters an individual timed one-lap trial. Use the
main-road 2-column / 4-row grid (8 slots), allocated sequentially; Pit brackets
are decoration only. First entry and Replay use a server-owned 3/2/1/GO and the
existing 2-second Mini Boost launch, with no Nitro consumption or Drift reward
credit. Official RACE launch and physics are outside this Park-only change.

The server uses Figure-8 RaceRouteProgress for six ordered checkpoints, including
provisional off-road progress committed on re-entry. Rejected discontinuities
retain route anchors instead of permanently invalidating an ordinary off-track
lap. After a wide excursion, Park reacquires route anchors only after 0.5 seconds
of continuous on-road samples; reacquisition grants no checkpoint or finish.
The shared CheckpointGuidanceController owns the original checkpoint/finish
flags and checker markers. A missed gate shows the next required checkpoint
and grants no finish reward. The server owns lap timing. Each accepted
lap atomically saves the personal best and K$5,000 using a unique idempotent
Park lap receipt in KDM_PlayerProgress_v1. Never claim a saved reward before
read-back confirmation. Replay is independent from save confirmation: retry the
same old receipt in the background and immediately reset into the next countdown,
even when saving fails or is still in flight. Stale saves cannot replace new lap
HUD state. Finish uses the official 2.4-second roll and 0.9-second
front-camera transition, stops the engine, then shows the existing new Park
time/PB/reward panel with Replay / Return Lobby. SOLO LAP uses the topbar center;
the transparent white Return Lobby button matches wallet width. Global leaderboard
is deferred to a later task. Studio economy uses the existing memory adapter;
Studio verification does not establish live DataStore or mobile acceptance.

## Rookie Park traffic and automatic GO launch - 2026-10-23

Park traffic is a server-shared fleet of seven distinct KDM V2 colors, joining at
0/30/60/90/120/150/180 seconds while the Hub has an audience. It never creates
seven extra bots per user or changes official race capacity. Each starts just
ahead of the personal start grid, ramps from rest using Mini Boost and runs at
70 studs/s even before any human selects TEST DRIVE. Human Park normal speed
remains 80. Existing turn drift, item hit caps and audience teardown remain.
Park bot smoke uses the lighter RACE emitter; beyond 300 studs visual pose work
is capped at 10 Hz, smoke beyond 160 and boost flame beyond 300 are suppressed.

Every official track's authoritative GO adapter starts the existing 2-second
Mini Boost. Launch automatically accelerates, Brake cancels, and existing
seating/network ownership and boost safety limits apply. Launch must not consume
Nitro or emit a successful Drift outcome/count toward repeatable Nitro rewards.

## Multiplayer Rematch rewards / Lobby planting update — 2026-10-24

Owner-approved: remove only the third Lobby verge row (15 trees at Park-local
z=145). Current Park total is 243 trees, with the first two staggered rows and
15+15 Lobby low plants retained. This narrowly supersedes the historical
258-tree preservation direction; no other grove reduction is approved.

For official races starting with at least two humans, each qualified finisher's
explicit consecutive Rematch advances their own rank-prize multiplier X1 -> X2
-> X3 -> X4, in the same server/session and track. New entrants, DNF/invalid
completion, departure/Lobby/rejoin, different track or a solo GO start at X1.
Freeze continuation at authoritative GO and its reward proof at completion;
late save responses cannot change a newer result. Multiply only existing human
rank base (3500/2500/2000/1500). PB and first-finish event bonuses remain separate
and unmultiplied; DNF consolation is unchanged. Save the multiplier and bonus
inside the existing idempotent official receipt with atomic wallet update and
readback confirmation. Never advertise payment as earned before confirmation.
Next Rematch previews show ONLY the multiplier, never an estimated cash amount;
the next finish rank is unknown. Actual confirmed payout is shown after each
race. Park's existing Replay amount preview and reward economy are unchanged.

## Tree planting principles — owner direction 2026-10-24

- Plant dense groves in a staggered / zigzag arrangement, with space for another tree between neighboring planting positions. Avoid continuous aligned rows and unnecessarily overlapping canopies.
- Even when reusing the same asset, vary its scale and Y rotation so nearby copies do not have matching size and direction.
- Preserve the intended forest-track atmosphere. Do not translate this qualitative direction into an unapproved canopy-width formula or a drastic tree-count reduction.
- The owner explicitly rejected the 50-tree reinterpretation and directed restoration of the existing **258-tree Park layout**. Retain that layout and the 15+15 low plants around the two Lobby trees. No dark CityBroadleaf or forest understory carpet is to be restored. Any further large density/count reduction needs separate owner direction.
- Later owner clarification on 2026-10-24 authorizes **redistributing 45 existing trees** from the circled northeast/left groves to the empty Lobby-front road verges in three offset rows, keeping **258 total**. The northeast decorative tower moves to the open outer-corner verge and faces the road. This is relocation, not a density/count reduction.
- Keep trees grounded, anchored, noncolliding, non-touching, non-querying and without cast shadows, outside road/recovery/pedestrian clearances.

Owner mobile report on 2026-10-24: heating has decreased after the earlier forest thinning / dark-tree removal. Record this as user-observed improvement, not measured temperature/FPS or a guarantee of zero heat. Preserve the accepted forest appearance and lower vegetation load.

## Park arrival and walk-up exhibits - 2026-10-24

Park Hub arrivals and Return Lobby use the pedestrian stem at Park-local (0,-36),
facing -Z toward the Park. RookieParkOrigin preserves the original course datum;
never recompute the track from the relocated HubSpawn. The one-shot arrival
camera hands back to Roblox native walking/orbit immediately.

Seven existing KDM V2 static exhibits occupy the T-crossbar at z=-61 and x=-48
through +48 with 16-stud spacing. Native nearby PLAY prompts reuse the validated
temporary preview Drive request and personal grid/countdown/boost launch. They
do not change persisted Garage selection or create another driving system.
Legacy non-Park indoor displays retain their layout and TEST DRIVE prompts.

## Off-road Boost / Nitro and AUDIO-B1 override — 2026-10-24

Owner direction supersedes the historical off-track Nitro cancellation rule:
an active Mini Boost or Nitro retains its original expiry and exhaust flame when
leaving the road. Apply KartConfig.OFF_TRACK_BOOST_SPEED_MULTIPLIER (0.80) to
its normal target: Mini Boost 100 -> 80 and current Nitro 120 -> 96 studs/s.
Returning to the road before expiry restores the full target through existing
acceleration; it never restarts or extends the timer. Permit authoritative Nitro
activation on grass/off-road with normal charge consumption. Preserve actual
barrier/crash, combat, Brake, seat/input/lifecycle, island/fall recovery and race
DNF protections and the existing route/checkpoint validation. Off-road travel
cannot earn Drift charge.
Normal non-boosted off-track speed, race capacity and network ownership stay unchanged.

Owner acceptance: off-road speed and exhaust flame behavior PASS. Preserve it.
The first AUDIO-B1 low-volume loop candidate was rejected as inaudible/too quiet.
Owner audio correction: Mini Boost uses template NitroStartPlayer 15548492905
and NitroLoopPlayer 15548491198 at 80% of source volumes: start
2.7980001*.80, sustain .800000012*.80. Sustain follows the existing
BoostFlameEnvelope through the active boost and natural residual flame fade;
connected boosts reuse the same loop. Preserve KDM Nitro 83211426606907 at .75.
Missile launch has its own COMBAT.MissileLaunch config with that original KDM
asset at .75; never bind it to BOOST_START or boost volume again. Keep bounded
instances and lifecycle cleanup; do not change the accepted speed/flame physics.
Studio playback is not acoustic, published permission or iPhone acceptance.
Owner accepted the completed work and explicitly authorized Commit / Push on
2026-10-24. Roblox Publish remains outside that approval.

## Lap cues and seated pedal pose — owner direction 2026-10-24

Park's first accepted lap in its two-lap run shows the same gold FINAL LAP notice
and three-beep pattern as official races. Re-arm per Replay deadline/generation;
reset/exit cancels pending cues. All accepted official and Park checkpoint counter
advances play the existing countdown asset once at .45 volume. Initial mirrors,
duplicates, counter resets, staging and missed gates are silent.

KDMDriverPedalController owns client-only seated leg transforms for R15 and R6,
KDM V2 and Sprint V1, including front-camera finish/results. Keep the accepted
Seat position, SeatWeld, avatar meshes/transparency, hand grip/wave, kart/root
frames, velocity and server network ownership untouched. Restore original joint
transforms on seat/character loss, death, departure or leaving driving state.
Do not fabricate replacement legs or upload a separate driver animation.
Owner refinement: straight forward legs (hip 90 degrees, knee/ankle zero),
so soles face the front camera. Mini Boost repeats its approved start cue every
.30 seconds while climbing to 100 studs/s (99.5 tolerance), then latches repeats
off until the next activation. Nitro onset and sustained flame-loop remain intact.

## Driving Invariants

Owner override — 2026-10-23: mobile Buttons mode defaults to automatic forward
throttle while actively driving. Left/Right steering is on the left; Drift and
Brake/Reverse are on the right. Forward and Auto toggle buttons are hidden.
Brake/Reverse overrides forward; release resumes forward. Maximum reverse speed
is now 50 studs/s in RACE and HUB. Keyboard control and the developer Joystick
rollback retain their input behavior. Preserve focus/menu/seat/state safety gates
and manual server network ownership. Rematch hitch investigation remains separate.

Owner override — 2026-10-22: HUB RookieLoop (`ROOKIE_LOOP_V1`) normal speed is
80 studs/s through `LobbyDrivePolicy.ParkForward`. Official RACE normal speed
remains 70; legacy HUB, reverse, acceleration, Drift, Mini Boost and Nitro stay
unchanged. Do not raise global KartConfig to implement the PARK override.

Garage kart selection persistence is now approved for ordinary users in the
exact production public HUB, using the existing KDM_PlayerProgress_v1 schema.
Joining is read-only; the first explicit valid Garage selection may create the
profile. Retain Studio/RACE/foreign-place exclusions and the canary-only rollback.

Normal:
70

Off-track:
50

Reverse:
50

Mini Boost:
100
2.0 sec

Mini Boost acceleration:
65

Continuous off-track DNF timeout:
15 sec

Nitro:
100
3 sec

Nitro acceleration:
75

Nitro exit deceleration:
15

Do not change these without explicit user approval.

Nitro must:

- ramp smoothly
- decay smoothly
- never stack above 100
- yield to Brake
- cancel on off-track
- cancel on Barrier

Mobile must use the SAME Kart physics.

## RaceLoadout

Default Race / Rematch (M4-A3 may replace one tactical item with Smoke):

Nitro = 1
Slick = 1
Shield = 1
Missile = 1
Smoke = 0

Temporary state:

RaceLoadout

Persistent future ownership:

Inventory

Do not mix them.

PC:

1 Nitro
2 Slick
3 Shield
4 Missile
Q Use

M4-A2 foundation: Catalog metadata and active RaceLoadout are separate. Catalog size may
exceed four; `RaceItemSlots.RACE_ITEM_SLOT_COUNT = 4` fixes active slot count.
Production slot order remains Nitro / Slick / Shield / Missile with 1/1/1/1.
RaceLoadout owns slots, temporary counts and selection. Server-only prepare
validates exactly four unique implemented catalog IDs with initial/max charges;
never accept arbitrary client slot tables. M4-A3 allows only validated three-ID
tactical choices below. Publish RaceItemSlot1..4; HUD cells and
desktop 1/2/3/4 resolve those slots, mobile taps directly use the displayed ID.
Selection/use must validate membership in this player's server slots, implemented
status and positive charge; only successful item activation consumes. Incoming
Shield emphasis follows item identity, not slot 3. Keep published HUD geometry.
Bonus Nitro requires an active Nitro slot; no hidden charge when absent.
Race/Rematch defaults refill; GO preserves valid Countdown selection/order.
Lifecycle/session cleanup clears active slots and charges. Smoke was deferred
at M4-A2; M4-A3 implements it below. M4-A4 implements Thunder below. No Rain, persistence, Shop or Garage
selector is implemented.
M4-A2 CODE COMPLETE — FOUR-SLOT ITEM EXPANSION FOUNDATION READY.
Studio runtime NOT VERIFIED. M4-A2 basic published smoke: PUBLISHED PASS, confirmed
by the user (four slots, mobile direct use, Rematch refills each item to one).
Mobile ROOM/NEXT above minimap: PUBLISHED PASS. Preserve these accepted behaviors.

## M4-A3 Smoke and Tactical Loadouts

Nitro is mandatory locked Core slot 1; choose exactly three of Slick / Shield /
Missile / Smoke. Default remains Slick/Shield/Missile, each active item charge 1.
Only a reserved RACE server's PRE_RACE/WAITING staging offers ITEMS; do not change
Garage flow or delay automatic Solo launches. SetTacticalLoadout validates actual
RaceSession membership, waiting phase, exactly three unique implemented tactical
IDs and excludes Nitro. Server constructs four slots. Choices live only for the
current server stay/logical session, survive Rematch and refill, reset on Garage/
departure/different logical session. Never add arbitrary client slot ownership,
a fifth HUD cell or key 5. Keep the five-successful-BOOST threshold; apply the
current R7-A1-R4 repeatable Nitro contract, not the historical one-shot award.

Smoke is implemented Attack/DropBehind, charge 1/max 1 only when selected.
R2 provisional drop 10, volume 36x18x10, lifetime 6, effect 3.00, grace .75, cap 12.
SmokeHazardService owns bounded native clouds, per-target handled sets, swept
contact and vision-only metadata. Shared immunity -> Shield -> Smoke effect;
cloud remains after one hit/block. Same cloud affects each target at most once,
including immune rejection; never cross RaceSession/rounds. Do not change velocity,
steering, grip, Drift, Nitro or Mini Boost. Haze is local native UI below all HUDs,
non-interactive, translucent with central coverage and .12/.28 sec in/out fades.
Session/reset markers reject stale haze. Clean hazards/effects on terminal/exit,
Rematch/reset, seat/character loss, destruction, departure and session/round change.
No persistence, Inventory, Shop, DataStore or external assets in M4-A3.
CombatFeedbackView solely owns actual results with one cyan badge style;
legacy BLOCKED presentation is removed, SLICK DEPLOYED remains owner-only.
SMOKE_HIT/SMOKE_BLOCKED and victim SMOKED! use this same contract.
M4-A3 MVP CLOSED / PUBLISHED PASS (user-confirmed; see closure below).
Historical Studio runtime NOT VERIFIED; subsequent published closure is recorded below.

## M4-A3-R1 Item Preparation Gate

M4-A3-R1 2-PLAYER ITEM-PREP FLOW — PUBLISHED PASS, user-confirmed on mobile:
10-second per-racer prep, tactical selection, CONFIRM & READY, RESET DEFAULT,
ITEMS READY 2/2, Host START gating and actual chosen four-slot HUD all work.
Nitro / Shield / Missile / Smoke is published visible. World Smoke visibility,
contact detection and SMOKED! feedback also PASS. R1 obscuration was weak; R2
strengthened it. Subsequent Smoke impact, Shield counterplay and fall-reset
published PASS close M4-A3 below.

Each PUBLIC_RACE WAITING entrant receives their own server-owned
`RaceConfig.ITEM_PREP_SECONDS = 10` deadline. CONFIRM & READY stores a validated
trio and readies that racer. Timeout AUTO READY retains the last confirmed
server-local choice or production default; an unconfirmed client draft is never
applied. Ready and Auto Ready both lock editing for this round. RaceController
owns deadlines, readiness counts, timeout notices and start gating;
TacticalLoadoutService owns validated temporary choices and confirmation.

`RaceItemsReady`, `RaceItemsAutoReady`, `RaceItemsPrepareRemaining`,
`RaceItemsReadyCount` and `RaceItemsRequiredCount` are server-authored UI mirrors.
A new entrant never resets another racer's prep. Departure immediately removes
that racer from counts; Host migration preserves remaining choices/deadlines.
Rematch returns to WAITING with previous choices and a fresh 10-second window.
For 1–3 racers all ready enables Host START SOLO/START RACE; it never auto-starts.
At 4/4, all four must be ready before the single shared Countdown starts
automatically. Host early Start is independently rejected by the server.

WAITING shows ITEMS READY count, ITEMS remaining seconds, CONFIRM & READY and
AUTO READY IN remaining seconds. Ready clients cannot reopen editing. Host
receives a compact 1.4-second `<DisplayName> AUTO READY` notice. Countdown closes
editing. Existing preformed-match ARRIVAL/roster-timeout routing and immediate
Practice/V2 Solo countdown stay unchanged because those paths expose no ITEMS
window. Smoke/item/physics tuning, room identity, queue and routing are unchanged.

M4-A3-R1 2-PLAYER ITEM-PREP FLOW — PUBLISHED PASS; Smoke impact remains open.
Studio runtime NOT VERIFIED. Published 2-player prep above is PASS; broader
4/4 real-device checks are deferred until multi-user testing is available.
Retain automated all-ready full-room countdown-once coverage.

## M4-A3-R2 Smoke Impact Rebalance

Published Smoke pipeline PASS: world cloud visible, contact detected, SMOKED!
feedback visible. SMOKE GAMEPLAY EFFECT — FAIL / TOO WEAK: the 18-stud lane-local
cloud was too easy to avoid; 22-percent base haze / edge-biased puffs left the
central racing line clear, and the 1.75-second effect ended too quickly.

R2 provisional volume is 36x18x10 (width/length/height), approximately 60 percent
of the 60-stud Base road. Smoke alone uses RaceItemGeometry.smokeDropFrame:
normal 10-stud behind-Kart point, nearest active Road segment, lateral local X=0,
original local Z and Road rotation. Slick remains on the owner's precise line.
A centered screen leaves roughly 12 studs per side before Kart footprint;
chassis overlap at the visible edge hits, deliberate extreme outer lines avoid.

Nine static charcoal native puffs substantially fill the trigger bounds with
.48 transparency; all parts remain anchored/noncolliding/non-touching/non-querying.
At 12 clouds the budget is 120 Parts including invisible triggers. World lifetime
6 seconds, owner grace .75, drop 10 and cap 12 are unchanged. Per-cloud handled
sets, multi-target persistence, offensive immunity and one-hit Shield are unchanged.

Server vision effect lasts 3.00 seconds (was 1.75). Local base opacity 45 percent
(was 22), nine center/horizon/corridor puffs at 60 percent opacity (was 42).
Fade-in .12 seconds, cosmetic fade-out .28 seconds; fade never extends server
active time. Haze remains translucent, non-interactive and below race HUD/controls.
Speed, steering/throttle, grip, Drift, Nitro and Mini Boost remain unchanged.
Unified SMOKED! feedback and the published R1 item-prep flow are frozen.

M4-A3 MVP CLOSED / PUBLISHED PASS.

### M4-A3-R2 follow-up: fall recovery preserves race inventory

A RACING fall reset previously called full item teardown through RaceResetSerial,
emptying the still-active racer's HUD. Same-round recovery now clears only transient
combat state: Shield, Smoke effect/clouds, owned Slick hazards, outgoing/incoming
Missiles, feedback, immunity and contact history. PrototypeWorld continues to stop
Nitro/Mini Boost/Slick/Missile hit effects and reset movement; fall routing and lap
invalidation are unchanged.

Preserve exact four-slot order, remaining charges, selected item, confirmed tactical
choice, bonusProgress, bonusPending, bonusAwardCount and bonusEverAwarded, with
DriftBonusProgress / DriftBonusNitroAwarded compatibility mirrors. Do not refill
consumed charges or award/settle a bonus merely because recovery occurred.
Subsequent valid BOOST cycles follow the current repeatable Nitro contract.
Garage, departure,
character/kart destruction and session teardown retain full inventory cleanup.
Focused production-controller validation covers untouched/custom/partially consumed
loadouts, repeated falls, 3/5 progress, already-awarded bonus and transient cleanup;
real PrototypeWorld fall handling is also exercised with deterministic mocks.
M4-A3 user-confirmed published real-device PASS: 10-second Item Prep, tactical
selection, CONFIRM & READY, RESET DEFAULT, readiness counts and Host Start gating;
selected slots in the real race HUD; road-centered widened Smoke, disruptive haze,
satisfactory duration and SMOKED! feedback with no intentional speed/steering penalty;
Shield fully blocks Smoke with clean visibility; fall recovery preserves slots,
consumed/unused charges and Bonus Nitro progress/state. Broader published four-player
testing remains deferred. Historical Studio runtime was not verified. Freeze M4-A3
values and behavior; do not reopen tuning as part of M4-A4.


## M4-A4 Thunder Prototype

Thunder is a weak ahead-pack comeback attack. RaceItemController snapshots every
valid RACING KartContext in the same RaceSession with a lower authoritative
RacePosition. Leader/solo/no-target use retains the charge and reports NO TARGET
AHEAD. One accepted event consumes one charge for all fixed targets; never retarget
when positions change. ThunderStrikeService owns bounded warning events (max 8),
balanced RaceThunderIncomingCount, following native clouds, delayed logical strikes,
short .25-second native flashes and lifecycle/round cleanup. No projectile/Touched.

Warning: 1.00 sec. Unshielded hit: 60 planar speed cap for 2.00 sec (R1 provisional), cancel current
Nitro/Mini Boost/Drift, preserve earned Bonus Nitro progress/state. Steering/throttle
and normal lateral grip remain active; recovery accelerates naturally. No hard stun,
yaw/spin, vertical force or position write. Existing shared 1.0-second immunity
precedes the normal 5-second/one-hit Shield, then the effect. Reject overlapping
Thunder/Missile/Slick physical effects; each fixed target resolves independently.

Catalog has six implemented items; tactical candidates are Slick/Shield/Missile/
Smoke/Thunder in a mobile-safe 3+2 selector. Nitro remains locked slot 1; choose
exactly three tactics. Active slots remain four, default Nitro/Slick/Shield/Missile.
Thunder cloud/bolt native HUD icon follows item ID; mobile tap sends one validated
UseItem, desktop active keys 1–4 then Q. No key 5 or new Shield automation. Incoming
Thunder uses the existing warning/Shield emphasis; victim SHOCKED!/BLOCKED! and one
server-authored attacker hit/block summary use CombatFeedbackView's unified badge.

Rematch retains tactical choices, gives a new 10-sec edit window and refills active
charges. Fall recovery clears Thunder transients while preserving exact inventory
and bonus state. Existing Smoke/Slick/Missile/Shield values, Room/Queue/Host behavior,
ROOM/NEXT placement and physics remain frozen. No audio asset IDs were added.

M4-A4 baseline automated validation: 40 validation files PASS; Thunder suite 119 checks, actual
KartContext integration 594 checks (including Thunder), mobile Touch 2071 / Joystick
1645 checks. Wrapped selector safe bounds and nonoverlap cover 932x430, 844x390 and
notch-safe landscape. Rojo build and git diff --check PASS.

### M4-A4-R1 Thunder Impact Duration / Cap Consistency

User-confirmed published 2-player partial PASS: active four-slot Thunder HUD,
activation, visible lightning strike, clear SHOCKED! feedback and the target/attack
pipeline. The original 60 / 1.25-sec impact was too weak on real mobile and felt
shorter than one second. This is partial PASS, not M4-A4 closure.

R1 extends only THUNDER_EFFECT_DURATION from 1.25 to 2.00 seconds. Warning stays
1.00 second, speed cap 60, targeting/Shield/immunity/grip unchanged. Final planar
clamping also synchronizes commandedSpeed to outputPlanar:Dot(forward). Lightning
remains a .25-second impact flash, with short SHOCKED! feedback.

Production KartContext tests sample .10/.50/1.00/1.50/1.90 seconds in normal,
Nitro-100 and Mini-Boost-100 cases: active state and <=60 maintained every step,
boosts cancelled, Bonus progress/award/charges preserved, natural recovery after
2.00 seconds. A forced lateral-speed case verifies commanded-speed synchronization;
normal grip and actual Shield zero-slowdown are checked. Existing fixed targeting,
fall cleanup, Rematch, item prep and four-slot mobile behavior remain protected.

R1 automated validation: all 40 validation files PASS; Thunder 120 checks,
production RaceItem/KartContext integration 891 checks, Joystick 1645 checks.
Rojo build and git diff --check PASS.

M4-A4-R1 MVP CLOSED / PUBLISHED 2-PLAYER PASS, confirmed by the user:
Thunder activation, visible lightning / SHOCKED!, ahead-only targeting, approximately
60 speed cap for 2 seconds and timely Shield blocking all passed. Shield activated
after the hit may show its visual but does not retroactively cancel the resolved
Thunder effect; this is intended. Freeze warning 1.00 sec / cap 60 / effect 2.00 sec.
Published 3/4-player all-ahead targeting and mixed Shield sampling are deferred,
not MVP closure blockers. Studio runtime NOT VERIFIED.

### Garage UI Visual Polish Phase 1

Historical implementation and validation notes below describe each revision at
the time it was tested. Final user acceptance supersedes their pending statuses;
see Garage Visual Polish Phase 1B Final Acceptance below.

Direction: Simple for 7, Cool for 15 / Roblox Arcade Garage. Preserve responsive
safe-area architecture and the existing dark/navy identity. Phase 1 enlarges only
Driver Select: mobile height targets 36% of safe height, capped by header/name
clearance; desktop height targets 34%. Camera fits full avatar bounding-box corners,
including hair, to aspect ratio and FOV with 80% projected fill. Width may limit
unusually wide avatars. Kart / Track / Ready, Population / LOBBY, arrows and bottom
controls retain their established layout. No gameplay or seating changes.
Automated layout/framing validation is separate from Studio and published mobile
visual acceptance; both visual runtime checks remain required for this UI phase.
Phase 1 automated validation: Garage 4905 checks across seven mobile/safe-area
scenarios, two desktop resolutions and varied avatar bounds/aspect/FOV; all 40
validation files, Joystick 1645 checks, Rojo build and git diff --check PASS.

Phase 1 published captures showed the preview remained too wide/short; this was
not accepted as a visual PASS. Phase 1B builds on that framing foundation: only
non-interactive header text uses the vacant TopbarInset band when centered text
fits; portrait, cutout and occupied-band cases fall back inside the safe Garage.
Interactive UI stays in CoreUISafeInsets. Preview stages use 44% safe height
within available space, narrower landscape proportions (Driver/Track up to
2.65:1, Kart up to 2.4:1), with a square Track fallback in portrait. Driver fits
visible body/hair bounds (85% fit envelope), Kart uses 72% width / 94% height
safety. Both cache a full-yaw fit at selection/resize; mouse/touch horizontal
orbit uses .32 degrees/pixel, idle uses 7 sec/turn and resumes 2.5 sec after
release. Selection, step, route, character, hidden GUI and destruction clean up
rotation ownership/connections. No per-frame model scan or layout work.
Driver/Kart redundant descriptions are removed. Track retains mode/laps, its
existing orientation and a compact START / FINISH legend. Garage-only map padding
changes; race minimap and gameplay remain unchanged. Studio notch-emulator local
visual/interaction checks were performed; this does not validate published
Population or routing. Published Android/iPhone acceptance (Driver at least 1.5x
larger, readable hair/face, natural swipe, safe Core UI) remains REQUIRED. No
Phase 1B commit/push/Publish without explicit user approval.
Phase 1B automated checks: Garage 18641, Kart orbit 69120 corner checks,
all 40 validation files, mobile Touch 2071 / Joystick 1645, Thunder 120,
Rojo build and git diff --check PASS. CODE COMPLETE / PUBLISHED VISUAL ACCEPTANCE REQUIRED.


## Slick

~10 studs behind Kart
16 x 5 pad (M4-A0-R2 provisional lane-denial footprint)
10 sec lifetime
0.75 sec owner grace
short controlled slip
automatic recovery
no vertical flip
rear deploy animation
~0.9 sec rear preview

## Shield

5 sec or one attack.

Attack resolution:

valid target
→ item immunity
→ Shield
→ offensive item

## M4-A0 Auto Homing Missile Prototype

Server selects only the immediate RACING racer ahead (`RacePosition - 1`) in
the same RaceSession with a valid KartContext. No target retains the charge and
publishes NO TARGET AHEAD. Client target identity/position is never accepted.
Target remains fixed; no mid-flight retarget. A 0.90-second pre-launch warning
allows the existing 5-second/one-attack Shield to block with no physics effect.
Server Heartbeat homing uses relative swept proximity, noncolliding native
geometry, speed 165, lifetime 7 seconds, radius 5.5, turn rate 8 rad/sec and a
16-record active limit including warnings. Shared offensive immunity precedes
Shield and effect. Unshielded hits cancel Nitro/Mini Boost/current Drift, then
cap planar speed at 55 and multiply lateral grip by 0.70 for 2.50 seconds.
Steering/throttle remain active; no long stun, flip, forced yaw, vertical launch
or zero-speed restart. Earned cumulative Bonus Nitro progress stays unchanged.
New Nitro/Boost cannot start during the effect. Per-context `KartMissileHitActive`
and all projectile/incoming state clear at lifecycle boundaries; Rematch refills
the four temporary items. Mobile has four native-icon tap cells; Nitro Charge
spans the complete group. Inventory/persistence and other attacks remain deferred.
Published 2-player mobile interim PASS, confirmed by the user: four-item loadout,
Missile target/fire against the immediate racer ahead, incoming warning, Shield
recommendation UI and physical slowing hit. M4-A0 was open then. R1 changes only
the hit duration from 1.25 to 2.50 seconds and mobile combat HUD placement: four
44–48px cells stay in the left safe lane; Nitro Charge spans all four below the
row and above Drift/Use. Short landscape uses compact LAP rows with both status
warnings and a 40px Quit target. Production KartContext checks cover the cap on
every simulation step through expiry, boost rejection, brake/throttle, natural
recovery, preserved Bonus Nitro and Shield without physics. Forced lateral/outside
push is a future tuning candidate only, not implemented. Preserve M3 behavior.
M4-A0-R1 published mobile retest: HUD left alignment and Missile 55 / 2.50 sec
PASS, confirmed by the user. The 0.75-second warning was too short for mobile
Shield select -> USE, and Slick was not observable/effective in real two-player
racing. R2 extends only the warning to 1.50 seconds; incoming feedback remains
immediate and flight starts after that window. Slick grows from 7x5 to 16x5 on
the 60-stud Base/Practice road: 26.7 percent width, still avoidable lane denial.
The rectangular dark surface and four bright Neon edges match the trigger's
planar footprint; rear preview uses the same dimensions. No homing placement or
effect strengthening. Preserve .70-second effect, .55 speed retain, 60-degree
yaw, 10-second lifetime, Shield and 1-second immunity. Compact server diagnostics
record DEPLOY / HIT / BLOCKED / EXPIRE; repeated immune contact logs once per
hazard/target, never every Heartbeat.
R2 Studio 1 Server / 2 Clients targeted audit PASS: Player1 remote Select/Use
consumed Slick 1->0 and incremented deployment serial; Player2 observed the real
Workspace hazard, owner/session attributes, fully opaque 16x5 surface and four
Neon edges at .55 and 9.5 seconds, gone at 10.5. A scripted swept Player2 crossing
consumed the hazard and activated the real effect at speed 38.5. Test karts were
anchored and positioned in Play only; this does not verify natural mobile driving,
chase-camera readability or published counterplay. Full combat Studio runtime
NOT VERIFIED. R2 published runtime PASS, confirmed by the user: Missile
targeting/fire and 55 / 2.50-second slowdown, Slick visibility to the following
racer and hit/effect, and mobile four-item HUD. Mobile Shield select -> USE
remained too difficult within the 1.50-second warning at that milestone.
R3 initially kept warning at 1.50 seconds with Missile/Slick/physics/M3 unchanged.
Published mobile racing showed two-step selection/use is too slow for combat.
R3 unifies every touch item slot: TAP ITEM -> USE ITEM while RACING, via one
UseItem request with exactly one validated Nitro/Slick/Shield/Missile id. The
server requires a loadout, positive charge, valid active Kart and successful
item-specific activation; only then consume one charge and publish. Rejects spend
nothing. Direct and desktop use share the existing .15-second server throttle.
No Shield-only action remains; Shield works identically with or without incoming,
using its normal five-second/one-hit defense, including multiple incoming.
Mobile has no persistent selection mark or redundant USE button; the item-only
button is hidden and disconnected. Countdown taps do nothing. Desktop keys
1/2/3/4 select and Q uses; valid Countdown selection survives the GO refill,
while empty/reset loadouts safely refill with default Nitro. Cyan border / ! /
TAP SHIELD emphasize the existing slot during incoming; cosmetic Slick feedback
cannot hide it. Preserve the published left-side geometry and driving controls.
R3 published mobile PASS, confirmed by the user: direct one-tap item activation
works, and MISSILE INCOMING -> tap Shield -> BLOCKED is natural and reliable.
The 1.50-second warning now makes defense too easy. Balance follow-up changes
only pre-launch warning to 0.90 seconds; actual reaction time also includes
flight time. Shield remains manual, five seconds/one attack; no auto-activation.
All other Missile/Slick values and behavior remain unchanged.
M4-A0 MVP CLOSED — MULTIPLAYER BALANCE SAMPLE DEFERRED.
The user accepts the Missile catch-up effect for MVP. 0.90 seconds is a provisional
freeze; repeated statistical two-device defense-rate testing is deferred because
the user is a solo tester. Broader tuning belongs to future 3/4-player playtests.
Keep mobile direct-use/Shield counterplay PASS and Slick published visibility /
hit-effect PASS. Closure is not statistical balance verification.

## M4-A1 Combat Feedback

RaceItemController remains attack authority. Its RaceCombatFeedbackSerial / Code /
TargetName result contract publishes MISSILE_HIT / MISSILE_BLOCKED / SLICK_HIT /
SLICK_BLOCKED only after accepted resolution; rejects, immunity and self-Slick do
not report owner success. Clients observe authoritative KartMissileHitActive /
KartSlickActive rising edges, never infer hits from visual proximity.
HomingMissileService owns native launch flash and attached Trail cleanup.
Shield uses separate cosmetic cyan activation/block pulses: .30 seconds, max 32,
updated by the existing server loop; never another defense or duration.
R1 CombatFeedbackView uses a 240x34 dark rounded badge, 17px text, .25 background
transparency below actual speed HUD bounds across GUI insets. Incoming has
priority, moving the result below warning; portrait stays below LAP. Victim
MISSILE HIT! / SLICK HIT! / BLOCKED! last 1.0 sec; 6px edges last .60 sec.
Owner confirmations last 1.2 sec. Preserve locked/incoming /
TAP SHIELD / BLOCKED, the item row, Nitro Charge and driving control positions.
No physics, camera shake/rotation, opaque central flashes or combat balance edits.
Serials support repeated attacks; latest result replaces the cue, no stale queue.
Finish/DNF/Quit/Garage/Rematch, seat/character loss, Kart destruction, reset and
session boundaries clear transient feedback. No arbitrary audio IDs or reused
Countdown/Boost sounds; no new audio hooks, combat SFX deferred pending assets.
M4-A1 initially had published visibility failure. R1 fixes initial binding
swallowing an already-active hit and adds direct Kart attribute observation;
Heartbeat remains a lifecycle/expiry fallback. DEBUG_TELEMETRY gates bounded
server source/target/code/serial and client event/victim logs, never per-frame.
The existing cosmetic Shield pulse uses cyan Neon for visibility; defense shell,
duration/consumption and physics are unchanged. Production view tests cover real
mocked serials/state, short transitions, lifecycle and mobile safe bounds.
M4-A1 MVP ACCEPTED FOR PROGRESSION, user-confirmed: Shield Missile BLOCKED and
Slick victim feedback are visible. M4-A3 normalizes the minor style inconsistency
and removes duplicate legacy BLOCKED. No blanket PASS for all combat paths.
Studio runtime NOT VERIFIED; broader combat checks remain published-client work.

## Production Kart

2 chassis families / 11 color choices:

Sprint V1: Red / White / Blue / Yellow (4).
KDM V2: Cyan / Red / White / Yellow / Metal Blue / Metal Pink / Black (7).

Visual hierarchy:

Visual
├─ StaticRoot
├─ WheelFLPivot
├─ WheelFRPivot
├─ WheelRLPivot
├─ WheelRRPivot
└─ SteeringPivot

Do not import A-Chassis / Creator Store physics.

Do not move Physics Seat during unrelated tasks.

Driver seating issue is deferred.

## NEXT PRIORITY

Current: R7-A1-R4 Track03 4P + Repeatable Nitro code/automated PASS;
Repeatable Nitro and Track03 solo user mobile PASS; actual human 4P runtime
acceptance pending. R7-H0 records the documentation / Lobby architecture freeze.

1. **R7-H1:** Compact Hub Foundation + Roblox Avatar = Driver migration stage 1.
2. **R7-H2:** Garage / Kart interaction integration + Quick UI shortcuts.
3. **R7-H3:** Track Board + 3D rotating Track Preview + Room Browser integration.
4. **R7-H4:** Lobby → Reserved Race → Return Hub mobile/multiplayer acceptance.
5. After 4P stabilization: 6P → 8P in separate capacity tasks.

Phase 1C is a historical priority, superseded by this order. Do not implement
XP / Shop / persistent reward systems ahead of these approved steps.

Preserve closed M3/M4 population, room, item-prep, combat and Rematch behavior.

## Mobile Architecture

Keyboard
Touch
Tilt
Gamepad
    ↓
common actions
    ↓
steering / throttle / brake / drift / item
    ↓
existing KartControl / RaceItemControl
    ↓
same server physics

Touch:
default

Tilt:
deferred optional input, not a first Multiplayer beta blocker

Gyroscope unavailable:
Touch fallback

## Future Optional Tilt Steering

Neutral is relative to CURRENT DEVICE POSE.

Not absolute horizontal.

Target:

sitting
reclining
lying on back

Side-lying:
best-effort

Required:

Neutral capture
Recenter
sensor availability detection
dead zone
sensitivity curve
smoothing

Initial tuning candidates:

Dead zone:
±4–6 degrees

Full steer:
±18–22 degrees

Smoothing:
0.12–0.18 sec

Output:

steering -1 ... +1

## Mobile Controls

Default Digital Driving Pad:

↑ Forward
← Left
→ Right
↓ Brake / Reverse

Auto Accelerate toggle, DRIFT, and one-tap RaceLoadout item use while RACING.
Normal digital steering is ±1.00; steering while Drifting is ±0.60.
Legacy Joystick is a developer rollback mode.

RaceLoadout cells should be tappable.

PC and Mobile share the server-authoritative five-segment Drift gauge. Gold READY
latches for that Drift. Releasing DRIFT or centering steering triggers Mini Boost
when the same racer has valid forward input, enough speed and a safe unlocked
race state. Unsafe termination still fails the Drift, but earned Nitro Charge
progress remains unchanged during that race.

## Mobile Steering HUD

The PC/Mobile circular steering indicator is display-only.

Target:

bottom-center
bottom ~1/3 cropped below screen, with a 3px bottom margin
upper ~2/3 visible

Wheel shows actual steering input.

Half-oval design is future polish.

## Known Issues

Legacy Track02 is preserved; accepted Hard Circuit geometry is Track03.
Actual four-human R4 runtime acceptance remains pending. Historical M1-B finish
presentation gates must not be promoted to a new acceptance claim.
Set `DEBUG_TELEMETRY = false` before public production.
Historical rejected EngineLoop asset `6667206432`: real-device
listening found a periodic thump and deceleration-like tail. Do not continue
trim tuning unless requested; select a new steady-state loop asset with approval.

### Frame hitch

Occasional approximately 0.1 sec visual/frame hitch while driving,
possibly near Drift / Mini Boost.

Root cause unknown.

Do not make speculative Camera/Physics fixes.

Profile before Production release.

### Driver seating

Too high / posture / hand relation.

Deferred.

## Deferred Ideas

Nitro Reward / collectible challenge
Obby
Racer XP
Mastery
DataStore
Shop

Keep ideas, do not implement now.

## Future Progression

After Multiplayer + persistence:

Racer XP
Racer Level
Active Race Time
Valid Laps
Wins
Podiums

Possible Mastery:

1 active racing hour
= 1 Mastery Point

Max 5 per item.

Approximately +1% utility duration per point.

Maximum +5%.

Avoid stronger opponent stun/control-loss progression.

## Monetization

Initial target:

~USD 500/month.

Prefer:

Kart body
skin
colors
wheels/rims
trails
exhaust
driver cosmetics
titles/badges
garage cosmetics
seasonal collection

Avoid strong paid race-performance advantages.

## Multiplayer

Historical milestones before R7-A1-R4 follow. Their one-shot Bonus Nitro and
Base-only public catalog describe earlier behavior; use current contracts above.

M2-A0 foundation maps Player -> KartContext. Racer-specific simulation state
must never be a global singleton. One RaceSession owns shared match/track
lifecycle; RacerState owns each participant's lap, off-track and finish progress.
Player Attributes remain the replicated UI contract. One player lifecycle event
must not clear other racers' resources. Slick hazards keep their server-assigned
owner and session. KartControl never trusts a client-selected Kart identity.
Use one shared track with multiple kart contexts. M2-A0 makes no kart collision,
ranking or matchmaking decision and does not enable public multiplayer.

M2-A1 validated synchronized 2-player Practice Circuit Race (2 laps) on real devices.
The Garage title is KART DRIFT MASTERS and shows a small PlaceVersion build
label. Five actual Mini Boost starts during one race award one Nitro per racer
per race. Successes need not be consecutive; failed Drifts and driving incidents
never subtract progress. A new Countdown or leaving for Garage resets it.
Mobile tutorial dismissal persists in a dedicated preference DataStore;
CONTROLS still reopens it manually.
Track01 Practice (1 lap) and Track02 V2 (3 laps) remain solo. M2-B0 sets
`PUBLIC_RACE_MAX_PLAYERS = 4` for the public Track01Race lobby. The first READY
racer becomes host. One to three racers wait without a timer until the host
starts; the fourth READY racer starts the shared countdown automatically. The
host may START SOLO at 1/4 or START RACE at 2/4 and 3/4. Other racers may LEAVE.
Host departure transfers authority to the earliest remaining ReadyOrder.
The shared session
owns countdown and start time; each player owns KartContext and RacerState.
Finish place is fixed at the official final gate, before presentation. One
finisher must not stop the other. Multiplayer Rematch waits for all remaining
participants to vote. KartControl never accepts a client kart or target identity.
After every remaining racer votes or leaves, a sub-full Rematch returns 1–3
voters to the flexible WAITING lobby. A full 4/4 Rematch automatically starts
the shared countdown. The host may start a sub-full lobby or wait for another
READY racer. Do not leave an unowned race kart visible on
the active grid. Minimap positions come from server-published `RaceMapPosition`
and `RaceMapActive` attributes, never client Workspace Kart discovery. Garage
shows same-server player presence. `QuitRace` is a server-authoritative RACING
forfeit and must leave the opponent driving.
For Track01Race, a completed solo REMATCH returns the same host and kart to the
start-grid PRE_RACE / WAITING FOR RACERS lobby without a countdown.
The user confirmed the initial WAITING screen, START SOLO, solo two-lap Finish,
and solo REMATCH lobby return on a real mobile device.
The user's R3 two-device test
confirmed shared racing, two-lap Finish/PLACE, WAITING lobby, host START SOLO
and CANCEL, same-track join, Rematch re-entry, rival minimap, Garage presence,
Quit Race, 95 stud/s Mini Boost, and the visible progress indicator. R4
raises Mini Boost to 100 stud/s for 2.0 seconds with acceleration 65, without
changing Drift charge difficulty, Nitro 100/3.0/75, or the 15-second off-track
DNF threshold. The cumulative five-Boost bonus rule supersedes the earlier
four-Boost requirement. The initial WAITING screen was covered
by Garage PREPARING GRID; Garage now hides during PRE_RACE so the host sees the
track lobby. The user confirmed on a real mobile device that cumulative progress
reaches 5/5 without consecutive successes, the fifth Mini Boost awards one Nitro,
the awarded Nitro is usable, and Mini Boost reaches 100 stud/s. The user also
confirmed DON'T SHOW AGAIN across a full app rejoin with manual CONTROLS access,
the 15-second off-track DNF, and acceptable Quit Race panel spacing. The old
mobile Nitro Charge label overlaps the item cells. R4.5 moves cumulative Nitro
progress into RaceItemUiController's ScreenGui; the current Drift gauge remains
in DriftChargeView. The user confirmed 3/5 and 5/5 with BONUS EARNED below the
item cells on a real device without overlap. M2-A1 is closed.

M2-B0 temporary policy: RacerKart/RacerKart, RacerKart/RacerDriver and
RacerDriver/RacerDriver do not physically collide; track/barrier contact remains
unchanged. Revisit only when controlled physical contact is designed.

The user reported completing the M2-B0 Studio 1 Server / 4 Clients validation.
That check found a stationary on-track racer could keep a finisher waiting
indefinitely. M2-B0-R1 adds a session-owned 45-second deadline starting at the
first official multiplayer finish gate. Racing opponents retain normal control
and items until they finish, quit, DNF or time out. Remaining racers at expiry
receive `RACE_TIMEOUT` DNF without a finish place/time. All terminal results
complete the round early, while solo races retain their existing lifecycle.
Finished racers see a waiting countdown with Rematch disabled and Garage
available; active racers see a compact LAP HUD warning. The user confirmed
M2-B0-R1 RUNTIME PASS in Studio with 1 Server / 4 Clients: the flexible lobby,
same-server AVAILABLE / INVITE / JOIN, revised WAITING panel, 45-second grace,
finished-racer countdown, RACE_TIMEOUT DNF, and resolution of the infinite wait.
M2-B1 makes TrackCatalog authoritative for match type, minimum/maximum racers,
laps and Garage preview rotation. Practice Circuit is solo practice (1 lap),
Base Circuit is public 1–4 (2 laps), and Prototype Circuit V2 remains solo
prototype (3 laps) until separate geometry validation. Only Base Circuit's
Garage preview rotates 90 degrees clockwise; gameplay orientation is unchanged.
Waiting public lobbies show eligible same-server Garage racers. Only the current
host may invite, and joining revalidates the invitation through normal READY.
The Garage local player list continues to include all players on that server;
M3-A2 labels it LOBBY.
The M2-B public server supports one active RaceSession / track at a time. The
current published server size is 50; TrackCatalog limits a public race to four
racers. The user checked M2-B1 in Studio and on mobile; screenshots exposed a
waiting-title overlap with the availability panel. The user then confirmed
AVAILABLE IN SERVER, host INVITE, the RACE INVITE
modal, JOIN, a three-player race, and the revised waiting composition in Studio
and on mobile. Fourth invited JOIN auto-start has not been explicitly tested.
M2-B0-R2 isolates kart and seated-driver parts with RacerKart and RacerDriver
groups, including late descendants, and restores each avatar part's original
group on release. A per-kart upright guard corrects sustained roll/pitch during
RACING without increasing planar speed. The user confirmed M2-B0-R2 RUNTIME
PASS for close kart contact: racers pass through without pushing or rollover.
Forced 60–90 degree manual tilt recovery is not separately device-validated.

M3 MVP requires independent Race instances. Another track's active session
must not normally block Solo READY with "Racer not ready", "Track full" or
"Grid full". M3-A0 keeps the current PlaceId and adds authoritative HUB/RACE
roles. Public HUB handles Garage and selection; a reserved RACE server owns one
track, one RaceSession and 1–4 KartContexts. Practice Circuit and Prototype
Circuit V2 Solo READY launch separate reserved RACE servers with a validated
`KDM_RACE_V1` payload. Base Circuit remains in the current local public flow
until M3-A1. Result GARAGE returns to a public HUB; Solo REMATCH stays in the
same reserved server. Studio cannot validate real TeleportService routing;
published Roblox client testing is required. The published server size remains
50, while race participant capacity follows payload and TrackCatalog. M3-A1
adds concurrent Base MatchRooms and reserved multiplayer race launch. M3-A2
polishes return/rematch/failure recovery and verifies the no-blocking MVP gate.
Selected future tracks may support up to six racers; do not implement six here.

M3-A0 is CLOSED / RUNTIME PASS. Published PC/mobile checks confirmed Practice
and V2 independent reserved races, same-track and different-track Solo,
three simultaneous Solo races, Countdown/Race/Finish, Solo REMATCH, result
GARAGE to public HUB, and in-race QUIT to HUB Garage. Studio teleport failure
is not a published-runtime result. Observed handoff takes roughly one second
and is acceptable. M3-P0 adds JOINING RACE and RETURNING TO GARAGE transition
feedback through `KDMRoutePending`, a larger mobile LAP-panel Quit target in
Core UI safe insets, and a fixed-height scrollable ONLINE list. M3-P0 published
runtime passed for transition feedback, Solo launch, HUB return
and ONLINE scrolling. Known device polish: Galaxy Tab Quit Race touch may open
Roblox Chat; PC and regular phone did not reproduce it. This is deferred.
M3-A1 Base Circuit rooms hold 1–4 racers and create no HUB race kart. The user
confirmed three concurrent Base START SOLO reserved races on real devices.
KDM persistent Room: a race is temporary; the logical Room and Host identity
remain discoverable across rounds. CREATE reserves the Room server and moves
Host to GridSlot 1 in locked PRE_RACE / WAITING. JOIN seats authorized racers
in staging on that server. No mid-race join is allowed; late friends and rivals
queue for next staging. At 2/4 or 3/4 staged, only the Host starts; 4/4 seated
racers auto-start. REMATCH returns to staging without auto-starting a sub-full
round. Current rematch voters, accepted invited queue, prior rivals, then
public queue have priority; FIFO applies within each class. The preferred
server is the same reservation for every round while a participant remains.
`KDM_ActiveBaseRooms_v1` keeps staged, current-round and queued members separate
with 45-second TTL and heartbeat. `KDM_HubPresence_v1` lists only available HUB
racers; cross-server invitations are server-authoritative and revalidated on
acceptance. Reservation access codes never reach clients. Room Browser x/4 is
room capacity; POS x/y is actual current-round participation. Base rounds
retain Nitro/Slick/Shield 1/1/1 and Smoke 0. Published R2 runtime passed:
CREATE moves Host to the persistent track Room, JOIN reaches the same reserved
server, active RACING remains Browser-visible for QUEUE NEXT, queued racers
enter the next round, REMATCH returns to WAITING, track Host invite and queue
flow work, and valid 4/4 arrivals auto-start. Host departure transfers to a
remaining racer, updates the Browser Host name, and preserves logical Room ID
and queue. M3-A1-R2 is RUNTIME PASS / CLOSED.

The local Garage player list is LOBBY, never total ONLINE. Experience-wide
KDM ONLINE, LOBBY and IN RACE are approximate server-summary presence counts;
one short-lived record per HUB or RACE job, with no per-player global writes.
Base Rooms remain visible during racing. Current-round JOIN is forbidden after
WAITING; QUEUE NEXT remains available. Host migration preserves logical Room
identity and queue. Cross-server directory or population metadata failure must
never abort an active race.

M3-A2 FUNCTIONAL RUNTIME: PASS / CLOSED. The user confirmed published PASS for:
population updates (KDM ONLINE / LOBBY / IN RACE), RACING Room Browser visibility,
QUEUE NEXT, queue auto-promotion, queue ordering/position, Host Migration with the
same Room preserved, and stale-user population expiry within the TTL window.
Do not reopen those confirmed runtime items. Mobile Population HUD placement
was the remaining layout failure.

M3-A2-R1 implements a centered 14px mobile Population status below the Garage
step header, with two lines for narrow headers. Keep CoreUISafeInsets, separate
local scrollable LOBBY names, and the existing desktop right-side panel.
Automated geometry checks cover all four Garage steps at 1600×739, 1280×720,
844×390 and 390×844 with safe insets and long counts (50 / 38 / 12).
M3-A2 aggregate Population mobile runtime: PASS. The user confirmed
`KDM ONLINE 3 • LOBBY 3 • IN RACE 0` after the initial updating state.
Preserve the aggregate logic and centered placement.

The R1 follow-up expands only the local LOBBY name panel: four 16px rows with
2px gaps, a 20px header, 102px panel height and 70px scroll viewport. Landscape
uses the right gutter beyond the carousel arrow and below CONTROLS/title;
portrait uses the space below the summary and above the arrow, with fewer
complete rows when necessary. Four visible rows are checked at 1600×739,
1280×720, 844×390 and 390×844; 390×600 safely falls back to one. Existing
scrolling for 5+ names, player updates and scroll retention stay intact.
Published R1 local Lobby list: Android PASS; iOS FAIL — only ~1 visible row
despite LOBBY 3. Aggregate and local counts were correct on both devices.
M3-A2-R2 removes the 72px landscape-gutter breakpoint that incorrectly selected
the short portrait lane under larger side safe insets. It uses the already-safe
Garage parent bounds once, count-derived 1–4 row heights (16px rows, 2px gaps),
and a maximum 70px scrolling viewport for 5+ names. Portrait remains bounded by
the summary and carousel arrow. Names gain width through smaller inner padding
and reserve scrollbar space only when scrolling is needed. Core Population /
Room UX remains PASS / CLOSED; aggregation, Room Browser, Queue Next, promotion,
queue order, Host migration and stale population expiry remain confirmed.
M3-A2-R2: PUBLISHED iOS VISUAL PASS / CLOSED. The user confirmed the published
local Lobby list now matches Android. Android/iOS Lobby list parity: PASS.
M3: CLOSED. The historical automated R2 run did not verify Studio runtime.

Public standard is four racers. Architecture may expand to six later; six-player
implementation and GridSlots 5/6 are deferred. A future friend/private room may
choose 2, 3, 4 or 6 racers with invites and a reserved server; M2-B0 does not
implement private rooms, reserved servers or cross-server matchmaking.
Selected tracks may have different capacities; none is automatically enabled
for multiplayer by the presence of four GridSlots.

Before declaring four-player runtime validation, verify:

RaceItemController cleanup
hazard ownership
race state
rematch/result
player/session isolation

## Tests

Historical per-milestone counts below remain evidence for their checkpoints.
Current R4 recorded validation is 53/53; H0 requires documentation checks only.

Current:

tests/camera_motion_validation.luau
tests/mobile_touch_validation.luau
tests/drift_telemetry_validation.luau
tests/kart_visual_validation.luau
tests/race_item_validation.luau
tests/missile_validation.luau
tests/slick_validation.luau
tests/race_mode_validation.luau
tests/race_route_validation.luau
tests/race_audio_validation.luau
tests/kart_audio_validation.luau
tests/track_environment_validation.luau
tests/finish_sequence_validation.luau
tests/finish_presentation_validation.luau
tests/race_result_hud_validation.luau
tests/garage_two_player_validation.luau
tests/two_player_race_validation.luau
tests/four_player_race_validation.luau
tests/player_preferences_validation.luau
tests/kart_contact_validation.luau
tests/race_launch_routing_validation.luau
tests/match_room_validation.luau
tests/match_room_service_validation.luau
tests/active_match_directory_validation.luau
tests/race_room_coordinator_validation.luau
tests/persistent_room_race_validation.luau
tests/reserved_match_validation.luau
tests/reserved_arrival_validation.luau

Always run:

rojo build -o $env:TEMP\<task>.rbxlx
git diff --check

Automated tests do not replace Studio tests.

Mobile requires:

Studio emulator
Android real device
iPhone real device

## Reporting

Always report:

- what changed
- why
- exact files
- tests
- Studio runtime status
- unresolved risks
- commit/push status

If Studio runtime was not verified, explicitly say:

Studio runtime NOT VERIFIED.

Keep tasks narrowly scoped.

## Finish Presentation and Results

The final gate crossing fixes the official race and lap times. Presentation
time never changes those records:

RACING → FINISHING / ROLL → FINISHING / PRESENT → FINISHED.

ROLL decelerates the kart for 2.4 seconds under locked controls. The kart stops
before the front camera transition and seated driver wave. Results appear only
after the transition and sit left of the driver/kart scene. Rematch restores the
Chase camera; Garage clears finish presentation state. DNF remains separate.

Results show Total Time, Lap 1/2/3, best lap number, displayed-centisecond
deltas, Rematch and Garage. Practice shows Lap 1 only.

On mobile FINISHED screens, keep the left result panel visually separate from
the Driver/Kart. Touch finish camera composition may shift the Driver/Kart right;
preserve the desktop finish view.
Finish screen-space drift is camera-only. Never add lateral server kart physics
for this cinematic.

Automated tests do not replace device checks. R3 shared-race runtime was
confirmed by the user on two real devices. The cumulative Bonus Nitro, 100
stud/s Mini Boost, initial and solo Rematch lobbies, tutorial persistence,
15-second DNF, Quit Race spacing, and R4.5 NITRO CHARGE placement passed on mobile.


### Garage Visual Polish Phase 1B-R1

Historical R1/R2/R3 reports below precede final acceptance and retain their
original measurements and runtime limitations.

Only the non-interactive title uses the free TopbarInset band; Step and mobile
Population remain in CoreUISafeInsets below it. Portrait, notch-heavy and crowded
Core UI use the safe header fallback. None-inset header size/origin changes also
recalculate alignment after device switching. Phase 1B widths remain bounded;
available vertical space grows the stage (mocked 1600x739: 784x347, 844x390:
387x169 for Driver). Driver orbit envelope grows 85% -> 89%; Garage-only Kart
width fit 72% -> 80%. Track canvas grows .94 -> .96 and padding 1.08 -> 1.04;
racing minimaps and track orientation/geometry remain unchanged. Full-yaw safety,
manual drag, seven-second idle turn and 2.5-second resume are preserved.
Studio local Driver/Kart rotation, Practice/Base/V2, Ready/Back and title/Core UI
alignment were inspected; notch fallback was inspected. Studio population remains
UPDATING because presence publication fails with its empty JobId; gameplay/status
logic was not changed. Published Android/iPhone size and clipping acceptance is
still required. Existing Phase 1/1B changes remain unstaged. No commit, push or
Roblox Publish for R1. PHASE 1B-R1 CODE COMPLETE / PUBLISHED VISUAL ACCEPTANCE REQUIRED.

### Garage Visual Polish Phase 1B-R2

R1 is NOT ACCEPTED: the user reported a disappearing PC title and unchanged
published mobile header. R2 reproduced the PC failure (raw title Y=-105) and
iPhone safe-header fallback before fixing them. R1 mixed Garage safe-root origin,
None-inset header origin and GetGuiInset in title placement; its 8-percent lost-width
condition rejected legitimate notches. Disabling the empty header during fallback
also left AbsoluteSize stale after desktop-to-mobile switching.

GarageTopHeader explicitly uses IgnoreGuiInset=true, ScreenInsets=None and
ClipToDeviceSafeArea=false. The title is its direct child in TOPBAR with a (.5,.5)
anchor and physical-screen-centered offsets. TopbarInset is translated once from
the camera's device-safe viewport to that canvas; Garage safe-root offsets never
enter the title calculation. Fallback depends on landscape, width, valid band and
centered title clearance, not TouchEnabled or notch-width loss. The empty header
stays enabled while Garage is visible so its runtime geometry remains live.
Step/Population remain in the Garage root; Ready reserves the existing CONTROLS
button clearance. Preview framing/rotation/width policies remain unchanged.

Zero measurements wait for geometry signals; title-size observation is startup-only
to avoid recursively observing layout output. Camera replacement and destruction
disconnect the owned viewport/layout listeners. GARAGE_LAYOUT_DEBUG defaults OFF;
only debug enables coordinate logs and the GARAGE R2 Build suffix. A hidden GUI
attribute identifies the layout revision without adding production screen text.

Actual Studio AbsolutePosition/AbsoluteSize and CoreGui icon bounds were queried.
iPhone 17 Pro landscape: camera 749x361, physical header 873x401, TopbarInset
(208,0)-(749,58), title raw (217,-41), size 314x24, physical top 37/center 49.
PC: camera/header 1709.33x762, TopbarInset (208,0)-(1709.33,58), title raw
(629,-47), size 450x36, physical top 11/center 29. Roblox raw AbsolutePosition
uses an inset-relative origin; negative raw Y alone is not screen clipping.
The actual title/icon center difference was 5px. Native Studio window captures
including Core UI confirmed visible, unclipped alignment on Driver/Kart and PC.
Mobile -> PC, >10-second wait, desktop resize (1919x1080 and 1599x739), then
Mobile retained TOPBAR. Runtime previews: iPhone Driver 353x154, Kart 319x154,
Track 353x139; desktop Driver 800x360 and Kart 744x360. Studio aggregate Population
still reports UPDATING because its empty JobId cannot publish presence; this is
not published Population validation. No new Garage layout errors in the final run.

R2 automated validation: Garage 18861 checks using actual absolute-bound semantics,
resize/late-topbar/zero-measurement/camera-replacement/stale-disabled-canvas cases;
all 40 validation files, Kart orbit 69120, Touch 2071, Joystick 1645, Thunder 120,
Rojo build and git diff --check PASS. Existing Phase 1/1B/R1 changes are preserved.
No commit, push or Roblox Publish. PHASE 1B-R2 CODE COMPLETE / PUBLISHED VALIDATION
REQUIRED, not CLOSED. After explicit Publish approval, fully close the Roblox app,
join a new server, verify latest BUILD PV and (if debug enabled) GARAGE R2, then
check Driver/Kart screenshots with Core UI, rotation, preview size, LOBBY and
Population on real Android/iPhone. PV alone does not establish source revision;
the exact source loaded by PV162 remains unverified.

### Garage Visual Polish Phase 1B-R3

User-confirmed PV166 closes R2's published header/preview/rotation/mobile visual
acceptance. Preserve that accepted composition and Topbar coordinate ownership.
R3 groups desktop preview/name/actions with a 36px name-to-button gap and a
1240px maximum content envelope. The 220px Lobby matches preview height; Controls
sits 12px below it. Mouse-only short windows use desktop composition. Mobile
landscape Driver/Kart/Track Lobby panels match stage height, use 120-150px width
and a fixed scrolling viewport; narrow stages shrink width by 6% only. Portrait
and mobile Ready retain their previous panel policy. Framing/rotation and mobile
preview-height calculation remain unchanged.

The real host invite path is RaceHudController -> GarageControl ->
RaceRoomCoordinator, rather than MatchRoomUiController's legacy Invite action.
Each target has INVITE / SENDING... / WAITING / RETRY state. Only successful
RoomSocialDirectory storage produces InviteSent with targetUserId, requestId,
roomId and authoritative expiresAt. Duplicate sends retain the existing stored
expiry. Independent RoomSnapshot pendingInvites mirrors restore missing ACK
state and clear declined/admitted/expired targets. The existing 5-second snapshot
poll supplies cross-server decline feedback; no new TTL is invented. Local legacy
Garage invites retain their existing 30-second lifetime with matching ACKs.

R3 automated validation: Garage 18872, production HUD 127, Room coordinator 18,
Touch 2071 / Joystick 1645, all 40 validation files, Rojo build and diff check PASS.
Actual Studio desktop probes covered requested 1920x1080, 1600x900, 1366x768,
1280x720 and 2560x1080 (emulator reports slightly smaller rendered viewports).
Stage sizes were 800x360, 800x360, 800x326, 769x290 and 800x360 respectively;
name/action gap 36px, Lobby equal height and Controls gap 12px in every probe.
The iPhone 17 Pro landscape probe measured safe canvas 749x302, preview 352x154,
Lobby 128x154, zero top/height delta and 120px name width. Custom 844x390 and
932x430 phone-emulator settings also retained matched panel/stage heights;
these presets include device cutout reductions and fallback-header clearance.

Actual local server with two, then three clients exercised cloned production
Room modules using isolated real MemoryStore maps and a Play-only negative-ID
adapter (Studio Player IDs -1/-2/-3; repository validation remains positive IDs).
Real client RemoteEvents produced stored InviteSent ACKs, decline removal,
accepted INVITED next-race queue membership, independent WAITING button states,
per-target decline restoration and expiry restoration. This is controlled Studio
runtime evidence, not cross-server/published acceptance. Tap-driven SENDING
feedback and reserved-server teleport/arrival remain unverified; direct requests
were used for the live storage tests. Studio's empty JobId still causes aggregate
presence errors; a separate direct probe confirmed MemoryStore works. Published
R3 remains NOT VERIFIED. No commit, push or Roblox Publish.
At that checkpoint, Phase 1B-R3 was not complete under the requested runtime criteria.

### Garage Visual Polish Phase 1B Final Acceptance

Garage Visual Polish Phase 1B / R2 / R3 / R3-R1: CLOSED / ACCEPTED.
The user completed Mobile and Desktop Visual Acceptance.

- Mobile Topbar alignment: PASS.
- Driver / Kart previews and horizontal rotation: PASS.
- Track preview layout / scale: PASS.
- Mobile Lobby responsive sidebar expansion and player list: PASS.
- Invite INVITE -> SENDING... -> WAITING and real-device tap feedback: PASS.
- Desktop responsive composition: preview scaling, content centering, Lobby /
  Controls sidebars, button grouping and large-display composition: PASS.
- Mobile regression after the desktop patch: PASS.

R3-R1 changes only desktop scale and centering; desktop previews are bounded at
1100x500, Lobby height matches the preview and Controls follows below it.
Historical Studio reserved-server HTTP 403 is not a Phase 1B failure and does not
establish reserved-server launch acceptance. No server logic change is requested.
Historical next UI direction at that checkpoint: Phase 1C / Arcade Garage Visual Layer.
Superseded by the R7-H0 Compact Lobby roadmap above.
This finalization authorizes the Git checkpoint only; no Roblox Publish.
