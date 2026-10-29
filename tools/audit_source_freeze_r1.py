"""Read-only N1/N2 audit; never regenerates an acceptance fixture."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPROVED = 'f5ebec8c7f86dac5c488f90a0a01041d147cf4a2'
FOV_PATH = 'src/shared/KDMSpeedSensation.luau'
VFX_PATH = 'src/client/KartWorldSpeedRenderer.luau'
# Owner accepted mobile-tested V3.2 and authorized production release2026-10-28.
# Pin independently of the manifest; retain every historical/base hash.
VFX_SHA256 = '0c606e01d8c63e3938430730d49ca033663033fd648bb833690bb300e2e0e1fb'
PARK_PATH = 'src/server/LobbyTestDriveService.luau'
PARK_SHA256 = '7af484a2ee7f089f673d938c04d6e3fae33d7ead8abe1e208d8dfb36bbbfbd3a'
VFX_OPT_HASHES = {
    'src/client/KDMItemVFXController.luau': '20363b517f249e6697ee5c4e38f4b103f231192f1b90c0ab94915ad505d1ae8d',
    'src/client/KartWorldVFXController.luau': '8b07f93ac60a06eee05065e0b56d4e5acf3e69a92504f387782336704b2cc8c2',
    'src/client/ShieldWorldRenderer.luau': '3a3a07f5c9b330af6635b214c93c98fd8d765e4c4c1d3d92a1c3caf2c2b9941a',
    'src/client/SmokeEffectView.luau': '0eede89f1c667a2d2703c5ef31c4feb5bcbaaa64211c8df83577c94d926c9cfb',
    'src/server/RaceItemVisuals.luau': 'dca2c4a5fdbefc91121ff64e82925c472be3db6f07044132d147acef99cce9d1',
}
# Owner-requested Park overtake release2026-10-29; historical hashes stay intact.
PARK_OVERTAKE_HASHES = {'src/client/GarageUiController.luau': '2e155b53e2a97be8a272a6a07084cd01a3bef36eb44769036af19a78c80c3a65', 'src/client/LobbyDemoController.luau': 'c3ba8233ac951e4c9aa5b7ece728463554a37b4149c59ac83684bd8f9190f7f1', 'src/client/LobbyPracticeView.luau': 'c284dda537d17f4b01e2c9f0434189863dcef920f285d6262c1b2a5dd7be1646', 'src/client/LobbyTestDriveController.luau': '508dd98c01cdd141aec0180bc7b5bf05a557cd1c773e00115c61c348c2060398', 'src/client/ParkOvertakeBotsView.luau': 'ca9612a223744e76b27a3e9a00856ba8efb2a90232fa302f32d17b9482c18124', 'src/client/RookieParkTrialView.luau': 'a51a435f2f34b54521dd645b4e7e9de32b05970a68b6831bc2a2af5b873d101f', 'src/server/EconomyService.luau': '140fa169e66556394e5b473bff7f9957791cf75e934bf766f683217f4cbf656d', 'src/server/LobbyPracticeCombat.luau': '1049ff96778393b7d0dd6e03e2b055511e58a530c0107b4805b762fec584ea52', 'src/server/LobbyTestDriveService.luau': '51042b06db31309968a6ae876f8a61cc63439288415dd7a12bfdb1327e59a76c', 'src/server/ParkOvertakeReward.luau': '0f9703846ab67938d5b119f22d7e5e5b9914254e285d0d43612187140aed0a61', 'src/server/RookieParkTrialSession.luau': '747ecaf2e3a7153ccc832095299f5993a51738a79ed7143e1ea6a30086d02b6d', 'src/shared/ParkOvertakePolicy.luau': '9c8f5aa07e80c423505841c085b66be5316dfd52f2cb2058d899ff618b2aca54', 'src/shared/RookieParkTrial.luau': '17c9db15469c3b828bae667e23c58241828179bc275729662e1e5ce53732d6dc'}
FOLLOWUP_PARENT = 'aba4a8b87b99b36109597a7ddcb22f3b2ea2684f'
FOLLOWUP_HASHES = {'src/client/ActivityRewardView.luau': '6205fe9a07bd140b0543073eb1951772d7abf25123db8ab5b73a361be7a62452', 'src/client/EconomyController.luau': 'fd6f3c2ae6d167fe19d94e4bc84fea5b2b7557cf8c37f187acc627f49a560ed3', 'src/client/HubGuidanceState.luau': '2c5eb0a791d6fd83ccff820c0131f942a80a0f4ec852dcedc787e0a0bc9fe9aa', 'src/client/HubGuidanceView.luau': '4a5c50e9a1fdde254cc996c3769b652f0415b73d0cd7069f067f0e5a490ffa85', 'src/client/HubLeaderboardController.luau': 'c943c7d4e38d996602701761960d79f6c117d7666c8e49a778474ea2550b01e0', 'src/client/HubUiController.luau': '346d5878e5b6888c4a7626d5f1af27c3e751964e9360938ea5d575ff6a2430c4', 'src/client/LobbyPracticeView.luau': '8b42ff3c700a6f44e2c3f53a82d35a88e3c3e1bf88cc665c61c5fdda10ef6dee', 'src/client/ParkOvertakeBotsView.luau': 'dfa45d60b1a8fb49b7dc780d9a936fd6ad349cd5068e5cf3676c3d1359b07131', 'src/server/HubLeaderboardBoardBuilder.luau': 'f1b1022fb38b872ba3c07a0bbcd83daf67318f252e16582e7a0ad38c5f46df06', 'src/server/HubParkRookieLoopBuilder.luau': 'f1cdad23649de8e23f29b6f58a4e596dbd90e4a0d4688c40a3e838381e2355f6', 'src/server/LobbyFrontDriveZoneBuilder.luau': 'c913a709236825b177aa18af8ff5de08387774d90e6bcf761f175614b7b33e0d', 'src/server/LobbyPracticeCombat.luau': 'b7a5a36a85a3ea9305bf81bf62db0271fe457350e5967172676a6334589e3494', 'src/server/MatchRoomService.luau': 'c5a8b9482ea2b361de98f8fef67e0012313500282f7c45e729c0e9e525bdc28f', 'src/server/ParkOvertakeReward.luau': '0947f76bd721623204205e791614055283258092a5a725a99c545b3bad144ecc', 'src/server/RookieParkTrialSession.luau': '87a25c5f40b92fa97fe1440cd0d43d8151d1cca9d676af961e41ea8fad1b9a23', 'src/shared/ParkOvertakePolicy.luau': '26c7192d025709db5e57b8e4058f70a8273cff5b02df40604f205ae7a3b2f3df'}
OVERTAKE_PARENT = '75ba1e7d29b336b74ce8814ef80115c9c2f20195'
FOV_CHANGES = [('Speed.HIGH_SPEED_START = 55', 'Speed.HIGH_SPEED_START = 50'),
               ('Speed.HIGH_SPEED_FULL = 80', 'Speed.HIGH_SPEED_FULL = 90'),
               ('HIGH_SPEED = table.freeze({FovDelta=3,', 'HIGH_SPEED = table.freeze({FovDelta=5,')]

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def canonical(raw):
    return raw.replace(b'\r\n', b'\n')

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def audit():
    release_path=ROOT/'tests/fixtures/source_freeze_release_f5ebec8.json'
    release=json.loads(release_path.read_text(encoding='utf-8')) if release_path.exists() else {}
    patches=[release[k] for k in ('ownerR3PolicyPatch','ownerR3DisplayPatch') if release.get(k)]
    l2 = json.loads((ROOT/'tests/fixtures/l2_presentation_changes.json').read_text(encoding='utf-8'))
    def historical(raw, path):
        raw = canonical(raw)
        for change in l2['files'].get(path, []):
            raw = raw.replace(change['after'].encode(), change['before'].encode(), 1)
        return digest(raw)
    n1 = json.loads((ROOT/'tests/fixtures/speed_sensation_starting_hashes.json').read_text(encoding='utf-8'))
    n2 = json.loads((ROOT/'tests/fixtures/n2_source_freeze.json').read_text(encoding='utf-8'))
    rows = []
    for family, mapping in [('N1', n1['hashes']), ('N2 frozen', n2['frozenHashes']), ('N2 candidate', n2['candidateHashes'])]:
        for path, expected in sorted(mapping.items()):
            alternatives = []
            if family == 'N1':
                hotfix = n1.get('approvedSourceHotfixes', {}).get(path)
                presentation = n1.get('approvedPresentationCandidates', {}).get(path)
                if hotfix:
                    expected = hotfix['sha256']
                if presentation:
                    expected = presentation['sha256']
                repair = n1.get('unstagedPresentationExceptions', {}).get(path)
                if repair:
                    alternatives.append(repair['sha256'])
            elif family == 'N2 frozen' and path == 'src/server/CompactHubBuilder.luau':
                alternatives.append(n2['hubException'])
            base = git('show', f'{APPROVED}:{path}')
            current = (ROOT/path).read_bytes()
            base_hash, current_hash = historical(base, path), historical(current, path)
            last = git('log', '-1', '--format=%H%x09%s', APPROVED, '--', path).decode().strip().split('\t', 1)
            history = git('log', '--format=%H%x09%s', f"{n1['baseline']}..{APPROVED}", '--', path).decode().splitlines()
            local_changed = canonical(base) != canonical(current)
            candidate = canonical(base)
            for before, after in FOV_CHANGES:
                if path == FOV_PATH:
                    assert candidate.count(before.encode()) == 1
                    candidate = candidate.replace(before.encode(), after.encode(), 1)
            owner_patch=any(path in ('src/server/RaceRecordOperations.luau','src/shared/TrackCatalog.luau') and path==r3['path']
                         and digest(canonical(current))==r3['sha256']
                         and canonical(current).count(r3['after'].encode())==1
                         and canonical(current).replace(r3['after'].encode(),r3['before'].encode(),1)==canonical(base) for r3 in patches)
            vfx_opt = path in VFX_OPT_HASHES and digest(canonical(current)) == VFX_OPT_HASHES[path]
            category = ('OWNER_ITEMS_KIOSK' if path in FOLLOWUP_HASHES and digest(canonical(current))==FOLLOWUP_HASHES[path]
                        else 'OWNER_PARK_DRIVER_COLLISION' if path == PARK_PATH and digest(canonical(current)) == PARK_SHA256
                        else 'OWNER_VFX_V3_2' if path == VFX_PATH and digest(canonical(current)) == VFX_SHA256
                        else 'OWNER_PARK_OVERTAKE' if path in PARK_OVERTAKE_HASHES and digest(canonical(current))==PARK_OVERTAKE_HASHES[path]
                        else 'OWNER_VFX_OPTIMIZATION' if vfx_opt
                        else 'OWNER_R3_POLICY_PATCH' if owner_patch else 'FOV_PHASE1' if local_changed and path == FOV_PATH and canonical(current) == candidate
                        else 'UNKNOWN_LOCAL' if local_changed else 'APPROVED_HEAD' if base_hash not in [expected, *alternatives] else 'HISTORICAL_MATCH')
            rows.append(dict(family=family, path=path, expected=expected, alternatives=alternatives,
                             approvedHistoricalHash=base_hash, workingHistoricalHash=current_hash,
                             approvedRawHash=digest(canonical(base)), workingRawHash=digest(canonical(current)),
                             baselineMismatch=base_hash not in [expected, *alternatives],
                             workingMismatch=current_hash not in [expected, *alternatives],
                             category=category, lastCommit=last[0], lastSubject=last[1], history=history))
    return dict(approvedHead=APPROVED, actualHead=git('rev-parse','HEAD').decode().strip(),
                n1Baseline=n1['baseline'], n2Parent=n2['parent'], rows=rows)

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='Optional audit report, not an acceptance fixture')
    parser.add_argument('--check-manifest', action='store_true', help='Verify immutable release manifest against approved Git objects')
    args=parser.parse_args()
    result=audit()
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    for family in ('N1','N2 frozen','N2 candidate'):
        rows=[r for r in result['rows'] if r['family']==family]
        print(f"{family}: targets={len(rows)} HEAD mismatches={sum(r['baselineMismatch'] for r in rows)} working mismatches={sum(r['workingMismatch'] for r in rows)}")
    for r in result['rows']:
        if r['workingMismatch']:
            print(f"{r['family']} | {r['path']} | {r['category']} | {r['lastCommit'][:7]} {r['lastSubject']}")
    # APPROVED remains the historical anchor after the release commit. Every
    # protected working source is independently checked below, including mutations.
    if git('merge-base','--is-ancestor',APPROVED,'HEAD') or any(r['category']=='UNKNOWN_LOCAL' for r in result['rows']):
        raise SystemExit('Unapproved HEAD/local change: audit is not an approval')
    if args.check_manifest:
        manifest=json.loads((ROOT/'tests/fixtures/source_freeze_release_f5ebec8.json').read_text(encoding='utf-8'))
        assert manifest['approvedHead']==APPROVED
        required={r['path'] for r in result['rows']}
        required.update(p for p in git('diff-tree','--no-commit-id','--name-only','-r',APPROVED).decode().splitlines() if p.startswith('src/'))
        assert set(manifest['files'])==required, 'Protected file set must equal historical union plus exact mobile-release source files'
        for path, entry in manifest['files'].items():
            original=canonical(git('show',f'{APPROVED}:{path}'))
            assert entry['sha256']==digest(original), path
            assert entry['lastCommit']==git('log','-1','--format=%H',APPROVED,'--',path).decode().strip(), path
            allowed=[original]
            if path==PARK_PATH:
                assert manifest['parkDriverCollisionPatch']['path']==PARK_PATH
                assert manifest['parkDriverCollisionPatch']['sha256']==PARK_SHA256
                current_park=canonical(git('show',f'{OVERTAKE_PARENT}:{path}'))
                assert digest(current_park)==PARK_SHA256, 'Park collision-only source must match exact reviewed approval'
                allowed.append(current_park)
            if path==VFX_PATH:
                assert manifest['speedV2Phase1Patch']['path']==VFX_PATH
                assert manifest['speedV2Phase1Patch']['sha256']==VFX_SHA256
                current_vfx=canonical((ROOT/path).read_bytes())
                assert digest(current_vfx)==VFX_SHA256, 'V3.2 must match owner-accepted exact QA source'
                allowed.append(current_vfx)
            if path in VFX_OPT_HASHES:
                assert manifest['vfxOptimizationPatches'][path]==VFX_OPT_HASHES[path]
                current_opt=canonical((ROOT/path).read_bytes())
                assert digest(current_opt)==VFX_OPT_HASHES[path], f'VFX optimization source must match exact hash: {path}'
                allowed.append(current_opt)
            if path==FOV_PATH:
                candidate=original
                for before,after in FOV_CHANGES:
                    assert candidate.count(before.encode())==1
                    candidate=candidate.replace(before.encode(),after.encode(),1)
                assert digest(candidate)==manifest['fovPhase1']['sha256'], 'FOV approval hash must match exact substitutions'
                allowed.append(candidate)
            for r3 in (manifest.get('ownerR3PolicyPatch'),manifest.get('ownerR3DisplayPatch')):
              if r3 and path in ('src/server/RaceRecordOperations.luau','src/shared/TrackCatalog.luau') and path==r3['path']:
                assert original.count(r3['before'].encode())==1
                candidate=original.replace(r3['before'].encode(),r3['after'].encode(),1)
                assert digest(candidate)==r3['sha256'], 'R3 exact approved eligibility-guard hunk'
                allowed.append(candidate)
            if path in PARK_OVERTAKE_HASHES:
                overtake_source=canonical(git('show',f'{FOLLOWUP_PARENT}:{path}'))
                assert digest(overtake_source)==PARK_OVERTAKE_HASHES[path], f'Unrecognized Park overtake source: {path}'
                allowed.append(overtake_source)
            if path in FOLLOWUP_HASHES:
                followup=canonical((ROOT/path).read_bytes())
                assert digest(followup)==FOLLOWUP_HASHES[path],f'Unrecognized follow-up: {path}'
                allowed.append(followup)
            assert canonical((ROOT/path).read_bytes()) in allowed, f'Unrecognized working source: {path}'
        assert manifest['parkOvertakePatches']==PARK_OVERTAKE_HASHES, 'Exact reviewed overtake file set/hash contract'
        for path, expected in PARK_OVERTAKE_HASHES.items():
            assert digest(canonical(git('show',f'{FOLLOWUP_PARENT}:{path}')))==expected, f'Unrecognized historical overtake source: {path}'
        assert manifest['parkItemsKioskPatches']==FOLLOWUP_HASHES
        for path, expected in FOLLOWUP_HASHES.items():
            assert digest(canonical((ROOT/path).read_bytes()))==expected,f'Unrecognized follow-up source: {path}'
        for path, expected in manifest['historicalArtifacts'].items():
            assert digest(canonical((ROOT/path).read_bytes()))==expected==digest(canonical(git('show',f'{APPROVED}:{path}'))),path
        print(f"PASS: {len(required)} manifest entries independently match approved Git objects; historical artifacts unchanged; {len(PARK_OVERTAKE_HASHES)} exact Park overtake source pins verified")
