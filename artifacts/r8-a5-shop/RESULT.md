# KDM R8-A5 Garage Shop & Economy Integration

Status: **KDM_R8_A5_GARAGE_SHOP_READY_FOR_MOBILE** — development Native candidate and mock-account Studio validation. No Publish. Public baseline remains **PV680**, following user-confirmed PV672 controls and PV680 engine audio acceptance.

Repository: `jbak2588/RobloxKart`, branch `prototype/kart-physics`. The implementation commit containing this report is the final source checkpoint; its Git parent is the preservation checkpoint below. No main integration.

## PV680 preservation before development

Fetched origin; original local and remote HEAD both equalled `537847cf82fa193fc76ad85abf58d34e746b3bf1`. Preserved the nine accepted local control/audio sources, which matched connected Studio sources after newline normalization, and committed/pushed them first:

`08685b3dc392df677702b920d385e5f9be856bbb` — Preserve PV680 accepted auto reverse controls and engine loop audio.

See `PV680_PRESERVATION.md`. `pv680-publish-output.jpg` records Studio's successful v680 publish output. The rollback is a post-publish Studio AutoRecovery copy, **not a downloaded PV680 delivery certificate**:

`KDM_PV680_STUDIO_ROLLBACK.rbxl` — 676,941 bytes; SHA-256 `0933f55de7935838bb2aab62bce1bc60aa22ec500218869dde23ea83530d570e`.

It has 168 matching baseline sources. Original world/assets and raw Terrain were checked against the earlier verified Native. Accepted AUTO BACKWARD, mobile controls and engine loop changes are included. No original file was deleted or rolled back.

## Implemented shop

Garage's SHOP button opens a dedicated safe-area drawer with WINGS, RACE ITEMS and MY INVENTORY. Closing returns to the Garage when opened there; race launch, test driving and race state transitions dismiss it. Existing DRIFT, digital pad, AUTO FORWARD/BACKWARD, item HUD, camera, physics and VFX sources were not changed by R8-A5.

WINGS uses the actual KDM V2 visual factory, seven color variants, with/without Wing comparison, permanent K$3,000 purchase, confirmation, Owned, Equip and Unequip. The entitlement is the single `KDM_V2_WING`, not a separate purchase for each color. Wallet and ownership use the existing Economy facade/attributes, keeping MY PROFILE and Garage in sync.

The Robux path remains disabled: `GamePassId=0`, `GamePassEnabled=false`. Disabled UI clearly identifies 50 Robux as the planned target. When separately configured, the client requests the player's actual pass price, the server independently verifies ownership, and both payment paths converge on the same Wing entitlement. Off-sale ownership can still be reconciled. No pass/product/Experience was created. Configuration and future Developer Product receipt design are in `MONETIZATION_SETUP.md`.

| Permanent refill voucher | Trial price |
|---|---:|
| Nitro | K$25 |
| Shield | K$30 |
| Slick | K$15 |
| Missile | K$35 |
| Smoke | K$20 |
| Thunder | K$40 |

Optional additive `shopInventory` preserves existing v1 accounts, wallet, records, receipts, selected kart and Wing data. Six per-account stock counts persist separately from temporary RaceLoadout. Purchased stock cap is 999 per item. Auto refill defaults **OFF**, requires explicit confirmation, and consumes owned stock only when a corresponding active race slot is empty. Limits: one refill per item and two refill reservations per official race, including cancelled/refunded reservations. No fifth slot or new racing HUD was added. Free initial items, lap refills, tactical selection, Rematch refill and earned Bonus Nitro remain owned by their original systems. Paid refills require the existing eligible reserved RACE path; Practice and Hub test driving do not consume paid stock.

## Transaction and failure behavior

K$ debit, stock or Wing grant, and request receipt are one mutation through the existing account UpdateAsync adapter. Prices and identity are server-owned. Stable client GUIDs reconcile retries and unknown acknowledgements. Duplicate Wing requests, insufficient funds, corrupt/future/deleted accounts, stock/receipt/byte capacity and invalid request identities fail without resetting data. An uncached valid receipt read-back is required before the UI displays PURCHASE SUCCESS / SAVE CONFIRMED. Timeout keeps a retry for the same request.

Refill identity is the server's globally unique OfficialRoundGuid plus item. Reservation debits stock; permanent consumption is confirmed **before** a transient race charge is granted. Charge mutation rechecks authoritative membership/state/slot/guid and records a runtime delivery key. Free lap refills, race end or Reset during I/O cannot grant a second charge. Known non-delivery is compensated once. Expired RESERVED receipts from a different server are reconciled in the Hub after 60 seconds; finalized DELIVERED receipts are never automatically refunded.

