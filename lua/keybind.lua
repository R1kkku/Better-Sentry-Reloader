if not _G.BetterSentryReloader then
    dofile(ModPath .. "lua/core.lua")
end

BetterSentryReloader:reload_sentry()
