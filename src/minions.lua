-- Balathstone Minions
-- Every minion is declared once here; timing rules live in src/core.lua.
-- Text is what the player sees (tooltip AND the text printed on the card art).
-- Conventions: "the minion to its right" replaces Hearthstone's targeted
-- friendly effects; "the Blind" is the enemy hero; "your hero" is your money.
local HS = Balathstone or Balearthstone
local M = HS.minion
local E = HS.E

local BC = '{C:attention}Battlecry:{} '
local DR = '{C:attention}Deathrattle:{} '
local SOG = '{C:attention}Start of Game:{} '

local function blind_dmg(n) return function(card) HS.damage_blind(n, card) end end
local function draw(n) return function(card) HS.draw(n, card) end end
local function summon(id, n) return function(card) for _ = 1, n or 1 do HS.summon(id, card) end end end

-- =========================================================================
-- LEGENDARY
-- =========================================================================
M { id = 'zephrys_the_great', name = 'Zephrys the Great', hs_id = 'ULD_003', atk = 3, hp = 2, mana = 2,
    rarity = 4, tribe = 'Elemental',
    text = { BC .. 'If your deck has no', 'duplicates, wish for the perfect card:',
        'a {C:dark_edition}Negative{} {C:attention}Location{} for your hand' },
    battlecry = function(card)
        if HS.deck_has_duplicates() then HS.say(card, 'Duplicates!', G.C.RED); return end
        local best, plays = 'High Card', -1
        for name, h in pairs(G.GAME.hands or {}) do
            if h.visible ~= false and (h.played or 0) > plays then best, plays = name, h.played or 0 end
        end
        local key = HS.location_for_hand and HS.location_for_hand[best]
        if key then
            local c = SMODS.add_card({ set = 'Planet', key = key, area = G.consumeables, edition = 'e_negative', key_append = 'hs_zephrys' })
            if c then
                c:set_edition({ negative = true }, true)
                HS.say(card, 'Wish Granted!', G.C.GOLD)
            end
        end
    end }

M { id = 'shudderwock', name = 'Shudderwock', hs_id = 'GIL_820', atk = 6, hp = 6, mana = 9, rarity = 4,
    text = { BC .. 'Repeat the {C:attention}Battlecries{}', 'of all your other minions' },
    battlecry = function(card)
        for _, o in ipairs(HS.others(card)) do
            if HS.def(o).battlecry and o.config.center.key ~= card.config.center.key then
                HS.run_battlecry(o, 1)
            end
        end
    end }

M { id = 'astalor_bloodsworn', name = 'Astalor Bloodsworn', hs_id = 'RLK_222', atk = 2, hp = 2, mana = 2,
    rarity = 4,
    text = { BC .. 'Deal {C:red}2{} damage to the Blind.', '{C:attention}Manathirst (5):{} Deal {C:red}8{} instead' },
    battlecry = function(card) HS.damage_blind(HS.mana() >= 5 and 8 or 2, card) end }

M { id = 'sire_denathrius', name = 'Sire Denathrius', hs_id = 'REV_906', atk = 10, hp = 10, mana = 10,
    rarity = 4, kw = { 'lifesteal' }, extra = { infused = 0 },
    text = { '{C:attention}Lifesteal{}. ' .. BC .. 'Deal {C:red}#1#{} damage', 'to the Blind. {C:attention}Endlessly Infuse (2):{}',
        'Deal 1 more and gain {X:mult,C:white}+X0.1{} Mult {C:inactive}(X#2#){}' },
    vars = function(card)
        local e = card and E(card)
        local inf = math.floor(((e and e.infused) or 0) / 2)
        local xm = 1 + inf * 0.1
        return { 5 + inf, string.format('%.1f', xm) }
    end,
    battlecry = function(card)
        local inf = math.floor(E(card).infused / 2)
        local n = 5 + inf
        HS.damage_blind(n, card)
        HS.heal_hero(n)
    end,
    score = function(card, context)
        local inf = math.floor(E(card).infused / 2)
        if inf > 0 then
            local xm = 1 + inf * 0.1
            return { Xmult = xm }
        end
    end,
    on_death = function(card) E(card).infused = E(card).infused + 1 end }

M { id = 'prince_renathal', name = 'Prince Renathal', hs_id = 'CORE_REV_018', atk = 3, hp = 4, mana = 3,
    rarity = 4,
    text = { 'Your deck size and Health are 40:', '{C:attention}+1{} hand size and', '{C:blue}+1{} Hand each round' },
    on_add = function(card)
        if G.hand then G.hand:change_size(1) end
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + 1
        ease_hands_played(1)
    end,
    on_remove = function(card)
        if G.hand then G.hand:change_size(-1) end
        G.GAME.round_resets.hands = G.GAME.round_resets.hands - 1
        -- never take away your last Hand mid-round (that would soft-lock the round)
        local cr = G.GAME.current_round
        if not (HS.in_round() and cr and (cr.hands_left or 0) <= 1) then ease_hands_played(-1) end
    end }

-- =========================================================================
-- RARE
-- =========================================================================
M { id = 'baron_rivendare', name = 'Baron Rivendare', hs_id = 'FP1_031', atk = 1, hp = 7, mana = 4,
    rarity = 3, tribe = 'Undead',
    text = { 'Your minions trigger their', '{C:attention}Deathrattles{} twice' } }

M { id = 'edwin_vancleef', name = 'Edwin VanCleef', hs_id = 'VAN_EX1_613', atk = 2, hp = 2, mana = 3, rarity = 3,
    text = { '{C:attention}Combo:{} When you take a turn,', 'gain {C:attention}+2/+2{} for each Spell or',
        'Discard used earlier this turn' },
    on_play = function(card, n) if n > 0 then HS.buff(card, 2 * n, 2 * n) end end }

M { id = 'archmage_antonidas', name = 'Archmage Antonidas', hs_id = 'VAN_EX1_559', atk = 5, hp = 7, mana = 7,
    rarity = 3,
    text = { 'Whenever you cast a {C:attention}Spell{},', 'add a {C:attention}Fireball{} to your hand',
        '{C:inactive}(not from Fireball itself)' },
    on_spell = function(card, center)
        if center.key ~= 'c_hs_fireball' then HS.add_spell('fireball', card) end
    end }

M { id = 'sylvanas_windrunner', name = 'Sylvanas Windrunner', hs_id = 'VAN_EX1_016', atk = 5, hp = 5, mana = 6,
    rarity = 3,
    text = { DR .. 'Mind control a random minion', 'from the Tavern, adding it', 'as {C:dark_edition}Negative{} {C:inactive}(+1 Minion slot){}' },
    deathrattle = function(card)
        if not HS.steal_from_shop(card, true) then
            local st = HS.state()
            st.sylvanas_steals = (st.sylvanas_steals or 0) + 1
        end
    end }

M { id = 'reno_jackson', name = 'Reno Jackson', hs_id = 'LOE_011', atk = 4, hp = 6, mana = 6, rarity = 3,
    text = { BC .. 'If your deck has no', 'duplicates, fully heal your hero', '{C:inactive}(raise your money to {C:money}$30{C:inactive}){}' },
    battlecry = function(card)
        if HS.deck_has_duplicates() then HS.say(card, 'Duplicates!', G.C.RED); return end
        HS.heal_hero(HS.hero_max(), card)
    end }

M { id = 'kelthuzad', name = "Kel'Thuzad", hs_id = 'FP1_013', atk = 6, hp = 8, mana = 8, rarity = 3,
    tribe = 'Undead',
    text = { 'At the end of each turn, summon', 'all friendly minions that', 'died this turn' } }

M { id = 'zilliax', name = 'Zilliax', hs_id = 'CORE_BOT_548', atk = 3, hp = 2, mana = 5, rarity = 3,
    tribe = 'Mech', kw = { 'divine_shield', 'taunt', 'lifesteal', 'rush' },
    text = { '{C:attention}Divine Shield, Taunt, Lifesteal, Rush{}.', '{C:attention}Magnetic:{} Gives {X:mult,C:white}X1.5{} Mult for each', '{C:attention}Steel Card{} held in your hand' },
    score = function(card, context)
        local steels = 0
        for _, c in ipairs((G.hand and G.hand.cards) or {}) do
            if c.ability and (c.ability.name == 'Steel Card' or c.ability.effect == 'Steel Card') then steels = steels + 1 end
        end
        if steels > 0 then
            local xm = 1.5 ^ steels
            return { Xmult = xm }
        end
    end }

M { id = 'grim_patron', name = 'Grim Patron', hs_id = 'BRM_019', atk = 3, hp = 3, mana = 5, rarity = 3,
    text = { 'After this minion survives', 'damage, {C:attention}summon{} another', '{C:attention}Grim Patron{}' },
    on_survive = function(card) HS.summon('grim_patron', card) end }

M { id = 'emperor_thaurissan', name = 'Emperor Thaurissan', hs_id = 'WON_133', atk = 4, hp = 4, mana = 5,
    rarity = 3,
    text = { 'At the end of your turn, the', 'next Tavern costs {C:money}$1{} less', '{C:inactive}(stacks, on every item){}' },
    end_turn = function(card)
        local st = HS.state()
        st.shop_discount = st.shop_discount + 1
        HS.say(card, '-$1 next Tavern', G.C.MONEY)
    end }

M { id = 'loatheb', name = 'Loatheb', hs_id = 'FP1_030', atk = 5, hp = 5, mana = 5, rarity = 3, tribe = 'Undead',
    text = { BC .. 'Enemy spells cost (5) more:', 'the {C:attention}Blind{} can\'t attack this round' },
    battlecry = function(card)
        if HS.enemy() then
            HS.state().boss_disarmed = true
            HS.say(card, 'Spores!', G.C.GREEN)
        end
    end }

M { id = 'leeroy_jenkins', name = 'Leeroy Jenkins', hs_id = 'VAN_EX1_116', atk = 6, hp = 2, mana = 4,
    rarity = 3, kw = { 'charge' },
    text = { '{C:attention}Charge{}. Gives {X:mult,C:white}X2{} Mult on the', '{C:attention}first turn{} of each round.', BC .. 'Heal the Blind for 2' },
    battlecry = function(card) HS.heal_blind(2, card) end,
    score = function(card, context)
        if HS.state().hand_index <= 1 then
            return { Xmult = 2 }
        end
    end }

M { id = 'dr_boom', name = 'Dr. Boom', hs_id = 'CORE_GVG_110', atk = 7, hp = 7, mana = 7, rarity = 3,
    text = { BC .. 'Summon two 1/1', '{C:attention}Boom Bots{}. WARNING:', 'Bots may explode' },
    battlecry = summon('boom_bot', 2) }

