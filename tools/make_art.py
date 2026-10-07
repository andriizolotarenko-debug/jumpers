"""Builds the counter textures in media/ from the sources in art/.

Everything that gets tinted in game is drawn in greys. Shapes follow UI-SPEC.md.
Run: python3 tools/make_art.py   (needs Pillow and numpy)
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")
MEDIA = os.path.join(ROOT, "media")

PX = 4          # texture pixels per UI pixel
SS = 4          # supersampling while drawing
H = 28          # ribbon height, UI px
B0 = 0.75       # cloth brightness; the game tints with cloth / B0

GOLD = [(0.0, (0xff, 0xe7, 0xa0)), (0.5, (0xd9, 0xa6, 0x40)), (1.0, (0x9c, 0x6a, 0x1c))]
RIM = (0x1a, 0x11, 0x07)
EDGE = (20, 12, 5, int(0.45 * 255))


def save(img, name):
    img.save(os.path.join(MEDIA, name + ".tga"))


def lerp(a, b, t):
    return a + (b - a) * t


def gold_at(t):
    t = min(1.0, max(0.0, t))
    for (t0, c0), (t1, c1) in zip(GOLD, GOLD[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            return tuple(int(lerp(c0[i], c1[i], k)) for i in range(3))
    return GOLD[-1][1]


def cloth_value(y_ui):
    """Brightness of the cloth at UI height y (y down, band centre = 0)."""
    t = (y_ui + H / 2) / (H + 6)
    c = B0
    if t < 0.45:
        a = 0.30 * (1 - t / 0.45)
        c = c * (1 - a) + a
    else:
        a = 0.38 * (t - 0.45) / 0.55
        c = c * (1 - a)
    return c


def noise(w, h, seed):
    rnd = np.random.default_rng(seed)
    n = rnd.random((h, w)) * 60 + 110
    n[:, ::7] += 25
    return (n / 255.0 - 0.6) * 0.12


# ---------- ribbon middle: a horizontally tileable cloth strip ----------
def ribbon_mid():
    w, h = 128, 128                       # 32 x 32 UI px; the band uses the top 28 UI px
    nz = noise(w, h, 1)
    a = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        y_ui = y / PX - H / 2
        v = np.clip(cloth_value(y_ui) + nz[y], 0, 1) * 255
        a[y, :, 0] = a[y, :, 1] = a[y, :, 2] = v
        a[y, :, 3] = 255
    save(Image.fromarray(a), "ribbon_mid")


# ---------- ribbon sides: tail + fold, in a 40 x 36 UI px box ----------
SIDE_BOX = (-26, -12, 14, 24)   # x0, y0, x1, y1 relative to the band's left edge and centre (y down)


def side_polys():
    h, d = H / 2, 6
    tail = [(10, -h + d), (-22, -h + d), (-14, d), (-22, h + d), (10, h + d)]
    fold = [(0, h), (10, h + d), (10, h)]
    return tail, fold


def to_canvas(pts, scale):
    bx, by = SIDE_BOX[0], SIDE_BOX[1]
    return [((x - bx) * scale, (y - by) * scale) for x, y in pts]


def ribbon_side():
    scale = PX * SS
    bw, bh = SIDE_BOX[2] - SIDE_BOX[0], SIDE_BOX[3] - SIDE_BOX[1]
    W, Hh = bw * scale, bh * scale
    tail, fold = side_polys()
    # brightness per row, shaded per part
    mask_t = Image.new("L", (W, Hh), 0)
    ImageDraw.Draw(mask_t).polygon(to_canvas(tail, scale), fill=255)
    mask_f = Image.new("L", (W, Hh), 0)
    ImageDraw.Draw(mask_f).polygon(to_canvas(fold, scale), fill=255)
    rows = np.array([cloth_value(SIDE_BOX[1] + (y + 0.5) / scale) for y in range(Hh)])
    mt = np.asarray(mask_t, float) / 255
    mf = np.asarray(mask_f, float) / 255
    val = rows[:, None] * (1 - 0.35) * mt * (1 - mf) + rows[:, None] * (1 - 0.7) * mf
    alpha = np.clip(mt + mf, 0, 1)
    rgb = np.clip(val / np.maximum(alpha, 1e-6), 0, 1)
    img = np.dstack([rgb * 255] * 3 + [alpha * 255]).astype(np.uint8)
    im = Image.fromarray(img)
    # faint 1 px edge
    edge = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
    dr = ImageDraw.Draw(edge)
    for poly in (tail, fold):
        pts = to_canvas(poly, scale)
        dr.line(pts + [pts[0]], fill=EDGE, width=int(1 * scale), joint="curve")
    im = Image.alpha_composite(im, edge)
    im = im.resize((bw * PX, bh * PX), Image.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.paste(im, (0, 0))
    save(canvas, "ribbon_side")

    # trim: dark rim 3.4 px + gold 1.6 px, gold runs top to bottom of the band
    trim = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
    dr = ImageDraw.Draw(trim)
    for poly in (tail, fold):
        pts = to_canvas(poly, scale)
        dr.line(pts + [pts[0], pts[1]], fill=RIM + (255,), width=int(3.4 * scale), joint="curve")
    gold_mask = Image.new("L", (W, Hh), 0)
    gd = ImageDraw.Draw(gold_mask)
    for poly in (tail, fold):
        pts = to_canvas(poly, scale)
        gd.line(pts + [pts[0], pts[1]], fill=255, width=int(1.6 * scale), joint="curve")
    grad = np.zeros((Hh, W, 4), np.uint8)
    for y in range(Hh):
        y_ui = SIDE_BOX[1] + (y + 0.5) / scale
        grad[y, :, :3] = gold_at((y_ui + H / 2) / H)
        grad[y, :, 3] = 255
    gold = Image.fromarray(grad)
    gold.putalpha(gold_mask)
    trim = Image.alpha_composite(trim, gold)
    trim = trim.resize((bw * PX, bh * PX), Image.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.paste(trim, (0, 0))
    save(canvas, "ribbon_trim_side")
    return bw, bh


# ---------- glyph ----------
def glyph():
    src = Image.open(os.path.join(ART, "glyph_source.png")).convert("RGBA")
    gh = 192
    gw = round(src.width * gh / src.height)
    g = src.resize((gw * SS, gh * SS), Image.LANCZOS)
    alpha = g.split()[3]
    C = 256 * SS
    ox, oy = (C - gw * SS) // 2, (C - gh * SS) // 2
    plain_a = Image.new("L", (C, C), 0)
    plain_a.paste(alpha, (ox, oy))
    white = Image.new("RGBA", (C, C), (255, 255, 255, 0))
    white.putalpha(plain_a)
    out_plain = white.resize((256, 256), Image.LANCZOS)
    save(out_plain, "glyph")
    # outline: dilate by ~1.6 UI px (UI glyph height 33.6 = 192 texture px)
    r = 1.7 * 192 / 33.6 * SS
    base = np.asarray(plain_a)
    dil = base.copy()
    for k in range(32):
        a = k / 32 * 2 * math.pi
        for rr in (r, r * 0.5):
            dx, dy = int(round(math.cos(a) * rr)), int(round(math.sin(a) * rr))
            dil = np.maximum(dil, np.roll(np.roll(base, dy, 0), dx, 1))
    outline = Image.new("RGBA", (C, C), (0x14, 0x0b, 0x05, 0))
    outline.putalpha(Image.fromarray(dil))
    out = Image.alpha_composite(outline, white).resize((256, 256), Image.LANCZOS)
    save(out, "glyph_outline")
    return gw, gh, (256 - gw) // 2, (256 - gh) // 2


# ---------- effects ----------
def radial(size, fn):
    c = (size - 1) / 2
    y, x = np.mgrid[0:size, 0:size]
    r = np.minimum(np.hypot(x - c, y - c) / c, 1.0)
    a = np.clip(fn(r), 0, 1)
    img = np.dstack([np.full_like(a, 255)] * 3 + [a * 255]).astype(np.uint8)
    return Image.fromarray(img)


def effects():
    save(radial(128, lambda r: (1 - r) ** 1.6), "glow")
    save(radial(32, lambda r: np.where(r < 0.3, 1, (1 - r) / 0.7) ** 1.5), "spark")
    # 4-point star
    s = 64 * SS
    im = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(im)
    c, R, w = s / 2, s / 2 - 2, s * 0.07
    d.polygon([(c, c - R), (c + w, c - w), (c + R, c), (c + w, c + w), (c, c + R), (c - w, c + w), (c - R, c), (c - w, c - w)], fill=255)
    im = im.filter(ImageFilter.GaussianBlur(SS)).resize((64, 64), Image.LANCZOS)
    star = Image.new("RGBA", (64, 64), (255, 255, 255, 0))
    star.putalpha(im)
    save(star, "star")
    # ring for tier-up
    save(radial(128, lambda r: np.exp(-((r - 0.86) / 0.06) ** 2)), "ring")
    # shine: a soft slanted bar, 64 x 128
    w, h = 64, 128
    y, x = np.mgrid[0:h, 0:w]
    xs = x - w / 2 + (y - h / 2) * 0.28
    a = np.exp(-(xs / 7.0) ** 2) * 0.9
    img = np.dstack([np.full_like(a, 255)] * 3 + [a * 255]).astype(np.uint8)
    save(Image.fromarray(img), "shine")
    # rays
    for cnt, width, name in ((14, 0.10, "rays14"), (9, 0.16, "rays9")):
        size = 256
        c = (size - 1) / 2
        y, x = np.mgrid[0:size, 0:size]
        ang = np.arctan2(y - c, x - c)
        r = np.hypot(x - c, y - c) / c
        step = 2 * math.pi / cnt
        dist = np.abs(((ang + step / 2) % step) - step / 2)
        wedge = np.clip(1 - dist / (width / 2), 0, 1) ** 0.6
        a = wedge * np.clip(1 - r, 0, 1) ** 1.2 * np.clip(r * 6, 0, 1)
        img = np.dstack([np.full_like(a, 255)] * 3 + [a * 255]).astype(np.uint8)
        save(Image.fromarray(img), name)
    # lightning: 6 bolts, each horizontal across a 128 x 32 strip (y centre = 16)
    for v in range(6):
        seed = v * 977 + 13

        def rnd():
            nonlocal seed
            seed = (seed * 16807) % 2147483647
            return seed / 2147483647

        offs = [0 if i in (0, 8) else (rnd() - 0.5) * 2 for i in range(9)]
        at, ln, dr_ = 2 + int(rnd() * 4), 0.22 + rnd() * 0.2, (-1 if rnd() < 0.5 else 1)
        W, Hh = 128 * SS, 32 * SS
        amp = 4.5 * SS * 128 / 64 / 2
        pts = [(4 * SS + (W - 8 * SS) * i / 8, Hh / 2 + o * amp) for i, o in enumerate(offs)]
        b = pts[at]
        br = (b[0] + (W - 8 * SS) * ln, b[1] + amp * dr_ * 1.6)
        glow_l = Image.new("L", (W, Hh), 0)
        core_l = Image.new("L", (W, Hh), 0)
        for layer, wdt, val in ((glow_l, 6 * SS, 110), (core_l, 2 * SS, 255)):
            dd = ImageDraw.Draw(layer)
            dd.line(pts, fill=val, width=wdt, joint="curve")
            dd.line([b, br], fill=val, width=max(1, wdt * 2 // 3), joint="curve")
        glow_l = glow_l.filter(ImageFilter.GaussianBlur(2 * SS))
        a = np.maximum(np.asarray(glow_l, float), np.asarray(core_l, float))
        # core is whiter: encode as white with alpha; colour comes from the tint
        img = np.dstack([np.full_like(a, 255)] * 3 + [a]).astype(np.uint8)
        im = Image.fromarray(img).resize((128, 32), Image.LANCZOS)
        save(im, "bolt%d" % (v + 1))


# ---------- caption band + soft line ----------
def caption():
    w, h = 256, 64
    x = np.linspace(-1, 1, w)
    ends = np.clip((1 - np.abs(x)) / 0.35, 0, 1)
    ends = ends * ends * (3 - 2 * ends)
    a = np.tile(ends * 0.62, (h, 1))
    img = np.dstack([np.zeros_like(a)] * 3 + [a * 255]).astype(np.uint8)
    save(Image.fromarray(img), "caption_band")
    a = np.tile(ends, (8, 1))
    a[0, :] = a[-1, :] = 0
    img = np.dstack([np.full_like(a, 255)] * 3 + [a * 255]).astype(np.uint8)
    save(Image.fromarray(img), "line")


# ---------- addon icon ----------
def icon():
    src = Image.open(os.path.join(ART, "icon_source.png")).convert("RGBA")
    sq = src.resize((128, 128), Image.LANCZOS)
    save(sq, "icon")
    m = Image.new("L", (128 * SS, 128 * SS), 0)
    ImageDraw.Draw(m).ellipse((0, 0, 128 * SS - 1, 128 * SS - 1), fill=255)
    m = m.resize((128, 128), Image.LANCZOS)
    rnd = sq.copy()
    rnd.putalpha(Image.fromarray(np.minimum(np.asarray(sq.split()[3]), np.asarray(m)).astype(np.uint8)))
    save(rnd, "icon_round")


if __name__ == "__main__":
    os.makedirs(MEDIA, exist_ok=True)
    random.seed(1)
    ribbon_mid()
    print("side box", ribbon_side())
    print("glyph w,h,x,y in 256 canvas:", glyph())
    effects()
    caption()
    icon()
    print("ok")
