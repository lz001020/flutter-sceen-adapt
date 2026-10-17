#!/usr/bin/env python3
"""Run debug core checks on booted iOS simulators; injected input, not native UI."""
import argparse
import datetime
import json
import pathlib
import queue
import subprocess
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
MARKER = '[screen_adapt:ios] '


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('devices', nargs='+')
    args = parser.parse_args()
    stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    output = ROOT / 'build' / ('ios-simulator-' + stamp)
    output.mkdir(parents=True)
    reports = []
    print('Reports:', output, flush=True)
    try:
        for device in args.devices:
            for scenario in ['core', 'conflict']:
                run = stamp + '-' + device + '-' + scenario
                report = {'device': device, 'scenario': scenario, 'run': run,
                          'mode': 'debug', 'result': 'failed', 'checks': []}
                reports.append(report)
                command = ['flutter', 'run', '-d', device, '--debug', '--no-pub',
                           '--target=../tool/ios_simulator_regression.dart',
                           '--dart-define=REGRESSION_RUN=' + run,
                           '--dart-define=REGRESSION_CONFLICT=' +
                           ('true' if scenario == 'conflict' else 'false')]
                process = subprocess.Popen(command, cwd=ROOT / 'demo',
                                           stdout=subprocess.PIPE,
                                           stderr=subprocess.STDOUT,
                                           stdin=subprocess.PIPE, text=True,
                                           bufsize=1)
                lines = queue.Queue()

                def read_lines(stream, destination):
                    for line in stream:
                        destination.put(line)
                    destination.put(None)

                reader = threading.Thread(target=read_lines,
                                          args=(process.stdout, lines), daemon=True)
                reader.start()
                try:
                    deadline = time.monotonic() + 300
                    with (output / (device + '-' + scenario + '.log')).open('w') as log:
                        while time.monotonic() < deadline:
                            try:
                                line = lines.get(timeout=1)
                            except queue.Empty:
                                continue
                            if line is None:
                                raise RuntimeError('Flutter exited without a completion event')
                            log.write(line)
                            log.flush()
                            if MARKER not in line:
                                continue
                            event = json.loads(line.split(MARKER, 1)[1])
                            if event['run'] != run:
                                continue
                            if event['type'] == 'check':
                                report['checks'].append(event['name'])
                            elif event['type'] == 'failure':
                                raise RuntimeError(event['error'])
                            elif event['type'] == 'done':
                                report['checks'] = event['checks']
                                report['result'] = 'passed'
                                print(f"PASS {device} {scenario}: {len(report['checks'])} checks",
                                      flush=True)
                                break
                        else:
                            raise TimeoutError('No completion event in 300 seconds')
                except BaseException as error:
                    report['error'] = str(error)
                    raise
                finally:
                    if process.poll() is None:
                        try:
                            process.stdin.write('q\n')
                            process.stdin.flush()
                            process.wait(timeout=15)
                        except (OSError, subprocess.TimeoutExpired):
                            process.terminate()
                            try:
                                process.wait(timeout=10)
                            except subprocess.TimeoutExpired:
                                process.kill()
                                process.wait()
    finally:
        (output / 'report.json').write_text(json.dumps(reports, indent=2) + '\n')


if __name__ == '__main__':
    main()
