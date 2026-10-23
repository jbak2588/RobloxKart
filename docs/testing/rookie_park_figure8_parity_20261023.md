# Rookie Park Figure-8 parity - 2026-10-23

## Changes

- Shared RaceRouteProgress, original CheckpointGuidanceController and checkpoint/finish assets replace the Park-only marker and sticky INVALID/distance rule. Six ordered gates remain required. Off-road route progress is provisional until re-entry; recovery grants no checkpoint, and discontinuous movement retains the validated route anchors.
- Official finish constants: 2.4-second roll, stop/anchor, 0.9-second front-camera transition, then result. Official and Park camera paths share front composition. Park engine loops stop during PRESENT.
- SOLO LAP occupies topbar center. Transparent white Return Lobby aligns to wallet width. The newly made translucent Park time/PB/K$5,000 reward panel remains in use.

## Studio runtime

Actual iPhone 13 landscape emulator, input-only pilot using the production LobbyDriveControl RemoteEvent and server kart physics. No kart CFrame/position writes or checkpoint bypass.

Completed one full lap: **02:49.137, 6/6 checkpoints, reward CONFIRMED, wallet 5,000 -> 10,000**. ROLL -> PRESENT measured 2.433 seconds at heartbeat resolution. FINISHED server body anchored, velocity 0; both Lobby engine loops stopped. Camera was in front of the driver and the preserved reward panel was visible beside the kart. Original next-checkpoint marker had 35 children and followed checkpoint progress. Return button width matched wallet (180 px), fill transparency 1, white border.

Replay returned to countdown and RUNNING with checkpoint 0 and engine loops playing again. Return Lobby cleared LobbyDriveActive and trial state. The temporary pilot was removed; Studio left in Edit. A final missed-notice clearing fix was unit-tested after the physical lap and synced before completion.

## Automated checks

PASS: trial 54; session lifecycle/finish 16; Park UI 267; RookieLoop builder 3,674,464; official finish presentation 29; marker alignment 1,721; race presentation 6,932; finish sequence 25; mobile Touch 1,188; Return Lobby 27; showroom drive 38. All production Luau sources compile. Scoped Rojo XML/binary and diff check verified separately before commit.

Studio economy uses the memory adapter. Published Android/iOS, live save/rejoin and real-device visual acceptance are not verified. No Roblox Publish in this task. Pre-existing exhaust/combat/Nitro-on-grass changes and their tests are excluded from this checkpoint. Previously documented baseline broad-suite failures remain outside scope.
