# KDM icon asset manifest — R6-A / R6-B

Baseline: `3b4ddfd81871cc0c3900cf09feb81ef00dc91c30` / PV345.
Integration branch: `feature/kdm-3d-icon-system`.
`KDMIconCatalog.luau` is the runtime source of truth. This manifest records the
user-provided uploads and acceptance evidence; it does not select gameplay items.

| Semantic key | Asset ID | Role | Version | Runtime status |
|---|---|---|---|---|
| Nitro | 80904195199672 | Item | v1 | ACTIVE / Studio load PASS |
| Shield | 133670688245113 | Item | v1 | ACTIVE / Studio load PASS |
| Slick | 99710951340190 | Item | v1 | ACTIVE / Studio load PASS |
| Missile | 122668047956907 | Item | v1 | ACTIVE / Studio load PASS |
| Thunder | 105188481205755 | Item | v1 | ACTIVE / Studio load PASS |
| Smoke | 117693178629090 | Item | v1 | ACTIVE / Studio load PASS |
| DriftWide | 117761162868097 | Action | v1 | ACTIVE / MOBILE WIRED / Studio load PASS |
| DriftSquare | 124990672172496 | Action | v1 | TUTORIAL / FALLBACK / Studio load PASS |
| Forward | 100127572127049 | Drive | v1 | ACTIVE / MOBILE WIRED / Studio load PASS |
| ForwardLeft | 124319636929371 | Drive | v1 | ACTIVE / MOBILE WIRED / Studio load PASS |
| ForwardRight | 88988885513779 | Drive | v1 | ACTIVE / MOBILE WIRED / Studio load PASS |
| BrakeReverse | 139789194418831 | Drive | v1 | ACTIVE / MOBILE WIRED / Studio load PASS |

## Presentation and fallback

Mobile four-slot HUD only: non-interactive ImageLabel, Fit, full cell bounds,
no additional padding or inner UIScale. Charge overlay remains 18x18 at bottom
right, white GothamBold, navy text stroke transparency .2 and ZIndex above image.
Empty charges dim the image to .55 transparency without dimming the count.
Loaded artwork hides the old procedural symbol and ordinary outer border.
Emergency Shield retains the cyan 3px stroke and existing ! mark. Desktop item
names, selected state and 1/2/3/4 / Q USE behavior remain unchanged. Mobile direct
use still has no persistent selection state.

Six temporary ImageLabels tell ContentProvider to preload image content, in a
spawned task. Pending/failed/missing mappings use the existing native symbols.
A 12-second terminal timeout preserves successful assets and fails remaining
ones. Late callbacks cannot reopen failed states or update a destroyed HUD;
temporary preload objects are released at completion, timeout or destruction.
R6-A preloads Items. R6-B separately preloads the six Action/Drive assets without changing the Item loader.

## Studio evidence (2026-10-04)

One existing KDM Studio instance, Play-only cloned modules, no permanent diagnostic helpers. The connected Rojo session also syncs the
feature files into Studio Edit; this is an unpublished feature preview. Simulator preset 750x361; camera reported 750x341 after the emulator
band, actual mobile HUD slot AbsoluteSize 44x44. All six images returned
AssetFetchStatus.Success and were visibly rendered. Readability PASS for all six
at the existing logical cell size; quantity 0/1/2/9 remains separate and legible.
Slick has more fine detail than the other symbols; no extra padding was added.

Local screenshots (excluded from Git):

- `artifacts/r6a_icons/items_1_2_0_9.jpg`: actual HUD Nitro/Shield/Slick/Missile.
- `artifacts/r6a_icons/all_enabled.jpg`: all four enabled, including Slick.
- `artifacts/r6a_icons/thunder_smoke_emergency.jpg`: actual HUD Thunder/Smoke,
  spent Nitro and incoming Shield emphasis.
- `artifacts/r6a_icons/native_feature_hud.jpg`: fresh Play of the Rojo-synced
  feature controller, no cloned controller or preview modules, same 44px result.
- `artifacts/r6a_icons/state_matrix.jpg`: temporary 44px presentation-only matrix,
  normal/selected-stroke/disabled/emergency-stroke with 1/2/0/9 counts. This is a
  diagnostic view of the production presentation module, not new selection or
  emergency gameplay behavior. Actual emergency activation remains Shield-only.

