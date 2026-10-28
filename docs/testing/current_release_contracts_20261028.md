# Current approved release contracts — 2026-10-28 (R3)

> Later release status2026-10-28: owner confirmed mobile acceptance and authorized
> commit/push plus official Publish. The approved R3 eligibility guard and label
> repair are included in source commit317a844 and official Place version1238.
> Project source hashes matched before and after native Publish; dashboard's
> published-only history confirms the version. This is deployment evidence, not
> a claim of live Wallet/DataStore transaction testing. See
> [release receipt](production_release_20261028.md). R3 checkpoint statements
> below are preserved as historical context.

Baseline: `f5ebec8c7f86dac5c488f90a0a01041d147cf4a2`, local/origin verified equal.
Unless explicitly marked **OWNER_APPROVED_LOCAL**, entries below are
**GIT_APPROVED**: immutable source in that owner-approved release. The owner separately confirms the published shop rules are current.
No current production Studio connection/published-source download was available
in this inspection (only QA KDM_New_Hub was connected), so none is relabeled
**LIVE_VERIFIED** from a local Edit model or from a Git commit alone.

| Contract | Approved behavior | Source / last-changing commit |
| --- | --- | --- |
| Kart sale | Seven KDM V2 colors Kart05–11; each K$50,000, permanent, purchase selects that color; old Wing owners retain all7; no new global Wing sale | KDMShopCatalog `3ed0758`; ShopOperations/ShopService `0fff186` |
| Items | Nitro5000; Missile4000; Thunder3500; Shield/Slick/Smoke2500 each | src/shared/KDMShopCatalog.luau `3ed0758` |
| Purchase authority | Server PREPARE ticket, fixed server catalog price, trusted transaction/receipt identity; replay confirms prior receipt, no second debit; insufficient/read-only/rate/identity failures reject | src/server/ShopService.luau / ShopOperations.luau `0fff186` |
| Legacy Wing/pass | Legacy reducers/data retained; public EconomyService BUY_WING/EQUIP_WING/PASS endpoints unavailable; GamePassEnabled=false, GamePassId0. Dormant WingPrice25000 is not current product price | EconomyService/EconomyConfig/ShopService; `0fff186` |
| Paid item use | PaidItemUseEnabled=false. Stock can be bought/retained; current public auto-consumption/refill is paused. Old stored preference/stock must not be deleted | KDMShopCatalog / ShopService / ShopOperations `0fff186` |
| New account | Absent account presents GUEST cash0. Authorized server TEST_DRIVE evidence≥30s moving and≥300 studs, or valid eligible official finish, qualifies activity and creates schema default cash5000. Existing profiles retain balances; joining/reading alone must not mint cash | EconomyService.qualifyActivity / KDMProgressionSchema.default; `0fff186` release snapshot |
| Persistence | KDM_PlayerProgress_v1; explicit server role/ID policy; public production storage/reward/shop flags true. Studio uses memory adapter; production and QA data are not treated as interchangeable | EconomyConfig / EconomyPolicy / ProgressionDataStoreAdapter |
| Finish base | Owner-confirmed contract: eligible FINISHED≥2 humans rank prizes3500/2500/2000/1500;1 human+bot1500; solo1000. **Ineligible finish pays0, including base/PB/first event. OWNER_APPROVED_LOCAL R3 adds only the base eligibility gate; HEAD still contains the old defect.** | RaceRecordOperations `d5e3931`; owner confirmation2026-10-28 |
| PB / first finish | Best full race1000, best lap500; ordinary base+PB capped5000. Stable first-finish event KDM_FINISH_EVENT_20261016 grants5000 once in addition; its event receipt, not only legacy firstFinishClaimed, is authoritative | RaceRecordOperations / KDMProgressionSchema |
| Rematch | Same-server Room lifecycle. Eligible multiplayer completion (including1H+bot), same track and server-owned rematch intent, advances X1/X2/X3…; multiplier applies base only. Solo/reset/invalid/departure cannot invent continuation. Park two-lap Replay separately earns5000×visit streak | RaceSession `13c1f48`; RaceRecordOperations `d5e3931`; EconomyOperations |
| Active DNF | Separate authoritative ACTIVE_DNF_COMPLETION amount1500 and round identity; not a FINISHED/PB event | EconomyOperations.dnf |
| Nitro | Actual balance BonusRequiredBoosts=3; only successful BOOST outcomes count; held max2, pending max1; accepted consume settles pending, rejected use does not | KDMGameplayBalance `36a1c78`, RaceLoadout |
| GAS | Explicit exact QA/production ID pair+flag; held forward/on-road ordinary cap90. No stacking with Nitro/boost or override of Brake/Drift/combat/off-road/timeout | GasPedalPolicy / PrototypeWorld / adapters `f5ebec8` |
| Reverse | Max70; shared REVERSE_ACCELERATION22 / BRAKE_FORCE70; stop before reversing, no speed jump. Park uses existing Lobby acceleration36 and reverse70, with bounded stationary head-on release | KartConfig / LobbyDrivePolicy / LobbyTestDriveService `f5ebec8` |
| Mobile | Five thin-outline rounded controls; ◀/▶, DRIFT left/GAS right, smaller BRAKE above GAS. Fixed right-side Smoke/Slick/Thunder/Missile then Shield/Nitro; icon+quantity; top-only feedback; safe top-right minimap | MobileControlView / TouchDrivingController / LobbyPracticeView etc. `f5ebec8` |
| Race items | Server-defined6 Slick/Missile/Smoke/Thunder/Nitro/Shield; direct mobile use, desktop1–6 select/Q use; tactical prep protocol retired. Non-final-lap empty-only refill; Nitro uses its own successful-BOOST contract | RaceItemSlots/RaceLoadout/TacticalLoadoutService `7a5309f` and later release |
| Park bots |7 distinct V2 colors at0/30/60/90/120/150/180s while Hub has audience; not an increase in official4-racer capacity | LobbyPracticePolicy / demo fleet `105d131` |
| Ownership | Validated deferred manual server-ownership guards after seating, Shield weld lifecycle and countdown/GO. No per-frame ownership reset or client-ownership change | PrototypeWorld / LobbyPracticeCombat / RaceItemController `c766860`, `f5ebec8` |

