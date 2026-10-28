# Speed Sensation V2 R2 — baseline comparison and QA readiness

## 1. 기준 HEAD 및 작업 상태

판정: **BLOCKED**. FOV 때문에 추가된 실패는 발견되지 않았지만, 기존 실패 중
경기 종료/재경기와 저장 초기화에 관한 불확실성을 해소하지 못해 D4의
“비공개 QA 실행을 막는 중대한 위험 없음”을 확정하지 않는다.
이 판정은 FOV 신규 회귀나 실제 Roblox 장애가 입증됐다는 뜻이 아니다.

local/origin/prototype/kart-physics:
`f5ebec8c7f86dac5c488f90a0a01041d147cf4a2` (fetch 후 일치).
원본은 다음 별도 detached Git worktree에서 실행했다:

`C:\Users\Public\Documents\ESTsoft\CreatorTemp\kdm-r2-ukad2saj\baseline`

후보 실행 경로는 `C:\dev\RobloxKart`. 원본에 후보 소스나 R1 산출물을 복사하지 않았다.
두 경로는 같은 lune 실행 파일/환경, Windows 호스트, Python 실행기로 순차 비교했다.
Lune0.10.5 / Rojo7.7.1 / Python3.11.9. 실제 실행 파일 경로와 로그는 비교 JSON에 기록했다.

최초 FOV 소스/테스트/보고서와 R1 산출물11개의 바이트 SHA256을 저장했고,
실행 후 전부 동일함을 확인했다. 원본 worktree의 git status도 비어 있다.
R2가 추가한 것은 비교/분류 도구, 증거 보고서 및 **미실행** QA 전용 패치와 테스트다.
게임 소스의 차이는 기존 FOV 세 상수뿐이다. 구매/저장/GAS/UI/물리/Ownership은 수정하지 않았다.

## 2. HEAD와 FOV 후보 테스트 비교

R1에서 실패한75개를 모두 실제 원본/후보에서 재실행했다. 추가 핵심28개도 양쪽에서 실행했다.

| 범위 | 원본 HEAD | 후보 | 판정 |
| --- | ---: | ---: | --- |
| 기존 실패75개 |75 FAIL|75 FAIL|전부 기존 실패|
| 추가 핵심28개 |28 PASS|28 PASS|양쪽 통과|
| 합계103개/각 경로 |28 PASS /75 FAIL|28 PASS /75 FAIL|새 실패0, 해결된 실패0|

기존75개 전체에 양쪽 종료 코드/실패 메시지/전체 로그를 보관했다.
현재 프로필에 맞춰 이미 수정된 FOV 테스트 기대값은 후보에 유지했고,
원본은 원본 테스트 그대로 실행했다. 어떤 실패 assertion도 비활성화하지 않았다.
R2 비교 도구가 처음에 존재하지 않는 public_autostart_gate 이름에서 멈춘 뒤,
실제 파일 invited_public_start_validation을 확인해 수정했다. 완료된 쌍은 동일
도구/HEAD/보존 해시를 확인한 후 재사용했고, 나머지 쌍을 모두 실행했다.
이는 테스트를 PASS 처리하거나 75개 중 일부를 생략한 것이 아니다.

R1 전체247개 결과172 PASS /75 FAIL은 보존한다. R2는 전체 suite 재실행이 아닌
위103개 쌍 비교와 별도 무결성/타깃 검사다. FULL_SUITE_PASS라고 보고하지 않는다.

## 3. 신규 회귀 목록

관찰된 NEW_FAILURE: **없음**. RESOLVED_FAILURE도 없음.
FOV 세 상수 이외의 프로덕션 변경 없음. 원본/후보의 기존 실패가 같다는 사실만으로
기존 기능 전체가 올바르거나 모든 실제 기기 동작이 검증됐다고 추론하지 않는다.

## 4. 기존75개 실패 분류

| 유형 | 개수 | 의미 |
| --- | ---: | --- |
| HISTORICAL_FREEZE |20|옛 해시/소스/월드 스냅샷과 승인 HEAD 사이의 경계 불일치|
| OUTDATED_TEST_EXPECTATION |33|현재 소스와 다른 가격·레이아웃·카탈로그·문구·설정 기대값|
| TEST_MOCK_OR_ENVIRONMENT |16|누락된 모듈/메서드/Roblox 자료형·템플릿 의존성|
| POTENTIAL_RUNTIME_REGRESSION |1|기존 warm-up 완료 상태 실패, 실제 원인 추가 분리 필요|
| UNDETERMINED |5|원본에서도 재현되지만 mock/기대값/실제 동작 중 원인 미확정|

