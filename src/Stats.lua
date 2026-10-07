-- PURE: today / all-time counts, per-day bests and period bests (R3.1).
-- A stats table: { jumps, streaks, best, days = { [dayNumber] = { j, s, b } } }
local _, ns = ...
ns = ns or {}

local Stats = {}

Stats.KEEP_DAYS = 366
Stats.MIN_STREAK = 2 -- a single jump is not counted as a streak
Stats.NEW_BEST_ABOVE = 10

-- Days since 1970-01-01 for a calendar date (proleptic Gregorian).
function Stats.dayNumber(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = math.floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

function Stats.new()
  return { jumps = 0, streaks = 0, best = 0, days = {} }
end

-- Fills in missing fields of a saved table.
function Stats.ensure(s)
  s = type(s) == "table" and s or {}
  s.jumps = tonumber(s.jumps) or 0
  s.streaks = tonumber(s.streaks) or 0
  s.best = tonumber(s.best) or 0
  s.days = type(s.days) == "table" and s.days or {}
  return s
end

local function day(s, today)
  local e = s.days[today]
  if not e then
    e = { j = 0, s = 0, b = 0 }
    s.days[today] = e
  end
  return e
end

function Stats.addJump(s, today)
  s.jumps = s.jumps + 1
  local e = day(s, today)
  e.j = e.j + 1
end

-- Records an ended streak. Returns isNewBest, previousBest.
-- NEW BEST only counts for streaks above x10 (R2.9); the best itself always updates.
function Stats.endStreak(s, today, n)
  local prev = s.best
  if n >= Stats.MIN_STREAK then
    s.streaks = s.streaks + 1
    local e = day(s, today)
    e.s = e.s + 1
    if n > e.b then e.b = n end
  end
  if n > s.best then s.best = n end
  return n > prev and n > Stats.NEW_BEST_ABOVE, prev
end

function Stats.today(s, today)
  local e = s.days[today]
  if not e then return 0, 0, 0 end
  return e.j, e.s, e.b
end

-- Best streak over the last `days` days including today.
function Stats.periodBest(s, today, days)
  local best = 0
  for d, e in pairs(s.days) do
    if d > today - days and d <= today and e.b > best then best = e.b end
  end
  return best
end

function Stats.prune(s, today)
  for d in pairs(s.days) do
    if d <= today - Stats.KEEP_DAYS then s.days[d] = nil end
  end
end

ns.Stats = Stats
return Stats
