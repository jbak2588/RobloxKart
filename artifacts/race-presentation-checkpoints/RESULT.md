# KDM Race Presentation & Checkpoint Guidance

2026-10-14 — `KDM_RACE_PRESENTATION_CHECKPOINTS_READY_FOR_PUBLISH` candidate.

Implementation commit: `dcc10c39946069be1313d626432b14b6e71447cd` on `prototype/kart-physics`. Baseline: PV655 / `78a6aa016f9eb4017cbdc376e83a3892c611190c`. This report is a subsequent documentation checkpoint. No Publish or main integration was performed. Public PV655 remains unchanged.

## Implemented behavior

| Improvement | Result |
| --- | --- |
| Natural flame expiry | Existing six original emitters retain their textures/profile. Normal duration expiry fades Rate, cached Size levels, Brightness, LightEmission and both PointLights. The tail ends at 82 studs/s or after 2 seconds, whichever comes first. |
| Emergency termination | Unknown/cancelled exits fail closed. Re-drift, off-track, crash, combat interruption and inactive rendering clear the tail immediately. Existing observer teardown handles reset, seat loss, race end and kart destruction. |
| GO sound | Original StartPlayer `15617817566` uses AudioPlayer → Wire → AudioDeviceOutput. It plays once at COUNTDOWN→RACING; countdown stops first. Missing/not-ready/failed audio construction falls back to the existing three-beep pattern. Leaving racing stops GO and invalidates delayed fallback beeps. |
| Checkpoint guidance | Only the local next authoritative gate is displayed. Original CheckpointFlag, FinishFlag and CheckpointFrame/pin are reused. Two roadside flags and 32 thin checker tiles follow the actual gate/road width. CP6→existing StartFinish gate→CP1 next lap. Every visual Part is anchored, noncolliding, non-touching and non-querying. |
| Finish/results | Existing finish timing, place label and camera are retained. Added 48 checker UI cells with faded edges and outlined white FINISH text. Results background transparency is 0.40. |
| Lap notices | Valid completed-lap changes display `N LAPS TO GO` or `FINAL LAP`, from server total/completed mirrors. No opening/finished-lap notice; no lap-selection/schema expansion. |

The existing normal speed cap is 70; straight assistance can reach 80. Mini Boost exit deceleration is 10, Nitro exit deceleration is 15. Accordingly, the visual-only 82 cutoff remains above both normal caps. A 100→82 tail takes approximately 1.8 seconds for Mini Boost and 1.2 seconds for Nitro under these decelerations. Driving equations, speed/duration values, drift/camera, Nitro awards, smoke lifetime, engine A, item/account/record logic are unchanged. Server changes add only end-reason metadata for the renderer.

## Reference assets and security

Actual source: `C:/Users/OWNER/Downloads/Engine_sound_N_Nitro_vfx.rbxlx`, SHA-256 `784e04a5467f96f64c2cfd5013bdd3e7415ef78ad536dc47a39e28bd5a02d1fa`.

New `KDMRacePresentationResources.rbxmx` contains 28 instances including its root: two original flag models, original bubble/pin GUI, StartPlayer and TickPlayer. External Wire references were removed. No Script, LocalScript, ModuleScript, RemoteEvent or VehicleSeat was imported. TickPlayer `15617815911` is retained as a reference but does not replace the accepted countdown timing/audio. FINISH checker cells use native UI and introduce no new texture permission dependency. Existing accepted Nitro assets are unchanged.

## Validation and evidence

PASS: Luau compile, 168 production files; Rojo Build; git diff checks. The 25 related suites in [regression.json](regression.json) passed, including accepted drift/camera, mobile Touch, production Bot, two-player race/controller, Rematch/room, records, economy, Wing, kart audio/visual and world VFX. Additional production tests passed: 6,932 lap/gate/flame decisions and asset checks; 33 flame fade/emergency/allocation checks plus 160 four-racer lifecycle checks.

Studio Play used the production controllers with controlled attribute/velocity fixtures. These are dynamic rendering/state tests, not an actual completed multiplayer race:

