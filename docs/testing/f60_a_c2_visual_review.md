# F60-A-C2 — local visual review (final user follow-up applied)

## 사용자 추가 요청 적용 — latest review

2026-10-20. This section supersedes the initial C2 visual specifications archived below. All work remains local and unstaged: **no commit / push / Publish**. Local and origin HEAD remain `5f9fe3eaec0b8a98abaa137bae54ba3d2e07ffa4`.

### Final appearance and interaction

- GARAGE / TRACKS / SHOP and RACE NOW / TEST DRIVE now have rounded dark **58%-transparent backgrounds** (42% opacity), rather than floating text alone. The surrounding groups remain clear, with no added outer border. All five hit targets remain 44px tall and retain their positions, colors and handlers.
- The three kiosk **floating title/pin BillboardGuis** are always hidden locally. Physical kiosk meshes/screens and floor directions remain functional. The old large RACE / PLAY TOGETHER / START THE FIRST RACE, GARAGE and TRACKS headings no longer cover the arrival view.
- The existing nearby starter-reward helper now also explains all three native HubPrompt actions. It appears only while the corresponding native proximity prompt is shown, and disappears on PromptHidden, walking away, opening a modal, driving, routing or racing.
- GARAGE: **Choose your kart and color.**
- RACE: **Race with players or a rookie bot. Finish races to earn K$.**
- TRACKS: **Preview circuits and choose a track.**
- The explanation uses a compact **190×76**, **82%-transparent** background, with a very faint outline. It appears beside the native E/touch OPEN prompt, or immediately above/below when the side placement would overlap fixed HUD or native joystick/jump artwork. The native prompt's original UIOffset and interaction behavior are preserved. No new overlay captures input.
- Guest kart guidance still shows **EARN K$ 5,000** with the existing 30 moving seconds / 300 studs / once-per-account condition. Qualified accounts receive kiosk descriptions, but never a misleading new starter grant. Rewards, persistence, matchmaking and kart physics were not changed.
- The prior C2 inward-facing showroom karts, profile/records integration, native language settings, touch targets and first/returning visitor rules remain intact.

### Final runtime checks and evidence

Studio Play verified actual approach to GARAGE, RACE and TRACKS, corresponding title/description, hidden floating heading/pin, and helper disappearance on departure with native offsets restored to `(0,0)`. The final approach row was checked against wallet/menu/CTA rectangles at all four requested sizes. No temporary English AutoLocalize override was used for this follow-up; captures reflect the Studio account's Korean locale while source strings remain English.

| Screen preset | Actual safe canvas | Nearby RACE helper origin | Helper size |
|---|---|---|---|
| 844×390 | 749×331 | (304,36) | 190×76 |
| 932×430 | 931×352 | (191,123) | 190×76 |
| 1102×485 | 1101×407 | (694,154) | 190×76 |
| PC 1920×1080 | 1920×1022 | (1142,506) | 190×76 |

The native prompt UI must be verified in native-window captures: MCP viewport captures omit the Roblox E/touch interface. Final evidence is in `artifacts/f60-c2/final-followup/`:

- `arrival-844-native.png`, `arrival-932-native.png`, `arrival-1102-native.png`, `arrival-pc-native.png`: final edge-button backgrounds and unobstructed arrival.
- `arrival-pc.png`: clean desktop viewport preview.
- `garage-near-native.png`, `race-near-native.png`, `tracks-near-native.png`: native E/touch interaction and contextual explanation.
- `pre-followup-local.zip`: entire dirty state backed up before this extra request.

Studio Play was stopped; device/scaling returned to default/FitToWindow; all three temporary follow-up devices were removed. Existing Studio warnings are not claimed resolved.

### Final validation and files

The complete 200-suite regression run again reports **157 PASS / 43 FAIL**. The failing test names are exactly the same 43 documented in initial C2, previously reproduced in the pre-C2 C1 baseline. They remain unresolved; this is not an all-green regression claim. Raw latest logs and exit codes: `artifacts/f60-c2/final-followup/regression/`.

After the last prompt-placement correction, the affected suites were rerun: starter/kiosk lifecycle and obstacle checks **64 PASS**; C2 production-Hub fixture **6435 PASS**; visual fixture **280 PASS**; guidance/Garage fixture **6433 PASS**; race-result HUD **264 PASS**. Both `.rbxlx` and `.rbxl` Rojo review builds and `git diff --check` pass.

