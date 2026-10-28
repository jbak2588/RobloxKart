# KDM Speed VFX V3.0 — Camera Airflow Particles & Subordinate Trail Demotion

**Date**: 2026-10-28
**Scope**: Client Speed VFX Architectural Transition (`src/client/KartWorldSpeedRenderer.luau`)
**Target QA Experience**: Universe `10772198697` / Place `106553302629620` (`KDM_New_Hub`, Private)
**Production Experience**: Universe `10768420544` / Place `127925465904803` (**STRICTLY UNTOUCHED**)
**Status**: `PRIVATE_QA_READY_FOR_DEVICE_TEST` (Automated Pass, Real-Device Mobile Evaluation Pending)

---

## 1. Architectural Transition: V2.3 to V3.0

### Background & Real-Device Diagnostic (Captures at 71 / 81 / 91 KM/H)
- **Problem**: When camera chases kart from a high angle, any long trail projected behind the kart appears as two chalk/paint lines drawn on the asphalt, stretching downward into mobile touch UI (direction pads, digital speed text, Nitro charge bar).
- **Core Strategy Change**:
  1. **Primary Speed VFX**: Shifted from rear-kart trails to **Camera Airflow Particles** (`KDMCameraAirflowLeft` / `KDMCameraAirflowRight`). High-speed airflow streaks fly past the camera left and right, creating visceral arcade forward momentum without obscuring the track or UI.
  2. **Trail Demotion**: Rear-kart trails demoted to subtle subordinate helpers. World length is strictly capped to $\le 6.0$ studs (inversely proportional to speed), starting at high transparency (0.75) and tapering to 0 width.
  3. **Attachment Preservation**: Rear bumper corner and upper cowl attachment positions from V2.2 are 100% preserved.

---

## 2. Parameter Comparison: Pre-change (V2.3) vs New (V3.0)

### A. Primary Trail (`KDMSpeedTrail1` & `KDMSpeedTrail2`)
| Parameter | V2.3 Tuned | V3.0 Implementation | Architectural Purpose |
| :--- | :--- | :--- | :--- |
| **MinLength** | `0.05` stud | `0.05` stud | Preserved |
| **Lifetime (70 / 80 / 90 studs/s)** | `0.13s / 0.12s / 0.11s` | `0.086s / 0.075s / 0.067s` | Inversely proportional ($L = v \times \text{Lifetime} \le 6.0$ studs) |
| **Max World Length** | ~9.0 ~ 10.0 studs | **$\le 6.0$ studs** | Eliminates UI intersection |
| **Transparency (Start -> End)** | `0.70 / 0.55 / 0.40 -> 1.0` | **`0.75 -> 1.0`** | Subordinate faint appearance |
| **WidthScale (Start -> End)** | `0.18 / 0.30 / 0.40 -> 0.0` | **`0.12 / 0.16 / 0.20 -> 0.0`** | Delicate taper |
| **Color** | White (`255, 255, 255`) -> Soft Cyan | White (`255, 255, 255`) -> Soft Cyan | Preserved color progression |

### B. Secondary Trail (`KDMSpeedTrail3` & `KDMSpeedTrail4`)
| Parameter | V2.3 Tuned | V3.0 Implementation | Architectural Purpose |
| :--- | :--- | :--- | :--- |
| **MinLength** | `0.05` stud | `0.05` stud | Preserved |
| **Activation Speed** | Only active at $\ge 90$ studs/s | Only active at $\ge 90$ studs/s (`bucket >= 19`) | Subordinate accent |
| **Lifetime** | `0.066s` (at 90 studs/s) | **`0.040s`** (at 90 studs/s) | 60% of Primary length ($\approx 3.6$ studs) |
| **Transparency (Start -> End)** | `0.40 -> 1.0` | **`0.80 -> 1.0`** | Very subtle accent |
| **WidthScale (Start -> End)** | `0.45 -> 0.0` | **`0.15 -> 0.0`** | Narrow subordinate width |

