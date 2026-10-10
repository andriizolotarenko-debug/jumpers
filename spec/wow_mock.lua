-- A small stand-in for the WoW client: enough of the API to load the whole addon,
-- drive jumps through the real hook and run every OnUpdate. Catches runtime errors
-- (nil calls, typos, bad arguments) before the code reaches the game.
local Mock = {}

local clock = 100
local timers = {}
local frames = {}
Mock.frames = frames
local eventFrames = {}

local function noop() end

local PREFIXES = { "Set", "Enable", "Register", "Unregister", "Clear", "Lock", "Unlock", "Start", "Stop", "Disable", "Raise" }

local Object = {}
Object.__index = function(self, key)
  local m = rawget(Object, key)
  if m then return m end
  if type(key) == "string" then
    for _, p in ipairs(PREFIXES) do
      if key:sub(1, #p) == p then return noop end
    end
  end
  return nil
end

local function new(kind, parent)
  local o = setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, alpha = 1,
    level = parent and (parent.level or 0) + 1 or 0, width = 0, height = 0, _text = "" }, Object)
  table.insert(frames, o)
  return o
end

function Object:GetParent() return self.parent end
function Object:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Object:Hide() self.shown = false end
function Object:SetShown(v) if v then self:Show() else self:Hide() end end
function Object:IsShown() return self.shown end
function Object:IsVisible()
  local o = self
  while o do
    if not o.shown then return false end
    o = o.parent
  end
  return true
end
function Object:SetScript(name, fn) self.scripts[name] = fn end
function Object:GetScript(name) return self.scripts[name] end
function Object:HookScript(name, fn) self.scripts[name] = fn end
function Object:GetFrameLevel() return self.level end
function Object:SetFrameLevel(l) self.level = l end
function Object:SetAlpha(a) assert(type(a) == "number", "SetAlpha needs a number"); self.alpha = a end
function Object:GetAlpha() return self.alpha end
function Object:SetScale(s) assert(type(s) == "number" and s > 0, "SetScale needs a positive number"); self.scale = s end
function Object:GetScale() return self.scale or 1 end
function Object:SetSize(w, h) assert(type(w) == "number" and type(h) == "number", "SetSize needs numbers"); self.width, self.height = w, h end
function Object:SetWidth(w) self.width = w end
function Object:SetHeight(h) self.height = h end
function Object:GetWidth() return self.width end
function Object:GetHeight() return self.height end
function Object:GetCenter() return 500, 400 end
function Object:SetPoint(point, rel, ...)
  assert(type(point) == "string", "SetPoint needs a point name")
  if type(rel) == "table" then assert(rel ~= self, "anchored to itself") end
end
function Object:CreateTexture() return new("Texture", self) end
function Object:CreateFontString(_, _, template) local o = new("FontString", self); o.font = template and "Fonts\\FRIZQT__.TTF"; return o end
function Object:SetFont(path, size) assert(type(size) == "number", "SetFont needs a size"); self.font = path; self.size = size; return true end
function Object:GetFont() return self.font, self.size end
function Object:SetText(t) self._text = t == nil and "" or tostring(t) end
function Object:GetText() return self._text end
function Object:GetStringWidth() return #self._text * (self.size or 12) * 0.55 end
function Object:GetStringHeight() return self.size or 12 end
function Object:SetTexCoord(...)
  local n = select("#", ...)
  assert(n == 4 or n == 8, "SetTexCoord needs 4 or 8 numbers")
  for i = 1, n do assert(type(select(i, ...)) == "number", "SetTexCoord needs numbers") end
end
function Object:SetVertexColor(r, g, b, a)
  assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "SetVertexColor needs numbers")
  assert(a == nil or type(a) == "number")
