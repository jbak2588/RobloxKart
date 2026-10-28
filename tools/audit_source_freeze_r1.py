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
            category = ('OWNER_VFX_V3_2' if path == VFX_PATH and digest(canonical(current)) == VFX_SHA256
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
            if path==VFX_PATH:
                assert manifest['speedV2Phase1Patch']['path']==VFX_PATH
                assert manifest['speedV2Phase1Patch']['sha256']==VFX_SHA256
                current_vfx=canonical((ROOT/path).read_bytes())
                assert digest(current_vfx)==VFX_SHA256, 'V3.2 must match owner-accepted exact QA source'
                allowed.append(current_vfx)
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
            assert canonical((ROOT/path).read_bytes()) in allowed, f'Unrecognized working source: {path}'
        for path, expected in manifest['historicalArtifacts'].items():
            assert digest(canonical((ROOT/path).read_bytes()))==expected==digest(canonical(git('show',f'{APPROVED}:{path}'))),path
        print(f"PASS: {len(required)} manifest entries independently match approved Git objects; historical artifacts unchanged")
