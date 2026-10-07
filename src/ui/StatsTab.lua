-- Personal Stats tab (UI-SPEC: Main window).
local _, ns = ...

local StatsTab = {}
ns.StatsTab = StatsTab

local W = 536
local ROW = 18
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
local scope = "char"
local listOpen = false
local ui = {}

local function stats()
  return scope == "account" and ns.account or ns.char
end

local function tierText(n)
  if not n or n <= 0 then return "|cff8a8a8a-|r" end
  local g = ns.Tiers.look(n).glow
  return string.format("|cff%02x%02x%02xx%d|r", g[1] * 255, g[2] * 255, g[3] * 255, n)
end

local function scrollFrame(page)
  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(W, 400)
  scroll:SetScrollChild(content)
  return scroll, content
end

local function at(region, x, y)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", ui.content, "TOPLEFT", x, y)
  return region
end

function StatsTab.Build(page)
  local ok, scroll, content = pcall(scrollFrame, page)
  if not ok then
    content = CreateFrame("Frame", nil, page)
    content:SetPoint("TOPLEFT")
    content:SetSize(W, 400)
  end
  ui.scroll, ui.content = scroll, content
  local T = ns.Window.Text

  ui.scope = ns.Window.Segmented(content, {
    { label = "Character", value = "char" },
    { label = "Account", value = "account" },
  }, 96, function(v) scope = v; StatsTab.Refresh() end)
  ui.scope.buttons[1]:SetPoint("TOPRIGHT", content, "TOPRIGHT", -100, 0)

  -- height climbed
  at(ns.Window.Header(content, "HEIGHT CLIMBED"), 0, 0)
  ui.height = at(content:CreateFontString(nil, "ARTWORK"), 0, -18)
  ui.height:SetFont(ns.FONT, 34, "")
  if not ui.height:GetFont() then ui.height:SetFont(STANDARD_TEXT_FONT, 30, "") end
  ui.height:SetTextColor(1, 0.92, 0.7)
  ui.heightSub = at(T(content, "GameFontHighlightSmall"), 0, -60)
  ui.heightSub:SetTextColor(0.7, 0.7, 0.7)

  -- progress to the next landmark
  ui.from = at(T(content, "GameFontHighlightSmall"), 0, -84)
  ui.to = T(content, "GameFontHighlightSmall")
  ui.to:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -84)
  local bar = CreateFrame("StatusBar", nil, content)
  bar:SetSize(W, 14)
  at(bar, 0, -100)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.95, 0.75, 0.25)
  bar:SetMinMaxValues(0, 1)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.55)
  ui.bar = bar
  ui.progress = at(T(content, "GameFontHighlightSmall"), 0, -120)
  ui.progress:SetTextColor(0.8, 0.8, 0.8)

  -- totals
  at(ns.Window.Header(content, "TOTALS"), 0, -150)
  local cols = { 300, 440 }
  for i, name in ipairs({ "Today", "All time" }) do
    local h = T(content, "GameFontNormalSmall", name)
    h:SetPoint("TOPRIGHT", content, "TOPLEFT", cols[i], -150)
  end
  ui.totals = {}
  for r, name in ipairs({ "Jumps", "Floors", "Streaks" }) do
    local y = -150 - r * 20
    at(T(content, "GameFontHighlight", name), 0, y)
    ui.totals[r] = {}
    for i = 1, 2 do
      local v = T(content, "GameFontHighlight")
      v:SetPoint("TOPRIGHT", content, "TOPLEFT", cols[i], y)
      ui.totals[r][i] = v
    end
  end

  -- best streaks
  at(ns.Window.Header(content, "BEST STREAK"), 0, -240)
  ui.best = {}
  local cell = W / 5
  for i, name in ipairs({ "Today", "7 days", "30 days", "Year", "All time" }) do
    local l = T(content, "GameFontHighlightSmall", name)
    l:SetPoint("TOP", content, "TOPLEFT", cell * (i - 0.5), -262)
    l:SetTextColor(0.7, 0.7, 0.7)
    local v = content:CreateFontString(nil, "ARTWORK")
    v:SetFont(ns.FONT, 22, "OUTLINE")
    if not v:GetFont() then v:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE") end
    v:SetPoint("TOP", l, "BOTTOM", 0, -4)
    ui.best[i] = v
  end

  -- all milestones, collapsible
  local toggle = CreateFrame("Button", nil, content)
  toggle:SetSize(W, 20)
  at(toggle, 0, -320)
  ui.toggleIcon = toggle:CreateTexture(nil, "ARTWORK")
  ui.toggleIcon:SetSize(14, 14)
  ui.toggleIcon:SetPoint("LEFT")
  ui.toggleText = toggle:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ui.toggleText:SetPoint("LEFT", ui.toggleIcon, "RIGHT", 6, 0)
  toggle:SetScript("OnClick", function() listOpen = not listOpen; StatsTab.Refresh() end)
  ui.rows = {}
  for i = 1, #ns.Landmarks do
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(W, ROW)
    at(row, 0, -346 - (i - 1) * ROW)
    row.mark = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.mark:SetPoint("LEFT", 0, 0)
    row.mark:SetWidth(22)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 26, 0)
    row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", 0, 0)
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 0.82, 0.2, 0.12)
    ui.rows[i] = row
  end

  page:SetScript("OnShow", StatsTab.Refresh)
  ns.On("JUMP", function() if page:IsVisible() then StatsTab.Refresh() end end)
  ns.On("STREAK_END", function() if page:IsVisible() then StatsTab.Refresh() end end)
  ns.On("SETTINGS", function(key) if key == "units" and page:IsVisible() then StatsTab.Refresh() end end)
