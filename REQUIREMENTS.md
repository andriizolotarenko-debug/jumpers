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
  point since the previous jump (non-zero movement between jumps). Brief stops, such as
  bumping into an obstacle, do not break the streak. A jump with no movement since the
  previous one is ignored. It does not extend the streak and does not reset the window.
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

- **R2.6** Above x200, every +100 jumps (x300, x400…) grows the counter by **5%**.
- **R2.7** From blue onwards, extra effects stack on: one at x50, then one more every
  100 jumps (x100, x200, x300…). Examples: sparks, glow, flames, lightning, orbiting
  stars, trail.
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
  Based on server time, so it is the same for everyone.
- **R4.3** Scope: every player who has the addon installed. Limited by the game to
  players reachable by in-game addon messaging (same realm / connected realms).
- **R4.4** Trust model: **trust the addon, not the player.** See §5.

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
- **R5.4** Records relayed second-hand, needed to sync history for players who were
  offline, are accepted only when confirmed by several independent peers (quorum).
- **R5.5** Known residual risk: a modified addon, or external key automation, can still
  produce fake or farmed streaks. Without a server this cannot be fully prevented. The
  checks above aim to raise the cost of cheating, not to make it impossible.

## 6. Distribution

- **R6.1** CurseForge project page and zip downloads on GitHub Releases.
- **R6.2** Automated packaging and upload on git tag (GitHub Actions + BigWigs packager).

---

## Open questions

1. Counter size growth: cap it (for example at +50%), so it never covers the screen?
2. Effects list (R2.7): the pool is finite. When it runs out, intensify existing
   effects or cycle them?
3. Does holding the jump key re-jump continuously on the Forever client, and does it
   fire the jump hook each time? Verify in-game. Affects detection and farming (R5.5).
4. Is "Today" the realm's calendar day (server time) or UTC?
