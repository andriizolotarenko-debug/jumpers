-- Leaderboard tab (R4, UI-SPEC: Main window).
local _, ns = ...

local BoardTab = {}
ns.BoardTab = BoardTab

local W = 600
local ROW = 26
local MAX_ROWS = 50
local CARD_H = 380
local VIEW = CARD_H - 34                -- list height when your place is not pinned
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
local demo = false
local ui = {}

-- ---------- streak badge: a small copy of the counter's ribbon ----------

local M = ns.MEDIA
local BH = 16                           -- band height
local K = BH / 28                       -- scale against the counter's 28 px band
local B0 = 0.75
local GOLD_TOP, GOLD_BOTTOM = { 1, 0.906, 0.627 }, { 0.612, 0.416, 0.11 }

local function badge(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(1, BH)
  b.tails = {}
  for i = 1, 2 do
    local t = b:CreateTexture(nil, "ARTWORK", nil, 0)
    t:SetTexture(M .. "ribbon_side")
    if i == 1 then t:SetTexCoord(0, 160 / 256, 0, 144 / 256) else t:SetTexCoord(160 / 256, 0, 0, 144 / 256) end
    t:SetSize(40 * K, 36 * K)
    local trim = b:CreateTexture(nil, "ARTWORK", nil, 1)
    trim:SetTexture(M .. "ribbon_trim_side")
    if i == 1 then trim:SetTexCoord(0, 160 / 256, 0, 144 / 256) else trim:SetTexCoord(160 / 256, 0, 0, 144 / 256) end
    trim:SetSize(40 * K, 36 * K)
    b.tails[i] = { t, trim }
  end
  b.tails[1][1]:SetPoint("CENTER", b, "LEFT", -6 * K, -6 * K)
  b.tails[1][2]:SetPoint("CENTER", b, "LEFT", -6 * K, -6 * K)
  b.tails[2][1]:SetPoint("CENTER", b, "RIGHT", 6 * K, -6 * K)
  b.tails[2][2]:SetPoint("CENTER", b, "RIGHT", 6 * K, -6 * K)
  b.band = b:CreateTexture(nil, "ARTWORK", nil, 2)
  b.band:SetTexture(M .. "ribbon_mid", "REPEAT", "CLAMP")
  b.band:SetAllPoints()
  b.rainbow = b:CreateTexture(nil, "ARTWORK", nil, 3)
  b.rainbow:SetTexture(M .. "rainbow", "REPEAT", "CLAMP")
  b.rainbow:SetBlendMode("MOD")
  b.rainbow:SetAllPoints()
  -- trim: dark rim + gold line on all four edges
  for _, spec in ipairs({ { "TOP", GOLD_TOP }, { "BOTTOM", GOLD_BOTTOM } }) do
    local rim = b:CreateTexture(nil, "ARTWORK", nil, 4)
    rim:SetColorTexture(0.1, 0.067, 0.027, 1)
    rim:SetPoint(spec[1] .. "LEFT", -1, spec[1] == "TOP" and 1 or -1)
    rim:SetPoint(spec[1] .. "RIGHT", 1, spec[1] == "TOP" and 1 or -1)
    rim:SetHeight(2.2)
    local g = b:CreateTexture(nil, "ARTWORK", nil, 5)
    g:SetColorTexture(spec[2][1], spec[2][2], spec[2][3], 1)
    g:SetPoint(spec[1] .. "LEFT", 0, spec[1] == "TOP" and 0.5 or -0.5)
    g:SetPoint(spec[1] .. "RIGHT", 0, spec[1] == "TOP" and 0.5 or -0.5)
    g:SetHeight(1)
  end
  for _, side in ipairs({ "LEFT", "RIGHT" }) do
    local rim = b:CreateTexture(nil, "ARTWORK", nil, 4)
    rim:SetColorTexture(0.1, 0.067, 0.027, 1)
    rim:SetPoint("TOP" .. side, side == "LEFT" and -1 or 1, 1)
    rim:SetPoint("BOTTOM" .. side, side == "LEFT" and -1 or 1, -1)
    rim:SetWidth(2.2)
    local g = b:CreateTexture(nil, "ARTWORK", nil, 5)
    g:SetColorTexture(0.85, 0.65, 0.25, 1)
    g:SetPoint("TOP" .. side, side == "LEFT" and -0.5 or 0.5, 0.5)
    g:SetPoint("BOTTOM" .. side, side == "LEFT" and -0.5 or 0.5, -0.5)
    g:SetWidth(1)
  end
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFont(ns.FONT, 14, "")
  if not b.text:GetFont() then b.text:SetFont(STANDARD_TEXT_FONT, 13, "") end
  b.text:SetShadowOffset(1, -1)
  b.text:SetShadowColor(0, 0, 0, 1)
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0.5)
  return b
