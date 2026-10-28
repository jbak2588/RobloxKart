# Source Freeze Baseline Reconciliation R1 — 2026-10-28

## Decision and approval boundary

Fetched origin/prototype/kart-physics and local HEAD both equal
`f5ebec8c7f86dac5c488f90a0a01041d147cf4a2`. Initial local changes were the
three FOV constants, their two test files, and the Phase1 report. They are retained.
No gameplay file was changed by R1; KDMSpeedSensation retains exactly the previously
requested Phase1 diff. No Git commit/push, Studio changes or Roblox Publish occurred.

Current approval evidence is the owner's R1 request explicitly naming this exact
release HEAD, plus its section D approving only the three FOV substitutions.
Commit subjects identify provenance; they are **not independently treated as human
approval**. Every historical mismatch is traced to a Git object reachable from
the explicitly approved HEAD. No unknown local source difference was adopted.

## Historical audit

Original N1 baseline: `5c704d5b0caf2b73e76c545617447006d14247bb`.
N1 includes its existing N1B result-cache, N2 presentation and Hub exceptions.
Original N2 parent: `a7e551fac3031c395f4febf6e4ebfc208f8b4639`.
Both historical checks apply their existing exact L2 reverse-hunk normalizer.
The audit reproduces those rules rather than comparing incompatible raw hashes.

| Historical family | Targets | Mismatches at approved HEAD | Mismatches with Phase1 |
| --- | ---: | ---: | ---: |
| N1 effective expectations |120|68|68|
| N2 frozen |121|67|68|
| N2 presentation candidates |5|5|5|

There are72 unique historical mismatching files at HEAD. The working FOV adds
one unique mismatch (KDMSpeedSensation, an N2 target, not an N1 frozen target).
There are zero UNKNOWN_LOCAL classifications. Full246 target records, historical
expected/effective hashes, approved/working hashes, last-changing commits and
per-file history are in `source_freeze_r1_audit_20261028.json`.

The old test commands still exit1, generally at FinishCameraComposition because
the existing tests stop on first failure. The read-only audit separately collects
**every** target and reports all later differences too. The order of an old test's
first failure is not evidence of additional corruption.

### FinishCameraComposition provenance

`46b64f81421e1d205592abf14ca8fe690df5ba98` (2026-10-23) adds only the shared
Composition.front function: driver target height2.25, front distance11, existing
viewport offset helper. It allows Park and official Race to share front-camera
composition. Its AGENTS.md change documents Park's official2.4s roll/.9s transition.
`docs/testing/rookie_park_figure8_parity_20261023.md` records that scope, native
Park finish/Replay/Return checks and official camera validation. The earlier
`ca63b35` introduced mobile finish/results separation. Neither change belongs
to this FOV revision. Current adoption is additionally supported by the owner's
explicit approval of f5ebec8; the old hash is preserved as historical evidence.

### Mobile/GAS release provenance

`f5ebec8` changes21 runtime files;14 also appear among historical mismatches.
New GasPedalPolicy and Park/mobile adapter files are covered in the current lock,
even where absent from old N1/N2 fixtures. AGENTS.md's production mobile-controls
release approval and `mobile_controls_production_release_20261027.md` document
the owner-authorized release. Existing audio, reverse, ownership and UI changes
are retained exactly as approved, not rewritten to satisfy old fixtures.

## Current-release integrity

Added `tests/fixtures/source_freeze_release_f5ebec8.json`, a **separate**, pinned
release manifest for133 exact files: historical-target union plus all21 runtime
files changed by f5ebec8. Existing fixture hashes were neither overwritten nor
deleted. Hashes come from immutable `git show f5ebec8:path`, never from accepting
whatever is currently in the working tree. Per-file last commit/subject is recorded.
Six original fixtures/normalizers/historical-validator artifacts are also pinned.

`tests/helpers/release_source_freeze.luau` compares complete canonical-LF bytes.
It applies no presentation/physics normalization. The only alternative is the
exact Phase1 candidate hash, then an additional reverse-of-three-strings check
must reproduce the approved full-file hash. A different constant, Mini/Nitro edit,
MAX_FOV/easing change, extra comment or any other byte difference is rejected.
The original full-file hash remains valid for the release/rollback baseline.
`tests/source_freeze_release_validation.luau` verifies the candidate, preservation,
all133 targets, mutations/deletions, unknown paths, and multi-error aggregation.

