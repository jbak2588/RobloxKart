# KDM P0 — Economy Idempotency & Bounded Storage 검토본

2026-10-20. **로컬 구현 및 검증 완료 / 사용자·ChatGPT 검토 대기. Commit, Push, Roblox Publish 없음. 운영 DataStore 접근·수정·삭제·일괄 재작성 없음.**

## 1. Git 및 F60 보존

시작 시 origin fetch 후 Local/Remote HEAD 모두 `5f9fe3eaec0b8a98abaa137bae54ba3d2e07ffa4`, 브랜치 `prototype/kart-physics`. 시작 상태와 diff 통계를 `artifacts/p0-economy/start-status.txt`, `start-diff-stat.txt`에 기록했다. `AGENTS.md`를 확인했다.

시작 시 존재하던 모든 F60 변경·신규 파일을 `f60-preserved.zip`에 백업하고 작업 후 전 파일 바이트 일치를 검사했다. **F60 파일 변경 0**. 기존 UI·조명 작업을 다시 수행하지 않았다. P0의 `GarageShopController` 변경은 서버 티켓 요청/재시도 통신뿐이며 레이아웃·버튼·텍스트·가격은 변경하지 않았다.

## 2. 원인과 A/B/A 재현

기존 `pruneAndCompressReceipts`는 `maxReceipts >= 1000`이면 현재 키를 제외한 모든 영수증을 삭제했다. 운영 기본값은 16384이므로 다른 거래가 끼어들 때 이전 중복 방지 증거가 사라졌다. 구매·선택·리필 예약에도 같은 위험이 있었다. 별도로 선택 저장은 압축된 SHA-256 영수증을 평문으로만 비교해 확인 실패가 가능했다.

기존 재현 프로브: A 30,000 → B 33,500 → A 재시도 **37,000 / APPLIED**. 수정 후 동일 프로브: **33,500 / REPLAY**, 추가 지급 0. `artifacts/p0-economy/aba-reproduction.log`.

## 3. 거래 수명과 신뢰 경계

영수증 개수 1/2/40/100 유지 정책을 사용하지 않는다. 정상 신규 거래는 서버가 발급한 수명 정보 `transaction={version=1,issuedAt=...}`를 갖고, 프로필의 `receiptPolicy={version=1,floor,migratedAt}`를 사용한다.

- 재시도 수명은 **24시간**, clock future allowance는 30초다. `floor=max(기존 floor, 서버 현재 시각−24시간)`으로 후퇴하지 않는다.
- 영수증이 있으면 기존 Canonical/SHA 서명을 확인해 REPLAY/확정한다. 재지급하지 않는다.
- 영수증이 없으면 서버 권한 문맥을 요구하고 `issuedAt <= floor`인 요청을 거부한다. 삭제된 영수증이 없다는 사실을 신규 거래 근거로 사용하지 않는다.
- 유효한 신규 거래의 보상/차감/보유품/영수증/정리 기준은 **같은 프로필 UpdateAsync**에서 원자적으로 반영된다. 별도 거래 DataStore를 만들지 않았다.
- 완료 거래는 재시도 수명이 끝났을 때만 정리한다. 현재 영수증만 남기는 삭제 코드는 제거했다.
- 단순 개수 초과나 큰 프로필은 안전한 거부를 우선한다. `maxReceipts=16384`, `maxBytes=3000000` 유지. 활성 영수증을 강제 삭제하지 않는다. 이후 만료된 완료 거래가 정리되면 정상 신규 거래가 계속 진행된다.

모든 운영 바인딩(EconomyService, ShopService, RaceRecordService, ProgressionLiveCoordinator)은 신뢰 가능한 서버 UTC millisecond clock을 주입한다. **시각이 없는 기존 순수 offline fixture 모드에서는 정리를 하지 않고 개수/용량 상한에서 거부한다. 이 모드는 운영 경로가 아니다.** 운영 문맥 없이 누락된 영수증을 새 거래로 처리하지 않는다. 이 구분과 운영 바인딩의 clock 주입은 향후 호출자를 추가할 때도 유지해야 한다.

### 레이스

RoundGuid는 기존 서버 collector의 불변 ID다. 거래 발급 시각은 서버 collector의 `achievedAt`과 같아야 한다. 재시도할 때 현재 시각으로 갱신하면 `TRANSACTION_TIME_MISMATCH`로 거부한다. 클라이언트에서 공식 결과·RoundGuid·완료 시각·거래 문맥을 받는 경로는 추가하지 않았다.

