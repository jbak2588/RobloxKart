# Speed Trail V2.3 — Mobile Trail Tuning 보고서 (71 / 82 / 91 KM/H 기준)

- **상태**: `PRIVATE_QA_READY_FOR_DEVICE_TEST`
- **대상 비공개 QA 환경**: Universe **10772198697** / Start Place **106553302629620** (`KDM_New_Hub`)
- **접근 권한**: Game Access: **Private** / Audience Reach: **Private**
- **공식 운영 환경**: Universe 10768420544 / Place 127925465904803 (일체 미접촉 / 변경 없음)
- **V2.3 Tuned 소스 SHA256**: `4e8eaa2b3bea0aafb74df3046845a0f9862def4cb9abac7f80baaa3a039969ea` (13,430 bytes)

---

## 1. 개요 및 변경 핵심 (World Length 고정 원리)

사용자의 실기기(71/82/91 KM/H) 주행 테스트 피드백을 반영하여, **속도가 증가해도 화면 하단(NITRO 게이지, 디지털 속도계, 가상 버튼)을 침범하지 않도록 트레일 세계 길이를 9~10 studs로 엄격히 고정**했습니다.

- **원리 ($L = v \times \text{Lifetime}$)**:
  - 71 KM/H ($v \approx 70$ studs/s): $70 \times 0.13\text{s} = \mathbf{9.1\text{ studs}}$
  - 82 KM/H ($v \approx 80$ studs/s): $80 \times 0.12\text{s} = \mathbf{9.6\text{ studs}}$
  - 91 KM/H ($v \approx 90$ studs/s): $90 \times 0.11\text{s} = \mathbf{9.9\text{ studs}}$
- 속도가 증가해도 트레일의 물리적 길이가 9.1~9.9 studs로 거의 일정하게 유지되므로, 3인칭 추적 카메라에서 화면 하단 UI 침범이 원천적으로 차단됩니다.
- 속도감의 차별화는 트레일 길이가 아닌 **폭 확장(0.18 → 0.30 → 0.40)**, **선명도(시작 투명도 0.70 → 0.55 → 0.40)**, 그리고 **91 KM/H 도달 시 꼬리 연시안(Soft Cyan) 발색**으로 구현했습니다.

---

## 2. 변경 전후 파라미터 상세 대비표 (71 / 82 / 91 KM/H)

### A. Primary Trail (KDMSpeedTrail1 & KDMSpeedTrail2)

| 속도 단계 | 이전 Lifetime (V2.3 Test) | 신규 Lifetime (V2.3 Tuned) | 트레일 세계 길이 ($v \times \text{Life}$) | 신규 폭 (WidthScale) | 신규 시작 투명도 (끝 1.0 페이드) | 신규 색상 (Color) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **71 KM/H**<br>(70 studs/s, bucket 10) | 0.10s (속도비례) | **0.13s (속도반비례)** | **9.1 studs** | **시작 0.18 stud** → 끝 0 | **시작 0.70** → 끝 1.0 | 원래 아이스 블루 단색<br>(`RGB 222, 243, 255`) |
| **82 KM/H**<br>(80 studs/s, bucket 17) | 0.14s (속도비례) | **0.12s (속도반비례)** | **9.6 studs** | **시작 0.30 stud** → 끝 0 | **시작 0.55** → 끝 1.0 | 원래 아이스 블루 단색<br>(`RGB 222, 243, 255`) |
| **91 KM/H**<br>(90 studs/s, bucket 20) | 0.18s (속도비례, 16.2st 침범) | **0.11s (속도반비례)** | **9.9 studs** (침범 해소) | **시작 0.40 stud** → 끝 0 | **시작 0.40** → 끝 1.0 | 시작: 아이스 블루<br>**끝: 연시안 (`RGB 130, 230, 255`)** |

- **WidthScale**: 끝부분이 정확히 `0`으로 수렴하는 완전 테이퍼.
- **Transparency**: 끝부분이 정확히 `1.0`으로 수렴하는 완전 페이드.
- **Attachment 위치**: V2.2 최적화 위치(후면 범퍼 모서리) 100% 보존.

### B. Secondary Trail (KDMSpeedTrail3 & KDMSpeedTrail4)
- **Lifetime**: Primary의 약 60% (**91 KM/H에서 `0.066s`**, 82 KM/H에서 `0.072s`)
- **점등 조건**: **90 studs/s에서만 완전 점등** (`bucket >= 19`, 86~90 studs/s). 71/82 KM/H에서는 완전 OFF.
- **형태**: 시작 폭 0.45 stud → 끝 0, 시작 투명도 0.40 → 끝 1.0 페이드.

---

## 3. 검증 결과
1. `tests/speed_world_vfx_validation.luau`: **PASS** (1,562 production checks + 24,316 V2 checks)
2. `tests/source_freeze_release_validation.luau`: **PASS** (683 integrity checks across 133 files)
3. `tests/current_release_contracts_validation.luau`: **PASS** (66 contract checks)
4. Rojo Build & git diff check: **PASS**
5. Studio Edit DataModel 동기화 확인: `c5208bf0-2434-45b7-aa6c-7c4c531adcd4`에 실시간 반영 완료 (`Len=13430`, SHA `4e8eaa2b...`).
6. 공식 Place (127925465904803): Version 1236 유지, 일체 미접촉.
7. Git commit / push: 미실행 (원격 HEAD `f5ebec8` 유지).
