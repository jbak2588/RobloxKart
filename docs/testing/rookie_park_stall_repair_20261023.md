# Rookie Park Replay and checkpoint stall repair - 2026-10-23

## Reproduced causes

- Replay explicitly rejected SAVING and retried UNCONFIRMED saves without starting another lap. Persistent storage failure trapped the player on the result screen.
- RaceRouteProgress retains accepted anchors after a wide excursion. Park had no normal on-road reacquisition path, so its >60-stud guard could reject every later checkpoint, even on another complete circuit.

Both new regression cases failed against 46b64f8 and passed with this repair.

## Repair

Replay starts the new countdown immediately, including while the previous save is in flight. An unconfirmed receipt is retried in the background with the same ID; no duplicate retry is launched while one is running. Late save completion cannot overwrite the new lap HUD. Reward success still requires storage read-back; the existing Park reward design is retained. Failed PB saves no longer say SAVING indefinitely.

Park reacquires its route anchor after 0.5 seconds of plausible continuous on-road samples. The reacquisition itself grants no gate/finish. Required checkpoint order is preserved, and a discontinuous sample cannot prime reacquisition or receive gate credit. Official Figure-8 logic and presentation remain unchanged.

## Verification

- Trial validation: 58 PASS, including two checkpoints -> long continuous excursion skipping checkpoint 3 -> return at checkpoint 4 (still 2/6) -> another full circuit -> 6/6 and FINISHED. Teleport rejection and idempotent receipt checks pass.
- Production session: 21 PASS, including failed save, in-flight save, late confirmation, one-click Replay, countdown and boosted GO.
- Production UI: 271 PASS across landscape/portrait sizes; Replay remains enabled and no earned reward is shown without confirmation. Return Lobby: 27 PASS.
- All 209 production sources compile. Scoped Rojo XML and binary builds and git diff --check PASS. Unrelated dirty source files were replaced with their committed versions in the build snapshot.
- Studio actual physics lap with temporary save-failure injection: **02:49.583, 6/6, UNCONFIRMED**. One actual Replay button click changed FINISHED to COUNTDOWN at grid (45, -151), checkpoint 0, reward NONE. The kart then entered RUNNING unanchored (sampled speed 34.697), and Return Lobby cleared drive/trial state. Both the temporary pilot and economy failure injection were removed; Studio was left in Edit. No kart position writes were used during the completed lap; the temporary pilot sent production input packets only.

The storage-failure injection establishes restart behavior, not the cause of the user's published storage failure or live save/rejoin acceptance. The long-excursion/extra-circuit case is deterministic route validation, not a physical/mobile lap. Android/iOS acceptance remains unverified. No Roblox Publish.