기존 보상 계산 블록은 HEAD와 **바이트 동일**함을 검사했다. 순위 보상, 최소 완주 보상, PB 보너스, 첫 완주 K$5,000 조건·금액을 변경하지 않았다. 기존 ACTIVE_DNF_COMPLETION 1,500 지급 경로에도 RoundGuid 영수증과 read-back 확인을 추가했다. 금액이나 지급 판정을 변경한 것이 아니라 기존 별도 신용 경로의 재시도 중복을 차단한 것이다.

### 구매 및 선택

Shop은 클라이언트 생성 UUID를 신규 차감 권한으로 인정하지 않는다. 기존 구매 확인 후 통신 내부에서 PREPARE로 서버가 발급한 GUID를 받고 동일 GUID로 실행/재시도한다. 티켓은 사용자·상품·행동·값에 결합되고 서버 메모리에서 검증한다. 사용자당 최대 32개/10분이며 만료·퇴출된 UUID를 새 시각으로 재발급하지 않는다. 클라이언트가 Shared 함수로 별도 ticket book을 만들어도 운영 서버의 닫힌 인스턴스와 무관하므로 권한이 생기지 않는다.

재접속/서버 재시작/티켓 만료 후에도 동일 영수증이 있으면 **읽기 전용 확인**은 가능하다. 티켓도 영수증도 없으면 차감 reducer를 실행하지 않고 거부한다. 미확정 구매를 다른 ID로 자동 재발급하지 않는다. 무제한 재시도는 지원하지 않으며, 수명 밖 미확정 요청에는 명시적 실패가 온다.

선택은 서버 발급 operation ID와 기존 expectedSelectionRevision CAS를 유지한다. 영수증이 정리되어도 과거 Revision은 CONFLICT여서 오래된 선택이 덮어쓰지 못한다. 선택 생성·확인 모두 평문 Canonical과 SHA-256을 동일하게 식별한다. 새 서명에서는 거래 수명 문맥을 분리하여 기존 사업 내용의 서명과 호환한다.

## 4. 자동 리필 예약

RESERVED이면서 미환불인 영수증은 나이와 관계없이 정리하지 않는다. 동일 라운드/아이템 키와 기존 라운드 총 2개·아이템당 1개 제한을 유지한다. 새 리필의 시간은 OfficialRoundIssuedAt에 고정하여 오래된 라운드에 새 시간을 붙이지 않는다.

FINALIZE/REFUND/REFUND_UNUSED는 **존재하는 예약만** 처리한다. 새 거래 권한을 생성하지 않는다. 오래된 예약을 종료한 직후 영수증이 삭제되어 ACK/read-back이 실패하지 않도록 `settledAt`을 기록하고 종료 이후에도 24시간 확인 시간을 준다. 반복 종료는 다시 환불하거나 stock을 소모하지 않는다. 원래 issuedAt은 바꾸지 않으므로 종료 확인 시간 연장이 새 리필 권한이 되지 않는다.

서버 종료 후 기존 HUB 복구 계약(다른 job의 60초 이상 된 RESERVED만 보상 복구)을 유지한다. DELIVERED는 자동 환불하지 않는다. 미해결 예약으로 용량이 꽉 차면 새 경제 거래를 거부하되 해당 예약의 명시적 복구는 가능하다. 원본 예약을 무조건 삭제하지 않는다.

## 5. 영구 필드와 실질적 상한 감사

| 필드 | 현행 상한/처리 |
|---|---|
| receipts | 24시간 활성 구간 + 미완료 예약, 최대 16384, 전체 3MB guard |
| records.scoped | 64 scope; lap/race boost/lifetime 유지 |
| records.metadata | 64 scope; lap/boost 증빙 유지 |
| records.races | 64 scope; scope별 Best Race / Last Race 유지 |
| pendingIndex / pendingRaceIndex | 각각 64; 일치하는 인덱스 복구 성공 전에 삭제하지 않음 |
| daily.claimBuckets | 8 bucket; 이번 작업에서 정책 변경 없음 |
| shopInventory | 허용된 6개 ID, 기존 stock/소모 규칙 유지 |
| purchaseHistory / cosmetics | 구매 소유권은 중복 획득 금지; 현행 Wing 구매 이력 1개, 소유권 상한 256 유지 |

