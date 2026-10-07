std = "lua51"
max_line_length = 130
exclude_files = { "libs/", ".luarocks/", ".install/", ".lua/" }
ignore = {
  "212/self",   -- unused self
}

globals = {
  "JumpersDB", "JumpersCharDB", "SLASH_JUMPERS1", "SlashCmdList", "Jumpers_OnAddonCompartmentClick",
  "UISpecialFrames",
}

read_globals = {
  "AscendStop", "C_DateAndTime", "C_Timer", "CreateColor", "CreateFrame", "GetCVar", "GetCurrentRegion",
  "GetPlayerFacing", "GetTime", "HasFullControl", "HideUIPanel", "InterfaceOptions_AddCategory",
  "IsFalling", "IsFlying", "IsPlayerMoving", "IsSwimming", "JumpOrAscendStart", "LibStub",
  "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "PanelTemplates_TabResize", "PlaySoundFile",
  "STANDARD_TEXT_FONT", "Settings", "SettingsPanel", "UIParent", "UnitOnTaxi", "date", "geterrorhandler",
  "hooksecurefunc", "issecretvalue", "tinsert", "unpack", "wipe",
}

files["spec/"] = { std = "+busted" }
