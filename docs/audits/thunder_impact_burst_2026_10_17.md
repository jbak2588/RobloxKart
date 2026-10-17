# Thunder bolt followed by Missile-style explosion

Baseline `cc9cbdfeaef869c7bc406a6e35a00c4cbbbac24b` matched origin after fetch;
tracked working tree was clean. User authorized a post-bolt explosion with
Size 28 / Shockwave 36 / light Range 38 and Brightness 9.

Unshielded Thunder now creates a hidden copy of the live Missile impact geometry.
It becomes visible 0.10 seconds after the initial bolt, grows using the existing
28-stud blast and 36-stud, sixteen-segment ring, and fades over 0.85 seconds.
One world PointLight per strike peaks at Range 38 / Brightness 9 and fades
quadratically to zero. Shadows are disabled. No UI glow/stroke/flash was added.
The existing Missile impact itself is unchanged; the requested PointLight is new
to Thunder only (production Missile had no PointLight).

ThunderStrikeService retains ownership and its 24-flash cap; actual hits now keep
their cosmetic container for 0.95 seconds total. The bolt retains its original
0.46-second fade. Shield blocks retain their original short, dim effect without
the new explosion, ring or light. Expiry, reset, departure/session cleanup destroy
the full subtree. Update loops allocate no new instances. Native effect has
40 descendants, including the single light.

Both Race and Hub practice already use these production visual/service modules.
No warning time, targeting, immunity, Shield resolution, speed cap, gameplay
effect duration, camera shake or audio changes.

Validation: 11 focused suites PASS: world visuals 101, VFX/config 246, four-racer
20-cycle world simulation 1,402, Thunder 121, practice combat 447, Missile 136,
race items, fall reset 345, audio 31, combat feedback 108 and impact camera 124.
Changed sources compile; Rojo build and diff checks PASS.

Isolated native Studio Edit probe at place 127925465904803 confirmed hidden
pre-burst geometry/light, full 38/9 light at 0.10 seconds, visible midpoint blast,
28/36 maximum extent, complete light fade, short Shield lifetime and final
0.95-second cleanup boundary. Temporary instances remained outside the game world
and were destroyed. Existing Studio sources were not replaced. Actual visual
playtesting and mobile acceptance remain unverified; no Roblox Publish.

Untracked logs/build: `artifacts/thunder-impact-burst/`.
