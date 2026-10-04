#!/usr/bin/env python3
"""Check complete semantic review coverage; never infer hardware necessity."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='fully prepared kernel source')
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    patches = REPO / 'kernel/patches'
    names = []
    for series in ('series', 'post-series'):
        names.extend(line.strip() for line in (patches / series).read_text().splitlines()
                     if line.strip() and not line.lstrip().startswith('#'))
    files = {name.split('-')[0]: patches / name for name in names}
    if len(files) != len(names):
        raise SystemExit('duplicate patch ID')
    reviews = json.loads((patches / 'functional-expectations.json').read_text())
    ids = [entry['id'] for entry in reviews]
    if len(ids) != len(set(ids)) or set(ids) != set(files):
        raise SystemExit(f'coverage mismatch: missing={set(files)-set(ids)}, stale={set(ids)-set(files)}')
    observed = {}
    for path in sorted(args.evidence.glob('*/function-results.json')):
        for function, result in json.loads(path.read_text()).items():
            observed.setdefault(function, []).append((path.parent.name, result))
    rows = []
    for review in reviews:
        source = args.source / review['source_file']
        content = source.read_text()
        if review['anchor'] not in content:
            raise SystemExit(f"missing source anchor: {review['id']}")
        line = content[:content.index(review['anchor'])].count('\n') + 1
        for component in review.get('components', []):
            component_source = args.source / component['source_file']
            if component['anchor'] not in component_source.read_text():
                raise SystemExit(f"missing component anchor: {component['id']}")
        calls = []
        for function in review['live_functions']:
            results = observed.get(function, [])
            if not results:
                calls.append(function + ':NOT_MEASURED')
            for capture, result in results:
                calls.append(f"{capture}:{function}:{result['state']}:{result.get('hits', 0)}")
        rows.append({
            'id': review['id'], 'patch_or_transform': str(files[review['id']].relative_to(REPO)),
            'sha256': sha(files[review['id']]), 'review': 'SOURCE_REVIEWED',
            'kind': review['kind'], 'effect': review['effect'],
            'source': f"{review['source_file']}:{line}", 'source_sha256': sha(source),
            'execution_gate': review['execution_gate'],
            'live_function_evidence': '; '.join(calls) or 'NOT_MEASURED_OR_INTERFACE_ONLY',
            'necessity_limit': review['limit'],
        })
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('w', newline='') as out:
        writer = csv.DictWriter(out, fieldnames=rows[0].keys(), delimiter='\t', lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)
    print(f'Coverage verified: {len(names)} subsystem patches; all component anchors verified.')


if __name__ == '__main__':
    main()
