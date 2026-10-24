# Lobby tree-base planting — 2026-10-24

Owner correction: replace the grid of low plants with compact mixed planting around the two existing Lobby trees. Reduce 60 low plants to 30, exactly 15 per tree.

- Retain all 308 trees and the cleared northeast forest center.
- Fifteen Rhododendron / Laurel / Fern models wrap each existing tree at Park-local (-145,-25) / (145,-25), using irregular inner and outer arcs, varied scale/yaw and an open root collar. Five of each species per side. No added forest understory or runtime system.
- Landscaping budget: 781 BaseParts / 696 MeshParts (previous 831 / 746). Original 440-tree forest had 1,445 / 1,360.
- Existing small beds/rocks and all track, traffic, UI and driving code remain unchanged.

Validation:

- Actual prefab/build validation: PASS 90,199 landscaping checks and 3,672,115 RookieLoop fixture checks. Exact 15+15 count, planting centers within 7–18 studs of each tree, grounding and visual-only flags validated. Minimum sampled road/recovery clearance remains 14.20 studs. Protected pedestrian footprint remains open.
- 209 production sources compile; Rojo XML and binary builds PASS from a scoped snapshot excluding pre-existing unrelated modifications. `git diff --check` PASS.
- Connected Studio runtime: 308 trees / 30 low plants / 781 BaseParts / 696 MeshParts. Viewed both tree bases from separate oblique cameras: planting forms compact clusters around the trunks, not rows across the lawn. No new border/bed meshes added.
- Pre-Publish Studio source audit: all 209 source hashes match the scoped release snapshot (CRLF/trailing whitespace normalized). Three unrelated locally modified production sources had been synced into Studio; restored only their Studio copies to the committed versions before release. Disk edits and the two unrelated modified tests remain preserved and excluded from this commit.
- Mobile driving and sustained thermal/brightness acceptance are owner-run; no complete lap or device thermal PASS claimed. Publish is explicitly authorized by the owner for this correction.
