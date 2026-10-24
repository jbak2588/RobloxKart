# AUDIO-B1 + off-road Boost/Nitro — local review 2026-10-24

## A. Baseline and scope

Branch `prototype/kart-physics`; local and fetched remote HEAD both
`e5937ac9ec6f2058f0d4026bd6c9ec362db7fe08`. Working tree was clean at entry.
The owner explicitly approved off-road physics changes in the message accompanying
`KDM_AUDIO_B1_SOFT_BOOST_CODEX_2026-10-24.md`; that supersedes its audio-only
physics freeze and historical off-track cancellation statements. Its explicit
no Commit / Push / Merge / Publish restriction governed local review. The owner
subsequently accepted completion and explicitly authorized Commit / Push;
Roblox Publish and Merge are not included in that final instruction.

## B. Current audio correction and source reference

Owner confirmed off-road speed/flames PASS. Those production changes are untouched
by this audio follow-up. Initial quiet-loop and onset-only candidates were rejected.
The owner now requests sustained turbine audio synchronized with remaining flame,
source-reference 80% volume, and restoration of original Missile launch audio.

XML reinspection of `C:/dev/rbxlx_data/Hub_n_lobby_original.rbxlx` confirms:
NitroStartPlayer=15548492905, Volume 2.7980001, nonlooped;
NitroLoopPlayer=15548491198, Volume .800000012, looped;
NitroStopPlayer=15548492078, Volume .800000012. Stop is not added to KDM.

| Use | Asset | KDM volume |
| --- | --- | --- |
| Mini Boost onset | 15548492905 | 2.7980001 * .80 = 2.23840008 |
| Mini sustain | 15548491198 | .800000012 * .80 = .6400000096 |
| Original KDM Nitro launch | 83211426606907 | .75, unchanged |
| Original Missile launch | 83211426606907 | .75, now independent config |

These are exactly 80% of the source Volume values, not a measured claim about
perceived loudness under different speakers, distance attenuation or audio buses.

## C. Current audio behavior

Race/Park AudioRuntime owns three bounded sounds: replacement Mini onset,
original KDM Nitro onset, and one Mini sustain loop. Mini onset plays once per
activation; its loop continues after the .729-second onset clip ends. Connected
boosts do not restart the loop. The existing BoostFlameEnvelope is reused for
natural tail weight and its 82-stud ending threshold, rather than cutting audio
when KartBoosting first turns false. Off-road active boost retains sustain;
combat/Drift/cancel/seat/menu/lifecycle safety clears it. Nitro alone has no added
loop or stop cue and retains its original onset/volume. No new frame loop exists.

CombatHitAudioController previously used ASSETS.BOOST_START for MissileLaunch,
which accidentally followed turbine changes. It now uses dedicated
COMBAT.MissileLaunch asset/volume, independent from all boost tuning. Actual fired
serial/session/reset validation, hit explosions and Thunder audio are unchanged.

Race and Park use KartConfig.OFF_TRACK_BOOST_SPEED_MULTIPLIER=.80:
Mini 100 -> 80 and Nitro 120 -> 96 studs/s. Grass departure preserves active
boost/Nitro and original end time. Road re-entry recovers the full target using
existing acceleration, without extending duration. Official Nitro activation
no longer rejects KartOffTrack; actual authoritative input, ownership, seating,
charge, barrier/crash and combat checks remain. Park already allowed grass within
the physical island; that island boundary remains a safety boundary.
Park cannot charge/re-enter Drift while off-road and thereby cancel an existing
Mini Boost. Its local Nitro value is resolved before the slide speed cap.
Normal off-track speed, base acceleration, Nitro duration, track/checkpoints,
15-second official DNF, item economy, server ownership and bots are unchanged.
No geometry, trees, packages, uploaded assets or HUD were changed.

## D. Files

Production: `src/shared/AudioConfig.luau`, `src/shared/KartConfig.luau`,
`src/client/AudioRuntime.luau`, `src/client/CombatHitAudioController.luau`,
`src/client/KartAudioController.luau`,
`src/client/LobbyTestDriveController.luau`, `src/server/NitroState.luau`,
`src/server/PrototypeWorld.luau`, `src/server/LobbyDriftSession.luau`,
`src/server/LobbyTestDriveService.luau`.

