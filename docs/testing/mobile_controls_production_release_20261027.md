# Mobile controls production release — 2026-10-27

Owner explicitly authorized production Publish and commit/push after private QA
revision10 / Place v103. This supersedes the private-only release restriction for
this scoped release. Target: Universe10768420544 / Place127925465904803.
The QA Universe10772198697 / Place106553302629620 remains private.

Includes the accumulated rounded mobile controls, right-side six-item layout,
count-only Park item labels, top feedback/minimap placement, bright waiting panels,
held GAS90 and audio, gradual reverse70, Park rim release guard, and the Park
ScrollingFrame touch blocker fix. See the private QA investigation log for each
revision and its limits. Existing validated manual server ownership guards remain.

Production rollout adds the exact production ID pair to the explicit mobile/GAS
feature gates. Default Rojo Workspace attributes enable these features and retain
HubParkV1Enabled=true. Other ID pairs remain disabled. Production received only
21 changed runtime modules; no QA-world copy or asset replacement was used.

Pre-release backup: native Download a Copy of production v1231, saved as
`C:\Users\OWNER\Downloads\KDM_PROD_127925465904803_v1231_before_mobile_controls.rbxl`
(1,387,111 bytes). Production retained4804 MeshParts /3515 SurfaceAppearances.

Validation:
- Full246-test suite:171 PASS /75 existing baseline failures; zero new failures
  against the fetched origin/prototype/kart-physics baseline39055dd.
- Mobile controls actual494 + geometry3528; GAS actual881 + policy27 PASS.
- All231 source files compile; full Rojo build and git diff check PASS.
- Ordinary production-ID Studio Client startup enabled mobile/GAS gates and
  entered HubParkRookieLoopG2 through TEST DRIVE; Park trial reached RUNNING.
  All six Park item captions contained only quantity1 and parented to SafeCanvas.
- Edit-model checksums and uniqueness match all21 local runtime files. Play-only
  probes removed; unchanged asset counts verified after Play stopped.

The earlier QA native BRAKE hit-stack check established removal of the scrolling
blocker. This production Studio run is not an iPhone acceptance test; the owner's
post-fix iPhone wall/reverse and long-session Rematch hitch acceptance remains
pending. Retired showroom implementation cleanup is also still outstanding.

Publish receipt will be recorded after native Studio confirms success. No live
server restart is included in this release.
