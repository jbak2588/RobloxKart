# Rookie Park Multiplayer — 2026-11-03

Owner requests a separate eight-racer, three-lap Park mode after Time Attack and
Overtake, using Overtake's seven noncontact rivals, ten seconds of human joining,
sequential bot grid fill, distinct random80–86stud/s paces and the second preview
position. Owner selects the existing public-race placement reward option.

## Behavior

- New `ParkMultiplayer` / `MULTIPLAYER` identity. Hub preview order: Overtake,
  Rookie Park Multiplayer, then the existing official tracks.
- Matchmaking is within the current Hub server. It does not search other servers
  or use the official four-player reserved-room pipeline.
- First participant opens a fixed ten-second window, including when all eight
  humans arrive early. Reservations made within the window get at most1.5seconds
  to finish seating. New arrivals after the deadline enter the next room.
- After the roster locks, empty real Park grid slots receive one bot every.3s;
  one human means seven bots, two means six, through eight humans and zero bots.
  All entries share the following three-second countdown/GO. Departures after
  roster lock are withdrawals; there is no mid-race replacement.
- Random pace is selected per bot per race from seven strata spanning80–86stud/s,
  then shuffled. The bots retain those different cruising paces; existing item
  delays affect their actual integrated distance and finish order.
- Reuses the existing Park course and eight brackets. Initial bot lane offset
  merges smoothly over90studs. No new course geometry or human physics tuning.
- Same existing Park human kart, seating, controls, GAS, launch boost, boundary
  recovery and manual server ownership. Client-only noncontact bot models use
  the Overtake Kart05–Kart11 palette. Private server pose handles remain unparented
  and are explicitly destroyed; distance/effect metadata is sampled.
- Human and bot finishes share overall1–8 position. Human prizes follow the
  existing public base schedule: one human plus bots1500; with2+ humans,
  human placement3500/2500/2000/1500 thereafter. This separate mode adds no
  official first-finish grant, official PB bonus or Replay multiplier.
- Valid complete three-lap/18-checkpoint proofs use immutable `park-race:`
  receipts with atomic wallet/lifetime-earned updates and uncached confirmation
  before the earned label. No time-attack PB/index or Overtake reward mutation.
- Existing Park items work inside the room. Cross-room, Time Attack, Overtake
  and ambient-demo damage is rejected. Ambient demo visuals are hidden for
  multiplayer participants to avoid drawing both fleets.
- Race Again enters a new ten-second roster. Last departure removes its bot
  metadata, private poses and local visuals. Rooms are bounded to six concurrent
  Hub sessions, with a fifteen-minute race timeout; invalid runs receive no reward.

## Validation

- New roster/policy/reward/integrity suite:652 checks PASS. Includes human counts
  1–8, exact complements, delayed sequential fill, seating grace, late arrivals,
  slot uniqueness, simultaneous finish ordering, duplicate ACK rejection,
  malformed proofs, finish departure during tie resolution, and exact source
  pins/mutation rejection.
- Production combat integration:15 checks PASS, including private poses,
  common-GO integration, actual hit-expiry distance, vision-only Smoke,
  room isolation, finish interpolation and cleanup.
- Real TrialSession adapter/full sampled course/save/Replay:13 checks PASS.
  No payout before all three laps and finalized position.
- Real Garage fixture: second preview and dedicated multiplayer launch PASS.
- Existing Overtake235 policy checks + first-card wiring +9 lifecycle checks PASS.
  Existing Time Attack route70 / lifecycle23 / presentation312 checks PASS.
  Combat508 / Garage6384 / collision27 / arrival-staging16 / fleet31 /
  Lobby driving-policy1186 checks PASS. Existing smoke-parity suite PASS.
- All251 Luau sources under src compile; Rojo default binary build PASS at
  `artifacts/park-multiplayer-20261103/KDM_Park_Multiplayer_Local.rbxl`.
