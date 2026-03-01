#!/usr/bin/env bash
   set -euo pipefail

   APP_NAME="flighttrace"
   SCHEME_NAME="package"
   BUILD_DIR="build"
   APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
   STAGE_DIR="${APP_NAME}-Installer"
   DMG_NAME="${APP_NAME}.dmg"

   # 1) Ensure app exists
   if [ ! -d "$APP_PATH" ]; then
     echo "App not found at $APP_PATH. Build first or adjust paths."
     exit 1
   fi

   # 2) Prepare staging folder
   rm -rf "$STAGE_DIR" "$DMG_NAME"
   mkdir -p "$STAGE_DIR"
   cp -R "$APP_PATH" "$STAGE_DIR/"

   # 3) Create Applications alias
   /usr/bin/osascript <<EOF
   tell application "Finder"
     set targetFolder to (POSIX file "$(pwd)/$STAGE_DIR") as alias
     make new alias file at targetFolder to POSIX file "/Applications" with properties {name:"Applications"}
   end tell
   EOF

   # 4) Optional: create a background image (skip if you have your own)
   # You can drop a PNG at "$STAGE_DIR/.background/bg.png" and set window layout with AppleScript.
   mkdir -p "$STAGE_DIR/.background"

   # 5) Create DMG
   hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_NAME"

   echo "Created $DMG_NAME"
