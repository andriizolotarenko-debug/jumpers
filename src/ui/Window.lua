-- The Jumpers window: portrait frame with three tabs (R6.1), plus small shared widgets.
local _, ns = ...

local Window = {}
ns.Window = Window

local PAGES = {
  { key = "stats", label = "Personal Stats" },
  { key = "board", label = "Leaderboard" },
  { key = "settings", label = "Settings" },
}

local frame
local tabs, pages = {}, {}
local current = "stats"

local function try(template, kind, name, parent)
  local ok, f = pcall(CreateFrame, kind, name, parent, template)
  if ok and f then return f end
  return nil
end

-- ---------- widgets ----------

local GOLD = { 1, 0.82, 0 }
local MUTED = { 0.62, 0.6, 0.56 }
Window.GOLD, Window.MUTED = GOLD, MUTED

function Window.Header(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetText(text)
  return fs
end

function Window.Text(parent, template, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
  if text then fs:SetText(text) end
  return fs
end

-- Small grey help text.
function Window.Note(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  fs:SetJustifyH("LEFT")
  if text then fs:SetText(text) end
  return fs
end

-- Small caps label, like "HEIGHT CLIMBED".
function Window.Caps(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetTextColor(0.72, 0.68, 0.6)
  fs:SetText(text:upper())
  return fs
end

-- Changa One numbers with a hard shadow.
function Window.Number(parent, size, flags)
  local fs = parent:CreateFontString(nil, "ARTWORK")
  fs:SetFont(ns.FONT, size, flags or "")
  if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, flags or "") end
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 1)
  return fs
end

local function border(f, r, g, b, a)
  local t = {}
  for i, spec in ipairs({
    { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
    { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
  }) do
    local e = f:CreateTexture(nil, "BORDER")
    e:SetColorTexture(r, g, b, a)
    e:SetPoint(spec[1])
    e:SetPoint(spec[2])
    if spec[3] then e:SetWidth(spec[3]) else e:SetHeight(spec[4]) end
    t[i] = e
  end
  return t
end
Window.Border = border

-- A dark inset panel with a thin warm border.
function Window.Card(parent, w, h)
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(w, h)
  local bg = c:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.42)
  border(c, 0.55, 0.45, 0.28, 0.35)
  return c
end

-- A gold section title with a hairline under it.
function Window.Section(parent, text, width)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetText(text)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.55, 0.45, 0.28, 0.35)
  line:SetHeight(1)
  line:SetWidth(width)
  line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -5)
  return fs
end

function Window.Button(parent, text, width, onClick)
  local b = try("UIPanelButtonTemplate", "Button", nil, parent) or CreateFrame("Button", nil, parent)
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

function Window.Check(parent, text, onClick)
  local cb = try("UICheckButtonTemplate", "CheckButton", nil, parent)
    or try("ChatConfigCheckButtonTemplate", "CheckButton", nil, parent)
  cb:SetSize(26, 26)
  if cb.Text then cb.Text:SetText("") end
  if cb.text then cb.text:SetText("") end
  local label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
  label:SetText(text)
  cb.label = label
  cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
  return cb
end

-- Page-arrow stepper button ("<" or ">").
function Window.Stepper(parent, dir, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(24, 24)
  local name = dir < 0 and "PrevPage" or "NextPage"
  b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Down")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  b:SetScript("OnClick", onClick)
  return b
end

-- A slim slider with a gold fill. Steps snap; SetSilently skips the callback.
function Window.Slider(parent, width, min, max, step, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(width, 18)
  s:SetMinMaxValues(min, max)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0, 0, 0, 0.7)
  track:SetPoint("LEFT", 0, 0)
  track:SetPoint("RIGHT", 0, 0)
  track:SetHeight(6)
  local fill = s:CreateTexture(nil, "ARTWORK")
  fill:SetColorTexture(0.95, 0.72, 0.15, 1)
  fill:SetPoint("LEFT", track, "LEFT", 0, 0)
  fill:SetHeight(6)
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local thumb = s:GetThumbTexture()
  if thumb then thumb:SetSize(32, 32) end
  local function paint(v)
    fill:SetWidth(math.max(0.01, (v - min) / (max - min) * width))
  end
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / step + 0.5) * step
    paint(v)
    if self.silent then return end
    onChange(v)
  end)
  function s:SetSilently(v)
    self.silent = true
    self:SetValue(v)
    paint(v)
    self.silent = false
  end
  function s:Step(dir)
    local lo, hi = min, max
    self:SetValue(math.min(hi, math.max(lo, self:GetValue() + dir * step)))
  end
  return s
end

