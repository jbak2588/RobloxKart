# Track surface / scenery cleanup — 2026-10-26

Owner directs one-track-at-a-time cleanup, Desert as surface/brightness reference,
Park-size advertising, removal of block trees, skid checks, V2B list retirement,
and NO Publish. Fetched origin; baseline be394cf matched remote, clean tree.

## Scope and implementation

TrackSurfaceStandard captures existing Desert values: Racing_Asphalt_A color map
15217440826, normal15217430764, roughness15217430840, tint RGB226/220/188;
Brightness2, exposure-.2, clock15.883889, Ambient130/128/120, Outdoor145/145/140,
diffuse.8, specular.25. Base/Hard clone the source variant locally and use the
same -.02/.08/.04 color grade. No runtime texture-map writes, global material
override or source asset changes. Preserve theme skies. Park lighting is excluded
from this standard after the owner's latest correction: original Brightness2,
exposure0, Clock14 and original effects remain unchanged.
Metro clones that exact original Desert variant and uses the same daylight/grade,
replacing2.5/+0.1 brightness/exposure; original city Sky / omitted Atmosphere stay.
Desert vegetation / road surface are unchanged; only bracket presentation is raised as described below.

Non-reference official roads trim only redundant straight visual end caps, using
the existing Desert helper. Raise kerb caps by .115 plus .08 per outer row and
.035 for red caps; Concrete avoids the old SmoothPlastic glare. This separates
coplanar red/white overlaps and edge paint. Supports, gates, authoritative road
samples, kart physics, grid centers/headings, driving and ownership are unchanged.
Park kerb geometry and all physical source builders stay byte-identical.

Owner follow-up narrowed remaining flicker to Park/Green asphalt and Desert row4
brackets; other road/kerbs PASS. Park/Green now hide overlapping main-road strips
and draw shared-edge mitered quads, each split into nonoverlapping native wedge
triangles. Exactly collinear stations collapse; every curved source sample stays.
Road tops remain Park+.02 / Green+.065, retaining skid contact. Pit polygons and
Green crossing ribbons retain geometry. These two rejected roads use Desert's
same albedo15217440826 at24 studs and tint, on matte Concrete with a Texture;
they deliberately omit the wet PBR normal/roughness response. Ordinary Texture
properties are supported by LocalScripts. No source asset edits or upload.
Native face counts3980 Park /556 Green (Lune3880/540 due float collinearity).
Added faces are client-only, noncolliding/nonquerying/non-touching/shadowless.

Desert's fourth-row brackets overlapped the raised crossing ribbon. Its local
controller lifts each painted stroke above the highest nearby road/ribbon by.04;
native checks give Grid7/Grid8 minimum.040000003 clearance. All24 strokes remain;
no actual GridSlot/heading/server authority moves.

Green existing advertising is replaced by19 inert .5 x4.5 x20 panels, using the
same graphics, road-facing side and clearances as Desert. Base/Hard originally had
only corner signs; add up to20 matching panels on clear straight verges. Keep all
three-per-corner signs unchanged. Require complete rotated panel footprint at least
16 studs beyond asphalt for new panels; existing Green placements retain the
Desert14-stud test. No colliders/query/touch/shadows added.

Base's seven block-tree pairs are hidden locally and replaced one-for-one with
Park's CityMaple native mesh. Scales .65–.85 / varied deterministic yaw, Park root
collar grounding, canopy clearance>=16 studs outside the road. Green's16 round-crown NaturalTreeA/B horizon models are hidden locally,
including late descendants; the owner explicitly rejected that species.
Park243 trees, Metro62 Maples and Desert vegetation are preserved.
Green/Hard contained no remaining block-tree pairs in ordinary RACE generation.
Replacement source originals remain inert/hidden for reversible scene teardown.

New preview-inspired staggered perimeter/infield groves use only CityMaple, the
owner's broad spreading yellow-green Park species, scaled.48-.78 with varied yaw.
Targets are bounded by actual route/canopy clearance, not the artistic preview
road geometry. Green29, Base38 additional plus7 block replacements, Hard65 trees.
Each gets three existing Lobby low plants: CityRhododendron / CityLaurel / CityFern
(87 /114 /195 instances). Base placement also reserves the seven replacement
canopies. Whole canopy shoulder>=16 studs; new canopy-to-canopy gap>=8 studs.
Maple root collar uses tilted trunk bottom+2 source studs, planted at ground-.2;
other plants use transformed eight-corner bounds, also buried. Native Green root
check found0 floating collars. No Park grove thinning, source prefab modification,
new flora assets or artificial block crowns.

