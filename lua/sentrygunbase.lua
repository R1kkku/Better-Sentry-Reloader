if not _G.BetterSentryReloader then
    dofile(ModPath .. "lua/core.lua")
end

Hooks:PostHook(SentryGunBase, "setup", "BetterSentryReloader_SentryGunBase_setup", function(self)
    if alive(self._unit) then
        BetterSentryReloader:register_sentry(self._unit)
    end
end)

Hooks:PostHook(SentryGunBase, "pre_destroy", "BetterSentryReloader_SentryGunBase_pre_destroy", function(self)
    if alive(self._unit) then
        BetterSentryReloader:unregister_sentry(self._unit)
    end
end)

-- Safe hook for sync_net_event:
-- Vanilla's old sync_net_event has an obsolete 100% total ammo drain when reload ratio is 1.
-- We hook this so that when Event ID 1 (100% refill) is received via network:
-- It properly refills the sentry and switches its brain on, without draining 100% of the player's ammo.
local orig_sync_net_event = SentryGunBase.sync_net_event
function SentryGunBase:sync_net_event(event_id, peer)
    if event_id == 1 then
        self:refill(1)
        return
    end

    if orig_sync_net_event then
        return orig_sync_net_event(self, event_id, peer)
    end
end
