# Rookie Park seated-avatar collision isolation — 2026-10-28

Owner authorized implementation, commit/push and production Publish. Baseline
local/origin f3c9babab74f09f403813df6fa3883adaeb9ffd2 on prototype/kart-physics.

## Change

LobbyTestDriveService previously excluded kart/kart and kart/avatar contact but
did not exclude LobbyAvatar/LobbyAvatar. Official RacerCollisionIsolation already
excludes driver/driver contact. Introduce ParkDriver only for sessions with the
Rookie Park timeTrial adapter, before seating. Keep it through Countdown, driving,
finish presentation and Replay; return to LobbyAvatar after the kart and seat
weld teardown has settled. Original per-part groups are restored on character
cleanup; late accessory handles inherit the currently active binding group.

ParkDriver cannot collide with itself, LobbyAvatar, LobbyKart, LobbyBoundary or
official racer groups. Its Default/world collision stays enabled. Existing
LobbyKart boundary/floor collisions and walking LobbyAvatar/LobbyAvatar contact
are unchanged. No CanCollide toggle, motion/authority write, track/start/finish
move, economy edit or official racing-policy change was introduced.

Canonical source SHA256:
`7af484a2ee7f089f673d938c04d6e3fae33d7ead8abe1e208d8dfb36bbbfbd3a`.
The current-release manifest records this exact separately approved source;
all historical and f5ebec8 hashes are retained. Independent Python audit pins
the same hash. Mutating the self-contact rule back to true is rejected.

## Validation

- New production-function test27 checks: collision matrix, two-avatar binding,
  late accessories, exit/re-entry, respawn, teardown, stale-character guard,
  idempotency and source mutation rejection.
- Native QA Studio Server contact test used two chassis assemblies with welded,
  collidable avatar-contact proxies and actual Roblox physics. Existing
  LobbyAvatar contact displaced the unanchored target21.048stud; ParkDriver
  contact displaced it0stud; ParkDriver versus walking LobbyAvatar0.00293stud;
  anchored Countdown target0stud. All targets retained floor support.
- The fixture deliberately reproduces force transfer through welded avatars,
  not two actual humanoid clients completing the Park race. Actual two-mobile
  finish-line acceptance is still pending; no universal zero-jitter claim.
- Test ran only in Private QA Play. Temporary fixtures were removed, Play stopped
  and the QA Edit module restored exactly. No QA Publish/account operation.
- Full suite250 processes:230 current-release PASS /20 unchanged historical FAIL;
  compare failure identities with prior release before deployment. No claim of
  FULL_SUITE_PASS. Source integrity683 checks, independent audit, Rojo build and
  git diff --check are required before Publish.

Raw suite logs, native fixture/results, prior module backup and build:
`C:/Users/Public/Documents/ESTsoft/CreatorTemp/kdm-production-release-zff91kx5/`.

## Deployment and rollback

Target only Universe10768420544 / Place127925465904803. Verify the one changed
production module against the validated full source and inventory before and
after Publish; retain HubPark and mobile/GAS flags. No server restart or access
setting change. Publication receipt is appended after dashboard confirmation.

Rollback by reviewed Git revert or restoring the previous published official
Place version and publishing it in Studio. Do not reset the working tree or
change ownership policy to address avatar contact.
