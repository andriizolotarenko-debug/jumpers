# Jumpers

A World of Warcraft: Forever addon that turns travel into a game: chain your jumps into
streaks, watch the combo counter grow, see how high you would have climbed, and compete
on a shared leaderboard.

Status: beta. Counter, stats and a peer-to-peer leaderboard (in game testing under way). Design and plan: [REQUIREMENTS.md](REQUIREMENTS.md),
[UI-SPEC.md](UI-SPEC.md), [ARCHITECTURE.md](ARCHITECTURE.md), [PLAN.md](PLAN.md).

## Install

Download the zip from [CurseForge](https://www.curseforge.com/wow/addons/jumpers) or
[GitHub Releases](https://github.com/andriizolotarenko-debug/jumpers/releases) and extract the `Jumpers`
folder into the `Interface/AddOns/` folder of your game version:

| Game version | Folder |
|---|---|
| Retail | `World of Warcraft/_retail_/` |
| Classic Era | `World of Warcraft/_classic_era_/` |
| Anniversary | `World of Warcraft/_anniversary_/` |
| Forever | `World of Warcraft/_classic_beta_/` (beta) |

## Use

- Run and jump. Jumps made within 3 seconds of each other while moving chain into a streak.
- `/jumpers` or the minimap button opens stats and settings.
- `/jumpers demo` plays a sample streak on the counter.
- `/jumpers selftest` checks that leaderboard messages go out and come back on your client.
- The leaderboard shares records through your guild and a hidden realm channel. Classic clients
  block addon channels, so there it uses your guild, your group and players you've met: it works
  best in a guild.

## Develop

- `luacheck .` and `busted` (Lua 5.1 / LuaJIT). `spec/smoke_spec.lua` loads the whole addon on a
  mocked client.
- Textures and sounds: `python3 tools/make_art.py`, `python3 tools/make_sounds.py`.
- Releases: push a `v*` tag; GitHub Actions packages it with the BigWigs packager and uploads it to
  CurseForge and GitHub Releases.

## License

[MIT](LICENSE)