M { id = 'tirion_fordring', name = 'Tirion Fordring', hs_id = 'VAN_EX1_383', atk = 6, hp = 6, mana = 8,
    rarity = 3, kw = { 'divine_shield', 'taunt' },
    text = { '{C:attention}Divine Shield, Taunt{}. ' .. DR .. 'Give', 'all your other minions {C:mult}+5{}', 'Attack permanently' },
    deathrattle = function(card)
        for _, m in ipairs(HS.others(card)) do HS.buff(m, 5, 0) end
        HS.say(card, '+5 Attack!', G.C.MULT)
    end }

M { id = 'harrison_jones', name = 'Harrison Jones', hs_id = 'VAN_EX1_558', atk = 5, hp = 4, mana = 5,
    rarity = 3,
    text = { BC .. 'Halve the {C:attention}Blind\'s{} Attack this', 'round and draw 2 cards' },
    battlecry = function(card)
        if HS.enemy() then
            HS.state().boss_half = true
            HS.draw(2, card)
        end
    end }

M { id = 'yogg_saron_hopes_end', name = "Yogg-Saron, Hope's End", hs_id = 'OG_134', atk = 7, hp = 5, mana = 10,
    rarity = 3,
    text = { BC .. 'Cast a random {C:attention}Spell{} for', 'each Spell you\'ve cast this run',
        '{C:inactive}(max 10, currently #1#){}' },
    vars = function() return { (G.GAME and G.GAME.hs and G.GAME.hs.spells_cast) or 0 } end,
    battlecry = function(card)
        local n = math.min(10, HS.state().spells_cast)
        for _ = 1, n do if HS.cast_random_spell then HS.cast_random_spell(card) end end
    end }

M { id = 'brann_bronzebeard', name = 'Brann Bronzebeard', hs_id = 'LOE_077', atk = 2, hp = 4, mana = 3,
    rarity = 3,
    text = { 'Your {C:attention}Battlecries{} trigger twice' } }

M { id = 'prince_keleseth', name = 'Prince Keleseth', hs_id = 'CORE_ICC_851', atk = 2, hp = 2, mana = 2,
    rarity = 3, tribe = 'Undead',
    text = { BC .. 'If your deck has no 2s,', 'give every card in your deck', '{C:chips}+3{} Chips permanently' },
    battlecry = function(card)
        if not HS.deck_all(function(c) return HS.rank_num(c) ~= 2 end) then
            HS.say(card, 'Deck has a 2', G.C.RED); return
        end
        for _, c in ipairs(G.playing_cards or {}) do
            c.ability.perma_bonus = (c.ability.perma_bonus or 0) + 3
        end
        HS.say(card, 'Deck +3 Chips!', G.C.CHIPS)
    end }

M { id = 'sunkeeper_tarim', name = 'Sunkeeper Tarim', hs_id = 'UNG_015', atk = 3, hp = 7, mana = 6, rarity = 3,
    kw = { 'taunt' },
    text = { '{C:attention}Taunt{}. ' .. BC .. 'Set all other', 'minions\' stats to 3/3. Gives', '{X:mult,C:white}X1.5{} Mult for each other 3/3' },
    battlecry = function(card)
        for _, o in ipairs(HS.others(card)) do HS.set_stats(o, 3, 3) end
    end,
    score = function(card, context)
        local count = 0
        for _, o in ipairs(HS.others(card)) do
            if HS.attack(o) == 3 and HS.health(o) == 3 then count = count + 1 end
        end
        if count > 0 then
            local xm = 1.5 ^ count
            return { Xmult = xm }
        end
    end }

