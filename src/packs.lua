-- Balathstone packs
--  * Discover: free "choose 1 of 3" packs. They open in the shop (straight
--    away if you're already there, otherwise as soon as the next shop opens),
--    so a pack never interrupts a hand.
--  * Hearthstone card-pack skins for the vanilla booster packs.
local HS = Balathstone or Balearthstone

-- Atlas rows (hs_packs): 0 Spell, 1 Location, 2 Forbidden, 3 Card, 4 Minion, 5 Discover
-- Columns: 0 normal, 1 jumbo, 2 mega  (Discover row: 0 spell, 1 location, 2 minion)
local PACK_ROWS = { arcana = 0, celestial = 1, spectral = 2, standard = 3, buffoon = 4 }
local SIZES = { normal = 0, jumbo = 1, mega = 2 }

local function can_select_consumeable(self, card, pack)
    return 'consumeables', true
end

if SMODS.ConsumableTypes then
    for _, t in ipairs({ 'Tarot', 'Planet', 'Spectral' }) do
        if SMODS.ConsumableTypes[t] then
            SMODS.ConsumableTypes[t].select_card = can_select_consumeable
        end
    end
end

local PACK_NAMES = {
    arcana = { normal = "Spell Pack", jumbo = "Jumbo Spell Pack", mega = "Mega Spell Pack" },
    celestial = { normal = "Location Pack", jumbo = "Jumbo Location Pack", mega = "Mega Location Pack" },
    spectral = { normal = "Forbidden Pack", jumbo = "Jumbo Forbidden Pack", mega = "Mega Forbidden Pack" },
    standard = { normal = "Standard Pack", jumbo = "Jumbo Standard Pack", mega = "Mega Standard Pack" },
    buffoon = { normal = "Minion Pack", jumbo = "Jumbo Minion Pack", mega = "Mega Minion Pack" },
}

-- Vanilla packs only go up to these numbers (e.g. there is no p_buffoon_mega_2)
local VARIANTS = 4

local owned = false
function HS.apply_pack_skins()
    for kind, row in pairs(PACK_ROWS) do
        for size, col in pairs(SIZES) do
            for n = 1, VARIANTS do
                local key = 'p_' .. kind .. '_' .. size .. '_' .. n
                local center = G.P_CENTERS and G.P_CENTERS[key]
                if center then
                    local pos = { x = col, y = row }
                    local pack_name = PACK_NAMES[kind] and PACK_NAMES[kind][size]
                    local consumable = kind == 'arcana' or kind == 'celestial' or kind == 'spectral'
                    center.atlas = 'hs_packs'
                    center.pos = pos
                    if pack_name then center.name = pack_name end
                    if consumable then center.select_card = can_select_consumeable end
                    -- take ownership once (it's re-run every new run otherwise)
                    if not owned and SMODS.Booster and SMODS.Booster.take_ownership then
                        pcall(function()
                            SMODS.Booster:take_ownership(key:sub(3), {
                                name = pack_name,
                                atlas = 'hs_packs',
                                pos = pos,
                                select_card = consumable and can_select_consumeable or nil
                            }, true)
                        end)
                    end
                end
            end
        end
    end
    owned = true
end

HS.apply_pack_skins()

-- Hook Card:set_sprites to ensure Hearthstone pack textures are always used for boosters
if Card and Card.set_sprites then
    local orig_card_set_sprites = Card.set_sprites
    function Card:set_sprites(_center, _front)
        orig_card_set_sprites(self, _center, _front)
        if self.ability and self.ability.set == 'Booster' then
            local center = _center or self.config.center
            if center and center.atlas == 'hs_packs' and G.ASSET_ATLAS and G.ASSET_ATLAS['hs_packs'] then
                if self.children.center then
                    self.children.center.atlas = G.ASSET_ATLAS['hs_packs']
                    self.children.center:set_sprite_pos(center.pos)
                end
            end
        end
    end
end

-- ----------------------------------------------------------------- Discover
local function discover_options(kind, opts)
    local pool = {}
    if kind == 'spell' then
        for _, s in ipairs(HS.spells) do if not s.token then pool[#pool + 1] = s.key end end
    elseif kind == 'location' then
        for _, key in pairs(HS.location_for_hand) do pool[#pool + 1] = key end
    elseif kind == 'minion' then
        for key, d in pairs(HS.defs) do
            if not d.token and (d.mana or 0) >= (opts.min_mana or 0) then pool[#pool + 1] = key end
        end
    end
    table.sort(pool)
    local picks = {}
    if opts.first then picks[1] = opts.first end
    local guard = 0
    while #picks < 3 and guard < 100 do
        guard = guard + 1
        local k = HS.pick(pool, 'hs_discover')
        local dup = false
        for _, p in ipairs(picks) do if p == k then dup = true end end
        if k and not dup then picks[#picks + 1] = k end
        if #pool <= #picks then break end
    end
    return picks
end

local function discover_pack(key, kind, pos, name, text)
    if not SMODS.Booster then return end
    SMODS.Booster({
        key = key,
        kind = 'hs_discover',
        atlas = 'hs_packs',
        pos = pos,
        config = { extra = 3, choose = 1 },
        cost = 0,
        weight = 0,
        draw_hand = false,
        select_card = kind ~= 'minion' and can_select_consumeable or nil,
        in_pool = function() return false end,
        loc_txt = { name = name, group_name = 'Discover', text = text },
        loc_vars = function(self) return { vars = {} } end,
        create_card = function(self, card, i)
            local st = HS.state()
            local choices = st.discover_choices or {}
            local k = choices[i]
            if kind == 'minion' then
                return { set = 'Joker', key = k, area = G.pack_cards, skip_materialize = true, key_append = 'hs_disc' }
            end
            return { set = kind == 'location' and 'Planet' or 'Tarot', key = k, area = G.pack_cards,
                skip_materialize = true, key_append = 'hs_disc' }
        end,
    })
end
discover_pack('hs_discover_spell', 'spell', { x = 0, y = 5 }, 'Discover a Spell',
    { 'Choose {C:attention}1{} of {C:attention}3{} Spells', 'to add to your hand' })
discover_pack('hs_discover_location', 'location', { x = 1, y = 5 }, 'Discover a Location',
    { 'Choose {C:attention}1{} of {C:attention}3{} Locations', 'to add to your hand' })
discover_pack('hs_discover_minion', 'minion', { x = 2, y = 5 }, 'Discover a Minion',
    { 'Choose {C:attention}1{} of {C:attention}3{}', 'minions to summon' })

local PACK_FOR = { spell = 'p_hs_discover_spell', location = 'p_hs_discover_location', minion = 'p_hs_discover_minion' }

-- Queue a Discover; opts: { first = key always offered, min_mana = n }
function HS.discover(kind, source, opts)
    local st = HS.state()
    st.discover_queue = st.discover_queue or {}
    st.discover_queue[#st.discover_queue + 1] = { kind = kind, opts = opts or {} }
    if source then HS.say(source, 'Discover!', G.C.SECONDARY_SET.Spectral) end
    HS.try_open_discover()
end

function HS.in_shop()
    return G.STATE == G.STATES.SHOP and G.shop_jokers ~= nil and not G.pack_cards
end

function HS.open_pack(key)
    local center = G.P_CENTERS[key]
    if not center then return end
    local card = Card(G.play.T.x + G.play.T.w / 2 - G.CARD_W * 1.27 / 2,
        G.play.T.y + G.play.T.h / 2 - G.CARD_H * 1.27 / 2, G.CARD_W * 1.27, G.CARD_H * 1.27,
        G.P_CARDS.empty, center, { bypass_discovery_center = true, bypass_discovery_ui = true })
    card.cost = 0
    card.from_tag = true
    G.FUNCS.use_card({ config = { ref_table = card } })
    card:start_materialize()
end

function HS.try_open_discover()
    local st = HS.state()
    local q = st.discover_queue
    if not (q and #q > 0) or not HS.in_shop() then return false end
    local item = table.remove(q, 1)
    st.discover_choices = discover_options(item.kind, item.opts)
    HS.event(function() HS.open_pack(PACK_FOR[item.kind]) end)
    return true
end

-- open queued Discovers when the shop opens / after each pack closes
local orig_calc = HS.calculate
function HS.calculate(context)
    local r = orig_calc(context)
    if context.starting_shop or context.ending_booster then
        HS.event(function() HS.try_open_discover() end)
    end
    return r
end