분류는 아래 테스트 로그와 현재 소스 근거를 기준으로 한다. OUTDATED는 테스트를 수정하거나
현재 정책을 새로 승인했다는 뜻이 아니다. 특히 Nitro의 실제3회 설정과 AGENTS의5회 설명은
기존 불일치로 별도 확인이 필요하다. 데이터/구매 코드나 그 기대값은 수정하지 않았다.

확정 가능한 예:
- datastore_idempotency: Smoke 구매 후9750을 기대하지만 현재 가격은2500이다.
  이 첫 assertion 실패로 뒤쪽 중복결제 검증까지 통과했다고 주장하지 않는다.
- Missile/Smoke/Thunder: Shield 준비 중 RaceItemController가 호출하는
  reassertServerAuthority가 구 mock에 없어 실패한다. 실제 소유권 가드를 제거하지 않았다.
- 다인원 fixture: 최신 grid 배치가 호출하는 setSpawnCFrame이 fake context에 없다.
- 현재 카탈로그는 Track02를 선택 목록에서 제외하나 구 테스트는6개 목록을 강제한다.

미해결 핵심:
- public_warmup_records_validation: 인간 완주 + bot timeout 후 COMPLETE 기대 실패.
  RaceController.updateComplete의 참가자 terminal 조건/auto-next 타이밍과의 관계를
  더 분리해야 한다. 실제 Roblox Rematch 장애라고 단정하지 않는다.
- r8_a4_runtime_validation: lost-ACK wallet7500 기대 실패. 새 이벤트/기본 보상 정책과
  fixture 기대값 차이인지, 재시도 문제인지 실제 값을 분리하지 못했다.
- r8_a6_public_cash_validation: account()가 nil. 이 fixture에는 ShopCatalog가 있으므로
  구 mock의 단순 모듈 누락이라고 분류하지 않았다. 초기화 원인 미확정.
- lobby_shield_visual / rookie_loop_manual_drive / r8_perf_p2c도 미확정으로 남긴다.