### C. Camera Airflow Particles (`KDMCameraAirflowLeft` & `KDMCameraAirflowRight`) [NEW]
| Parameter | Specification & Implementation |
| :--- | :--- |
| **Container Part** | 2 parts parented to `Camera` (fallback `Workspace`), Anchored, Non-colliding, CanQuery=false, CanTouch=false, Transparency=1 |
| **Relative Placement** | Offset from camera: `X = ±12.5`, `Y = -0.5`, `Z = -16.0` (Span: `Size = Vector3.new(7, 5, 12)`) |
| **Particle Volume** | `Shape = Box`, `ShapeStyle = Volume`, `LockedToPart = false` (world-fixed flight past camera) |
| **Orientation & Direction** | `Orientation = VelocityParallel`, `EmissionDirection = Back`, `Speed = NumberRange.new(15, 20)` |
| **Texture Selection** | `"rbxasset://textures/particles/smoke_main.dds"` stretched with `Squash` (75..112.5) for seamless streaks |
| **LightEmission** | `0.3` |
| **Emission Rate** | `< 68 studs/s`: 0<br>`70 studs/s`: 8 per side<br>`80 studs/s`: 20 per side<br>`90 studs/s`: 36 per side |
| **Lifetime** | `70 studs/s`: 0.45s<br>`80 studs/s`: 0.38s<br>`90 studs/s`: 0.32s |
| **Size & Squash** | `70 studs/s`: 0.04 stud width, Squash 75.0 (length ~3 studs)<br>`80 studs/s`: 0.06 stud width, Squash 100.0 (length ~6 studs)<br>`90 studs/s`: 0.08 stud width, Squash 112.5 (length ~9 studs) |
| **Transparency** | `1.0 -> Peak (0.75 / 0.60 / 0.45) -> 1.0` (fades in, peaks, fades out before reaching camera near-plane) |
| **Color** | `70~80 studs/s`: Pure White (`255, 255, 255`)<br>`90 studs/s`: Soft Cyan (`200, 235, 255`) |

---

## 3. Test & Verification Matrix

| Test Suite | Result | Details |
| :--- | :--- | :--- |
| `tests/speed_world_vfx_validation.luau` | **PASS** | 1,562 production checks + 31,196 V2/V3 checks |
| `tests/source_freeze_release_validation.luau` | **PASS** | 683 source integrity checks across 133 files |
| `tests/current_release_contracts_validation.luau` | **PASS** | 66 contract checks verified |
| `rojo.exe build default.project.json` | **PASS** | Build succeeds with zero errors |
| `git diff --check` | **PASS** | Zero whitespace or line-ending anomalies |

**Source SHA256 (`src/client/KartWorldSpeedRenderer.luau`)**:
`27b3aacd8852cfa46d98620e5ba45ff9855c2a480f373f66b6bffe4c4cd91bb3`

---

## 4. Live Studio Synchronization & Deployment

- **QA Studio Instance (`c5208bf0-2434-45b7-aa6c-7c4c531adcd4`)**:
  - Live synchronized via Rojo.
  - Script source verified: `len = 17776`, contains `V3.0 Debug: 임시 빨간색` and `Rate 3배`.
- **Production Studio Instance (`d7f83941-f27a-486a-94c5-4977dccd17d2`)**:
  - **Untouched** (`Version = 1236`).
- **Publish Action**:
  - User can publish the synchronized QA Studio place by pressing `Alt + P` in the QA Studio window.

---

## 5. V3.0 Diagnostic & Screen Projection Math

### A. Screen Projection Math (1600 x 739 Mobile Viewport, Vertical FOV 50° ~ 55°)
- **Camera Frustum Half-Width at Distance $d$**:
  $W_{\text{half}} = d \times \frac{1600}{739} \times \tan(\theta_v / 2) \approx d \times 1.01$ (at FOV 50°).
- **At $d = 16\text{ studs}$**:
  - Frustum half-width is $\approx 16.15\text{ studs}$ (Center to screen edge is 16.15 studs).
  - Current Left part ($X \in [-16, -9]$): projects to $X_{\text{px}} \in [8, 354]$ (directly overlapping left direction buttons at $X < 410, Y > 550$).
  - Current Right part ($X \in [9, 16]$): projects to $X_{\text{px}} \in [1246, 1592]$ (directly overlapping right item icons & GAS at $X > 1145$).
- **Target Driving Corridor ($X_{\text{px}} \in [460, 580]$ and $[1020, 1140]$)**:
  - Requires physical offset $X \approx \pm 5.5 \sim 7.0\text{ studs}$.

### B. Squash 75 ~ 112.5 & Texture Analysis
- **Squash Formula**: $\text{Squash} = \text{Length} / \text{Thickness}$ ($3.0 / 0.04 = 75$, $6.0 / 0.06 = 100$, $9.0 / 0.08 = 112.5$).
- **Render Issue**: At $d = 16\text{ studs}$, thickness 0.04 stud is only $\approx 1.98\text{ pixels}$. Stretching radial `smoke_main.dds` creates extreme alpha dilution at ~2px width, becoming virtually invisible.
- **Solution**: Linear streak/beam texture + thickness increase to 0.12 ~ 0.20 stud (~6..10px) with Squash 15..25.

