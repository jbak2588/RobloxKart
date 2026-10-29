# Hub arrival and Overtake shortcuts - 2026-10-30

Owner explicitly requested code changes, scoped commit/push and official Publish.
Baseline: 91446d377f43064c8384da9ac61efd207913eb54, freshly fetched local/origin equal.

## Behavior

- Park Hub arrival moves 15 studs toward the T crossbar: (0, .75, -51),
  still facing -Z. RookieParkOrigin, walkway, exhibits, course and start anchors
  are unchanged. Native TIME ATTACK prompt remains at z=-35 / radius12.
- Wallet uses the navigation fill24/36/52 at .58 transparency and pale225/235/245
  text without the old green text stroke, blue gradient or capsule outline.
  Rounded capsule, cash formatting and shop-plus action remain.
- OVERTAKE appears above RACE NOW and TIME ATTACK. All three have44px targets,
  12px vertical gaps, guarded navigation and teardown disconnection. The new
  shortcut calls the existing requestDrive("OVERTAKE") entry.
- Overtake instructions measure the existing four text lines once at18px and
  add24px total horizontal padding. Native topbar and actual Park minimap bounds
  constrain the panel with12px clearance. Remains at top6px, hides at countdown1.
  This supersedes the PV1265 countdown3 presentation requirement only.

## Validation

- Current release integrity:772 checks PASS; exact five source hashes added as
  hubArrivalUiPatches, retaining historical N1/N2 and all prior release pins.
- Independent Python --check-manifest PASS; Rojo default build and diff check PASS.
- F60 visual layout:444 checks PASS (three actions, minimum touch bounds, short
  safe canvas, gaps and connection cleanup).
- Park trial view:307 checks PASS (topbar/map clearance, padding, visible3/2,
  hidden1, unchanged finish/reward presentation).
- Raw full suite:252 tests,231 PASS /21 FAIL. Twenty are the same historical
  failures; the additional decor test still pinned the old arrival source. Its
  revised exact arrival-only reversal preserves the original geometry comparison
  and passed2404 checks on rerun. Final reconciled result:232 PASS /20 historical
  FAIL /0 new FAIL. Historical fixtures are unchanged; NOT FULL_SUITE_PASS.
- Raw logs: C:/Users/Public/Documents/ESTsoft/CreatorTemp/kdm-hub-ui-20261030-5ga6t_6f/.
- [Machine-readable receipt](hub_arrival_ui_results_20261030.json).

## Studio evidence

- Exact official Universe10768420544 / Place127925465904803; initial version1265.
- Ordinary initializer/arrival with iPhone17 Pro landscape simulation:
  viewport750x382, CoreUI-safe navigation750x324, Overtake156x44.
- Character arrived near local(0.01,3.00,-50.98); TIME ATTACK prompt distance16.25
  exceeds radius12. Arrival screenshot has no ROOKIE LOOP/TIME ATTACK prompt.
- Wallet actual BackgroundTransparency .58, fill24/36/52, text225/235/245.
- Native shortcut click entered ParkOvertakeActive=true using the existing route.
- Runtime countdown probe observed visible8/7/6/5/4/3/2 and hidden1. Native viewport
  screenshot at2 shows the compact instruction panel above the countdown and
  clear of the Park minimap. Measured instruction size370x88.
- Play stopped and device simulation reset to default after verification.
- Existing PlayerPreferences API / Studio aggregate-presence warnings remain;
  no new release-source runtime exception observed. A failed read-only parity
  transport attempt logged HTTP disabled; HTTP settings were left unchanged.
- Real Android/iPhone published visual acceptance is still pending; Studio
  simulation does not establish real-device or full-race economy acceptance.

## Full native backup and parity

Backup (candidate sources included):
C:/Users/OWNER/AppData/Local/Temp/KDM-official-hub-ui-20261030.rbxl
Bytes1411991; SHA2567712c6d0b46d90dde865d9f1dc0390618f18b69ef18159deee2c925af6da54e8.
Native backup was deserialized read-only with Lune:232/232 local project sources
match canonical LF SHA256; zero mismatches. Three Workspace release flags remain
true. The binary Terrain content-map property is unknown to Lune; the native
backup is preserved byte-for-byte and is not reserialized or used as a rebuild.
Publication uses the original Studio scene. No server restart or QA access change.
