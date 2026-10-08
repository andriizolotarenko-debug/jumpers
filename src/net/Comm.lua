-- ADAPTER: leaderboard traffic over addon messages (R4, R5). Guild + a hidden custom channel.
-- Classic clients block addon messages in custom channels, so there (or wherever the channel
-- fails its probe) records also travel through the group and by whisper to players we met.
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
local ANSWER_COOLDOWN = 300    -- s between our sync answers (per asker for whispers)
local ANSWER_TOP = 10          -- records per timeframe in an answer
local ANSWER_MAX = 25          -- messages in one answer
local ENOUGH_RELAYS = 2        -- skip a record once this many peers relayed it since the ask
local PROBE_WAIT = 20          -- s to wait for the echo that proves the channel works
local ASK_BATCH = 5            -- peers asked by whisper per round
local ASK_RETRY = 1800         -- s before an unanswered peer is asked again
local WHISPER_MAX = 10         -- peers a live record or heartbeat is whispered to

local issecret = issecretvalue or function() return false end
local queue = {}
local channelId = 0
local me, myClass
local heard = {}               -- player -> last heard (server time)
local via = {}                 -- player -> chat type we last heard them on
local asked = {}               -- player -> GetTime() we last whispered them a sync request
local answeredTo = {}          -- player -> GetTime() we last answered them by whisper
local whispered = {}           -- whisper target -> GetTime(), to hide "player not found" replies
local lastSyncTraffic = 0
local lastAnswer = -math.huge
local answering = nil
local probe = nil              -- { n } while we wait for our channel echo
local selftest = nil           -- { at, n, got = { [chat type] = seconds } } while a self-test waits
-- channelState: "off" (Classic: never joined), "probing", "ok", "blocked"
local status = { channel = false, channelState = "probing", guild = false, lastSync = nil }
Comm.status = status

local CLASSIC_PROJECTS = {
  WOW_PROJECT_CLASSIC, WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_WRATH_CLASSIC,
  WOW_PROJECT_CATACLYSM_CLASSIC, WOW_PROJECT_MISTS_CLASSIC,
}

local function isClassic()
  if not WOW_PROJECT_ID then return false end
  for _, id in pairs(CLASSIC_PROJECTS) do
    if id == WOW_PROJECT_ID then return true end
  end
  return false
end

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

-- True where the realm channel can't carry our messages: then group and whispers fill in.
local function fallback()
  return status.channelState == "off" or status.channelState == "blocked"
end
Comm.Fallback = fallback

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

local function groupType()
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
  return nil
end

local function leaveChannel()
  if LeaveChannelByName then pcall(LeaveChannelByName, CHANNEL) end
  channelId = 0
  status.channel = false
  status.channelState = "blocked"
end

local function send(item)
  local ok, result
  if item.target == "CHANNEL" then
    if channelId <= 0 then return true end
    ok, result = pcall(C_ChatInfo.SendAddonMessage, Wire.PREFIX, item.msg, "CHANNEL", channelId)
  elseif item.target == "WHISPER" then
    whispered[item.to] = GetTime()
    ok, result = pcall(C_ChatInfo.SendAddonMessage, Wire.PREFIX, item.msg, "WHISPER", item.to)
  else
    ok, result = pcall(C_ChatInfo.SendAddonMessage, Wire.PREFIX, item.msg, item.target)
  end
  if not ok then return true end                       -- blocked here: drop it, don't retry forever
  if result == false then return false end              -- older clients: false = not sent
  if type(result) == "number" and Enum and Enum.SendAddonMessageResult then
    local R = Enum.SendAddonMessageResult
    if result == R.AddonMessageThrottle or result == R.ChannelThrottle or result == R.GeneralError then
      return false
    end
    if item.target == "CHANNEL" and (result == R.InvalidChatType or result == R.InvalidChannel) then
      leaveChannel()                                    -- this client refuses channel traffic
    end
  end
  return true
end

local function pump()
  local item = queue[1]
  if not item then return end
  if send(item) then
    table.remove(queue, 1)
  else
    item.tries = (item.tries or 0) + 1
    if item.tries > 5 then table.remove(queue, 1) end
  end
end