end
function Object:SetTextColor(r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number") end
function Object:SetColorTexture(r, g, b) assert(type(r) == "number" and type(g) == "number" and type(b) == "number") end
function Object:SetTexture(path) assert(path == nil or type(path) == "string" or type(path) == "number") self.texture = path end
function Object:SetBlendMode(mode) assert(mode == "ADD" or mode == "BLEND" or mode == "DISABLE" or mode == "MOD" or mode == "ALPHAKEY") end
function Object:SetRotation(r) assert(type(r) == "number") end
function Object:SetGradient(o, a, b) assert(o == "VERTICAL" or o == "HORIZONTAL"); assert(type(a) == "table" and type(b) == "table") end
function Object:GetThumbTexture() self.thumb = self.thumb or new("Texture", self); return self.thumb end
function Object:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Object:SetValue(v)
  self.value = v
  if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v, false) end
end
function Object:GetValue() return self.value or 0 end
function Object:SetChecked(v) self.checked = v and true or false end
function Object:GetChecked() return self.checked end
function Object:GetFontString() self.fs = self.fs or new("FontString", self); return self.fs end
function Object:HighlightText() self.highlighted = true end
function Object:Click() if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton") end end
function Object:RegisterEvent(e) eventFrames[e] = eventFrames[e] or {}; table.insert(eventFrames[e], self) end
function Object:SetScrollChild(c) self.child = c end
function Object:StartMoving() end
function Object:StopMovingOrSizing() end
function Object:Cancel() self.cancelled = true end
function Object:SetID(id) self.id = id end
function Object:GetVerticalScroll() return self.vscroll or 0 end
function Object:SetVerticalScroll(v) assert(type(v) == "number"); self.vscroll = v end
function Object:GetStatusBarTexture() self.sbt = self.sbt or new("Texture", self); return self.sbt end

local function install()
  _G.CreateFrame = function(kind, name, parent, template)
    if template and template ~= "UIPanelButtonTemplate" and template ~= "UICheckButtonTemplate"
      and template ~= "UIPanelScrollFrameTemplate" and template ~= "PanelTabButtonTemplate"
      and template ~= "UIPanelCloseButton" then
      error("unknown template " .. tostring(template))
    end
    local f = new(kind, parent)
    if name then _G[name] = f end
    return f
  end
  _G.UIParent = new("Frame")
  _G.GetTime = function() return clock end
  _G.C_Timer = {
    After = function(d, fn) table.insert(timers, { at = clock + d, fn = fn, once = true }) end,
    NewTicker = function(d, fn, n)
      local t = setmetatable({ every = d, at = clock + d, fn = fn, left = n }, Object)
      table.insert(timers, t)
      return t
    end,
  }
  _G.C_DateAndTime = { GetCurrentCalendarTime = function() return { year = 2026, month = 10, monthDay = 7 } end }
  _G.date = os.date
  _G.hooksecurefunc = function(name, fn)
    local orig = _G[name]
    _G[name] = function(...) orig(...); fn(...) end
  end
  _G.JumpOrAscendStart = function() end
  Mock.falling = false
  _G.IsFalling = function() return Mock.falling end
  _G.IsSwimming = function() return false end
  _G.IsFlying = function() return false end
  _G.UnitOnTaxi = function() return false end
  _G.HasFullControl = function() return true end
  _G.IsPlayerMoving = function() return Mock.moving end
  _G.GetPlayerFacing = function() return Mock.facing or 0 end
  _G.GetCurrentRegion = function() return 3 end
  _G.UnitName = function() return "Tester" end
  _G.UnitClass = function() return "Hunter", "HUNTER" end
  _G.GetServerTime = function() return 20733 * 86400 + 50000 + math.floor(clock) end
  _G.time = os.time
  _G.GetNormalizedRealmName = function() return "TestRealm" end
  _G.GetRealmName = function() return "Test Realm" end
  _G.IsInGuild = function() return true end
  Mock.roster = Mock.roster or { "Tester-TestRealm", "Ann-TestRealm" }
  _G.GetNumGuildMembers = function() return #Mock.roster end
  _G.GetGuildRosterInfo = function(i) return Mock.roster[i] end
  _G.C_GuildInfo = { GuildRoster = function() Mock.fire("GUILD_ROSTER_UPDATE") end }
  _G.GetChannelName = function() return Mock.joined and 5 or 0 end
  _G.JoinTemporaryChannel = function() Mock.joined = true end
  _G.LeaveChannelByName = function() Mock.joined = false end
  _G.IsInRaid = function() return Mock.group == "RAID" end
  _G.IsInGroup = function() return Mock.group ~= nil end
  _G.WOW_PROJECT_MAINLINE, _G.WOW_PROJECT_CLASSIC, _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 1, 2, 5
  _G.WOW_PROJECT_ID = Mock.project or 1
  _G.ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
  Mock.filters = {}
  _G.ChatFrame_AddMessageEventFilter = function(event, fn) Mock.filters[event] = fn end
  _G.ChatFrame_OpenChat = function(text) Mock.chat = text end
  _G.IsControlKeyDown = function() return false end
  _G.ChatFrame_RemoveChannel = noop
  _G.RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 } }
  Mock.sent, Mock.routes = {}, {}
  -- the game echoes addon messages to the sender; Mock.echo lists the routes that do
  Mock.echo = Mock.echo or { GUILD = true, CHANNEL = true, PARTY = true, RAID = true, WHISPER = true }
  _G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, target, to)
      assert(prefix == "JMPR" and #msg <= 255)
      assert(target == "GUILD" or (target == "CHANNEL" and to == 5) or (target == "PARTY" and Mock.group)
        or (target == "RAID" and Mock.group == "RAID") or (target == "WHISPER" and type(to) == "string"))
      table.insert(Mock.sent, msg)
      table.insert(Mock.routes, { msg = msg, target = target, to = to })
      if Mock.echo[target] and (target ~= "WHISPER" or to == "Tester-TestRealm") then
        table.insert(timers, { at = clock + 0.5, once = true,
          fn = function() Mock.fire("CHAT_MSG_ADDON", prefix, msg, target, "Tester") end })
      end
      return true
    end,
  }
  _G.UnitLevel = function() return 12 end
  _G.GetCVar = function() return "eu" end
  _G.PlaySoundFile = function(path, channel)
    assert(path:match("%.ogg$") and channel == "SFX")
    Mock.sounds = (Mock.sounds or 0) + 1
  end
  _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
  _G.UISpecialFrames = {}
  _G.tinsert = table.insert
  _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  _G.unpack = _G.unpack or table.unpack
  _G.geterrorhandler = function() return error end
  _G.SlashCmdList = {}
  _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
  _G.Settings = { RegisterCanvasLayoutCategory = function() return {} end, RegisterAddOnCategory = noop }
  _G.PanelTemplates_SetNumTabs = noop
  _G.PanelTemplates_SetTab = noop
  _G.PanelTemplates_TabResize = noop
  _G.print = noop
