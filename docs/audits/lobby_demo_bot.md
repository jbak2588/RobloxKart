# Lobby demonstration bot

2026-10-16. User authorized implementation, Studio validation, commit/push and
Publish for the existing Kart Drift Masters place (127925465904803).

Updated after v748: one shared demonstration runs while at least one player is
connected to this public Hub server, regardless of RaceState, route state or
human test driving. Only the last actual server departure removes it. Empty,
reserved and race servers do not run the demo.
Server audience signals create/remove one timeline; clients sample its shared
server clock for smooth motion and synchronized late arrivals. No per-frame
network pose stream, humanoid/seat ownership, racer registration or item state.

The existing front apron receives no geometry changes. A cyan V2 kart and native
seated helmet driver cruise the original stadium loop at 36 studs/second. At the
Lobby exit side, a tangent-connected 28-stud circle gives one full donut, smooth
32-degree visual slip, then rejoins the loop. The cycle is about 27 seconds;
the donut lasts about 4.9 seconds. These are presentation values, not changes to
human Lobby controls or racing physics. Two bounded native smoke emitters operate
only during the donut. All demo parts are anchored/noncolliding/non-touching/
non-querying. No purchase, persistent state, reward, new external asset or audio.

## v748 initial validation (historical)

- `lobby_demo_validation`: 25,893 checks PASS, including two cycles of swept full
  chassis clearance at 120 Hz, continuous joins, two-user audience/last departure,
  cancellation/return, reserved exclusion and listener teardown/restart.
- Existing showroom selection: 38 PASS; Garage transition: 6,384 PASS; Lobby mobile:
  7,796 PASS; complete loop: 4,753 PASS; Lobby policy: 1,051 PASS; training Drift:
  855 PASS; surface/Barrier: 814 PASS.
- Actual Studio iPhone 13 Pro landscape: production auto-start, one client bot,
  native driver and visible donut smoke inspected from the exit.
- 300 samples over 30 seconds: 43 active smoke samples, 257 cruise samples, all
  poses inside the actual apron, noncolliding parts and stable 73 descendants.
  No client error messages in the final run.
- Last audience state removal destroys server timeline and client bot/smoke;
  restoring GARAGE restarts them. Existing real Drive RemoteEvent successfully
  enters/seats Kart05 and exits while the demonstration remains present. Seven
  showroom TEST DRIVE prompts remain.
- Physical Android/iPhone and published multi-human acceptance are not established
  by this Studio run. The bot is an ambient visual demonstration, not a racer.

## Release

All 177 production sources match between the local tree and Studio Edit. All 177
compile; Rojo build and diff checks PASS. The native candidate copy is stored
locally at `artifacts/lobby-demo-bot/PRE_PUBLISH_NATIVE_CANDIDATE.rbxl` with SHA256
`a2c4ee5c309ff58108625eb266330278d355f58d1a2e6a7d5380b31285ba43a5`.
It preserves the existing native place; the Rojo validation scaffold was never
opened or published in its place.

Implementation commit `bd6463bcb04c9bd1020b47d8b52543a598068068` was pushed and
matched origin/prototype/kart-physics before Publish. Roblox Studio confirmed
successful publication to Kart Drift Masters and linked release **v748**, for
PlaceId **127925465904803** / UniverseId **10768420544**. The local publish log is
`artifacts/lobby-demo-bot/publish-output.txt`. This is publication confirmation,
not published multi-human/device acceptance. Studio was returned to Edit mode.

The pre-existing Studio PlayerPreferences API-access warning and unrelated asset
203785492 type warning were present; this task does not change either setting or
asset. No new demo client errors were observed.

## Follow-up: training Boost HUD and server occupancy

User requested BOOST CHARGE / BOOST READY terminology, wallet clearance, EXIT
KART alignment with visible Drift artwork, and a demo that lasts until the Hub
server is actually empty. The connected-player rule above supersedes the earlier
GARAGE audience rule and its historical state-removal acceptance.

Changed `src/client/LobbyTestDriveController.luau` and
`src/client/LobbyDriveLayout.luau`: training labels now say BOOST CHARGE n% and
BOOST READY / RELEASE. Actual wallet bounds determine the 12px clearance; label
and five-segment bar share a responsive width below it. EXIT KART uses the visible
Drift artwork edge instead of its wider transparent touch hitbox. Racing HUD and
charge/Boost physics are unchanged.