end

local function setBadge(b, n)
  local look = ns.Tiers.look(n)
  local digits = #tostring(n)
  local w = (0.54 + 0.6 * digits) * 14 + 16
  b:SetWidth(w)
  b.band:SetTexCoord(0, w / (BH / 28 * 32), 0, 28 / 32)
  b.rainbow:SetTexCoord(0, w / 60, 0, 1)
  b.rainbow:SetShown(look.rainbow)
  local c = look.cloth
  local tint = { math.min(1, c[1] / B0), math.min(1, c[2] / B0), math.min(1, c[3] / B0) }
  if look.rainbow then b.band:SetVertexColor(1, 1, 1) else b.band:SetVertexColor(tint[1], tint[2], tint[3]) end
  local side = look.rainbow and ns.Tiers.hsv(0.8, 0.7, 0.85) or tint
  for i = 1, 2 do b.tails[i][1]:SetVertexColor(side[1], side[2], side[3]) end
  local f = look.face
  b.text:SetText("x" .. n)
  b.text:SetTextColor(f[1], f[2], f[3])
end

-- ---------- sample board for screenshots (/jumpers demoboard): shown only, never stored ----------

local DEMO = {
  { "Velaria", "DRUID", 1240, 380, true }, { "Grimtusk", "WARRIOR", 812, 1500, true },
  { "Moonwhisper", "PRIEST", 455, 3100 }, { "Kazgrim", "SHAMAN", 318, 5200, true },
  { "Elyndra", "MAGE", 262, 7400 }, { "Brokkar", "PALADIN", 214, 9800, true },
  { "Sylvaris", "HUNTER", 187, 12500 }, { "Faeliss", "ROGUE", 142, 15800, true },
  { "Dornak", "WARLOCK", 120, 21000 }, { "Lunarae", "DRUID", 96, 26500 },
  { "Hrothgar", "WARRIOR", 77, 31000, true }, { "Tiriwen", "PRIEST", 61, 36500 },
  { "Morghul", "WARLOCK", 49, 41000 }, { "Aethelyn", "PALADIN", 38, 47000, true },
  { "Quillon", "HUNTER", 27, 52000 }, { "Zarethis", "MAGE", 19, 60000 },
}