Use these **current release** checks:

```powershell
python tools/audit_source_freeze_r1.py --check-manifest
lune run tests/source_freeze_release_validation.luau
lune run tests/speed_sensation_camera_validation.luau
lune run tests/speed_world_vfx_validation.luau
```

The Python audit independently compares every manifest entry/provenance and the
protected set against immutable Git objects. It refuses a different HEAD or an
unrecognized working-source difference. It has no fixture-regeneration option.
The two original N1/N2 commands remain historical compatibility diagnostics;
their failures are not suppressed, filtered out of the suite, or relabeled PASS.

## Verification and limits

Current release integrity:682 checks across133 files PASS. Independent approved
Git-object and historical-artifact verification PASS. All231 game sources compile;
full Rojo build (`%TEMP%/kdm_source_freeze_r1.rbxlx`) and git diff --check PASS.
The complete suite and per-failure reasons are recorded below after execution.

Studio runtime NOT VERIFIED for R1. No new runtime source behavior was introduced
by reconciliation. FOV's mobile comfort,70/GAS90 perception and long-session
device acceptance still require private QA testing; arithmetic/cadence checks do
not establish them. This is not approval to Publish or a declaration that all
historical/gameplay tests pass. QA remains Universe10772198697 /
Place106553302629620, Private, after separate Publish approval if required.

## Rollback

Remove only the new R1 audit script, release manifest, release helper/test and R1
reports to return to the pre-R1 validation setup. Existing historical files have
not been modified, and pre-existing FOV source/test/report changes remain intact.
Do not reset/restore the entire working tree. Rolling back FOV is a separate
choice: restore exactly55/80/3 and matching profile expectations as documented
in the Phase1 report. No physics/camera/ownership migration is involved.

## Per-file historical differences

The table below lists each unique mismatching approved source, its most recent
changing commit and subject. Full intervening history and hashes are in the JSON
audit. Approval basis for every row is exact membership in the owner-approved
f5ebec8 snapshot; this does not invent undocumented historical human approvals.