Changed `src/shared/LobbyDemoRoute.luau` and
`src/client/LobbyDemoController.luau`: connected users retain the same timeline
through gameplay and route state changes, including human test driving. Server
PlayerRemoving excludes the departing player immediately; only the last actual
departure clears the shared state. Updated `tests/lobby_demo_validation.luau` and
`tests/lobby_drive_mobile_fix_validation.luau` protect these rules.

Automated: demo 25,895 PASS; mobile/layout 7,814 PASS; training Drift 855 PASS;
showroom preview 38 PASS; Garage transition 6,384 PASS; Rojo build/diff PASS.
Actual Studio mobile runtime: wallet bottom Y=58, label Y=70, bar Y=96; EXIT
left X=22 and visible Drift X=22.5 (pixel rounding). BOOST CHARGE 0% and BOOST
READY / RELEASE checked against production UI. Real Drive/Stop entry/exit PASS.
Server and client demo remain present with an unchanged StartedAt through a
non-GARAGE connected state, then return to GARAGE. Studio returned to Edit.

This follow-up is a Git checkpoint, not a new Publish. Physical-device visual
acceptance remains unverified; published v748 remains the previous implementation.

## Follow-up: shared human smoke and quiet spatial audio

User explicitly authorized commit/push and Publish for this follow-up, including
the preceding Boost HUD/server-occupancy checkpoint. The demo no longer constructs
a separate short/faint particle profile. `src/client/KartWorldExhaustRenderer.luau`
exports its unchanged human smoke constructor and density calculation;
`src/client/LobbyDemoController.luau` consumes them with the same Lobby flag,
32-degree visual slip and near/far/slow-frame LOD policy. Human and race settings
are unchanged. Lobby smoke lifetime is 6.5-8.0 seconds, with the same white color,
size/opacity evolution, velocity, drag and 68 particles/second per-emitter cap.
Releasing the donut stops new emission while existing particles fade naturally.

`src/client/LobbyDemoFeedback.luau` reuses approved engine, friction and Mini Boost
audio assets from AudioConfig. Every connected client's shared-clock bot has four
world-parented Sounds (two engine crossfade voices, one friction loop, one Boost
cue); there is no server Sound pose stream and no global/2D announcement. Engine
uses the existing crossfade looper; friction uses the same 5-8 second region as
human training. Mini Boost fires once when the donut releases; late arrival during
an already-active boost does not replay a stale cue. Demo volume is 30% of the
corresponding direct training mix (engine .18, friction .18, Boost .225), with
InverseTapered attenuation from 12 to 180 studs. Existing SoundGroups still apply.
Destroying the bot stops/destroys all voices and disconnects its rendering.

`tests/lobby_demo_feedback_validation.luau`: 77 checks PASS, covering shared smoke
properties/rates, unchanged race density, relative volume, world parenting,
attenuation bounds, one-shot edges, late joining and audio destruction. Existing
remote world VFX 1,402, demo geometry/lifecycle 25,895, mobile/layout 7,814, Garage
transition 6,384 and showroom 38 checks PASS. Kart audio validation PASS. The
existing boost-flame-fade test fails its redrift residual-clear assertion; the
exact pre-task renderer also reproduces that failure in an isolated fixture.

Studio: real Kart05 human test drive and demo smoke match all 14 compared profile
fields. All four demo Sounds load; engine and friction play at .18 with correct
assets, spatial mode and distance limits. The full live cycle and final release
outcome are recorded below after verification. Real-device listening/performance
and published multi-human acceptance remain separate from this Studio evidence.

Final live sample: 320 samples over 32 seconds, 43 drift / 277 cruise samples,
one Boost cue, max smoke rate 68, stable 77 descendants and zero new client errors.
Native mobile view confirms dense smoke. Zone teardown stops and destroys all
four sound voices, removes bot effects and produces no callback errors. All 178
production sources compile and match Studio Edit; Rojo build/diff PASS.

Release: implementation commit `6151c0f98454b1876f2f8f60fa4e46bba278d7a9` was
pushed and matched origin before Publish. Native feedback candidate contains all
178 exact committed production sources and no Play-only bot/audit objects; SHA256
`1ef6a069eccd218db36eab75cf397a32b3ef0f9a63e0494e0c4c421829b130c6`.
Studio confirmed successful publication of Kart Drift Masters, PlaceId
127925465904803 / UniverseId 10768420544, and linked **v750**. Confirmation is in
`artifacts/lobby-demo-bot/feedback-publish-output.txt`; the preserved native copy
is `artifacts/lobby-demo-bot/DEMO_FEEDBACK_NATIVE_CANDIDATE.rbxl`.
This release also includes the preceding Boost HUD and connected-player lifetime
checkpoint. Studio remains in Edit. Published real-device listening, perceived
distance balance and multi-human performance remain unverified.

