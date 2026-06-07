#!/usr/bin/env bash

DIST_DIR="dist"
APK_SRC_DIR="build/app/outputs/flutter-apk"
BUNDLE_SRC="build/app/outputs/bundle/release/app-release.aab"
WINDOWS_SRC_DIR="build/windows/x64/runner/Release"
LINUX_SRC_DIR="build/linux/x64/release/bundle"
APP_NAME="ToolLab"

show_help() {
  echo -e "\033[1;36m========================================================\033[0m"
  echo -e "\033[1;32m             ${APP_NAME} Build Script                       \033[0m"
  echo -e "\033[1;36m========================================================\033[0m"
  echo -e "Usage: ./build.sh [arguments...]"
  echo -e ""
  echo -e "\033[1;33mArguments:\033[0m"
  echo -e "  \033[1;32mclean\033[0m       - Clean Flutter build cache and clear dist/"
  echo -e "  \033[1;32mapk\033[0m         - Build universal Android APK"
  echo -e "  \033[1;32mapks\033[0m        - Build Android APKs split per ABI"
  echo -e "  \033[1;32mapks1\033[0m       - Build Android arm64-v8a Split APK"
  echo -e "  \033[1;32mbundle\033[0m      - Build Android App Bundle (.aab)"
  echo -e "  \033[1;32mwindows\033[0m     - Build Windows Desktop release"
  echo -e "  \033[1;32mlinux\033[0m       - Build Linux Desktop release"
  echo -e "  \033[1;32mpackage\033[0m     - Package Windows/Linux build into a ZIP file with install script"
  echo -e "  \033[1;32mhelp\033[0m        - Show this help message"
  echo -e "\033[1;36m========================================================\033[0m"
}

if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

RUN_CLEAN=false
PACKAGE=false
WINDOWS_PACKAGED=false
LINUX_PACKAGED=false
declare -a TASKS=()

# Extract version from pubspec.yaml
VERSION=""
if [ -f "pubspec.yaml" ]; then
  VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //g' | tr -d '\r')
fi

if [ -n "$VERSION" ]; then
  VERSION_SAFE=$(echo "$VERSION" | tr '+' '_')
  ZIP_SUFFIX="-v${VERSION_SAFE}"
  VER_STR=" (v${VERSION})"
else
  ZIP_SUFFIX=""
  VER_STR=""
fi

for arg in "$@"; do
  case "$arg" in
    clean) RUN_CLEAN=true ;;
    apk) TASKS+=("apk") ;;
    apks|apk-split) TASKS+=("apk-split") ;;
    apks1) TASKS+=("apks1") ;;
    bundle) TASKS+=("bundle") ;;
    windows) TASKS+=("windows") ;;
    linux) TASKS+=("linux") ;;
    package) PACKAGE=true ;;
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

create_zip() {
  local zip_name="$1"
  local folder_to_zip="$2"
  shift 2
  local extra_files=("$@")

  local stage_dir="$DIST_DIR/stage"
  rm -rf "$stage_dir"
  mkdir -p "$stage_dir/dist"

  # Copy compiled folder to stage/dist/
  cp -r "$folder_to_zip" "$stage_dir/dist/"

  # Copy extra files (installers) to stage/
  for f in "${extra_files[@]}"; do
    if [ -f "$f" ]; then
      cp "$f" "$stage_dir/"
      if [ "$(basename "$f")" = "install.ps1" ] && [ -n "$VERSION" ]; then
        sed -i "s/\$Version = '[^']*'/\$Version = '${VERSION}'/g" "$stage_dir/install.ps1"
      fi
    fi
  done

  # 1. Try standard 'zip' command
  if command -v zip >/dev/null 2>&1; then
    local abs_zip_path="$(pwd)/$zip_name"
    (cd "$stage_dir" && zip -r "$abs_zip_path" .)
    rm -rf "$stage_dir"
    return 0
  fi

  # 2. Try PowerShell on Windows (native)
  if command -v powershell.exe >/dev/null 2>&1; then
    echo "Using PowerShell to compress..."
    powershell.exe -NoProfile -Command "Compress-Archive -Path '${stage_dir}/*' -DestinationPath '${zip_name}' -Force"
    rm -rf "$stage_dir"
    return 0
  fi

  # 3. Try Tar on Linux/macOS (native, creates .tar.gz instead of .zip)
  if command -v tar >/dev/null 2>&1; then
    local tar_name="${zip_name%.zip}.tar.gz"
    echo "Using tar to compress to $tar_name..."
    local abs_tar_path="$(pwd)/$tar_name"
    (cd "$stage_dir" && tar -czf "$abs_tar_path" .)
    rm -rf "$stage_dir"
    return 0
  fi

  rm -rf "$stage_dir"
  echo -e "\033[1;31mError: No compression tool found ('zip', 'powershell.exe', or 'tar' not available).\033[0m"
  return 1
}

package_windows() {
  if [ -d "$DIST_DIR/${APP_NAME}-windows" ]; then
    echo -e "\033[1;32m>>> Packaging Windows Release...\033[0m"
    pkg_files=()
    [ -f "install.bat" ] && pkg_files+=("install.bat")
    [ -f "install.ps1" ] && pkg_files+=("install.ps1")
    
    zip_name="$DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-windows.zip"
    rm -f "$zip_name"
    create_zip "$zip_name" "$DIST_DIR/${APP_NAME}-windows" "${pkg_files[@]}"
  else
    echo -e "\033[1;31mError: Windows build folder not found at '$DIST_DIR/${APP_NAME}-windows'.\033[0m"
    return 1
  fi
}

