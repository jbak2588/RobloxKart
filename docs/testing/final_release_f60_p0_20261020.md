# F60 + P0 release gate — 2026-10-20

Scope approved for two commits and push. **Roblox Publish is held**: mandatory release gates below are not all established. No production data writes, Publish, or server restart were performed in this release task. This report does not mark the 41 baseline failures as PASS.

## Git / exact source

Start: `prototype/kart-physics`, local/origin `5f9fe3eaec0b8a98abaa137bae54ba3d2e07ffa4` after fetch. Reviewed consolidated P0 diff was regenerated and matched the previous review artifact exactly. All preserved F60 files were byte-identical to their reviewed backup. F60 and P0 manifests have no overlapping paths; no hunk surgery or file restore is needed.

Final full regression rerun: **202 suites, 161 PASS / 41 existing FAIL / 0 new FAIL**. Idempotency 75 checks/10,000 transactions PASS; DNF/autorefill integration 152 checks PASS. No new source edits were made in this release task. Production compilation, XML/binary build, and diff checks are rerun before push. Per-file commit and source-hash manifests remain local under `artifacts/final-release/`, excluded from commits along with all builds/logs/captures/profiles/ZIPs.

Studio remained in Edit mode. A read-only SHA-256 audit compared all **196 production sources** to disk: 196 match, 0 absent, 0 different. The checked-in Git tree is verified again against these normalized source hashes after both commits.

## Deployment identity

Verified Studio DataModel: universe/experience **10768420544**, place **127925465904803**, loaded PlaceVersion **915**. The loaded version number is not proof of current live published version or of running-server versions.

This repository uses **one Place for both roles**, rather than two independent HUB/RACE Places. `ServerRuntime.resolve` chooses HUB vs reserved RACE; RaceLaunchService teleports/reserves using `game.PlaceId`. Both roles load the same economic modules and `KDM_PlayerProgress_v1`. Do not invent a second RACE Place or publish to another Place on the assumption that the roles are separate Places.

## Publish gates

| Gate | Finding |
|---|---|
| Universe and runtime target | PASS for Studio/source identity above; Creator Hub live universe/place inventory not independently enumerated |
| Reviewed source in Studio | 196/196 source hashes match; no Publish performed |
| Same P0 contract for HUB/RACE | Same-Place architecture and shared economic modules confirmed |
| Visual/driving/mobile | Reviewed F60 captures/acceptance preserved; automated regression unchanged. Remaining VFX cases below are not cleared |
| Read-only operational backup / recovery | Concrete plan below; no authenticated current pre-release full-store snapshot/version manifest exported or recovery drill completed |
| Studio cannot write production data | Economic facade uses Studio-only memory adapter; diagnostic official rounds fail record mutation validation and repair policy blocks Studio writes. **PlayerPreferences still has a real KDM_PlayerPrefs_v1 UpdateAsync path without IsStudio guard**; full-game Play must not run against production-connected Studio API access. No Play was started in this release task; API-services-off / separate test-universe isolation is not verified here |
| Remaining failures cleared for release | No newly reproduced money/dedup/storage/own-profile access/result correctness defect. Three VFX assertions remain unresolved rather than waived |
| Active players / coordinated outdated-server restart | Live player count, server inventory, management permissions and complete old-server drain not verified; restart not attempted |

These are reasons to hold Publish, not a request for another confirmation. Commit/push approval is independent. Source code was not changed merely to force these release gates green.

## Storage/access/result review

The old ineligible-zero payout assertion conflicts with the approved completed-race base-reward policy. The old money runtime totals omit the approved first-finish event. The current reward math is unchanged and current idempotency/runtime tests pass. The failing legacy service harness still calls old begin without controller identity; actual current controller/record/economy/shop integration passes.

Own-profile access is not arbitrary-user access: runtime keys are derived from the invoking Player.UserId; personal-record query accepts no client target UID and returns records, not wallet/receipts. MY RECORDS UI's existing admin restriction is preserved. Ordered leaderboard repair remains separately policy-gated. The old blanket 'ordinary account makes zero records API calls' expectation is not the current public own-account policy.

The HUD test reads the Best label using obsolete text expectations. A separate temporary probe executed the actual production HUD and checked RecordSave: SAVE PENDING / RECORD SAVE UNCONFIRMED / RECORD SAVED / NEW BEST RACE. It passed without weakening or editing the original failing test.

## Each of the 41 existing failures

