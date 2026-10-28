"""Build R2 evidence report from unchanged paired logs; never changes acceptance tests."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('state',type=Path)
args=p.parse_args()
state=json.loads(args.state.read_text())
root,out,baseline=map(Path,(state['original'],state['output'],state['baseline']))
comparison=json.loads((out/'comparison.json').read_text())
assert len(comparison['results'])==103
rules={}
def assign(names,category,source,needle,reason,impact):
    assert category in {'HISTORICAL_FREEZE','OUTDATED_TEST_EXPECTATION','TEST_MOCK_OR_ENVIRONMENT','POTENTIAL_RUNTIME_REGRESSION','UNDETERMINED'}
    lines=(root/source).read_text(encoding='utf-8').splitlines()
    at=next((i for i,line in enumerate(lines) if needle in line),None)
    assert at is not None,(source,needle)
    evidence={'path':source,'line':at+1,'excerpt':'\n'.join(lines[max(0,at-1):at+3])}
    for name in names.split():
        test=name+'_validation.luau'
        assert test not in rules,test
        rules[test]={'category':category,'reason':reason,'runtimeImpact':impact,'sourceEvidence':evidence}

assign('bot_internal_control r8_perf_p0 r8_perf_p1','HISTORICAL_FREEZE','src/server/PrototypeWorld.luau','GasPedalPolicy',
       'Tests remove only specific old hunks then require an old complete source body/string. f5ebec8 already includes GAS/authority/mobile-era additions.',
       'Historical snapshot incompatibility; not evidence that current input/physics failed. Current GAS/ownership tests pass.')
assign('finish_source_freeze speed_sensation','HISTORICAL_FREEZE','tests/fixtures/n2_source_freeze.json','FinishCameraComposition',
       'Original N1/N2 hashes predate approved release; R1 exhaustively reconciles the differences without changing those fixtures.',
       'FOV functional checks run before the old freeze error; dedicated current-release integrity and camera checks pass.')
assign('item_aftershock','HISTORICAL_FREEZE','src/client/KDMItemVFXController.luau','local',
       'Exact L1/K2 canonical freeze rejects later approved source. Both pristine HEAD and candidate fail at the freeze.',
       'Does not demonstrate an effect malfunction; current integrated item/VFX tests pass.')
assign('lobby_palette','HISTORICAL_FREEZE','src/client/GarageUiController.luau','local',
       'Non-color source comparison permits only its historical palette hunks, excluding subsequent approved shop/navigation/UI work.',
       'Historical source boundary mismatch; no new UI modification in R2.')
assign('park_a1_island_visual park_a2_landscaping','HISTORICAL_FREEZE','src/server/HubParkRookieLoopBuilder.luau','local',
       'Tests compare exact Park builder/layout bytes with older commits. Those files already differ in the approved release.',
       'Old scope-freeze failure, not a measured new geometry collision; R2 changes no geometry.')
assign('chevron_standard practice_figure8_geometry track_environment track_visual_standard','HISTORICAL_FREEZE','src/server/TrackBuilder.luau','local',
       'Generated-world/geometry signatures are frozen to older track snapshots, while the approved release contains later paint/grid/scenery changes.',
       'A frozen signature difference is not itself a runtime driving failure. Physical driving/track files are unchanged by the candidate.')
assign('lobby_terminology track02_published_binding track_h3_flow track_v2_geometry','HISTORICAL_FREEZE','src/shared/TrackCatalog.luau','Order =',
       'Exact catalog hash/non-display-field/inverse-hunk comparison predates the approved catalog and retired Track02 selection policy.',
       'Historical catalog compatibility check; does not prove a newly broken route.')
assign('rookie_loop_demo','HISTORICAL_FREEZE','src/shared/KartConfig.luau','MAX_REVERSE_SPEED',
       'Exact eceaec9-era KartConfig snapshot excludes the already approved reverse70 and later configuration changes.',
       'Current reverse/controller tests pass; reverting the config would undo approved functionality.')
assign('straight_speed','HISTORICAL_FREEZE','src/shared/KDMGameplayBalance.luau','BonusRequiredBoosts',
       'Test requires complete old DRIFT balance equality; approved HEAD already contains later tuning.',
       'No R2 tuning change. Historical balance mismatch is retained rather than rewritten.')
assign('v2_gauge_v1_audio','HISTORICAL_FREEZE','src/shared/AudioConfig.luau','local',
       'Exact asset/input freeze with a narrow old audio exception rejects later approved AudioConfig.',
       'Current engine/boost/race audio tests pass; no R2 audio changes.')
assign('activity_qualification r8_a3_service r8_a3b_integration','TEST_MOCK_OR_ENVIRONMENT','src/server/EconomyService.luau','local ShopCatalog=',
       'Old injected module-node lists omit the KDMShopCatalog dependency required by EconomyService; logs show missing node/path before the intended scenario.',
       'These mocks cannot establish live storage failure. No production DataStore was called and no purchase/storage code was edited.')
assign('four_player_race p0_race_identity_integration r8_a3_controller track03_four_player two_player_race','TEST_MOCK_OR_ENVIRONMENT','src/server/RaceController.luau','context:setSpawnCFrame',
       'Fake kart contexts do not implement setSpawnCFrame, now used by production grid placement; execution stops at a missing table method.',
       'Mock interface failure, not evidence of a native kart-context failure. Actual four-human/device acceptance is still not established.')
assign('missile smoke thunder','TEST_MOCK_OR_ENVIRONMENT','src/server/RaceItemController.luau','PrototypeWorld.reassertServerAuthority(player)',
       'Shield use inside these fixtures reaches the approved authority guard, but their PrototypeWorld stub lacks reassertServerAuthority.',
       'Failures occur in a mocked Shield setup, not a newly failing Missile/Smoke/Thunder effect. Current real-controller item/authority integration tests pass.')
assign('race_start_boost','TEST_MOCK_OR_ENVIRONMENT','src/server/RaceController.luau','reassertServerAuthority',
       'Old injected launch fixture references an absent mocked PrototypeWorld authority dependency.',
       'Cannot establish a real launch defect; current public-race/controller and authority launch checks pass.')
assign('multiplayer_foundation','TEST_MOCK_OR_ENVIRONMENT','src/server/RaceSession.luau','SetAttribute',
       'Removal path calls SetAttribute on a minimal fake object that lacks the Roblox method.',
       'Mock object contract failure; no changed participant/ownership source in R2.')
assign('lobby_practice_view','TEST_MOCK_OR_ENVIRONMENT','src/shared/LobbyPracticePolicy.luau','Color3.fromRGB',
       'Old fixture environment omits Roblox Color3 while the fleet policy now authors per-bot colors; policy load fails at fromRGB.',
       'Real Roblox supplies Color3; current Park practice-combat and mobile controller harnesses pass.')
assign('lobby_demo','TEST_MOCK_OR_ENVIRONMENT','src/server/LobbyDemoService.luau','LobbyPracticePolicy).BotFleet',
       'Legacy demo require mock supplies LobbyDemoRoute but not the newer LobbyPracticePolicy dependency; indexing BotFleet on the returned nil fails.',
       'Mock dependency failure before fleet playback; current Park startup/practice behavior must not be inferred broken from this fixture.')
assign('pit_garage_art','TEST_MOCK_OR_ENVIRONMENT','src/server/CompactHubBuilder.luau','local ok, failure = pcall',
       'Minimal legacy art/template dependency mock does not represent all current kiosk/template requirements; builder catches an extraction failure and falls back, violating the art-only assertion.',
       'Does not prove the asset-complete native Park Hub fails; baseline and candidate share the same builder and assets.')
assign('combat_hit_audio','OUTDATED_TEST_EXPECTATION','src/shared/AudioConfig.luau','NITRO_START',
       'Assertion hardcodes the old explosion asset/volume equality; current release has later approved boost/Missile-onset audio changes.',
       'Expected asset mismatch, not evidence of a new audio stop. Current audio regression tests pass.')
assign('datastore_idempotency','OUTDATED_TEST_EXPECTATION','src/shared/KDMShopCatalog.luau','Prices=',
       'The failed remote-purchase assertion expects10000-250=9750 for Smoke; current approved Smoke price is2500. This first failure is before later idempotency scenarios.',
       'No demonstrated duplicate debit from this assertion; cannot claim the remainder of this old test passed. Purchase code untouched.')
assign('drift_telemetry','OUTDATED_TEST_EXPECTATION','src/shared/KartConfig.luau','DEBUG_TELEMETRY = false',
       'Fixture expects one diagnostic log but uses DEBUG_TELEMETRY=false; production intentionally suppresses finish logger/diagnostic updates in that mode.',
       'Debug observability expectation, not a drift-motion failure. No tuning changes were made.')
assign('first60_hub_entry','OUTDATED_TEST_EXPECTATION','src/server/MatchRoomService.luau','local',
       'Exact source-string QuickPlay lookup assertion predates current track-aware Race Now routing.',
       'Text-pattern mismatch is not a failed live matchmaking scenario; no routing edits in R2.')
assign('gameplay_balance','OUTDATED_TEST_EXPECTATION','src/shared/KartConfig.luau','OFF_TRACK_BOOST_SPEED_MULTIPLIER',
       'Old public-key whitelist omits OFF_TRACK_BOOST_SPEED_MULTIPLIER, already present in approved HEAD.',
       'Configuration whitelist mismatch; FOV does not change this multiplier.')
assign('h1_drive_presence','OUTDATED_TEST_EXPECTATION','src/server/LobbyTestDriveService.luau','LobbyDriveActive',
       'Source-text presence assertion demands an exact older adjacent statement sequence after later lifecycle changes.',
       'Not an executed presence transport failure; no Lobby service source changes in R2.')
assign('hub_park_reference_course','OUTDATED_TEST_EXPECTATION','src/shared/HubParkRookieLoopLayout.luau','Slots',
       'Old strictly descending X-per-slot expectation conflicts with the approved paired main-road grid arrangement.',
       'Old layout assumption; candidate preserves every slot and geometry file.')
assign('hub_world_progression','OUTDATED_TEST_EXPECTATION','src/client/HubGuidanceState.luau','return "ROOMS", "RACE"',
       'Fixture expects fresh GARAGE guidance while current F60 source directly returns ROOMS/RACE.',
       'Intentional navigation-policy mismatch; not camera/input regression.')
assign('kart_v2_production','OUTDATED_TEST_EXPECTATION','src/shared/KDMV2VisualDefinition.luau','DriverSeatLocalCFrame',
       'Measured seat assertion expects old Y+.06000018; current approved lowered seat uses Y-.79.',
       'Old visual-seat measurement, not a changed server seat in R2.')
assign('kart_visual','OUTDATED_TEST_EXPECTATION','src/shared/KartVisualFactory.luau','local steeringCenter',
       'Test asserts old SteeringPivot(0,1.65,-1.05); current source uses lowered(0,.85,-.95).',
       'Approved steering artwork position mismatch; no physical geometry changes in R2.')
assign('lap_item_refill practice_figure8_race practice_three_lap race_mode','OUTDATED_TEST_EXPECTATION','src/shared/TrackCatalog.luau','Order =',
       'Shared race-mode fixture expects six selectable tracks including retired Track02; current approved catalog has five after inserting Metro.',
       'Execution stops at stale catalog expectations before downstream refill/race assertions. Those later scenarios remain unverified by these files.')
assign('lobby_drive_mobile_fix','OUTDATED_TEST_EXPECTATION','src/client/MobileControlView.luau','controlsV1Enabled',
       'Legacy pad/portrait Drift boundary assumptions predate approved five-button rounded controls and current safe-area layout.',
       'Current 5-button/Touch/reverse tests pass; no UI relocation in R2.')
assign('practice_public_bot','OUTDATED_TEST_EXPECTATION','src/shared/TrackCatalog.luau','TargetLaps = 3',
       'Fixture expects Desert to have2 laps (only Track01 allowed3); approved Desert entry now also has3.',
       'Expected-lap mismatch, not new lap-authority code.')
assign('r8_a2l1_canary_guidance','OUTDATED_TEST_EXPECTATION','src/client/HubGuidanceState.luau','return "ROOMS", "RACE"',
       'Multi-scenario old progression/Canary guidance fixture includes Garage-first/layout assumptions superseded by current direct room guidance.',
       'Historical navigation/Canary acceptance is not live economy acceptance; detailed scenario failures retained in logs.')
assign('r8_a3_hud','OUTDATED_TEST_EXPECTATION','src/client/RaceHudController.luau','recordSaveLabel.Text =',
       'Fixture expects save status in Results.Best; current HUD owns save state in the separate RecordSave label.',
       'Wrong result-label expectation; no evidence that pending save is being reported as confirmed.')
assign('r8_a4_economy','OUTDATED_TEST_EXPECTATION','src/server/RaceRecordOperations.luau','Base completion reward is guaranteed',
       'Old test expects zero money for an ineligible finished record; current source deliberately guarantees a base completion reward and gates PB/event rewards on eligibility.',
       'Existing reward-policy difference. This review does not approve changing reward policy or assert live storage correctness.')
assign('r8_a4_hud','OUTDATED_TEST_EXPECTATION','src/client/RaceHudController.luau','REWARD +K$',
       'Fixture demands the older K$50/BASE35/RACE PB10/LAP PB5 text; current confirmed reward presentation uses rank-prize/PB/event wording.',
       'Text formatting mismatch; pending/unconfirmed handling must not be inferred failed from this assertion.')
assign('r8_d2_presentation','OUTDATED_TEST_EXPECTATION','src/client/KartWorldExhaustRenderer.luau','trail.Lifetime =',
       'Fixture uses official karts but requires lifetime6; current source assigns official2.5 and Lobby6.',
       'Old visual-lifetime expectation; current speed/world/item rendering tests pass.')
assign('r8_perf_p2b','OUTDATED_TEST_EXPECTATION','src/client/RacePerformanceMonitor.luau','local',
       'Exact summaryScroll/field-order source-string assertion predates subsequent performance UI edits.',
       'Diagnostic UI assertion, not measured render FPS or ownership stalls.')
assign('r8_perf_partner','OUTDATED_TEST_EXPECTATION','src/shared/KDMPerformanceBuffer.luau','11734277722',
       'Fixture allows old diagnostic account11736539305; current explicit allowlist uses11734277722.',
       'Diagnostic access-policy mismatch, not race admission/input authorization.')
assign('race_item_reset','OUTDATED_TEST_EXPECTATION','src/shared/RaceItemSlots.luau','Retired protocol',
       'Fixture asserts SetTacticalLoadout succeeds; current source intentionally retires tactical selection and supplies six fixed items.',
       'Old prep protocol assumption; current six-item/loadout/reset integration passes.')
assign('race_launch_routing','OUTDATED_TEST_EXPECTATION','src/shared/TrackCatalog.luau','Track01 =',
       'Fixture expects Track01 arrival MaxPlayers1; current Track01 is a public multiplayer track.',
       'Old track-role/selection assertion; no payload or admission change in R2.')
assign('repeatable_nitro','OUTDATED_TEST_EXPECTATION','src/shared/KDMGameplayBalance.luau','BonusRequiredBoosts = 3',
       'Fixture requires5 boosts but approved HEAD already configures3. Historical AGENTS prose is inconsistent with this accepted source snapshot; R2 does not reconcile tuning.',
       'Existing policy/documentation discrepancy; current item integration exercises the actual configured award logic.')
assign('rookie_loop_fleet','OUTDATED_TEST_EXPECTATION','src/shared/LobbyPracticePolicy.luau','id = 7',
       'Fixture requires exactly4 bots; approved Park policy has7 distinct color entries.',
       'Old fleet-size expectation; not an additional R2 performance load.')
assign('straight_speed_kart','OUTDATED_TEST_EXPECTATION','src/shared/KartConfig.luau','MAX_REVERSE_SPEED = 70',
       'Fixture expects reverse24; approved release uses gradual reverse70.',
       'Current reverse ramp/controller regression passes; restoring24 would undo owner direction.')
assign('track01_figure8_environment track_horizon_environment','OUTDATED_TEST_EXPECTATION','src/server/TrackBuilder.luau','local',
       'Assertions require old exact SpeedCue/VisualPartCount counts that predate approved cue/paint/scenery cleanup.',
       'Old decoration-count expectation; no R2 scenery/geometry change.')
assign('track02_barrier_safety_b track02_raceability_b v2_public_multiplayer','OUTDATED_TEST_EXPECTATION','src/shared/TrackCatalog.luau','Track02 =',
       'Legacy Track02/V2 candidate diagnostics demand an older geometry/direction-marker/identity contract; Track02 is now outside selectable QA track scope.',
       'Retired-track compatibility follow-up; not evidence of a new selected-track regression.')
assign('lobby_shield_visual','UNDETERMINED','src/client/KartWorldVFXController.luau','local enabled=human',
       'Old practice world-observer fixture does not produce KDMShieldWorld at its assertion. The precise observer lifecycle/mocking cause is not established from the paired logs.',
       'Could be a stale fixture or an existing Park Shield presentation defect; current shared item/ownership tests pass but native Park Shield parity remains unverified.')
assign('rookie_loop_manual_drive','UNDETERMINED','src/shared/RookieLoopDriveGeometry.luau','function',
       'Fixture expects origin excluded as old Lobby island; current geometry reports it inside. Whether this is an obsolete island assumption requires a geometry-specific review.',
       'No new geometry difference; old boundary assertion remains unresolved, not auto-approved.')
assign('r8_perf_p2c','UNDETERMINED','src/shared/KDMProgressionSchema.luau','local',
       'Test can no longer reproduce its old canonical-size capacity refusal. Receipt/schema compression has evolved; exact root of the changed reproducer was not isolated.',
       'Does not demonstrate a current storage capacity failure; large-account behavior still cannot be accepted from this failed reproduction.')
assign('r8_a4_runtime','UNDETERMINED','src/server/RaceRecordOperations.luau','money.firstFinish=5000',
       'Lost-ACK assertion expects wallet7500/lifetime2500; current reducer has newer event/base policies. Both runs fail, but actual output and duplicate-credit causality were not isolated.',
       'Potential storage/reward acceptance gap: do not claim exactly-once live payment proven. Requires a separate focused non-live diagnostic, not a production reward change.')
assign('r8_a6_public_cash','UNDETERMINED','src/server/EconomyService.luau','local ShopCatalog=',
       'Fixture account() returns nil before its expected starter-cash assertion. Unlike older fixtures it does include ShopCatalog; initialization/environment vs actual startup failure is not isolated.',
       'Existing account-initialization uncertainty; no R2 storage calls or source edits. Must not dismiss as a known missing dependency.')
assign('public_warmup_records','POTENTIAL_RUNTIME_REGRESSION','src/server/RaceController.luau','local function updateComplete()',
       'Controlled warm-up fixture fails to reach expected COMPLETE after human finish and bot timeout. Current updateComplete requires all participants terminal; the blocking participant/timing is not yet isolated.',
       'Existing potential round-settlement/Rematch issue. Not a proven native bug or FOV regression, but relevant enough that broad PRIVATE_QA_READY cannot be asserted without resolving the ambiguity.')

failed=[r for r in comparison['results'] if r['priorFailure']]
assert len(failed)==75
assert set(rules)=={r['test'] for r in failed}, {'missing':set(r['test'] for r in failed)-set(rules),'extra':set(rules)-set(r['test'] for r in failed)}
for row in comparison['results']:
    for label in ('baseline','candidate'):
        row[label]['log']=(out/label/(Path(row['test']).stem+'.log')).read_text(encoding='utf-8')
    if row['test'] in rules:
        row.update(rules[row['test']])
        path=root/'tests'/row['test']
        text=path.read_text(encoding='utf-8').splitlines()
        log=row['candidate']['log']
        locations=re.findall(r"Script '[^']*"+re.escape(path.stem)+r"', Line (\d+)",log)
        line=int(locations[-1]) if locations else 1
        row['testEvidence']={'path':'tests/'+row['test'],'line':line,
            'excerpt':'\n'.join(text[max(0,line-2):min(len(text),line+2)])}
counts=Counter(row['category'] for row in failed)
comparison['classificationCounts']=dict(counts)
comparison['decision']='BLOCKED'
comparison['decisionReason']='No new FOV failures; current release integrity/core tests pass. Existing warm-up COMPLETE failure plus unresolved ACK/account initialization evidence prevent ruling out material QA-loop/storage risks under condition D4. This is not a claim that FOV caused them.'
comparison['preservedHashes']=state['preserved']
comparison['preservationPass']=all(hashlib.sha256((root/path).read_bytes()).hexdigest()==sha for path,sha in state['preserved'].items())
comparison['baselinePristine']=not subprocess.check_output(['git','status','--porcelain'],cwd=baseline,text=True).strip()
assert comparison['preservationPass'] and comparison['baselinePristine']
destination=root/'docs/testing/speed_sensation_r2_comparison_20261028.json'
destination.write_text(json.dumps(comparison,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'pairedTests':len(comparison['results']),'classification':dict(counts),
 'newFailures':[r['test'] for r in comparison['results'] if r['comparison']=='NEW_FAILURE'],
 'decision':comparison['decision'],'preservation':comparison['preservationPass']}))
