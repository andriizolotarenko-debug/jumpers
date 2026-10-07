-- The on-screen counter: follows the streak, sits at the character's feet, drags when unlocked.
local _, ns = ...

local CounterUI = {}
ns.CounterUI = CounterUI

local holder, counter, dragHint
local demo = false

local function applyPos()
  local p = ns.Settings.Pos()
  holder:ClearAllPoints()
  holder:SetPoint("CENTER", UIParent, "CENTER", p.x, p.y)
end

local function applySettings()
  counter:SetUserScale(ns.Settings.Get("size") / 100)
  counter:SetReduced(ns.Settings.Get("reduced"))
  local unlocked = ns.Settings.Get("unlocked")
  holder:EnableMouse(unlocked)
  dragHint:SetShown(unlocked)
  if unlocked then
    counter:ShowStatic(37)
  elseif counter.static then
    counter:Hide()
  end
end

function CounterUI.Init()
  holder = CreateFrame("Frame", "JumpersCounter", UIParent)
  holder:SetSize(220, 70)
  holder:SetFrameStrata("MEDIUM")
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  holder:RegisterForDrag("LeftButton")
  holder:SetScript("OnDragStart", holder.StartMoving)
  holder:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.Settings.Set("pos", { x = math.floor(cx - ux + 0.5), y = math.floor(cy - uy + 0.5) })
    applyPos()
  end)

  dragHint = CreateFrame("Frame", nil, holder)
  dragHint:SetAllPoints()
  local bg = dragHint:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.2, 0.6, 1, 0.18)
  local label = dragHint:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("BOTTOM", holder, "TOP", 0, 4)
  label:SetText("Drag the counter, then lock it in /jumpers")
  dragHint:Hide()

  counter = ns.Counter.New(holder)
  counter.root:SetPoint("CENTER")
  CounterUI.counter = counter
  CounterUI.holder = holder

  applyPos()
  applySettings()

  ns.On("JUMP", function(n)
    if demo or not ns.Settings.Get("show") then return end
    counter:Jump(n)
  end)
  ns.On("STREAK_END", function(n, isNewBest, prev, isTodayBest, prevToday)
    if demo then return end
    if isNewBest then
      counter:End(n, "best", prev)
    elseif isTodayBest then
      counter:End(n, "today", prevToday)
    else
      counter:End(n)
    end
    if ns.Settings.Get("unlocked") then C_Timer.After(2.2, applySettings) end
  end)
  ns.On("DEMO_JUMP", function(n)
    demo = true
    counter:Jump(n)
  end)
  ns.On("DEMO_END", function(n)
    counter:End(n, n > 10 and "best" or nil, ns.char.best > 0 and ns.char.best or nil)
    C_Timer.After(2.2, function() demo = false; if ns.Settings.Get("unlocked") then applySettings() end end)
  end)
  ns.On("SETTINGS", function(key)
    if key == "pos" then applyPos() return end
    if key == "size" or key == "reduced" or key == "unlocked" or key == "show" then
      if key == "show" and not ns.Settings.Get("show") then counter:Hide() end
      applySettings()
    end
  end)
end
