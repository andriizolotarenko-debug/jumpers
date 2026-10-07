# Jumpers — Architecture

Companion to [REQUIREMENTS.md](REQUIREMENTS.md). `Rx.y` references point there.

## Principles

- **Pure core, thin adapter.** All rules (streaks, tiers, units, stats, leaderboard
  merge) live in pure Lua modules with no WoW API calls. They are unit-tested outside
  the game. A single adapter module talks to the WoW API.
- **Zero cost when idle.** No per-frame work unless a streak is active. Movement is
  tracked through events, and polling runs only inside the 3 s window.
- **Small, owned art.** The counter ships its own textures (TGA, drawn in greys and
  tinted in game) and one OFL font, so the game matches the approved design
  ([UI-SPEC.md](UI-SPEC.md)). Sounds are short synthesised OGG files, pre-mixed at four
  volume levels.
- **Few libraries.**
  - v1 uses only LibDataBroker-1.1 and LibDBIcon-1.0 (with LibStub and
    CallbackHandler) for the minimap button (R6.2).
  - The leaderboard needs no libraries: its messages are short plain text.
  - All of them come in through `.pkgmeta` externals and are never committed.
- **Fail safe.** Any API that returns nothing (facing in instances, region, calendar)
  degrades to "don't count" or a default. It never errors and never counts by mistake.

## Module map

```
Jumpers.toc
src/
  Core.lua          namespace, init, SavedVariables load + schema migration, slash cmd
  Detector.lua      ADAPTER: jump hook, takeoff confirm, context filters, movement
  Streak.lua        PURE: 3 s window state machine → emits jump / streak-end
  Tiers.lua         PURE: n → look (colours, part alphas, trims, lettering, effects, scale)
  Stats.lua         PURE: today / all-time counts, per-day bests (realm day), period bests, NEW BEST check
  Units.lua         PURE: jumps → m / ft / floors; milestone index, progress, crossings
  Landmarks.lua     DATA: the 55 milestones (UI-SPEC)
  Settings.lua      settings store + defaults; Options → AddOns stub that opens the window
  ui/Counter.lua    combo counter: assembly, tier looks, window fade, snap-out, NEW BEST plaque,
                    the 4 stacking effects (x25 / x50 / x100 / x200) and trim spark bursts
  ui/CounterUI.lua  the on-screen instance: position, unlock + drag, streak events, /jumpers demo
  ui/Caption.lua    milestone caption above the counter
  ui/Window.lua     portrait frame with three tabs
  ui/StatsTab.lua   Personal Stats tab
  ui/BoardTab.lua   Leaderboard tab (v1: "coming in v2" notice)
  ui/SettingsTab.lua  settings controls + live counter preview
  ui/Minimap.lua    LibDataBroker launcher + LibDBIcon button
  net/Wire.lua      PURE: message format
  net/Verify.lua    PURE: plausibility checks
  net/Board.lua     PURE: record store, timeframes, quorum, online set, sync picks
  net/Comm.lua      ADAPTER: addon messages, channel join, pacing, heartbeat, sync
libs/               fetched by the packager from .pkgmeta externals (gitignored)
media/              counter textures (TGA) + ChangaOne-Italic.ttf + OFL.txt
spec/               busted tests for every PURE module
```

Data flow (v1):

```
JumpOrAscendStart hook ─► Detector ──(counted jump)──► Streak ──► Counter / Effects
  movement events + facing poll ─┘                       │
                                                         └─(streak end)──► Stats ─► SavedVariables
```

## Jump detection (Detector)

1. `hooksecurefunc("JumpOrAscendStart", …)` fires on each jump key press. One press is
   one jump (R1.3a).
2. Reject at press time when any of these is true:
   - `IsFalling()`: already airborne, the press does nothing
   - `IsSwimming()`: the key means ascend (R1.4)
   - `IsFlying()`
   - `UnitOnTaxi("player")`
   - `not HasFullControl()`: stun, fear, cutscene
3. **Takeoff confirm.** The press is "pending" until `IsFalling()` becomes true within
   ~0.3 s. This filters roots and blocked jumps. Then it counts.
4. Mounted jumps and jumps on ships, zeppelins and the tram pass the filters naturally
   (R1.4).

### Movement since previous jump (R1.3)

- **Position.** `PLAYER_STARTED_MOVING` / `PLAYER_STOPPED_MOVING` events. "Moved" means
  the player is moving now, or stopped after the previous jump. Event-driven, free when
  idle. It reflects the character's own movement, so standing on a moving ship does not
  count.
- **Turning.** While a streak is active, poll `GetPlayerFacing()` at ~10 Hz and compare
  it with the facing at the previous jump. A nil result (restricted in instances) means
  "no turn detected".
- **First jump of a streak.** It has no previous jump. It counts if the character is
  moving, or moved or turned within the last 3 s.

## Streak engine (Streak, pure)

```
state: idle | active(n, lastJumpAt, startedAt)
onCountedJump(t):  idle → active(1)            → emit jump(1)
                   active, t - last ≤ 3 → n+1  → emit jump(n+1)
tick(t):           active, t - last > 3        → emit streakEnd(n, startedAt, last) → idle
```

Time comes from `GetTime()`, injected so tests can drive it. The window is a constant
(R1.2).

## Counter UI (ui/Counter, ui/CounterUI)

Exact look and timings: [UI-SPEC.md](UI-SPEC.md).

- **Frame.** Child of `UIParent`, anchored just below screen centre, draggable when
  unlocked (R2.2).
