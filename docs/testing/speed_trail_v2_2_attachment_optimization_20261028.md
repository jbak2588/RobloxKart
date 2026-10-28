# Speed Trail V2.2 — Attachment Position Optimization 보고서

- **판정 상태**: `PRIVATE_QA_PUBLISHED_DEVICE_PENDING`
- **대상 QA 환경**: Universe **10772198697** / Start Place **106553302629620** (`KDM_New_Hub`)
- **접근 권한**: Game Access: **Private** / Audience Reach: **Private**
- **공식 운영 환경**: Universe 10768420544 / Place 127925465904803 (일체 미접촉 / 변경 없음)

---

## 1. 긴 선의 정체 확인 (최초 진단 결과)

사용자의 실제 모바일 81 / 91 KM/H 주행 스크린샷에 나타난 긴 흰색/연하늘색 평행선을 정밀 진단했습니다:

1. **`DriftTireTrail` 및 스키드 마크 배제**:
   - `DriftTireTrail`은 검은색(`RGB 8, 9, 11`), 슬립 각도 5도 이상 및 `KartDrifting == true` 상태에서만 켜지며 수명은 1.4초입니다.
   - 캡처된 주행 화면은 직진 가속 상태(`KartDrifting == false`)이며 색상이 밝은 아이스 블루(`RGB 222, 243, 255`)입니다.
2. **`KDMSpeedTrail1` & `KDMSpeedTrail2` (Primary High Trail) 확인**:
   - V2.1의 Primary Attachment는 뒷바퀴 회전축(`Z = wheel.Center.Z`) 외측에 배치되었고, 하단점이 `yLow = wheel.Center.Y - 0.5`로 노면과 불과 0.2~0.25 stud 간격에 불과했습니다.
   - 높은 3인칭 추적 카메라(High Chase Cam)에서 보면 이 리본이 아스팔트 지면에 밀착된 채 뒤로 뻗어나가므로, 공기 흐름이 아니라 **"도로에 그어진 분필선" 또는 "타이어 궤적"처럼 보이는 착시**가 발생했습니다.
3. **해결 전략**:
   - 효과 강도나 리본 개수를 늘리지 않고, **Primary를 차체 후면 범퍼 모서리로 후퇴/상향**, **Secondary를 측면 상부 카울로 배치**, **Vortex를 타이어 후방 후류 영역으로 이동**하여 차체에서 공기가 분리되는 3D 공기 역학 궤적을 형성했습니다.

---

## 2. Attachment 변경 전후 좌표 비교표

### A. 단위계 및 차체 기준 좌표
- **Chassis 원점**: `(0, 0, 0)`
- **전후 축 (Z)**: `-Z` = 전방, `+Z` = 후방
- **수직 축 (Y)**: `+Y` = 상방, `-Y` = 하방 (지면은 바퀴 중심 대비 `Y ~ -0.74` ~ `-1.0`)
- **수평 축 (X)**: `-X` = Left, `+X` = Right

### B. 변경 전후 좌표 비교표 (Harness Mock 기준 / 실제 KDMV2Geometry 환산)

