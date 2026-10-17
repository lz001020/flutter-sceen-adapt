"""Summarize timeline stage wall times within recorded benchmark frames."""

import argparse
import collections
import json
import pathlib
import statistics


def percentile(values, percent):
    ordered = sorted(values)
    return ordered[int((len(ordered) - 1) * percent / 100 + 0.5)]


def summarize(timeline_path):
    events = json.loads(timeline_path.read_text())['traceEvents']
    frames_path = timeline_path.with_name(timeline_path.name.replace('_timeline', '_frames'))
    frames = json.loads(frames_path.read_text())
    first = min(frame['buildStartUs'] for frame in frames)
    last = max(frame['rasterFinishUs'] for frame in frames)
    stages = collections.defaultdict(list)
    pending = collections.defaultdict(list)
    for event in events:
        name = event.get('name', '')
        key = (event.get('pid'), event.get('tid'), name)
        phase = event.get('ph')
        if phase == 'B':
            pending[key].append(event['ts'])
        elif phase == 'E' and pending[key]:
            start = pending[key].pop()
            if first <= start and event['ts'] <= last:
                stages[name].append(event['ts'] - start)
        elif phase == 'X' and first <= event['ts'] and event['ts'] + event['dur'] <= last:
            stages[name].append(event['dur'])
    names = ('BUILD', 'LAYOUT (root)', 'PAINT (root)', 'COMPOSITING',
             'SEMANTICS (root)', 'GPURasterizer::Draw', 'CollectNewGeneration',
             'CollectOldGeneration')
    result = {'frames': len(frames), 'stages': {}}
    for name in names:
        values = stages[name]
        result['stages'][name] = {
            'count': len(values),
            'p50Us': statistics.median(values) if values else None,
            'p90Us': percentile(values, 90) if values else None,
            'sumUs': sum(values),
        }
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=pathlib.Path)
    args = parser.parse_args()
    paths = sorted(args.directory.glob('*_timeline.json'))
    if not paths:
        parser.error('No timeline reports found')
    summary = {p.stem.removesuffix('_timeline'): summarize(p) for p in paths}
    (args.directory / 'timeline-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    for name, result in summary.items():
        print(name, 'frames=', result['frames'],
              {key: value['p90Us'] for key, value in result['stages'].items()})


if __name__ == '__main__':
    main()
