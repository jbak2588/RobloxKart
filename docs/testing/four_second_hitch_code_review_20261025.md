# Race Rematch 4초 끊김 코드 리뷰 — 2026-10-25

기준: `886d69afd9eaa7fbad97398da9e7b2181aaa8cd6` (origin/prototype/kart-physics와 일치).
검토 범위: src의 반복 타이머, 입력/물리/소유권, Room 갱신, Rematch 수명주기, HUD/VFX 및 기존 성능 진단. 이번 변경은 리뷰 문서만이며 런타임 수정/게시는 하지 않았다.

## 결론과 재현 조건

- 오너 최신 보고: **인간 대 인간에서도 정확히 4초 간격**으로 끊긴다. 1인+봇 전용 결함으로 한정하면 안 된다.
- 앞선 보고: Lobby로 나갔다 다시 입장하면 완화되며, Rematch 후 재발한다. 새 배치 시험에서도 약 10회 중 2회 발생했다. Park Replay에서는 같은 증상이 보고되지 않았다.
- 미니맵 상대 표시를 숨겨도 재현됐으므로 그 실험은 원인을 입증하지 못했다. 상대 표시는 복원되어 있다.
- **현재 코드에서 RACING 중 매 4초마다 실행되는 명시적 작업은 찾지 못했다.** 주기적 엔진/복제 동작이나 누적 부하를 배제한다는 뜻은 아니다.
- Rematch 데이터 누적, GC, 네트워크 소유권 재전환 중 어느 것도 현 시점에 확정할 수 없다. 실패 순간의 서버/양쪽 클라이언트 동시 캡처가 없다. 해결 판정은 OPEN이다.

## 확인된 코드 사실

| 경로 | 위치 | 실제 동작 / 판단 |
| --- | --- | --- |
| Room 상태 갱신 | src/server/RaceRoomCoordinator.luau:371–389 | `task.wait(5)` 뒤 MemoryStore 조회, publish 및 snapshot. 5초에 I/O 시간이 더해진다. 정확한 4초 타이머가 아니다. |
| 전역 presence | src/server/KDMServerPresence.luau:6 | heartbeat 9초. |
| 순위/지도 | src/shared/RaceConfig.luau:13, src/server/RaceController.luau:1350 | 0.10초 간격. session 갱신은 0.2초. |
| 입력 | src/client/KartInputController.luau:134, src/shared/KartConfig.luau:88 | 입력 유지 전송 0.25초, 서버 입력 만료 0.5초. 전송 공백이면 감속 원인이 될 수 있지만 그 공백 발생 자체는 미확인. |
| 개인 기록 조회 | src/server/RaceRecordService.luau:170 | 4초 **요청 제한**. 4초마다 호출하는 루프가 아니다. |
| 구 전술 UI | src/client/TacticalLoadoutController.luau:109 | 요청 후 단발 4초 timeout. 현재 client init에서 시작하지 않는 구 컨트롤러. 주행 주기 작업이 아니다. |
| 새 reserved job Rematch | src/server/RaceRoomCoordinator.luau:189–191 | quickMatch, 인간 1명+봇 1명, 대기/도착 예정 없음에만 적용. **인간 2명에는 적용되지 않는다.** 인간끼리는 기존 job의 다음 라운드를 사용한다. |
| 서버 소유권 | src/server/PrototypeWorld.luau:239,1351–1362 | 생성 시 및 착석 후 deferred Seat/Humanoid 관계 확인 후 `SetNetworkOwner(nil)`. 기존 승인된 PV931 보호가 남아 있다. 4초 주기 소유권 쓰기는 없다. |
| Controller 설치 | src/server/RaceController.luau:170–174,1293 | start guard와 단일 Heartbeat 경로. Rematch 경로가 매번 start를 호출해 Heartbeat를 추가하는 구조는 확인되지 않았다. |
| 카트 제거 | src/server/RaceController.luau:1106, src/server/PrototypeWorld.luau:1481 | context 해제 경로가 있으며 소유자 연결 해제/모델 제거를 수행한다. 정적 확인만으로 장시간 모든 객체의 무누수를 보증하지 않는다. |

## 후속 측정 우선순위

### 1. 소유권/복제 보정과 실제 시뮬레이션 중단 구분

PV931의 과거 증상과 유사하므로 우선 확인할 항목이지만, 재발 원인으로 단정하지 않는다. `SetNetworkOwner(nil)`은 유지한다. 클라이언트 소유권으로 바꾸거나 매 프레임 소유권을 쓰는 우회책은 적용하지 않는다.

기존 서버 진단 `src/server/RacePerformanceMonitor.luau:93–105`는 `GetNetworkOwner()`만 기록한다. **현재 소유자가 nil인 자동 모드와 수동 서버 모드를 구별하지 못한다.** 재현 캡처에 `GetNetworkOwnershipAuto()`와 두 인간 카트의 동일 시각 상태가 필요하다.

