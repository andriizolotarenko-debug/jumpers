# Jumpers — Plan

Target: **v1.0 on CurseForge by Forever launch (2026-11-04).** Leaderboard follows as v2.

## Phase 0 — API spike (in game, ~1 session)

A throwaway debug addon that prints to chat. It checks the assumptions the architecture
rests on, on the **Forever client** (beta, or launch day at the latest):

| # | Check | Why |
|---|---|---|
| S1 | `select(4, GetBuildInfo())` | TOC `## Interface` number |
| S2 | `JumpOrAscendStart` hook fires once per press, and not when holding | detection, R1.3a |
| S3 | `IsFalling()` turns true within ~0.3 s of a real jump; stays false when rooted | takeoff confirm |
| S4 | `PLAYER_STARTED/STOPPED_MOVING` fire normally; standing on a moving ship = not moving | R1.3 |
| S5 | `GetPlayerFacing()` in the open world vs inside a dungeon | turning, fail-safe |
| S6 | `IsSwimming`, `IsFlying`, `UnitOnTaxi`, `HasFullControl` behave as expected | R1.4 |
| S7 | `GetCurrentRegion()` and `C_DateAndTime.GetCurrentCalendarTime()` exist | units, realm day |
| S8 | Jump height and cycle time (measure with a wall or ledge) | 1.50 m constant, ~0.8 s min gap |
| S9 | `SendAddonMessage` to a custom channel works without a hardware event | v2 transport |

**Needs Andrii in game.** I write the spike addon and the checklist, Andrii runs it and
pastes the output.

## Phase 1 — v1.0 MVP

1. **Skeleton.** TOC, `Core`, SavedVariables + schema version, slash `/jumpers`,
   `.luacheckrc`, busted setup, CI workflow (lint + tests).
2. **Streak engine + Tiers + Units + Stats.** Pure modules with full specs.
3. **Detector.** Jump hook, filters, takeoff confirm, movement and turning.
4. **Art.** Textures for the ribbon, trim, glyph and effects (TGA), plus the font with
   its licence, per [UI-SPEC.md](UI-SPEC.md).
5. **Counter UI.**
   - Assembly x1–x20, tier colours, lettering, growth, window fade, end behaviour.
   - Trim bursts and 4 effect layers.
   - NEW BEST plaque, milestone caption, sounds.
6. **Main window.**
   - Portrait frame with three tabs.
   - Personal Stats: height progress, today / all-time totals, period bests, milestone list.
   - Leaderboard notice.
   - Settings tab with live preview; Options → AddOns stub.
   - Minimap button (LibDataBroker + LibDBIcon via `.pkgmeta`).
7. **Release pipeline.**
   - `.pkgmeta` and release workflow on tag.
   - CurseForge project id and `CF_API_KEY` secret (Andrii creates the project).
8. **In-game acceptance.** Run the checklist below on the Forever client, then tag
   `v1.0.0`.

### v1 in-game acceptance checklist

- [ ] Running jumps within 3 s count x1, x2, x3…; a 3 s pause ends the streak with a
      snap-out.
- [ ] A standing jump does not count and does not reset the window. Turning in place
      between jumps does count.
- [ ] Jumps are not counted while swimming, flying, on a flight path or stunned. They
      are counted mounted and on ships, zeppelins and the tram.
- [ ] The ribbon assembles over x1–x20 (trims snap on at x10 / x20), colours and
      effects arrive at x25 / x50 / x100 / x200, the counter grows +0.1% per jump.
- [ ] Without jumps the ribbon fades by 3 s; the end is a snap above x10, a fade below.
- [ ] A record above x10 ends with NEW BEST!; passing a landmark shows its caption.
- [ ] The window opens from the minimap button and `/jumpers`; all settings apply live.
- [ ] Stats survive `/reload` and relog. Units default by region and can be switched in
      settings.
- [ ] No Lua errors (`/console scriptErrors 1`), including inside a dungeon.
- [ ] Idle CPU is about zero (no OnUpdate while no streak is active).

## Phase 2 — v2.0 Leaderboard

Built (see ARCHITECTURE: Leaderboard):

1. No libraries: plain-text messages (`net/Wire`) and our own send pacing.
2. `net/Verify` and `net/Board` as pure modules with specs: timeframes, quorum = 2,
   hide unconfirmed, online set, sync picks.
3. `net/Comm`: channel join, live streak broadcast, heartbeat (5 min), sync on login /
   every 15 min when quiet, jittered and suppressed answers.
4. Leaderboard tab: Today / 7 / 30 / 365 days, Players Online filter.

Still to do in game:

5. Multi-client test: two or more characters on one realm (or one guild). Check live
   record, relayed record (hidden until 2 relayers), online expiry after 10 min.
6. Check that the client lets an addon join `JumpersLB` and send addon messages to it
   (S9). If not, the board runs on guild traffic only.

## Risks

| Risk | Mitigation |
|---|---|
| Forever API differs from the Classic Era client | Phase 0 spike before writing Detector |
| BigWigs packager may not know the Forever game type yet | fallback: manual CurseForge upload for v1.0 |
| Addon messages to custom channels restricted | guild / party only for v2.0; revisit |
| Farming with external key automation | accepted residual risk (R5.5) |
