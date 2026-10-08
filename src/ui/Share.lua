-- Sharing the addon: a copyable CurseForge link and a chat line the player sends themselves.
-- Nothing is ever sent automatically: "Tell a friend" only fills the chat box.
local _, ns = ...

local Share = {}
ns.Share = Share

Share.URL = "https://www.curseforge.com/wow/addons/jumpers"
local SHORT = "curseforge.com/wow/addons/jumpers"

local popup

local function build()
  local f = ns.Window.Card(UIParent, 400, 96)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
  bg:SetAllPoints()
  bg:SetColorTexture(0.06, 0.05, 0.04, 0.96)
  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
  title:SetText("Jumpers on CurseForge")
  local box = CreateFrame("EditBox", nil, f)
  box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
  box:SetSize(372, 24)
  box:SetFontObject(ChatFontNormal or GameFontHighlight)
  box:SetAutoFocus(false)
  box:SetTextInsets(6, 6, 0, 0)
  local well = box:CreateTexture(nil, "BACKGROUND")
  well:SetAllPoints()
  well:SetColorTexture(0, 0, 0, 0.6)
  ns.Window.Border(box, 0.55, 0.45, 0.28, 0.5)
  local function reset(self)
    self:SetText(Share.URL)
    self:HighlightText()
  end
  box:SetScript("OnTextChanged", function(self, user) if user then reset(self) end end)
  box:SetScript("OnEscapePressed", function() f:Hide() end)
  box:SetScript("OnEnterPressed", function() f:Hide() end)
  box:SetScript("OnKeyDown", function(_, key)
    if key == "C" and ((IsControlKeyDown and IsControlKeyDown()) or (IsMetaKeyDown and IsMetaKeyDown())) then
      C_Timer.After(0.1, function()
        f:Hide()
        ns.Print("link copied")
      end)
    end
  end)
  local hint = ns.Window.Note(f, "Press Ctrl+C (Cmd+C on a Mac) to copy, Esc to close.")
  hint:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -66)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
  f:SetScript("OnShow", function()
    reset(box)
    box:SetFocus()
  end)
  f:Hide()
  popup = f
end

-- Shows the link selected in a box, ready for Ctrl+C.
function Share.CopyLink()
  if not popup then build() end
  popup:Hide()
  popup:Show()
end

-- Opens the chat box with `text` and the link. The player picks where and presses Enter.
function Share.Tell(text)
  local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
  if not open or not pcall(open, text .. " " .. SHORT) then Share.CopyLink() end
end
