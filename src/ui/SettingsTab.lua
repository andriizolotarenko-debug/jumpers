-- Settings tab (R6.3) with a live counter preview.
local _, ns = ...

local SettingsTab = {}
ns.SettingsTab = SettingsTab

local ui = {}
local sample

local function volumeText(v)
  return v <= 0 and "Off" or (v .. "%")
end

local function showPreview()
  if sample then return end
  ui.preview:SetUserScale(ns.Settings.Get("size") / 100)
  ui.preview:SetReduced(ns.Settings.Get("reduced"))
  ui.preview:ShowStatic(37)
end

local function playSample()
  if sample then sample:Cancel() end
  local i = 0
  ui.preview:SetUserScale(ns.Settings.Get("size") / 100)
  sample = C_Timer.NewTicker(0.2, function()
    i = i + 1
    if i <= 60 then
      ui.preview:Jump(i)
    else
      sample:Cancel()
      ui.preview:End(60, false)
      C_Timer.After(1.2, function() sample = nil; if ui.box:IsVisible() then showPreview() end end)
    end
  end)
end

function SettingsTab.Build(page)
  local W = ns.Window
  local S = ns.Settings

  -- counter
  local h = W.Header(page, "COUNTER")
  h:SetPoint("TOPLEFT", 0, 0)
  ui.show = W.Check(page, "Show combo counter", function(v) S.Set("show", v) end)
  ui.show:SetPoint("TOPLEFT", 0, -20)

  local sizeLabel = W.Text(page, "GameFontHighlight", "Size")
  sizeLabel:SetPoint("TOPLEFT", 4, -58)
  ui.sizeValue = W.Text(page, "GameFontHighlight")
  ui.sizeValue:SetPoint("TOPLEFT", 240, -58)
  ui.size = W.Slider(page, 150, 50, 200, 5, function(v)
    S.Set("size", v)
    ui.sizeValue:SetText(v .. "%")
  end)
  ui.size:SetPoint("TOPLEFT", 36, -80)
  local minus = W.Button(page, "-", 24, function() ui.size:SetValue(math.max(50, S.Get("size") - 5)) end)
  minus:SetPoint("RIGHT", ui.size, "LEFT", -6, 0)
  local plus = W.Button(page, "+", 24, function() ui.size:SetValue(math.min(200, S.Get("size") + 5)) end)
  plus:SetPoint("LEFT", ui.size, "RIGHT", 6, 0)

  ui.unlock = W.Check(page, "Unlock position", function(v) S.Set("unlocked", v) end)
  ui.unlock:SetPoint("TOPLEFT", 0, -108)
  local reset = W.Button(page, "Reset", 70, function() S.Set("pos", nil) end)
  reset:SetPoint("LEFT", ui.unlock.label, "RIGHT", 10, 0)

  ui.reduced = W.Check(page, "Reduced effects", function(v) S.Set("reduced", v) end)
  ui.reduced:SetPoint("TOPLEFT", 0, -136)

  -- sound
  local sh = W.Header(page, "SOUND")
  sh:SetPoint("TOPLEFT", 0, -184)
  local volLabel = W.Text(page, "GameFontHighlight", "Volume")
  volLabel:SetPoint("TOPLEFT", 4, -208)
  ui.volValue = W.Text(page, "GameFontHighlight")
  ui.volValue:SetPoint("TOPLEFT", 240, -208)
  ui.volume = W.Slider(page, 150, 0, 100, 25, function(v)
    S.Set("volume", v)
    ui.volValue:SetText(volumeText(v))
    if v > 0 then ns.PlaySound("milestone") end
  end)
  ui.volume:SetPoint("TOPLEFT", 36, -230)

  -- units
  local uh = W.Header(page, "HEIGHT UNITS")
  uh:SetPoint("TOPLEFT", 0, -270)
  ui.units = W.Segmented(page, {
    { label = "Metres", value = "m" },
    { label = "Feet", value = "ft" },
  }, 90, function(v) S.Set("units", v); ui.units:Select(v) end)
  ui.units.buttons[1]:SetPoint("TOPLEFT", 4, -292)

  -- minimap
  local mh = W.Header(page, "MINIMAP")
  mh:SetPoint("TOPLEFT", 0, -334)
  ui.minimap = W.Check(page, "Minimap button", function(v)
    S.Get("minimap").hide = not v
    ns.Fire("SETTINGS", "minimap")
  end)
  ui.minimap:SetPoint("TOPLEFT", 0, -354)

  -- preview
  local box = CreateFrame("Frame", nil, page)
  box:SetSize(250, 190)
  box:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -20)
  box:SetClipsChildren(true)
  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.05, 0.06, 0.08, 0.85)
  local caption = W.Text(page, "GameFontNormalSmall", "Preview")
  caption:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 4)
  ui.box = box
  ui.preview = ns.Counter.New(box)
  ui.preview.root:SetPoint("CENTER", box, "CENTER", 0, -6)
  local play = W.Button(page, "Play sample streak", 160, playSample)
  play:SetPoint("TOP", box, "BOTTOM", 0, -8)

  box:SetScript("OnShow", showPreview)
  page:SetScript("OnShow", SettingsTab.Refresh)
  ns.On("SETTINGS", function(key)
    if (key == "size" or key == "reduced") and box:IsVisible() and not sample then showPreview() end
  end)
end

function SettingsTab.Refresh()
  local S = ns.Settings
  ui.show:SetChecked(S.Get("show"))
  ui.size:SetSilently(S.Get("size"))
  ui.sizeValue:SetText(S.Get("size") .. "%")
  ui.unlock:SetChecked(S.Get("unlocked"))
  ui.reduced:SetChecked(S.Get("reduced"))
  ui.volume:SetSilently(S.Get("volume"))
  ui.volValue:SetText(volumeText(S.Get("volume")))
  ui.units:Select(S.Units())
  ui.minimap:SetChecked(not S.Get("minimap").hide)
end
