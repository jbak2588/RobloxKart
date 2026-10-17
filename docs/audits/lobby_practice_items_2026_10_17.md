# 시승장 아이템 연습 — 로컬 구현

기준: `2b4353bf7041b183bb2bc02895bc94ae7e00f901`.
작업 전 origin fetch / 개발 브랜치 동일 HEAD / 추적 파일 변경 없음 확인.
기존 미추적 아티팩트와 정식 레이스/로비 형상 변경은 보존했다.

사용자 승인 범위: 시승장에서 다섯 아이템과 반복 니트로 연습, 봇 피격,
동시 시승 중인 인간끼리 공격. 봇의 공격 기능은 추가하지 않는다.
이 문서는 이전의 아이템 가능 여부 검토 이후 승인된 구현을 기록한다.

## 플레이 동작

- 선택 과정 없이 Nitro / Slick / Shield / Missile / Smoke / Thunder 직접 버튼을 제공한다.
  전술 아이템은 각각 1개, 성공한 사용 후 **6초**에 재충전된다. 이 대기시간은 시승 전용이다.
- 니트로는 시작 1개, 성공한 Mini Boost 5회마다 +1이다. 보유 최대 2 / pending 최대 1,
  5/5에서 pending이 있으면 추가 적립 정지, 유효한 사용 때만 소비와 pending 정산을 원자적으로
  수행하는 기존 RaceLoadout 계약을 그대로 쓴다. 시도/충전만으로는 세지 않는다.
- 니트로는 기존 100 / 3초 / 가속 75 / 종료 감속 15를 참조한다. Brake, 경계 접촉 및
  물리 공격 피격 시 취소하며, Mini Boost와 합쳐도 100을 넘지 않는다.
- 슬릭·미사일·썬더는 실제 경고/투사체/낙뢰/미끄러짐과 피격을 연결한다. 인간 피격자의
  미사일 55 / 2.5초, 썬더 60 / 2초, 슬릭 회전/속도 유지율은 기존 설정/모듈을 참조한다.
  물리 효과 중 Drift/Boost는 취소한다. 미사일·썬더 피격 중 일반 조향·스로틀은 계속 가능하다.
- 쉴드는 혼자서도 기존 청색 보호막을 5초 동안 볼 수 있다. 다른 인간 시승자의 공격에는
  기존 면역 우선 → 한 번 차단 → 소모 규칙을 적용한다. 봇의 역공은 없다.
- 스모크는 기존 구름 크기/지속시간과 3초 시야 효과를 쓴다. 인간 피해자는 기존 45% 바탕 /
  60% 중앙 puff / .12초 진입 / .28초 종료 haze를 받는다. 봇은 구름과 SMOKED! 상태를 표시하며,
  별도 시야 AI/감속/운전 페널티는 추가하지 않는다. 자기 Smoke/Slick도 기존 소유자 유예 뒤 적용된다.
- 시승 종료/하차/캐릭터 변경/레이스 이동은 해당 운전자의 임시 상태, 발사 중 공격과 소유 hazard를
  정리한다. 같은 시승의 경계/낙하 복귀는 공격 일시 상태만 지우고 잔량/보너스/재충전 시각은 보존한다.

## 타격 대상 및 서버 경계

`LobbyPracticeCombat`은 같은 Hub의 현재 탑승 기록을 전투 actor로 연결한다.
실제 Player를 만들거나 RaceSession/RaceState/RacePosition을 위조하지 않는다.
정식 `RaceItemController`의 대상 검증을 완화하지 않았다.

- 대상: 실제 시승 기록과 현재 Seat/Humanoid/캐릭터가 일치하는 인간, 그리고 서버 시연 봇 proxy.
- 제외: 보행자, 전시 카트, 하차/사망한 사람, 레이스 이동 중인 사람과 다른 전투 컨텍스트.
- 자유 주행에는 순위가 없어 미사일은 **180스터드 이내 앞쪽(dot >= .15)의 가장 가까운 대상**,
  썬더는 같은 범위의 앞쪽 대상들을 서버에서 고정한다. 인간과 봇은 같은 후보 규칙을 쓴다.
  이 시승 규칙은 정식 레이스의 바로 앞 순위/모든 앞 순위 규칙과 구분된다.
- 클라이언트는 UseItem + 시승 generation + 고정 catalog ID만 보낸다. 대상/좌표/명중/잔량/
  슬롯 테이블을 받지 않는다. 탑승 상태, 세대, 잔량, .25초 요청 간격을 서버에서 검증한다.
  대상 없음/니트로 발동 거절/수용 한도 초과 등 사용 승인 전 거절은 잔량을 소비하지 않는다.
  승인된 발사는 이후 Shield/면역으로 막혀도 사용한 충전을 돌려주지 않는다.
- 미사일·썬더·스모크는 실제 기존 서비스를 adapter로 재사용하고 슬릭은 동일 swept 기하와
  `SlickMotion`을 쓴다. 경고 카운터, 세션/라운드/복귀 serial, hazard별 handled set을 유지한다.
  전역 수용 한도와 유한 lifetime/cleanup도 기존 설정을 참조한다.
- 드롭은 서버 카트 뒤의 시승 영역에서만 허용하고 hazard 모서리도 중앙 섬/외곽 안쪽인지 검사한다.
  자유 시승장은 정식 트랙의 고정 lane center가 없어 Smoke도 카트 뒤에 배치한다.