`records.metadata`는 단순 불필요 로그가 아니다. PersonalRecordsController에서 증빙으로 트랙/분류 제목을 만들고 schema가 scope/provenance를 검증한다. 제거하지 않았다. 최저/최고·최근 기록, 누적 boost, 지갑, 첫 보상 상태, 소유/장착 및 pending leaderboard repair는 정리 대상이 아니다. 현재 catalog를 넘는 64개 이상의 새 기록 범위를 추가하는 미래 변경에는 별도 저장 설계 검토가 필요하며, 기존 기록을 자동 삭제하지 않는다.

## 6. 제공된 현재 프로필 분석과 마이그레이션

사용자가 제공한 UID 11700555357의 **현재 JSON 복제본만** 분석했다. 운영 API에서 다시 읽거나 쓰지 않았다. 원래 85KB였던 버전은 제공되지 않았고 현재 Creator Hub 표시 23.2KB라는 설명을 구분해 기록한다.

| 항목 | Compact JSON bytes |
|---|---:|
| 전체 | 23,759 (23.20 KiB) |
| receipts (1개) | 272 |
| records.scoped | 1,559 |
| records.races | 12,668 |
| records.metadata | 8,283 |
| pendingIndex | 2 |
| pendingRaceIndex | 2 |
| purchaseHistory | 135 |
| 그 외 필드 객체 | 728 |

각 하위 객체의 JSON 길이이므로 필드명/구조 overhead를 포함한 전체와 단순 합이 같지는 않다. 현 프로필 대부분은 보존해야 하는 레이스 기록과 증빙이다. 영수증만 줄여서 5KB를 만들 수 없고 그런 제한도 적용하지 않았다.

현재 프로필 복제본 schema 검증 PASS. 점진적 수명 필드 추가 후 **23,759 → 23,863 bytes**. 잔액 179,640, 누적 획득 206,140, 선택/구매/장착/첫 보상/전체 records/stock/pending/activity는 전부 동일하다. 원본 JSON도 불변이다. 실제 압축 저장 크기는 측정하지 않았다.

합성 legacy 검증: 신규/영수증 1/40/1100개, Canonical/SHA 서명, 미완료 예약, 손상/저장 실패 프로필을 테스트했다. 85KB를 넘는 합성 프로필은 **135,779 bytes**, 첫 점진적 마이그레이션 165,331 bytes(legacy retry 시각 추가 및 1회 기록 반영), 24시간 만료 뒤 신규 거래에서 **2,547 bytes**로 안전하게 정리됐다. 이는 제공된 실제 계정의 과거 85KB 버전 측정이라고 주장하지 않는다.

알 수 없는 이전 영수증의 나이는 마이그레이션 시각으로 한 번만 기록해 전체 재시도 구간을 준다. 기존에 이미 삭제된 영수증을 복구했다고 주장하지 않으며, P0 이전의 권한 문맥 없는 미확정 요청은 신규 지급하지 않는다. 손상되거나 한도를 넘는 원본은 덮어쓰기/초기화 없이 READ_ONLY/명시적 오류로 남긴다.

## 7. 장기 거래 크기

실제 production reducers에 서버 clock을 주입해 **10,000회**(5,000 레이스 + 5,000 자동 리필 설정 거래)를 실행했다. 1시간에 1거래로 진행시킨 모형이며, 24개의 영수증은 개수 정책이 아니라 이 모형의 24시간 활성량이다.

| 누적 거래 | 전체 JSON | receipts JSON | 활성 영수증 |
|---:|---:|---:|---:|
| 1,000 | 7,612 | 5,353 | 24 |
| 5,000 | 7,615 | 5,353 | 24 |
| 10,000 | 7,617 | 5,353 | 24 |

전체의 몇 바이트 증가는 누적 통계 숫자의 자릿수이며, 거래 이력은 정체한다. 더 빠른 거래율에서는 24시간 이력이 더 많아질 수 있고 개수/3MB guard에서 안전하게 거부한다. 상한 도달 시 오래된 요청을 새 보상으로 처리하는 우회는 없다. 미완료 예약이 많은 비정상 프로필은 강제 GC 대신 복구/보류한다.

## 8. 테스트 결과

전용 `tests/datastore_idempotency_validation.luau`: **75 checks PASS**, 10,000회 장기 모형 포함.

