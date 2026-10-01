if not _G.BetterSentryReloader then
    dofile(ModPath .. "lua/core.lua")
end

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_BetterSentryReloader", function(menu_manager)
    MenuCallbackHandler.bsr_callback_target_mode = function(this, item)
        BetterSentryReloader.settings.target_mode = item:value()
        BetterSentryReloader:save()
    end

    MenuCallbackHandler.bsr_callback_max_range = function(this, item)
        BetterSentryReloader.settings.max_range = item:value()
        BetterSentryReloader:save()
    end

    MenuCallbackHandler.bsr_callback_allow_team_sentries = function(this, item)
        local val = item:value()
        BetterSentryReloader.settings.allow_team_sentries = (val == "on" or val == true or val == "true")
        BetterSentryReloader:save()
    end

    MenuCallbackHandler.bsr_callback_repair_health = function(this, item)
        local val = item:value()
        BetterSentryReloader.settings.repair_health = (val == "on" or val == true or val == "true")
        BetterSentryReloader:save()
    end

    MenuCallbackHandler.bsr_callback_play_sound = function(this, item)
        local val = item:value()
        BetterSentryReloader.settings.play_sound = (val == "on" or val == true or val == "true")
        BetterSentryReloader:save()
    end

    MenuCallbackHandler.bsr_callback_show_hint = function(this, item)
        local val = item:value()
        BetterSentryReloader.settings.show_hint = (val == "on" or val == true or val == "true")
        BetterSentryReloader:save()
    end

    BetterSentryReloader:load()
    MenuHelper:LoadFromJsonFile(BetterSentryReloader._path .. "menu/options.json", BetterSentryReloader, BetterSentryReloader.settings)
end)