The controller waits for complete Road/Kerb/SpeedCue/VisualRail counts before
building; Road-only readiness initially missed later replicated Base scenery and
was repaired before final verification. Park also applies incoming late road/pit
pieces. All local colors/materials/frames/sizes/transparency/SurfaceGui enabled
states and lighting/copies restore on teardown. No per-frame presentation writes.

Track02 is removed only from selectable catalog Order. Five official entries now
appear: Green, Desert, Base, Metro, Hard. Retain the old Entries.Track02 identity
for existing records/payload compatibility, but do not modify or verify V2B scenery.

## Skid contact

Base and Hard had non-queryable visual roads but still used a road Raycast for
skids. Extend the existing bounded Figure-8/Metro top-plane contact to Base/Hard,
with the same tire height / road bounds / airborne rejection. No CanQuery or
collision flag changes. Park's physical support top is0 and current road top+.02;
replace stale .37 offset with.02, so trails lie at.06 (.02 road +.04 clearance).

Production-renderer tests verify two rear-tire marks on all five selected official
tracks, no dependency on Raycast hits, and no airborne/off-road marks. Park test
verifies both marks at.06. Native ordinary LocalScript probe using the production
KartVisualFactory plus rear-wheel motors produced two active Park trails at
Y=.05999994 while moving the local QA kart. This is a synthetic renderer check,
not manual mobile Drift acceptance. An initial bot clone lacked its non-archivable
Visual; the replacement probe creates the actual production visual and cleans up.

## Sequential native checks

Ordinary Client initializer (not privileged direct controller calls), in order:

| Track | Road visuals | Kerbs processed | Ads | Block-tree replacements |
| --- | ---: | ---: | ---: | ---: |
| Green Island | 250 (includes two crossing ribbons) | 320 | 19 | 0 |
| Base | 390 | 382 | 20 | 7 |
| Hard | 429 | 964 | 20 | 0 |
| Metro | existing390 | existing matte kerbs | existing46 | existing62 Maples |
| Park | 1875 including pit pieces | unchanged | unchanged | unchanged243 trees |

Base: zero visible legacy trunk/canopy parts and no canopy clearance violations.
Final Base/Hard follow-up verifies all20 panel sizes each, minimum full-footprint
shoulder24.73 /24.58 studs respectively.
Metro: Ready /83 buildings /2 bridges /64 lamps /46 ads /62 Maples, original Desert
map IDs, exposure-.2, diffuse.8, specular.25; no overlapping common controller.
Park: all1875 road/pit visuals converted (zero missed); normal production HUB
startup retains RookieLoop and existing nine physical colliders. Ordinary Client
checks had no production script errors; existing Studio DataStore access warnings
remain. No four-human, hardware FPS/heat or published visual acceptance inferred.

## Validation

PASS:20 reference/list/theme-isolation checks; all-track skid checks plus25 VFX
lifecycle checks; Park3,671,426 unchanged road/collider/layout/grass checks;
Metro11,143 selected-world/layout checks;1,851 paint/grid/launch corridor checks;
230 production sources compile; default Rojo build; git diff --check.
Additional PASS:3,456 deterministic planting/density/full-canopy-clearance checks;
8,849 shared-edge triangle coverage / matte / height / visual-only checks.
Native Green: all old main strips hidden,0 rejected visible round-crown parts,
0 faces with missing matte albedo. Native Park:0 missed road faces,0 physical/query
faces, no added grade, identical lighting before/after surface teardown. Ordinary
Client source startup is used. Desert QA must enable the production
KDMFigure8DesertCandidate flag; without it the test exercises Green scenery.
Native Sky inspection confirms matte roads and Park species. Static captures and
synthetic Drift trails are not mobile motion-flicker/FPS/heat acceptance; owner
must verify the local candidate while driving on their device.

No Publish. Temporary Studio initializers, QA scripts and karts are excluded.
