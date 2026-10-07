-- The combo counter (UI-SPEC: Anatomy ... NEW BEST!). One instance follows the streak,
-- another one is the preview in the Settings tab.
local _, ns = ...
local Tiers = ns.Tiers

local Counter = {}
Counter.__index = Counter
ns.Counter = Counter

local M = ns.MEDIA
local H = 28                       -- ribbon height
local GH = H * 1.2                 -- glyph height
local GW = GH * 150 / 192          -- glyph width (texture: 150 x 192 inside 256 x 256)
local GT = GH * 256 / 192          -- glyph texture size
local B0 = 0.75                    -- cloth texture brightness
local NUM_SIZE, X_SIZE = 25, 18
local NUM_Y, X_Y = 0.8, -1.7       -- puts both baselines at cap-height / 2 below centre
-- Advance widths from the font file (Changa One: "x" 0.54 em, digits 0.6 em). Measuring in
-- game is unreliable: outlined text reports a wider string.
local X_W, DIGIT_W = 0.54 * X_SIZE, 0.6 * NUM_SIZE
local DEPTH = Tiers.DEPTH
local SIDE_U, SIDE_V = 160 / 256, 144 / 256

local GOLD = Tiers.hex("#f2c75c")
local SPARK_GOLD = Tiers.mix(GOLD, { 1, 1, 1 }, 0.25)
local GOLD_TOP, GOLD_BOTTOM = Tiers.hex("#ffe7a0"), Tiers.hex("#9c6a1c")
local PLAQUE_GOLD = Tiers.hex("#ffd76a")
local PLAQUE_SILVER, PLAQUE_SLATE = Tiers.hex("#e4eef7"), Tiers.hex("#6f8aa3")
local RIM = Tiers.hex("#1a1107")
local WHITE, BLACK = { 1, 1, 1 }, { 0, 0, 0 }
local mix = Tiers.mix

