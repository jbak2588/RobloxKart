# Metro City Circuit — 2026-10-26

## Roadside / checkpoint release candidate

Owner explicitly authorizes Commit / Push followed by Publish after verifying
Rookie Racing Park HUB. Baseline d4a8f2e matched origin at task start.

Metro-only asphalt keeps Desert's color/roughness/tiling, removes the micro
NormalMap and disables environment specular for a matte road. Restore the prior
specular setting and all source materials on scene teardown. Other tracks retain
their source material and lighting. No physics/authority/route/gate changes.

Extract the original StreetLights/StreetLamp_A as four inert parts (three native
meshes plus source LightSource); preserve source PBR, dimensions and shape. No
source spotlights/Beams/scripts cloned. Total Metro palette 2,536 parts.
64 lamps at uniform arc-length stations (~85 studs), alternating sides; every
lamp footprint stays at least 12 studs outside the road. 46 Park-style KDM rails
use the same road-facing 20 x 4.5 artwork, alternating red/white. Full projected
building widths plus 35 studs and a 350-stud outward frontage search exclude ads
from facades/entrances. Rails stay >=16 studs outside asphalt, avoid lamps and
remain inert. 83 buildings, two skybridges and 62 Park Maples retained.

Wrong-way / rejected finish does not advance/reset server progress. Ordinary pins
fade outside 350 studs and can be occluded by city buildings. While authoritative
RaceCheckpointMissed>0, the same required pin uses a 2,000-stud range, minimum
56px width and AlwaysOnTop; kart overlap, near fade and camera direction checks
still apply. Accepted checkpoint clears the missed mirror and restores ordinary
range/occlusion. Missing visual folders can rebuild on missed/reset events.
Native Client verified unchanged next=1, missed pin visible at 600 studs, hidden
when facing away, visible again on turning back, then next=2 restores range350.
This is a presentation/mirror test, not a claimed manual reverse-driven lap.

Native production-bound Studio reports Universe10768420544 / Place127925465904803,
loaded Edit snapshot PlaceVersion1161 (not the latest cloud-version number), persisted HubParkV1Enabled=true. Ordinary HUB startup
creates HubParkRookieLoopG2 with ROOKIE_LOOP_V1; no legacy LobbyFrontTestDriveZone.
All 215 primary server/client/shared scripts match the repository modulo trailing
newlines. Default Rojo builds now explicitly carry the Park flag, avoiding a
fresh-build fallback to the old front drive zone. Policy retains role/ID/Bot gates.

PASS: Metro 11,131; source resource audit; checkpoint marker 1,730 (including nine
missed-distance checks); six-track paint971; skid25; checkpoint/DNF21; Park
startup20 / world initialization674; lap/presentation6,932; route recovery3,185;
continuity/reverse/two-lap86,203; 225 Luau sources compile; default Rojo release.
Native candidate before final frontage widening had14,655 scenery parts; final
candidate removes33 rails. Existing Studio DataStore API-access warnings remain;
no new live DataStore, four-human mobile or device performance acceptance claimed.
Release source committed/pushed as cbd9b74650c58471053e79026e0ae027798692b0
before Publish. Studio Publish succeeded as v1192, confirmed by native Output:
"place published", "add publish notes to v1192", and the named KDM success line.
Production target remains Universe10768420544 / Place127925465904803. Marketplace
Updated confirms 2026-10-26T06:23:15.168Z (13:23 Jakarta). KDMBuildCommit on the
published snapshot is cbd9b74650c58471053e79026e0ae027798692b0 and the persisted
Park flag is true. Verified all2,248 Metro native mesh identities before Publish;
no temporary QA scenes were present. No running servers were forcibly restarted.
The loaded Edit PlaceVersion remains1161 after Publish, so it is not used as the
release receipt; the Studio v1192 success output is the release evidence.
Published mobile visuals/heat and live multiplayer acceptance remain separate.


## Current clear landscape and full-track overview

Owner refinements replace the remaining gray floor / partial shops / beech trees,
extend both U outsides, reduce the thick atmosphere and capture the complete course.

All 83 placed buildings use complete native Kit_* models. Remove both partial
Shop_14_bldg / Shop_28_bldg resources and their fabricated StreetShell parts, plus
the old Metro CityBeech resource. Building palette: 2,522 parts plus two five-part
native bridges (2,532 total). Existing bridge anchors, Base-derived route, Desert
road material, skid repair, actual slots, gates and other five tracks stay intact.
Both U outsides now have eight buildings each; rear-start quarters have four each
plus the rear-straight building. Full rotated footprints retain the 24-stud shoulder.

