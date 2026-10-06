# Kart Drift Masters

Mobile-first arcade kart racing game for Roblox.

## Goal

Build a real commercial Roblox game with:

- easy mobile controls
- skill-based drifting
- strategic race items
- short replayable races
- multiplayer competition
- cosmetic / collection monetization

Initial commercial target: **USD 500/month**.

## Current Baseline

- Repository: `jbak2588/RobloxKart`
- Branch: `prototype/kart-physics`
- Review baseline: current `origin/prototype/kart-physics` HEAD

## Game Flow

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

## Planned Roblox Compact Racing Hub

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

## Driving

| Mode | Speed | Duration |
| --- | --- | --- |
| Normal | 70 stud/s | — |
| Mini Boost | 100 stud/s | 2.0 sec |
| Nitro | 100 stud/s | 3 sec |

## RaceLoadout

Every race starts with:

- Nitro 1
- Slick 1
- Shield 1
- Missile 1
- Smoke 0 in the default (optional tactical choice in M4-A3)

PC controls: `1` Nitro / `2` Slick / `3` Shield / `4` Missile; `Q` = use.

RaceLoadout is temporary. Inventory is reserved for future persistent Shop ownership.

### M4-A2 Four-Slot Item Expansion Foundation

`RaceItemCatalog` owns item metadata, implementation status and initial/max charges.
The catalog may grow beyond four; `RaceItemSlots.RACE_ITEM_SLOT_COUNT = 4` fixes
the race HUD at exactly four active slots. Production defaults remain
`Nitro / Slick / Shield / Missile`, each with one charge. At M4-A2 Smoke was
deferred metadata only; M4-A3 below implements the fifth catalog item without
adding a fifth active slot.

Server-only `RaceLoadout:prepare(slotIds, preserveSelection)` validates exactly
four unique implemented items with charge configuration, copies their order,
and owns `slots`, `counts` and `selected`. Invalid preparation changes nothing.
The server publishes `RaceItemSlot1..4` and charge attributes. Mobile taps use
the displayed active item directly; desktop `1/2/3/4` select slot positions and
`Q` uses the selection. Both selection and use require membership in that
player's server loadout. Existing icons, HUD geometry and combat feedback stay
unchanged; incoming emphasis finds Shield by item identity, wherever its slot is.
Bonus Nitro now follows R7-A1-R4 repeatable five-BOOST cycles, held max 2 and
pending max 1, and requires Nitro in the active loadout. No hidden charge is created.

Historical M4-A2 lifecycle description: New Race/Rematch prepared the default;
terminal/exit and session teardown cleared slots and charges. Same-race fall
recovery now preserves inventory and repeatable reward state as specified above. GO refills valid Countdown slots
and preserves desktop preselection; a cleared loadout safely uses the default.
The M4-A2 foundation added no persistence, inventory, Shop or selector. M4-A3
adds server-local pre-race tactical choices and Smoke below; a Garage item selector
remains deferred. At M4-A2, Thunder/Rain and persistence were deferred. Thunder was
subsequently implemented and MVP closed in M4-A4-R1; Rain and persistence remain deferred.

Automated production tests cover alternate slot order, publication, keys/taps,
icons, Shield emphasis, deferred/inactive rejection, lifecycle and Bonus Nitro.
Studio runtime NOT VERIFIED for M4-A2. User-confirmed M4-A2 basic published smoke:
PUBLISHED PASS (four slots, mobile direct use, Rematch refills each default item
to one). Mobile ROOM/NEXT above minimap: PUBLISHED PASS. M4-A1 published feedback
visibility failed; see R1 below. Broader multiplayer balance remains deferred.

**M4-A2 CODE COMPLETE — FOUR-SLOT ITEM EXPANSION FOUNDATION READY**

### M4-A3 Smoke Screen + Pre-Race Tactical Loadout v1

Nitro is the mandatory locked Core in slot 1. In a reserved RACE server's existing
PRE_RACE/WAITING staging, ITEMS opens a compact modal: choose exactly three of
Slick / Shield / Missile / Smoke, RESET DEFAULT, CONFIRM or BACK to discard edits.
Default remains Nitro / Slick / Shield / Missile. All buttons are at least 44px
high. No Garage-flow change or new waiting timer is added for automatic Solo
launches. A round starting closes the modal and locks changes.

SetTacticalLoadout accepts only three unique implemented allowed tactical IDs.
The server checks RaceSession membership and PRE_RACE plus a waiting session,
constructs Nitro + three choices, and stores them only for the current server
stay/session. Rematch keeps choices and refills each active item to one. Garage,
departure or a different logical RaceSession restores safe defaults. No fifth
HUD cell, key 5, persistence, Inventory, Shop or DataStore is added. Bonus Nitro's
five-BOOST threshold is retained; repeatable awards use the R7-A1-R4 contract.
Smoke icon follows its actual active slot.

R2 Smoke prototype: drop 10 studs behind at Road center; volume 36x18x10; lifetime 6 seconds;
vision effect 3.00 seconds; owner grace .75 seconds; maximum 12 clouds. Nine
charcoal translucent native puffs match the invisible volume. All parts are
anchored, noncolliding, non-touching and non-querying; no external assets or
particle spam. Server swept volume checks handle each cloud/target once. Clouds
survive a hit/block and can independently affect multiple racers in the same
RaceSession; session/round boundaries remove them. Existing offensive immunity
precedes Shield. A block consumes that target's Shield, adds no obscuration,
and preserves the cloud; immune contact is marked handled without repeated work.

KartSmokeObscuredActive and session/reset markers drive a local translucent haze
with central haze coverage, .12-second fade-in and .28-second fade-out. Its GUI is below all
driving/item HUDs, never captures input, and changes no camera/physics. Speed,
steering, Drift, Nitro and Mini Boost remain active. Smoke lifecycle clears at
terminal/exit, seat/character loss, reset/destruction and session/round changes.

CombatFeedbackView is the sole actual result badge owner. Legacy BLOCKED text and
item-row hiding were removed; owner SLICK DEPLOYED may remain. MISSILE HIT! /
SLICK HIT! / BLOCKED! / SMOKED! share the approved cyan text, font, badge and
one-second victim timing. New SMOKE_HIT / SMOKE_BLOCKED give deployer confirmations
with the same badge; latest result replaces the previous one. Item geometry,
Incoming priority and ROOM/NEXT above minimap remain unchanged.

M4-A1 is MVP ACCEPTED FOR PROGRESSION, user-confirmed: Shield Missile defense
BLOCKED and Slick victim feedback are visible. Minor style inconsistency is
fixed here. Four slots, mobile direct use, Rematch default refill and ROOM/NEXT
placement retain published PASS. Subsequent Smoke impact and Shield counterplay
published PASS are recorded in the closure below. Studio runtime NOT VERIFIED
for M4-A3; broader combat paths remain deferred.

**M4-A3 MVP CLOSED / PUBLISHED PASS**

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


## Production Kart

2 chassis families / 11 color choices: Sprint V1 (Red, White, Blue, Yellow)
and KDM V2 (Cyan, Red, White, Yellow, Metal Blue, Metal Pink, Black).

## Historical Development Notes

Milestone descriptions and validation counts below describe their original checkpoints.
The current R7-A1-R4 contract and R7-H0 roadmap above take precedence; old one-shot
Nitro, three-track catalog and Phase 1C priorities are historical only.

### M4-A0 Auto Homing Missile Prototype

**M3 CLOSED. M3-A2-R2 PUBLISHED iOS VISUAL PASS / CLOSED.** The user confirmed
Android/iOS local Lobby list parity. All proven M3 Room, queue, routing and
population behavior remains closed.

