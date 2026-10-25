# All-track start/finish paint — 2026-10-25

Owner requests four checker rows and Park-style two-column/four-row brackets
for every KDM track, explicitly including Park. Baseline e3f7b3a1370264af85ba70c3f7345c8fa867caef
was clean and matched fetched origin/prototype/kart-physics.

Inspected C:/dev/rbxlx_data/Hub_n_lobby_original.rbxlx read-only. Its
SA_Racing_CheckPoint_a SurfaceAppearance uses ColorMap rbxassetid://15424111389
(TexturePack 15424187604); Floor_Checkered also shares that image. Studio
rendering confirms a four-by-four white/transparent checker tile. Reuse this
image directly as a native top-face Texture, tiled every 8x8 studs. A band eight
studs along travel gives four rows of two-stud squares, two studs inside each
road edge. Transparent gaps show the existing asphalt; no new asset upload,
template scripts, mesh imports or privileged runtime image writes.

TrackBuilder applies to Track01, Track01Desert, Track01Race, Track02 and Track03.
Each receives eight Park-style three-stroke brackets: 10-stud front width,
0.35-stud stroke width and four-stud arms. Centers sit +/-14 studs from the
approach centerline, at 30/60/90/120 studs before the finish, following actual
polyline distance/tangent so curved approaches remain on asphalt. Existing
catalog spawn CFrames and four-racer capacity are unchanged. Track cache checks
StartFinishPaintVersion=1 so pre-change cached paint is rebuilt once.

Rookie Park retains its existing eight main-road slot/bracket positions and
separate decorative Pit brackets. Replace its sixteen single-row checker Parts
with one source-image band. StartSlots, allocation, TrialFinishX and all seven
trial gates remain unchanged. All added paint is anchored, noncolliding,
non-touching, non-querying and shadow-free. Official paint Part count increases
by five (20 old checker Parts -> one band +24 bracket strokes); Park decreases
by fifteen. Each band adds one native Texture, no update loop or GUI.

CheckpointGuidanceController retains finish flags and marker but omits its old
32-Part/two-row overlay when the server track has standardized paint. Ordinary
checkpoint overlays and legacy-track fallback remain intact.

Validation:

- start_finish_paint_validation: 730 PASS across all five catalog tracks.
  Compares every non-paint generated property/attribute with the task baseline;
  checks checker asset/scale/direction, all bracket corners inside asphalt,
  unchanged capacity, visual safety, cache reuse and old-cache invalidation.
- hub_park_rookie_loop_validation: 3671426 PASS, including unchanged main-road
  starts/brackets, four-row source band and contact/query safety.
- practice_figure8_geometry_validation: 42971 PASS; immutable world comparison
  excludes only the newly authorized paint/metadata in addition to its prior
  exclusions. Road, gates, kerbs and minimap remain frozen.
- checkpoint_marker_alignment_validation: 1721 PASS.
- All 222 production Luau files compile. Default Rojo XML build and diff check
  PASS.
- Studio ordinary Hub startup produces Park's four-row band and eight unchanged
  brackets. Native Play screenshots inspected for Park and the official
  Track01Desert builder. All five official production builder outputs inspected
  in Play: four checker rows/eight brackets/original image. Temporary official
  preview was isolated from the Hub for its screenshot; no theme/route change.
- Controlled client guidance probes: Park finish has both original banners and
  zero duplicate checker Parts; Park checkpoint 1 retains 32 checker Parts.
  Official Desert finish likewise retains the banner and zero duplicate paint.
  Probe attributes were restored, controllers destroyed and Play stopped.
- track_environment_validation's historical Legacy gameplay output assertion
  fails. Reproduced the same failure with the **pre-task** e3f7b3a TrackBuilder;
  this predates the requested paint change. Its immutable old marking fixture
  differs from the current baseline (including CenterDash1). The suite is not
  reported PASS; the new exact task-baseline comparison covers all five tracks.
- Ordinary Studio startup reports its pre-existing disabled PlayerPrefs API
  access. One QA query ran before client replication completed; retried with
  WaitForChild, then completed the visual/guidance probes successfully.

Final source synced to Edit. No temporary QA instances or bootstrap remain.
No Roblox Publish. Published texture permission and real-device visual acceptance
remain separate from Studio rendering and automated geometry checks.

## Owner-authorized production Publish

Owner explicitly requested Publish after the above checkpoint. Published via
Studio's normal File > Publish action to Universe 10768420544 /
Place 127925465904803. Studio Output confirmed success at 2026-10-25 23:09:07
client-local time and linked publication **v1157**. The Edit session's old
game.PlaceVersion value remained 1113; the new version is taken from the actual
publication success output, not that cached property.

Before Publish, checked all 222 production script sources against commit
4c53388ec8a9156774106be9a4a20d138ff5d1af using normalized source length/checksum.
Four manually synced modules differed only by one terminal newline; normalized
those and verified their checksums. Set KDMBuildCommit to that code commit.
Ran tools/repair_desert_mesh_prefabs.luau in Edit: all three actual prefab mesh
IDs verified. No QA scene/bootstrap present. This publication also includes
e3f7b3a's Track01Desert-only inward background relief. Real-device acceptance
of the newly published presentation is not implied by successful publication.