| 부착점 (Attachment) | V2.1 이전 좌표 (Harness / 실제) | V2.2 최적화 좌표 (Harness / 실제) | 물리적 위치 및 시각적 개선 의도 |
| :--- | :--- | :--- | :--- |
| **Primary Left**<br>`KDMSpeedPoint1_1`<br>`KDMSpeedPoint1_2` | X: -4.62 / -3.52<br>Y: [-0.50, +0.50] (중심 0.00)<br>Z: 3.00 / 2.69 | **X: -3.93 / -2.99**<br>**Y: [+0.35, +0.85] (중심 +0.60)**<br>**Z: 4.40 / 4.09** | **후면 범퍼 좌측 모서리**: 노면 밀착을 완전히 벗어나 범퍼 테일라이트 높이(+0.60)로 상승, 중앙 방향 15% 수렴, 범퍼 뒷면(Z +1.40)에서 방출 시작 |
| **Primary Right**<br>`KDMSpeedPoint2_1`<br>`KDMSpeedPoint2_2` | X: +4.62 / +3.52<br>Y: [-0.50, +0.50] (중심 0.00)<br>Z: 3.00 / 2.69 | **X: +3.93 / +2.99**<br>**Y: [+0.35, +0.85] (중심 +0.60)**<br>**Z: 4.40 / 4.09** | **후면 범퍼 우측 모서리**: 좌우 대칭, 배기구(X=±1.45) 바깥쪽 범퍼 코너에서 깔끔하게 뒤로 뻗어나가는 메인 속도선 형성 |
| **Secondary Left**<br>`KDMSpeedPoint3_1`<br>`KDMSpeedPoint3_2` | X: -3.40 / -3.40<br>Y: [+0.85, +1.45] (중심 +1.15)<br>Z: 2.30 / 1.99 | **X: -4.63 / -3.69**<br>**Y: [+1.05, +1.45] (중심 +1.25)**<br>**Z: 3.90 / 3.59** | **좌측 상부 카울 슬립스트림**: Primary보다 바깥쪽(+0.70 stud), 상단(+0.65 stud), 전방(-0.50 stud)에서 차체 어깨를 스쳐 지나가는 공기 띠 형성 |
| **Secondary Right**<br>`KDMSpeedPoint4_1`<br>`KDMSpeedPoint4_2` | X: +3.40 / +3.40<br>Y: [+0.85, +1.45] (중심 +1.15)<br>Z: 2.30 / 1.99 | **X: +4.63 / +3.69**<br>**Y: [+1.05, +1.45] (중심 +1.25)**<br>**Z: 3.90 / 3.59** | **우측 상부 카울 슬립스트림**: 모바일 카메라에서 Primary와 시각적으로 겹치지 않고 2층 입체 기류로 완전히 분리 |
| **Micro Vortex Left**<br>`KDMSpeedVortexPointLeft` | Position: (-4.58, -0.25, 3.15) | **Position: (-4.70, +0.25, 3.55)** | **좌측 뒷바퀴 후류 공간**: 바퀴 외측면 +0.20 stud, 바퀴 중심 상단 +0.25 stud, 바퀴 후방 +0.55 stud에서 타이어 회전 와류 분출 |
| **Micro Vortex Right**<br>`KDMSpeedVortexPointRight` | Position: (+4.58, -0.25, 3.15) | **Position: (+4.70, +0.25, 3.55)** | **우측 뒷바퀴 후류 공간**: 노면 접지선에서 벗어나 타이어 후류 분리 영역에서 깨끗한 공기 방울 생성 |

---

## 3. 수정 파일 및 실제 변경 Diff

### `src/client/KartWorldSpeedRenderer.luau`

```luau
@@ -120,23 +120,25 @@
-	-- Trails: index 1 & 2 = Primary flank ribbons; index 3 & 4 = Secondary upper cowl ribbons
+	-- Trails: index 1 & 2 = Primary rear bumper ribbons; index 3 & 4 = Secondary upper cowl slipstream
 	for index = 1, 4 do
 		local isPrimary = index <= 2
 		local side = if index % 2 == 1 then -1 else 1
 		local wheel = if side < 0 then wheels.Left else wheels.Right
+		local xPrimary = (wheel.Center.X + side * (wheel.Width * 0.5 + 0.12)) * 0.85
+		local zPrimary = wheel.Center.Z + 1.40
 		local x, yLow, yHigh, z
 		if isPrimary then
-			x = wheel.Center.X + side * (wheel.Width * 0.5 + 0.12)
-			yLow = wheel.Center.Y - 0.5
-			yHigh = wheel.Center.Y + 0.5
-			z = wheel.Center.Z
+			x = xPrimary
+			yLow = wheel.Center.Y + 0.35
+			yHigh = wheel.Center.Y + 0.85
+			z = zPrimary
 		else
-			-- Secondary: elevated above rear cowl/fender, inset to X=±3.40, clear separation from primary
-			x = side * 3.40
-			yLow = wheel.Center.Y + 0.85
+			-- Secondary: elevated above rear cowl/fender, wider and forward from primary
+			x = xPrimary + side * 0.70
+			yLow = wheel.Center.Y + 1.05
 			yHigh = wheel.Center.Y + 1.45
-			z = wheel.Center.Z - 0.70
+			z = zPrimary - 0.50
 		end
 		for edge = 1, 2 do
 			local attachment = Instance.new("Attachment")
@@ -194,3 +196,3 @@
 		local point = Instance.new("Attachment")
 		point.Name = "KDMSpeedVortexPoint" .. sideName
-		point.Position = Vector3.new(wheel.Center.X + side * (wheel.Width * 0.5 + 0.08), wheel.Center.Y - 0.25, wheel.Center.Z + 0.15)
+		point.Position = Vector3.new(wheel.Center.X + side * (wheel.Width * 0.5 + 0.20), wheel.Center.Y + 0.25, wheel.Center.Z + 0.55)
 		point.Parent = chassis
```

---

## 4. 인스턴스 예산 및 속도별 활성 효과