Missile is a temporary fourth race item for tactical chase/counterplay. The
server acquires exactly the immediately preceding `RacePosition` in the same
RaceSession, requiring both racers to be RACING with valid KartContexts. It
never skips an invalid immediate rival to attack the leader. Leader and solo
use return `NO TARGET AHEAD` without consuming a charge. Source feedback shows
`MISSILE LOCKED: <player>`; the target sees `MISSILE INCOMING / SHIELD CAN BLOCK`.
Incoming counts support multiple projectiles. The client supplies only Select,
Use or direct UseItem actions, never a target, position or hit report.

`RaceItemController` owns target acquisition, loadout consumption and the shared
valid target → immunity → Shield → effect path. `HomingMissileService` owns
the 0.90-second pre-launch warning, fixed target, Heartbeat flight and cleanup. Incoming
feedback publishes immediately; projectile flight waits for the full window. It moves
noncolliding native geometry at 165 stud/s, turning at up to 8 rad/sec, with a
7-second flight lifetime and 5.5-stud relative swept hit radius. Up to 16 active
records (including warnings) are allowed. Targets never change after acceptance;
invalid racers, changed sessions/rounds, reset karts and owner departure expire
the projectile safely. A small native impact flash lasts 0.2 seconds. Wall
collision/path following and approved combat audio remain deferred.

The existing Shield blocks one Missile, consumes itself and applies no hit
physics. An unshielded hit cancels Nitro, Mini Boost and the current Drift, then
sets per-KartContext `KartMissileHitActive` for 2.50 seconds: planar speed cap 55
and normal lateral grip ×0.70. Steering, throttle and Shield remain available;
new Nitro/Mini Boost are rejected. No forced spin, flip, vertical launch, control
lock or zero-speed restart occurs. Speed recovers with normal acceleration after
expiry, and earned cumulative Bonus Nitro progress is preserved. Reset, seat
change, Garage, Finish, DNF/Quit, destruction and owner release clear the effect.

Mobile uses four 44–48px native-icon cells in the left safe lane, without the
former short-landscape horizontal offset into the Kart/view corridor. Nitro
Charge is centered across all four cells, below them and above Drift/Use. Short
landscape safe bounds use 44px cells and compact LAP rows while retaining both
status warnings and the 40px Quit target. Driving controls retain their positions.
Prototype tuning is in `RaceItemConfig`;
the existing driving/boost invariants remain unchanged.

Published 2-player mobile interim PASS, confirmed by the user: four-item loadout,
Missile selection/fire against the immediate racer ahead, incoming warning,
Shield recommendation UI and a physical slowing hit. That interim result did not close M4-A0.
R1 extends slowdown from 1.25 to 2.50 seconds and moves the four-slot HUD away
from the central Kart view. A forced lateral/outside push remains a future tuning
candidate only; R1 adds no push or impulse.

R1 published mobile retest PASS, confirmed by the user: left-aligned four-item
HUD and clearly felt Missile 55 / 2.50-second slowdown. The 0.75-second warning
was too short for mobile Shield select -> USE, and Slick was not visible/effective
to the trailing racer. R2 gives a 1.50-second reaction window and audits/widens
Slick as described below. At that milestone M4-A0 remained OPEN.

R2 published runtime PASS, confirmed by the user: Missile targeting/fire and
55 / 2.50-second slowdown, Slick visible to the following racer and its hit/effect,
and the mobile four-item HUD. Mobile Shield select -> USE remains too difficult
even with the 1.50-second warning at that milestone.

**M4-A0-R3 mobile one-tap activation / Shield counterplay: PUBLISHED PASS.**
The user confirmed direct one-tap item activation works and
`MISSILE INCOMING -> tap Shield -> BLOCKED` is natural and reliable.
Published mobile racing showed SELECT ITEM -> USE was too slow and required
unnecessary attention during combat. Touch now uses TAP ITEM -> USE ITEM for
Nitro, Slick, Shield and Missile while RACING. Each tap sends one atomic
`UseItem` request with exactly one item id; the server validates the id, loadout,
charge, active Kart and item-specific activation before consuming one charge.
Rejections spend nothing, and direct/desktop use share the .15-second throttle.
Shield uses the same direct path with or without incoming; it remains manual
five-second/one-attack defense. The Shield-only action has been removed.
Mobile has no persistent selection checkmark and the redundant item-only USE
button is hidden/disconnected. Countdown taps do nothing. Desktop 1/2/3/4 select
and Q use stay unchanged; valid Countdown selection survives GO's authoritative
refill, while reset/empty loadouts refill safely. A cyan border, `!` and
`TAP SHIELD` emphasize the existing Shield slot during incoming, including
cosmetic Slick feedback. The four-item group stays in its approved left lane.
With one-tap defense, the user found 1.50 seconds too forgiving. This balance
follow-up changes only `MISSILE_WARNING_SECONDS` to **0.90 seconds**. This is
the pre-launch warning; total reaction time also includes projectile flight.
Shield is still a manual tap, five seconds or one offensive hit. Other Missile
values, Slick 16x5 and behavior, physics and M3 are unchanged.
**M4-A0 MVP CLOSED — MULTIPLAYER BALANCE SAMPLE DEFERRED.**
The user accepts the Missile catch-up effect for MVP and freezes 0.90 seconds
provisionally. Mobile direct use / Shield counterplay and Slick published
visibility/effect remain PASS. As a solo tester, the user defers repeated
statistical two-device defense-rate testing to a later 3–4-player sample.
This closure does not claim a completed statistical balance sample.
Do not reopen MVP combat values during M4-A1.
Production KartContext tests enforce cap 55 every simulation
step, with active samples at 0.25, 1.00, 1.50, 2.25 and 2.49 seconds, followed by
normal acceleration after 2.50 seconds; braking/throttle and Shield are covered.
AUTO TEST PASS: all 33 `*_validation.luau` suites plus Joystick (34 runs),
including focused Missile, production KartContext and mobile layout coverage.
Rojo build and `git diff --check` PASS. This is not PUBLISHED RUNTIME PASS.

### M4-A1 Combat Feedback Polish v1

**CODE COMPLETE — PUBLISHED COMBAT FEEDBACK SMOKE TEST REQUIRED.**
RaceItemController publishes a small server-authored result contract:
RaceCombatFeedbackSerial / Code / TargetName. MISSILE_HIT, MISSILE_BLOCKED,
SLICK_HIT and SLICK_BLOCKED are emitted only after accepted attack resolution;
immune/rejected contacts and self-Slick hits do not report owner success.
Missile targeting, fixed flight and incoming counts remain unchanged.

Native launch flash and a short Attachment/Trail exhaust make flight readable;
the projectile owns and destroys these objects. Shield activation and block use
short cyan expanding shells, separate from the five-second/one-hit defense.
At most 32 cosmetic Shield pulses live for 0.30 seconds in the existing server
loop. Slick's 16x5 pad/perimeter and all effects stay unchanged.
R1 CombatFeedbackView uses a dark rounded 240x34 badge, 17px GothamBold and .25
background transparency, below the actual speed panel in screen coordinates.
Incoming warning has priority; the badge moves below it while visible. Portrait
uses the existing safe lane below LAP. Victims see MISSILE HIT! / SLICK HIT! /
BLOCKED! for 1.0 second, with 6px peripheral cues fading over .60 seconds.
Attackers see HIT: name / SHIELD BLOCKED / SLICK HIT: name / SLICK BLOCKED for
1.2 seconds. Existing MISSILE LOCKED, incoming/TAP
SHIELD and BLOCKED! remain. No camera motion, central opaque flash or physics.
No new audio assets or audio hooks were added; combat remains silent until
approved owned/licensed assets are provided. Existing audio is unchanged.

