if not _G.BetterSentryReloader then
    dofile(ModPath .. "lua/core.lua")
end

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_BetterSentryReloader", function(loc)
    loc:load_localization_file(BetterSentryReloader._path .. "loc/english.json", false)
end)