| File | Last change | Scope/provenance |
| --- | --- | --- |
| src/client/AudioRuntime.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/CombatFeedbackView.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/DriftChargeView.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/DriverCelebrationController.luau | ce1738e | Add Park two-lap Replay rewards and shared finish presentation |
| src/client/FinishCameraComposition.luau | 46b64f8 | Align Rookie Park checkpoints and finish presentation with Figure-8 |
| src/client/FinishCelebrationController.luau | ce1738e | Add Park two-lap Replay rewards and shared finish presentation |
| src/client/GarageUiController.luau | 0fff186 | Sell permanent KDM V2 karts per color and update shop inventory |
| src/client/HubArrivalCameraController.luau | 4fc6ead | Move Park arrival and seven walk-up PLAY exhibits to the T plaza |
| src/client/HubGuidanceState.luau | a878818 | Finalize F60 lobby UI and lighting polish |
| src/client/HubGuidanceView.luau | a878818 | Finalize F60 lobby UI and lighting polish |
| src/client/HubUiController.luau | 0fff186 | Sell permanent KDM V2 karts per color and update shop inventory |
| src/client/HubWorldGuidanceView.luau | a878818 | Finalize F60 lobby UI and lighting polish |
| src/client/KDMControlIconView.luau | 08685b3 | Preserve PV680 accepted auto reverse controls and engine loop audio |
| src/client/KDMDriverGripController.luau | ce1738e | Add Park two-lap Replay rewards and shared finish presentation |
| src/client/KDMIconCatalog.luau | 08685b3 | Preserve PV680 accepted auto reverse controls and engine loop audio |
| src/client/KDMImpactCameraController.luau | 29076cd | Fix Hub test drive off-track stutter loop and bind camera shake and haptics |
| src/client/KDMItemVFXController.luau | 81f3df1 | Add staggered 4-bot fleet with distinct colors and full hit reactions on Hub test track |
| src/client/KartAudioController.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/KartCameraController.luau | 46b64f8 | Align Rookie Park checkpoints and finish presentation with Figure-8 |
| src/client/KartInputController.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/KartVisualMotionController.luau | b5aa3a8 | feat: sharpen drift action and restore tire feedback |
| src/client/KartWorldExhaustRenderer.luau | 7085949 | Fix track surface flicker and skid contact; plant Park-species preview groves |
| src/client/KartWorldVFXController.luau | ce1738e | Add Park two-lap Replay rewards and shared finish presentation |
| src/client/LobbyCreateView.luau | 9e91812 | Route public racers into shared cross-track rooms |
| src/client/MatchRoomUiController.luau | ec573ed | feat(hub): simplify first-entry racing UI and CTA hierarchy |
| src/client/MobileControlView.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/MobileTutorialView.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/RaceAudioController.luau | e872b16 | Add lap cues, straight driver legs and boost acceleration audio |
| src/client/RaceHudController.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/RaceItemUiController.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/RoomDisplay.luau | 9e91812 | Route public racers into shared cross-track rooms |
| src/client/SmokeEffectView.luau | c23a048 | feat(lobby): add practice items against bot and seated drivers |
| src/client/TouchDrivingController.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/TouchDrivingModel.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/V2DonorGauge.luau | e5937ac | Adjust mobile driving HUD layout to prevent Brake and speedometer overlap |
| src/client/V2GaugeController.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/client/init.client.luau | 7085949 | Fix track surface flicker and skid contact; plant Park-species preview groves |
| src/server/ActiveMatchDirectory.luau | f3b6e49 | Restore minimap rivals and trial fresh-job bot race Rematches |
| src/server/CompactHubBuilder.luau | 7aae5e1 | Finalize RookieLoop HUB course and manual test drive |
| src/server/DriftTelemetry.luau | 81fd875 | feat: add controlled arcade rear slide drift |
| src/server/GarageController.luau | 7aae5e1 | Finalize RookieLoop HUB course and manual test drive |
| src/server/HomingMissileService.luau | cc9cbdf | Play approved boost onset when Missile actually fires |
| src/server/MatchRoomService.luau | 3214d47 | Release separate desert Figure-8 track for Race Now |
| src/server/NitroState.luau | 6e53847 | Synchronize boost audio and preserve off-road Nitro use |
| src/server/PrototypeWorld.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/server/RaceBotController.luau | 0c54d0c | Lower Race Bot Sprint V1 seating and cockpit geometry to match low racing posture |
| src/server/RaceController.luau | 13c1f48 | Align official racer starts to painted grids in entry order |
| src/server/RaceItemController.luau | c766860 | Reassert server authority on race item weld and race start to eliminate periodic hitch |
| src/server/RaceItemVisuals.luau | 47e3e39 | feat(combat, hud, economy): persistent checkpoint miss alert, active DNF rewards, and damage smoke plume |
| src/server/RaceLaunchService.luau | 1abeea6 | feat(kdm): checkpoint R8 kart persistence and returning player guidance |
| src/server/RaceLoadout.luau | 7a5309f | feat(race): offer all six items and remove preparation gate |
| src/server/RaceRoomCoordinator.luau | f3b6e49 | Restore minimap rivals and trial fresh-job bot race Rematches |
| src/server/RaceServerBootstrap.luau | 13c1f48 | Align official racer starts to painted grids in entry order |
| src/server/RaceSession.luau | 13c1f48 | Align official racer starts to painted grids in entry order |
| src/server/RoomSocialDirectory.luau | aa8206b | Wait for host start after public race invitations |
| src/server/TacticalLoadoutService.luau | 7a5309f | feat(race): offer all six items and remove preparation gate |
| src/server/ThunderStrikeService.luau | 64fe30f | Add delayed Missile-style explosion and world light to Thunder hits |
| src/server/TrackBuilder.luau | d36102e | Fix Metro client material permissions and straighten race grid launch |
| src/server/init.server.luau | dfe728b | Add source-template Figure-8 desert theme for isolated staging |
| src/shared/AudioConfig.luau | 4d5c067 | Restore original KDM boost sound at 20 percent lower pitch |
| src/shared/KDMFinishPresentation.luau | ce1738e | Add Park two-lap Replay rewards and shared finish presentation |
| src/shared/KDMGameplayBalance.luau | 36a1c78 | Tune off-track grass speed to 60 studs/s and reduce bonus nitro drift requirement to 3 |
| src/shared/KDMItemVFXConfig.luau | 47e3e39 | feat(combat, hud, economy): persistent checkpoint miss alert, active DNF rewards, and damage smoke plume |
| src/shared/KDMUiTheme.luau | 06a7342 | feat(ui): overhaul lobby and shop UI to bright Roblox arcade racing theme |
| src/shared/KDMV2VisualDefinition.luau | e5f36e2 | Lower VisualSeat to align gear stick lever and steering mount with new wheel position |
| src/shared/KartConfig.luau | f5ebec8 | Ship mobile controls, Park touch input fix and gradual reverse |
| src/shared/KartVisualFactory.luau | 0c54d0c | Lower Race Bot Sprint V1 seating and cockpit geometry to match low racing posture |
| src/shared/RaceConfig.luau | e383a03 | Restore same-server bot Rematch after Shield authority repair |
| src/shared/RaceItemSlots.luau | 7a5309f | feat(race): offer all six items and remove preparation gate |
| src/shared/RaceRouteProgress.luau | d843f12 | Reduce race hot-path work and enable two-account live diagnostics |
| src/shared/TrackCatalog.luau | 7085949 | Fix track surface flicker and skid contact; plant Park-species preview groves |
| src/shared/TrackGeometry.luau | d36102e | Fix Metro client material permissions and straighten race grid launch |
| src/shared/KDMSpeedSensation.luau | c5baa5 + local Phase1 | HEAD matches original; exactly55→50,80→90,High delta3→5 approved by R1 D |