-- A compact two-way switch: one bordered box, the picked side in gold.
function Window.Segmented(parent, items, width, onPick)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(width * #items, 24)
  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.5)
  border(box, 0.55, 0.45, 0.28, 0.5)
  local seg = { box = box, buttons = {} }
  for i, item in ipairs(items) do
    local b = CreateFrame("Button", nil, box)
    b:SetSize(width, 24)
    b:SetPoint("LEFT", box, "LEFT", (i - 1) * width, 0)
    b.sel = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.sel:SetPoint("TOPLEFT", 1, -1)
    b.sel:SetPoint("BOTTOMRIGHT", -1, 1)
    b.sel:SetColorTexture(0.35, 0.25, 0.08, 0.75)
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b.label = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.label:SetPoint("CENTER")
    b.label:SetText(item.label)
    b.value = item.value
    b:SetScript("OnClick", function() onPick(item.value) end)
    seg.buttons[i] = b
  end
  function seg:Select(value)
    for _, b in ipairs(self.buttons) do
      local on = b.value == value
      b.sel:SetShown(on)
      if on then b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else b.label:SetTextColor(0.75, 0.73, 0.7) end
    end
  end
  return seg
end

-- ---------- window ----------

-- ---------- tabs: our own, as wide as the window, the same on every client ----------

local TAB_H, TAB_GAP, TAB_INSET = 34, 4, 10

local function makeTab(label)
  local b = CreateFrame("Button", nil, frame)
  b:SetHeight(TAB_H)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.1, 0.09, 0.08, 0.97)
  b.glow = b:CreateTexture(nil, "ARTWORK")
  b.glow:SetPoint("TOPLEFT", 1, -1)
  b.glow:SetPoint("BOTTOMRIGHT", -1, 1)
  b.glow:SetColorTexture(1, 1, 1, 1)
  local ok = CreateColor and b.glow.SetGradient and pcall(b.glow.SetGradient, b.glow, "VERTICAL",
    CreateColor(0.85, 0.6, 0.15, 0.55), CreateColor(0.85, 0.6, 0.15, 0.05))
  if not ok then b.glow:SetColorTexture(0.85, 0.6, 0.15, 0.3) end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.9, 0.6, 0.07)
  b.edges = border(b, 0.55, 0.45, 0.28, 0.6)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.label:SetPoint("CENTER", 0, 1)
  b.label:SetText(label)
  return b
end

local function paintTab(b, selected)
  b.glow:SetShown(selected)
  local e = selected and { 1, 0.82, 0.3, 0.95 } or { 0.55, 0.45, 0.28, 0.6 }
  for _, edge in ipairs(b.edges) do edge:SetColorTexture(e[1], e[2], e[3], e[4]) end
  if selected then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
end

local function create()
  frame = try("PortraitFrameTemplate", "Frame", "JumpersWindow", UIParent)
    or try("BasicFrameTemplateWithInset", "Frame", "JumpersWindow", UIParent)
  if not frame then
    -- no Blizzard frame templates: a plain dark panel with a title and a close button
    frame = CreateFrame("Frame", "JumpersWindow", UIParent)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.08, 0.95)
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -8)
    frame.TitleText = title
    local close = Window.Button(frame, "X", 24, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
  end
  frame:SetSize(640, 580)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  tinsert(UISpecialFrames, "JumpersWindow")

  if frame.SetTitle then
    frame:SetTitle("Jumpers")
  elseif frame.TitleText then
    frame.TitleText:SetText("Jumpers")
  end
  local portraitSet = false
  if frame.SetPortraitToAsset then
    portraitSet = pcall(frame.SetPortraitToAsset, frame, ns.ICON)
  end
  if not portraitSet then
    local p = frame:CreateTexture(nil, "OVERLAY")
    p:SetTexture(ns.MEDIA .. "icon_round")
    p:SetSize(56, 56)
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 6)
  end

  local body = CreateFrame("Frame", nil, frame)
  body:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -66)
  body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
  Window.body = body

  for i, p in ipairs(PAGES) do
    local page = CreateFrame("Frame", nil, body)
    page:SetAllPoints()
    page:Hide()
    pages[p.key] = page

    local tab = makeTab(p.label)
    tab:SetScript("OnClick", function() Window.Select(p.key) end)
    tabs[i] = tab
  end
  -- equal widths across the window: left edge of tab i at i-1 widths plus gaps
  local n = #PAGES
  local w = (640 - 2 * TAB_INSET - (n - 1) * TAB_GAP) / n
  for i, tab in ipairs(tabs) do
    tab:SetWidth(w)
    tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", TAB_INSET + (i - 1) * (w + TAB_GAP), 1)
  end

  ns.StatsTab.Build(pages.stats)
  ns.BoardTab.Build(pages.board)
  ns.SettingsTab.Build(pages.settings)
end

function Window.Select(key)
  if not frame then create() end
  current = key
  for i, p in ipairs(PAGES) do
    pages[p.key]:SetShown(p.key == key)
    paintTab(tabs[i], p.key == key)
  end
end

function Window.Show(key)
  if not frame then create() end
  Window.Select(key or current)
  frame:Show()
end

function Window.Toggle()
  if frame and frame:IsShown() then
    frame:Hide()
  else
    Window.Show()
  end
end
