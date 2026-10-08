-- "Number only" counter: just "xN" in white. No ribbon, colours, ornaments, pops or effects.
-- Same interface as Counter, so CounterUI and the settings preview can use either.
local _, ns = ...

local PlainCounter = {}
PlainCounter.__index = PlainCounter
ns.PlainCounter = PlainCounter

local SIZE = 26
local LINGER = 1.2       -- s the final count stays after the streak ends

function PlainCounter.New(parent)
  local self = setmetatable({ userScale = 1, token = 0 }, PlainCounter)
  self.root = CreateFrame("Frame", nil, parent)
  self.root:SetSize(160, 40)
  self.text = self.root:CreateFontString(nil, "OVERLAY")
  self.text:SetPoint("CENTER")
  self.root:Hide()
  return self
end

function PlainCounter:Show(n)
  local size = math.floor(SIZE * self.userScale + 0.5)
  self.text:SetFont(ns.FONT, size, "OUTLINE")
  if not self.text:GetFont() then self.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
  self.text:SetShadowOffset(1, -1)
  self.text:SetShadowColor(0, 0, 0, 0.8)
  self.text:SetTextColor(1, 1, 1)
  self.text:SetText("x" .. n)
  self.root:Show()
end

function PlainCounter:Jump(n)
  self.static = false
  self.token = self.token + 1
  local event = ns.Tiers.event(n)
  if event == "tier" then
    ns.PlaySound("tierup")
  elseif event == "ornament" or event == "stage" then
    ns.PlaySound("milestone")
  else
    ns.PlaySound("tick")
  end
  self:Show(n)
end

-- record: "best", "today" or nil. Only the sound marks a record here.
function PlainCounter:End(n, record)
  if self.static or not self.root:IsShown() then return end
  if record then
    ns.PlaySound(record == "best" and "fanfare" or "tierup")
  elseif n > 10 then
    ns.PlaySound("snap")
  end
  self.token = self.token + 1
  local token = self.token
  C_Timer.After(LINGER, function()
    if self.token == token and not self.static then self.root:Hide() end
  end)
end

function PlainCounter:ShowStatic(n)
  self.static = true
  self.token = self.token + 1
  self:Show(n)
end

function PlainCounter:Hide()
  self.static = false
  self.token = self.token + 1
  self.root:Hide()
end

function PlainCounter:SetUserScale(s)
  self.userScale = s
end

function PlainCounter:SetReduced() end

function PlainCounter:CurrentScale()
  return self.userScale
end
