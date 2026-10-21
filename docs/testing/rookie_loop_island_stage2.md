# RookieLoop island and uphill terrain — 2026-10-21

Baseline: `7aae5e17f1b7c7d17929de62e5fd1b7eb05e2344`.
User explicitly resolved the original height constraint: distant roads also rise
gently, so the low Lobby can overlook driving on the far course. Preserve the
accepted X/Z route, widths, bracket locations/order and driving tuning.

## Implementation

- T plaza/Lobby remain Y=0. Beyond relative Z=-70, height is
  `0.04 * (-70 - z)`: 4% grade / 2.29 degrees. Pit +0.48, start straight
  +2.68, far track +43.2 studs. One continuous inclined physical support and
  one Lobby-level support; decorative road/grass slices remain noncolliding.
- Beveled island footprint X -820..720 / Z -1270..220; native grass, faceted
  slate cliffs, closed stone safety rim and an opaque ocean at Y=-58.
  269 scenery Parts including 49 water tiles (2000 studs each): one Part would
  clamp to 2048, so the 14,000-stud ocean is explicitly tiled.
- Opt-in HUB/staging gate unchanged; default OFF, production HUB denied,
  RACE and Studio Bot Test unchanged. Old rectangular Baseplate is hidden
  visually in park mode; original collision properties stay unchanged.
- Built-in blue Sky replaces the alpine panorama only inside the gated HUB
  build. Original Sky is archived intact under the park model. Lighting
  tuning, Terrain and the default project sky are unchanged.
- Containment and last-safe recovery use local ground height with the original
  -4/+18 and safe-update margins. Item drops follow height and normal; RookieLoop
  Slick center sits at ground+.47 so its underside clears the .37 road top.
  Legacy item drop remains +.25. No item strength/charges/timers change.
- Existing skid renderer queries the same named support container and follows
  its real normals. Ground paint, arrows, spawn frames and rails follow the plane.
- No ownership, movement tuning, speed caps, economy, matching or race changes.

## Actual Studio validation

Separate local file, GameId=0 / PlaceId=0. User's open staging Place untouched.
Normal client Input/UseItem requests drove the production native physics; no
position/velocity writes during the lap.

- Whole main circuit including uphill/downhill, S corners and hairpins: 111.67s,
  completed; containment resets 0; time under positive throttle below 3 studs/s 0.
  Max planar speed 120.0001, max terrain-relative center-height error .01193,
  chassis max tilt 2.62 degrees, highest chassis Y 43.82. Nitro and Shield active.
- Separate targeted 35s input run: charge 1, ready true, Mini Boost active,
  max speed 100.0003, rear tire Trail enabled, resets 0. This short run is not
  a second completed lap.
- Separate deliberate off-track warp at Y=19.36: reset serial 0->1, returned to
  the prior elevated safe location, remained seated, network owner nil. This
  warp is recovery instrumentation, not part of the driving/lap evidence.
- RETURN LOBBY: active/pending false, kart absent, seat released.
- Native real item-drop method: expected/actual Y 19.27, correct upward normal,
  center .10 above road. Native rays from T plaza to two sampled far-road
  kart-height points were unobstructed. This is solo visibility, not actual
  multi-user acceptance.
- Final scenery restarted and captured with blue sky, 2000-stud water tiles and
  269 scenery Parts. Driving geometry/support are unchanged from the full lap;
  the final Slick surface clearance was additionally checked with native code.

20 focused files PASS / 3 existing FAIL / 0 new FAIL; 203 production Luau files
compile; Rojo XML/binary and diff check PASS. Existing failures are the same
four-item practice default, obsolete Garage race callback and historical audio
snapshot assertions documented at stage 1; not changed or marked PASS.

Lune's non-horizontal `CFrame.lookAt` has a pitch-sign mismatch versus Studio.
The new isolated item-grounding test uses an explicit basis-math bridge and the
native method was verified separately; it does not relax the normal assertion.

Artifacts (ignored): `artifacts/hub-racing-park/park-stage2/`:
`island-on-preview.rbxl`, `island-off.rbxlx`, `island-overview.png`,
`lobby-uphill.png`, native probes and `test-results.json`.
Android/iOS, published staging, actual multiplayer and sustained mobile FPS are
NOT VERIFIED for this elevated revision. No Roblox Publish or production writes.
