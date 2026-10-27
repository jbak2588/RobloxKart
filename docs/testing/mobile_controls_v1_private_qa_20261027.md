# Mobile Controls v1 — Private QA

Target: Universe **10772198697**, Start Place **106553302629620** (`KDM_New_Hub`).
Owner screenshot confirms Game access Private / Audience reach Private. Access settings were not changed.
Production Universe 10768420544 / Place 127925465904803 is not a publishing target.

## Candidate and isolation

HEAD / origin baseline: `39055dd43d3a4b4a9b14896ccf57e8bcb62dbdab`.
Working tree remains dirty. No commit or push authorized or performed.

`KDMControlsV1Preview` defaults OFF and requires the exact QA Universe/Place pair.
QA Workspace explicitly enables it. GAS owns/relinquishes touch and displays pressed state only;
it does not change speed, throttle transport, server physics, boost or Nitro rewards.
The owner sees `UI PREVIEW / GAS SPEED NOT CONNECTED`.

Changed client modules: MobileControlView, TouchDrivingModel, TouchDrivingController,
RaceItemUiController, DriftChargeView, RaceHudController, V2GaugeController,
CombatFeedbackView, MobileTutorialView, LobbyPracticeView, LobbyTestDriveController.
Tests: added mobile_controls_v1_validation; item_vfx_validation permits the explicitly
authorized HUD edits while retaining gameplay/physics source parity assertions.

## Studio and asset preservation

Original QA version: **70**. Native backup:
`C:/Users/OWNER/Downloads/KDM_QA_106553302629620_v70_before_controls.rbxl` (1,387,080 bytes).
Scoped Rojo project:
`C:/Users/OWNER/AppData/Local/Temp/kdm-private-controls-qa.project.json`, localhost **34873**.
It updates only the eleven client modules, ignores unknown instances and preserves the original
Workspace HubParkV1Enabled / KDMBuildCommit attributes. Original QA shop/economy sources are
preserved from the backup; they predate repository HEAD and are outside this UI task.

Before/after edit-time counts: 4,804 MeshParts, 3,515 SurfaceAppearances, one Terrain,
227 ModuleScripts, two LocalScripts and one Script. Temporary QA probe scripts are removed.
No asset import, terrain regeneration or native-place replacement is used.

An initial scoped Rojo attribute list omitted HubParkV1Enabled and caused the old showroom
to start. Fixed before publishing by restoring the backup attribute and preserving it in
the sync project. Fresh ordinary startup now reports enabled=true / flag=true and
connectedZone=`Workspace.KDMHub.HubParkRookieLoopG2`; the old drive zone is absent.
TEST DRIVE enters Park RUNNING (two laps); RETURN LOBBY restores native TouchGui and
unseats the driver in the new Hub. iPhone 13 emulator visually confirms the Park,
five buttons, 3x2 items, digital speed, Drift gauge and GAS preview notice.

## Verification

New controller/HUD tests: **258 PASS**; pure viewport/flag checks: **3,214 PASS**.
Mobile touch: 1,188 PASS; six-item HUD: 453 PASS; mobile HUD polish: 513 PASS;
Lobby drive: 1,096 PASS; Hub startup: 20 PASS; Hub initialization: 674 PASS;
VFX/gameplay parity: 248 PASS. Rojo build and git diff --check pass.
Viewports include 1600x739, 926x428, 852x393, 812x375, 750x332 and notch-side variants.

Full suite: 245 tests, 170 pass / 75 fail. All 75 failures also reproduce on the unchanged
baseline; this is not a fully green suite. Historical straight_speed_validation fails its
old gameplay balance source-freeze assertion on that baseline too; physics is unchanged.
External logs: `C:/Users/OWNER/AppData/Local/Temp/kdm_controls_full_validation`;
baseline comparison: `C:/Users/OWNER/AppData/Local/Temp/kdm_controls_baseline_results`.