- **카트당 인스턴스 수**: **정확히 24개 고정** (초과 없음)
  - Trail: 4개 (`KDMSpeedTrail1..4`)
  - Speed Attachment: 8개 (`KDMSpeedPoint1_1..4_2`)
  - Micro Vortex Attachment: 2개 (`KDMSpeedVortexPointLeft/Right`)
  - Micro Vortex Emitter: 2개 (`KDMSpeedVortexLeft/Right`)
  - Jet Attachment: 2개 (`KDMSpeedJetPointExhaustLeft/Right`)
  - Jet Emitter: 6개 (`KDMSpeedJetCore/Plume/Spark` x 2)
- **프레임당 메모리 할당**: **0 bytes (Zero-Heap Allocation)**
- **속도별 활성 단계**:
  - `70 studs/s`: Primary 2개만 켜짐 (폭 0.18, 투명도 0.68)
  - `80 studs/s`: 4개 Trail + Vortex 초기 점등 (측면당 rate 2)
  - `85 studs/s`: 4개 Trail + Vortex 가속 (측면당 rate 6)
  - `90 studs/s`: 4개 Trail (Primary 폭 0.40, Secondary 폭 0.52) + Vortex 최대 (측면당 rate 8)
  - `후진/정차/드리프트/니트로/오프트랙/컨트롤 락`: 기존 속도 효과 즉시 억제 및 우선순위 준수

---

## 5. 자동 검증 및 회귀 결과

1. **VFX 단위 및 회귀 테스트**:
   - `tests/speed_world_vfx_validation.luau`: **PASS** (1,562 production checks + 22,236 V2 checks)
2. **Current Release Source Freeze**:
   - `tests/source_freeze_release_validation.luau`: **PASS** (683 integrity checks across 133 files)
3. **Current Release Contracts**:
   - `tests/current_release_contracts_validation.luau`: **PASS** (66 contract checks)
4. **전체 스위트 실행 결과**:
   - **Current Release: 229 PASS / 0 FAIL**
   - **Historical Freeze: 20 FAIL 보존 (신규 실패 0건)**
5. **Rojo Build & Whitespace**:
   - `rojo.exe build default.project.json`: **PASS**
   - `git diff --check`: **PASS**
6. **Git 정책 준수**:
   - `git commit`: 미실행
   - `git push`: 미실행
   - 공식 Place(127925465904803): 일체 미접촉 / 미수정

---

## 6. QA 배포 및 상태 확인

- **Studio Target**: `c5208bf0-2434-45b7-aa6c-7c4c531adcd4` (`KDM_New_Hub`, PlaceId 106553302629620)
- **적용 모듈**: `StarterPlayer.StarterPlayerScripts.Client.KartWorldSpeedRenderer`
- **수정 전 V2.1 SHA256**: `a0ab494b84e31be8d4e3a815a2d12d9ef8be08977075d42f2cfcc61693b31aa2`
- **수정 후 V2.2 SHA256**: `010aff42cb443994b04d51c53628d4ee9b4aea5da28a2c3606f801db1c3116ca`
- **적용 소스 길이**: 12,904 bytes (299 라인)
- **QA PlaceVersion**: 109 (Edit 세션 실시간 동기화 완료, 이전 Published v111/v112 보존)
- **접근 권한 확인**: Creator Dashboard 상 `Private` 상태 유지
- **공식 KDM Place (127925465904803)**: Version 1236 유지, 변경 없음

---

## 7. 사용자가 수행할 모바일 실기기 판정 항목

모바일 실기기(Android / iPhone) 주행 시 다음 5가지 시각적 핵심 사항을 확인합니다:

1. **노면 분필선 착시 해소**:
   - 80~90 studs/s 직진 가속 시, 메인 트레일이 도로 바닥에 그어진 선이 아니라 **카트 후면 범퍼 모서리(테일라이트 높이)에서 뒤로 뿜어져 나오는 공기 흐름**으로 명확히 인식되는가?
2. **Primary vs Secondary 층위 분리**:
   - 하단 내측(범퍼)의 뚜렷한 주 속도선과 상단 외측(카울 어깨)의 넓고 짧은 에어 리본이 서로 겹쳐 하나의 선으로 뭉개지지 않고 2개 층으로 구분되는가?
3. **Micro Vortex 후류 발생 위치**:
   - 뒷바퀴 접지면 바닥이 아닌, 타이어 바깥쪽 뒤편 상단에서 자연스러운 공기 와류 입자가 흩어지는가?
4. **차체와의 연결성**:
   - 트레일의 발생 시작점이 차체와 부자연스럽게 떨어져 공중에 떠 있는 레이저처럼 보이지 않는가?
5. **HUD 및 시야 간섭**:
   - 중앙 드라이버, 전방 주행 도로, 하단 디지털 속도계(KM/H) 및 우측 가상 버튼에 대한 간섭이 없는가?

