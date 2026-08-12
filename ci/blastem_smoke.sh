#!/usr/bin/env bash
set -euo pipefail

ROM="${1:?ROM path required}"
QA_DIR="${2:-$PWD/qa-blastem}"
mkdir -p "$QA_DIR"

BLASTEM_URL="https://www.retrodev.com/blastem/nightlies/blastem64-0.6.3-pre-732f5689d438.tar.gz"

sudo apt-get update -qq
sudo apt-get install -y -qq xvfb xdotool scrot >/dev/null
curl -L --retry 3 --fail --silent --show-error "$BLASTEM_URL" -o /tmp/blastem64.tar.gz
rm -rf /tmp/blastem-nightly
mkdir -p /tmp/blastem-nightly
tar -xzf /tmp/blastem64.tar.gz -C /tmp/blastem-nightly

BLASTEM_BIN="$(find /tmp/blastem-nightly -type f -name blastem -perm -111 | head -1)"
test -n "$BLASTEM_BIN"
BLASTEM_DIR="$(dirname "$BLASTEM_BIN")"
echo "BlastEm: $BLASTEM_BIN"
"$BLASTEM_BIN" -h > "$QA_DIR/blastem-help.txt" 2>&1 || true

TEST_HOME="$QA_DIR/home"
mkdir -p "$TEST_HOME/.config/blastem"
if [ -f "$BLASTEM_DIR/default.cfg" ]; then
  cp "$BLASTEM_DIR/default.cfg" "$TEST_HOME/.config/blastem/blastem.cfg"
  python3 - "$TEST_HOME/.config/blastem/blastem.cfg" "$QA_DIR" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); out=sys.argv[2]
s=p.read_text(errors='replace')
s=s.replace('screenshot_path $HOME', f'screenshot_path {out}')
s=s.replace('\tgl on', '\tgl off')
s=s.replace('\tscaling linear', '\tscaling nearest')
s=s.replace('\tfullscreen off', '\tfullscreen off')
p.write_text(s)
PY
fi

Xvfb :99 -screen 0 800x600x24 > "$QA_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
trap 'kill $XVFB_PID 2>/dev/null || true' EXIT
export DISPLAY=:99
export HOME="$TEST_HOME"
export SDL_AUDIODRIVER=dummy
export LD_LIBRARY_PATH="$BLASTEM_DIR/lib:${LD_LIBRARY_PATH:-}"
sleep 1

(
  cd "$BLASTEM_DIR"
  "$BLASTEM_BIN" "$ROM" > "$QA_DIR/blastem.log" 2>&1
) &
EMU_PID=$!

sleep 3
WID="$(xdotool search --onlyvisible --pid "$EMU_PID" 2>/dev/null | head -1 || true)"
if [ -z "$WID" ]; then
  WID="$(xdotool search --onlyvisible --name 'BlastEm|MAXIMUM|CLONAGE' 2>/dev/null | head -1 || true)"
fi
xdotool search --onlyvisible --name '.*' getwindowname %@ > "$QA_DIR/windows.txt" 2>&1 || true

scrot "$QA_DIR/boot-screen.png" || true

if [ -n "$WID" ]; then
  echo "Window ID: $WID" | tee "$QA_DIR/window-id.txt"
  xdotool keydown --window "$WID" Right || true
  sleep 3
  xdotool key --window "$WID" s || true
  sleep 2
  xdotool key --window "$WID" s || true
  sleep 2
  xdotool keyup --window "$WID" Right || true
  xdotool key --window "$WID" p || true
  sleep 1
else
  echo "No BlastEm window detected" | tee "$QA_DIR/window-id.txt"
  sleep 5
fi

scrot "$QA_DIR/after-input.png" || true
kill "$EMU_PID" 2>/dev/null || true
wait "$EMU_PID" 2>/dev/null || true
sleep 1

find "$QA_DIR" -maxdepth 2 -type f -printf '%p %s bytes\n' | sort | tee "$QA_DIR/files.txt"
find "$QA_DIR" -type f -name 'blastem_*.png' -print | head -5 > "$QA_DIR/internal-screenshots.txt" || true
