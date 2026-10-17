# Practice Shield matches race presentation

Baseline `64fe30f4a4430892a3229de94b21f818ce37e65f` matched origin after fetch;
tracked working tree was clean.

The common world observer skipped the local player's entire Lobby kart because
the test-drive controller already owns its exhaust. That also skipped Shield
rendering, leaving the basic replicated 9 x 6.5 x 11 shell visible to the driver.
Race uses ShieldWorldRenderer: an avatar/kart-fitted shell, soft glow, pulsing
surface and eight counterrotating orbit trails.

Local practice now skips only the already-owned exhaust/speed path. Shield uses
the exact same unchanged ShieldWorldRenderer and geometry as race/remote karts,
and hides the plain replicated shell using LocalTransparencyModifier. Practice
session and block serials now drive its lifecycle and block flash independently
of race session attributes. Local exhaust remains one pair.

Practice activation and successful Shield blocking also invoke the existing
RaceItemVisuals.shieldPulse, including its native ripple outline, original size,
0.30-second expansion/fade and bounded 32-pulse cap. Recovery, departure and
teardown remove the pulse. Shield duration five seconds / one attack, inventory,
item effects, audio, driving and all race rendering values remain unchanged.
The observer's previously CRLF-encoded Git blob is normalized to LF, matching the
other edited Luau source and passing standard diff whitespace checks.

Eight focused suites PASS: production local/remote practice observer parity 14
plus shared harness lifecycle 82; practice orchestrator 454; race Shield restore
367; four-racer/20-cycle observer 1,402; speed/exhaust/Shield regression 14,851;
native item visuals 101; combat audio 31; driving containment 71. Changed sources
compile; Rojo build and diff checks PASS.

Tests verify glow/orbit parity, hidden duplicate shell, animated local orbits,
practice block flash, one local exhaust pair, expiry, exact native pulse expansion
and recovery cleanup. Runtime visual/mobile acceptance remains unverified. No
Studio source replacement or Roblox Publish. Logs/build are in the untracked
`artifacts/lobby-shield-parity` folder.
