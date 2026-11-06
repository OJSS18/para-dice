# Para-DICE: notes for Claude

A dice roguelite (Yahtzee meets craps) in LÖVE 11 / Lua. The owner is a beginner, so code comments are written plainly for them. Keep that style: explain *why* in simple words, and avoid clever one-liners.

## Running and testing
- Run the game: `& "C:\Program Files\LOVE\love.exe" .` from this folder (PowerShell). It opens full screen, and Escape quits. End every reply with this command.
- `lovec.exe` (same folder) is the console build. Use it for headless checks, where it prints errors and `print` output.
- Visual checks: put a small harness LÖVE project in the scratchpad. It loads `main_game.lua` (a copy of main.lua), calls `animation.autoThrow`, and saves `love.graphics.captureScreenshot` PNGs. Then crop and contact-sheet them with Python/PIL and look at the result. Enter on the marker screen doesn't throw until every marker is placed, so call the throw directly.
- The ` key is godmode (wins the level / gives coins) for testing.
- **Refactors must not change output.** Prove it with the regression harness: `bash tools/regress/run.sh archive/v0.0.2 before`, `bash tools/regress/run.sh . after`, then `bash tools/regress/compare.sh before after`. It must say IDENTICAL. The run is deterministic (fixed seed, fake clock and mouse); the script is `tools/regress/driver.lua`. It only catches errors on the paths it plays, so extend the script when you add features.
- `archive/v0.0.2/` is a frozen copy of the code before the clean-up (also git tag `v0.0.2`). Never edit it.

## Code layout rules
- main.lua's header lists every module. Shared helpers (rect, isInside, clamp, lerp, round, sum, countFaces, pickWeighted, randomBetween) live in `util.lua` - use them instead of writing local copies. Logic files never draw, and drawing files never change game data.
- `config.lua` holds every tweakable number. `config.VERSION` shows bottom-right. Bump it and add a `CHANGELOG.md` entry (and update the README's "Current version") for each shipped change.
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
