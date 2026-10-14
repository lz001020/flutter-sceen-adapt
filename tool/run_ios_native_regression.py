#!/usr/bin/env python3
"""Run XCUITest native clicks, keyboard input and rotation on iOS simulators."""
import argparse
import base64
import datetime
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('devices', nargs='+')
    args = parser.parse_args()
    stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    output = ROOT / 'build' / ('ios-native-' + stamp)
    output.mkdir(parents=True)
    reports = []
    print('Reports:', output, flush=True)
    try:
        for device in args.devices:
            run = stamp + '-' + device
            report = {'device': device, 'run': run, 'mode': 'debug',
                      'result': 'failed', 'driver': 'XCUITest'}
            reports.append(report)
            defines = ','.join(base64.b64encode(value.encode()).decode() for value in
                               ['REGRESSION_RUN=' + run, 'IOS_NATIVE_REGRESSION=true'])
            command = ['xcodebuild', '-workspace', 'Runner.xcworkspace',
                       '-scheme', 'Runner', '-configuration', 'Debug',
                       '-destination', 'platform=iOS Simulator,id=' + device,
                       '-parallel-testing-enabled', 'NO',
                       '-collect-test-diagnostics', 'never',
                       '-only-testing:RunnerTests/RunnerTests/testNativeInteractionRegression',
                       '-resultBundlePath', str(output / (device + '.xcresult')),
                       '-derivedDataPath', str(ROOT / 'build/ios-native-derived'),
                       'ARCHS=arm64', 'ONLY_ACTIVE_ARCH=YES', 'CODE_SIGNING_ALLOWED=NO',
                       'FLUTTER_TARGET=' + str(ROOT / 'tool/android_interaction_regression.dart'),
                       'DART_DEFINES=' + defines, 'test']
            print('Testing:', device, flush=True)
            try:
                with (output / (device + '.log')).open('w') as log:
                    subprocess.run(command, cwd=ROOT / 'example/ios',
                                   stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=900)
                report['result'] = 'passed'
                report['checks'] = 17
                print('PASS native:', device, flush=True)
            except BaseException as error:
                report['error'] = str(error)
                raise
    finally:
        (output / 'report.json').write_text(json.dumps(reports, indent=2) + '\n')


if __name__ == '__main__':
    main()
