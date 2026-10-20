# H1-FINAL Shared HUB Test Drive Social Discovery — final review

> **사용자 후속 수정 — 2026-10-20:** 현재 공유 시승장은 같은 HUB 서버에 연결된 이용자만 공유하며, 여러 HUB 서버의 이용자를 한곳에 모으는 구조가 아니다. 요청에 따라 `DEMO · NOT A PLAYER` 배지와 `LIVE TEST DRIVE` 안내판 전체(판면·프레임·기둥·받침), 안내판 텍스트 갱신을 제거했다. 기존 시승·내부 인원 집계·카메라·데모 주행·효과 메시지·키오스크·TEST DRIVE 버튼은 보존했다. 아래 표지/배지 설명과 캡처는 제거 전 검증 이력이다. `C:/dev/KDM_H1_Final.rbxl` 및 `.rbxlx`는 제거된 상태로 다시 생성한다. Publish는 수행하지 않는다.

후속 제거 검증: Presence 33, 서비스 통합 27, builder 4593, demo 391410, driving polish 39551, showroom 38, wall/qualification 73 checks PASS. Production 197개 컴파일, Rojo 두 형식 빌드, diff 검사 PASS. 격리 Studio(GameId/PlaceId=0)에서 안내판 네 부품 및 DemoIdentity 미생성, 데모 모델·기존 TEST DRIVE Prompt 유지 확인. 이번 제거에서는 관련 7 suites를 재실행했으며, 아래 204 suites 결과는 직전 H1-FINAL 전체 실행 이력이다.

기준: `prototype/kart-physics`, Local/Origin HEAD 모두 `fbf334e15aec62d8d3834c2d5589c43e30fee235`. 최종 작업 시작 시 origin을 fetch하고 HEAD 일치를 확인했다. 기존 H1 미커밋 파일 12개를 ZIP으로 보존한 뒤 최소 수정했다. 사용자는 검증 후 H1만 Commit / Push하도록 승인했다. **Roblox Publish는 금지되어 수행하지 않는다.**

## 구현

- HubSpawn 위치·방향, 기존 쇼룸 7대, 출입구·키오스크·Prompt는 보존했다. 초기 카메라가 기존 시승장 입구를 한 번 바라보도록 목표 방향만 변경했다. CameraType.Custom / Humanoid subject로 즉시 반환하며 카메라 투어나 고정 RenderStepped 제어를 추가하지 않았다.
- 서버 `LobbyTestDriveService`가 소유하는 records를 읽는 `LobbyDrivePresence`를 추가했다. 실제 캐릭터·생존 Humanoid·양쪽 Seat 점유·같은 zone의 카트·LobbyDriveActive·GARAGE 상태를 모두 확인한다. 봇과 쇼룸은 이 records에 없으므로 집계하지 않는다.
- 기존 낮은 8×1.8 stud 패널을 램프 옆 고정형 양면 SurfaceGui 표지로 마무리했다. 판면은 8.8×3.3×0.24 studs, 프레임은 9.04×3.54×0.18 studs이며 작은 포스트/베이스를 사용한다. 위치는 HubSpawn 기준 X−11, Z−38, ground top+4.9이다(이전 X−10, Z−26, top+3.5). 판면 투명도 0.25→0.08, 640×240 canvas에 제목 58px/보조문구 34px와 Cyan 강조선을 사용한다(이전 640×144/27px). 전체 프레임 오른쪽 끝도 보행 폭 바깥이고 Prompt는 변경하지 않았다. 네 부품 모두 비충돌·비접촉·비쿼리·그림자 없음, 양면 표시 거리 100 studs. 신규 버튼·HUD·Billboard는 없다.
- 실제 인원 0은 서버 Attribute에 그대로 남고 `LIVE TEST DRIVE / WATCH THE DEMO · TRY DRIVING`을 표시한다. 1명은 `1 PLAYER DRIVING / JOIN THE ACTION`, 복수는 `N PLAYERS DRIVING / JOIN THE ACTION`이다. 같은 count에서는 텍스트/Attribute를 다시 쓰지 않는다.
- 탑승 성공 및 기존 stop의 records 제거 시점에만 집계한다. 같은 값이면 Attribute/Text를 다시 쓰지 않는다. 새 인원 표시용 Heartbeat, RemoteEvent, 영구 저장은 없다. 늦게 들어온 관찰자는 현재 Attribute 및 표지 Text를 복제받는다.
- 기존 1개 데모 모델에 거리 제한된 `DEMO · NOT A PLAYER` 식별만 추가했다. 효과 메시지와 같은 6-stud 기준점에서 SizeOffset Y=1.125를 사용해 화면상 중심 간격 36px(높이 32px + 여유 4px)을 유지한다. 거리로 인해 두 배지가 겹치는 문제를 피하며, 데모 경로·수량·이펙트 LOD·사운드는 변경하지 않았다.
- 시승 시작 슬롯·서버 주행·충돌 그룹·아이템·경제·저장 스키마와 LobbyPostDriveView / QuickStart 흐름은 보존했다. 시승 중 RACE NOW는 이번에 추가하지 않았다.

