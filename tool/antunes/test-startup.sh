#!/bin/bash
set -euo pipefail
source /Users/y/toolchains/env.sh
ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
EXPECTED="${2:-direct}"
CACHE="${KUMONE_TEST_CACHE:-$(dirname "$ROOT")/.cache/startup-tests}"
mkdir -p "$CACHE"
python3 - "$ROOT" "$EXPECTED" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1]);expected=sys.argv[2]
ios=(r/'Sources/Kumone/Features/IOSMainWindow.swift').read_text()
android=(r/'android/app/src/main/assets/app.js').read_text()
api=(r'android/app/src/main/java/com/antunes/app/MusicApi.java').read_text()
if expected=='gate':
 assert 'UpstreamGate { gatedBody }' in ios
 assert 'if(!status.configured){setupPage();return;}' in android
 assert '先做两道算术题' in android
 print('BASELINE: iOS=verification-gate; Android=verification-gate; exit=0')
else:
 assert 'UpstreamGate' not in ios
 assert not (r/'Sources/Kumone/Features/Pages/UpstreamSetupView.swift').exists()
 assert 'setupPage' not in android and '开始之前' not in android and 'status.configured' not in android
 assert 'boolean configured()' not in api and 'void configure(' not in api
 print('MODIFIED: iOS=direct-home; Android=direct-home; exit=0')
PY
if [[ "$EXPECTED" == direct ]]; then
  cat > "$CACHE/main.swift" <<'SWIFT'
import Foundation
let key = "upstream.hosts"
let previous = UserDefaults.standard.data(forKey: key)
UserDefaults.standard.removeObject(forKey: key)
defer {
    if let previous { UserDefaults.standard.set(previous, forKey: key) }
    else { UserDefaults.standard.removeObject(forKey: key) }
}
precondition(Upstream.isConfigured)
precondition(Upstream.webHost == "music.163.com")
precondition(Upstream.interfaceHost == "interface.music.163.com")
precondition(Upstream.cdnSuffix == ".music.126.net")
Upstream.reset()
precondition(Upstream.isConfigured)
print("SWIFT: fresh-install=direct-home; reset=direct-home; endpoints=valid; exit=0")
SWIFT
  /Users/y/toolchains/bin/xcrun swiftc "$ROOT/Sources/Kumone/Core/API/Upstream.swift" "$CACHE/main.swift" -o "$CACHE/startup-test"
  "$CACHE/startup-test"
fi
