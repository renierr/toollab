#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
binary=${1:-"$root/build/linux/x64/debug/bundle/tool_lab"}
mkdir -p "$root/.agents/temp"
scratch=$(mktemp -d "$root/.agents/temp/lua-unwind-XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT

cc -shared -fPIC -o "$scratch/probe.so" "$root/test/linux/lua_unwind_probe.c" -ldl
ulimit -c 0
LD_PRELOAD="$scratch/probe.so" "$binary"
