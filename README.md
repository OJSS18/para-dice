# Para-DICE

A Yahtzee / craps-style dice roguelite made with [LÖVE](https://love2d.org) 11.

**Play in your browser:** see the GitHub Pages link in this repository's "About" section.

**Current version:** v0.8.2 - see [CHANGELOG.md](CHANGELOG.md). New to the game? Pick **TUTORIAL** on the title screen.

## Running it on your computer

Install LÖVE 11, then from this folder run:

```
love .
```

## The online leaderboard (Supabase)

The leaderboard works on each device straight away. To share one board between
everyone, it uses a free [Supabase](https://supabase.com) project:

1. On the Supabase dashboard, make a **New project** (any name, e.g. `para-dice`).
2. Open its **SQL Editor**, paste this in and press **Run**:

```sql
create table public.runs (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  username text not null check (char_length(username) between 3 and 16),
  mode text not null check (mode in ('normal', 'hard')),
  level int not null check (level between 0 and 1000),
  points bigint not null check (points >= 0),
  code text not null check (char_length(code) < 20000),
  version text
);
alter table public.runs enable row level security;
create policy "anyone can read runs" on public.runs for select using (true);
create policy "anyone can add runs" on public.runs for insert with check (true);
create index runs_rank on public.runs (mode, level desc, points desc);
```

3. In **Project Settings > API**, copy the **Project URL** and the **anon public** key
   into `config.ONLINE_URL` and `config.ONLINE_KEY` in `config.lua`. (The anon key is
   meant to be public: the rules above only let people read runs and add new ones.)

Anyone could post a made-up row to the table, so the game never trusts one: before
showing an online run it replays the run's code (instantly) and only shows it if it
really reaches the level and points it claims (`verify.lua`). Only runs from the same
game version are fetched, since a code only replays on its own version - so each new
version starts a fresh leaderboard season.

On a computer the game talks to Supabase with the built-in `curl` program; in a browser,
`docs/index.html` does it for the game (see `net.lua`).

## How the web version is made

The `docs/` folder is the web build, made with [love.js](https://github.com/Davidobot/love.js),
and GitHub Pages serves it. `docs/coi-serviceworker.min.js`
([coi-serviceworker](https://github.com/gzuidhof/coi-serviceworker), MIT) adds the
browser headers love.js needs for smooth audio, since GitHub Pages can't send them itself.

## Credits

- Fonts: Limelight, Ultra, Bungee, Righteous, Press Start 2P (Google Fonts, SIL Open Font License / Apache 2.0)
- Music: "Bonne Soirée" from a Balatro music replacement pack (fan-made; not owned by this project)