Additional source changes in this follow-up: `HubGuidanceView.luau`, `HubUiController.luau` (button backgrounds), `HubWorldGuidanceView.luau` (hide duplicate floating kiosk navigation), `WelcomeRewardController.luau` (shared nearby descriptions and bounded placement). Additional test changes: `f60_c1_visual_layout_validation.luau`, `f60_c2_lobby_layout_validation.luau`, `starter_drive_hint_validation.luau`. This report was updated. All C1 work remains preserved; no server/shared source was modified.

---

## Archived initial C2 review — superseded appearance, retained audit evidence


2026-10-20. No commit, push or Roblox Publish performed. Final visual approval remains pending.

## Baseline and scope

- Branch `prototype/kart-physics`; initial fetch confirmed local and origin HEAD both `5f9fe3eaec0b8a98abaa137bae54ba3d2e07ffa4`. Final HEAD remains identical; index remains empty.
- All C1 local work was backed up before edits in `artifacts/f60-c2/c1-local-baseline.zip` and `c1-baseline.patch`. C2-only changes are separately recorded in `c2-only.patch`.
- C1 EconomyController, PersonalRecordsController and their existing profile/records tests were preserved byte-for-byte (apart from comparing normalized line endings). MY PROFILE and nested MY RECORDS were not changed in C2.

## Product changes

- Both CTA buttons are vertical at every size, with 44px height and a 12px gap. The heading, helper labels and container fill are hidden. Yellow RACE NOW and cyan TEST DRIVE retain their existing callbacks.
- GARAGE / TRACKS / SHOP sit at safe-canvas x=16, y=70/120/170, below the wallet ending at y=58. Their 44px rows have 6px gaps, transparent backgrounds/borders, left-aligned light text and existing pale blue/orange/green native icons.
- Native mobile controls retain their corners: in the 844 preset, menu ends at y=214; joystick artwork begins at y=238. CTA ends at y=219; native jump begins at y=241. These are safe-canvas coordinates, not screenshot pixels.
- Source AutoLocalize settings, first/returning visitor rules, matchmaking, Rookie Bot, AutoStart, Nitro 120, rewards and DataStore code are unchanged by C2.

## Showroom audit

The spawn camera faces +Z, so screen-left is world +X. Front/rear wheel positions were measured using `VisualMotionRole=FrontWheel/RearWheel`; factory front bumper and exhaust placement corroborated the front direction. Before C2 all side karts faced +X. Therefore only **ShowroomBay3/5/7 at X=+30** faced outward. Bay2/4/6 at X=-30 already faced inward.

Only the positive-X static display frame receives a Y-axis half-turn, after this audit. Their nose-to-center dot product is now **0.999993**; opposite-side karts also remain 0.999993. Hero bay is unchanged. No position offsets, color IDs, scale, factory or live physics code were changed.

Seven static exhibits and seven TEST DRIVE prompts remain. Side prompt positions are still `(±30, 2.33, 885/901/917)`, activation range 8; exhibits have no Seats. Bay centers retain 16 studs of longitudinal spacing; reported display bounds are approximately 8.28 by 11.16 studs in plan. The central path and live test-drive spawn are not moved. Actual CTA input still spawned and seated the player in `LobbyFrontTestDriveZone.LobbyKart_11700555357.Seat`; showroom and Hub controls hid during driving.

## Studio evidence

LandscapeSensor; Hub uses CoreUISafeInsets. Actual Play-mode geometry was queried and screenshots inspected at all requested sizes. FitToWindow can round rendered dimensions by one pixel; hardware/home/CoreUI insets reduce the usable canvas.

| Requested screen | Rendered viewport | Safe canvas | CTA origin / size |
|---|---|---|---|
| 844×390, iPhone 13 | 749×389 | 749×331 | (557,111), 180×108 |
| 932×430, custom phone | 931×410 | 931×352 | (739,132), 180×108 |
| 1102×485, custom phone | 1101×465 | 1101×407 | (909,187), 180×108 |
| 1920×1080, desktop | 1920×1080 | 1920×1022 | (1688,894), 220×108 |

Menu rows remain 132×44 on phones and 150×44 on desktop; CTA hit rectangles are 156×44 / 196×44. Safe bounds, wallet clearance, opposing lanes, vertical CTA gap and hidden heading passed runtime assertions. The hero kart and center floor remain visible. Physical screen edges may crop side exhibits as before; HUD adds no opaque covering panel.

