# Shield all-mode repair and corner chevron release — 2026-10-25

Baseline: e383a03, matching origin; clean initial worktree. Owner authorizes
code, validation and production Publish.

## Shield

Official Race/Solo use the c766860 PrototypeWorld/RaceItemController repair.
Park uses **LobbyPracticeCombat**, a separate record and item adapter; its weld
creation/removal previously had no equivalent repair. Added deferred checks
after shell/pulse creation, block, expiry, capped eviction and transient cleanup.
Only the same current, live seated human record is eligible; auto/client-owned
assemblies are returned to manual server ownership. No per-frame ownership writes,
physics tuning or combat balance changes. Same-server human-plus-bot Rematch remains
enabled through the normal path (fresh-server workaround remains false).

Native Studio Play validation used the production Park Drive/UseItem remotes, then
an isolated official PrototypeWorld seated RACING context with the real RaceItemControl
remote. Both actually consumed Shield and showed active Shield in 45 samples.
Each sampler covered 130 samples at 0.1-second intervals, including the active shell,
pulse and subsequent expiry: **zero automatic-mode or client-owner samples** in both
paths. The Race fixture required unlocking its controls before the successful item
activation; an earlier locked attempt was rejected and is not counted as a pass.
This is lifecycle validation, not a new full lap, published 2-human or mobile endurance
acceptance. Play-only fixtures were removed by Stop; no QA scripts were added to Edit.

## Chevron audit

| Track | Before boards | After boards | Corners |
| --- | ---: | ---: | ---: |
| Rookie Park | 54 | 54 | 18 |
| Figure-8 Green Island | 54 | 12 | 4 |
| Figure-8 Desert | 54 | 12 | 4 |
| Base Circuit | 45 | 18 | 6 |
| V2 | 102 | 48 | 16 |
| Hard | 156 | 42 | 14 |

Every corner has three roadside boards and only one road-facing SurfaceGui;
rear graphics are not created. Analytic tracks use their actual geometry arcs;
spline tracks use connected same-direction curvature runs. Park already grouped
its corner sections correctly. Builders version the visual cache to replace old
double-sided/multi-cluster decorations. Road, marking, kerb, barrier and trigger
signatures are unchanged against e383a03 for every catalog track.

Native Studio audit: Park 54 boards, all 18 groups exactly three, zero boards
with extra/missing face; generated Desert 12 boards and zero extra/missing faces.

## Checks and release integrity

- Park combat: 465 PASS; Lobby drive policy: 1,096 PASS.
- Official ownership: 25 PASS; item suite: 1,191 PASS (+273 NPC, 13 preview).
- All-track chevron/physical signatures: 450 PASS; Park decor: 2,403 PASS.
- Figure-8 geometry/world freeze: 42,971 PASS; desert: 282,078 PASS.
- Room: 49 PASS; Rematch rewards: 178 PASS; 2P: 108 PASS; 4P: 55 PASS.
- Changed runtime/new test Luau compilation, Rojo XML/binary builds, diff check PASS.
- Legacy track_environment_validation still fails its old frozen-marking comparison
  to 647be04b. Reproduced the identical failure with the unmodified e383a03 builder;
  it is not reported as a pass. Focused comparison against this task's baseline
  verifies the unchanged physical/marking output for all five catalog entries.
- Production Edit source audit compared 222 script sources to the Rojo build.
  Canonical bootstrap and seven related sources synchronized and verified; final
  check has zero mismatches. Three immutable desert source MeshIds verified intact.
- Publish target: Kart Drift Masters, Universe 10768420544 / Place 127925465904803.
