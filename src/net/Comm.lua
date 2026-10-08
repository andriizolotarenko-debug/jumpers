-- ADAPTER: leaderboard traffic over addon messages (R4, R5). Guild + a hidden custom channel.
-- Everything is paced to stay inside the server's addon-message allowance, and every game
-- call is guarded: if a client blocks a channel or a send, the board keeps working locally.
local _, ns = ...

local Comm = {}
ns.Comm = Comm

local Wire, Verify, Board = ns.Wire, ns.Verify, ns.Board

local CHANNEL = "JumpersLB"
local PACE = 1.1               -- s between sends (the server refills ~1 message per second)
local HEARTBEAT = 300          -- s (R4.5)
local SYNC_EVERY = 900         -- s (R5.4)
local QUIET = 600              -- s without sync traffic before we ask again
local ANSWER_COOLDOWN = 300    -- s between our sync answers
local ANSWER_TOP = 10          -- records per timeframe in an answer
local ANSWER_MAX = 25          -- messages in one answer
local ENOUGH_RELAYS = 2        -- skip a record once this many peers relayed it since the ask

local issecret = issecretvalue or function() return false end
local queue = {}
local channelId = 0
local me, myClass
local heard = {}               -- player -> last heard (server time)
local lastSyncTraffic = 0
local lastAnswer = -math.huge
local answering = nil
local selftest = nil           -- { at, n, got = { [target] = seconds } } while a self-test waits
local status = { channel = false, guild = false, lastSync = nil }
Comm.status = status

local function now()
  return GetServerTime and GetServerTime() or time()
end

local function store()
  return ns.board
end

local function myRealm()
  local r = GetNormalizedRealmName and GetNormalizedRealmName()
  if type(r) ~= "string" or r == "" or issecret(r) then r = (GetRealmName and GetRealmName() or ""):gsub("%s", "") end
  return r
end

-- "Name" -> "Name-Realm" so names from connected realms never collide.
local function full(name)
  if type(name) ~= "string" or issecret(name) or name == "" then return nil end
  if name:find("-", 1, true) then return name end
  return name .. "-" .. myRealm()
end

function Comm.Me()
  return me
end