## Follow-up: Mini Boost flame and actual kart size check

User authorized commit/push and Publish. `src/client/KartWorldExhaustRenderer.luau`
provides a showcase adapter that clones the same two native exhaust attachments
and six ParticleEmitters used by human karts. Active Mini Boost uses the same 70%
template emission rate and observer LOD, original sizes/colors and PointLights.
`src/client/LobbyDemoController.luau` drives these from the existing two-second
shared-clock DemoBoosting phase, with existing audio timing and cleanup. The
showcase continues on its existing route; racing/human physics are unchanged.
At its normal 36-stud presentation speed, release clears flame particles instead
of leaving a high-speed tail. No additional effects are allocated per lap.

Actual Studio Kart05 comparison: both model scales are exactly 1. All 22 geometry
BaseParts match by relative path, Size and MeshId; no mismatches. Human bounds
6.902905 x 2.663242 x 9.324319 studs; bot bounds match within floating point
rounding. Both use KartVisualFactory.createVisual. The actual kart is already
the same size, so no artificial enlargement or geometry change was made.

`tests/lobby_demo_boost_validation.luau`: 57 checks PASS for original template
count, Mini Boost density, full/half/zero LOD, 100 repeated cycles, release and
cleanup (plus 25 underlying production world-VFX checks). Existing feedback 77,
remote world VFX 1,402, demo 25,895 and showroom 38 checks PASS. All 178 production
sources compile; Rojo build/diff PASS. Actual Studio mobile view confirms twin
blue-white flame plumes at donut release. The final runtime audit and release
confirmation follow below after verification.

Final runtime: 320 samples over 32 seconds, 114 enabled and 1,806 disabled emitter
samples, stable 87 descendants, zero new client errors; both cloned template
attachments are destroyed on zone teardown. All 178 Studio Edit source hashes
match the committed tree. Implementation commit
`7c6a7c52e696afdf8cd754ba70da5c1402659af3` was pushed and matched origin before
Publish. Studio confirmed successful publication to the existing Kart Drift
Masters place and linked **v751** (PlaceId 127925465904803, UniverseId 10768420544).
Evidence: `artifacts/lobby-demo-bot/boost-publish-output.txt`. The existing native
place was published directly; no Rojo validation scaffold was opened. Studio
remains in Edit. Actual published multi-human/mobile visual acceptance remains
unverified.

## Follow-up: three mixed routes, corner friction and 12% showcase enlargement

User confirmed published mobile v751 boost flames PASS and explicitly authorized
three route variations, smoke/friction on all bot turns, 10-15% enlargement,
commit/push and Publish. This supersedes the earlier single-loop/same-size bot
presentation contract; human kart geometry and controls remain unchanged.

`src/shared/LobbyDemoRoute.luau` now shares a deterministic 84-second sequence:
WIDE_LOOP (one exit donut plus stadium loop), S_SLALOM (one donut plus left/right
S-weaves), DOUBLE_DONUT (two tighter exit donuts plus loop). Durations are about
26.95 / 27.31 / 29.74 seconds. Patterns share position and forward tangent at their
joins; a startup arc-length table keeps the 36-stud/second presentation speed
continuous, with binary sampling and no per-frame path allocations. Late joiners
sample the same server timeline. Boost flame/audio windows remain two seconds
after each pattern's exit donut.

`src/client/LobbyDemoController.luau` uses the allowed bot-only visual steering
fallback: every curved segment, in either direction, requests the shared human
smoke and friction audio regardless of charge. Signed visual slip eases smoothly
between directions. This is an ambient display, not human Drift-key automation;
no Drift awards, RaceLoadout, Mini Boost physics or human steering rules change.
Existing distance/frame-rate effect LOD still applies.

The complete bot geometry/driver/anchors are scaled once by 1.12 before shared
particles/flames are attached, preserving their human smoke/effect profiles.
Actual Studio comparison against human Kart05: all 22 BaseParts are exactly 12%
larger (within float rounding), bot model scale 1.120000005, human scale 1.
Bot visual bounds are 7.725293 x 2.982832 x 10.443239 studs. Smoke still lasts
6.5-8 seconds. No factory, catalog, race, human test-drive or track-geometry edits.

