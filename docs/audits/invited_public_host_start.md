# Host decides departure after invitations — 2026-10-16

Baseline `4d3a18612d916808c4f594a1542eeaec9517ebbe` matched origin before work.
Follow-up to the published people-first matchmaking fixes.

Sending a validated host invitation now switches that reserved room to explicit
host start for its remaining lifetime, including rematch and host migration.
The gate is latched before yielding storage lookups. Pending response/admission
blocks host Start; acceptance/decline alone never starts a countdown. Once
responses resolve and the existing per-human item preparation is ready, the
host chooses START RACE. A full invited room also waits for this decision.
Uninvited PLAY NOW matching and its normal automatic starts remain unchanged.

RoomSocialDirectory keeps a short-lived ACCEPTED/DECLINED response in the existing
invite entry, with original expiry and expected room/host/expiry fencing. Consumed
responses no longer produce invitations. The reserved coordinator publishes
responses, pending counts and a server-owned manual-start mirror. Accepted but
absent entrants remain guarded until membership/admission or expiry. The existing
authoritative startRound arrival/roster checks remain active. Responses are shown
as ACCEPTED/DECLINED: name; WAIT REPLY disables the host action while pending.
Response display history expires with the invitation. No seat/capacity, item,
physics, track, reward or room allocation policy changes.

Production files: RoomSocialDirectory, MatchRoomService, RaceRoomCoordinator,
RaceController, server init and RaceHudController.

Validation:

- New invited-room production controller: 11 PASS, including two-human wait,
  pending server rejection, guest rejection, full-room host start and one countdown.
- Coordinator: 25 PASS, including explicit acceptance/decline visibility, absent
  accepted entrant gating and invitation-scoped pending removal.
- HUD: 263 PASS plus D2 integration; pending WAIT REPLY, ready START RACE and
  unchanged ordinary quick AUTO START are explicitly covered.
- MatchRoom service 32, uninvited public controller 22, global matching 64,
  active directory 27, reserved arrival 9 and warm-up rewards 13: PASS.
- Native Studio real MemoryStore: four acceptance/decline checks on an isolated
  GUID-named QA map; test entry removed, no public directory fixtures written.
- Studio 750x390 iPhone emulator: real HUD executed with Play-only room/status
  fixtures; WAIT REPLY inactive, then ACCEPTED: Invited Friend and active
  START RACE. Native screenshot confirms readable status and 44px start target.
  This is UI/runtime evidence, not a two-human cross-server invitation test.
- Rojo build and CRLF-aware diff check PASS. Studio returned to Edit;
  Play-only fixtures are discarded. Published two-account acceptance remains pending.