- Track01, Track01Race, Track02 and Track03: targets 1–6 then target 0 (StartFinish), one target per controller, lifecycle cleanup. Practice check: 41 safe Parts per CP, 43 at Finish; unsafe Part count zero. Track03 concurrent simulated owners 2001/2002 selected CP1/CP3 and cleaned up. This establishes independent progress selection, not two-human network acceptance.
- Original GO ready=true, TimeLength=3.221333 seconds. Two countdown/Rematch-style cycles produced exactly two GO plays; repeated RACING updates did not replay it; stopped on Garage. Studio reported no error for this audio asset. DataStore API access was disabled and PlayerPreferences emitted its existing load warning; no persistence acceptance is inferred.
- Production renderer on an actual V2 clone, controlled planar velocities 100→82: Nitro RearEmitter Rate 80 active; Mini Boost 56 active. Rate/Size/Brightness declined to zero at 82; re-drift at 98 cleared immediately. The sampling fixture used a slower dt and therefore activated the existing half-density LOD during fading. This is separate from speed/physics tuning. Final continuous RenderStep capture confirms the complete original bright flame profile and visible decay.
- Actual HUD: 2-lap FINAL LAP; 3-lap 2 LAPS TO GO→FINAL LAP; 4-lap 3→2 LAPS TO GO→FINAL LAP. FINISH banner visible once on transition, 51 children including 48 checkers. Mobile emulator results showed lap times, RECORD SAVED, K$ breakdown and buttons legibly at 0.40.
- Four-racer repeated VFX simulation verifies no extra instances allocated during fade. Existing LOD halves density beyond 80 studs or dt>35ms and disables beyond 160. Guidance creates at most two flags/32 checker Parts for a target; no per-frame world scan.

Images:

- [Checkpoint/pin/flags](checkpoint-verified.png)
- [FINISH checker banner](finish-verified.png)
- [Original flame rendered](flame-verified.png)
- [Results 0.40](results-mobile.png), [same fixture at 0.08](results-before-008.png)

Dynamic videos:

- [Checkpoint sequence](studio-checkpoints.mp4)
- [Verified continuous Nitro/Mini Boost fade](studio-flame-fade-verified.mp4)
- [Lap/finish state sequence](studio-laps-finish.mp4)

Numeric evidence: [practice](studio-practice.json), [Track02](studio-track02.json), [Base](studio-base.json), [audio/flames](studio-audio-vfx.json), [HUD](studio-hud.json). Early capture files are diagnostic only; use the verified screenshots and flame video for visual review. Video capture frame rate is not a mobile FPS benchmark.

## Native candidate and preservation

Native: `C:/dev/RobloxKart/artifacts/race-presentation-checkpoints/KDM_RACE_PRESENTATION_NATIVE_CANDIDATE.rbxl`

SHA-256: `46827ee23b4e509fcfa841bf9e6997462950f85d6d107c2302d4a13027c08e53` — 675,942 bytes.

Studio native local download after stopping Play; no Lune reserialization. [Native audit](native-semantic.json): all 168 Sources exactly match the repository after line-ending normalization; no temporary test scripts persisted. All 1,061 existing PV655 world/asset entries match, excluding editor Camera and the four intentionally added source modules/new asset root. New visual/audio root has 28 safe instances. [Raw Terrain audit](native-terrain.json): all 70 groups preserved, including identical Materials content after SharedString relocation.

Rollback backup retained: `artifacts/lobby-vfx-audio-integration/KDM_PUBLISHED_PV655_VERIFIED.rbxl`, SHA-256 `bbdb2034bafd7ad917e55ca69bd1f0a877fbe7a288d20f9c2bd7efda72e030fa`. Existing earlier rollback files were not modified. No world/track geometry, kart/Wing, engine A, profile/record/economy data or payment activation was changed.

Modified implementation: default.project.json; new race presentation resource; BoostFlameEnvelope, CheckpointGuidanceController, RacePresentationState, RaceStartAudio; KartWorldExhaustRenderer, RaceAudioController, RaceHudController, client init; cosmetic metadata in PrototypeWorld/LobbyTestDriveService; test harness and two scoped validation suites.

## Remaining acceptance

Actual two-human + Bot network race, real-device low-end mobile FPS/audio/readability, all-track natural driving through gates, off-track recovery and Rematch require runtime acceptance. Studio controlled progress and four-racer simulation do not replace those checks. Persistence was protected by unchanged code and passing related tests, not a live DataStore write test. The existing lap selection still supplies its approved lap counts; 3/4-lap notices were exercised through controlled server-mirror values.

Before a separately approved Publish, verify the Native hash above. After Publish approval, check GO once, each player's own next checkpoint, CP6→Finish→new lap, flame decay and emergency removal, FINISH/results readability, mobile FPS, and unchanged records/K$ on two real devices. No Publish was attempted in this task.
