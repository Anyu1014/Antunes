#!/bin/bash
# 发行产物：build/latest/Antunes-<version>.apk / .ipa
# 用法：Scripts/package.sh [android|ios|all|clean]（默认 all）；iOS 需 KUMONE_TEAM_ID
# 旧产物按 build/history/ 归档，文件名不再带 -android / -ios-unsigned 后缀。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/src"
LATEST="$ROOT/build/latest"
HISTORY="$ROOT/build/history"
[ -f /Users/y/toolchains/env.sh ] && . /Users/y/toolchains/env.sh

if [ "${1:-all}" = clean ]; then
  mkdir -p "$ROOT/.cache"
  # 保留 README.md：它是「这里放什么、可以整目录删」的说明，本身也是零成本文件。
  find "$ROOT/.cache" -mindepth 1 -maxdepth 1 ! -name README.md -exec rm -rf {} +
  exit 0
fi

VERSION="$(grep -o "versionName '[^']*'" "$SRC/android/app/build.gradle" | head -1 | sed "s/.*'\(.*\)'/\1/")"
[ -n "$VERSION" ] || { echo "读不到 versionName" >&2; exit 1; }

mkdir -p "$LATEST" "$HISTORY"
archive_old() { # 只归档本次平台，历史同名包永不覆盖。
  local extension="$1" archive="" f
  for f in "$LATEST"/Antunes-*."$extension"; do
    [ -f "$f" ] || continue
    if [ -z "$archive" ]; then
      archive="$(mktemp -d "$HISTORY/$(date +%Y%m%d-%H%M%S)-XXXXXX")"
    fi
    mv "$f" "$archive/"
  done
}

build_android() {
  ( cd "$SRC/android" && /Users/y/toolchains/bin/gradle assembleRelease -q )
  local apk="$SRC/android/app/build/outputs/apk/release/app-release.apk"
  [ -f "$apk" ] || { echo "release apk 不存在" >&2; exit 1; }
  archive_old apk
  cp "$apk" "$LATEST/Antunes-$VERSION.apk"
  echo "APK: $LATEST/Antunes-$VERSION.apk"
}

build_ios() {
  : "${KUMONE_TEAM_ID:?请设置 KUMONE_TEAM_ID，以本机开发签名生成可装机 IPA}"
  local dd="$SRC/ios/DerivedData"
  ( cd "$SRC" && /Users/y/toolchains/bin/xcodebuild -project ios/Antunes.xcodeproj -scheme Antunes -configuration Release \
      -sdk iphoneos -destination 'generic/platform=iOS' \
      DEVELOPMENT_TEAM="$KUMONE_TEAM_ID" CODE_SIGN_STYLE=Automatic \
      -derivedDataPath "$dd" -quiet build )
  local app="$dd/Build/Products/Release-iphoneos/Antunes.app"
  [ -d "$app" ] || { echo "iOS .app 不存在" >&2; exit 1; }
  mkdir -p "$ROOT/.cache"
  local stage; stage="$(mktemp -d "$ROOT/.cache/package-ios-XXXXXX")"
  mkdir -p "$stage/Payload"
  cp -R "$app" "$stage/Payload/"
  local ipa="$stage/Antunes-$VERSION.ipa"
  ( cd "$stage" && zip -qry "$ipa" Payload )
  archive_old ipa
  mv "$ipa" "$LATEST/Antunes-$VERSION.ipa"
  rm -rf "$stage"
  echo "IPA: $LATEST/Antunes-$VERSION.ipa"
}

case "${1:-all}" in
  android) build_android ;;
  ios) build_ios ;;
  all) build_android; build_ios ;;
  *) echo "用法：$0 [android|ios|all|clean]" >&2; exit 1 ;;
esac
