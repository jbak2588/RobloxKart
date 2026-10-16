# Mobile race status, public rewards and Lobby return — 2026-10-16

Baseline: `e2acba2ef824fbc7c180a2133db57b34dc8838d7`, matching origin before work.
User requested implementation, commit/push and Publish.

## Changes

- `PublicRaceStatusView`: BOT WARM-UP / player-arrival notices use the physical
  TopbarInset band, between Roblox controls and the minimap, including device
  cutout translation. Observe geometry changes and hide outside pre-race/racing.
- `RaceItemUiController`: all landscape touch heights use the same safe top lane
  (8 px) for MISSILE LOCKED / incoming warnings; remove the <320 px exception
  that put Galaxy and iPhone in different lanes.
- `RaceRouteTransitionView` and client startup: independent ENTERING RACE ROOM...
  overlay observes server-owned KDMRoutePending, survives the browser/Garage
  closing, and clears on failure/cancel. HUB_RETURN has RETURNING TO LOBBY...
- `RaceController`: public bot warm-ups now feed the existing official finish
  and atomic reward pipeline. Private practice remains excluded. Existing full
  route/lap eligibility, receipt deduplication and economy amounts are unchanged:
  one human plus bots has K$1,500 base, with existing eligible PB bonuses.
  An interrupted warm-up never emits a finished result. A completed human gets
  the normal eight-second results window; unfinished warm-ups retain fast retry.
- `HubUiController` hides its shortcut dock during test drive.
  `LobbyTestDriveController` replaces EXIT KART with one blue RETURN LOBBY action
  above the right driving pad, using the previous shortcut style. Its caption
  is separate from the gradient, preserving white text. Existing Stop/neutral/
  detach/return routing is reused.

## Validation

- New public status/routing view tests: 29 PASS; phone/tablet proportions
  1024x461, 800x370, 750x302 and 932x390, icon/map clearance and route cleanup.
- New production warm-up controller observer test: 13 PASS; official begin,
  progress, two laps, FINISHED-only submission once and full result window.
- Public controller: 22 PASS; human races, warm-up arrival authorization,
  handoff, private practice and public rematch retained.
- Economy: 59 PASS, including one-human bot reward, invalid/incomplete terminal
  rejection, atomic wallet/receipt and duplicate-round protection.
- Mobile touch input/HUD: 3,002 PASS, with an added Galaxy-sized safe canvas and
  fixed warning-lane assertions. Garage transition: 6,384 PASS; Lobby layout:
  7,814 PASS; combat feedback: 102 PASS; record validation: 65 PASS;
  result/payment HUD and showroom admission regressions PASS.
- Rojo build, source compilation and CRLF-aware diff check PASS.
- Studio iPhone 13 Pro emulator, actual PreferredInput.Touch, original sources:
  viewport 750x390, safe canvas 750x332. Public banner raw position (216,-49),
  size 410x40; warning raw position (215,8), size 320x40. The None-inset GUI raw
  origin is (-47,-58); native screenshot confirms the banner in the icon/map
  band with the warning below. Negative raw Y is inset-relative, not clipping.
- Studio transfer overlay shown/cleared with controlled route attributes.
  Actual test-drive entry and native game mouse click on RETURN LOBBY succeeded;
  seat released and normal Lobby dock restored. No new feature runtime errors.
  Play-only UI fixtures were removed by Stop; no test changes enter Edit.

Galaxy/iPhone physical-device acceptance and real published wallet credit remain
pending. Studio persistence is diagnostic/disabled; controller/economy tests do
not establish a real live currency award. The unrelated historical Shop navigation
fixture currently fails loading its Shop dependency; no all-repository PASS claim.

## Larger driving karts — review only

Driving visual scale 1.2 is feasible, separately from chassis collision/physics.
It needs wheel ground clearance, exhaust/steering targets, camera clearance and
avatar seating checks. Current KDMDriverGripController only aligns arms; it does
not adjust torso/legs. Enlarging the shell alone cannot reproduce the reference
driver posture across Roblox avatar proportions. A separate visual/seat-pose
pass is recommended, first in test drive, then races with multiple avatars.
No live kart scale, seat, avatar identity or driving physics changed in this task.

## Publication

Implementation `6da1be145f194cb1de043eab89a1289157ac34cb` committed and pushed
to `origin/prototype/kart-physics`, with matching local/remote HEADs. All seven
changed/new native production sources exactly matched local files before Publish.
Studio confirmed Roblox publication to place `127925465904803` as **v772** on
2026-10-16 at 20:32:27. User explicitly authorized Publish in this request.
Physical Galaxy/iPhone rendering and published wallet acceptance remain pending.
