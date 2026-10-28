# KDM Speed VFX V3.1 — 2D Screen-space Arcade Speed Lines (Zero Frame Drop)

**Date**: 2026-10-28
**Scope**: Client Speed VFX Architectural Transition (`src/client/KartWorldSpeedRenderer.luau`)
**Target QA Experience**: Universe `10772198697` / Place `106553302629620` (`KDM_New_Hub`, Private)
**Production Experience**: Universe `10768420544` / Place `127925465904803` (**STRICTLY UNTOUCHED**)
**Status**: `PRIVATE_QA_READY_FOR_DEVICE_TEST` (Automated Pass, Real-Device Mobile Evaluation Pending)

---

## 1. Architectural Transition: V3.0 (3D Camera Particles) to V3.1 (2D Screen-Space Speed Lines)

### Background & Diagnostic Analysis
- **Defect in V3.0**: 3D world particles emitted around the camera were invisible on real devices due to:
  1. Frustum & near-plane culling during high-speed chase-camera turns.
  2. Sub-pixel aliasing at mobile resolutions ($1600 \times 739$) combined with radial alpha smoke dilution.
  3. Dynamic aspect ratio shifts pushing world particles off-screen.
- **Solution in V3.1**:
  - Implemented **2D Screen-space Arcade Speed Lines** (`KDMSpeedLinesGui`) pinned directly to screen bounds.
  - Zero Frame Drop guarantee: fixed pool of 16 lightweight GUI frames, zero heap allocation per frame, DisplayOrder 2 (behind touch controls).
  - Central driving line ($50\%$ center box) kept 100% clear.
  - Trails demoted to subordinate helper ($\le 6.0$ studs length, V2.2 bumper attachments).
  - Micro vortex subtle white vapor at rear tires.

---

## 2. 2D Screen-space Speed Lines Specifications

| Parameter | Specification | Architectural Purpose |
| :--- | :--- | :--- |
| **Container Gui** | `KDMSpeedLinesGui` in `PlayerGui`, `DisplayOrder = 2`, `IgnoreGuiInset = true` | Drawn beneath all HUD text and touch controls (DisplayOrder 20/21) |
| **Object Pool Size** | 16 fixed frames pre-created on start | Zero `Instance.new` / `Destroy` during gameplay |
| **Per-Frame Allocation** | **0 bytes** (zero garbage collection pressure) | **Zero Frame Drops / Micro-stutters** |
| **Ray Distribution** | 6 Left rays, 6 Right rays, 4 Top corner rays | Dynamic radial streaming from screen horizon outward |
| **Central Safe Zone** | Center $X \in [0.35, 0.65], Y \in [0.30, 0.85]$ completely clear | Zero obstruction of road, turns, and opponent karts |
| **Touch Interaction** | `Active = false`, `Selectable = false` | Touch events pass through to game/HUD controls |

### Speed Response Profile
- **$< 68\text{ studs/s}$**: Completely dormant (`Enabled = false`, 0 CPU cost).
- **$70\text{ studs/s}$**: Subtle, faint wind flow (`peakTrans = 0.65`, short length).
- **$80\text{ studs/s}$**: Clear, streaming air corridors on screen edges (`peakTrans = 0.35`).
- **$90\text{ studs/s}$ (GAS held)**: Intense, razor-sharp white/cyan arcade streaks (`peakTrans = 0.10`, fast rush).
- **Drift / Off-track / Stopped / Controls Locked**: Instantly turns off.

---

## 3. Test & Verification Matrix

| Test Suite | Result | Details |
| :--- | :--- | :--- |
| `tests/speed_world_vfx_validation.luau` | **PASS** | 1,562 production checks + 23,516 V2/V3.1 checks |
| `tests/source_freeze_release_validation.luau` | **PASS** | 683 source integrity checks across 133 files |
| `tests/current_release_contracts_validation.luau` | **PASS** | 66 contract checks verified |
| `rojo.exe build default.project.json` | **PASS** | Build succeeds with zero errors |
| `git diff --check` | **PASS** | Zero whitespace or line-ending anomalies |

**Source SHA256 (`src/client/KartWorldSpeedRenderer.luau`)**:
`226fe315359e3803d5f6fae84733af47f20a11c5f3554cf96b094f7a77cce9c2`
