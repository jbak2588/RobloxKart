# Dual Figure-8 public release — 2026-10-25

Owner supplied mobile + PC acceptance of the staging desert and authorized two
independent themes plus production Publish after Studio integration checks.

- Track01: Figure-8 Green Island; original geometry, theme, grid and records retained.
- Track01Desert: Figure-8 Desert Canyon; same geometry/grid, 3 laps, 1–4 racers,
  existing bot support; independent room/arrival/rematch/record identity.
- Race Now QuickStart searches/creates desert rooms only. Other selection and
  browsing paths retain existing behavior; both themes appear in the catalog.
- Desert eligibility now includes exact production Universe10768420544 /
  Place127925465904803. Theme selection additionally requires Track01Desert.
- Common sponsor arch and two lighting towers support both track IDs.
- Native grass length0.1 matches accepted staging (Studio setting).

## Verification

PASS: 282072 desert/catalog/real launch+arrival/record isolation/geometry checks;
71 production-service cross-Hub matchmaking checks including green-room rejection
by Race Now and two humans joining one desert room; 40 room-service checks;
25 room-coordinator checks;17 persistent-room race checks;65 official records
checks;10 profile-record integration checks;43139 accepted Figure-8 geometry
checks;25 world-VFX/skid checks;222 production sources compile;default Rojo
release XML;git diff --check.

Production-bound Studio: normal Hub startup has no desert environment. RACE
Track01Desert startup through ordinary client init builds SOURCE_DESERT,
911 terrain tiles,106 natural instances,19 ad panels,12 one-sided chevrons,
3 cliffs,1 dune,0 shoulder grass patches,1 common arch,2 towers. Zero script
errors in fresh RACE startup. Switching to Green Island and restarting the
presentation controller restores16 natural trees and removes desert materials
and light overrides. Original server bootstrap restored after runtime probes.
No temporary QA scripts or scene changes are included in the release.

Legacy tests are not all green: race_launch_routing_validation still fails its
old arrival SelectedDriverId/appearance assertion; track01_figure8_environment
and track_horizon_environment have obsolete fixed cue/part-count expectations
(the horizon count mismatch was recorded before this release). They are not
reported as passing. The focused launch test uses the actual new catalog,
RaceLaunchPayload and RaceArrivalPlan and verifies both themes as RACE/4 seats.

Studio lifecycle probes do not establish a new full driven lap, real cross-server
teleport or four-human mobile acceptance of this release. Owner's preceding
mobile/PC desert acceptance is retained separately from these integration checks.
