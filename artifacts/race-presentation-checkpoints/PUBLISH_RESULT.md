# KDM Floating Checkpoint Marker — Publish Result

**PUBLISHED PASS — PV665** on the existing Kart Drift Masters StartPlace.

Experience: `10768420544` · StartPlace: `127925465904803`.

Approved production revision: `705227548802ee0b7172f010c658671bbdef8754`. Local and origin HEAD matched before publishing. Approved Native SHA-256 rechecked: `e337cbae697d7eb1986290a8b546aadecb876fe73fead6b1db10c7792082ec8e`, 674,842 bytes.

## Publish evidence

One Publish As request selected the existing KDM Experience/StartPlace. The user completed Studio's asset-permission prompt once; no retry or duplicate Publish was issued. [Publish log](floating-publish-log.txt) records target Universe/Place IDs, `PublishSuccessful` at **2026-10-14 08:47:55.197 UTC**, and subsequent version check **665**. The local Native success label initially reports placeId 0; the target log and reopened cloud DataModel confirm the actual existing StartPlace.

[Version history screenshot](floating-pv665-published-history.png) shows **v665 — 게시됨**, **v663 — 이전에 게시됨**. v664 is a pre-existing unpublished version at 13:03; it was not an additional Publish from this operation. Newly reopened cloud DataModel reports PlaceId `127925465904803`, GameId `10768420544`, PlaceVersion **665** and 168 source containers.

From v665's version-history menu, opened its local copy. [Download screenshot](floating-pv665-local-copy.png) records DataModel loading `https://assetdelivery.roblox.com/v1/asset/?id=127925465904803&version=665`. Saved that downloaded version with Studio native Save As, without editing or running it.

## Published Native comparison

File: `C:/dev/RobloxKart/artifacts/race-presentation-checkpoints/KDM_PUBLISHED_PV665_VERIFIED.rbxl`.

SHA-256: `5a27872ebd14285d698575e6b81844f814aad007b1e6f43d6180ef15456100c3` — 674,845 bytes.

PASS: [Source/world audit](floating-published-semantic.json) verifies all **168 Sources** exactly match approved repository source after CRLF normalization and all **1,093 world/asset entries** match approved Native, excluding editor Camera. No extra test/import scripts persisted. [Raw Terrain audit](floating-published-terrain.json) verifies all **70 Terrain groups**, including actual Materials content, are preserved. Native binary hashes differ after Studio serialization; source/world/Terrain equivalence was verified rather than assuming whole-file byte equality. No Lune serialization was used.

## PV663 rollback preservation

Pre-publish edit backup was retained and hash-checked: `KDM_PV663_EDIT_BACKUP_NATIVE.rbxl`, SHA-256 `14538e15d976b9cf70bbf5115c4ab08b2df360f52deeefb0b55f3e0b730f1949`.

Also downloaded **actual historical PV663** from version history after publishing and saved it separately, without restoring/publishing it:

`C:/dev/RobloxKart/artifacts/race-presentation-checkpoints/KDM_PUBLISHED_PV663_ROLLBACK_VERIFIED.rbxl`.

SHA-256: `408a38b5f78c347c3010573e10ecb952a6c9747ccffc348a5323b6bb43f196e5` — 673,683 bytes. [Source/world comparison](pv663-rollback-semantic.json): 168 prior Sources and 1,093 world/asset entries preserved; [Terrain comparison](pv663-rollback-terrain.json): 70 groups preserved. [Download evidence](pv663-rollback-download.png) shows actual version=663 URL. Prior Native/AutoRecovery/PV655 rollback backups remain intact.

## Scope and remaining user acceptance

No production code, mobile HUD/keypad/Safe Area, physics, Boost/Nitro, kart/Wing, records or economy changes were made during publishing. No Play test, DataStore initialization, record/K$ reset, main integration or new Experience creation was performed. Report/audit evidence only; published production source remains the approved revision above.

User will now verify the floating checkpoint sign on actual mobile: CP1–6 → FINISH, airborne text/pin between flags, approach/near fade and kart clearance. This final mobile visual acceptance remains pending; publication and preservation verification are complete.
