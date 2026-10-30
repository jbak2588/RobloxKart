# Park remote-human motion audit — 2026-10-30

Owner reports other humans' TIME ATTACK / OVERTAKE karts pausing, skipping an
intermediate position and reappearing ahead on mobile. Owner confirms their own
kart and surrounding scene remain smooth. Distance dependence is not yet supplied.
Tree thinning is authorized if useful. This task investigates; no speculative
physics, ownership, scenery or production deployment change was made.

Fetched baseline: `752bba670eaecf1aba3f2838879ee37866b79578`, clean and equal to
`origin/prototype/kart-physics`. Published-reference release is PV1285. Native
measurements below are **Studio Play, PlaceVersion0**, not a live PV1285 mobile
or two-human internet capture. Exact Universe10768420544 / Place127925465904803.
Raw measurements: [results](park_remote_motion_audit_results_20261030.json).

## Assessment

**The user's specific failure is not reproduced or conclusively attributed.**
The first diagnostic target is delivery/presentation of remote human physics,
including the other driver's input uplink, rather than an assumed forest GPU
problem. Smooth observer frames do not prove the other driver's device, server
or network is healthy. There is a concrete unnecessary-replication candidate
shared by both modes, and an additional bot-only stale-sample behavior.

| Candidate | Evidence and practical limit |
| --- | --- |
| Remote human physics delivery / other driver's input | Both modes use LobbyTestDriveService's server-driven physical kart. Observer sees ordinary Roblox physics replication; no project-owned remote-human pose buffer or extrapolation/fallback renderer exists. A driver input gap over .5s removes throttle and coasts; focus/menu/text safety also neutralizes input. Neither cause would necessarily lower the observer's FPS. Requires correlated driver/server/observer capture to distinguish. |
| Invisible bot proxy replication | Shared showcase proxies move every server Heartbeat even though clients render separate bots from a timeline. Each active Overtake driver adds seven more anchored invisible moving proxies. Their transforms replicate in addition to approximately10Hz attribute samples. Native one-driver Overtake observed30,268 CFrame-change notifications over40.014s including countdown, plus2,030 distance and2,030 timestamp changes. These are property notifications, **not packet or byte counts**, and do not prove bandwidth saturation. |
| Server CPU overload | In the measured single-human Overtake run, Combat.update p95 .3305ms / max .7396ms, server frame p95 18.052ms / max20.553ms. No shared server pause observed in this limited run. Several active humans, offensive effects, long sessions and production hardware were not measured. |
| Ownership handoff | GO explicitly unanchors then calls SetNetworkOwner(nil). During1,922 Overtake RUNNING samples, zero automatic-ownership or client-owner samples. Existing Shield deferred authority guard remains. No evidence here to justify changing accepted manual server authority. Short local ownership evidence does not exclude a production lifecycle-specific pulse. |
| Forest/render load | Current Park has243 trees,651 landscaping BaseParts,566 MeshParts/SurfaceAppearances and zero landscaping shadows. All are anchored/inert. Fixed-camera desktop ON/OFF/ON shows overlapping frame distributions, described below. Mobile GPU/thermal cost remains unmeasured; tree removal is not established as the remedy for remote-only motion. |
| Distance-based culling | Workspace.StreamingEnabled=false in native startup. No distance-based hide/destroy logic for entire human karts was found. The300-stud/10Hz pose LOD applies to local showcase/Overtake bots, not human karts; distant VFX reductions only affect effects. Native synthetic motion at four distance offsets did not reproduce a distance stall. Engine physics prioritization under live network pressure remains unmeasured. |

## Human versus bot paths

- Human TIME ATTACK and OVERTAKE share `src/server/LobbyTestDriveService.luau`:
  kart creation149–174; seat lifecycle217–235; separate Heartbeat combat/driving
  callbacks329–333; input timeout355/368; final velocity/angular velocity write520.
  No per-frame human PivotTo path exists during ordinary unobstructed driving.
  Recovery345–350 can intentionally relocate a kart. Bounded reverse-rim release
  and legacy escape are separate exceptional paths, not a general interpolation.
- `src/server/RookieParkTrialSession.luau:105` samples lap proof at .1s, but returns
  false between RUNNING samples, allowing normal driving each Heartbeat. This
  does **not** throttle human movement to10Hz. GO109 sets server ownership.
  Finish presentation98 anchors a human kart intentionally; a genuinely finished
  kart remaining stationary must be distinguished from a mid-race delivery stall.
- `src/client/KartVisualMotionController.luau:33` binds the local player's wheel
  and steering motors only. Remote wheel rotation is not animated by this module;
  this may make a remote kart look less alive but cannot explain its chassis
  disappearing/reappearing or world-position jumps.
- `src/client/KartWorldVFXController.luau:93` reduces distant speed effects, not
  human kart visibility. Its LocalTransparencyModifier changes concern the Shield
  shell only. No common whole-human-kart visibility cutoff was found.
- `src/client/ParkOvertakeBotsView.luau:78` predicts a bot from its latest sample
  for at most .3s, then holds it. A delayed sample therefore produces stop/catch-up
  presentation; at70 studs/s the prediction allowance is21 studs. The analogous
  showcase path is `LobbyDemoController.luau:130`. Both explicitly lower distant
  pose updates to10Hz beyond300 studs. **These are bots, not remote humans.**
  Overtake's seven rival visuals belong to the local driver's session; another
  observer does not receive that driver's seven visible rival models.

