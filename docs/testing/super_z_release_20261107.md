# Super Z-Track official release — 2026-11-07

Owner requests the supplied Super Z preview immediately after Rookie Park
Overtake and a four-racer, three-lap public race. Commit/push and official
Publish authorized for Universe10768420544 / Place127925465904803 once tested.
No server restart or other release is included.

## Implementation

- `SuperZ` / `SuperZV1`: separate track, route, room, record and rematch identity.
  Existing public1–4 player policy, optional existing room Bot, three laps.
  Hub order: Overtake → Super Z → Rookie Park Multiplayer → original tracks.
  Original default Track01 and existing catalog order retained.
- Preview `rbxassetid://104331982200577` is the supplied Image asset.
- `KDMSuperZResources.rbxmx`: static scene extracted from the accepted local
  native model, with both paved inner corners,73 trees, four island guards,
  and seven seamless visual MeshParts. No prototype scripts were imported.
- Official builder adds four paint/grid slots, the finish and12 checkpoints.
  Uses existing physical ground, native Park material and nonphysical scenery.
- Super Z road queries include variable width and both added asphalt polygons.
  The nearest-reference route originally used the old corner centers, which
  could be ambiguous on inner lines. Final reference follows the revised
  inner boundaries into the road; sample length5699.87 studs. The visible
  course, outer road and start/finish are unchanged. This reference length
  differs from the original6,000-stud design centerline.
- No other track's road/controls/GAS/Drift/Nitro/items/reward policy changed.
  The suspended KDM-R design work was not resumed.

## Validation

- Original Git baseline local/fetched origin `450c41adf4ecc096a8659fed40628849b8bb0fa2`.
- Super Z:12,551 checks including four independent ordered three-lap route
  states, four legal inner/outer lane cases, shortcut rejection, native asset
  structure, exact source hashes and mutation rejection.
- Actual Garage component test: Overtake → Super Z → Park Multiplayer;
  original Park request remains isolated. Production-pair Studio Hub opens
  normally. ImageLabel preload for the supplied asset returned Success; the
  actual Garage Ready RemoteEvent opened the Super Z room browser. Physical
  automated arrow clicks did not advance the native picker; order evidence
  is from the actual component fixture, not a native mouse acceptance claim.
- Existing four-player controller55, race route4434, GAS, item refill, room,
  paint and bot contracts passed. Final raw suite:267 validations including
  reruns of updated assertions;246 PASS,21 failures also present at baseline,
  zero newly failing validation identities. Historical failures and logs stay
  visible. This is not FULL_SUITE_PASS.
- Rojo final build and git diff --check passed. All244 runtime source files
  match official Edit normalized byte lengths/checksums; no missing/extra
  runtime source in the compared trees. Three release flags remain true.

## Native driving and release gate

- Controlled Studio real physics with existing human-input validation and
  unmodified kart physics/ownership. First reference route290.90s for three laps;
  final corrected route in local Studio284.04s; exact official ID pair with
  GAS active at89–91stud/s finished3/3 in274.20s (92.08/91.25/90.88).
  No DNF. The automated driver had brief grass excursions with recovery;
  this is not a clean manual line or a physics balance change.
- Real ordinary Client clone153/153 positive-intrinsic MeshParts (7 road,
  146 tree), actual asphalt, kerbs, lap HUD, items and directional minimap.
  Native preflight found Rojo-created empty MeshIds; restored the9 existing
  owned asset IDs with the scoped Edit-only repair script. No runtime mesh
  generation or security changes. The repaired source and client clones
  passed; native pre-publish Download Copy is preserved.
- Actual Finish ReturnGarage RemoteEvent invoked the local test return callback
  and released the seat; published reserved-server teleport and real4-human
  races and mobile device driving remain unverified. Studio's original
  preferences API-disabled warning was observed; no live data was written.
- Temporary QA startup/input adapters removed; standard Server and Client
  initializers restored. Exact official pair verified in Edit, metadata1315
  before publishing. Metadata is not itself a publication receipt.

Evidence (ignored local artifact directory): `artifacts/super-z-release-20261107/`
contains native pre-publish copy, build, drive results, regression logs,
baseline comparison and publication receipt. Git retains the authored scene,
route/policy, tests and reproducible extraction/repair tools.
