-- Balathstone Forbidden Spells (replace Spectral cards)
-- Real Hearthstone spells with big, Spectral-sized effects. They count as
-- Spells for "whenever you cast a Spell" minions.
local HS = Balathstone or Balearthstone
local E = HS.E

local function hand(min, max) return { area = 'hand', min = min or 1, max = max or 1 } end
local function S(t) t.set = 'Spectral'; t.cost = 4; return HS.spell(t) end

S { id = 'astral_communion', name = 'Astral Communion', hs_id = 'AT_043', mana = 5,
    text = { 'Gain 10 Mana Crystals:', '{C:blue}+2{} Turns each round.', '{C:red}Destroy{} all cards in your hand' },
    can = function() return G.hand and #G.hand.cards > 0 end,
    effect = function(card)
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + 2
        if HS.in_round() then ease_hands_played(2) end
        local all = {}
        for _, c in ipairs(G.hand.cards) do all[#all + 1] = c end
        HS.destroy_cards(all, card)
    end }

S { id = 'renounce_darkness', name = 'Renounce Darkness', hs_id = 'OG_118', mana = 2,
    text = { 'Change every card in your', 'hand to one random suit', '{C:inactive}(a new class!){}' },
    can = function() return G.hand and #G.hand.cards > 0 end,
    effect = function(card)
        local suit = HS.pick(HS.SUITS, 'hs_renounce')
        for _, c in ipairs(G.hand.cards) do HS.set_suit(c, suit) end
        HS.say(card, suit .. '!', G.C.FILTER)
    end }

S { id = 'deck_of_lunacy', name = 'Deck of Lunacy', hs_id = 'DMF_108', mana = 2,
    text = { 'Every card in your hand', 'gains {C:attention}+3{} rank', '{C:inactive}(up to Ace){}' },
    can = function() return G.hand and #G.hand.cards > 0 end,
    effect = function(card) for _, c in ipairs(G.hand.cards) do HS.shift_rank(c, 3) end end }

S { id = 'golden_monkey', name = 'Golden Monkey', mana = 4, targets = hand(1, 1),
    text = { 'Add a {C:money}Gold Seal{} to', '1 selected card' },
    effect = function(card, t) t[1]:set_seal('Gold', nil, true) end }

S { id = 'prismatic_lens', name = 'Prismatic Lens', hs_id = 'BOT_436', mana = 4, targets = hand(2, 2),
    text = { 'Select 2 cards in your hand.', 'Swap their ranks, then add', 'a random {C:dark_edition}Edition{} to one' },
    effect = function(card, t)
        local a, b = t[1].base.value, t[2].base.value
        HS.set_rank(t[1], b); HS.set_rank(t[2], a)
        local ed = poll_edition and poll_edition('hs_lens', nil, true, true)
        if ed then HS.pick(t, 'hs_lens_pick'):set_edition(ed, true) end
    end }

S { id = 'doom', name = 'DOOM!', hs_id = 'OG_239', mana = 10,
    text = { 'Destroy all your minions.', 'Draw a card for each' },
    can = function() return #HS.minions() > 0 end,
    effect = function(card)
        local ms = HS.minions()
        for _, m in ipairs(ms) do HS.kill(m, 'destroy') end
        HS.draw(#ms, card)
    end }

S { id = 'myras_unstable_element', name = "Myra's Unstable Element", hs_id = 'BOT_242', mana = 5, in_round = true,
    text = { 'Draw the rest of your deck' },
    effect = function(card) HS.draw(#G.deck.cards, card) end }

S { id = 'corrupting_mist', name = 'Corrupting Mist', hs_id = 'UNG_831', mana = 2,
    text = { 'Curse all your minions: they', 'die at the end of your next turn.', 'Gain {C:money}$4{} for each' },
    can = function() return #HS.minions() > 0 end,
    effect = function(card)
        local ms = HS.minions()
        for _, m in ipairs(ms) do E(m).doomed = true end
        ease_dollars(4 * #ms)
    end }

S { id = 'conceal', name = 'Conceal', hs_id = 'VAN_EX1_128', mana = 1,
    text = { 'Give your minions {C:attention}Stealth{}.', 'The Blind can\'t attack', 'this round' },
    can = function() return #HS.minions() > 0 end,
    effect = function(card)
        for _, m in ipairs(HS.minions()) do HS.give(m, 'stealth'); E(m).stealth_broken = false end
        if HS.in_round() then HS.state().boss_disarmed = true end
    end }

S { id = 'twisting_nether', name = 'Twisting Nether', hs_id = 'VAN_EX1_312', mana = 8,
    text = { 'Destroy {C:red}ALL{} cards in your', 'hand. Gain {C:money}$4{} for each' },
    can = function() return G.hand and #G.hand.cards > 0 end,
    effect = function(card)
        local all = {}
        for _, c in ipairs(G.hand.cards) do all[#all + 1] = c end
        ease_dollars(4 * #all)
        HS.destroy_cards(all, card)
    end }

S { id = 'shadow_essence', name = 'Shadow Essence', hs_id = 'CORE_ICC_235', mana = 6,
    text = { 'Summon a {C:attention}5/5{} copy of a', 'random minion you have' },
    can = function() return #HS.minions() > 0 and HS.board_space() > 0 end,
    effect = function(card)
        local src = HS.pick(HS.minions(), 'hs_essence')
        local c = HS.summon(src.config.center.key, card)
        if c then E(c).attack = 5; E(c).health = 5; E(c).max_health = 5 end
    end }

S { id = 'time_warp', name = 'Time Warp', hs_id = 'UNG_028t', mana = 5, in_round = true,
    text = { 'Take an extra turn:', '{C:blue}+1{} Turn this round' },
    effect = function(card) ease_hands_played(1) end }

S { id = 'sacrificial_pact', name = 'Sacrificial Pact', hs_id = 'VAN_NEW1_003', mana = 0,
    targets = { area = 'jokers', min = 1, max = 1 },
    text = { 'Destroy a selected minion.', 'A random other minion', 'becomes {C:dark_edition}Polychrome{}' },
    can = function() return #HS.minions() >= 2 end,
    effect = function(card, t)
        local others = HS.others(t[1])
        HS.kill(t[1], 'destroy')
        local lucky = HS.pick(others, 'hs_pact')
        if lucky then lucky:set_edition({ polychrome = true }, true) end
    end }

S { id = 'ancestral_knowledge', name = 'Ancestral Knowledge', hs_id = 'CORE_AT_053', mana = 2,
    targets = hand(1, 1),
    text = { 'Add a {C:blue}Blue Seal{} to', '1 selected card' },
    effect = function(card, t) t[1]:set_seal('Blue', nil, true) end }

S { id = 'shadow_visions', name = 'Shadow Visions', hs_id = 'UNG_029', mana = 2, targets = hand(1, 1),
    text = { 'Add a {C:purple}Purple Seal{} to', '1 selected card' },
    effect = function(card, t) t[1]:set_seal('Purple', nil, true) end }

S { id = 'duplicate', name = 'Duplicate', hs_id = 'FP1_018', mana = 3, targets = hand(1, 1),
    text = { 'Add 2 copies of 1 selected', 'card to your hand' },
    effect = function(card, t)
        local desc = HS.describe_card(t[1])
        for _ = 1, 2 do
            local c = copy_card(t[1], nil, nil, G.playing_card)
            c:add_to_deck()
            G.deck.config.card_limit = G.deck.config.card_limit + 1
            table.insert(G.playing_cards, c)
            G.hand:emplace(c)
            c:start_materialize()
        end
    end }

S { id = 'free_from_amber', name = 'Free From Amber', hs_id = 'UNG_854', mana = 8,
    text = { '{C:attention}Summon{} a random', '{C:legendary}Legendary{} minion' },
    can = function() return HS.board_space() > 0 end,
    effect = function(card) HS.summon_random(function(d) return d.rarity == 4 end, card) end }

S { id = 'ultimate_infestation', name = 'Ultimate Infestation', hs_id = 'CORE_ICC_085', mana = 10,
    text = { 'Upgrade every {C:attention}poker hand{}', 'by 1 level' },
    effect = function(card)
        for k, _ in pairs(G.GAME.hands) do level_up_hand(card, k, true, 1) end
        HS.say(card, 'Infested!', G.C.GREEN)
    end }

S { id = 'survival_of_the_fittest', name = 'Survival of the Fittest', hs_id = 'SCH_609', mana = 10,
    text = { 'Give all minions on your', 'board {C:attention}+2/+2{} and', '{X:mult,C:white}X1.5{} Mult permanently' },
    can = function() return #HS.minions() > 0 end,
    effect = function(card)
        for _, m in ipairs(HS.minions()) do
            HS.buff(m, 2, 2)
            local e = E(m)
            if e then e.x_mult = (e.x_mult or 1) * 1.5 end
        end
        HS.say(card, 'Survival!', G.C.MULT)
    end }

S { id = 'shadowform', name = 'Shadowform', hs_id = 'CORE_EX1_625', mana = 3,
    text = { 'Add {C:dark_edition}Negative{} to a random', 'friendly minion.', '{C:red}-1{} Hand Size' },
    can = function() return #HS.minions() > 0 end,
    effect = function(card)
        local m = HS.pick(HS.minions(), 'hs_shadowform')
        if m then
            m:set_edition({ negative = true }, true)
            HS.say(m, 'Negative!', G.C.DARK_EDITION)
        end
        if G.hand then G.hand:change_size(-1) end
    end }