Ordinary Client initializer and Park runtime pass UI startup. Studio PlayerPreferences
GetAsync reports Studio API access disabled; no security setting was changed. Private
record/economy allowlists, live persistence, Reserved teleport, Android/iOS multi-touch,
performance and actual driving acceptance remain **NOT VERIFIED**.

## Publish / rollback

Publish **succeeded**, Studio receipt at 2026-10-27 00:40:37: new changes to
`KDM_New_Hub` published; its generated link explicitly identifies **v76**.
Studio's already-open DataModel still reports its originally loaded version 70;
the new version number is taken from the publish receipt, not that stale property.
Version note: `KDM Mobile Controls v1 UI-only Private QA — GAS preview, no physics change`.
The same note is stored in QA Workspace.KDMQAVersionNotes.
Creator Dashboard version-note entry was not verified; the note is stored in the
place metadata and this report. No claim is made that the Dashboard note was saved.
Test URL: https://www.roblox.com/games/106553302629620/
Rollback: restore the original QA version 70 / native backup, or disable
KDMControlsV1Preview for legacy controls. Never publish this candidate to production.

## Owner layout revision — 2026-10-27

Supersedes the v1 item order and right-hand button positions above:
heavy `<` / `>` steering glyphs; GAS at the old BRAKE center, DRIFT at the old
GAS center, and smaller BRAKE at the old DRIFT center (minimum 48px hit area).
Items always use Smoke / Slick / Thunder / Missile on row one, Shield / Nitro
on row two. Their panel and Nitro progress end 12px inside the right safe edge;
the official minimap moves to their left. Drift gauge follows the moved DRIFT
and clears the smaller BRAKE, including narrow safe-area variants.

Revised automated tests: 291 actual controller/HUD checks and 3,466 pure geometry
checks PASS. Ordinary client Park trial visibly confirms the new arrangement
in the iPhone 13 emulator. No gameplay transport or physical speed change.
Prior v76 remains the first release receipt. The layout revision was published to
the same private QA Start Place as **v79**, confirmed by Studio's successful publish
receipt at 2026-10-27 01:09:19 (Asia/Jakarta). Private access was unchanged; no
production Publish or Git commit/push occurred. Full-suite rerun: 170 PASS / 75
unchanged baseline failures. Rojo builds, syntax compilation and diff checks PASS.

Retired showroom implementation removal is still outstanding; this UI revision
does not claim that its server code has been removed. Park remains the sole QA baseline.

## Held GAS + layout revision 3 — 2026-10-27 (published history)

Owner now explicitly authorizes real GAS acceleration, superseding the earlier
UI Preview-only restriction. Separate server flag `KDMGasPedalEnabled` is default
OFF and enables only in Universe10772198697 / Place106553302629620. No production
or Git commit/push authorization. Prior QA version loaded before this revision:
**80**, backed up natively to
`C:/Users/OWNER/Downloads/KDM_QA_106553302629620_v80_before_gas.rbxl`
(1,391,855 bytes) before applying the new server/client transport modules.

GAS is an optional boolean on the existing authoritative control transport;
legacy targets retain the original three arguments. The server still verifies
the actual seated driver, lifecycle and input timeout. A held, valid, positive
on-road input raises the normal cap to90. Existing acceleration is used; release
removes the modifier immediately and existing deceleration handles overspeed.
Brake, Drift, off-road, combat, Nitro and Mini Boost retain their priority. No
new reward, charge, boost event, client ownership or per-frame ownership writes.
GAS also supplies forward input while held when the previous AutoForward latch
is off; release preserves that prior latch.

Ordinary LocalScript -> live Park remote -> actual Studio server physics capture:
heldSpeed=90.00373840332031 studs/s, heldActive=true, onRoad=true;
one second after release:79.6592025756836, releasedActive=false. The ~.004
overshoot is measured assembly motion; the commanded normal cap is90.
This scripted Studio transport capture is distinct from hardware multi-touch.

