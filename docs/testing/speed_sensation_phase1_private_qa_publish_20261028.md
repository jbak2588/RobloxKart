# FOV Phase 1 Private QA 게시 결과 — 2026-10-28

**PRIVATE_QA_PUBLISHED_DEVICE_PENDING**

지정 QA Universe **10772198697** / Start Place **106553302629620**에 FOV 모듈 하나만 게시했습니다. Creator Dashboard의 해당 Place Version History에서 **Show published only**를 켠 상태로 **111번**과 게시 완료 체크 표시를 확인했습니다. 게시 후 Overview에서도 **Game access: Private / Audience reach: Private**를 확인했습니다.

[실기기 테스트 URL](https://www.roblox.com/games/106553302629620/) · [게시 이력](https://create.roblox.com/dashboard/creations/experiences/10772198697/places/106553302629620/version-history) · [Private 상태](https://create.roblox.com/dashboard/creations/experiences/10772198697/overview)

## 요청 결과17항목

| 항목 | 결과 |
| --- | --- |
|1 HEAD/origin|f5ebec8c7f86dac5c488f90a0a01041d147cf4a2로 일치. 재시작 후 fetch 확인. |
|2 기존 작업 보존|기존 미커밋/미추적74개 파일 SHA256 모두 동일. FOV/R1/R2/R3, 보상0 및 문구 수정 보존. |
|3 Current Release|R3와 동일한 범위229/229 PASS. 전체249개를 재실행하여229 PASS/20 FAIL. |
|4 Historical|동일20개 실패 목록 유지. 삭제·Fixture 갱신·자동PASS 없음. FULL_SUITE_PASS가 아님. |
|5 Source Integrity|682 PASS,133개 소스 승인 Git 객체 일치 감사 PASS. Manifest/역사적Fixture 이번 작업에서 수정 없음. |
|6 FOV|START55→50, FULL80→90, HIGH_SPEED.FovDelta3→5만 변경. 기본75/Mini6/Nitro10/MAX87/Attack10/Release5 유지. |
|7 실제 QA Studio|MCP로 Universe10772198697/Place106553302629620 및 Edit 확인. HubParkV1Enabled=true. |
|8 실제 변경|ReplicatedStorage.Shared.KDMSpeedSensation 한 개. 기존 전체Source는 준비 스크립트 before와 일치, 적용 전체Source는 검증 후보와 일치. |
|9 Publish|성공. QA 전용 Studio 게시 후 Creator Dashboard 실제 게시 목록에서111 확인. |
|10 Place Version|실제 게시111. Studio의 game.PlaceVersion109는 로드 당시 값으로 새 게시 영수증과 구분. 미게시 저장본110도 게시 전 관찰. |
|11 Private|Dashboard에서 게시 전/후 Game access와 Audience reach 모두Private 확인. 공개 전환/권한 변경 없음. |
|12 실기기|Android: NOT VERIFIED / iPhone: NOT VERIFIED. PC·Studio 결과를 실기기PASS로 간주하지 않음. |
|13 회귀|현재 릴리스229개에서 신규 실패0. Camera/Speed VFX/GAS/Touch/Ownership/아이템/종료/Rematch 검사 유지. |
|14 미검증|실제 모바일 멀미·가독성·저FPS 렌더링·연속주행·입력/부스터 전환은 실기기 검증 필요. |
|15 롤백|이전 실제 게시109를 Version History에서 복원 가능함을 확인. Restore는 저장만 하므로 QA Studio에서 열고 QA Place로 재게시 필요. 또는 보관한 기존 모듈 전체Source 사용. |
|16 Git|Commit/Push/Stage/main 변경 없음. |
|17 공식 Place|Universe10768420544/Place127925465904803에 적용·게시하지 않음. 공식 Studio 창 대상 입력/소스 변경 및 서버 재시작 없음. |

## 적용 범위와 증거

QA의 기존231개 스크립트 전체Source를 기록하고,11,167개 인스턴스의 부모/이름/클래스/Attributes 및 GUI/Part/Workspace/Lighting 등의 주요 속성을 게시 전후 비교했습니다. 변경Source는 FOV 모듈 하나, 기록 범위의 속성/인스턴스 추가·삭제 변경0개입니다. Studio 편집기 카메라 상태는 게임 카메라 알고리즘과 별개입니다.

- 모듈 전체Source SHA256: a1bdca31a8c1dbae506aaab0857a96b330ce7b1353d1a909803ea3b4c5c98e15
- 목표 FOV: 일반70→77.5°, GAS90→80°, Mini81°, Nitro85°. 공유 강도에 따른 일반 속도선 강도 변화는 승인된 부수효과입니다. 별도 VFX 수정 없음.
- Rojo build는 검증만 했으며 빌드 파일은 게시하지 않았습니다. QA 전체 Rojo 동기화 없음.
- 로컬 R3 보상·상점·안내문구 변경을 QA에 추가 복사하지 않았습니다. 기존 QA109 상태에 FOV 모듈만 적용했습니다.
- 기존 게시109를 전체 Place 롤백 기준으로 확보했습니다. 로컬 전체Place 사본 다운로드는 하지 않았고, 기존 모듈 전체Source와 스크립트 무결성 목록을 별도 보관했습니다.

## 로컬 증거 위치

C:/Users/Public/Documents/ESTsoft/CreatorTemp/kdm-fov-private-publish-8e0sn9jl/

- publish-receipt.json: 대상·게시111·Private·검증 결과
- qa-before-snapshot.json: 기존231개 스크립트 해시 및 원본 FOV
- qa-after-diff.json / qa-post-publish-diff.json: 적용 및 게시 후 범위 비교
- KDMSpeedSensation-before.luau: 롤백용 전체 모듈55/80/3
- KDMSpeedSensation-candidate.luau: 게시 모듈50/90/5
- validation/results.json 및 개별 로그: 재실행249개 결과
- manifest.log: Git 객체 및 역사적Fixture 보존 감사
- validation-only.rbxlx: 검증 전용 빌드. 게시하지 않음.

QA는 Private이며, 실제 모바일 수용성 검증은 미완료입니다.
