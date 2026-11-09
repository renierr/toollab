#!/usr/bin/env bash
# Boot the Android emulator if none is running, then `flutter run` on it.
# Works on Linux and in MSYS2/Git Bash on Windows.
#
# Machine config (never committed, first hit wins):
#   SDK dir : ANDROID_SDK_ROOT / ANDROID_HOME, then sdk.dir in
#             android/local.properties (written by Flutter), then ~/Android/Sdk
#   AVD     : --avd, then ANDROID_AVD, then avd.name in
#             android/local.properties, then the only AVD if exactly one exists
set -euo pipefail
cd "$(dirname "$0")"

AVD="" SERIAL="" ASSUME_YES=0 WANT_RUN=0 WANT_EMU=0 COLD=0

show_help() {
    cat <<'EOF'
Boot the Android emulator (if needed) and run ToolLab on it.

Usage: ./run-android.sh --run|--boot [OPTION]... [-- FLUTTER_RUN_ARGS...]

Tasks:
  --run           boot the emulator if none is running, then flutter run on it
  --boot          only boot the emulator and wait until it is ready

Options:
  --avd NAME      which emulator AVD to boot
  --serial ID     use this adb device instead (no emulator is booted)
  --cold          cold boot (ignore the emulator's saved snapshot)
  -y, --yes       boot without asking
  -h, --help      show this help

Everything after -- goes to flutter run unchanged (implies --run).

Examples:
  ./run-android.sh --run
  ./run-android.sh --run -y --avd Pixel_10_Pro_XL
  ./run-android.sh --run -- --release
  ./run-android.sh --boot
EOF
}

[ $# -eq 0 ] && { show_help; exit 0; }

while [ $# -gt 0 ]; do
    case "$1" in
        --run) WANT_RUN=1; shift ;;
        --boot) WANT_EMU=1; shift ;;
        --avd) AVD="${2:-}"; shift 2 ;;
        --serial) SERIAL="${2:-}"; shift 2 ;;
        --cold) COLD=1; shift ;;
        -y | --yes) ASSUME_YES=1; shift ;;
        -h | --help) show_help; exit 0 ;;
        --) WANT_RUN=1; shift; break ;;
        *) echo "Unknown option '$1'" >&2; show_help >&2; exit 1 ;;
    esac
done

[ "$WANT_RUN" = 1 ] || [ "$WANT_EMU" = 1 ] || {
    echo "Nothing to do: pass --run or --boot." >&2
    show_help >&2
    exit 1
}

# Flutter writes sdk.dir with escaped Windows backslashes; the grep may
# match nothing, which must not abort under pipefail.
prop() {
    [ -f android/local.properties ] || return 0
    grep -E "^$1=" android/local.properties 2>/dev/null | cut -d= -f2- |
        tr -d '\r' | sed 's#\\\\#/#g; s#\\#/#g' | tail -n 1 || true
}

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$(prop sdk.dir)}}"
[ -n "$SDK" ] || SDK="$HOME/Android/Sdk"
[ -d "$SDK/platform-tools" ] || {
    echo "Android SDK not found at '$SDK'." >&2
    echo "Set ANDROID_SDK_ROOT or run 'flutter doctor' once to write android/local.properties." >&2
    exit 1
}
ADB="$SDK/platform-tools/adb"
[ -f "$ADB" ] || ADB="$ADB.exe"
EMULATOR="$SDK/emulator/emulator"
[ -f "$EMULATOR" ] || EMULATOR="$EMULATOR.exe"

booted() {
    "$ADB" -s "$1" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -q 1
}

# First emulator adb knows about, in any state (a booting one shows as offline).
emulator_serial() {
    "$ADB" devices 2>/dev/null | tr -d '\r' | awk '/^emulator-[0-9]+\t/ {print $1; exit}'
}

resolve_avd() {
    [ -n "$AVD" ] || AVD="${ANDROID_AVD:-$(prop avd.name)}"
    [ -n "$AVD" ] && return 0
    mapfile -t avds < <("$EMULATOR" -list-avds 2>/dev/null | tr -d '\r' | grep -v '^INFO' || true)
    if [ "${#avds[@]}" -eq 1 ]; then
        AVD="${avds[0]}"
        return 0
    fi
    echo "No AVD selected and ${#avds[@]} exist." >&2
    [ "${#avds[@]}" -gt 0 ] && printf '  %s\n' "${avds[@]}" >&2
    echo "Pass --avd NAME, set ANDROID_AVD, or add avd.name to android/local.properties." >&2
    exit 1
}

boot_emulator() {
    resolve_avd
    if [ "$ASSUME_YES" = 0 ]; then
        [ -t 0 ] || {
            echo "No emulator running. Re-run with --yes to boot one." >&2
            exit 1
        }
        printf "No emulator running. Boot AVD '%s'? [Y/n] " "$AVD"
        IFS= read -r answer || answer=""
        case "${answer:-y}" in
            [Yy]*) ;;
            *) echo "Aborted." >&2; exit 1 ;;
        esac
    fi
    local args=(-avd "$AVD")
    [ "$COLD" = 1 ] && args+=(-no-snapshot-load)
    local log="${TMPDIR:-/tmp}/toollab-emulator.log"
    echo "==> starting emulator ($AVD), log: $log"
    nohup "$EMULATOR" "${args[@]}" >"$log" 2>&1 &
    disown 2>/dev/null || true
}

wait_for_boot() {
    echo "==> waiting for boot (up to 5 min)"
    for _ in $(seq 1 100); do
        SERIAL="$(emulator_serial)"
        [ -n "$SERIAL" ] && booted "$SERIAL" && break
        sleep 3
    done
    [ -n "$SERIAL" ] && booted "$SERIAL" || {
        echo "Emulator did not boot in time." >&2
        exit 1
    }
}

if [ -n "$SERIAL" ]; then
    booted "$SERIAL" || { echo "Device '$SERIAL' is not booted." >&2; exit 1; }
else
    SERIAL="$(emulator_serial)"
    if [ -z "$SERIAL" ]; then
        boot_emulator
        wait_for_boot
    elif ! booted "$SERIAL"; then
        wait_for_boot
    fi
fi
echo "==> device $SERIAL: $("$ADB" -s "$SERIAL" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"

[ "$WANT_RUN" = 1 ] || exit 0
echo "==> flutter run -d $SERIAL $*"
exec flutter run -d "$SERIAL" "$@"
