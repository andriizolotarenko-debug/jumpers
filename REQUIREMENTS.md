# Jumpers — Requirements (v1)

Target client: **World of Warcraft: Forever** (launch 2026-11-04).
Distribution: CurseForge + zip on GitHub Releases.

Jumpers turns travelling across the world into a game: chain jumps into **streaks**,
watch the combo counter grow next to your character, and compete on a shared
leaderboard.

---

## 1. Streaks (core mechanic)

- **R1.1** A jump made within **3 seconds** of the previous counted jump extends the
  current streak. If 3 s pass with no counted jump, the streak ends and is recorded.
- **R1.2** The 3 s window is fixed for everyone. Not configurable.
- **R1.3** Only *moving* jumps count. A jump counts only if the character moved at some
  point since the previous jump. Brief stops, such as bumping into an obstacle, do not
  break the streak. A jump with no movement since the previous one is ignored. It does
  not extend the streak and does not reset the window.
  - Movement = a change of position **or a turn** (change of facing).
  - Fail safe: if the game does not expose the character's facing (possible inside
    dungeons and raids), turning alone does not count there. Only moving counts. The
    addon must never error or count movement on missing data.
- **R1.3a** One key press = one jump. Holding the jump key does not repeat jumps on the
  Forever client, so each counted jump is a deliberate press.
  - Movement is the character's own movement. Standing still on a moving ship is not
    movement.
- **R1.4** Contexts:

  | Context | Counted |
  |---|---|
  | On foot | ✅ |
  | Mounted | ✅ |
  | Ships, zeppelins, tram | ✅ |
  | Swimming | ❌ |
  | Flying / flight path (taxi) | ❌ |
  | No control of the character (stun, fear, cutscene) | ❌ |

- **R1.5** Every counted jump also increments the lifetime totals, whether or not it
  is part of a long streak.

## 2. Combo counter UI

The approved visual design, with exact values, is in [UI-SPEC.md](UI-SPEC.md).

- **R2.1** Hidden by default. The counter is a fantasy ribbon with the jumper glyph and
  `xN`. It **assembles itself** as the streak grows:
  - x1–x5: the glyph and count fade in (outlined lettering up to x6).
  - x6–x10: the middle of the ribbon fades in. At x10 its gold trim snaps on with a
    burst of gold sparks.
  - x11–x20: the sides fade in the same way. Their trim snaps on at x20.
- **R2.2** Placed at the character's feet. The WoW API does not expose the character's
  screen position. The camera keeps the character near screen centre, so the counter is
  anchored just below centre and the player can drag it.
- **R2.3** No countdown. While no jump is made, the ribbon and effects hold for 1 s and
  then fade out by the end of the 3 s window. The glyph and count stay.
- **R2.4** When the streak ends:
  - above x10: the glyph and count disappear **abruptly**, with a short snap.
  - at x10 or below: they fade out quickly.
- **R2.5** Tiers change the ribbon colour (WoW item-quality colours):

  | Streak | Tier colour |
  |---|---|
  | x1–x24 | Grey (while assembling) |
  | x25 | Green (uncommon) |
  | x50 | Blue (rare) |
  | x100 | Purple (epic) |
  | x200 | Orange (legendary) |

- **R2.6** Four stacking effects, one added at each tier from green upward:
  - x25 shine
  - x50 lightning
  - x100 sparks
  - x200 rays
- **R2.7** Size growth: **+0.1% per jump** from the first one (x100 = +10%,
  x1000 = +100%). Capped at **+300%** (reached at x3000). At the end it should be
  genuinely big.
- **R2.8** Each tier change plays a short animation and sound. The assembly milestones
  x5, x10 and x20 get a lighter version.

## 3. Personal statistics

- **R3.1** Tracked per character and per account:
  - total counted jumps
  - best streak
  - number of streaks
- **R3.2** The streak counter and leaderboard use **jumps**. Personal stats also
  translate jumps into **height climbed**, as if every jump were a step up.
  - Height per jump: ~1.64 yd ≈ **1.50 m ≈ 4.92 ft**, derived from WoW jump physics.
    Must be calibrated in-game.
  - Units: metres, feet, floors. Default: **feet in the US region, metres elsewhere**.
    The player can switch.
  - Floor height: 3 m in metres mode, 10 ft in feet mode.
- **R3.3** Fun comparisons of the height climbed:
  - **Buildings:** Eiffel Tower, Empire State Building, Burj Khalifa…
  - **Mountains:** Hoverla, Mont Blanc, Everest…
  - **Space:** Kármán line, ISS orbit, Earth→Moon, Earth→Mars…
  - Shown as "climbed N× Eiffel Tower" or as progress toward the next landmark.

## 4. Leaderboard

- **R4.1** Ranked by **best single streak (jumps)** within the timeframe.
- **R4.2** Timeframes: **Today**, **Last 7 days**, **Last 30 days**, **Last year**.
  "Today" is the **realm's calendar day**. All timeframes use realm time, so they are
  the same for everyone.
- **R4.3** Scope: every player who has the addon installed. Limited by the game to
  players reachable by in-game addon messaging (same realm / connected realms).
- **R4.4** Trust model: **trust the addon, not the player.** See §5.
- **R4.5** **Players Online** filter: shows only players currently online, meaning heard
  from within the last 10 minutes. Every addon sends a small "I'm here + my bests"
  heartbeat every ~5 minutes. All data in this view is first-hand and live.

## 5. Integrity (anti-cheat)

Constraint: WoW addons have no network access outside the game. There is no server
that could hold an authoritative leaderboard. Everything runs client-side and
peer-to-peer over addon messages.

- **R5.1** Leaderboard records are created only from **live events**. A streak is
  broadcast to peers when it ends. Peers record what they receive live, and the game
  server authenticates the sender's name.
- **R5.2** Local saved data (SavedVariables) is never accepted as a source of
  leaderboard records. Editing your own files changes only your own local view.
- **R5.3** Plausibility checks on every received record:
  - minimum time per jump (physical jump cycle)
  - streak duration consistent with its length
  - timestamps consistent with server time
- **R5.4** Decentralised sync. Each addon keeps its own copy of the leaderboard. On
  login, and periodically, it asks online peers for their top records and merges them.
  This fills in records set while you were offline.
  - Such second-hand records are accepted as **confirmed** only when at least
    **2 independent peers** report the same record (quorum).
  - Until then they are **not shown** at all.
  - With nobody online, you see your local copy: your own records plus what you saw
    before. It syncs when others come online.
  - To keep traffic small, only each timeframe's top N records are synced, never the full
    history. Messages are throttled.
- **R5.5** Known residual risk: a modified addon, or external key automation, can still
  produce fake or farmed streaks. Without a server this cannot be fully prevented. The
  checks above aim to raise the cost of cheating, not to make it impossible.

## 6. Distribution

- **R6.1** CurseForge project page and zip downloads on GitHub Releases.
- **R6.2** Automated packaging and upload on git tag (GitHub Actions + BigWigs packager).

---

## Open questions

None. Defaults adopted on 2026-10-07: unconfirmed records are hidden,
quorum = 2 peers, "online" = heard within the last 10 minutes.
