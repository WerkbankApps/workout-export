#!/bin/zsh
# Erzeugt die App-Store-Screenshots im Simulator mit Beispieldaten.
# Voraussetzung: Die App wurde vorher in Xcode für den Simulator gebaut (Debug).
# Aufruf: Scripts/make-screenshots.sh ["iPhone 18 Pro Max"]
set -euo pipefail

DEVICE_NAME="${1:-iPhone 18 Pro Max}"
BUNDLE_ID="de.werkbankapps.workoutexport"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/Screenshots/${DEVICE_NAME}"
DERIVED_DATA="$(defaults read com.apple.dt.Xcode IDECustomDerivedDataLocation 2>/dev/null || echo "$HOME/Library/Developer/Xcode/DerivedData")"

# Xcode's index keeps a stub copy of the app under Index.noindex – skip it.
APP_PATH="$(find "$DERIVED_DATA" -maxdepth 6 -path "*/Build/Products/Debug-iphonesimulator/*" -not -path "*Index.noindex*" -name "WBA - Workout Export.app" -print -quit)"
[[ -n "$APP_PATH" ]] || { echo "App nicht gefunden – bitte zuerst in Xcode für den Simulator bauen."; exit 1; }

UDID="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['name'] == name and 'iOS' in runtime:
            print(d['udid']); sys.exit()
" "$DEVICE_NAME")"
[[ -n "$UDID" ]] || { echo "Simulator '$DEVICE_NAME' nicht gefunden."; exit 1; }

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
xcrun simctl install "$UDID" "$APP_PATH"
mkdir -p "$OUT_DIR"

shot() {
    local name="$1"; shift
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoMode "$@" >/dev/null
    sleep "${WAIT:-4}"
    xcrun simctl io "$UDID" screenshot --type=png "$OUT_DIR/$name.png" >/dev/null 2>&1
    echo "✓ $name"
}

shot "1-Workouts"     -hasSeenIntro YES -demoSelectCount 3
xcrun simctl ui "$UDID" appearance dark
shot "2-Dunkelmodus"  -hasSeenIntro YES -demoSelectCount 2
xcrun simctl ui "$UDID" appearance light
WAIT=6 shot "3-Export" -hasSeenIntro YES -demoSelectCount 3 -demoShowExport YES
shot "4-Willkommen"   -hasSeenIntro NO

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear
xcrun simctl shutdown "$UDID"
echo "Fertig: $OUT_DIR"
