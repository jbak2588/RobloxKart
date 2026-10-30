# Multiplayer human-first Top5 fallback - 2026-10-30

Owner confirmed: keep human-versus-human entries first; only when fewer than5
users exist, fill empty Top5 rows with valid1H+1B finish records. Owner explicitly
authorized scoped commit/push and official Publish, without server restart.
Baseline cadede48d9e7e7b4ef02240d50959db99935049d; fetched local/origin equal.

## Production read-only audit

Creator Dashboard owner session, exact Universe10768420544. All204 active
KDM_PlayerProgress_v1 keys inspected through visible Data Stores Manager,25 keys
per page.22 profiles retained race entries. Only current saved lastRace/bestRace
full-race snapshots were analyzed; no version-history rollback, key edit, account
write, derived-index write or API/security-setting change was performed.
No raw account IDs, wallets, receipts or profile exports are committed.

| Track | Human-only users | 1H+1B users | Distinct union |
| --- | ---: | ---: | ---: |
| Green Island / Track01 |4|15|17|
| Desert Canyon / Track01Desert |2|3|4|
| Base Circuit / Track01Race |4|3|5|
| Metro City / Track01Metro |0|1|1|
| Hard Circuit / Track03 |0|0|0|

Counts require eligible/serverAccepted/finalized FINISHED evidence, correct owner,
current track/geometry/ruleset/lap count, positive lap times and consistent full
Finish total. Old single-lap minima are not converted or multiplied. Counts are
unique users, not race finishing positions or number of historical attempts.
This is a current saved-profile audit, not a claim of complete all-time history.

The production policy applied read-only to these records selects Green Island.
Rows1-4 are human-only totals94,929 /97,146 /99,363 /104,279ms. Row5 is a distinct
1H+1B user at91,429ms. A faster bot-category record belonging to an already-listed
human user is excluded. Human priority intentionally takes precedence over time
between the two categories; each category remains sorted by complete Finish total.

## Implementation and preservation

- Keep existing MULTI_<track>_TOTAL_R2_L<laps> indexes strictly human-only.
- Add separate BOT_<track>_TOTAL_R2_L<laps> derived indexes, admitting exactly
  BOT_1H_1B with1 starting human/1 starting bot. No mixed2H+bot or incomplete run.
- Compose human rows first and append only enough distinct bot users to reach5.
  Five or more human rows retain the existing human Top50 with no bot additions.
  Prefix supplemental world/detail names with [1H+1B] so long names cannot hide
  provenance; explain HUMANS FIRST in board/detail status. Own visible fallback
  row uses its actual score, without replacing a human-only saved PB.
- Feature the track with the fullest Top5, then more human Top5 rows, then more
  distinct users within the loaded Top50 source pages. Green is the audited
  initial default/tie preference. Incomplete/stale source caches preserve the
  current track. Physical board, subtitle, kiosk and initial Multiplayer tab agree.
- Existing bounded offline scan reads accounts and idempotently min-writes only
  the derived indexes. Same exact live-environment guard, read/write budgets,
 12s sorted-read spacing, profile/backfill retries and60s cache refresh remain.
  Additional source caches may take a few minutes to warm.204-account backfill
  needs at least roughly7 minutes, plus read/write contention and refresh delay.
- Preserve account balances, receipts, purchases, PBs, old indexes, geometry,
  driving, manual ownership, race admission and all rewards. No server restart.

## Validation and deployment preparation

-253 full validation processes:233 PASS /20 identical historical FAIL /0 new FAIL.
  NOT FULL_SUITE_PASS; original N1/N2 and historical failures remain.
- Dedicated fallback28 checks, existing leaderboard64, integrity/mutation784 PASS.
  Separate-category proof, deduplication, full-human priority, missing evidence,
  stale caches and feature selection are covered. Python manifest audit, Rojo
  build and diff check PASS. Final presentation-prefix compile checks rerun PASS.
- Actual Studio ordinary startup confirms MULTI_Track01 on board+kiosk and the
  replicated featured attribute; subtitle GREEN ISLAND /3-LAP /HUMANS FIRST.
  Studio stays memory-only and says STUDIO PREVIEW - NO LIVE DATA. Existing
  PlayerPreferences API warning remains. No real live index write claimed here.
- Native original Place backup (candidate sources included):
  C:/Users/OWNER/AppData/Local/Temp/KDM-official-multiplayer-fallback-20261030.rbxl.
  SHA256cc1e98ae7a4129543bfb854474840a517d0983d99f4638e389297a371a1e2399.
  Read-only Lune inspection confirms232/232 source matches, zero mismatches and
  all three Workspace release flags true. Preserve binary Terrain content-map
  bytes; publish the original scene, not a reserialized/rebuilt backup.
- Live backfill completion and actual published board rendering remain separate
  from Studio/mock evidence. Existing jobs retain their old code until replaced
  naturally; no forced restart is part of this release.

See [machine-readable receipt](multiplayer_fallback_results_20261030.json).

## Publication receipt

Published official Universe10768420544 / Place127925465904803 as PV1270,
code commit0832a5ce66ab9d92a609831cf79972b6f4729f3f. Native Studio success
and Creator Dashboard published-only history independently confirm1270.
No server restart. Live backfill completion and published board rendering
remain unverified; the read-only audit and Studio evidence above are distinct.
