#!/usr/bin/env bash
set -euo pipefail

APP_NAME="flighttrace"

# Xcode settings
PROJECT_PATH="flighttrace.xcodeproj"   # or: "flighttrace.xcworkspace"
USE_WORKSPACE=false                    # set true if using xcworkspace
SCHEME_NAME="flighttrace"              # your actual Xcode scheme name
CONFIGURATION="Release"                # Release or Debug
SDK="macosx"

# Output
STAGE_DIR="${APP_NAME}-Installer"
DMG_NAME="${APP_NAME}.dmg"

echo "==> Building ${SCHEME_NAME} (${CONFIGURATION})"

if [[ "$USE_WORKSPACE" == "true" ]]; then
  BUILD_SETTINGS_CMD=(xcodebuild -workspace "$PROJECT_PATH" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" -sdk "$SDK" -showBuildSettings)
  BUILD_CMD=(xcodebuild -workspace "$PROJECT_PATH" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" -sdk "$SDK" build)
else
  BUILD_SETTINGS_CMD=(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" -sdk "$SDK" -showBuildSettings)
  BUILD_CMD=(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" -sdk "$SDK" build)
fi

# Build first (so the .app exists where settings point)
"${BUILD_CMD[@]}"

echo "==> Discovering built app path from build settings"

# Ask xcodebuild where the app ended up:
BUILD_SETTINGS="$("${BUILD_SETTINGS_CMD[@]}")"

TARGET_BUILD_DIR="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F' = ' '/TARGET_BUILD_DIR/ {print $2; exit}')"
WRAPPER_NAME="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F' = ' '/WRAPPER_NAME/ {print $2; exit}')"

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${WRAPPER_NAME:-}" ]]; then
  echo "Failed to detect TARGET_BUILD_DIR or WRAPPER_NAME from xcodebuild settings."
  exit 1
fi

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"

echo "==> App path: $APP_PATH"

# Ensure app exists
if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at $APP_PATH"
  exit 1
fi

echo "==> Preparing staging folder"
rm -rf "$STAGE_DIR" "$DMG_NAME"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"

echo "==> Creating /Applications alias"
# IMPORTANT: EOF must be unindented
/usr/bin/osascript <<EOF
tell application "Finder"
  set targetFolder to (POSIX file "$(pwd)/$STAGE_DIR") as alias
  make new alias file at targetFolder to POSIX file "/Applications" with properties {name:"Applications"}
end tell
EOF

echo "==> Creating DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_NAME"

echo "==> Created $DMG_NAME"
