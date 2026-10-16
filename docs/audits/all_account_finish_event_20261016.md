# All-account race completion event — 2026-10-16

Supersedes the newcomer-only eligibility policy in welcome_first_race_20261016.md.

- User explicitly authorized code changes, commit/push and Publish. Baseline 6c4ca4c0965130e41590d75adb208be76ab6091e matched origin/prototype/kart-physics; tracked tree clean.
- Stable campaign ID KDM_FINISH_EVENT_20261016, separate from historical welcomeSeen/firstFinishClaimed. All existing and new accounts are eligible once, including previous finishers and recipients of the previous welcome bonus.
- Campaign seen/claimed state lives in optional onboarding.finishEvent. Missing historical state is eligible; acknowledgement only stores seen, without changing wallet. Existing balance, purchased items, selection and records remain intact. Initial K$5,000 is not re-granted to existing accounts.
- First eligible full completion after deployment pays K$5,000 campaign bonus plus ordinary race reward in one UpdateAsync receipt/latch transaction. Subsequent rounds, replay, rejoin or redeployment retain the campaign latch and do not repeat the bonus. Campaign identity is fixed, not generated on join.
- Popup welcomes new/returning racers, explains the once-per-account bonus and unchanged existing balance, and uses START EVENT RACE. Existing 3-lap isolated Practice route remains. Results say EVENT BONUS.
- Validation: economy/campaign 76 checks (including historical bonus recipients, old finishers without onboarding, new players, acknowledgement with no credit, persisted latch/rejoin, replay, invalid finish, overflow and malformed state); 10,000 receipts remain valid below 3 MB.
- Regression PASS: official records 65; progression mock 550 / runtime 76; first Practice controller 9; cross-HUB matchmaking 68; completed warm-up observer 13. Rojo build and whitespace checks PASS.
- Native Studio iPhone landscape: Play-only old-account fixture with cash K$22,640 and historical welcome/bonus flags true receives campaign eligibility and visible updated popup; cash stays K$22,640. No persistent production account modifications. Stop Play removed fixture before Publish. Five changed source scripts exact-synced and compiled in original native place.
- Published transport, real completion payment and persistent production rejoin require real-device acceptance. Join a new server running this release; old running servers retain their old code.
