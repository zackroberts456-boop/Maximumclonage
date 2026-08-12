#!/usr/bin/env bash
set -euo pipefail

ROM="${1:?ROM path required}"
QA_DIR="${2:-$PWD/qa-mednafen}"
mkdir -p "$QA_DIR"

sudo apt-get update -qq
sudo apt-get install -y -qq mednafen xvfb xdotool scrot x11-utils >/dev/null
mednafen -help > "$QA_DIR/mednafen-help.txt" 2>&1 || true
mednafen -remote-help > "$QA_DIR/mednafen-remote-help.txt" 2>&1 || true

TEST_HOME="$QA_DIR/home"
mkdir -p "$TEST_HOME"
Xvfb :98 -screen 0 800x600x24 -nolisten tcp > "$QA_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
export DISPLAY=:98
export HOME="$TEST_HOME"
export SDL_AUDIODRIVER=dummy
export SDL_VIDEODRIVER=x11
export LIBGL_ALWAYS_SOFTWARE=1

cleanup(){
  kill "${EMU_PID:-}" 2>/dev/null || true
  kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

mednafen \
  -sound 0 \
  -videoip 0 \
  -fs 0 \
  -md.correct_aspect 0 \
  -md.input.port1 gamepad \
  "$ROM" > "$QA_DIR/mednafen.log" 2>&1 &
EMU_PID=$!
echo "$EMU_PID" > "$QA_DIR/pid.txt"

WID=""
for _ in $(seq 1 25); do
  if ! kill -0 "$EMU_PID" 2>/dev/null; then break; fi
  WID="$(xdotool search --onlyvisible --pid "$EMU_PID" 2>/dev/null | head -1 || true)"
  if [ -z "$WID" ]; then WID="$(xdotool search --onlyvisible --name 'Mednafen|Maximum|Clonage' 2>/dev/null | head -1 || true)"; fi
  [ -n "$WID" ] && break
  sleep 1
done

xwininfo -root -tree > "$QA_DIR/xwininfo-tree.txt" 2>&1 || true
scrot "$QA_DIR/boot-screen.png" || true

if [ -n "$WID" ]; then
  echo "$WID" > "$QA_DIR/window-id.txt"
  xdotool windowactivate --sync "$WID" 2>/dev/null || true
  # Mednafen default gamepad direction uses W/A/S/D. Genesis action mappings
  # follow its numeric-keypad gamepad convention; exercise B/C while running.
  xdotool keydown --window "$WID" d || true
  sleep 3
  xdotool key --window "$WID" KP_2 || true
  sleep 1
  xdotool key --window "$WID" KP_3 || true
  sleep 2
  xdotool key --window "$WID" KP_2 || true
  sleep 2
  xdotool keyup --window "$WID" d || true
  sleep 2
else
  echo "NO_WINDOW" > "$QA_DIR/window-id.txt"
  sleep 3
fi

scrot "$QA_DIR/after-input.png" || true
if kill -0 "$EMU_PID" 2>/dev/null; then echo ALIVE > "$QA_DIR/emulator-state.txt"; else echo EXITED > "$QA_DIR/emulator-state.txt"; fi
kill "$EMU_PID" 2>/dev/null || true
wait "$EMU_PID" 2>/dev/null || true
find "$QA_DIR" -maxdepth 2 -type f -printf '%p %s bytes\n' | sort > "$QA_DIR/files.txt"
cat "$QA_DIR/emulator-state.txt"
