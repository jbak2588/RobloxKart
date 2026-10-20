# KDM P0 — DNF 예외 경로 및 자동 리필 서비스 통합 보완

2026-10-20. 로컬 보완 완료. **Commit/Push/Roblox Publish/운영 서버 재시작 없음. 운영 DataStore 접근·변경 0.**

## 결론

독립 검토에서 지적한 실제 회귀를 확인했다. P0의 EconomyOperations.dnf는 유효한 RoundGuid와 발급 시각을 요구하지만, 기존 RaceController는 선택적 RaceRecordService.begin이 이를 만들 것으로 의존했다. 기록 서비스 없음/로드 실패/begin 예외일 때 레이스는 진행하지만 ACTIVE_DNF_COMPLETION의 기존 1,500이 지급되지 않았다.

수정 전 Controller와 실제 P0 EconomyService/Operations/Adapter를 조합한 red probe에서 모의 잔액 **10,000 / 누적 획득 0**을 확인했다. 수정 후 세 실패 경로 모두 **11,500 / 누적 획득 1,500**, 같은 ID 재시도에서도 추가 지급 0이다. 단순 복사한 보상 함수로 검증하지 않았다.

## 최소 수정

1. **RaceController**: 실제 GO 시점에 서버 HttpService GUID와 서버 UTC milliseconds를 한 번만 발급한다. 모든 GO 참가자의 OfficialRoundGuid/OfficialRoundIssuedAt 및 서버 racer.transactionIdentity에 같은 불변 값을 먼저 설정한다. COUNTDOWN 중 이탈자는 제외한다. 이후 선택적 records.begin에 이 값을 전달한다.
2. **RaceRecordService.begin**: 자체 GUID/시각 재발급을 제거했다. Controller의 식별자를 검증하고 공식 collector가 그대로 사용한다. 정상 경로에서 GUID 생성은 여전히 라운드당 1회다. 관찰자 실패가 주행·경제 식별자 발급을 막지 않는다.
3. **활성 DNF 비동기 작업**: task.spawn 전에 해당 racer의 불변 식별자를 캡처하고 EconomyService.creditReward의 서버 내부 인자로 전달한다. 리매치/새 라운드가 먼저 도착해도 옛 작업이 새 식별자로 지급되지 않는다. 옛 지급이 새 라운드의 RaceMoneyState/RaceActiveDnfBonus를 덮어쓰지 않도록 GUID를 확인한다. 지갑의 정상 저장·복제는 유지한다.

EconomyOperations.dnf의 1,500 금액/ACTIVE_DNF_COMPLETION reason/24시간 수명/동일 프로필 영수증 계약은 변경하지 않았다. 기존 활성 판정인 on-road, not crashed, speed >=15, completedLaps >=1도 그대로다. 비활성 timeout은 여전히 지급 0이다. 공식 기록 observer 장애 시 공식 기록 저장 자체를 성공했다고 표시하지 않으며, 이번 보완은 경제 식별자의 의존성만 제거한다.

ShopService/ShopOperations는 이번 보완에서 수정하지 않았다. normal race에서 RaceState=RACING 이벤트가 발생하기 전에 OfficialRoundIssuedAt을 제공하므로 기존 자동 리필이 동일한 서버 라운드 시각을 사용한다.

## 신규 서비스 통합 검증

`tests/p0_race_identity_integration_validation.luau`는 기존 deterministic four-player fixture를 기반으로 실제 RaceController와 실제 EconomyService/EconomyOperations/ProgressionDataStoreAdapter, ShopService/ShopOperations를 실행한다. NORMAL에서는 실제 RaceRecordService/OfficialRaceRecords까지 사용한다.

Roblox 플랫폼 I/O(시각/GUID/DataStore/신호·스케줄러/카트 이동)와 RaceItemController의 voucherTarget/applyVoucher 경계만 모의 처리했다. 운영 서버·실기기 검증이라고 주장하지 않는다. 기존 실제 RaceItemController 검증도 전체 회귀에서 별도로 실행했다.

