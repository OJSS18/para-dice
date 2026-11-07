# Para-DICE changelog

The version is in `config.lua` (`config.VERSION`) and shows in the bottom-right corner of the screen.

## v0.8.0 - 2026-11-06

- Cheaper upgrades, all on the same footing: LOWER 13, UPPER 13, EVEN and ODD start at 30,
  HOT FOUR at 10 (KEEP BONUS stays 20). Each level now costs 1.5x the one before (was 2x, 3x...):
  30, 45, 70, 100, 150...
- KEEP without rerolling now pays x1.25 (was x1.1); KEEP BONUS still adds +0.1x a level.
- HARD retuned so it can actually be won: goals grow x1.35 a level, then x1.40 from level 6
  (were x1.5 / x1.62). Level 10 on HARD is 8,932 (was 28,243). In the simulator the best
  strategies now win about 1-5% of HARD runs (was 0%). A new leaderboard season.

## v0.7.0 - 2026-11-06

- The shop shows ALL 6 upgrades every visit (LOWER 13, UPPER 13, EVEN, ODD, HOT FOUR, KEEP BONUS),
  as a 3 x 2 grid of cards showing the next level, its multiplier (e.g. x1.25 > x1.50) and price.
- Upgrades never sell out: buy several levels in one visit - each level costs more than the
  last (LOWER 13: 60, 120, 180...). In the simulator, stacking one upgrade doesn't beat the
  best strategies (0-3% wins vs 10%). A new leaderboard season.

## v0.6.0 - 2026-11-06

- New starting luck item: JUST GETTING STARTED - every round scores x1.25 points (it replaces
  Run it Back, which stacked x1.1 onto each point you hit). The tutorial explains it.
  In the simulator the first levels get easier (the best strategies reach level 6 about
  twice as often) while full wins stay at about 10% or less. A new leaderboard season.

## v0.5.0 - 2026-11-06

- Steeper late game: from level 6 to 10 each goal grows x1.35 (NORMAL) or x1.62 (HARD),
  instead of x1.25 / x1.5. Levels 1-5 are unchanged. NORMAL goals for levels 6-10 are now
  1648 / 2225 / 3003 / 4055 / 5474. In the simulator this holds the strongest strategies to
  about 10% wins (it was 17%), so reaching level 5 no longer means the run is as good as won.
  A new leaderboard season.

## v0.4.0 - 2026-11-06

- Mystery Machine odds: Common 35%, Uncommon 35%, Rare 25%, Epic 4%, Legendary 1%
  (were 30 / 30 / 22 / 13 / 5).
- Each spin at a shop visit costs 10 more than the last (35, 45, 55...); the price goes
  back to 35 at the next level's shop. A new leaderboard season.

## v0.3.0 - 2026-11-06

Balance update, priced from the strategy simulator (about 80 coins per extra level a
purchase helps clear). A new leaderboard season.
- Money Makers: 4 of a Kind now pays 35 coins and 3 of a Kind 20 (they paid the dice sum).
- Dice: Red 40 (same), Blue 25 (was 40), Purple 30 (was 55), Amber 60 (was 50),
  Green 10 (was 30 - hugging the middle lands on low-value tiles, so it hurts more than it helps).
- Upgrades now have their own prices (LVL2 costs 2x, LVL3 3x...): LOWER 13 / UPPER 13 60,
  EVEN 55, ODD 40, HOT FOUR 20, KEEP BONUS 20 (all were 25).
- Markers: 20 / 30 / 40 / 50 for the 2nd to 5th chip (were 50 / 75 / 100 / 125).
- Mystery Machine: 35 a spin (was 30).

## v0.2.1 - 2026-11-06

- Placeholder pictures for the 11 new luck items, in the same style as the others (made by
  `python tools/make-luck-icons.py`; swap in real art any time with the same file names).

## v0.2.0 - 2026-11-06

Luck item shake-up (a new leaderboard season, since old replays would play differently):
- Show Me The Money is now LEGENDARY (+100 points per hit, for the run). The stronger
  rare / epic / legendary versions are gone. Rabbit's Leg is now x1.25 per hit (was x1.5).
- New perks that help THIS round: Middle of the Road (common), Hot Dice and Underdog
  (uncommon), Double Down and First Impression (rare), Hat Trick (epic).
- New coin perks: Tip Jar and Piggy Bank (uncommon), Collector and Compound Interest (rare).
- COPYCAT (epic): copies the luck item in the slot to its left.
- Rearrange your luck items: drag them in the luck rack or the shop's YOUR LUCK, or press
  L to pick one and the arrow keys to move it. (Moves are part of replays.)
- New perks use a plain coin icon until they get art: add assets/luck/<id>.png
  (middleRoad, hotDice, underdog, tipJar, piggyBank, doubleDown, firstImpression,
  collector, interest, copycat, hatTrick).

## v0.1.1 - 2026-11-06

- Shop transitions: at the end of a level the table slides away and the shop slides in
  with a soft swoosh; CONTINUE slides the table back in with a matching swoosh.
  (The swooshes are made in code, so the download didn't grow.)
- The online leaderboard is live (Supabase). Seasons now follow a separate rules version,
  so looks-only updates like this one keep everyone's runs on the board.

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
