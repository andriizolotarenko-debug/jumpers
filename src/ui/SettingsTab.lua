-- Settings tab (R6.3) with a live counter preview.
local _, ns = ...

local SettingsTab = {}
ns.SettingsTab = SettingsTab

local W = 600          -- page width
local PREVIEW_W = 250
local LEFT = W - PREVIEW_W - 24   -- width of the left column next to the preview

local ui = {}
local sample

local function volumeText(v)
  return v <= 0 and "Off" or (v .. "%")
end

local REDUCED_NOTE = "No lightning, sparks or rays. Colours and the shine stay."
local PLAIN_NOTE = "Just the xN count: no ribbon, animations, effects or milestone captions."

-- The preview follows "Number only" like the real counter.
local function pickPreview()
  local want = ns.Settings.Get("plain") and ui.plainPreview or ui.fancyPreview
  if want ~= ui.preview then
    if ui.preview then ui.preview:Hide() end
    ui.preview = want
  end
end

local function showPreview()
  if sample then return end
  pickPreview()
  ui.preview:SetUserScale(ns.Settings.Get("size") / 100)
  ui.preview:SetReduced(ns.Settings.Get("reduced"))
  ui.preview:ShowStatic(37)
end

local function playSample()
  if sample then sample:Cancel() end
  local i = 0
  pickPreview()
  ui.preview:SetUserScale(ns.Settings.Get("size") / 100)
  sample = C_Timer.NewTicker(0.2, function()
    i = i + 1
    if i <= 60 then
      ui.preview:Jump(i)
    else
      sample:Cancel()
      ui.preview:End(60)
      C_Timer.After(1.2, function() sample = nil; if ui.box:IsVisible() then showPreview() end end)
    end
  end)
end

local function at(region, page, x, y)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
  return region
end

-- Slider row: label on the left; stepper, slider, stepper, value on the right of `rightEdge`.
local function sliderRow(page, label, y, rightEdge, min, max, step, onChange)
  local W_ = ns.Window
  at(W_.Text(page, "GameFontHighlight", label), page, 2, y - 4)
  local value = W_.Text(page, "GameFontHighlight")
  value:SetPoint("TOPRIGHT", page, "TOPLEFT", rightEdge, y - 4)
  value:SetJustifyH("RIGHT")
  value:SetWidth(44)
  local slider = W_.Slider(page, 120, min, max, step, function(v)
    value:SetText(onChange(v))
  end)
  slider:SetPoint("TOPRIGHT", page, "TOPLEFT", rightEdge - 44 - 30 + slider.pad, y - 3)
  local minus = W_.Stepper(page, -1, function() slider:Step(-1) end)
  minus:SetPoint("RIGHT", slider, "LEFT", slider.pad - 10, 0)
  local plus = W_.Stepper(page, 1, function() slider:Step(1) end)
  plus:SetPoint("LEFT", slider, "RIGHT", 10 - slider.pad, 0)
  return slider, value
end

