# KDM R8-A5 Garage Shop — Publish Result

**KDM_R8_A5_GARAGE_SHOP_PUBLISHED_FOR_MOBILE_REVIEW — PV681 PUBLISHED PASS.**

Existing Experience `10768420544`, StartPlace `127925465904803`. No new Experience or duplicate place was created.

## Approved source and Native

Fetched origin and confirmed local and remote `prototype/kart-physics` HEAD both equalled `bfb33c2b7e37bdba58ec50255de6b2981cfc6029` before publication. No production source changes were made during this task. The report commit containing this document adds publication evidence only; approved production source remains that SHA.

Approved file: `KDM_R8_A5_GARAGE_SHOP_NATIVE_CANDIDATE.rbxl`, **686,153 bytes**.

SHA-256 before and after Publish: `7b454a9c6a16be6a378f6e134fc04b343bf9133c99fede4ad9d55dcc17c8d3f5`.

Before publishing, the loaded Studio candidate's 173 source containers matched the approved disk sources after newline normalization. The existing cloud editing session was stuck applying script changes and had an intermediate editing state. The user closed that session with Task Manager before the Native publication. It was not used as the publication source.

## Actual PV680 rollback backup

Before publication, Roblox Studio **Version History** showed **v680 — published**, with v679 and earlier unpublished saves below it. Evidence: local image `publish-pv680-history.png`.

Opened v680's **Open local copy** action. The [download log](publish-pv680-download-log.txt) records:

`https://assetdelivery.roblox.com/v1/asset/?id=127925465904803&version=680`

Saved the downloaded version using Studio native Save As, without editing or running it:

`C:/dev/RobloxKart/artifacts/r8-a5-shop/KDM_PUBLISHED_PV680_ROLLBACK_VERIFIED.rbxl`

**676,974 bytes**; SHA-256 `03291340ae878522f57c3b006e56dac45e686abf60bed65d5e78537211e15137`.

[Semantic verification](publish-pv680-semantic.json): 168 baseline sources exactly match the earlier preserved PV680 Studio copy; 1,093 original world/asset entries match. [Raw Terrain verification](publish-pv680-terrain.json): 70 Terrain groups and actual 323-byte Materials content preserved. This is the actual downloaded historical v680, not an AutoRecovery substitute. The prior AutoRecovery backup remains unchanged and retained separately.

The [candidate world/source audit](publish-candidate-semantic.json) and [candidate raw Terrain audit](publish-candidate-terrain.json) also compare the approved Native directly against this actual downloaded PV680 backup.

## One Native Publish and resulting PV681

Selected existing **Kart Drift Masters** in Studio's Publish As dialog, then its existing place, and submitted **Overwrite once**. No retry or second Publish was issued. Local selection evidence: `publish-target.png`.

The [publish log](publish-success-log.txt) identifies:

- `publishAs: currentUniverse=0 currentPlace=0 -> targetUniverse=10768420544 targetPlace=127925465904803 isPublish=1`
- `PublishSuccessful` at **2026-10-14 15:55:52.170 UTC**, equivalent to **22:55:52.170 Asia/Jakarta**.
- `PublishToDifferentGame ... dstPlaceId=127925465904803 ... dstUniverse=10768420544`.
- Subsequent place version check: **681**.

Studio's asset permission stage completed before success. No Game Pass or Developer Product was created/enabled. The initial success label refers to local source placeId 0; target IDs, the reopened cloud DataModel and Version History establish the actual existing KDM destination.

After publication, the cloud DataModel reports PlaceId `127925465904803`, GameId `10768420544`, PlaceVersion **681**, and **173 source containers**. Version History shows **v681 — published** and **v680 — previously published**. Local evidence: `publish-pv681-history.png`. No extra intervening version appears between v680 and v681.

## Actual published Native verification

Opened **v681** from Version History's Open local copy action. [Download log](publish-pv681-download-log.txt) and local image `publish-pv681-download.png` identify the exact asset delivery URL ending in `&version=681`.

Saved the downloaded version natively without editing or running it:

`C:/dev/RobloxKart/artifacts/r8-a5-shop/KDM_PUBLISHED_PV681_VERIFIED.rbxl`

**686,155 bytes**; SHA-256 `5a0d422af8e249b03f2cb7f4bc32e098e2649169d16c819eb66284a3f8b795ad`.

| Verification against approved source / downloaded PV680 | Result |
|---|---|
| All production Sources, after CRLF normalization | **173 exact matches** to approved repository source |
| Original world/asset entries, excluding editor Camera and five new source modules | **1,093 preserved** |
| Raw Terrain property groups | **70 preserved** |
| Actual Terrain Materials SharedString content | **323 bytes identical** |
| Extra mock/import/test source containers | **None** |

Evidence: [published semantic audit](publish-pv681-semantic.json), [published raw Terrain audit](publish-pv681-terrain.json). Whole-file hashes differ after Studio serialization; preservation is established by source/world/raw Terrain equivalence, not assumed binary identity. Lune was used only for read-only deserialization. Its unknown Terrain property-type warning is covered by the raw binary checks. No Native Terrain serialization through Lune occurred.

Read-only reproduction scripts remain local: `audit-publish-pv680.luau`, `audit-publish-pv680-terrain.py`, `audit-publish-candidate.luau`, `audit-publish-candidate-terrain.py`, `audit-published-pv681.luau`, `audit-published-pv681-terrain.py`, using the existing `binary-reader.py`. Native files and screenshots remain local artifacts; only the required report/log/JSON evidence is committed.

## Preserved configuration and mobile review

The actual published sources match the approved SHA, including:

- `StoragePublicEnabled=false`, `RewardsPublicEnabled=false`, `ShopTransactionsPublicEnabled=false`, and the existing canary allowlist.
- `GamePassId=0`, `GamePassEnabled=false`; no active Developer Product IDs, prompts or receipt handler.
- Existing account/store identity, record schemas, selected kart/Wing entitlement, accepted driving physics, AUTO BACKWARD, mobile racing HUD and PV680 engine audio.

No production code/configuration edits, public K$ rollout, arbitrary K$ credit/debit, record/account initialization/reset or main integration occurred. The user's previously confirmed **K$805** account was not read, purchased against or modified during this task. Preservation here establishes unchanged source/configuration and absence of account operations; it does not claim a new live balance query.

**Mobile review is now ready on PV681.** Join a newly started KDM server so it loads PV681, open Garage → SHOP, and review WINGS / RACE ITEMS / MY INVENTORY, seven V2 colors, with/without Wing comparison and touch scrolling. Also check Lobby driving, digital pad/AUTO BACKWARD and racing controls. Public transactions and Robux remain disabled; the existing canary is unchanged. This publication is for display/control review, not approval to make actual account purchases or expand sales.

The earlier development report's mock validation and paid-refill crash boundary remain documented in [RESULT.md](RESULT.md). Real mobile acceptance is pending the user's test; no published-device PASS or live financial/crash acceptance is claimed by this report.
