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
