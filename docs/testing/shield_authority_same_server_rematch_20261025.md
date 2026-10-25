# Shield authority / same-server Rematch final review — 2026-10-25

Baseline: local and origin `c7668602a367512c89c5f7466b2c604c4c44d8fc`, clean worktree.

Owner reports finding and fixing the hitch with another worker, and supplies the
specific reproduction: activating Shield while seated starts the roughly four-second
hitch. Reviewed c766860: Shield shell/pulse creation, expiry, hit removal and capped
pulse eviction schedule deferred server-authority checks; Countdown and GO also
schedule them. These are event-driven and avoid redundant ownership writes. Existing
PV931 Occupant protection remains. The automated ownership fixture simulates an
assembly reverting to automatic mode; it does not independently prove native engine
handoff timing or long-session mobile acceptance.

Final review found that the new helper checked for an occupant but did not establish
that it was the owner's current living Humanoid seated in that exact seat. Added both
Seat.Occupant and Humanoid.SeatPart checks, plus Health, before reassertion. Added
regressions for incomplete seating and a dead driver.

Per owner direction, production `FRESH_BOT_REMATCH_ENABLED=false`. Human-plus-bot
Quick Race now uses the same existing nextStaging path as other rosters. The unused
opt-in experiment remains disabled. No new server reservation/teleport is made by
this Rematch path. Room, match identity, human arrival, bot and grid are retained.
Existing reward-run continuity and timed/button Rematch logic are unchanged.

## Validation

- Deferred ownership lifecycle: **25/25 PASS**. This harness also executes the
  production item suite: **1,191/1,191**, plus 273 NPC and 13 preview checks PASS.
- Room coordinator: **49/49 PASS**, including three same-job 1H+1B Rematches with
  the actual production flag, retained bot/room/job, and zero new reservations.
- Two-player race: **108/108 PASS**; four-player race: **55/55 PASS**.
- Rematch rewards: **178/178 PASS**, including existing continuation coverage.
- Luau compile of the six reviewed runtime/test sources: PASS.
- Rojo default project XML and binary builds: PASS; `git diff --check`: PASS.
- Connected production Studio is in Edit mode; its PrototypeWorld source contains
  the c766860 authority helper. No native Play test, new live 2-human test, mobile
  endurance run or Roblox Publish was performed in this final review.

This supersedes the prior review's absence of a concrete trigger with the owner's
Shield reproduction. Do not reinterpret deterministic PASS as a measured engine
ownership trace or a claim that all network jitter has been eliminated.
