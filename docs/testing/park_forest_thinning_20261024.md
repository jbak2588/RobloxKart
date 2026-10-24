# Rookie Racing Park forest thinning — 2026-10-24

Scope: reduce overlapping forest density for the reported iPhone 12 Pro Max heat/automatic dimming, then apply the owner's follow-up to remove all forest understory and retain 30 low plants on each Lobby side.

- Trees: **440 → 308**, exactly 132 removed (30%). Existing offset planting sites are selectively retained, avoiding relocation into driving/recovery corridors. Minimum anchor separation: **22.36 → 31.26 studs**; mean nearest-neighbor separation: **33.44 → 41.49 studs**. Mature crowns can still overlap; this reduces layering rather than guaranteeing zero overlap.
- Northeast grove: remove 40 trees from its central ellipse, Park-local center **(300, -1080)**, radii **220 × 120 studs**. Keep the surrounding forest and corner screening.
- Understory: remove all **270 forest placements**. Reuse Rhododendron / Laurel / Fern for **60 low plants**, 30 per side, beside the Lobby: |x|=112–187, z=-16–77. Ten of each species per side, at 70–85% prefab scale, staggered rows. Existing small flower beds, six shrubs and five rocks remain.
- Total landscaping: **1,445 → 831 BaseParts** (42.5% reduction), **1,360 → 746 MeshParts** (45.1% reduction). No runtime density/LOD system or new asset dependency.
- Grounding, static/noncolliding/no-shadow configuration, track geometry, collision surfaces, kart physics, traffic, UI, rewards, arrival and PLAY flow remain unchanged. Functional builder code is identical outside planting lists/comments.

[Before/after planting diagram](park_forest_thinning_20261024.svg). This is a coordinate diagram, not a rendered canopy or Studio screenshot.

Validation:

- `lune run tests/park_a2_landscaping_validation.luau`: **PASS 92,969 checks**; includes actual prefab grounding, all visual footprints outside the pedestrian protected region, minimum sampled road/recovery clearance **14.20 studs**, 308 trees, 30+30 Lobby plants, empty northeast center, >=31-stud tree anchor spacing.
- Its real RookieLoop builder/geometry fixture: **PASS 3,672,295 checks**. Track/layout/drive geometry unchanged against fixed pre-task commit `4fc6ead`; updated the older stale freeze baseline to the actual task baseline.
- Scoped production snapshot: **209/209 sources compile PASS**; Rojo XML `.rbxlx` and binary `.rbxl` builds **PASS**. Snapshot excludes the five pre-existing unrelated modified files (three production sources plus two tests); those changes remain in the working tree.
- `git diff --check`: PASS.
- Studio rendering, kart viewpoint / complete lap: **NOT VERIFIED**, no Studio instances connected. No runtime screenshot supplied.
- iPhone / Android thermal, brightness, FPS and sustained driving: **NOT VERIFIED**. Asset-count reductions do not establish device thermal acceptance or prove vegetation was the only cause. Compare the same phone brightness/settings and session duration after deployment.
- Commit/push only; Roblox Publish not performed for this change.