HUD feedback and server pulse/projectile visuals clear at race/session/reset,
seat/character loss, destruction and exit boundaries. Repeated results use
serials; newest result replaces the compact cue without queuing old messages.
Automated checks cover resolution, native visuals, cleanup and safe GUI bounds
including 932x430 / 844x390 and smaller notch-safe landscape parents. The item
row, Nitro Charge, Drift, wheel and pad geometry are unchanged.
Initial M4-A1: PUBLISHED FEEDBACK VISIBILITY FAIL, confirmed by the user's mobile
two-player test: effects work but Missile hit, Shield block and Slick hit cues
were not perceived. The audit confirms server hit/block
authoring and deterministic client serial/state rendering, but does not prove
published replication. Initial view binding could swallow an already-active hit;
R1 displays that initial edge and directly observes Kart attributes so short
Slick transitions do not depend solely on Heartbeat sampling. Telemetry-gated
server source/target/code/serial and client event/victim logs occur only on actual
transitions. Shield defense shell/timing stay unchanged; the existing cosmetic
pulse uses cyan Neon for clearer contact. No combat balance changes.
Production view tests execute all four attacker results, three victim cues,
expiry, replacement, initial binding, short transitions and lifecycle cleanup.
Geometry checks use actual speed bounds across separate GUI insets at 932x430,
844x390 and notch-safe landscape, clearing LAP/map/ROOM/items/road center.
Studio runtime NOT VERIFIED for R1. Subsequent user-confirmed published mobile
BLOCKED and Slick victim visibility are PASS; M4-A1 is MVP ACCEPTED FOR
PROGRESSION. M4-A3 above fixes the remaining style inconsistency. This is not
a blanket published PASS for all attacker/victim combat paths.

### M1-A Digital Driving Pad v1

Touch defaults to a fixed, icon-only driving pad at bottom right. Hold the large
up arrow for forward, left/right for stable -1/+1 steering, and down for the
existing brake-to-reverse action. Each touch owns its button until release or
cancellation, even when the finger moves outside it. Forward and steering can
use separate fingers. If both directions are held, the last pressed wins;
releasing it returns to the still-held direction. Releasing both centers steering.
Existing server steering smoothing is reused without adding an input ramp.
While DRIFT is held, digital left/right targets are limited to -0.60/+0.60.
Releasing DRIFT immediately restores -1/+1 for the held direction. This applies
with either forward hold or Auto Accelerate; legacy joystick input is unchanged.

The arrow/lock option beside the pad toggles forward hold (default OFF).
An open lock with an outline means OFF; a closed lock with a filled button means ON.
ON maintains forward throttle without holding forward; down still brakes
or reverses, and releasing resumes forward. Race transitions, seat loss, focus
loss, driving-touch cancellation and hidden/destroyed controls switch the hold OFF.

The left side has hold-to-drift and Nitro/Slick/Shield/Missile action icons.
Tap an available item once to use it while racing; counts and dimming show loadout
state. No separate mobile USE button or persistent selection checkmark is needed.
The cropped bottom-center steering wheel only displays steering; it accepts no input.

Mobile HUD icons are built from native UI shapes: a lightning bolt for Nitro,
a small car with winding skid marks for Slick, a shield for Shield, a missile
body/nose/fins for Missile. No external icon assets or packages
are required. The mobile speed panel is 160 x 56 with 0.30 background transparency;
it uses a separate full-screen overlay and `GuiService.TopbarInset` to align
with the Roblox top control band. Driving input is unchanged
by this visual polish.

Keyboard and touch share `KartInputController` and the existing `KartControl` /
`RaceItemControl` remotes. Server physics and item rules are unchanged.
`TouchDrivingModel.MobileDriveControlMode = "Buttons"` is the single developer
mode switch. Set it to `"Joystick"` before startup for rollback; the legacy
implementation and its tests remain available, with no player settings menu.
The legacy joystick dead zone defaults to 0.10 and can be tuned through the client
`RobloxKartTouchDriving.JoystickDeadZone` attribute (0–0.30).

Tilt, neutral calibration and Recenter are deferred to M1-B. Android/iPhone
usability and safe-area tuning still require real-device validation in M1-C.

Run `lune run tests/mobile_touch_validation.luau` for deterministic input,
touch ownership, lifecycle reset and layout checks. These mocks do not replace
Studio or real-device multi-touch testing. Add `Joystick` to that command to
run the retained legacy controller checks. Real-device approval requires repeated
intentional left/right Drift-to-Mini-Boost success. The user has confirmed
READY, release and Mini Boost on a real device, with acceptable boost frequency.
Drift charge thresholds and all kart physics are unchanged.

### TrackV2 Revision Required — Historical Gate

Superseded by R3B/R3C: Track02 Legacy V2 is preserved; refined Hard Circuit is Track03.

User device testing reports insufficient sustained drift arcs and arc length
for the current charge requirements, plus abrupt S-turns approaching Finish
and sections where a normal racing line effectively forces fence contact.
A separate geometry revision is required; this steering patch changes no track.
Future work should evaluate 2–3 continuous drift arcs (initial radius candidates
R100–R140) against actual physics and 0.60 steering, with 0.85–1.0 seconds of
on-road drift and a stable corner-exit approach to Finish. Revalidate centerline,
road width, checkpoints, barriers, grid, finish tangent, route progress, minimap,
lap counting, off-track/DNF behavior and Track01 when revising the geometry.

### Drift charge gauge and device diagnostics

One shared five-cell battery displays server charge for touch and keyboard:
`min(driftDuration / 1.00, qualifiedDuration / 0.75)`, clamped to 0–1.
Cells fill partially between the 20/40/60/80/100% boundaries; 0% is empty.
READY fills all five in gold and pulses the border once for 0.20 seconds.
The gauge appears in 0.12 seconds and fades for 0.30 seconds on drift termination;
a server-confirmed Mini Boost gives a brief full-gauge gold pulse before fading.
Failed attempts fade in cyan without a failure warning. No numbers or text appear
inside the player gauge.
READY latches once both charge requirements are met. Releasing DRIFT or centering
steering then starts Mini Boost if the same racer still has valid forward input,
enough speed, unlocked controls, and no off-track, barrier or Slick condition.
Unsafe termination, lost input, reverse, or leaving the race still cancels it.
Gauge attributes update at approximately 10 Hz, with immediate lifecycle clears.
The loadout row moves upward 20 pixels to leave room; the gauge has no touch input.
On mobile, its center aligns with the DRIFT button, with an 8px geometric gap
that leaves clearance for the 3px READY border pulse.
On PC it sits 10px above the clipped steering display, 140–160px wide and
18px high in compact viewports or 20px otherwise. The previous size was
110–150 by 16px; the lower cluster position creates clearance behind the kart.
Both platforms clip the bottom third of the same display-only wheel at the
screen with a 3px bottom margin. PC keeps its full 84px compact / 112px normal wheel diameter;
mobile keeps its existing size, clip ratio and steering synchronization.
Changing PreferredInput only relocates the single display; both layouts interpret
the same server progress. Keyboard Shift does not create local charge.

With `KartConfig.DEBUG_TELEMETRY`, the non-interactive development panel shows:

- `D` / `Q`: server drift / qualified-slip duration.
- `S`: slip angle; `IA`: current / maximum input age in this drift (not network RTT).
- `DT` (ASCII): current / maximum server Heartbeat duration.
- `V`, `T`, `St`, `Raw`, `IV`: forward speed, throttle, smoothed/raw steering, input validity.
- `END` / `BOOST`: last termination reason / actual boost eligibility, retained for two seconds.

