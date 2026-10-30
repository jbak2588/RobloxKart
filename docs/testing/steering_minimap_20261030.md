# Steering glyph centering / directional minimaps — 2026-10-30

Owner requests existing font triangles enlarged20 percent, optically centered,
and recommended cyan/bright-outline directional self markers on fixed minimaps.
Explicit commit/push/official Publish approval, Universe10768420544 /
Place127925465904803, no restart. Baseline44c7065dcbd47f13ec11a51b0639d1333a58d181,
fetched identical remote/local clean prototype/kart-physics.

Steering retains ◀/▶ GothamBlack and increases TextSize40 ->48. Only the
noninteractive labels move. Rendered TextBounds advance distinguishes wide
triangle fallback from half-width fallback; use1/6 vs1/12 point-size vertical
compensation and1px mirrored horizontal correction for wide glyphs. Observe
TextBounds changes after fonts load. Fixed offsets alone overcorrected the
native half-width fallback, so the final implementation handles both. Existing
138px controlled native clone views measured old ink center+2.5px and final
center-.5px vertically (rounded screenshot pixels); final horizontal-.5px.
Nominal font size increases exactly20 percent, with raster quantization. See
C:/Users/OWNER/AppData/Local/Temp/kdm-glyph-centering-final.png. These captures
are controlled presentation clones, distinct from mobile real-device acceptance.
Button/outline bounds, touch ownership, BRAKE/GAS/Drift, input and physics stay fixed.

MinimapDriverMarker shares one14px noninteractive triangle between Park/Overtake
and official TrackMapRenderer. Cyan65/225/245 fill, pale240/250/255 border;20 UI
rows built once, no per-frame instances, uploaded assets, font dependency or
network calls. Update rotation from chassis.CFrame.LookVector in the existing
position update. World+Z maps up; +X maps right; honor any renderer map rotation.
Keep heading while stopped/reversing since velocity is never the direction input.
Zero/missing/nonfinite planar direction preserves previous orientation. Other
racers remain existing16px orange hollow rings; start marker, track geometry,
map placement, insets, viewport masks and minimap preview policy unchanged.

Validation:543 direction/cardinal/full-turn/projected-map/fixed-budget checks;
35 actual renderer/rival/cleanup tests; mobile production controller500 and
layout3528 checks. Rendered widths24/34 at TextSize48 exercise both baseline
branches. Existing HUD mock chassis now has a real CFrame; Garage map preview
mock acknowledges the new helper without adding player markers. No assertions
removed. Release integrity874 checks and five exact source hashes with mutation/
deletion rejection; historical pins/N1/N2 artifacts remain unchanged.
Native ordinary Overtake startup shows the Park14px arrow,20 rows,90 degrees
for chassis forward(1,0,0). Real official renderer controlled native cards show
0,90,-180,-90 for +Z,+X,-Z,-X. Scene UI only, not reserved-server admission or
real-device driving acceptance. Test-only overlays/state discarded on Stop.
No server/account/economy/Robux-product changes.

Final full regression:260 processes,240 PASS, unchanged20 historical failures,
zero new failures. No FULL_SUITE_PASS claim. Independent source audit passed.
Native full Place backup: KDM-official-steering-minimap-20261030.rbxl in owner Temp.
SHA256 eceb71d6bae7cb05768518820b7baee1932ab5978964c957edff4c9a0ac6ebca.
All238 source files match working sources after LF normalization; all three
release flags true. Binary backup inspected read-only, never reserialized.
