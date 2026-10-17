#!/usr/bin/env python3
"""Compare equal-update workloads on one Android device in Profile mode."""

import argparse
import datetime as dt
import json
import pathlib
import re
import statistics
import subprocess
import time
import urllib.parse
import urllib.request

from android_display_state import capture_portrait

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEMO = ROOT / 'demo'
APK = DEMO / 'build/app/outputs/flutter-apk/app-profile.apk'
PACKAGE = 'dev.designscale.regression'
COMPONENT = f'{PACKAGE}/{PACKAGE}.MainActivity'
MARKER = '[demo:update_benchmark] '
VARIANTS = ('designConst', 'designDynamic',
            'screenUtilOptimized', 'screenUtilInline')
SCENARIOS = ('parentRebuild', 'localUpdate', 'complexParentRebuild')
DEFAULT_SCENARIOS = ('parentRebuild', 'localUpdate')
COMPLEX_CARD_COUNT = 12


def command(*args, cwd=None, timeout=180, output=None):
    result = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=timeout)
    if output is not None:
        output.write_text(result.stdout)
    if result.returncode:
        raise RuntimeError(f'{" ".join(args)} exited {result.returncode}: '
                           f'{result.stdout[-1200:]}')
    return result.stdout


def adb(device, *args, **kwargs):
    return command('adb', '-s', device, *args, **kwargs)


def validate_counts(result):
    steps = result['updates']
    optimized = result['variant'] in ('designConst', 'screenUtilOptimized')
    if result['scenario'] == 'complexParentRebuild':
        expected = {
            'grid': 0,
            'card': 0,
            'details': 0,
            'price': 0,
            'complexFeed': 0 if optimized else steps,
            'complexCard': 0 if optimized else steps * COMPLEX_CARD_COUNT,
        }
    elif result['scenario'] == 'parentRebuild':
        expected = {'grid': 0 if optimized else steps,
                    'card': 0 if optimized else steps * 8,
                    'details': 0 if optimized else steps * 8,
                    'price': 0 if optimized else steps * 8,
                    'complexFeed': 0,
                    'complexCard': 0}
    else:
        expected = {'grid': 0, 'card': 0,
                    'details': 0 if optimized else steps, 'price': steps,
                    'complexFeed': 0,
                    'complexCard': 0}
    for key, value in expected.items():
        if result[key] != value:
            raise RuntimeError(f'build count mismatch: {result["variant"]} '
                               f'{result["scenario"]} {key}={result[key]} '
                               f'(expected {value})')


def vm_call(url, method, **params):
    query = urllib.parse.urlencode({key: '[' + ','.join(value) + ']' if isinstance(value, list)
                                   else value for key, value in params.items()})
    with urllib.request.urlopen(url + method + '?' + query, timeout=10) as response:
        payload = json.load(response)
    if 'error' in payload:
        raise RuntimeError(f'VM service {method}: {payload["error"]}')
    return payload.get('result', payload)


