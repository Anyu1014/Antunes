#!/bin/sh
# 模拟器热更新：把 web 资源推入设备 files/hot/，再刷新 WebView。不重装、不清数据。
#   ./hot.sh            推 app.js app.css core.mjs index.html
#   ./hot.sh app.js     只推一个
set -e
ADB="${ADB:-/Users/y/toolchains/bin/adb}"
PKG=com.antunes.app
HERE=$(cd "$(dirname "$0")" && pwd)
ASSETS="$HERE/../../android/app/src/main/assets"
FILES="${*:-app.js app.css core.mjs index.html}"
"$ADB" shell run-as "$PKG" mkdir -p files/hot
for f in $FILES; do
  "$ADB" push "$ASSETS/$f" "/data/local/tmp/hot_upload" >/dev/null
  "$ADB" shell run-as "$PKG" cp /data/local/tmp/hot_upload "files/hot/$f"
  echo "pushed $f"
done
"$ADB" shell rm -f /data/local/tmp/hot_upload
cd "$HERE" && node reload.mjs
