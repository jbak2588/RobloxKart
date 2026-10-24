# Park Final Lap, checkpoint beep and seated pedal pose — 2026-10-24

Baseline prototype/kart-physics local/fetched origin:
d61bced3c2a56da7da1dbc17e84d4400ad35f693, clean working tree at entry.
Owner explicitly requests implementation, validation, Commit + Push + Publish.

## Change

Park lap 1 -> lap 2 shows gold GothamBlack FINAL LAP at the official notice
position, with the same 1.45-second hold/.2-second fade interval. Its generation
and GO deadline re-arm on Replay; exits and result states clear it. The existing
RaceAudioController plays its actual three higher Final Lap beeps for Park too,
with queued repeats cancelled on exit. Official race Final Lap is unchanged.

Every accepted local official/Park checkpoint counter advance plays a distinct
CheckpointBeep Sound using countdown asset 9119144736 at volume .45. Initial
replication, unchanged counters, lap/reset rollback, staging and missed gates
produce no beep. No server checkpoint adjudication/progress or recovery change.

New KDMDriverPedalController owns only native seated lower-body Transform
presentation. It supports R15 Hip/Knee/Ankle Motor6D or AnimationConstraint and
R6 hip Motor6D frames, in KDM V2 and Sprint V1. Owner refinement uses 90-degree hips and straight knees/ankles, with soles
facing forward. It extends legs forward through
staging, driving, finish and results; no cloned limbs, avatar transparency change,
seat/root/kart CFrame, SeatWeld, velocity or network ownership write. Original
transforms restore on state/seat/character loss, death, departure or teardown.
One PreSimulation connection and .25-second shared player poll; no per-frame
instance allocation or per-player frame connection. Steering hand IK and seated
finish wave retain their separate existing owners.

Studio current R15 measurements: straight-pose feet are chassis-local X +/- .420,
Y -.118, Z -1.088. Both sole normals dot kart forward = 1.0. Native front view
shows shoe tread facing the camera, with legs straight. The original seat stays
unchanged; existing hands remain at the wheel. Earlier finish preview verified
independent wave behavior; automated checks cover the final straight pose too.

Mini Boost start now repeats every .30 seconds during acceleration below the
100-stud cap (99.5 tolerance), latching off after reaching it until a new boost.
Nitro priority, 80-percent source volume and existing sustain/flame tail remain.
Studio loaded-asset probe observed four real Played events during the climb
and still four after reaching 100 studs/s. This verifies playback events, not
subjective mobile loudness or listening acceptance.

## Validation

PASS driver_pedal_pose_validation: 395 production pose/lifecycle checks across
R15 Motor6D/AnimationConstraint, both kart profiles, R6 native hip frames,
repeated seating, finish persistence, shoulder isolation and exact restoration.
PASS boost_audio_validation: 41 checks including acceleration repeats, cap latch,
new activation re-arm, Nitro priority and lifecycle stop.
PASS race_audio_validation: official/Park countdown and Final Lap, new official
and Park checkpoint one-shot/dedup/reset/staging gates, Replay re-arm and queued
Final Lap exit cancellation. Same existing countdown asset and dedicated volume.
PASS rookie_park_trial_view_validation: 299 actual View checks including Final
Lap show/expiry, result/reward and phone-safe layout.
PASS kdm_driver_grip_validation 72, driver_finish_celebration_validation 197,
finish_celebration_validation 111, park_driver_feedback_validation 24,
finish_presentation_validation 29, mobile_touch_validation 1188,
race_item_validation 1191 + 273 + 13, rookie_park_trial_validation 70,
rookie_park_trial_session_validation 23, race_result_hud_validation 269.
All 211 production sources compile; Rojo XML/binary and diff checks PASS.

## Studio and limits

Native R15 seated foot/hand/finish camera and Return Lobby restoration are checked
in Studio. Controlled route replay uses real elapsed traversal and accepted
production Park checkpoint/finish processing, with client Played/notice observers;
it is explicitly not a manual lap or physics/steering acceptance. QA-only tasks
and attributes disappear on Stop. Final counts: 12 CheckpointBeep events, each of the three Final Lap sounds once,
Final Lap notice observed. Production completion: FINISHED, 118613 ms,
checkpoint 6/6 in lap 2, reward CONFIRMED in Studio memory adapter.
Actual Return Lobby then clears LobbyDriveActive/phase and unseats the driver.
No direct profile or reward mutation is used for the route replay.

R6 and Sprint pose are automated under deterministic mocks, not measured on all
real avatars. Actual Android/iPhone hearing, touch, thermal/FPS, live multiplayer
and published DataStore acceptance are not established by these local checks.
Previously documented long-session Rematch hitch investigation is untouched.

## Delivery

Only scoped source/tests/AGENTS/report are staged. Commit + Push are authorized;
Publish must be confirmed by native Studio success/version log after source audit.
