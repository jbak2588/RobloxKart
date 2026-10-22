# RookieLoop shared demo bot

The existing public-HUB demonstration is now connected to RookieLoop. It is not
a RaceSession racer or human kart. The unchanged LobbyDemoService owns one shared
timeline while any user is connected, retaining last-departure/zone cleanup and
private/RACE exclusions. Each client renders one noncolliding demonstration.

RookieLoopDemoRoute derives its closed arc-length route from the approved main
road. It starts opposite the Lobby, stays outside Pit slots, drifts through
corners and uses one straight-only boost window beyond the Pit exit. Server
practice targeting and client rendering select the same route. Original apron
patterns are unchanged. Audience-only pace is 36; with active human practice,
normal pace is the current HUB-only 80, with existing Mini Boost/combat effects.
No deleted DEMO identification label or discovery sign was restored.

Existing smoke/flames/spatial audio/LOD, 0.10-second proxy sync and client
interpolation are reused. No new Heartbeat, remotes, persistent data or human
physics/network ownership changes. Official RACE bots are unchanged.

Validation: 157958 path/footprint/clock checks and 94 real practice-orchestrator
checks PASS, including item hit types, Shield and teardown. Related regression
run: 33 suites PASS / 4 historical FAIL / 0 new FAIL. Historical failures remain
r8_a2l1_canary_guidance_validation, lobby_practice_combat_validation,
lobby_post_drive_return_validation and v2_gauge_v1_audio_validation.
206 production Luau files compile; Rojo XML/binary builds and diff check PASS.
Studio visual/full-lap, published late-join/multiplayer and mobile acceptance:
NOT VERIFIED. Studio file picker did not load the isolated test place.
Commit/push authorized; no Roblox Publish in this task.
