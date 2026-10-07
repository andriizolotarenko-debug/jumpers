# Jumpers — Architecture

Companion to [REQUIREMENTS.md](REQUIREMENTS.md). `Rx.y` references point there.

## Principles

- **Pure core, thin adapter.** All rules (streaks, tiers, units, stats, leaderboard
  merge) live in pure Lua modules with no WoW API calls. They are unit-tested outside
  the game. A single adapter module talks to the WoW API.
- **Zero cost when idle.** No per-frame work unless a streak is active. Movement is
  tracked through events, and polling runs only inside the 3 s window.
- **No shipped art or sound in v1.** Use the game's built-in fonts, textures and sound
  kits. No asset licensing, tiny package.
- **No libraries in v1.** Libraries arrive in v2 with networking (AceComm,
  LibSerialize, LibDeflate via `.pkgmeta` externals).
- **Fail safe.** Any API that returns nothing (facing in instances, region, calendar)
  degrades to "don't count" or a default. It never errors and never counts by mistake.

## Module map

```
Jumpers.toc
src/
  Core.lua          namespace, init, SavedVariables load + schema migration, slash cmd
  Detector.lua      ADAPTER: jump hook, takeoff confirm, context filters, movement
  Streak.lua        PURE: 3 s window state machine → emits jump / streak-end
  Tiers.lua         PURE: n → { colour, effects[], scale }
  Stats.lua         PURE: totals, best, count, per-day bests (realm day)
  Units.lua         PURE: jumps → m / ft / floors; landmark progress
  Landmarks.lua     DATA: buildings, mountains, space distances
  ui/Counter.lua    combo counter frame, tier looks, pop-in / snap-out animations
  ui/Effects.lua    4 stacking effect layers (x25 / x50 / x100 / x200)
  ui/StatsWindow.lua  personal stats + fun metrics (v2: Leaderboard tab)
  Settings.lua      options panel: units, counter position lock/reset, sound on/off
  -- v2 --
  net/Comm.lua      ADAPTER: addon messages, channel join, throttling
  net/Board.lua     PURE: record store, timeframes, quorum, online set
  net/Verify.lua    PURE: plausibility checks
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

## Counter UI (ui/Counter, ui/Effects)

- Child of `UIParent`, anchored above screen centre, draggable when unlocked (R2.2).
- Text `x<n>` uses the built-in font, with colour from `Tiers`.
  - Below x25 the looks differ only by font tint: base, x5 grey, x10 bronze (R2.5).
- `AnimationGroup`s for the effects:
  - **Pop-in** on every jump: a quick scale bounce.
  - **Tier-up flash and sound** (R2.8).
  - **Snap-out** on streak end: about 0.12 s of scale-up plus alpha to 0, then hide
    (R2.4).
- Effects: 4 texture layers with looping animations, toggled by `Tiers.effects`
  (R2.6).
- Scale: `1 + min(0.10 × floor(n / 100), 3.0)` (R2.7).

## Persistence

- `JumpersDB` (account-wide) and `JumpersCharDB` (per character), with
  `schemaVersion` and migrations in `Core`.
- Stats keep totals, best streak and streak count, plus **one best-streak entry per
  realm day**, capped at 366 days. Every timeframe (today / 7 / 30 / 365) is derived from
  that list, so storage stays small and bounded.
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

- **Transport.** `C_ChatInfo.SendAddonMessage` with prefix `JMPR` to the guild and to a
  hidden custom channel joined on login. The game server authenticates the sender's
  name. Traffic is throttled by AceComm / ChatThrottleLib.
- **Live record.** On streak end, broadcast:
  `{len, startedAt, endedAt (server epoch), realmDay, intervals digest}` (R5.1).
- **Verify (pure).** Reject a record when:
  - the minimum gap between jumps is below the physical jump cycle (~0.8 s on flat
    ground, minus tolerance)
  - its duration is outside `[(n-1)·minGap, (n-1)·3 s]`
  - its timestamps are in the future or stale (R5.3)
- **Board (pure).**
  - Per-player best per realm day; timeframes derived from that.
  - Second-hand records need **2 distinct relayers** reporting the identical record.
    Until then they are hidden (R5.4).
  - Own SavedVariables are never re-broadcast as first-hand (R5.2).
- **Online.** A heartbeat about every 5 min carries a short "here + my bests" message.
  The online set is everyone heard from within 10 min (R4.5).
- **Sync.** On login and about every 15 min, request each timeframe's top N from peers.
  Answers are rate-limited and jittered so a crowded channel does not storm.

## Testing

- **Unit:** `busted` on Lua 5.1 for all pure modules, run in CI.
- **Lint:** `luacheck` with WoW globals declared.
- **In game:** a manual checklist in PLAN.md, run on the Forever client. The dev loop
  is a symlink from the repo into `Interface/AddOns/Jumpers`, then `/reload`.

## Distribution

- **Packaging.** `.pkgmeta` + BigWigs packager in GitHub Actions on a `v*` tag. It
  uploads to CurseForge (`CF_API_KEY` repo secret + `## X-Curse-Project-ID` in the TOC)
  and attaches the zip to a GitHub Release (R6).
- **TOC `## Interface`.** Read it from the Forever client with
  `/dump select(4, GetBuildInfo())`.
