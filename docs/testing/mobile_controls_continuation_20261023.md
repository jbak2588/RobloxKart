# Mobile controls continuation — 2026-10-23

The interrupted worker had implemented the core layout, auto-forward default,
reverse cap and several tests, but had not committed or completed Studio checks.
This continuation retains those edits and finishes the control scope.

- Left: independent Left/Right steering. Right: Drift above Brake/Reverse.
- Buttons mode automatically accelerates only through existing driving gates;
  Forward/Auto widgets are hidden. Brake overrides; release resumes forward.
- RACE/HUB maximum reverse is 50. Keyboard and developer Joystick rollback remain.
- Fixed double brake/reverse integration in Park: the shared training adapter owns
  fresh input, while the service retains stale-input coasting.
- Fixed short-screen practice items/text overlapping the relocated driving zones.
  Items stay on the left to keep the right thumb available for Drift/Brake.

Validation: 13 focused suites plus Joystick execution passed (14 runs), including
1188 Buttons transport/lifecycle/layout checks, 904 Joystick checks, 641 reverse
transition checks and 260 actual practice hitbox/layout checks. All 206 production
Luau sources compile; Rojo XML/binary builds and diff checks pass.

Studio iPhone 13 landscape preview confirmed the new controls, hidden Forward/Auto
widgets and default auto acceleration. Separate synthetic input packets through
the real server driving path reached reverse -50 and forward +80 after release;
server ownership remained nil. These packets are not hardware touch acceptance.
Android/iOS hardware multi-touch and published acceptance remain unverified.

Rival minimap markers remain: positions are published with ranking at 0.10 seconds.
Hiding markers locally would not remove that server publication. No correlated
capture establishes a link to the reported four-second Rematch hitch, and this
change does not claim to resolve it.

Pre-existing Nitro/grass/flame edits are preserved outside this control commit.
No Roblox Publish was requested for this continuation.
