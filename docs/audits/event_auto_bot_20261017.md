# Event Practice automatic BOT — 2026-10-17

- User confirmed published completion event, requested one automatic BOT after item preparation so items can be used against an opponent. Continues the authorized event release workflow. Baseline f095043f5a2ccb74e7dd2481279318adb961ad2a matched remote; tracked tree clean.
- Only event private Practice permits a server-owned BOT. Existing coordinator heartbeat automatically adds one KDM Rookie after the host has arrived; normal private practice remains solo. No public discovery or other-human admission was enabled.
- RaceController requires an actual admitted BOT before countdown, and directory startRound independently requires one staged BOT. Failed/slow creation therefore retries without launching solo. Existing item-prep and auto-ready contracts remain; BOT is automatically ready.
- Welcome footer now says 1 BOT. Existing full-lap reward observer, once-only campaign state and manual event result progression remain unchanged.
- PASS: event automatic production BOT 53 checks (real Directory/Coordinator/BotController with deterministic transport/physics mocks); event full three-lap controller 12; production BOT on Track01 125; global matching 68; coordinator 25; completed warm-up observer 13; economy/campaign 76.
- RaceItem integration PASS: 1179 production checks including NPC target/debuff/recovery, 273 additional NPC physical integration checks, and 13 rear-preview lifecycle checks. Includes production BOT Missile/Thunder targeting; normal item rules remain unchanged (ahead-only attacks still require a target ahead).
- Rojo build and whitespace checks PASS. Four changed scripts syntax-checked and exact-synced to original native Studio Edit place. Actual reserved-server event arrival and published two-kart start/item use require real-device validation; Studio cannot establish production teleport acceptance.

Release: implementation 2cdcfc5180ebef0ded5c12cbe748d8a0997b78a8 pushed with local/remote HEAD equality verified. Native Studio Publish succeeded for place 127925465904803, version 783.