User confirmed bottom-edge alignment with the digital speed underline. Steering
has the same dimensions as DRIFT and an exact15px gap. DRIFT moves to the safe
right edge; GAS is left of it, smaller BRAKE directly above GAS. Item rows are
lowered immediately above BRAKE; very short safe areas place them to its left
instead of covering controls. Item/background/count panels are transparent.
Nitro charge text and segment bar are centered above digital speed. The official
minimap is transparent at the upper-right; Park now has a static course minimap
in a separate DeviceSafeInsets layer, with a moving driver marker and transparent
background, independent of Roblox's topbar inset.

Latest code verification: mobile controller/HUD296 + viewport geometry3488 PASS;
actual race GAS integration10 + cap/gate/Park adapter26 PASS; original race item
production fixture checks, network ownership25, slide/boost855, wall service73,
six-item HUD453, mobile touch1188, mobile HUD513, VFX245 PASS. Full suite246:
171 PASS /75 baseline failures, no new failures.231 Luau sources compile. Rojo
build and diff checks PASS. Test fixtures now load the real new GasPedalPolicy.

Scoped Rojo now maps12 client modules, two server modules (PrototypeWorld and
LobbyTestDriveService), plus Shared.GasPedalPolicy. All15 source checksums match
disk and each has exactly one instance. Native asset counts are preserved:
4804 MeshParts /3515 SurfaceAppearances /1 Terrain.228 ModuleScripts (one added),
1 Script /2 LocalScripts; all temporary probes removed before publishing.

Current revision **published successfully as v87**. Native Studio receipt:
`KDM_New_Hub` published, generated version-note link v87, 2026-10-27.
Access settings remained Private. No Git commit/push or production Publish.
Version note stored in QA Workspace:
`KDM Mobile Controls v3 Private QA — held GAS 90 studs/s, transparent HUD, Park Hub`.
The native publication receipt, not stale Edit DataModel.PlaceVersion, supplies
the final version number. Rollback to QA v80 / its backup or set
KDMGasPedalEnabled=false; never restore/publish into production.


## Fixed right-side item rows + GAS audio revision4 — 2026-10-27

Supersedes revision3's short-screen item fallback: there is no center fallback.
Both item rows always share BRAKE's horizontal center. Top row is SMOKE / SLICK /
THUNDER / MISSILE; lower row is SHIELD / NITRO only, immediately behind BRAKE.
Transparent backgrounds are retained. At the750x332 Studio safe viewport,
BRAKE is(596,179), size48; upper item positions are(531/577/623/669,85),
lower positions(577/623,131), size40. Both rows center at620, matching BRAKE.
The lower row ends8px above BRAKE. No central fallback exists at smaller sizes.

Official minimaps now share Park's separate DeviceSafeInsets ScreenGui placement.
Both actual Studio map panels measured position(660,-50), size78x78 and background
transparency1 relative to the CoreUI coordinate origin; native phone rendering
places both at the same safe upper-right location. NITRO CHARGE text aligns with
its bar's left edge; Drift charge segments sit immediately beside the text.
The previous isolated Drift percentage label is hidden in this QA presentation.

AudioRuntime.gasEngineTargets is shared by official and Park engine renderers.
At held GAS90 the target pitch is95% of boost peak(1.406), with bounded±.006
high-load flutter; acceleration from70 progressively raises pitch and volume.
It reuses the existing loaded engine sound and smoothing. Release restores the
normal target, while active Mini Boost / Nitro bypass the GAS modifier. It adds
no boost event, sound asset, heat mechanic, physics or authority changes.
Ordinary LocalScript -> actual Park remote/server -> live engine capture:
speed90.00373840332031, KartGasPedalActive=true, engine PlaybackSpeed1.41136694,
IsLoaded=true, IsPlaying=true. This confirms runtime properties, not audible
real-device acceptance; engine sound balance still needs owner listening.