Metro trees directly clone ReplicatedStorage.KDMHubForestTreePrefabs.CityMaple,
the dominant Rookie Park species. Source Park files/placements are unchanged.
Plant with the same Trunk bottom + two-source-stud root collar and -.2-stud target
used by Park, preserving native mesh orientation; seeded scale .8–1.25 and yaw
0–360 degrees vary per site while remaining stable through Rematch. 62 Maples.
World-axis prefab bounds and conservative canopy radius certify recovery clearance.
No original beech tree clones remain in the Metro scene or its private palette.

Every exposed ground layer (Infield, SafetyGround, underlying Baseplate and four
1800-stud backdrop tiles) uses Grass, RGB72/121/72. Paved forecourts under each
building extend to the existing 34-stud sidewalks; certify each forecourt at least
six studs outside the asphalt before creation. No gray fallback floor remains in
these layers. All appearance changes and the Baseplate are restored on teardown.

Source atmosphere was Haze 2.02999997, Density .324999988, Glare .300000012.
Native overhead comparison: Haze=0 with unchanged density remains heavily veiled;
removing the Atmosphere gives clear course visibility. Metro therefore clones Sky
and source ColorCorrection only, omitting Atmosphere. Local Brightness2.5,
ClockTime14.5, exposure .1, Ambient30/30/35 and OutdoorAmbient70/65/75 brighten the
scene. This overrides the older source-atmosphere preservation direction for Metro
only. Prior Lighting objects/settings are restored on teardown.

Native final census: 83 buildings / 13,709 building parts, two bridges, 62 Maples,
390 sidewalk strips; 14,320 scenery parts / 16,030 total track parts, excluding
karts/avatars and the inert 2,532-part palette. Build ~2.33s in final Edit capture.
Mobile performance/heat and published real-human racing remain unverified.

Native captures (unmodified Studio raster output):
- artifacts/metro-city/metro-full-overview-clear-20261026.jpg (full course/buildings)
- artifacts/metro-city/metro-haze-zero-comparison-20261026.jpg (density still present)
The camera is an elevated oblique view fitted from road/building world bounds;
all road extrema and both U sections are visible. Atmosphere removal, grass,
complete building models, exact Park meshes/root collars and all static-safe flags
verified natively. Studio window activation was needed to refresh its capture.

Validation: Metro layout 7,137 PASS; source hash/mesh/material audit PASS; six-track
paint 971 PASS; Metro skid 25 PASS; unchanged Park 3,671,426 PASS; 224 Luau sources
compile; default/desert-preview Rojo builds PASS. Native ordinary Client teardown
checks cover Lighting, Baseplate color/material and temporary materials. No Publish.

## Earlier U-bend infill / Desert road / tire-mark repair


Owner requested additional buildings only at the U bends and behind staging,
Desert Figure-8 road surface and restored Drift skid marks.

Added 14 native kit/low-shop buildings (72 total): outer upper U (3), inner U (4),
rear-start quarter bends (3+3), and one low shop on the rear straight. The prior
58 building/bridge frames and scales are unchanged. Same footprint nonoverlap and
24-stud shoulder tests apply (Studio minimum ~28). Existing pocket-tree positions
outside added building footprints are retained; eight nearby trees yield to the
new buildings, leaving 46. Source Sky, route, gates, actual grid and old five tracks
remain unchanged. Studio scenery 11,404 parts plus 1,710 existing track parts.

Road clones the actual KDMDesertResources.Materials.Racing_Asphalt_A variant,
with the same 226/220/188 tint and Asphalt base. Texture maps, roughness/metalness
maps and StudsPerTile match exactly. A Metro-local variant name avoids global
material overrides. Reuse Desert's straightRoadLength helper to remove overlapping
end caps from 245 nonphysical straight visual slices; authoritative centerline,
support, gates and driving are untouched. Teardown restores size/color/variant.

Skid cause: Metro's visual Road parts are non-queryable, while the old exhaust
renderer used Raycast except on Figure-8. Extend the existing bounded road-top-plane
sampler to the exact Metro ID + PracticeCircuitV1 combination. No query flags,
physics, Trail count/lifetime, Drift thresholds, smoke or network ownership change.
Ordinary Client native probe: both existing tire trails enable at road top + .04
(Y=.105), even though an Include-Road Raycast still returns nil; airborne and
outside-road probes disable both. No extra permanent mark geometry.

