# Speed Sensation V2 Phase 1 — local candidate

Baseline: local HEAD and fetched origin/prototype/kart-physics both
f5ebec8c7f86dac5c488f90a0a01041d147cf4a2; working tree initially clean.
Owner approves local implementation and validation only. No Publish, Git
commit/push or production rollout is authorized for this task.

## Assessment and scope

Changed only HIGH_SPEED_START55→50, HIGH_SPEED_FULL80→90 and HIGH_SPEED
FovDelta3→5 in src/shared/KDMSpeedSensation.luau, plus profile expectations in
tests/speed_sensation_validation.luau and tests/speed_sensation_camera_validation.luau.

At base FOV75, settled targets are:

| Motion | Before | Candidate |
| --- | ---: | ---: |
| Forward70 |76.944°|77.5°|
| Forward80 |78°|79.21875°|
| Held GAS90 |78°|80°|
| Mini Boost |81°|81°|
| Nitro |85°|85°|

70→90 FOV separation grows1.056°→2.5°, approximately2.37x. This supports a
bounded speed distinction; perceived benefit and motion comfort require device QA.
MAX_FOV87, attack10/release5 exponential easing, chase position/tracking and
all physics/GAS/Drift/Boost/Nitro/network/track/HUD source files are unchanged.

The existing world renderer also consumes the shared HIGH_SPEED intensity for
air-trail width/transparency. The requested thresholds therefore also change its
50–90 ramp (including slightly weaker trails at70/80). Trail constants, instance
budgets and Mini Boost/Nitro particle profiles are unchanged. This is not a new
camera-only resolver or a renderer rewrite.

## Validation

- speed_sensation_validation:1663 profile/priority/cadence checks pass, including
  30/60/120 FPS and alternating30/60 FPS easing. The full command exits1 at the
  preserved historical source-freeze check, as it already did before this edit.
- speed_world_vfx_validation:1402 production +14852 particle checks PASS.
- speed_sensation_camera_validation:40 actual camera-owner checks PASS.
- camera_motion:6 cases/3000 variable frames; impact_camera:124; r8_d4_camera:2613;
  r8_d4_restore_camera:3600 frames; finish_presentation:29 PASS.
- race_network_ownership, gas_pedal (881 actual integration +27 policy),
  mobile_controls_v1 (494 controller/HUD +3528 geometry) PASS.
- Full Rojo build to %TEMP%/kdm_speed_sensation_v2_phase1.rbxlx and
  git diff --check PASS.

## Unmodified validation gates / required approval

Both speed_sensation_validation and finish_source_freeze_validation already
failed before editing at src/client/FinishCameraComposition.luau versus the
historical fixture. Those unrelated baseline mismatches remain unresolved.

Additionally tests/fixtures/n2_source_freeze.json freezes KDMSpeedSensation:
- Original/expected SHA256:54df42b823b45fc14e2057169f636b150fd41ad05c6ab42e879925244d311013
- Candidate SHA256:a1bdca31a8c1dbae506aaab0857a96b330ce7b1353d1a909803ea3b4c5c98e15

No fixture/hash/normalizer was edited or bypassed. To clear this new conflict,
explicit approval is needed for an exact Phase1 exception covering only these
three profile constants while rejecting every other mutation. It must preserve
the original hash and all unrelated historical failures, not regenerate baselines.
This report does not claim all validation passed or deployment readiness.

Studio runtime NOT VERIFIED. No Studio model was changed and no QA or production
Publish occurred. After resolving validation gates and obtaining any required
Publish approval, mobile testing belongs only to Universe10772198697 /
Place106553302629620, Private. Check70/GAS90 comparison,30/60 FPS transitions,
Mini/Nitro, Drift, off-road, release, finish/reset, HUD readability and nausea on
iPhone/Android. Automated easing tests do not establish those device results.

Rollback is limited to restoring the three original profile constants and their
matching test expectations; no server, geometry or camera algorithm rollback is
needed. All changes remain local and uncommitted.