## 봇 및 UI

- 기존 시연 경로를 서버도 계산하는 투명한 전투 proxy를 추가했다. 클라이언트는 서버의
  RouteElapsed / SampledAt / RouteRate를 보간하며 기존 카트/드라이버 시각 모델을 그린다.
  시승자가 있으면 봇은 레이스 normal 70 / Boost 100을 향해 가속하고 실제 공격 cap/슬릭
  유지율을 반영한다. 시승자가 없으면 기존 ambient 36 속도로 돌아간다. 공격 AI는 없다.
- 봇의 피격 상태는 실제 월드 연출, 슬릭 회전, 짧은 상태 배지로 확인할 수 있다.
  스모크는 봇 카메라가 없어 상태 관찰용이며 인간끼리 사용하면 실제 haze를 체험한다.
- 모바일은 모든 아이템을 직접 누른다. 낮은 화면은 한 행 가로 스크롤, 여유가 있으면 3열 2행이다.
  최소 44px target과 기존 운전/Drift/복귀 영역의 비중첩을 확인했다. 작은 화면은 기존 Drift 게이지
  중복을 숨기고 READY/MINI BOOST 및 니트로 0/5 상태를 연습 안내에 표시한다.
- 기존 KDM 아이콘/asset 실패 fallback을 재사용한다. 재충전 초, incoming → SHIELD, 사용/명중/
  차단과 니트로 보상 상태는 서버 mirror로 표시한다. 쉴드 추천은 자동 발동을 뜻하지 않는다.
- PC는 클릭 외에 N=Nitro, Z=Slick, X=Shield, C=Missile, V=Smoke, B=Thunder를 쓸 수 있다.
  정식 레이스의 1–4 / Q 입력 및 4슬롯 UI는 그대로다.

## 소유권 및 회귀 범위

RaceLoadout에 서버 고정 `preparePractice()`만 추가했다. 같은 클래스의 각 시승 인스턴스가
잔량/슬롯/보너스를 단독 소유한다. 정식 prepare()/tactical 검증은 여전히 정확히 4슬롯이며
임의 6슬롯 입력을 거절한다. 별도 보너스 카운터나 Inventory/영구 소유권을 만들지 않았다.

Cash, XP, 승패, 랭킹, persistent Inventory, DataStore, 구매, 트랙/Room/Queue/Rematch,
멀티플레이 정원과 정식 레이스 튜닝에는 변경이 없다. 타원형 시승장 형상도 이번 작업에서 바꾸지 않았다.

## 검증

집중 **28개 검증 파일 PASS**. 목록/로그는 미추적 `artifacts/lobby-practice-items/validation.json`
및 같은 폴더의 개별 log에 있다. 일부 마지막 보강 검사는 개별 재실행했다.

- 실제 전투 orchestrator + 기존 미사일/썬더/스모크/슬릭/Loadout 실행: **440 checks**.
  두 인간 actor, 이동하는 봇, 경고/Shield/명중, 속도 cap, 면역, haze metadata, 6초 충전,
  잘못된 payload/세대, 니트로 pending/복귀/세션 종료를 포함한다.
- 실제 연습 UI 실행: **25 checks**. 여섯 직접 버튼, 한 번 요청, focus/menu/비활성 차단,
  PC 키, 경고, 재충전, 중복 listener 및 파괴 cleanup.
- 열 가지 모바일/portrait/desktop 안전 영역: **120 checks**, 44px/스크롤/운전 비중첩.
- 실제 SmokeEffectView: **59 checks**, 기존 레이스와 시승 context, 소유자/탑승/이동 cleanup.
- 실제 Lobby heartbeat의 물리 효과 분기에서도 Drift 재시작 차단과 일반 steering/throttle
  유지를 추가 검증했다. 시승 Nitro의 가속/최대/종료 감속도 별도 검사했다.
- 기존 반복 Nitro, 정식 4슬롯, RaceItem, 미사일, 썬더, Smoke, 전투 피드백, 오디오,
  시연 경로/Boost, 시승 복귀/경계, Garage/Hub 안내와 mobile Touch 회귀가 포함된다.
- 변경/신규 Luau 컴파일, Rojo build, git diff check PASS.

검사는 실제 production 코드를 사용하되 시간/네트워크/Player/physics integration을 결정적으로
mock한 자동 검사다. **Studio 화면/실제 네트워크 physics/두 인간 모바일 동시 시승은 아직 미검증**이다.
Roblox Publish는 하지 않았다. 기존 source-hash/whitelist 등 전역 역사 테스트 전체 PASS를 주장하지 않는다.

추가 실행한 `boost_flame_fade_validation.luau`는 `redrift clears residual particles`에서 FAIL이다.
수정 전 기준 HEAD의 해당 테스트/renderer/observer/asset을 별도 폴더에 복사해 같은 실패를 재현했다.
실패 경로의 renderer/envelope는 이번 작업에서 수정하지 않았다. 이 검사를 28개 PASS에 포함하지 않았다.
기준 재현 로그: `artifacts/lobby-practice-items/boost-flame-baseline.log`.
니트로의 정상/취소 종료 reason과 기존 flame fade 연결은 신규 전투 검사에서 별도로 확인했다.
