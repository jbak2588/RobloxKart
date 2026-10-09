# R7-L2 Lobby UX + R7-L3 Test Drive code checkpoint

The approved Lobby candidate is preserved on `feature/r7-l2-kdm-lobby-ux`, based on N2 `2f03803940ce8f2104819949d246a1ba210ee65e`. Production and the N2 feature branch remain unchanged.

Includes wall-mounted KDM banners, live Lobby overlay, Race List/Create Race presentation, restored Garage floor, per-player Test Drive, mobile digital pad, Garage/Tracks exit handling, Lobby-only 70/30 speed and 35-stud Drift radius, side wings, Plastic black/yellow fences, flat floor, barrier/recovery, fixed paired tire marks, audio and Unicode repair. Race physics, items, Bot/Track policy, finish/results, persistent schema and Reserved protocol are preserved.

Final v2-B evidence: **109/109 commands PASS**, six Historical Freeze checks, 131-source compile and Rojo build PASS. Candidate build SHA-256 is `8c8806067518136e8cdb8184439b5143e4d0a56b0dc7b68a1f36c0dcb9b6a1df`, not a Git SHA. Production/test content was unchanged after that gate; the checkpoint does not repeat the full suite.

Single-client Studio acceptance: native TEST DRIVE prompt/Seat and EXIT; real GUI selection plus native Return for Garage/Back/Tracks; Unicode display; scripted RemoteEvent driving approximately 69.92 forward / 29.92 reverse, 35.15 Drift radius, side wings, barrier and safe recovery. Static geometry: 1658 Parts / 608 marks. One desktop Studio viewport at 1919x1080 maintained approximately 60 FPS; live marks stayed at the 96-part pool and cleaned up on Exit. These checks do not establish sustained physical keyboard or mobile multi-touch acceptance.

**Android/iPhone, actual two-human/Reserved Race acceptance and broader online/mobile performance remain NOT VERIFIED/PENDING.** No Roblox Publish or production merge is part of this checkpoint.

## Reproduction

Use a full Git clone containing the historical commits, and install Lune, Rojo and Python on PATH. Source/test identities are recorded in `source-manifest.json`; Git CRLF/LF checkout conversion is normalized for comparison.

To list the exact 109 commands without running them:

```text
python artifacts/r7-l3-integrated-checkpoint/regression.py --list
```

To intentionally rerun the complete gate:

```text
python artifacts/r7-l3-integrated-checkpoint/regression.py
```

`regression-evidence.json` is a compact record of the completed v2-B results, not a claim that checkpoint creation ran the suite again. Large builds, screenshots and raw Studio/debug logs are intentionally excluded.

The checkpoint adapter is an equivalent copy of the reviewed v2-B helper: only its relative specification path, specification digest and metadata CRLF normalization differ. The inverse specification removes non-executable external-backup provenance strings; all hashes, offsets and exact inverse bytes remain identical. The original historical runner and its A1 source fixture are included unchanged. Runtime does not read an external backup. The existing Garage/Touch registration harnesses and the Hub harness load actual current modules without altering original assertion bodies. No Studio instrumentation or temporary debug helper is included.
