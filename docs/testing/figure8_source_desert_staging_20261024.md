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

## Island / roadside source follow-up — 2026-10-25

Baseline 1ace1bd; clean entry and fetched remote matched. Owner now permits original
DRY yellow tufts; no green turf. Added original Racing_Foliage_Grass_b and actual
MaterialService AsphaltName override Racing_Asphalt_A. The original road mesh tint
is RGB 226/220/188; earlier Figure-8 used 56/59/65, then 78/81/86. Original indirect
lighting scales are 1/1 versus inherited 0/0. Candidate keeps reduced sun 2 and
exposure -0.2, uses diffuse .8 / specular .25, softer ambient and a matte asphalt
copy (source color/normal/roughness retained, metallic map disabled). No new art.

Nineteen separated 20 x 4.5 x .5 Park-size advertising panels replace overlapping
straight rail slices client-side; corner chevrons remain. Minimum measured panel
center gap 49.98 studs. Panel footprint centerline distance >=44; original rail/GUI
state restored on cleanup. Adjacent cactus/rock/agave clusters retain >=68 centerline
clearance. Original static tumbleweeds removed from planting, not made into a new
wind simulation.

One island dune uses a low original sampled height patch, scaled/tapered into an
ellipse at (0,338), radii84/64. Raised footprint tested against actual road >=68.
The nine added native Terrain tiles have a below-floor base to avoid an exposed
rim. This island is the owner's explicit exception to the old rectangular exclusion.
Road geometry, support, triggers, checkpoints and physics unchanged. Planting waits
for terrain, samples actual Terrain height and the flat floor, then buries 38% of
boulder height. No moving foliage, shadows, lights or per-frame environment work.

Studio final layout: 19 panels, 34 cactus, 34 agave, 38 boulders, 64 small original
dry tufts (28 on the dune; remainder roadside), zero planted tumbleweeds. 170 palette
instances;881 terrain tiles. Construction around3.87 seconds on this desktop.
All38 boulder bounds below sampled ground, zero unsafe decorative BaseParts;
actual road material/appearance, hill profile and panel spacing visually reviewed.
Cleanup restored original road color and original advertising GUI visibility.
This is visual/placement validation, not mobile thermal/FPS or full manual-lap PASS.

Checks: 276566 source/isolation/terrain/dune-clearance checks;43139 geometry checks;
76 production race-controller checks;25 world-VFX/skid regression checks;222-source
compile; Rojo XML and binary builds; git diff --check. Mobile moving shimmer,
road contrast, live texture permissions and sustained performance remain device QA.

## Ordinary-client capability correction — 2026-10-25

Owner screenshot after v51 showed only road tint applied, with green infield,
old sky and rails. Reproduced under an ordinary LocalScript (not MCP execution):
The current thread cannot write MetalnessMap (lacking capability Plugin).
The privileged MCP preview had masked this client capability failure; the prior
v51 visual review did not establish successful ordinary-client startup.

Removed the runtime texture-map assignment. The empty asphalt metallic map is
now baked into the resource prefab in Edit; runtime only clones that variant.
Added baked-prefab regression (276567 checks PASS).222-source compilation,
Rojo XML and diff checks PASS. Ordinary LocalScript controller startup completed
with zero MessageErrors, SOURCE_DESERT / TerrainReady,881 tiles,170 natural
instances,19 ad panels,64 dry tufts and1 dune. Native Client initializer was also
exercised in Studio with temporary RACE attribute and GarageControl fixture:
CLIENT sync OK role=RACE; infield hidden=1, correct source sky, complete same counts,
zero MessageErrors. This tests ordinary client capability/startup, not a live
reserved-server teleport or a full driven lap. All temporary QA scripts, bootstrap
changes and fixture remotes removed by Stop/restoration before publishing.

## Crossing cliffs / three-sign corners — 2026-10-25

