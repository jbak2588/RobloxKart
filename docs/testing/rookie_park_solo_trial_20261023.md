# Rookie Racing Park individual lap trial - 2026-10-23

## Implemented

- Main-road two-column/four-row bracket grid (8 starts); sequential free-slot allocation wraps through all eight. Existing Pit parking paint remains decorative.
- Each driver independently receives server-owned 3/2/1/GO. First entry and Replay launch with the existing 2-second Mini Boost, without consuming Nitro or crediting a successful Drift. Official RACE start/physics are unchanged.
- One timed lap, six ordered forward swept gates, finish-line return, and server-observed motion/route continuity. Initial start-line passage never counts as a completed lap or a missed gate. A missed gate shows its direction and prevents the award. Recovery grants no gate or distance credit; discontinuous motion invalidates the record.
- Bright translucent lap/PB/reward result, Replay and Return Lobby. Running timer includes personal best when loaded. Result controls hide the driving pad/dials; the older starter-drive notice is hidden while a Park trial is active.
- Atomic personal best/last/lap count plus K$5,000 per valid lap in the existing KDM_PlayerProgress_v1 profile. Server GUID receipts make retries idempotent; success text requires read-back confirmation. Unknown saves can be retried through Replay before restarting. Global leaderboard remains deferred.

## Reference inspected

Hub_n_lobby_original.rbxlx: LapLabel/PlayerListFrame transparency 0.5, HeaderFrame 0.3, background-free FINISH text, and CheckpointGui's behind-camera inversion and screen clamp. Adopted native translucent presentation and bounded next-gate guidance; imported no scripts, remotes or foreign race systems.

## Studio evidence

Actual Studio iPhone 13 landscape: viewport 750x390, Core UI safe canvas 750x332.

| Run | Input-only physical lap | Checkpoints | Lap time | Saved wallet | Personal best |
| --- | --- | --- | --- | --- | --- |
| First | Completed | 6/6 | 02:48.787 | 5,000 -> 10,000 | 02:48.787 |
| Replay | Completed | 6/6 | 02:49.638 | 10,000 -> 15,000 | 02:48.787 |

The temporary QA pilot sent normal Input packets through LobbyDriveControl, driving the actual server kart physics. It did not write kart positions/CFrames or bypass checkpoint validation. The pilot was removed after testing. Result froze the kart; Replay reset to the grid/countdown; Return Lobby unseated and cleared trial state while preserving wallet/PB. The next fresh entry used grid 2 at local (45, -123), rather than Pit or grid 1.

Final source smoke: countdown stayed anchored at speed 0 through 3/2/1; GO unanchored with server ownership nil, boost=true, peak sampled speed 99.825, Nitro remained 1. Studio returned to Edit with no QA script remaining.

Studio economy uses the existing memory adapter. This verifies transaction/read-back behavior, not live DataStore persistence across server sessions. Published Android/iOS multi-touch, visual acceptance and live save/rejoin remain NOT VERIFIED. No Publish performed.

## Automated validation

PASS: new trial rules/records/rewards 54, production trial lifecycle 14, production UI 267; main-road/Pit/flat-support builder 3,674,522 plus flat-recovery 15,318; legacy service physics/qualification 73; showroom selection 38; Return Lobby 27; mobile input Buttons 1188 / Joystick 904; speed HUD 28; six-item HUD 453; race/result HUD 264; official records 65; public warm-up observer 13. All 209 production Luau files compile. Scoped Rojo XML/binary and git diff --check PASS.

Three older broad validations fail identically at the original HEAD b9caf92: r8_a4_economy_validation (ineligible zero), rookie_loop_manual_drive_validation (Lobby island excluded), hub_world_progression_validation (fresh chooses Garage). These are recorded baseline failures, not reported as passing or repaired in this task. Reproduced with source reads redirected to git show HEAD.

Pre-existing exhaust, practice-combat, Nitro-on-grass service hunk and two related test edits remain outside this commit. Push follows repository policy; Roblox Publish requires a separate explicit request.
