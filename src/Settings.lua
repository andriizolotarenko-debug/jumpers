-- Settings store with defaults (R6.3), media paths, sounds, and the Options -> AddOns stub.
local ADDON, ns = ...

local Settings = {}
ns.Settings = Settings

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
ns.MEDIA = MEDIA
ns.FONT = MEDIA .. "ChangaOne-Italic.ttf"
ns.ICON = MEDIA .. "icon"
ns.ICON_SMALL = MEDIA .. "icon_small"   -- minimap button and the AddOns list

Settings.DEFAULTS = {
  show = true,
  size = 100,          -- percent, 50..200
  unlocked = false,
  pos = nil,           -- { x, y } offset from screen centre
  reduced = false,
  plain = false,       -- "Number only": just xN, no ribbon, animations or captions
  volume = 0,          -- percent, 0 = off
  units = nil,         -- "m" | "ft"; nil = by region
  minimap = { hide = false },
}
Settings.DEFAULT_POS = { x = 0, y = -110 }

local db

function Settings.Init(saved)
  db = saved
  for k, v in pairs(Settings.DEFAULTS) do
    if db[k] == nil then
      if type(v) == "table" then
        local copy = {}
        for kk, vv in pairs(v) do copy[kk] = vv end
        db[k] = copy
      else
        db[k] = v
      end
    end
  end
end

function Settings.Get(key)
  return db[key]
end

function Settings.Set(key, value)
  db[key] = value
  ns.Fire("SETTINGS", key, value)
end

function Settings.Units()
  if db.units == "m" or db.units == "ft" then return db.units end
  local region = GetCurrentRegion and GetCurrentRegion()
  local portal = GetCVar and GetCVar("portal")
  return ns.Units.default(region, portal)
end

function Settings.Pos()
  return db.pos or Settings.DEFAULT_POS
end

-- Sounds: pre-mixed at 25 / 50 / 75 / 100 %, picked by the volume setting.
function ns.PlaySound(name)
  local v = db and db.volume or 0
  if v <= 0 then return end
  local level = math.min(100, math.max(25, math.floor((v + 12) / 25) * 25))
  PlaySoundFile(MEDIA .. "sounds\\" .. name .. "_" .. level .. ".ogg", "SFX")
end

-- Options -> AddOns -> Jumpers: one button that opens the window (R6.2).
function Settings.RegisterOptionsStub()
  local panel = CreateFrame("Frame")
  panel.name = "Jumpers"
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Jumpers")
  local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  note:SetText("Stats and settings live in the Jumpers window.")
  local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  button:SetSize(160, 24)
  button:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
  button:SetText("Open Jumpers")
  button:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    ns.Window.Show("settings")
  end)
  if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
    local category = _G.Settings.RegisterCanvasLayoutCategory(panel, "Jumpers")
    _G.Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end
