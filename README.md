# Jumpers

A World of Warcraft: Forever addon that turns travel into a game: chain your jumps into
streaks, watch the combo counter grow, see how high you would have climbed, and compete
on a shared leaderboard.

Status: beta. Counter, stats and a peer-to-peer leaderboard (in game testing under way). Design and plan: [REQUIREMENTS.md](REQUIREMENTS.md),
[UI-SPEC.md](UI-SPEC.md), [ARCHITECTURE.md](ARCHITECTURE.md), [PLAN.md](PLAN.md).

## Install

Download the zip from [CurseForge](https://www.curseforge.com/wow/addons/jumpers) or
[GitHub Releases](https://github.com/andriizolotarenko-debug/jumpers/releases) and extract the `Jumpers`
folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.

## Use

- Run and jump. Jumps made within 3 seconds of each other while moving chain into a streak.
- `/jumpers` or the minimap button opens stats and settings.
- `/jumpers demo` plays a sample streak on the counter.

## Develop

- `luacheck .` and `busted` (Lua 5.1 / LuaJIT). `spec/smoke_spec.lua` loads the whole addon on a
  mocked client.
- Textures and sounds: `python3 tools/make_art.py`, `python3 tools/make_sounds.py`.
- Releases: push a `v*` tag; GitHub Actions packages it with the BigWigs packager and uploads it to
  CurseForge and GitHub Releases.

## License

[MIT](LICENSE)
