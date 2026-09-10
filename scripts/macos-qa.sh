#!/bin/bash
# macos-qa.sh — Build, test, launch Key.app, and capture overlay screenshots on macOS.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "HOST=wrong uname=$(uname -s) — this script must run on macOS"
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHOT_DIR="${PROJECT_DIR}/.qa-screenshots"
mkdir -p "$SHOT_DIR"

cd "$PROJECT_DIR"
echo "[QA] Building..."
swift build
echo "[QA] Testing..."
swift test

pkill -x Key || true
sleep 0.4

echo "[QA] Launching..."
swift run --skip-build Key >/tmp/key-qa.log 2>&1 &
KEY_PID=$!
sleep 2

# Toggle the overlay via the default global shortcut (⌘⇧K). Accessibility may be required.
osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "k" using {command down, shift down}
end tell
APPLESCRIPT
sleep 0.8
screencapture -x "$SHOT_DIR/01-cursor-table.png"

# Cycle tables by clicking relative tab positions is environment-specific;
# capture the current board and settings file as evidence of launch.
if [[ -f "$HOME/.config/key/settings.json" ]]; then
  cp "$HOME/.config/key/settings.json" "$SHOT_DIR/settings.json"
fi

echo "[QA] Screenshots in $SHOT_DIR"
echo "[QA] Key pid=$KEY_PID"
echo "[QA] DONE"
