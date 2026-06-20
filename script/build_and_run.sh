#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="ScrutinyMonitor"
DISPLAY_NAME="Scrutiny Monitor"
BUNDLE_ID="com.chriswebb.ScrutinyMonitor"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_HOME="$HOME"
# Synced folders attach metadata to nested .appex bundles, invalidating signatures.
# Widgets also need a stable installed location so WidgetKit will cache them.
DIST_DIR="${SCRUTINY_MONITOR_DIST_DIR:-$USER_HOME/Applications}"
LEGACY_APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
TEMP_APP_BUNDLE="${TMPDIR:-/tmp}/$APP_NAME-dist/$APP_NAME.app"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS_TEMPLATE="$ROOT_DIR/script/ScrutinyMonitor.entitlements"
GENERATED_ENTITLEMENTS="$DIST_DIR/$APP_NAME.entitlements"
GENERATED_WIDGET_ENTITLEMENTS="$DIST_DIR/ScrutinyMonitorWidget.entitlements"
BUILD_HOME="$ROOT_DIR/.cache/home"
BUILD_CACHE="$ROOT_DIR/.cache/clang"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
CODE_SIGN_KEYCHAIN="${CODE_SIGN_KEYCHAIN:-$USER_HOME/Library/Keychains/login.keychain-db}"
USE_DEVELOPMENT_ENTITLEMENTS=false
APP_GROUP_IDENTIFIER="group.com.chriswebb.ScrutinyMonitor"

if [[ -n "${DEVELOPMENT_TEAM:-}" && "$CODE_SIGN_IDENTITY" != "-" ]]; then
  USE_DEVELOPMENT_ENTITLEMENTS=true
  APP_GROUP_IDENTIFIER="$DEVELOPMENT_TEAM.group.com.chriswebb.ScrutinyMonitor"
fi

export HOME="$BUILD_HOME"
export CLANG_MODULE_CACHE_PATH="$BUILD_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_CACHE"

mkdir -p "$BUILD_HOME" "$BUILD_CACHE"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
WIDGET_BUILD_BINARY="$(swift build --show-bin-path)/ScrutinyMonitorWidget"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
  </dict>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>ScrutinyMonitorAppGroupIdentifier</key>
  <string>$APP_GROUP_IDENTIFIER</string>
</dict>
</plist>
PLIST

# --- Package the Widget Extension ---
WIDGET_BUNDLE="$APP_CONTENTS/PlugIns/ScrutinyMonitorWidget.appex"
WIDGET_MACOS="$WIDGET_BUNDLE/Contents/MacOS"
WIDGET_BINARY="$WIDGET_MACOS/ScrutinyMonitorWidget"
WIDGET_INFO_PLIST="$WIDGET_BUNDLE/Contents/Info.plist"
WIDGET_ENTITLEMENTS_TEMPLATE="$ROOT_DIR/script/ScrutinyMonitorWidget.entitlements"

mkdir -p "$WIDGET_MACOS"
cp "$WIDGET_BUILD_BINARY" "$WIDGET_BINARY"
chmod +x "$WIDGET_BINARY"

cat >"$WIDGET_INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>ScrutinyMonitorWidget</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID.Widget</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME Widget</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME Widget</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>ScrutinyMonitorAppGroupIdentifier</key>
  <string>$APP_GROUP_IDENTIFIER</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
PLIST

# --- Codesigning (Sign child bundles first, then parent) ---
if [[ "$USE_DEVELOPMENT_ENTITLEMENTS" == true ]]; then
  sed "s/TEAM_ID_PLACEHOLDER/$DEVELOPMENT_TEAM/g" "$ENTITLEMENTS_TEMPLATE" >"$GENERATED_ENTITLEMENTS"
  sed "s/TEAM_ID_PLACEHOLDER/$DEVELOPMENT_TEAM/g" "$WIDGET_ENTITLEMENTS_TEMPLATE" >"$GENERATED_WIDGET_ENTITLEMENTS"
else
  cp "$WIDGET_ENTITLEMENTS_TEMPLATE" "$GENERATED_WIDGET_ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Delete :com.apple.security.application-groups" "$GENERATED_WIDGET_ENTITLEMENTS"
fi

# Synced folders can attach Finder metadata that invalidates nested bundle signatures.
xattr -cr "$APP_BUNDLE"

# Codesign Widget Extension
HOME="$USER_HOME" codesign --force --keychain "$CODE_SIGN_KEYCHAIN" --sign "$CODE_SIGN_IDENTITY" --entitlements "$GENERATED_WIDGET_ENTITLEMENTS" "$WIDGET_BUNDLE"

# Codesign Main App Bundle
if [[ "$USE_DEVELOPMENT_ENTITLEMENTS" == true ]]; then
  HOME="$USER_HOME" codesign --force --keychain "$CODE_SIGN_KEYCHAIN" --sign "$CODE_SIGN_IDENTITY" --entitlements "$GENERATED_ENTITLEMENTS" "$APP_BUNDLE"
else
  HOME="$USER_HOME" codesign --force --keychain "$CODE_SIGN_KEYCHAIN" --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
fi

# Signing can cause synced folders to attach Finder metadata to nested bundles again.
xattr -cr "$APP_BUNDLE"
xattr -d com.apple.FinderInfo "$WIDGET_BUNDLE" 2>/dev/null || true
codesign --verify --deep --strict "$APP_BUNDLE"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ "$LEGACY_APP_BUNDLE" != "$APP_BUNDLE" && -d "$LEGACY_APP_BUNDLE" ]]; then
  "$LSREGISTER" -u "$LEGACY_APP_BUNDLE" || true
fi
if [[ "$TEMP_APP_BUNDLE" != "$APP_BUNDLE" && -d "$TEMP_APP_BUNDLE" ]]; then
  "$LSREGISTER" -u "$TEMP_APP_BUNDLE" || true
fi
"$LSREGISTER" -f "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --package|package|build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--package|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
