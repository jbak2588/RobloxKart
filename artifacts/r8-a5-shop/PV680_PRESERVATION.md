# PV680 accepted baseline preservation

2026-10-14. Public PV680 is the user-confirmed accepted release. PV672 AUTO BACKWARD / mobile HUD and PV680 engine boundary-noise removal are accepted by the user. No publish was performed by this task.

Baseline Git HEAD / fetched origin: `537847cf82fa193fc76ad85abf58d34e746b3bf1`. Preserved the five AUTO BACKWARD source files and four engine crossfade source files from the working tree. These nine files exactly match the connected Studio Edit sources after CRLF normalization. Studio Output shows the successful publish and **v680** release-note link. The Edit DataModel retains PlaceVersion 671 from its original load; that metadata is not claimed as a new download of PV680.

Read-only backup of the Studio automatic recovery file created after the v680 publish:

- `KDM_PV680_STUDIO_ROLLBACK.rbxl`, 676,941 bytes.
- SHA-256 `0933f55de7935838bb2aab62bce1bc60aa22ec500218869dde23ea83530d570e`.
- All 168 production Sources match disk exactly; no imported/test scripts.
- All 1,093 semantic Native world/asset entries and 70 raw Terrain property groups equal the verified PV665 Native baseline. Terrain material bytes also equal the baseline. Read-only Lune semantic inspection plus raw binary Terrain inspection; no Terrain reserialization.
- `pv680-publish-output.jpg`, `pv680-semantic.json`, `pv680-terrain.json` retain evidence. This is a post-publish Studio backup, not an asset-delivery download certificate.

AUTO BACKWARD regression: digital input/lifecycle/transport/layout 2,908 checks, Joystick 2,418, icon control 568, catalog 118 PASS. Same -1/0/+1 input contract; automatic directions exclusive; manual Forward/Brake permanently cancel digital auto; reverse suppresses Drift. No server physics change. Studio real Touch events showed reverse with steering -1 and +1, forward/backward switches, successful uploaded images and manual Forward cancellation. Hardware multi-touch was mocked in automated tests; subsequent PV672 real-device acceptance is the user's evidence.

Audio preservation retains the existing approved A asset `6667206432` and the manually accepted dual-voice trim/crossfade/jitter implementation. Existing kart audio, countdown/GO and Lobby driving tests PASS. No audio retuning in this preservation step.

K$805 is user-confirmed account state, not queried or modified here. No account writes, reset, reward rollout, main operation or publish. Existing unrelated artifacts remain untouched. The earlier AUTO BACKWARD candidate based on PV665 is superseded by this PV680 backup; subsequent shop candidate must start from this backup.