Owner approved implementation after the read-only feasibility review. Added three
static sampled-source mesas at (-230,-25),(230,-25),(0,190), ellipse radii60/90,
60/90,45/65. Source patch around column512/48 is rotated/scaled, with an edge
blend and height caps110/110/60; not a giant scaled decorative boulder. The raised
footprints preserve >=68-stud actual road centerline clearance and >=130-stud
crossing-center exclusion. Native voxel surface smoothing still needs device-view
acceptance. No road, support, physics, checkpoints, routing or kart changes.

Desert-only selection keeps three original chevron sign panels near quarter,
half and three-quarter corner stations, with >=20-stud sign-center separation.
Original image/direction retained; other panels/GUI hidden locally and restored
on teardown. Ordinary LocalScript controller startup: zero MessageErrors,
SOURCE_DESERT / TerrainReady,3 cliffs,1 dune,911 tiles (+30),19 ad panels,
12 visible chevrons. Actual nearest-corner counts3/3/3/3. Existing170 palette
instances and64 dry tufts retained. Desktop construction about4.74 seconds;
not a mobile thermal/FPS result or full manually driven-lap acceptance.

281908 focused terrain/source/clearance/chevron checks,43139 Figure-8 geometry
checks,25 world-VFX/skid checks,222-source compile,Rojo XML and diff checks PASS.
Temporary ordinary-client startup fixture removed before publication. Publish
scope remains Universe10772198697 / Place106553302629620 only.

## Native grass clarification / road shimmer attempt — 2026-10-25

Owner clarified that the intended dry grass is the original Terrain blade
rendering, not the imported Grass_b round clump. Removed both Grass_b and tumbleweed
prefabs and all64 round placements. Imported source Racing_Sand_Grass instead;
original template Terrain has Decoration=true,GrassLength0.1. These properties
are non-scriptable: test preview and published Studio test place use baked0.1;
default project retains its prior0.7 to avoid an unrelated production change.
Native Grass voxels cover irregular dune areas and12 small shoulder patches;
Grass color204/190/140 yields golden blades. Shoulder sample centers stay >=44
from centerline (>=12 road-edge allowance including2-stud voxel half-width).
ReadVoxels preserves neighboring mesa data outside the small patches. Native
blade behavior reference: https://create.roblox.com/docs/parts/terrain.

Road overlap is distinct from specular reflection. The source uses the same
normal map without the Figure-8 overhanging Part seam arrangement. A depth-layer
experiment produced visible fine seams and was discarded. Final road Y is unchanged;
152 straight noncolliding visual slices now end at their actual chord endpoints,
removing coplanar straight overhang. Curved geometry and the actual physical
support remain unchanged. Original normal map restored; no new runtime map writes.
No universal shimmer-removal or mobile moving-view PASS is claimed.

Ordinary LocalScript environment startup: zero MessageErrors;923 tiles,3 cliffs,
1 dune,19 panels,12 chevrons,106 cactus/agave/rock instances,0 round clumps,
12 shoulder patches. Native blades visually confirmed on dune; source normal map
and unchanged road Y confirmed. Cleanup fixture removed. Focused282057 checks,
43139 geometry checks,25 skid/world-VFX checks,222-source compile,default/preview
Rojo XML and diff checks pass. Mobile shimmer, grass readability and sustained
rendering/thermal acceptance remain owner-device checks.

## Roadside grass removal / one-sided chevrons — 2026-10-25

Owner mobile review rejected the12 isolated native shoulder grass patches as
burial mounds. Removed their voxel construction entirely; the existing island
dune and its grass remain. Desert-only chevrons disable their outward-facing
SurfaceGui, using the nearest road segment to choose the inward face. Cleanup
restores prior GUI state. Original sign count, front image and road geometry stay
unchanged. No replacement grass mounds or additional scenery.

Validation: 282061 focused checks, 43139 Figure-8 geometry checks, all222 production sources compile, Rojo preview XML and diff check PASS. Ordinary Studio LocalScript runtime:12 enabled road-facing sign GUIs,12 disabled rear GUIs,0 shoulder patches; no environment/QA script errors. Mobile appearance remains owner verification.
