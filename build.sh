#!/usr/bin/env bash

DIST_DIR="dist"
APK_SRC_DIR="build/app/outputs/flutter-apk"
BUNDLE_SRC="build/app/outputs/bundle/release/app-release.aab"
WINDOWS_SRC_DIR="build/windows/x64/runner/Release"
LINUX_SRC_DIR="build/linux/x64/release/bundle"
APP_NAME="ToolLab"

show_help() {
  echo -e "\033[1;36m========================================================\033[0m"
  echo -e "\033[1;32m             ToolLab Build Script                       \033[0m"
  echo -e "\033[1;36m========================================================\033[0m"
  echo -e "Usage: ./build.sh [arguments...]"
  echo -e ""
  echo -e "\033[1;33mArguments:\033[0m"
  echo -e "  \033[1;32mclean\033[0m       - Clean Flutter build cache and clear dist/"
  echo -e "  \033[1;32mapk\033[0m         - Build universal Android APK"
  echo -e "  \033[1;32mapks\033[0m        - Build Android APKs split per ABI"
  echo -e "  \033[1;32mbundle\033[0m      - Build Android App Bundle (.aab)"
  echo -e "  \033[1;32mwindows\033[0m     - Build Windows Desktop release"
  echo -e "  \033[1;32mlinux\033[0m       - Build Linux Desktop release"
  echo -e "  \033[1;32mhelp\033[0m        - Show this help message"
  echo -e "\033[1;36m========================================================\033[0m"
}

if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

RUN_CLEAN=false
declare -a TASKS=()

for arg in "$@"; do
  case "$arg" in
    clean) RUN_CLEAN=true ;;
    apk) TASKS+=("apk") ;;
    apks|apk-split) TASKS+=("apk-split") ;;
    bundle) TASKS+=("bundle") ;;
    windows) TASKS+=("windows") ;;
    linux) TASKS+=("linux") ;;
    -h|--help|help) show_help; exit 0 ;;
    *) echo -e "\033[1;31mError: Unknown argument '$arg'\033[0m"; show_help; exit 1 ;;
  esac
done

if [ "$RUN_CLEAN" = true ]; then
  echo -e "\033[1;33m>>> Cleaning Flutter build cache...\033[0m"
  flutter clean
  if [ -d "$DIST_DIR" ]; then
    rm -rf "${DIST_DIR:?}"/*
  fi
fi

mkdir -p "$DIST_DIR"

for task in "${TASKS[@]}"; do
  case "$task" in
    apk)
      echo -e "\033[1;32m>>> Building Android APK...\033[0m"
      rm -f "$APK_SRC_DIR/app-release.apk"
      if flutter build apk --release; then
        if [ -f "$APK_SRC_DIR/app-release.apk" ]; then
          cp "$APK_SRC_DIR/app-release.apk" "$DIST_DIR/${APP_NAME}-release.apk"
          echo -e "\033[1;32m>>> Saved: $DIST_DIR/${APP_NAME}-release.apk\033[0m"
        fi
      else
        exit 1
      fi
      ;;
    apk-split)
      echo -e "\033[1;32m>>> Building Android Split APKs...\033[0m"
      rm -f "$APK_SRC_DIR"/app-*-release.apk
      if flutter build apk --release --split-per-abi; then
        for file in "$APK_SRC_DIR"/app-*-release.apk; do
          if [ -f "$file" ]; then
            filename=$(basename "$file")
            target="${filename#app-}"
            target="${target%-release.apk}"
            cp "$file" "$DIST_DIR/${APP_NAME}-${target}-release.apk"
          fi
        done
      else
        exit 1
      fi
      ;;
    bundle)
      echo -e "\033[1;32m>>> Building App Bundle...\033[0m"
      rm -f "$BUNDLE_SRC"
      if flutter build appbundle --release; then
        if [ -f "$BUNDLE_SRC" ]; then
          cp "$BUNDLE_SRC" "$DIST_DIR/${APP_NAME}-release.aab"
        fi
      else
        exit 1
      fi
      ;;
    windows)
      echo -e "\033[1;32m>>> Building Windows Release...\033[0m"
      rm -rf "$WINDOWS_SRC_DIR"
      if flutter build windows --release; then
        if [ -d "$WINDOWS_SRC_DIR" ]; then
          rm -rf "$DIST_DIR/${APP_NAME}-windows"
          mkdir -p "$DIST_DIR/${APP_NAME}-windows"
          cp -r "$WINDOWS_SRC_DIR"/* "$DIST_DIR/${APP_NAME}-windows/"
        fi
      else
        exit 1
      fi
      ;;
    linux)
      echo -e "\033[1;32m>>> Building Linux Release...\033[0m"
      rm -rf "$LINUX_SRC_DIR"
      if flutter build linux --release; then
        if [ -d "$LINUX_SRC_DIR" ]; then
          rm -rf "$DIST_DIR/${APP_NAME}-linux"
          mkdir -p "$DIST_DIR/${APP_NAME}-linux"
          cp -r "$LINUX_SRC_DIR"/* "$DIST_DIR/${APP_NAME}-linux/"
        fi
      else
        exit 1
      fi
      ;;
  esac
done

echo -e "\033[1;32m>>> All builds completed!\033[0m"
ls -lh "$DIST_DIR"
