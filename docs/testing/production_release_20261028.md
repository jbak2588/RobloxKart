# KDM consolidated production release — 2026-10-28

Owner explicitly confirmed mobile testing complete and authorized commit/push and
official Publish in this conversation. This supersedes the earlier task-specific
private-only/no-Git instructions for these accepted changes.

## Scope and provenance

- Baseline local and freshly fetched origin: f5ebec8c7f86dac5c488f90a0a01041d147cf4a2,
  branch prototype/kart-physics. Main unchanged.
- FOV Phase1: HIGH_SPEED_START50, FULL90, FovDelta5 only. Mini/Nitro/MAX_FOV,
  easing and camera tracking retained.
- V3.2 handoff included: orange cruise exhaust retained during Drift; blue
  Mini/Nitro priority; demoted air trails; wheel-vortex removal. Screen-space
  lines and experimental camera-airflow implementations are retired, not enabled.
- R3: invalid official finishes grant zero base/PB/first-finish money;
  public track capability-label encoding repaired. Other economy unchanged.
- R1/R2/R3 contracts, tests, reports and original historical fixtures retained.
- Mobile acceptance: OWNER_REPORTED_COMPLETE for this release. This does not
  independently establish four-human or long-session network-hitch acceptance.
- Proposed Park seven-bot overtaking mode was reviewed only and is NOT included.

## Handoff reconciliation

The handoff's c84dc14c... hash was stale. Actual local and QA Edit source match
exactly at canonical LF SHA256
`0c606e01d8c63e3938430730d49ca033663033fd648bb833690bb300e2e0e1fb`.
No renderer behavior was changed during release preparation. The current-release
exception now pins that exact accepted source, independently checked by Python;
original f5ebec8 and N1/N2 hashes were not replaced. Extra/deleted source mutations
remain rejected. At85stud, smoothstep rounds to bucket19 (four trails), and the
cruise plume formula yields26 per side /124 total particles per second. Three
stale test values were corrected without weakening the assertions.

## Validation

- Full raw suite:249 processes,229 PASS /20 historical FAIL. NOT FULL_SUITE_PASS.
- Current-release subset229/229 PASS; same historical failure identities as R3;
  no newly failing tests.
- Source integrity683 checks across133 protected sources PASS, including source
  mutation rejection and original historical-artifact preservation.
- Independent Python audit --check-manifest PASS.
- Speed world VFX1562 production +28152 profile/budget checks PASS.
- GAS/Touch/Camera/Ownership, combat, wallet/ACK/DataStore, finish/Rematch are
  included in the current-release suite. No live account mutation by tests.
- Rojo default build PASS; git diff --check PASS.
- Raw logs/build/snapshots:
  C:/Users/Public/Documents/ESTsoft/CreatorTemp/kdm-production-release-b4skdnq5/.

## Studio and deployment preparation

Exact production pair verified in Edit: Universe10768420544 / Place127925465904803.
Loaded Studio version1236 is not a publication receipt. Creator Dashboard's
published-only history confirmed previous published version1234, recoverable via
Restore then Studio Publish. Saved but unpublished versions1235–1237 are distinct.
Compared222 project scripts against canonical local hashes; only the old renderer
differed before synchronization. Applied that one module and rechecked:222/222
exact source matches,231-script inventory unchanged except that module. Workspace
HubParkV1Enabled / KDMControlsV1Preview / KDMGasPedalEnabled remain true.
No full-world sync, geometry mutation, ownership write, account migration or
server restart. QA access settings remain untouched.

## Verified publication receipt

- Status: PRODUCTION_PUBLISHED, Place version **1238**.
- Creator Dashboard published-only history confirms1238 at October28,2026,
  9:27PM (dashboard local display). Previous published1234 remains recoverable.
- Source/test/contract commit: `317a844`; pre-Publish pushed HEAD: `86350f6`.
  Later commits contain document cleanup and this receipt only.
- Native official Studio File > Publish (Alt+P), exact production pair above.
- QA Overview re-read after production Publish: Game access Private and Audience
  reach Private. No QA access-setting mutation.
- Post-Publish inventory:222/222 project source hashes match validated local;
  all231 script hashes unchanged since the one-module synchronization; all three
  Workspace release flags still true. No server restart or QA Publish performed.
- [Published version history](https://create.roblox.com/dashboard/creations/experiences/10768420544/places/127925465904803/version-history)
- [Official game](https://www.roblox.com/games/127925465904803/)
- Working and baseline-to-release `git diff --check` PASS after imported document
  formatting cleanup. Original R1 audit content/bytes restored and retained.
- User-reported mobile acceptance precedes this release. Post-publication
  real-device re-entry is not independently replayed here; existing live jobs
  were not forcibly restarted.

## Rollback

For deployed rollback, restore previous published production version1234 in the
same Place, open and Publish it in Studio. Do not select QA or change access.
For Git rollback, use a reviewed revert of the release commit, never reset/force
push; FOV, VFX, eligibility and label fixes can be reverted separately by file.
Historical reports describe their original checkpoints; this document records
the later owner acceptance and deployment status.
