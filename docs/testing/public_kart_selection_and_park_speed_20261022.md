# Public Garage selection and PARK speed — 2026-10-22

Owner requested general-player Garage selection to remain until explicitly
changed and RookieLoop normal speed of 80 studs/s. Commit/push only; no Publish.

Selection persistence previously admitted only the owner's canary account.
AllowAllUsers now enables valid ordinary accounts in the exact production public
HUB. Studio, RACE, reserved/private servers and other experiences remain excluded.
The existing schema/store, bounded adapter, receipts, CAS, read-back confirmation,
retry and departure handling are reused. Joining never creates a default profile;
an explicit valid selection can create one. Setting AllowAllUsers=false restores
the owner-only canary. No currency, item, record or reward reset is performed.

LobbyDrivePolicy.ParkForward=80 applies only to ROOKIE_LOOP_V1. Official RACE
KartConfig remains 70 and legacy HUB remains 60. Acceleration, reverse, Drift,
Mini Boost, Nitro and server ownership are unchanged.

Validation: 29 suites PASS / 4 existing FAIL / 0 new FAIL. The normal PARK
regression set retains its three historical failures. Expanded progression
coverage additionally finds r8_a2l1_canary_guidance_validation failing its old
P02/P03/P04/P08 UI contracts; the same failures were reproduced with 482888b
config, policy and test sources. These assertions remain failing, not waived to
PASS. Updated public admission assertions in P01 pass.

Real Coordinator tests cover canary and ordinary-user restore/save paths. A
mock-backend test verifies first explicit save, two-user key isolation, fresh
service/rejoin restoration and replacement only on another valid selection.
The real Drift solver reaches the 80 cap in deterministic tests. Production
Luau compilation, Rojo XML/binary builds and diff check pass. No real DataStore
test writes were made. Published rejoin/mobile driving are NOT VERIFIED.
