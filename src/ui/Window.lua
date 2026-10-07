-- The Jumpers window: portrait frame with three tabs (R6.1), plus small shared widgets.
local _, ns = ...

local Window = {}
ns.Window = Window

local PAGES = {
  { key = "stats", label = "Personal Stats" },
  { key = "board", label = "Leaderboard |cff9d9d9dv2|r" },
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

function Window.Slider(parent, width, min, max, step, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(width, 18)
  s:SetMinMaxValues(min, max)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0, 0, 0, 0.65)
  track:SetPoint("LEFT", 0, 0)
  track:SetPoint("RIGHT", 0, 0)
  track:SetHeight(6)
  local edge = s:CreateTexture(nil, "BORDER")
  edge:SetColorTexture(0.6, 0.5, 0.3, 0.6)
  edge:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 1)
  edge:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 1)
  edge:SetHeight(1)
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local thumb = s:GetThumbTexture()
  if thumb then thumb:SetSize(32, 32) end
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / step + 0.5) * step
    if self.silent then return end
    onChange(v)
  end)
  function s:SetSilently(v)
    self.silent = true
    self:SetValue(v)
    self.silent = false
  end
  return s
end

-- Two or more buttons acting as one choice.
function Window.Segmented(parent, items, width, onPick)
  local seg = { buttons = {} }
  for i, item in ipairs(items) do
    local b = Window.Button(parent, item.label, width, function() onPick(item.value) end)
    if i > 1 then b:SetPoint("LEFT", seg.buttons[i - 1], "RIGHT", 2, 0) end
    b.value = item.value
    seg.buttons[i] = b
  end
  function seg:Select(value)
    for _, b in ipairs(self.buttons) do
      if b.value == value then
        b:LockHighlight()
        if b.GetFontString and b:GetFontString() then b:GetFontString():SetTextColor(1, 0.82, 0) end
      else
        b:UnlockHighlight()
        if b.GetFontString and b:GetFontString() then b:GetFontString():SetTextColor(0.8, 0.8, 0.8) end
      end
    end
  end
  return seg
end

-- ---------- window ----------

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
  frame:SetSize(600, 560)
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

    local tab = try("PanelTabButtonTemplate", "Button", "JumpersWindowTab" .. i, frame)
    if tab then
      tab:SetText(p.label)
      if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    else
      tab = Window.Button(frame, p.label, 140, nil)
    end
    tab:SetID(i)
    tab:SetScript("OnClick", function() Window.Select(p.key) end)
    if i == 1 then
      tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
    else
      tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 2, 0)
    end
    tabs[i] = tab
  end
  frame.Tabs = tabs
  frame.numTabs = #tabs
  if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, frame, #tabs) end

  ns.StatsTab.Build(pages.stats)
  ns.BoardTab.Build(pages.board)
  ns.SettingsTab.Build(pages.settings)
end

function Window.Select(key)
  if not frame then create() end
  current = key
  for i, p in ipairs(PAGES) do
    pages[p.key]:SetShown(p.key == key)
    if p.key == key and PanelTemplates_SetTab then pcall(PanelTemplates_SetTab, frame, i) end
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
