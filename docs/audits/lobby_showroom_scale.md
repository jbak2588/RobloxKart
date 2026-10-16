# Lobby showroom kart proportions — 2026-10-16

The seven static V2 showroom karts now use a uniform 1.2 visual scale, applied
before floor alignment. This follows the requested 20% enlargement and gives
the exhibited karts more presence beside standing Roblox avatars. The supplied
KDM icon images are visual references; no icon assets or new vehicle art change.

Only `src/client/HubUiController.luau` changes production behavior. Each fresh
factory visual is scaled once; refreshes do not accumulate scale. Grounding,
bay locations, TEST DRIVE prompts and temporary preview selection are retained.
Live player/demo karts, seating and physics retain their existing dimensions.
The two existing display/Garage test fixtures now model native Model scaling,
which Lune does not implement.

Validation:

- Existing display safety/grounding/replacement checks: 15 PASS.
- Garage transition/layout/invite/orbit checks: 6,384 PASS.
- Showroom selection/admission checks: 38 PASS.
- Drive loop/building safety checks: 4,753 PASS.
- Rojo build and CRLF-aware diff check: PASS.
- Studio Play: all seven exhibits have scale 1.2, approximately
  8.28 x 3.20 x 11.19 studs in their local axes; tire bottoms remain at Y=0.33.
  Standing test avatar height is approximately 5.65 studs. Native landscape
  view inspected with an avatar beside the hero kart; bays remain separated.
- Actual existing Drive/Stop RemoteEvent path: successful seating, live visual
  scale 1, exit and recreation of seven scale-1.2 exhibits. Temporary camera and
  comparison avatar existed only in Play; Studio returned to Edit.
- Historical `hub_world_progression_validation` still expects a fresh user to
  choose Garage; the already-published people-first flow chooses Race. This
  unrelated stale expectation was observed, not modified in this visual task.
- Android/iPhone visual acceptance has not been performed for this enlargement.

Baseline: `cc3e3451deceb936d6ecc10a95570a005b7786d6`, matching origin before work.

Release: implementation `284811f6504e61c235ab838be651d28bab6d969a` committed
and pushed to `origin/prototype/kart-physics`. Native Studio source exactly
matched the committed candidate before publishing the requested Lobby exhibit.
Studio confirmed successful publication to place `127925465904803` as **v767**
on 2026-10-16 at 18:43:26. Real-device appearance remains pending user acceptance.
