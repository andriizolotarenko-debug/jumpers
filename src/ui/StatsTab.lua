-- Personal Stats tab (UI-SPEC: Main window).
local _, ns = ...

local StatsTab = {}
ns.StatsTab = StatsTab

local W = 600
local ROW = 20
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
local scope = "char"
local listOpen = false
local ui = {}

local issecret = issecretvalue or function() return false end

local function stats()
  return scope == "account" and ns.account or ns.char
end

local function tierColor(n)
  if not n or n <= 0 then return { 0.45, 0.45, 0.45 } end
  return ns.Tiers.look(n).glow
end

local function at(region, parent, x, y)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  return region
end

local function right(region, parent, x, y)
  region:ClearAllPoints()
  region:SetPoint("TOPRIGHT", parent, "TOPLEFT", x, y)
  return region
end

-- A plain scroll area driven by the mouse wheel; scrolls only when the content is taller.
local function scrollArea(page)
  local scroll = CreateFrame("ScrollFrame", nil, page)
  scroll:SetAllPoints()
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(W, 400)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
    local v = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 40))
    self:SetVerticalScroll(v)
  end)
  return scroll, content
end

local function buildHeader(c)
  local W_ = ns.Window
  ui.name = at(c:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"), c, 2, -2)
  ui.who = at(W_.Note(c), c, 2, -24)
  ui.scope = W_.Segmented(c, {
    { label = "Character", value = "char" },
    { label = "Account", value = "account" },
  }, 84, function(v) scope = v; StatsTab.Refresh() end)
  ui.scope.box:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2, -4)
end

local function buildHeight(c)
  local W_ = ns.Window
  local card = at(W_.Card(c, W, 150), c, 0, -48)
  at(W_.Caps(card, "Height climbed"), card, 16, -14)
  ui.height = at(W_.Number(card, 40), card, 14, -30)
  ui.height:SetTextColor(1, 1, 1)
  ui.heightSub = W_.Note(card)
  ui.heightSub:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT", -16, -66)

  ui.from = at(card:CreateFontString(nil, "ARTWORK", "GameFontHighlight"), card, 16, -80)
  ui.to = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ui.to:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -80)

  local track = at(CreateFrame("Frame", nil, card), card, 16, -98)
  track:SetSize(W - 32, 12)
  local tbg = track:CreateTexture(nil, "BACKGROUND")
  tbg:SetAllPoints()
  tbg:SetColorTexture(0, 0, 0, 0.75)
  W_.Border(track, 0.55, 0.45, 0.28, 0.45)
  local bar = CreateFrame("StatusBar", nil, track)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("BOTTOMRIGHT", -1, 1)
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  bar:SetMinMaxValues(0, 1)
  local fill = bar:GetStatusBarTexture()
  fill:SetVertexColor(1, 1, 1, 1)
  local ok = CreateColor and fill.SetGradient and pcall(fill.SetGradient, fill, "HORIZONTAL",
    CreateColor(0.62, 0.42, 0.11, 1), CreateColor(1, 0.8, 0.35, 1))
  if not ok then bar:SetStatusBarColor(0.95, 0.72, 0.2) end
  ui.bar = bar

  ui.fromM = at(W_.Note(card), card, 16, -116)
  ui.toM = W_.Note(card)
  ui.toM:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -116)
  ui.progress = at(W_.Note(card), card, 16, -132)
end

local function buildTotals(c)
  local W_ = ns.Window
  local cw = (W - 12) / 2
  local card = at(W_.Card(c, cw, 142), c, 0, -210)
  local cols = { 180, cw - 16 }
  for i, name in ipairs({ "Today", "All time" }) do right(W_.Caps(card, name), card, cols[i], -14) end
  ui.totals = {}
  for r, name in ipairs({ "Jumps", "Floors", "Streaks" }) do
    local y = -34 - (r - 1) * 34
    local sep = card:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.55, 0.45, 0.28, 0.2)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
    sep:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, y)
    local label = at(card:CreateFontString(nil, "ARTWORK", "GameFontHighlight"), card, 16, y - 10)
    label:SetText(name)
    label:SetTextColor(0.8, 0.78, 0.74)
    ui.totals[r] = {}
    for i = 1, 2 do
      ui.totals[r][i] = right(W_.Number(card, 18), card, cols[i], y - 8)
    end
  end

  local best = at(W_.Card(c, cw, 142), c, cw + 12, -210)
  at(W_.Caps(best, "Best streak"), best, 16, -14)
  ui.best = {}
  local cell = (cw - 32) / 3
  for i, name in ipairs({ "Today", "7 days", "30 days", "Year", "All time" }) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local x, y = 16 + col * cell, -36 - row * 52
    at(ns.Window.Note(best, name), best, x, y)
    ui.best[i] = at(W_.Number(best, 22), best, x - 1, y - 14)
  end
end