| Suite | Cause / evidence | Release risk judgment |
|---|---|---|
| `boost_flame_fade_validation.luau` | Unresolved VFX: re-drift residual-particle assertion fails. Timing/throttle interaction needs a separate renderer investigation; not waived. | PUBLISH NOT CLEARED: visual behavior vs fixture timing unresolved |
| `bot_internal_control_validation.luau` | Historical whole-source freeze excludes only the original Bot extension; fails before a behavioral assertion. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `drift_telemetry_validation.luau` | Fixture expects an end log although production DEBUG_TELEMETRY=false. Configuration/observability contract mismatch. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `economy_v2_arcade_shop_validation.luau` | Fixture module registry lacks KDMUiStyleHelper, required by GarageShopController line 12. Actual Studio Shop opens. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `economy_v2_shop_navigation_validation.luau` | Uses the same incomplete Shop fixture; missing KDMUiStyleHelper. Actual Studio Shop opens. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `finish_source_freeze_validation.luau` | Historical exact RaceController source fingerprint differs after later approved race changes. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `hub_world_progression_validation.luau` | Expects first-visit CHOOSE KART/Garage gating, superseded by approved one-click RACE NOW. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `item_aftershock_validation.luau` | Historical exact KDMItemVFXController source fingerprint differs. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `lobby_palette_validation.luau` | Freezes all non-color HubUiController source, conflicting with approved C1/C2 structural UI changes. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `lobby_post_drive_return_validation.luau` | Expects old Race-screen entry callback; current approved action uses QuickStart. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `lobby_practice_combat_validation.luau` | Asserts four default race items; current approved contract has six. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `lobby_shield_visual_validation.luau` | Unresolved VFX: practice local/remote Shield renderer visibility assertion fails at fixture tick. Not accepted as harmless. | PUBLISH NOT CLEARED: visual behavior vs fixture timing unresolved |
| `lobby_terminology_validation.luau` | Historical TrackCatalog non-display-field freeze conflicts with later catalog revisions. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `missile_validation.luau` | Direct Shield-use assertion also expects selected Nitro as historical slot 1; current six-item default slot 1 is Slick. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `pit_garage_art_validation.luau` | Offline builder fixture lacks KDMTemplateResources.Kiosk resource used by actual art builder. Live Studio PIT_GARAGE loads. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `practice_figure8_geometry_validation.luau` | Fails old whole-catalog freeze (except original Bot capability), before geometry acceptance. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `practice_public_bot_validation.luau` | Fails exact accepted-byte catalog fingerprint for earlier P2B milestone. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_a2l1_canary_guidance_validation.luau` | Historical canary expects CHOOSE KART and old Garage/Tracks progression, superseded by current entry flow. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_a3_hud_validation.luau` | Old assertion reads Results.Best, but save state belongs to Results.RecordSave. Actual label pending/failure/confirmed/PB probe PASS; no false success reproduced. | Non-blocking stale presentation assertion; actual save-status probe PASS |
| `r8_a3_service_validation.luau` | Fixture calls the former 3-argument begin API; current controller supplies the required independent identity. Actual 4-mode service-chain integration PASS. Public records query is scoped to the invoking player, not a client-selected user. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_a3b_integration_validation.luau` | Reuses obsolete service fixture / begin API. Actual records-runtime and current controller/economy/shop integration PASS; this legacy fixture has not been rewritten. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_a4_economy_validation.luau` | Expects zero base reward for ineligible completed result; current completion/DNF reward contract differs (race_checkpoint_and_dnf_reward suite passes). Requires old contract reconciliation. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_a4_runtime_validation.luau` | Old injected wallet totals omit the already-approved first-finish event bonus. Underlying runtime 60 checks and dedicated current reward/ACK-loss tests PASS. Later embedded service fixture also predates independent identity. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_a6_public_cash_validation.luau` | Expects initial join to persist a K$5,000 wallet; approved qualified-Test-Drive-only storage leaves guest profile nil. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_d2_presentation_validation.luau` | Unresolved VFX: persistent grounded skid-mark visibility assertion fails. Needs renderer/timing review; not waived. | PUBLISH NOT CLEARED: visual behavior vs fixture timing unresolved |
| `r8_perf_p0_validation.luau` | Exact observer-wrapper source-string assertion differs after subsequent performance changes. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_perf_p1_validation.luau` | Exact full-simulation preservation source assertion differs; not a measured FPS failure. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_perf_p2b_validation.luau` | Exact diagnostic summary ordering/CanvasSize source-string assertion differs after diagnostic changes. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_perf_p2c_validation.luau` | Historical reproduction expects old false-capacity refusal; compressed signatures no longer reproduce that scenario. Does not establish receipt-retention safety. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `r8_perf_partner_validation.luau` | Expects live diagnostic allowlist for two accounts; user explicitly requested disabling those overlays after device acceptance. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `race_item_reset_validation.luau` | Calls removed SetTacticalLoadout selection contract; current six-item flow has no tactical preparation. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `race_launch_routing_validation.luau` | Historical arrival expectations include old Practice capacity/forced driver/pre-race state, superseded by public Practice/Bot/avatar/countdown changes. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `speed_sensation_validation.luau` | Historical exact RaceController gameplay source fingerprint differs. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `straight_speed_validation.luau` | Numeric route analysis runs; failure is unchanged balance DRIFT assertion, not a reported numeric straight-strip failure. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `track02_published_binding_validation.luau` | Historical PV545 catalog parity assertion differs from later catalog revision. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `track02_raceability_b_validation.luau` | Expects legacy production catalog and B diagnostic-only status, predating later production binding. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `track03_four_player_validation.luau` | Expects four-human WAITING/item-prep gate; approved current full-room launch has no item-prep wait. Current four_player_race suite passes. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `track_h3_flow_validation.luau` | Historical exact catalog freeze permits only original P1C/P2B field changes. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `track_v2_geometry_validation.luau` | Numeric Nitro-strip output runs; failure is historical unchanged Track02 catalog gameplay assertion. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `v2_gauge_v1_audio_validation.luau` | Historical AudioConfig/input asset fingerprint differs after later audio revisions. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |
| `v2_public_multiplayer_validation.luau` | Historical catalog identity/image freeze differs from subsequent catalog revisions. | No confirmed economic/storage/access/result blocker from this assertion; historical contract/fixture mismatch |

