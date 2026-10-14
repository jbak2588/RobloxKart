# KDM Checkpoint Floating Marker

Target: **KDM_CHECKPOINT_FLOATING_MARKER_MOBILE_HUD_PUBLISH** — Native candidate prepared; no Publish performed.

Baseline: `prototype/kart-physics`, `696a20e4a905ae99ff8aa936db41d2dae4226f76`; local/origin equality checked after fetch. Public PV663 remains unchanged by this task.

Scope follows the user's introductory instruction: **item 2 (Mobile Safe Area/HUD fix) is excluded**, because the preceding marker work did not change keypad positions. TouchDrivingController, MobileControlView, RaceHudController, button positions, touch bounds and ScreenInsets were not edited. This report does not claim a HUD clipping fix.

## Floating presentation

The pin's bottom-centre anchor floats above the road at 80% of the actual scaled original banner height. Both original checkpoint and finish flags measure approximately 15.2996 studs high, so the pin tip is approximately **12.2397 studs above the road**, between their upper portions. Text and pin remain one compact sign. Height is computed when constructing each target from the actual flag bounds and existing road surface; it is not a fixed world Y coordinate.

Kept the perspective size cap, bottom-centre alignment, AlwaysOnTop=false, camera-after-render update and kart/head overlap rejection. Added a gradual distant entrance: zero opacity at 350 studs, increasing to full opacity at 250 studs. Existing 50→26 stud near fade remains; no sign within 26 studs, behind the camera or overlapping the local kart/head. Distance uses the existing kart-to-anchor 3D measurement. Flags and floor checkers stay visible during sign fade.

Only production source changed: `src/client/CheckpointGuidanceController.luau`. Gate selection, per-player CP1–6 → FINISH → CP1, server progress/lap/record logic, physics, camera, VFX, audio, MY RECORDS, K$, Wing and kart assets are unchanged. Banner placement/scale, the 32 checker tiles and actual gate positions are unchanged.

## Validation and evidence

PASS: 1,721 production marker checks (including distant fade); 6,932 race presentation checks; 3,600 exact production camera frames; 2,805 mobile input/lifecycle/layout checks; 105 two-player race checks; 33 flame checks plus 160 four-racer VFX lifecycle checks; kart visual suite; compile of all 168 production Luau files; Rojo Build and whitespace checks.

Studio Play used the actual seated avatar/V2 kart and unchanged production chase camera with a temporary controlled approach fixture. It moved through lateral/yaw variations and CP1–6 → FINISH → CP1, including distant and near visibility boundaries. This is dynamic presentation verification, not natural race completion, a physical drift test or two-human network acceptance. All temporary Play objects were removed before saving Native.

- [Mobile dynamic video](studio-floating-mobile.mp4), [PC dynamic video](studio-floating-pc.mp4): 50 seconds each, captured at 20 fps. Capture fps is not a mobile performance benchmark.
- [Mobile floating sign](floating-mobile.png), [PC floating sign](floating-pc.png): same gate, 60 studs away. The sign is above the crossing and clear of the driver.
- [Actual render evidence](floating-studio.json): mobile 749×381, 2,400 samples; PC approximately 1269×600, 492 samples. Both observed all targets 0–6 and partial fades. No marker enabled in the <=26 stud region. Minimum road clearance 12.239687 studs, maximum banner-relative height error <0.000002 studs, horizontal gate-centre error zero. Pin-to-canvas-bottom layout error <0.00001 pixel.
- [Safety check](floating-safety.json): 32 unchanged crossing tiles; zero unanchored/collidable/touchable/queryable guidance parts; AlwaysOnTop=false.

Real-device visual acceptance and all-track natural driving remain user runtime checks after a separately authorized Publish. Existing geometry selection is preserved; this dynamic fixture exercised Practice geometry. Mobile HUD was intentionally outside scope.

## Native preservation

Candidate: `C:/dev/RobloxKart/artifacts/race-presentation-checkpoints/KDM_CHECKPOINT_FLOATING_MARKER_NATIVE_CANDIDATE.rbxl`

SHA-256: `e337cbae697d7eb1986290a8b546aadecb876fe73fead6b1db10c7792082ec8e` — 674,842 bytes.

Studio native Save As after stopping Play; no Lune serialization. [Semantic audit](floating-native-semantic.json): all 168 Sources match the repository after CRLF normalization; all 1,093 existing world/asset entries preserved, excluding editor Camera; no fixture scripts persisted. [Raw binary Terrain audit](floating-native-terrain.json): 70 groups and actual Materials content unchanged. Existing Native and rollback files were retained.

Previous candidate remains unchanged: `KDM_CHECKPOINT_MARKER_ALIGNMENT_NATIVE_CANDIDATE.rbxl`, SHA-256 `dfdd663d35d86bf325206148bf90891ce4370d7835ad25ab306bb39189d0bd07`.

Commit scope: marker controller, focused test, report and small audit evidence/helpers. Native/videos/images are local deliverables. Final local/origin revision is recorded in `floating-git-final.json` after push. No Publish, main integration, data initialization or account/record writes were performed.