`tests/lobby_demo_validation.luau` sweeps all patterns over two complete cycles,
including conservative enlarged sideways footprint clearance, both steering
directions, per-bend friction, constant speed, tangent-safe joins and audience
lifecycle. Existing boost template 57, feedback 77, remote VFX 1,402, showroom 38,
mobile/layout 7,814 and kart audio validations PASS. All 178 sources compile;
Rojo build/diff PASS. Actual Studio runtime sequence and release follow below.

Final automated route result: 181,460 PASS. Actual approximately 87-second Studio
sample: 779 samples, all three patterns seen, 70 left / 473 right turn samples,
1,086 active smoke-emitter samples and 64 Boost samples; model remains bounded at
87 descendants, bot scale 1.120000005. Conservative enlarged footprint stays on
the existing apron throughout; no new client errors. Real human Kart05 Drive/
Stop still works alongside the demo. Enlarged bot/feedback teardown PASS.

Release: all 178 production source hashes match Studio Edit. Implementation
commit `4811872c6bba354508f53050e9f4f783a9f3d1f3` was pushed and matched origin
before publication. Studio confirmed successful publication to the existing
Kart Drift Masters place and linked **v752**, PlaceId 127925465904803 / UniverseId
10768420544. Evidence: `artifacts/lobby-demo-bot/patterns-publish-output.txt`.
Existing native place published directly; Studio remains in Edit. User's mobile
boost-flame acceptance applies to v751; the new three-pattern/12% presentation
still requires published device acceptance.

## Follow-up: one drift-only lap in each Lobby side wing

User explicitly authorized implementation, commit/push and Publish after the
side-space feasibility review. Baseline: `07a7f12`, matching origin before work.
Only the shared presentation route changes; existing native building, paving,
barriers, human controls/physics, effects and 1.12 bot scale are preserved.

The shared sequence is now WIDE_LOOP, S_SLALOM, RIGHT_SIDE_DRIFT, DOUBLE_DONUT,
LEFT_SIDE_DRIFT. One cycle lasts 153.18 seconds. The right excursion lasts 32.73
seconds including approach/return, with one radius-50 circle centered at zone
local (170,134). The left lasts 36.46 seconds, with one radius-35 circle at
(-275,134). Curved entry/return paths share forward tangents at joins and keep
the central building recess clear. Both complete side excursions explicitly
return `boosting=false`: no flame or boost-launch sound, while turns use the
existing human-profile drift smoke and quiet spatial friction audio.

Automated validation: 391,410 route/footprint/continuity/audience/lifecycle checks
PASS across two full cycles. Coverage includes one full revolution per side,
no boost throughout entry/circle/return, continuous circle drift, conservative
12%-enlarged sideways bounds and bounded heading changes across every sample.
A 20 Hz clearance probe measured minimum enlarged-corner road-boundary clearance
of 21.15 studs on the right excursion and 16.90 on the left. Shared boost 57,
feedback 77, world VFX and kart audio checks PASS; all 178 production sources
compile, Rojo build and diff check PASS. Studio/release evidence follows below.

Actual Studio Play: 158.26 seconds / 1,899 samples, all five patterns observed,
zero side boost violations and zero circle drift-state failures. Both side
circles had playing spatial friction audio. The left circle recorded 150 active
smoke-emitter samples at close range. Right-wing close-range replay: 96 samples,
190 active smoke-emitter samples, 96 playing friction samples, no drift failures,
no active boost flames and no boost-start sound. Earlier distant right-wing
samples correctly had smoke suppressed by existing distance LOD. The model stayed
bounded at 87 descendants; no bot-module runtime errors. Existing Studio API /
Core UI warnings remain separate from this route change. Returned to Edit with
no Play bot; all 178 production source hashes match the local files.

Release: implementation commit `a4e8892ef28dcc8354cce0c5c7ca99a1b7c626ad` was
pushed to `origin/prototype/kart-physics` with matching HEADs before Publish.
Studio confirmed successful publication to the existing Kart Drift Masters
place and linked **v755**, PlaceId 127925465904803 / UniverseId 10768420544.
Evidence: `artifacts/lobby-demo-bot/side-publish-output.txt`. The existing native
place was published directly; no Rojo validation scaffold was opened. Studio
remains in Edit. Published mobile visual acceptance of the added side excursions
remains unverified.