| 조건 | 검증 결과 |
|---|---|
| RaceRecordService 모듈 없음 | 실제 레이스 GO, identity/time 유효, 활성 DNF 1,500 1회 PASS |
| 모듈 require 실패 | optional pcall 경로 이후 동일 보상 PASS |
| begin 예외 | observer 비활성화 경고 후 동일 보상 PASS |
| 정상 실제 observer | collector와 경제 경로 GUID/시각 일치, 라운드당 GUID 1개 PASS |
| 지연 DNF 작업 직전 새 라운드 attrs 도착 | 원래 라운드 영수증에 지급, 새 HUD 상태 보호 PASS |
| DNF UpdateAsync 저장 성공 후 ACK 유실 | uncached read-back 확인, 동일 ID 재시도 추가 지급 0 PASS |
| 비활성 timeout | 기존 무보상 정책 PASS |
| 실제 Rematch GO | 새 GUID/새 시각 발급 PASS |
| 정상 자동 리필, RESERVED ACK 유실 | 실제 ShopService 재확인 후 FINALIZE, stock 1회 소모·runtime charge 1회 PASS |
| 같은 라운드 같은 아이템 재시도 | 두 번째 stock 소모·charge 지급 없음 PASS |
| 예약 직후 사용 자격 소실 | 실제 REFUND_REFILL로 stock 원복, 재환불 없음 PASS |
| FINALIZE 후 runtime 적용 실패 | 실제 REFUND_UNUSED_REFILL로 원복 PASS |

신규 suite 결과: **MISSING 29 / LOAD_FAILURE 29 / BEGIN_FAILURE 29 / NORMAL 65 checks PASS** (총 152). 전체 로그에 실제 모듈 호출과 uncached store/API-shape 검증을 포함한다. begin fault의 observer unavailable 경고는 의도된 fault injection 결과다.

## 전체 검증

- **202 suites: 161 PASS / 기존 41 FAIL / 신규 실패 0.** 보완 전 P0의 201개(160 PASS/41 FAIL)에 신규 통합 suite 1개가 추가됐다. 기존 실패를 수정·완화하지 않았다.
- `datastore_idempotency_validation`: 기존 **75 checks / 10,000회 장기 모형 PASS**.
- 기존 two-player/four-player/controller observer, records runtime, shop, race item, checkpoint/DNF, mobile 입력 관련 검증은 전체 결과에 기록돼 있다.
- Production **196 Luau 파일 컴파일 PASS**.
- `git diff --check` PASS.
- Rojo XML/바이너리 PASS: `C:/dev/KDM_P0_Exceptions_Review.rbxlx`, `.rbxl`.

독립 GUID/시각 API가 Controller로 이동했으므로 기존 controller fixture 6개에 플랫폼 API mock을 추가했다: two_player_race, four_player_race, persistent_room_race, reserved_arrival, reserved_match, race_mode. 기존 assertion과 gameplay 수치는 그대로다. 실제 API가 없는 모의 환경을 위해 필요한 입력 의존성만 추가했으며 실제 코드에 가짜 GUID/로컬 counter fallback을 넣지 않았다.

## 보존 및 Git

시작 fetch 후 Local/Origin HEAD 모두 `5f9fe3eaec0b8a98abaa137bae54ba3d2e07ffa4`, branch `prototype/kart-physics`. 시작 상태/후보 전체 백업: `artifacts/p0-economy-exceptions/start-status.txt`, `pre-followup.zip`.

F60 전 파일을 기존 P0 시작 백업과 비교해 **바이트 동일**함을 확인했다. 로비·조명·Nitro·물리·모바일 조작·Bot/AutoStart 정책을 변경하지 않았다. 보완 production 변경은 RaceController/RaceRecordService/EconomyService 3개뿐이다. 기존 P0 후보 변경은 보존했다.

## 최종 Diff와 증거 경로

- 이번 보완만의 Diff: `artifacts/p0-economy-exceptions/followup.diff` (보완 전 P0 후보 대비).
- 현재 P0 통합 Diff: `artifacts/p0-economy-exceptions/consolidated-p0.diff` (HEAD 대비 P0 source/tests/docs만; F60 제외).
- 수정 전 실제 미지급 재현: `red-probe.luau`, `red-probe.log`, `pre-fix-RaceController.luau`.
- 전체 결과/로그: `regression/results.json`, `regression/summary.json`, 각 suite `.log`.
- F60 보존 증거: `f60-preservation.json`.

원래 P0 검토 보고서 `docs/testing/p0_economy_idempotency_review.md`는 보완 전 checkpoint로 보존한다. 이번 보고서가 경제 식별자 소유권과 최신 테스트 수치를 갱신한다. 배포는 미실행이며, 추후 별도 승인된 배포 시 구버전 영수증 삭제 서버의 동시 종료가 필요하다는 기존 제약도 유지된다.