end

function StatsTab.Refresh()
  if not ui.content then return end
  local s = stats()
  local unit = ns.Settings.Units()
  local U, L = ns.Units, ns.Landmarks
  local today = ns.Today()
  ui.scope:Select(scope)

  ui.height:SetText(U.format(U.heightM(s.jumps), unit))
  local per = unit == "ft" and string.format("%.1f ft", U.HEIGHT_PER_JUMP_M * U.FT_PER_M)
    or string.format("%.1f m", U.HEIGHT_PER_JUMP_M)
  ui.heightSub:SetText(U.int(s.jumps) .. " jumps \195\151 " .. per)

  local k, frac, togo = U.progress(s.jumps, L)
  ui.from:SetText(k > 0 and (CHECK .. " " .. L[k].name) or "Start")
  if k < #L then
    ui.to:SetText(L[k + 1].name .. " \226\128\162 " .. U.format(L[k + 1].m, unit))
    ui.progress:SetText(string.format("Milestone %d of %d \194\183 %d%% there \194\183 %s jumps to go",
      k + 1, #L, math.floor(frac * 100), U.int(togo)))
  else
    ui.to:SetText("")
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
  for i = 1, 5 do ui.best[i]:SetText(tierText(bests[i])) end

  ui.toggleIcon:SetTexture(listOpen and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
  ui.toggleText:SetText(string.format("ALL MILESTONES (%d/%d)", k, #L))
  for i, row in ipairs(ui.rows) do
    row:SetShown(listOpen)
    if listOpen then
      local lm = L[i]
      row.mark:SetText(i <= k and CHECK or tostring(i))
      row.name:SetText(lm.name)
      row.value:SetText(U.format(lm.m, unit))
      local c = i <= k and { 0.95, 0.95, 0.95 } or (i == k + 1 and { 1, 0.82, 0.2 } or { 0.5, 0.5, 0.5 })
      row.name:SetTextColor(c[1], c[2], c[3])
      row.value:SetTextColor(c[1], c[2], c[3])
      row.mark:SetTextColor(c[1], c[2], c[3])
      row.hl:SetShown(i == k + 1)
    end
  end
  ui.content:SetHeight(listOpen and (346 + #L * ROW + 10) or 350)
end