Principles: `AGENTS.md`. Tests: new `tests/boost_audio_validation.luau`, plus
`kart_audio_validation`, `park_driver_feedback_validation`, `race_item_validation`,
`lobby_training_drift_validation`, `lobby_practice_combat_validation`,
`combat_hit_audio_validation`.
The practice test's obsolete four-slot/five-BOOST expectations were updated to
current six-slot and configured reward threshold; gameplay tuning was not changed.

## E. Validation

PASS: boost_audio_validation (36), kart_audio_validation (controller, engine
and finish regressions), race_audio_validation, park_driver_feedback_validation
(24), race_item_validation (1191 + 273 + 13), lobby_practice_combat_validation
(460), lobby_training_drift_validation (855 + off-road checks),
mobile_touch_validation (1188), boost_flame_fade_validation (160 + 49),
race_start_boost_validation (473, four tracks), lobby_test_drive_validation
(1096), lobby_wall_service_validation (73), combat_hit_audio_validation (31).
All 210 production sources compile. Rojo XML and binary builds PASS:
`KDM_AudioB1_LocalReview.rbxlx` / `.rbxl` in the environment temporary directory.
`git diff --check` PASS.

Additional historical tests FAIL on both this change and the unchanged entry HEAD:
- repeatable_nitro_validation: obsolete fixed five-BOOST requirement.
- lobby_drive_mobile_fix_validation: obsolete portrait Drift layout expectation.
- v2_gauge_v1_audio_validation: historical AudioConfig source freeze.
These were reproduced in an isolated HEAD snapshot, not claimed as passing or
weakened to hide failures. The affected current behavior has focused coverage above.

Studio local production Park: keyboard W and real UseItem remote on actual grass
consume Nitro 1 -> 0; measured off-road maximum 96, road-return maximum 120;
2 active exhaust emitters in each state. QA repositioned the seated kart between
a real grass point and road to isolate the transition; this is not a full manual
lap or real-device driving acceptance. In that earlier audio-candidate run,
NitroStart, BoostLoop, NitroStop Played counts were each 1; that sound profile
was subsequently replaced as described above. End time remains original; no synthetic reward/loadout bypass.

Current corrected audio tests include exact source-volume products, ten successive
Mini pulses, one continuous loop across connected boosts, tail volume at .75 of
nominal after .5 seconds, zero at the same exhaust end-speed threshold,
off-road sustain, Nitro-only isolation, cancellation and idempotent cleanup.
Missile production controller tests verify the old asset/.75 for actual Race and
Park launch serials and independence from turbine asset/volume.

Studio actual Park countdown/GO (native keyboard W) confirmed MiniBoostStart=1
and MiniBoostLoop=1. There were 20 active-boost samples with the onset already
finished but sustain still playing, and 33 residual-flame samples after natural
boost expiry with sustain still playing. Zero samples had active flame without
loop audio. Loop peak was .639999986 (Sound float precision); at speed 80 the
flame count, loop volume and playing state were all zero. The existing
AttackerMissileLaunch was loaded with asset 83211426606907 and volume .75.
This verifies production playback state/timing, not a microphone recording or
subjective 80%-loudness measurement. Actual firing/session routing is covered by
combat_hit_audio_validation; no published multiplayer acceptance is inferred.

Previous candidate's Studio production Park physics evidence remains valid:
Return Lobby left no seat, drive inactive and no local boost Sound instances.
Studio's stale pre-39c0f6d exhaust was previously synchronized to entry HEAD;
no new flame tuning is made in this audio correction.

NOT VERIFIED: acoustic recording/actual listening, iPhone/Android concurrent
finger input, device thermal/FPS, published asset access and full manual race.
Official race lifecycle/physics coverage is deterministic production-controller
validation, not a new published multiplayer runtime acceptance.

## F. Risks and rollback

Audio candidates still require device listening and published permission checks.
Muted/unavailable candidates preserve engine pitch and driving. Preserve the
existing server ownership guard and unresolved long-session Rematch investigation.
Rollback only this task's exact file diff; do not reset unrelated future work.

## G. Delivery

Owner accepted completion and explicitly requested Commit + Push.
The scoped Git checkpoint includes the accepted physics/audio, tests and this report.
Merge: NO / Publish: NO. Local Studio review is complete; no deployment was attempted.
