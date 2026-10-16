# SHOP color restoration — 2026-10-16

- Baseline: a961d4c7e455df873697937c1b8bba3ffadc48c8, matched origin/prototype/kart-physics before editing.
- Removed direct Shop gradients that multiplied button glyphs, backgrounds and ViewportFrame model colors. Restored flat authored navy/blue/green/red colors; softened button text outlines. Shared styling outside Shop is unchanged.
- Visible WINGS category becomes KART PARTS, allowing future exterior parts. Internal WINGS routing and existing wing product/ownership behavior remain compatible.
- User's quota condition: driving-kart enlargement and seating/camera work deferred; this release contains Shop presentation only.
- Validation: visual geometry suite 389 checks PASS; Rojo build PASS; whitespace diff check PASS.
- Studio iPhone 13 Pro landscape: KART PARTS kart preview, RACE ITEMS green action and MY INVENTORY blue action visually checked; all Shop UIGradient descendants absent. Tab clicks work. Native original place retained.
- Studio visual fixture only: profile response with owned wing and voucher counts; Garage context supplied to separately required test module. No persistent writes/purchases. Stopping Play removed all fixtures before Publish.
- Existing arcade-shop and shop-navigation suites cannot initialize: their mock module map lacks KDMUiStyleHelper (GarageShopController line 12). Not reported as passing. Purchase/save logic was not changed.
- Published mobile acceptance remains pending.

- Release: implementation 18ce82399b7b920283b4406bd3b36bf7c7ad5aa5 pushed and remote HEAD verified. Explicitly authorized native Studio Publish succeeded at 23:05:46, place 127925465904803, version 778 (Studio success output).
