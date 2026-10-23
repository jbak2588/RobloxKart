# Mobile right-thumb item layout — 2026-10-23

- Move six race items (four attacks above Nitro/Shield) and Nitro Charge to the right above the driving row.
- Narrow Drift artwork to 140px (132px portrait), retain its aspect ratio and full hitbox, and align Brake/Reverse to its right with an 8px gap. Left steering and input ownership are unchanged.
- Move LOBBY/NEXT and INVITE RACERS into the former left item lane. Invite uses transparent fill, white outline and white text. Keep the minimap at its existing top-right position.
- Apply the same right-item/bottom-row arrangement to Park TEST DRIVE, with RETURN LOBBY on the left. Retain tiny-window scrolling fallback.
- Preserve six-item direct use, emergency Shield, Nitro reward state and desktop input. Full transparent item/control artwork replacement remains future work.

Validation: mobile input Buttons 1188 / Joystick 904, six-item production HUD 453, mobile HUD layout 513, race/result HUD 264, Park practice layout 260, Lobby mobile 7813, speed HUD 28 and control icons 569 checks PASS. All 206 production Luau files compile; scoped Rojo XML and binary builds and git diff --check PASS.

Studio iPhone 13 landscape: viewport 750x390 / safe canvas 750x332. Actual Park TEST DRIVE presentation checked. Race HUD checked using a temporary client RACING state and room snapshot on the Park scene; this was a presentation preview, not an official race or full-lap test. Studio returned to Edit; temporary runtime changes discarded. Android/iOS hardware multi-touch and driving acceptance of this new layout remain unverified. No Publish performed.

Pre-existing exhaust, practice-combat, test-drive-service and two related test changes were preserved and excluded from this commit.
