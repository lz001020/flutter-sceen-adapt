#!/usr/bin/env python3
"""Build a real-binding app, drive native input, and restore device settings."""
import argparse
import datetime
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
MARKER = '[screen_adapt:regression] '


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('device')
    parser.add_argument('--mode', choices=['profile', 'release'], default='profile')
    args = parser.parse_args()
    run = datetime.datetime.now().strftime('%Y%m%d%H%M%S') + '-' + args.mode
    output = ROOT / 'build' / ('interaction-' + run)
    output.mkdir(parents=True)
    saved = {}
    report = {'run': run, 'mode': args.mode, 'device': args.device,
              'result': 'failed', 'checks': [], 'settings_restored': False}
    completed = False

    def adb(*command):
        return subprocess.check_output(['adb', '-s', args.device, *command],
                                       text=True, timeout=60).strip()

    def setting(key, value):
        adb('shell', 'settings', 'put', 'system', key, str(value))

    try:
        adb('get-state')
        for key in ['accelerometer_rotation', 'user_rotation', 'font_scale']:
            saved[key] = adb('shell', 'settings', 'get', 'system', key)
        report['original_settings'] = saved.copy()
        report['model'] = adb('shell', 'getprop', 'ro.product.model')
        report['android'] = adb('shell', 'getprop', 'ro.build.version.release')
        (output / 'report.json').write_text(json.dumps(report, indent=2))
        setting('accelerometer_rotation', 0)
        setting('user_rotation', 0)
        setting('font_scale', 1.0)
        print(f'Building {args.mode}; reports: {output}', flush=True)
        with (output / 'build.log').open('w') as log:
            subprocess.run(['flutter', 'build', 'apk', '--' + args.mode, '--no-pub',
                            '--target=../tool/android_interaction_regression.dart',
                            '--dart-define=REGRESSION_RUN=' + run], cwd=ROOT / 'demo',
                           stdout=log, stderr=subprocess.STDOUT, check=True,
                           timeout=600)
        adb('shell', 'am', 'force-stop', 'dev.designscale.regression')
        print(adb('install', '-r', str(ROOT / 'demo/build/app/outputs/flutter-apk' /
                                      f'app-{args.mode}.apk')), flush=True)
        adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
        adb('shell', 'wm', 'dismiss-keyguard')
        adb('shell', 'am', 'start', '-W', '-n', 'dev.designscale.regression/.MainActivity')
        # Activity launch completion can precede the window accepting input.
        time.sleep(2)
        handled = set()
        next_window_check = 0.0
        deadline = time.monotonic() + 240
        while time.monotonic() < deadline:
            if time.monotonic() >= next_window_check:
                windows = adb('shell', 'dumpsys', 'window')
                focused = [line.strip() for line in windows.splitlines()
                           if 'mCurrentFocus=' in line]
                if focused and not any('dev.designscale.regression/' in line
                                       for line in focused):
                    raise RuntimeError('Test app lost foreground. Keep the device '
                                       'unlocked and do not switch apps during the run.')
                next_window_check = time.monotonic() + 5
            logs = adb('logcat', '-d', '-v', 'brief', '-s', 'flutter', 'AndroidRuntime')
            (output / 'device.log').write_text(logs)
            for line in logs.splitlines():
                if MARKER not in line:
                    continue
                event = json.loads(line.split(MARKER, 1)[1])
                if event['run'] != run:
                    continue
                if event['type'] == 'check':
                    if event['name'] not in report['checks']:
                        report['checks'].append(event['name'])
                    continue
                if event['type'] == 'failure':
                    raise RuntimeError(event['error'] + '\n' + event.get('stack', ''))
                if event['type'] == 'done':
                    report['checks'] = event['checks']
                    completed = True
                    return
                if event['type'] != 'action' or event['id'] in handled:
                    continue
                handled.add(event['id'])
                action = event['action']
                print(f"Action {event['id']}: {action}; "
                      f"received_ms={int(time.time() * 1000)} "
                      f"emitted_ms={event.get('timeMs')}", flush=True)
                if action == 'tap':
                    adb('shell', 'input', 'tap', str(event['x']), str(event['y']))
                elif action == 'swipe':
                    adb('shell', 'input', 'swipe', *(str(event[k]) for k in
                        ['x1', 'y1', 'x2', 'y2']), '500')
                elif action == 'text':
                    adb('shell', 'input', 'text', event['text'])
                elif action == 'back':
                    adb('shell', 'input', 'keyevent', '4')
                elif action == 'rotation':
                    setting('user_rotation', event['value'])
                elif action == 'font':
                    setting('font_scale', event['value'])
                else:
                    raise RuntimeError('Unknown action: ' + action)
                print(f"Action {event['id']} completed_ms="
                      f"{int(time.time() * 1000)}", flush=True)
            time.sleep(0.15)
        raise TimeoutError('No completion report within 240 seconds.')
    except BaseException as error:
        report['error'] = str(error)
        raise
    finally:
        restore_errors = []
        # Font and orientation are restored even when a check or build fails.
        for key, value in saved.items():
            try:
                if value == 'null':
                    adb('shell', 'settings', 'delete', 'system', key)
                else:
                    setting(key, value)
                if adb('shell', 'settings', 'get', 'system', key) != value:
                    raise RuntimeError('Read-back differs: ' + key)
            except Exception as error:
                restore_errors.append(str(error))
        report['settings_restored'] = bool(saved) and not restore_errors
        report['restore_errors'] = restore_errors
        if completed and report['settings_restored']:
            report['result'] = 'passed'
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print('Settings restored:', report['settings_restored'], flush=True)
        if restore_errors:
            raise RuntimeError('Failed to restore settings: ' + '; '.join(restore_errors))
        if completed:
            print(f"PASS {args.mode}: {len(report['checks'])} checks", flush=True)


if __name__ == '__main__':
    main()