M { id = 'theotar_the_mad_duke', name = 'Theotar, the Mad Duke', hs_id = 'CORE_REV_238', atk = 4, hp = 4,
    mana = 6, rarity = 3,
    text = { BC .. 'Swap your lowest card in', 'hand for a {C:attention}J, Q, K or A{} from', 'the enemy\'s hand' },
    battlecry = function(card)
        if not (G.hand and #G.hand.cards > 0) then return end
        local low
        for _, c in ipairs(G.hand.cards) do
            if not low or HS.rank_num(c) < HS.rank_num(low) then low = c end
        end
        local rank = HS.pick({ 'Jack', 'Queen', 'King', 'Ace' }, 'hs_theotar')
        if low and SMODS.change_base then
            SMODS.change_base(low, nil, rank)
            HS.say(low, 'Swapped!', G.C.PURPLE)
        end
    end }

M { id = 'baku_the_mooneater', name = 'Baku the Mooneater', hs_id = 'CORE_GIL_826', atk = 7, hp = 8, mana = 9,
    rarity = 3, tribe = 'Beast',
    text = { SOG .. 'If your deck has only odd', 'cards {C:inactive}(A=1, J=11, K=13){}, each', 'turn gives {X:mult,C:white}X2.5{} Mult' },
    score = function(card, context)
        if HS.deck_all(function(c) return HS.rank_num(c) % 2 == 1 end) then
            return { Xmult = 2.5 }
        end
    end }

M { id = 'genn_greymane', name = 'Genn Greymane', hs_id = 'CORE_GIL_692', atk = 6, hp = 5, mana = 6, rarity = 3,
    text = { SOG .. 'If your deck has only even', 'cards {C:inactive}(Q=12){}, each', 'turn gives {X:mult,C:white}X2.5{} Mult' },
    score = function(card, context)
        if HS.deck_all(function(c) return HS.rank_num(c) % 2 == 0 end) then
            return { Xmult = 2.5 }
        end
    end }

M { id = 'mutanus_the_devourer', name = 'Mutanus the Devourer', hs_id = 'WC_030', atk = 4, hp = 4, mana = 7,
    rarity = 3, tribe = 'Murloc',
    text = { BC .. 'Eat a random card in', 'your hand. Gain {C:attention}+1{} Attack and', 'Health equal to its Chips' },
    battlecry = function(card)
        if not (G.hand and #G.hand.cards > 0) then return end
        local victim = HS.pick(G.hand.cards, 'hs_mutanus')
        local chips = (victim.base and victim.base.nominal) or 0
        HS.buff(card, 1, chips)
        if SMODS.destroy_cards then SMODS.destroy_cards({ victim }) end
    end }

M { id = 'whizbang_the_wonderful', name = 'Whizbang the Wonderful', hs_id = 'BOT_914', atk = 4, hp = 5,
    mana = 4, rarity = 3,
    text = { SOG .. 'Add a random', 'enhanced card to your hand', '{C:inactive}(a Wonderful Deck!){}' },
    start_of_game = function(card)
        if not (G.hand and SMODS.add_card) then return end
        SMODS.add_card({ set = 'Enhanced', area = G.hand, key_append = 'hs_whizbang' })
        HS.say(card, 'Wonderful!', G.C.PURPLE)
    end }

M { id = 'carnivorous_cube', name = 'Carnivorous Cube', hs_id = 'LOOT_161', atk = 4, hp = 6, mana = 5,
    rarity = 3, extra = { eaten = {} },
    text = { BC .. 'Eat the highest card in', 'your hand. ' .. DR .. 'Add 2', 'copies of each eaten card to your deck' },
    vars = function(card)
        local e = card and E(card)
        return { e and e.eaten and #e.eaten or 0 }
    end,
    battlecry = function(card)
        local high = HS.highest_in_hand()
        if not high then return end
        local e = E(card)
        e.eaten[#e.eaten + 1] = HS.describe_card(high)
        HS.destroy_cards({ high })
        HS.say(card, 'Om nom!', G.C.RED)
    end,
    deathrattle = function(card)
        for _, desc in ipairs(E(card).eaten) do
            HS.create_playing_card(desc, G.deck); HS.create_playing_card(desc, G.deck)
        end
        HS.say(card, '+' .. (2 * #E(card).eaten) .. ' cards', G.C.GREEN)
    end }

M { id = 'mechathun', name = "Mecha'thun", hs_id = 'BOT_424', atk = 10, hp = 10, mana = 10, rarity = 3,
    tribe = 'Mech',
    text = { DR .. 'If your deck and', 'hand are empty and you have no', 'other minions, win the round' },
    deathrattle = function(card)
        if HS.in_round() and #G.deck.cards == 0 and #G.hand.cards == 0 and #HS.others(card) == 0 then
            HS.win_blind(card)
        end
    end }

-- =========================================================================
-- UNCOMMON
-- =========================================================================
M { id = 'knife_juggler', name = 'Knife Juggler', hs_id = 'VAN_NEW1_019', atk = 3, hp = 2, mana = 2, rarity = 2,
    text = { 'After you {C:attention}summon{} a minion,', 'deal {C:red}1{} damage to the Blind' },
    on_summon = function(card, new) if new ~= card then HS.damage_blind(1, card) end end }

M { id = 'flamewaker', name = 'Flamewaker', hs_id = 'BRM_002', atk = 2, hp = 4, mana = 3, rarity = 2,
    text = { 'After you cast a {C:attention}Spell{},', 'deal {C:red}2{} damage to the Blind' },
    on_spell = function(card) HS.damage_blind(2, card) end }

M { id = 'sludge_belcher', name = 'Sludge Belcher', hs_id = 'WON_128', atk = 3, hp = 6, mana = 5, rarity = 2,
    tribe = 'Undead', kw = { 'taunt' },
    text = { '{C:attention}Taunt{}. ' .. DR .. 'Summon a', '1/2 {C:attention}Slime{} with {C:attention}Taunt{}' },
    deathrattle = summon('putrid_slime') }

M { id = 'piloted_shredder', name = 'Piloted Shredder', hs_id = 'GVG_096', atk = 4, hp = 3, mana = 4, rarity = 2,
    tribe = 'Mech',
    text = { DR .. 'Summon a random', '2-Cost minion' },
    deathrattle = function(card) HS.summon_random(function(d) return d.mana == 2 end, card) end }

M { id = 'acolyte_of_pain', name = 'Acolyte of Pain', hs_id = 'WON_357', atk = 1, hp = 4, mana = 3, rarity = 2,
    text = { 'Whenever this minion takes', 'damage, draw a card' },
    on_damaged = function(card) HS.draw(1, card) end }

M { id = 'doomsayer', name = 'Doomsayer', hs_id = 'VAN_NEW1_021', atk = 0, hp = 7, mana = 2, rarity = 2,
    text = { 'At the start of your turn,', 'destroy {C:red}ALL{} minions' },
    start_turn = function(card)
        for _, o in ipairs(HS.minions()) do HS.kill(o, 'destroy') end
    end }

M { id = 'bloodmage_thalnos', name = 'Bloodmage Thalnos', hs_id = 'VAN_EX1_012', atk = 1, hp = 1, mana = 2,
    rarity = 2, spell_damage = 1,
    text = { '{C:attention}Spell Damage +1{}', DR .. 'Draw a card' },
    deathrattle = draw(1) }

M { id = 'frothing_berserker', name = 'Frothing Berserker', hs_id = 'VAN_EX1_604', atk = 2, hp = 4, mana = 3,
    rarity = 2,
    text = { 'Whenever a minion takes damage,', 'gain {C:mult}+1{} Attack' },
    on_damaged = function(card) HS.buff(card, 1, 0) end,
    on_any_damaged = function(card) HS.buff(card, 1, 0) end }

M { id = 'gadgetzan_auctioneer', name = 'Gadgetzan Auctioneer', hs_id = 'VAN_EX1_095', atk = 4, hp = 4,
    mana = 5, rarity = 2,
    text = { 'Whenever you cast a {C:attention}Spell{},', 'draw a card' },
    on_spell = function(card) HS.draw(1, card) end }

M { id = 'cairne_bloodhoof', name = 'Cairne Bloodhoof', hs_id = 'VAN_EX1_110', atk = 4, hp = 5, mana = 6,
    rarity = 2,
    text = { DR .. 'Summon', '{C:attention}Baine Bloodhoof{}' },
    deathrattle = summon('baine_bloodhoof') }

M { id = 'murloc_warleader', name = 'Murloc Warleader', hs_id = 'VAN_EX1_507', atk = 3, hp = 3, mana = 3,
    rarity = 2, tribe = 'Murloc',
    text = { 'Your other {C:attention}Murlocs{} have', '{C:attention}+2/+1{}' },
    aura = function(src, t) if HS.is_tribe(t, 'Murloc') then return 2, 1 end end }

M { id = 'southsea_captain', name = 'Southsea Captain', hs_id = 'VAN_NEW1_027', atk = 3, hp = 3, mana = 3,
    rarity = 2, tribe = 'Pirate',
    text = { 'Your other {C:attention}Pirates{} have', '{C:attention}+1/+1{}' },
    aura = function(src, t) if HS.is_tribe(t, 'Pirate') then return 1, 1 end end }

M { id = 'cult_master', name = 'Cult Master', hs_id = 'VAN_EX1_595', atk = 4, hp = 2, mana = 4, rarity = 2,
    text = { 'After a friendly minion dies,', 'draw a card' },
    on_death = function(card) HS.draw(1, card) end }

M { id = 'defender_of_argus', name = 'Defender of Argus', hs_id = 'VAN_EX1_093', atk = 2, hp = 3, mana = 4,
    rarity = 2,
    text = { BC .. 'Give adjacent minions', '{C:attention}+1/+1{} and {C:attention}Taunt{}' },
    battlecry = function(card)
        for _, o in ipairs(HS.adjacent(card)) do HS.buff(o, 1, 1); HS.give(o, 'taunt') end
    end }

M { id = 'sunfury_protector', name = 'Sunfury Protector', hs_id = 'VAN_EX1_058', atk = 2, hp = 3, mana = 2,
    rarity = 2,
    text = { BC .. 'Give adjacent', 'minions {C:attention}Taunt{}' },
    battlecry = function(card)
        for _, o in ipairs(HS.adjacent(card)) do HS.give(o, 'taunt'); HS.say(o, 'Taunt!', G.C.FILTER) end
    end }

local function adjacent_aura(n)
    return function(src, t)
        for _, a in ipairs(HS.adjacent(src)) do if a == t then return n, 0 end end
    end
end

M { id = 'dire_wolf_alpha', name = 'Dire Wolf Alpha', hs_id = 'VAN_EX1_162', atk = 2, hp = 2, mana = 2,
    rarity = 2, tribe = 'Beast',
    text = { 'Adjacent minions have', '{C:mult}+1{} Attack' },
    aura = adjacent_aura(1) }

M { id = 'flametongue_totem', name = 'Flametongue Totem', hs_id = 'VAN_EX1_565', atk = 0, hp = 3, mana = 2,
    rarity = 2, tribe = 'Totem',
    text = { 'Adjacent minions have', '{C:mult}+2{} Attack' },
    aura = adjacent_aura(2) }

M { id = 'sorcerers_apprentice', name = "Sorcerer's Apprentice", hs_id = 'VAN_EX1_608', atk = 3, hp = 2,
    mana = 2, rarity = 2,
    text = { 'Your {C:attention}Spells{} cost {C:money}$1{} less', 'in the Tavern' },
    discount = function(src, c)
        local set = c.ability and c.ability.set
        if set == 'Tarot' or set == 'Spectral' then return 1 end
    end }

M { id = 'mana_wyrm', name = 'Mana Wyrm', hs_id = 'WON_031', atk = 1, hp = 3, mana = 1, rarity = 2,
    text = { 'Whenever you cast a {C:attention}Spell{},', 'gain {C:mult}+1{} Attack' },
    on_spell = function(card) HS.buff(card, 1, 0) end }

M { id = 'mechwarper', name = 'Mechwarper', hs_id = 'GVG_006', atk = 4, hp = 4, mana = 4, rarity = 2,
    tribe = 'Mech',
    text = { 'Your {C:attention}Mechs{} cost {C:money}$1{} less', 'in the Tavern' },
    discount = function(src, c) if HS.is_tribe(c, 'Mech') then return 1 end end }

M { id = 'scavenging_hyena', name = 'Scavenging Hyena', hs_id = 'VAN_EX1_531', atk = 2, hp = 2, mana = 2,
    rarity = 2, tribe = 'Beast',
    text = { 'Whenever a friendly {C:attention}Beast{}', 'dies, gain {C:attention}+2/+1{}' },
    on_death = function(card, dead) if HS.is_tribe(dead, 'Beast') then HS.buff(card, 2, 1) end end }

M { id = 'wild_pyromancer', name = 'Wild Pyromancer', hs_id = 'VAN_NEW1_020', atk = 3, hp = 2, mana = 2,
    rarity = 2,
    text = { 'After you cast a {C:attention}Spell{}, deal', '1 damage to {C:red}ALL{} your minions' },
    on_spell = function(card)
        for _, o in ipairs(HS.minions()) do HS.damage(o, 1, card) end
    end }

M { id = 'shielded_minibot', name = 'Shielded Minibot', hs_id = 'GVG_058', atk = 2, hp = 2, mana = 2,
    rarity = 2, tribe = 'Mech', kw = { 'divine_shield' },
    text = { '{C:attention}Divine Shield{}' } }

M { id = 'twilight_drake', name = 'Twilight Drake', hs_id = 'VAN_EX1_043', atk = 4, hp = 1, mana = 4,
    rarity = 2, tribe = 'Dragon',
    text = { BC .. 'Gain {C:chips}+1{} Health for', 'each card in your hand' },
    battlecry = function(card) HS.buff(card, 0, G.hand and #G.hand.cards or 0) end }

M { id = 'dark_iron_dwarf', name = 'Dark Iron Dwarf', hs_id = 'VAN_EX1_046', atk = 4, hp = 4, mana = 4,
    rarity = 2,
    text = { BC .. 'Give the minion to its', 'right {C:mult}+2{} Attack this turn' },
    battlecry = function(card)
        local r = HS.right(card)
        if r then HS.buff(r, 2, 0, 'turn') end
    end }

M { id = 'houndmaster', name = 'Houndmaster', hs_id = 'VAN_DS1_070', atk = 4, hp = 3, mana = 4, rarity = 2,
    text = { BC .. 'Give the {C:attention}Beast{} to its', 'right {C:attention}+2/+2{} and {C:attention}Taunt{}' },
    battlecry = function(card)
        local r = HS.right(card)
        if r and HS.is_tribe(r, 'Beast') then HS.buff(r, 2, 2); HS.give(r, 'taunt') end
    end }

M { id = 'si7_agent', name = 'SI:7 Agent', hs_id = 'VAN_EX1_134', atk = 3, hp = 3, mana = 3, rarity = 2,
    text = { '{C:attention}Combo:{} When you take a turn,', 'deal {C:red}2{} damage to the Blind' },
    on_play = function(card, n) if n > 0 then HS.damage_blind(2, card) end end }

M { id = 'azure_drake', name = 'Azure Drake', hs_id = 'VAN_EX1_284', atk = 4, hp = 4, mana = 5, rarity = 2,
    tribe = 'Dragon', spell_damage = 1,
    text = { '{C:attention}Spell Damage +1{}', BC .. 'Draw a card' },
    battlecry = draw(1) }

M { id = 'kezan_mystic', name = 'Kezan Mystic', hs_id = 'GVG_074', atk = 4, hp = 3, mana = 4, rarity = 2,
    text = { BC .. 'Take control of the', 'Blind\'s {C:attention}Secret{} {C:inactive}(gain the Secret', '{C:inactive}for skipping this Blind){}' },
    battlecry = function(card)
        if not HS.in_round() or HS.is_boss() then return end
        local which = G.GAME.blind_on_deck
        local tag = which and G.GAME.round_resets.blind_tags and G.GAME.round_resets.blind_tags[which]
        if tag and add_tag and Tag then
            add_tag(Tag(tag, false, which))
            HS.say(card, 'Secret stolen!', G.C.PURPLE)
        end
    end }

M { id = 'spellbreaker', name = 'Spellbreaker', hs_id = 'VAN_EX1_048', atk = 4, hp = 3, mana = 4, rarity = 3,
    text = { BC .. '{C:attention}Silence{} the Blind', '{C:inactive}(disable its ability){}' },
    battlecry = function(card) HS.silence_boss(card) end }

M { id = 'big_game_hunter', name = 'Big Game Hunter', hs_id = 'VAN_EX1_005', atk = 4, hp = 2, mana = 3,
    rarity = 2,
    text = { BC .. 'If the Blind has {C:attention}7+{}', 'Attack, disarm it {C:inactive}(it can\'t', 'attack this round){}' },
    battlecry = function(card)
        if HS.enemy() and HS.boss_attack_value() >= 7 then
            HS.state().boss_disarmed = true
            HS.say(card, 'Big game!', G.C.RED)
        end
    end }

M { id = 'faceless_manipulator', name = 'Faceless Manipulator', hs_id = 'VAN_EX1_564', atk = 3, hp = 3,
    mana = 5, rarity = 2,
    text = { BC .. 'Become a copy of the', 'minion to its right' },
    battlecry = function(card)
        local r = HS.right(card)
        if not r then return end
        local summoned = E(card).summoned
        card:set_ability(r.config.center, nil, true)
        card.ability.extra = copy_table(r.ability.extra)
        card.ability.extra.summoned = summoned
        if card.set_cost then card:set_cost() end
        HS.say(card, 'Copied!', G.C.PURPLE)
    end }

M { id = 'water_elemental', name = 'Water Elemental', hs_id = 'VAN_CS2_033', atk = 3, hp = 6, mana = 4,
    rarity = 2, tribe = 'Elemental',
    text = { '{C:attention}Freeze{} any character', 'damaged by this minion', '{C:inactive}(the Blind skips its next attack){}' },
    after_attack = function(card) if HS.enemy() then HS.freeze_boss(card) end end }

M { id = 'armorsmith', name = 'Armorsmith', hs_id = 'VAN_EX1_402', atk = 1, hp = 4, mana = 2, rarity = 2,
    text = { 'Whenever a friendly minion', 'takes damage, gain 1 {C:attention}Armor{}' },
    on_damaged = function(card) HS.armor(1, card) end,
    on_any_damaged = function(card) HS.armor(1, card) end }

M { id = 'cruel_taskmaster', name = 'Cruel Taskmaster', hs_id = 'VAN_EX1_603', atk = 2, hp = 2, mana = 2,
    rarity = 2,
    text = { BC .. 'Deal 1 damage to the', 'minion to its right and give', 'it {C:mult}+2{} Attack' },
    battlecry = function(card)
        local r = HS.right(card)
        if r then HS.damage(r, 1, card); HS.buff(r, 2, 0) end
    end }

M { id = 'amani_berserker', name = 'Amani Berserker', hs_id = 'VAN_EX1_393', atk = 2, hp = 3, mana = 2,
    rarity = 2, enrage = { atk = 3 },
    text = { '{C:attention}Enrage:{} {C:mult}+3{} Attack' } }

M { id = 'raging_worgen', name = 'Raging Worgen', hs_id = 'VAN_EX1_412', atk = 3, hp = 3, mana = 3, rarity = 2,
    enrage = { atk = 1, windfury = true },
    text = { '{C:attention}Enrage: Windfury{} and', '{C:mult}+1{} Attack' } }

M { id = 'jungle_panther', name = 'Jungle Panther', hs_id = 'VAN_EX1_017', atk = 4, hp = 2, mana = 3,
    rarity = 2, tribe = 'Beast', kw = { 'stealth' },
    text = { '{C:attention}Stealth{}' } }

M { id = 'stranglethorn_tiger', name = 'Stranglethorn Tiger', hs_id = 'VAN_EX1_028', atk = 5, hp = 5, mana = 5,
    rarity = 2, tribe = 'Beast', kw = { 'stealth' },
    text = { '{C:attention}Stealth{}' } }

M { id = 'tundra_rhino', name = 'Tundra Rhino', hs_id = 'VAN_DS1_178', atk = 2, hp = 5, mana = 5, rarity = 2,
    tribe = 'Beast',
    text = { 'Your {C:attention}Beasts{} have {C:attention}Charge{}' },
    dyn_kw = function(card, kw) return kw == 'charge' end,
    grant = function(src, t, kw) return kw == 'charge' and HS.is_tribe(t, 'Beast') end }

M { id = 'warsong_commander', name = 'Warsong Commander', hs_id = 'VAN_EX1_084', atk = 2, hp = 3, mana = 3,
    rarity = 2,
    text = { 'Whenever you {C:attention}summon{} a minion', 'with 3 or less Attack, give', 'it {C:attention}Charge{}' },
    on_summon = function(card, new)
        if new ~= card and HS.attack(new) <= 3 then HS.give(new, 'charge'); HS.say(new, 'Charge!', G.C.RED) end
    end }

M { id = 'micro_machine', name = 'Micro Machine', hs_id = 'GVG_103', atk = 1, hp = 2, mana = 2, rarity = 2,
    tribe = 'Mech',
    text = { 'At the start of your turn,', 'gain {C:mult}+1{} Attack' },
    start_turn = function(card) HS.buff(card, 1, 0) end }

M { id = 'secretkeeper', name = 'Secretkeeper', hs_id = 'VAN_EX1_080', atk = 1, hp = 2, mana = 1, rarity = 2,
    text = { 'Whenever you gain a {C:attention}Secret{},', 'gain {C:attention}+1/+1{} permanently' },
    on_tag = function(card) HS.buff(card, 1, 1) end }

M { id = 'mana_addict', name = 'Mana Addict', hs_id = 'VAN_EX1_055', atk = 1, hp = 3, mana = 2, rarity = 2,
    text = { 'Whenever you cast a {C:attention}Spell{},', 'gain {C:mult}+2{} Attack this turn' },
    on_spell = function(card) HS.buff(card, 2, 0, 'turn') end }

M { id = 'imp_gang_boss', name = 'Imp Gang Boss', hs_id = 'CORE_BRM_006', atk = 2, hp = 4, mana = 3,
    rarity = 2, tribe = 'Demon',
    text = { 'Whenever this minion takes', 'damage, {C:attention}summon{} a 1/1 {C:attention}Imp{}' },
    on_damaged = function(card) HS.summon('imp', card) end }

M { id = 'injured_blademaster', name = 'Injured Blademaster', hs_id = 'VAN_CS2_181', atk = 4, hp = 7, mana = 3,
    rarity = 2,
    text = { BC .. 'Deal 4 damage', 'to HIMSELF' },
    battlecry = function(card) HS.damage(card, 4, card) end }

M { id = 'tar_creeper', name = 'Tar Creeper', hs_id = 'UNG_928', atk = 1, hp = 5, mana = 3, rarity = 2,
    tribe = 'Elemental', kw = { 'taunt' }, defend_atk = 2,
    text = { '{C:attention}Taunt{}. Has {C:mult}+2{} Attack during', 'your opponent\'s turn', '{C:inactive}(when the Blind attacks it){}' } }

M { id = 'unbound_elemental', name = 'Unbound Elemental', hs_id = 'VAN_EX1_258', atk = 2, hp = 4, mana = 3,
    rarity = 2,
    text = { 'Whenever you play a hand with', 'an {C:attention}Enhanced{} card {C:inactive}(Overload){},', 'gain {C:attention}+1/+1{}' },
    on_play = function(card)
        for _, c in ipairs((G.play and G.play.cards) or {}) do
            if c.ability and c.ability.set == 'Enhanced' then HS.buff(card, 1, 1); return end
        end
    end }

M { id = 'violet_teacher', name = 'Violet Teacher', hs_id = 'VAN_NEW1_026', atk = 3, hp = 5, mana = 4,
    rarity = 2,
    text = { 'Whenever you cast a {C:attention}Spell{},', '{C:attention}summon{} a 1/1 {C:attention}Violet Apprentice{}' },
    on_spell = function(card) HS.summon('violet_apprentice', card) end }

M { id = 'antique_healbot', name = 'Antique Healbot', hs_id = 'GVG_069', atk = 3, hp = 3, mana = 5, rarity = 2,
    tribe = 'Mech',
    text = { BC .. 'Restore {C:money}8{} Health', 'to your hero' },
    battlecry = function(card) HS.heal_hero(8, card) end }

M { id = 'savannah_highmane', name = 'Savannah Highmane', hs_id = 'VAN_EX1_534', atk = 6, hp = 5, mana = 6,
    rarity = 2, tribe = 'Beast',
    text = { DR .. 'Summon two', '2/2 {C:attention}Hyenas{}' },
    deathrattle = summon('hyena', 2) }

M { id = 'sunwalker', name = 'Sunwalker', hs_id = 'VAN_EX1_032', atk = 4, hp = 5, mana = 6, rarity = 2,
    kw = { 'taunt', 'divine_shield' },
    text = { '{C:attention}Taunt, Divine Shield{}' } }

M { id = 'fire_elemental', name = 'Fire Elemental', hs_id = 'VAN_CS2_042', atk = 6, hp = 5, mana = 6,
    rarity = 2, tribe = 'Elemental',
    text = { BC .. 'Deal {C:red}3{} damage', 'to the Blind' },
    battlecry = blind_dmg(3) }

M { id = 'coldlight_oracle', name = 'Coldlight Oracle', hs_id = 'VAN_EX1_050', atk = 2, hp = 2, mana = 3,
    rarity = 2, tribe = 'Murloc',
    text = { BC .. 'Draw 2 cards' },
    battlecry = draw(2) }

M { id = 'coldlight_seer', name = 'Coldlight Seer', hs_id = 'VAN_EX1_103', atk = 2, hp = 3, mana = 3,
    rarity = 2, tribe = 'Murloc',
    text = { BC .. 'Give your other', '{C:attention}Murlocs{} {C:chips}+2{} Health' },
    battlecry = function(card)
        for _, o in ipairs(HS.others(card)) do
            if HS.is_tribe(o, 'Murloc') then HS.buff(o, 0, 2) end
        end
    end }

M { id = 'mind_control_tech', name = 'Mind Control Tech', hs_id = 'VAN_EX1_085', atk = 3, hp = 3, mana = 3,
    rarity = 2,
    text = { BC .. 'If the next Tavern has', '2+ minions, take control of', 'one at random' },
    battlecry = function(card)
        local st = HS.state()
        st.mct_steals = (st.mct_steals or 0) + 1
        HS.say(card, 'Next Tavern!', G.C.PURPLE)
    end }

M { id = 'harvest_golem', name = 'Harvest Golem', hs_id = 'VAN_EX1_556', atk = 2, hp = 3, mana = 3, rarity = 2,
    tribe = 'Mech',
    text = { DR .. 'Summon a', '2/1 {C:attention}Damaged Golem{}' },
    deathrattle = summon('damaged_golem') }

M { id = 'haunted_creeper', name = 'Haunted Creeper', hs_id = 'FP1_002', atk = 1, hp = 2, mana = 2, rarity = 2,
    tribe = 'Beast',
    text = { DR .. 'Summon two', '1/1 {C:attention}Spectral Spiders{}' },
    deathrattle = summon('spectral_spider', 2) }

M { id = 'dirty_rat', name = 'Dirty Rat', hs_id = 'CFM_790', atk = 2, hp = 6, mana = 2, rarity = 2,
    kw = { 'taunt' },
    text = { '{C:attention}Taunt{}. ' .. BC .. 'Your opponent', 'summons a minion from their hand', '{C:inactive}(+1 minion in the next Tavern){}' },
    battlecry = function(card)
        local st = HS.state()
        st.shop_extra_minions = st.shop_extra_minions + 1
    end }

M { id = 'mountain_giant', name = 'Mountain Giant', hs_id = 'CORE_EX1_105', atk = 8, hp = 8, mana = 12,
    rarity = 2, tribe = 'Elemental', cost = 14,
    text = { 'Costs {C:money}$1{} less for each card', 'in your consumable slots' },
    cost_mod = function() return G.consumeables and #G.consumeables.cards or 0 end }

-- =========================================================================
-- COMMON
-- =========================================================================
M { id = 'patches_the_pirate', name = 'Patches the Pirate', hs_id = 'CFM_637', atk = 1, hp = 1, mana = 1,
    rarity = 1, tribe = { 'Pirate', 'Demon' }, kw = { 'charge' },
    text = { '{C:attention}Charge{}. When bought, hides in', 'your deck. Jumps out when you', 'buy a {C:attention}Pirate{} or draw him' } }

M { id = 'pen_flinger', name = 'Pen Flinger', hs_id = 'SCH_248', atk = 1, hp = 1, mana = 1, rarity = 1,
    text = { BC .. 'Deal {C:red}1{} damage to the', 'Blind. {C:attention}Spellburst:{} Trigger its', '{C:attention}Battlecry{} again' },
    battlecry = blind_dmg(1),
    spellburst = function(card) HS.run_battlecry(card) end }

M { id = 'babbling_book', name = 'Babbling Book', hs_id = 'CORE_KAR_009', atk = 1, hp = 2, mana = 1, rarity = 1,
    text = { BC .. 'Add a random {C:attention}Spell{}', 'to your hand' },
    battlecry = function(card) HS.add_spell(nil, card, function() return true end) end }

M { id = 'northshire_cleric', name = 'Northshire Cleric', hs_id = 'VAN_CS2_235', atk = 1, hp = 3, mana = 1,
    rarity = 1,
    text = { 'Whenever a minion is healed,', 'draw a card' },
    on_heal = function(card) HS.draw(1, card) end }

M { id = 'loot_hoarder', name = 'Loot Hoarder', hs_id = 'VAN_EX1_096', atk = 2, hp = 1, mana = 2, rarity = 1,
    text = { DR .. 'Draw a card' },
    deathrattle = draw(1) }

M { id = 'annoy_o_tron', name = 'Annoy-o-Tron', hs_id = 'GVG_085', atk = 1, hp = 2, mana = 2, rarity = 1,
    tribe = 'Mech', kw = { 'taunt', 'divine_shield' },
    text = { '{C:attention}Taunt, Divine Shield{}' } }

M { id = 'abusive_sergeant', name = 'Abusive Sergeant', hs_id = 'VAN_CS2_188', atk = 2, hp = 1, mana = 1,
    rarity = 1,
    text = { BC .. 'Give the minion to its', 'right {C:mult}+2{} Attack this turn' },
    battlecry = function(card)
        local r = HS.right(card)
        if r then HS.buff(r, 2, 0, 'turn') end
    end }

M { id = 'argent_squire', name = 'Argent Squire', hs_id = 'VAN_EX1_008', atk = 1, hp = 1, mana = 1, rarity = 1,
    kw = { 'divine_shield' },
    text = { '{C:attention}Divine Shield{}' } }

M { id = 'elven_archer', name = 'Elven Archer', hs_id = 'VAN_CS2_189', atk = 1, hp = 1, mana = 1, rarity = 1,
    text = { BC .. 'Deal {C:red}1{} damage', 'to the Blind' },
    battlecry = blind_dmg(1) }

M { id = 'flame_imp', name = 'Flame Imp', hs_id = 'VAN_EX1_319', atk = 3, hp = 2, mana = 1, rarity = 1,
    tribe = 'Demon',
    text = { BC .. 'Deal 3 damage to', 'your hero {C:inactive}(lose {C:money}$3{C:inactive}){}' },
    battlecry = function(card) HS.damage_hero(3, card) end }

M { id = 'goldshire_footman', name = 'Goldshire Footman', hs_id = 'VAN_CS1_042', atk = 1, hp = 2, mana = 1,
    rarity = 1, kw = { 'taunt' },
    text = { '{C:attention}Taunt{}' } }

M { id = 'grimscale_oracle', name = 'Grimscale Oracle', hs_id = 'VAN_EX1_508', atk = 1, hp = 1, mana = 1,
    rarity = 1, tribe = 'Murloc',
    text = { 'Your other {C:attention}Murlocs{} have', '{C:mult}+1{} Attack' },
    aura = function(src, t) if HS.is_tribe(t, 'Murloc') then return 1, 0 end end }

M { id = 'ironforge_rifleman', name = 'Ironforge Rifleman', hs_id = 'VAN_CS2_141', atk = 2, hp = 2, mana = 3,
    rarity = 1,
    text = { BC .. 'Deal {C:red}1{} damage', 'to the Blind' },
    battlecry = blind_dmg(1) }

M { id = 'leper_gnome', name = 'Leper Gnome', hs_id = 'VAN_EX1_029', atk = 2, hp = 1, mana = 1, rarity = 1,
    text = { 'At the end of each round, destroy', 'the lowest card left in your hand.', DR .. 'Deal {C:red}2{} damage to the Blind' },
    end_round = function(card)
        local low = HS.lowest_in_hand()
        if low then HS.destroy_cards({ low }, card) end
    end,
    deathrattle = blind_dmg(2) }

M { id = 'murloc_tidecaller', name = 'Murloc Tidecaller', hs_id = 'VAN_EX1_509', atk = 1, hp = 2, mana = 1,
    rarity = 1, tribe = 'Murloc',
    text = { 'Whenever you {C:attention}summon{} a {C:attention}Murloc{},', 'gain {C:mult}+1{} Attack' },
    on_summon = function(card, new)
        if new ~= card and HS.is_tribe(new, 'Murloc') then HS.buff(card, 1, 0) end
    end }

M { id = 'murloc_tidehunter', name = 'Murloc Tidehunter', hs_id = 'VAN_EX1_506', atk = 2, hp = 1, mana = 2,
    rarity = 1, tribe = 'Murloc',
    text = { BC .. 'Summon a 1/1', '{C:attention}Murloc Scout{}' },
    battlecry = summon('murloc_scout') }

M { id = 'novice_engineer', name = 'Novice Engineer', hs_id = 'VAN_EX1_015', atk = 1, hp = 1, mana = 2,
    rarity = 1,
    text = { BC .. 'Draw a card' },
    battlecry = draw(1) }

M { id = 'raid_leader', name = 'Raid Leader', hs_id = 'VAN_CS2_122', atk = 2, hp = 2, mana = 3, rarity = 1,
    text = { 'Your other minions have', '{C:mult}+1{} Attack' },
    aura = function() return 1, 0 end }

M { id = 'southsea_deckhand', name = 'Southsea Deckhand', hs_id = 'VAN_CS2_146', atk = 2, hp = 1, mana = 1,
    rarity = 1, tribe = 'Pirate',
    text = { 'Has {C:attention}Charge{} while you have', 'another {C:attention}Pirate{}' },
    dyn_kw = function(card, kw)
        if kw ~= 'charge' then return false end
        for _, o in ipairs(HS.others(card)) do
            if HS.is_tribe(o, 'Pirate') then return true end
        end
        return false
    end }

M { id = 'stonetusk_boar', name = 'Stonetusk Boar', hs_id = 'VAN_CS2_171', atk = 1, hp = 1, mana = 1,
    rarity = 1, tribe = 'Beast', kw = { 'charge' },
    text = { '{C:attention}Charge{}' } }

M { id = 'stormwind_champion', name = 'Stormwind Champion', hs_id = 'VAN_CS2_222', atk = 6, hp = 6, mana = 7,
    rarity = 1,
    text = { 'Your other minions have', '{C:attention}+1/+1{}' },
    aura = function() return 1, 1 end }

M { id = 'stormwind_knight', name = 'Stormwind Knight', hs_id = 'VAN_CS2_131', atk = 2, hp = 5, mana = 4,
    rarity = 1, kw = { 'charge' },
    text = { '{C:attention}Charge{}' } }

M { id = 'timber_wolf', name = 'Timber Wolf', hs_id = 'VAN_DS1_175', atk = 1, hp = 1, mana = 1, rarity = 1,
    tribe = 'Beast',
    text = { 'Your other {C:attention}Beasts{} have', '{C:mult}+1{} Attack' },
    aura = function(src, t) if HS.is_tribe(t, 'Beast') then return 1, 0 end end }

M { id = 'voidwalker', name = 'Voidwalker', hs_id = 'VAN_CS2_065', atk = 1, hp = 3, mana = 1, rarity = 1,
    tribe = 'Demon', kw = { 'taunt' },
    text = { '{C:attention}Taunt{}' } }

M { id = 'voodoo_doctor', name = 'Voodoo Doctor', hs_id = 'VAN_EX1_011', atk = 2, hp = 1, mana = 1, rarity = 1,
    text = { BC .. 'Restore {C:chips}2{} Health to', 'the minion to its right' },
    battlecry = function(card)
        local r = HS.right(card)
        if r then HS.heal(r, 2) end
    end }

M { id = 'wolfrider', name = 'Wolfrider', hs_id = 'VAN_CS2_124', atk = 3, hp = 1, mana = 3, rarity = 1,
    kw = { 'charge' },
    text = { '{C:attention}Charge{}' } }

M { id = 'young_dragonhawk', name = 'Young Dragonhawk', hs_id = 'VAN_CS2_169', atk = 1, hp = 1, mana = 1,
    rarity = 1, tribe = 'Beast', kw = { 'windfury' },
    text = { '{C:attention}Windfury{}' } }

M { id = 'zombie_chow', name = 'Zombie Chow', hs_id = 'FP1_001', atk = 2, hp = 3, mana = 1, rarity = 1,
    tribe = 'Undead',
    text = { DR .. 'Restore {C:blue}5{} Health', 'to the Blind' },
    deathrattle = function(card) HS.heal_blind(5, card) end }

M { id = 'bluegill_warrior', name = 'Bluegill Warrior', hs_id = 'VAN_CS2_173', atk = 2, hp = 1, mana = 2,
    rarity = 1, tribe = 'Murloc', kw = { 'charge' },
    text = { '{C:attention}Charge{}' } }

M { id = 'dread_corsair', name = 'Dread Corsair', hs_id = 'VAN_NEW1_022', atk = 3, hp = 3, mana = 4,
    rarity = 1, tribe = 'Pirate', kw = { 'taunt' },
    text = { '{C:attention}Taunt{}. Costs {C:money}$1{} less', 'for each other {C:attention}Pirate{}', 'you have' },
    cost_mod = function(card)
        local n = 0
        for _, o in ipairs(HS.minions()) do
            if o ~= card and HS.is_tribe(o, 'Pirate') then n = n + 1 end
        end
        return n
    end }

M { id = 'frostwolf_warlord', name = 'Frostwolf Warlord', hs_id = 'VAN_CS2_226', atk = 4, hp = 4, mana = 5,
    rarity = 1,
    text = { BC .. 'Gain {C:attention}+1/+1{} for each', 'other friendly minion' },
    battlecry = function(card)
        local n = #HS.others(card)
        if n > 0 then HS.buff(card, n, n) end
    end }

M { id = 'gnomish_inventor', name = 'Gnomish Inventor', hs_id = 'VAN_CS2_147', atk = 2, hp = 4, mana = 4,
    rarity = 1,
    text = { BC .. 'Draw a card' },
    battlecry = draw(1) }

M { id = 'kobold_geomancer', name = 'Kobold Geomancer', hs_id = 'VAN_CS2_142', atk = 2, hp = 2, mana = 2,
    rarity = 1, spell_damage = 1,
    text = { '{C:attention}Spell Damage +1{}' } }

M { id = 'korkron_elite', name = "Kor'kron Elite", hs_id = 'VAN_NEW1_011', atk = 4, hp = 3, mana = 4,
    rarity = 1, kw = { 'charge' },
    text = { '{C:attention}Charge{}' } }

M { id = 'ironbeak_owl', name = 'Ironbeak Owl', hs_id = 'VAN_CS2_203', atk = 2, hp = 1, mana = 2, rarity = 2,
    tribe = 'Beast',
    text = { BC .. '{C:attention}Silence{} the Blind', '{C:inactive}(disable its ability){}' },
    battlecry = function(card) HS.silence_boss(card) end }

M { id = 'worgen_infiltrator', name = 'Worgen Infiltrator', hs_id = 'VAN_EX1_010', atk = 2, hp = 1, mana = 1,
    rarity = 1, kw = { 'stealth' },
    text = { '{C:attention}Stealth{}' } }

M { id = 'mistress_of_mixtures', name = 'Mistress of Mixtures', hs_id = 'CFM_120', atk = 2, hp = 2, mana = 1,
    rarity = 1, tribe = 'Undead',
    text = { DR .. 'Restore {C:money}4{} Health', 'to each hero {C:inactive}(you and the Blind){}' },
    deathrattle = function(card) HS.heal_hero(4, card); HS.heal_blind(4) end }

M { id = 'corridor_creeper', name = 'Corridor Creeper', hs_id = 'LOOT_149', atk = 2, hp = 5, mana = 7,
    rarity = 1, tribe = 'Beast', cost = 9,
    text = { 'Costs {C:money}$1{} less for each', 'minion that died this run' },
    cost_mod = function() return (G.GAME and G.GAME.hs and G.GAME.hs.deaths) or 0 end }

M { id = 'righteous_protector', name = 'Righteous Protector', hs_id = 'CORE_ICC_038', atk = 1, hp = 1,
    mana = 1, rarity = 1, kw = { 'taunt', 'divine_shield' },
    text = { '{C:attention}Taunt, Divine Shield{}' } }

M { id = 'fire_fly', name = 'Fire Fly', hs_id = 'CORE_UNG_809', atk = 1, hp = 2, mana = 1, rarity = 1,
    tribe = 'Elemental',
    text = { BC .. 'Summon a 1/2', '{C:attention}Flame Elemental{}' },
    battlecry = summon('flame_elemental') }

M { id = 'glacial_shard', name = 'Glacial Shard', hs_id = 'CORE_UNG_205', atk = 2, hp = 1, mana = 1,
    rarity = 1, tribe = 'Elemental',
    text = { BC .. '{C:attention}Freeze{} the Blind', '{C:inactive}(it skips its next attack){}' },
    battlecry = function(card) if HS.enemy() then HS.freeze_boss(card) end end }

M { id = 'plated_beetle', name = 'Plated Beetle', hs_id = 'CORE_LOOT_413', atk = 2, hp = 3, mana = 2,
    rarity = 1, tribe = 'Beast',
    text = { DR .. 'Gain 3 {C:attention}Armor{}' },
    deathrattle = function(card) HS.armor(3, card) end }

M { id = 'armor_vendor', name = 'Armor Vendor', hs_id = 'CORE_YOP_032', atk = 1, hp = 3, mana = 1, rarity = 1,
    text = { BC .. 'Give 4 {C:attention}Armor{} to each', 'hero {C:inactive}(you and the Blind){}' },
    battlecry = function(card) HS.armor(4, card); HS.heal_blind(4) end }

M { id = 'wandmaker', name = 'Wandmaker', hs_id = 'CORE_SCH_160', atk = 2, hp = 2, mana = 2, rarity = 1,
    text = { BC .. 'Add a random 1-Cost', '{C:attention}Spell{} to your hand' },
    battlecry = function(card) HS.add_spell(nil, card, function(s) return (s.mana or 99) <= 1 end) end }

M { id = 'tour_guide', name = 'Tour Guide', hs_id = 'CORE_SCH_312', atk = 1, hp = 1, mana = 1, rarity = 1,
    text = { BC .. 'Gain {C:red}+1{} Mulligan' },
    battlecry = function(card) ease_discard(1); HS.say(card, '+1 Mulligan', G.C.RED) end }

M { id = 'kindling_elemental', name = 'Kindling Elemental', hs_id = 'BAR_854', atk = 1, hp = 2, mana = 1,
    rarity = 1, tribe = 'Elemental',
    text = { BC .. '{C:attention}Elementals{} in the next', 'Tavern cost {C:money}$1{} less' },
    battlecry = function(card)
        local st = HS.state()
        st.tribe_discount.Elemental = (st.tribe_discount.Elemental or 0) + 1
    end }

M { id = 'peasant', name = 'Peasant', hs_id = 'SW_319', atk = 2, hp = 1, mana = 1, rarity = 1,
    text = { 'At the start of your turn,', 'draw a card' },
    start_turn = draw(1) }

M { id = 'bonechewer_brawler', name = 'Bonechewer Brawler', hs_id = 'BT_715', atk = 2, hp = 3, mana = 2,
    rarity = 1, kw = { 'taunt' },
    text = { '{C:attention}Taunt{}. Whenever this minion', 'takes damage, gain {C:mult}+2{} Attack' },
    on_damaged = function(card) HS.buff(card, 2, 0) end }

M { id = 'costumed_singer', name = 'Costumed Singer', hs_id = 'JAM_001', atk = 1, hp = 1, mana = 1, rarity = 1,
    text = { 'At the end of your turn, draw', 'a {C:attention}Secret{} {C:inactive}(1 in 6 chance to', '{C:inactive}gain a random Secret){}' },
    end_turn = function(card)
        local p = (G.GAME.probabilities and G.GAME.probabilities.normal) or 1
        if HS.rand('hs_singer') < p / 6 and add_tag and Tag and get_next_tag_key then
            add_tag(Tag(get_next_tag_key('hs_singer')))
            HS.say(card, 'Secret!', G.C.PURPLE)
        end
    end }

M { id = 'frequency_oscillator', name = 'Frequency Oscillator', hs_id = 'ETC_106', atk = 2, hp = 1, mana = 1,
    rarity = 1, tribe = 'Mech',
    text = { BC .. 'Turn a random card in', 'your hand into a {C:attention}Steel Card{}', '{C:inactive}(a Mech!){}' },
    battlecry = function(card)
        local pool = {}
        for _, c in ipairs((G.hand and G.hand.cards) or {}) do
            if c.config.center.key ~= 'm_steel' then pool[#pool + 1] = c end
        end
        local t = HS.pick(pool, 'hs_oscillator')
        if t then HS.enhance(t, 'm_steel', card) end
    end }

M { id = 'miracle_salesman', name = 'Miracle Salesman', hs_id = 'WW_331', atk = 2, hp = 2, mana = 1, rarity = 1,
    text = { DR .. 'Get a {C:attention}Snake Oil{}' },
    deathrattle = function(card) HS.add_spell('snake_oil', card) end }

M { id = 'gold_panner', name = 'Gold Panner', hs_id = 'WW_391', atk = 1, hp = 2, mana = 2, rarity = 1,
    text = { 'At the end of your turn,', 'draw a card' },
    end_turn = draw(1) }

M { id = 'drone_deconstructor', name = 'Drone Deconstructor', hs_id = 'TTN_860', atk = 1, hp = 2, mana = 1,
    rarity = 1, tribe = 'Mech',
    text = { BC .. 'Summon a 1/1 {C:attention}Sparkbot{}', 'with a random keyword' },
    battlecry = function(card)
        HS.summon(HS.pick(HS.SPARKBOTS, 'hs_sparkbot'), card)
    end }

M { id = 'tar_lurker', name = 'Tar Lurker', hs_id = 'UNG_049', atk = 1, hp = 7, mana = 5, rarity = 1,
    tribe = 'Elemental', kw = { 'taunt' }, defend_atk = 3,
    text = { '{C:attention}Taunt{}. Has {C:mult}+3{} Attack during', 'your opponent\'s turn', '{C:inactive}(when the Blind attacks it){}' } }

M { id = 'waxadred', name = 'Waxadred', hs_id = 'DRG_036', atk = 7, hp = 5, mana = 5, rarity = 1,
    tribe = { 'Elemental', 'Dragon' },
    text = { DR .. 'Shuffle a {C:attention}Candle{} into', 'your deck that resummons', 'Waxadred when drawn' },
    deathrattle = function(card) HS.add_candle(); HS.say(card, 'Candle!', G.C.GOLD) end }

M { id = 'safety_inspector', name = 'Safety Inspector', hs_id = 'DMF_125', atk = 1, hp = 3, mana = 1,
    rarity = 1,
    text = { BC .. 'Destroy the lowest card', 'in your hand {C:inactive}(fails inspection){}.', 'Draw a card' },
    battlecry = function(card)
        local low = HS.lowest_in_hand()
        if low then HS.destroy_cards({ low }, card) end
        HS.draw(1, card)
    end }

M { id = 'vicious_fledgling', name = 'Vicious Fledgling', hs_id = 'UNG_075', atk = 3, hp = 3, mana = 3,
    rarity = 1, tribe = 'Beast',
    text = { 'After this attacks {C:inactive}(scores){},', '{C:attention}Adapt{} {C:inactive}(once per round){}' },
    after_attack = function(card)
        local e = E(card)
        if e.round_flag then return end
        e.round_flag = true
        HS.adapt(card)
    end }

M { id = 'dreadsteed', name = 'Dreadsteed', hs_id = 'AT_019', atk = 1, hp = 1, mana = 4, rarity = 1,
    tribe = 'Demon',
    text = { DR .. 'At the end of the', 'turn, summon a {C:attention}Dreadsteed{}' },
    deathrattle = function(card)
        if HS.in_round() then
            local st = HS.state()
            st.end_of_turn_summons[#st.end_of_turn_summons + 1] = 'j_hs_dreadsteed'
        else
            HS.summon('dreadsteed', card)
        end
    end }

M { id = 'molten_giant', name = 'Molten Giant', hs_id = 'CORE_EX1_620', atk = 8, hp = 8, mana = 20,
    rarity = 1, tribe = 'Elemental', cost = 22,
    text = { 'Costs {C:money}$1{} less for each Health', 'your hero is missing', '{C:inactive}(each $ below $30){}' },
    cost_mod = function() return math.max(0, HS.hero_max() - ((G.GAME and G.GAME.dollars) or 0)) end }

M { id = 'sea_giant', name = 'Sea Giant', hs_id = 'CORE_EX1_586', atk = 8, hp = 8, mana = 10, rarity = 1,
    cost = 12,
    text = { 'Costs {C:money}$1{} less for each', 'minion you have' },
    cost_mod = function() return #HS.minions() end }

-- =========================================================================
-- CLASSIC LEGENDS (batch 1 of the new cards)
-- =========================================================================
M { id = 'ragnaros_the_firelord', name = 'Ragnaros the Firelord', hs_id = 'VAN_EX1_298', atk = 8, hp = 8,
    mana = 8, rarity = 3, tribe = 'Elemental', no_attack = true,
    text = { "Can't attack {C:inactive}(scores no Mult){}.", 'After each hand, deal {C:red}8{}', 'damage to the Blind' },
    end_turn = function(card) HS.damage_blind(8, card) end }

HS.DREAMS = { 'ysera_awakens', 'nightmare', 'emerald_drake', 'laughing_sister' }
M { id = 'ysera', name = 'Ysera', hs_id = 'VAN_EX1_572', atk = 4, hp = 12, mana = 9, rarity = 3,
    tribe = 'Dragon',
    text = { 'At the end of each round,', 'add a {C:attention}Dream{} card', 'to your hand' },
    end_round = function(card)
        HS.add_spell(HS.pick(HS.DREAMS, 'hs_ysera'), card)
    end }

M { id = 'malygos', name = 'Malygos', hs_id = 'VAN_EX1_563', atk = 4, hp = 12, mana = 9, rarity = 3,
    tribe = 'Dragon', spell_damage = 5,
    text = { '{C:attention}Spell Damage +5{}' } }

M { id = 'alexstrasza', name = 'Alexstrasza', hs_id = 'VAN_EX1_561', atk = 8, hp = 8, mana = 9, rarity = 3,
    tribe = 'Dragon',
    text = { BC .. 'Set a {C:attention}Boss Blind{} to', 'half its starting requirement' },
    battlecry = function(card)
        if not HS.is_boss() then HS.say(card, 'Not a Boss', G.C.UI.TEXT_INACTIVE); return end
        local half = math.floor((HS.state().blind_base or G.GAME.blind.chips) / 2)
        if G.GAME.blind.chips > half then
            G.GAME.blind.chips = math.max(1, half)
            HS.update_blind_text()
            HS.say(card, 'Blind set to half!', G.C.RED)
        end
    end }

M { id = 'deathwing', name = 'Deathwing', hs_id = 'VAN_NEW1_030', atk = 12, hp = 12, mana = 10, rarity = 3,
    tribe = 'Dragon',
    text = { BC .. 'Destroy all other minions.', 'Discard your hand and', 'draw a new one' },
    battlecry = function(card)
        for _, o in ipairs(HS.others(card)) do HS.kill(o, 'destroy') end
        if HS.in_round() and G.hand and #G.hand.cards > 0 then
            local n = #G.hand.cards
            HS.event(function()
                for i = #G.hand.cards, 1, -1 do draw_card(G.hand, G.discard, nil, nil, nil, G.hand.cards[i]) end
            end)
            HS.draw(n)
        end
    end }

M { id = 'onyxia', name = 'Onyxia', hs_id = 'VAN_EX1_562', atk = 8, hp = 8, mana = 9, rarity = 3,
    tribe = 'Dragon',
    text = { BC .. '{C:attention}Summon{} 1/1 Whelps', 'until your board is full' },
    battlecry = function(card)
        local guard = 0
        while HS.board_space() > 0 and guard < 20 do
            guard = guard + 1
            if not HS.summon('whelp', card) then break end
        end
    end }

M { id = 'nat_pagle', name = 'Nat Pagle', hs_id = 'VAN_EX1_557', atk = 0, hp = 4, mana = 2, rarity = 3,
    text = { 'At the start of each hand,', '{C:green}50%{} chance to draw', 'an extra card' },
    start_turn = function(card)
        if HS.rand('hs_nat_pagle') < 0.5 then HS.draw(1, card) end
    end }

M { id = 'king_mukla', name = 'King Mukla', hs_id = 'VAN_EX1_014', atk = 5, hp = 5, mana = 3, rarity = 3,
    tribe = 'Beast',
    text = { BC .. 'The Blind eats 2 Bananas:', 'it heals {C:blue}2{}' },
    battlecry = function(card) HS.heal_blind(2, card) end }

M { id = 'questing_adventurer', name = 'Questing Adventurer', hs_id = 'VAN_EX1_044', atk = 2, hp = 2,
    mana = 3, rarity = 2,
    text = { 'Whenever you use a {C:attention}Spell{},', 'discard, or buy a minion,', 'gain {C:attention}+1/+1{}' },
    on_spell = function(card) HS.buff(card, 1, 1) end,
    on_discard = function(card) HS.buff(card, 1, 1) end,
    on_buy = function(card) HS.buff(card, 1, 1) end }

-- =========================================================================
-- COMBO ENGINES (X Mult stacking, retriggers, card generation)
-- =========================================================================
M { id = 'whirlwind_tempest', name = 'Whirlwind Tempest', hs_id = 'DAL_742', atk = 6, hp = 6, mana = 8,
    rarity = 3, tribe = 'Elemental',
    text = { 'Your minions with {C:attention}Windfury{}', 'have {C:attention}Mega-Windfury{}', '{C:inactive}(score 4 times){}' },
    grant = function(src, t, kw) return kw == 'mega_windfury' and HS.has(t, 'windfury') end }

M { id = 'tyrande', name = 'Tyrande', hs_id = 'EDR_464', atk = 5, hp = 7, mana = 7, rarity = 3,
    text = { BC .. 'Your next {C:attention}3{} Spells', 'cast twice {C:inactive}(#1# left){}' },
    vars = function(card)
        local st = G.GAME and G.GAME.hs
        return { (st and st.cast_twice) or 0 }
    end,
    battlecry = function(card, i)
        local st = HS.state()
        st.cast_twice = math.max(st.cast_twice or 0, 3 * (i or 1))
    end }

M { id = 'archmage_vargoth', name = 'Archmage Vargoth', hs_id = 'DAL_558', atk = 2, hp = 6, mana = 4,
    rarity = 3,
    text = { 'After each hand, cast a Spell', 'you used this turn again', '{C:inactive}(targets are random){}' },
    end_turn = function(card)
        local used = HS.state().turn_spells or {}
        local pool = {}
        for _, key in ipairs(used) do
            local s = HS.spell_by_key and HS.spell_by_key[key]
            if s and s.random ~= false then pool[#pool + 1] = s end
        end
        local s = HS.pick(pool, 'hs_vargoth')
        if s then HS.cast_spell(s, card) end
    end }

M { id = 'old_murk_eye', name = 'Old Murk-Eye', hs_id = 'VAN_EX1_062', atk = 2, hp = 4, mana = 4, rarity = 3,
    tribe = 'Murloc', kw = { 'charge' },
    text = { '{C:attention}Charge{}. Has {C:mult}+1{} Attack for each', 'other Murloc. Your other Murlocs', 'each give {X:mult,C:white}X1.1{} Mult' },
    dyn_atk = function(card)
        local n = 0
        for _, o in ipairs(HS.others(card)) do if HS.is_tribe(o, 'Murloc') then n = n + 1 end end
        return n
    end,
    lord_x = function(lord, t) if HS.is_tribe(t, 'Murloc') then return 1.1 end end }

M { id = 'skycapn_kragg', name = "Skycap'n Kragg", hs_id = 'AT_070', atk = 4, hp = 6, mana = 7, rarity = 3,
    tribe = 'Pirate', kw = { 'charge' },
    text = { '{C:attention}Charge{}. Costs {C:money}$1{} less per', 'Pirate you have. Your other', 'Pirates each give {X:mult,C:white}X1.1{} Mult' },
    cost_mod = function()
        local n = 0
        for _, o in ipairs(HS.minions()) do if HS.is_tribe(o, 'Pirate') then n = n + 1 end end
        return n
    end,
    lord_x = function(lord, t) if HS.is_tribe(t, 'Pirate') then return 1.1 end end }

M { id = 'grimestreet_enforcer', name = 'Grimestreet Enforcer', hs_id = 'CFM_639', atk = 4, hp = 4, mana = 5,
    rarity = 2,
    text = { 'After each hand, cards left', 'in your hand permanently', 'gain {X:mult,C:white}X0.05{} Mult' },
    end_turn = function(card)
        local n = 0
        for _, c in ipairs((G.hand and G.hand.cards) or {}) do
            c.ability.perma_x_mult = (c.ability.perma_x_mult or 0) + 0.05
            n = n + 1
        end
        if n > 0 then HS.say(card, '+X0.05', G.C.MULT) end
    end }

-- Broken legendaries: Negative, Polychrome and Steel generation
M { id = 'lyra_the_sunshard', name = 'Lyra the Sunshard', hs_id = 'CORE_UNG_963', atk = 3, hp = 5, mana = 4,
    rarity = 4, tribe = 'Elemental',
    text = { 'Whenever you cast a {C:attention}Spell{}, add', 'a random {C:dark_edition}Negative{} Spell to', 'your hand {C:inactive}(not from her own){}' },
    on_spell = function(card, center, spell_card)
        if spell_card and spell_card.ability and spell_card.ability.hs_lyra then return end
        local pool = {}
        for _, s in ipairs(HS.spells) do if not s.token then pool[#pool + 1] = s.key end end
        local key = HS.pick(pool, 'hs_lyra')
        if not key then return end
        local c = SMODS.add_card({ set = 'Tarot', key = key, area = G.consumeables, edition = 'e_negative',
            key_append = 'hs_lyra' })
        if c then
            c:set_edition({ negative = true }, true)
            c.ability.hs_lyra = true
            HS.say(card, 'Sunshard!', G.C.DARK_EDITION or G.C.PURPLE)
        end
    end }

M { id = 'zola_the_gorgon', name = 'Zola the Gorgon', hs_id = 'CORE_LOOT_516', atk = 2, hp = 2, mana = 3,
    rarity = 4, tribe = 'Naga',
    text = { BC .. '{C:attention}Summon{} a Golden copy', 'of the minion to its right:', 'it is {C:dark_edition}Polychrome{}' },
    battlecry = function(card)
        local t = HS.right(card)
        if not t or t.config.center.key == card.config.center.key then return end
        local c = HS.clone_minion(t, card)
        if c then
            c:set_edition({ polychrome = true }, true)
            HS.say(c, 'Golden!', G.C.GOLD)
        end
    end }

M { id = 'mimiron_the_mastermind', name = 'Mimiron, the Mastermind', hs_id = 'TTN_920', atk = 2, hp = 5,
    mana = 3, rarity = 4, tribe = 'Mech',
    text = { 'After you buy or summon a', '{C:attention}Mech{}, a random card in your', 'deck becomes a {C:attention}Steel Card{}' },
    on_summon = function(card, new)
        if new == card or not HS.is_tribe(new, 'Mech') then return end
        local pool = {}
        for _, c in ipairs(G.playing_cards or {}) do
            local k = c.config and c.config.center and c.config.center.key
            if k == 'c_base' or (k and k:find('^m_') and k ~= 'm_steel' and not k:find('^m_hs_')) then
                pool[#pool + 1] = c
            end
        end
        local target = HS.pick(pool, 'hs_mimiron')
        if target then HS.enhance(target, 'm_steel', card) end
    end }

-- =========================================================================
-- CLASS LEGENDS (combo engines from other classes)
-- =========================================================================
M { id = 'tess_greymane', name = 'Tess Greymane', hs_id = 'CORE_GIL_598', atk = 6, hp = 6, mana = 7, rarity = 4,
    text = { BC .. 'Recast every {C:attention}Spell{} you', 'used since last round started', '{C:inactive}(targets chosen randomly){}' },
    battlecry = function(card)
        local st = HS.state()
        local list = st.tess_spells or {}
        if #list == 0 then HS.say(card, 'Nothing to replay', G.C.UI.TEXT_INACTIVE); return end
        st.recasting = true
        local n = 0
        for i = 1, math.min(#list, 12) do
            local s = HS.spell_by_key and HS.spell_by_key[list[i]]
            if s and s.random ~= false and HS.cast_spell(s, card) then n = n + 1 end
        end
        st.recasting = nil
        HS.say(card, 'Replayed ' .. n .. '!', G.C.SECONDARY_SET.Tarot)
    end }

local function paletress_summon(card)
    HS.summon_random(function(d)
        return d.rarity == 4 and d.id ~= 'confessor_paletress'
    end, card, { temporary = true })
end
M { id = 'confessor_paletress', name = 'Confessor Paletress', hs_id = 'AT_018', atk = 5, hp = 4, mana = 7,
    rarity = 3,
    text = { '{C:attention}Battlecry{} and after each', 'Discard {C:inactive}(Inspire){}: {C:attention}summon{} a random', '{C:legendary}Legendary{} minion for this round' },
    battlecry = paletress_summon,
    on_discard = function(card) if HS.in_round() then paletress_summon(card) end end }

M { id = 'raza_the_chained', name = 'Raza the Chained', hs_id = 'CFM_020', atk = 5, hp = 5, mana = 5, rarity = 3,
    text = { BC .. 'If your deck has no', 'duplicates, gain {C:red}+3{} Discards', '{C:inactive}(your Hero Power costs 0){}' },
    battlecry = function(card)
        if HS.deck_has_duplicates() then HS.say(card, 'Duplicates!', G.C.RED); return end
        if ease_discard then ease_discard(3) end
        HS.say(card, '+3 Discards', G.C.RED)
    end }

M { id = 'mozaki_master_duelist', name = 'Mozaki, Master Duelist', hs_id = 'SCH_400', atk = 3, hp = 8,
    mana = 5, rarity = 3,
    text = { 'After you cast a {C:attention}Spell{}, permanently', 'gain {C:attention}Spell Damage +1{}', '{C:inactive}(currently +#1#){}' },
    vars = function(card)
        local e = card and E(card)
        return { (e and e.spell_damage) or 0 }
    end,
    on_spell = function(card)
        local e = E(card)
        e.spell_damage = (e.spell_damage or 0) + 1
        HS.say(card, 'Spell Damage +' .. e.spell_damage, G.C.SECONDARY_SET.Tarot)
    end }

M { id = 'spiritsinger_umbra', name = 'Spiritsinger Umbra', hs_id = 'UNG_900', atk = 3, hp = 4, mana = 5,
    rarity = 3,
    text = { 'After you buy or {C:attention}summon{} a', 'minion, trigger its', '{C:attention}Deathrattle{}' },
    on_summon = function(card, new)
        if new == card or not HS.alive(new) then return end
        local nd = HS.def(new)
        if not (nd and nd.deathrattle) then return end
        -- deathrattles that summon could chain forever: cap the depth
        local st = HS.state()
        st.umbra_depth = (st.umbra_depth or 0) + 1
        if st.umbra_depth <= 3 then
            local times = HS.has_minion('baron_rivendare') and 2 or 1
            for i = 1, times do nd.deathrattle(new, i) end
            HS.say(new, 'Deathrattle!', G.C.PURPLE)
        end
        st.umbra_depth = st.umbra_depth - 1
    end }

M { id = 'aviana', name = 'Aviana', hs_id = 'AT_045', atk = 5, hp = 5, mana = 9, rarity = 3,
    text = { 'Minions in the shop', 'cost {C:money}$1{}' },
    shop_cap = function() return 1 end,
    on_add = function() HS.refresh_costs() end,
    on_remove = function() HS.event(HS.refresh_costs) end }

M { id = 'grommash_hellscream', name = 'Grommash Hellscream', hs_id = 'VAN_EX1_414', atk = 4, hp = 9,
    mana = 8, rarity = 3, kw = { 'charge' }, enrage = { atk = 6 },
    text = { '{C:attention}Charge{}. {C:attention}Enrage:{} {C:mult}+6{} Attack', '{C:inactive}(while damaged){}' } }

-- =========================================================================
-- TOKENS (only ever summoned; never appear in shops or packs)
-- =========================================================================
local function token(t)
    t.token = true
    t.rarity = 1
    t.cost = 1
    t.text = t.text or {}
    return M(t)
end

token { id = 'boom_bot', name = 'Boom Bot', hs_id = 'GVG_110t', atk = 1, hp = 1, mana = 1, tribe = 'Mech',
    text = { DR .. 'Deal {C:red}1-4{} damage', 'to the Blind' },
    deathrattle = function(card)
        HS.damage_blind(1 + math.floor(HS.rand('hs_boombot') * 4), card)
    end }
token { id = 'putrid_slime', name = 'Putrid Slime', hs_id = 'FP1_012t', atk = 1, hp = 2, mana = 1,
    kw = { 'taunt' }, text = { '{C:attention}Taunt{}' } }
token { id = 'baine_bloodhoof', name = 'Baine Bloodhoof', hs_id = 'EX1_110t', atk = 5, hp = 5, mana = 5 }
token { id = 'violet_apprentice', name = 'Violet Apprentice', hs_id = 'NEW1_026t', atk = 1, hp = 1, mana = 1 }
token { id = 'imp', name = 'Imp', hs_id = 'BRM_006t', atk = 1, hp = 1, mana = 1, tribe = 'Demon' }
token { id = 'murloc_scout', name = 'Murloc Scout', hs_id = 'CORE_EX1_506a', atk = 1, hp = 1, mana = 1,
    tribe = 'Murloc' }
token { id = 'hyena', name = 'Hyena', hs_id = 'EX1_534t', atk = 2, hp = 2, mana = 2, tribe = 'Beast' }
token { id = 'damaged_golem', name = 'Damaged Golem', hs_id = 'skele21', atk = 2, hp = 1, mana = 1,
    tribe = 'Mech' }
token { id = 'spectral_spider', name = 'Spectral Spider', hs_id = 'FP1_002t', atk = 1, hp = 1, mana = 1,
    tribe = 'Beast' }
token { id = 'flame_elemental', name = 'Flame Elemental', hs_id = 'UNG_809t1', atk = 1, hp = 2, mana = 1,
    tribe = 'Elemental' }
-- new-card tokens
token { id = 'whelp', name = 'Whelp', hs_id = 'ds1_whelptoken', atk = 1, hp = 1, mana = 1, tribe = 'Dragon' }
token { id = 'hound', name = 'Hound', hs_id = 'EX1_538t', atk = 1, hp = 1, mana = 1, tribe = 'Beast',
    kw = { 'charge' }, text = { '{C:attention}Charge{}' } }
token { id = 'huffer', name = 'Huffer', hs_id = 'VAN_NEW1_034', atk = 4, hp = 2, mana = 3, tribe = 'Beast',
    kw = { 'charge' }, text = { '{C:attention}Charge{}' } }
token { id = 'leokk', name = 'Leokk', hs_id = 'NEW1_033', atk = 2, hp = 4, mana = 3, tribe = 'Beast',
    text = { 'Your other minions have', '{C:mult}+1{} Attack' },
    aura = function(src, t) return 1, 0 end }
token { id = 'misha', name = 'Misha', hs_id = 'VAN_NEW1_032', atk = 4, hp = 4, mana = 3, tribe = 'Beast',
    kw = { 'taunt' }, text = { '{C:attention}Taunt{}' } }
token { id = 'scarab_beetle', name = 'Scarab Beetle', hs_id = 'ICC_832t4', atk = 1, hp = 5, mana = 1,
    tribe = 'Beast', kw = { 'taunt' }, text = { '{C:attention}Taunt{}' } }
token { id = 'spirit_wolf', name = 'Spirit Wolf', hs_id = 'VAN_EX1_tk11', atk = 2, hp = 3, mana = 2,
    kw = { 'taunt' }, text = { '{C:attention}Taunt{}' } }
token { id = 'emerald_drake', name = 'Emerald Drake', hs_id = 'VAN_DREAM_03', atk = 7, hp = 6, mana = 4,
    tribe = 'Dragon' }
token { id = 'laughing_sister', name = 'Laughing Sister', hs_id = 'VAN_DREAM_01', atk = 3, hp = 5, mana = 2,
    kw = { 'stealth' }, text = { '{C:attention}Stealth{}' } }
-- Secret tokens (src/secrets.lua)
token { id = 'snake', name = 'Snake', hs_id = 'VAN_EX1_554t', atk = 1, hp = 1, mana = 1, tribe = 'Beast' }
token { id = 'ironfur_grizzly', name = 'Ironfur Grizzly', hs_id = 'VAN_CS2_125', atk = 3, hp = 3, mana = 3,
    tribe = 'Beast', kw = { 'taunt' }, text = { '{C:attention}Taunt{}' } }
token { id = 'cat_in_a_hat', name = 'Cat in a Hat', hs_id = 'KAR_004a', atk = 4, hp = 2, mana = 2,
    tribe = 'Beast', kw = { 'stealth' }, text = { '{C:attention}Stealth{}' } }
token { id = 'defender', name = 'Defender', hs_id = 'VAN_EX1_130a', atk = 2, hp = 1, mana = 1 }
-- Drone Deconstructor's Sparkbots: one real card per keyword
HS.SPARKBOTS = {}
for _, v in ipairs({ { 'divine_shield', 'Divine Shield', 'TTN_719t' }, { 'taunt', 'Taunt', 'TTN_719t1' },
    { 'rush', 'Rush', 'TTN_719t2' }, { 'windfury', 'Windfury', 'TTN_719t3' },
    { 'reborn', 'Reborn', 'TTN_719t6' }, { 'lifesteal', 'Lifesteal', 'TTN_719t7' } }) do
    local id = 'sparkbot_' .. v[1]
    HS.SPARKBOTS[#HS.SPARKBOTS + 1] = id
    token { id = id, name = 'Sparkbot', hs_id = v[3], atk = 1, hp = 1, mana = 1, tribe = 'Mech',
        kw = { v[1] }, text = { '{C:attention}' .. v[2] .. '{}' } }
end
