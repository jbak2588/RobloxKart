# PARK-FLAT-R1 accepted checkpoint — 2026-10-22

Owner-approved baseline for subsequent PARK world art. Supersedes the uphill
driving geometry described in `rookie_loop_island_stage2.md`; unfinished local
H1 elevation work is excluded. Starting Git HEAD: `b33b293d731412807ede21a7635777cdd15802f3`.

- One continuous horizontal contact face; height 0 and normal (0,1,0).
  Asphalt top +.02 stud, decorative grass -.2; island cliffs, sea and Sky retained.
- Approved main-course X/Z and four manual spawn slots retained. Road width 68,
  shoulders 0; outside guardrails stay fixed. Pit width 32, widened toward the
  road with its plaza-side edge retained, matching asphalt and both kerb borders.
  The obsolete median wall and PIT IN/OUT text/arrows are removed.
- Red/white kerbs use equal arc-length runs and shared polygon edges at one
  height, avoiding overlapping colour surfaces. Pit surfaces are clipped at
  the main asphalt boundary.
- Default flag OFF and existing Studio/staging gate retained. No automatic
  arrival boarding, kart physics, ownership, item tuning, HUD, official RACE,
  matching, economy or DataStore changes. Item grounding follows the flat skin.

## Acceptance and final verification

Owner confirmed private-published mobile real-device driving and accepted the
road-snag, wheel-contact and grass-flicker fixes, including the final Pit/kerb
revision. This is user-supplied device acceptance, separate from automation.

Latest isolated Studio run (GameId/PlaceId 0): visible TEST DRIVE entry, native
client inputs, full loop plus Pit return 125.84s; no position/velocity writes,
resets 0, observed stalled time 0, maximum ground-height error .01485 stud.
RETURN LOBBY cleared active/pending state, kart and seat; Studio errors 0.

Final focused regression: **21 PASS / 3 existing FAIL / 0 new FAIL** (24 files).
The existing failures remain FAIL, unchanged:

- `lobby_practice_combat_validation`: historical four-item defaults assertion.
- `lobby_post_drive_return_validation`: obsolete Garage race-entry assertion.
- `v2_gauge_v1_audio_validation`: historical AudioConfig snapshot assertion.

203 production Luau files compile; Rojo XML/binary builds and `git diff --check`
PASS. Flat recovery validation: 15,412 checks; shared geometry fixture:
3,671,314 checks. No new code changes during checkpoint finalization.

H1 WIP remains in ignored `artifacts/h1-wip-backup-20261022-074934` (source copies,
patch and hash manifest). Builds, captures, logs and probes remain ignored and
are excluded from this checkpoint. Roblox Publish is not part of this approval.
