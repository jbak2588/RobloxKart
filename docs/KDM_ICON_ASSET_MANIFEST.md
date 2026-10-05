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
| AutoStart | 132977729157200 | Action | v1 | ACTIVE / BUTTONS WIRED / Studio load PASS |
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

## R6-B1 mobile control UX candidate (2026-10-05)

R6-B code passed but user real-device UX acceptance FAILED. This revision
supersedes R6-B's Auto removal, small controls and shrinking pressed animation.
Starting feature HEAD: `c8d5d60b4ed8cde9e0b064aa1c8d6e0fa7f79046`.
Continue `feature/kdm-four-button-drive`; no production merge or Publish.

AutoStart 132977729157200 loaded successfully. Buttons restore continuous Auto
throttle 1, toggle OFF/ON, turn acceleration, Brake -1 priority and release resume.
Focus/seat/menu/race teardown/locks clear Auto through the existing reset path.
The four manual outputs and +/-0.60 Drift remain unchanged. Joystick math is unchanged.

Normal safe height >=340: drive 68x68, target 82x82, Auto 58x58 / 64x64.
Short layout: drive 62x62 / 74x74, Auto 52x52 / 58x58. The existing 750x361
emulator reported 751x282 CoreUISafe, so it uses this short configuration.
The Auto target is exactly at the four primary target centers' midpoint.
Horizontal center spacing is 86 normal / 78 short, necessary to prevent square
hitbox corner overlap with a 4px gap; cluster width is 254 normal / 230 short.
Vertical spacing is 77 / 70, cluster height 236 / 214. On the exceptional
473x240 landscape only, 58px art / 70px target fits the physical bounds; it does
not fall back to 52px. Portrait has its own safe arrangement.

Wide Drift matches the four Item slot widths: 200x83.33 short, 216x90 normal.
Targets are 221x95 and 238x103 respectively; the exceptionally tiny 473x240
viewport uses a tighter vertical target. Artwork remains Fit, no stretching.
Gauge width is 65 percent of artwork width; charging/READY/fade behavior unchanged.
Idle and pressed UIScale are always 1.00. Held artwork brightens slightly; Auto ON
adds a small green state light. Loaded art has no additional circular frame.

Necessary collision adjustments: on very short landscape safe areas the unchanged
44px Item slots and Nitro row move beside LAP rather than overlap it. Incoming item
warning moves to the top of that safe region. Item assets, slot sizes, selection,
quantity, direct-use, emergency Shield and fallback are unchanged. Passive V2
RPM/speed gauge scales to the space beside the enlarged Drift, preserving its
aspect, typography, speed/RPM mapping and bottom alignment. The already optional
legacy steering display is hidden only on landscape widths below 600 where it
cannot fit beside the wide Drift. Development diagnostic bounds adapt separately.
Invite button/list use free space between LAP, items, minimap and individual pad
hitboxes. Empty corners of the plus cluster are not touch targets.

Actual emulator touch verified manual controls, Auto ON, Auto+turn, Brake/Reverse
-24 and Brake release Auto resume (throttle 1, observed approximately 63 during
acceleration). Play-only synthetic independent owner tests drove the actual
server to gold READY in both directions and real Mini Boost on release (observed
approximately 90 and 100 planar/total speed during acceleration). Synthetic-owner
screenshots are not physical two-finger tests. No force cap, forced braking,
server/controller/physics/audio/Seat/kart geometry changes were made.

Fresh captures are excluded under `artifacts/r6b1_controls/`: idle, Auto_OFF,
Auto_ON, Forward, ForwardLeft, ForwardRight, BrakeReverse, Drift,
Auto_ForwardLeft, Auto_ForwardRight, ForwardLeft_Drift_harness,
ForwardRight_Drift_harness (.jpg). HUD diagnostic overlay was removed only in
Play for clean screenshots. Stopping Play removed all admission/controller helpers;
Edit helper inventory returned zero. No second Studio was launched.

Validation: full 49/49; Touch 2319; legacy Joystick 1932; control icon 432;
geometry 52/52 unchanged; Item/Drift/Mini Boost/Bot/HUD/Results/Finish/Garage/
Orbit/V2/Grip/Audio/Gauge suites, Rojo and diff check PASS.
User real-device UX acceptance remains required, particularly thumb travel,
Auto readability and the short-screen Item lane adjustment. Production PV345
and accepted R6-A branch remain frozen. Roblox Publish: NO.

## KDM CONTROL ICON SYSTEM v2 — ACTIVE (R6-B2, 2026-10-05)

Continues feature/kdm-four-button-drive from b42d45c; production remains
3b4ddfd81871cc0c3900cf09feb81ef00dc91c30. The v1 table above is historical for
Drive, AutoStart and DriftWide; those six mappings are now LEGACY. DriftSquare
remains the existing compact tutorial/fallback asset. Item mappings are unchanged.

| Semantic key | Active v2 Asset ID |
|---|---|
| Forward | 133764403498700 |
| ForwardLeft | 107782001043228 |
| ForwardRight | 118487432534938 |
| BrakeReverse | 94445847645477 |
| AutoStart | 111620163887565 |
| DriftWide | 139581158872943 |

User artwork replacement (2026-10-05): `kdm_action_drift_wide_v2.png`
139581158872943 supersedes 88284882958523. Only the DriftWide mapping changes;
button geometry, Fit, input behavior and all other icon IDs remain unchanged.
The Studio evidence below describes the original R6-B2 asset set.

Studio visual identity inspection found the uploaded left/right filenames reversed:
118487432534938 points right; 107782001043228 points left. The user explicitly
approved mapping by the actual artwork. All six returned AssetFetchStatus.Success.
Drift retains Fit and horizontal presentation; no procedural rotation or new assets.
The Auto PNG includes a baked green dot at (512,212)/1024. A single colocated
runtime lamp covers it: graphite OFF, green ON. The Auto state machine is unchanged.

Touch dimensions and center spacing remain R6-B1 (short Drive 59x59, Auto 50x50,
Drift 221x63), with unchanged image frame sizes and no pressed shrink. The user
approved a minimum bottom correction after v2 clipping was observed: v2 alpha
padding replaces only the old bottom padding; GUI bounds replace the unsettled
Camera viewport when calculating bottom inset. No physics/input changes.

One existing Studio emulator session verified the actual HUD, Auto OFF/ON and
control imagery. Capture attempts for manual buttons are recorded locally; focus
changes in automation can release held input before observation. Drift held was
observed brightened. Physical two-finger Drift+steering is not claimed verified.
Automated Touch/Joystick ownership and Drift/Mini Boost regression cover behavior.
Evidence (excluded from Git): artifacts/r6b2/asset_identity.jpg, idle_Auto_OFF_Drift_idle.jpg,
Auto_ON.jpg, Forward.jpg, ForwardLeft.jpg, ForwardRight.jpg, BrakeReverse.jpg, Drift.jpg.

Studio raw JobId was empty. The Presence resolver now generates studio-<GUID>
once at boot using local HttpService:GenerateGUID(false). Native MemoryStore showed
one live HUB row with playerCount=1. Publish/remove stability and GUID calls are
validated with captured map keys. Map name, TTL 30 and heartbeat 9 are unchanged.
No repeated empty-key/publish failure appeared after the fix across multiple heartbeats.
Shutdown cleanup remains the existing same-instance remove path.
EXPECTED — Studio DataStore API access intentionally remains disabled.
PlayerPreferences and Teleport/routing source are unchanged. No Publish or production merge.
REAL DEVICE UX — NOT VERIFIED.
