# Robux K$ top-ups — 2026-10-30

Owner requests50/100 Robux top-ups and explicitly confirms50 -> K$25,000,
100 -> K$60,000. Baselineb42d7ec29faa7a876eabeae858c6e9ea4299d56f,
local/remote identical and clean after fetch, prototype/kart-physics.
Continuing owner release workflow: scoped commit/push and exact official Publish
Universe10768420544 / Place127925465904803, no restart.

Developer products created in the official Creator Dashboard:
3723936705 K$25,000, fixed50 Robux;3723937538 K$60,000, fixed100 Robux.
Managed pricing disabled for both, no icon upload. Initially off sale until
receipt handler publication; activate only after official Publish. No actual
Robux purchase, charge, real account grant, credential or security-setting change.

Wallet + opens GET K$; Shop + K$ opens the same modal above the existing Shop.
Two44px buttons, native safe-area bounds, live client product prices, balance,
close/cancel and receipt-wait messaging. Native Roblox payment approval is the
only purchase confirmation. No grant from prompt-finished; only server saved
wallet attributes update balance. No buying while driving, launching, in races
or behind incompatible overlays. Hub/Shop navigation and mobile driving retained.
Studio shows preview with purchases disabled, no live credit.

Server owns a fixed SKU/ProductId/amount allowlist. Guarded PROMPT RPC accepts
only a SKU, rejects arbitrary amount or extra fields, checks eligibility, account,
capacity and current product metadata. A read-only credit preflight blocks known
capacity failures. LIST never writes an account. ProcessReceipt is registered
once at all server startup, so legitimate delayed receipts can settle in reserved
race jobs through existing initialize storage policy. Exact production pair only;
unknown products, absent players, wrong environment and failed stores defer.

Cash credit and SHA256 purchase identity marker are one UpdateAsync on the
existing KDM_PlayerProgress_v1 user key. Confirm with uncached read-back before
PurchaseGranted. Unknown ACK/retry/concurrent server callbacks derive from latest
persisted state; never grant twice. Permanent robuxTopUps map deliberately lives
outside expiring gameplay receipts and is strictly optionally validated by the
existing v1 schema. No age-based pruning of purchase identities. Guest creation
starts default0 plus exact paid amount, no starter/activity/first-finish grant.
Deleted/corrupt/future accounts are not reset or resurrected. Overflow/capacity
never truncates a paid amount; receipt remains pending if it cannot be saved.
LifetimeEarned/rankings, all historical account fields/receipts, rewards, ownership,
selection, item stock/use flag, physics and driving controls remain unchanged.

Validation:81 pure receipt/unknown-ACK/permanent500-day replay/guest/preservation
checks;18 actual runtime service/remote/receipt/late-race scope checks;219 actual
client UI/safe-area/cancel/no-local-credit/lifecycle checks. Studio ordinary wallet
+ and Shop + K$ both open the new UI; runtime stack40 over Shop35 verified. Labels
50/100 and25,000/60,000 correct, balance0 unchanged, Studio buttons disabled.
Native client/server startup has no new errors; only existing preference API
warning. No paid real-user transaction acceptance claimed. Play stopped, all
QA state discarded. Release integrity859 checks and independent Python audit
PASS, all earlier manifest fields and historical N1/N2 fixtures preserved.
Official docs: https://create.roblox.com/docs/production/monetization/developer-products


Full regression:259 total /239PASS /same20 historicalFAIL /0 newFAIL.
NOT FULL_SUITE_PASS. Logs:kdm-hub-ui-20261030-wtz09r61 under CreatorTemp.
Routing mock updated for the new ordinary server startup service; no assertion
removed. Full suite includes existing mobile, shop, storage and race regressions.
Rojo build/diff check PASS.

Native full Place backup:C:/Users/OWNER/AppData/Local/Temp/KDM-official-robux-topups-20261030.rbxl
SHA256bd8901efb9c6987cdf1cde5e5473cee9329e6fbb044aaaea66fbefba25e253fd.
237/237 sources match repository, all3 release flags true. Preserve binary Terrain
content; Publish native scene, never a reserialized backup. Production metadata
GetDeveloperProductsAsync lists both configured IDs within this experience.
Publication/sale activation receipt follows after deployment.
