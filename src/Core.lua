-- Namespace, saved variables, the streak loop and the slash command.
local ADDON, ns = ...

ns.SCHEMA = 1

-- A tiny event bus between modules.
local listeners = {}
function ns.On(event, fn)
  listeners[event] = listeners[event] or {}
  table.insert(listeners[event], fn)
end
function ns.Fire(event, ...)
  local list = listeners[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok then geterrorhandler()(err) end
  end
end

function ns.Print(msg)
  print("|cffffd76aJumpers|r " .. msg)
end

-- Realm calendar day (R4.2). Falls back to the local clock.
function ns.Today()
  if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
    local ok, t = pcall(C_DateAndTime.GetCurrentCalendarTime)
    if ok and type(t) == "table" and t.year and t.month and t.monthDay then
      return ns.Stats.dayNumber(t.year, t.month, t.monthDay)
    end
  end
  local d = date("*t")
  return ns.Stats.dayNumber(d.year, d.month, d.day)
end

ns.streak = ns.Streak.new()

-- The streak loop runs only while a streak is active (zero cost when idle).
local ticker
local function stopTicker()
  if ticker then ticker:Cancel(); ticker = nil end
end

local function endStreak(ended)
  local today = ns.Today()
  local isNewBest, prev, isTodayBest, prevToday = ns.Stats.endStreak(ns.char, today, ended.n)
  ns.Stats.endStreak(ns.account, today, ended.n)
  ns.Fire("STREAK_END", ended.n, isNewBest, prev, isTodayBest, prevToday)
  ns.Comm.OwnStreak(ended, isNewBest or isTodayBest)
end

local function tick()
  local ended = ns.streak:tick(GetTime())
  if ended then
    stopTicker()
    endStreak(ended)
    return
  end
  ns.Detector.Poll()
end

-- Called by the Detector for every counted jump.
function ns.CountedJump(t)
  local n, ended = ns.streak:jump(t)
  if ended then endStreak(ended) end
  local today = ns.Today()
  local before = ns.char.jumps
  ns.Stats.addJump(ns.char, today)
  ns.Stats.addJump(ns.account, today)
  ns.Fire("JUMP", n)
  local idx = ns.Units.crossed(before, ns.char.jumps, ns.Landmarks)
  if idx then ns.Fire("MILESTONE", idx) end
  if not ticker then ticker = C_Timer.NewTicker(0.05, tick) end
end

local function initDB()
  JumpersDB = type(JumpersDB) == "table" and JumpersDB or {}
  JumpersCharDB = type(JumpersCharDB) == "table" and JumpersCharDB or {}
  JumpersDB.schema = ns.SCHEMA
  JumpersCharDB.schema = ns.SCHEMA
  JumpersDB.settings = type(JumpersDB.settings) == "table" and JumpersDB.settings or {}
  JumpersDB.stats = ns.Stats.ensure(JumpersDB.stats)
  JumpersCharDB.stats = ns.Stats.ensure(JumpersCharDB.stats)
  ns.account = JumpersDB.stats
  ns.char = JumpersCharDB.stats
  local today = ns.Today()
  ns.Stats.prune(ns.account, today)
  ns.Stats.prune(ns.char, today)
  ns.Settings.Init(JumpersDB.settings)
end

-- Wipes character and account stats (the Settings tab's test button).
function ns.ResetProgress()
  JumpersDB.stats = ns.Stats.new()
  JumpersCharDB.stats = ns.Stats.new()
  ns.account = JumpersDB.stats
  ns.char = JumpersCharDB.stats
  ns.Fire("STATS_RESET")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    initDB()
  elseif event == "PLAYER_LOGIN" then
    -- the leaderboard is kept per realm
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(realm) ~= "string" or realm == "" or (issecretvalue and issecretvalue(realm)) then realm = "realm" end
    JumpersDB.boards = type(JumpersDB.boards) == "table" and JumpersDB.boards or {}
    JumpersDB.boards[realm] = ns.Board.ensure(JumpersDB.boards[realm])
    ns.board = JumpersDB.boards[realm]
    ns.Detector.Init()
    ns.CounterUI.Init()
    ns.Caption.Init()
    ns.Minimap.Init()
    ns.Settings.RegisterOptionsStub()
    ns.Comm.Init()
  end
end)

-- Plays a made-up streak on the real counter, so the look can be checked without jumping.
function ns.Demo(length)
  length = length or 60
  local i = 0
  local demo
  demo = C_Timer.NewTicker(0.22, function()
    i = i + 1
    if i <= length then
      ns.Fire("DEMO_JUMP", i)
    else
      demo:Cancel()
      ns.Fire("DEMO_END", length)
    end
  end)
end

SLASH_JUMPERS1 = "/jumpers"
SlashCmdList.JUMPERS = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "demoboard" then
    ns.BoardTab.ToggleDemo()
  elseif msg == "demo" then
    ns.Demo(60)
  elseif msg:match("^demo %d+$") then
    ns.Demo(tonumber(msg:match("%d+")))
  else
    ns.Window.Toggle()
  end
end

-- Addon compartment (the AddOns button by the minimap).
function Jumpers_OnAddonCompartmentClick()
  ns.Window.Toggle()
end
