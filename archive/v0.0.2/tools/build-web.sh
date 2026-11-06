#!/usr/bin/env bash
# Rebuild the web version in docs/ (served by GitHub Pages).
#
#   bash tools/build-web.sh
#
# Then commit and push; Pages updates the live site in a minute or two.
#
# Notes:
#   * Standard love.js mode (not -c): compat mode makes the music choppy.
#   * Only the 5 generated files are copied into docs/. docs/index.html,
#     docs/theme/love.css and docs/coi-serviceworker.min.js are hand-made
#     (phone scaling, rotate prompt, audio unlock) - never overwrite them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/paradice-web"
mkdir -p "$WORK"

# 1. Package the game: every .lua at the top level plus assets/ (minus the
#    font that isn't licensed for public use).
(cd "$ROOT" && python - "$WORK/game.love" <<'PY'
import glob, os, sys, zipfile
skip = {"Qager-zrlmw.ttf", "info.txt"}
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for f in glob.glob("*.lua"):
        z.write(f)
    for root, _, files in os.walk("assets"):
        for f in files:
            if f not in skip:
                z.write(os.path.join(root, f))
PY
)

# 2. Build with love.js.
cd "$WORK"
[ -d node_modules/love.js ] || npm install love.js@11.4.1 --silent
rm -rf out
node node_modules/love.js/index.js game.love out -t "Para-DICE" -m 268435456

# 3. Copy just the generated files into docs/.
cp out/game.data out/game.js out/love.js out/love.wasm out/love.worker.js "$ROOT/docs/"
echo "docs/ updated. game.data is $(du -h "$ROOT/docs/game.data" | cut -f1)."