Verification: mobile controls296 + geometry3524 PASS; expanded kart audio PASS
(including rise,95% target, flutter bounds, release, Boost/Nitro priority and live
controller heartbeat). Full246-test run:171 PASS /75 existing baseline failures,
no new failures against39055dd.231 sources compile; Rojo build and diff checks
PASS. All17 scoped source checksums match disk with exactly one instance each.
Temporary probe removed. Asset counts remain4804 MeshParts /3515 SurfaceAppearances
/1 Terrain, with228 ModuleScripts /1 Script /2 LocalScripts.

Exact QA Universe10772198697 / Place106553302629620 and HubParkV1Enabled=true
verified before publishing. LayoutRevision=4, preview and GAS flags true. Public
Studio was read only: Universe10768420544 / Place127925465904803 / version1231,
no GAS flag and no new audio helper. Prior native v80 backup remains available;
QA v87 is the preceding published UI/GAS checkpoint. Access settings are unchanged
from the owner-confirmed Private dashboard. No Git commit/push is authorized.

Published successfully as **QA Place Version91**. Native Studio receipt at
2026-10-27 12:36:30 (Asia/Jakarta): KDM_New_Hub published; version-note link v91.
Universe10772198697 / Place106553302629620 only. Private access was unchanged.
Test URL: https://www.roblox.com/games/106553302629620/
No Git commit/push or production Publish occurred.
Changed runtime modules for this revision: MobileControlView, RaceItemUiController,
LobbyPracticeView, DriftChargeView, RaceHudController, LobbyTestDriveController,
AudioRuntime and KartAudioController; mobile-controls and audio validations updated.


## Rounded controls / item row revision5 — 2026-10-27

All five controls now use code-drawn rounded rectangles (UICorner scale.28),
1px neutral white outlines, existing translucent fill and touch ownership.
DRIFT is left of GAS with equal dimensions; smaller BRAKE follows GAS above it.
SHIELD / NITRO are centered immediately above DRIFT at BRAKE's vertical level.
SMOKE / SLICK / THUNDER / MISSILE are above both, aligned from the right safe edge.
Items retain transparent backgrounds and now have1px white outlines, including
refreshes and empty counts. No center fallback. Actual Studio750x332 positions:
DRIFT(584,237), GAS(668,237), both69x69; BRAKE(679,177),48x48.
Steering(12,237)/(96,237),69x69,15px separation. Native emulator inspection PASS.

PublicRaceStatusView measures the notice text and resolves the new separate
DeviceSafeInsets minimap on layout. Actual native banner width272, right568;
map left660:92px clearance. Existing non-QA layout remains unchanged.

Official engine audio now treats PRE_RACE / COUNTDOWN / control lock as idle,
ignores stale speed and Boost/GAS, and applies the idle target immediately.
The actual engine heartbeat test repeats five Rematch-like cycles with stale
100-stud velocity and active Boost/GAS, asserting idle before GO each cycle.
This is a deterministic controller test, not a third-rematch real-device capture.

Authority review: GAS and Mini Boost only alter existing solver state/attributes;
there are no added joints, assembly changes or network ownership calls. Shield
remains the welded special case with its existing deferred validated repair.
Other item visuals/hazards/projectiles do not weld new parts to the seated kart.
Existing production item and combat tests cover accepted effects / targeting.
Added70 repeated GAS / Mini Boost / five non-Shield item-path ownership-write
checks PASS (targetless offensive calls may correctly reject). Existing25
seating/Shield deferred authority lifecycle checks PASS. No speculative physics,
camera or ownership changes were made to address uncorrelated hitches.

Live Park ordinary-script input probe exercised GAS and non-Shield item requests;
a first authority sampler hit the anchored countdown boundary and was discarded.
A corrected unanchored sampler recorded200 samples, zero automatic ownership,
zero client owner, zero anchored skips. That short capture is after the request
sequence, and does not establish every activation's ownership timing or long-run
mobile frame/network smoothness. Real-device repeated Rematches and audible idle
balance remain owner acceptance items. The temporary probe exists only in Play
and is absent from the saved Edit model after stopping.

