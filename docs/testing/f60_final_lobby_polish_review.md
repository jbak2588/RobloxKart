# F60 Final Lobby Polish — local review, 2026-10-20

Status: visual implementation complete locally; **NOT an all-green acceptance**. Commit/Push blocked by the user's explicit condition to stop on a major unresolved regression. Roblox Publish was neither attempted nor performed.

## Git and scope

Fetched origin before resuming. Branch `prototype/kart-physics`; local and origin HEAD both `5f9fe3eaec0b8a98abaa137bae54ba3d2e07ffa4`. No new commit SHA. Nothing staged, committed, pushed or published. C1/C2 dirty work preserved; pre-final backup is `artifacts/f60-final/pre-final-local.zip`. EconomyController and PersonalRecordsController are byte-identical to that backup. Unrelated editor settings were not staged.

This final polish changes `src/server/CompactHubBuilder.luau` (HUB fixtures), `src/client/HubUiController.luau` (exterior kiosk), `src/client/WelcomeRewardController.luau` (helper contrast), and the corresponding contrast expectation in `tests/starter_drive_hint_validation.luau`. All earlier dirty C1/C2 files remain. Full file inventory: `artifacts/f60-final/changed-files.txt` and `git status --short`.

## Exterior Test Drive kiosk — latest user correction included

Reused yellow script-free stand, without a new Cyan kart. Actual screen front was checked from the track side, rather than inferred only from pivot axes. Removed the earlier extra 180-degree rotation so the illuminated screen faces the test-drive area (-world Z). Moved from (8, 3.1664, 858.5) to **(4.65, 3.1664, 861.9)**, between exterior bollards at X approximately 1.40 and 7.91. Rear edge is approximately 0.16 studs outside the wall face. Removed the entire black TEST DRIVE plaque and its SurfaceGui.

Final actual capture: `artifacts/f60-final/entry-kiosk.png`. The kiosk is anchored, noncolliding/non-touching/non-querying with no Seat, scripts or extra ProximityPrompt. Original LobbyFrontDriveEntry and its prompt/handler remain. The central/right portion of the entrance remains clear. Actual TEST DRIVE CTA input after the final source restart seated the player in `Workspace.KDMHub.LobbyFrontTestDriveZone.LobbyKart_11700555357.Seat`. A synthetic E-key attempt under phone emulation did not establish native prompt activation, so that specific interaction is not claimed PASS.

## HUB-only lighting

| Fixture | Before | After |
|---|---|---|
| Existing 3 showroom PointLights | Brightness 1 / Range 30 / Shadows false | Brightness .25 / Range 50 / Shadows false |
| Doorway fill | None | 2 lights, Brightness .25 / Range 30 / Shadows false |
| Doorway positions | None | Local (-29,10,-22), (-29,10,22), world approximately (+/-22,10.25,871) |
| Global Lighting | Ambient (0,0,0), OutdoorAmbient (.5,.5,.5), Brightness 2, Exposure 0 | Unchanged |

Imported shell lights were not changed. Only two new shadowless lights added. Existing HUB role guard prevents RACE construction; `compact_hub_validation` passes including RACE builds-nothing assertion. No global Lighting configuration, track environment, physics, input, reward or storage source changed by this final polish. Nitro 120 source remains unchanged.

Before/after captures use the same forced runtime camera for each pair, with original/final local fixture values toggled. The final source was restarted and runtime light values checked again. All captures are in `artifacts/f60-final/`: `before-entrance.png` / `after-entrance.png`, `before-left.png` / `after-left.png`, `before-right.png` / `after-right.png`.

Mean Rec.709 screenshot luminance in fixed ROIs (8-bit image values, not physical light measurements): entrance 71.67 -> 125.76, left dark area 31.42 -> 83.18, right 90.39 -> 116.61. ROI coordinates in `brightness-comparison.json`. Corners/doorway are visibly lifted, color differentiation and shadows remain. Mobile GPU cost was not measured on a physical device; two shadowless fills are not a 60 FPS guarantee.

## UI and actual screen review

