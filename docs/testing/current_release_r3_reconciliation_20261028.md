# R3 current-release reconciliation — 2026-10-28

Baseline and freshly fetched origin: `f5ebec8c7f86dac5c488f90a0a01041d147cf4a2` on `prototype/kart-physics`. No main/commit/push/Publish or server restart.

## Outcome

- Full raw suite: **249 total / 229 PASS / 20 FAIL**. This is **not FULL_SUITE_PASS**.
- Prior75 failures: **55 resolved**, historical20 retained; **new failures0** over the comparable original suite.
- Current-release subset: **229 PASS / 0 FAIL**; historical diagnostics remain separate failing processes.
- Current source integrity **682 PASS**, protecting133 exact approved source files; Python audit independently matches approved Git objects and unchanged historical artifacts.
- Default Rojo build and `git diff --check`: PASS. Build hash and full individual outcomes are in the companion JSON.
- R1/R2 evidence, FOV candidate and its pre-existing tests preserved byte-for-byte. Original N1/N2 fixture hashes and historical20 test bodies are preserved.

## Policies and production-source changes

The contract is [current_release_contracts_20261028.md](current_release_contracts_20261028.md). GIT_APPROVED, OWNER_APPROVED_LOCAL and OWNER_CONFIRMED_LIVE_POLICY are distinct from LIVE_VERIFIED.

Only two new production-source changes were authorized during R3:

1. `src/server/RaceRecordOperations.luau`: gate base payment on full-race eligibility. Invalid official finish pays0 base/PB/event; no compensation of historical payouts or change to active-DNF policy. Invalid receipt replay, preserved campaign eligibility, later valid payout and injected old-bug rejection PASS. Legitimate solo/bot/human rank payouts are unchanged.
2. `src/shared/TrackCatalog.luau`: public capability-label line repaired from mojibake to `PUBLIC RACE • 1–4 RACERS • …`. No other label, lap, entry, selection or geometry changed.

The pre-existing FOV50/90/delta5 candidate remains local and unchanged. Mini/Nitro, easing, physical velocities, GAS, touch implementation, ownership and data/purchase implementation are unchanged. The R1 manifest adds exact full-file SHA + reversible single-hunk exceptions for the two owner approvals; it never refreshes the original historical hashes. Wrong price/stock identity, duplicate transactions, malformed read-back and an intentionally restored invalid-base defect are rejected by tests.

## Six risk investigations

| Test | Evidence and cause | Result / limit |
| --- | --- | --- |
| public_warmup_records | Huge single fixture tick skipped the entire results window. Step through bot timeout; actual COMPLETE/FINISHED/DNF at66.3, then8-second completion lifecycle; observer emitted once. |13 checks PASS; actual server lifecycle under mocked transport, no production lifecycle edit. |
| r8_a4_runtime | Fresh5000 + legitimate first finish7500 =12500, lifetime7500. Lost ACK/concurrent callback/retry confirms one receipt; failed writes/read-back never claim success. Current service identity is supplied by controller. |Runtime60 + service40 checks PASS. Live DataStore calls0. |
| r8_a6_public_cash | Guest query leaves profile absent/cash0; explicit trusted activity qualifies5000. Separate first-finish event remains. Rejoin, existing805 balance, legacy ownership, corrupt/future accounts, cross-server competing initialization, lost ACK and shutdown preserve data. |476 checks PASS. Fixture supplies current API, no account/purchase code changed. |
| lobby_shield_visual | Mock lacked Workspace.ChildAdded; observer started before Hub and could not discover it. Added native-shaped child signals, tested later discovery and teardown. |14 +82 world checks PASS; no observer/ownership repair modified. |
| rookie_loop_manual_drive | `inside` now means island land, not asphalt. Origin is island land with negative road contact; boundary fixture must actually leave island. |3358 manual corridor/road/edge checks PASS; no physics edit. |
| r8_perf_p2c | prepare compresses long legacy signatures. Compare canonical vs actual JSON and semantic signature identity rather than stale raw-body equality. |78 checks PASS; bounded receipt growth and replay identity retained. |

These resolve the six automated evidence gaps; they do not certify live-service outages or real-device network smoothness.

## Current vs historical test execution

The original historical20 are executed unchanged and fail below. `speed_sensation_validation` prints **1663 behavior/priority/cadence checks PASS**, then fails its original historical source envelope at FinishCameraComposition. The separate current-release682 and camera integration tests pass. No process-level PASS is claimed for that file.