Validation: mobile controller/HUD297 + geometry3527 PASS; audio repeated idle
cycles PASS; public banner31 PASS; GAS actual race integration80 plus policy/Park26
PASS.231 sources compile; Rojo build PASS. Full-suite result and native publication
receipt recorded below when complete. Publish remains restricted to private QA
Universe10772198697 / Place106553302629620. No Git commit/push.


Final revision5 validation:246 tests,171 PASS /75 unchanged baseline failures.
The banner fixture was updated to load MobileControlView with its actual workspace
and rerun successfully after the full run; final banner test31 PASS. No new failures.
All18 deployed source checksums match disk, exactly one instance each. No temporary
probe remains in Edit. Public Studio remains version1231, without the QA GAS flag
or audio helper; it was inspected read only. QA IDs, Park flag and layout5 verified.
Native v80 backup and QA version91 remain rollback checkpoints. Private access
settings were unchanged. Published successfully as **private QA Place Version94**, confirmed by native
KDM_New_Hub success receipt and v94 version-note link. Private access unchanged.
Test URL: https://www.roblox.com/games/106553302629620/
No production Publish or Git commit/push.


## Shared item frames / top-only combat / finish fade revision6 — 2026-10-27

BRAKE now right-aligns with GAS and Missile at the same12px safe margin.
Button dimensions and offsets use integer pixels to prevent a1px raster mismatch.
Steering glyphs changed from angle brackets to filled ◀ / ▶, preserving input.
Shared MobileControlView.styleItem gives Park and official items the same.28
rounded corners, neutral28/30/34 fill at.52 transparency, matching inactive controls.
The1px white outline is on an inset1px overlay above images/captions. This addresses
Park's clipped ScrollingFrame boundary strokes and the missing official UICorner.
The old button-attached borders are disabled, avoiding doubled/interrupted frames.

CombatFeedbackView is the final placement owner for every result and incoming
warning, regardless of QA flag, caller position, portrait/short screen, or a bottom
speed panel. CoreUI-safe top6px is the normal band; simultaneous incoming/result
uses warning6px and result40px. Both stay at the top and never follow lower widgets.
All nonempty Park event messages, including target lock and incoming warnings, use
this shared view; PracticeFeedback shows charge state only. Ordinary Studio Park
lock-message presentation produced a visible MISSILE LOCKED badge at y6. Production
view tests include hit/block/victim feedback and hostile center/bottom layout inputs.

Finish regression: revision5's immediate idle alpha also affected finish/control
lock, while Park explicitly stopped both engine voices at PRESENT. The shared
AudioRuntime finish envelope now captures the preceding engine target and smoothly
fades pitch toward idle and volume to zero over3.3s (2.4s roll +.9s transition),
even if lock/stale velocity arrives first. Park no longer stops at PRESENT. Pre-GO
idle remains immediate. Replay/Rematch clears the envelope; no physics/boost changes.
Actual ordinary-script Park client finish-presentation simulation captured both
engine voices combined: t0≈.246,t.5≈.263,t1≈.262,t1.5≈.155,t2≈.092,t2.5≈.038,
t3≈.005,t3.5=0. Loop-splice crossfading means individual voice volume can be zero
and combined amplitude can briefly vary; the underlying target envelope is smooth
and monotonic. This is a local presentation simulation, not a completed valid lap
or audible real-device acceptance. Original first-voice-only capture was not used
to infer silence during loop splices. Temporary probes are Play-only.

Validation: mobile controls417 + geometry3527 PASS; combat view152 PASS; expanded
engine tests include crossing continuity, monotonic3.3s fade, no PRESENT-boundary
cut, Replay reset and five pre-GO idle cycles PASS. Touch1188, HUD513, six-item453,
GAS80+26 and authority25 PASS. Full246:171 PASS /75 existing baseline failures,
no new failures. Final integer-pixel and glyph changes passed affected mobile tests.
231 sources compile, Rojo build and diff checks PASS.18 deployed source checksums
are checked against disk with uniqueness, exact QA IDs and Park flag before Publish.
Assets remain4804 MeshParts /3515 SurfaceAppearances /1 Terrain. Private-only QA
Universe10772198697 / Place106553302629620; no Git writes. Published successfully as **QA Place Version97**, confirmed by
native KDM_New_Hub receipt and v97 note link. Private access unchanged.
Test URL: https://www.roblox.com/games/106553302629620/
No production Publish or Git commit/push.


