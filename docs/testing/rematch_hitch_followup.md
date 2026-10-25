# Repeated Rematch hitch follow-up — 2026-10-21

## Status

OPEN: user-reported published recurrence, not a verified repair.

The user reports smooth initial human-plus-bot play, followed after approximately
5–15 Rematches by a bot start that appears to advance and snap backward. Periodic
roughly 3–4-second hitches then persist. Returning to the Lobby and starting
another RACE NOW restores smooth play. The user subsequently confirmed the
affected published version is **PV932**. A synchronized client/server capture
of its failing interval is still unavailable.

PV932 was published from `94808583f10576cc4caeabf5de4ab1c10160c175`, which includes
the PV931 human-seating authority repair and the extended winner celebration.
Comparing that commit with the follow-up HEAD shows no differences under `src/`.
The local native experiment therefore used the same production source revision;
its isolated environment and temporary harness remain important limitations.
Do not attribute this report simply to a version predating the seating repair.

The investigation starts at clean `prototype/kart-physics` HEAD
`578ae85ced49bf602c8aed04918024d0ed158449`, matching fetched origin. No production
source or gameplay tuning is changed in this follow-up. The previously accepted
PV931 authority repair remains intact. Its 40-second native captures and four
mocked reseatings were short-run evidence, not 15 consecutive race finishes.

## Source review

- `RaceController` reuses each racer/context on Rematch, clears round progress,
  resets the grid pose/velocities and uses the existing shared countdown.
  `RaceRoomCoordinator.nextRound` also refreshes staged spawn slots; it does not
  construct another physics loop for every Rematch.
- Human manual server ownership is asserted at creation and deferred seating.
  The bot also finalizes its connected assembly after seating. An unchanged
  occupant does not generate another seating callback on every Rematch. These
  facts identify what to observe; they do not prove ownership is lost on Rematch.
- The chase camera binds one named render callback, resets its finish mode and
  target on return from presentation, and disconnects prior seating listeners.
- `RaceResultsCache` clears its entries when the round changes. World VFX clears
  renderers at controls/session changes; finish timers use serial cancellation.
  The tire trails have a finite 2.5-second lifetime and 180-stud maximum length.
  No obvious unbounded per-Rematch renderer or result cache was found. Source
  review and stable object counts cannot exclude every connection or memory leak.
- Internal performance diagnostics remain OFF by default. They were not enabled
  in production during this investigation.

The pattern is consistent with some state or load that survives in the current
race session and is removed by a Lobby/new-server transition. A first-download
asset explanation is a weaker fit for an initially smooth run that deteriorates
on the same already-used track; this is an inference, not an exclusion of all
asset, memory, thermal or network effects. The bot's apparent reverse movement
alone cannot distinguish bot motion, local camera motion and replication delay.

## Isolated native experiment

The local `C:/dev/KDM_Rematch_Investigation.rbxl` is built from the baseline.
Only its unsaved Studio test copy is altered: enable the existing Studio bot
harness on Track01 Figure 8, start race client controllers and add temporary
steering/measurement scripts. Assert GameId=0 and PlaceId=0 before installing
probes. Production EconomyService uses its existing in-memory Studio adapter;
no operating profile writes, duplicate reward requests or resets are performed.

The human-context kart follows the existing bot steering through a temporary
server control wrapper. This bypasses real mobile input transport. The Studio
bot harness does not exercise production reserved-room MemoryStore/admission
traffic, a real iPhone renderer or Internet replication conditions.

Rounds 1–20 run eight seconds before the probe invokes each racer's existing
timeout handler. The client then uses the existing Rematch remote, followed by
the normal shared countdown and grid reset. This is an accelerated DNF/reset
stress test, **not twenty normal three-lap completions**. Rounds 21–23 retain
the normal three-lap course and finish adjudication. A later temporary bot delay
creates human-winner coverage of the extended celebration and its cleanup.

The first client harness attempted Rematch as soon as session completion was
published, before the human reached FINISHED. The production server correctly
rejected that early request. A separate test driver waits for FINISHED/DNF before
requesting the next full round; no production gate was changed.

Measurements, the exact temporary probe sources, and final results are retained
in `artifacts/rematch-hitch/native-results.json`. The local Play run was stopped
after round 23 reached FINISHED. The main operating Place was not modified.

