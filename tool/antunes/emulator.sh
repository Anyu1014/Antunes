#!/bin/bash
set -euo pipefail
source /Users/y/toolchains/env.sh
# The automatic software renderer fails to bind the desktop display on this Mac.
exec /Users/y/toolchains/bin/emulator -avd dev -gpu host -no-snapshot-load -no-boot-anim "$@"