Actual mouse input opened GARAGE (HubOverlayOpen=true), TRACKS (TrackPreview visible / TRACK SELECT), and SHOP (KDMShopOpen=true). Hub GUI and CTA hid for each modal. Actual BACK/Close input restored Hub navigation. TEST DRIVE actual input entered a seated live kart and hid showroom/navigation. Automated tests retain the unchanged RACE NOW callback and routing coverage; no published matchmaking or real-device acceptance is claimed.

Studio is configured `ko-kr`. Its automatic translation caused GARAGE/TRACKS text/icon rendering to disappear in the native-language probe. Per the explicit task constraint, no production translation setting was changed to address this. **English review screenshots** temporarily disabled AutoLocalize only on menu descendants in the disposable Play session, then restored every original flag. They demonstrate the English layout, not Korean localization acceptance. Ending Play removed all probe changes. Native-window screenshots include Roblox Core UI; MCP viewport captures omit some native overlays/world signage.

Evidence under `artifacts/f60-c2/`:

- Before: `before-844-topbar.png`, `before-pc.png` (preserved C1 captures).
- Native Korean probe: `after-844-native.png`.
- English layout: `after-844-english-probe.png`, `after-932-english-probe.png`, `after-1102-english-probe.png`, `after-pc-english-probe.png`.
- Native-window English layout: `after-844-native-english-probe.png`, `after-pc-native-english-probe.png`.

Play was stopped, scaling restored to FitToWindow, device reset to default and three temporary custom devices removed. No production server was restarted or published. Existing Studio UIBlox FoundationProvider warnings and asset-type mismatch for `203785492` remained; no clean-console claim is made.

## Validation — not all green

- Entire `tests/*validation.luau` set: **200 suites, 157 PASS / 43 FAIL** (199 initial suites plus the new C2 fixture suite).
- Every one of the 43 failing suites was rerun against an isolated HEAD archive overlaid with the pre-C2 C1 backup: **43/43 also fail there**. Thus no currently failing suite was previously passing in C1. This does not resolve those failures or establish overall regression acceptance.
- Full per-suite exit codes: `artifacts/f60-c2/regression/results.json`; baseline comparison: `baseline-comparison.json`; failure inventory: `FAILURES.md`; complete raw logs for both versions remain alongside them.
- `race_result_hud_validation.luau`: **264 production HUD checks PASS**. Only test contracts changed: obsolete ITEMS READY/WAIT ITEMS/auto-ready notices removed from expectations; approved direct Host Start retained; WAIT REPLY and AUTO START checks retained. The same suite also expected the historical large in-panel Quit button; updated to current 64×40 outlined QUIT beside the LAP panel and 56px short-screen status panel. Production race code was not reverted.
- New C2 fixture suite: **6432 checks PASS**, including the established 6384 Garage/invite/orbit checks plus 48 C2 wallet/menu/CTA layout checks.
- C1 visual fixture with C2 assertions: **280 PASS**; First60 **76 PASS**; guidance fixture **6433 PASS**; normal Garage transition **6384 PASS**. Shop navigation fixture remains FAIL due to its pre-existing missing StyleHelper module injection; actual Studio Shop input passed.
- Two Rojo builds PASS: `C:/dev/KDM_F60A_C2_Review.rbxlx` and `.rbxl`. `git diff --check` PASS.

## Changed files relative to C1

Production: `src/client/HubGuidanceState.luau`, `HubGuidanceView.luau`, `HubUiController.luau` only.

Tests: `tests/first60_hub_entry_validation.luau`, `hub_next_action_guidance_validation.luau`, `economy_v2_shop_navigation_validation.luau`, `race_result_hud_validation.luau`, `f60_c1_visual_layout_validation.luau`, new `f60_c2_lobby_layout_validation.luau`. This report is new. All other dirty files belong to preserved C1 work. No staged changes, commits, pushes or Publish.


## Final F60 follow-up and latest exterior kiosk correction

See [final local review](f60_final_lobby_polish_review.md) for HUB-only lighting, current track-facing/wall-mounted exterior kiosk, actual PC/phone captures, all 43 failure causes, and confirmed receipt replay blocker. No commit/push/Publish; existing local work preserved.
