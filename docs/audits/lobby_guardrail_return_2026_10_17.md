# Test-drive containment and return-to-race prompt

Baseline: `c23a0488b3e5ea2d185081e3a8aeaa55414aa6e5`, matching
`origin/prototype/kart-physics` after fetch. Scope authorized by the user:
restore the former guardrail appearance/collision response and add a post-drive
English prompt with Play now / Later.

## Changes

- Restore yellow/black 3 x 2.4-stud guardrail visuals around both boundaries of
  the oval. Preserve cyan kerbs, asphalt, the island, and the safety shoulder.
- Keep 2 x 14-stud kart-only collision walls, overlapping their ends by one stud
  each. The pedestrian entry has a visual opening but no kart collision opening.
  Walking avatars and production race vehicles keep their previous collision rules.
- Preserve the original `Policy.barrierImpact` / `KartConfig` rebound, rotation,
  damping, alignment, and cooldown. No race or test-drive speed tuning changes.
- Add swept boundary-crossing recovery so a jump across the island cannot pass
  an endpoint-only containment check. Existing outside/fall recovery remains.
  Isolate item updates in a separate Heartbeat listener so an item update error
  cannot abort the driving listener before boundary checks.
- The server Stop reply now reports whether a live character actually returned
  to HubSpawn. Only the explicit RETURN LOBBY button uses this confirmation to
  show the new prompt. Client seat/attribute replication may settle for up to two
  seconds; stale requests, character replacement and failed returns cannot show it.
- English prompt: “Enjoyed your test drive?” / “Now race against players from
  around the world! Put your drifting skills and item strategies to the test,
  climb the rankings, and earn rewards.” Play now calls existing
  `Garage.open('RACE')`, opening the Race browser. Later dismisses the modal.
  Other overlays, a new drive, death or launch dismiss it. No automatic race launch.

## Validation

27 focused Lune suites PASS, including actual builder (4,589), actual driving
Heartbeat (71), yielding exit/lifecycle (39,551), original collision policy (814),
production Return handler (25), responsive modal (32), practice combat (440),
practice view/layout, demo, mobile/oval geometry, Garage/Hub, and combat VFX/items.
All five changed production sources compile. Rojo build and `git diff --check` PASS.
Logs/build are in the untracked `artifacts/lobby-guardrail-return` folder.

Isolated native Studio Edit-mode validation at place 127925465904803 built the
current builder under an unparented temporary Model: 394 rails / 266 walls /
532 edge endpoints, all endpoints covered by overlapping adjacent walls. The
temporary instances were destroyed; the open game's sources/world were unchanged.
Lune 0.10.5's planar lookAt Z mirroring requires an equivalent yaw constructor in
the builder test adapter; native Studio validation uses Roblox CFrame.lookAt.

Full driving playtest, visual popup acceptance and published real-device acceptance
remain unverified. No Roblox Publish or open-place source synchronization performed.
