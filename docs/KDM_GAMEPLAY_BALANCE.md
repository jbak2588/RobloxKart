# KDM gameplay balance

`src/shared/KDMGameplayBalance.luau` is the frozen source for item effects,
Drift/charge, Nitro, Mini Boost, immunity, feedback and Bonus Nitro requirements.
Existing gameplay consumers use the unchanged RaceItemConfig and KartConfig APIs.

Durations are seconds, distance is studs, speed is studs/sec (not km/h),
acceleration is studs/sec squared, yaw is radians, slip thresholds are degrees.
Base vehicle physics, camera, UI, assets, networking, routing and RaceConfig
remain outside this module. Server effect authority remains unchanged.

**Balance value change != implementation change.** Future approved tuning should
change this source unless gameplay logic itself must change. No live overrides exist.

Run gameplay_balance_validation, race_item_validation, missile/slick/smoke/thunder,
mobile_touch_validation (Touch and Joystick), bot validations and the full
`*_validation.luau` suite, then Rojo build and git diff --check.
R6-C0 preserves exact values from baseline 6c7e4b39.
