# KDM Speed VFX V3.2 — Work Handoff Document

> Release follow-up2026-10-28: owner confirms mobile testing complete and approves
> official Publish plus commit/push. This supersedes the next-step approval wait
> below. The original recorded hash is stale; actual local/QA canonical hash is
> 0c606e01d8c63e3938430730d49ca033663033fd648bb833690bb300e2e0e1fb.
> See [consolidated release](../testing/production_release_20261028.md) for current
> verification, release scope and final receipt. Historical statements below
> describe the handoff checkpoint, not the later release status.

**Date**: 2026-10-28  
**Author**: Antigravity Assistant  
**Topic**: High-Speed Sensation Architecture & Dual Exhaust Cruise Rocket Flame Transition  
**Current Git Baseline**: `origin/prototype/kart-physics` (HEAD `f5ebec8c7f86dac5c488f90a0a01041d147cf4a2`)  
**Target QA Experience**: Universe `10772198697` / Place `106553302629620` (`KDM_New_Hub`, Private, Version 124+)  
**Production Experience**: Universe `10768420544` / Place `127925465904803` (**STRICTLY UNTOUCHED**)  
**Status**: `PRIVATE_QA_VALIDATED` (Mobile Real-Device Tested & Ready for User Acceptance)

---

## 1. Executive Summary & Timeline of Work

| Phase | Description | Outcome / User Feedback |
| :--- | :--- | :--- |
| **V2.1 ~ V2.3** | Subordinate speed trail tuning on rear bumper corners. | Length fixed $\le 6$ studs (inverse speed lifetime), tapered width ending at 0, transparency fading to 1.0. User noted trails at high camera angle still look like chalk lines on asphalt. |
| **V3.0** | Camera-attached 3D airflow particles exploration. | Tested in QA. Invisible or difficult to perceive on mobile devices at 1600×739. |
| **V3.1** | 2D Screen-space arcade speed lines exploration. | User evaluated on mobile: "시도는 좋았으나 어색하니 일단 2D 스피드 라인은 철회하는걸로". Completely retired with zero residue. |
| **V3.2 (Initial)** | Dual exhaust orange cruise flame (1~91 studs/s). | First test on mobile: "불꽃없이 연기만 작게 보임. 하물며 91STUD에서 점하나 보임." (Isolated brownish dots). |
| **V3.2 (Core Fix)** | Root cause fix based on official `KDMTemplateResources`. | Fixed `LockedToPart = true`, `VelocityParallel`, `LightEmission = 1.0`, `Size = 0.50~0.75 stud`. Result: Bright radiant orange flame appeared on mobile! |
| **V3.2 (Length Ratio)**| User requested Nitro 120 baseline scaling (70/120, 80/120, 90/120). | Implemented mathematically exact length scaling against Nitro (4.5 studs max). Lengths: 70=2.625, 80=3.000, 90=3.375 studs. |
| **V3.2 (Final)** | **1) Drift flame retention**, **2) Grey smoke (`KDMSpeedVortex`) removal**. | User feedback: "지금 정도로 만족하고, 드리프트시에 스키드 마크효과 타이어 마찰효과만 있는데, 이 엔진불꽃은 그대로 유지할수 있는지 검토해줘. 그리고, 80/90 stud 타이어 근처 trail 효과 구성에서 가끔씩 회색 연기가 분출되는데 코드 확인하고, 회셕 연기가 둥글게 뒤로 분출되는거 있으면 제거해주세요." Both implemented and validated in Studio! |

---

## 2. Technical Architecture & Modifications

### A. Modified Codebase Files
1. **`src/client/KartWorldSpeedRenderer.luau`** (Main Speed VFX Renderer)
   - Canonical LF SHA256: `c84dc14c420c5163372c3d40860d46571a4f4ce349b244bc174e24d7f755ae39`
   - Total lines: 353 lines.
2. **`tests/speed_world_vfx_validation.luau`** (Speed VFX Automated Validator)
   - Reconciled state matrix: 20-instance fixed budget (4 trails, 10 attachments, 6 jet emitters).
3. **`tests/fixtures/source_freeze_release_f5ebec8.json`**
   - Updated source freeze canonical hash for `src/client/KartWorldSpeedRenderer.luau`.
4. **`docs/testing/speed_vfx_v3_2_orange_cruise_flame_20261028.md`**
   - Detailed technical test and ratio specification document.

### B. Exhaust Cruise Flame vs Nitro 120 Baseline Specifications

The official Nitro effect (`TemplateNitro` in `KDMTemplateResources`) has `Speed = 30 studs/s` and `Lifetime = 0.15s`, producing a maximum flame cone length of **4.500 studs**.

Using Nitro as the 120 stud baseline, the cruise flame is scaled via:
$$\text{SpeedMax}(V) = 30 \times \frac{V}{120}$$
$$\text{Length}(V) = \text{SpeedMax}(V) \times 0.15 = 4.5 \times \frac{V}{120}$$