The numeric panel is separate from the player battery: bottom-right on PC,
in the upper HUD area beside the minimap on wide mobile screens, or in the gap
below the speed panel on small landscape screens. It no longer sits beside the
kart. DEBUG=false creates no numeric overlay and keeps the player gauge functional.

Each ended drift also emits one `[KartDriftDiag]` server summary. A new drift resets
the maxima; the final timeout frame is included. Diagnostic attributes and text
are DEBUG-only, while the battery is available independently. No charge constants,
input timeouts, server delta cap or track geometry were changed.

On a newly published version and a fresh device session, test Practice Circuit:
Auto ON + sustained LEFT/RIGHT + DRIFT for 2+ seconds, then release DRIFT. Compare
with holding DRIFT while pulsing the direction button for approximately 0.5 seconds.
Capture the panel during charging and immediately after release.

| Observation | Follow-up diagnosis |
| --- | --- |
| Repeated `input_timeout`, max IA above 0.50 | Investigate client send gaps / transport; this is not a direct ping measurement. |
| D=1.00, Q below 0.75, slip mostly below 12°, normal IA/DT | Insufficient qualified slip; compare steering and threshold separately later. |
| Repeated max DT above 0.05 with slow D/Q | Investigate server hitches and discarded charge time; cap remains unchanged. |
| READY then `shift_release` or `steer_below_exit`, BOOST NO | Inspect throttle, speed, input validity and safety state. |
| Pulses raise slip above 12° and Q increases, sustained steering does not | Evidence for slip dynamics rather than assuming network latency. |

Run `lune run tests/drift_telemetry_validation.luau` for publication/diagnostic
contracts. The mobile and race-item suites also exercise gauge and production
drift/boost integration. Real-device cause identification still requires captures;
automated tests do not establish the cause on a phone.

## M1-A final beta polish

The mobile Drift gauge now has an 8px geometric gap above DRIFT. The shared
steering wheel clip sits 3px above the bottom edge; diameter, visible two-thirds
and steering behavior are unchanged. Mobile speed uses its own full-screen GUI
and the runtime GUI top inset to align with Roblox's top controls. PC speed
layout and the main race HUD's safe-area policy are unchanged.

A touch-preferred client sees a three-page DRIVE / DRIFT & BOOST / RACE ITEMS
guide on its first READY step of the session. A CONTROLS button on READY opens
it again. Closing it returns to READY and never sends the server Ready action.
The PC Garage card includes full-gauge release and item key hints.

After all checkpoints, a forward crossing just outside the StartFinish gate
increments `RaceFinishMissedSerial` and shows FINISH MISSED / RETURN TO FINISH
LINE for 1.8 seconds. The existing gate remains authoritative for lap completion;
wrong-direction and distant plane crossings do not trigger this guidance.

Practice and V2 receive sparse deterministic tree, lamp and rock speed cues
under `Environment/SpeedCues`. They have no collision, touch, query or shadow.
The cache version and object/part count attributes identify the generated world.
Track centerline, width, checkpoints and finish geometry are unchanged.

The user previously confirmed digital-pad Drift READY -> release -> Mini Boost
on a real device and an acceptable boost frequency. The READY controls tutorial
now shows its gameplay icons above the card and uses native five-segment Drift
gauge examples; the replay button reads CONTROLS. DRIVE shows the actual arrows
without a duplicate text row. A valid final finish fixes the official time and
lap history at the gate, then enters FINISHING / ROLL for a 2.4-second straight
deceleration with locked input, FINISH banner and sound. Once stopped, the
FINISHING / PRESENT phase moves the chase camera to a front view over 0.9 seconds
while the seated driver raises and waves the right arm when the rig has a shoulder Motor6D.
FINISHED holds that camera and wave and shows the result panel at the left of
the driver/kart scene. The panel shows total time, individual laps, displayed
centisecond-consistent deltas and best lap number. Rematch resets records and
restores the chase camera. Finish roll, lap breakdown, tutorial icons, front
view and driver wave were confirmed on a real device. Mobile separation between
the left result panel and Driver/Kart remains under final device tuning. The
mobile Finish view now uses camera-only screen composition during the late
ROLL to move the Kart image toward the right before the front view. The server
Finish Roll remains straight and unchanged. The narrower left results panel and
camera composition still need final real-device validation for visual separation.
M2-A0 prepared the server for multiple kart contexts. M2-A1 implements a
two-player beta on Practice Circuit Race. The user has since validated the R3
shared race on two real devices. The user also confirmed on a real mobile device
that cumulative progress reaches 5/5 without consecutive successes, the fifth
Mini Boost awards one Bonus Nitro, the awarded Nitro can be used, and Mini Boost
reaches 100 stud/s. The user also confirmed initial WAITING, START SOLO, Solo
Finish to REMATCH to WAITING, tutorial dismissal across a full rejoin, Quit Race
spacing, and the 15-second off-track DNF. The R4.5 item HUD placement also
passed on a real device at 3/5 and 5/5 with BONUS EARNED below the item cells.
Historical pending gates at M1: TrackV2 geometry revision and production-off telemetry.
Current track state is preserved Legacy V2 (Track02) plus accepted Hard Circuit (Track03);
public production telemetry must remain disabled.

### Engine loop asset decision

The current `ENGINE_LOOP` asset is `rbxassetid://6667206432` (catalog length
about 1.927 seconds). At 70 studs/s the existing dynamic pitch is about 1.29x,
so one source cycle is about 1.49 seconds. Real-device listening found a
periodic thump and roughly one-second brake-like tail, including at idle.
`Engine Sound Loop 7` (`6667206432`) is **rejected as the final continuous
engine-loop candidate**. Full-length and 0.05/0.10-second trim experiments did
not remove the sound. The source clip's changing tone/RPM may contribute;
the waveform was not independently analyzed. Repository audio controllers have
no separate normal Brake Sound. The current asset ID remains in place until a
new steady-state loop is selected and approved.

In Studio Play, use the Server Command Bar to select a mode for the first player:

```lua
game.Players:GetPlayers()[1]:SetAttribute("KartEngineLoopTestMode", "FIXED_FULL")
```

The developer diagnostic modes remain for reference; further trim tuning is
paused. `FIXED_FULL` plays the full asset at 1x; `FIXED_A/B` trim 0.05/0.10
seconds at each end at 1x; `DYNAMIC_A/B` use those regions with the existing
pitch response. For a future approved asset, compare idle, 70 studs/s and Mini
Boost, prioritizing 70. `[KartEngineDiag]` prints the loaded runtime length and
effective loop period once per mode. If the asset does not load within five
seconds, the mode uses the full asset and prints a warning. A missing or invalid
attribute means `NORMAL`; diagnostic modes work only in Studio or when
`DEBUG_TELEMETRY` is enabled. No player-facing setting or new audio asset is
included.
Approve a replacement only after 20–30 seconds of clean looping at idle and
70 studs/s, a natural 0 → 70 → 0 pitch change without a prerecorded braking
tail, and no click through Mini Boost/Nitro pitch changes. Prefer a constant
steady-RPM texture over a startup, throttle-blip or rev-up/release clip.

## Deferred

- Nitro Reward Challenge
- Obby
- Racer XP / Mastery
- gameplay progression DataStore
- Shop

## M2-A0 Multiplayer Foundation

**Historical behavior before R7-A1-R4.** Old one-shot Nitro, capacity/catalog lists
and milestone status here do not override the current contract above.

The server maps each Player to a `KartContext` holding that kart's chassis,
seat, controls, speed, Drift, Mini Boost, Nitro, Slick victim motion, barrier
response and Finish Roll state. `PrototypeWorld` runs one Heartbeat over the
registered contexts. `KartControl` still sends throttle, steering and Drift only;
the server resolves the caller's context and verifies its seat. Server physics
authority and tuning are unchanged.

