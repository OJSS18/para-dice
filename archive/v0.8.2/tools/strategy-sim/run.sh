#!/usr/bin/env bash
# Run the strategy bots against the real game logic.
#   bash tools/strategy-sim/run.sh [games per strategy] [first seed] [strategy numbers, e.g. 6,10]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/tools/strategy-sim"
LOVE="${LOVE:-/c/Program Files/LOVE/lovec.exe}"
WORK="$(mktemp -d)"
cp "$ROOT"/*.lua "$WORK/"
rm "$WORK/main.lua" "$WORK/conf.lua"
cp "$HERE/sim.lua" "$HERE/strategies.lua" "$HERE/early.lua" "$HERE/main.lua" "$WORK/"
cat > "$WORK/conf.lua" <<'EOF'
function love.conf(t)
    t.identity = "ParaDiceSim"
    t.window = false
    t.modules.graphics, t.modules.window, t.modules.audio, t.modules.sound = false, false, false, false
end
EOF
(cd "$WORK" && "$LOVE" . "$@")
rm -rf "$WORK"
