#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ToolLab-linux"
EXE_NAME="tool_lab"
SRC="dist/$APP_NAME"
DEST="$HOME/.local/share/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/toollab"
DESKTOP="$HOME/.local/share/applications/toollab.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

VERSION=""
if [ -f "pubspec.yaml" ]; then
  VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //g' | tr -d '\r')
fi

WRITE_INFO='\033[1;36m'
WRITE_OK='\033[1;32m'
WRITE_WARN='\033[1;33m'
WRITE_ERR='\033[1;31m'
NC='\033[0m'

echo_info() { echo -e "${WRITE_INFO}INFO:${NC} $1"; }
echo_ok()   { echo -e "${WRITE_OK}OK:${NC}   $1"; }
echo_warn() { echo -e "${WRITE_WARN}WARN:${NC} $1"; }
echo_err()  { echo -e "${WRITE_ERR}ERR:${NC}  $1"; }

stop_app() {
  local pid
  pid=$(pgrep -x "$EXE_NAME" 2>/dev/null || true)
  if [ -n "$pid" ]; then
    echo_info "Stopping running $APP_NAME..."
    kill "$pid" 2>/dev/null || true
    sleep 1
  fi
}

install_files() {
  stop_app
  echo_info "Copying files to $DEST..."
  rm -rf "$DEST"
  cp -r "$SRC" "$DEST"
  echo_ok "Files copied ($(find "$DEST" -type f | wc -l) files)"
}

install_symlink() {
  mkdir -p "$BIN_DIR"
  ln -sf "$DEST/$EXE_NAME" "$BIN"
  echo_ok "Symlink created: $BIN -> $DEST/$EXE_NAME"
}

install_desktop_file() {
  mkdir -p "$HOME/.local/share/applications"

  local icon_path="$DEST/data/flutter_assets/assets/logo/logo.png"

  cat > "$DESKTOP" << EOF
[Desktop Entry]
Name=ToolLab
Comment=Tool Collection App
Exec=$DEST/$EXE_NAME %F
Icon=$icon_path
Terminal=false
Type=Application
Categories=Utility;
MimeType=application/pdf;text/plain;text/markdown;image/png;image/jpeg;image/webp;image/bmp;image/gif;image/tiff;image/x-icon;image/x-tga;image/x-portable-pixmap;image/x-portable-graymap;image/x-portable-bitmap;image/x-portable-anymap;audio/x-mod;audio/x-xm;audio/x-it;audio/x-s3m;audio/wav;audio/mpeg;audio/ogg;audio/flac;audio/aac;audio/mp4;audio/opus;audio/x-ms-wma;audio/aiff;audio/amr;audio/x-matroska;
StartupWMClass=tool_lab
EOF
  echo_ok "Desktop file created: $DESKTOP"
}

install_icon_resource() {
  if [ -f "$DEST/data/flutter_assets/assets/logo/logo.png" ]; then
    mkdir -p "$ICON_DIR"
    cp "$DEST/data/flutter_assets/assets/logo/logo.png" "$ICON_DIR/toollab.png"
    xdg-icon-resource install --size 256 "$ICON_DIR/toollab.png" "toollab" 2>/dev/null || true
    echo_ok "Icon resource registered"
  fi
}

register_file_associations() {
  local -a mime_types=(
    "application/pdf"
    "text/plain"
    "text/markdown"
    "image/png"
    "image/jpeg"
    "image/webp"
    "image/bmp"
    "image/gif"
    "image/tiff"
    "image/x-icon"
    "image/x-tga"
    "image/x-portable-pixmap"
    "image/x-portable-graymap"
    "image/x-portable-bitmap"
    "image/x-portable-anymap"
    "audio/x-mod"
    "audio/x-xm"
    "audio/x-it"
    "audio/x-s3m"
    "audio/wav"
    "audio/mpeg"
    "audio/ogg"
    "audio/flac"
    "audio/aac"
    "audio/mp4"
    "audio/opus"
    "audio/x-ms-wma"
    "audio/aiff"
    "audio/amr"
    "audio/x-matroska"
  )

  for mime in "${mime_types[@]}"; do
    xdg-mime default toollab.desktop "$mime" 2>/dev/null || true
    echo_ok "Registered $mime -> toollab.desktop"
  done
}

update_mime_database() {
  local mime_dir="$HOME/.local/share/mime"
  if [ -d "$mime_dir" ]; then
    update-mime-database "$mime_dir" 2>/dev/null || true
  fi
  update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
  echo_ok "MIME and desktop databases updated"
}

uninstall_all() {
  echo_info "Starting uninstall..."

  stop_app

  local -a mime_types=(
    "application/pdf"
    "text/plain"
    "text/markdown"
    "image/png"
    "image/jpeg"
    "image/webp"
    "image/bmp"
    "image/gif"
    "image/tiff"
    "image/x-icon"
    "image/x-tga"
    "image/x-portable-pixmap"
    "image/x-portable-graymap"
    "image/x-portable-bitmap"
    "image/x-portable-anymap"
    "audio/x-mod"
    "audio/x-xm"
    "audio/x-it"
    "audio/x-s3m"
    "audio/wav"
    "audio/mpeg"
    "audio/ogg"
    "audio/flac"
    "audio/aac"
    "audio/mp4"
    "audio/opus"
    "audio/x-ms-wma"
    "audio/aiff"
    "audio/amr"
    "audio/x-matroska"
  )
  for mime in "${mime_types[@]}"; do
    xdg-mime default "" "$mime" 2>/dev/null || true
  done
  echo_ok "File associations removed"

  if [ -f "$DESKTOP" ]; then
    rm -f "$DESKTOP"
    echo_ok "Removed desktop file"
  fi

  if [ -f "$BIN" ]; then
    rm -f "$BIN"
    echo_ok "Removed symlink: $BIN"
  fi

  if [ -d "$ICON_DIR" ]; then
    rm -f "$ICON_DIR/toollab.png"
    xdg-icon-resource uninstall --size 256 "toollab" 2>/dev/null || true
    echo_ok "Removed icon resource"
  fi

  if [ -d "$DEST" ]; then
    rm -rf "$DEST"
    echo_ok "Removed $DEST"
  fi

  update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
  update-mime-database "$HOME/.local/share/mime/" 2>/dev/null || true
  echo_ok "MIME and desktop databases updated"

  echo_ok "Uninstall complete"
}

install_all() {
  if [ ! -d "$SRC" ]; then
    echo_err "Source not found: $SRC. Run 'flutter build linux' first."
    exit 1
  fi
  if [ ! -f "$SRC/$EXE_NAME" ]; then
    echo_err "$EXE_NAME not found in $SRC"
    exit 1
  fi

  install_files
  install_symlink
  install_desktop_file
  install_icon_resource
  register_file_associations
  update_mime_database

  echo_ok "$APP_NAME installed to $DEST"
  echo_info "Launch with 'toollab' or from your app launcher"
  echo_info "Run '$0 --uninstall' to remove"
}

# --- Entry point ---
if [ -n "$VERSION" ]; then
  echo_info "Starting installer for $APP_NAME (v$VERSION)..."
else
  echo_info "Starting installer for $APP_NAME..."
fi

if [ "${1:-}" = "--uninstall" ] || [ "${1:-}" = "-u" ]; then
  uninstall_all
  exit 0
fi

if [ -d "$DEST" ]; then
  echo_info "$APP_NAME is already installed at $DEST"
  read -r -p "Reinstall/update? [Y/n] " answer
  if [ "$answer" != "" ] && [[ "$answer" =~ ^[Nn] ]]; then
    echo_info "Update cancelled"
    exit 0
  fi
fi

install_all
