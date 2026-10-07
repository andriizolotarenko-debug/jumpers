# Jumpers — Requirements (v1, draft)

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

- **R2.1** Hidden by default. Appears on the first counted jump as `x1`, then `x2`,
  `x3`… on each counted jump within the window.
- **R2.2** Placed above the character. The WoW API does not expose the character's screen
  position. The camera keeps the character near screen centre, so the counter is anchored
  above centre and the player can drag it.
- **R2.3** No countdown or timer visual. The 3 s window is meant to be felt.
- **R2.4** When the streak ends, the counter disappears **abruptly**, with a short
  micro-animation (pop / snap). No slow fade.
- **R2.5** Tiers change the counter's look (WoW item-quality colours):

  | Streak | Tier colour |
  |---|---|
  | x5 | Grey (poor) |
  | x10 | Bronze |
  | x25 | Green (uncommon) |
  | x50 | Blue (rare) |
  | x100 | Purple (epic) |
  | x200 | Orange (legendary) |

- **R2.6** Four stacking effects, one added at each tier from green upward:
  x25, x50, x100, x200. Examples: sparks, glow, flames, lightning.
- **R2.7** Size growth: every 100 jumps grows the counter by **+10%** of its base size,
  starting at x100 (x100 = +10%, x200 = +20%…). Capped at **+300%** (reached at x3000).
  At the end it should be genuinely big.
- **R2.8** Each tier change plays a short animation and sound.

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
  - Such second-hand records are accepted as **confirmed** only when several independent
    peers report the same record (quorum).
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

1. Records that have not reached quorum yet: hide them, or show them marked
   "unconfirmed"? Quorum size: 2 or 3 peers?
2. Players Online: is "heard within the last 10 minutes" acceptable?
3. Verify in-game: does holding the jump key re-jump continuously on the Forever client,
   and does it fire the jump hook each time? Affects detection and farming (R5.5).
4. Verify in-game: is the character's facing readable inside dungeons and raids? On the
   modern client it is restricted there. If not, turning cannot be detected in instances,
   so movement there falls back to position change only.