| 테스트 | 분류 | 실패 원인/분류 근거 | 현재 소스 근거 |
| --- | --- | --- | --- |
| activity_qualification_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Old injected module-node lists omit the KDMShopCatalog dependency required by EconomyService; logs show missing node/path before the intended scenario. | src/server/EconomyService.luau:6 |
| bot_internal_control_validation.luau | HISTORICAL_FREEZE | Tests remove only specific old hunks then require an old complete source body/string. f5ebec8 already includes GAS/authority/mobile-era additions. | src/server/PrototypeWorld.luau:8 |
| chevron_standard_validation.luau | HISTORICAL_FREEZE | Generated-world/geometry signatures are frozen to older track snapshots, while the approved release contains later paint/grid/scenery changes. | src/server/TrackBuilder.luau:1 |
| combat_hit_audio_validation.luau | OUTDATED_TEST_EXPECTATION | Assertion hardcodes the old explosion asset/volume equality; current release has later approved boost/Missile-onset audio changes. | src/shared/AudioConfig.luau:10 |
| datastore_idempotency_validation.luau | OUTDATED_TEST_EXPECTATION | The failed remote-purchase assertion expects10000-250=9750 for Smoke; current approved Smoke price is2500. This first failure is before later idempotency scenarios. | src/shared/KDMShopCatalog.luau:6 |
| drift_telemetry_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture expects one diagnostic log but uses DEBUG_TELEMETRY=false; production intentionally suppresses finish logger/diagnostic updates in that mode. | src/shared/KartConfig.luau:90 |
| finish_source_freeze_validation.luau | HISTORICAL_FREEZE | Original N1/N2 hashes predate approved release; R1 exhaustively reconciles the differences without changing those fixtures. | tests/fixtures/n2_source_freeze.json:9 |
| first60_hub_entry_validation.luau | OUTDATED_TEST_EXPECTATION | Exact source-string QuickPlay lookup assertion predates current track-aware Race Now routing. | src/server/MatchRoomService.luau:1 |
| four_player_race_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Fake kart contexts do not implement setSpawnCFrame, now used by production grid placement; execution stops at a missing table method. | src/server/RaceController.luau:342 |
| gameplay_balance_validation.luau | OUTDATED_TEST_EXPECTATION | Old public-key whitelist omits OFF_TRACK_BOOST_SPEED_MULTIPLIER, already present in approved HEAD. | src/shared/KartConfig.luau:14 |
| h1_drive_presence_validation.luau | OUTDATED_TEST_EXPECTATION | Source-text presence assertion demands an exact older adjacent statement sequence after later lifecycle changes. | src/server/LobbyTestDriveService.luau:89 |
| hub_park_reference_course_validation.luau | OUTDATED_TEST_EXPECTATION | Old strictly descending X-per-slot expectation conflicts with the approved paired main-road grid arrangement. | src/shared/HubParkRookieLoopLayout.luau:80 |
| hub_world_progression_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture expects fresh GARAGE guidance while current F60 source directly returns ROOMS/RACE. | src/client/HubGuidanceState.luau:32 |
| item_aftershock_validation.luau | HISTORICAL_FREEZE | Exact L1/K2 canonical freeze rejects later approved source. Both pristine HEAD and candidate fail at the freeze. | src/client/KDMItemVFXController.luau:2 |
| kart_v2_production_validation.luau | OUTDATED_TEST_EXPECTATION | Measured seat assertion expects old Y+.06000018; current approved lowered seat uses Y-.79. | src/shared/KDMV2VisualDefinition.luau:8 |
| kart_visual_validation.luau | OUTDATED_TEST_EXPECTATION | Test asserts old SteeringPivot(0,1.65,-1.05); current source uses lowered(0,.85,-.95). | src/shared/KartVisualFactory.luau:349 |
| lap_item_refill_validation.luau | OUTDATED_TEST_EXPECTATION | Shared race-mode fixture expects six selectable tracks including retired Track02; current approved catalog has five after inserting Metro. | src/shared/TrackCatalog.luau:3 |
| lobby_demo_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Legacy demo require mock supplies LobbyDemoRoute but not the newer LobbyPracticePolicy dependency; indexing BotFleet on the returned nil fails. | src/server/LobbyDemoService.luau:20 |
| lobby_drive_mobile_fix_validation.luau | OUTDATED_TEST_EXPECTATION | Legacy pad/portrait Drift boundary assumptions predate approved five-button rounded controls and current safe-area layout. | src/client/MobileControlView.luau:33 |
| lobby_palette_validation.luau | HISTORICAL_FREEZE | Non-color source comparison permits only its historical palette hunks, excluding subsequent approved shop/navigation/UI work. | src/client/GarageUiController.luau:1 |
| lobby_practice_view_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Old fixture environment omits Roblox Color3 while the fleet policy now authors per-bot colors; policy load fails at fromRGB. | src/shared/LobbyPracticePolicy.luau:8 |
| lobby_shield_visual_validation.luau | UNDETERMINED | Old practice world-observer fixture does not produce KDMShieldWorld at its assertion. The precise observer lifecycle/mocking cause is not established from the paired logs. | src/client/KartWorldVFXController.luau:81 |
| lobby_terminology_validation.luau | HISTORICAL_FREEZE | Exact catalog hash/non-display-field/inverse-hunk comparison predates the approved catalog and retired Track02 selection policy. | src/shared/TrackCatalog.luau:3 |
| missile_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Shield use inside these fixtures reaches the approved authority guard, but their PrototypeWorld stub lacks reassertServerAuthority. | src/server/RaceItemController.luau:42 |
| multiplayer_foundation_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Removal path calls SetAttribute on a minimal fake object that lacks the Roblox method. | src/server/RaceSession.luau:87 |
| p0_race_identity_integration_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Fake kart contexts do not implement setSpawnCFrame, now used by production grid placement; execution stops at a missing table method. | src/server/RaceController.luau:342 |
| park_a1_island_visual_validation.luau | HISTORICAL_FREEZE | Tests compare exact Park builder/layout bytes with older commits. Those files already differ in the approved release. | src/server/HubParkRookieLoopBuilder.luau:2 |
| park_a2_landscaping_validation.luau | HISTORICAL_FREEZE | Tests compare exact Park builder/layout bytes with older commits. Those files already differ in the approved release. | src/server/HubParkRookieLoopBuilder.luau:2 |
| pit_garage_art_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Minimal legacy art/template dependency mock does not represent all current kiosk/template requirements; builder catches an extraction failure and falls back, violating the art-only assertion. | src/server/CompactHubBuilder.luau:85 |
| practice_figure8_geometry_validation.luau | HISTORICAL_FREEZE | Generated-world/geometry signatures are frozen to older track snapshots, while the approved release contains later paint/grid/scenery changes. | src/server/TrackBuilder.luau:1 |
| practice_figure8_race_validation.luau | OUTDATED_TEST_EXPECTATION | Shared race-mode fixture expects six selectable tracks including retired Track02; current approved catalog has five after inserting Metro. | src/shared/TrackCatalog.luau:3 |
| practice_public_bot_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture expects Desert to have2 laps (only Track01 allowed3); approved Desert entry now also has3. | src/shared/TrackCatalog.luau:15 |
| practice_three_lap_validation.luau | OUTDATED_TEST_EXPECTATION | Shared race-mode fixture expects six selectable tracks including retired Track02; current approved catalog has five after inserting Metro. | src/shared/TrackCatalog.luau:3 |
| public_warmup_records_validation.luau | POTENTIAL_RUNTIME_REGRESSION | Controlled warm-up fixture fails to reach expected COMPLETE after human finish and bot timeout. Current updateComplete requires all participants terminal; the blocking participant/timing is not yet isolated. | src/server/RaceController.luau:990 |
| r8_a2l1_canary_guidance_validation.luau | OUTDATED_TEST_EXPECTATION | Multi-scenario old progression/Canary guidance fixture includes Garage-first/layout assumptions superseded by current direct room guidance. | src/client/HubGuidanceState.luau:32 |
| r8_a3_controller_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Fake kart contexts do not implement setSpawnCFrame, now used by production grid placement; execution stops at a missing table method. | src/server/RaceController.luau:342 |
| r8_a3_hud_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture expects save status in Results.Best; current HUD owns save state in the separate RecordSave label. | src/client/RaceHudController.luau:1293 |
| r8_a3_service_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Old injected module-node lists omit the KDMShopCatalog dependency required by EconomyService; logs show missing node/path before the intended scenario. | src/server/EconomyService.luau:6 |
| r8_a3b_integration_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Old injected module-node lists omit the KDMShopCatalog dependency required by EconomyService; logs show missing node/path before the intended scenario. | src/server/EconomyService.luau:6 |
| r8_a4_economy_validation.luau | OUTDATED_TEST_EXPECTATION | Old test expects zero money for an ineligible finished record; current source deliberately guarantees a base completion reward and gates PB/event rewards on eligibility. | src/server/RaceRecordOperations.luau:93 |
| r8_a4_hud_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture demands the older K$50/BASE35/RACE PB10/LAP PB5 text; current confirmed reward presentation uses rank-prize/PB/event wording. | src/client/RaceHudController.luau:1319 |
| r8_a4_runtime_validation.luau | UNDETERMINED | Lost-ACK assertion expects wallet7500/lifetime2500; current reducer has newer event/base policies. Both runs fail, but actual output and duplicate-credit causality were not isolated. | src/server/RaceRecordOperations.luau:113 |
| r8_a6_public_cash_validation.luau | UNDETERMINED | Fixture account() returns nil before its expected starter-cash assertion. Unlike older fixtures it does include ShopCatalog; initialization/environment vs actual startup failure is not isolated. | src/server/EconomyService.luau:6 |
| r8_d2_presentation_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture uses official karts but requires lifetime6; current source assigns official2.5 and Lobby6. | src/client/KartWorldExhaustRenderer.luau:82 |
| r8_perf_p0_validation.luau | HISTORICAL_FREEZE | Tests remove only specific old hunks then require an old complete source body/string. f5ebec8 already includes GAS/authority/mobile-era additions. | src/server/PrototypeWorld.luau:8 |
| r8_perf_p1_validation.luau | HISTORICAL_FREEZE | Tests remove only specific old hunks then require an old complete source body/string. f5ebec8 already includes GAS/authority/mobile-era additions. | src/server/PrototypeWorld.luau:8 |
| r8_perf_p2b_validation.luau | OUTDATED_TEST_EXPECTATION | Exact summaryScroll/field-order source-string assertion predates subsequent performance UI edits. | src/client/RacePerformanceMonitor.luau:1 |
| r8_perf_p2c_validation.luau | UNDETERMINED | Test can no longer reproduce its old canonical-size capacity refusal. Receipt/schema compression has evolved; exact root of the changed reproducer was not isolated. | src/shared/KDMProgressionSchema.luau:2 |
| r8_perf_partner_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture allows old diagnostic account11736539305; current explicit allowlist uses11734277722. | src/shared/KDMPerformanceBuffer.luau:25 |
| race_item_reset_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture asserts SetTacticalLoadout succeeds; current source intentionally retires tactical selection and supplies six fixed items. | src/shared/RaceItemSlots.luau:10 |
| race_launch_routing_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture expects Track01 arrival MaxPlayers1; current Track01 is a public multiplayer track. | src/shared/TrackCatalog.luau:5 |
| race_mode_validation.luau | OUTDATED_TEST_EXPECTATION | Shared race-mode fixture expects six selectable tracks including retired Track02; current approved catalog has five after inserting Metro. | src/shared/TrackCatalog.luau:3 |
| race_start_boost_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Old injected launch fixture references an absent mocked PrototypeWorld authority dependency. | src/server/RaceController.luau:428 |
| repeatable_nitro_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture requires5 boosts but approved HEAD already configures3. Historical AGENTS prose is inconsistent with this accepted source snapshot; R2 does not reconcile tuning. | src/shared/KDMGameplayBalance.luau:126 |
| rookie_loop_demo_validation.luau | HISTORICAL_FREEZE | Exact eceaec9-era KartConfig snapshot excludes the already approved reverse70 and later configuration changes. | src/shared/KartConfig.luau:15 |
| rookie_loop_fleet_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture requires exactly4 bots; approved Park policy has7 distinct color entries. | src/shared/LobbyPracticePolicy.luau:14 |
| rookie_loop_manual_drive_validation.luau | UNDETERMINED | Fixture expects origin excluded as old Lobby island; current geometry reports it inside. Whether this is an obsolete island assumption requires a geometry-specific review. | src/shared/RookieLoopDriveGeometry.luau:4 |
| smoke_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Shield use inside these fixtures reaches the approved authority guard, but their PrototypeWorld stub lacks reassertServerAuthority. | src/server/RaceItemController.luau:42 |
| speed_sensation_validation.luau | HISTORICAL_FREEZE | Original N1/N2 hashes predate approved release; R1 exhaustively reconciles the differences without changing those fixtures. | tests/fixtures/n2_source_freeze.json:9 |
| straight_speed_kart_validation.luau | OUTDATED_TEST_EXPECTATION | Fixture expects reverse24; approved release uses gradual reverse70. | src/shared/KartConfig.luau:15 |
| straight_speed_validation.luau | HISTORICAL_FREEZE | Test requires complete old DRIFT balance equality; approved HEAD already contains later tuning. | src/shared/KDMGameplayBalance.luau:126 |
| thunder_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Shield use inside these fixtures reaches the approved authority guard, but their PrototypeWorld stub lacks reassertServerAuthority. | src/server/RaceItemController.luau:42 |
| track01_figure8_environment_validation.luau | OUTDATED_TEST_EXPECTATION | Assertions require old exact SpeedCue/VisualPartCount counts that predate approved cue/paint/scenery cleanup. | src/server/TrackBuilder.luau:1 |
| track02_barrier_safety_b_validation.luau | OUTDATED_TEST_EXPECTATION | Legacy Track02/V2 candidate diagnostics demand an older geometry/direction-marker/identity contract; Track02 is now outside selectable QA track scope. | src/shared/TrackCatalog.luau:65 |
| track02_published_binding_validation.luau | HISTORICAL_FREEZE | Exact catalog hash/non-display-field/inverse-hunk comparison predates the approved catalog and retired Track02 selection policy. | src/shared/TrackCatalog.luau:3 |
| track02_raceability_b_validation.luau | OUTDATED_TEST_EXPECTATION | Legacy Track02/V2 candidate diagnostics demand an older geometry/direction-marker/identity contract; Track02 is now outside selectable QA track scope. | src/shared/TrackCatalog.luau:65 |
| track03_four_player_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Fake kart contexts do not implement setSpawnCFrame, now used by production grid placement; execution stops at a missing table method. | src/server/RaceController.luau:342 |
| track_environment_validation.luau | HISTORICAL_FREEZE | Generated-world/geometry signatures are frozen to older track snapshots, while the approved release contains later paint/grid/scenery changes. | src/server/TrackBuilder.luau:1 |
| track_h3_flow_validation.luau | HISTORICAL_FREEZE | Exact catalog hash/non-display-field/inverse-hunk comparison predates the approved catalog and retired Track02 selection policy. | src/shared/TrackCatalog.luau:3 |
| track_horizon_environment_validation.luau | OUTDATED_TEST_EXPECTATION | Assertions require old exact SpeedCue/VisualPartCount counts that predate approved cue/paint/scenery cleanup. | src/server/TrackBuilder.luau:1 |
| track_v2_geometry_validation.luau | HISTORICAL_FREEZE | Exact catalog hash/non-display-field/inverse-hunk comparison predates the approved catalog and retired Track02 selection policy. | src/shared/TrackCatalog.luau:3 |
| track_visual_standard_validation.luau | HISTORICAL_FREEZE | Generated-world/geometry signatures are frozen to older track snapshots, while the approved release contains later paint/grid/scenery changes. | src/server/TrackBuilder.luau:1 |
| two_player_race_validation.luau | TEST_MOCK_OR_ENVIRONMENT | Fake kart contexts do not implement setSpawnCFrame, now used by production grid placement; execution stops at a missing table method. | src/server/RaceController.luau:342 |
| v2_gauge_v1_audio_validation.luau | HISTORICAL_FREEZE | Exact asset/input freeze with a narrow old audio exception rejects later approved AudioConfig. | src/shared/AudioConfig.luau:1 |
| v2_public_multiplayer_validation.luau | OUTDATED_TEST_EXPECTATION | Legacy Track02/V2 candidate diagnostics demand an older geometry/direction-marker/identity contract; Track02 is now outside selectable QA track scope. | src/shared/TrackCatalog.luau:65 |