Current selectable official tracks (TrackCatalog.Order / `7085949`):

| ID | Display | Laps | Capacity |
| --- | --- | ---: | ---: |
| Track01 | Figure-8 Green Island |3|4|
| Track01Desert | Figure-8 Desert Canyon |3|4|
| Track01Race | Base Circuit |2|4|
| Track01Metro | Metro City Circuit |2|4|
| Track03 | KDM Hard Circuit |2|4|

Track02 remains an Entries compatibility record but is not selectable.
Rookie Park TEST DRIVE is a separate two-lap/six ordered checkpoints-per-lap trial;
main-road8 anchors and Replay visit-streak rules are separate from official races.

## Conflicts with historical AGENTS/development prose

| Old explanation | Actual approved source / handling |
| --- | --- |
| Nitro requires5 successful boosts | Actual3 in `36a1c78`, already inside f5ebec8. Owner R3 explicitly asks current3 testing. No tuning restored; discrepancy explicitly retained here. |
| Track01 single practice lap / Desert2 / Track02 selectable | Current catalog above; Track02 retired from Order. Historical records/protocol Entry remains. |
| Initial joining grants5000 | Guest read does not create account. Activity qualification creates5000, preserving old profiles. |
| Wing25000 unlocks7 colors for every new buyer | Historical entitlement only; new per-color kart50000. Owner confirms current shop rules supersede old descriptions. |
| Items250 / automatic paid refill ON | Current catalog prices above, PaidItemUseEnabled=false. Do not consume purchased inventory automatically. |
| Reverse24 or50 | Current70, gradual. Do not change live physics to fit an old test. |
| Four Park bots / single legacy demo world | Seven traffic colors, new Park-connected Hub. Retired code still exists; not claimed deleted. |
| GAS preview-only/private-only, circular controls | Approved f5ebec8 enables exact QA+production pairs and latest rounded layout; old paragraphs are historical. |
| Current reducer guarantees ineligible finish base | **Owner explicitly rejects this behavior2026-10-28 and separately approves the minimal source fix.** Local R3 adds the eligibility gate only; zero-payment assertions and an injected old-bug rejection test enforce it. |
| One-human+bot has no multiplier / fresh-job Rematch | Current same-server eligible1H+bot continuation is approved. |

