# Lobby demonstration bot

2026-10-16. User authorized implementation, Studio validation, commit/push and
Publish for the existing Kart Drift Masters place (127925465904803).

One shared demonstration runs only while at least one server player is in GARAGE
and is not departing through RACE_LAUNCH. Garage overlays and human test driving
remain Lobby activity. Empty, reserved and race servers do not run the demo.
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

## Validation

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
