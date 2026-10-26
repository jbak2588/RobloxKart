# Color-specific permanent kart shop — 2026-10-26

Owner scope: replace the single all-color Wing sale with seven permanent KDM V2 karts, one color per K$25,000 purchase. Existing Wing buyers keep all seven colors. Wingless karts remain free rentals. Purchased-item race use and automatic consumption are deferred. No Publish authorization was requested for this shop change.

## Implementation

- Server catalog recognizes exactly Kart05–Kart11. New entitlements use `cosmetics.ownedPartIds.KDM_V2_KART_<KartId>` in the existing account. Historical `KDM_V2_WING` remains a grandfathered entitlement to the seven V2 colors, never Sprint V1. No destructive migration or separate account store.
- BUY_KART atomically debits the authoritative price, grants only that color, and persists its default selection. USE_KART selects an owned color without payment. Both use existing server-issued tickets, immutable signed receipts, read-back confirmation, and retry identity. Duplicates and unowned selection fail closed.
- Confirmed Shop selections update the progression session CAS revision and cancel stale queued selection callbacks. A late initial profile read cannot replace the confirmed purchase revision. Existing race/route selection guards remain.
- Server-owned color attributes determine wings for the actual driving kart, including temporary Park showroom rentals. The Garage preview uses its previewed color's ownership. Manual server network ownership and seating lifecycle are unchanged.
- BUY KARTS provides seven actual-model cards plus the selected wing-equipped rotating preview. Mouse/touch horizontal orbit follows the Garage camera behavior; idle rotation stops with the shop/preview lifecycle. Garage BUY KARTS opens this collection and returns to the existing Garage context.
- MY INVENTORY contains owned karts and stored items. Very short safe canvases switch inventory sections by tapping its active tab. Removed the automatic consumption toggle and disabled the race refill scheduler/consumer; existing stock and old reservation compensation remain intact.
- Both Shop and legacy Economy public remotes reject the old Wing sale/equip and auto-refill activation. Legacy pure receipt reducers remain for historical records/recovery.
- Authoritative item prices: Nitro 5000; Missile 4000; Thunder 3500; Shield, Slick, Smoke 2500 K$. Free lap refills and repeatable Nitro rewards are unchanged.

## Validation

- Shop operations / inventory / recovery / preserved fields / color-specific ownership / migration / pricing: 188 checks PASS.
- Progression runtime: 18 scenarios / 85 checks PASS, including queued selection and delayed-load races against confirmed purchases.
- Shop UI fixture: 111 checks PASS; Shop navigation fixture: 126 Shop checks plus 6411 Garage transition/layout/invite/orbit checks PASS.
- Driver card 95; orbit-safe visual geometry 389; Wing geometry 211; Garage binding 16; six-slot loadout 28; Garage display 15; mobile input 1188; progression mock 640 checks PASS.
- Race items and network ownership regression suites PASS (includes 25 deferred ownership lifecycle checks). Test fixtures now load the production color-ownership catalog.
- All 230 production Luau sources compile. Rojo build and `git diff --check` PASS.
- Existing `r8_a4_economy_validation.luau` fails at line 49, `ineligible zero`. The test and all its loaded dependencies (schema, KartCatalog, RaceRecordOperations, EconomyOperations, EconomyPolicy, EconomyConfig) are unchanged by this task. This unrelated baseline failure is not claimed fixed.

## Ordinary Studio client evidence

Production IDs, HUB, Park enabled. Studio account adapter only; no live money/DataStore writes. Ordinary LocalScripts seeded a temporary in-memory K$300,000 account and exercised the real remotes.

- Red purchase through the ticketed remote: K$300,000 -> 275,000; only Red owned; selected Kart06 and Wing equipped; Cyan remains unowned.
- Black purchase through visible product card, BUY and confirmation UI: K$275,000 -> 250,000; PURCHASE COMPLETE; Kart11 selected, Red and Black owned, Cyan unowned.
- Seven factory model cards, scrolling, purchase confirmation, owned Red viewport and separate stored-item inventory observed on the 750x332 device-safe canvas. No AUTO REFILL toggle; stored-only text displayed.
- Old endpoints: Shop BUY_WING / SET_AUTO_REFILL -> INVALID_OPERATION; Economy BUY_WING -> UNAVAILABLE.
- Ordinary test drive of owned Black: actual Kart11 has its wing and remains manually server-owned.
- Temporary unowned Cyan rental: actual Kart05 has no wing, keeps manual server ownership, and preserves the purchased Kart11 default selection.

Studio captures and deterministic tests do not establish live DataStore rejoin, physical mobile heat/FPS, or hardware multitouch acceptance. Temporary QA scripts and memory accounts are removed by stopping Play; production sources retain normal server/client startup. No Publish performed.