One `RaceSession` owns the shared active track, match mode, participant map and
future finish-order hook. Each `RacerState` owns checkpoint/route progress,
lap timing, off-track timing, reset tracking and finish timing. Player Attributes
remain the replicated UI contract. RaceItem cleanup is player-specific;
Slick hazards carry a server-assigned owner and session, while Shield and hit
immunity remain separate for each player.

M2-A0 preserved the solo flow. The user validated Drift/Mini Boost, Nitro,
Slick, Shield, barrier recovery and Finish/Result/Rematch by driving in Studio.

## M2-A1 Validation and M2-B0 Public Race

**Historical behavior before R7-A1-R4.** Old one-shot Nitro, capacity/catalog lists
and milestone status here do not override the current contract above.

The Garage displays **KART DRIFT MASTERS** and the current Roblox PlaceVersion
as a small build label. Each actual Mini Boost start adds one cumulative point
toward a five-Boost reward during that race. At 5/5, the racer earns one Bonus
Nitro, at most once per race. Failed Drifts, off-track events, barriers, Slick,
and other driving incidents do not remove earned progress. The Race Item HUD
owns NITRO CHARGE progress and the award beside the Nitro/Slick/Shield loadout.
On mobile the counter uses the three-cell group width below those cells. The
current-attempt Drift gauge remains over DRIFT in its own HUD.
The compact LAP panel ends 4 px below QUIT RACE while that action is visible.
The last controls tutorial page offers **DON'T SHOW AGAIN**. This preference is
stored separately from race data; CONTROLS still opens the tutorial manually.

`Track01Race` (Base Circuit, **2 laps**) has one public lobby with a
capacity of four racers (`TrackCatalog.Entries.Track01Race.MaxPlayers`). `Track01` remains
solo with 1 lap; `Track02` remains solo with 3 laps. The first READY racer becomes
the lobby host. At 1/4 the host
may START SOLO; at 2/4 or 3/4 the host may START RACE or keep waiting. The fourth
READY racer starts the shared three-second countdown automatically. Other
racers see WAITING FOR HOST and may LEAVE without closing the lobby. Host LEAVE
transfers authority to the earliest remaining ReadyOrder. A single `RaceSession` owns
the countdown deadline and official start timestamp. The roster locks when
countdown begins. Each racer has a separate KartContext, grid slot and progress.

Live position is server-ranked by finish place, completed laps, checkpoints,
route fraction and ready order. Official finish place is assigned at the final
gate crossing, before the finish camera sequence. A finished racer leaves the
other racers driving. The session completes when all remaining racers finish or
DNF; a disconnect removes that racer without ending another racer's drive.
Multiplayer Rematch waits for every remaining participant to vote or leave.
One to three voters return to the start-grid WAITING FOR RACERS lobby; the host
may start at the current size or wait for more racers. Four votes from a full
four-racer round start a shared countdown automatically. Result UI closes when
voters enter the lobby. The original round size remains the position denominator
if someone quits, disconnects or DNF.
Released karts leave the race grid, and `KartOwnerUserId` identifies active
server-owned karts. The race minimap uses server-published `RaceMapPosition`
attributes at the 0.10-second ranking interval and shows rivals as orange
hollow rings around cyan local dots. The Garage shows players in the same server.

The user reported completing the M2-B0 Studio 1 Server / 4 Clients runtime check.
That check found a stalled on-track racer could keep a finished racer waiting
indefinitely. M2-B0-R1 starts a shared 45-second deadline at the first official
multiplayer finish gate crossing. Remaining racers keep normal controls and
items. The round completes early if everyone finishes, forfeits or DNF; at
expiry, racers still driving receive `RACE_TIMEOUT` DNF without an official
finish place or time. The original position denominator remains fixed. Finished
racers see the waiting countdown with Rematch disabled and Garage available;
drivers see a compact race-end warning in the LAP HUD. Solo races have no grace
timer. The user confirmed M2-B0-R1 RUNTIME PASS in Studio with 1 Server /
4 Clients: the flexible 1/4–4/4 lobby, same-server AVAILABLE / INVITE / JOIN,
revised WAITING panel, 45-second first-finisher grace, finished-racer countdown,
RACE_TIMEOUT DNF, and resolution of the infinite wait.
M2-B1 reads match type, capacity, laps and preview rotation from `TrackCatalog`.
Track Select and READY show each track's capability. Base Circuit's Garage
preview rotates 90 degrees clockwise; gameplay geometry and minimap stay in
their original orientation. In a waiting public lobby, racers see eligible
same-server Garage players. Only the host may send an in-game invite; JOIN is
optional and is revalidated through the normal READY admission path. The Garage
ONLINE list still shows everyone connected to that Roblox server.

The M2-B public server supports one active RaceSession and active track at a time.
The current published Roblox server size is 50; M2-B0 limits each public race
to four racers through TrackCatalog. The architecture may expand to six later.
A future friend/private room could offer a chosen capacity of 2, 3, 4 or 6 with
invites and possibly a reserved server; it is not implemented in M2-B1.
Different selected tracks may have different capacity; Prototype Circuit V2
remains solo until its geometry is validated for public multiplayer. The user
checked M2-B1 in Studio and on a mobile device. Screenshots exposed overlap
between the waiting title and availability panel. The user then confirmed
AVAILABLE IN SERVER, host INVITE, the RACE INVITE modal, JOIN, a three-player
race, and the revised waiting composition in Studio and on mobile. Fourth
invited JOIN auto-start has not been explicitly validated.

M2-B0-R2 isolates kart and seated-driver BaseParts, including late-added
accessories, using RacerKart and RacerDriver collision groups. Original avatar
groups are restored when the driver leaves the race kart. A per-kart upright
guard corrects sustained abnormal roll/pitch during RACING while preserving
planar heading and momentum. The user confirmed R2 RUNTIME PASS for close kart
contact: racers pass through without physical pushing or rollover. Forced
60–90 degree manual tilt recovery has not been separately device-validated.

### M3 MVP session routing

MVP requires independent race instances so another track's active session does
not normally block READY with "Racer not ready", "Track full", or "Grid full".
M3-A0 uses the current PlaceId in two roles: public HUB for Garage and track
selection, and reserved RACE server for one track, one RaceSession and its
racers. HUB Solo READY for Practice Circuit (Track01) and Prototype Circuit V2
(Track02) launches a new reserved server with a validated `KDM_RACE_V1` payload.
Base Circuit (Track01Race) retains the M2-B public 1–4 racer flow during this
phase. A Solo result's GARAGE returns to a public HUB; REMATCH stays in the same
reserved server and reuses the race stack. Published Roblox client testing is
required for actual teleport, return, and concurrent HUB Base/Solo behavior;
Studio does not support TeleportService playtests. The configured server size
remains 50: HUB may hold more users, while a reserved race's participant count
is constrained by its payload and TrackCatalog.

M3-A0 is CLOSED / RUNTIME PASS. Published PC/mobile testing confirmed
independent Practice and V2 reserved races, same-track and different-track Solo
instances, three simultaneous independent Solo races, Countdown/Race/Finish,
Solo REMATCH in the same reserved server, result GARAGE returning to public
HUB, and in-race QUIT returning to HUB Garage. Studio cannot validate real
TeleportService routing. The observed teleport handoff takes roughly one
second on tested devices and is acceptable. M3-P0 shows JOINING RACE after
Solo READY and RETURNING TO GARAGE during HUB return, restores controls after
failure, enlarges the mobile LAP-panel Quit target within Core UI safe insets,
and makes the same-server player list vertically scrollable. M3-P0 published
runtime checks passed for transitions, Solo launch, HUB return and local-list
scrolling. Known device polish: Galaxy Tab Quit Race touch may open Roblox Chat;
PC and regular phone did not reproduce it. This remains deferred.