Final native integer-pixel check: BRAKE right738 / GAS right738 / Missile right738
at750x332; actual steering labels ◀ / ▶. Added finish lock-before-state regression:
RACING control lock alone does not snap audio, and the following FINISHING/ROLL
retains crossing sound. Pre-GO states still idle immediately. This handles delayed
state/phase replication without changing lock authority. Affected audio test PASS.
Scoped Rojo was no longer syncing at this revision; the exact updated client
sources were applied only to the verified QA Edit model and checksum-verified.
No unscoped/full asset synchronization was performed. Native assets unchanged.


## Official pre-race panels share results style revision7 — 2026-10-27

RaceHudController now reuses the existing ResultPresentationView panel/button
helpers for RaceLobbyHost and AvailableRacers, including Start, Cancel/Leave,
Invite and Add/Remove Bot. Panels use70/110/135 blue at.4 transparency with the
same2px pale-white border and16px corner as Results; buttons use115/205/230 cyan
at.25 with8px corners. Headings/counts are white. Inactive human/bot invitation
states retain.55 transparency; AUTO START keeps the normal cyan appearance while
its existing authoritative automatic-start policy still owns activation.
Refresh paths preserve the new style instead of restoring old opaque blue/grey.
No remote, handler, room state, admission, bot or race behavior changed.

Validation: production race result/HUD269 checks and D2 integration PASS;
invitation handoff8 PASS;231 sources compile; Rojo build and diff checks PASS.
The requested racer-rows standalone test filename does not exist; actual bot-row
coverage is included in the production HUD test. No full-suite rerun was needed
for this appearance-only revision. Existing unrelated baseline failures remain.
Only RaceHudController runtime source changes in this revision; native QA layout
inspection and final checksum / publication receipt recorded below.


Native ordinary-client pre-race presentation check: both panels visible, panel
alpha.4,2px border, Start/Cancel/Invite buttons use the exact shared results cyan
and normal.25 alpha. Native emulator screenshot confirms appearance.18 scoped
source checksums match disk with exactly one instance each; no temporary probes.
QA IDs/Park flag/revision7 verified. Public Studio remained version1231 without
QA flags and was read only. Access settings unchanged from owner-confirmed Private.
Published successfully as **QA Place Version98**, native KDM_New_Hub receipt
and v98 note link confirmed. Private access unchanged. No production Publish or
Git commit/push. Test URL: https://www.roblox.com/games/106553302629620/


## Park wall reverse / progressive70 revision8 — 2026-10-27

Ordinary held negative input could already back away from a simple outer wall
before repair; that observation does not reproduce every owner touch/contact.
The initial actual Studio grass capture ramped only to≈40 because reverse50 had
an off-road80% multiplier. The UI also retained GAS when its already-owned finger
moved into BRAKE: InputBegan on BRAKE was ignored for an existing touch, and the
old InputChanged transfer recognized DRIFT only. It now recognizes BRAKE first,
releasing GAS and assigning negative throttle to that same finger. Direct BRAKE
and the earlier GAS-to-DRIFT gesture remain intact. Hardware gesture acceptance
remains separate from deterministic controller transport checks.

Shared KartConfig reverse maximum and Lobby policy reverse maximum are70.
Park no longer reduces reverse maximum on grass. The existing22 studs/s² reverse
acceleration and70 studs/s² forward braking are unchanged. Positive speed reaches
zero before reverse acceleration, taking≈3.18s from rest to-70. Release/auto-forward
uses existing smooth braking and acceleration, with no reverse boost or jump.
The service wall-stop reconciliation now rejects opposite-sign contact jitter and
removes its accidental reference to offTrack before that local's declaration.
No new ownership call, joint, collider, teleport recovery rule or forward tuning.

