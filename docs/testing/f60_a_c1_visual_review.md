# F60-A-C1 local visual review - 2026-10-20

## Baseline / delivery status

Starting local and fetched origin/prototype/kart-physics HEAD both equal
`5f9fe3eaec0b8a98abaa137bae54ba3d2e07ffa4`. Working tree was clean.
No rollback to ec573ed, branch switch, reset, merge or rebase was performed.
Changes remain local and unstaged for the user's visual review. No commit, push
or Roblox Publish was performed for C1. User visual acceptance is pending.

## Presentation changes

| Area | Baseline | Local C1 |
| --- | --- | --- |
| CTA card BackgroundTransparency | .35 | .92 (8% opacity) |
| RACE NOW button background | .25 transparency + border | 1, no border |
| TEST DRIVE button background | .35 transparency + border | 1, no border |
| Shortcuts panel / buttons | .35 / .35, separate borders | 1 / 1, borders removed |
| Desktop first-entry card | 280 x 208 | 280 x 128 |
| Phone CTA | Compact only below 400 safe pixels | Compact below 500 safe pixels |

The initial baseline render was inspected before editing. Buttons no longer add
an opaque layer on top of their parent panel. RACE NOW retains yellow
(255,215,50), TEST DRIVE cyan (111,211,245), and both use GothamBold without a
text stroke. All CTA hit targets have at least 44px height. The state presentation
now returns exactly TEST DRIVE, never FREE TEST DRIVE. Existing instance names
remain compatible with their consumers.

YOUR KART IS READY remains subordinate to the action text. Extra brand/helper
copy is hidden. Phone actions are side by side; desktop actions use two rows
with 20px / 18px text. Returning desktop compact actions retain 18px / 16px text.
Shortcuts keep white/light-gray icons and captions, 44px targets and fixed gaps;
desktop captions are 15px, phone captions 13px. Existing actions/routes are kept.

## Profile / Records

The profile modal still uses CoreUISafeInsets. A separate KDMProfileHeader GUI
uses DeviceSafeInsets for its transparent 104 x 44 header button. Its position is
computed from GuiService.TopbarInset and GetGuiInset(), accounting for the CoreUI
coordinate origin used by AbsolutePosition. With the observed 58px TopBar, the
header local Y is 7, and its center is 29px, matching the native menu row. At the
844 preset the device-safe canvas width is 750, button local right edge is 738
and AbsolutePosition is (634,-51); adding the native core inset gives screen Y=7.
At 1920 desktop the right edge is 1908 and left edge 1804. Notch-safe horizontal
space and right padding are retained. Topbar/size changes update this layout
through events, with header listeners and GUI disposed when the modal GUI dies.

The independent MY RECORDS TopBar GUI is removed. Only the existing canary admin
11700555357 receives a MY RECORDS action in the profile footer, beside CLOSE.
The records controller mounts once, issues no automatic read, retains its existing
4-second query cooldown, error formatting, scrolling and server remote. Closing
Records returns to the profile; closing the profile hides Records. General users
receive no records action or read request. No server authorization was changed.
Caption labels are separate from gradient buttons to keep white text readable.

Live Studio interaction opened the profile and Records, and closed both correctly.
Studio API restrictions return RECORDS: ERROR / READ_UNAVAILABLE; this is recorded
as the existing unavailable-read path, not a successful operating DataStore read.
Mocked records tests cover response rendering, long-text scroll and access gating.

## Render evidence

Artifacts under `C:/dev/RobloxKart/artifacts/f60-c1/`:

- mobile-844-topbar.png: native Studio game viewport cropped from the full native
  capture; includes Roblox's actual menu icons and the aligned MY PROFILE.
- mobile-844.png: 844 x 390 iPhone 13 preset render (750 x 390 runtime camera,
  750 x 332 CoreUI canvas after device/core insets).
- mobile-932.png: custom 932 x 430 phone simulator render (932 x 410 runtime
  camera, 932 x 352 CoreUI canvas in ActualResolution mode).
- mobile-1102.png: custom 1102 x 485 phone simulator render (1102 x 465 runtime
  camera, 1102 x 407 CoreUI canvas in ActualResolution mode).
- pc-1920.png: actual 1920 x 1080 desktop simulator render; action text and full
  right-side menu remain readable at native resolution.
- profile-records-entry.png and records-error.png: profile entry and unavailable
  read presentation; native clicks were used, not simulated server records.

Additional FitToWindow captures are scaled by Studio, not pixel-for-pixel hardware
screenshots. ActualResolution phone captures showed a simulator-only left-side
shading artifact absent from native/FitToWindow evidence, so the final mobile
review captures use the latter. UI bounds were also checked numerically. Camera
remains at the initial showroom spawn for each fresh Play session.

Studio renders were inspected for CTA/shortcut overlap, clipping, central avatar
visibility, top-row alignment and the absence of the separate Records button.
The three phone presets and desktop presentation are ready for visual review.
This does not claim published mobile hardware acceptance or a fresh race load test.

## Executed tests

| Test | Result |
| --- | --- |
| first60_hub_entry_validation | PASS (76) |
| hub_next_action_guidance_validation | PASS (256 + 6433) |
| lobby_post_drive_view_validation | PASS (33) |
| mobile_touch_validation | PASS (1430, mocked input) |
| two_player_race_validation | PASS (105) |
| four_player_race_validation | PASS (47) |
| race_result_hud_validation | FAIL at line 238 |
| economy_v2_driver_card_validation | PASS (100) |
| r8_a3b_records_scroll_validation | PASS (8) |
| r8_a3_personal_records_view_validation | PASS (12) |
| profile_records_integration_validation | PASS (10) |
| f60_c1_visual_layout_validation | PASS (250) |
| global_race_matchmaking_validation | PASS (68) |
| repeatable_nitro_validation | PASS (59) |

The result-HUD test still expects `ITEMS READY 2/2` in the host lobby and later
checks the historical item-ready start gate. That test and production RaceHudController
are unchanged by C1. This expectation predates the user-approved no-item-prep flow.
It is explicitly NOT counted as PASS, and unrelated race behavior was not changed
to satisfy it. Full command output is in artifacts/f60-c1/test-results.json.

Older Records fixtures were updated to provide the already-required style helper
and expect the existing readable track/category title. The profile fixture now
models separate header/modal GUIs. The guidance fixture expects the intentionally
minimal presentation. New tests exercise header coordinates, all visitor guidance
states, 44px hit areas, callbacks, Records access/cooldown and duplicate mounts.

`git diff --check`: PASS. Both requested builds: PASS:
`C:/dev/KDM_F60A_C1_Review.rbxlx` and `C:/dev/KDM_F60A_C1_Review.rbxl`.
These are review builds, not files uploaded to Roblox.

## Preserved scope / dirty files

Both performance diagnostic startup flags remain false. The performance acceptance
document is unchanged. Nitro 120 in KDMGameplayBalance, physics/input/network,
DataStores, visitor qualification, restore, starter/first-race rewards and matching
server code are unchanged. No new capacity acceptance or next project is inferred.

Modified production files:
src/client/{HubGuidanceView,HubGuidanceState,HubUiController,EconomyController,
PersonalRecordsController}.luau.

Modified tests: first60_hub_entry_validation, hub_next_action_guidance_validation,
economy_v2_driver_card_validation, r8_a3_personal_records_view_validation,
r8_a3b_records_scroll_validation. New tests: f60_c1_visual_layout_validation,
profile_records_integration_validation. This review document is also new.
All are intentionally dirty/unstaged. Ignored screenshots and review artifacts
remain local. Await the user's visual approval before any Git checkpoint or Publish.
