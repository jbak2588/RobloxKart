# Disabled Robux integration / future receipt plan

No pass or product was created. `EconomyConfig.GamePassId=0`, `GamePassEnabled=false` and `ShopTransactionsPublicEnabled=false` remain. Storage/reward public flags also remain false. Current public release stays PV680.

## Wing pass, after separate activation approval

In Creator Hub select the **existing** Kart Drift Masters Experience `10768420544`, Monetization → Passes. Create/configure its Wing pass, set the global target price to **50 Robux**, and record the real pass ID. Replace only `GamePassId` with that verified ID; enable it only after a separate approval and permission/ownership test. Do not create a new Experience. Keep general K$ shop rollout independently gated.

The client uses `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.GamePass)` to display the current player's personalized/regional `PriceInRobux`. The 50 Robux text while disabled is a planned target, not a quote. Roblox's purchase prompt provides the final price. The server checks sale availability before a prompt and independently calls `UserOwnsGamePassAsync`; the purchase-finished event alone is not ownership evidence. Owned passes can be reconciled even when a pass is no longer for sale. A verified pass and a cash purchase grant the same `KDM_V2_WING` entitlement; seven V2 colors do not create seven products.

Reference: [Regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing), [Passes](https://create.roblox.com/docs/production/monetization/passes).

## Developer Product item packs — design only

No Developer Product IDs, purchase prompts or `ProcessReceipt` binding are activated in this candidate. A future server-owned product catalog must map verified ProductId → fixed item quantities. Never accept a client price, item list, quantity or claimed payment.

The single future `ProcessReceipt` owner should:

1. Resolve PlayerId to the same existing account key, and allow only known products belonging to this Experience.
2. Use a durable receipt key based on Roblox `PurchaseId`; atomically append the receipt and add inventory inside the same `UpdateAsync` callback. Callback replay checks the stored identity/signature and returns the unchanged profile for the same receipt.
3. Perform an uncached receipt read-back before returning `PurchaseGranted`. Unknown writes, budgets, absent players, corrupt/future/deleted profiles or read failures return `NotProcessedYet`, with no client success claim.
4. Reconcile reconnect/server retries from that receipt. Never use `PromptProductPurchaseFinished` as fulfillment proof or overwrite another receipt handler.
5. Apply stock/byte/receipt capacity rules without deleting prior records or receipts. Paid packs need a separately approved overflow policy; do not acknowledge a paid receipt whose inventory could not be durably granted.

The current K$ store's optional `shopInventory` field, pure `ShopOperations`, existing account adapter and read-back coordinator are the foundation. Actual product creation, catalog IDs, handler registration, live payment tests and rollout require a separate task.

Reference: [Developer Products](https://create.roblox.com/docs/production/monetization/developer-products), [MarketplaceService receipt contract](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService).