def run_case(device, directory, round_number, scenario, variant,
             require_portrait=False, diagnostics=False, isolate_paint=False):
    name = f'r{round_number}_{scenario}_{variant}'
    build_log = directory / f'{name}_build.log'
    raw_log = directory / f'{name}_device.log'
    command('flutter', 'build', 'apk', '--profile',
            '--target=lib/performance/update_benchmark_main.dart',
            f'--dart-define=PERF_VARIANT={variant}',
            f'--dart-define=PERF_SCENARIO={scenario}',
            f'--dart-define=PERF_DIAGNOSTICS={str(diagnostics).lower()}',
            f'--dart-define=PERF_ISOLATE_PAINT={str(isolate_paint).lower()}',
            cwd=DEMO, timeout=600, output=build_log)
    adb(device, 'install', '-r', str(APK), timeout=120)
    adb(device, 'shell', 'am', 'force-stop', PACKAGE)
    adb(device, 'logcat', '-c')
    display_before = None
    if require_portrait:
        display_before = capture_portrait(device, directory / f'{name}_display-before.txt')
    adb(device, 'shell', 'am', 'start', '-n', COMPONENT)
    deadline = time.monotonic() + 45
    service_url = None
    forwarded_port = None
    try:
        while time.monotonic() < deadline:
            logs = adb(device, 'logcat', '-d', '-s', 'flutter', timeout=30)
            raw_log.write_text(logs)
            if diagnostics and service_url is None:
                match = re.search(r'VM service is listening on http://127\.0\.0\.1:(\d+)(/\S*/)', logs)
                if match:
                    forwarded_port = adb(device, 'forward', 'tcp:0', f'tcp:{match[1]}').strip()
                    service_url = f'http://127.0.0.1:{forwarded_port}{match[2]}'
                    vm_call(service_url, 'setVMTimelineFlags', recordedStreams=['Dart', 'Embedder', 'GC'])
                    vm_call(service_url, 'clearVMTimeline')
            if 'error=insufficientFrames' in logs or 'Unhandled Exception' in logs:
                raise RuntimeError(f'benchmark failed: {raw_log}')
            results = [json.loads(line.split(MARKER, 1)[1])
                       for line in logs.splitlines()
                       if MARKER in line and line.split(MARKER, 1)[1].startswith('{')]
            if results:
                result = results[-1]
                if result['variant'] != variant or result['scenario'] != scenario:
                    raise RuntimeError(f'wrong run in {raw_log}')
                validate_counts(result)
                if diagnostics:
                    if service_url is None:
                        raise RuntimeError('Diagnostic run did not expose a VM service')
                    timeline = vm_call(service_url, 'getVMTimeline')
                    (directory / f'{name}_timeline.json').write_text(json.dumps(timeline) + '\n')
                    # debugPrint deliberately throttles large output batches.
                    flush_deadline = time.monotonic() + 15
                    frames = []
                    while time.monotonic() < flush_deadline:
                        logs = adb(device, 'logcat', '-d', '-s', 'flutter', timeout=30)
                        raw_log.write_text(logs)
                        frames = [json.loads(line.split('[demo:update_frame] ', 1)[1])
                                  for line in logs.splitlines() if '[demo:update_frame] ' in line]
                        if len(frames) == result['frames']:
                            break
                        time.sleep(0.5)
                    if len(frames) != result['frames']:
                        raise RuntimeError(f'Incomplete raw frame diagnostics: {len(frames)}')
                    (directory / f'{name}_frames.json').write_text(json.dumps(frames) + '\n')
                if require_portrait:
                    display_after = capture_portrait(device, directory / f'{name}_display-after.txt')
                    if display_before != display_after:
                        raise RuntimeError(f'Display changed in {name}')
                    result['displayBefore'] = display_before
                    result['displayAfter'] = display_after
                return result
            time.sleep(0.5)
        raise TimeoutError(f'benchmark did not finish: {raw_log}')
    finally:
        if forwarded_port is not None:
            adb(device, 'forward', '--remove', f'tcp:{forwarded_port}')



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('device', help='ADB device serial')
    parser.add_argument('--rounds', type=int, default=3)
    parser.add_argument('--require-portrait', action='store_true',
                        help='Fail unless each case starts and ends in portrait; lock rotation externally')
    parser.add_argument('--isolate-paint', action='store_true')
    parser.add_argument('--diagnostics', action='store_true', help='Capture VM timeline and raw FrameTiming')
    parser.add_argument('--scenarios', nargs='+', choices=SCENARIOS,
                        default=list(DEFAULT_SCENARIOS))
    parser.add_argument('--variants', nargs='+', choices=VARIANTS, default=list(VARIANTS))
    args = parser.parse_args()
    if args.rounds < 1:
        parser.error('--rounds must be positive')
    adb(args.device, 'get-state')
    timestamp = dt.datetime.now().strftime('%Y%m%d%H%M%S')
    directory = ROOT / 'build' / f'update-benchmark-{timestamp}'
    directory.mkdir(parents=True)
    info = {}
    for name, prop in [('model', 'ro.product.model'),
                       ('soc', 'ro.soc.model'),
                       ('android', 'ro.build.version.release')]:
        info[name] = adb(args.device, 'shell', 'getprop', prop).strip()
    info['size'] = adb(args.device, 'shell', 'wm', 'size').strip()
    info['density'] = adb(args.device, 'shell', 'wm', 'density').strip()
    (directory / 'display-before.txt').write_text(
        adb(args.device, 'shell', 'dumpsys', 'display'))
    (directory / 'thermal-before.txt').write_text(
        adb(args.device, 'shell', 'dumpsys', 'thermalservice'))
    report = {'device': args.device, 'info': info, 'mode': 'profile',
              'result': 'incomplete',
              'requirePortrait': args.require_portrait,
              'diagnostics': args.diagnostics,
              'isolatePaint': args.isolate_paint,
              'roundsRequested': args.rounds, 'cases': [], 'medians': {}}
    print(f'Reports: {directory}', flush=True)
    try:
        for round_number in range(1, args.rounds + 1):
            scenarios = args.scenarios if round_number % 2 else reversed(args.scenarios)
            for scenario in scenarios:
                variants = args.variants if round_number % 2 else reversed(args.variants)
                for variant in variants:
                    print(f'Round {round_number}: {scenario} / {variant}', flush=True)
                    result = run_case(args.device, directory, round_number,
                                      scenario, variant, args.require_portrait, args.diagnostics, args.isolate_paint)
                    result['round'] = round_number
                    report['cases'].append(result)
                    (directory / 'report.json').write_text(
                        json.dumps(report, ensure_ascii=False, indent=2) + '\n')
                    workload_builds = (
                        result['complexCard']
                        if scenario == 'complexParentRebuild'
                        else result['details']
                    )
                    workload_label = (
                        'complex card builds'
                        if scenario == 'complexParentRebuild'
                        else 'detail builds'
                    )
                    print(f'  UI p90 {result["uiP90Us"]}us, '
                          f'total p90 {result["totalP90Us"]}us, '
                          f'{workload_label} {workload_builds}', flush=True)
        for scenario in args.scenarios:
            report['medians'][scenario] = {}
            for variant in args.variants:
                rows = [r for r in report['cases']
                        if r['scenario'] == scenario and r['variant'] == variant]
                report['medians'][scenario][variant] = {
                    key: statistics.median(r[key] for r in rows)
                    for key in ('frames', 'uiP90Us', 'uiP99Us', 'rasterP90Us',
                                'totalP90Us', 'totalP99Us', 'over16667Us',
                    'grid', 'card', 'details', 'price', 'complexFeed',
                    'complexCard', 'vsyncP90Us', 'gapP90Us')}
        report['result'] = 'complete'
    finally:
        (directory / 'display-after.txt').write_text(
            adb(args.device, 'shell', 'dumpsys', 'display'))
        (directory / 'thermal-after.txt').write_text(
            adb(args.device, 'shell', 'dumpsys', 'thermalservice'))
        (directory / 'report.json').write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
