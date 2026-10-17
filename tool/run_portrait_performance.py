"""Lock portrait for update/feed comparisons and restore rotation even on failure."""

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time

from android_display_state import capture_portrait

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCENARIOS = ('parentRebuild', 'localUpdate', 'complexParentRebuild')
DEFAULT_SCENARIOS = ('parentRebuild', 'localUpdate')


def adb(device, *args):
    return subprocess.check_output(['adb', '-s', device, *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('device')
    parser.add_argument('--isolate-paint', action='store_true')
    parser.add_argument('--diagnostics', action='store_true')
    parser.add_argument('--updates-only', action='store_true')
    parser.add_argument('--rounds', type=int, default=3)
    parser.add_argument('--scenarios', nargs='+', choices=SCENARIOS,
                        default=list(DEFAULT_SCENARIOS),
                        help='Update scenarios; complexParentRebuild is opt-in')
    args = parser.parse_args()
    if args.rounds < 1:
        parser.error('--rounds must be positive')
    device = args.device
    directory = ROOT / 'build' / f'portrait-performance-{dt.datetime.now():%Y%m%d%H%M%S}'
    directory.mkdir(parents=True)
    original = {key: adb(device, 'shell', 'settings', 'get', 'system', key)
                for key in ('accelerometer_rotation', 'user_rotation')}
    report = {'device': device, 'result': 'incomplete', 'originalRotationSettings': original,
              'diagnostics': args.diagnostics, 'updatesOnly': args.updates_only,
              'isolatePaint': args.isolate_paint, 'requestedScenarios': args.scenarios}
    paths = sorted(set(list(ROOT.glob('lib/**/*.dart'))
                       + list(ROOT.glob('demo/lib/**/*.dart'))
                       + list(ROOT.glob('tool/*performance*'))
                       + [ROOT / 'tool/android_display_state.py', ROOT / 'demo/pubspec.lock']))
    manifest = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in paths if p.is_file()}
    (directory / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Portrait reports: {directory}', flush=True)
    try:
        adb(device, 'shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
        adb(device, 'shell', 'settings', 'put', 'system', 'user_rotation', '0')
        for attempt in range(10):
            time.sleep(0.5)
            try:
                report['displayBefore'] = capture_portrait(device, directory / 'display-before.txt')
                break
            except RuntimeError:
                if attempt == 9:
                    raise
        before = set((ROOT / 'build').glob('update-benchmark-*'))
        update_command = [sys.executable, str(ROOT / 'tool/compare_update_performance.py'),
                          device, '--rounds', str(args.rounds), '--require-portrait']
        if args.isolate_paint:
            update_command += ['--isolate-paint']
        scenarios = (['parentRebuild'] if args.diagnostics and
                     args.scenarios == list(DEFAULT_SCENARIOS) else args.scenarios)
        update_command += ['--scenarios', *scenarios]
        if args.diagnostics:
            update_command += ['--diagnostics', '--variants',
                               'designConst', 'screenUtilOptimized']
        subprocess.run(update_command, cwd=ROOT, check=True)
        added = set((ROOT / 'build').glob('update-benchmark-*')) - before
        if len(added) != 1:
            raise RuntimeError('Cannot identify update report directory')
        report['updateDirectory'] = str(added.pop().relative_to(ROOT))
        if not args.updates_only:
            env = dict(os.environ, PERF_REQUIRE_PORTRAIT='1')
            with (directory / 'mixed-feed-run.log').open('w') as log:
                print('Running mixed feed: 3 rounds / 2 engines', flush=True)
                subprocess.run(['zsh', 'tool/compare_mixed_feed_performance.sh', device],
                               cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
            feed = directory / 'mixed-feed'
            feed.mkdir()
            files = list((ROOT / 'build/performance').glob(f'{device}_*_mixed_feed_round*'))
            for file in files:
                shutil.copy2(file, feed / file.name)
            for file in feed.glob('*_display-*.txt'):
                # Snapshots were already validated by the per-case helper.
                raw = file.read_text()
                if 'mOverrideDisplayInfo=DisplayInfo{' not in raw:
                    raise RuntimeError(f'Missing effective display state: {file}')
        report['displayAfter'] = capture_portrait(device, directory / 'display-after.txt')
        report['result'] = 'complete'
        if not args.updates_only:
            print('\n'.join((directory / 'mixed-feed-run.log').read_text().splitlines()[-5:]), flush=True)
    finally:
        restoration = {}
        for key, value in original.items():
            try:
                if value == 'null':
                    adb(device, 'shell', 'settings', 'delete', 'system', key)
                else:
                    adb(device, 'shell', 'settings', 'put', 'system', key, value)
                restoration[key] = adb(device, 'shell', 'settings', 'get', 'system', key) == value
            except Exception as error:
                restoration[key] = str(error)
        report['rotationRestored'] = restoration
        (directory / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(f'Rotation restored: {restoration}', flush=True)
        if not all(value is True for value in restoration.values()):
            raise RuntimeError('Rotation settings restoration failed')


if __name__ == '__main__':
    main()
