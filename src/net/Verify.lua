-- PURE: plausibility checks on a received record (R5.3).
local _, ns = ...
ns = ns or {}

local Verify = {}

Verify.MIN_GAP = 0.45      -- s; the jump cycle is longer, minus generous lag tolerance (calibrate in game)
Verify.WINDOW = 3          -- s, the streak window (R1.1)
Verify.SLACK = 1           -- s of timing slack on a whole streak
Verify.LIVE_SKEW = 120     -- s a live record may differ from our server time
Verify.MAX_AGE_DAYS = 366
Verify.MIN_LEN = 11        -- only streaks above x10 reach the board
Verify.MAX_LEN = 100000

-- rec: { p, c, n, e (server epoch), d (realm day), u (duration s), g (min gap s) }
-- now: server epoch; today: realm day; live: received first-hand right after the streak.
-- Returns true, or false and a reason.
function Verify.record(rec, now, today, live)
  local n, e, d, u, g = rec.n, rec.e, rec.d, rec.u, rec.g
  if type(rec.p) ~= "string" or rec.p == "" then return false, "player" end
  if n ~= math.floor(n) or n < Verify.MIN_LEN or n > Verify.MAX_LEN then return false, "length" end
  if g < Verify.MIN_GAP then return false, "gap" end
  if u < (n - 1) * Verify.MIN_GAP - Verify.SLACK or u < (n - 1) * g - Verify.SLACK then return false, "too fast" end
  if u > (n - 1) * Verify.WINDOW + Verify.SLACK then return false, "too slow" end
  if e > now + Verify.LIVE_SKEW then return false, "future" end
  if live and now - e > Verify.LIVE_SKEW then return false, "stale" end
  if d > today + 1 or d <= today - Verify.MAX_AGE_DAYS then return false, "day" end
  -- the realm day must match the end time give or take a time zone
  local dayOfEnd = math.floor(e / 86400)
  if math.abs(dayOfEnd - d) > 1 then return false, "day mismatch" end
  return true
end

ns.Verify = Verify
return Verify
