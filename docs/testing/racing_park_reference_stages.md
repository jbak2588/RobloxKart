# Racing Park reference implementation — 2026-10-21

References: `C:/dev/rbxlx_data/f1_calendar_sample.png` supplies the folded course
shape; `KDM 카트 레이싱 허브 섬.png` supplies the island/paddock atmosphere.
Existing F60 building, seven display karts, manual boarding and server authority
remain the foundation. User approved Commit/Push after private PC/mobile course
testing on 2026-10-21. Roblox Publish is not authorized. Default flag remains OFF.

## Final course acceptance and slot ordering

User completed private-version PC/mobile testing and accepted course shape and
width. The reported rear-first slot behavior was confirmed: the server fills
lowest available index and the array previously began at X=-45 while travel is
+X. Reverse only the slot index order to X=45,15,-15,-45. Physical brackets,
road/pit geometry, driving physics and widths do not move. First entrant now
uses the leading bracket; later entrants take the next free bracket behind it.
Focused geometry/anchor tests verify index 1 at X=45 facing +X and the remaining
three behind it. Native multiplayer testing of this final index-only change is
NOT VERIFIED; the user's course acceptance preceded this correction.

## Stage 1 — front-only pen-sketch course (revised locally)

- User's final pen sketch supersedes the earlier rear/perimeter expansion.
- Closed 5,913.8-stud course. Final user-approved cross section: road 32 ->50,
  kerbs remain 2, each shoulder 18 ->9 studs. Transfer 9 studs per side to the
  road, preserving the centerline, guardrails and 36-stud containment radius.
  This explicit HUB-only request supersedes the general minimum shoulder rule
  for this layout; official RACE tracks are unchanged. Lane arrows follow the
  new lane centers at +/-12.5 studs. Pit width remains 22 studs.
- Bounds relative to HubSpawn: X -700..600, Z -1150..-137. With current spawn
  world Z=888, this reaches world Z=-262, including the former Figure-8 region.
  No main road passes behind the building. Lobby and entrance remain fixed.
- Sequence: eastbound start, outer right northbound straight, upper-right inset,
  inner right descent, lower bowl, central hairpin and alternating S corners,
  upper-left loop, outer-left descent, return chicane, start. No crossing/bridge.
- Folded infield, alternating corners, paired hairpin arcs, perimeter straights.
  Minimum sampled curvature radius 59.52 studs. Tight corners require slowing;
  full Nitro through a hairpin is not an acceptance requirement.
- 870-stud main straight. The original outer-right straight was 360 studs
  (Nitro 120*3). The final user-approved 63-stud pit-side shift extends it to
  423 studs (relative z=-267 to -690); other infield corners remain unchanged.
  This is maximum-speed distance, not a guarantee from a standing start or an
  automatic brake at the end. Curves are outside this straight measurement.
  Mini Boost remains 100*2=200 studs; no item values were changed.
- New HUB normal cap follows `KartConfig.MAX_FORWARD_SPEED` (currently 70).
  Legacy HUB remains 60; Mini Boost 100 and Nitro 120 unchanged. At constant
  70, 84.5 seconds per lap; cornering and boost usage change actual lap time.
- Final pit center Z -145 -> -82; main start Z -200 -> -137. T plaza front
  edge stays -70, leaving 1 stud to the pit road and 12 studs to slot centers.
  Four slots at X -45,-15,15,45 now all face the plaza, with 30-stud spacing.
  Every former SLOT text is replaced by a three-stroke native ] in front of
  the kart (+X closed end, open toward the kart); paint is noncolliding,
  nontouching, nonquerying and above the visual pit surface. No automatic boarding.
- Same invisible flat collision support: no new chassis/ownership tuning,
  bridge, elevated road, automatic boarding or persistent data.

Validation: reference sizing + real production Drift solver caps PASS; geometry
continuity/envelope/ground tests 3,666,070 checks PASS; manual corridor 3,354 PASS;
startup 570 +18 PASS; F60 6,435 PASS; showroom 38 PASS; mobile layout 7,814 PASS;
legacy policy 1,051 PASS; Drift 855 PASS; surface/Barrier 814 PASS. Production
compile and Rojo XML/binary build PASS. No unrelated failing assertions changed.

Final commit check: 18 focused validation files PASS, including 75 idempotency
checks/10,000 transactions, active-DNF reward, lap refill, race items/bot routing,
F60, mobile layout, skid marks and gauges. Three existing validation files FAIL:
`lobby_practice_combat_validation` expects four instead of six default items;
`lobby_post_drive_return_validation` expects the obsolete Garage race callback;
`v2_gauge_v1_audio_validation` compares AudioConfig against an older frozen
revision. The first two reproduce against saved review-HEAD production sources;
AudioConfig/input and the third test are unchanged from review HEAD. Assertions
are preserved. This is a focused regression run, not a new whole-suite PASS.

Earlier isolated Studio captures returned a blank viewport. The subsequent user
private PC/mobile course acceptance supersedes that pending visual status.
`front-sketch-plan.svg` is a generated geometry
diagram, not a Studio screenshot. The updated ON preview contains current sources.
Previous G3-A full-lap acceptance belongs to the smaller old layout and must not
be transferred to this layout. User private testing is recorded above; no new
agent-captured timing, mobile FPS measurements or multiplayer capture is claimed.

## Stage 2 — course acceptance recorded; measured performance remains

Drive the expanded loop, pit and tight corners at the new normal cap. Exercise
Drift/Mini Boost/Nitro/Shield and recovery/return. Check camera visibility, road
joins and mobile draw cost before dressing: road slices increased 576 ->1,557.
Do not adjust accepted vehicle physics to compensate for a bad corner.

## Stage 3 — island and paddock presentation

Shape the visual island edge/cliffs/water around the measured course envelope;
reuse curated tree/rock resources in bounded clusters. Add KDM gates, planting,
fencing and plaza/podium identity without road incursions or new rewards.
Keep the F60 building and clear pedestrian/garage access. Reference images set
the intended quality; the current greybox is not the finished island.

## Stage 4 — elevation and social landmarks

Implement elevated areas/underpasses only with matching 3D support, containment
and recovery, then revalidate driving. Present track selection/records through
existing authorized services; do not fake functioning votes or global boards.
Finish with PC/mobile visual and sustained performance acceptance. Deployment
and automatic boarding remain separate from this local implementation.
