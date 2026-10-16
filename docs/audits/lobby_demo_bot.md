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

Production source parity, compilation/build, Git checkpoint and Publish outcome
are recorded after the final release checks.
