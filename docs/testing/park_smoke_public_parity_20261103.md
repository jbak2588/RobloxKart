# Park drift smoke parity release — 2026-11-03

Owner requests matching Park Time Attack / Overtake drift smoke emission and
particle lifetime to public races, then explicitly authorizes Commit/Push/Publish.

- Runtime/test commit: `2bc1a29`, branch `prototype/kart-physics`, pushed to origin.
- Park uses the public slip-angle emission curve, capped at 34 particles/second
  per rear wheel (formerly 68), and lifetime 3.0–4.2 seconds (formerly 6.5–8.0).
- Park particle size, opacity, motion, skid trails and boost visuals are retained.
  Public race behavior and legacy Lobby density remain unchanged.
- `park_smoke_parity_validation.luau`: PASS, including matched slip/LOD/lifetime,
  stopped emission, and 27 existing world-VFX harness checks.
- `performance_vfx_followup_validation.luau`: PASS, including 51 world-VFX checks.
- Scoped staged diff check: PASS. Historical failures were not rerun or relabeled.
- Production Studio Edit: exact Universe10768420544 / Place127925465904803.
  All 238 local runtime scripts match normalized byte length and rolling checksum;
  all 247 Studio script entries were unchanged across publication checks.
- HubParkV1Enabled, KDMControlsV1Preview and KDMGasPedalEnabled remain true.
  GasPedalPolicy.Speed=90; enabled(actual universe, place, flag)=true.
- Native Studio output confirms publication v1307 on 2026-11-03 at 16:57:28
  (Asia/Jakarta). Edit game.PlaceVersion still reports1305; this is recorded
  separately and is not used as the publication receipt. Dashboard history was
  not independently checked in this release.
- Existing owner-selected native baseline backup remains preserved at
  `artifacts/pv1289-baseline/KDM_Owner_Selected_Studio_Baseline_20261103.rbxl`.
  No new native backup was completed during this release.
- No production server restart, cloud Restore, access change or account write.
  Mobile hitch improvement and post-publication device acceptance remain unmeasured.

The user described roughly one mobile hitch per Park run during drift plus boost.
This release changes smoke density/timing; it does not establish the hitch cause
or claim to eliminate it. Suspended KDM-R work and unrelated files are excluded.