Actual ordinary LocalScript -> Park control remote -> live server/chassis capture
at outer IslandEdgeGuard, position(0,.6,-356), facing toward the front wall:
.25s:-4.19,1s:-21.48,2s:-43.84,3s:-66.93,3.25s:-69.91 studs/s.
The kart moved inward from z-356 to z-235 by3.25s. All20 quarter-second samples
were off-road, manual ownership(auto=false) and server-owned(clientOwner=false).
This is Studio server physics, not real-device long-session acceptance. The initial
before capture reached≈-39.83, and both recordings used the same outer wall setup.

Validation: mobile controls418 + geometry3527; reverse1640 checks on road/grass at
30/60Hz; actual service heartbeat236 including stale forward budget, zero crossing,
progressive cap and opposite-sign jitter; actual official server GAS/reverse881 +
policy26; touch1188; ownership25; training855 PASS. Updated historical50-cap assertions
and durations for70, leaving rates unchanged. VFX freeze comparison normalizes only
the separately authorized50->70 reverse field; other config remains byte-identical.
Full246 run plus affected fixture reruns:171 PASS /75 unchanged baseline failures,
no new failures.231 sources compile; Rojo build and diff checks PASS.21 deployed
source checksums and uniqueness PASS; all temporary probes absent from Edit.
Changed runtime files: TouchDrivingController, LobbyDriftSession,
LobbyTestDriveService, KartConfig and LobbyDrivePolicy. Only exact private QA
Universe10772198697 / Place106553302629620, Park enabled, revision8. No Git writes.
Published successfully as **QA Place Version99**, confirmed by native KDM_New_Hub
success receipt and v99 note link. Private access unchanged. QA v98 and the existing
native backups remain rollback points. No production Publish or Git commit/push.
Test URL: https://www.roblox.com/games/106553302629620/


## Measured head-on rim reverse release revision9 — 2026-10-27

Owner clarifies the thumb presses BRAKE only and confirms the70 ramp; the remaining
failure is exact head-on rim contact, not the earlier GAS-to-BRAKE gesture. The
prior wall-placement capture was insufficient. A first grid run reversed too early
before impact and was discarded. Subsequent ordinary-client runs drove all the way
to the actual x700 IslandEdgeGuard at z765 and first-grid z737, with no steering.
At z737 the kart stopped at x≈695.05 and continued forward pressure for5s; subsequent
negative input backed it away normally, without any recovery correction. Server
manual ownership stayed intact. These successful Studio natural collisions do not
reproduce or disprove the owner's exact published real-device immobilization.

Added a bounded Park-only release guard for that stationary physical condition.
The service caches the eight actual IslandEdgeGuard colliders and tests chassis
support extent against their oriented boxes. It does not use road/grass clearance,
which measures distance from the race route rather than the island rim. Qualified
contact has front-to-wall alignment dot≤-.98, signed hull gap[-1,.25], valid held
negative throttle, negative command, actual speed<5 and≤.15 positional movement
for.35s. It then translates inward only by clamp(.30-gap,0,1), at most twice per
continuous stall with1s cooldown. It preserves height/heading, progressive speed,
seating, existing safe recovery and manual server ownership. Normal reverse motion,
oblique contact or absent braking never qualifies. ParkReverseReleaseSerial and
Distance change only on a correction; no per-frame diagnostic replication.

Deterministic actual-service tests cover real wall box qualification, contact
release,≤1-stud correction, unchanged height, no granted speed, oblique/free-space
rejection,3-stud stationary contact jitter, absent brake and already-moving reverse.
245 heartbeat/qualification checks PASS; reverse1640, authority25 and training855
PASS. Syntax compilation and Rojo build PASS. The natural capture used the stricter
initial<2 speed cutoff; the final<5 cutoff admits the owner's visible≈3 contact
jitter while retaining the displacement/duration gate. No inference that the
owner's hardware issue is fully reproduced or accepted should be made.

