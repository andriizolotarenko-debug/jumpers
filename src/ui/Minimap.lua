-- Minimap button through LibDataBroker + LibDBIcon (R6.2). Skipped when the libraries are absent.
local _, ns = ...

local Minimap = {}
ns.Minimap = Minimap

function Minimap.Init()
  if not LibStub then return end
  local LDB = LibStub("LibDataBroker-1.1", true)
  local Icon = LibStub("LibDBIcon-1.0", true)
  if not LDB or not Icon then return end

  local launcher = LDB:NewDataObject("Jumpers", {
    type = "launcher",
    label = "Jumpers",
    icon = ns.ICON_SMALL,
    OnClick = function() ns.Window.Toggle() end,
    OnTooltipShow = function(tip)
      local _, _, best = ns.Stats.today(ns.char, ns.Today())
      tip:AddLine("Jumpers")
      tip:AddLine("Best streak today: x" .. best, 1, 1, 1)
      tip:AddLine("Click open \194\183 Drag move", 0.6, 0.6, 0.6)
    end,
  })
  Icon:Register("Jumpers", launcher, ns.Settings.Get("minimap"))

  ns.On("SETTINGS", function(key)
    if key ~= "minimap" then return end
    if ns.Settings.Get("minimap").hide then Icon:Hide("Jumpers") else Icon:Show("Jumpers") end
  end)
end