Three VFX failures (redrift residual particles, practice Shield world visual, grounded skid marks) need focused fixture-timing and runtime visual confirmation. They do not establish a new financial defect, but their behavior is not certified safe for this conditional Publish. Other legacy assertion/fixture mismatches are recorded individually above; none is silently converted into a passing test.

## Read-only backup and forward recovery plan — not executed

1. Confirm exact universe/place and current live versions in Creator Hub; inventory active public HUB and reserved RACE jobs. Use one coordinated maintenance window, not a prolonged bleed-off of writers using the old receipt-deletion code.
2. With approved read-only Open Cloud/Data Stores Manager access, export all pages of current keys for the default-scope `KDM_PlayerProgress_v1`, latest version IDs/timestamps, key user IDs and metadata. Read exact versions as needed; never Set/Update/Remove as part of backup. Record capture time, per-key version and checksums and verify counts/page completion. Export values only into protected, non-repository storage; public logs contain aggregate status only. A live multi-key export is not an atomic global snapshot, so record each key's own version.
3. Keep an original immutable copy and validate cloned profiles offline. Test restore logic on a separate test universe/store, never on production accounts. The single user-supplied JSON used by P0 is not a full operational backup.
4. If a production problem occurs, stop new testing/writes to affected accounts and retain current profiles/versions for analysis. Prefer a forward fix with current idempotency policy. Do not republish the old prune-all code or blindly Revert full profiles: that can remove recent purchases/rewards and dedup evidence. Any per-key recovery requires a reviewed current-version-aware merge preserving ledger/ownership/first-reward/receiptPolicy/reservations, then separate authorization.

[Official Data Stores Manager/version inspection](https://create.roblox.com/docs/cloud-services/data-stores/data-stores-manager), [version retention and same-hour overwrite behavior](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching).

## Exact future manual deployment sequence — only after all gates pass

1. Resolve the VFX/runtime and Studio isolation gates; obtain and verify the read-only backup manifest. Confirm live player load and maintenance access. Open/build the pushed P0 HEAD and verify sources/assets and target universe/place.
2. Publish to **10768420544 / 127925465904803** only after Creator Hub confirms this is the same active target. One place update serves both public HUB and reserved RACE roles. Capture the new published version V; the version after Publish is currently unknown.
3. Creator Hub → Creations → game → Configure → Server Management → select the verified target Place → Restart Servers → **Restart only servers with outdated versions**. Avoid a long optional delay because old writers can delete new receipts. Check reserved as well as public jobs; do not infer complete drain only from pressing Restart.
4. Record active old job IDs/versions before and after restart. Verify no old-version job remains able to write profiles; if that cannot be established, stop the rollout and further account tests.
5. On version V, perform limited normal-use checks only: Lobby UI/lighting, TEST DRIVE, RACE NOW to reserved race, normal completion/payment/first-event latch, existing account data, one deliberate normal shop purchase and reconnect ownership, normal autorefill. Do not replay transactions intentionally or reset production profiles. Stop on storage errors.

[Official release/restart procedure](https://create.roblox.com/docs/projects/update-experiences). Publishing alone does not terminate existing servers. No post-Publish check is claimed for this task because Publish is held.
