# Para-DICE

A Yahtzee / craps-style dice roguelite made with [LÖVE](https://love2d.org) 11.

**Play in your browser:** see the GitHub Pages link in this repository's "About" section.

**Current version:** v0.0.2 - see [CHANGELOG.md](CHANGELOG.md). New to the game? Pick **TUTORIAL** on the title screen.

## Running it on your computer

Install LÖVE 11, then from this folder run:

```
love .
```

## How the web version is made

The `docs/` folder is the web build, made with [love.js](https://github.com/Davidobot/love.js),
and GitHub Pages serves it. `docs/coi-serviceworker.min.js`
([coi-serviceworker](https://github.com/gzuidhof/coi-serviceworker), MIT) adds the
browser headers love.js needs for smooth audio, since GitHub Pages can't send them itself.

## Credits

- Fonts: Limelight, Ultra, Bungee, Righteous, Press Start 2P (Google Fonts, SIL Open Font License / Apache 2.0)
- Music: "Bonne Soirée" from a Balatro music replacement pack (fan-made; not owned by this project)