package_linux() {
  if [ -d "$DIST_DIR/${APP_NAME}-linux" ]; then
    echo -e "\033[1;32m>>> Packaging Linux Release...\033[0m"
    pkg_files=()
    [ -f "install.sh" ] && pkg_files+=("install.sh")
    
    zip_name="$DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-linux.zip"
    rm -f "$zip_name"
    create_zip "$zip_name" "$DIST_DIR/${APP_NAME}-linux" "${pkg_files[@]}"
  else
    echo -e "\033[1;31mError: Linux build folder not found at '$DIST_DIR/${APP_NAME}-linux'.\033[0m"
    return 1
  fi
}

for task in "${TASKS[@]}"; do
  case "$task" in
    apk)
      echo -e "\033[1;32m>>> Building Android APK${VER_STR}...\033[0m"
      rm -f "$APK_SRC_DIR/app-release.apk"
      if flutter build apk --release; then
        if [ -f "$APK_SRC_DIR/app-release.apk" ]; then
          cp "$APK_SRC_DIR/app-release.apk" "$DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-release.apk"
          echo -e "\033[1;32m>>> Saved: $DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-release.apk\033[0m"
        fi
      else
        exit 1
      fi
      ;;
    apk-split)
      echo -e "\033[1;32m>>> Building Android Split APKs${VER_STR}...\033[0m"
      rm -f "$APK_SRC_DIR"/app-*-release.apk
      if flutter build apk --release --split-per-abi; then
        for file in "$APK_SRC_DIR"/app-*-release.apk; do
          if [ -f "$file" ]; then
            filename=$(basename "$file")
            target="${filename#app-}"
            target="${target%-release.apk}"
            cp "$file" "$DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-${target}-release.apk"
            echo -e "\033[1;32m>>> Saved: $DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-${target}-release.apk\033[0m"
          fi
        done
      else
        exit 1
      fi
      ;;
    apks1)
      echo -e "\033[1;32m>>> Building Android arm64-v8a Split APK${VER_STR}...\033[0m"
      rm -f "$APK_SRC_DIR"/app-*-release.apk
      if flutter build apk --release --target-platform android-arm64 --split-per-abi; then
        for file in "$APK_SRC_DIR"/app-*-release.apk; do
          if [ -f "$file" ]; then
            filename=$(basename "$file")
            target="${filename#app-}"
            target="${target%-release.apk}"
            cp "$file" "$DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-${target}-release.apk"
            echo -e "\033[1;32m>>> Saved: $DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-${target}-release.apk\033[0m"
          fi
        done
      else
        exit 1
      fi
      ;;
    bundle)
      echo -e "\033[1;32m>>> Building App Bundle${VER_STR}...\033[0m"
      rm -f "$BUNDLE_SRC"
      if flutter build appbundle --release; then
        if [ -f "$BUNDLE_SRC" ]; then
          cp "$BUNDLE_SRC" "$DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-release.aab"
          echo -e "\033[1;32m>>> Saved: $DIST_DIR/${APP_NAME}${ZIP_SUFFIX}-release.aab\033[0m"
        fi
      else
        exit 1
      fi
      ;;
    windows)
      echo -e "\033[1;32m>>> Building Windows Release${VER_STR}...\033[0m"
      rm -rf "$WINDOWS_SRC_DIR"
      if flutter build windows --release; then
        if [ -d "$WINDOWS_SRC_DIR" ]; then
          rm -rf "$DIST_DIR/${APP_NAME}-windows"
          mkdir -p "$DIST_DIR/${APP_NAME}-windows"
          cp -r "$WINDOWS_SRC_DIR"/* "$DIST_DIR/${APP_NAME}-windows/"
          echo "$VERSION" > "$DIST_DIR/${APP_NAME}-windows/version.txt"
          if [ "$PACKAGE" = true ]; then
            package_windows
            WINDOWS_PACKAGED=true
          fi
        fi
      else
        exit 1
      fi
      ;;
    linux)
      echo -e "\033[1;32m>>> Building Linux Release${VER_STR}...\033[0m"
      rm -rf "$LINUX_SRC_DIR"
      if flutter build linux --release; then
        if [ -d "$LINUX_SRC_DIR" ]; then
          rm -rf "$DIST_DIR/${APP_NAME}-linux"
          mkdir -p "$DIST_DIR/${APP_NAME}-linux"
          cp -r "$LINUX_SRC_DIR"/* "$DIST_DIR/${APP_NAME}-linux/"
          echo "$VERSION" > "$DIST_DIR/${APP_NAME}-linux/version.txt"
          if [ "$PACKAGE" = true ]; then
            package_linux
            LINUX_PACKAGED=true
          fi
        fi
      else
        exit 1
      fi
      ;;
  esac
done

if [ "$PACKAGE" = true ]; then
  if [ "$WINDOWS_PACKAGED" != true ] && [ -d "$DIST_DIR/${APP_NAME}-windows" ]; then
    package_windows || exit 1
    WINDOWS_PACKAGED=true
  fi
  if [ "$LINUX_PACKAGED" != true ] && [ -d "$DIST_DIR/${APP_NAME}-linux" ]; then
    package_linux || exit 1
    LINUX_PACKAGED=true
  fi

  if [ "$WINDOWS_PACKAGED" != true ] && [ "$LINUX_PACKAGED" != true ]; then
    echo -e "\033[1;31mError: No existing Windows or Linux build found in '$DIST_DIR/' to package.\033[0m"
    exit 1
  fi
fi

echo -e "\033[1;32m>>> All builds completed!\033[0m"
ls -lh "$DIST_DIR"