## 실제 Studio 로컬 검증

운영 Place에서 Play하지 않고, Rojo 로컬 빌드를 열어 **GameId=0 / PlaceId=0**을 먼저 확인했다. 운영 API 접근도 꺼져 있음을 사용자가 확인했다. 격리된 로컬 서버와 실제 Studio 클라이언트 Player1–4(UserId -1…-4)를 사용했다. 운영 프로필은 읽거나 수정하지 않았다. 로컬 PlayerPreferences의 `DataStore unavailable`은 이 환경의 예상 상태다.

| 항목 | 결과 / 증거 |
|---|---|
| 신규 단독 HUB | 실제 봇 모델 1개, 식별 문구 표시, count=0, LobbyDriveActive=false |
| 동일 서버 두 클라이언트 | Player1 탑승 후 Player2에서 LobbyKart_-1 / Seat.Occupant / `1 PLAYER DRIVING` 확인. observer.png |
| 늦은 입장 | Player1 주행 중 추가한 클라이언트에 현재 카트와 count가 복제됨 |
| 네 클라이언트 동시 탑승 | 실제 Seat 점유 4개, 서버 카트 4대 / count=4, 서로 다른 시작 위치. four.png |
| 타 사용자 움직임 / 드리프트 | 관찰 클라이언트에서 실제 원격 카트 이동 및 KartDrifting=true를 샘플링해 둘 다 확인. 다른 사용자 카트에 DriftSmoke / DriftTireTrail 렌더러도 존재. 기존 remote_world_vfx 검증 PASS. 각 이펙트의 실기기 화질 판정은 별도 |
| 비충돌 | 서버 PhysicsService에서 LobbyKart↔LobbyKart 충돌 false 확인 |
| 독립 하차 | 실제 RETURN LOBBY 버튼으로 한 명만 하차, 다른 카트 유지. 이후 본인 카트 제거 확인 |
| 사망 / 재탑승 | Player3 사망 후 해당 카트 제거. 리스폰 뒤 재탑승도 성공 |
| 레이스 이동 정리 | 격리 서버에서 기존 RACE_LAUNCH 상태 전환을 주어 해당 카트 / count 정리 확인. 실제 예약 서버 텔레포트와 구분 |
| 접속 종료 | 탑승한 로컬 Player1을 테스트 목적으로 종료한 뒤 Players에서 제거되고 해당 카트도 제거됨 |
| 최종 정리 | 남은 접속자 3명, count=0 / 잔여 시승 카트=0. 이후 로컬 서버/클라이언트 세션 종료 |
| 종료 후 RACE NOW | 기존 서버 QuickStart 진입 로그 확인. 로컬 예약 서버 할당 HTTP 403으로 실제 매칭·텔레포트 완료는 NOT VERIFIED |

실제 두 사람이 접속한 게시 버전 검증이나 실기기 60 FPS 확인으로 표시하지 않는다. 네 클라이언트는 같은 PC의 Studio 프로세스다. 정상 입력만 사용했고 경제 중복 지급 요청이나 테스트용 영구 데이터를 생성하지 않았다.

## 성능 / 화면

2명 탑승 및 4명 탑승 상태에서 각각 5초, 300개의 서버 Heartbeat 간격을 측정했다. 입력 부하와 실제 모바일 GPU 성능 시험을 대신하지 않는 짧은 로컬 기본 안정성 측정이다.

| 탑승자 | p50 / p95 / max |
|---|---|
| 2 | 16.91 / 18.01 / 19.12 ms |
| 4 | 16.93 / 18.07 / 18.98 ms |

인원 모듈 단위 테스트는 4-record 집계를 10,000번 호출해도 값이 같으면 복제 쓰기가 추가되지 않음을 확인했다(이벤트 호출 비용 시험이며 FPS 시험이 아님).

PC HD1080 1920×1080, iPhone13 가로 844×390, 사용자 지정 가로 932×430·1102×485를 실제 Studio 에뮬레이터에서 확인했다. 기존 5개 내비게이션 버튼은 44px 클릭 높이를 유지하고 중앙과 모바일 조작 영역을 침범하지 않는다. 새 표지는 비대화형 월드 오브젝트이므로 UI Safe Area/터치 영역을 추가 점유하지 않는다. 844는 notch 기기이며 다른 두 크기는 cutout 없는 사용자 지정 기기다. Windows 배율과 native inset 때문에 캡처 픽셀 크기/Camera.ViewportSize가 기기 설정 수치와 다를 수 있다.