end

function Mock.load(toc, project)
  Mock.project = project
  install()
  local ns = {}
  for line in io.lines(toc) do
    local file = line:match("^(src\\.+%.lua)$")
    if file then
      local path = file:gsub("\\", "/")
      assert(loadfile(path))("Jumpers", ns)
    end
  end
  return ns
end

function Mock.fire(event, ...)
  for _, f in ipairs(eventFrames[event] or {}) do
    f.scripts.OnEvent(f, event, ...)
  end
end

-- Advances the clock in small steps, running timers and every visible OnUpdate.
function Mock.advance(seconds)
  local step = 0.02
  local stop = clock + seconds
  while clock < stop - 1e-9 do
    clock = clock + step
    for i = #timers, 1, -1 do
      local t = timers[i]
      if t.cancelled then
        table.remove(timers, i)
      elseif clock >= t.at then
        if t.once then
          table.remove(timers, i)
          t.fn()
        else
          t.at = t.at + t.every
          t.fn(t)
          if t.left then
            t.left = t.left - 1
            if t.left <= 0 then t.cancelled = true end
          end
        end
      end
    end
    for _, f in ipairs(frames) do
      local u = f.scripts.OnUpdate
      if u and f:IsVisible() then u(f, step) end
    end
  end
end

function Mock.jump()
  _G.JumpOrAscendStart()
  Mock.advance(0.06)
  Mock.falling = true
  Mock.advance(0.5)
  Mock.falling = false
end

return Mock
