# KDM R6-A icon asset manifest

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
| DriftWide | 124990672172496 | Action | v1 | REGISTERED / NOT WIRED |
| DriftSquare | 117761162868097 | Action | v1 | REGISTERED / NOT WIRED |
| Forward | 100127572127049 | Drive | v1 | REGISTERED / R6-B PENDING |
| ForwardLeft | 124319636929371 | Drive | v1 | REGISTERED / R6-B PENDING |
| ForwardRight | 88988885513779 | Drive | v1 | REGISTERED / R6-B PENDING |
| BrakeReverse | 139789194418831 | Drive | v1 | REGISTERED / R6-B PENDING |

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
Only Items preload; registered Action/Drive assets have no input/UI wiring.

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
