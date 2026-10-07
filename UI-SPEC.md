# Jumpers — Combo Counter UI Spec

Approved design of the streak counter (R2). It is the contract for `ui/Counter.lua` and
`ui/Effects.lua`. Sizes are UI pixels at scale 1. Times are seconds.

## Anatomy

A folded fantasy ribbon with the jumper glyph and the count, placed at the character's
feet.

```
     ┌──────────────────────────┐
  ◣──┤  🏃 x37                  ├──◢     sides (tails + folds) · middle · gold trim
     └──────────────────────────┘
```

| Part | Content | Notes |
|---|---|---|
| Glyph | White jumper silhouette from the addon icon | Tinted with the face colour |
| Count | `x` (72% size) + number | Font **Changa One Italic**, 25 px, shipped TTF (OFL) |
| Middle | Ribbon band, height 28 | Grey cloth texture, tinted per tier |
| Sides | Two tails behind the band, 22 px out, 6 px lower, 8 px notch, plus fold triangles | Darker shade of the tier colour |
| Trim | Dark rim (3.4 px) + gold line (1.6 px) around each part | Gold gradient `#ffe7a0 → #d9a640 → #9c6a1c` |

The glyph height is 1.2 × ribbon height. It sits at the left of the band, 9 px from the
edge, with 5 px to the count. The band runs 12 px past the count.

## Lettering

- **x1–x6 (outline):** face colour plus a dark outline (`#140b05`). No shadow, no
  extrusion. The glyph uses a pre-baked outlined texture.
- **x7 and up (extruded):**
  - 4 copies of the text and glyph, 1 px apart downward, behind the face.
  - Their colour runs from `mix(cloth, black, 0.74)` at the back to `0.46` at the front.
  - A 35% black drop layer sits 1.5 px under the last copy.
  - No outline.
- **Face colour:** `mix(white, tier glow, 0.2)`.
- **Fading as one unit:** the glyph and count fade as a single image, so the layers never
  show through each other. In WoW: the outline style is a single FontString with
  `OUTLINE`. Extruded text is only on screen at full alpha, apart from the 0.4 s end fade.

## Assembly x1–x20 (grey)

| Streak | What appears |
|---|---|
| x1–x5 | Glyph + count fade in: alpha `n / 5` |
| x6–x10 | Middle fades in without trim: alpha `(n − 5) / 5`. **x10:** trim snaps on |
| x11–x20 | Sides fade in without trim: alpha `(n − 10) / 10`. **x20:** trim snaps on |
| x21–x24 | Full grey ribbon |

- **Before the trim:** a part shows only a faint 1 px edge at `rgba(20,12,5,.45)`.
- **Trim snap:**
  - The trim appears instantly.
  - An additive light-gold stroke flashes over the new trim for 0.35 s.
  - 30 gold sparks burst off that part's edges. Each lives 0.55–0.95 s, drifts outward
    and falls under gravity.
- **Milestones x5, x10, x20:** a light pop (amplitude 0.3, 0.22 s) and a soft two-note
  sound.

## Tiers (from x25)

| Streak | Tier | Cloth | Glow |
|---|---|---|---|
| x1–x24 | Grey | `#777777` | `#c9c9c9` |
| x25 | Uncommon | `#1f8f27` | `#1eff00` |
| x50 | Rare | `#0b5cbf` | `#2b8cff` |
| x100 | Epic | `#7f30c4` | `#b54bff` |
| x200 | Legendary | `#d06000` | `#ff8a10` |

Tier-up (R2.8):
- A pop (amplitude 0.45, 0.32 s).
- The middle flashes white (0.3 s).
- An expanding ring in the glow colour (0.45 s).
- A chime.

## Effects (stacking, additive blend)

| From | Effect | Behaviour |
|---|---|---|
| x25 | Shine | A diagonal light bar sweeps across the middle in 0.75 s, every 2.4 s, clipped to the band |
| x50 | Lightning | 6 slots around the ribbon: 2 above, 2 below, 1 at each end. A 6-frame bolt flipbook. Each slot fires for 0.14 s once per 0.75–1.35 s. A soft glow behind the ribbon flares with each strike |
| x100 | Sparks | 16 sparks rise 34–52 px off the ribbon and fade. Every third one is a 4-point star |
| x200 | Rays | Two ray sets behind everything (14 and 9 rays), turning at +0.35 and −0.22 rad/s, squashed to 62% height |

Effects use the current tier's glow colour.

## Size growth (R2.7)

`scale = 1 + min(0.001 × n, 3.0)`, so it grows +0.1% per jump from the first one:
- x100 = +10%
- x1000 = +100%
- x3000 = +300% (the cap)

The scale eases toward its target over about 0.1 s.

## Timing within the 3 s window

| Moment | Behaviour |
|---|---|
| Counted jump | Pop: amplitude 0.18 over 0.16 s, easing out quadratically. The first jump uses 0.3 over 0.2 s |
| 0–1 s idle | Everything fully visible |
| 1–3 s idle | Ribbon and effects fade to 0 (smoothstep). Glyph and count stay. A new jump restores them within ~0.1 s |
| Streak end, n > 10 | Glyph + count snap out: 0.12 s, scale +35%, alpha to 0, short sound |
| Streak end, n ≤ 10 | Glyph + count fade out over 0.4 s, silent |

There is no explicit countdown. The fade is the only hint that the window is running
out (R2.3).

## Placement

- Anchored below screen centre, at the character's feet. The exact offset is calibrated
  in game.
- Draggable when unlocked in settings, with a reset to default.
- The counter grows around its centre.

## Assets

Assets are shipped in `media/`:
- Textures are power-of-two TGA files.
- Coloured textures are drawn in greys and tinted with `SetVertexColor`.

| File | Use |
|---|---|
| `ribbon_mid.tga`, `ribbon_side.tga` | Cloth, tinted per tier |
| `ribbon_trim_mid.tga`, `ribbon_trim_side.tga` | Gold trim, untinted |
| `glyph.tga`, `glyph_outline.tga` | Jumper silhouette, plain and with outline |
| `shine.tga`, `glow.tga`, `spark.tga`, `rays.tga` | Effects |
| `bolts.tga` | Lightning flipbook, 6 frames |
| `ChangaOne-Italic.ttf` + `OFL.txt` | Count font and its licence |

Sounds come from the game's built-in sound kits. The kits are picked during
implementation for:
- the jump tick
- the milestone
- the tier-up
- the snap-out
