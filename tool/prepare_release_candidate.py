#!/usr/bin/env python3
"""Copy current non-ignored sources into an isolated local release candidate.

Does not change the original Git index, commit history, or remote.
The manifest is outside the candidate to avoid self-referential hashes.
"""
import datetime
import hashlib
import json
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main():
    stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    output = ROOT / 'build' / ('release-candidate-' + stamp)
    candidate = output / 'source'
    candidate.mkdir(parents=True)
    raw = subprocess.check_output(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
        cwd=ROOT)
    manifest = {}
    for name in sorted(set(raw.decode().split('\0')) - {''}):
        source = ROOT / name
        if not source.exists():
            continue
        ignored = subprocess.run(
            ['git', 'check-ignore', '--no-index', '-q', '--', name], cwd=ROOT)
        if ignored.returncode == 0:
            continue
        if ignored.returncode != 1:
            raise RuntimeError('git check-ignore failed: ' + name)
        if source.is_symlink() or not source.is_file():
            raise RuntimeError('Review non-regular file before packaging: ' + name)
        destination = candidate / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if hashlib.sha256(destination.read_bytes()).hexdigest() != digest:
            raise RuntimeError('Snapshot verification failed: ' + name)
        manifest[name] = digest
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    subprocess.run(['git', 'init', '-q'], cwd=candidate, check=True)
    subprocess.run(['git', 'add', '--all'], cwd=candidate, check=True)
    subprocess.run(['git', '-c', 'user.name=Release validation', '-c',
                    'user.email=validation@localhost', 'commit', '-q', '-m',
                    'build(release): 创建本地发布验收快照'], cwd=candidate, check=True)
    print(candidate, flush=True)


if __name__ == '__main__':
    main()