-- Gold ornaments and gems by group (Tiers.ORNAMENTS: x75, x150, x350, x400, x500, x750).
-- ax: anchored to the band's Left / Right edge or its Centre; x, y, w, h in UI px (y up);
-- u, v crop the texture; fh / fv mirror it; gem = stone colour (shape "rhombus" or octagon);
-- side = drawn with the tails; until = hidden from that group on.
local SAPPHIRE, EMERALD, RUBY, DIAMOND = { 0.3, 0.6, 1 }, { 0.25, 0.95, 0.5 }, { 1, 0.2, 0.25 }, { 0.92, 0.97, 1 }
local PEARL = { 1, 0.95, 0.86 }
local PIECES = {}
do
  local function add(t) PIECES[#PIECES + 1] = t end
  local corners = { { "L", -2, 16 }, { "R", 2, 16, true }, { "L", -2, -16, false, true }, { "R", 2, -16, true, true } }
  for _, c in ipairs(corners) do
    add({ g = 1, tex = "orn_corner", ax = c[1], x = c[2], y = c[3], w = 12, h = 12, u = 48 / 64, v = 48 / 64,
      fh = c[4], fv = c[5] })
  end
  add({ g = 2, tex = "orn_crest", ax = "C", x = 0, y = 21, w = 48, h = 20, u = 192 / 256, v = 80 / 128, ["until"] = 6 })
  add({ g = 2, tex = "orn_crest", ax = "C", x = 0, y = -21, w = 48, h = 20, u = 192 / 256, v = 80 / 128, fv = true })
  add({ g = 3, gem = RUBY, shape = "rhombus", side = true, ax = "L", x = -24, y = -6, w = 12, h = 16 })
  add({ g = 3, gem = RUBY, shape = "rhombus", side = true, ax = "R", x = 24, y = -6, w = 12, h = 16 })
  local runs = { { "L", 18, 19.5 }, { "R", -18, 19.5, true }, { "L", 18, -19.5, false, true }, { "R", -18, -19.5, true, true } }
  for _, c in ipairs(runs) do
    add({ g = 4, tex = "orn_run", ax = c[1], x = c[2], y = c[3], w = 24, h = 8, u = 96 / 128, v = 1, fh = c[4], fv = c[5] })
  end
  add({ g = 4, gem = SAPPHIRE, ax = "C", x = 0, y = 20, w = 9, h = 9, ["until"] = 6 })
  add({ g = 4, gem = SAPPHIRE, ax = "C", x = 0, y = -20, w = 9, h = 9 })
  for _, c in ipairs({ { "L", -2.8, 16.5 }, { "R", 2.8, 16.5 }, { "L", -2.8, -16.5 }, { "R", 2.8, -16.5 } }) do
    add({ g = 5, gem = EMERALD, ax = c[1], x = c[2], y = c[3], w = 5.5, h = 5.5 })
  end
  for _, c in ipairs({ { "L", 18, 19.7 }, { "R", -18, 19.7 }, { "L", 18, -19.7 }, { "R", -18, -19.7 } }) do
    add({ g = 5, gem = DIAMOND, ax = c[1], x = c[2], y = c[3], w = 4.5, h = 4.5 })
  end
  add({ g = 6, tex = "orn_crown", ax = "C", x = 0, y = 26, w = 60, h = 32, u = 240 / 256, v = 1 })
  for _, c in ipairs({
    { DIAMOND, 0, 40, 6 }, { RUBY, -11, 35, 4.5 }, { RUBY, 11, 35, 4.5 }, { PEARL, -23, 31, 3.5 }, { PEARL, 23, 31, 3.5 },
    { SAPPHIRE, 0, 16, 6 }, { RUBY, -14, 16, 4 }, { RUBY, 14, 16, 4 },
  }) do
    add({ g = 6, gem = c[1], ax = "C", x = c[2], y = c[3], w = c[4], h = c[4] })
  end
end

local function clamp01(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
local function smooth(x) x = clamp01(x); return x * x * (3 - 2 * x) end
local function rand(i, k) local v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453; return v - math.floor(v) end

local function noSnap(t)
  if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
  if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
  return t
end

local function tex(frame, layer, sub, file, blend)
  local t = frame:CreateTexture(nil, layer, nil, sub or 0)
  if file then t:SetTexture(M .. file) end
  if blend then t:SetBlendMode(blend) end
  return noSnap(t)
end

local function solid(frame, layer, sub, c, a, blend)
  local t = frame:CreateTexture(nil, layer, nil, sub or 0)
  t:SetColorTexture(c[1], c[2], c[3], a or 1)
  if blend then t:SetBlendMode(blend) end
  return noSnap(t)
end

local function gradient(t, top, bottom)
  t:SetColorTexture(1, 1, 1, 1)
  if CreateColor and t.SetGradient then
    local ok = pcall(t.SetGradient, t, "VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1),
      CreateColor(top[1], top[2], top[3], 1))
    if ok then return end
  end
  local c = mix(top, bottom, 0.5)
  t:SetColorTexture(c[1], c[2], c[3], 1)
end

local function place(r, x, y, w, h)
  r:ClearAllPoints()
  r:SetPoint("CENTER", r:GetParent(), "CENTER", x, y)
  r:SetSize(math.max(w, 0.01), math.max(h, 0.01))
end

local function tint(t, c, a)
  t:SetVertexColor(c[1], c[2], c[3], a or 1)
end

local function setFont(fs, size, flags)
  fs:SetFont(ns.FONT, size, flags or "")
  if not fs:GetFont() then
    fs:SetFont(STANDARD_TEXT_FONT, size, flags or "")
  end
end

local function layer(parent, level)
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("CENTER")
  f:SetSize(1, 1)
  f:SetFrameLevel(level)
  return f
end

-- One child frame per depth (drop, DEPTH ... 1, face). Font strings have no sublevels,
-- so separate frame levels are what keeps the extrusion behind the face.
local function depthFrames(parent)
  local level = parent:GetFrameLevel()
  local f = { layers = {} }
  f.drop = layer(parent, level + 1)
  for d = DEPTH, 1, -1 do f.layers[d] = layer(parent, level + 2 + (DEPTH - d)) end
  f.face = layer(parent, level + 2 + DEPTH)
  return f
end

-- A text in the extruded style: drop + DEPTH copies + face, or one outlined face.
local function textStack(frames, size)
  local s = { size = size, layers = {} }
  s.drop = frames.drop:CreateFontString(nil, "ARTWORK")
  for d = DEPTH, 1, -1 do
    s.layers[d] = frames.layers[d]:CreateFontString(nil, "ARTWORK")
  end
  s.face = frames.face:CreateFontString(nil, "ARTWORK")
  for _, fs in ipairs({ s.drop, s.face, unpack(s.layers) }) do
    setFont(fs, size)
    fs:SetJustifyH("LEFT")
  end
  return s
end

local function stackDo(s, fn)
  fn(s.drop); fn(s.face)
  for d = 1, DEPTH do fn(s.layers[d]) end
end

function Counter.New(parent, opts)
  opts = opts or {}
  local self = setmetatable({}, Counter)
  self.static = false
  self.userScale = 1
  self.reduced = false
  self.volume = opts.silent and 0 or nil

  local root = CreateFrame("Frame", nil, parent)
  root:SetSize(1, 1)
  root:Hide()
  self.root = root
  local base = root:GetFrameLevel()

  local inner = CreateFrame("Frame", nil, root)
  inner:SetPoint("CENTER")
  inner:SetSize(1, 1)
  self.inner = inner

  -- behind everything: rays and the lightning aura
  local back = layer(inner, base + 1)
  self.back = back
  self.rays = {
    tex(back, "BACKGROUND", 0, "rays14", "ADD"),
    tex(back, "BACKGROUND", 1, "rays9", "ADD"),
  }
  self.aura = tex(back, "BORDER", 0, "glow", "ADD")

  -- sides: tails + folds, their trim and its flash
  local sides = layer(inner, base + 2)
  self.sides = sides
  self.tail = { tex(sides, "ARTWORK", 0, "ribbon_side"), tex(sides, "ARTWORK", 0, "ribbon_side") }
  self.tailTrim = { tex(sides, "ARTWORK", 1, "ribbon_trim_side"), tex(sides, "ARTWORK", 1, "ribbon_trim_side") }
  self.tailFlash = { tex(sides, "ARTWORK", 2, "ribbon_trim_side", "ADD"), tex(sides, "ARTWORK", 2, "ribbon_trim_side", "ADD") }
  self.tail[1]:SetTexCoord(0, SIDE_U, 0, SIDE_V)
  self.tailTrim[1]:SetTexCoord(0, SIDE_U, 0, SIDE_V)
  self.tailFlash[1]:SetTexCoord(0, SIDE_U, 0, SIDE_V)
  self.tail[2]:SetTexCoord(SIDE_U, 0, 0, SIDE_V)
  self.tailTrim[2]:SetTexCoord(SIDE_U, 0, 0, SIDE_V)
  self.tailFlash[2]:SetTexCoord(SIDE_U, 0, 0, SIDE_V)

  -- middle: cloth band, faint edge, trim (rim + gold), flashes
  local mid = layer(inner, base + 3)
  self.mid = mid
  self.band = mid:CreateTexture(nil, "ARTWORK", nil, 0)
  self.band:SetTexture(M .. "ribbon_mid", "REPEAT", "CLAMP")
  noSnap(self.band)
  self.edge, self.rim, self.gold, self.goldFlash = {}, {}, {}, {}
  for i = 1, 4 do
    self.edge[i] = solid(mid, "ARTWORK", 1, { 20 / 255, 12 / 255, 5 / 255 }, 0.45)
    self.rim[i] = solid(mid, "ARTWORK", 2, RIM)
    self.gold[i] = solid(mid, "ARTWORK", 3, WHITE)
    self.goldFlash[i] = solid(mid, "OVERLAY", 0, mix(GOLD, WHITE, 0.55), 1, "ADD")
  end
  self.gold[1]:SetColorTexture(GOLD_TOP[1], GOLD_TOP[2], GOLD_TOP[3], 1)
  self.gold[2]:SetColorTexture(GOLD_BOTTOM[1], GOLD_BOTTOM[2], GOLD_BOTTOM[3], 1)
  gradient(self.gold[3], GOLD_TOP, GOLD_BOTTOM)
  gradient(self.gold[4], GOLD_TOP, GOLD_BOTTOM)
  self.flash = solid(mid, "OVERLAY", 1, WHITE, 1, "ADD")

  -- gold ornaments and gems (UI-SPEC: Gold ornaments), one texture per piece
  self.pieces = {}
  for i, def in ipairs(PIECES) do
    local frame = def.side and sides or mid
    local p = { def = def }
    if def.gem then
      local file = def.shape == "rhombus" and "gem_rhombus" or "gem"
      p.set = tex(frame, "ARTWORK", 5, file .. "_set")
      p.tex = tex(frame, "ARTWORK", 6, file)
      tint(p.tex, def.gem)
    else
      p.tex = tex(frame, "ARTWORK", 4, def.tex)
      local u, v = def.u or 1, def.v or 1
      p.tex:SetTexCoord(def.fh and u or 0, def.fh and 0 or u, def.fv and v or 0, def.fv and 0 or v)
    end
    self.pieces[i] = p
  end
  -- x1000: a hue strip multiplied over the grey band
  self.rainbow = mid:CreateTexture(nil, "ARTWORK", nil, 1)
  self.rainbow:SetTexture(M .. "rainbow", "REPEAT", "CLAMP")
  self.rainbow:SetBlendMode("MOD")
  noSnap(self.rainbow)
  self.rainbow:Hide()

  -- x25 shine, clipped to the band
  local clip = CreateFrame("Frame", nil, inner)
  clip:SetFrameLevel(base + 4)
  clip:SetClipsChildren(true)
  self.clip = clip
  self.shine = tex(clip, "ARTWORK", 0, "shine", "ADD")

  -- core: glyph + count
  local core = layer(inner, base + 5)
  self.core = core
  local depth = depthFrames(core)
  self.glyphDrop = tex(depth.drop, "BORDER", 0, "glyph")
  self.glyphLayers = {}
  for d = DEPTH, 1, -1 do
    self.glyphLayers[d] = tex(depth.layers[d], "BORDER", 0, "glyph")
  end
  self.glyphFace = tex(depth.face, "BORDER", 0, "glyph")
  self.xText = textStack(depth, X_SIZE)
  self.numText = textStack(depth, NUM_SIZE)

  -- in front: lightning, sparks, ring, trim bursts
  local front = layer(inner, base + 6 + DEPTH + 2)
  self.front = front
  self.bolts = {}
  for i = 1, 6 do self.bolts[i] = tex(front, "ARTWORK", 0, "bolt1", "ADD") end
  self.sparks = {}
  for i = 1, 16 do self.sparks[i] = tex(front, "ARTWORK", 1, (i - 1) % 3 == 0 and "star" or "spark", "ADD") end
  self.ring = tex(front, "OVERLAY", 0, "ring", "ADD")
  self.particles = {}
  for i = 1, 90 do
    self.particles[i] = tex(front, "OVERLAY", 1, (i - 1) % 4 == 0 and "star" or "spark", "ADD")
    tint(self.particles[i], mix(GOLD, WHITE, 0.25))
  end

  -- NEW BEST plaque + "previous xN"
  local plaque = layer(inner, base + 7 + DEPTH + 2)
  self.plaque = plaque
  self.plaqueGlow = tex(plaque, "BACKGROUND", 0, "glow", "ADD")
  tint(self.plaqueGlow, PLAQUE_GOLD)
  self.plaqueText = textStack(depthFrames(plaque), 17)
  self.stars = {}
  for i = 1, 6 do
    self.stars[i] = tex(plaque, "OVERLAY", 0, "star", "ADD")
    tint(self.stars[i], mix(PLAQUE_GOLD, WHITE, 0.4))
  end
  self.prev = layer(inner, base + 8 + 2 * (DEPTH + 2))
  self.prevText = self.prev:CreateFontString(nil, "OVERLAY")
  self.prevText:SetFont(STANDARD_TEXT_FONT, 18, "THICKOUTLINE")
  self.prevText:SetTextColor(0.92, 0.92, 0.92)
  self.prevText:SetPoint("CENTER", self.prev, "CENTER", 0, -H / 2 - 16)

  self:PreparePlaque()
  self.bursts = {}
  self.n = 0
  self.flag = 1
  self.scale = 1
  root:SetScript("OnUpdate", function(_, elapsed) self:Update(GetTime(), elapsed) end)
  return self
end

-- The plaque reads NEW BEST! in gold (all-time record) or BEST TODAY! in silver (today's).
function Counter:PreparePlaque(kind)
  local s = self.plaqueText
  local today = kind == "today"
  local face = today and PLAQUE_SILVER or PLAQUE_GOLD
  stackDo(s, function(fs) fs:SetText(today and "BEST TODAY!" or "NEW BEST!"); fs:SetJustifyH("CENTER") end)
  s.face:SetTextColor(face[1], face[2], face[3])
  s.drop:SetTextColor(0, 0, 0, 0.35)
  for d = 1, 3 do
    local c = mix(today and PLAQUE_SLATE or PLAQUE_GOLD, BLACK, 0.45 + 0.1 * d)
    s.layers[d]:SetTextColor(c[1], c[2], c[3])
  end
  tint(self.plaqueGlow, today and PLAQUE_SILVER or PLAQUE_GOLD)
  for i = 1, 6 do tint(self.stars[i], mix(face, WHITE, 0.4)) end
  s.layers[4]:Hide()
  place(s.face, 0, 1.5, 200, 24)
  for d = 1, 3 do place(s.layers[d], 0, 1.5 - d, 200, 24) end
  place(s.drop, 0, 1.5 - 3 - 1.5, 200, 24)
  place(self.plaqueGlow, 0, 0, 150, 48)
  local spots = { { -62, 8 }, { -48, -10 }, { -70, -4 }, { 62, 9 }, { 50, -11 }, { 71, -3 } }
  self.starSpots = spots
  for i = 1, 6 do place(self.stars[i], spots[i][1], spots[i][2], 12, 12) end
  self.plaque:Hide()
  self.prev:Hide()
end

-- ---------- layout: everything that depends on n ----------

function Counter:Layout(n)
  local look = Tiers.look(n)
  self.look = look
  local style = look.extruded and "extrude" or "outline"
  local num = tostring(n)
  local xs, ns_ = self.xText, self.numText
  if style ~= self.style then
    self.style = style
    for _, s in ipairs({ xs, ns_ }) do
      setFont(s.face, s.size, style == "outline" and "THICKOUTLINE" or "")
      stackDo(s, function(fs) if fs ~= s.face then fs:SetShown(style == "extrude") end end)
    end
    self.glyphFace:SetTexture(M .. (style == "outline" and "glyph_outline" or "glyph"))
    self.glyphDrop:SetShown(style == "extrude")
    for d = 1, DEPTH do self.glyphLayers[d]:SetShown(style == "extrude") end
  end
  stackDo(xs, function(fs) fs:SetText("x") end)
  stackDo(ns_, function(fs) fs:SetText(num) end)

  local xW, nW = X_W, #num * DIGIT_W
  local bw = 9 + GW + 5 + xW + 2 + nW + 12
  local x0, x1 = -bw / 2, bw / 2
  self.bw, self.x0, self.x1 = bw, x0, x1
  self.halfW = bw / 2 + 22

  -- band and trim
  place(self.band, 0, 0, bw, H)
  self.band:SetTexCoord(0, bw / 32, 0, H / 32)
  local h = H / 2
  place(self.edge[1], 0, h, bw, 1); place(self.edge[2], 0, -h, bw, 1)
  place(self.edge[3], x0, 0, 1, H); place(self.edge[4], x1, 0, 1, H)
  place(self.rim[1], 0, h, bw + 3.4, 3.4); place(self.rim[2], 0, -h, bw + 3.4, 3.4)
  place(self.rim[3], x0, 0, 3.4, H + 3.4); place(self.rim[4], x1, 0, 3.4, H + 3.4)
  for i, g in ipairs({ self.gold, self.goldFlash }) do
    local w = i == 1 and 1.6 or 3.2
    place(g[1], 0, h, bw + w, w); place(g[2], 0, -h, bw + w, w)
    place(g[3], x0, 0, w, H + w); place(g[4], x1, 0, w, H + w)
  end
  place(self.flash, 0, 0, bw, H)
  self.clip:ClearAllPoints()
  self.clip:SetPoint("CENTER", self.inner, "CENTER", 0, 0)
  self.clip:SetSize(bw, H)
  place(self.tail[1], x0 - 6, -6, 40, 36); place(self.tail[2], x1 + 6, -6, 40, 36)
  for i = 1, 2 do
    local x = i == 1 and x0 - 6 or x1 + 6
    place(self.tailTrim[i], x, -6, 40, 36)
    place(self.tailFlash[i], x, -6, 40, 36)
  end

  -- glyph and text
  local gx = x0 + 9 + GW / 2
  local textX = x0 + 9 + GW + 5
  local function put(r, dy, isText, x, baseY)
    r:ClearAllPoints()
    if isText then
      r:SetPoint("LEFT", r:GetParent(), "CENTER", x, baseY + dy)
    else
      place(r, gx, 1 + dy, GT, GT)
    end
  end
  local top = style == "extrude" and 2 or 0
  put(self.glyphFace, top)
  put(self.glyphDrop, -3.5)
  for d = 1, DEPTH do put(self.glyphLayers[d], 2 - d) end
  for _, item in ipairs({ { xs, textX, X_Y }, { ns_, textX + xW + 2, NUM_Y } }) do
    local s, x, y = item[1], item[2], item[3]
    put(s.face, top, true, x, y)
    put(s.drop, -3.5, true, x, y)
    for d = 1, DEPTH do put(s.layers[d], 2 - d, true, x, y) end
  end

  -- colours
  place(self.rainbow, 0, 0, bw, H)
  self.rainbow:SetShown(look.rainbow)
  self:ApplyColors(look.cloth, look.glow)

  -- trims
  for i = 1, 4 do
    self.edge[i]:SetShown(not look.trimMid)
    self.rim[i]:SetShown(look.trimMid)
    self.gold[i]:SetShown(look.trimMid)
  end
  self.tailTrim[1]:SetShown(look.trimSide); self.tailTrim[2]:SetShown(look.trimSide)
  self:PlaceOrnaments(nil, 1)
  self:LayoutBolts()
end

-- Tints everything that follows the tier colour. Called on layout, and every frame at x1000.
function Counter:ApplyColors(cloth, glow)
  local xs, ns_ = self.xText, self.numText
  local c = { math.min(1, cloth[1] / B0), math.min(1, cloth[2] / B0), math.min(1, cloth[3] / B0) }
  if self.look.rainbow then tint(self.band, WHITE) else tint(self.band, c) end
  tint(self.tail[1], c); tint(self.tail[2], c)
  local face = mix(WHITE, glow, 0.2)
  tint(self.glyphFace, face)
  xs.face:SetTextColor(face[1], face[2], face[3])
  ns_.face:SetTextColor(face[1], face[2], face[3])
  tint(self.glyphDrop, BLACK, 0.35)
  xs.drop:SetTextColor(0, 0, 0, 0.35); ns_.drop:SetTextColor(0, 0, 0, 0.35)
  for d = 1, DEPTH do
    local e = Tiers.extrude(cloth, d)
    tint(self.glyphLayers[d], e)
    xs.layers[d]:SetTextColor(e[1], e[2], e[3]); ns_.layers[d]:SetTextColor(e[1], e[2], e[3])
  end
  tint(self.aura, glow)
  local rc = mix(glow, WHITE, 0.4)
  tint(self.rays[1], rc); tint(self.rays[2], rc)
  local sc = mix(glow, WHITE, 0.45)
  for i = 1, 16 do tint(self.sparks[i], sc) end
  local bc = mix(glow, WHITE, 0.35)
  for i = 1, 6 do tint(self.bolts[i], bc) end
  tint(self.ring, mix(glow, WHITE, 0.3))
  self.glow = glow
end

-- Places every piece of the ornament groups shown at this count. Group `grow` is drawn at
-- `k` times its size (the appear pop).
function Counter:PlaceOrnaments(grow, k)
  local shown = self.look.ornaments
  for _, p in ipairs(self.pieces) do
    local d = p.def
    local on = d.g <= shown and not (d["until"] and shown >= d["until"])
    p.tex:SetShown(on)
    if p.set then p.set:SetShown(on) end
    if on then
      local f = d.g == grow and k or 1
      local x = (d.ax == "L" and self.x0 or d.ax == "R" and self.x1 or 0) + d.x
      place(p.tex, x, d.y, d.w * f, d.h * f)
      if p.set then place(p.set, x, d.y, d.w * 1.3 * f, d.h * 1.3 * f) end
    end
  end
end

-- Lightning slots: 2 above, 2 below, 1 at each end (y up).
function Counter:LayoutBolts()
  local h, minX, maxX = H / 2, self.x0 - 22, self.x1 + 22
  local cx = (minX + maxX) / 2
  self.boltSlots = {
    { minX + 8, h + 3, cx - 2, h + 7 }, { cx + 2, h + 7, maxX - 8, h + 3 },
    { minX + 10, -h - 9, cx - 4, -h - 12 }, { cx + 4, -h - 12, maxX - 10, -h - 9 },
    { minX - 3, h - 1, minX - 9, -h - 8 }, { maxX + 3, h - 1, maxX + 9, -h - 8 },
  }
  for i, s in ipairs(self.boltSlots) do
    local b = self.bolts[i]
    local dx, dy = s[3] - s[1], s[4] - s[2]
    local len = math.sqrt(dx * dx + dy * dy)
    if i <= 4 then
      place(b, (s[1] + s[3]) / 2, (s[2] + s[4]) / 2, len, 14)
      b.rot = math.atan2(dy, dx)
      b.vertical = false
    else
      place(b, (s[1] + s[3]) / 2, (s[2] + s[4]) / 2, 14, len)
      b.vertical = true
    end
  end
end

-- ---------- events ----------

function Counter:Sound(name)
  if self.volume == 0 then return end
  ns.PlaySound(name)
end

function Counter:Pop(amp, dur)
  self.popAmp, self.popDur, self.popAt = amp, dur, GetTime()
end

function Counter:Burst(part, color, group)
  if self.reduced then return end
  table.insert(self.bursts, 1, { part = part, at = GetTime(), color = color or SPARK_GOLD, group = group })
  self.bursts[4] = nil
end

function Counter:Reset()
  self.ending = nil
  self.best = nil
  self.tierAt = nil
  self.ornAt = nil
  wipe(self.bursts)
  for i = 1, #self.particles do self.particles[i]:Hide() end
  self.plaque:Hide()
  self.prev:Hide()
  self.root:SetAlpha(1)
end

function Counter:Jump(n)
  local now = GetTime()
  if n == 1 or self.ending or self.static then
    self:Reset()
    self.static = false
    self.flag = 0
    self.scale = self.userScale * Tiers.growth(n)
  end
  self.n = n
  self.lastJump = now
  self:Layout(n)
  local event = Tiers.event(n)
  if event == "tier" then
    self:Pop(0.45, 0.32)
    self.tierAt = now
    self:Sound("tierup")
  elseif event == "ornament" then
    self:Pop(0.35, 0.26)
    self:Sound("milestone")
    self.ornAt, self.ornGroup = now, self.look.ornaments
    self:Burst("ornament", nil, self.look.ornaments)
  elseif event == "stage" then
    self:Pop(0.3, 0.22)
    self:Sound("milestone")
  elseif event == "pulse" then
    self:Pop(0.24, 0.2)
    self:Sound("tick")
    self:Burst("pulse", Tiers.mix(self.glow or self.look.glow, WHITE, 0.5))
  elseif n == 1 then
    self:Pop(0.3, 0.2)
    self:Sound("tick")
  else
    self:Pop(0.18, 0.16)
    self:Sound("tick")
  end
  if n == Tiers.TRIM_MID then self:Burst("mid") end
  if n == Tiers.TRIM_SIDE then self:Burst("side") end
  self.root:Show()
end

-- record: "best" (all-time), "today" (today's best) or nil.
function Counter:End(n, record, prev)
  if self.static or not self.root:IsShown() then return end
  local now = GetTime()
  if record then
    self:PreparePlaque(record)
    self.best = { at = now }
    self:Pop(record == "best" and 0.4 or 0.3, 0.3)
    self:Burst("mid", record == "today" and mix(PLAQUE_SILVER, WHITE, 0.3) or nil)
    self:Sound(record == "best" and "fanfare" or "tierup")
    self.plaque:Show()
    self.plaque:SetAlpha(0)
    if prev and prev > 0 then
      self.prevText:SetText("previous x" .. prev)
      self.prev:Show()
      self.prev:SetAlpha(0)
    end
    self.ending = { kind = "best", at = now }
  elseif n > 10 then
    self.ending = { kind = "snap", at = now }
    self:Sound("snap")
  else
    self.ending = { kind = "fade", at = now }
  end
end

-- Shows a fixed count, full ribbon, no fade (settings preview, unlocked position).
function Counter:ShowStatic(n)
  self:Reset()
  self.static = true
  self.n = n
  self.flag = 1
  self:Layout(n)
  self.scale = self.userScale * Tiers.growth(n)
  self.root:Show()
end

function Counter:Hide()
  self.static = false
  self:Reset()
  self.root:Hide()
end

function Counter:SetUserScale(s)
  self.userScale = s
end

function Counter:SetReduced(on)
  self.reduced = on and true or false
end

-- Current overall scale, used to place the milestone caption.
function Counter:CurrentScale()
  return self.scale or self.userScale
end

-- ---------- per frame ----------

local function updateBursts(self, now)
  local used = 0
  local h, d = H / 2, 6
  for b = 1, #self.bursts do
    local burst = self.bursts[b]
    local dt = now - burst.at
    local edges
    local count, speed, lifeBase = 30, 1, 0.55
    if burst.part == "mid" then
      edges = { { self.x0, self.x1, h, 1 }, { self.x0, self.x1, -h, -1 } }
    elseif burst.part == "pulse" then
      edges = { { self.x0, self.x1, h, 1 }, { self.x0, self.x1, -h, -1 } }
      count, speed, lifeBase = 14, 0.55, 0.4
    elseif burst.part == "ornament" then
      edges = {}
      for _, piece in ipairs(self.pieces) do
        local pd = piece.def
        if pd.g == burst.group then
          local x = (pd.ax == "L" and self.x0 or pd.ax == "R" and self.x1 or 0) + pd.x
          edges[#edges + 1] = { x - pd.w / 2, x + pd.w / 2, pd.y, pd.y >= 0 and 1 or -1 }
        end
      end
      if #edges == 0 then edges = { { self.x0, self.x1, h, 1 } } end
    else
      edges = {
        { self.x0 - 22, self.x0, -h - d, -1 }, { self.x1, self.x1 + 22, -h - d, -1 },
        { self.x0 - 22, self.x0, h - d, 1 }, { self.x1, self.x1 + 22, h - d, 1 },
      }
    end
    for i = 1, 30 do
      local p = self.particles[(b - 1) * 30 + i]
      local e = edges[(i - 1) % #edges + 1]
      local r1, r2, r3 = rand(i, 1), rand(i, 2), rand(i, 3)
      local life = lifeBase + r2 * 0.4
      if i <= count and dt <= life then
        local x = e[1] + (e[2] - e[1]) * r1 + (r3 - 0.5) * 80 * speed * dt
        local y = e[3] + e[4] * (35 + r2 * 65) * speed * dt - 70 * dt * dt
        local sz = (0.8 + r3 * 1.3) * ((i - 1) % 4 == 0 and 8 or 5)
        place(p, x, y, sz, sz)
        tint(p, burst.color)
        p:SetAlpha(1 - dt / life)
        p:Show()
      else
        p:Hide()
      end
    end
    -- trim flash
    local fa = dt < 0.35 and (1 - dt / 0.35) or 0
    if burst.part == "mid" or burst.part == "ornament" then
      for i = 1, 4 do self.goldFlash[i]:SetAlpha(fa); self.goldFlash[i]:SetShown(fa > 0) end
    elseif burst.part == "side" then
      for i = 1, 2 do self.tailFlash[i]:SetAlpha(fa); self.tailFlash[i]:SetShown(fa > 0) end
    end
    if dt < 1 then used = b end
  end
  for i = used + 1, #self.bursts do self.bursts[i] = nil end
  for i = used * 30 + 1, #self.particles do self.particles[i]:Hide() end
  if used == 0 then
    for i = 1, 4 do self.goldFlash[i]:Hide() end
    for i = 1, 2 do self.tailFlash[i]:Hide() end
  end
end

local function updateEffects(self, now, effects, flag)
  local look = self.look
  local halfW = self.halfW
  -- x25 shine
  local ph = (now % 2.4) / 0.75
  if effects >= 1 and ph < 1 then
    local x = self.x0 - 30 + (self.bw + 60) * ph
    place(self.shine, x, 0, 24, H * 1.4)
    self.shine:SetAlpha(0.75)
    self.shine:Show()
  else
    self.shine:Hide()
  end
  -- x50 lightning + aura
  local flare = 0
  for i = 1, 6 do
    local b = self.bolts[i]
    local per = 0.75 + ((i - 1) * 0.29) % 0.6
    local bph = (now + (i - 1) * 0.41) % per
    if effects >= 2 and bph < 0.14 then
      local v = (math.floor(now * 16) + (i - 1) * 2) % 6 + 1
      if b.frame ~= v then b:SetTexture(M .. "bolt" .. v); b.frame = v end
      local a = bph < 0.05 and 1 or 0.55
      flare = math.max(flare, a)
      if b.vertical then
        if i % 2 == 0 then b:SetTexCoord(1, 1, 0, 1, 1, 0, 0, 0) else b:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0) end
      else
        b:SetTexCoord(0, 1, 0, 1)
        if b.SetRotation then b:SetRotation(b.rot) end
      end
      b:SetAlpha(a)
      b:Show()
    else
      b:Hide()
    end
  end
  if effects >= 2 then
    local pulse = 0.25 + 0.2 * math.sin(now * 4.2) + 0.55 * flare
    local R = halfW + 18 + pulse * 6
    place(self.aura, 0, 1, R * 2, R)
    self.aura:SetAlpha(clamp01(0.55 + 0.25 * pulse))
    self.aura:Show()
  else
    self.aura:Hide()
  end
  -- x100 sparks
  for i = 1, 16 do
    local s = self.sparks[i]
    if effects >= 3 then
      local r1, r2 = (math.sin(i * 91.7) + 1) / 2, (math.sin(i * 47.3) + 1) / 2
      local sp = (now * (0.55 + r2 * 0.4) + i * 0.137) % 1
      local minX = self.x0 - 22
      local x = minX + 6 + r1 * (self.bw + 44 - 12) + math.sin(now * 3 + i) * 2
      local y = -(H / 2 - 4) + sp * (34 + r2 * 18)
      local size = (1 + r2 * 1.4) * ((i - 1) % 3 == 0 and 8 or 5)
      place(s, x, y, size, size)
      s:SetAlpha(math.sin(math.pi * sp) * 0.95)
      s:Show()
    else
      s:Hide()
    end
  end
  -- x200 rays
  for i = 1, 2 do
    local r = self.rays[i]
    if effects >= 4 then
      local R = halfW + 46
      place(r, 0, 0, R * 2, R * 2 * 0.62)
      if r.SetRotation then r:SetRotation(now * (i == 1 and 0.35 or -0.22)) end
      r:SetAlpha(i == 1 and 0.5 or 0.38)
      r:Show()
    else
      r:Hide()
    end
  end
  -- tier-up: flash + ring
  local tdt = self.tierAt and now - self.tierAt
  if tdt and tdt < 0.45 and not self.reduced then
    local k = tdt / 0.45
    self.flash:SetAlpha(tdt < 0.3 and 0.85 * (1 - tdt / 0.3) or 0)
    self.flash:Show()
    local r = halfW * 0.6 + k * 70
    place(self.ring, 0, 0, r * 2 / 0.86, r / 0.86)
    self.ring:SetAlpha(1 - k)
    self.ring:Show()
  else
    self.flash:Hide()
    self.ring:Hide()
  end
  self.back:SetAlpha(flag)
  self.front:SetAlpha(flag)
  self.clip:SetAlpha(flag * look.mid)
end

function Counter:Update(now, elapsed)
  if not self.look then return end
  local look = self.look
  local dt = math.min(elapsed or 0, 0.1)

  -- ribbon fade inside the window (R2.3)
  local target = 1
  if not self.static and not self.ending and self.lastJump then
    local idle = now - self.lastJump
    target = 1 - smooth((idle - 1) / 2)
  elseif self.ending and self.ending.kind ~= "best" then
    target = self.flag
  end
  if target > self.flag then
    self.flag = math.min(target, self.flag + dt / 0.1)
  else
    self.flag = target
  end
  local flag = self.flag

  -- size: eases toward its target over ~0.1 s
  local want = self.userScale * look.scale
  self.scale = self.scale + (want - self.scale) * math.min(1, dt / 0.1)
  local pop = 1
  if self.popAt then
    local p = (now - self.popAt) / self.popDur
    if p < 1 then pop = 1 + self.popAmp * (1 - p) * (1 - p) else self.popAt = nil end
  end

  -- end of the streak (R2.4) and NEW BEST (R2.9)
  local endScale, alpha = 1, 1
  local e = self.ending
  if e then
    local t = now - e.at
    if e.kind == "best" then
      local pt = t / 0.28
      local ps = pt < 1 and (1 + 2.70158 * (pt - 1) ^ 3 + 1.70158 * (pt - 1) ^ 2) or 1
      self.plaque:SetAlpha(clamp01(pt * 2))
      self.plaque:SetScale(math.max(0.01, ps))
      self.plaque:ClearAllPoints()
      -- clear the x150 crest, and the x750 crown
      local lift = look.ornaments >= 6 and 25 or (look.ornaments >= 2 and 9 or 0)
      self.plaque:SetPoint("CENTER", self.inner, "CENTER", 0, (H / 2 + 17 + lift) / math.max(0.01, ps))
      self.plaqueGlow:SetAlpha(0.45 + 0.2 * math.sin(now * 5))
      for i = 1, 6 do self.stars[i]:SetAlpha(0.5 + 0.5 * math.sin(now * 6 + i * 1.7)) end
      if self.prev:IsShown() then self.prev:SetAlpha(clamp01((t - 0.2) / 0.25)) end
      if t >= 1.8 then
        self.ending = { kind = "snap", at = now }
        self:Sound("snap")
      end
    elseif e.kind == "snap" then
      local p = t / 0.12
      endScale, alpha = 1 + 0.35 * p, 1 - p
      if p >= 1 then self:Hide(); return end
    else
      local p = t / 0.4
      alpha = 1 - p
      if p >= 1 then self:Hide(); return end
    end
  end

  self.inner:SetScale(math.max(0.01, self.scale * pop * endScale))
  self.root:SetAlpha(clamp01(alpha))
  self.sides:SetAlpha(look.sides * flag)
  self.mid:SetAlpha(look.mid * flag)
  self.core:SetAlpha(look.core)
  if look.rainbow then
    local cloth, glow = Tiers.rainbowAt(now)
    self:ApplyColors(cloth, glow)
    local u = (now * 0.15) % 1
    self.rainbow:SetTexCoord(u, u + self.bw / 90, 0, 1)
  end
  -- reduced effects keep the colours and the x25 shine, and drop lightning, sparks and rays
  local effects = self.reduced and math.min(look.effects, 1) or look.effects
  updateEffects(self, now, effects, flag)
  updateBursts(self, now)
  if self.ornAt then
    local p = (now - self.ornAt) / 0.3
    if p < 1 then
      self:PlaceOrnaments(self.ornGroup, 1 + 0.7 * (1 - p) * (1 - p))
    else
      self.ornAt = nil
      self:PlaceOrnaments(nil, 1)
    end
  end
end
