# Lobby two-row planting and consecutive Rematch rewards — 2026-10-24

Baseline: prototype/kart-physics, local and fetched origin both
6e53847c254952464dc7cdce07e9af514551ab53; clean working tree at entry.
Owner requested implementation, validation, commit and push. No Publish requested.

## Implemented

Remove exactly 15 tree sites in the third Lobby verge row (Park-local z=145).
The first two staggered rows at -15/65 and all other groves stay in place.
Park total 258 -> 243 trees; Lobby understory remains 15+15. All static
noncolliding, non-touching, non-querying, grounded and shadowless settings stay.
No track, kart, camera, combat or audio tuning changed.

Park next Replay reward is now a larger bold gold-accent card with border,
scaled vertical layout on small screens so it clears the Replay/Return buttons.
Park reward amounts and multiplier economy are unchanged.

Multiplayer next Rematch preview shows ONLY X2 / X3 / X4, per the owner's latest
correction. It never predicts a future cash amount; finish rank is unknown.
The result continues to show actual earned amounts only after receipt readback.

For an official race that actually starts with at least two humans, a qualified
full-route finisher who explicitly Rematches advances their individual streak.
First run X1, first consecutive Rematch X2, next X3, next X4. Duplicate votes
cannot skip multipliers. New arrivals, DNF/invalid completion, departure/Lobby/
rejoin, track change or solo GO reset to X1. Other racers' streaks are independent.
The actual GO roster owns eligibility, not a client multiplier or button count.

Only human rank base is multiplied: 1st 3500, 2nd 2500, 3rd 2000, 4th 1500.
Example: a second-place X3 finish earns 7500 rank reward plus any separately
qualified PB/event bonus. Existing PB bonuses and first-finish 5000 event are
not multiplied; official DNF consolation is unchanged. No new remote, profile
store, DataStore namespace, package, inventory or race capacity change.

The existing official finish operation freezes the multiplier, adds the rank
bonus, and updates wallet + receipt atomically. Receipt replay is idempotent,
changed multiplier on retry is rejected, overflow fails without partial writes,
and old receipts remain valid. Async saves retain old-round proofs while the
existing OfficialRoundGuid guard prevents stale HUD replacement. A failed save
does not falsely advertise payment or prevent subsequent race navigation.

## Validation

PASS: rematch_reward_validation (138): rank X1-X4, per-player chains, changed
rank, solo/DNF/rejoin/new entrants/track change, old receipt compatibility,
wallet overflow, altered receipt rejection, duplicate payment prevention,
PB/event isolation, queued stale saves and lost ACK readback.
PASS: two_player_race_validation (108): production controller GO/finish/Rematch
wiring, per-racer multiplier sent to the record observer, and independent DNF reset.
The optional record observer is a qualification stub in this controller harness;
real collector/operation validation is covered separately.
PASS: four_player_race_validation (55), persistent_room_race_validation (17),
r8_a3_records_validation (65), profile_records_integration_validation (10),
rookie_park_trial_validation (70), rookie_park_trial_session_validation (23),
rookie_park_trial_view_validation (291), race_result_hud_validation (269),
mobile_touch_validation (1188).
PASS: park_a2_landscaping_validation (66211 plus its underlying geometry fixture):
243 trees, 30 low plants, 651 static parts / 566 meshes, first two rows retained,
third absent, sampled corridor clearance at least 14.20 studs.
All 210 production sources compile; Rojo XML and binary builds and diff check PASS.

Studio actual generated Park reports 243 trees and 30 understory groups, and a
top-down native capture confirms two rows beside the Lobby. Production Park
result View was previewed with local synthetic result data; gold border/text
are readable and clear of actions. The multiplayer next-multiplier card is also
reviewed with Play-only attribute previews. These previews do not run a full lap,
create rewards or claim an actual two/four-human race. Temporary preview state
is discarded when Play stops. Client/tree sources match the review checkout.

Real-device mobile visuals, actual published multiplayer Rematch payouts and
live DataStore writes are NOT VERIFIED here. Existing historical r8_a4 economy
suite has an unrelated pre-task ineligible-zero expectation failure documented
in audio_b1_offroad_boost_20261024.md; this task does not change invalid-route
base reward behavior. Focused current economy tests above pass.

## Files and delivery

Production: HubParkLandscapingBuilder, RookieParkTrialView, RaceHudController,
RaceSession, RaceController, RaceRecordService, RaceRecordOperations and
KDMProgressionSchema. Tests: rematch_reward_validation (new), two_player_race,
park_a2_landscaping, rookie_park_trial_view and race_result_hud validation.
AGENTS records the owner-approved 243-tree exception and multiplayer reward rules.

Commit and push the scoped change after validation. Roblox Publish: NO.
