# Rookie Park Overtake — 2026-10-29

Owner authorizes implementation, scoped commit/push and official Publish to
Universe `10768420544` / Place `127925465904803`. Baseline local/origin:
`75ba1e7d29b336b74ce8814ef80115c9c2f20195` (includes finish-total rankings and
`1305df9` VFX optimization). Existing Desert-priority ranking defaults are retained.

## Final contract

- Separate Hub challenge, first card in TRACKS, preview `94896526779384`.
- Existing Rookie Racing Park geometry, grid allocation, physical human kart,
  manual server ownership, GAS/Drift/Nitro and two-lap time attack remain intact.
- One human per personal challenge. Seven differently colored noncontact rivals
  start together at 1/8, 2/8, ... 7/8 of actual course length from that human's
  allocated start. Each uses the same server-time timeline and constant70 studs/s.
- Driver must complete3 laps and all18 ordered checkpoints. The initial grid-to-
  finish crossing does not count as a lap. Existing continuity/recovery checks apply.
- At the final finish, compare unwrapped total race distance against each rival.
  No cumulative pass counter, repeat passes, modulo-position sorting or lapped-bot
  double counting. Ties are not ahead.
- Base K$5,000 + K$5,000 per rival behind at finish; all7 add a single K$10,000
  perfect bonus. Max K$50,000. Replay starts a fresh challenge with no multiplier.
- Owner superseded the earlier suggested60 and requested80, then finalized a
  difficulty requiring95–100 average studs/s for all7. Uniform70 yields approx98.8
  with the current three-lap geometry. Tests check every allocated start slot.
- Eight-second pre-GO instruction display, then existing launch/countdown lifecycle.
  In-race HUD stays at top; results show final count, reward and confirmed-save status.
- Nitro/Shield stay available. Four offensive items are hidden/rejected in this
  mode; other Hub combat cannot target its driver. Ordinary Park/official combat
  retains its existing rules. Rivals are personal route-following visual bots,
  not player actors, Seat assemblies or shared audio sources.

## Persistence and isolation

A dedicated `park-overtake:<server GUID>` immutable receipt derives the reward
from server-observed finish time, slot and complete-course proof. It checks exact
final count, plausible maximum pace120, wallet capacity and account validity.
A lost ACK/retry cannot credit twice; mismatched identities are rejected. The
existing `parkReward` exact Hub permission and Studio memory adapter apply.
Cash, lifetime earned and ledger revision update atomically; purchases, selection,
existing PBs and old receipts are preserved. Challenge races never feed Solo or
Multiplayer time rankings. The lifetime earned board includes earned prize money.
No remote accepts reward amount, finish proof, elapsed time or pass count.

Seven visual models are built one per frame, noncolliding/non-queryable, with
no Humanoids or physics ownership. Course station lookup is binary search over
precomputed samples. Replay/exit/respawn destroys all personal models and clears
replicated challenge attributes. Ordinary demo visuals resume after exit.

## Validation

- Dedicated test:231 policy/route/reward/receipt checks, real Garage first-card and
  dedicated launch wiring, plus9 real Park session/ACK/Replay checks.
- Exact finish-order threshold, tie/repass semantics,0/partial/7 counts, perfect
  maximum, invalid/partial/forged proofs, duplicate ACK, receipt mismatch,
  capacity/deleted-account rejection, unrelated-profile preservation.
- Existing normal Park trial/session/view, controls, GAS, ownership, item, wallet,
  race lifecycle and VFX regression coverage retained.
- Historical N1/N2 fixtures are unchanged. Current-release manifest adds only13
  exact feature hashes, independently pinned by the auditor. Every feature source
  rejects extra/deleted bytes; old base hashes and other approved patches remain.
- Studio ordinary initialization and actual Track card click verified: image loads,
  rule text visible, ordinary Hub Drive remote starts mode,7 models present.
