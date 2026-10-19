# Published two-player performance capture — 2026-10-19

Diagnostics are enabled only for mozzy_hni (11700555357) and Synister110
(11734277722), in the KDM production experience/place, plus Studio. Ordinary
players receive no diagnostic GUI or snapshots. Progression/record access policies
are separate and unchanged. No diagnostic DataStore writes are added.

## Real-device procedure

1. Join a fresh published server with both accounts. Record device model, OS,
   graphics level, Wi-Fi/cellular, charging, power-saving and whether recording.
2. In race staging leave `PERF LIGHT` and the normal gauge mode selected. Run the
   same track together, use Drift and combat items, and finish both laps.
3. Before leaving or rematching, capture the `KDM PERF` summary on each device.
   Scroll the small summary panel to capture all rows, including version and Round.
   The same summary is available on DNF. A full application crash cannot show it.
4. Report the approximate time of the freeze and what both drivers saw. Send both
   summaries and device details together. A second run with `PERF OFF` can measure
   whether diagnostics themselves materially affect the symptom, but has no summary.

Published clients/servers are independent of Studio; their Output is not forwarded
to the open Studio window. In the live Roblox app, `/console` in chat opens the
Developer Console (F9 on desktop). The client log contains `[KDMPerfSummary]` and
anomaly reports. Server logs require the appropriate developer permissions; the
second test account's client summary includes its authorized server snapshots.
Capture evidence before leaving: diagnostic rings are bounded, temporary memory,
not a permanent log archive. These captures are not automatically sent to Codex.

## Reading the measurements

- `frameInterval`: real client frame spacing, including engine/render scheduling.
  A 60fps frame is about 16.7ms; repeated >33ms / >50ms frames and gaps matter.
- `serverFrame`: sampled server simulation frame spacing, not client FPS.
- `serverKartStep` / `serverRaceLoop`: instrumented script execution time; these
  are not total server CPU/GPU time and sampled snapshots can miss short spikes.
- `serverInputAge`: age of the latest input at the server, including the intentional
  input send interval. It is not a pure network ping measurement.
- `snapshotAge`: server snapshot age on receipt; includes network and scheduling,
  not a round-trip latency measurement.
- `p50/p95/max`: typical / slow-tail / worst observed samples. Per-frame metrics
  and 0.5-second server snapshots have different sampling rates.

High client frame spacing with a healthy server points toward client/render work;
high server frame spacing on both devices points toward shared server pressure.
Input/snapshot ages help investigate transport delays. These are diagnostic leads,
not proof of one cause or a guarantee of 60fps. Rendering/GPU bottlenecks may need
Roblox MicroProfiler captures after this first comparison.

## Validation and scope

Spatial road lookup retains precise current-position checks (including sloped-road
fallback). Route projection visits only continuity-eligible segments, retaining
the original tie order. Lap completion explicitly flushes the final progress sample.
Remote exhaust updates are reduced beyond 90 studs and culled beyond 160; local
kart updates remain immediate. Tire rays include only road surfaces. Runtime kart
discovery uses descendant/attribute events instead of recurring tree scans.
Driving constants, combat tuning, six-item flow and four-racer capacity are unchanged.

Old `r8_perf_p1_validation` compares whole files against an earlier historical
commit and fails its exact-source assertion on already changed production files.
`r8_perf_p2c_validation` also expects a historical false-capacity reproduction.
Neither is evidence that current gameplay or physical-device performance passes.
Current focused gameplay/equivalence checks and Studio smoke checks are recorded
with this task; published two-human iPhone/tablet acceptance remains pending.

References: https://create.roblox.com/docs/studio/developer-console and
https://create.roblox.com/docs/performance-optimization/identify
