#!/usr/bin/env bash
# Play PIPS mode with the strategy bot, headless, through the real logic.
#   bash tools/pips-sim/run.sh [games] [first seed]
# Env: TRACE=1 prints each game's run; GROWTH=1.7 overrides GOAL_GROWTH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/tools/pips-sim"
LOVE="${LOVE:-/c/Program Files/LOVE/lovec.exe}"
WORK="$(mktemp -d)"
cp "$ROOT"/*.lua "$WORK/"
rm "$WORK/main.lua" "$WORK/conf.lua"
cp "$HERE/bot.lua" "$HERE/main.lua" "$WORK/"
cat > "$WORK/conf.lua" <<'CONF'
function love.conf(t)
    t.identity = "ParaDicePipsSim"
    t.window = false
    t.modules.graphics, t.modules.window, t.modules.audio, t.modules.sound = false, false, false, false
end
CONF
(cd "$WORK" && "$LOVE" . "$@")
rm -rf "$WORK"
