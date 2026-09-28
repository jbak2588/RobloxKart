# AGENTS.md — RobloxKart / Kart Master

Read this before editing the project.

## Mission

Commercial mobile-first Roblox arcade kart racing game.

Working titles:

RobloxKart
Kart Master

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
Practice Circuit Race
3 Laps

Track02
Prototype Circuit V2 Race
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
82
1 sec

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

2-player Multiplayer after M1-B real-device finish presentation validation.
Use Practice Circuit Race first; TrackV2 geometry revision remains pending.

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

PC and Mobile share the server-authoritative five-segment Drift gauge. READY is
Gold; releasing Drift triggers an eligible Mini Boost.

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
The periodic EngineLoop thump is under developer A/B listening diagnosis;
the trim candidates are not approved production audio settings.

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

After M1-B real-device validation, start with 2 players on Practice Circuit
Race, then expand:

2 players
→ 4
→ 6

Before Multiplayer audit:

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

Do not start Multiplayer until the M1-B presentation receives real-device
validation and the user authorizes that work.
