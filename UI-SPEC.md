# Jumpers — UI Spec

Approved design of the combo counter (R2), the NEW BEST and milestone moments, the main
window (R6) and the milestone list (R3.3). It is the contract for the `ui/` modules.
Sizes are UI pixels at scale 1. Times are seconds.

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
| x300 | Mythic | `#b3151b` | `#ff3b30` |
| x1000 | Rainbow | hue cycles (period ~8 s) | hue cycles |

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

**Rainbow (x1000):** a tileable hue strip is multiplied over the grey band and scrolls
slowly along it. The tails, the extrusion, the face tint and every effect follow one
hue that cycles through the spectrum (cloth `hsv(h, 0.85, 0.8)`, glow `hsv(h, 0.65, 1)`).
In Personal Stats a best streak of x1000+ is printed one hue per character.

## Every tenth jump

Every 10th jump that has no bigger moment of its own (not x10, x20, a tier or an
ornament) gets a small pulse:
- a pop (amplitude 0.24, 0.2 s);
- 14 sparks in the tier's glow colour (mixed 50% with white) drift off the top and bottom
  edges of the band and fade within ~0.4–0.8 s;
- the tick sound.

## Gold ornaments (x75 – x750)

Past the last effects the frame keeps getting richer. Each group snaps on with a pop
(amplitude 0.35, 0.26 s), grows in from 170% to full size over 0.3 s, flashes the trim,
bursts gold sparks from its pieces and plays the milestone sound. They stay for the rest
of the streak and fade with the ribbon.

| From | Ornament | Pieces |
|---|---|---|
| x75 | Corner curls | A short gold scroll with a leaf at each corner of the band, 12 × 12 |
| x150 | Crest and pendant | A diamond with a ball and two scrolls on top of the band, mirrored below it, 48 × 20 |
| x350 | Wings | Three short filigree strokes with curled ends past each tail, 26 × 24 |
| x400 | Runs and sapphires | Filigree strips along the top and bottom trim (24 × 8, four), a sapphire set in the crest and the pendant |
| x500 | Emeralds and diamonds | An emerald on each corner curl, a small diamond on each run |
| x750 | Crown | A crown replaces the top crest: rubies on its three points, a sapphire in its band |

Drawn like the trim: gold gradient `#ffe7a0 → #d9a640 → #9c6a1c` with a dark rim. Gems are
a faceted stone in greys, tinted per gem (sapphire, emerald, ruby, diamond), in a gold
setting. With the crest on, the NEW BEST plaque sits 9 px higher; with the crown, 22 px.

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

Assets are shipped in `media/` and built by `tools/make_art.py` and `tools/make_sounds.py`
from the sources in `art/`:
- Textures are power-of-two TGA files, drawn at 4 texture pixels per UI pixel.
- Coloured textures are drawn in greys and tinted with `SetVertexColor`.

| File | Use |
|---|---|
| `ribbon_mid.tga` | Cloth band, tiles horizontally, tinted per tier |
| `ribbon_side.tga`, `ribbon_trim_side.tga` | Tail + fold, and its gold trim (untinted). The middle trim is drawn with solid lines |
| `glyph.tga`, `glyph_outline.tga` | Jumper silhouette, plain and with outline |
| `shine.tga`, `glow.tga`, `spark.tga`, `star.tga`, `ring.tga` | Effects |
| `rays14.tga`, `rays9.tga` | The two x200 ray sets |
| `bolt1.tga` … `bolt6.tga` | Lightning, 6 frames |
| `caption_band.tga`, `line.tga` | Milestone caption band and its gold lines |
| `icon.tga`, `icon_round.tga` | Addon icon: window portrait, leaderboard notice |
| `icon_small.tga` | Minimap button and AddOns list: a big gold jumper on blue, readable at 16 px |
| `orn_corner.tga`, `orn_crest.tga`, `orn_wing.tga`, `orn_run.tga`, `orn_crown.tga` | Gold ornaments, untinted |
| `gem.tga`, `gem_set.tga` | Gem stone (tinted per gem) and its gold setting |
| `rainbow.tga` | Hue strip multiplied over the band at x1000 |
| `ChangaOne-Italic.ttf` + `OFL.txt` | Count font and its licence |