| 요구 시나리오 | 결과 |
|---|---|
| 10,000 + A 1,500, A 반복 | 11,500 유지 |
| A / B / A | A 재지급 0 |
| A / 구매 또는 선택 / A | 재지급 0 |
| 영수증 GC 후 과거 A / 정상 신규 B | A 거부, B 정상 지급 |
| 저장 ACK 유실·callback 재실행·두 작성자 | 1회 지급, uncached receipt 확인 |
| RESERVED 중 다른 거래·FINALIZE·환불·재시작 복구 | 예약 보존, 중복 소모/환불 0 |
| 늦게 종료된 오래된 예약의 확인 | settledAt 확인 구간 유지 |
| 평문/SHA 레이스·선택·구매 | 호환 PASS |
| maxReceipts 16384 및 작은 3 | 활성량 초과 거부, 만료 뒤 신규 허용 |
| 실제 Shop RemoteFunction PREPARE/실행/재시도 | 1회 차감, client UUID 신규 권한 거부 |
| pending leaderboard/영구 기록 보존 | PASS |

최종 전체 회귀: **201 suites = 160 PASS / 41 FAIL**, 신규 실패 **0**. F60 기준 43개 중 `r8_a3b_full_race_validation`, `r8_a6_b_canary_grant_validation`가 이번 수정으로 PASS. 나머지 41개는 기존 실패 기준선과 동일하며 해결했다고 표시하지 않았다. 원시 로그/exit/timing은 `artifacts/p0-economy/regression/`, 비교는 summary.json에 있다.

요청된 progression mock/runtime, records, shop, records runtime, public_warmup_records, race_item, first60은 PASS. `r8_a4_economy`(과거 ineligible zero 기대), `r8_a4_runtime`(과거 첫 완주 이벤트 이전 금액 기대)는 기존 기준선 FAIL 그대로다. 보상 계산을 바꾸거나 이 검증을 낮추지 않았다. 관련 r8_a6 결과도 전체 results.json에 개별 기록했다.

기존 PASS 테스트의 계약 변경은 세 곳이다: r8_a3_records의 위험한 '이전 영수증 즉시 삭제' 기대를 '신뢰할 만료 정보 없는 영수증 보존'으로 변경; r8_a2l의 축약 schema fixture에 새 API 연결; r8_a5의 실제 서비스 clock과 서버 거래 문맥 fixture 주입. 잔액/ACK/중복/보유품/실패 처리 기존 assertion은 유지했다. 실패 숨기기나 무조건 PASS 변경은 없다.

Production Luau **196개 컴파일 PASS**. `git diff --check` PASS. Rojo XML/바이너리 PASS: `C:/dev/KDM_P0_Economy_Review.rbxlx`, `.rbxl`.

## 9. 수정 파일과 산출물

P0 source: KDMProgressionSchema; RaceRecordOperations/Service; EconomyOperations/Service; ShopOperations/Service; ProgressionOperations/PlayerProgressionService/ProgressionLiveCoordinator; GarageShopController(통신만).

P0 tests: 신규 datastore_idempotency_validation; r8_a2l_datastore_validation; r8_a3_records_validation; r8_a5_shop_validation. RaceRecordRuntime과 ProgressionDataStoreAdapter의 기존 원자적 callback/재시도/uncached read-back은 감사 후 그대로 사용했다.

정확한 경로는 `artifacts/p0-economy/p0-files.json`, tracked diff는 `p0-tracked.diff`, reward/F60 보존 증거는 `scope-verification.json`. 실제 제공 프로필 JSON은 Git-ignored artifacts에만 있고 원본 body를 공개 진단 로그나 문서에 넣지 않았다. Mock/합성 자료와 실제 제공 복제본을 구분했다.

## 10. 검토 전제와 운영 상태

- 서버 시각·공식 collector·서버 티켓 발급이 신뢰 경계다. 클라이언트 시간/UUID만으로 신규 거래를 허용하지 않는다.
- 24시간 밖의 원본 요청을 영구 재실행하는 계약은 제공하지 않는다. 미완료 예약은 예외로 안전한 종료/복구까지 유지한다.
- 정책/byte 검증 실패 시 원본 보존, 안전한 거부가 우선이다.
- 현재까지 실제 운영 데이터 변경 0. Commit/Push/Publish/운영 서버 재시작 0.
- 추후 승인된 배포 시 **이전의 영수증 삭제 코드를 가진 구버전 서버를 함께 종료해야** 한다. 신규/구버전 혼재 중 구버전이 새 영수증을 삭제하는 문제를 새 코드만으로 보장할 수 없다. 이번 작업에서는 배포/재시작을 실행하지 않았다.

Roblox 공식 문서상 key 한도는 4,194,304이며 총 할당량은 500MB + lifetime user당 1MB, 최신 key 버전의 압축 크기로 산정한다. 이 보고서의 JSON 원본 byte 측정과 플랫폼 압축 저장량은 다른 지표다. [공식 DataStore 한도 문서](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits).
