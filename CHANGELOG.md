# Para-DICE changelog

The version is in `config.lua` (`config.VERSION`) and shows in the bottom-right corner of the screen.

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