- Controlled real-time native route pilot verified18 gates, final finish, reward
  ACK and one-click Replay. The initial60-stud experiment produced197,459ms /
  7 behind / K$50,000; it is superseded and is not final70-speed acceptance.
- iPhone17 Pro landscape simulator: loaded preview and rules fit; actual client
  viewport750x382. This is not an iPhone device acceptance or network-load capture.
- Studio preference API access is disabled; existing KDM_PlayerPrefs_v1 warning
  is unrelated to this feature. No production DataStore writes during Studio QA.

## Rollback

Revert only this feature commit, restore its current-release hash extensions,
and rebuild/sync. Keep prior `75ba1e7`, total-time indexes, purchases and account
fields. Already-issued immutable challenge receipts remain ordinary valid receipts;
never delete/roll back wallets to remove a feature. Before publication, retain the
previous official published version as a Roblox rollback point and save a local
full-place snapshot. No server restart or access-setting changes are authorized.

## Final70 validation receipt

- Final controlled100-stud/s native pilot started from the actual observed
  post-GO chassis position (17.7ms delay; no initial distance jump).3 laps /
  18 checkpoints finished in177,730ms; final7 behind; rewardK$50,000 and
  SAVE_CONFIRMED. Studio memory wallet increased15,000 ->65,000 exactly.
  A prior absolute-clock pilot skipped the initial line crossing and needed an
  extra circuit; the observed-position pilot removes that injection artifact.
  These captures are controlled route validation, not manual mobile driving.
- Final full suite252 tests:232 PASS and the same20 historical failures; no new
  failed tests.709 current-release integrity/mutation checks PASS; independent
  baseline133-file audit plus13 exact feature pins PASS. Rojo build/diff PASS.
- Official Edit model231 project sources match canonical local SHA256 hashes;
  exact Universe/Place and all3 Park/mobile/GAS rollout flags verified true.
- iPhone17 Pro landscape preview/image/rule/result screenshots verified. The
  simulator input-focus guard hid driving controls during some unattended tool
  captures; existing mobile input regressions passed, but real-device driving
  acceptance remains unverified. Device simulation stopped; Studio reset to
  default viewport and Edit mode. No production account writes or server restart.
- Existing published rollback point verified in Creator Dashboard:PV1244.
  Unpublished autosaves1252 are not publication evidence.

Full native pre-publication snapshot (candidate sources included):
`C:/Users/OWNER/AppData/Local/Temp/KDM-official-before-overtake-publish-20261029.rbxl`
(1,410,296 bytes, SHA256 `ab6f3bf05ad44dbe85ff4011fe922b27e59e1607c6f1eead5a3f6150e62d0a1b`).
All241 serialized script sources match the native inventory, including231 project
sources. The native binary is retained untouched; the Lune read-only inspector
warned about its newer Terrain.VoxelGridAssetContentMap serialization property.
Publication uses the original Studio scene rather than a rebuilt/round-tripped
copy, preserving imported mesh and terrain properties.

## Official publication receipt

- Implementation commit `67baa80f20fbc9f23d4aa1c22c65c7bf64d73788` pushed to
  `origin/prototype/kart-physics`; local and remote matched before Publish.
- Original native Studio scene published to Universe `10768420544` /
  Place `127925465904803`. Creator Dashboard Version History confirms **PV1252**
  with Show published only enabled and a Published Version checkmark on2026-10-29.
  Dashboard displays the version's local update time as October29 at7:41PM;
  this timestamp is not asserted as the later publication-click time.
- Evidence: `C:/Users/OWNER/AppData/Local/Temp/KDM-overtake-published-v1252-20261029.png`.
- No access-setting changes, server restart, main changes or production account
  test writes. Existing servers were not forced to reload. Post-publication
  real-device manual driving and a live wallet transaction remain unverified.
- Rollback checkpoint remains previously published PV1244; wallet receipts and
  account balances must be preserved. Restore requires normal Studio Publish.
