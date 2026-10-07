-- PURE: the 3 s streak window (R1.1, R1.2). Time is passed in, so tests can drive it.
local _, ns = ...
ns = ns or {}

local Streak = {}
Streak.__index = Streak
Streak.WINDOW = 3

function Streak.new()
  return setmetatable({ n = 0, last = nil, started = nil, minGap = nil }, Streak)
end

function Streak:active()
  return self.n > 0
end

-- Ends the streak if its window ran out by time t. Returns the ended streak or nil.
function Streak:tick(t)
  if self.n > 0 and t - self.last > Streak.WINDOW then
    local ended = { n = self.n, startedAt = self.started, endedAt = self.last, minGap = self.minGap }
    self.n, self.last, self.started, self.minGap = 0, nil, nil, nil
    return ended
  end
  return nil
end

-- A counted jump at time t. Returns the new count, plus the streak it ended if the
-- previous window had already run out.
function Streak:jump(t)
  local ended = self:tick(t)
  if self.n == 0 then
    self.started = t
  else
    local gap = t - self.last
    if not self.minGap or gap < self.minGap then self.minGap = gap end
  end
  self.n = self.n + 1
  self.last = t
  return self.n, ended
end

-- Seconds since the last counted jump, or nil when idle.
function Streak:idle(t)
  if self.n == 0 then return nil end
  return t - self.last
end

ns.Streak = Streak
return Streak
