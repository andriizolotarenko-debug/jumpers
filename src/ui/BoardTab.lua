-- Leaderboard tab: v1 shows a notice (R6.1).
local _, ns = ...

local BoardTab = {}
ns.BoardTab = BoardTab

function BoardTab.Build(page)
  local card = ns.Window.Card(page, 460, 150)
  card:SetPoint("CENTER", page, "CENTER", 0, 30)
  local icon = card:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ns.MEDIA .. "icon_round")
  icon:SetSize(48, 48)
  icon:SetPoint("TOP", card, "TOP", 0, -14)
  local title = card:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", icon, "BOTTOM", 0, -8)
  title:SetText("Leaderboard is coming in v2")
  local text = ns.Window.Note(card, "Best streaks of everyone on your realm who runs Jumpers: today, 7 days, "
    .. "30 days and the year, with a Players Online filter.")
  text:SetPoint("TOP", title, "BOTTOM", 0, -8)
  text:SetWidth(400)
  text:SetJustifyH("CENTER")
end