local function enqueue(msg, target, to)
  if #queue > 60 then return end
  queue[#queue + 1] = { msg = msg, target = target, to = to }
end

-- Every broadcast route we have: guild, the channel, and in fallback mode the group.
local function post(msg)
  if IsInGuild and IsInGuild() then enqueue(msg, "GUILD") end
  if channelId > 0 then enqueue(msg, "CHANNEL") end
  local group = fallback() and groupType()
  if group then enqueue(msg, group) end
end

-- Online players only a whisper reaches (met in a group or by whisper, not heard in our guild).
local function whisperPeers()
  local out = {}
  if not fallback() then return out end
  for p in pairs(Board.online(heard, now())) do
    if via[p] == "WHISPER" and #out < WHISPER_MAX then out[#out + 1] = p end
  end
  return out
end

-- ---------- the hidden channel ----------

local function joinChannel()
  local id = GetChannelName and GetChannelName(CHANNEL)
  if (type(id) ~= "number" or id == 0) and JoinTemporaryChannel then
    pcall(JoinTemporaryChannel, CHANNEL)
    id = GetChannelName(CHANNEL)
  end
  channelId = type(id) == "number" and id or 0
  if channelId > 0 and ChatFrame_RemoveChannel then
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
      local f = _G["ChatFrame" .. i]
      if f then pcall(ChatFrame_RemoveChannel, f, CHANNEL) end
    end
  end
end

local function testRecord(n)
  return { c = myClass, n = n, e = now(), d = ns.Today(), u = (n - 1) * 0.8, g = 0.6 }
end

-- Joins the channel and sends ourselves a test message there: only the game's echo proves
-- the channel carries addon messages on this client. No echo: leave it and fall back.
local function probeChannel()
  if status.channelState == "off" then return end
  joinChannel()
  if channelId <= 0 then status.channelState = "blocked"; return end
  status.channelState = "probing"
  local n = 11 + math.random(0, 88)
  probe = { n = n }
  enqueue(Wire.test(testRecord(n)), "CHANNEL")
  C_Timer.After(PROBE_WAIT + #queue * PACE, function()
    if probe and probe.n == n then
      probe = nil
      leaveChannel()
    end
  end)
end

-- ---------- receiving ----------

local NOT_FOUND = type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string"
  and "^" .. ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"

-- Hides the "No player named X is currently playing" reply to our whisper to an offline peer.
local function hideNotFound(_, _, msg)
  if not NOT_FOUND or type(msg) ~= "string" or issecret(msg) then return false end
  local name = msg:match(NOT_FOUND)
  local at = name and (whispered[name] or whispered[full(name) or ""])
  return at ~= nil and GetTime() - at < 10
end

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

-- A sync request by whisper: answer the asker alone, and ask back if we have not lately.
local function answerWhisper(from)
  if answeredTo[from] and GetTime() - answeredTo[from] < ANSWER_COOLDOWN then return end
  answeredTo[from] = GetTime()
  enqueue(Wire.heartbeat(myClass), "WHISPER", from)
  local sent = 0
  for _, r in ipairs(Board.forSync(store(), ns.Today(), ANSWER_TOP, me)) do
    if sent >= ANSWER_MAX then break end
    if r.p ~= from then
      enqueue(Wire.relay(r), "WHISPER", from)
      sent = sent + 1
    end
  end
  if not asked[from] or GetTime() - asked[from] > ANSWER_COOLDOWN then
    asked[from] = GetTime()
    enqueue(Wire.query(), "WHISPER", from)
  end
end

-- Our own test message came back: the game echoes addon messages to the sender.
local function onEcho(channel, data)
  if probe and channel == "CHANNEL" and data.n == probe.n then
    probe = nil
    status.channelState = "ok"
    status.channel = true
  end
  if not selftest or data.n ~= selftest.n or selftest.got[channel] then return end
  selftest.got[channel] = GetTime() - selftest.at
  local ok, why = Verify.record(data, now(), ns.Today(), true)
  ns.Print(string.format("self-test: %s echo after %.1f s, record %s", channel:lower(),
    selftest.got[channel], ok and "decoded and verified" or ("rejected (" .. tostring(why) .. ")")))
end

local CHAT_TYPES = { GUILD = true, CHANNEL = true, PARTY = true, RAID = true, INSTANCE_CHAT = true, WHISPER = true }

local function onMessage(prefix, msg, channel, sender)
  if prefix ~= Wire.PREFIX or issecret(msg) or not CHAT_TYPES[channel] then return end
  local from = full(sender)
  if not from then return end
  local kind, data = Wire.decode(msg, from)
  if from == me then
    if kind == "T" then onEcho(channel, data) end
    return
  end
  if not kind then return end
  local t = now()
  heard[from] = t
  if channel ~= "CHANNEL" then via[from] = channel end
  if channel ~= "GUILD" and channel ~= "CHANNEL" then Board.notePeer(store(), from, t) end
  local today = ns.Today()
  local changed = false
  if kind == "R" then
    if Verify.record(data, t, today, true) then changed = Board.addFirstHand(store(), data) end
  elseif kind == "S" then
    lastSyncTraffic = GetTime()
    data.p = full(data.p)
    if answering and data.p and channel ~= "WHISPER" then
      local k = Board.key(data)
      answering.relays[k] = (answering.relays[k] or 0) + 1
    end
    if data.p and data.p ~= me and Verify.record(data, t, today, false) then
      changed = Board.addRelayed(store(), data, from, t)
    end
  elseif kind == "Q" then
    lastSyncTraffic = GetTime()
    if channel == "WHISPER" then
      answerWhisper(from)
    elseif not answering and GetTime() - lastAnswer > ANSWER_COOLDOWN then
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
  local msg = Wire.record(rec)
  post(msg)
  for _, p in ipairs(whisperPeers()) do enqueue(msg, "WHISPER", p) end
end

local function sync(force)
  if not force and GetTime() - lastSyncTraffic < QUIET then return end
  status.lastSync = now()
  post(Wire.query())
end

-- Fallback mode: whisper a sync request to peers we met and have not heard from lately.
local function askPeers()
  if not fallback() then return end
  local skip = Board.online(heard, now())
  for p, at in pairs(asked) do
    if GetTime() - at < ASK_RETRY then skip[p] = true end
  end
  for _, p in ipairs(Board.peersToAsk(store(), skip, ASK_BATCH)) do
    asked[p] = GetTime()
    enqueue(Wire.query(), "WHISPER", p)
  end
end

local function heartbeat()
  local msg = Wire.heartbeat(myClass)
  post(msg)
  for _, p in ipairs(whisperPeers()) do enqueue(msg, "WHISPER", p) end
end

-- /jumpers selftest: sends a test record through every route we have and waits for the game
-- to echo it back. Checks sending, pacing, the channel, decoding and verification on this
-- client. Other clients ignore "T" messages, so nothing reaches anyone's board.
function Comm.SelfTest()
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or not me then
    ns.Print("self-test: addon messages are unavailable on this client")
    return
  end
  if selftest then ns.Print("self-test: already running"); return end
  status.guild = IsInGuild and IsInGuild() or false
  local group = groupType()
  local state = status.channelState
  if state ~= "off" and channelId <= 0 then joinChannel() end
  local want = {}
  if status.guild then want[#want + 1] = "GUILD" end
  if channelId > 0 then want[#want + 1] = "CHANNEL" end
  if group then want[#want + 1] = group end
  want[#want + 1] = "WHISPER"
  local channelText = state == "off" and "not available on Classic clients"
    or (state == "ok" and ("joined (#" .. channelId .. ")") or (channelId > 0 and "checking" or "unavailable"))
  ns.Print(string.format("self-test: channel %s, guild %s, group %s, %d message(s) queued",
    channelText, status.guild and "yes" or "no", group and group:lower() or "no", #queue))
  local n = 20 + math.random(0, 79)
  selftest = { at = GetTime(), n = n, got = {} }
  if channelId > 0 and state ~= "ok" then
    status.channelState = "probing"
    probe = { n = n }
  end
  local msg = Wire.test(testRecord(n))
  for _, target in ipairs(want) do enqueue(msg, target, target == "WHISPER" and me or nil) end
  C_Timer.After(15 + #queue * PACE, function()
    for _, target in ipairs(want) do
      if not selftest.got[target] then
        ns.Print("self-test: no " .. target:lower() .. " echo. Messages there may be blocked.")
      end
    end
    if probe and probe.n == n then
      probe = nil
      leaveChannel()
    end
    ns.Print("self-test: done")
    selftest = nil
  end)
end

function Comm.Init()
  me = full(UnitName and UnitName("player"))
  local class = UnitClass and select(2, UnitClass("player"))
  if type(class) == "string" and not issecret(class) then myClass = class end
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or not me then return end
  pcall(C_ChatInfo.RegisterAddonMessagePrefix, Wire.PREFIX)
  status.guild = IsInGuild and IsInGuild() or false
  if isClassic() then status.channelState = "off" end
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
  local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
  if addFilter then pcall(addFilter, "CHAT_MSG_SYSTEM", hideNotFound) end

  C_Timer.NewTicker(PACE, pump)
  C_Timer.After(8, function()
    probeChannel()
    heartbeat()
    sync(true)
    askPeers()
  end)
  C_Timer.NewTicker(HEARTBEAT, function()
    if status.channelState == "ok" and channelId <= 0 then joinChannel() end
    heartbeat()
    askPeers()
  end)
  C_Timer.NewTicker(SYNC_EVERY, function() sync(false) end)
end
