#!/usr/bin/env python3
"""Release metadata, collision-safe archival, and cache-only clean checks."""
import pathlib
import re
import shutil
import subprocess
import tempfile

src = pathlib.Path(__file__).resolve().parents[2]
script = (src / 'Scripts/package.sh').read_text()
assert "versionName '1.4'" in (src / 'android/app/build.gradle').read_text(), 'Android version must be 1.1'
assert 'versionCode 8' in (src / 'android/app/build.gradle').read_text()
config = (src / 'ios/Config/Shared.xcconfig').read_text()
assert 'MARKETING_VERSION = 1.4\n' in config and 'CURRENT_PROJECT_VERSION = 8\n' in config
assert (src / 'android/app/src/main/assets/app.js').read_text().count('<small>1.4</small>') == 2
assert 'local dd="$SRC/ios/DerivedData"' in script
assert '/Users/y/toolchains/bin/xcodebuild' in script and 'KUMONE_TEAM_ID' in script
assert 'mktemp -d "$ROOT/.cache/' in script
archive = re.search(r'^archive_old\(\).*?^}', script, re.M | re.S).group()
with tempfile.TemporaryDirectory(dir=src.parent / '.cache') as temporary:
    root = pathlib.Path(temporary)
    latest = root / 'build/latest'
    history = root / 'build/history'
    latest.mkdir(parents=True)
    history.mkdir()
    (latest / 'Antunes-1.0.apk').write_text('old-apk')
    (latest / 'Antunes-1.0.ipa').write_text('keep-ios')
    (history / 'Antunes-1.0.apk').write_text('keep-history')
    body = f'LATEST="{latest}"\nHISTORY="{history}"\n' + archive + '\narchive_old apk\n'
    subprocess.run(['bash', '-euc', body], check=True)
    (latest / 'Antunes-1.0.apk').write_text('old-again')
    subprocess.run(['bash', '-euc', body], check=True)
    assert not (latest / 'Antunes-1.0.apk').exists()
    assert (latest / 'Antunes-1.0.ipa').read_text() == 'keep-ios'
    assert sorted(p.read_text() for p in history.rglob('*.apk')) == ['keep-history', 'old-again', 'old-apk']
    fixture_src = root / 'src'
    (fixture_src / 'Scripts').mkdir(parents=True)
    shutil.copy2(src / 'Scripts/package.sh', fixture_src / 'Scripts/package.sh')
    (fixture_src / 'must-keep').write_text('source-cache')
    (root / '.cache/nested').mkdir(parents=True)
    (root / '.cache/nested/log').write_text('disposable')
    subprocess.run(['bash', str(fixture_src / 'Scripts/package.sh'), 'clean'], check=True)
    assert list((root / '.cache').iterdir()) == []
    assert (fixture_src / 'must-keep').read_text() == 'source-cache'
    assert (latest / 'Antunes-1.0.ipa').read_text() == 'keep-ios'
print('PASS: 1.4 metadata, collision-safe platform archival, cache-only clean')