Sounds are the addon's own short synthesised OGG files in `media/sounds/`. `PlaySoundFile`
has no volume argument, so each sound is pre-mixed at 25 / 50 / 75 / 100 % and the volume
setting picks one (the slider moves in 25 % steps):
- `tick`: every counted jump and the tenth-jump pulse
- `milestone`: x5, x10, x20 and the ornaments
- `tierup`: x25, x50, x100, x200
- `snap`: the snap-out
- `fanfare`: NEW BEST!
- `caption`: the milestone caption

## NEW BEST! (R2.9)

- **Trigger:** a streak above x10 ends and beats the stored best.
- **Sequence (1.8 s hold, then the usual 0.12 s snap-out):**
  - The ribbon and effects return to full alpha within ~0.1 s.
  - The counter pops (amplitude 0.4, 0.3 s).
  - The middle trim flashes and bursts gold sparks.
  - Fanfare sound.
- **Plaque:**
  - "NEW BEST!" in Changa One Italic 17 px, centred 17 px above the ribbon top.
  - Gold face `#ffd76a`, with 3 extrusion layers in dark gold and a 35% drop layer.
  - Pops in with an overshoot over 0.28 s.
  - A soft additive gold glow pulses behind it.
  - Six twinkling 4-point stars around it.
- **Under the ribbon:**
  - "previous xN" in the game font, bold 18 px, with a dark outline.
  - It fades in after 0.2 s.
  - It is hidden when there was no previous best.

## Milestone caption (R2.10)

- **Trigger:** the character's total height (jumps × 1.5 m) passes the next landmark.
  If several are passed at once, only the last one is shown.
- **Placement:** centred above the counter, `26 × scale + 46` px above the counter's
  anchor.
- **Content, two lines in the game font with a dark outline:**
  - "You climbed", 14 px, gold `#f2c75c`
  - `<name> • <height>`, bold 24 px, white

  Heights below 100 km show in m or ft. From 100 km they show in km, or in mi in feet
  mode.
- **Band:** a dark horizontal band (62% black, fading out at both ends, 380 × 62 px),
  with thin gold lines along its top and bottom edges.
- **Motion:**
  - Rises 10 px while fading in (0.25 s).
  - Holds for 2.8 s.
  - Drifts up 8 px while fading out (0.6 s).
- **Sound:** a soft two-tone chime.

## Main window (R6)

- **Frame:**
  - A portrait frame with the addon icon in the round portrait at the top left.
  - The title "Jumpers" and a close button.
  - Three tabs at the bottom: **Personal Stats**, **Leaderboard** (tagged `v2`), **Settings**.
- **Personal Stats:**
  - A **Character / Account** toggle.
  - **Height climbed:** a big number (Changa One), "N jumps × 1.5 m".
  - A progress bar from the last landmark passed (with ✓) to the next one, with
    "Milestone k of 55 · p% there · N jumps to go".
  - **Totals:** a table with Today and All time columns. Rows: Jumps, Floors, Streaks.
  - **Best streak:** Today, 7 days, 30 days, Year, All time, each coloured by its tier.
  - **All milestones:** a collapsible list showing passed ✓, next highlighted and the
    rest dimmed.
- **Leaderboard:** v1 shows a short "coming in v2" notice. The v2 layout is:
  - period buttons (Today / 7 days / 30 days / Year)
  - a "Players online" checkbox
  - a table of rank, player (class colour, online dot), best streak (tier colour) and
    when it was set
  - your own row highlighted
