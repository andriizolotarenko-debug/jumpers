-- Milestone caption above the counter (R2.10, UI-SPEC: Milestone caption).
local _, ns = ...

local Caption = {}
ns.Caption = Caption

local IN, HOLD, OUT = 0.25, 2.8, 0.6
local frame, line1, line2
local shownAt

local function offsetY()
  local c = ns.CounterUI.counter
  local scale = c and c:CurrentScale() or 1
  return 26 * scale + 46
end

local function update()
  local t = GetTime() - shownAt
  local alpha, dy
  if t < IN then
    alpha, dy = t / IN, -10 * (1 - t / IN)
  elseif t < IN + HOLD then
    alpha, dy = 1, 0
  elseif t < IN + HOLD + OUT then
    local p = (t - IN - HOLD) / OUT
    alpha, dy = 1 - p, 8 * p
  else
    frame:Hide()
    return
  end
  frame:SetAlpha(alpha)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", ns.CounterUI.holder, "CENTER", 0, offsetY() + dy)
end

function Caption.Show(index)
  local lm = ns.Landmarks[index]
  if not lm then return end
  line2:SetText(lm.name .. " \226\128\162 " .. ns.Units.format(lm.m, ns.Settings.Units()))
  frame:SetWidth(math.max(380, line2:GetStringWidth() + 90))
  shownAt = GetTime()
  frame:SetAlpha(0)
  frame:Show()
  ns.PlaySound("caption")
end

function Caption.Init()
  frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(380, 62)
  frame:SetFrameStrata("MEDIUM")
  frame:Hide()
  local band = frame:CreateTexture(nil, "BACKGROUND")
  band:SetAllPoints()
  band:SetTexture(ns.MEDIA .. "caption_band")
  for i, point in ipairs({ "TOP", "BOTTOM" }) do
    local l = frame:CreateTexture(nil, "BORDER")
    l:SetTexture(ns.MEDIA .. "line")
    l:SetVertexColor(0.95, 0.78, 0.36, 0.9)
    l:SetHeight(2)
    l:SetPoint(point .. "LEFT", frame, point .. "LEFT", 0, i == 1 and -1 or 1)
    l:SetPoint(point .. "RIGHT", frame, point .. "RIGHT", 0, i == 1 and -1 or 1)
  end
  line1 = frame:CreateFontString(nil, "OVERLAY")
  line1:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
  line1:SetTextColor(0xf2 / 255, 0xc7 / 255, 0x5c / 255)
  line1:SetPoint("TOP", frame, "TOP", 0, -9)
  line1:SetText("You climbed")
  line2 = frame:CreateFontString(nil, "OVERLAY")
  line2:SetFont(STANDARD_TEXT_FONT, 24, "THICKOUTLINE")
  line2:SetTextColor(1, 1, 1)
  line2:SetPoint("TOP", line1, "BOTTOM", 0, -3)
  frame:SetScript("OnUpdate", update)

  ns.On("MILESTONE", function(index)
    if ns.Settings.Get("show") then Caption.Show(index) end
  end)
end
