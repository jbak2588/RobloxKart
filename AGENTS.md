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

Approved remote baseline:

83c24303ccf5485d51dff6c99e1554ce3f3a4a8f

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
→ Race
→ Result

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

Mobile Touch Driving + Tilt Steering Option v1.

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
optional

Gyroscope unavailable:
Touch fallback

## Tilt Steering

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

Expected:

Touch/Tilt steering
GAS
BRAKE / REVERSE
DRIFT
ITEM

RaceLoadout cells should be tappable.

Do not recreate every keyboard key as a separate mobile button.

## Mobile Steering HUD

Reuse current circular steering indicator first.

Target:

bottom-center
bottom ~1/3 cropped below screen
upper ~2/3 visible

Wheel should show actual steering input.

Half-oval design is future polish.

## Known Issues

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

After Mobile controls:

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
tests/kart_visual_validation.luau
tests/race_item_validation.luau
tests/race_mode_validation.luau

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

## Recommended Next Split

M1-A:
- common input abstraction
- Touch steering
- GAS
- BRAKE/REVERSE
- DRIFT
- ITEM
- tappable RaceLoadout
- steering HUD mobile placement

M1-B:
- Tilt Steering
- Neutral capture
- Recenter
- gyro fallback
- dead-zone/sensitivity/smoothing

M1-C:
- Android/iPhone tuning
- safe areas
- Practice/Race regression

Do not start Multiplayer until mobile driving is actually usable.