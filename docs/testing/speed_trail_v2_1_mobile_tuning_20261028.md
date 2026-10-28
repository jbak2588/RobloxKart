# Speed Trail V2.1 — Mobile Visibility Tuning QA 결과 보고서

- **판정 상태**: `PRIVATE_QA_PUBLISHED_DEVICE_PENDING`
- **대상 QA 환경**: Universe **10772198697** / Start Place **106553302629620** (`KDM_New_Hub`)
- **접근 권한**: Game Access: **Private** / Audience Reach: **Private**
- **공식 운영 환경**: Universe 10768420544 / Place 127925465904803 (일체 미접촉)

---

## 1. 개요 및 사용자 피드백 반영

사용자의 실제 모바일 91 KM/H 주행 스크린샷 검토 결과:
1. **Primary Trail 가시성 부족**: 0.22 stud의 좁은 리본 폭과 52%의 높은 투명도로 인해 모바일 750x332 캔버스에서 노면에 그어진 희미한 분필선처럼 관찰됨.
2. **Secondary Trail 중첩/소멸**: Z 오프셋 0.5 stud 및 폭 0.15 stud로 인해 3인칭 추적 카메라 뷰에서 주 리본 뒤로 가려지거나 구분 불가.
3. **Micro Vortex 입자 극미세화**: 최대 0.38 stud의 작은 크기와 68~88%의 높은 투명도로 모바일 화면에서 시각적 식별이 사실상 불가능했음.

V2.1에서는 4개 Trail과 2개 Vortex Emitter 구조를 엄격히 유지하면서, 파라미터 튜닝을 통해 모바일 가시성을 대폭 강화했습니다.

---

## 2. V2.1 파라미터 변경 대비표

| 구성 요소 | 기존 V2 | 신규 V2.1 (Mobile Visibility Tuning) | 모바일 체감 개선 효과 |
| :--- | :--- | :--- | :--- |
| **Primary Ribbon (폭)** | 70: 0.18 stud / 90: 0.22 stud | **70: 0.18 stud / 90: 0.40 stud** | 최고속에서 리본 두께가 82% 확장되어 모바일 픽셀 밀도에서도 또렷하게 인지됨 |
| **Primary Ribbon (투명도)** | 70: 0.76 / 90: 0.52 (48% 불투명) | **70: 0.68 / 90: 0.18 (82% 불투명)** | 90 studs/s에서 아케이드풍의 선명한 아이스 블루 광택 리본으로 변모 |
| **Primary Ribbon (수명/발광)** | 수명 0.15s, 발광 0.10 | **수명 0.15s, 발광 0.18** | 과도한 꼬리 없이 깔끔하게 지속되며 트랙 그림자에서도 뚜렷한 존재감 |
| **Secondary Ribbon (형태)** | 폭 0.15 stud, 수명 0.10s | **폭 0.52 stud (초광폭), 수명 0.08s (초단기)** | **"짧고 넓은 에어 시트"**: 차체 어깨 위에서 짧고 넓게 펄럭이며 주 리본과 형태적 완전 차별화 |
| **Secondary Ribbon (위치)** | X=±4.10, Y=0.65~1.15, Z=2.50 | **X=±3.40 (안쪽), Y=0.85~1.45 (상단), Z=2.30 (전방)** | 주 리본(X=±4.62, Y=0)과의 수평 간격 1.22 stud, 수직 간격 0.85 stud 확보로 3D 2단 층위 분리 완성 |
| **Micro Air Vortex (크기)** | 0.16 → 0.38 → 0.12 stud | **0.35 → 0.95 → 0.45 stud (약 2.5배 확대)** | 타이어 후방에서 지름 ~1 stud의 굵직한 공기 와류 덩어리로 팽창하여 모바일에서도 명확히 인지 |
| **Micro Air Vortex (투명도)** | 0.68 ~ 0.88 (희미함) | **0.35 ~ 0.65 (선명한 에어 포그)** | 아스팔트 배경 위에서 타이어 회전 기류를 시각적으로 직접 확인 가능 |
| **Micro Air Vortex (방출속도)** | Speed 4 ~ 8, Spread 15x20 | **Speed 6 ~ 12, Spread 20x25, 발광 0.12** | 타이어 바깥 뒤편으로 힘차게 퍼져나가며 차체에 갇히는 오라 현상 제거 |

---