M3-A1 Base Circuit rooms support 1–4 racers in independent reserved RACE
servers. The user confirmed three simultaneous Base START SOLO races on real
devices. M3-A1-R2 changes the Room lifecycle: CREATE reserves a Room server and
teleports the Host directly to GridSlot 1, where PRE_RACE waits with controls
locked. The same logical Room ID and reserved server remain in use across
rounds while a participant remains. JOIN admits a selected racer to the next
open grid slot in that Room; 2/4 and 3/4 wait for the Host to start, while 4/4
seated racers start automatically. Countdown locks the current round roster.
The Browser keeps WAITING, STARTING, RACING, FINISHING and ROUND_COMPLETE Rooms
visible, including full rooms. Active rounds offer QUEUE NEXT without mid-race
entry. After results, REMATCH returns the racer to staging; accepted queued
racers enter staging by Rematch, accepted invitation, prior rival, then public
priority, with FIFO order within a class. The Host can choose when to start a
sub-full next round. Room Browser x/4 describes room capacity; POS x/y counts
actual racers in the current round. `KDM_ActiveBaseRooms_v1` stores server-only
reservation data and separate staged, current-round and queued membership.
`KDM_HubPresence_v1` advertises only available HUB racers; short-lived invites
are delivered across servers and revalidated on acceptance. Reservation access
codes stay server-side; join tokens are short-lived and verified by the Room
server. Base round loadout remains Nitro/Slick/Shield
1/1/1 with Smoke 0. M3-A1-R2 is RUNTIME PASS / CLOSED after published real-device
checks: CREATE moved Host into a waiting persistent Room, JOIN reached the same
reserved server, active RACING remained Browser-visible for QUEUE NEXT, queued
racers entered the next round, REMATCH returned to WAITING, track Host invites
and queue flow worked, and valid 4/4 arrivals started automatically. When Host A
left, racer B became Host and the Browser name updated while logical Room ID and
queue stayed intact.

M3-A2 labels the same-HUB Garage player list LOBBY. A separate approximate
KDM ONLINE / LOBBY / IN RACE summary aggregates one short-lived presence record
per live HUB or RACE job. RACE includes reserved Base WAITING through results,
Practice and V2. Records refresh every 9 seconds and expire after 30 seconds;
departing HUB racers with a committed race launch leave the HUB count. A failed
aggregation shows KDM STATUS UPDATING rather than a fabricated zero. Room Browser
maps ROUND_COMPLETE to RESULTS, shows NEXT count, and keeps JOIN limited to an
open WAITING slot; active rounds offer QUEUE NEXT. Queued racers see their
position and staging transition. Host-only invite controls and compact Room/NEXT
status stay on track; results show next-round readiness. Directory list failure
retains the last Room list and shows ROOM STATUS UPDATING. Room expiry, failed
joining and failed teleport return players to a usable Browser with explicit
errors; staged slots are released. Cross-server metadata outages do not stop
local race gameplay.

### M3-A2 runtime closure and M3-A2-R1 mobile polish

**M3-A2 FUNCTIONAL RUNTIME: PASS / CLOSED.** The user confirmed published
runtime PASS for population updates (KDM ONLINE / LOBBY / IN RACE), RACING Room
Browser visibility, QUEUE NEXT, queue auto-promotion into the next round, queue
ordering/position, Host Migration with the same Room preserved, and stale-user
population expiry within the TTL window. These confirmed functional checks are
closed; mobile Population placement was the remaining layout failure.

M3-A2-R1 moves the mobile Population summary out of the right-side local player
list into a centered 14px status line below each Garage step header:
`KDM ONLINE 3 • LOBBY 2 • IN RACE 1`. Narrow headers use two lines, with
`KDM ONLINE 3` above `LOBBY 2 • IN RACE 1`. CoreUISafeInsets remain authoritative.
The local scrollable LOBBY player list stays separate, in a compact side gutter;
the desktop right-side population panel keeps its existing layout. Mobile invite
modals temporarily hide the summary; the Room modal retains its higher display
order. Population storage, Room/queue/host/teleport logic and gameplay are unchanged.

Automated Garage checks cover all four steps at 1600×739, 1280×720, 844×390 and
390×844, including simulated safe insets, navigation arrows, preview bounds,
action buttons, CONTROLS, BUILD PV, local LOBBY separation, modal precedence and
long counts (`KDM ONLINE 50 • LOBBY 38 • IN RACE 12`). Text width checks use a
conservative glyph budget and do not replace Roblox font/device rendering.
Initial R1 validation passed all 31 Luau validation suites plus the Joystick
variant (32 runs), including 412 Garage checks, Rojo build and `git diff --check`.
**M3-A2 aggregate Population mobile runtime: PASS.** The user confirmed
`KDM ONLINE 3 • LOBBY 3 • IN RACE 0` on published mobile after the initial
updating state. Preserve that summary's logic and centered Garage placement.

The follow-up R1 local LOBBY polish expands only the player-name panel to four
visible rows at 1600×739, 1280×720, 844×390 and 390×844. Its four-row height is
102px: a 20px header, 16px name rows, 2px row gaps and a 70px scroll viewport.
The existing fifth-and-later scrolling, name truncation and player-specific
join/leave updates remain. Landscape panels fit in the right gutter beyond the
carousel arrow, below CONTROLS and the title. Portrait panels stay below the
aggregate summary and above the arrow, falling back to fewer complete rows when
vertical space is limited (390×600 shows one). With simulated 16px side and 58px
top safe insets, tested panel widths are 140 / 108 / 65 / 54px respectively.
The Garage validation also checks 1/2/3/4/5/10/50 names, scroll retention and
separation from the approved aggregate status and selection controls.
The local-list patch passed all 32 validation runs, including 951 Garage checks,
Rojo build and `git diff --check`. Studio runtime NOT VERIFIED for this patch.
Published R1 local Lobby list: **Android PASS; iOS FAIL** — only approximately
one row was visible with `LOBBY 3`, while aggregate and local counts were correct.
M3-A2-R2 fixes the responsive width breakpoint: a landscape gutter narrower than
72px now stays in the landscape lane instead of falling into the short portrait
lane. No platform branch or additional safe-inset subtraction is used. The
already-safe parent bounds determine the available space; 1/2/3/4 players receive
1/2/3/4 complete 16px rows with 2px gaps. Panel height is 32px plus row content;
5+ players retain a 102px panel / 70px viewport with an expanding manual canvas.
Portrait keeps its constrained fallback. Smaller inner padding and reserving
scrollbar width only when needed improve compact name rendering.

R2 automated checks cover all four Garage steps at 1600×739, 1280×720, 844×390,
932×430 and 390×844, plus narrow notch-safe landscape and 390×600 fallback,
with 1/2/3/4/5/10/50-player simulations, complete last rows, control separation,
join/leave updates and scroll retention. Core Population / Room UX remains
**PASS / CLOSED**: aggregation, Room Browser, Queue Next, queue promotion/order,
Host migration and stale population expiry are confirmed published runtime.
**M3-A2-R2 PUBLISHED iOS VISUAL PASS / CLOSED.** The user confirmed the local
Lobby list now matches Android. **Android/iOS Lobby list parity PASS; M3 CLOSED.**
The historical automated R2 run did not verify Studio runtime.
R2 validation passed all 31 Luau suites plus the mobile Joystick variant (32
runs), Rojo build and `git diff --check`.