A separate labelled native controlled-stall injection validates guard execution
against the actual rim after a natural approach. It is explicitly fault injection,
not a natural failure reproduction. Result, final suite and Publish receipt follow.


Controlled native stall injection result: holding accepted reverse while cancelling
physical motion only for the test yielded releaseSerial1, inward correction
.34981786 stud. Subsequent samples: x693.12/speed-8.61 at.68s, x679.40/-25.86 at1.47s,
x652.18/-43.08 at2.25s. All samples retained auto=false / clientOwner=false.
No repeat correction occurred. The injected condition disconnected after the first
release; all temporary scripts/listeners/captures disappeared when Play stopped.
This validates the live release path and does not establish the owner's exact
natural device failure cause. That acceptance remains pending owner retest.

Final246-suite run:171 PASS /75 unchanged baseline failures, no new failures.
Affected heartbeat245, reverse1640, training855 and authority25 PASS.231 sources
compile; full Rojo build and diff check PASS. Existing QA v99 and native backups
remain rollback points. Only LobbyTestDriveService and LobbyDrivePolicy runtime
sources changed in this revision. Private QA published successfully as **Place Version101**, confirmed by native
KDM_New_Hub success receipt and v101 note link. Private access unchanged.
No production Publish or Git commit/push.
Test URL: https://www.roblox.com/games/106553302629620/


## iPhone BRAKE transparent hit blocker / count-only Park items revision10

Owner reports no BRAKE pressed color on iPhone even before wall impact, while
PC/Studio reverse works. This is evidence of an input/UI blockage rather than an
established physics failure. Found the higher-layer Park PracticeItems scrolling
rectangle spans the empty right side of row2 over BRAKE. KDMLobbyTestDrive uses
DisplayOrder21 versus RobloxKartTouchDriving20. Scrolling/touch capture explains
why keyboard/PC transport testing missed it; no further physics changes made.

Native PlayerGui:GetGuiObjectsAtPosition at BRAKE center(714,201) before repair:
PracticeItems ScrollingFrame appeared above ControlsV1Glyph / BrakeReverse.
After repair, the only interactive TextButton/ScrollingFrame at that point is
BrakeReverse Active=true; PracticeItems.Visible=false, Active=false and
ScrollingEnabled=false. Fixed-layout item buttons now parent directly to
SafeCanvas at their own positions. There is no rectangular input target over the
empty row2 space. Legacy scrolling presentation retains its original container.
Direct item requests check active view state rather than scroll visibility, and
all reparented buttons are explicitly cleaned up on destroy.

The owner also requests Park icon parity: its separate view still authored
item-name/cooldown captions. Fixed Park now shows the same bottom-right quantity,
14px white text with dark stroke, as official race items. Names are absent;
server charges/refill/cooldown semantics are unchanged.

Validation: actual controller + actual Park view494 checks, geometry3527; tests
cover hidden/disabled scroll, individual item parents, no item/BRAKE overlap,
direct item requests, count-only labels and cleanup across three viewports.
Touch1188, six-item453, practice layout260, reverse1640 PASS.231 sources compile,
Rojo build and diff checks PASS. No full-suite rerun for this UI-only change;
previous full checkpoint171 PASS /75 baseline failures remains separately recorded.
Only LobbyPracticeView runtime source changes this revision. Current QA Studio
connection changed after reopen; exact Universe10772198697 / Place106553302629620,
Park flag and revision10 verified. Temporary native probes are Play-only.
Published successfully as **private QA Place Version103**, confirmed by native
KDM_New_Hub success receipt and v103 note link. Private access unchanged.
Final native check: six Park captions are numeric1 only and each button parents
to SafeCanvas; BRAKE center has only BrakeReverse Active=true as an interactive
button/scroll target.21 source checksums/uniqueness and probe removal PASS.
Public Studio remained version1231 without this patch and was inspected read only.
No Git commit/push or public Publish.
Test URL: https://www.roblox.com/games/106553302629620/