## Complete suite result and remaining failures

All247 validation files were run: **172 PASS /75 FAIL**. No additional failure
names appear versus the prior recorded failure set; the earlier f5ebec8 release
record reports171/246 PASS, with the new current-release test adding one PASS.
The prior diagnostic failure-name set originated from39055dd/mobile-candidate
comparison; this is not claimed to be a newly rerun pristine f5ebec8 full suite.
The exact immutable f5ebec8 source-object reconciliation is independently checked.
No failures were filtered from this result. All75 errors below remain unresolved
as historical compatibility or other test/implementation follow-ups; the assertion
is an observed failure cause, not proof of a runtime gameplay defect. Full logs,
per-test codes/timings and comparison limits are in
source_freeze_r1_validation_20261028.json.

| Failed test | Observed failure (original fixture/assertion/mock error) |
| --- | --- |
| activity_qualification_validation.luau | C:\dev\RobloxKart\tests\activity_qualification_validation:14: KDMShopCatalog |
| bot_internal_control_validation.luau | C:\dev\RobloxKart\tests\bot_internal_control_validation:5: entire human input/physics/items unchanged; only exact Bot extension excluded |
| chevron_standard_validation.luau | Track01Metro driving geometry unchanged |
| combat_hit_audio_validation.luau | C:\dev\RobloxKart\tests\combat_hit_audio_validation:16: Missile launch preserves original KDM explosion independently of turbine tuning |
| datastore_idempotency_validation.luau | actual remote debits one fixed-price purchase |
| drift_telemetry_validation.luau | C:\dev\RobloxKart\tests\drift_telemetry_validation:22: one end log |
| finish_source_freeze_validation.luau | C:\dev\RobloxKart\tests\finish_source_freeze_validation:3: frozen server/gameplay/N1/cache/audio src/client/FinishCameraComposition.luau |
| first60_hub_entry_validation.luau | C:\dev\RobloxKart\tests\first60_hub_entry_validation:11: 7. QuickPlay prioritizes existing public race candidate matching Discovery ranking |
| four_player_race_validation.luau | attempt to call missing method 'setSpawnCFrame' of table |
| gameplay_balance_validation.luau | C:\dev\RobloxKart\tests\gameplay_balance_validation:6: no unapproved public key OFF_TRACK_BOOST_SPEED_MULTIPLIER |
| h1_drive_presence_validation.luau | C:\dev\RobloxKart\tests\h1_drive_presence_validation:5: publish after accepted seat |
| hub_park_reference_course_validation.luau | C:\dev\RobloxKart\tests\hub_park_reference_course_validation:4: lowest free index fills front to rear in +X travel direction |
| hub_world_progression_validation.luau | C:\dev\RobloxKart\tests\hub_world_progression_validation:4: fresh chooses Garage |
| item_aftershock_validation.luau | C:\dev\RobloxKart\tests\item_aftershock_validation:3: exact L1/K2 canonical freeze src/client/KDMItemVFXController.luau |
| kart_v2_production_validation.luau | C:\dev\RobloxKart\tests\kart_v2_production_validation:14: measured source-to-bucket Seat contract |
| kart_visual_validation.luau | C:\dev\RobloxKart\tests\kart_visual_validation:99: assertion failed! |
| lap_item_refill_validation.luau | Green Figure-8 first/default |
| lobby_demo_validation.luau | attempt to index nil with 'BotFleet' |
| lobby_drive_mobile_fix_validation.luau | C:\dev\RobloxKart\tests\lobby_drive_mobile_fix_validation:5: portrait Drift above pad/shortcuts |
| lobby_palette_validation.luau | C:\dev\RobloxKart\tests\lobby_palette_validation:6: non-color source frozen GarageUiController |
| lobby_practice_view_validation.luau | attempt to index nil with 'fromRGB' |
| lobby_shield_visual_validation.luau | C:\dev\RobloxKart\tests\lobby_shield_visual_validation:3: same Shield renderer used by both practice clients |
| lobby_terminology_validation.luau | C:\dev\RobloxKart\tests\lobby_terminology_validation:3: all non-display catalog fields unchanged Track01Race |
| missile_validation.luau | attempt to call a nil value |
| multiplayer_foundation_validation.luau | attempt to call missing method 'SetAttribute' of table |
| p0_race_identity_integration_validation.luau | attempt to call missing method 'setSpawnCFrame' of table |
| park_a1_island_visual_validation.luau | C:\dev\RobloxKart\tests\park_a1_island_visual_validation:4: accepted driving/gate source unchanged: src/shared/HubParkRookieLoopLayout.luau |
| park_a2_landscaping_validation.luau | C:\dev\RobloxKart\tests\park_a2_landscaping_validation:5: approved road/drive/gate unchanged: src/server/HubParkRookieLoopBuilder.luau |
| pit_garage_art_validation.luau | C:\dev\RobloxKart\tests\pit_garage_art_validation:3: actual art build succeeds |
| practice_figure8_geometry_validation.luau | frozen complete generated world Track01Race |
| practice_figure8_race_validation.luau | Green Figure-8 first/default |
| practice_public_bot_validation.luau | C:\dev\RobloxKart\tests\practice_public_bot_validation:21: lap authority Track01Desert |
| practice_three_lap_validation.luau | Green Figure-8 first/default |
| public_warmup_records_validation.luau | completed human and bot terminal round settles |
| r8_a2l1_canary_guidance_validation.luau | C:\dev\RobloxKart\tests\r8_a2l1_canary_guidance_validation:122: L1 direct validation failed |
| r8_a3_controller_validation.luau | attempt to call missing method 'setSpawnCFrame' of table |
| r8_a3_hud_validation.luau | pending is not stored success |
| r8_a3_service_validation.luau | C:\dev\RobloxKart\tests\r8_a3_service_validation:45: attempt to index nil with 'path' |
| r8_a3b_integration_validation.luau | attempt to index nil with 'path' |
| r8_a4_economy_validation.luau | C:\dev\RobloxKart\tests\r8_a4_economy_validation:11: ineligible zero |
| r8_a4_hud_validation.luau | confirmed breakdown |
| r8_a4_runtime_validation.luau | lost ACK credits exactly once |
| r8_a6_public_cash_validation.luau | C:\dev\RobloxKart\tests\r8_a6_public_cash_validation:137: attempt to index nil with 'wallet' |
| r8_d2_presentation_validation.luau | C:\dev\RobloxKart\tests\r8_d2_presentation_validation:23: persistent grounded marks visible |
| r8_perf_p0_validation.luau | C:\dev\RobloxKart\tests\r8_perf_p0_validation:4: exact observer wrapper found |
| r8_perf_p1_validation.luau | C:\dev\RobloxKart\tests\r8_perf_p1_validation:4: exact full simulation preservation |
| r8_perf_p2b_validation.luau | C:\dev\RobloxKart\tests\r8_perf_p2b_validation:14: render evidence first and full summary scrollable |
| r8_perf_p2c_validation.luau | C:\dev\RobloxKart\tests\r8_perf_p2c_validation:7: reproduces P2C original false capacity refusal |
| r8_perf_partner_validation.luau | C:\dev\RobloxKart\tests\r8_perf_partner_validation:4: approved diagnostic account |
| race_item_reset_validation.luau | C:\dev\RobloxKart\tests\race_item_reset_validation:123: assertion failed! |
| race_launch_routing_validation.luau | C:\dev\RobloxKart\tests\race_launch_routing_validation:7: arrival restores validated selections and grid for Track01 |
| race_mode_validation.luau | C:\dev\RobloxKart\tests\race_mode_validation:10: Green Figure-8 first/default |
| race_start_boost_validation.luau | attempt to index nil with 'reassertServerAuthority' |
| repeatable_nitro_validation.luau | C:\dev\RobloxKart\tests\repeatable_nitro_validation:11: frozen requirement and held capacity |
| rookie_loop_demo_validation.luau | C:\dev\RobloxKart\tests\rookie_loop_demo_validation:6: legacy demo/audience/physics/RACE untouched src/shared/KartConfig.luau |
| rookie_loop_fleet_validation.luau | C:\dev\RobloxKart\tests\rookie_loop_fleet_validation:5: BotFleet contains exactly 4 bots |
| rookie_loop_manual_drive_validation.luau | C:\dev\RobloxKart\tests\rookie_loop_manual_drive_validation:4: Lobby island excluded |
| smoke_validation.luau | attempt to call a nil value |
| speed_sensation_validation.luau | C:\dev\RobloxKart\tests\speed_sensation_validation:4: frozen gameplay/geometry/audio/exhaust src/client/FinishCameraComposition.luau |
| straight_speed_kart_validation.luau | reverse24 |
| straight_speed_validation.luau | C:\dev\RobloxKart\tests\straight_speed_validation:7: unchanged balance DRIFT |
| thunder_validation.luau | attempt to call a nil value |
| track01_figure8_environment_validation.luau | Track01 has exactly 8 SpeedCue objects |
| track02_barrier_safety_b_validation.luau | C:\dev\RobloxKart\tests\track02_barrier_safety_b_validation:4: candidate forward cues |
| track02_published_binding_validation.luau | C:\dev\RobloxKart\tests\track02_published_binding_validation:5: PV545 Catalog parity |
| track02_raceability_b_validation.luau | C:\dev\RobloxKart\tests\track02_raceability_b_validation:5: production catalog still legacy; B diagnostic only |
| track03_four_player_validation.luau | attempt to call missing method 'setSpawnCFrame' of table |
| track_environment_validation.luau | C:\dev\RobloxKart\tests\track_environment_validation:17: Legacy gameplay output exactly matches accepted baseline |
| track_h3_flow_validation.luau | C:\dev\RobloxKart\tests\track_h3_flow_validation:12: P1C preview + exact P2B fields only; all other catalog bytes frozen |
| track_horizon_environment_validation.luau | HUB Track01 server VisualPartCount preserved at 1366 |
| track_v2_geometry_validation.luau | C:\dev\RobloxKart\tests\track_v2_geometry_validation:8: unchanged catalog gameplay entry Track01Race |
| track_visual_standard_validation.luau | Track01 exact Markings geometry/flags/attributes |
| two_player_race_validation.luau | attempt to call missing method 'setSpawnCFrame' of table |
| v2_gauge_v1_audio_validation.luau | C:\dev\RobloxKart\tests\v2_gauge_v1_audio_validation:3: stable assets/input plus approved audio exception src/shared/AudioConfig.luau |
| v2_public_multiplayer_validation.luau | C:\dev\RobloxKart\tests\v2_public_multiplayer_validation:10: production identity/image unchanged |

Current GAS, mobile controls, reverse, ownership, actual camera-owner, camera
motion/restore, Speed VFX and finish-presentation regressions PASS. Historical
speed_sensation_validation completes1663 profile/cadence checks before its
unchanged historical freeze failure; finish_source_freeze_validation retains
its historical mismatch. Neither full command is labeled PASS.

**Release status:** R1 current-release integrity and exact FOV scope are verified,
but overall suite is not green, Studio/device QA is pending, and Publish/commit/
push is not authorized or performed. Other75 failures are not silently approved.