**Boundary:** permanent account storage and transient live race state cannot form one cross-store atomic transaction. A server dying after finalized consumption but before the live charge can leave one consumed voucher without a charge. The implementation fails closed at this boundary rather than refunding an uncertain delivery and permitting duplicate usage. Mock tests verify that unknown finalization never grants/refunds, and known failed delivery compensates once. A real forced-crash/live DataStore acceptance test and an approved recovery/support policy remain required before general paid-refill rollout. No exactly-once cross-store guarantee is claimed.

`ShopTransactionsPublicEnabled=false` remains; StoragePublicEnabled and RewardsPublicEnabled also retain their existing false values and existing canary allowlist. Studio production adapters reject live writes. No actual user purchase, account read/write, arbitrary credit/debit or account reset was performed. The user-confirmed **K$805** balance is untouched by this task.

## Validation

| Check | Result |
|---|---|
| Shop mock transactions, timeout, replay, inventory, refund, delivery ordering, safe layout | 126 PASS |
| Existing economy, 10,000 retained receipts | 59 PASS; 2,513,408 JSON bytes |
| Existing economy runtime | 60 + 33 PASS |
| Production RaceItem/Nitro integration | 902 PASS; 1,179 total including NPC cases, plus 273 physical NPC checks |
| Touch / Joystick | 2,908 / 2,418 PASS |
| Race presentation / checkpoint guidance | 6,932 / 1,721 PASS |
| Economy HUD / Wing / Garage | 260 / 211 / 81 PASS |
| Kart visual/orbit and full source Compile | 69,120 corner checks; all 173 Luau sources compile |
| Rojo Build / git diff check | PASS |

The two legacy HUD/VFX harness corrections only update stale test dependencies/expectations to accepted production behavior; they do not change the race HUD or exhaust renderer. Logs are adjacent `*-validation.txt` files. This is a scoped regression run, not a claim that every historical repository harness was rerun.

Studio local PC and iPhone 16 Pro landscape were exercised with the production UI plus **temporary in-memory** server fixture `studio-mock-account.luau`. Actual client button activation confirmed Wing purchase K$3,100→100, Owned, comparison/color selection and Unequip without ownership loss. Separate mobile mock confirmed Nitro K$3,100→3,075 with stock 1 and AUTO REFILL ON saving. Touch scrolling changed actual CanvasPosition and exposed product purchase buttons. Production schema/coordinator and actual RaceLoadout/RaceItemController were exercised under deterministic mocks for slot refill, repeat delivery, inactive/full slots, Rematch and preserved Bonus Nitro.

Safe-area rectangles cover 749×323, 749×381, 932×352, 844×332, 473×240, 473×182, 320×568 and 1920×1022. The actual emulator viewport was 750×402 with a 750×344 CoreUISafeInsets root. Shop touch scrolling is owned only inside its Products list and suppresses purchase activation after a drag. Compact layouts retain 44px buttons and one scrollable safe region without subtracting insets twice. No approved racing-control coordinates were edited.

Evidence: `studio-mobile-shop.mp4`, `studio-mobile-inventory.mp4`, `studio-pc-shop.mp4`, `studio-mobile-wing.jpg`, `studio-mobile-owned.jpg`, `studio-mobile-items-scroll.jpg`, `studio-mobile-inventory-on.jpg`, `studio-pc-final-wing.jpg`, `studio-pc-final-owned.jpg`. Initial PC evidence is also retained. These demonstrate Studio/mock behavior, not published-device acceptance, actual paid ownership, live reconnection or a live multi-server failure test.

## Native candidate and preservation

`KDM_R8_A5_GARAGE_SHOP_NATIVE_CANDIDATE.rbxl` — **686,153 bytes**.

SHA-256: `7b454a9c6a16be6a378f6e134fc04b343bf9133c99fede4ad9d55dcc17c8d3f5`.

Saved by Roblox Studio in Edit mode after stopping Play and removing temporary mock fixtures. Read-only audits confirm:

- **173 exact disk sources**: original 168 plus ShopCatalog, ShopOperations, ShopService, ShopLayout and GarageShopController.
- **1,093 preserved original world/asset entries** relative to the PV680 rollback, including existing tracks/karts.
- **70 identical raw Terrain property groups**, with actual material SharedString content unchanged at 323 bytes.
- No mock account Script or temporary PlayerGui objects in the saved candidate.

`audit-native.luau`, `audit-terrain.py`, `binary-reader.py`, `native-semantic.json` and `native-terrain.json` reproduce the local checks. Lune only deserializes for source/world comparison; its unknown Terrain type warning is covered by the raw binary audit. Native Terrain was never serialized through Lune. Rojo SOURCE_CHECK is a source-only build, not the preserved-world release file.

Native, rollback, media and source-only build are local artifacts, not Git binary additions. Source/report/test files are selectively committed to the development branch. Further acceptance is a user mobile review of this Native candidate and separately authorized live persistence/crash/Robux tests. **No Publish, main integration, general-user K$ rollout or real Robux activation occurred.**