M2-A1-R2 adds a confirmed Quit Race action during RACING. The server treats an
accepted quit as a forfeit, returns that racer to Garage and leaves the opponent
driving. The continuous off-track DNF timeout is 15 seconds. Mini Boost Beta is
95 stud/s for 1.5 seconds with unchanged 65 acceleration; Nitro remains
100 stud/s for 3 seconds. A homing missile remains deferred.

R4 Mini Boost Beta 2 raises only the Mini Boost maximum speed and duration to
100 stud/s for 2.0 seconds. Acceleration remains 65; Nitro remains 100 stud/s
for 3 seconds with acceleration 75. Drift charge requirements, one bonus Nitro
per race, and the 50 stud/s off-track cap stay intact.
After READY, the Garage overlay now hides in `PRE_RACE` so the host sees the
waiting controls over the track while seated at the grid.
The user confirmed on a real mobile device that the initial WAITING FOR RACER
screen, START SOLO, solo two-lap Finish, and solo REMATCH return to WAITING work.

M2-A1 temporarily disables physical kart-to-kart collision through the
`RacerKart` collision group. Track and barrier collisions remain enabled.
Revisit this after synchronized-race validation. Same-Heartbeat finish ties use
official final time and then ready order; subframe photo-finish interpolation is
deferred. The user confirmed a real 2-player server/client race: separate
karts, 2-lap Finish/PLACE, Mini Boost, Nitro, Slick, Shield and multiplayer
item interactions passed. The subsequent R3 two-device test confirmed the
WAITING lobby, host START SOLO/CANCEL, same-track join, Rematch re-entry,
rival minimap, Garage presence, Quit Race, 95 stud/s Mini Boost, visible
progress indicator, and two-lap Finish/PLACE. That test also found that
the initial WAITING controls were covered by the Garage PREPARING GRID overlay;
the later Garage visibility fix was confirmed on a real mobile device.

The user's real-device check confirmed cumulative five-Boost progress, Bonus
Nitro +1 and its use, 100 stud/s Mini Boost, DON'T SHOW AGAIN across a full
close and rejoin with manual CONTROLS access, and the 15-second off-track DNF.
The Quit Race panel spacing is accepted. The previous mobile NITRO CHARGE
placement overlapped the loadout cells and clipped the label. The user has now
confirmed the R4.5 placement on a real mobile device: 3/5 and 5/5 with BONUS
EARNED remain below the item cells without overlap. M2-A1 is closed and
real-device validated.

## Known Polish Gates

- occasional ~0.1 sec driving/frame hitch
- driver seating height/posture

## Development

