# Attacker Missile / Thunder impact audio

Baseline `1d25b277ff24c127fb927bd7d253df26af1c7005` matched the fetched
`origin/prototype/kart-physics`; tracked working tree was clean.

The omission affected both race and practice source paths. Commit 3089cee added
one generic hit helper reusing BOOST_START, rather than dedicated explosion or
Thunder assets. Commit 7232692 removed that inappropriate booster cue without
adding replacement attacker audio. Race CombatFeedbackView currently renders
results only; practice previously published text only. A read-only inventory of
the running Studio client also found no Missile/Thunder hit Sound instances.

Added CombatHitAudioController, started once from client init, shared across
both modes. Race Missile listens to confirmed MISSILE_HIT; Thunder listens to
the authoritative event summary with positive hit count, once per event. Block,
no-hit, victim-only, inactive and duplicate serial events remain silent.

Practice publishes a typed hit serial only after real Missile resolution or a
positive Thunder event summary. It includes the practice session, drive generation
and recovery serial. Bot and seated-human targets use the same path; messages are
not parsed to infer outcomes. No damage, movement, timing, target, charge or VFX
changes. Sounds are local to the attacker under the existing SFX group and do
not attenuate with distance to the victim. Lifecycle changes stop playback.

The old code contains no separate original explosion/Thunder recording to
recover. Replacement uses Roblox's bundled `sounds/impact_explosion_03.mp3`, at
pitch 1.0 for Missile and 0.68 for the lower Thunder impact/rumble. No external
audio asset, upload, BOOST_START substitution or asset permission dependency.

Validation: 11 focused suites PASS; new audio controller 24 checks, actual
practice orchestrator 447, race feedback 108, plus kart audio, Missile, Thunder,
practice UI/layout, driving containment, return flow and world VFX. Changed
sources compile; Rojo build and diff checks PASS.

Native Studio Client probe: the bundled asset successfully loaded (2.586 seconds)
and entered playback at both pitches with advancing TimePosition. The probe used
zero volume and removed its temporary Sounds. This verifies native loading and
playback, not human listening or published mobile acceptance. Existing running
scripts were not replaced; no Roblox Publish was performed.

Untracked logs/build: `artifacts/combat-hit-audio/`.
