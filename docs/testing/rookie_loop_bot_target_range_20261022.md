# RookieLoop bot target range

The owner confirmed Missile/Thunder were attempted with the demo bot far away.
The unchanged 180-stud practice acquisition range rejected those requests; the
previous route rollout tested direct hit resolution but not distant use/launch.

PARK demo-bot acquisition now allows 480 studs with the same forward dot >=0.15,
valid actor, seating, generation and authoritative server target selection.
Other humans and the original apron bot retain 180 studs. Closest valid target
selection, charge consumption/refill, warnings, missile speed/lifetime, effects,
audio and official RACE are unchanged. Bots behind or beyond 480 remain excluded.

The focused test drives the real Combat:use, HomingMissileService and
ThunderStrikeService against a moving bot 400 studs ahead. Both weapons launch
and produce confirmed hit results (not just a launch acknowledgement), followed
by six-second refill. It also covers out-of-range/rear rejection without charge
consumption, stale generation/client target rejection, PvP/legacy boundaries and
pending missile cleanup when the bot disappears: 23 checks PASS.

Related regression: 34 suites PASS / 4 existing FAIL / 0 new FAIL. The historical
guidance, practice four-slot, post-drive callback and audio snapshot failures are
unchanged. Production Luau compilation (206 files), Rojo XML/binary builds and
diff checks PASS. Native Studio/mobile firing with this change is NOT VERIFIED.
No Roblox Publish performed.
