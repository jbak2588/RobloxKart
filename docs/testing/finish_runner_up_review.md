# Winner celebration through runner-up arrival — 2026-10-21

Baseline: `0e50d51f42610fe9fe978dc37df1bcbc78d9a16b`, matching fetched origin
on `prototype/kart-physics`; working tree was clean.

## Accepted driving invariant

The user confirmed PV931 mobile driving is natural and very smooth, "like
watching HD video." AGENTS.md now records this published acceptance, the guarded
post-SeatWeld manual server ownership requirement, and the difference between
rendering FPS and replicated motion stalls. PrototypeWorld and all physics/input
tuning remain unchanged in this task.

## Celebration

- Server publishes `RaceWinnerAwaitingRunnerUp` only for the sole official
  finisher of a multi-racer round while the round is RACING. The source is the
  server's finishOrder, not client-reported position. It is updated using the
  existing change-only session publication; no new RemoteEvent or Heartbeat.
- The first finisher's existing PRESENT pose keeps waving while this flag is
  true, including after the normal transition to FINISHED/results.
- Two existing local particle emitters are reused. The standard winner's three
  32-particle pulses remain; waiting extends with one 32-particle pulse every
  0.6 seconds. Lifetime remains <=1.05 seconds, giving at most two overlapping
  pulses (64 particles). There are no extra attachments or per-frame Emit calls.
- Runner-up crossing clears the flag even if third/fourth racers remain active.
  Extended particles are removed and the arm returns to its existing raised hold.
- If no runner-up arrives, existing DNF/forfeit/timeout completion ends the
  hold. Rematch, seat/character loss, departure and teleport retain cleanup.
- Solo and placed racers retain their finite base presentation. No extra race
  delay, result gate, reward, physics or finish/grace timing change.

## Validation

- New client test: 65 checks across long waiting, runner-up stop, DNF, Garage,
  Countdown/session replacement, seat/character loss, teleport and teardown;
  instance budgets and stale timers included.
- Production server integration: 55 four-player checks, including exclusive
  winner flag, runner-up clearing while others race, rematch reset and all-rival
  DNF fallback. Race-mode integration: 160 checks including solo no-wait.
- Existing driver rig checks: 195; finish particle/TouchGui checks: 266.
- Full regression: 206 suites / 165 PASS / 41 pre-existing FAIL / zero new FAIL.
  Existing failures are not presented as passes.
- All 197 production Luau files compile. Normal Rojo XML/binary builds and
  `git diff --check` pass. Test builds:
  `C:/dev/KDM_Finish_Runner_Up.rbxlx` and `.rbxl`.

Native Studio verification uses an isolated GameId/PlaceId=0 Figure 8 harness
with an automatically steered human-context kart and a Rookie Bot delayed at
the start to create a visible winner wait. The normal production finish gates,
result state and server-owned waiting flag drive the clients; no operating
DataStore writes or test code are included in the production build. Native
results and publication evidence are retained under `artifacts/finish-runner-up/`.
Native result: the human crossed first at 108.713 seconds; the bot crossed
second at 120.463 seconds. The authoritative waiting flag stayed true between
those crossings. After PRESENT began, the client retained exactly two emitters
and changing shoulder poses throughout nine one-second samples; 0.8 seconds
after runner-up arrival it had zero celebration emitters. The isolated run was
then stopped. This does not substitute for the user's published mobile visual
acceptance of the extended finish presentation.
