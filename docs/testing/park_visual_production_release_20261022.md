# PARK visual rollout — 2026-10-22

Owner approved commit/push and clarified that PARK is to be public in production
KDM (Universe 10768420544 / Place 127925465904803), rather than staging only.

Includes the preserved A1 faceted island skin, A2 small static landscape pass,
and Figure-8-style arch, four lighting towers and 90 KDM rail panels. No further
cliff improvement was made after the owner's direction change. Roads, Pit,
FlatSupport, kart physics/authority, items, HUD and manual boarding stay unchanged.
The official Figure-8 RACE builders/controllers are unchanged.

HubParkRuntimePolicy now accepts the exact production pair with the explicit
HubParkV1Enabled attribute. Staging remains allowed. Mixed IDs, RACE role and Bot
test mode remain excluded. Default builds keep the flag unset/OFF; the release
place sets it ON. To disable PARK, set the attribute false and publish a new
place version; no old economy-code rollback is required.

Validation: 24 focused suites PASS / 3 existing FAIL / 0 new FAIL. Existing
failures are lobby_practice_combat_validation (historical four-item contract),
lobby_post_drive_return_validation (historical Garage callback), and
v2_gauge_v1_audio_validation (old audio snapshot). No assertions were changed to
hide these failures. Exact production ON/OFF, RACE isolation and mixed-ID cases
are covered in startup/world initialization tests.

205 production Luau files compile; Rojo XML and binary builds and diff check PASS.
Native isolated Studio creation confirmed 133 decor parts / 16 lamp meshes /
90 branded rails, no errors and no collisions/queries on decor. Mobile acceptance
of the earlier flat road remains owner-confirmed; the additional A2/decor mobile
performance and post-publish checks are not established by that acceptance.

Publish outcome/version is recorded in the task report only after Roblox confirms
the upload. This document does not claim a completed publication.

Native Studio input-driven full loop plus Pit return: 125.97 seconds, zero stalls
and resets; Nitro/Shield exercised; RETURN LOBBY clears active/pending/seating/kart.