## 5. 핵심 기능 테스트 결과

양쪽 PASS28개:

| 핵심 테스트 | 원본/후보 |
| --- | --- |
| boost_audio_validation.luau | PASS / PASS |
| camera_motion_validation.luau | PASS / PASS |
| finish_presentation_validation.luau | PASS / PASS |
| finish_sequence_validation.luau | PASS / PASS |
| gas_pedal_validation.luau | PASS / PASS |
| impact_camera_validation.luau | PASS / PASS |
| invited_public_start_validation.luau | PASS / PASS |
| item_world_vfx_validation.luau | PASS / PASS |
| kart_audio_validation.luau | PASS / PASS |
| lobby_practice_combat_validation.luau | PASS / PASS |
| mobile_controls_v1_validation.luau | PASS / PASS |
| mobile_reverse_transition_validation.luau | PASS / PASS |
| mobile_touch_validation.luau | PASS / PASS |
| public_race_controller_validation.luau | PASS / PASS |
| r8_d4_camera_validation.luau | PASS / PASS |
| r8_d4_restore_camera_validation.luau | PASS / PASS |
| race_audio_validation.luau | PASS / PASS |
| race_item_validation.luau | PASS / PASS |
| race_loadout_slots_validation.luau | PASS / PASS |
| race_network_ownership_validation.luau | PASS / PASS |
| rematch_reward_validation.luau | PASS / PASS |
| reserved_match_validation.luau | PASS / PASS |
| shield_restore_validation.luau | PASS / PASS |
| six_item_race_ui_validation.luau | PASS / PASS |
| slick_validation.luau | PASS / PASS |
| smoke_effect_view_validation.luau | PASS / PASS |
| speed_sensation_camera_validation.luau | PASS / PASS |
| speed_world_vfx_validation.luau | PASS / PASS |

