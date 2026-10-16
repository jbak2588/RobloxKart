# People-first public racing — published v766

Requested outcome: two players arriving in different HUB jobs can press PLAY NOW
and start together, without agreeing a track or exchanging invitations.
Baseline: `632227e1e5a1e23605db7f546ec2fe5ce89081dc`, matching origin before work.
Implementation/Studio validation below does **not** establish published two-job,
two-human teleport acceptance. The validated implementation was published as
v766 after explicit user approval; see the release record below.

## Product behavior

- Central RACE / PLAY TOGETHER and the Hub's main CTA open the all-track browser.
  Existing Garage and selected-track entry remain available. TRACKS opens its
  catalog; RACE THIS TRACK opens the selected track's public rooms, while
  PRACTICE SOLO opens a private session for that track.
- PLAY NOW ranks public human waiting rooms first, followed by one-human bot
  warm-ups and active human races' next-round queues. Existing track identity is
  retained through admission, reserved arrival and rematch. Only an empty public
  directory creates the default Base Track public room. Explicit NEW RACE still
  lets users choose a track and filtered custom/default title.
- Public quick rooms automatically start after the existing per-human 10-second
  item preparation, with two humans or one human plus the existing supported bot.
  Quick-room results return to staging after eight seconds; a completed warm-up
  returns after one. Ordinary explicitly-created public rooms retain host start.
- One-human bot rounds are marked BOT WARM-UP. A new user's destination token,
  actual arrival and character are checked before announcing a five-second
  transition. The bot is removed, the host returns to staging without a forfeit,
  the guest seats/confirms, and both receive a fresh item-preparation window.
  Two-human running races cannot be interrupted. Requests arriving during the
  warm-up countdown are offered a destination reservation once warm-up starts.
- Human reservations displace optional staged bots. Rematchers keep their seats;
  travelling reserved arrivals and queued humans have priority over bots. A bot
  is reconciled out before its replacement human is admitted by RaceController.
- Private practice is hidden from public discovery, rejects other humans and
  queues, disables invitations/bots and starts one human after item preparation.
  Warm-up and private practice do not submit official record/reward observations.
  Human competitive racing retains existing record/reward behavior.

## Shared allocation and lifecycle

`GlobalRaceAllocator` uses a universe-wide MemoryStore hash-map key with a
30-second lease and owner token. Independent HUB services refresh the shared
directory while holding this allocation lease. `ActiveMatchDirectory.stage`
uses a separate atomic sorted-map update for authoritative seat capacity.
Reserved-server access codes and admission tokens remain server-only.

New quick rooms stay hidden while initializing. A stale allocator cannot publish
after its lease is replaced. Teleport runs after releasing the allocation lease.
Uncertain failures clean up the requesting player's reservation, preserving
other entrants. Empty abandoned initializations expire or are removed. Directory
errors produce retry feedback, with no isolated-solo fallback. Admission and
queue leases expire after 60 seconds; connected queued users renew their lease.
An expired creator reservation transfers host identity to the replacement human.

Server logs record HUB job, user, room, track and JOIN/WARMUP_JOIN/NEXT outcome,
without access codes. The existing reserved-server admission, match/track/private
server validation, selected kart authority and item readiness remain in force.

## Display

The list uses the existing four catalog preview assets as small track icons.
Rows show track, filtered room title, state, actual humans, bots, reservations
and next-round queue separately. Recommended rooms receive a gold accent.
Directory failures display unavailable/retrying rather than a false empty list.

Creator references inform logical UI type: mobile title/body/detail/button
22/16/14/16 px; desktop 28/18/16/18 px. Targets are at least 44 px. The safe-area
panel caps at 960x700; narrow portrait stacks each row's action below its content.
Room identities truncate separately from status. Flat button backgrounds avoid
gradient tinting of text. The central kiosk now shows live race information;
the other headings are GARAGE and TRACKS.

## Validation

- `global_race_matchmaking_validation`: 64 checks. Two independent production
  HUB service instances share a yielding mock MemoryStore and transport: one
  reservation, same room/code, authoritative arrivals, race preservation/queue,
  failure rollback, expired seats/host recovery, stale creators and private
  practice isolation. These are production-service tests, not real teleports.
- `public_race_controller_validation`: 22 production-controller checks for
  two-human auto-start, item readiness, warm-up handoff, rejected tokens,
  competitive race protection, public rematch, bounded storage-failure retries
  and one-human private practice.
- `lobby_create_ui_validation`: 40 real-view fixture checks, including responsive
  layout, track icons, filtered titles, optional creation, Unicode limits,
  keyboard access and private practice action.
- Existing suites PASS: directory 27, room service 32, coordinator 18, persistent
  room race 17, reserved arrival 9, reserved match 13, routing 175, production bot
  125, Garage 6,384, guidance state/runtime, showroom 38, mobile HUD 226 and mobile
  input 2,908. RaceItem, fall-reset inventory and Thunder regression suites PASS.
- All 183 production sources compile. Rojo validation build PASS. Diff check
  uses `cr-at-eol` for the repository's existing CRLF files; their endings are
  preserved. Unrelated untracked artifacts and `.vscode/settings.json` stay out.
- The historical `lobby_terminology_validation` still expects the old Track02
  display name; the current `Prototype V2B TEST` catalog name is unchanged here.
  No claim is made that every historical repository test passes.

Actual Studio MemoryStore test: 12 concurrent allocation requests across two
allocator objects produced one winner; eight concurrent seat requests admitted
exactly four. Dedicated audit keys were cleaned up. This ran in one Studio job.
Native CTA mouse input opened PLAY TOGETHER. Mobile runtime: 750x390 viewport,
726x316 safe panel, 22px title / 14px detail / 16px buttons. PC runtime:
1192x1131 viewport, 960x700 panel, 28px title / 16px detail, loaded 72px track
icons and a 160x44 private-practice target with no close-button overlap. Room
rows used Play-only display fixtures; no fake rooms entered public discovery.
No new feature-module runtime errors were observed. Existing Studio DataStore
API/Core UI warnings are separate. Studio is returned to Edit.

Evidence: `artifacts/global-race-matching/studio-runtime-audit.json`,
`studio-source-index.json` and `SOURCE_CHECK.rbxlx` (validation scaffold only).

## Published acceptance still required

Use two accounts in different live HUB jobs: simultaneous PLAY NOW, actual
same-room admission and shared countdown; repeat with a running bot warm-up,
an existing human race, cancellation/failed transfer and private practice.
Studio cannot establish the real TeleportAsync handoff or two-human driving.
Main, racer capacity, track geometry, human physics and persistent inventory
rules are unchanged.

## Release record — 2026-10-16

- User explicitly approved Publish after the implementation and validation report.
- Published code: `9e918123881b2d9ef3560713838d5182fc7e6fab` on
  `prototype/kart-physics`, with local and origin HEAD matching before release.
- Rechecked all 183 native Studio source hashes against the validated candidate;
  no Play-only demo bot remained in Edit.
- Published the existing native Kart Drift Masters place `127925465904803`.
  Studio confirmed successful Roblox publication at 17:56:22 and linked **v766**.
- Evidence: `artifacts/global-race-matching/publish-output.txt`.
- Real two-account, different-HUB admission and shared race acceptance remains
  pending. Publish success does not establish that live multiplayer acceptance.

Primary API references:
- https://create.roblox.com/docs/reference/engine/classes/MemoryStoreHashMap
- https://create.roblox.com/docs/cloud-services/memory-stores/sorted-map
- https://create.roblox.com/docs/projects/teleport
