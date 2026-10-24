# Figure-8 original-template desert staging — 2026-10-24

Baseline 4d5c067a39b2ebf487a622ed815601fc632545a6, clean entry; fetched remote matched.
Authorized test Universe 10772198697 / Place 106553302629620 is KDM_New_Hub.
Production Place 127925465904803 is excluded, even with a live preview flag.

Source C:/dev/rbxlx_data/Hub_n_lobby_original.rbxlx SHA256:
784e04a5467f96f64c2cfd5013bdd3e7415ef78ad536dc47a39e28bd5a02d1fa.
Source file itself was not edited. No new marketplace/generated scenery.

Four original palette prefabs, five original material variants, original Sky,
Atmosphere and ColorCorrection only. No scripts, template roads, gameplay,
Grass_b or Racing_Sand_Grass imported. Runtime meshes grounded, scale/yaw varied,
anchored, noncolliding/non-touching/non-querying/no shadows. Final 120 sites:
28 cactus, 31 agave, 32 tumbleweed and 29 boulders. Actual road-centerline
clearance >68 studs; crossover center exclusion 130 studs.

Terrain surface sampled from original at 4-stud resolution: x[-1792,640),
z[-1152,640), y[-8,256). Quarter-stud surface quantization, upper sample cap 256.
This is a sampled height/material reconstruction, not a byte-for-byte TerrainRegion
copy. Eight bounded data modules avoid Studio's 200KB Source setter limit.
Original relief is translated (+576,+336 in X/Z), not replaced with invented hills.
The x[-400,400], z[-440,608] road/recovery rectangle is never written; edge relief
blends outward over 160 studs. Grass/LeafyGrass samples become source Sand.
872 bounded terrain tiles; no frame loop or replicated gameplay geometry added.
Original infield/support appearance changes are client-only, reversible; native
road/support collision and all physics/ownership sources are untouched.

Validation:
- figure8_desert_validation: 275507 policy/source/height/actual-road-clearance checks.
- practice_figure8_geometry_validation: 43139 accepted geometry/continuity/world/
  minimap checks. Centerline length remains 2478.535506248474.
- practice_figure8_race_validation: 76 production-controller checks.
- Production source compile, default XML and preview binary Rojo builds, diff check.
- Existing track_horizon_environment_validation fails its old HUB VisualPartCount
  ==1366 assertion before client scenery tests; TrackBuilder is unchanged in this
  task. This old-count suite is not reported PASS.

Studio isolated preview: actual runtime/source meshes/materials, native kart view,
no visible grass parts, zero unsafe decoration parts. Final terrain build about
5.37 seconds on this desktop, improved from 10.12 seconds for first candidate.
No mobile FPS, thermal or memory claim follows from desktop construction timing.
Controlled 95-stud/s route replay exercised six ordered gates each lap, three laps,
FINISHING then FINISHED: 26.33 / 26.07 / 26.10, total78.53 seconds. It is not a
manual steering/physics lap, real multiplayer or live economy acceptance. The QA
replay followed an earlier failed probe/DNF and included ordinary fall recovery;
those probes are not counted as successful manual tests. All temporary QA bootstrap,
attributes and camera probes are removed before source audit and publication.

Mobile iPhone/Android heating, sustained FPS, live texture permissions, teleport
entry and Rematch acceptance remain user-device tests. Default staging entry keeps
the existing Hub -> Figure 8 track selection -> race flow, with same-place reserved
teleport. No production routing or economy policy change.

Final release bootstrap Studio check: role HUB, GARAGE state, KDMHub present,
no MessageError; candidate true but desert rendering remains RACE Track01 only.
Edit source audit: all 222 script/data sources match repository hashes; temporary
QAOriginalSource attribute removed, no extra LuaSourceContainer remains.

Mobile glare follow-up: direct daylight Brightness 3 -> 2, fixed exposure -0.2,
source color correction softened (brightness -0.02, contrast 0.08, saturation 0.04).
Sand uses RGB 224/218/205 instead of white; original maps retained. Desert cleanup
restores prior exposure as well as lighting/material appearance. Studio runtime
confirmed applied values, terrain completion and brightness/exposure restoration.
275507 focused checks, 222-source compile, Rojo XML build and diff check pass.
This is a lighting-only follow-up; no new driving or mobile comfort PASS claimed.

Kerb/skid follow-up: Studio confirms Figure-8 Road.CanQuery=false. Shared exhaust
previously queried that folder, preventing tire trails from enabling. Figure-8
now intersects bounded visual road top planes (cached nearby slice search, including
raised crossover ribbons); other tracks retain existing raycasts. No collision or
query flags changed. Regression covers both marks, surface height, airborne and
road-boundary rejection; remote VFX/culling suites and source/build checks pass.
Desert-only visual kerbs raised 0.04/0.06 studs to separate coplanar red/white overlaps
and edge lines. Asphalt RGB 56/59/65 -> 78/81/86 improves black-mark contrast.
Studio actual kart renderer enabled both trails; environment teardown restored
kerb frames and road color. Manual/mobile moving flicker and skid visibility remain
user-device checks; no new full-lap PASS claimed.
