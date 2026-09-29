# AGENTS.md — Kart Drift Masters

Read this before editing the project.

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

## Current C2-A Warning

Nitro Reward Challenge is DEFERRED.

It was not approved for commit.

Possible local experimental files may include:

RaceReward*
Nitro Core / Entry / Exit
Reward UI/tests

Before new development:

inspect git status/diff.

Remove only C2-A-specific uncommitted changes.

Do not remove unrelated changes.

## Approved Current Flow

Driver
→ Kart
→ Track
→ Ready
→ Countdown
→ RACING
→ FINISHING (ROLL → PRESENT)
→ FINISHED / Result

Off-track DNF remains a separate result path.

Tracks:

Track01
Practice
1 Lap

Track01Race
Base Circuit Public Race (1–4 racers)
2 Laps

Track02
Prototype Circuit V2 Solo Prototype
3 Laps

Do not re-add a separate Driving License flow unless explicitly requested.

## Driving Invariants

Normal:
70

Off-track:
50

Reverse:
24

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

Every Race / Rematch:

Nitro = 1
Slick = 1
Shield = 1
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
Q Use

## Slick

~10 studs behind Kart
7 x 5 pad
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

## Production Kart

Sprint V1

Colors:

Red
White
Blue
Yellow

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

M2-A1 two-player Practice Circuit Race and R4.5 NITRO CHARGE placement passed
the user's real-device checks. M2-B0 expands the public race to four players;
TrackV2 geometry revision remains pending.

Do NOT add XP / Shop / Reward systems first.

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

Auto Accelerate toggle, DRIFT, tappable RaceLoadout selection and Item Use.
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

TrackV2 geometry revision remains pending. M1-B finish presentation needs
real-device validation. Set `DEBUG_TELEMETRY = false` before public production.
The current EngineLoop asset `6667206432` is rejected for production: real-device
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
Smoke
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

M2-B0 temporary policy: RacerKart parts do not physically collide with other
RacerKart parts; track/barrier contact remains unchanged. Revisit after four-racer
runtime validation.

The user reported completing the M2-B0 Studio 1 Server / 4 Clients validation.
That check found a stationary on-track racer could keep a finisher waiting
indefinitely. M2-B0-R1 adds a session-owned 45-second deadline starting at the
first official multiplayer finish gate. Racing opponents retain normal control
and items until they finish, quit, DNF or time out. Remaining racers at expiry
receive `RACE_TIMEOUT` DNF without a finish place/time. All terminal results
complete the round early, while solo races retain their existing lifecycle.
Finished racers see a waiting countdown with Rematch disabled and Garage
available; active racers see a compact LAP HUD warning. R1 Studio/device runtime
verification is still required.
M2-B1 makes TrackCatalog authoritative for match type, minimum/maximum racers,
laps and Garage preview rotation. Practice Circuit is solo practice (1 lap),
Base Circuit is public 1–4 (2 laps), and Prototype Circuit V2 remains solo
prototype (3 laps) until separate geometry validation. Only Base Circuit's
Garage preview rotates 90 degrees clockwise; gameplay orientation is unchanged.
Waiting public lobbies show eligible same-server Garage racers. Only the current
host may invite, and joining revalidates the invitation through normal READY.
The Garage ONLINE list continues to include all players on that server.
The MVP supports one active RaceSession / track at a time. Four-player server
capacity is recommended for the public beta. The user checked M2-B1 in Studio
and on mobile; screenshots exposed a waiting-title overlap with the availability
panel. The title was moved into that panel, so the revised composition still
needs a device recheck.

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

Current:

tests/camera_motion_validation.luau
tests/mobile_touch_validation.luau
tests/drift_telemetry_validation.luau
tests/kart_visual_validation.luau
tests/race_item_validation.luau
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
