# Road / paint visibility hotfix — 2026-10-26

Owner requests repair of Base grid-area road flicker, Park edge paint appearing
ahead of a moving driver, and Green Island brackets appearing row-by-row on the
return to the finish. Explicitly authorizes commit, push and production Publish.
Fetched origin first: clean prototype/kart-physics at b7ab693, matching remote.

## Repair

Park and Green used a separate Texture on every matte asphalt face. Roblox
renders Texture/Decal geometry separately, with depth behavior that can obscure
thin parts above it at distance. Increasing paint lift alone did not fix the
owner's device report. Replace this layer with a preauthored Concrete material
variant containing the same Desert albedo 15217440826, 24-stud tiling, no normal,
roughness or metalness maps. All road faces, pit pieces and crossing ribbons use
the opaque material. Ordinary LocalScripts only clone the saved variant; they
never write privileged map properties. Preserve Park neutral tint, lighting,
existing .20 paint lift and .02 asphalt top. Green stays at .065.

Base native builder inspection found overlapping Road382/383, Road384/385 and
Road386/387 underneath grid strokes. Straight-only trimming missed the curved
approach. Extend the existing shared-edge road polygons to Base, retaining its
exact original Desert Asphalt PBR variant and tint. All390 old road rectangles
are locally hidden. Native replacement has640 faces (Lune648 due floating-point
collinearity). No second coplanar road layer or per-frame rebuilding.

Green brackets lacked Desert's crossing clearance. Place all24 strokes above
the highest crossing top with at least .04 clearance, without changing X/Z,
rotation or actual GridSlots. Resolve the grid folder when each descendant
arrives, so late paint/folders receive the same one-time repair. Teardown restores
original frames, materials, colors, visibility and lighting.

No server production source changes. Physics, route/checkpoint gates, start
slots, allocations, GO, item/reward logic and ownership guards remain unchanged.
Hard/Metro/Desert appearance is outside this repair. Both Rojo manifests include
the new material. A stale Park skid test expected the superseded .37 road top;
its assertion now matches the current .02 top plus .04 trail clearance.

## Validation

- 15,768 baked-material / shared-edge geometry / PBR / visual-only checks PASS.
- 43 surface-reference / theme-isolation checks PASS.
- 1,851 paint / road / capacity / frozen-builder checks PASS.
- 93 real-controller grid allocation / seating / Countdown / Rematch checks PASS.
- All five official tracks and Park skid tests PASS; 25 world-VFX checks PASS.
- Focused Park grounded/airborne/idle/legacy skid test PASS, 47 VFX checks.
- 3,671,426 unchanged Park geometry / collider / manual-zone checks PASS.
- Network authority suite: 25 deferred ownership lifecycle checks PASS, with
  existing combat / Nitro / NPC / preview checks PASS.
- All230 production sources compile. Default and desert-preview Rojo builds PASS.
- git diff --check PASS.

Native Studio ordinary Client initializer starts Park, then observes server-built
Base and Green by the normal role/track listeners. Park: Ready,3980 shared faces,
3059 edge lines,0 leftover DesertMatteAlbedo Textures,0 wrong material assignments.
Base: Ready,390 hidden originals,640 PBR faces. Green: Ready,24 grid strokes,
minimum crossing clearance .040000002; a late-added stroke also clears by .04.
Park re-entry and fresh Play startup both build successfully. Desktop and iPhone13
landscape emulator (750x390 rendered viewport) are inspected; low native render
quality is included. Camera probes are Play-only and excluded from the release.
Existing Studio DataStore API-disabled warnings are unrelated to this visual fix.

Reference: Roblox engineering explanation of separate decal/texture geometry:
https://devforum.roblox.com/t/placing-thin-parts-on-top-of-part-with-texture-objects-in-it-causes-flickering/1499535/10

Real Android/iPhone driving and repeated full laps are NOT VERIFIED by these
automated and emulator checks. No hardware FPS/heat or four-human acceptance is
inferred. Production destination is Universe10768420544 / Place127925465904803,
with HubParkV1Enabled=true. Publish receipt is recorded after release.

## Release receipt

Implementation ff96508990528a215f10d8988829f18ce62de574 was committed and pushed to
origin/prototype/kart-physics; exact local/remote HEAD equality verified.
Before Publish, all230 native Studio script sources matched repository checksums
(newline-normalized Adler32), all3 Desert and2248 Metro source mesh identities
passed their existing authoring gates, and no temporary QA objects remained.
Workspace.KDMBuildCommit carries the implementation hash; HubParkV1Enabled=true.

Studio Publish completed successfully to the existing Kart Drift Masters place.
Native Output records the request at18:28:12.244 and successful new changes
published at18:28:14.331 (Studio display clock). The final dialog says publication
complete. The production universe/root-place pair was independently checked with
the Roblox games API:10768420544 /127925465904803. No new place was created and no
live-server restart was requested. The loaded Edit PlaceVersion remains1213;
that cached value is not presented as the new publication's numeric version.

Changed files: AGENTS.md; default.project.json; desert-preview.project.json;
src/assets/KDMRoadMaterials.rbxmx; src/client/TrackRoadRibbon.luau;
src/client/TrackSurfaceController.luau; tests/rookie_loop_skid_mark_validation.luau;
tests/track_road_ribbon_validation.luau; this report. Release receipt is a
documentation-only follow-up to the published implementation.