### 2. RACE 전용 Room 갱신과 클라이언트 작업의 상관관계

`RaceRoomCoordinator` snapshot은 참가자마다 사용 가능한 유저/초대 목록을 만들고 RoomSnapshot을 전송한다. `src/server/RoomSocialDirectory.luau:25–42`는 100개씩 전체 presence 페이지를 순회하며 총 페이지/반환 인원 상한이 없다. 온라인 규모에 따른 작업/페이로드 증가 후보다. **MemoryStore 호출의 yield 자체가 전체 물리를 멈춘다는 결론은 성립하지 않는다.** 5초 작업이므로 오너의 정확한 4초와도 아직 일치하지 않는다. 시작/종료/전송/수신 타임스탬프를 실제 끊김과 비교해야 한다.

`src/client/RaceHudController.luau:1173–1178`은 HUD 갱신 때 결과 화면이 닫힌 RACING에서도 결과 수집을 수행한다. `src/client/RaceResultsCache.luau:9–63`은 참가자 row/lap/liveKeys/정렬 배열을 새로 만든다. 불필요한 할당 후보는 맞으나 **4초 GC 정지의 증거는 없다.** 캐시는 session 변경 시 초기화하며 동일 참가자 key를 덮어쓴다. 단순히 결과 row가 Rematch마다 무한히 쌓인다는 증거도 없다.

### 3. Rematch 수명주기 실측

같은 job의 첫 경기와 2/3번째 경기에서 context 수, 카트/SeatWeld/Attachment/Trail/ParticleEmitter 수, 활성 연결/주기 작업 수 및 Lua 메모리 추이를 비교한다. 엔트리 재사용과 재생성 경로를 구분한다. 카트 수가 같다는 사실만으로 연결 누수가 없다고 판단하지 않는다. 인간 2명의 Rematch는 새 job 시험으로 검증된 적이 없다.

## 기존 진단의 한계와 재현 캡처 기준

- `src/server/init.server.luau:8`에서 내부 수집은 기본 false다.
- `src/client/RacePerformanceMonitor.luau:10`의 enabled는 모듈 로드시 결정된다. 입장 후 서버 attribute만 바꿔서는 기존 client 수집이 켜지지 않는다.
- `src/client/RacePerformanceMonitor.luau:153`은 본인 row만 수신한다. 두 기기의 캡처를 공통 서버 시각으로 결합해야 한다.
- 로그 경고에는 cooldown이 있으므로 경고 출력 개수/간격을 실제 끊김 횟수/간격으로 해석하면 안 된다.
- 기존 Studio 모의 반복/짧은 캡처 PASS는 이번 공개 인터넷 인간 2명 재현의 PASS가 아니다. 기존 근거는 rematch_hitch_followup.md 참조.

다음 실행 검증은 제한된 진단 계정에서 입장 전 수집을 켠 빌드로 수행해야 한다. 일반 공개 유저 전체에 고빈도 로그를 켜지 않는다.

1. 인간 2명, 같은 Race room에서 첫 경기 및 연속 Rematch를 실행한다. 양쪽 클라이언트와 서버에서 공통 `GetServerTimeNow()`를 기록한다.
2. 끊김 전후 프레임 dt/서버 Heartbeat dt/물리 step 시간, 실제·명령 속도와 위치, 입력 나이, owner ID와 auto 모드, Seat 상태, controls lock/reset serial을 보존한다.
3. 같은 구간에 RoomSnapshot 시작/전송/수신, HUD 처리 시간, 메모리 및 객체 수를 기록한다. 최소 연속 세 번의 끊김 간격을 수치로 확인한다.
4. client dt만 튀면 렌더/HUD/GC 경로, 서버 dt/step도 튀면 서버 작업 경로, dt는 정상이지만 위치 정체/되돌림이면 복제·소유권·입력·reset 경로를 추적한다. 이는 분류 기준이며 단일 지표만으로 원인을 확정하지 않는다.
5. 원인과 같은 시각에 발생한 작업만 제한적으로 수정하고 동일 조건으로 재검증한다. 10회 이상 Rematch 및 실제 인간 2명 재경기/배수 연속성도 별도로 확인한다. 미재현은 해결 확정으로 보고하지 않는다.

## 이번 검증 결과

- 정적 코드 리뷰 및 `git diff --check`: 수행.
- 게임 동작 변경: 없음. 따라서 기존 모바일 조작감/소유권/미니맵을 변경하지 않았다.
- 실제 인간 2명 동시 캡처/공개판 재현/수정 후 해소 검증: 미수행. **끊김 수정 PASS 아님.**
