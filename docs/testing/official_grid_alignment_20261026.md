# Official grid placement alignment — 2026-10-26

Owner requests matching actual official starts to the published 2-column /
4-row paint, in entry order (front left/right, then following row), with 1H+1B
sharing the first row. Park is explicitly excluded. Fetched clean baseline
3a34a1057fd3a707aff55af1ab6453c6ab17fdc9 matched origin/prototype/kart-physics.

The prior visual task retained old catalog spawns and the bot's last-slot spawn;
those do not match the newly painted centers. TrackGeometry.getStartGridFrames
now supplies the existing eight painted centers/headings (30-stud row spacing,
+/-14-stud columns) and TrackBuilder uses it. All five catalog entries' four
authoritative CFrames are updated to those first four centers; tests compare
every center and heading. No course definition/sample/gate/kerb is moved.

RaceServerBootstrap captures server arrival sequence before asynchronous
admission/character waits. It publishes RaceArrivalOrder only for a validated
entrant; token validation and reserved slot admission are unchanged. RaceSession
orders humans by that sequence (local Garage fallback remains ReadyOrder), then
bots. RaceController packs the actual seated karts into catalog slots at waiting
entry, roster changes, Rematch staging and Countdown. It retains existing kart
height, seat relationships, context resets and countdown ownership guards.
No per-frame placement, physics tuning or network ownership changes.

Bot authentication still reserves the final logical slot in the directory. Its
physical position is the next occupied slot after humans: slot 2 for 1H+1B,
slot 3 for 2H+1B, slot 4 for 3H+1B. This does not expand capacity or change bot
admission policy, room/reward lifecycle or same-server Rematch routing. Park
sources/anchors/allocation and all existing physics/economy sources are intact.

Validation:

- start_finish_paint_validation: 810 PASS across all five tracks, including
  actual spawn-to-bracket center/heading, all bracket footprints within road,
  safety, cache and immutable non-paint generated output.
- race_grid_placement_validation: 93 PASS using real RaceController/RaceSession:
  1H+1B front row, 2H+1B packing, late seating vs entry order, four-person
  Countdown, GO, same-server Rematch and departure packing, with intact seats.
- practice_figure8_geometry_validation: 42971 PASS; route/minimap unchanged.
  Only the owner-authorized GridSlots are excluded from the old catalog freeze.
  Its old square-apron Z-band grid assertion is replaced by >=130-stud radial
  clearance from the actual crossing (the old square apron no longer exists).
- race_mode_validation: 164 total PASS; practice_figure8_race_validation: 80 PASS;
  persistent_room_race_validation: 17 PASS; reserved arrival: 9 PASS;
  reserved match: 13 PASS; production bot (Desert): 125 PASS; room coordinator:
  49 total PASS. Updated context mocks implement the real setSpawnCFrame API.
  Mode fixtures now reflect the already shipped five-track / dual three-lap
  Figure-8 catalog rather than the obsolete four-track / frozen old V1 grid.
- Rookie Park regression: 3671426 PASS; its main-road start anchors unchanged.
- 222 production sources compile; default Rojo XML and diff checks PASS.
- Native Studio checks: all five catalog spawn centers match native generated
  frames within 0.000044 studs, heading dot >.99999.
- Controlled Play probe on the production-bound place: started an isolated clone
  of RaceController against the real PrototypeWorld and Track01Desert, seated
  the actual player and production BotController NPC, with a local canAdmit
  adapter (not a live room reservation). WAITING gives human slot 1 / bot slot 2;
  actual chassis horizontal error 0.0000153 studs for both. Both seat relationships
  are valid, GetNetworkOwner()==nil and GetNetworkOwnershipAuto()==false.
  Real client StartRace remote enters COUNTDOWN with slots 1/2 retained.
  Initial Hub-only World lacked official acquire API; initialized official World
  for this probe, then completed seating. This is controlled local evidence, not
  published admission, manual driving or real-device acceptance.
- race_launch_routing_validation still fails its old Track01 selection/grid
  assertion. Reproduced the identical failure with baseline 3a34a10 Bootstrap;
  it predates this task and the fixture was left unchanged.

Play stopped; no QA clone/scene remains in Edit. Updated sources are synced to
the production-bound Studio. No Publish for this change; mobile/published
placement acceptance remains separate.