- Existing collision source freeze initially rejected the intentional source
  change. Historical hashes were retained, with twelve exact runtime hashes
  added under `parkMultiplayerPatches`; collision regression/mutation checks PASS.
  No full-suite-pass claim; unrelated historical failures were not reclassified.

## Native Studio evidence and limits

Exact production-connected Studio used only for local Play. One actual seated
human entered through the existing client RemoteEvent, remained frozen for the
join/fill/countdown, and started with seven local bot models. Native samples showed
seven distinct base paces80.4947,80.8807,81.7874,82.6725,84.1627,84.3775,85.4413.
Each replicated bot metadata Model had zero children (no replicated body).
Three-lap HUD and overall position rendered; human chassis remained manual
server-owned. Normal Stop cleared the session ID, active/pending flags, room and
fleet. Local Play was stopped and Studio returned to Edit.

The first probe explicitly started an extra controller instance and produced a
duplicate local fleet; that contaminated Play was discarded. A fresh Play using
only the existing RemoteEvent confirmed exactly seven models. No production
controller duplication was introduced. Native startup retained the existing
Studio preferences API-access warning; no new feature runtime error was observed.

Eight actual connected humans, repeated mobile runs, device FPS and a native
manual three-lap finish remain unverified. Full-route/receipt checks above use
deterministic fixtures, not live account writes. Suspended KDM-R geometry was not
resumed. The implementation phase did not Publish, Commit/Push or restart servers.

## Release authorization — 2026-11-03

Owner subsequently explicitly requests Commit/Push/Publish of this feature.
Release targets exact Universe10768420544 / Place127925465904803, without a
production restart. Final targeted feature, collision and smoke-parity checks
PASS; all251 src Luau files compile. All242 runtime source files match the
production-connected Studio Edit normalized lengths/checksums;251 total Studio
script entries. All three release flags remain true; GAS90 is enabled for the
actual production pair. Actual8-human and mobile acceptance limits remain above.

## Publication receipt

- Feature commit `7db95a28528aedeff73cf26a4c8bb46faaadf2a4`, pushed to
  `origin/prototype/kart-physics` before publication.
- Native Studio Publish succeeded for Place127925465904803 at17:42:13
  Asia/Jakarta on2026-11-03. Studio output explicitly identifies **v1312**;
  the native log independently records PublishSuccessful and the exact Place ID.
- Post-Publish all242 runtime files still match local normalized lengths/checksums;
  all251 Studio script entries are unchanged from preflight. Hub/controls/GAS
  flags remain true; actual-pair GAS policy remains enabled at90.
- Edit metadata continues to report1305; it is not the publication receipt.
  Creator Dashboard history and real8-human/mobile acceptance were not rechecked.
- Existing owner-selected native baseline backup remains preserved (SHA256
  bf91643a15b2a5eb5728ace9808f92d8c0e4c81b82a4afbe71c704a9309df0d6).
  Current Rojo binary is retained in artifacts/park-multiplayer-20261103/
  KDM_Park_Multiplayer_Local.rbxl (SHA256
  9a67309b511f757925da00d9546143c3e8e6d18779f425484c9d7b0b28afb263).
  A new native Download Copy attempt was canceled after its filename field could
  not be reliably targeted; no new native pre-publication copy is claimed.
- No server restart, Cloud Restore, access-setting change or live account write.
  Unrelated baseline/archive files remain outside the scoped release commits.

## Bot pace increase — owner2026-11-03

Owner reports bots are too slow against a full-course held-GAS human and requests
85–91stud/s. Shift only the multiplayer pace distribution up5stud/s; retain its
seven random strata, per-race shuffle, hit delays, finish scoring, human physics,
GAS90, Overtake70, matchmaking and rewards. Updated boundary checks and88stud/s
combat-motion fixture PASS (652 policy/roster/reward/integrity,15 combat,13 full
route/lifecycle checks). Exact source pin updated only for this policy.
Production Edit policy normalized bytes1777 / rolling checksum1891669659 match
local. Deployment follows the owner's existing scoped release authorization.
