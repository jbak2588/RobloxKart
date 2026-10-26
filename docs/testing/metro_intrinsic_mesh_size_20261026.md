# Metro intrinsic mesh size emergency repair — 2026-10-26

Owner supplied production start-line and checkpoint2 screenshots of enormous
building faces and awnings covering Metro City Circuit. Confirmed exact track:
Track01Metro. Fetched origin; clean baseline a04a305 matched remote development
branch before changes.

## Reproduction and cause

Reproduced the supplied start-line view through the ordinary Client initializer
in a Studio initial RACE startup. QA startup uses production PrototypeWorld,
RaceItemController and RaceController with Metro; no direct privileged scenery
controller build. A preliminary stripped startup blocked on KartControl; the
final reproduction uses the normal services so this is not mistaken for a fix.

The placement math and bounding boxes were already safe:83 buildings with
minimum whole-box shoulder27.99995 studs. Nevertheless native screenshots
reproduced the huge walls. All2248 client source MeshParts had MeshSize=(0,0,0),
while Edit/server meshes repaired with ApplyMesh reported nonzero sizes. Park's
CityMaple mesh sizes were normal. Checking MeshId or server bounds alone missed
the rendering defect.

The city extractor whitelist omitted serialized MeshPart InitialSize. Roblox uses
intrinsic mesh size to scale rendered geometry to Part.Size. This zero intrinsic
size made the rendered geometry disagree with the bounds used by the layout.
MeshSize is not replicated; Edit/server-only repair and GetBoundingBox checks did
not prove client render correctness.

Reference: https://create.roblox.com/docs/reference/engine/classes/TriangleMeshPart
and https://devforum.roblox.com/t/meshpartapplymesh-not-working-correctly/3603822/2

## Changes

- src/assets/KDMMetroResources.rbxmx: preserve the original positive InitialSize
  on all2248 MeshParts. No building positions, Part.Size, rotations, palette,
  road, route, actual grid, physics or server authority changes.
- tools/extract_metro_city_resources.py: retain InitialSize during extraction.
- tests/metro_city_resource_validation.py: require all2248 serialized sizes to
  be positive and match the original city asset for the corresponding MeshId.
- src/client/MetroCityEnvironment.luau: reject unusable building meshes with an
  empty ID or zero intrinsic size before they can cover a racing corridor.
- tools/repair_metro_mesh_prefabs.luau: check positive intrinsic sizes as well
  as IDs; repair invalid sizes at authoring time.

The original city.rbxlx hash remains
da91339e3c6a5f5159c7cb471d3f9473aa03c13d241655283605045144ea5ff5.
No runtime privileged mesh/map property writes or per-frame scenery changes.

## Verification

After the serialized-size repair, a fresh ordinary Client startup reports all2248
source MeshParts with positive intrinsic sizes. The complete scene has83
buildings,2 bridges and12479 runtime MeshParts, with0 zero intrinsic sizes.
All83 building bounding boxes retain >=27.99995 studs of road shoulder;0 road
intrusions. Native iPhone13 landscape emulator screenshots at the same start
view and checkpoint2 now show correctly sized facades, clear asphalt, and the
intended elevated bridge. Before/after native rendering establishes the repair;
the previously passing geometry-only tests were insufficient.

PASS: original resource hash/material/lighting/mesh identity and intrinsic-size
validation;11143 Metro layout/frozen-world checks;230 source compilation; default
Rojo build;git diff --check. Real Android/iPhone full-lap acceptance remains
separate. Temporary QA startup/camera objects are excluded from release.
