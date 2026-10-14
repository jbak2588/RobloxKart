# GO audio change — pending next Native / Publish

User requested reusing the countdown tone for GO, higher in pitch and twice as long. **Not published. Public PV665 remains unchanged.** Include this change in the next report and refresh the Native candidate from current source before the next authorized Publish; the already published floating-marker Native does not contain this change.

- Countdown/GO asset: `rbxassetid://9119144736`. Countdown 3/2/1 timing, speed and volume unchanged.
- GO: one non-looped sound, PlaybackSpeed 0.5 for exactly 2× source duration. GO-only PitchShiftSoundEffects apply 2× pitch compensation then 1.18× pitch lift, yielding nominal pitch 18% above countdown. Existing GO volume 0.85 retained. No repeated GO beeps or delayed repeat callbacks.
- Removed RaceStartAudio/StartPlayer `15617817566` from RaceAudioController's execution path. Kept the original safe resource/module for compatibility; 168 production source containers remain.
- Existing Final Lap three-beep sequence, finish/DNF cues, Rematch deduplication and departure/state cleanup retained. Engine A, VFX, physics, UI, records/economy and mobile controls untouched.

Validation PASS: focused race audio test (one GO, same asset, exact duration ratio, independent pitch, unchanged countdown, state deduplication/cleanup, Final Lap ordering and Rematch); kart audio tests; 6,932 presentation checks; kart visual/compile of all 168 production Luau files; Rojo Build; whitespace checks.

This validation is automated/mocked, not Studio listening or real-device audio acceptance. Local verification Studio copies had been closed; no cloud DataModel was edited for testing. Actual timbre and mix should be heard by the user after the next authorized release. Roblox [PitchShiftSoundEffect documentation](https://create.roblox.com/docs/reference/engine/classes/PitchShiftSoundEffect) specifies independent pitch processing and Octave range 0.5–2; each applied stage is within that range. Effects are attached only to the short GO cue, not continuous engine/countdown audio.

Pending Native source updates: `src/shared/AudioConfig.luau`, `src/client/RaceAudioController.luau`. No additional audio asset permission dependency introduced. Do not re-publish the old candidate expecting this change; refresh and verify its 168 Sources first. No Publish or main integration performed in this task.