Validation: Metro 6,327 checks PASS (each target area populated, prior 58 sites
unchanged, full footprints/capacity/chevrons/original-five freeze). Metro and Figure-8
skid-contact tests PASS including off-road/airborne rejection. Existing six-track
paint 971 PASS, remote world-VFX and speed-VFX regressions PASS, 224 Luau sources
compile and default Rojo build PASS. Native Client material comparison and complete
road size/color/variant restoration PASS. No mobile/live-race acceptance claimed.
No Publish performed. Temporary QA scenes/probe kart removed.

## Previous modular-kit street blocks


Owner request after rollback: retain Base-derived Metro; use the complete kit
buildings for continuous street fronts, native low shops, pocket forests and the
native elevated building-to-building bridges. No native street-layout conversion.

Read-only source Endorsed Models/PrefabBuildings contains 11 top-level building
models (including two distinct H models). Reuse all 11 under unique Kit_* names,
plus City_Template 14_bldg / 28_bldg low shops, both five-part Skybridge models and
the two-part BeechwoodTree_Var02 street tree. Source palette: 2,634 parts total;
2,622 in building/shop models. Full original exterior MeshIds/PBR maps retained.
Only the two old partial low-shop models keep the recessed solid depth repair;
complete kit models use their actual native structure. No imported scripts,
vehicles or dynamic source lights. Source Sky/Atmosphere/color correction unchanged.

Final layout: 58 buildings, two bridges, 54 native trees in pocket groups and 390
wide sidewalk strips. Each long boulevard has compact, wall-adjacent three-building
blocks including a low shop. Facades stay parallel to the road. Building footprint
clearance is at least 28 studs beyond the asphalt edge in Studio. Native bridge
ends enter the paired Kit_I tower fronts; lowest bridge support is 55 studs above
ground. Road-visible rear faces and exposed stepped/end side walls remain. Hidden
shared decoration is culled only where another building/absence of route visibility
hides it. Groves use varied scale/rotation and the complete rotated canopy footprint
stays beyond the 24-stud recovery shoulder. Trees are grouped rather than allocated
to the earliest part of the lap. Sidewalks span 34 studs from the kerb-side frontage
to the buildings, with separated overlapping planes to prevent texture flicker.

Final Studio Edit census: 9,855 building parts; 10,382 scenery parts including
bridges/trees/beds/sidewalks; 12,092 total track BaseParts. This excludes avatars,
karts and the inert 2,634-part ReplicatedStorage source palette. Build about 1.52s
in the local Edit check; a prior grove-density variant built in 1.28s on ordinary
Client. These are local construction measurements, not mobile frame-rate evidence.
Part count is higher than the old partial-facade layout; mobile heat/FPS and actual
published multiplayer acceptance remain unverified.

Validation: Metro geometry/layout/continuous adjacency/whole-footprint clearance,
paired bridge towers, forests, frozen five prior worlds and paint checks PASS.
Metro validation 5,341 checks; six-track paint 971; race modes 168; Metro Bot 125;
224 Luau sources compile. Source hash/Sky/material/mesh audit PASS. Ordinary Client
build verified all parts safe, both bridges overhead, exact source Sky and complete
Lighting/material teardown. Only existing Studio DataStore permission warning.
Default and desert-preview Rojo builds PASS. No Publish performed. QA scene/cache
and temporary source backup are removed from Studio.

Screenshot: artifacts/metro-city/modular-blocks-skybridge.jpg.

## Earlier authoring checkpoints (superseded layout counts below)


New Track01Metro / Metro City Circuit preserves Base's PracticeCircuitV1 course,
checkpoints and aligned starting anchors, with separate room/rematch/record identity.
Public race: 1–4 racers, two laps, same optional Bot contract as Base.
Base and the five pre-existing entries/generated worlds are frozen. Track Board
adds Metro beside Base; Race Now remains Desert; Hub unchanged. Metro currently
uses the existing course-map preview fallback.

## Source scenery and corrected distant approach

Read-only source: C:/dev/rbxlx_data/city.rbxlx.
SHA256: da91339e3c6a5f5159c7cb471d3f9473aa03c13d241655283605045144ea5ff5.
The distant hazy city is in the original six-face Sky with Atmosphere and color
correction. Preserve those settings exactly, including original haze. No surrounding
SurfaceGui/photo panels remain. An early interior-photo wall experiment was removed;
its uploaded image is unreferenced. CityBlock_Center is a ground/block part, not
an original distant skyline resource.

Sky Bk/Dn/Ft/Lf/Rt/Up: 11263062161 / 11263065295 / 11263066644 /
11263068413 / 11263069782 / 11263070890.
Lighting: Brightness 2, ClockTime 15.5, exposure 0; Ambient 10/9/12,
OutdoorAmbient 34/26/36, diffuse/specular 1. Atmosphere and color correction are
cloned without overrides. Prior Lighting/settings are restored on teardown.

