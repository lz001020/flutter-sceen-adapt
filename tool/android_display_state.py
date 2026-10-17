"""Record effective Android display state; never infer rotation from panel size."""

import argparse
import json
import pathlib
import re
import subprocess


def capture_portrait(device, output):
    raw = subprocess.check_output(
        ['adb', '-s', device, 'shell', 'dumpsys', 'display'], text=True)
    pathlib.Path(output).write_text(raw)
    lines = [line for line in raw.splitlines()
             if 'mOverrideDisplayInfo=DisplayInfo{' in line and 'displayId 0,' in line]
    if len(lines) != 1:
        raise RuntimeError('Cannot identify effective display 0 override')
    line = lines[0]
    rotation = re.search(r'\brotation (\d+)', line)
    size = re.search(r'\breal (\d+) x (\d+)', line)
    app = re.search(r', app (\d+) x (\d+)', line)
    if not rotation or not size or not app:
        raise RuntimeError('Incomplete effective display information')
    state = {'rotation': int(rotation[1]), 'width': int(size[1]),
             'height': int(size[2]), 'appWidth': int(app[1]),
             'appHeight': int(app[2])}
    if state['rotation'] != 0 or state['width'] >= state['height']:
        raise RuntimeError(f'Expected rotation 0 portrait: {state}')
    return state


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('device')
    parser.add_argument('output')
    args = parser.parse_args()
    print(json.dumps(capture_portrait(args.device, args.output)))
