# Park arrival and T-crossbar PLAY exhibits - 2026-10-24

Arrival/Return Lobby now places the avatar on the pedestrian stem at local (0,-36), facing Park (-Z). Stable RookieParkOrigin is captured before moving HubSpawn, so road/Pit/FlatSupport/course coordinates stay fixed. The one-shot camera frames the avatar and Park, then native camera orbit/walking resumes.

The seven existing catalog V2 exhibits move from the indoor Lobby to T-crossbar positions x=-48,-32,-16,0,16,32,48 / z=-61, within the existing 120x24 pedestrian plaza. They are still static, anchored, noncolliding client visuals. Native nearby PLAY uses the existing preview-ID validation, allocation, seating, countdown and boost path. Persisted Garage selection is unchanged. Non-Park layout/prompts retain legacy behavior.

## Studio evidence

- Initial avatar root relative to Park center: (0,2.998,-36), forward (0,0,-1); camera forward about (0,-0.243,-0.970). Course center remains (0,0,888). All seven PLAY prompts are enabled at the requested crossbar positions.
- Actual W walking from the arrival stem approached the Yellow exhibit at local z=-53.87. Native Studio screenshot showed E / PLAY with KDM V2 Yellow. Actual E input entered COUNTDOWN with LobbyDriveKartId=Kart08 while SelectedKartId remained Kart05. RUNNING followed on the existing main-road start grid.
- Actual Return Lobby cleared driving, restored the new arrival position/direction and rebuilt exactly seven static displays. No full lap was required or claimed for this entry-only change. Published Android/iOS walk-up/tap acceptance remains unverified.

## Validation

PASS: RookieLoop builder/safety/arrival/display-footprint 3,674,479; production arrival camera Park/legacy/race ownership 8; server showroom selection/invalid payload/eligibility 38; Return Lobby 27; personal route/checkpoint/reward regression 58. All 209 production sources compile; scoped Rojo XML/binary and git diff --check checked before commit. Existing unrelated dirty exhaust, practice Nitro-edge, service and associated tests remain excluded.

User explicitly requested commit/push and Roblox Publish. Publication is reported only after Studio confirms success.