- **Settings** (R6.3):
  - Counter group (show, size slider with steppers, unlock + reset, reduced effects),
    with a live preview of the counter beside it and a "Play sample streak" button.
  - Sound volume slider ("Off" at 0%).
  - Progress: a "Reset progress" button (with a confirmation) that clears character and
    account stats. Meant for testing.
  - Metres / Feet toggle.
  - Minimap button checkbox.
- **Minimap button:**
  - The addon icon, via LibDataBroker + LibDBIcon.
  - Tooltip: "Jumpers", "Best streak today: xN", "Click open · Drag move".

## Milestones (R3.3)

Heights are in metres. Rows marked WoW are estimates and are measured in game before
release.

| # | Landmark | m | | # | Landmark | m |
|---|---|---|---|---|---|---|
| 1 | Durotar zeppelin tower (WoW) | 20 | | 29 | Lowest satellite orbits | 160,000 |
| 2 | Statue of Liberty | 93 | | 30 | Sputnik 1, lowest point | 215,000 |
| 3 | Great Pyramid of Giza | 139 | | 31 | Vostok 1, first human in space | 327,000 |
| 4 | Space Needle | 184 | | 32 | International Space Station | 420,000 |
| 5 | Karazhan (WoW) | 250 | | 33 | Starlink satellites | 550,000 |
| 6 | Eiffel Tower | 330 | | 34 | Iridium satellites | 780,000 |
| 7 | Empire State Building | 443 | | 35 | Ceres, edge to edge | 940,000 |
| 8 | Tokyo Skytree | 634 | | 36 | Makemake, edge to edge | 1,430,000 |
| 9 | Burj Khalifa | 828 | | 37 | Pluto, edge to edge | 2,377,000 |
| 10 | Teldrassil (WoW) | 1,100 | | 38 | The Moon, edge to edge | 3,474,000 |
| 11 | Ben Nevis | 1,345 | | 39 | Mercury, edge to edge | 4,879,000 |
| 12 | Mount Hoverla | 2,061 | | 40 | Mars, edge to edge | 6,779,000 |
| 13 | Mount Olympus | 2,918 | | 41 | O3b satellites | 8,062,000 |
| 14 | Mount Fuji | 3,776 | | 42 | Earth, edge to edge | 12,742,000 |
| 15 | Mont Blanc | 4,806 | | 43 | GPS satellites | 20,200,000 |
| 16 | Kilimanjaro | 5,895 | | 44 | Geostationary orbit | 35,786,000 |
| 17 | Aconcagua | 6,961 | | 45 | Once around the Earth | 40,075,000 |
| 18 | Mount Everest | 8,849 | | 46 | Neptune, edge to edge | 49,244,000 |
| 19 | Airliners cruise here | 11,000 | | 47 | Twice around the Earth | 80,150,000 |
| 20 | Ozone layer | 15,000 | | 48 | Saturn, edge to edge | 116,460,000 |
| 21 | Concorde cruised here | 18,000 | | 49 | Jupiter, edge to edge | 139,820,000 |
| 22 | SR-71 Blackbird record | 25,929 | | 50 | Saturn's rings, edge to edge | 273,000,000 |
| 23 | Highest crewed balloon, 1961 | 34,668 | | 51 | The Moon | 384,400,000 |
| 24 | Highest skydive | 41,420 | | 52 | To the Moon and back | 768,800,000 |
| 25 | Highest weather balloon | 53,000 | | 53 | The Sun, edge to edge | 1,392,700,000 |
| 26 | Shooting stars burn up | 75,000 | | 54 | The Moon's orbit, all the way round | 2,415,000,000 |
| 27 | Kármán line, edge of space | 100,000 | | 55 | Around the Sun | 4,375,000,000 |
| 28 | Northern lights | 130,000 | |  | | |

The space end is meant as a lifelong dream. At 5,000 jumps a day the Moon's diameter
takes about 1.3 years, and the distance to the Moon about 140 years.