- **Layers.** The ribbon is split into three groups, each with its own alpha:
  - core: glyph + count
  - middle
  - sides

  `Tiers` turns `n` into a description of the look: colours, part alphas, trim flags,
  lettering style, effects and scale. Counter only applies it.
- **Count text.**
  - x1–x6: one FontString with `OUTLINE`.
  - From x7: 4 offset FontStrings for the extrusion plus the face.
  - Each depth (drop, 4 extrusion copies, face) lives in its own child frame with a rising
    frame level: font strings have no draw sublevels. Text widths come from the font's
    advance widths, not `GetStringWidth`, which over-reports outlined text.
- **Animation.** One OnUpdate per counter, running only while the counter is shown. It
  drives the window fade (hold 1 s, fade by 3 s), the pops, trim bursts, tier-up flash and
  ring, the 4 stacking effects and the end (snap or fade, NEW BEST hold). Effects are
  additive textures: shine (clipped to the band), lightning (6 frames), sparks, rays
  (`SetRotation`).
- **Scale.** `1 + min(0.001 × n, 3.0)` (R2.7).

## Persistence

- `JumpersDB` (account-wide) and `JumpersCharDB` (per character), with
  `schemaVersion` and migrations in `Core`.
- Stats keep all-time jumps, streaks and best streak, plus **one entry per realm day**:
  that day's jumps, streaks and best streak. Day entries are capped at 366.
  - "Today" and every period best (today / 7 / 30 / 365 days) come from the day entries.
  - "All time" keeps its own counters.
  - Floors and height are derived from jumps, never stored.
- The milestone caption follows the character's height. `Units` returns which
  landmarks a new jump crosses.
- Settings live in `JumpersDB.settings` (account-wide), with the defaults from R6.3.
- Realm day comes from `C_DateAndTime.GetCurrentCalendarTime()`, which uses realm time
  (R4.2).

## Units (Units, pure)

- `HEIGHT_PER_JUMP_M = 1.50` (calibrate in game).
- Default unit from `GetCurrentRegion()`: US → ft, anything else → m. Fallback is the
  `portal` CVar, then m (R3.2).
- Floors: 3 m per floor, or 10 ft in feet mode.
- Landmarks: an ordered list of `{name, height_m, category}`. Output is "climbed N×"
  plus progress toward the next landmark (R3.3).

## Leaderboard (v2)

- **Transport (`net/Comm`).** `C_ChatInfo.SendAddonMessage` with prefix `JMPR` to the
  guild and to the hidden custom channel `JumpersLB` (joined a few seconds after login and
  removed from every chat window). The game server authenticates the sender's name. No
  libraries: messages are short plain text (`net/Wire`) and a queue sends one message per
  ~1.1 s to stay inside the server's addon-message allowance. A blocked or throttled send
  is retried a few times, then dropped; the board keeps working locally.
- **Live record.** When a streak above x10 ends as the character's best of the realm day,
  it goes on our own board and out to peers:
  `R|1|class|n|endedAt (server epoch)|realmDay|duration|minGap` (R5.1). The sender is the
  player.
- **Verify (pure).** Reject a record when:
  - it is x10 or shorter, or absurdly long;
  - its minimum gap between jumps is below 0.45 s (the jump cycle is longer; generous
    tolerance until it is measured in game);
  - its duration is outside `[(n-1)·minGap, (n-1)·3 s]` give or take 1 s;
  - it ends in the future, or (live) more than 2 min ago, or its realm day does not match
    its end time give or take a day (R5.3).
- **Board (pure).**
  - Kept per realm in `JumpersDB.boards[realm]`: the best record per player and realm
    day; timeframes (today / 7 / 30 / 365 days) derive from that. 366 days are kept.
  - Second-hand records (`S|1|player|…`) need **2 distinct relayers** reporting the
    identical record. Until then they are hidden (R5.4). Relays of a player's own records
    by that player are ignored, and we never relay our own (R5.2).
- **Online.** A heartbeat every 5 min (`H|1|class`) says "I'm here". The online set is
  everyone heard from within 10 min (R4.5). The heartbeat carries no bests: those would
  come from SavedVariables, which R5.2 rules out. The online view filters the board.
- **Sync.** On login, and every 15 min when the channel has had no sync traffic for
  10 min, send `Q|1`. A peer answers after a random 2–6 s with the top 10 records of each
  timeframe (at most 25 messages), skips any record two others already relayed while it
  waited, and answers at most once per 5 min. Answers are broadcast, so everyone listening
  benefits from one request.

## Testing

- **Unit:** `busted` on Lua 5.1 for all pure modules, run in CI.
- **Smoke:** `spec/smoke_spec.lua` loads every file in TOC order on a mocked client
  (`spec/wow_mock.lua`), drives jumps through the real hook and runs every OnUpdate.
- **Lint:** `luacheck` with WoW globals declared.
- **In game:** a manual checklist in PLAN.md, run on the Forever client. The dev loop
  is a symlink from the repo into `Interface/AddOns/Jumpers`, then `/reload`.

## Distribution

- **Packaging.** `.pkgmeta` + BigWigs packager in GitHub Actions on a `v*` tag. It
  uploads to CurseForge (`CF_API_KEY` repo secret + `## X-Curse-Project-ID` in the TOC)
  and attaches the zip to a GitHub Release (R7).
- **TOC `## Interface`.** Read it from the Forever client with
  `/dump select(4, GetBuildInfo())`.
