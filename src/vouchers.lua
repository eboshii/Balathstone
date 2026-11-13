-- Balathstone Treasures (replace Vouchers)
-- Hearthstone Adventure treasures, mostly "Passive" effects, which map
-- naturally onto Balatro's permanent vouchers. 16 tier-1 / tier-2 pairs.
local HS = Balathstone or Balearthstone
local E = HS.E

function HS.voucher(id)
    return G.GAME and G.GAME.used_vouchers and G.GAME.used_vouchers['v_hs_' .. id] and true or false
end

HS.voucher_count = HS.voucher_count or 0
HS.voucher_defs = HS.voucher_defs or {}

local function V(v)
    HS.voucher_count = HS.voucher_count + 1
    local idx = HS.voucher_count - 1
    HS.voucher_defs[#HS.voucher_defs + 1] = v
    local tips = HS.keyword_tips(v.text)
    SMODS.Voucher({
        key = 'hs_' .. v.id,
        loc_txt = { name = v.name, text = v.text },
        atlas = 'hs_vouchers',
        pos = { x = idx % 8, y = math.floor(idx / 8) },
        config = v.config or {},
        requires = v.requires and { 'v_hs_' .. v.requires } or nil,
        cost = 10,
        unlocked = true,
        discovered = true,
        hs_id = v.hs_id,
        hs_text = v.text,
        hs_voucher = v,
        loc_vars = function(self, info_queue)
            for _, k in ipairs(tips) do info_queue[#info_queue + 1] = { set = 'Other', key = k } end
            return { vars = {} }
        end,
        redeem = function(self, card)
            if v.redeem then v.redeem(card) end
            HS.refresh_costs()
        end,
        calculate = v.calculate and function(self, card, context) return v.calculate(card, context) end or nil,
    })
end

-- 1/2 ----------------------------------------------------------------------
V { id = 'small_backpacks', name = 'Small Backpacks', hs_id = 'LOOTA_804',
    text = { '{C:attention}Passive:{} At the start of', 'each round, draw 2 cards' },
    calculate = function(card, context)
        if context.first_hand_drawn then HS.draw(2) end
    end }
V { id = 'rocket_backpacks', name = 'Rocket Backpacks', hs_id = 'DALA_731', requires = 'small_backpacks',
    text = { '{C:attention}Passive:{} Your minions', 'have {C:attention}Rush{}' } }

-- 3/4 ----------------------------------------------------------------------
V { id = 'vip_membership', name = 'VIP Membership', hs_id = 'ULDA_011',
    text = { '{C:attention}Passive:{} Taverns you visit', 'are upgraded: {C:attention}+1{} card', 'slot in the Tavern' },
    redeem = function() change_shop_size(1) end }
V { id = 'golden_candle', name = 'Golden Candle', hs_id = 'DALA_709', requires = 'vip_membership',
    text = { 'Whenever you Refresh, {C:green}1 in 4{}', 'chance a Tavern minion becomes', 'a random {C:red}Rare{} minion' },
    calculate = function(card, context)
        if context.reroll_shop and G.shop_jokers then
            local p = (G.GAME.probabilities and G.GAME.probabilities.normal) or 1
            if HS.rand('hs_candle') < p / 4 then
                local pool, targets = {}, {}
                for key, d in pairs(HS.defs) do if d.rarity == 3 and not d.token then pool[#pool + 1] = key end end
                table.sort(pool)
                for _, c in ipairs(G.shop_jokers.cards) do if HS.def(c) then targets[#targets + 1] = c end end
                local t, key = HS.pick(targets, 'hs_candle_t'), HS.pick(pool, 'hs_candle_k')
                if t and key then
                    t:set_ability(G.P_CENTERS[key])
                    t:set_cost()
                    HS.say(t, 'Golden!', G.C.GOLD)
                end
            end
        end
    end }

-- 5/6 ----------------------------------------------------------------------
V { id = 'emerald_goggles', name = 'Emerald Goggles', hs_id = 'DALA_733',
    text = { '{C:attention}Passive:{} The leftmost card', 'in the Tavern costs {C:money}$2{} less' } }
V { id = 'scrying_orb', name = "Khadgar's Scrying Orb", hs_id = 'LOOTA_824', requires = 'emerald_goggles',
    text = { '{C:attention}Passive:{} Your {C:attention}Spells{} cost', '{C:money}$2{} less in the Tavern' } }

-- 7/8 ----------------------------------------------------------------------
V { id = 'crystal_gem', name = 'Crystal Gem', hs_id = 'LOOTA_801',
    text = { '{C:attention}Passive:{} Start with an extra', 'Mana Crystal: {C:blue}+1{} Turn', 'each round' },
    redeem = function()
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + 1
        ease_hands_played(1)
    end }
V { id = 'arcanite_crystal', name = 'Arcanite Crystal', hs_id = 'PVPDR_BAR_Passive16', requires = 'crystal_gem',
    text = { '{C:attention}Passive:{} After you cast a', '{C:attention}Spell{}, the Tavern costs {C:money}$1{} less', '{C:inactive}(until you leave the Tavern){}' },
    calculate = function(card, context)
        if context.using_consumeable and HS.is_spell(context.consumeable.config.center) then
            local st = HS.state()
            st.shop_discount = st.shop_discount + 1
            HS.refresh_costs()
        end
    end }

-- 9/10 ---------------------------------------------------------------------
V { id = 'archmage_staff', name = 'Archmage Staff', hs_id = 'LOOTA_819',
    text = { 'At the start of each round,', 'add a random {C:attention}Spell{} to your hand' },
    calculate = function(card, context)
        if context.first_hand_drawn then HS.add_spell(nil, nil, function() return true end) end
    end }
V { id = 'orb_of_the_untold', name = 'Orb of the Untold', hs_id = 'DALA_712', requires = 'archmage_staff',
    text = { 'At the start of each {C:attention}Boss{}', 'Blind, deal {C:red}20{} damage to it' },
    calculate = function(card, context)
        if context.first_hand_drawn and HS.is_boss() then HS.damage_blind(20) end
    end }

-- 11/12 --------------------------------------------------------------------
V { id = 'map_golden_monkey', name = 'Map to the Golden Monkey', hs_id = 'LOE_019t',
    text = { 'Shuffle the {C:money}Golden Monkey{}', 'into your deck {C:inactive}(always scores,', '{C:inactive}earns $5 when scored){}' },
    redeem = function()
        SMODS.add_card({ set = 'Enhanced', enhancement = 'm_hs_golden_monkey', area = G.deck, skip_materialize = true })
    end }
V { id = 'elixir_of_vigor', name = 'Elixir of Vigor', hs_id = 'BAR_763t6', requires = 'map_golden_monkey',
    text = { 'Every card in your deck', 'permanently gains {C:chips}+10{} Chips' },
    redeem = function()
        for _, c in ipairs(G.playing_cards or {}) do
            c.ability.perma_bonus = (c.ability.perma_bonus or 0) + 10
        end
    end }

-- 13/14 --------------------------------------------------------------------
V { id = 'captured_flag', name = 'Captured Flag', hs_id = 'LOOTA_828',
    text = { '{C:attention}Passive:{} Your minions', 'have {C:attention}+1/+1{}' } }
V { id = 'boots_of_haste', name = 'Boots of Haste', hs_id = 'LOOTA_812', requires = 'captured_flag',
    text = { 'Your minions cost (0) this turn:', 'the first minion in each', 'Tavern is {C:money}free{}' },
    calculate = function(card, context)
        if context.starting_shop then HS.state().boots_used = false; HS.refresh_costs() end
        if context.buying_card and context.card and HS.def(context.card) then
            HS.state().boots_used = true
            HS.event(HS.refresh_costs)
        end
    end }

-- 15/16 --------------------------------------------------------------------
V { id = 'mysterious_tome', name = 'Mysterious Tome', hs_id = 'LOOTA_833',
    text = { 'At the start of each {C:attention}Boss{}', 'Blind, play a random {C:attention}Secret{}', '{C:inactive}(gain a random Secret){}' },
    calculate = function(card, context)
        if context.setting_blind and G.GAME.blind and G.GAME.blind.boss and add_tag and Tag and get_next_tag_key then
            add_tag(Tag(get_next_tag_key('hs_tome')))
        end
    end }
V { id = 'shifting_hourglass', name = 'Shifting Hourglass', hs_id = 'LOOTA_830', requires = 'mysterious_tome',
    text = { 'Take an extra turn:', '{C:blue}+1{} Turn each round' },
    redeem = function()
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + 1
        ease_hands_played(1)
    end }

-- 17/18 --------------------------------------------------------------------
V { id = 'robes_of_gaudiness', name = 'Robes of Gaudiness', hs_id = 'DALA_735',
    text = { '{C:attention}Passive:{} Everything in the', 'Tavern costs half, but you can', 'only buy {C:attention}2{} cards per Tavern' },
    redeem = function()
        G.GAME.discount_percent = math.max(G.GAME.discount_percent or 0, 50)
    end,
    calculate = function(card, context)
        if context.starting_shop then HS.state().robes_buys = 0 end
        if context.buying_card then
            local st = HS.state()
            st.robes_buys = (st.robes_buys or 0) + 1
        end
    end }
V { id = 'scepter_of_summoning', name = 'Scepter of Summoning', hs_id = 'LOOTA_803', requires = 'robes_of_gaudiness',
    text = { '{C:attention}Passive:{} Minions in the', 'Tavern cost at most {C:money}$5{}' } }

-- 19/20 --------------------------------------------------------------------
V { id = 'pristine_compass', name = 'Pristine Compass', hs_id = 'GILA_853b',
    text = { 'At the start of each round,', 'add a copy of a random card', 'in your hand to your hand' },
    calculate = function(card, context)
        if context.first_hand_drawn and G.hand and #G.hand.cards > 0 then
            HS.create_playing_card(HS.describe_card(HS.pick(G.hand.cards, 'hs_compass')), G.hand)
        end
    end }
V { id = 'magic_mirror', name = 'Magic Mirror', hs_id = 'KAR_A01_01', requires = 'pristine_compass',
    text = { 'Whenever you use a {C:attention}Location{},', 'create a copy of it', '{C:inactive}(copies can\'t be copied){}' },
    calculate = function(card, context)
        local c = context.using_consumeable and context.consumeable
        if c and c.ability and c.ability.set == 'Planet' and not c.ability.hs_mirrored then
            local copy = HS.add_spell(c.config.center.key)
            if copy then copy.ability.hs_mirrored = true end
        end
    end }

-- 21/22 --------------------------------------------------------------------
V { id = 'sack_of_coins', name = 'Sack of Coins', hs_id = 'GILA_816b',
    text = { '{C:attention}Summon{} a random 6-Cost', 'minion' },
    redeem = function() HS.summon_random(function(d) return d.mana == 6 end) end }
V { id = 'hefty_sack_of_coins', name = 'Hefty Sack of Coins', hs_id = 'GILA_816c', requires = 'sack_of_coins',
    text = { '{C:attention}Summon{} a random 3, 6,', 'and 9-Cost minion' },
    redeem = function()
        for _, m in ipairs({ 3, 6, 9 }) do HS.summon_random(function(d) return d.mana == m end) end
    end }

-- 23/24 --------------------------------------------------------------------
V { id = 'the_candle', name = "Waxadred's Candle", hs_id = 'DRG_036t',
    text = { 'Shuffle a {C:attention}Candle{} into your', 'deck: when drawn, {C:attention}summon{}', '{C:attention}Waxadred{}' },
    redeem = function() HS.add_candle() end }
V { id = 'wish', name = 'Wish', hs_id = 'LOOTA_814', requires = 'the_candle',
    text = { 'Fill your board with', '{C:legendary}Legendary{} minions. Fully', 'heal your hero' },
    redeem = function()
        while HS.board_space() > 0 do
            if not HS.summon_random(function(d) return d.rarity == 4 end) then break end
        end
        HS.heal_hero(HS.hero_max())
    end }

-- 25/26 --------------------------------------------------------------------
V { id = 'primordial_wand', name = 'Primordial Wand', hs_id = 'LOOTA_817',
    text = { 'At the start of each round,', '{C:attention}Adapt{} a random minion' },
    calculate = function(card, context)
        if context.first_hand_drawn and HS.adapt then
            local m = HS.pick(HS.minions(), 'hs_pwand')
            if m then HS.adapt(m) end
        end
    end }
V { id = 'wand_of_disintegration', name = 'Wand of Disintegration', hs_id = 'LOOTA_806', requires = 'primordial_wand',
    text = { '{C:attention}Silence{} every Boss Blind', '{C:inactive}(disable its ability){}' },
    calculate = function(card, context)
        if context.setting_blind and G.GAME.blind and G.GAME.blind.boss and not G.GAME.blind.disabled then
            G.GAME.blind:disable()
        end
    end }

-- 27/28 --------------------------------------------------------------------
V { id = 'potion_of_vitality', name = 'Potion of Vitality', hs_id = 'LOOTA_800',
    text = { '{C:attention}Passive:{} Double your Health:', 'healing raises money up to', '{C:money}$60{}. Gain {C:money}$10{} now' },
    redeem = function() ease_dollars(10) end }
V { id = 'princes_ring', name = "A Prince's Ring", hs_id = 'DALA_738', requires = 'potion_of_vitality',
    text = { '{C:attention}Passive:{} {C:attention}+1{} Hand Size' },
    redeem = function() G.hand:change_size(1) end }

-- 29/30 --------------------------------------------------------------------
V { id = 'justicars_ring', name = "Justicar's Ring", hs_id = 'LOOTA_802',
    text = { '{C:attention}Passive:{} {C:red}+1{} Mulligan', 'each round' },
    redeem = function()
        G.GAME.round_resets.discards = G.GAME.round_resets.discards + 1
        ease_discard(1)
    end }
V { id = 'time_warp', name = 'Time Warp', hs_id = 'UNG_028t', requires = 'justicars_ring',
    text = { 'Once per round, if your last', 'turn would lose, take an', 'extra turn {C:inactive}(+1 Turn){}' },
    calculate = function(card, context)
        if context.setting_blind then HS.state().time_warped = false end
        if context.after and G.GAME.current_round.hands_left == 0 and not HS.state().time_warped then
            local total = (G.GAME.chips or 0) + (SMODS.last_hand_score or 0)
            if total < G.GAME.blind.chips then
                HS.state().time_warped = true
                ease_hands_played(1)
                return { message = 'Time Warp!', colour = G.C.BLUE }
            end
        end
    end }

-- 31/32 --------------------------------------------------------------------
V { id = 'glyph_of_warding', name = 'Glyph of Warding', hs_id = 'LOOTA_831',
    text = { '{C:attention}Passive:{} Enemy minions cost', 'more: Boss attacks deal', '{C:attention}2{} less damage' } }
V { id = 'cloak_of_invisibility', name = 'Cloak of Invisibility', hs_id = 'LOOTA_832', requires = 'glyph_of_warding',
    text = { '{C:attention}Passive:{} Your minions have', 'permanent {C:attention}Stealth{}', '{C:inactive}(the Boss can\'t attack them){}' } }

-- Robes of Gaudiness: block buying once the limit is reached
if G and G.FUNCS and G.FUNCS.can_buy then
    local orig_can_buy = G.FUNCS.can_buy
    G.FUNCS.can_buy = function(e)
        orig_can_buy(e)
        if HS.voucher('robes_of_gaudiness') and (HS.state().robes_buys or 0) >= 2 then
            e.config.colour = G.C.UI.BACKGROUND_INACTIVE
            e.config.button = nil
        end
    end
end

return HS.voucher_defs
