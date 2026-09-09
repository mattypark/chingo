#!/usr/bin/env bash
# Build the bear, export it, and render a turnaround to look at.
#
#   ./assets/bear3d/make.sh            build + export + render
#   ./assets/bear3d/make.sh --quiet    build + export only
#
# One command, because the loop this is used in is "change a number, look at it" and anything
# with three steps in it gets shortened to one step by whoever is in a hurry.
set -euo pipefail
cd "$(dirname "$0")"

BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
LOOK="${BEAR_LOOK_DIR:-$HOME/.claude/jobs/2c14c618/tmp/bear-look}"

"$BLENDER" --background --python build_bear.py 2>&1 | grep -E "^BUILT|Error:" || true
"$BLENDER" --background bear.blend --python export.py 2>&1 | grep -E "^EXPORTED|ERROR" || true

if [ "${1:-}" != "--quiet" ]; then
  "$BLENDER" --background bear.blend --python look.py -- "$LOOK" >/dev/null 2>&1
  ( cd "$LOOK" && ffmpeg -loglevel error -i front.png -i quarter.png -i side.png -i back.png \
      -filter_complex hstack=4 -y turn.png )
  echo "LOOK $LOOK/turn.png"
fi

echo "SIZE $(du -h bear.usdz | cut -f1)"
