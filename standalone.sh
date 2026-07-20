#!/usr/bin/env bash
# Launch the standalone single-tool builder.
#
#   ./standalone.sh                         # interactive menu (pick tool + platform)
#   ./standalone.sh <tool-id> [target]      # direct build, e.g. ./standalone.sh notes android-apk
#   ./standalone.sh --restore               # revert any leftover workspace patches
#
# Targets: android-apk (default) | android-split | android-arm64 | android-bundle | windows | linux
cd "$(dirname "$0")" || exit 1
exec dart run tool/build_standalone.dart "$@"
