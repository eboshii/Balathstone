-- Balathstone Secrets
-- Every vanilla Tag is replaced by a Hearthstone Secret. You still earn one by
-- skipping a Blind; it waits in the tag area as a Secret icon (hover it to see
-- the card) and triggers ONCE when its condition happens during play, usually on
-- the enemy's turn (the Boss attacking). Like Hearthstone, you can't hold two
-- copies of the same Secret.
--
-- The engine (src/core.lua) calls HS.trigger_secret(event, ...) at:
--   'boss_attack'  (target, atk)  before a Boss attack lands. Return {cancel=true} or {redirect=card}
--   'buy_minion'   (card)         after you buy a minion
--   'blind_set'    ()             when a Blind starts
--   'round_start'  ()             after the opening hand is drawn
--   'cast_spell'   (center, card) after you use a Spell
--   'minion_death' (card)         when a friendly minion really dies (not sold, not Reborn)
--   'would_lose'   ()             your last Hand failed to beat the Blind
--   'lose_money'   (n)            you lose money during a round (your hero takes damage)
local HS = Balathstone or Balearthstone
local E = HS.E

SMODS.Atlas({ key = 'hs_secret_icons', path = 'secret_icons.png', px = 34, py = 34 })
SMODS.Atlas({ key = 'hs_secrets', path = 'secrets.png', px = 142, py = 190 })

-- icon column per class in hs_secret_icons
HS.SECRET_CLASS = {
    Mage = { x = 0, colour = HEX and HEX('C25FD8') or nil },
    Hunter = { x = 1, colour = HEX and HEX('3FA34D') or nil },
    Paladin = { x = 2, colour = HEX and HEX('E2B13C') or nil },
    Rogue = { x = 3, colour = HEX and HEX('7D7D86') or nil },
}

HS.SECRETS = {}          -- list, in card-atlas order
HS.SECRET_BY_KEY = {}    -- 'tag_hs_x' -> definition

