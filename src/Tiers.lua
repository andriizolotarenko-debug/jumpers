-- PURE: streak length -> how the counter looks (UI-SPEC: Assembly, Tiers, Lettering, Size).
local _, ns = ...
ns = ns or {}

local Tiers = {}

local function hex(h)
  return {
    tonumber(h:sub(2, 3), 16) / 255,
    tonumber(h:sub(4, 5), 16) / 255,
    tonumber(h:sub(6, 7), 16) / 255,
  }
end
Tiers.hex = hex

Tiers.LIST = {
  { min = 1, name = "Grey", cloth = hex("#777777"), glow = hex("#c9c9c9") },
  { min = 25, name = "Uncommon", cloth = hex("#1f8f27"), glow = hex("#1eff00") },
  { min = 50, name = "Rare", cloth = hex("#0b5cbf"), glow = hex("#2b8cff") },
  { min = 100, name = "Epic", cloth = hex("#7f30c4"), glow = hex("#b54bff") },
  { min = 200, name = "Legendary", cloth = hex("#d06000"), glow = hex("#ff8a10") },
  { min = 300, name = "Mythic", cloth = hex("#b3151b"), glow = hex("#ff3b30") },
  -- x1000: the counter cycles through the hues; these are the colours shown at rest
  { min = 1000, name = "Rainbow", cloth = hex("#c040c0"), glow = hex("#ff7ad9"), rainbow = true },
}

Tiers.TRIM_MID = 10
Tiers.TRIM_SIDE = 20
Tiers.OUTLINE_UPTO = 6
Tiers.DEPTH = 4
Tiers.STAGES = { [5] = true, [10] = true, [20] = true }
-- gold ornaments: corner curls, crest + pendant, wings, runs + sapphires, emeralds + diamonds, crown
Tiers.ORNAMENTS = { 75, 150, 350, 400, 500, 750 }

local WHITE, BLACK = { 1, 1, 1 }, { 0, 0, 0 }

local function mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
Tiers.mix = mix

local function clamp01(v)
  if v < 0 then return 0 elseif v > 1 then return 1 end
  return v
end

function Tiers.index(n)
  local i = 1
  for k, t in ipairs(Tiers.LIST) do
    if n >= t.min then i = k end
  end
  return i
end

function Tiers.growth(n)
  return 1 + math.min(0.001 * n, 3.0)
end

-- Number of stacked effects: x25 shine, x50 lightning, x100 sparks, x200 rays (4 at most).
function Tiers.effects(n)
  return math.min(4, Tiers.index(n) - 1)
end

-- An RGB colour from a hue (0..1), saturation and value.
function Tiers.hsv(h, sat, v)
  local i = math.floor(h * 6) % 6
  local f = h * 6 - math.floor(h * 6)
  local p, q, t = v * (1 - sat), v * (1 - f * sat), v * (1 - (1 - f) * sat)
  if i == 0 then return { v, t, p } elseif i == 1 then return { q, v, p } elseif i == 2 then return { p, v, t }
  elseif i == 3 then return { p, q, v } elseif i == 4 then return { t, p, v } end
  return { v, p, q }
end

-- Rainbow colours at time t: cloth and glow, slowly cycling.
function Tiers.rainbowAt(t)
  local h = (t * 0.12) % 1
  return Tiers.hsv(h, 0.85, 0.8), Tiers.hsv(h, 0.65, 1)
end

-- Number of gold ornament groups on the frame.
function Tiers.ornaments(n)
  local k = 0
  for _, at in ipairs(Tiers.ORNAMENTS) do
    if n >= at then k = k + 1 end
  end
  return k
end

-- Extrusion colour for layer d (DEPTH = back ... 1 = front).
function Tiers.extrude(cloth, d)
  local depth = Tiers.DEPTH
  return mix(cloth, BLACK, 0.74 - (depth - d) / (depth - 1) * 0.28)
end

function Tiers.look(n)
  local i = Tiers.index(n)
  local tier = Tiers.LIST[i]
  return {
    tier = i,
    name = tier.name,
    cloth = tier.cloth,
    glow = tier.glow,
    face = mix(WHITE, tier.glow, 0.2),
    core = clamp01(n / 5),
    mid = clamp01((n - 5) / 5),
    sides = clamp01((n - 10) / 10),
    trimMid = n >= Tiers.TRIM_MID,
    trimSide = n >= Tiers.TRIM_SIDE,
    extruded = n > Tiers.OUTLINE_UPTO,
    effects = math.min(4, i - 1),
    rainbow = tier.rainbow or false,
    ornaments = Tiers.ornaments(n),
    scale = Tiers.growth(n),
  }
end

-- What happens when the streak reaches n: "tier" (a new colour), "ornament" (x75/x150/x300),
-- "stage" (x5/x10/x20), "pulse" (every other tenth jump) or nil.
function Tiers.event(n)
  for i = 2, #Tiers.LIST do
    if Tiers.LIST[i].min == n then return "tier" end
  end
  for _, at in ipairs(Tiers.ORNAMENTS) do
    if at == n then return "ornament" end
  end
  if Tiers.STAGES[n] then return "stage" end
  if n % 10 == 0 then return "pulse" end
  return nil
end

ns.Tiers = Tiers
return Tiers