캡처: `artifacts/h1-social/captures.md` 및 PNG. before-spawn / afterSpawn은 실제 초기 시점 전후, before-entry / pc-entry는 같은 위치에서 입구 비교(종횡비는 다름). observer / four는 실제 로컬 다중 클라이언트, 844 / 932 / 1102 / pc는 각 기기 설정에서 촬영했다. 시각 검토를 위해 일부 캡처는 카메라를 일시 지정했으며 제품 카메라 투어 코드가 아니다. 사용자 지정 `H1 Social Preview`는 로컬 검토용 에뮬레이터 프리셋으로 남겼다.

## 자동 검증

- 전체 **204 suites: 163 PASS / 기존 41 FAIL / 신규 FAIL 0**. 기준 final-release 실행과 실패 집합 동일. `artifacts/h1-final/regression/summary.json` (최종 재실행).
- 새 presence 검증 33 checks, 실제 서비스 코드 + 모의 Players/Seat lifecycle 검증 27 checks PASS. 4인 슬롯, 늦은 입장, 상태 전환, 제거, 재탑승을 포함한다.
- 기존 service/builder 테스트 4개는 새 모듈 의존성과 Vector2/UDim2 환경만 보충했다. 기존 assertion을 제거하거나 완화하지 않았다.
- Production Luau **197개 컴파일 PASS**, Rojo XML/바이너리 빌드 PASS, `git diff --check` PASS.
- 경제 / P0 / 레이스 소스는 수정하지 않았다. 기존 41 FAIL을 PASS 처리하지 않았다. 범위 밖 과거 UI·VFX assertion의 상세 판정은 F60+P0 release 보고서에 남아 있다.

최종 로컬 검토 빌드: `C:/dev/KDM_H1_Final.rbxl` 및 `.rbxlx`. 임시 캡처·로그·프로필·빌드는 커밋 대상이 아니다.

## 변경 파일

Production: `src/server/LobbyDrivePresence.luau`(추가), `src/server/LobbyTestDriveService.luau`, `src/server/LobbyFrontDriveZoneBuilder.luau`, `src/client/HubArrivalCameraController.luau`, `src/client/LobbyDemoController.luau`.

Tests: `tests/h1_drive_presence_validation.luau`(추가), `tests/h1_shared_drive_service_validation.luau`(추가), `tests/lobby_driving_polish_validation.luau`, `tests/lobby_reference_oval_builder_validation.luau`, `tests/lobby_showroom_test_drive_validation.luau`, `tests/lobby_wall_service_validation.luau`. 이 검토 문서를 포함해 총 12개 로컬 변경 파일.

## H2 최소 설계안 — 구현하지 않음

단순히 HubUiController.onRaceNow의 LobbyDriveActive 거부 조건을 제거하지 않는다. 기존 MatchRoomService의 QuickStart는 이미 stopLobbyDrive를 호출하므로 동일 서버 권한 경로를 재사용한다.

1. 시승 중 CTA는 한 개의 요청 의도만 만들고, 기존 매칭 요청의 중복 방지/진행 상태를 재사용한다. 별도 Stop 요청과 QuickStart 요청을 클라이언트에서 동시에 보내지 않는다.
2. 서버가 admission / 현재 room·invite·queue·launch·character 세대를 검사한 뒤 기존 stopLobbyDrive를 호출한다. 실제 좌석 해제, LobbyDriveActive/Pending 해제와 카트 제거가 끝난 것을 확인한 후 ensureSelection → 기존 QuickStart 예약/이동으로 진행한다. 현재 helper의 반환값만으로 실패까지 성공 취급하지 않도록 명시적인 종료 결과를 설계한다.
3. Seat 해제 timeout, 사망·리스폰, 초대 수락과의 경쟁, 빠른 재탭은 취소/재시도 가능한 한 개의 상태 전환으로 처리한다. 실패 시 안전한 HUB 상태에서 기존 재시도 UX를 사용하며 새 보상·차감·영구 상태를 만들지 않는다.
4. 검증은 느린 SeatWeld 해제, 빠른 중복 탭, 초대/이탈 경쟁, 할당 실패 및 실제 게시된 HUB→예약 RACE 이동을 포함한다. count 정리는 H1의 기존 stop hook을 그대로 사용한다.

