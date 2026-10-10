-- PURE: this login's numbers: jumps, time spent jumping and the recent jump rate.
-- Times are GetTime() seconds.
local _, ns = ...
ns = ns or {}

local Session = {}

Session.JUMP_TIME = 1.5   -- s of jumping one jump adds at most; a shorter gap to the last jump counts in full
Session.RECENT = 300      -- s window of the recent rate

function Session.new(now)
  return { start = now, jumps = 0, active = 0, last = nil, times = {}, head = 1, tail = 0 }
end

local function prune(s, now)
  while s.head <= s.tail and s.times[s.head] <= now - Session.RECENT do
    s.times[s.head] = nil
    s.head = s.head + 1
  end
end

-- Counts a jump. Returns the seconds of jumping it adds.
function Session.jump(s, now)
  local add = s.last and math.min(now - s.last, Session.JUMP_TIME) or Session.JUMP_TIME
  s.jumps = s.jumps + 1
  s.active = s.active + add
  s.last = now
  s.tail = s.tail + 1
  s.times[s.tail] = now
  prune(s, now)
  return add
end

function Session.elapsed(s, now)
  return math.max(0, now - s.start)
end

-- Share of `online` seconds spent jumping, 0..1.
function Session.share(active, online)
  if not online or online <= 0 then return 0 end
  return math.min(1, active / online)
end

-- Jumps per minute over the whole session.
function Session.rate(s, now)
  local mins = Session.elapsed(s, now) / 60
  if mins <= 0 then return 0 end
  return s.jumps / mins
end

-- Jumps per minute over the last RECENT seconds (or the session, if shorter).
function Session.recentRate(s, now)
  prune(s, now)
  local mins = math.min(Session.RECENT, Session.elapsed(s, now)) / 60
  if mins <= 0 then return 0 end
  return (s.tail - s.head + 1) / mins
end

ns.Session = Session
return Session