추가 후보 검사:
- python tools/audit_source_freeze_r1.py --check-manifest:133개 파일이 원본 Git 객체와 일치,
  원본 역사적 artifact 유지 PASS.
- source_freeze_release_validation:682개 현재 무결성/변조 거부 검사 PASS.
- speed_sensation_qa_target_r2_validation:12개 QA 타깃/변경 범위 검사 PASS.
- Rojo build, git diff --check PASS.

FOV 계산/보간, Mini/Nitro 우선순위, 실제 카메라 owner의 위치 유지/수명주기,
GAS 전송/서버 cap, Touch/후진, 공유 아이템/Shield authority 검증이 양쪽에서 통과했다.
30/60 FPS 테스트는 결정론적 수치 검증이며 실제 기기 프레임 변동 캡처는 아니다.

## 6. Private QA 진행 가능 여부

| 조건 | 결과 |
| --- | --- |
| D1 FOV 때문에 새 실패 없음 |PASS:75개 기존 실패 +28개 핵심 쌍 비교|
| D2 FOV/GAS/Camera/Touch 핵심 |PASS:관련 쌍 검사와 현재 무결성 검사|
| D3 서버 물리/Ownership 변경 없음 |PASS:프로덕션 차이는 FOV3상수뿐|
| D4 기존 중대한 위험 없음 |확정 불가:완료/저장 관련 기존 실패 원인 미분리|
| D5 지정 QA만 적용 가능 |준비된 패치의 타깃 거부 검증 PASS, 미실행|

