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
}

Tiers.TRIM_MID = 10
Tiers.TRIM_SIDE = 20
Tiers.OUTLINE_UPTO = 6
Tiers.DEPTH = 4
Tiers.STAGES = { [5] = true, [10] = true, [20] = true }

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

-- Number of stacked effects: x25 shine, x50 lightning, x100 sparks, x200 rays.
function Tiers.effects(n)
  return Tiers.index(n) - 1
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
    effects = i - 1,
    scale = Tiers.growth(n),
  }
end

-- What happens when the streak reaches n: "tier" (a new colour), "stage" (x5/x10/x20) or nil.
function Tiers.event(n)
  for i = 2, #Tiers.LIST do
    if Tiers.LIST[i].min == n then return "tier" end
  end
  if Tiers.STAGES[n] then return "stage" end
  return nil
end

ns.Tiers = Tiers
return Tiers
