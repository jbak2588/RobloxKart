# Figure-8 Desert Canyon near-course background relief — 2026-10-25

Owner requests bringing all existing background mountains closer, including the
side below the supplied overview. Baseline fetched and clean:
778e2fe0baca3d2db449c396f3b2f2612d2aa0b2, matching origin/prototype/kart-physics.

The original sampled-source relief is mapped inward on both horizontal axes at
0.68 scale about (0,84); original sample heights/materials and source assets are
retained. This compacts horizontal mountain footprints rather than translating
individual mesh models: the background is reconstructed native Terrain.
Replace the old rectangular exclusion / 160-stud outer fade with an actual-road
distance mask: no raised background inside 132 studs of the centerline, then a
60-stud smooth transition. Both loop interiors remain excluded. The existing
three near-course mesas and island dune keep their original settings.

132 studs leaves 102 studs beyond the 30-stud road half-width. It also preserves
the former +/-90 X/Z recovery sample envelope, with margin for voxel smoothing.
Road/kerb/checkpoint/recovery geometry, physics, ownership, race routing and
economy are unchanged. No new scenery assets, per-frame work or terrain data
modules. Destination tiles inverse-sample the original source; distant tiles
avoid per-column road searches. Destruction still cancels pending construction
and clears the recorded tile regions.

Validation:

- figure8_desert_validation: 337071 checks PASS, including all raised destination
  sample centers, all four sides, unchanged source height mapping, interior dune,
  and every road sample's +/-90 recovery envelope. Nearest positive relief sample
  is 132.00499 studs from centerline; retained west/east/north/south peak heights
  are 256 / 164.25 / 191.75 / 168.5 (source/blend values before voxel height cap).
- practice_figure8_geometry_validation: 42971 PASS; accepted centerline length
  remains 2478.535506248474.
- All 222 production Luau sources compile; Rojo default XML build and diff check
  PASS.
- Studio ordinary Client module build on a temporary production TrackBuilder
  desert track: TerrainReady, 467 tiles, 3 cliffs, 1 dune, 12 chevrons, 19 ad
  rails, 106 natural placements; construction 3.13 seconds on this desktop.
  Edit preview separately completed in 3.54 seconds. Overview and road-height
  screenshots inspected. Temporary preview folders and scenery were removed;
  the updated environment module remains synced to Studio. These are controlled
  scenery checks, not manual driving, published or real-device acceptance.
- Additional practice_figure8_race_validation stops in the unchanged shared
  race_mode_validation fixture's `#catalog.Order==4` assertion (Practice
  first/default); current dual-theme catalog has five tracks. Neither that
  fixture nor the catalog is changed by this task. This suite is not PASS.
- Studio's ordinary Hub startup also reported its existing disabled API access
  for KDM_PlayerPrefs_v1. No desert generation error was observed.

Mobile driving/FPS/thermal acceptance remains unverified. No Roblox Publish.
