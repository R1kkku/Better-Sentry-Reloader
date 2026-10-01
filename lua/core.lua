if _G.BetterSentryReloader then
    return
end

BetterSentryReloader = BetterSentryReloader or {}
BetterSentryReloader._path = ModPath
BetterSentryReloader._save_path = SavePath and (SavePath .. "better_sentry_reloader.json") or (ModPath .. "save_settings.json")
BetterSentryReloader._last_reload_t = 0
BetterSentryReloader.sentries = BetterSentryReloader.sentries or {}

BetterSentryReloader.settings = {
    target_mode = 1,              -- 1: Aimed (Crosshair), 2: Closest, 3: All in Range
    max_range = 10,               -- In meters (2 to 50)
    cost_mode = 1,                -- 1: Perk-Based, 2: Custom Percentage, 3: Free
    custom_cost_percent = 20,     -- In percent (1% to 50%)
    cost_multiplier = 100,        -- Scale factor in percent (10% to 200%)
    allow_team_sentries = false,  -- Whether to reload teammate sentries too
    repair_health = false,        -- Also repair sentry health when host
    play_sound = true,            -- Play reload sound effect
    show_hint = true              -- Show HUD hint with reload status & ammo cost
}

function BetterSentryReloader:save()
    local file = io.open(self._save_path, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

function BetterSentryReloader:load()
    local file = io.open(self._save_path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and #content > 0 then
            local data = json.decode(content)
            if type(data) == "table" then
                for k, v in pairs(data) do
                    self.settings[k] = v
                end
            end
        end
    end
end

function BetterSentryReloader:register_sentry(unit)
    if alive(unit) then
        self.sentries[unit:key()] = unit
    end
end

function BetterSentryReloader:unregister_sentry(unit)
    if alive(unit) then
        self.sentries[unit:key()] = nil
    end
end

function BetterSentryReloader:get_all_active_sentries()
    local result = {}
    local seen = {}

    -- 1. Check registered sentries
    for key, unit in pairs(self.sentries) do
        if alive(unit) and unit:base() and not unit:base():is_removed() then
            table.insert(result, unit)
            seen[unit:key()] = true
        else
            self.sentries[key] = nil
        end
    end

    -- 2. Fallback search via slot mask (slot 25 & 26) in case any sentries were spawned prior to script load
    if managers.slot then
        local mask = managers.slot:get_mask("sentry_gun")
        if mask then
            local found = World:find_units_quick("all", mask)
            for _, unit in ipairs(found) do
                if alive(unit) and not seen[unit:key()] and unit:base() and unit:base().sentry_gun and not unit:base():is_removed() then
                    table.insert(result, unit)
                    self.sentries[unit:key()] = unit
                    seen[unit:key()] = true
                end
            end
        end
    end

    return result
end

function BetterSentryReloader:is_valid_target(sentry_unit, player_unit)
    if not alive(sentry_unit) or not sentry_unit:base() or sentry_unit:base():is_removed() then
        return false
    end

    -- Dead / destroyed sentry check
    if sentry_unit:character_damage() and sentry_unit:character_damage():dead() then
        return false
    end

    -- Check ownership: only reload local player's sentries unless allow_team_sentries is enabled
    if not self.settings.allow_team_sentries then
        if not sentry_unit:base():is_owner() then
            return false
        end
    end

    return true
end

function BetterSentryReloader:get_target_sentries(player_unit)
    local all_sentries = self:get_all_active_sentries()
    local valid_sentries = {}
    local cam = player_unit:camera()
    local cam_pos = cam:position()
    local cam_fwd = cam:forward()
    local max_dist_cm = (self.settings.max_range or 10) * 100

    for _, sentry in ipairs(all_sentries) do
        if self:is_valid_target(sentry, player_unit) then
            local sentry_pos = sentry:position()
            local dist = (sentry_pos - cam_pos):length()
            if dist <= max_dist_cm then
                table.insert(valid_sentries, {
                    unit = sentry,
                    distance = dist,
                    position = sentry_pos
                })
            end
        end
    end

    if #valid_sentries == 0 then
        return {}
    end

    local mode = self.settings.target_mode or 1

    -- Mode 3: All sentries in range
    if mode == 3 then
        local list = {}
        for _, entry in ipairs(valid_sentries) do
            table.insert(list, entry.unit)
        end
        return list
    end

    -- Mode 2: Closest sentry
    if mode == 2 then
        table.sort(valid_sentries, function(a, b)
            return a.distance < b.distance
        end)
        return { valid_sentries[1].unit }
    end

    -- Mode 1: Aimed (Crosshair / Raycast)
    -- First check direct raycast hit on sentry gun body
    if managers.slot then
        local mask = managers.slot:get_mask("sentry_gun")
        if mask then
            local ray = World:raycast("ray", cam_pos, cam_pos + cam_fwd * max_dist_cm, "slot_mask", mask)
            if ray and alive(ray.unit) and self:is_valid_target(ray.unit, player_unit) then
                return { ray.unit }
            end
        end
    end

    -- Check angle / dot product to find sentry closest to center of screen
    local best_unit = nil
    local best_score = -1

    for _, entry in ipairs(valid_sentries) do
        local sentry_head = entry.position + Vector3(0, 0, 20)
        local to_sentry = (sentry_head - cam_pos):normalized()
        local dot = cam_fwd:dot(to_sentry)

        -- Must be in front (FOV cone of ~45 degrees, dot >= 0.70)
        if dot >= 0.70 then
            -- Raycast check for line of sight (not obstructed by walls)
            local los_ray = World:raycast("ray", cam_pos, sentry_head, "slot_mask", managers.slot:get_mask("world_geometry"))
            if not los_ray then
                -- Score combines centering on screen with distance preference
                local score = dot - (entry.distance / (max_dist_cm * 5))
                if score > best_score then
                    best_score = score
                    best_unit = entry.unit
                end
            end
        end
    end

    if best_unit then
        return { best_unit }
    end

    -- Fallback to closest if aiming wasn't direct but within range
    table.sort(valid_sentries, function(a, b)
        return a.distance < b.distance
    end)
    return { valid_sentries[1].unit }
end

function BetterSentryReloader:calculate_ammo_cost(sentry_unit, player_unit)
    local weapon_costs = {}
    local total_bullets = 0

    if not alive(sentry_unit) or not alive(player_unit) then
        return weapon_costs, 0
    end

    local sentry_weapon = sentry_unit:weapon()
    if not sentry_weapon then
        return weapon_costs, 0
    end

    local current_ratio = sentry_weapon:ammo_ratio() or 0
    local missing_ratio = math.max(0, 1.0 - current_ratio)

    if missing_ratio <= 0.001 then
        return weapon_costs, 0
    end

    local cost_mode = self.settings.cost_mode or 1
    if cost_mode == 3 then
        -- Free mode (no ammo cost)
        return weapon_costs, 0
    end

    local cost_mult = (self.settings.cost_multiplier or 100) / 100
    local cost_reduction_lvl = managers.player:upgrade_value("sentry_gun", "cost_reduction", 1)
    local dep_cost = (SentryGunBase and SentryGunBase.DEPLOYEMENT_COST and SentryGunBase.DEPLOYEMENT_COST[cost_reduction_lvl]) or 0.70
    local full_cost_fraction = 1.0 - dep_cost -- 0.30 (no perk), 0.25 (basic), 0.20 (aced)

    local eq = player_unit:equipment()
    local recorded_costs = eq and eq.get_sentry_deployement_cost and eq:get_sentry_deployement_cost(sentry_unit:id())

    local inventory = player_unit:inventory()
    if not inventory then
        return weapon_costs, 0
    end

    for index, weapon in pairs(inventory:available_selections()) do
        local base = weapon.unit:base()
        local max_ammo = base:get_ammo_max()
        local full_bullets = 0

        if cost_mode == 2 then
            -- Custom percentage mode
            local custom_pct = (self.settings.custom_cost_percent or 20) / 100
            full_bullets = max_ammo * custom_pct
        else
            -- Perk-based mode (mirrors pick up and redeploy)
            if recorded_costs and recorded_costs[index] then
                full_bullets = recorded_costs[index]
            else
                full_bullets = max_ammo * full_cost_fraction
            end
        end

        local bullets_needed = math.ceil(full_bullets * missing_ratio * cost_mult)
        if bullets_needed > 0 then
            weapon_costs[index] = bullets_needed
            total_bullets = total_bullets + bullets_needed
        else
            weapon_costs[index] = 0
        end
    end

    return weapon_costs, total_bullets
end

function BetterSentryReloader:can_afford(weapon_costs, player_unit)
    local inventory = player_unit:inventory()
    if not inventory then
        return false
    end

    for index, cost in pairs(weapon_costs) do
        if cost > 0 then
            local weapon = inventory:available_selections()[index]
            if not weapon or weapon.unit:base():get_ammo_total() < cost then
                return false
            end
        end
    end
    return true
end

function BetterSentryReloader:deduct_ammo(weapon_costs, player_unit)
    local inventory = player_unit:inventory()
    if not inventory then
        return
    end

    for index, cost in pairs(weapon_costs) do
        if cost > 0 then
            local weapon = inventory:available_selections()[index]
            if weapon then
                local base = weapon.unit:base()
                local current_ammo = base:get_ammo_total()
                local new_ammo = math.max(0, current_ammo - cost)
                base:set_ammo_total(new_ammo)

                local clip_ammo = base:get_ammo_remaining_in_clip()
                if clip_ammo > new_ammo then
                    base:set_ammo_remaining_in_clip(new_ammo)
                end

                if managers.hud then
                    managers.hud:set_ammo_amount(index, base:ammo_info())
                end
            end
        end
    end
end

function BetterSentryReloader:update_sentry_refund_pool(sentry_unit, player_unit)
    local eq = player_unit:equipment()
    if not eq or not eq._sentry_ammo_cost then
        return
    end

    local uid = sentry_unit:id()
    eq._sentry_ammo_cost[uid] = eq._sentry_ammo_cost[uid] or {}

    local cost_reduction_lvl = managers.player:upgrade_value("sentry_gun", "cost_reduction", 1)
    local dep_cost = (SentryGunBase and SentryGunBase.DEPLOYEMENT_COST and SentryGunBase.DEPLOYEMENT_COST[cost_reduction_lvl]) or 0.70
    local full_cost_fraction = 1.0 - dep_cost

    local inventory = player_unit:inventory()
    if inventory then
        for index, weapon in pairs(inventory:available_selections()) do
            local base = weapon.unit:base()
            local full_bullets = math.floor(base:get_ammo_max() * full_cost_fraction)
            eq._sentry_ammo_cost[uid][index] = full_bullets
        end
    end
end

function BetterSentryReloader:refill_unit(sentry_unit)
    if not alive(sentry_unit) then
        return
    end

    if Network:is_server() then
        if sentry_unit:weapon() then
            sentry_unit:weapon():change_ammo(sentry_unit:weapon():ammo_max())
        end
        if sentry_unit:brain() then
            sentry_unit:brain():switch_on()
        end
        if sentry_unit:interaction() then
            sentry_unit:interaction():set_dirty(true)
        end
        if self.settings.repair_health and sentry_unit:character_damage() then
            if sentry_unit:character_damage().replenish then
                sentry_unit:character_damage():replenish()
            elseif sentry_unit:character_damage()._health and sentry_unit:character_damage()._HEALTH_INIT then
                sentry_unit:character_damage()._health = sentry_unit:character_damage()._HEALTH_INIT
            end
        end
    else
        -- Guest/Client: Send native network event to host.
        -- Event ID 1 in sentry refill_ratios corresponds to 100% refill.
        if managers.network and managers.network:session() then
            managers.network:session():send_to_host("sync_unit_event_id_16", sentry_unit, "base", 1)
        end
    end
end

function BetterSentryReloader:notify(text)
    if not self.settings.show_hint then
        return
    end

    if managers.hud and managers.hud.show_hint then
        managers.hud:show_hint({
            text = text,
            time = 2.5
        })
    end
end

function BetterSentryReloader:play_feedback_sound(sound_name)
    if not self.settings.play_sound then
        return
    end

    local player_unit = managers.player:player_unit()
    if alive(player_unit) and player_unit:sound() then
        player_unit:sound():play(sound_name or "ammo_pickup")
    elseif managers.menu then
        managers.menu:post_event("menu_enter")
    end
end

function BetterSentryReloader:reload_sentry()
    -- Debounce hotkey (300ms cooldown)
    local now = Application:time()
    if now - self._last_reload_t < 0.3 then
        return
    end
    self._last_reload_t = now

    local player_unit = managers.player:player_unit()
    if not alive(player_unit) then
        return
    end

    -- Verify player is in a valid alive state
    local state = managers.player:current_state()
    if state == "bleed_out" or state == "fatal" or state == "incapacitated" or state == "custody" then
        return
    end

    local targets = self:get_target_sentries(player_unit)
    if #targets == 0 then
        self:notify(managers.localization:text("bsr_hint_none_in_range"))
        return
    end

    -- Check if targets are already at 100% ammo
    local needs_reload = {}
    for _, sentry in ipairs(targets) do
        local ratio = (sentry:weapon() and sentry:weapon():ammo_ratio()) or 1
        if ratio < 0.999 then
            table.insert(needs_reload, sentry)
        end
    end

    if #needs_reload == 0 then
        self:notify(managers.localization:text("bsr_hint_already_full"))
        return
    end

    -- Calculate total ammo required across all targets needing reload
    local total_costs_by_weapon = {}
    local grand_total_bullets = 0
    local target_costs = {}

    for _, sentry in ipairs(needs_reload) do
        local costs, bullets = self:calculate_ammo_cost(sentry, player_unit)
        target_costs[sentry:key()] = costs
        grand_total_bullets = grand_total_bullets + bullets

        for idx, cost in pairs(costs) do
            total_costs_by_weapon[idx] = (total_costs_by_weapon[idx] or 0) + cost
        end
    end

    -- Check affordability
    if not self:can_afford(total_costs_by_weapon, player_unit) then
        self:notify(managers.localization:text("bsr_hint_no_ammo"))
        if managers.menu then
            managers.menu:post_event("menu_error")
        end
        return
    end

    -- Deduct ammo from weapons
    self:deduct_ammo(total_costs_by_weapon, player_unit)

    -- Refill sentries and update refund tracking
    local reloaded_count = 0
    for _, sentry in ipairs(needs_reload) do
        self:refill_unit(sentry)
        self:update_sentry_refund_pool(sentry, player_unit)
        reloaded_count = reloaded_count + 1

        -- Play sound at sentry unit
        if sentry:sound_source() and self.settings.play_sound then
            sentry:sound_source():post_event("wp_sentrygun_swap_ammo")
        end
    end

    -- Player audio and HUD feedback
    self:play_feedback_sound("ammo_pickup")

    local msg
    if grand_total_bullets > 0 then
        msg = managers.localization:text("bsr_hint_reloaded_cost", {
            COUNT = tostring(reloaded_count),
            BULLETS = tostring(grand_total_bullets)
        })
    else
        msg = managers.localization:text("bsr_hint_reloaded_free", {
            COUNT = tostring(reloaded_count)
        })
    end

    self:notify(msg)
end

BetterSentryReloader:load()