local function demoList()
  local now = GetServerTime and GetServerTime() or time()
  local list, online = {}, {}
  local me = ns.Comm.Me()
  local mine = me and { p = me, c = select(2, UnitClass("player")), n = 233, e = now - 600 }
  local scale = period == 1 and 1 or (period == 7 and 1.15 or (period == 30 and 1.3 or 1.6))
  for i, d in ipairs(DEMO) do
    local p = d[1] .. "-Demo"
    local n = math.floor(d[3] * (i % 3 == 0 and scale or 1))
    list[#list + 1] = { p = p, c = d[2], n = n, e = now - d[4] * (period == 1 and 1 or 3) }
    if d[5] then online[p] = true end
  end
  if mine then list[#list + 1] = mine; online[me] = true end
  table.sort(list, function(a, b) return a.n > b.n end)
  if onlineOnly then
    local only = {}
    for _, r in ipairs(list) do if online[r.p] then only[#only + 1] = r end end
    list = only
  end
  return list, online
end

function BoardTab.ToggleDemo()
  demo = not demo
  ns.Window.Show("board")
  BoardTab.Refresh()
  ns.Print(demo and "sample leaderboard on (for screenshots, nothing is stored)" or "sample leaderboard off")
end

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

local function makeRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(W, ROW)
  row.zebra = row:CreateTexture(nil, "BACKGROUND")
  row.zebra:SetAllPoints()
  row.mine = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.mine:SetAllPoints()
  row.mine:SetColorTexture(1, 0.82, 0.2, 0.14)
  row.rank = ns.Window.Number(row, 15)
  row.rank:SetPoint("LEFT", COLS.rank, 0)
  row.rank:SetWidth(36)
  row.rank:SetJustifyH("LEFT")
  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.name:SetPoint("LEFT", COLS.player, 0)
  row.best = badge(row)
  row.best:SetPoint("RIGHT", row, "LEFT", COLS.best - 10, 1)
  row.when = ns.Window.Note(row)
  row.when:SetPoint("RIGHT", row, "LEFT", COLS.when, 0)
  return row
end

-- rank: a number, "50+" past the list, or nil when the player has no streak in the period.
local function fill(row, r, rank, online, me)
  local medal = type(rank) == "number" and MEDALS[rank]
  row.rank:SetText(rank or "-")
  if medal then row.rank:SetTextColor(medal[1], medal[2], medal[3]) else row.rank:SetTextColor(0.6, 0.6, 0.6) end
  row.name:SetText(ns.Comm.Short(r.p) .. (online[r.p] and (" " .. DOT) or ""))
  row.name:SetTextColor(classColor(r.c))
  row.best:SetShown(r.n ~= nil)
  if r.n then setBadge(row.best, r.n) end
  row.when:SetText(r.e and ago(r.e) or "no streak above x10 yet")
  row.mine:SetShown(r.p == me)
end

-- Shows your place pinned under the list only while your own row is out of sight.
local function updatePinned()
  local top = ui.scroll:GetVerticalScroll()
  local rank = ui.myRank
  local inView = rank and rank <= MAX_ROWS and (rank - 1) * ROW >= top - 1 and rank * ROW <= top + VIEW + 1
  local show = ui.me ~= nil and ui.count > 0 and not inView
  ui.pinned:SetShown(show)
  ui.pinSep:SetShown(show)
  ui.scroll:ClearAllPoints()
  ui.scroll:SetPoint("TOPLEFT", ui.card, "TOPLEFT", 0, -30)
  ui.scroll:SetPoint("BOTTOMRIGHT", ui.card, "BOTTOMRIGHT", 0, show and (ROW + 10) or 4)
end

local function buildTail(content)
  local W_ = ns.Window
  local tail = CreateFrame("Frame", nil, content)
  tail:SetSize(W, 1)
  ui.tail = tail
  ui.empty = W_.Note(tail)
  ui.empty:SetWidth(460)
  ui.empty:SetJustifyH("CENTER")
  ui.classic = W_.Note(tail)
  ui.classic:SetWidth(520)
  ui.classic:SetJustifyH("CENTER")
  ui.invite = tail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ui.invite:SetText("The more friends run Jumpers, the more fun the board gets.")
  ui.copy = W_.Button(tail, "Copy link", 120, function() ns.Share.CopyLink() end)
  ui.tell = W_.Button(tail, "Tell a friend", 120, function()
    local mine = ui.myRec
    ns.Share.Tell(mine and string.format("Jump with me! My best streak is x%d on the Jumpers leaderboard. Get it:", mine.n)
      or "Jump with me! I chain jumps into streaks with the Jumpers addon. Get it:")
  end)
end

-- Lays the empty note, the Classic note and the invite out under the last row.
local function layoutTail(count)
  local y = 0
  local function place(region, h, x)
    region:ClearAllPoints()
    region:SetPoint("TOP", ui.tail, "TOP", x or 0, -y)
    y = y + h
  end
  ui.tail:ClearAllPoints()
  ui.tail:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, -(count * ROW) - 14)
  for _, fs in ipairs({ ui.empty, ui.classic }) do
    if fs:IsShown() then place(fs, fs:GetStringHeight() + 12) end
  end
  place(ui.invite, 22)
  ui.copy:ClearAllPoints()
  ui.copy:SetPoint("TOPRIGHT", ui.tail, "TOP", -4, -y)
  ui.tell:ClearAllPoints()
  ui.tell:SetPoint("TOPLEFT", ui.tail, "TOP", 4, -y)
  y = y + 26
  ui.tail:SetHeight(y)
  ui.content:SetHeight(count * ROW + 14 + y + 8)
end

local function buildRows(card)
  ui.card = card
  local scroll = CreateFrame("ScrollFrame", nil, card)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(W, ROW * MAX_ROWS)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * ROW * 3)))
    updatePinned()
  end)
  ui.scroll, ui.content = scroll, content
  ui.rows = {}
  for i = 1, MAX_ROWS do
    local row = at(makeRow(content), content, 0, -(i - 1) * ROW)
    row.zebra:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
    row:Hide()
    ui.rows[i] = row
  end
  buildTail(content)

  -- your own place, pinned under the list while your row is out of sight
  local sep = card:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(0.55, 0.45, 0.28, 0.35)
  sep:SetHeight(1)
  sep:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, ROW + 7)
  sep:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, ROW + 7)
  ui.pinSep = sep
  ui.pinned = makeRow(card)
  ui.pinned:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 4)
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

  local card = at(W_.Card(page, W, CARD_H), page, 0, -82)
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
  if demo then list, online = demoList() end
  local me = ns.Comm.Me()
  ui.period:Select(period)
  ui.online:SetChecked(onlineOnly)

  local count = 0
  for _ in pairs(online) do count = count + 1 end
  local realm = GetRealmName and GetRealmName() or ""
  ui.sub:SetText(string.format("%s \194\183 %d with Jumpers online", realm, count))

  local myRank, myRec
  for i, r in ipairs(list) do
    if r.p == me then myRank, myRec = i, r; break end
  end
  for i, row in ipairs(ui.rows) do
    local r = list[i]
    row:SetShown(r ~= nil)
    if r then fill(row, r, i, online, me) end
  end
  ui.me, ui.myRank, ui.myRec, ui.count = me, myRank, myRec, #list
  if me then
    -- past the list we only know a part of the realm, so the place is "50+", not a number
    local rank = myRank and (myRank > MAX_ROWS and (MAX_ROWS .. "+") or myRank)
    fill(ui.pinned, myRec or { p = me, c = select(2, UnitClass("player")) }, rank, online, me)
  end

  local st = ns.Comm.status
  ui.empty:SetShown(#list == 0)
  ui.empty:SetText(onlineOnly and "Nobody online has a streak above x10 in this period yet."
    or "No streaks yet. Streaks above x10 show up here: yours, and everyone's on your realm who runs Jumpers.")
  ui.classic:SetShown(ns.Comm.Fallback())
  ui.classic:SetText((st.channelState == "off" and "Classic clients" or "This client")
    .. " can't share records through a realm-wide channel, so they travel through your guild, your group"
    .. " and players you've met. Jumpers works best in a guild.")
  layoutTail(math.min(#list, MAX_ROWS))
  local maxScroll = math.max(0, ui.content:GetHeight() - VIEW)
  if ui.scroll:GetVerticalScroll() > maxScroll then ui.scroll:SetVerticalScroll(maxScroll) end
  updatePinned()

  local routes = {}
  if st.guild then routes[#routes + 1] = "your guild" end
  if st.channelState == "ok" then routes[#routes + 1] = "the Jumpers channel" end
  if st.channelState == "probing" then routes[#routes + 1] = "the Jumpers channel (connecting)" end
  if ns.Comm.Fallback() then
    routes[#routes + 1] = "your group"
    routes[#routes + 1] = "players you've met"
  end
  local via = #routes > 1 and (table.concat(routes, ", ", 1, #routes - 1) .. " and " .. routes[#routes]) or routes[1]
  ui.foot:SetText("Shared live through " .. via .. ". Records relayed by others stay hidden until two players confirm them.")
end
