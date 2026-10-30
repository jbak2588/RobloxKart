# Continuous Rookie Park asphalt - 2026-10-30

Compared the source Hub_n_lobby_original.rbxlx and both owner Park screenshots.
The source uses MaterialService Asphalt override Racing_Asphalt_A: ColorMap
15217440826, StudsPerTile24, Organic pattern. KDM retains that albedo/scale but
Park uses the previously accepted matte material and dark165/170/180 tint.

Patch seams came from independently oriented WedgePart faces (including short
straight pieces retained by the old exact-collinearity float test), rather than
a different road image. Replace the Park main-road visual ribbon with a single
preauthored MeshPart and a uniform material projection. The source OBJ and
offline exporter are checked in. Mesh94042544951144 belongs to the experience
creator. The first flat-only experimental asset110412772852499 is unused.

Native Studio OBJ import rotates geometry180 degrees aboutY; compensate once
at runtime. Intrinsic size1373 x.01 x1086 is preserved, with7632 total faces
and1908 top faces. Top remains originY+.02, center(-50,.015,-643.5). All main
road edges follow the established sampled ribbon within floating precision.
No physical support, course, collision, checkpoints, paint, driving, ownership,
rewards or account writes changed. Other tracks and the separate pit remain
unchanged under the one-track-at-a-time scenery rule. Missing prefab falls back
to the existing visual ribbon. No separate Texture/Decal layer. No runtime
EditableMesh, API/security-setting changes, or live geometry generation.

Validation: ordinary Studio client startup renders the imported mesh at straight
and EntryCurve cameras, with continuous appearance and intact raised paint.
Native asset geometry was independently read to establish import orientation.
Runtime confirms non-colliding/non-queryable/non-touchable, precise render,
positive MeshSize and top.02. Existing PlayerPreferences API warning remains.
Road regression25317 checks PASS, including static topology, planar UVs, top
winding, height, tint, ordinary cloning and existing Green/Base/fallback paths.
Full suite253 processes:233 PASS / same20 historical FAIL /0 new FAIL;
NOT FULL_SUITE_PASS. Manifest audit133 entries PASS; Rojo build and diff check
PASS. Final bounded-prefab-wait edit reran road validation successfully.

Native full Place backup (candidate sources included):
C:/Users/OWNER/AppData/Local/Temp/KDM-official-park-continuous-asphalt-20261030.rbxl
SHA256fa53cbc13d99e7469c1ffcd2b53a7da2d2f6a7338dcdb17d4820877c3140ac68.
232/232 project sources match, zero mismatches, all3 release flags true. Preserve
original binary Terrain content; do not reserialize this backup for publication.

Real mobile/published visual acceptance remains separate from Studio evidence.
No server restart. See park_continuous_asphalt_results_20261030.json.

## Publication receipt

Official Universe10768420544 / Place127925465904803 published as PV1274,
code commitc93a0352bf13fd82353a142199726a975e11ad72. Native Studio success
and Creator Dashboard published-only history independently confirm1274.
Post-Publish runtime-source equality and MeshId94042544951144 verified.
No restart. Existing jobs retain old visuals until replaced naturally.
