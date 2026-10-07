-- PURE: jumps -> height, floors, formatting and milestone progress (R3.2, R3.3).
local _, ns = ...
ns = ns or {}

local Units = {}

Units.HEIGHT_PER_JUMP_M = 1.50
Units.FT_PER_M = 3.28084
Units.FLOOR_M = 3
Units.FLOOR_FT = 10
Units.KM_FROM_M = 100000 -- from 100 km heights switch to km / mi

function Units.heightM(jumps)
  return jumps * Units.HEIGHT_PER_JUMP_M
end

function Units.floors(jumps, unit)
  local m = Units.heightM(jumps)
  if unit == "ft" then
    return math.floor(m * Units.FT_PER_M / Units.FLOOR_FT)
  end
  return math.floor(m / Units.FLOOR_M)
end

-- 1234567 -> "1,234,567"
function Units.int(n)
  local s = tostring(math.floor(n + 0.5))
  local neg = s:sub(1, 1) == "-"
  if neg then s = s:sub(2) end
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  if out:sub(1, 1) == "," then out = out:sub(2) end
  return (neg and "-" or "") .. out
end

-- Splits a height into a number and its unit label.
function Units.split(m, unit)
  if m >= Units.KM_FROM_M then
    if unit == "ft" then
      return m / 1609.344, "mi"
    end
    return m / 1000, "km"
  end
  if unit == "ft" then
    return m * Units.FT_PER_M, "ft"
  end
  return m, "m"
end

function Units.format(m, unit)
  local v, label = Units.split(m, unit)
  return Units.int(v) .. " " .. label
end

-- Region default: US -> ft, anything else -> m (R3.2).
function Units.default(region, portal)
  if region == 1 then return "ft" end
  if region == nil and type(portal) == "string" and portal:lower() == "us" then return "ft" end
  return "m"
end

-- Number of landmarks passed at a height.
function Units.passed(m, list)
  local k = 0
  for i = 1, #list do
    if m >= list[i].m then k = i else break end
  end
  return k
end

-- Index of the last landmark crossed going from oldJumps to newJumps, or nil.
function Units.crossed(oldJumps, newJumps, list)
  local a = Units.passed(Units.heightM(oldJumps), list)
  local b = Units.passed(Units.heightM(newJumps), list)
  if b > a then return b end
  return nil
end

-- Progress from the last landmark passed to the next one.
-- Returns passed count, fraction 0..1, jumps to go (nil when all are passed).
function Units.progress(jumps, list)
  local m = Units.heightM(jumps)
  local k = Units.passed(m, list)
  if k >= #list then return k, 1, nil end
  local from = k > 0 and list[k].m or 0
  local to = list[k + 1].m
  local frac = (m - from) / (to - from)
  local togo = math.ceil((to - m) / Units.HEIGHT_PER_JUMP_M)
  return k, frac, togo
end

ns.Units = Units
return Units
