"""Read-only classification of an exported KDM_PlayerProgress_v1 backup.
Never deletes or edits Roblox data. Empty historical profiles are ambiguous:
old Test Drive use was not recorded, so default cash alone is not deletion proof.
Usage: python audit_inactive_profiles.py backup.json report.json
"""
import argparse
import collections
import json
from pathlib import Path


def classify(key, profile):
    if not isinstance(profile, dict) or profile.get('schemaVersion') != 1:
        return 'PRESERVE_UNRECOGNIZED'
    if key != 'u:' + str(profile.get('userId')) or profile.get('deleted'):
        return 'PRESERVE_KEY_OR_DELETION_STATE'
    if profile.get('activity'):
        return 'PRESERVE_QUALIFIED_ACTIVITY'
    records = profile.get('records')
    if not isinstance(records, dict):
        return 'PRESERVE_UNRECOGNIZED'
    if any(records.values()) or profile.get('pendingIndex') or profile.get('pendingRaceIndex'):
        return 'PRESERVE_RACE_OR_PROGRESS'
    for field in ('cosmetics', 'wallet', 'selection'):
        if not isinstance(profile.get(field), dict):
            return 'PRESERVE_UNRECOGNIZED'
    if any(profile.get('daily', {}).values()):
        return 'PRESERVE_OTHER_REWARDS'
    cosmetics = profile.get('cosmetics', {})
    if cosmetics.get('ownedPartIds') or cosmetics.get('equippedPartIdsBySlot'):
        return 'PRESERVE_OWNERSHIP'
    if profile.get('receipts') or profile.get('purchaseHistory') or profile.get('inventory') or profile.get('shopInventory'):
        return 'PRESERVE_TRANSACTION_OR_INVENTORY'
    wallet = profile.get('wallet', {})
    if wallet.get('cash') != 5000 or wallet.get('ledgerRevision') != 0 or wallet.get('lifetimeEarned', 0) != 0:
        return 'PRESERVE_WALLET_ACTIVITY'
    selection = profile.get('selection', {})
    if selection.get('revision') != 0 or selection.get('lastOpId'):
        return 'PRESERVE_SELECTION_ACTIVITY'
    return 'REVIEW_AMBIGUOUS_NO_TEST_DRIVE_HISTORY'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('backup', type=Path)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    data = json.loads(args.backup.read_text(encoding='utf-8-sig'))
    entries = data.items() if isinstance(data, dict) else ((row['key'], row['value']) for row in data)
    rows = [{'key': key, 'classification': classify(key, value), 'safeToDelete': False} for key, value in entries]
    report = {'readOnly': True, 'safeDeletionCount': 0, 'counts': dict(collections.Counter(row['classification'] for row in rows)), 'entries': rows}
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'readOnly': True, 'safeDeletionCount': 0, 'counts': report['counts']}))


if __name__ == '__main__':
    main()