P2B/K1 historical inline checks uncovered behind outdated expectations are also retained in `practice_public_bot_validation --historical` and `v2_public_multiplayer_validation --historical`; both still FAIL at their old catalog/geometry checkpoint. Default current-release runs verify exact current hashes plus mutation rejection, and execute actual bot/room/garage/4-racer/refill flows. The original frozen H3 test remains in the historical20; current V2 uses the complete current Garage UI integration.

### Retained historical failures

| Test | Concrete failure |
| --- | --- |
| `bot_internal_control_validation.luau` | C:\dev\RobloxKart\tests/bot_internal_control_validation:5: entire human input/physics/items unchanged; only exact Bot extension excluded |
| `chevron_standard_validation.luau` | Track01Metro driving geometry unchanged |
| `finish_source_freeze_validation.luau` | C:\dev\RobloxKart\tests/finish_source_freeze_validation:3: frozen server/gameplay/N1/cache/audio src/client/FinishCameraComposition.luau |
| `item_aftershock_validation.luau` | C:\dev\RobloxKart\tests/item_aftershock_validation:3: exact L1/K2 canonical freeze src/client/KDMItemVFXController.luau |
| `lobby_palette_validation.luau` | C:\dev\RobloxKart\tests/lobby_palette_validation:6: non-color source frozen GarageUiController |
| `lobby_terminology_validation.luau` | C:\dev\RobloxKart\tests/lobby_terminology_validation:3: all non-display catalog fields unchanged Track01Race |
| `park_a1_island_visual_validation.luau` | C:\dev\RobloxKart\tests/park_a1_island_visual_validation:4: accepted driving/gate source unchanged: src/shared/HubParkRookieLoopLayout.luau |
| `park_a2_landscaping_validation.luau` | C:\dev\RobloxKart\tests/park_a2_landscaping_validation:5: approved road/drive/gate unchanged: src/server/HubParkRookieLoopBuilder.luau |
| `practice_figure8_geometry_validation.luau` | frozen complete generated world Track01Race |
| `r8_perf_p0_validation.luau` | C:\dev\RobloxKart\tests/r8_perf_p0_validation:4: exact observer wrapper found |
| `r8_perf_p1_validation.luau` | C:\dev\RobloxKart\tests/r8_perf_p1_validation:4: exact full simulation preservation |
| `rookie_loop_demo_validation.luau` | C:\dev\RobloxKart\tests/rookie_loop_demo_validation:6: legacy demo/audience/physics/RACE untouched src/shared/KartConfig.luau |
| `speed_sensation_validation.luau` | C:\dev\RobloxKart\tests/speed_sensation_validation:4: frozen gameplay/geometry/audio/exhaust src/client/FinishCameraComposition.luau |
| `straight_speed_validation.luau` | C:\dev\RobloxKart\tests/straight_speed_validation:7: unchanged balance DRIFT |
| `track02_published_binding_validation.luau` | C:\dev\RobloxKart\tests/track02_published_binding_validation:5: PV545 Catalog parity |
| `track_environment_validation.luau` | C:\dev\RobloxKart\tests/track_environment_validation:17: Legacy gameplay output exactly matches accepted baseline |
| `track_h3_flow_validation.luau` | C:\dev\RobloxKart\tests/track_h3_flow_validation:12: P1C preview + exact P2B fields only; all other catalog bytes frozen |
| `track_v2_geometry_validation.luau` | C:\dev\RobloxKart\tests/track_v2_geometry_validation:8: unchanged catalog gameplay entry Track01Race |
| `track_visual_standard_validation.luau` | Track01 exact Markings geometry/flags/attributes |
| `v2_gauge_v1_audio_validation.luau` | C:\dev\RobloxKart\tests/v2_gauge_v1_audio_validation:3: stable assets/input plus approved audio exception src/shared/AudioConfig.luau |

## QA / release decision

**PRIVATE_FOV_VISUAL_QA: READY_FOR_MANUAL_MOBILE_QA.** Automated FOV/camera/GAS/touch/boost/Nitro/VFX/combat/ownership/finish/Rematch checks pass; no new failures. In the exact QA Studio Universe10772198697 / Place106553302629620, temporarily applied only the candidate FOV module in Edit and entered ordinary Park TEST DRIVE through the client remote. Observed HubParkV1Enabled=true, FOV HIGH_SPEED_START50, LobbyDriveActive=true, ParkTrialPhase=RUNNING and a seated local driver. Play was then stopped and QA Edit FOV restored exactly55/80/delta3. No Publish or production data API call was made. The current access setting was not independently re-read; it must remain Private before any future Publish.