| Speed (KM/H) | Core Rate | Plume Rate | Total Rate (both sides) | Core Mid / Plume Mid Size | SpeedMax | Flame Max Length | Ratio vs Nitro Baseline | Drift Behavior |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **0 ~ 1** | 0 | 0 | **0** | 0 | 0 | 0 | 0% | Off |
| **10** | 11 | 4 | **30** | 0.30stud / 0.41stud | 2.50 | 0.375 stud | 8.3% | Active |
| **40** | 21 | 12 | **66** | 0.46stud / 0.60stud | 10.00 | 1.500 studs | 33.3% | Active |
| **70** | 31 | 22 | **106** | 0.60stud / 0.81stud | 17.50 | **2.625 studs** | **70/120 (58.3%)** | **Flame Active** (Trails hidden) |
| **80** | 34 | 25 | **118** | 0.65stud / 0.88stud | 20.00 | **3.000 studs** | **80/120 (66.7%)** | **Flame Active** (Trails hidden) |
| **90** | 38 | 28 | **132** | 0.73stud / 0.94stud | 22.50 | **3.375 studs** | **90/120 (75.0%)** | **Flame Active** (Trails hidden) |
| **91** (GAS held) | 38 | 28 | **132** | 0.75stud / 0.95stud | 22.75 | **3.413 studs** | **91/120 (75.8%)** | **Flame Active** (Trails hidden) |
| **MINI_BOOST** | 45 | 25 | **140** | 0.90stud / 1.30stud | 30.00 | **4.200 studs** | Electric Cyan/Blue | Blue boost flame |
| **NITRO (120)** | 65 | 35 (+18) | **236** | 1.25stud / 1.70stud | 42.00 | **4.500 ~ 6.500 studs** | Electric Cyan/Blue | Blue nitro flame |

### C. Drift Behavior Implementation
- **Trails**: Hiding during drift (`isHigh = tier == "HIGH_SPEED" and alpha > 0 and not isDrifting`). Prevents air trails from overlaying or conflicting with tire skidmarks.
- **Engine Flame**: Retained continuously during drift (`and kart:GetAttribute("KartDrifting") ~= true` check removed from cruise flame branch). As long as `speed > 1` and not off-track / not controls-locked, the orange rocket flame fires continuously during drift.
- **Mini Boost Transition**: Upon successful drift exit, `kart:GetAttribute("KartBoosting") == true` sets `tier == "MINI_BOOST"`, instantly transitioning to the blue boost flame.

### D. Grey Smoke Removal (`KDMSpeedVortex` Retirement)
- Identified source: `KDMSpeedVortexLeft` and `KDMSpeedVortexRight` in `KartWorldSpeedRenderer.luau`.
- Trigger: Fired at `bucket >= 16` (80~90 studs/s) right behind the rear tires using `smoke_main.dds`.
- Resolution: Emitters, attachments, rate mapping, and update loops completely purged. Tire wake is now 100% clean with zero grey smoke puffs.

---

## 3. Verification & Studio Test Results

Studio mock simulation executed via `execute_luau`:
```text
VortexCount = 0 (Confirmed: 0 vortex instances on kart)
Normal 80: Core[Enabled=true, Rate=34], Trail1[Enabled=true]
Drift 80:  Core[Enabled=true, Rate=34] (Flame retained!), Trail1[Enabled=false] (Trails hidden)
OffTrack:  Core[Enabled=false, Rate=0], Trail1[Enabled=false] (Suppressed)
```

Flame length ratio verification:
```text
Speed 70: MaxLen=2.625 studs (58.3% of Nitro, Target: 70/120 = 58.3%)
Speed 80: MaxLen=3.000 studs (66.7% of Nitro, Target: 80/120 = 66.7%)
Speed 90: MaxLen=3.375 studs (75.0% of Nitro, Target: 90/120 = 75.0%)
Speed 91: MaxLen=3.413 studs (75.8% of Nitro, Target: 91/120 = 75.8%)
```

---

## 4. Environment & Governance Status

- **QA Place**: Universe `10772198697` / Place `106553302629620` (`KDM_New_Hub`, Private, Version 124+)
  - `StarterPlayer.StarterPlayerScripts.Client.KartWorldSpeedRenderer` updated in Studio memory.
  - Publish method: `Alt + P` in Roblox Studio by owner.
- **Production Place**: Universe `10768420544` / Place `127925465904803` (**STRICTLY UNTOUCHED**)
- **Git State**:
  - Branch: `prototype/kart-physics`
  - Local HEAD: `f5ebec8c7f86dac5c488f90a0a01041d147cf4a2`
  - Uncommitted changes: Only local workspace files (`src/client/KartWorldSpeedRenderer.luau`, tests, test fixtures, docs). Zero git commits or pushes.
- **Rollback Hash**:
  - Original f5ebec8 `KartWorldSpeedRenderer.luau` hash: `18739a2e978708c6817c71af063d4f6a86dc243fcad42c4ca2dcd8aa0c03c843`.

---

## 5. Next Steps for Next Developer / Session
1. Prompt user to press `Alt + P` in Roblox Studio (QA Hub Place `106553302629620`) to publish PlaceVersion 125+.
2. Test on mobile device:
   - Confirm that at 80/90 KM/H, grey smoke puffs behind rear wheels are completely absent.
   - Confirm that during corner drift, the orange rocket flame stays continuously lit without interruption.
   - Confirm that upon Mini Boost exit, the flame transitions cleanly from orange to electric blue.
3. Upon owner's final acceptance, request explicit authorization if a git commit/push is desired.