function SettingsTab.Build(page)
  local W_ = ns.Window
  local S = ns.Settings

  -- combo counter
  at(W_.Section(page, "Combo counter", W), page, 0, 0)
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local version = getMeta and getMeta("Jumpers", "Version")
  if type(version) ~= "string" or version:find("@", 1, true) then version = "dev" end
  local ver = W_.Note(page, version)
  ver:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -2)
  ui.show = at(W_.Check(page, "Show combo counter", function(v) S.Set("show", v) end), page, -2, -22)

  ui.size, ui.sizeValue = sliderRow(page, "Size", -56, LEFT, 50, 200, 5, function(v)
    S.Set("size", v)
    return v .. "%"
  end)

  ui.unlock = at(W_.Check(page, "Unlock position", function(v) S.Set("unlocked", v) end), page, -2, -86)
  local reset = W_.Button(page, "Reset", 72, function() S.Set("pos", nil) end)
  reset:SetPoint("TOPRIGHT", page, "TOPLEFT", LEFT, -88)
  at(W_.Note(page, "While unlocked, drag the counter to move it."), page, 2, -112)

  ui.reduced = at(W_.Check(page, "Reduced effects", function(v) S.Set("reduced", v) end), page, -2, -130)
  ui.plain = at(W_.Check(page, "Number only", function(v) S.Set("plain", v) end), page, 168, -130)
  ui.effectsNote = at(W_.Note(page, REDUCED_NOTE), page, 2, -156)

  -- preview
  local box = CreateFrame("Frame", nil, page)
  box:SetSize(PREVIEW_W, 150)
  box:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -24)
  box:SetClipsChildren(true)
  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.04, 0.05, 0.07, 0.9)
  local glow = box:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetTexture(ns.MEDIA .. "glow")
  glow:SetVertexColor(0.85, 0.7, 0.4, 0.18)
  glow:SetSize(PREVIEW_W * 1.2, 120)
  glow:SetPoint("CENTER", box, "CENTER", 0, -8)
  W_.Border(box, 0.55, 0.45, 0.28, 0.45)
  ui.box = box
  ui.fancyPreview = ns.Counter.New(box)
  ui.fancyPreview.root:SetPoint("CENTER", box, "CENTER", 0, -4)
  ui.plainPreview = ns.PlainCounter.New(box)
  ui.plainPreview.root:SetPoint("CENTER", box, "CENTER", 0, -4)
  local play = W_.Button(page, "Play sample streak", PREVIEW_W, playSample)
  play:SetPoint("TOP", box, "BOTTOM", 0, -6)

  -- sound
  at(W_.Section(page, "Sound", W), page, 0, -200)
  ui.volume, ui.volValue = sliderRow(page, "Volume", -222, W, 0, 100, 25, function(v)
    S.Set("volume", v)
    if v > 0 then ns.PlaySound("milestone") end
    return volumeText(v)
  end)

  -- units
  at(W_.Section(page, "Units", W), page, 0, -262)
  at(W_.Text(page, "GameFontHighlight", "Height"), page, 2, -288)
  ui.units = W_.Segmented(page, {
    { label = "Metres", value = "m" },
    { label = "Feet", value = "ft" },
  }, 70, function(v) S.Set("units", v); ui.units:Select(v) end)
  ui.units.box:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -284)
  at(W_.Note(page, "Set from your region on first run (US: feet). Floors and landmarks live in Personal Stats."),
    page, 2, -312)

  -- minimap
  at(W_.Section(page, "Minimap", W), page, 0, -340)
  ui.minimap = at(W_.Check(page, "Show minimap button", function(v)
    S.Get("minimap").hide = not v
    ns.Fire("SETTINGS", "minimap")
  end), page, -2, -362)

  -- progress
  at(W_.Section(page, "Progress", W), page, 0, -400)
  local resetProgress = W_.Button(page, "Reset progress", 140, function()
    if StaticPopup_Show then StaticPopup_Show("JUMPERS_RESET_PROGRESS") else ns.ResetProgress() end
  end)
  at(resetProgress, page, 0, -424)
  local warn = W_.Note(page, "Clears jumps, streaks, bests and milestones for this character and the account.")
  warn:SetPoint("LEFT", resetProgress, "RIGHT", 10, 0)

  at(W_.Note(page, "Open this window: minimap button or |cffffd100/jumpers|r. Try |cffffd100/jumpers demo|r."),
    page, 2, -462)

  if StaticPopupDialogs then
    StaticPopupDialogs.JUMPERS_RESET_PROGRESS = {
      text = "Reset all Jumpers progress?\nJumps, streaks, bests and milestones go back to zero.",
      button1 = YES or "Yes",
      button2 = NO or "No",
      OnAccept = function() ns.ResetProgress() end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      showAlert = true,
    }
  end

  box:SetScript("OnShow", showPreview)
  page:SetScript("OnShow", SettingsTab.Refresh)
  ns.On("SETTINGS", function(key)
    if key == "plain" then
      ui.reduced:SetEnabled(not S.Get("plain"))
      ui.effectsNote:SetText(S.Get("plain") and PLAIN_NOTE or REDUCED_NOTE)
    end
    if (key == "size" or key == "reduced" or key == "plain") and box:IsVisible() and not sample then showPreview() end
  end)
end

function SettingsTab.Refresh()
  local S = ns.Settings
  ui.show:SetChecked(S.Get("show"))
  ui.size:SetSilently(S.Get("size"))
  ui.sizeValue:SetText(S.Get("size") .. "%")
  ui.unlock:SetChecked(S.Get("unlocked"))
  ui.reduced:SetChecked(S.Get("reduced"))
  ui.reduced:SetEnabled(not S.Get("plain"))
  ui.plain:SetChecked(S.Get("plain"))
  ui.effectsNote:SetText(S.Get("plain") and PLAIN_NOTE or REDUCED_NOTE)
  ui.volume:SetSilently(S.Get("volume"))
  ui.volValue:SetText(volumeText(S.Get("volume")))
  ui.units:Select(S.Units())
  ui.minimap:SetChecked(not S.Get("minimap").hide)
end