## Replication workload detail

`src/server/LobbyPracticeCombat.luau:93` updates each Overtake proxy's physical
CFrame (and redundantly assigns its equivalent Position) every update; only its
distance/time/speed attributes are gated by BotSyncSeconds=.10. Shared showcase
proxy writes at406–414 use the same pattern. All are parented in the replicated
Park zone. Their server position is also used by combat targeting/collision;
naively reducing the authoritative update rate can change combat behavior.

At60 server frames/s, seven active shared bots alone imply up to420 moving proxy
CFrame changes/s; one Overtake driver adds another420/s. For N active Overtake
drivers the source-level workload is approximately420*(1+N)/s, with separate
attribute updates, subject to phase/activity and engine coalescing. Replication
fan-out to observers is a plausible cost contributor. The native40s event counter
matches that order of magnitude. No network dump or bytes/sec saturation was
captured, so it is an optimization candidate rather than the established root
cause of the owner's report.

Native Overtake local visuals had seven models,26 BaseParts each. This is a
bounded182-part visual fleet, not seven network-owned physical drivers.

## Native measurements

Tests ran against ordinary startup, then runtime-only probes. Temporary Scripts
used ordinary script identity to wrap the actual Combat.update module. A wrapper
required from the privileged command environment initially observed no calls;
that invalid instrumentation was discarded. No source instrumentation shipped.

1. TIME ATTACK started through the actual button. GO reached RUNNING with
   automatic ownership false and server owner. A normal-identity30s Combat.update
   capture (shared demo fleet, stationary seated human) recorded1,800 calls:
   mean .1292ms, p95 .1671ms, max .4090ms. No actual human lap was completed.
2. Synthetic observer probe: four independent unanchored6x1x8 parts with manual
   server ownership, gravity compensation and70-stud/s circular velocity. Initial
   Z offsets40/200/400/800 from the stationary observer; actual distance varies
   around the circle. No position teleport in the retained capture.25s client
   capture after1s warmup:1,501 frames, zero stationary frames at every probe,
   maximum step2.267 studs. Client frame p95 18.019ms / max24.585ms. Server35s
   p95 18.026ms / max19.689ms; zero stationary probe samples. This is a synthetic
   assembly test over local transport, **not two actual human karts or a phone**.
   An earlier looping straight-line probe introduced teleports and was discarded.
3. Fixed-camera landscaping ON/OFF/ON, .75s settle +3s each:

   | Landscaping | Samples | Mean ms | p95 ms | Max ms |
   | --- | ---: | ---: | ---: | ---: |
   | ON |180|16.669|18.112|24.122|
   | OFF |180|16.660|18.173|20.034|
   | ON |181|16.666|18.213|18.502|

   This60FPS-limited desktop comparison cannot exclude mobile GPU saturation or
   thermal throttling. Static trees are not a continuous source of pose updates.
   No trees were permanently removed based on this inconclusive GPU evidence.
4. Overtake requested through the existing guarded handler in the local Play run.
  40s server window includes8s countdown, approximately32s RUNNING:1,923 combat
   calls, mean .2295ms / p95 .3305ms / max .7396ms.1,922 ownership samples all
   manual server. Separate30s client RUNNING capture:1,801 frames, mean16.666ms /
   p95 18.079ms / max24.145ms. No offensive-item or multi-human saturation test.

## Next corrective work, in evidence order

1. Correlate one real moving driver and mobile observer with a server-side ring:
   synchronized time; both clients' frame intervals; server frame interval,
   accepted input age, driver phase, actual position/velocity, reset serial and
   network owner/automatic status; observer position changes, distance and sample
   age. Keep diagnostics opt-in, bounded and in memory; no per-frame telemetry
   remotes, public account data or DataStore writes. The existing performance
   monitor is disabled by default and primarily official-race oriented, so it
   does not already supply this Park observer evidence. A live reproduction is
   needed before labeling a human-race fix verified.
2. Remove unnecessary replication of invisible moving bot authority proxies by
   separating full-rate server combat pose from compact presentation state.
   Preserve targeting, sweep previous positions, effect timing, session isolation,
   immutable final distance and scoring. Do not blindly throttle server combat
   or remove the existing proxy objects without updating their consumers.
3. If server motion remains continuous but observer delivery stalls, evaluate a
   bounded timestamped **remote-only cosmetic** pose buffer. It must not write
   authoritative chassis transforms, change local driving, transfer ownership,
   manufacture route proof or turn intentional recovery into a long interpolation.
   No such speculative renderer has been added in this investigation.
4. Thin distant decorative trees only after a phone GPU/thermal comparison shows
   a material gain. Tree count by itself does not diagnose a remote packet gap.

Roblox documents that server-owned physics can exhibit client jitter, and that
MicroProfiler network dumps distinguish physics, data/property and asset traffic:
[network ownership](https://create.roblox.com/docs/physics/network-ownership),
[network capture](https://create.roblox.com/docs/performance-optimization/microprofiler/network),
[performance guidance](https://create.roblox.com/docs/performance-optimization/improve).
These explain measurement choices; they do not attribute this particular report.

## Cleanup / scope

Trees and camera restored, Play stopped, then Edit verified with no audit folder
or runtime audit Scripts. Production source, controls, physics, ownership,
economy, geometry and release flags are unchanged. No Publish or server restart.
This documentation/evidence-only task does not rerun or reclassify the existing
240-pass/20-historical-failure regression baseline.