H1-FINAL 승인 범위에 따라 위 12개 H1 파일만 선택적으로 Commit / Push한다. 임시 빌드·캡처·로그·백업은 제외한다. Roblox Publish와 Drift Park 도로/레이스 트랙 수정은 수행하지 않는다.


## H1-FINAL 최종 재검증 — 2026-10-20

위의 초기 H1 다중 클라이언트 검증을 보존하면서, 최종 소스로 다시 GameId=0 / PlaceId=0 로컬 서버와 Player1–4를 실행했다. 운영 Place는 Edit에 남겼다.

| 최종 확인 | 결과 |
|---|---|
| 0명 | count=0, LIVE TEST DRIVE / WATCH THE DEMO · TRY DRIVING. 데모 제외 |
| 1명 | Player1 실제 탑승, 두 면 모두 1 PLAYER DRIVING / JOIN THE ACTION |
| 늦은 입장 | Player2가 count=1과 LobbyKart_-1을 복제받음. Player4도 입장 시 count=3과 기존 카트 확인 |
| 4명 | 실제 Seat 점유 4개 / 카트 4개 / count=4, 시작 위치 20/808, 20/816, 20/824, 36/808 |
| 타 사용자 주행 | Player2에 2.5초간 정상 20Hz Input을 전송. Player1 관찰에서 원격 카트 이동 확인, 드리프트와 다른 카트들이 보이는 캡처 확보 |
| 독립 하차 | Player2 Stop 후 count=3, 다른 사용자 Active 유지 |
| 사망 | Player3 사망 후 count=2, 해당 카트 제거 |
| 레이스 이동 상태 | Player4 RACE_LAUNCH 전환 후 count=1, 해당 카트 제거. 실제 예약 서버 텔레포트 검증은 아님 |
| 마지막 하차 | Player1 Stop 후 count=0, 시승 카트=0, 접속자 4명 유지, 표지 demo 안내 복귀 |
| 카메라 | 최초 입장 Custom / Humanoid subject 유지. 시각 촬영을 위해 테스트 중 임시 카메라를 지정했으며 제품 카메라 로직은 재변경하지 않음 |
| 종료 | 검증 후 로컬 서버와 네 클라이언트 세션 종료 |

최종 PC 1920×1080과 모바일 프리셋 844×390, 932×430, 1102×485에서 실제 Studio 캡처를 재확보했다. Native inset을 제외한 Camera.ViewportSize는 각각 1920×1080, 750×390.4(notch), 932×410.4, 1102.4×464.8이며 Windows 배율 때문에 PNG 크기도 다르다. 기기 설정 해상도와 렌더링 영역을 혼동하지 않는다. 모바일 버튼·지갑·프로필 위치는 보존되고 표지는 터치 UI를 추가하지 않는다. 근접 화면에서 두 줄이 잘리지 않으며, 1명 문구 TextBounds 458.4×57.6 / 보조 256.8×33.6은 각 영역 601.6×115.2 / 601.6×57.6 안에 들어간다.

최종 캡처 갤러리: `artifacts/h1-final/captures.md`. before-entry와 844-final-exterior는 같은 카메라 위치/목표점에서 촬영했지만 874와 844 프리셋 차이가 있다. PC 내부 시점은 `pc-interior-clear.png`를 기준으로 한다. 일부 시험용 interior 캡처는 중앙 기둥에 가려져 최종 대표 이미지에서 제외했다. 초기 Spawn에서는 출입구와 주행 장면이 보이지만 표지 세부 문구는 접근할수록 읽기 쉽다. 더 넓은 주행 장면 노출은 후속 Drift Park 지형 설계 과제로 남기며 카메라 강제 투어는 추가하지 않았다.

전체 최종 회귀 **204 suites: 163 PASS / 기존 41 FAIL / 신규 FAIL 0**이며 실패 집합이 F60/P0 기준과 같다. Presence 33, 서비스 통합 27, 실제 builder 4605 checks PASS. Production Luau 197개 컴파일, Rojo XML/바이너리, git diff --check PASS. 원본 source-hash manifest 대비 바뀐 기존 production 소스는 H1의 네 파일뿐이며 새 Presence 모듈 하나가 추가됐다. F60 조명·UI·P0 경제·DataStore·VFX·물리·매칭 코드는 그대로다. 41개 실패를 수정/무시/PASS 처리하지 않았다. 각 원인과 기존 위험은 `final_release_f60_p0_20261020.md`에 기록된 판정을 유지한다. 이번에 신규 중대 회귀는 확인되지 않았다.

실기기 새 버전 검증 및 공개 HUB→예약 RACE 텔레포트는 이번 로컬 검증 결과에 포함하지 않는다. H1-FINAL은 Publish하지 않는다.
