# Metro City Circuit — 2026-10-26

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
