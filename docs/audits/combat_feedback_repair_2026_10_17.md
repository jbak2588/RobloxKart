# Combat presentation repair — 2026-10-17

Review baseline: `3089cee5c13390ecd54e7470ff23e493b59166a4`, fetched and matched
against `origin/prototype/kart-physics` before editing. Tracked working tree was
clean; existing untracked artifacts were preserved.

## Findings and repair

- The new `spawnMissileImpact` and `attachThunderCloud` client functions had no
  callers. Production uses `HomingMissileService` / `ThunderStrikeService` →
  `RaceItemVisuals`. Enlarging their unused config did not enlarge live effects.
  Removed those disconnected implementations and their unused settings.
- The added screech helper assigned its Sound to an undefined `Workspace` global,
  leaving it unparented and inaudible; its parent-guarded cleanup also skipped
  destruction. It started at the beginning of the asset,
  unlike the existing tire controller's selected 5–8 second skid region.
- Attacker hit confirmation explicitly reused `BOOST_START`. Removed that cue.
  Slick now drives the seated victim's existing local tire loop from their own
  authoritative `KartSlickActive`, even though the hit cancels normal Drift and
  may leave low/aligned velocity. Existing fade, sound group, playback region,
  seat/character/Garage cleanup are reused; no new sound asset was introduced.
- The duplicate `HitConfirmedBadge` used a gold `UIStroke` with default Contextual
  mode, which strokes the text glyphs, rather than a border. Its scaled text and
  2.5px stroke explain the reported unreadable glowing text. Removed this duplicate
  badge and restored the single accepted cyan combat result for attacker/victim,
  retaining item/target names and Thunder hit/block counts.
- Actual replicated Missile impact now expands from 4 to 28 studs over 0.85s;
  a 16-segment horizontal Neon ring expands to 36 studs. Spark radius is 14.
  Existing service cleanup owns every child. Shield block stays a small 0.42s
  cyan effect, without the ordinary explosion/ring. No PointLight or screen flash
  was added; visible world geometry supplies the impact.
- Actual replicated Thunder warning now spans 12.5 studs, uses 4.5-high,
  9.5-deep dark puffs, and follows the victim at a 7.8-stud offset. Three native
  puffs are used, preserving the existing bounded instance count. Lightning is
  thicker and connects the elevated warning height toward the kart; the existing
  short strike lifetime and dim Shield-block distinction remain intact.

Gameplay physics, damage/effect durations, targeting, charges, immunity, Nitro,
Slick spin policy and mobile controls were not changed.

## Validation

15 focused validation files PASS:

`item_vfx`, `item_world_vfx`, `item_local_vfx`, `remote_world_vfx`, `slick_spin`,
`missile`, `thunder`, `combat_feedback_view`, `kart_audio`, `lobby_palette`,
`hub_next_action_guidance`, `garage_h2_flow`, `impact_camera`, `race_item`,
`mobile_touch` (each with `_validation.luau`).

Coverage includes actual production visual construction/updates, 12.5-stud cloud
bounds and target following, visible midpoint blast/ring, finite cleanup and
noninteractive parts; four-racer/20-cycle world VFX simulation (1,402 checks);
Slick spin regression (5,756 checks); audio victim versus attacker dispatch,
correct skid playback region, no hit-triggered booster onset, expiry/lock/seat/
Garage cleanup; readable single combat badge and Thunder victim feedback.

All changed Luau files compile. Rojo build and `git diff --check` PASS.
Local logs/build: `artifacts/combat-feedback-repair/` (untracked).

Two additional legacy tests remain FAIL and are **not** reported as passing:

- `item_aftershock_validation`: behavior checks run successfully through the
  visual/camera/20-cycle section, then the historical exact-source freeze fails.
  Baseline snapshot also fails (at the disconnected client VFX controller).
  After removing that code, the test advances to a pre-existing gameplay-balance
  source hash mismatch. The immutable fixture was not rewritten to hide this.
- `gameplay_balance_validation`: baseline and repaired trees both fail at the
  pre-existing public `DRIFT_CAMERA` key whitelist mismatch. Gameplay balance
  source is unchanged by this repair.

Baseline failures were reproduced using copies read directly from the baseline
Git commit in `artifacts/combat-feedback-repair/baseline/`.

No Roblox Publish, live-game source replacement, Studio visual acceptance or
real-device listening was performed. A fresh local/published multiplayer visual
and listening retest is still needed to establish user-facing acceptance.
