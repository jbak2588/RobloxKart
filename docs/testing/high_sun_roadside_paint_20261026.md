# High sun / stable roadside paint — 2026-10-26

Baseline7085949 matched origin/prototype/kart-physics after fetch. Owner reports
Park kerbs / Green edge lines drawing near the moving kart, Park road too pale,
and low-angle glare. Commit/push only, no Publish.

## Change

Park kerb top+.07 and white line+.045 were only.05/.025 above the+.02 asphalt.
Green white-line tops+.0975 were only.0325 above+.065 road tops. Small visual
separation is vulnerable to depth occlusion at shallow distant camera angles.
Streaming is disabled in this place; no distance/velocity-based paint generator
exists. Lift only Park Kerb/EdgeLine and Green LeftEdge/RightEdge plus crossing
OuterEdge guidance by.20, with idempotent late-descendant handling and restoration
on teardown. Colors, route, kerb XZ shapes, collision/query flags and actual
road/grid/checkpoint contact remain unchanged. No moving-camera/per-frame writes.

Park matte asphalt retains Desert albedo15217440826, tile24, but uses a darker,
neutral165/170/180 tint instead of226/220/188. Green and the accepted Base/Hard/
Metro/Desert albedos and colors are unchanged. This is a visual tone adjustment;
exact perceptual brightness across different skies is not a measured guarantee.

All five selectable official tracks and Park use ClockTime13 and
GeographicLatitude23.5. Roblox native GetSunDirection gives Y=.96592575, a75-degree
elevation, with almost zero north/south component. Base/Green/Hard use the common
lighting table, Metro uses that table with latitude backup/restore, Desert uses
the same sun constants with latitude backup/restore. Park applies only these two
sun properties; native Brightness2/exposure0 and existing color effects remain.
Rojo default Lighting also sets13/23.5, so initial frames/editor builds match.
Track02 is still outside the selectable / cleanup / validation set.

## Validation

Ordinary Client initializer in native Studio:
- Park9035 raised visual pieces, including5976 kerb wedges; minimum kerb top
 .269999985, i.e..25 above asphalt. All1875 road/pit pieces retain matte handling.
 Dark neutral albedo present. Brightness2/exposure0 retained, sun Y=.96592575.
- Green264 raised pieces (256 boundary strips plus8 crossing guidance edges).
 Minimum white boundary bottom.262500001, i.e..1975 above asphalt. Sun matches.
 Native viewport inspected from low driving-height camera; distant white edge
 remains visible along the straight.

PASS:25 surface/config/list checks;13,269 triangle/matte/height/visual-only/tint
checks. Regression PASS: all5 selected official skid contacts plus Park,25 VFX lifecycle,
1,851 paint/route/grid frozen-world checks,3,456 planting checks,230 production
sources compile, default Rojo build and git diff --check. Native Base / Hard
sequential identity changes retain13/23.5; no additional marking lift on either.
Native Metro also matches13/23.5. Fresh ordinary Desert startup with production
opt-in builds SOURCE_DESERT and matches13/23.5. Sequential synthetic theme swaps
do not substitute for that fresh Desert check.

No Publish. Native screenshots / synthetic geometry verification do not establish
real-device moving-camera flicker or hardware performance acceptance. Temporary
Studio startup overrides/camera scripts are discarded before finishing.