local function secret(t)
    local idx = #HS.SECRETS
    t.key = 'tag_hs_' .. t.id
    HS.SECRETS[#HS.SECRETS + 1] = t
    HS.SECRET_BY_KEY[t.key] = t
    local text = { '{C:attention}Secret:{} ' .. t.text[1] }
    for i = 2, #t.text do text[#text + 1] = t.text[i] end
    t.card_text = text
    SMODS.Tag({
        key = t.id,
        atlas = 'hs_secret_icons',
        pos = { x = HS.SECRET_CLASS[t.class].x, y = 0 },
        loc_txt = { name = t.name, text = text },
        config = {},
        discovered = true,
        min_ante = t.min_ante,
        hs_secret = t,
        -- the card shown when you hover the icon (tools/build_art.py renders it)
        hs_id = t.hs_id,
        hs_text = text,
        hs_card_atlas = 'hs_secrets',
        hs_card_pos = { x = idx % 8, y = math.floor(idx / 8) },
        -- Secrets never fire through vanilla tag timing; the engine triggers them
        apply = function(self, tag, context) end,
        loc_vars = function(self, info_queue, tag)
            info_queue[#info_queue + 1] = { set = 'Other', key = 'hs_kw_secret' }
            return { vars = {} }
        end,
    })
    return t
end

-- Fire every held Secret listening for `event`. A Secret whose fire() returns
-- false (e.g. nothing to summon into) stays hidden for later.
function HS.trigger_secret(event, ...)
    if not (G.GAME and G.GAME.tags) then return nil end
    local result = {}
    local held = {}
    for i, tag in ipairs(G.GAME.tags) do held[i] = tag end
    for _, tag in ipairs(held) do
        local def = HS.SECRET_BY_KEY[tag.key]
        if def and def.event == event and not tag.triggered then
            local r = def.fire(tag, ...)
            if r ~= false then
                tag.triggered = true
                if type(r) == 'table' then for k, v in pairs(r) do result[k] = v end end
                local col = HS.SECRET_CLASS[def.class].colour or G.C.PURPLE
                if tag.yep then
                    tag:yep(def.name .. '!', col, function() return true end)
                else
                    for i, t in ipairs(G.GAME.tags) do if t == tag then table.remove(G.GAME.tags, i); break end end
                end
                HS.notify('on_secret', def)
            end
        end
    end
    return next(result) and result or nil
end

local function space() return HS.board_space() > 0 end
local function summon_n(id, n)
    local made = 0
    for _ = 1, n do if HS.summon(id) then made = made + 1 end end
    return made > 0
end

-- ------------------------------------------------------------------- Mage
secret { id = 'ice_block', name = 'Ice Block', hs_id = 'EX1_295', class = 'Mage', event = 'would_lose',
    text = { 'When your last Hand would', 'lose the round, gain', '{C:blue}+1{} Hand instead' },
    fire = function() ease_hands_played(1) end }

secret { id = 'ice_barrier', name = 'Ice Barrier', hs_id = 'EX1_289', class = 'Mage', event = 'boss_attack',
    text = { 'When the Boss attacks a', 'minion, it gains {C:attention}+8{} Health', 'first' },
    fire = function(tag, target)
        if not target then return false end
        HS.buff(target, 0, 8)
    end }

secret { id = 'mirror_entity', name = 'Mirror Entity', hs_id = 'EX1_294', class = 'Mage', event = 'buy_minion',
    text = { 'After you buy a minion,', '{C:attention}summon{} a copy of it' },
    fire = function(tag, card)
        if not space() then return false end
        if not HS.summon(card.config.center.key) then return false end
    end }

secret { id = 'counterspell', name = 'Counterspell', hs_id = 'EX1_287', class = 'Mage', event = 'blind_set',
    text = { 'When a {C:attention}Boss Blind{} starts,', 'disable its ability' },
    fire = function()
        if not (HS.is_boss() and not G.GAME.blind.disabled) then return false end
        G.GAME.blind:disable()
    end }

secret { id = 'mana_bind', name = 'Mana Bind', hs_id = 'UNG_024', class = 'Mage', event = 'cast_spell',
    text = { 'When you cast a {C:attention}Spell{}, add a', '{C:dark_edition}Negative{} copy of it to', 'your hand' },
    fire = function(tag, center)
        if not (center and center.key and G.P_CENTERS[center.key]) then return false end
        local c = SMODS.add_card({ set = center.set, key = center.key, area = G.consumeables,
            edition = 'e_negative', key_append = 'hs_mana_bind' })
        if not c then return false end
        c:set_edition({ negative = true }, true)
    end }

-- ------------------------------------------------------------------- Hunter
secret { id = 'explosive_trap', name = 'Explosive Trap', hs_id = 'EX1_610', class = 'Hunter',
    event = 'boss_attack',
    text = { 'When the Boss attacks,', 'deal {C:red}5{} damage to the Blind' },
    fire = function() HS.damage_blind(5) end }

secret { id = 'freezing_trap', name = 'Freezing Trap', hs_id = 'EX1_611', class = 'Hunter',
    event = 'boss_attack',
    text = { 'When the Boss attacks,', 'cancel it and {C:attention}Freeze{}', 'the Boss' },
    fire = function()
        HS.freeze_boss()
        return { cancel = true }
    end }

secret { id = 'snake_trap', name = 'Snake Trap', hs_id = 'EX1_554', class = 'Hunter', event = 'boss_attack',
    text = { 'When the Boss attacks a', 'minion, {C:attention}summon{} three', '1/1 Snakes' },
    fire = function(tag, target)
        if not (target and space()) then return false end
        summon_n('snake', 3)
    end }

secret { id = 'bear_trap', name = 'Bear Trap', hs_id = 'AT_060', class = 'Hunter', event = 'boss_attack',
    text = { 'When the Boss attacks,', '{C:attention}summon{} a 3/3 Bear', 'with {C:attention}Taunt{}' },
    fire = function()
        if not space() then return false end
        HS.summon('ironfur_grizzly')
    end }

secret { id = 'cat_trick', name = 'Cat Trick', hs_id = 'KAR_004', class = 'Hunter', event = 'cast_spell',
    text = { 'After you cast a {C:attention}Spell{},', '{C:attention}summon{} a 4/2 Panther', 'with {C:attention}Stealth{}' },
    fire = function()
        if not space() then return false end
        HS.summon('cat_in_a_hat')
    end }

-- ------------------------------------------------------------------- Paladin
secret { id = 'noble_sacrifice', name = 'Noble Sacrifice', hs_id = 'EX1_130', class = 'Paladin',
    event = 'boss_attack',
    text = { 'When the Boss attacks,', '{C:attention}summon{} a 2/1 Defender', 'to take the hit' },
    fire = function()
        if not space() then return false end
        local d = HS.summon('defender')
        if not d then return false end
        return { redirect = d }
    end }

secret { id = 'redemption', name = 'Redemption', hs_id = 'EX1_136', class = 'Paladin', event = 'minion_death',
    text = { 'When a friendly minion dies,', 'return it to life with', '{C:attention}1{} Health' },
    fire = function(tag, card)
        local key = card.config.center.key
        HS.event(function() HS.summon(key, nil, { health = 1 }) end)
    end }

secret { id = 'avenge', name = 'Avenge', hs_id = 'FP1_020', class = 'Paladin', event = 'minion_death',
    text = { 'When a friendly minion dies,', 'give a random friendly', 'minion {C:attention}+3/+2{}' },
    fire = function(tag, card)
        local pool = HS.others(card)
        local t = HS.pick(pool, 'hs_avenge')
        if not t then return false end
        HS.buff(t, 3, 2)
    end }

secret { id = 'eye_for_an_eye', name = 'Eye for an Eye', hs_id = 'EX1_132', class = 'Paladin',
    event = 'lose_money',
    text = { 'When you lose money in a', 'round, deal that much', 'damage to the Blind' },
    fire = function(tag, n) HS.damage_blind(n) end }

secret { id = 'competitive_spirit', name = 'Competitive Spirit', hs_id = 'AT_073', class = 'Paladin',
    event = 'round_start',
    text = { 'When your turn starts,', 'give your minions {C:attention}+1/+1{}' },
    fire = function()
        local ms = HS.minions()
        if #ms == 0 then return false end
        for _, m in ipairs(ms) do HS.buff(m, 1, 1) end
    end }

-- ------------------------------------------------------------------- Rogue
secret { id = 'cheat_death', name = 'Cheat Death', hs_id = 'LOOT_204', class = 'Rogue', event = 'minion_death',
    text = { 'When a friendly minion dies,', 'it returns at the start', 'of the next round' },
    fire = function(tag, card)
        local st = HS.state()
        st.cheat_death = st.cheat_death or {}
        st.cheat_death[#st.cheat_death + 1] = card.config.center.key
    end }

secret { id = 'dirty_tricks', name = 'Dirty Tricks', hs_id = 'BT_709', class = 'Rogue', event = 'cast_spell',
    text = { 'After you cast a {C:attention}Spell{},', 'draw {C:attention}2{} cards' },
    fire = function() HS.draw(2) end }

-- Cheat Death: minions come back when the next Blind starts
function HS.return_cheated()
    local st = HS.state()
    local list = st.cheat_death
    if not (list and #list > 0) then return end
    st.cheat_death = {}
    for _, key in ipairs(list) do HS.summon(key) end
end

-- ------------------------------------------------------------------- tag pool
-- Only Secrets are ever offered; you can't hold two copies of the same one.
local function held(key)
    for _, t in ipairs((G.GAME and G.GAME.tags) or {}) do
        if t.key == key and not t.triggered then return true end
    end
    return false
end

if add_tag and Tag then
    local orig_add_tag = add_tag
    function add_tag(tag, ...)
        -- a vanilla Tag handed out directly (Overwatch Deck, challenges...) becomes a random Secret
        if tag and tag.key and not HS.SECRET_BY_KEY[tag.key] and G.P_TAGS and G.P_TAGS['tag_hs_ice_block'] then
            local options = {}
            for _, s in ipairs(HS.SECRETS) do if not held(s.key) then options[#options + 1] = s.key end end
            local key = HS.pick(options, 'hs_secret_convert')
            if not key then return end
            tag = Tag(key, false, tag.ability and tag.ability.blind_type)
        end
        if tag and HS.SECRET_BY_KEY[tag.key] and held(tag.key) then
            local options = {}
            for _, s in ipairs(HS.SECRETS) do if not held(s.key) then options[#options + 1] = s.key end end
            local key = HS.pick(options, 'hs_secret_reroll')
            if not key then return end -- every Secret is already up
            tag = Tag(key, false, tag.ability and tag.ability.blind_type)
        end
        return orig_add_tag(tag, ...)
    end
end

-- Hovering a Secret shows the Secret card itself above its description
if G and G.UIDEF and G.UIDEF.card_h_popup then
    local orig_popup = G.UIDEF.card_h_popup
    function G.UIDEF.card_h_popup(card)
        local base = orig_popup(card)
        local tag = card and card.config and card.config.tag
        local def = tag and HS.SECRET_BY_KEY[tag.key]
        local atlas = def and G.ASSET_ATLAS and G.ASSET_ATLAS['hs_secrets']
        if not (atlas and base and base.nodes) then return base end
        local center = G.P_TAGS[tag.key]
        local w, h = G.CARD_W * 1.15, G.CARD_H * 1.15
        local sprite = Sprite(0, 0, w, h, atlas, center.hs_card_pos)
        return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = {
                { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                    { n = G.UIT.O, config = { object = sprite } } } },
                { n = G.UIT.R, config = { align = 'cm' }, nodes = base.nodes },
            } } } }
    end
end

return HS.SECRETS
