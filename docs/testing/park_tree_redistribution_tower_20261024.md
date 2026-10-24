# Park tree redistribution and tower relocation — 2026-10-24

Owner-marked plan: relieve the northeast/top and left interior groves, move their trees into the empty road verges on both sides of the Lobby, keep 258 trees, and move the tower hidden behind the northeast forest.

- Relocate **45 existing trees**; retain 258 trees, all species totals, 30 Lobby low plants and the same 681 BaseParts / 596 MeshParts. Left verge gets 24 relocated trees and right verge 21, in three staggered rows at local z=-15/65/145. Alternating rows are offset, with the rear edge fitted to the island chamfers. No trees deleted/added, no dark CityBroadleaf or forest understory reintroduced.
- Vary the relocated copies' scale/yaw; nearby same-prefab placements (<110 studs, used only as a review neighborhood) differ by at least .08 scale and 25 degrees. This is not a global canopy-gap formula and does not reduce the tree count.
- Move only ParkTower4 from (250,-1040), yaw160 to **(430,-900), yaw180**, facing +Z toward the outer-right corner road. Clear its foliage corridor while relocating trees. The other three towers, arch, advertising and chevrons retain their placement. Towers remain the existing static decorative models; no dynamic lights added.
- Preserve road/collision/support/physics, personal trial, bots, UI, Lobby arrival and PLAY exhibits. Existing unrelated five dirty files stay outside this commit and release.

Validation:

- Actual asset landscaping suite PASS **72,177 checks**; 258 trees/30 low plants, grounding, >=31-stud anchor separation, transformed footprints outside protected pedestrian region, sampled road/recovery clearance >=14.20 studs. Relocated model corners remain on the island including chamfer edges. Exact row/side counts and nearby-copy variation verified.
- Circuit decor suite PASS **2,742 checks**, including the moved tower footprint >=12-stud road/recovery clearance, +Z orientation and a foliage-free mast/head-to-track corridor. Historical layout freeze baseline updated to the current fixed pre-task commit a87064f, with layout unchanged.
- Shared real RookieLoop fixture PASS **3,671,765 checks**. No full driving lap claimed for a static-art relocation.
- Scoped 209-source compile and Rojo XML/binary builds PASS; `git diff --check` PASS.
- Studio runtime confirms 258 trees, 30 low plants, moved tower world position (430,.4,-12) corresponding to local (430,-900), facing +Z. Inspected the tower from the road and the three-row Lobby verges in an oblique overview. Mobile driving and sustained heat/brightness recheck remain owner-run.
