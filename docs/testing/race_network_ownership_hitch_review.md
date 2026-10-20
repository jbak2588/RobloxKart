# Race motion hitch investigation — 2026-10-20

## Scope and baseline

User report: iPhone 12 Pro Max, published PV925, recording disabled; recurring
roughly four-second hitch even with one human and the Rookie Bot, and apparent
forward/backward jumps of nearby racers.

Started from a clean `prototype/kart-physics` checkout at
`4dc718d32aa18be45e41e086f61f5c7786c95b69`, matching fetched origin.
PrototypeWorld, RaceController, RaceBotController, KartInputController,
KartCameraController, ChaseCameraMotion and RaceHudController match the approved
PV925 Git baseline `fbf334e15aec62d8d3834c2d5589c43e30fee235`.
This is a source comparison, not a readback of code from a live PV925 server.

## Reproduced defect and repair

Kart creation explicitly calls `chassis:SetNetworkOwner(nil)`. Human seating
subsequently joins the character through SeatWeld; the joined assembly was
observed with automatic network ownership enabled. Under server velocity writes,
ownership periodically changed to the client and back. The production bot already
finalizes server ownership after seating and did not exhibit this handoff.

PrototypeWorld now defers a server ownership assertion after the owner's
Occupant event. Before writing it checks the current owner, kart/chassis parents,
and both sides of the Seat/Humanoid relationship. There is no per-frame ownership
write, new remote, input change, interpolation layer or physics tuning change.

## Native Studio A/B measurement

An isolated local place (`GameId=0`, `PlaceId=0`) used production Figure 8
geometry, a human-context kart driven by a temporary deterministic steering
wrapper, and the normal Rookie Bot. Temporary harness flags route the existing
bot test bootstrap to Figure 8 and start race client controllers. This is not a
real reserved server or an iPhone performance measurement. The bootstrap also
initializes HUB services. Both captures used the same harness, with only the
production ownership repair changed between runs.

| Measurement | Before | After |
| --- | ---: | ---: |
| Server capture | 42.015 s / 2,521 samples | 42.015 s / 2,521 samples |
| Client capture | 40.016 s / 2,401 samples | 40.014 s / 2,401 samples |
| Automatic ownership samples, human | 2,521 | 0 |
| Client ownership pulses | 13 | 0 |
| Human motion stalls in client capture | 13 groups / 151 samples | 0 |
| Duration of each stall group | about 0.17–0.20 s | none observed |
| Bot stationary samples while previously moving >30 studs/s | 0 | 0 |
| Human p95 absolute displacement residual | 1.183 studs | 0.093 studs |
| Client frame p95 / max | 17.878 / 20.679 ms | 17.888 / 20.937 ms |
| Client frames >33.33 ms | 0 | 0 |

Before repair the first handoff occurred at 2.832 seconds of the client capture;
subsequent handoffs repeated about every 3.0 seconds. The motion stall clusters
followed these pulses. The user's approximate four-second interval need not be
identical to this local measurement.

A stall sample means projected client position displacement <0.01 studs while
the previous planar velocity exceeds 30 studs/s. Residual compares displacement
along that velocity with velocity × elapsed time. World-space reverse steps were
not observed in either run. The local kart/camera stall can change the apparent
relative position of a continuously moving rival; this supports the reported
ahead/behind appearance without claiming that a rival actually reversed.

These results establish a reproducible ownership/replication defect and its local
removal. They do not prove that every mobile hitch has the same cause or establish
published four-human acceptance. First-download asset work and mobile CPU/GPU/GC
spikes remain separate possibilities if symptoms persist after deployment.

## Validation and boundaries

- New production-context test: 17 checks, including four seating cycles, deferred
  execution, unseating, incomplete seating, owner release and removed/destroyed
  context guards. These lifecycle checks use deterministic mocks.
- Four existing context fixtures gained a task.defer scheduler stub. Their
  gameplay assertions remain intact.
- The VFX parity test initially flagged the intentional nine-line production
  addition. Its comparison now excludes only that exact authority repair on both
  sides; the remaining gameplay/geometry/HUD comparison stays byte-for-byte.
- Production Luau compilation: 197 files PASS.
- Rojo XML and binary builds PASS:
  `C:/dev/KDM_Race_Ownership_Fix.rbxlx` and
  `C:/dev/KDM_Race_Ownership_Fix.rbxl`.
- Builds use the normal source project; no probe scripts, bot harness flags or
  autopilot wrapper are included.
- Full regression: **205 suites / 164 PASS / 41 pre-existing FAIL / 0 new FAIL**.
  Compared with H1-FINAL's 204 / 163 / 41 baseline; the added ownership suite
  passes. The failing suite set is unchanged. Existing failures remain unresolved
  and are not presented as passes or as published acceptance.
- `git diff --check` PASS.

Raw captures, temporary probe scripts and regression logs are retained locally in
`artifacts/motion-investigation/`, excluded from Git. An additional native forced
unseat/reseat attempt exited the race through its existing lifecycle and does not
count as a native reseating pass. The isolated Studio run was stopped afterward.
The unrelated sound/VFX Studio project was not modified.

F60/H1 UI and lighting, P0 economy/storage, item contracts, combat effects,
normal speed, Nitro 120 studs/s and race capacity are unchanged. Production diff
is limited to PrototypeWorld's seating callback. No Roblox Publish was performed.

## Remaining acceptance

After a separately authorized Publish, repeat the user's solo + bot test on the
iPhone 12 Pro Max without recording, followed by two humans running side by side.
Check the running PlaceVersion before comparing with PV925. Published mobile
acceptance and four-human network conditions remain unverified in this task.

Reference: [Roblox network ownership](https://create.roblox.com/docs/physics/network-ownership).
