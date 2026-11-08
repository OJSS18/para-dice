# Para-DICE: notes for Claude

A dice roguelite (Yahtzee meets craps) in LÖVE 11 / Lua. The owner is a beginner, so code comments are written plainly for them. Keep that style: explain *why* in simple words, and avoid clever one-liners.

## Running and testing
- Run the game: `& "C:\Program Files\LOVE\love.exe" .` from this folder (PowerShell). It opens full screen, and Escape quits. End every reply with this command.
- `lovec.exe` (same folder) is the console build. Use it for headless checks, where it prints errors and `print` output.
- Visual checks: put a small harness LÖVE project in the scratchpad. It loads `main_game.lua` (a copy of main.lua), calls `animation.autoThrow`, and saves `love.graphics.captureScreenshot` PNGs. Then crop and contact-sheet them with Python/PIL and look at the result. Enter on the marker screen doesn't throw until every marker is placed, so call the throw directly.
- The ` key is godmode (wins the level / gives coins) for testing.
- **Refactors must not change output.** Prove it with the regression harness: record `bash tools/regress/run.sh <copy of the code before the change> before`, then `bash tools/regress/run.sh . after`, then `bash tools/regress/compare.sh before after`. Use `archive/v0.8.2` as the "before" copy for changes since v0.9.0 (note v0.9.0 added a PLAY menu card, which changes the menu screenshot and some glyph edges). `compare.py` compares RGB - before v0.9.0 it compared RGBA and missed every pixel change. It must say IDENTICAL. The run is deterministic (fixed seed, fake clock and mouse); the script is `tools/regress/driver.lua`. It only catches errors on the paths it plays, so extend the script when you add features.
- Balance testing: `bash tools/strategy-sim/run.sh [games] [seed] [strategy numbers]` plays bot strategies (`tools/strategy-sim/strategies.lua`) through the real logic modules, headless. `TRACE=1` prints each game's result and luck items. `PERKTEST=1` rates every luck item (held from the start); `PRICETEST=1` measures every shop purchase - prices are set at about 80 coins per extra level cleared. As of v0.0.2 the best bot wins ~56%, driven by stacking luck items (Show Me The Money, Rabbit's Leg).
- PIPS balance: `bash tools/pips-sim/run.sh [games] [seed]` plays PIPS mode with a bot (`tools/pips-sim/bot.lua`). `TRACE=1` prints each run; `SET="SETS=4 REROLLS=5"` and `GROWTH=2.2` override config.PIPS numbers.
- `archive/v0.0.2/` and `archive/v0.8.2/` are frozen copies (also git tags `v0.0.2`, `v0.8.2`). Never edit them.

## PIPS mode (second game type)
- Its own files: `pipsgame.lua` (run + `pipsgame.act` doorway), `pipsdice`, `pipshands`, `pipsscore`, `perkys`, `pipsshop` (logic); `pipsview` (looks-only roll/reel animation), `pipslayout`, `pipsdraw`, `pipsinput`. All its numbers are in `config.PIPS`.
- Same replay rules as the main game: every change goes through `pipsgame.act`, randomness through `rng.random`, `pipsgame.ACTION_NAMES` only grows at the end. Not on the leaderboard / stats / replays yet.
- Dice are drawn by code (`pipsdraw.die`), not from the PNGs, so they can be any of the 10 colours in `pipsdice.COLORS`.

## Code layout rules
- main.lua's header lists every module. Shared helpers (rect, isInside, clamp, lerp, round, sum, countFaces, pickWeighted, randomBetween) live in `util.lua` - use them instead of writing local copies. Logic files never draw, and drawing files never change game data.
- `config.lua` holds every tweakable number. `config.VERSION` shows bottom-right. Bump it and add a `CHANGELOG.md` entry (and update the README's "Current version") for each shipped change. Bump `config.RULES_VERSION` too ONLY if old replay codes could play out differently (it resets the online leaderboard season).
- **Replays depend on two rules:** every game-changing player input must go through `game.act(name, arg)` (main.lua never changes game data directly), and all game randomness must use `rng.random` (seeded per run), never `love.math.random` (that's for animations only). `game.ACTION_NAMES` order is part of the replay-code format: only ever add to the end.
- Dice results are chosen in `dice.lua` before a throw. `animation.lua` only moves the dice and picks pictures, so it must never change `dice.values`.

## Dice art
- `assets/dice/die_<color>_<1-6>.png` (128×128) are the flat faces used by the shop, the tray, and landed dice.
- `assets/dice/tumble/*.png` (216×216, die body 130 px) are the rolling frames: `tumble_*_01-16` is the spin loop, `settle_*_f|r<face>_1-4` tips onto a face, and `land_*_<face>` is flat. Frame IDs are described at the top of `animation.lua`.
- The rolling frames are **generated** from the flat faces. After changing face art or adding a colour, run `bash tools/render-dice.sh`. Poses are set in `tools/dice-render/main.lua`, and `tools/dice-render/dice3d.lua` is the cube renderer. A new colour must go in both `COLORS` there and `dicetypes.lua`.

## Web version (GitHub Pages)
- Live at https://ojss18.github.io/para-dice/ from repo OJSS18/para-dice, served from `docs/` on `main`.
- Rebuild with `bash tools/build-web.sh`, then commit and push. Check that `gh api repos/OJSS18/para-dice/pages/builds/latest` reports `built`.
- Hand-made files that must never be overwritten: `docs/index.html`, `docs/theme/love.css`, `docs/coi-serviceworker.min.js`.
- On the web, `love._os == "Web"`: the window is 1366×768 and Escape doesn't quit. Every key-only action also needs a tap button for phones (`ui.touchMode`).
- Download size: `game.data` is about 42 MB, and 29 MB of that is `assets/music/bonne_soiree.mp3`. Re-encoding it with ffmpeg (installed via winget) is the big remaining saving. The owner has postponed this for now.

## Git
- Commit email: `353161310+OJSS18@users.noreply.github.com`. Work on `main` and push when asked or when shipping.
- `assets/fonts/Qager-zrlmw.ttf` and `assets/fonts/info.txt` are git-ignored (non-commercial licence). Keep them out of builds.
