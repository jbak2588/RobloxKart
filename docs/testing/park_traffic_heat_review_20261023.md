# Park traffic, GO launches and mobile heat review - 2026-10-23

## Thermal audit

Actual Studio client ParkLandscaping: 440 trees, 270 understory models, 1,445 BaseParts, 1,360 MeshParts and 1,360 SurfaceAppearances; 16 unique mesh IDs. Mesh fidelity: 1,336 Automatic / 24 Precise. Zero landscaping shadows, particle emitters or partially transparent BaseParts. Leaf texture alpha and overlapping canopies still carry GPU overdraw/geometry cost; BasePart.Transparency=0 does not mean leaf textures are opaque. No per-frame landscaping builder loop was found.

Fixed-camera desktop Studio ON/OFF/ON capture (1 second settling, 3 seconds sampling each): mean 16.664 / 16.662 / 16.659 ms; p95 17.875 / 17.978 / 18.327 ms. This 60-FPS-limited desktop result neither identifies nor excludes a mobile GPU/power bottleneck. Studio memory (about 2 GB including Studio/testing overhead) is not a phone memory measurement. No Android/iOS device temperatures, GPU timings, power draw or sustained-session thermal throttling were measured. Trees remain a plausible cost contributor, not a proven sole cause. Forest density and asset fidelity were preserved.

To bound the cost of expanding traffic, Park bots now use existing official Race drift smoke (3.0-4.2 second lifetime vs Lobby 6.5-8.0, half-rate formula). Far Park pose updates run at most 10 Hz beyond 300 studs. Existing smoke LOD remains 160 studs; launch flames remain visible to nearby observers out to 300 studs. Legacy apron behavior is retained. These are workload reductions, not a claim that phone heating is fixed.

## Traffic

Seven distinct KDM V2 variants: Cyan, Red, Yellow, White, Metal Blue, Metal Pink, Black. Shared audience clock schedules 0/30/60/90/120/150/180 seconds; late users do not duplicate the fleet. Empty Hub clears traffic. Start is on the centerline just ahead of the personal grid; bots ramp from zero using normal Mini Boost, then base speed 70 before and during human TEST DRIVE. Human Park 80, official 70, item tuning, trial rewards and track geometry are unchanged.

Production proxy KartBoosting drives every client's flame, with hit suppression. Controlled Studio clock advancement verified seven rendered models and a fresh Black launch with DemoBoosting=true and six enabled native flame emitters. This verifies client rendering state; full 180-second cadence is covered deterministically rather than claimed as real-time waiting.

## All official GO launches

RaceController's shared startRace adapter calls the production KartContext Mini Boost path for Track01, Track01Race, Track02 and Track03. Same 100 cap / 2 seconds / 65 acceleration; automatic throttle during launch, Brake cancellation. No Nitro consumption, successful Drift outcome or bonus credit. No ownership lifecycle change. Existing natural boost decay and safety handling remain.

## Validation

PASS: RookieLoop full-route geometry/clock 81,357 + production seven-bot/pace/stagger/item/teardown integration 137; Park moving Missile/Thunder acquisition/hit/refill 23; native boost template/LOD/lifecycle 57; actual official GO adapter + actual KartContext across four track IDs 473. Studio resource/frame-time and seven-bot flame probes above are controlled local evidence, not published/mobile acceptance. Legacy lobby_demo_validation fails from an existing fixture that omits LobbyPracticePolicy (BotFleet nil); it is not claimed as passing. All 209 production Luau sources compile; scoped Rojo XML/binary builds and diff checks PASS. Existing unrelated exhaust, practice Nitro edge handling and service/test edits remain outside the commit; the scoped snapshot used index source bytes. No Publish requested in this task.
