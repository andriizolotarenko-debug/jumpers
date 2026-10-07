-- Leaderboard tab (R4, UI-SPEC: Main window).
local _, ns = ...

local BoardTab = {}
ns.BoardTab = BoardTab

local W = 600
local ROW = 22
local MAX_ROWS = 50
local COLS = { rank = 14, player = 52, best = 420, when = W - 16 }
local DOT = "|TInterface\\FriendsFrame\\StatusIcon-Online:10:10:0:0|t"
local PERIODS = {
  { label = "Today", value = 1 },
  { label = "7 days", value = 7 },
  { label = "30 days", value = 30 },
  { label = "Year", value = 365 },
}
local MEDALS = { { 1, 0.82, 0.2 }, { 0.85, 0.88, 0.92 }, { 0.85, 0.55, 0.3 } }

local period = 1
local onlineOnly = false
local ui = {}

local function at(region, parent, x, y)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  return region
end

local function ago(e)
  local now = GetServerTime and GetServerTime() or time()
  local d = now - e
  if d < 60 then return "just now" end
  if d < 3600 then return math.floor(d / 60) .. " min ago" end
  if d < 86400 then return math.floor(d / 3600) .. " h ago" end
  if d < 86400 * 2 then return "yesterday" end
  return date("%b %d", e)
end

local function classColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.85, 0.85, 0.85
end

local function buildRows(card)
  local scroll = CreateFrame("ScrollFrame", nil, card)
  scroll:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -30)
  scroll:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(W, ROW * MAX_ROWS)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * ROW * 3)))
  end)
  ui.scroll, ui.content = scroll, content
  ui.rows = {}
  for i = 1, MAX_ROWS do
    local row = at(CreateFrame("Frame", nil, content), content, 0, -(i - 1) * ROW)
    row:SetSize(W, ROW)
    row.zebra = row:CreateTexture(nil, "BACKGROUND")
    row.zebra:SetAllPoints()
    row.zebra:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
    row.mine = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.mine:SetAllPoints()
    row.mine:SetColorTexture(1, 0.82, 0.2, 0.14)
    row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.rank:SetPoint("LEFT", COLS.rank, 0)
    row.rank:SetWidth(30)
    row.rank:SetJustifyH("LEFT")
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", COLS.player, 0)
    row.best = ns.Window.Number(row, 17)
    row.best:SetPoint("RIGHT", row, "LEFT", COLS.best, 0)
    row.when = ns.Window.Note(row)
    row.when:SetPoint("RIGHT", row, "LEFT", COLS.when, 0)
    row:Hide()
    ui.rows[i] = row
  end
end

function BoardTab.Build(page)
  local W_ = ns.Window
  ui.title = at(page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"), page, 2, -2)
  ui.title:SetText("Best single streak")
  ui.sub = at(W_.Note(page), page, 2, -24)

  ui.period = W_.Segmented(page, PERIODS, 70, function(v) period = v; BoardTab.Refresh() end)
  ui.period.box:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -48)
  ui.online = W_.Check(page, "Players online", function(v) onlineOnly = v; BoardTab.Refresh() end)
  ui.online:SetPoint("TOPRIGHT", page, "TOPRIGHT", -110, -47)

  local card = at(W_.Card(page, W, 380), page, 0, -82)
  local heads = {
    { "#", "LEFT", COLS.rank }, { "Player", "LEFT", COLS.player },
    { "Best streak", "RIGHT", COLS.best }, { "When", "RIGHT", COLS.when },
  }
  for _, h in ipairs(heads) do
    local fs = W_.Caps(card, h[1])
    if h[2] == "LEFT" then
      fs:SetPoint("TOPLEFT", card, "TOPLEFT", h[3], -10)
    else
      fs:SetPoint("TOPRIGHT", card, "TOPLEFT", h[3], -10)
    end
  end
  local sep = card:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(0.55, 0.45, 0.28, 0.35)
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -26)
  sep:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -26)
  buildRows(card)
  ui.empty = W_.Note(card)
  ui.empty:SetPoint("CENTER", card, "CENTER", 0, 10)
  ui.empty:SetWidth(440)
  ui.empty:SetJustifyH("CENTER")

  ui.foot = at(W_.Note(page), page, 2, -470)
  ui.foot:SetWidth(W)

  page:SetScript("OnShow", BoardTab.Refresh)
  local acc = 0
  page:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc > 15 then acc = 0; BoardTab.Refresh() end
  end)
  ns.On("BOARD", function() if page:IsVisible() then BoardTab.Refresh() end end)
end

function BoardTab.Refresh()
  if not ui.rows or not ns.board then return end
  local today = ns.Today()
  local online = ns.Comm.Online()
  local list = ns.Board.top(ns.board, today, period, onlineOnly and online or nil)
  local me = ns.Comm.Me()
  ui.period:Select(period)
  ui.online:SetChecked(onlineOnly)

  local count = 0
  for _ in pairs(online) do count = count + 1 end
  local realm = GetRealmName and GetRealmName() or ""
  ui.sub:SetText(string.format("%s \194\183 %d with Jumpers online", realm, count))

  for i, row in ipairs(ui.rows) do
    local r = list[i]
    row:SetShown(r ~= nil)
    if r then
      local medal = MEDALS[i]
      row.rank:SetText(i)
      if medal then row.rank:SetTextColor(medal[1], medal[2], medal[3]) else row.rank:SetTextColor(0.6, 0.6, 0.6) end
      row.name:SetText(ns.Comm.Short(r.p) .. (online[r.p] and (" " .. DOT) or ""))
      row.name:SetTextColor(classColor(r.c))
      local g = ns.Tiers.look(r.n).glow
      row.best:SetText("x" .. r.n)
      row.best:SetTextColor(g[1], g[2], g[3])
      row.when:SetText(ago(r.e))
      row.mine:SetShown(r.p == me)
    end
  end
  ui.content:SetHeight(math.max(1, math.min(#list, MAX_ROWS)) * ROW)

  if #list == 0 then
    ui.empty:SetText(onlineOnly and "Nobody online has a streak above x10 in this period yet."
      or "No streaks yet. Streaks above x10 show up here: yours, and everyone's on your realm who runs Jumpers.")
    ui.empty:Show()
  else
    ui.empty:Hide()
  end

  local st = ns.Comm.status
  local via = st.channel and (st.guild and "your guild and the Jumpers channel" or "the Jumpers channel")
    or (st.guild and "your guild only" or "nobody yet: no guild, and the channel is unavailable")
  ui.foot:SetText("Shared live through " .. via .. ". Records relayed by others stay hidden until two players confirm them.")
end
