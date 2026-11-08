#!/usr/bin/env bash
# Re-make every rolling-die picture (assets/dice/tumble/*.png) from the flat
# face pictures (assets/dice/die_<color>_<face>.png), the ones the shop and
# tray use. Run this after changing or adding any die face art.
#
#   bash tools/render-dice.sh
#
# How: tools/dice-render is a tiny LÖVE program that draws each die as a 3D
# cube textured with the flat faces, and saves 70 frames per colour:
#   tumble_<c>_01..16   the spin loop
#   settle_<c>_f/r<R>_1..4   tipping onto face R (step 4 rocks past flat)
#   land_<c>_<R>   lying flat on face R (identical to the tray picture)
# The poses and the frame size (216, see config.TUMBLE_FRAME_SIZE) are set
# at the top of tools/dice-render/main.lua. New colours: add them to COLORS
# there AND to dicetypes.lua.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOVE="${LOVE:-/c/Program Files/LOVE/lovec.exe}"
WORK="$(mktemp -d)"
SAVE="$APPDATA/LOVE/ParaDiceRender"

cp -r "$ROOT/tools/dice-render/." "$WORK/"
mkdir -p "$WORK/assets/dice"
cp "$ROOT"/assets/dice/die_*.png "$WORK/assets/dice/"

rm -rf "$SAVE"
(cd "$WORK" && "$LOVE" .)

count=$(ls "$SAVE/tumble" | wc -l)
if [ "$count" -lt 420 ]; then
    echo "Only $count frames were made - something went wrong." >&2
    exit 1
fi
cp "$SAVE"/tumble/*.png "$ROOT/assets/dice/tumble/"
rm -rf "$WORK"
echo "Rendered $count frames into assets/dice/tumble/"
