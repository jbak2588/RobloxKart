# Green crossing / checkpoint paint — 2026-10-26

Fetched baselinea24ca4e matches origin/prototype/kart-physics; clean tree. Owner
requests removal of Green crossing lines and early visibility of checkpoint
checker rows, then narrows checker problem to Park/Green only. No Publish.

## Implementation

The existing local surface controller hides Green CrossoverGuidance paint via
LocalTransparencyModifier1, including late descendants, and restores originals
on teardown. All16 racing-divider dashes and8 outside-edge pieces disappear.
Both asphalt crossing ribbons, geometry, actual route, kerbs, gates and authority
remain untouched. Desert's crossing appearance is unchanged.

Checkpoint checker parts have no distance-driven spawning/hiding; only the
floating pin uses perspective/proximity fade. The two matte tracks' small road
separation allows shallow-view distant occlusion. Their checker-plane lift changes
from.065 to.265 above the selected road/support plane. Other tracks stay.065.
This preserves two rows of16 black/white cells, next-required-gate lifecycle,
missed-gate recovery, banner/pin behavior and existing finish-band suppression.
No extra checker band overlays the standardized four-row server finish line.

## Validation

PASS1,737 production marker perspective/proximity/missed-gate + scoped-height
checks;43 surface/list/theme-isolation checks;230 production sources compile;
1,851 frozen-world/grid/paint checks; all5 official + Park skid contacts and25 VFX
lifecycle checks; default Rojo build and diff whitespace checks.

Native ordinary Green startup: all24 crossing paint pieces hidden, both asphalt
ribbons retained; surface Ready. An ordinary temporary LocalScript uses production
CheckpointGuidanceController with a read-only attribute proxy (no server progress,
player state, seat or kart mutation). Each of six required gates immediately has32
opaque checker parts; all bottomsY=.317500043, above the crossing ribbon maximum
.12 by.1975. Finish has0 duplicate checker parts. Controller teardown leaves no
KDMNextCheckpoint folder. This checks scene geometry without approach-based writes;
real-device moving-camera acceptance remains separate.

Native production Hub/Park: seven trial gates ready. The same read-only proxy
exercise gives32 immediately opaque cells for each of six checkpoints, all bottoms
Y=.252499986 (asphalt+.02, clearance.2325). Finish has0 duplicate cells; teardown
removes the guidance folder. Ordinary source initializer is restored/verified in
Edit; all temporary Play QA scripts/state are discarded.

No Publish.
