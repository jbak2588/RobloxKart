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

Driver → Kart → Track → Ready → Race → Result

Current track selections:

1. Practice Circuit — Solo Practice — 1 Lap
2. Base Circuit — Public Race — 1–4 Racers — 2 Laps
3. Prototype Circuit V2 — Solo Prototype — 3 Laps

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
- Smoke 0 (deferred)

PC controls: `1` Nitro / `2` Slick / `3` Shield / `4` Missile; `Q` = use.

RaceLoadout is temporary. Inventory is reserved for future persistent Shop ownership.

## Production Kart

Sprint V1

Colors: Red, White, Blue, Yellow.

## Current Priority

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
Incoming counts support multiple projectiles. The client supplies only Select
and Use actions, never a target, position or hit report.

`RaceItemController` owns target acquisition, loadout consumption and the shared
valid target → immunity → Shield → effect path. `HomingMissileService` owns
the 1.50-second warning, fixed target, Heartbeat flight and cleanup. Incoming
feedback publishes immediately; projectile flight waits for the full window. It moves
noncolliding native geometry at 165 stud/s, turning at up to 8 rad/sec, with a
7-second flight lifetime and 5.5-stud relative swept hit radius. Up to 16 active
records (including warnings) are allowed. Targets never change after acceptance;
invalid racers, changed sessions/rounds, reset karts and owner departure expire
the projectile safely. A small native impact flash lasts 0.2 seconds. Wall
collision/path following and production combat VFX/audio are deferred to polish.

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
Shield recommendation UI and a physical slowing hit. This does not close M4-A0.
R1 extends slowdown from 1.25 to 2.50 seconds and moves the four-slot HUD away
from the central Kart view. A forced lateral/outside push remains a future tuning
candidate only; R1 adds no push or impulse.

R1 published mobile retest PASS, confirmed by the user: left-aligned four-item
HUD and clearly felt Missile 55 / 2.50-second slowdown. The 0.75-second warning
was too short for mobile Shield select -> USE, and Slick was not visible/effective
to the trailing racer. R2 gives a 1.50-second reaction window and audits/widens
Slick as described below. M4-A0 remains OPEN.

R2 published runtime PASS, confirmed by the user: Missile targeting/fire and
55 / 2.50-second slowdown, Slick visible to the following racer and its hit/effect,
and the mobile four-item HUD. Mobile Shield select -> USE remains too difficult
even with the 1.50-second warning; M4-A0 remains OPEN.

**M4-A0-R3 CODE COMPLETE — PUBLISHED EMERGENCY SHIELD RETEST REQUIRED.**
During RACING with an incoming Missile, tapping the mobile Shield slot sends one
payload-free `EmergencyShield` request. The server checks its own incoming record,
loadout, charge, active Kart and existing Shield before activating and consuming
exactly one Shield. Rejections consume nothing. This remains manual defense with
the same five-second/one-attack Shield; multiple incoming Missiles do not create
extra Shields. A cyan border, `!` and `TAP SHIELD` emphasize the existing slot,
including during cosmetic Slick feedback. Outside incoming warnings, mobile
selection -> USE and PC controls are unchanged. Warning stays 1.50 seconds;
Missile/Slick balance, physics and M3 behavior are unchanged.
R3 Studio runtime NOT VERIFIED. Published Android/iPhone retests must cover
one-tap activation, empty/already-active Shield, warning expiry before receipt,
normal selection/use, duplicate taps and multiple incoming Missiles. Leader
rejection and 3–4-player immediate targeting remain required. Automated tests
do not establish device touch or published counterplay PASS.
Production KartContext tests enforce cap 55 every simulation
step, with active samples at 0.25, 1.00, 1.50, 2.25 and 2.49 seconds, followed by
normal acceleration after 2.50 seconds; braking/throttle and Shield are covered.
AUTO TEST PASS: all 33 `*_validation.luau` suites plus Joystick (34 runs),
including focused Missile, production KartContext and mobile layout coverage.
Rojo build and `git diff --check` PASS. This is not PUBLISHED RUNTIME PASS.

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

The left side has icon buttons for hold-to-drift, Nitro/Slick/Shield/Missile selection,
and using the selected item. Counts and a selection checkmark show loadout state.
The cropped bottom-center steering wheel only displays steering; it accepts no input.

Mobile HUD icons are built from native UI shapes: a lightning bolt for Nitro,
a small car with winding skid marks for Slick, a shield for Shield, a missile
body/nose/fins for Missile, and a finger
pressing a circular trigger for item activation. No external icon assets or packages
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

### TrackV2 Revision Required

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
TrackV2 geometry revision and production-off debug telemetry remain pending.

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
- Smoke gameplay
- Racer XP / Mastery
- gameplay progression DataStore
- Shop

## M2-A0 Multiplayer Foundation

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

1. M3-A2-R1 published mobile local LOBBY four-row visual validation
2. Combat expansion / Missile, then additional track and public capacity work
3. Persistence, Shop and cosmetics as scheduled

## Driver appearance decision (2026-09-26)

- All drivers are shown without hats or helmets in Garage and races for now, so their faces and hairstyles remain visible.
- Current roster: Crimson, Azure, Sunburst. Nova and its procedural hairstyle were removed at the user's request.
- Revisit optional hats/helmets when character customization is expanded; do not restore mandatory headgear during visual refactors.

## Production release polish gate

- DEFERRED: Driver seating height / posture / hands / seat-shell fit.
- PV1-B designs around the existing Physics Seat; do not change Seat CFrame, humanoid seating, rig proportions, or hip height.

## Strategic RaceLoadout (C1-B)

C1-A baseline: `be66348e599631775ce8293ca2c3a893a91df7a1`.

### Equal starting resources

Every new race/Rematch prepares Nitro 1, Slick 1, Shield 1, Missile 1, Smoke 0 during COUNTDOWN, in Studio and production. Selection is permitted during COUNTDOWN; use is blocked until RACING. Garage, Finish, DNF, reset and occupant loss clear temporary resources/effects. Grid seating during COUNTDOWN preserves prepared counts. Rematch refills all four and clears old hazards, Shield, Nitro, Missile incoming/projectiles/effects, immunity and preview.

RaceLoadout is server-authoritative temporary state, replacing RaceItemSlot. Inventory means future persistent Shop/ownership only. No persistent Inventory or DataStore is implemented.

- Maximum charges: Nitro 2, Slick 1, Shield 1, Missile 1; Smoke deferred.
- PC 1/2/3/4 selects Nitro/Slick/Shield/Missile; Q uses the server-selected item. Mobile item cells select normally; the Use button calls useRaceItem(). Only the Shield slot during RACING with incoming Missiles sends the atomic EmergencyShield request for immediate manual defense.
- Accepted use consumes only that item; rejected use retains charges. Once empty, selection advances deterministically Nitro -> Slick -> Shield -> Missile -> Nitro. Keys override the selection at any time if charges remain.
- RaceItemControl accepts Select with one validated item ID, Use with no arguments, or payload-free EmergencyShield during server-confirmed incoming Missiles in RACING. Clients cannot grant charges or choose position/target/hit/speed effects. KartControl payload is unchanged.
- Race item HUD: four cells, desktop 88 x 48 each, compact PC 70 x 40 each; mobile 44–48px square cells in the safe GUI area. Available selected cell highlighted; empty cells dimmed. Visible in COUNTDOWN and RACING.

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

### Nitro / extra reward policy

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