Nine sanitized exterior models / 348 parts retain source MeshIds, PBR maps,
materials, exterior window panes and fire escapes: 6_BLDG, 15_bldg, 17_bldg,
31_BLDG, 33_BLDG, 34_BLDG, 41_BLDG, 43_BLDG, 45_BLDG. Source scripts, vehicles,
dynamic lights, interiors and loose set dressing are excluded. Eight source
material variants exist only during Metro scenery lifetime. All decorative parts
are anchored, noncolliding, non-touching, non-querying and without cast shadows.
No per-frame scenery work, kart authority or global physics change.

Placement faces facades toward the course and checks the entire rotated footprint
against every centerline segment. Minimum building shoulder: 24 studs beyond road
edge; building bounds do not overlap. Studio ordinary Client: 75 buildings / 2,851
building parts, 390 sidewalk strips, 3,242 total scenery parts; minimum building
shoulder 25.21 studs; build ~0.91 seconds. Lune imported prefab bounds give 77 sites.
Continuous two-sided kerbs include outward double rows on sharp bends. Metro omits
old close barrier triggers; corners retain three road-facing chevrons each.
Four-row checker, eight painted brackets and four actual race slots stay aligned.

Scenery is gated to RACE + Track01Metro + PracticeCircuitV1. Teardown cancels
construction and restores ground/road appearance, Lighting and materials.

## Validation

- metro_city_resource_validation.py PASS: original source hash, exact source
  Sky/Atmosphere/color correction/material values, source meshes, inert palette.
- metro_city_validation: 4,240 PASS, including all five existing catalog entries
  and generated worlds property-for-property unchanged, Metro identity/record
  isolation, complete footprint clearance, nonoverlap, coverage, support and kerbs.
- start_finish_paint: 971 PASS; race_mode: 168 PASS; production_bot Track01Metro:
  125 PASS; race_grid_placement: 93 PASS; room coordinator: 49 PASS.
- reserved_arrival: 9 PASS; reserved_match: 13 PASS; hub_park_rookie_loop:
  3,671,426 PASS. All 224 production Luau sources compile.
- Default and desert-preview Rojo builds and git diff --check PASS.
- Studio ordinary Client: all meshes present, 3,242 visual parts safe, no photo
  SurfaceGuis/scripts; exact six Sky faces and Atmosphere values. Metro start
  creates scenery; HUB transition cleans scenery and restores original Lighting
  and materials. Initial Hub contained zero Metro environments.
- Native Edit mesh gate verified 288 original MeshParts. No Metro console error;
  existing Studio DataStore access warning remains unrelated.

Screenshot: artifacts/metro-city/metro-original-sky-street.jpg.
Temporary Studio QA worlds/caches removed. No Roblox Publish performed. Mobile
heat/FPS, full published races and real multi-human acceptance remain unverified.

## Authoring mesh gate

Rojo XML alone cannot reliably reconstruct immutable MeshPart content. After a
fresh import/sync, run tools/repair_metro_mesh_prefabs.luau in Studio Edit before
visual QA or separately authorized Publish. It restores source mesh content while
preserving size/frame/texture. Current Studio prefabs used native mesh creation.
Regenerate resources with python tools/extract_metro_city_resources.py;
never edit the source city template.


## Owner rollback after native-city experiment

Owner cancelled importing the original city street layout. Removed the uncommitted
MetroCityV1 / 45-stud conversion, original-city chunk palette, custom spawn anchors,
record token and narrower-road bot steering. TrackGeometry, TrackCatalog,
RaceBotSteering, RaceRecordConfig and RaceRecordPolicy are restored to c1c812f.
The cancelled candidate is locally recoverable under
artifacts/metro-city/cancelled-native-20261026/ and is not production content.

Metro again uses Base's PracticeCircuitV1 with its existing aligned GridSlots.
Retained the earlier native facade pivot repair, nine recessed StreetShell bodies
(357 palette parts), matte kerbs and separated alternating kerb/road-edge planes.
Facades are parallel to the road, without the diagonal approach-angle experiment.
Original Sky/Atmosphere remain unchanged. No original-city street conversion or
photo walls remain in the shipped source or Studio palette.

Rollback checks: Metro 4,249 PASS; all six start/finish paint checks 971 PASS,
including the five prior worlds unchanged; original resource identity/property
checks PASS; 224 Luau files compile; Rojo default build and diff checks PASS.
Studio Edit verifies PracticeCircuitV1 and no OriginalCity resource/MetroCityV1.
No Publish performed. Source city file remains unchanged.
