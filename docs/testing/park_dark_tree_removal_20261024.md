# Park dark tree removal — 2026-10-24

The owner requested removal of every Park tree matching the dark green tree in the supplied mobile screenshots. Compared the four City tree prefabs in a temporary Studio specimen row; the matching model is CityBroadleaf. Removed the temporary fixture after identification.

- Remove all 50 CityBroadleaf planting entries; 308 → 258 trees. No replacement planting or recoloring.
- Preserve all remaining tree sites and the 15+15 Lobby low-plant clusters, grounded visual-only behavior, original small beds/rocks and northeast clearing. Keep the reusable prefab asset available; it is no longer instantiated by Park landscaping.
- Landscaping now totals 681 BaseParts / 596 MeshParts, down from 781 / 696.

Validation: PASS 70,575 actual-prefab landscaping checks and 3,671,765 real RookieLoop builder/geometry fixture checks. Minimum sampled road/recovery clearance remains 14.20 studs. Regression asserts zero CityBroadleaf planting entries. Scoped 209-source compile and Rojo XML/binary builds PASS; unrelated existing dirty sources excluded from snapshot. Diff check PASS.

Studio runtime independently confirms 258 trees, zero CityBroadleaf, 30 low plants, 681 BaseParts and 596 MeshParts, with anchored/noncolliding/non-touching/non-querying flags. Viewed the outer right track forest after removal. Temporary identification fixtures removed; Play stopped after inspection. Mobile lap/thermal acceptance not claimed. This change is committed/pushed; no Roblox Publish performed in this task.
