-- PURE: the addon-message format of the leaderboard (prefix JMPR). Plain text, "|"-separated.
--   R|1|class|n|endedAt|day|duration|minGap          live record, the sender is the player
--   S|1|player|class|n|endedAt|day|duration|minGap   relayed record (sync answer)
--   Q|1                                              sync request
--   H|1|class                                        heartbeat: "I'm here"
local _, ns = ...
ns = ns or {}

local Wire = {}
Wire.PREFIX = "JMPR"
Wire.VERSION = "1"

local function split(msg)
  local out = {}
  for part in (msg .. "|"):gmatch("([^|]*)|") do out[#out + 1] = part end
  return out
end

local function num(v)
  local n = tonumber(v)
  if n == nil or n ~= n or n == math.huge or n == -math.huge then return nil end
  return n
end

local function fields(r)
  return table.concat({ r.c or "", tostring(math.floor(r.n)), tostring(math.floor(r.e)), tostring(math.floor(r.d)),
    string.format("%.1f", r.u or 0), string.format("%.2f", r.g or 0) }, "|")
end

function Wire.record(r)
  return "R|" .. Wire.VERSION .. "|" .. fields(r)
end

function Wire.relay(r)
  return "S|" .. Wire.VERSION .. "|" .. r.p .. "|" .. fields(r)
end

function Wire.query()
  return "Q|" .. Wire.VERSION
end

function Wire.heartbeat(class)
  return "H|" .. Wire.VERSION .. "|" .. (class or "")
end

local function record(p, f, i)
  local r = { p = p, c = f[i], n = num(f[i + 1]), e = num(f[i + 2]), d = num(f[i + 3]), u = num(f[i + 4]),
    g = num(f[i + 5]) }
  if not (r.n and r.e and r.d and r.u and r.g) then return nil end
  if r.c == "" or not r.c:match("^[A-Z]+$") then r.c = nil end
  return r
end

-- Decodes a message from `sender`. Returns kind ("R", "S", "Q", "H") and its data, or nil.
function Wire.decode(msg, sender)
  if type(msg) ~= "string" or #msg > 255 then return nil end
  local f = split(msg)
  local kind, version = f[1], f[2]
  if version ~= Wire.VERSION then return nil end
  if kind == "R" and #f == 8 then
    local r = record(sender, f, 3)
    return r and "R", r
  elseif kind == "S" and #f == 9 then
    if f[3] == "" or f[3]:find("[%s|]") then return nil end
    local r = record(f[3], f, 4)
    return r and "S", r
  elseif kind == "Q" then
    return "Q", nil
  elseif kind == "H" then
    local class = f[3]
    if class and not class:match("^[A-Z]+$") then class = nil end
    return "H", class
  end
  return nil
end

ns.Wire = Wire
return Wire
