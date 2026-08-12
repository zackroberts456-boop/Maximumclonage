#!/usr/bin/env bash
set -euo pipefail

ROM="${1:?ROM path required}"
QA_DIR="${2:-$PWD/qa-blastem}"
mkdir -p "$QA_DIR"

BLASTEM_URL="https://www.retrodev.com/blastem/nightlies/blastem64-0.6.3-pre-732f5689d438.tar.gz"

sudo apt-get update -qq
sudo apt-get install -y -qq xvfb xdotool scrot x11-utils >/dev/null
curl -L --retry 3 --fail --silent --show-error "$BLASTEM_URL" -o /tmp/blastem64.tar.gz
rm -rf /tmp/blastem-nightly
mkdir -p /tmp/blastem-nightly
tar -xzf /tmp/blastem64.tar.gz -C /tmp/blastem-nightly

BLASTEM_BIN="$(find /tmp/blastem-nightly -type f -name blastem -perm -111 | head -1)"
test -n "$BLASTEM_BIN"
BLASTEM_DIR="$(dirname "$BLASTEM_BIN")"
echo "BlastEm: $BLASTEM_BIN" | tee "$QA_DIR/blastem-path.txt"
"$BLASTEM_BIN" -h > "$QA_DIR/blastem-help.txt" 2>&1 || true
ldd "$BLASTEM_BIN" > "$QA_DIR/blastem-ldd.txt" 2>&1 || true
find "$BLASTEM_DIR" -maxdepth 2 -type f -printf '%p %s bytes\n' | sort > "$QA_DIR/blastem-files.txt" || true

TEST_HOME="$QA_DIR/home"
mkdir -p "$TEST_HOME/.config/blastem"
if [ -f "$BLASTEM_DIR/default.cfg" ]; then
  cp "$BLASTEM_DIR/default.cfg" "$TEST_HOME/.config/blastem/blastem.cfg"
  python3 - "$TEST_HOME/.config/blastem/blastem.cfg" "$QA_DIR" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); out=Path(sys.argv[2]).resolve()
s=p.read_text(errors='replace')
s=s.replace('screenshot_path $HOME', f'screenshot_path {out}')
s=s.replace('\tgl on', '\tgl off')
s=s.replace('\tscaling linear', '\tscaling nearest')
s=s.replace('\tfullscreen on', '\tfullscreen off')
p.write_text(s)
PY
fi

Xvfb :99 -screen 0 800x600x24 -nolisten tcp > "$QA_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
export DISPLAY=:99
export HOME="$TEST_HOME"
export SDL_AUDIODRIVER=dummy
export SDL_VIDEODRIVER=x11
export LIBGL_ALWAYS_SOFTWARE=1
export LD_LIBRARY_PATH="$BLASTEM_DIR/lib:${LD_LIBRARY_PATH:-}"
sleep 1

cleanup() {
  kill "${EMU_PID:-}" 2>/dev/null || true
  sleep 1
  kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

(
  cd "$BLASTEM_DIR"
  exec "$BLASTEM_BIN" -g "$ROM" 640 480 > "$QA_DIR/blastem.log" 2>&1
) &
EMU_PID=$!
echo "$EMU_PID" > "$QA_DIR/blastem-pid.txt"

# SDL can take a few seconds to create the X11 window on a cold hosted runner.
WID=""
for _ in $(seq 1 20); do
  if ! kill -0 "$EMU_PID" 2>/dev/null; then break; fi
  WID="$(xdotool search --onlyvisible --pid "$EMU_PID" 2>/dev/null | head -1 || true)"
  if [ -z "$WID" ]; then
    WID="$(xdotool search --onlyvisible --class 'blastem|BlastEm' 2>/dev/null | head -1 || true)"
  fi
  if [ -z "$WID" ]; then
    WID="$(xdotool search --onlyvisible --name 'BlastEm|MAXIMUM|CLONAGE' 2>/dev/null | head -1 || true)"
  fi
  [ -n "$WID" ] && break
  sleep 1
done

xwininfo -root -tree > "$QA_DIR/xwininfo-tree.txt" 2>&1 || true
xdotool search --onlyvisible --name '.*' getwindowname %@ > "$QA_DIR/windows.txt" 2>&1 || true
ps -ef > "$QA_DIR/processes.txt" 2>&1 || true

scrot "$QA_DIR/boot-screen.png" || true

if [ -n "$WID" ]; then
  echo "Window ID: $WID" | tee "$QA_DIR/window-id.txt"
  xdotool windowactivate --sync "$WID" 2>/dev/null || true
  xdotool keydown --window "$WID" Right || true
  sleep 4
  xdotool key --window "$WID" s || true
  sleep 2
  xdotool key --window "$WID" s || true
  sleep 2
  xdotool keyup --window "$WID" Right || true
  xdotool key --window "$WID" p || true
  sleep 2
else
  echo "No BlastEm window detected" | tee "$QA_DIR/window-id.txt"
  # Still leave the emulator alive briefly so logs can expose startup trouble.
  sleep 3
fi

scrot "$QA_DIR/after-input.png" || true
find "$QA_DIR" -type f -name 'blastem_*.png' -print | head -10 > "$QA_DIR/internal-screenshots.txt" || true

# Capture state before killing the emulator.
if kill -0 "$EMU_PID" 2>/dev/null; then echo ALIVE > "$QA_DIR/emulator-state.txt"; else echo EXITED > "$QA_DIR/emulator-state.txt"; fi
kill "$EMU_PID" 2>/dev/null || true
wait "$EMU_PID" 2>/dev/null || true
sleep 1

find "$QA_DIR" -maxdepth 2 -type f -printf '%p %s bytes\n' | sort | tee "$QA_DIR/files.txt"