**FULL_RELEASE: NOT_READY.** Official published-source equivalence is not downloaded/verified, historical suite is intentionally not fully green, and no release/deployment approval is included. The invalid-finish patch is a local reviewed candidate, not a statement that deployed payouts already changed.

Still unverified: actual iPhone comfort/HUD readability, real 30/60FPS renderer switching, four real humans, 5–15 bot Rematch long-session hitches, native official reserved-server entry from published QA, and real-service DataStore outages. Mathematical cadence tests and deterministic four-controller mocks do not establish those acceptances.

## Changed R3 test files

Pre-existing FOV test files are excluded from this R3 list because their snapshot hashes were preserved. R1 current-release helper/manifest/audit updates are the two exact source exceptions plus explicit UTF-8 JSON reads; original historical entries remain unchanged.

- `tests/activity_qualification_validation.luau`
- `tests/combat_hit_audio_validation.luau`
- `tests/datastore_idempotency_validation.luau`
- `tests/drift_telemetry_validation.luau`
- `tests/first60_hub_entry_validation.luau`
- `tests/four_player_race_validation.luau`
- `tests/gameplay_balance_validation.luau`
- `tests/h1_drive_presence_validation.luau`
- `tests/helpers/world_vfx_harness.luau`
- `tests/hub_park_reference_course_validation.luau`
- `tests/hub_world_progression_validation.luau`
- `tests/kart_v2_production_validation.luau`
- `tests/kart_visual_validation.luau`
- `tests/lobby_demo_validation.luau`
- `tests/lobby_drive_mobile_fix_validation.luau`
- `tests/lobby_practice_view_validation.luau`
- `tests/lobby_shield_visual_validation.luau`
- `tests/missile_validation.luau`
- `tests/multiplayer_foundation_validation.luau`
- `tests/p0_race_identity_integration_validation.luau`
- `tests/pit_garage_art_validation.luau`
- `tests/practice_public_bot_validation.luau`
- `tests/public_warmup_records_validation.luau`
- `tests/r8_a2l1_canary_guidance_validation.luau`
- `tests/r8_a3_hud_validation.luau`
- `tests/r8_a3_service_validation.luau`
- `tests/r8_a4_economy_validation.luau`
- `tests/r8_a4_hud_validation.luau`
- `tests/r8_a4_runtime_validation.luau`
- `tests/r8_a6_public_cash_validation.luau`
- `tests/r8_d2_presentation_validation.luau`
- `tests/r8_perf_p2b_validation.luau`
- `tests/r8_perf_p2c_validation.luau`
- `tests/r8_perf_partner_validation.luau`
- `tests/race_item_reset_validation.luau`
- `tests/race_launch_routing_validation.luau`
- `tests/race_mode_validation.luau`
- `tests/race_start_boost_validation.luau`
- `tests/repeatable_nitro_validation.luau`
- `tests/rookie_loop_fleet_validation.luau`
- `tests/rookie_loop_manual_drive_validation.luau`
- `tests/smoke_validation.luau`
- `tests/straight_speed_kart_validation.luau`
- `tests/thunder_validation.luau`
- `tests/track01_figure8_environment_validation.luau`
- `tests/track02_barrier_safety_b_validation.luau`
- `tests/track02_raceability_b_validation.luau`
- `tests/track03_four_player_validation.luau`
- `tests/track_horizon_environment_validation.luau`
- `tests/two_player_race_validation.luau`
- `tests/v2_public_multiplayer_validation.luau`
- `tests/current_release_contracts_validation.luau`

## Evidence and rollback

Full249 outcomes, source-exception hunks/hashes, six raw risk logs and preservation evidence: [current_release_r3_results_20261028.json](current_release_r3_results_20261028.json). Raw individual logs and build are also retained under `C:/Users/Public/Documents/ESTsoft/CreatorTemp/kdm-r3-phir5whc/`.

Rollback is file/hunk scoped: reverse only the exact R3 before/after hunks stored in the JSON for RaceRecordOperations and TrackCatalog; remove only the newly added R3 test/contract changes if requested. FOV rollback uses its three inverse substitutions55/80/delta3 independently. Keep all pre-existing R1/R2 artifacts and unrelated working changes. Do not reset/restore the entire working tree. No deployed version or Git commit needs rollback because none was created here.

Commit / Push / Roblox Publish: **NOT EXECUTED**.