-- Shows "Name" for players of our realm, "Name-Realm" for others.
function Comm.Short(player)
  local realm = "-" .. myRealm()
  if player:sub(-#realm) == realm then return player:sub(1, -#realm - 1) end
  if player:sub(-5) == "-Demo" then return player:sub(1, -6) end   -- the screenshot sample board
  return player
end

function Comm.Online()
  local set = Board.online(heard, now())
  if me then set[me] = true end
  return set
end

-- ---------- sending ----------

local function send(msg, target)
  local ok, result
  if target == "CHANNEL" then
    if channelId <= 0 then return true end
    ok, result = pcall(C_ChatInfo.SendAddonMessage, Wire.PREFIX, msg, "CHANNEL", channelId)
  else
    ok, result = pcall(C_ChatInfo.SendAddonMessage, Wire.PREFIX, msg, target)
  end
  if not ok then return true end                       -- blocked here: drop it, don't retry forever
  if result == false then return false end              -- older clients: false = not sent
  if type(result) == "number" and Enum and Enum.SendAddonMessageResult then
    local R = Enum.SendAddonMessageResult
    if result == R.AddonMessageThrottle or result == R.ChannelThrottle or result == R.GeneralError then
      return false
    end
  end
  return true
end

local function pump()
  local item = queue[1]
  if not item then return end
  if send(item.msg, item.target) then
    table.remove(queue, 1)
  else
    item.tries = (item.tries or 0) + 1
    if item.tries > 5 then table.remove(queue, 1) end
  end
end

local function post(msg)
  if #queue > 60 then return end
  if IsInGuild and IsInGuild() then queue[#queue + 1] = { msg = msg, target = "GUILD" } end
  if channelId > 0 then queue[#queue + 1] = { msg = msg, target = "CHANNEL" } end
end

-- ---------- the hidden channel ----------

local function joinChannel()
  local id = GetChannelName and GetChannelName(CHANNEL)
  if (type(id) ~= "number" or id == 0) and JoinTemporaryChannel then
    pcall(JoinTemporaryChannel, CHANNEL)
    id = GetChannelName(CHANNEL)
  end
  channelId = type(id) == "number" and id or 0
  status.channel = channelId > 0
  if channelId > 0 and ChatFrame_RemoveChannel then
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
      local f = _G["ChatFrame" .. i]
      if f then pcall(ChatFrame_RemoveChannel, f, CHANNEL) end
    end
  end
end

-- ---------- receiving ----------

-- Answers a sync request with the top records, skipping any that enough peers already relayed
-- while we waited (so a crowded channel does not repeat itself).
local function answerSync()
  local heardRelays = answering and answering.relays or {}
  answering = nil
  lastAnswer = GetTime()
  local sent = 0
  for _, r in ipairs(Board.forSync(store(), ns.Today(), ANSWER_TOP, me)) do
    if sent >= ANSWER_MAX then break end
    if (heardRelays[Board.key(r)] or 0) < ENOUGH_RELAYS then
      post(Wire.relay(r))
      sent = sent + 1
    end
  end
end

-- Our own self-test message came back: the game echoes addon messages to the sender.
local function onEcho(channel, data)
  if data.n ~= selftest.n or selftest.got[channel] then return end
  selftest.got[channel] = GetTime() - selftest.at
  local ok, why = Verify.record(data, now(), ns.Today(), true)
  ns.Print(string.format("self-test: %s echo after %.1f s, record %s", channel == "GUILD" and "guild" or "channel",
    selftest.got[channel], ok and "decoded and verified" or ("rejected (" .. tostring(why) .. ")")))
end

local function onMessage(prefix, msg, channel, sender)
  if prefix ~= Wire.PREFIX or issecret(msg) then return end
  if channel ~= "GUILD" and channel ~= "CHANNEL" then return end
  local from = full(sender)
  if not from then return end
  local kind, data = Wire.decode(msg, from)
  if from == me then
    if kind == "T" and selftest then onEcho(channel, data) end
    return
  end
  if not kind then return end
  local t = now()
  heard[from] = t
  local today = ns.Today()
  local changed = false
  if kind == "R" then
    if Verify.record(data, t, today, true) then changed = Board.addFirstHand(store(), data) end
  elseif kind == "S" then
    lastSyncTraffic = GetTime()
    data.p = full(data.p)
    if answering and data.p then
      local k = Board.key(data)
      answering.relays[k] = (answering.relays[k] or 0) + 1
    end
    if data.p and data.p ~= me and Verify.record(data, t, today, false) then
      changed = Board.addRelayed(store(), data, from, t)
    end
  elseif kind == "Q" then
    lastSyncTraffic = GetTime()
    if not answering and GetTime() - lastAnswer > ANSWER_COOLDOWN then
      answering = { relays = {} }
      C_Timer.After(2 + math.random() * 4, answerSync)
    end
  end
  if changed then ns.Fire("BOARD") end
end

-- ---------- our own records ----------

-- Called when a streak ends: our own record goes on our board and out to peers, live (R5.1).
function Comm.OwnStreak(ended, isDayBest)
  if not me or ended.n < Verify.MIN_LEN or not isDayBest then return end
  local rec = {
    p = me, c = myClass, n = ended.n, e = now(), d = ns.Today(),
    u = ended.endedAt - ended.startedAt, g = ended.minGap or 0,
  }
  if Board.addFirstHand(store(), rec) then ns.Fire("BOARD") end
  post(Wire.record(rec))
end

-- /jumpers selftest: sends a test record through the guild and the channel and waits for the
-- game to echo it back. Checks sending, pacing, the channel, decoding and verification on this
-- client. Other clients ignore "T" messages, so nothing reaches anyone's board.
function Comm.SelfTest()
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or not me then
    ns.Print("self-test: addon messages are unavailable on this client")
    return
  end
  if selftest then ns.Print("self-test: already running"); return end
  if channelId <= 0 then joinChannel() end
  status.guild = IsInGuild and IsInGuild() or false
  ns.Print(string.format("self-test: channel %s, guild %s, %d message(s) queued",
    status.channel and ("joined (#" .. channelId .. ")") or "unavailable",
    status.guild and "yes" or "no", #queue))
  if not status.channel and not status.guild then
    ns.Print("self-test: nowhere to send. Join a guild, or check that custom channels are allowed.")
    return
  end
  local n = 20 + math.random(0, 79)
  selftest = { at = GetTime(), n = n, got = {} }
  local t = now()
  post(Wire.test({ c = myClass, n = n, e = t, d = ns.Today(), u = (n - 1) * 0.8, g = 0.6 }))
  C_Timer.After(15 + #queue * PACE, function()
    for _, target in ipairs({ "GUILD", "CHANNEL" }) do
      local wanted = (target == "GUILD" and status.guild) or (target == "CHANNEL" and status.channel)
      if wanted and not selftest.got[target] then
        ns.Print("self-test: no " .. (target == "GUILD" and "guild" or "channel") .. " echo. Messages there may be blocked.")
      end
    end
    ns.Print("self-test: done")
    selftest = nil
  end)
end

local function sync(force)
  if not force and GetTime() - lastSyncTraffic < QUIET then return end
  status.lastSync = now()
  post(Wire.query())
end

function Comm.Init()
  me = full(UnitName and UnitName("player"))
  local class = UnitClass and select(2, UnitClass("player"))
  if type(class) == "string" and not issecret(class) then myClass = class end
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or not me then return end
  pcall(C_ChatInfo.RegisterAddonMessagePrefix, Wire.PREFIX)
  status.guild = IsInGuild and IsInGuild() or false
  Board.prune(store(), ns.Today(), now())

  local events = CreateFrame("Frame")
  events:RegisterEvent("CHAT_MSG_ADDON")
  events:RegisterEvent("PLAYER_GUILD_UPDATE")
  events:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
      onMessage(...)
    else
      status.guild = IsInGuild and IsInGuild() or false
    end
  end)

  C_Timer.NewTicker(PACE, pump)
  C_Timer.After(8, function()
    joinChannel()
    post(Wire.heartbeat(myClass))
    sync(true)
  end)
  C_Timer.NewTicker(HEARTBEAT, function()
    if channelId <= 0 then joinChannel() end
    post(Wire.heartbeat(myClass))
  end)
  C_Timer.NewTicker(SYNC_EVERY, function() sync(false) end)
end
