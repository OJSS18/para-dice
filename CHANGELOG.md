# Para-DICE changelog

The version is in `config.lua` (`config.VERSION`) and shows in the bottom-right corner of the screen.

## v0.1.0 - 2026-11-06

- New MAIN MENU on a blue felt table, with the big Para-DICE logo in marquee lights:
  PLAY, REPLAY, SETTINGS, LOGIN / STATS and LEADERBOARD.
- PLAY menu: TUTORIAL, NORMAL (level goals x1.25) or HARD (level goals x1.5).
- ENDLESS: after level 10 you can keep going. Each endless level's goal is x2,
  and from level 11 you can hold a 4th luck item.
- REPLAY CODES: every finished run gives a code (COPY CODE to share it). Paste one
  into REPLAY to watch that exact run, with pause, rewind / skip a round,
  restart and 0.5x-4x speed.
- LOGIN with a username to keep stats (best run, best round, highest level,
  Mystery Machine spins, 5 of a Kinds, BIG / MEGA WINs and more).
- LEADERBOARD ranked by highest level, then points, with a WATCH button on every
  run. It works on this device; the shared online board switches on once a
  Supabase project is set up (see README).
- Escape during a run now asks first (press it twice to go back to the menu).
- Every finished run goes on the leaderboard straight away (as "Guest" if you're not
  logged in; god mode runs stay on this device, marked). The online board refreshes
  by itself every 20 seconds.
- Anti-cheat: every online run is checked by replaying its code before it's shown, so
  made-up scores, re-posted codes and god mode runs never appear.

## Unreleased

- Code clean-up: shared helpers moved into `util.lua`, the three top-right tabs share one drawing function, dead code removed. Nothing looks or plays any differently (checked screenshot-for-screenshot with `tools/regress`).

## v0.0.2 - 2026-11-06

- Rolling dice now match the shop and tray dice: every tumble, settle and landing picture was re-made from the new glossy dice art.
- Smoother landing: a die tips onto its face, rocks a touch, and ends on exactly the tray picture (no more jump on the last frame).

## v0.0.1 - 2026-11-06

First tracked version.

- Throw the dice with real physics (fling them on the felt), or press Enter to throw straight away.
- 5 rounds per level, 10 levels. POINTS tiles, MONEY MAKER hands, white marker chips.
- Luck items are permanent perks: hold up to 3, sell any time for half their value.
- 51 luck items (counting the starter, Run it Back) across Common / Uncommon / Rare / Epic / Legendary, each with its own picture.
- Shop: dice, upgrades, markers, and the 3-reel Mystery Machine (the only way to get luck items).
- START WITH TUTORIAL: a guided 2-round walkthrough with spotlights and arrows, plus a shop tour.
