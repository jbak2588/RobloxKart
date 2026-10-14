# KDM_AUTO_BACKWARD_READY_FOR_MOBILE

AUTO BACKWARD implementation is preserved with the user-accepted PV672 mobile control behavior. Public baseline subsequently advanced to PV680 after the separate manually accepted engine sound correction. See `../r8-a5-shop/PV680_PRESERVATION.md` for the exact source/Native reconciliation.

OFF `72068260330921`, ON `139569165680720`. New digital-only toggle sits right of BrakeReverse, defaults OFF, switches exclusively with AUTO FORWARD and preserves steering. Manual Forward/Brake cancels either automatic direction without resuming it on release. Reverse clears/rejects Drift; lifecycle resets clear both directions. Joystick behavior remains unchanged.

Validation: 2,908 digital checks, 2,418 Joystick checks, 568 control/icon checks, 118 catalog checks; 168 Luau compile; Rojo; Lobby 1,051 policy checks, 7,796 mobile layout checks, 855 training Drift checks; checkpoint 1,721 and race presentation 6,932 PASS. Automated multi-touch uses mocked InputObjects. Real Studio device-emulator Touch events confirmed -1/+1 reverse steering, exclusive toggles, manual Forward cancellation and loaded ON/OFF artwork. User supplied published PV672 mobile PASS.

Local videos: `studio-auto-backward.mp4`, `studio-final-candidate.mp4`. Studio screenshots are local artifacts. The old `KDM_AUTO_BACKWARD_NATIVE_CANDIDATE.rbxl` predates PV680 audio and must not be published. The PV680 rollback Native is the starting point for R8-A5. No publish or main integration performed here.
