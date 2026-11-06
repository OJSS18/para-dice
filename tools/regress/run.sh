#!/usr/bin/env bash
# Scripted, fully deterministic playthrough of the game that saves a
# screenshot + state line at ~220 checkpoints. Use it to prove a refactor
# changed NOTHING on screen:
#
#   bash tools/regress/run.sh archive/v0.0.2 before   # the old code
#   bash tools/regress/run.sh . after                 # the current code
#   bash tools/regress/compare.sh before after        # IDENTICAL or a list of diffs
#
# The script itself is tools/regress/driver.lua (fake clock and mouse, fixed
# random seed, no sound). Results go to tools/regress/out/<name>/ (git-ignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/tools/regress"
SRC="$(cd "$1" && pwd)"; NAME="$2"
LOVE="${LOVE:-/c/Program Files/LOVE/lovec.exe}"
WORK="$HERE/out/work_$NAME"
rm -rf "$WORK"; mkdir -p "$WORK/assets"
cp "$SRC"/*.lua "$WORK/"
mv "$WORK/main.lua" "$WORK/main_game.lua"
cp "$HERE/driver.lua" "$WORK/main.lua"
cat > "$WORK/conf.lua" <<CONF
function love.conf(t)
    t.identity = "regress_$NAME"
    t.window.title = "regress"
    t.window.width, t.window.height = 1366, 768
    t.window.vsync = 0
end
CONF
for d in dice fonts luck sounds; do cp -r "$ROOT/assets/$d" "$WORK/assets/"; done
SAVE="$APPDATA/LOVE/regress_$NAME"
rm -rf "$SAVE" "$HERE/out/$NAME"; mkdir -p "$SAVE/shots"
(cd "$WORK" && timeout 600 "$LOVE" . 2>&1 | tail -25)
cp -r "$SAVE" "$HERE/out/$NAME"
rm -rf "$WORK"
echo "$NAME: $(ls "$HERE/out/$NAME/shots" | wc -l) screenshots"
