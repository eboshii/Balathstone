--- STEAMODDED HEADER
--- MOD_NAME: Balathstone
--- MOD_ID: Balathstone
--- MOD_AUTHOR: [Balathstone Team]
--- MOD_DESCRIPTION: Total conversion: Hearthstone Minions, Spells, Quests, and Legendary Boss Blinds.
--- VERSION: 1.0.1
--- PREFIX: hs

-- Enable smooth linear anti-aliased texture filtering for high-resolution cards
SMODS.texture_filter_override = "linear"

-- Create Atlases for custom textures (rendered with full official Hearthstone borders)
SMODS.Atlas({
    key = "hs_minions",
    path = "minions.png",
    px = 142,
    py = 190
})

SMODS.Atlas({
    key = "hs_consumables",
    path = "consumables.png",
    px = 142,
    py = 190
})

SMODS.Atlas({
    key = "hs_vouchers",
    path = "vouchers.png",
    px = 142,
    py = 190
})

SMODS.Atlas({
    key = "hs_cards",
    path = "cards.png",
    px = 142,
    py = 190
})

SMODS.Atlas({
    key = "hs_decks",
    path = "decks.png",
    px = 142,
    py = 190
})

SMODS.Atlas({
    key = "hs_packs",
    path = "packs.png",
    px = 142,
    py = 190
})

SMODS.Atlas({
    key = "hs_blinds",
    path = "blinds.png",
    px = 34,
    py = 34,
    atlas_table = "ANIMATION_ATLAS",
    frames = 21
})

-- Register Hearthstone Sounds
if SMODS.Sound then
    SMODS.Sound({ key = "attack", path = "attack.wav" })
end

-- Apply smooth linear filtering to our custom Hearthstone atlases
local function apply_linear_filtering()
    for _, key in ipairs({"hs_minions", "hs_consumables", "hs_vouchers", "hs_cards", "hs_blinds", "hs_decks", "hs_packs"}) do
        if G.ASSET_ATLAS and G.ASSET_ATLAS[key] and G.ASSET_ATLAS[key].image then
            G.ASSET_ATLAS[key].image:setFilter("linear", "linear")
        end
    end
end

-- (SMODS.texture_filter_override above already makes Sprite:draw_self /
-- draw_from use linear filtering, so no extra draw hook is needed.)

-- Load Core Engine
-- SMODS.current_mod is only ours while this file loads; keep our own handle.
local THIS_MOD = SMODS.current_mod
local mod_path = THIS_MOD.path
assert(SMODS.load_file("src/core.lua"))()
assert(SMODS.load_file("src/visuals.lua"))()

-- Load Minions (150 Jokers + summon-only tokens)
assert(SMODS.load_file("src/enhancements.lua"))()
assert(SMODS.load_file("src/minions.lua"))()

-- Load Consumables: Spells (Tarot), Locations (Planet), Forbidden Spells (Spectral)
assert(SMODS.load_file("src/spells.lua"))()
assert(SMODS.load_file("src/locations.lua"))()
assert(SMODS.load_file("src/spectrals.lua"))()

-- Load Hearthstone Legendary Boss Blinds
assert(SMODS.load_file("src/bosses.lua"))()

-- Load Hearthstone Adventure Treasure Vouchers (32 Vouchers)
assert(SMODS.load_file("src/vouchers.lua"))()

-- Load Hearthstone Packs and Discover
assert(SMODS.load_file("src/packs.lua"))()

-- Load Hearthstone Deck Card Backs
assert(SMODS.load_file("src/decks.lua"))()

-- Load Hearthstone Secrets (replace every vanilla Tag)
assert(SMODS.load_file("src/secrets.lua"))()

-- Deep-merge helper for table localization injection
local function deep_merge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            deep_merge(target[k], v)
        else
            target[k] = v
        end
    end
end

-- Load Hearthstone UI Localization
local function apply_hearthstone_localization()
    if SMODS.load_mod_localization then
        SMODS.load_mod_localization(mod_path, THIS_MOD.id)
    end
    if G.localization then
        local lang = (G.SETTINGS and (G.SETTINGS.real_language or G.SETTINGS.language)) or "en-us"
        local loc_chunk = loadfile(mod_path .. "localization/" .. lang .. ".lua") or loadfile(mod_path .. "localization/default.lua")
        if loc_chunk then
            local ok, loc_data = pcall(loc_chunk)
            if ok and type(loc_data) == "table" then
                deep_merge(G.localization, loc_data)
            end
        end
    end
    if init_localization and type(init_localization) == 'function' then
        init_localization()
    end
end
apply_hearthstone_localization()

-- COMPLETE VANILLA PURGE: Remove ALL old Jokers, Tarots, Planets, Spectrals, Vouchers, and Boss Blinds!
local TARGET_SETS = {
    Joker = true,
    Tarot = true,
    Planet = true,
    Spectral = true,
    Tarot_Planet = true,
    Voucher = true,
    Tag = true, -- every Tag is a Hearthstone Secret (src/secrets.lua)
}