local function buildMilestones(c)
  local W_ = ns.Window
  local card = at(W_.Card(c, W, 30), c, 0, -364)
  local toggle = CreateFrame("Button", nil, card)
  toggle:SetAllPoints()
  toggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  ui.arrow = toggle:CreateTexture(nil, "ARTWORK")
  ui.arrow:SetSize(14, 14)
  ui.arrow:SetPoint("LEFT", 12, 0)
  ui.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  ui.toggleText = toggle:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ui.toggleText:SetPoint("LEFT", ui.arrow, "RIGHT", 6, 0)
  toggle:SetScript("OnClick", function()
    listOpen = not listOpen
    StatsTab.Refresh()
    if listOpen and ui.scroll then ui.scroll:SetVerticalScroll(0) end
  end)

  ui.rows = {}
  for i = 1, #ns.Landmarks do
    local row = at(CreateFrame("Frame", nil, c), c, 0, -400 - (i - 1) * ROW)
    row:SetSize(W, ROW)
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 0.82, 0.2, 0.12)
    row.zebra = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    row.zebra:SetAllPoints()
    row.zebra:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
    row.mark = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.mark:SetPoint("LEFT", 12, 0)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 44, 0)
    row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", -12, 0)
    ui.rows[i] = row
  end
end

function StatsTab.Build(page)
  local ok, scroll, content = pcall(scrollArea, page)
  if not ok then
    content = CreateFrame("Frame", nil, page)
    content:SetPoint("TOPLEFT")
    content:SetSize(W, 400)
  end
  ui.scroll, ui.content = ok and scroll or nil, content
  buildHeader(content)
  buildHeight(content)
  buildTotals(content)
  buildMilestones(content)

  page:SetScript("OnShow", StatsTab.Refresh)
  ns.On("JUMP", function() if page:IsVisible() then StatsTab.Refresh() end end)
  ns.On("STREAK_END", function() if page:IsVisible() then StatsTab.Refresh() end end)
  ns.On("SETTINGS", function(key) if key == "units" and page:IsVisible() then StatsTab.Refresh() end end)
end

local function setWho()
  if scope == "account" then
    ui.name:SetText("Account")
    ui.who:SetText("All your characters together")
    return
  end
  local name = UnitName and UnitName("player")
  if name and not issecret(name) then ui.name:SetText(name) else ui.name:SetText("This character") end
  local level = UnitLevel and UnitLevel("player")
  if type(level) == "number" and not issecret(level) then
    ui.who:SetText("Level " .. level .. " \194\183 this character")
  else
    ui.who:SetText("This character")
  end
end

function StatsTab.Refresh()
  if not ui.content then return end
  local s = stats()
  local unit = ns.Settings.Units()
  local U, L = ns.Units, ns.Landmarks
  local today = ns.Today()
  ui.scope:Select(scope)
  setWho()

  ui.height:SetText(U.format(U.heightM(s.jumps), unit))
  local per = unit == "ft" and string.format("%.1f ft", U.HEIGHT_PER_JUMP_M * U.FT_PER_M)
    or string.format("%.1f m", U.HEIGHT_PER_JUMP_M)
  ui.heightSub:SetText(U.int(s.jumps) .. " jumps \195\151 " .. per .. ", as if every jump were a step up")

  local k, frac, togo = U.progress(s.jumps, L)
  ui.from:SetText(k > 0 and L[k].name or "Start")
  ui.fromM:SetText(k > 0 and (U.format(L[k].m, unit) .. " " .. CHECK) or U.format(0, unit))
  if k < #L then
    ui.to:SetText(L[k + 1].name)
    ui.toM:SetText(U.format(L[k + 1].m, unit))
    ui.progress:SetText(string.format(
      "Milestone |cffffffff%d of %d|r \194\183 %d%% there \194\183 |cffffffff%s jumps|r to go",
      k + 1, #L, math.floor(frac * 100), U.int(togo)))
  else
    ui.to:SetText("")
    ui.toM:SetText("")
    ui.progress:SetText("Every milestone passed. Legendary.")
  end
  ui.bar:SetValue(frac)

  local tj, ts = ns.Stats.today(s, today)
  local values = {
    { tj, s.jumps },
    { U.floors(tj, unit), U.floors(s.jumps, unit) },
    { ts, s.streaks },
  }
  for r = 1, 3 do
    for i = 1, 2 do ui.totals[r][i]:SetText(U.int(values[r][i])) end
  end

  local bests = {
    ns.Stats.periodBest(s, today, 1),
    ns.Stats.periodBest(s, today, 7),
    ns.Stats.periodBest(s, today, 30),
    ns.Stats.periodBest(s, today, 365),
    s.best,
  }
  for i = 1, 5 do
    local n = bests[i]
    local c = tierColor(n)
    ui.best[i]:SetText(n > 0 and ("x" .. n) or "-")
    ui.best[i]:SetTextColor(c[1], c[2], c[3])
  end

  if ui.arrow.SetRotation then ui.arrow:SetRotation(listOpen and -math.pi / 2 or 0) end
  ui.toggleText:SetText(string.format("All milestones \194\183 %d of %d passed", k, #L))
  for i, row in ipairs(ui.rows) do
    row:SetShown(listOpen)
    if listOpen then
      local lm = L[i]
      row.mark:SetText(i <= k and CHECK or ("|cff808080" .. i .. "|r"))
      row.name:SetText(lm.name)
      row.value:SetText(U.format(lm.m, unit))
      local c = i <= k and { 0.92, 0.92, 0.92 } or (i == k + 1 and { 1, 0.82, 0.2 } or { 0.5, 0.5, 0.5 })
      row.name:SetTextColor(c[1], c[2], c[3])
      row.value:SetTextColor(c[1], c[2], c[3])
      row.hl:SetShown(i == k + 1)
    end
  end
  ui.content:SetHeight(listOpen and (400 + #L * ROW + 8) or 396)
  if not listOpen and ui.scroll then ui.scroll:SetVerticalScroll(0) end
end
