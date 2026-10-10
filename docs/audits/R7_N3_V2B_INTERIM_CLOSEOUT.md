# R7-N3 V2B Interim Track — Scoped Closeout

2026-10-10. R7_N3_SCOPED_CLOSED. V2B remains an interim track.

The final abrupt Finish-entry corner improvement is CLOSED. The B geometry, static Barrier clearance improvements, Studio scripted two-lap completion and double-BOOST feasibility are accepted within that scope. Existing public KDM Experience 10768420544 / Start Place 127925465904803 published PV 545 successfully. The user confirms mobile two-lap completion in the final closeout request. This is user-supplied acceptance, not a new agent device test.

Track02 now selects PrototypeCircuitV2B with display name Prototype V2B TEST, matching the published P1 candidate. TrackId, PUBLIC_RACE, four-racer capacity, two laps, six checkpoint order, GridSlots, preview asset and Bot policy remain unchanged. Legacy V2 geometry remains defined. The preview thumbnail still depicts Legacy V2.

## Accepted boundary and known limitations

V2B is not accepted as the final Drift/Nitro-optimized track. Further V2 optimization stops here. P15's approximately 26.882-stud radius bottleneck remains; stable Boost exits across all mobile sectors, Bot and actual multiplayer acceptance, device FPS and sustained object/memory budgets are not fully certified. CP6 moved approximately 159.7 studs; scripted and user-confirmed two-lap completion do not establish every multiplayer lap edge case. The earlier scripted sample recorded 4.2117 seconds off-track across two laps and a static export of 2159 Parts; neither is a mobile performance certificate.

The next milestone is a new Drift-first track design, under a separate scoped task. No new track or V2 geometry/physics tuning is part of this closeout.

## Source and Git integration

Feature baseline: feature/r7-l2-kdm-lobby-ux at 10e59366eeaea9900cb2b2a0ca60ee611cf9b88a.
Production baseline: prototype/kart-physics at 647be04b28e63f23e2826cfb0bc1e50b9cad2232.

This checkpoint preserves the three source files identical to the PV545-approved candidate, the two B direct validations and helper, and the exact-source B historical inverse runner/specification. Existing historical assertions and N1/N2 fixtures are unchanged. No large builds, screenshots, or temporary logs belong to the commit. The commit containing this document is the feature checkpoint and is integrated into Production by fast-forward only; exact final local/remote SHAs and validation evidence are recorded in artifacts/r7-n3-closeout/RESULT.md after integration.

Published candidate file SHA-256: b2c77e381bde68856bc5760535592ec978152de9258713d10b3d962bb06a49d0. Source parity is exact against artifacts/r7-n3-a1b-p1/test-build. PV545 publication was verified in Studio Output and Version History; this Git task does not republish.

## Reproduction from a full clean clone

Run these existing commands at repository root with Lune and Rojo installed:

```text
lune run artifacts/r7-l3-a1-mobile-fix/compile.luau
lune run artifacts/r7-n3-closeout/catalog-freeze-runner.luau tests/track02_raceability_b_validation.luau
lune run tests/track02_published_binding_validation.luau
lune run tests/track02_barrier_safety_b_validation.luau
lune run tests/track_environment_validation.luau
lune run artifacts/r7-n3-closeout/catalog-freeze-runner.luau tests/track_h3_flow_validation.luau
lune run artifacts/r7-n3-closeout/catalog-freeze-runner.luau --self-test
lune run tests/reserved_arrival_validation.luau
lune run tests/reserved_match_validation.luau
lune run tests/race_launch_routing_validation.luau
lune run tests/persistent_room_race_validation.luau
lune run artifacts/r7-n3-a1b/compatibility-runner.luau --self-test
rojo build -o <external-output-path>.rbxl
git diff --check
```

The B geometry test requires the feature baseline commit above in Git history. Its historical diagnostic-only Catalog assertion is preserved through an exact two-field inverse, while B geometry/route assertions execute current Geometry and Builder. The separate current-binding test generates B using the actual Catalog. The H3 historical byte freeze receives that same strict inverse only on its first Catalog read; subsequent UI and routing assertions receive actual PV545 Catalog bytes. Both target test hashes and current/baseline Catalog hashes are pinned, with mutation rejection. Original direct failures remain in the closeout evidence.

The strict B runner accepts only enumerated historical targets and exact reviewed Geometry/Builder inverses; it never substitutes direct B validation or grants generic exceptions. The prior 113-command evidence remains historical and is not represented as a new 113-command closeout run. New closeout validation: 14/14 effective checks passed in an isolated clean candidate clone, including 131-source compile, 48,828 B route checks, 47,517 Barrier checks, 244 current H3 UI/route checks, current Catalog/Builder binding, Reserved routing, both adapter self-tests, Rojo and diff checks. Initial direct run: 10/12; two historical Catalog-contract failures recovered without assertion edits.

Original A0/A1B reports remain unchanged. Roblox Publish: NO in this closeout. PV545 remains the published version.