-- 1. Intercept pool generation so shops, booster packs, tags, and events ONLY yield Hearthstone cards
local orig_get_current_pool = get_current_pool
function get_current_pool(_type, _rarity, _legendary, _append)
    local pool, pool_key = orig_get_current_pool(_type, _rarity, _legendary, _append)
    if TARGET_SETS[_type] then
        local filtered = {}
        for _, k in ipairs(pool) do
            if k and (k:find('_hs_') or k == 'UNAVAILABLE') then
                table.insert(filtered, k)
            end
        end
        if #filtered == 0 then
            for k, v in pairs(G.P_CENTERS) do
                if k:find('_hs_') then
                    if v.set == _type or (_type == 'Tarot_Planet' and (v.set == 'Tarot' or v.set == 'Planet')) then
                        table.insert(filtered, k)
                    end
                end
            end
        end
        return filtered, pool_key
    end
    return pool, pool_key
end

-- Hearthstone's 7-minion board: +2 Minion slots on top of the base 5. Decks
-- apply their own changes afterwards (Black Deck: 7 - 1 = 6), and resumed runs
-- keep their saved limit.
if get_starting_params then
    local orig_get_starting_params = get_starting_params
    function get_starting_params()
        local p = orig_get_starting_params()
        if p and p.joker_slots then
            p.joker_slots = p.joker_slots + 2
        end
        return p
    end
end

-- Steeper Blind scaling: on top of vanilla's curve, every Ante multiplies the requirement
-- by ANTE_GROWTH more (Ante 1 unchanged, Ante 8 = 5x vanilla, still compounding in endless).
-- Stakes keep stacking on top as usual.
Balathstone.ANTE_GROWTH = 5 ^ (1 / 7)
if get_blind_amount then
    local orig_get_blind_amount = get_blind_amount
    function get_blind_amount(ante)
        local amount = orig_get_blind_amount(ante)
        if not ante or ante <= 1 or not amount then return amount end
        amount = amount * Balathstone.ANTE_GROWTH ^ (ante - 1)
        -- round like vanilla: keep two significant figures
        local unit = 10 ^ math.max(0, math.floor(math.log10(amount) - 1))
        return math.floor(amount / unit + 1e-6) * unit
    end
end

-- 2. Purge vanilla centers and replace Boss Blinds with Hearthstone Legendary Bosses
local original_init_game_object = Game.init_game_object
function Game:init_game_object()
    local ret = original_init_game_object(self)

    apply_linear_filtering()
    apply_hearthstone_localization()
    if Balathstone and Balathstone.apply_deck_skins then
        Balathstone.apply_deck_skins()
    end
    if Balathstone and Balathstone.apply_pack_skins then
        Balathstone.apply_pack_skins()
    end
    
    -- Disable all vanilla cards in G.P_CENTERS
    for k, v in pairs(G.P_CENTERS) do
        if TARGET_SETS[v.set] and not k:find('_hs_') then
            v.in_pool = function() return false end
            v.unlocked = false
            v.discovered = false
        end
    end
    
    -- Vanilla Tags never appear: Secrets replace them
    if G.P_TAGS then
        for k, v in pairs(G.P_TAGS) do
            if not k:find('_hs_') then v.in_pool = function() return false end end
        end
    end

    -- Clean center pools for Jokers and Consumables
    if G.P_CENTER_POOLS then
        for set_name, _ in pairs(TARGET_SETS) do
            if G.P_CENTER_POOLS[set_name] then
                local hs_only = {}
                for _, center in ipairs(G.P_CENTER_POOLS[set_name]) do
                    if center.key and center.key:find('_hs_') then
                        table.insert(hs_only, center)
                    end
                end
                G.P_CENTER_POOLS[set_name] = hs_only
            end
        end
        
        -- Filter Boss Blinds pool to ONLY Hearthstone Legendary Bosses (bl_hs_...) and mark discovered
        if G.P_BLINDS then
            for k, b in pairs(G.P_BLINDS) do
                if k:find('^bl_hs_') then
                    b.discovered = true
                elseif b.boss or b.small or b.big then
                    b.in_pool = function() return false end
                end
            end
        end
    end
    
    -- Enable selecting spells, locations, and forbidden spells to inventory from packs
    if SMODS.ConsumableTypes then
        for _, set_name in ipairs({'Tarot', 'Planet', 'Spectral'}) do
            if SMODS.ConsumableTypes[set_name] then
                SMODS.ConsumableTypes[set_name].select_card = function(self, card, pack) return 'consumeables', true end
            end
        end
    end
    if G.P_CENTERS then
        for _, v in pairs(G.P_CENTERS) do
            if v.set == 'Booster' and (v.kind == 'Arcana' or v.kind == 'Celestial' or v.kind == 'Spectral') then
                v.select_card = function(self, card, pack) return 'consumeables', true end
            end
        end
    end
    
    return ret
end

-- Every Hearthstone timing window (Battlecry, Deathrattle, start/end of turn,
-- spells, shop...) is dispatched centrally by the engine.
SMODS.current_mod.calculate = function(self, context)
    return (Balathstone or Balearthstone).calculate(context)
end
