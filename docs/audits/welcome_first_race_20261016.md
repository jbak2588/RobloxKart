# Welcome reward and first race — 2026-10-16

## Scope

Approved by user: implement/test, commit/push and Publish. Baseline 74f0546341a57dbff2d77768ff45672f9cb04af3 matched origin/prototype/kart-physics; tracked tree was clean.

- New accounts retain the existing K$5,000 initial balance. Welcome modal explicitly says it was granted for visiting. No claim-button cash grant.
- Navy/gold modal, bright green START FIRST RACE, LATER, actual KDM kart/wing and Nitro/Shield/Missile artwork. Await confirmed profile; suppress during competing overlays, driving and routing. Persist welcome acknowledgement without changing wallet.
- First CTA directly creates an isolated Track01 Practice reserved room without a prior browser selection. Solo, 3 laps, normal item preparation/countdown. Public discovery, other entrants and recruiting interruptions are excluded. Existing private practice stays unrewarded; this first-race room explicitly forwards its reward-observer exception through the server bootstrap/coordinator.
- First eligible full finish in a rewarded race (solo/BOT/human) pays an additional K$5,000. The durable onboarding latch, ordinary completion/PB payment and receipt are committed atomically in the existing reducer. Read-back confirmation owns success presentation. Retries and concurrent updates cannot award twice. Invalid/unfinished races grant no bonus and retain eligibility.
- Old profiles remain schema-compatible. Legacy previous eligible finishers do not receive a retroactive first bonus or welcome popup. No balance reset or duplicate initial cash.
- Results split first bonus/race reward/total, emphasize PLAY TOGETHER VIA LOBBY; this button retains the actual return-to-Lobby action. First-race results do not auto-rematch after eight seconds.
- BOT opponent was optional in the reviewed idea; the first CTA uses the supported solo alternative to preserve an uninterrupted introductory full race. Normal BOT races also qualify for the once-only bonus.

## Verification

- Economy: 69 checks, including normal payments, first solo/BOT bonuses, replay, second round, invalid finish, capacity failure, legacy finishers and tampered receipts. 10,000 receipts remain schema-valid within the 3 MB profile budget.
- Global matchmaking: 68 checks, including CTA without browser selection, forced Track01 identity, isolated room/discovery/queue protection, double-click deduplication and existing cross-HUB paths.
- First Practice production controller: 9 checks plus bootstrap forwarding assertion; automatic countdown, all 3 laps, terminal presentation, single observer and retained results.
- Existing completed warm-up 13, Practice three-lap/rematch 94, coordinator 25, concurrent rooms 18, routing 175, official records 65, backed-up reset 13 and record diagnostics/runtime 108 checks PASS.
- Progression mock: 25 scenarios / 550 checks PASS; progression runtime 76 checks PASS.
- Studio iPhone landscape: new profile automatically showed actual kart/items and clear K$5,000 granted/+K$5,000 first finish copy. START triggered the real first-race request; unavailable reserved-server transport returned a retry error with cash unchanged. LATER closed the modal and server-authored welcomeSeen became true; cash remained K$5,000.
- Studio layout probes: 750x332, 648x223, 844x332, 360x650, 1280x662, 1920x1022 safe-root sizes; panel/control bounds and button gaps PASS. Narrow 360px root had no text-height overflow. These are geometry probes, not six real-device tests.
- Studio original native place retained. Play-only UI geometry probes removed by Stop before Publish. No live account purchases or persistent production writes were used for testing.
- Historical practice_public_bot_validation stops on its old exact-byte TrackCatalog fixture; TrackCatalog is unchanged by this task. It is not reported as passing.
- Rojo build and whitespace diff checks PASS. Real published teleport/first finish/persistent rejoin/mobile acceptance remain pending; Studio cannot validate reserved-server teleport.
