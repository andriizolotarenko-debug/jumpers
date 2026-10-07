-- PURE: the local copy of the leaderboard (R4, R5.4).
-- store = { records = { ["player:day"] = rec }, pending = { [key] = { rec, by = { relayer = true }, count, at } } }
-- Records are confirmed when heard first-hand from the player, or relayed identically by
-- QUORUM distinct peers. Unconfirmed records are never shown.
local _, ns = ...
ns = ns or {}

local Board = {}

Board.QUORUM = 2
Board.PENDING_TTL = 3600   -- s an unconfirmed relay is kept
Board.ONLINE_FOR = 600     -- s since last heard to count as online (R4.5)
Board.KEEP_DAYS = 366
Board.TIMEFRAMES = { today = 1, week = 7, month = 30, year = 365 }

function Board.ensure(store)
  store = type(store) == "table" and store or {}
  store.records = type(store.records) == "table" and store.records or {}
  store.pending = type(store.pending) == "table" and store.pending or {}
  return store
end

function Board.key(rec)
  return rec.p .. ":" .. rec.e .. ":" .. rec.n
end

local function copy(rec)
  return { p = rec.p, c = rec.c, n = rec.n, e = rec.e, d = rec.d, u = rec.u, g = rec.g }
end

-- Keeps the best record per player and realm day. Returns true if the board changed.
local function confirm(store, rec)
  local slot = rec.p .. ":" .. rec.d
  local cur = store.records[slot]
  if cur and (cur.n > rec.n or (cur.n == rec.n and cur.e <= rec.e)) then return false end
  store.records[slot] = copy(rec)
  return true
end

-- A record heard from the player who made it (or our own).
function Board.addFirstHand(store, rec)
  return confirm(store, rec)
end

-- A record relayed by `relayer`. Relays of a player's own records by that player are ignored
-- (their SavedVariables are not a source, R5.2). Returns true if this confirmed it.
function Board.addRelayed(store, rec, relayer, now)
  if relayer == rec.p then return false end
  local slot = store.records[rec.p .. ":" .. rec.d]
  if slot and slot.n >= rec.n then return false end
  local key = Board.key(rec)
  local p = store.pending[key]
  if not p then
    p = { rec = copy(rec), by = {}, count = 0, at = now }
    store.pending[key] = p
  end
  if p.by[relayer] then return false end
  p.by[relayer] = true
  p.count = p.count + 1
  if p.count >= Board.QUORUM then
    store.pending[key] = nil
    return confirm(store, rec)
  end
  return false
end

-- How many distinct peers have relayed this record and are still pending.
function Board.relays(store, rec)
  local p = store.pending[Board.key(rec)]
  return p and p.count or 0
end

-- Best record per player within the last `days` realm days, sorted by length, then earlier.
-- online: optional set of players to keep.
function Board.top(store, today, days, online)
  local best = {}
  for _, r in pairs(store.records) do
    if r.d > today - days and r.d <= today and (not online or online[r.p]) then
      local b = best[r.p]
      if not b or r.n > b.n or (r.n == b.n and r.e < b.e) then best[r.p] = r end
    end
  end
  local list = {}
  for _, r in pairs(best) do list[#list + 1] = r end
  table.sort(list, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    if a.e ~= b.e then return a.e < b.e end
    return a.p < b.p
  end)
  return list
end

-- Records worth relaying in a sync answer: the top `n` of every timeframe, never `me`'s own.
function Board.forSync(store, today, n, me)
  local seen, out = {}, {}
  for _, days in ipairs({ 1, 7, 30, 365 }) do
    local count = 0
    for _, r in ipairs(Board.top(store, today, days)) do
      if r.p ~= me then
        count = count + 1
        local k = Board.key(r)
        if not seen[k] then
          seen[k] = true
          out[#out + 1] = r
        end
        if count >= n then break end
      end
    end
  end
  return out
end

function Board.prune(store, today, now)
  for slot, r in pairs(store.records) do
    if r.d <= today - Board.KEEP_DAYS then store.records[slot] = nil end
  end
  for key, p in pairs(store.pending) do
    if now - p.at > Board.PENDING_TTL then store.pending[key] = nil end
  end
end

-- Online set: everyone heard within ONLINE_FOR seconds. heard = { [player] = time }.
function Board.online(heard, now)
  local set = {}
  for p, t in pairs(heard) do
    if now - t <= Board.ONLINE_FOR then set[p] = true end
  end
  return set
end

ns.Board = Board
return Board