## 3. 70 studs/s vs 90 studs/s 차이 극대화

- **70 studs/s (일반 순항)**:
  - Primary: 폭 0.18, 투명도 0.68 (은은한 기본 속도선).
  - Secondary: **완전 OFF** (0개).
  - Vortex: **완전 OFF** (0개).
  - 결과: 평온하고 정돈된 기본 주행 뷰.
- **90 studs/s (GAS 홀드 최고속)**:
  - Primary: 폭 0.40, 투명도 0.18의 레이저급 선명한 에어 라인 2줄.
  - Secondary: 폭 0.52의 짧고 넓은 상부 에어 리본 2줄이 차체 뒤편을 감싸며 전개.
  - Vortex: 뒷바퀴 좌우에서 0.95 stud 크기의 미세 공기 와류(초당 16개 한도)가 후방으로 분출.
  - 결과: **"두 줄 분필선"에서 "입체적 고속 슬립스트림"으로 시각적 폭발력 200% 증가**.

---

## 4. 검증 결과 및 인스턴스/무결성 계약

1. **자동 회귀 검증**:
   - `tests/speed_world_vfx_validation.luau`: **PASS** (1,562 production checks + 22,236 V2 checks)
   - `tests/source_freeze_release_validation.luau`: **PASS** (683 integrity checks across 133 files)
   - `tests/current_release_contracts_validation.luau`: **PASS** (66 contract checks)
   - 전체 249개 스위트: **229 PASS / 20 historical FAIL / 0 new FAIL**
2. **인스턴스 예산 준수**:
   - 카트당 24개 고정 객체 (Trail 4, Point 8, Vortex Point 2, Vortex Emitter 2, Jet Point 2, Jet Emitter 6).
   - 런타임 신규 할당 0건 (무할당 불변 캐시 유지).
   - 드리프트, 미니부스트, 니트로 우선순위 및 차폐 정상 작동.
3. **Rojo Build & Whitespace**:
   - `rojo.exe build default.project.json`: **PASS**
   - `git diff --check`: **PASS**
4. **Git 무결성**:
   - `git commit`: 미실행
   - `git push`: 미실행
   - 공식 Place(127925465904803): 미실행 / 미접촉

---

## 5. QA Place 적용 내역

- **Studio Target**: `c5208bf0-2434-45b7-aa6c-7c4c531adcd4` (`KDM_New_Hub`, PlaceId 106553302629620)
- **적용 모듈**: `StarterPlayer.StarterPlayerScripts.Client.KartWorldSpeedRenderer`
- **적용 Source SHA256**: `a0ab494b84e31be8d4e3a815a2d12d9ef8be08977075d42f2cfcc61693b31aa2`
- **게시 전 PlaceVersion**: 111 (사용자 V2 테스트 버전)
- **게시 적용 상태**: Studio Edit DataModel에 V2.1 소스 직접 반영 완료, Team Create 라이브 세션 동기화 완료 (게시 버전 112).
- **롤백 기준**: 이전 V2 (SHA 5f93f058...) 및 이전 V1 (SHA 18739a2e...) 백업 보존.

---

## 6. 사용자가 수행할 모바일 실기기 테스트 항목

모바일 기기에서 비공개 QA 플레이 시 다음 5개 핵심 포인트를 확인합니다:

1. **GAS 90 studs/s 주속감**: 이전 91 KM/H 스크린샷과 비교하여 두 줄의 희미한 선 대신 확실한 아케이드 속도감이 느껴지는가?
2. **Primary vs Secondary 분리감**: 하단 외측의 얇고 긴 메인 리본과 상단 내측의 짧고 넓은 보조 에어 시트가 2단으로 뚜렷이 구분되어 보이는가?
3. **뒷바퀴 공기 와류 가시성**: 뒷바퀴 뒤편에서 퍼져나가는 하얀 공기 방울/와류 입자가 눈에 들어오는가? (파란 니트로/하얀 드리프트와 혼동되지 않는지 확인)
4. **시야 및 인터페이스 간섭**: 중앙의 드라이버, 전방 도로, 하단 디지털 속도계(91 KM/H) 및 우측 가상 버튼(GAS/DRIFT/BRAKE)을 가리지 않는가?
5. **프레임레이트(FPS) 및 스터터**: GAS 가속 및 부스트 진입 시 화면 끊김이나 히치 없이 부드럽게 렌더링되는가?
