# KDM Speed VFX V3.2 — Orange Cruise Rocket Flame (Nitro 120 Baseline Ratio, Drift Flame Retained, KDMSpeedVortex Retired)

**Date**: 2026-10-28  
**Scope**: Client Speed VFX (`src/client/KartWorldSpeedRenderer.luau`)  
**Target QA Experience**: Universe `10772198697` / Place `106553302629620` (`KDM_New_Hub`, Private, Version 124+)  
**Production Experience**: Universe `10768420544` / Place `127925465904803` (**STRICTLY UNTOUCHED**)  
**Status**: `PRIVATE_QA_READY_FOR_DEVICE_TEST` (Automated Pass, Real-Device Mobile Evaluation Ready)

---

## 1. User Feedback & Technical Reconciliation

### 1. Drift Flame Retention
- **Feedback**: "지금 정도로 만족하고, 드리프트시에 스키드 마크효과 타이어 마찰효과만 있는데, 이 엔진불꽃은 그대로 유지할수 있는지 검토해줘."
- **Analysis**:
  - 기존에는 `tier == "HIGH_SPEED" and kart:GetAttribute("KartDrifting") == true` 조건으로 인해 `tier`가 강제로 `"NONE"`으로 리셋되고, 크루즈 화염 분사 조건문에서도 `and kart:GetAttribute("KartDrifting") ~= true`가 걸려 있어 드리프트 진입 즉시 배기 화염이 꺼졌습니다.
  - 이를 수정하여:
    - **Air Trails(차체 공기 트레일)**: 드리프트 시 스키드마크/타이어 마찰 연출과 겹치지 않도록 깔끔하게 숨김(`isHigh = tier == "HIGH_SPEED" and alpha > 0 and not isDrifting`).
    - **Engine Rocket Flame(배기 로켓 화염)**: 드리프트 도중에도 카트 전방 속도(`speed > 1`)에 따라 **오렌지 로켓 화염이 양쪽 배기구에서 박력 있게 연속 분출**되도록 유지.
    - **미니 부스트 연계**: 드리프트 성공 후 미니 부스트 발동 시 `tier == "MINI_BOOST"`로 즉시 일렉트릭 블루 제트 화염으로 자연스럽게 전환.

### 2. Rear Wheel Wake Grey Smoke Puffs (`KDMSpeedVortex`) Complete Retirement
- **Feedback**: "그리고, 80/90 stud 타이어 근처 trail 효과 구성에서 가끔씩 회색 연기가 분출되는데 코드 확인하고, 회셕 연기가 둥글게 뒤로 분출되는거 있으면 제거해주세요."
- **Analysis**:
  - `src/client/KartWorldSpeedRenderer.luau`에 존재하던 `KDMSpeedVortexLeft` / `KDMSpeedVortexRight` 이미터가 원인으로 확인되었습니다.
  - 이 이미터는 80~90stud 속도(`bucket >= 16`)에서 후륜 타이어 바로 뒤(`Position = wheel.Center + ...`)에 `smoke_main.dds` 텍스처를 1~3개씩 둥근 빌보드 형태로 뿜어내어 지저분한 회색 연기 찌꺼기처럼 보였습니다.
  - **조치**: `KDMSpeedVortexPoint` 어태치먼트 2개와 `KDMSpeedVortex` 이미터 2개, 관련 레이트 맵 및 루프 코드를 **완전히 삭제(Retire)**하여 인스턴스 예산 절감(24 $\to$ 20개) 및 타이어 주변 시야를 순수하게 정돈했습니다.

---

## 2. Speed-Proportional Flame Mapping (1~91 studs/s, Nitro 120 Baseline)

| Speed (KM/H) | Core Rate | Plume Rate | 양쪽 총 Rate | Core 폭 / Plume 폭 (중앙부) | SpeedMax | **화염 최대 분출 길이** | **니트로 대비 실제 비율** | 드리프트 중 상태 |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **0 ~ 1** | 0 | 0 | **0** | 0 (Off) | 0 | 0 | 0% | 꺼짐 |
| **10** | 11 | 4 | **30** | 0.28stud / 0.40stud | 2.50 | 0.375 stud | 8.3% | 유지 |
| **40** | 21 | 12 | **66** | 0.46stud / 0.60stud | 10.00 | 1.500 studs | 33.3% | 유지 |
| **70** | 31 | 22 | **106** | 0.60stud / 0.81stud | 17.50 | **2.625 studs** | **70/120 (58.3%)** | **화염 유지** (트레일 숨김) |
| **80** | 34 | 25 | **118** | 0.65stud / 0.88stud | 20.00 | **3.000 studs** | **80/120 (66.7%)** | **화염 유지** (트레일 숨김) |
| **90** | 38 | 28 | **132** | 0.73stud / 0.94stud | 22.50 | **3.375 studs** | **90/120 (75.0%)** | **화염 유지** (트레일 숨김) |
| **91** (GAS held) | 38 | 28 | **132** | 0.75stud / 0.95stud | 22.75 | **3.413 studs** | **91/120 (75.8%)** | **화염 유지** (트레일 숨김) |
| **미니 부스트** | 45 | 25 | **140** | 0.90stud / 1.30stud | 30.00 | **4.200 studs** | 일렉트릭 블루/시안 | 블루 부스트 화염 |
| **니트로 (120)** | 65 | 35 (+18) | **236** | 1.25stud / 1.70stud | 42.00 | **4.500 ~ 6.500 studs** | 일렉트릭 블루/시안 | 블루 니트로 화염 |

---

## 3. Verification Matrix

| 항목 | 결과 | 세부 내용 |
| :--- | :--- | :--- |
| **스튜디오 모의 카트 시뮬레이션** | **PASS** | `VortexCount=0`, 드리프트 80stud 시 `Core Rate=34` 유지 및 `Trail=false` 확인 완료 |
| **KDMSpeedVortex 완전 제거** | **PASS** | 80/90stud 타이어 후방 회색 둥근 연기 이미터 완전 박멸 |
| **컴파일 검증** | **PASS** | `loadstring(speedRenderer.Source)` 무에러 통과 |
| **인스턴스 예산 절감** | **PASS** | 24개 $\to$ 20개(트레일 4 + 어태치먼트 10 + 배기 이미터 6), 런타임 힙 할당 0 |
| **공식 운영 환경 보호** | **PASS** | Place `127925465904803` 일체 미접촉 |

**Source Canonical SHA256 (`src/client/KartWorldSpeedRenderer.luau`)**:
`c84dc14c420c5163372c3d40860d46571a4f4ce349b244bc174e24d7f755ae39`