Preserved wallet + three left menus, two right CTAs, translucent fills, profile in upper-right native-safe band, records inside profile, admin restriction, inward-facing exhibits and empty central showroom. Context hint BackgroundTransparency .82 -> .70, without changing reward logic. Production text stays English; Studio ko-kr localization explains Korean menu/floor labels in captures. Translation system unchanged.

Actual final live captures:

- `artifacts/f60-final/pc-1920.png`: PC 1920x1080.
- `artifacts/f60-final/mobile-844.png`: iPhone 13 844x390 preset (notch-safe camera viewport about 750x390).
- `artifacts/f60-final/mobile-932.png`: phone 932x430 custom preset.
- `artifacts/f60-final/mobile-1102.png`: phone 1102x485 custom preset.

Studio/Windows scaling affects encoded screenshot pixel dimensions; these names identify simulator device configuration, not a claim that encoded image dimensions equal device dimensions. Left/right groups remain readable with no overlap with native joystick/jump; center showroom remains visible. Interactive targets retain 44px minimum. Phone presets are Studio emulation, not real-device acceptance. Game orientation is LandscapeSensor. Existing safe-area structure remains; no translation edits.

Actual mouse input earlier in this final review opened GARAGE, TRACKS, SHOP and MY PROFILE and restored navigation on closing. Actual TEST DRIVE CTA seating passed again after latest kiosk source restart. RACE NOW emitted F60_MATCHMAKING_STARTED / QuickStart, but allocator returned HTTP 403 in Studio; full public-server transfer is **NOT VERIFIED**. Rookie Bot / AutoStart, race items, mobile controls and Nitro contracts retain passing relevant automated suites; no new published-human test claim.

Studio Play stopped, capture camera lifetime ended, scaling restored to FitToWindow, simulator reset to default. Only F60FinalPC/932/1102 temporary custom devices removed; unrelated user presets preserved. No production server restart.

## Validation and 43 failures

Final post-correction full rerun: **200 suites: 157 PASS / 43 FAIL**. Same failing suite set as the preserved pre-final C1/C2 checkpoint; all 43 had also been reproduced against isolated C1. This proves provenance only, not correctness. Complete final exits/timings/logs: `artifacts/f60-final/regression/`. Every failure has a separate cause/disposition row in `artifacts/f60-final/failure-audit.md`.

Categories include historical exact-source/catalog freezes, superseded four-item/item-prep/onboarding contracts, incomplete Shop/art resource fixtures, disabled diagnostic expectations, and unresolved VFX/save-status/access-policy checks. No failing test was hidden, changed to unconditional PASS or dismissed solely because it was pre-existing. VFX residual particles, practice Shield/skid visibility and save/access-policy discrepancies remain review items.

`f60_c2_lobby_layout_validation` 6435 checks PASS; contextual starter guidance 64 checks PASS. `race_result_hud_validation` 264 checks PASS with the existing approved six-item/no-prep contract. All 200-suite detail is in results.json, including failures.

Rojo XML and binary builds PASS: `C:/dev/KDM_F60_Final_Review.rbxlx` and `.rbxl`. `git diff --check` PASS. Temporary builds/captures/probes remain excluded from Git staging.

## Confirmed major blocker: reward replay receipt retention

`src/shared/KDMProgressionSchema.luau:386`, `pruneAndCompressReceipts`, deletes **all other receipts** when maxReceipts >= 1000 (default 16384), rather than retaining older idempotency receipts. A later race/purchase can therefore erase an earlier operation's deduplication record.

Independent offline probe uses the production RaceRecordOperations reducer: race A produces cash 30,000; race B 33,500; retrying A produces **37,000, status APPLIED**. Expected REPLAY with unchanged 33,500 fails, exit 1. No production accounts/DataStores were modified by the probe. Artifacts: `duplicate-reward-probe.luau` and `duplicate-reward-probe.log`. Existing `r8_a3b_full_race_validation` and `r8_a6_b_canary_grant_validation` expose this same receipt-retention defect.

This is a real pre-existing production issue, not an obsolete UI string. Persistence code was kept outside this Lobby-only scope. Per the user's explicit condition, **do not commit or push this candidate until the major issue is separately fixed/verified or the user changes that condition**. Publish remains prohibited.
