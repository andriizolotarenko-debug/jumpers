-- Leaderboard tab: v1 shows a notice (R6.1).
local _, ns = ...

local BoardTab = {}
ns.BoardTab = BoardTab

function BoardTab.Build(page)
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("CENTER", page, "CENTER", 0, 40)
  title:SetText("Leaderboard is coming in v2")
  local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOP", title, "BOTTOM", 0, -12)
  text:SetWidth(420)
  text:SetJustifyH("CENTER")
  text:SetText("Best streaks of everyone on your realm who runs Jumpers: today, 7 days, "
    .. "30 days and the year, with a Players Online filter.")
end
