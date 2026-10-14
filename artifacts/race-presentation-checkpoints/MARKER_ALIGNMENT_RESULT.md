# KDM Checkpoint Marker Visual Alignment Fix

Status: **KDM_CHECKPOINT_MARKER_ALIGNMENT_READY_FOR_PUBLISH** (Publish not performed).

Baseline: `prototype/kart-physics`, `0cdf18e27720534dfac610bd9f48525b641b9254`. Local HEAD and origin matched after fetch. User supplied PV663 mobile acceptance for checkpoint sequencing and flame decay; this task changes only checkpoint presentation.

## Change

`CheckpointGuidanceController.luau` now anchors the pin's bottom centre to the actual checker crossing centre, 0.075 studs above the road surface. Removed inherited AutomaticSize/padding and the old 210×115 fixed-pixel, elevated, AlwaysOnTop presentation. Text and pin share one bounded canvas; the original font, pin texture, flags and crossing tiles remain.

Perspective scales the sign with camera depth/FOV/viewport height, capped at 200 pixels and 36% of viewport height. Opacity decreases between 50 and 26 studs from the kart; at 26 studs or less the sign is hidden. It is also hidden offscreen, behind the camera, beyond 350 studs, or when its projected rectangle overlaps the local kart/head bounds. Flags and crossing remain visible during sign fade. Rendering runs after the unchanged chase camera; kart bounds are cached on seat changes, with no per-frame world scan. Render binding and connections are removed on destruction.

Also handles a Humanoid arriving after CharacterAdded so the first seating event creates guidance without requiring another progress update. Next-gate selection and server mirrors are unchanged: one local target, CP1–6 → Finish → next-lap CP1. No server, physics, camera, VFX, audio, record, economy or asset source was edited.

## Validation

PASS: 1,281 production marker perspective/proximity/overlap checks; 6,932 race presentation decisions and asset checks; 3,600 exact production camera frames; 2,805 mobile control/lifecycle/layout checks; 105 synchronized two-player checks; 33 flame checks plus 160 four-racer VFX lifecycle checks. Kart visual suite and compile of all 168 production Luau files passed. Rojo build and git diff whitespace checks passed.

Studio Play used an actual seated avatar/V2 kart and unchanged production chase camera. A temporary fixture moved the kart through 160→−20 stud approaches with lateral/yaw variation and controlled next-gate mirrors. This tests dynamic presentation, not a naturally completed race or a two-human network session. Fixtures were removed by stopping Play before Native saving.

- [Mobile dynamic video](studio-marker-mobile.mp4), [PC dynamic video](studio-marker-pc.mp4): each 43 seconds, CP sequence and approaches.
- [Mobile aligned screenshot](marker-mobile-aligned.png), [PC aligned screenshot](marker-pc-aligned.png): same gate at 60 studs; pin tip points to the checker line and the driver is clear.
- [Render samples/summary](marker-studio-summary.json): mobile viewport 749×381, PC 2302.4×684. Mobile early and later samples together include targets 0–6; PC includes all 0–6. Maximum pin-tip-to-canvas-bottom error <0.00001 pixel. No enabled marker within 26 studs; partial fade observed on both cameras. This numeric error measures GUI layout alignment, with visual crossing alignment checked in captures; it is not an image-derived pixel measurement.
- Independent local controllers for owners 11700555357/2002 selected CP1/CP3 simultaneously and the second controller cleaned up. This is simulated ownership, not two-human acceptance.
- [Lifecycle evidence](marker-lifecycle.json): DNF/Garage/Finished/seat exit leave zero targets; RACING restores exactly one.

Videos are captured at 20 fps and are not device FPS benchmarks. Actual PV663 mobile screenshots supplied the original defect; the corrected candidate still needs user real-device visual acceptance after a separately authorized Publish. Existing track surface/direction selection is unchanged; dynamic approaches here exercised the Practice geometry, not natural driving on every track.

## Native and preservation

Updated local Native: `C:/dev/RobloxKart/artifacts/race-presentation-checkpoints/KDM_CHECKPOINT_MARKER_ALIGNMENT_NATIVE_CANDIDATE.rbxl`

SHA-256: `dfdd663d35d86bf325206148bf90891ce4370d7835ad25ab306bb39189d0bd07` — 674,711 bytes.

Saved with Studio's native Save As after stopping Play; no Lune serialization. [Semantic audit](marker-native-semantic.json): 168 Sources exactly match the repository after line-ending normalization; no test scripts persisted; all 1,093 prior world/asset entries preserved, excluding editor Camera. [Raw binary Terrain audit](marker-native-terrain.json): 70 groups preserved, including identical 323-byte Materials content. Source changes are limited to this controller; kart/Wing, kiosk, engine A, approved VFX, tracks, world and Terrain remain intact.

Retained backups:

- Prior Native: `KDM_RACE_PRESENTATION_NATIVE_CANDIDATE.rbxl`, SHA-256 `46827ee23b4e509fcfa841bf9e6997462950f85d6d107c2302d4a13027c08e53`.
- PV663 edit-session native copy: `KDM_PV663_EDIT_BACKUP_NATIVE.rbxl`, SHA-256 `14538e15d976b9cf70bbf5115c4ab08b2df360f52deeefb0b55f3e0b730f1949`, 673,650 bytes. Compared read-only with prior Native: 168 Sources, 1,093 world/asset entries and 70 Terrain groups equal. This is an edit-session backup, not a newly downloaded public-version proof.
- PV655 verified rollback: `artifacts/lobby-vfx-audio-integration/KDM_PUBLISHED_PV655_VERIFIED.rbxl`, SHA-256 `bbdb2034bafd7ad917e55ca69bd1f0a877fbe7a288d20f9c2bd7efda72e030fa`.

Commit/push scope: controller, focused validation, this report and small audit evidence/helpers. Native/images/videos remain local deliverables. The implementation revision is the commit containing this report; final local/origin equality is recorded in `marker-git-final.json` after push.

No Publish, main integration, DataStore initialization, account/record writes or economy changes were performed. Public PV663 remains unchanged by this task.
