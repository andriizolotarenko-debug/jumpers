std = "lua51"
max_line_length = 130
exclude_files = { "libs/", ".luarocks/", ".install/", ".lua/" }
ignore = {
  "212/self",   -- unused self
}

globals = {
  "JumpersDB", "JumpersCharDB", "SLASH_JUMPERS1", "SlashCmdList", "Jumpers_OnAddonCompartmentClick",
  "UISpecialFrames", "StaticPopupDialogs",
}

read_globals = {
  "AscendStop", "C_DateAndTime", "C_Timer", "CreateColor", "CreateFrame", "GetCVar", "GetCurrentRegion",
  "GetPlayerFacing", "GetTime", "HasFullControl", "HideUIPanel", "InterfaceOptions_AddCategory",
  "IsFalling", "IsFlying", "IsPlayerMoving", "IsSwimming", "JumpOrAscendStart", "LibStub",
  "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "PanelTemplates_TabResize", "PlaySoundFile",
  "STANDARD_TEXT_FONT", "StaticPopup_Show", "YES", "NO", "Settings", "UnitName", "UnitLevel", "SettingsPanel", "UIParent", "UnitOnTaxi", "date", "geterrorhandler",
  "hooksecurefunc", "issecretvalue", "tinsert", "unpack", "wipe",
  "C_ChatInfo", "ChatFrame_RemoveChannel", "Enum", "GetChannelName", "GetNormalizedRealmName", "GetRealmName",
  "GetServerTime", "IsInGuild", "JoinTemporaryChannel", "NUM_CHAT_WINDOWS", "RAID_CLASS_COLORS", "UnitClass", "time",
  "IsInRaid", "IsInGroup", "LeaveChannelByName", "ERR_CHAT_PLAYER_NOT_FOUND_S", "ChatFrame_AddMessageEventFilter",
  "ChatFrameUtil", "ChatFrame_OpenChat", "IsControlKeyDown", "WOW_PROJECT_ID", "WOW_PROJECT_CLASSIC",
  "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", "WOW_PROJECT_WRATH_CLASSIC", "WOW_PROJECT_CATACLYSM_CLASSIC",
  "WOW_PROJECT_MISTS_CLASSIC", "ChatFontNormal", "GameFontHighlight", "IsMetaKeyDown",
}

files["spec/"] = { std = "+busted" }
files["spec/wow_mock.lua"] = { max_line_length = false, ignore = { "143", "212" } }
