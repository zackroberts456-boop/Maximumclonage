#!/usr/bin/env bash
set -euo pipefail

ROM="${1:?ROM path required}"
QA_DIR="${2:-$PWD/qa-blastem-source}"
mkdir -p "$QA_DIR"

sudo apt-get update -qq
# BlastEm's older Makefile asks pkg-config for SDL2 + GLEW + GL as one group
# even when NOGL=1. Installing the dev packages keeps pkg-config from dropping
# the SDL include flags (which was the cause of the previous SDL.h failure).
sudo apt-get install -y -qq \
  build-essential git pkg-config libsdl2-dev libglew-dev libgl1-mesa-dev \
  zlib1g-dev xvfb xdotool scrot x11-utils >/dev/null

rm -rf /tmp/blastem-src
git clone --depth 1 https://github.com/libretro/blastem.git /tmp/blastem-src > "$QA_DIR/git-clone.log" 2>&1
cd /tmp/blastem-src
# Deterministic source build. Disable OpenGL/Nuklear in the runtime itself;
# GLEW/GL headers are installed only because this legacy Makefile probes them
# while calculating SDL2 flags.
make -j2 NOGL=1 NONUKLEAR=1 HOST_ZLIB=1 NOLTO=1 > "$QA_DIR/build.log" 2>&1
BLASTEM_BIN=/tmp/blastem-src/blastem
test -x "$BLASTEM_BIN"
"$BLASTEM_BIN" -h > "$QA_DIR/blastem-help.txt" 2>&1 || true
ldd "$BLASTEM_BIN" > "$QA_DIR/blastem-ldd.txt" 2>&1 || true

TEST_HOME="$QA_DIR/home"
mkdir -p "$TEST_HOME/.config/blastem"
if [ -f /tmp/blastem-src/default.cfg ]; then
  cp /tmp/blastem-src/default.cfg "$TEST_HOME/.config/blastem/blastem.cfg"
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

Xvfb :97 -screen 0 800x600x24 -nolisten tcp > "$QA_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
export DISPLAY=:97
export HOME="$TEST_HOME"
export SDL_AUDIODRIVER=dummy
export SDL_VIDEODRIVER=x11
export LIBGL_ALWAYS_SOFTWARE=1
sleep 1

cleanup(){
  kill "${EMU_PID:-}" 2>/dev/null || true
  kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

(
  cd /tmp/blastem-src
  exec "$BLASTEM_BIN" -g "$ROM" 640 480 > "$QA_DIR/blastem.log" 2>&1
) &
EMU_PID=$!
echo "$EMU_PID" > "$QA_DIR/pid.txt"

WID=""
for _ in $(seq 1 25); do
  if ! kill -0 "$EMU_PID" 2>/dev/null; then break; fi
  WID="$(xdotool search --onlyvisible --pid "$EMU_PID" 2>/dev/null | head -1 || true)"
  if [ -z "$WID" ]; then WID="$(xdotool search --onlyvisible --name 'BlastEm|MAXIMUM|CLONAGE' 2>/dev/null | head -1 || true)"; fi
  [ -n "$WID" ] && break
  sleep 1
done

xwininfo -root -tree > "$QA_DIR/xwininfo-tree.txt" 2>&1 || true
xdotool search --onlyvisible --name '.*' getwindowname %@ > "$QA_DIR/windows.txt" 2>&1 || true
scrot "$QA_DIR/boot-screen.png" || true

if [ -n "$WID" ]; then
  echo "$WID" > "$QA_DIR/window-id.txt"
  xdotool windowactivate --sync "$WID" 2>/dev/null || true
  # BlastEm default keyboard mappings: arrows + A/S/D = A/B/C.
  xdotool keydown --window "$WID" Right || true
  sleep 4
  xdotool key --window "$WID" s || true
  sleep 2
  xdotool key --window "$WID" d || true
  sleep 2
  xdotool key --window "$WID" s || true
  sleep 2
  xdotool keyup --window "$WID" Right || true
  sleep 1
else
  echo NO_WINDOW > "$QA_DIR/window-id.txt"
  sleep 3
fi

scrot "$QA_DIR/after-input.png" || true
find "$QA_DIR" -type f -name 'blastem_*.png' -print > "$QA_DIR/internal-screenshots.txt" || true
if kill -0 "$EMU_PID" 2>/dev/null; then echo ALIVE > "$QA_DIR/emulator-state.txt"; else echo EXITED > "$QA_DIR/emulator-state.txt"; fi
kill "$EMU_PID" 2>/dev/null || true
wait "$EMU_PID" 2>/dev/null || true
find "$QA_DIR" -maxdepth 2 -type f -printf '%p %s bytes\n' | sort > "$QA_DIR/files.txt"
cat "$QA_DIR/emulator-state.txt"