| Measurement | Result |
| --- | --- |
| Completed rounds | 20 accelerated DNF/reset rounds, then 3 normal three-lap rounds |
| Server samples / client rendered frames | 41,159 / 41,155 |
| Automatic-ownership samples, human or bot | 0 |
| Client-owned samples, human or bot | 0 |
| Detected stationary-moving samples, human / bot | 0 / 0 |
| Server heartbeat maximum | 26.952 ms |
| Client frame maximum / frames over 33.33 ms | 41.053 ms / 1 |
| Round-start server instances, accelerated rounds 1–20 | 51,065 every round |
| Human owner connections / bot controls, round 22 | 3 / 1 |
| Observed occupant/root changes after late round 21 | 0 |
| Late-round client instances, rounds 22 / 23 | 55,128 / 55,128 |

The extra late-installed observer scripts change the server round-start instance
count to 51,069 and 51,071 in rounds 22/23; do not misreport those deliberate probe
insertions as a game leak. The frame/sample totals include staging and finish
waiting. A stationary-moving sample means the prior speed exceeds 30 studs/s
but displacement is below .01 studs during RACING. A separate late observer
found no negative forward-displacement steps below -.05 studs, human or bot,
in rounds 21–23, excluding the first racing second after each grid reset.

The client did have one isolated 41-ms rendered frame. This is not a zero-hitch
claim; repeated three-to-four-second stalls and ownership pulses were not
reproduced in this capture. Round 22 also exercised the human winner waiting
for the delayed bot: two emitters were present during PRESENT waiting and no
finish emitters survived into round 23 RACING.

This evidence does not establish published mobile long-session acceptance or
exclude production networking/persistence work. In particular, twenty short
DNF rounds followed by three normal finishes do not replace the reported
five-to-fifteen consecutive full races on the affected device. The source audit
does not justify a speculative physics or camera patch.

## Validation

Targeted reruns: network ownership lifecycle (17 checks), four-player controller
(55), winner/runner-up lifecycle (65), finish particles (266), driver celebration
(195), camera motion (6 cases / 3,000 samples), and bot route continuity (124,758)
PASS. `bot_internal_control_validation` still FAILS its line-5 historical whole-
source freeze assertion, exactly as recorded before this investigation in
`artifacts/finish-runner-up/regression/bot_internal_control_validation.log`.
It is not reclassified as PASS. No test assertion was modified.

This is eight targeted suites: seven PASS / one unchanged existing FAIL, not a
rerun of the entire regression suite. Normal baseline Rojo binary/XML builds
and `git diff --check` pass. Probe scripts and captures are excluded from Git.

## Required evidence for the unresolved device case

Capture the failing interval with PlaceVersion, round number and elapsed session
time. Correlate client frame time and kart displacement against server step time,
input age, network owner **and automatic-ownership mode**, assembly/seat changes,
instance counts and memory. A server-owned sample alone does not establish
manual ownership: automatic mode can still report a nil owner between handoffs.
Observe the first anomalous bot start and the subsequent periodic hitches in the
same capture, then compare a fresh RACE NOW under the same device/network.

Do not replace the accepted server simulation with client ownership or perform
per-frame ownership writes as a speculative workaround. No Roblox Publish is
performed in this follow-up.

## Owner first isolation request — 2026-10-25

After successful desert asset/reward acceptance, owner reports first two Race Now
human+bot rounds smooth, third Rematch hitching roughly every4 seconds with
broken-looking trails and bot forward/backward snaps. Park remains smooth after
4–5 Replays. This is a user observation, not proof that the minimap is causal.

First reversible experiment disables only rival minimap collection, position
smoothing and marker updates via RaceConfig.MINIMAP_RIVALS_ENABLED=false. Local
racer position, course, checkpoint cue and minimap stay. Server map replication,
ranking, bot controls, physics, seating and manual server ownership remain intact.
No race-server recreation is bundled into this experiment. If the same failure
persists, owner authorizes investigating a fresh-entry-style Rematch lifecycle;
do not report that second intervention as implemented by this change.

Owner clarification: fresh-entry means reproducing Lobby exit/re-entry cleanup, not restarting the entire Roblox server. A possible later fresh-room handoff must preserve room/roster/reward continuation. This first minimap isolation does not implement that handoff.

Validation:222-source compile,Rojo build,diff check;17 deferred ownership guards and existing1191 combat/NPC checks plus273 live-gated NPC checks and13 rear-preview checks PASS;150 Rematch receipt/session checks PASS. Studio render loop with active opponent map state:local marker1,rival markers0,rival collector calls0. Temporary QA bootstrap restored. No real third-Rematch hitch capture or mobile acceptance; recurrence remains OPEN.