Generated by [Rojo](https://github.com/rojo-rbx/rojo) 7.7.0.

Do not treat generated RBXLX as source of truth. Source lives in `src/` and `default.project.json`.

To build the place from scratch, use:

```bash
rojo build -o "RobloxKart.rbxlx"
```

Next, open `RobloxKart.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).

## Git Rules

Work only on `prototype/kart-physics`.

Do not:

- modify `main`
- force push
- rebase
- blindly `git add .`
- publish Roblox without approval

## Next Development Order

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

## Driver appearance decision (2026-09-26)

Historical implemented appearance policy; superseded as a target by Roblox Avatar = Driver.
Stop forced recolor/hat hiding only during the approved staged migration.

- All drivers are shown without hats or helmets in Garage and races for now, so their faces and hairstyles remain visible.
- Current roster: Crimson, Azure, Sunburst. Nova and its procedural hairstyle were removed at the user's request.
- Revisit optional hats/helmets when character customization is expanded; do not restore mandatory headgear during visual refactors.

## Production release polish gate

- DEFERRED: Driver seating height / posture / hands / seat-shell fit.
- PV1-B designs around the existing Physics Seat; do not change Seat CFrame, humanoid seating, rig proportions, or hip height.

## Strategic RaceLoadout (C1-B)

**Historical behavior before R7-A1-R4.** Old one-shot Nitro, capacity/catalog lists
and milestone status here do not override the current contract above.

C1-A baseline: `be66348e599631775ce8293ca2c3a893a91df7a1`.

### Equal starting resources

Every new race/Rematch prepares Nitro 1, Slick 1, Shield 1, Missile 1, Smoke 0 by default during COUNTDOWN, in Studio and production. M4-A3 preserves approved tactical choices on Rematch and refills each active item to one. Selection is permitted during COUNTDOWN; use is blocked until RACING. Garage, Finish, DNF, reset and occupant loss clear temporary resources/effects. Grid seating during COUNTDOWN preserves prepared counts. Rematch refills all four and clears old hazards, Shield, Nitro, Missile incoming/projectiles/effects, immunity and preview.

RaceLoadout is server-authoritative temporary state, replacing RaceItemSlot. Inventory means future persistent Shop/ownership only. No persistent Inventory or DataStore is implemented.

- Maximum charges: Nitro 2, Slick 1, Shield 1, Missile 1; Smoke max 1 when chosen in M4-A3, zero in the default.
- PC 1/2/3/4 selects Nitro/Slick/Shield/Missile; Q uses the server-selected item. Mobile slots directly use that exact item while RACING via UseItem; Countdown taps do nothing. Valid desktop Countdown selection survives the authoritative GO refill.
- Accepted use consumes only that item; rejected use retains charges. Once empty, selection advances deterministically Nitro -> Slick -> Shield -> Missile -> Nitro. Keys override the selection at any time if charges remain.
- RaceItemControl accepts Select with one validated item ID, Use with no arguments, or UseItem with exactly one validated item ID while RACING. All activation uses the same server checks and throttle. Clients cannot grant charges or choose position/target/hit/speed effects. KartControl payload is unchanged.
- Race item HUD: four cells, desktop 88 x 48 each, compact PC 70 x 40 each; mobile 44–48px square cells in the safe GUI area. Desktop highlights selection; mobile uses bright available/dim empty action icons, with cyan Shield emphasis during incoming. Visible in COUNTDOWN and RACING.

### Slick / Shield

Slick drops 10 studs behind chassis, provisional R2 16 x 5 pad, 4-stud detection height, 10-second lifetime, 0.75-second owner grace. Server swept detection uses one controller loop, bounded to 16 hazards. Successful hit or block consumes the pad. Slick owns movement for 0.7 seconds, retains 55% speed and recovers toward legal road direction without vertical impulse. Barrier/off-track safety wins. It cancels Nitro, Mini Boost and Drift.

R2 audit found the old 7-stud width occupied only 11.7% of the 60-stud
Base Circuit / PracticeCircuitV1 road, so opposite racing lines could avoid it.
The old flattened oval and partial side accents also understated the rectangular
trigger corners. The new 16-stud footprint occupies 26.7%: lane denial, still
avoidable from the opposite side. A thicker dark rectangular oil surface and
four bright purple Neon edges show the same 16x5 planar bounds as the trigger;
there is no hidden larger footprint, auto-homing or placement under a rival.
DEPLOY / HIT / BLOCKED / EXPIRE server diagnostics report lifecycle events;
immune contact is logged once per hazard/target to avoid Heartbeat spam.

Attack resolution: valid target -> 1-second item hit immunity -> Shield -> offensive effect. Shield lasts 5 seconds or one block. It adds no speed and may coexist with Nitro. Cyan pulsing shell/orbit animation and BLOCKED feedback are preserved. Lifecycle boundaries clear effects.

World deploy: rear ejection -> 0.20-second travel -> splash -> 0.16-second pad reveal. Temporary splash parts clean at 0.42 seconds; trigger timing remains unchanged.

R2 Studio 1 Server / 2 Clients targeted audit PASS: Player1 used the real
Select/Use RemoteEvent, Slick charge 1->0 and deployment serial incremented.
Player2 observed `Workspace.Prototype.RaceItemHazards.SlickHazard` with correct
owner/session attributes, 16x5 surface at transparency 0, LocalTransparencyModifier
0 and four opaque Neon edges at .55 and 9.5 seconds; the hazard was gone at 10.5.
No persistent transparency or premature visual destruction was found. Initial
child replication may arrive after ChildAdded; the bounded reveal finishes by
approximately .36 seconds. A scripted Player2 swept crossing consumed the hazard
and activated the production Slick effect at speed 38.5. Anchored karts and
temporary Play-only staging were used for repeatability. Client projection placed
the opaque patch in view from the opposite lane at about 47 studs; real mobile
chase-camera readability and natural two-lane racing remain published checks.

Rear Deploy Preview: accepted Slick use replaces loadout display for 0.9 seconds. Lightweight WorldModel contains at most 64 current kart visual parts, a simplified road, drop, splash and pad. It is a rear-facing deployment replay, not live Workspace rendering. No track/world clone or main camera change. It cleans its scene/render connection on timeout, race exit, replacement or GUI destruction. BLOCKED interrupts it. Item input remains active throughout. Desktop 248 x 152; compact 176 x 112 at the existing lower-left anchor.

### Nitro / extra reward policy — historical C1-B

The one-shot grant API and optional gate/token below are historical/deferred;
R4 implements repeatable Drift rewards through RaceLoadout instead.

Current speeds: normal 70, Mini Boost 100 for 2.0 seconds, Nitro 100 for 3 seconds. Mini Boost acceleration is 65; Nitro acceleration 75 and smooth exit 15 stud/s per second remain. Brake priority, off-track cancellation and barrier cancellation remain.

Server-only RaceItemController.grantBonusNitro(player) permits one extra Nitro per player per race while RACING, maximum two. Before use: 1 -> 2; after use: 0 -> 1. Repeated reward calls reject. A new race resets reward eligibility. No client grant action exists.

Future reward gate/token: fixed location, equal opportunity, player-specific, once per race; one player never removes it for others. Prefer a small racing-line/risk tradeoff. Track gate placement is deferred.

### Product policy

Core MVP: equal starting loadout + optional one-time Nitro reward. Random Item Boxes are REMOVED from core MVP; they may be revisited for special modes/events. The old Studio sequential grants and follow-up Shield grant are removed.

License was deferred at the C1-B baseline; the C1-C implementation is described below.

At the C1-B baseline, Smoke gameplay, Inventory, DataStore, multiplayer and full License were not implemented. Physics Seat, driver seating, track, camera, kart colors/materials and physics tuning remained unchanged.

### Validation / Studio smoke

Run `lune run tests/race_item_validation.luau`, `lune run tests/kart_visual_validation.luau`, `rojo build -o <temporary-output>.rbxlx`, and `git diff --check`.

Results at that baseline: 157 RaceItem/Nitro checks; 8 rear preview lifecycle checks; 93 visual contract cases; 12 preview/framing cases; 38 Luau scripts compile. Movement tests use deterministic signal/time/physics-transport mocks and do not replace Studio physics.

Studio 896 x 414 basic smoke passed: 1/1/1 during countdown/start, 2/Q Slick world deployment and temporary matching-kart preview, HUD restoration with Slick=0, 3/Q Shield globe and Shield=0, Nitro activation/exhaust and Nitro=0, then fresh 1/1/1 on the actual Rematch button. A server command set DNF in the test session to reach Rematch without a full race. No full held-key speed run was performed by automation; the then-current 70/82/100 speeds, Nitro duration/exit and cancellation were covered by deterministic controller tests. Preview duration/cleanup is checked with a controlled clock at 0.89 and 0.91 seconds.

## C1-C - Permanent Practice and race selections

**Historical behavior before R7-A1-R4.** Old one-shot Nitro, capacity/catalog lists
and milestone status here do not override the current contract above.

Latest user decision replaces Driving License with always-available Practice. Garage remains Driver -> Kart -> Track -> Ready. No License tutorial, session completion flag, unlock gate, dedicated button or special completion result remains.

| Order | Selection | Catalog ID | Geometry | Laps |
| --- | --- | --- | --- | --- |
| 1 (default) | Practice Circuit - PRACTICE | Track01 | PracticeCircuitV1 | 1 |
| 2 | Base Circuit - PUBLIC RACE (1–4) | Track01Race | PracticeCircuitV1 | 2 |
| 3 | Prototype Circuit V2 - SOLO PROTOTYPE | Track02 | PrototypeCircuitV2 | 3 |

The first two selections share exactly the same geometry and grid positions. Track Select and Ready show SOLO PRACTICE / 1 LAP, PUBLIC RACE / 1–4 RACERS / 2 LAPS, or SOLO PROTOTYPE / 3 LAPS according to the selected track. No existing track geometry is modified. Server derives mode, capacity and target laps from the validated catalog selection, never client-provided mode or laps. One RaceController handles all modes; TrackCatalog.Entries[trackId].TargetLaps sets each track's lap count. RaceConfig.TOTAL_LAPS remains 3 as the fallback. Checkpoint order/direction checks remain.

All modes retain Nitro/Slick/Shield 1/1/1, normal FINISHED/DNF results and Rematch. Repeated Practice always stays one lap. No persistent progression, tutorial requirements or touch driving is added.

### Deferred polish gates

Previous apparent backward snap: user confirmed resolved. No automatic reverse command was found. Earlier camera correction is preserved, with no further camera/physics change for the separate hitch. Static require diagnostic removal is not established as a runtime hitch cause.

**PERFORMANCE POLISH GATE - BEFORE PRODUCTION RELEASE:** occasional ~0.1 second whole-screen visual/frame hitch during driving, possibly around Drift/Mini Boost transition. Root cause unknown; profiling required before release. No speculative workaround. Existing KartMotion diagnostics are event-triggered and limited to at most once per second.

**DRIVER SEATING - DEFERRED:** height/posture/hands/seat-shell fit.

### Validation

`tests/race_mode_validation.luau`: 59 integration checks covering catalog order, shared geometry/grid, all three lap targets, invalid gates, no License state, repeated Practice, actual controller results, loadout and Rematch.

Camera: 6 cases / 3,000 variable-frame samples. RaceItem: 157 checks (including 89 Slick/Shield/loadout), rear preview: 8, visual contract: 93, Garage framing: 12, Luau compile: 40 scripts.

Rojo output: `%TEMP%\RobloxKart-c1c-final.rbxlx`. User confirmed the revised three selections in Studio and explicitly approved commit/push.

## Lap recovery after brief track excursions

The reported V2 session detected Finish at 13:45:55.279 and 13:46:55.159, but was still waiting for CP4 and CP5 respectively. No lap invalidation occurred. Both tracks use the same ordered-checkpoint rules; entering a checkpoint off-road or missing its narrow volume could leave progress stuck for subsequent laps.

RaceRouteProgress now supplements gate detection using the same sampled centerline as TrackBuilder. Forward checkpoint crossings near the course (within twice its road width of the centerline) are provisional off-road and committed on returning to the road. Checkpoint order, finish direction, minimum lap time, fall resets and the 15-second continuous off-road DNF remain. Large position/projection jumps do not recover checkpoints. Finish rejection now logs the missing checkpoint explicitly. GO plays three higher beeps with cancellation on race exit.

Validation: `lune run tests/race_route_validation.luau` (both actual geometries, repeated laps, excursions, reverse and teleport/reset cases), `lune run tests/race_mode_validation.luau` (66 checks, including two V2 laps with excursions around CP4/5/6 and off-road DNF), and `lune run tests/race_audio_validation.luau` (3-2-1, three GO beeps, spacing/cancellation). These are deterministic tests, not Studio physics or audio playback verification.


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