The owner subsequently authorized two precise local exceptions to the original R3 source restriction: the invalid-finish base-payment gate and the public track capability label encoding repair. Both are **OWNER_APPROVED_LOCAL**, not committed/published. Other gameplay/economy/ownership/camera logic remains byte-identical to HEAD except the pre-existing FOV candidate.
FOV Phase1 remains a local candidate:50/90/High delta5; Mini6/Nitro10, MAX_FOV87
and easing/position unchanged. It is not claimed LIVE_VERIFIED or Published.

## Owner confirmations — 2026-10-28

- Activity-qualified starter5000 and first eligible official-finish event5000 are
  **separate grants**. No join/read-only minting; no repeated grant on rejoin/retry.
- Ineligible official finish: **zero completion reward as well as zero PB/event**.
  This was a confirmed contract/source defect. The owner approved the second-item source fix; local R3 now gates base payment on eligible=true. Invalid receipts remain durable and replay-safe; campaign eligibility and account data are preserved. This does not change the separately authorized active-DNF policy.
- Green/Desert3 laps, Base/Metro/Hard2; Track02 not selectable: confirmed.
- Current shop rules confirmed by owner as the latest published rules. They remain
  GIT_APPROVED + OWNER_CONFIRMED_LIVE_POLICY; actual published source not downloaded,
  so no unsupported LIVE_VERIFIED source claim is made.

## Additional exact R3 contracts and scope

- **OWNER_APPROVED_LOCAL display repair:** TrackCatalog.capabilityLabel public line
  uses `PUBLIC RACE • 1–4 RACERS • …`. The single line was reconstructed against
  the approved Git object; laps, selectable IDs and geometry are unchanged.
  The unused legacy solo-label mojibake is outside this approval and remains.
- Official bots are enabled for Green, Desert, Base and Metro; Hard/retired Track02
  remain disabled. All official tracks still cap total racers at4.
- Valid individual-lap eligibility and full-race eligibility are separate existing
  record fields. The new payment gate does not rewrite records or compensate old
  payouts. An invalid race pays0 even when an individual valid lap exists.
- The approved TrackBuilder emits Green HUB/RACE1054/1006 visual parts,
 88 visual rails (19 KDM panels+12 curve-chevrons+57 plain), legacy SpeedCues0,
 six checkpoints+finish. Tests retain the <=1400 budget and independent geometry,
 clearance, noncollision, branding, cache and cleanup checks. Terrain grass is.1.
  These are f5ebec8 output contracts, not new scenery changes; current client
  preview groves are covered separately from retained horizon modules.
- Current imported Hub shell uses3 native kiosks in place of old sign parts;
  wall boards remain3. Local showroom fixtures have range50/brightness.25;
  doorway fills range30/brightness.25. The Lune mock now models rigid Model
  pivot/bounds and the native Kiosk resource rather than substituting server code.
- Public paid-use remains OFF even if an old profile has autoRefill=true. The
  identity integration includes a clearly labeled **test-only LEGACY_OPT_IN**
  branch to exercise retained reserve/finalize/refund defenses; it cannot enable
  production consumption. A separate real-service default-policy scenario proves
  no stock, receipt or delivery is consumed while paused.
- R1 current-release manifest retains all original133 approved full-file hashes
  and all N1/N2 fixtures. Two appended exact before/after hunks allow only the
  owner-approved R3 changes. Full-file SHA plus inverse-hunk verification reject
  any other bytes. R1/R2 evidence files are preserved.