Preview helpers exist only in Play and are removed by stopping Play. No Publish,
production branch merge or changes to kart appearance/physics/input occurred.
Published/mobile visual acceptance remains the user's next step.

## Validation

48 validation files PASS, including 110 catalog/preload/fallback checks; Touch
2090 and Joystick 1664 checks, including image-backed HUD direct-use and emergency
behavior. Garage exact geometry 52/52 unchanged. Item/HUD/Bot/Drift/Audio/Gauge/
Orbit/V2/Grip regression, Rojo build and git diff --check PASS.

## R6-B four-button feature candidate (2026-10-04)

R6-A is user accepted at `c1d31ed68f3b2f3a8057bb6af5b806a91d8163ef`.
R6-B branch: `feature/kdm-four-button-drive`. Production remains PV345 /
`3b4ddfd81871cc0c3900cf09feb81ef00dc91c30`; no production merge or Publish.

The user approved swapping DriftWide/DriftSquare to match the actual artwork:
117761162868097 is horizontal; 124990672172496 is the compact image. The user
reconfirmed ForwardLeft 124319636929371. It initially failed Studio fetching;
a fresh fetch succeeded and the actual HUD subsequently displayed all five race
control images. Both Drift images also loaded successfully for comparison.

Buttons mode removes AutoForward UI/activation/attribute. Forward, ForwardLeft,
ForwardRight and BrakeReverse output (1,0), (1,-1), (1,1), (-1,0). Brake has
priority; last-held turn wins and releasing it restores the other held turn.
Drift preserves the existing +/-0.60 steering. Pointer movement does not release
an owner; End/Cancel and lifecycle cleanup do. No fractional throttle, artificial
corner speed cap, forced braking, server physics or KartControl protocol changes.
Legacy Joystick math and internal AutoForward remain available for rollback.

The 750x361 Studio preset gives camera size 750x341 and a CoreUISafe control
region 750x283. Drive artwork is 52x52, turn targets 65x65, Forward/Brake targets
62x62, with nonoverlapping gaps. Wide Drift artwork is approximately 116x48,
inside a 140x63 target, Fit without cropping/stretch. Its five-segment gauge is
centered 8px above the target. Press scale is .95 for drive and .97 for Wide Drift.
Portrait and smaller layouts use 44-46px drive artwork.

Studio real touch verified each single button's output; Forward reached 70 and
Brake/Reverse reached -24. The initial local harness bypassed Garage and left the
character's Hub anchor active; removing that Play-only character anchor allowed
normal motion. No source physics, chassis, Seat or geometry correction was made.
A Play-only controller harness supplied two independent model owners for FL/FR +
Drift, since the input tool cannot provide two physical fingers. Actual server
Drift qualified to READY in both directions; releasing Drift while retaining
Forward triggered Mini Boost (observed speed approximately 93 during acceleration).
Physical two-finger behavior and natural corner-entry coast remain real-device
acceptance items. No client/server gameplay code was altered for the harness.

Local captures, excluded from Git, in `artifacts/r6b_controls/`:
`idle.jpg`, `Forward_pressed.jpg`, `ForwardLeft_pressed.jpg`,
`ForwardRight_pressed.jpg`, `BrakeReverse_pressed.jpg`, `Drift_pressed.jpg`,
`ForwardLeft_Drift_harness.jpg`, `ForwardRight_Drift_harness.jpg`, `portrait.jpg`.
The combined captures are explicitly synthetic-owner harness evidence, not
physical two-finger tests. Item/gauge/drive layouts remain separated in these
captures and automated invite bounds checks. All Play-only helpers were removed
by stopping Play; Edit helper inventory returned zero.

Fresh regression: 49 validation files, Buttons Touch 1976, legacy Joystick 1664,
control icon/lifecycle/hitbox 298 checks; geometry fixture 52/52 unchanged.
Item/HUD/Drift/Bot/Audio/Gauge/Garage/Orbit/V2/Grip suites, Rojo and diff check PASS.
Real-device acceptance is still required. No Roblox Publish performed.