따라서 전체 판정은 **BLOCKED**, PRIVATE_QA_READY가 아니다.
FOV 후보 자체의 추가 실패는 없으며, 다음에 필요한 작업은 프로덕션 기능 임의 수정이 아니라
기존 warm-up 완료·ACK·계정 초기화의 원인을 isolated fixture에서 추가 분리하는 것이다.
이 작업에서는 그 결과를 임의로 정상/무해하다고 승인하지 않았다.

`tools/apply_speed_sensation_phase1_private_qa_r2.luau`는 이후 승인 시 사용할 준비 파일이다.
정확히 Universe10772198697 / Place106553302629620, Studio Edit 모드에서만 동작하며
공식 Universe/Place 및 교차 조합, Play/live, 예상 외 기존 소스를 모두 거부한다.
하나의 Shared.KDMSpeedSensation만 기존 정확한 소스→후보로 변경하고 Publish하지 않는다.
원본/후보 두 전체 파일은 R1 승인 해시 검사도 통과한다. 실제 Studio에서 실행하지 않았다.
접근 Private 설정 변경 기능도 포함하지 않는다. 게시 승인이나 실제 Private 확인을 대신하지 않는다.

## 7. 미검증 항목

Studio/native runtime NOT VERIFIED for R2. iPhone/Android 체감·멀미·HUD 가독성,
실제30/60 FPS 전환, 장시간 Rematch hitch, 실제 다인원/네트워크·live DataStore는 미검증이다.
부스터/니트로가 수치상 유지된다는 것과 실기기 연출 수용은 구분한다.
기존75개 실패 중 assertion 이후의 미실행 시나리오는 검증됐다고 주장하지 않는다.

## 8. 롤백 방법

R2 비교는 원본/후보 게임 파일을 변경하지 않았다. 새 R2 도구/보고서/미실행 QA 패치/타깃 테스트만
제거하면 R1 상태로 돌아간다. FOV와 R1 파일은 최초 보존 해시와 동일하다.
원본 detached worktree는 재현을 위해 깨끗한 상태로 보존했다. 필요 시 경로를 확인하고
git worktree remove로 해당 worktree만 정리할 수 있다. 현재 working tree reset/restore는 필요 없다.
FOV 원복은 별도 선택으로 정확히55/80/3 및 관련 기대값만 복원한다.

## 9. Git / Publish

Commit / Push / Roblox Publish **전부 미실행**. Studio 모델/공개 Place/QA 접근 설정 변경 없음.
원본 N1/N2 Fixture, 기존 실패 테스트 및 데이터 저장/구매 코드는 수정하지 않았다.

전체 증거: `speed_sensation_r2_comparison_20261028.json`에103개 쌍 전체 로그,
75개 분류·소스/테스트 근거·실행 환경·보존 SHA256·baseline clean 결과를 기록했다.
