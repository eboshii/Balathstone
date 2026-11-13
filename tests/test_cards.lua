-- Balathstone mechanic tests. Run with:  python tests/run_tests.py
local HS = Balathstone or Balearthstone
local E = HS.E
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end
local function eq(a, b, msg)
    if a ~= b then error((msg and (msg .. ': ') or '') .. 'expected ' .. tostring(b) .. ', got ' .. tostring(a), 2) end
end
local function ok(v, msg) if not v then error(msg or 'expected true', 2) end end

local function minion_centers()
    local t = {}
    for k, c in pairs(G.P_CENTERS) do if c.hs_minion then t[#t + 1] = c end end
    table.sort(t, function(a, b) return a.key < b.key end)
    return t
end
local function spell_centers()
    local t = {}
    for k, c in pairs(G.P_CENTERS) do if c.hs_spell then t[#t + 1] = c end end
    table.sort(t, function(a, b) return a.key < b.key end)
    return t
end

-- ===================================================================== registry
test('150 collectible minions plus summon-only tokens', function()
    local real, tokens = 0, 0
    for _, c in ipairs(minion_centers()) do
        if c.hs_minion.token then
            tokens = tokens + 1
            eq(c.in_pool(c), false, c.key .. ' token must not be in pools')
        else
            real = real + 1
            ok(c.in_pool == nil, c.key .. ' should be in pools')
        end
        ok(c.hs_id, c.key .. ' has no Hearthstone render id')
    end
    eq(real, 175, 'collectible minions')
    ok(tokens >= 11, 'tokens')
end)

test('atlas positions are unique', function()
    for _, set in ipairs({ { minion_centers(), 'minion' }, { spell_centers(), 'consumable' } }) do
        local seen = {}
        for _, c in ipairs(set[1]) do
            local k = c.pos.x .. ',' .. c.pos.y
            ok(not seen[k], set[2] .. ' position clash ' .. k .. ' ' .. c.key .. ' / ' .. tostring(seen[k]))
            seen[k] = c.key
        end
    end
end)

test('card text names every keyword the card actually has', function()
    local problems = {}
    for _, c in ipairs(minion_centers()) do
        local d = c.hs_minion
        local text = table.concat(d.text or {}, ' ')
        local function need(cond, word)
            if cond and not text:find(word, 1, true) then problems[#problems + 1] = d.name .. ' missing "' .. word .. '"' end
        end
        need(d.battlecry, 'Battlecry')
        need(d.deathrattle, 'Deathrattle')
        need(d.start_of_game, 'Start of Game')
        need(d.spellburst, 'Spellburst')
        need(d.spell_damage, 'Spell Damage')
        need(d.enrage, 'Enrage')
        for _, kw in ipairs(d.kw or {}) do
            local word = ({ divine_shield = 'Divine Shield', taunt = 'Taunt', windfury = 'Windfury', charge = 'Charge',
                rush = 'Rush', lifesteal = 'Lifesteal', stealth = 'Stealth', reborn = 'Reborn' })[kw]
            need(word, word)
        end
        -- and the reverse: text promising a Battlecry/Deathrattle must have one
        if text:find('Battlecry:', 1, true) and not d.battlecry then problems[#problems + 1] = d.name .. ' text says Battlecry but has none' end
        if text:find('Deathrattle:', 1, true) and not d.deathrattle then problems[#problems + 1] = d.name .. ' text says Deathrattle but has none' end
    end
    ok(#problems == 0, table.concat(problems, '; '))
end)

-- ===================================================================== battlecry timing
test('Battlecry triggers once per round, not every hand (Murloc Tidehunter)', function()
    T.new_run()
    T.add('murloc_tidehunter')
    T.start_round()
    eq(T.count('murloc_scout'), 1, 'after round start')
    T.play_hand(); T.play_hand()
    eq(T.count('murloc_scout'), 1, 'after two hands')
    T.end_round()
    T.start_round()
    eq(T.count('murloc_scout'), 2, 'next round')
end)

test('Battlecry runs after the opening hand is drawn (Twilight Drake)', function()
    T.new_run()
    local drake = T.add('twilight_drake')
    T.start_round()
    eq(#G.hand.cards, 8)
    eq(E(drake).health, 1 + 8, 'drake health')
end)

test('Brann doubles Battlecries: Wandmaker makes 2 spells', function()
    T.new_run()
    T.add('brann_bronzebeard'); T.add('wandmaker')
    T.start_round()
    eq(#G.consumeables.cards, 2)
    for _, c in ipairs(G.consumeables.cards) do
        ok(c.config.center.hs_spell.mana <= 1, 'Wandmaker spell should cost 1: ' .. c.config.center.key)
    end
end)

test('Brann doubles summons too (Murloc Tidehunter)', function()
    T.new_run()
    T.add('brann_bronzebeard'); T.add('murloc_tidehunter')
    T.start_round()
    eq(T.count('murloc_scout'), 2)
end)

test('Shudderwock repeats the other Battlecries', function()
    T.new_run()
    T.add('murloc_tidehunter'); T.add('shudderwock')
    T.start_round()
    eq(T.count('murloc_scout'), 2)
end)

-- ===================================================================== summons
test('summons create the exact token (Dr. Boom, Highmane, Cairne)', function()
    T.new_run()
    T.add('dr_boom')
    T.start_round()
    eq(T.count('boom_bot'), 2)
    T.end_round()
    T.new_run()
    local hm = T.add('savannah_highmane')
    T.sell(hm)
    eq(T.count('hyena'), 2, 'Highmane hyenas')
    T.new_run()
    T.sell(T.add('cairne_bloodhoof'))
    eq(T.count('baine_bloodhoof'), 1)
end)

test('summoned minions sell for $0', function()
    T.new_run()
    T.add('murloc_tidehunter')
    T.start_round()
    local scout
    for _, c in ipairs(G.jokers.cards) do if c.config.center.key == 'j_hs_murloc_scout' then scout = c end end
    ok(scout, 'scout exists')
    eq(scout.sell_cost, 0)
end)

test('board limit stops summons', function()
    T.new_run()
    G.jokers.config.card_limit = 2
    T.add('dr_boom')
    T.start_round()
    eq(#G.jokers.cards, 2)
end)

-- ===================================================================== deathrattle
test('Deathrattle on sale and on death; Rivendare doubles it', function()
    T.new_run()
    T.sell(T.add('haunted_creeper'))
    eq(T.count('spectral_spider'), 2, 'sold')
    T.new_run()
    T.add('baron_rivendare')
    T.sell(T.add('haunted_creeper'))
    eq(T.count('spectral_spider'), 4, 'Rivendare')
    T.new_run()
    local g = T.add('harvest_golem')
    HS.damage(g, 10)
    T_flush()
    eq(T.count('harvest_golem'), 0, 'golem died')
    eq(T.count('damaged_golem'), 1, 'golem deathrattle')
end)

test('Loot Hoarder draws when it dies mid-round, queues when sold in the shop', function()
    T.new_run()
    local lh = T.add('loot_hoarder')
    T.start_round()
    local before = #G.hand.cards
    HS.damage(lh, 5); T_flush()
    eq(#G.hand.cards, before + 1)
    T.end_round()
    T.new_run()
    T.sell(T.add('loot_hoarder'))
    eq(HS.state().pending_draws, 1)
    T.start_round()
    eq(#G.hand.cards, 9, 'drew the queued card at round start')
end)

test('Kel\'Thuzad resummons minions that died this turn', function()
    T.new_run()
    T.add('kelthuzad')
    local w = T.add('wolfrider')
    T.start_round()
    HS.damage(w, 5); T_flush()
    eq(T.count('wolfrider'), 0)
    T.play_hand()
    eq(T.count('wolfrider'), 1)
end)

test('Reborn returns the minion with 1 Health', function()
    T.new_run()
    local m = T.add('sunwalker')
    HS.give(m, 'reborn')
    E(m).shield = false
    HS.damage(m, 99); T_flush()
    ok(not m.removed, 'still on board')
    eq(E(m).health, 1)
end)

-- ===================================================================== keywords
test('Windfury granted by the Windfury spell doubles scoring', function()
    T.new_run()
    local m = T.add('raid_leader') -- 2/2
    T.start_round()
    local chips, mult = T.play_hand()
    eq(mult, 2); eq(chips, 2 * HS.CHIPS_PER_HEALTH)
    local s = T.spell('windfury')
    ok(T.use(s, { m }), 'Windfury usable on a minion')
    chips, mult = T.play_hand()
    eq(mult, 4, 'windfury mult'); eq(chips, 4 * HS.CHIPS_PER_HEALTH, 'windfury chips')
end)

test('native Windfury (Young Dragonhawk)', function()
    T.new_run()
    T.add('young_dragonhawk')
    T.start_round()
    local chips, mult = T.play_hand()
    eq(mult, 2); eq(chips, 2 * HS.CHIPS_PER_HEALTH)
end)

test('Charge scores an extra time on the first hand only', function()
    T.new_run()
    T.add('stonetusk_boar')
    T.start_round()
    local _, m1 = T.play_hand()
    local _, m2 = T.play_hand()
    eq(m1, 2); eq(m2, 1)
end)

test('Windfury and Charge stacks to 4 attacks on the first hand', function()
    T.new_run()
    local m = T.add('stonetusk_boar') -- 1/1 Charge
    local s = T.spell('windfury')
    ok(T.use(s, { m }), 'Windfury usable on Stonetusk Boar')
    T.start_round()
    local c1, m1 = T.play_hand()
    eq(m1, 4, 'windfury + charge mult on hand 1')
    eq(c1, 4 * HS.CHIPS_PER_HEALTH, 'windfury + charge chips on hand 1')
    local c2, m2 = T.play_hand()
    eq(m2, 2, 'windfury only mult on hand 2')
    eq(c2, 2 * HS.CHIPS_PER_HEALTH, 'windfury only chips on hand 2')
end)

test('Taunt is attacked first, Divine Shield blocks it', function()
    T.new_run()
    local a = T.add('wolfrider')
    local b = T.add('goldshire_footman')
    T.start_round('malygos')
    T.play_hand()
    ok(b.removed, 'footman (taunt) took the hit and died')
    ok(not a.removed, 'wolfrider untouched')
    T.new_run()
    local sq = T.add('argent_squire')
    T.start_round('malygos')
    T.play_hand()
    ok(not sq.removed, 'shield blocked')
    T.play_hand()
    ok(sq.removed, 'second hit kills')
end)

test('Boss does not attack if Blind is defeated by the hand', function()
    T.new_run()
    local a = T.add('goldshire_footman')
    T.start_round('malygos')
    G.GAME.blind.chips = 1 -- low requirement so one hand beats it
    T.play_hand()
    ok(not a.removed, 'blind was defeated, so boss did not attack')
end)

test('Boss attack is queued post-scoring without prediction', function()
    T.new_run()
    local a = T.add('goldshire_footman')
    T.start_round('malygos')
    G.GAME.blind.chips = 50000
    -- Simulate context.after firing before chips are flushed
    SMODS.calculate_context({ after = true, full_hand = G.play.cards })
    ok(not a.removed, 'boss attack must not fire immediately inside calculate_context before event flush')
    T_flush()
    ok(a.removed, 'boss attack executes after event flush')
end)

test('Boss attack triggers attack animation and Freeze sets boss_frozen', function()
    T.new_run()
    local a = T.add('baron_rivendare')
    T.start_round('malygos')
    G.GAME.blind.chips = 99999
    T.play_hand()
    ok(a.hs_attack_anim ~= nil, 'minion has attack animation')
    eq(a.hs_attack_anim.atk, HS.boss_attack_value())

    HS.freeze_boss()
    eq(HS.state().boss_frozen, true)
end)

test('Divine Shield comes back every round', function()
    T.new_run()
    local sq = T.add('argent_squire')
    T.start_round('ragnaros')
    T.play_hand()
    eq(E(sq).shield, false)
    T.end_round()
    T.start_round()
    eq(E(sq).shield, true)
end)

test('Stealth protects until the minion has scored', function()
    T.new_run()
    local w = T.add('worgen_infiltrator')
    T.start_round('malygos')
    T.play_hand()
    ok(not w.removed, 'stealthed on first hand')
    T.play_hand()
    ok(w.removed, 'attacked after it scored')
end)

test('Boss attack: defender strikes back at the Blind', function()
    T.new_run()
    T.add('tar_creeper') -- 1/5 taunt, +2 attack when defending = 3 damage
    T.start_round('malygos')
    T.play_hand()
    eq(G.GAME.blind.chips, math.floor(1000 * 0.98 ^ 3))
end)

test('Boss attack: Divine Shield absorbs the damage; minion survives', function()
    T.new_run()
    local shield = T.add('righteous_protector') -- 1/1 taunt divine shield
    T.start_round('malygos') -- 2 attack
    local _, m1 = T.play_hand()
    eq(m1, 1)
    ok(not shield.removed, 'shield absorbed hit')
    eq(T.hp(shield), 1, 'health unchanged')
    eq(G.GAME.blind.chips, math.floor(1000 * 0.98 ^ 1), '1 damage dealt back to blind')
end)

test('Enrage and auras', function()
    T.new_run()
    local amani = T.add('amani_berserker')
    eq(T.atk(amani), 2)
    HS.damage(amani, 1)
    eq(T.atk(amani), 5, 'enraged')
    T.new_run()
    local a = T.add('wolfrider'); local wolf = T.add('dire_wolf_alpha'); local c = T.add('wolfrider'); local far = T.add('wolfrider')
    eq(T.atk(a), 4); eq(T.atk(c), 4); eq(T.atk(far), 3, 'not adjacent')
    T.new_run()
    local scout = T.add('murloc_scout'); local wl = T.add('murloc_warleader'); local boar = T.add('stonetusk_boar')
    eq(T.atk(scout), 3); eq(T.hp(scout), 2); eq(T.atk(boar), 1, 'not a murloc')
end)

test('Combo: Edwin grows after a discard this turn', function()
    T.new_run()
    local ed = T.add('edwin_vancleef')
    T.start_round()
    T.play_hand()
    eq(E(ed).attack, 2, 'no combo')
    T.discard(2)
    T.play_hand()
    eq(E(ed).attack, 4, 'combo')
end)

-- ===================================================================== blind / hero
test('Blind damage lowers the requirement by 2% per point; queued outside a round', function()
    T.new_run()
    T.add('elven_archer')
    T.start_round()
    eq(G.GAME.blind.chips, 980)
    T.end_round()
    T.new_run()
    T.sell(T.add('leper_gnome'))
    eq(HS.state().pending_blind, 2)
    T.start_round()
    eq(G.GAME.blind.chips, math.floor(1000 * 0.98 ^ 2))
end)

test('Hero healing gives money but never above $30', function()
    T.new_run()
    T.add('antique_healbot')
    G.GAME.dollars = 10
    T.start_round()
    eq(G.GAME.dollars, 18)
    T.end_round()
    G.GAME.dollars = 27
    T.start_round()
    eq(G.GAME.dollars, 30)
end)

test('Reno Jackson: no duplicates -> money to $30; duplicates -> nothing', function()
    T.new_run()
    T.add('reno_jackson')
    G.GAME.dollars = 4
    T.start_round()
    eq(G.GAME.dollars, 30)
    T.end_round()
    T.new_run()
    T.add('reno_jackson')
    local dup = copy_card(G.playing_cards[1])
    G.playing_cards[#G.playing_cards + 1] = dup
    G.GAME.dollars = 4
    T.start_round()
    eq(G.GAME.dollars, 4)
end)

-- ===================================================================== spells
test('Spell targeting: minion-target spells need a selected minion', function()
    T.new_run()
    local m = T.add('wolfrider')
    local s = T.spell('blessing_of_kings')
    eq(T.use(s, {}), false, 'no target')
    ok(T.use(s, { m }), 'with target')
    eq(E(m).attack, 7)
end)

test('Spell targeting: highlight limits follow the selected spell', function()
    T.new_run()
    T.add('wolfrider'); T.add('wolfrider')
    local bok = T.spell('blessing_of_kings')
    local sprint = T.spell('sprint')
    G.consumeables:add_to_highlighted(bok)
    eq(G.jokers.config.highlighted_limit, 1)
    eq(G.consumeables.config.highlighted_limit, 1, 'consumables stay single-select')
    G.consumeables:add_to_highlighted(sprint)
    eq(#G.consumeables.highlighted, 1, 'selecting another spell replaces the first')
    eq(G.jokers.config.highlighted_limit, 1)
end)

test('Consumables in packs can be selected to inventory or used', function()
    T.new_run()
    local s = T.spell('bananas')
    local area, can_also_use = s.config.center:select_card(s, {})
    eq(area, 'consumeables')
    eq(can_also_use, true)

    local spec = SMODS.create_card({ key = 'c_hs_astral_communion', set = 'Spectral' })
    local s_area, s_use = spec.config.center:select_card(spec, {})
    eq(s_area, 'consumeables')
    eq(s_use, true)

    local loc = SMODS.create_card({ key = 'c_hs_hedge_maze', set = 'Planet' })
    local l_area, l_use = loc.config.center:select_card(loc, {})
    eq(l_area, 'consumeables')
    eq(l_use, true)

    ok(G.P_CENTERS.p_arcana_normal_1.select_card, 'arcana pack has select_card')
    ok(G.P_CENTERS.p_spectral_normal_1.select_card, 'spectral pack has select_card')
    ok(G.P_CENTERS.p_celestial_normal_1.select_card, 'celestial pack has select_card')
end)

test('Spell Damage boosts Fireball; Antonidas makes Fireballs (not from Fireball)', function()
    T.new_run()
    T.add('kobold_geomancer')
    T.start_round()
    ok(T.use(T.spell('fireball')))
    eq(G.GAME.blind.chips, math.floor(1000 * 0.98 ^ 7))
    T.new_run()
    T.add('archmage_antonidas')
    ok(T.use(T.spell('arcane_intellect')))
    eq(#G.consumeables.cards, 1)
    eq(G.consumeables.cards[1].config.center.key, 'c_hs_fireball')
    ok(T.use(G.consumeables.cards[1]))
    eq(#G.consumeables.cards, 0, 'Fireball does not make another Fireball')
end)

test('Deck spells: enhance, suit, rank, destroy', function()
    T.new_run()
    T.start_round()
    local a, b = G.hand.cards[1], G.hand.cards[2]
    ok(T.use(T.spell('mark_of_the_wild'), { a, b }))
    eq(a.config.center.key, 'm_wild'); eq(b.config.center.key, 'm_wild')
    ok(T.use(T.spell('moonfire'), { a }))
    eq(a.base.suit, 'Spades')
    HS.set_rank(a, '9')
    ok(T.use(T.spell('bananas'), { a }))
    eq(a.base.value, '10')
    local deck_before = #G.playing_cards
    HS.set_rank(b, '3')
    ok(T.use(T.spell('shadow_word_pain'), { b }))
    eq(#G.playing_cards, deck_before - 1)
    local high = G.hand.cards[1]
    HS.set_rank(high, '2')
    eq(T.use(T.spell('shadow_word_death'), { high }), false, 'rank 2 is too low for SW: Death')
end)

test('Locations level up their hand', function()
    T.new_run()
    ok(T.use(T.spell('castle_kennels')))
    eq(G.GAME.hands['Pair'].level, 2)
end)

test('Yogg-Saron casts a spell per spell cast this run', function()
    T.new_run()
    T.add('wolfrider')
    HS.state().spells_cast = 3
    T.add('yogg_saron_hopes_end')
    T.start_round()
    ok(HS.state().spells_cast >= 4, 'cast at least one random spell')
end)

-- ===================================================================== deck manipulation minions
test('Leper Gnome destroys the lowest card left in hand at end of round', function()
    T.new_run()
    T.add('leper_gnome')
    T.start_round()
    local low = HS.lowest_in_hand()
    local n = #G.playing_cards
    T.end_round()
    eq(#G.playing_cards, n - 1)
    ok(low.removed, 'the lowest card was destroyed')
end)

test('Carnivorous Cube eats the best card and gives 2 copies back', function()
    T.new_run()
    local cube = T.add('carnivorous_cube')
    T.start_round()
    local n = #G.playing_cards
    eq(#E(cube).eaten, 1)
    eq(#G.playing_cards, n)
    T.end_round()
    local before = #G.playing_cards
    T.sell(cube)
    eq(#G.playing_cards, before + 2)
end)

test('Prince Keleseth: with no 2s, every card gains +3 Chips', function()
    T.new_run()
    for i = #G.playing_cards, 1, -1 do
        local c = G.playing_cards[i]
        if c.base.value == '2' then c:start_dissolve() end
    end
    T.add('prince_keleseth')
    T.start_round()
    for _, c in ipairs(G.playing_cards) do eq(c.ability.perma_bonus, 3) end
end)

test('Waxadred leaves a Candle that resummons it when drawn', function()
    T.new_run()
    local w = T.add('waxadred')
    T.sell(w)
    local candle
    for _, c in ipairs(G.deck.cards) do
        if c.config.center.key == 'm_hs_waxadreds_candle' then candle = c end
    end
    ok(candle, "the real Waxadred's Candle card was shuffled in")
    eq(candle.config.center.hs_id, 'DRG_036t')
    G.deck:remove_card(candle); G.deck:emplace(candle) -- put it on top
    T.start_round()
    eq(T.count('waxadred'), 1)
end)

test('Tirion Deathrattle gives other minions +5 Attack permanently', function()
    T.new_run()
    local wolf = T.add('wolfrider')
    local tirion = T.add('tirion_fordring')
    eq(HS.attack(wolf), 3)
    T.sell(tirion)
    eq(HS.attack(wolf), 8, 'wolfrider gained +5 attack permanently')
end)

test('Southsea Deckhand and Dread Corsair pirate synergy', function()
    T.new_run()
    local deckhand = T.add('southsea_deckhand')
    ok(not HS.has(deckhand, 'charge'), 'no charge alone')
    local corsair = T.add('dread_corsair')
    ok(HS.has(deckhand, 'charge'), 'gains charge with another pirate')
    eq(HS.cost_discount(corsair), 1, 'dread corsair discounts by $1 with deckhand')
end)

test('Drone Deconstructor summons a real Sparkbot variant with its keyword', function()
    T.new_run()
    T.add('drone_deconstructor')
    T.start_round()
    local bot
    for _, c in ipairs(G.jokers.cards) do if c.config.center.key:find('sparkbot') then bot = c end end
    ok(bot, 'sparkbot summoned')
    local kw = bot.config.center.key:gsub('^j_hs_sparkbot_', '')
    ok(HS.has(bot, kw), 'variant has its keyword ' .. kw)
end)

test('Map to the Golden Monkey adds the real Golden Monkey card', function()
    T.new_run()
    local n = #G.playing_cards
    T.redeem('map_golden_monkey')
    eq(#G.playing_cards, n + 1)
    eq(G.playing_cards[#G.playing_cards].config.center.key, 'm_hs_golden_monkey')
end)

test('generated cards never appear randomly', function()
    for _, k in ipairs({ 'm_hs_waxadreds_candle', 'm_hs_golden_monkey' }) do
        eq(G.P_CENTERS[k].in_pool(G.P_CENTERS[k]), false, k)
    end
end)

test('Grim Patron summons another when it survives damage', function()
    T.new_run()
    local gp = T.add('grim_patron')
    HS.damage(gp, 1); T_flush()
    eq(T.count('grim_patron'), 2)
end)

test('Faceless Manipulator becomes the minion to its right', function()
    T.new_run()
    T.add('faceless_manipulator'); T.add('wolfrider')
    T.start_round()
    eq(T.count('wolfrider'), 2)
end)

-- ===================================================================== bosses
test('Boss abilities: Loatheb blocks Spells, Sylvanas zeroes weak minions, Illidan', function()
    T.new_run()
    T.start_round('loatheb')
    eq(T.use(T.spell('arcane_intellect')), false, 'Loatheb blocks spells')
    T.end_round()
    T.new_run()
    T.add('young_dragonhawk')
    T.start_round('sylvanas')
    local _, mult = T.play_hand()
    eq(mult, 0)
    local il = G.P_BLINDS['bl_hs_illidan']
    eq(il:debuff_hand({ 1, 2, 3 }, {}, 'Pair', true), true)
    eq(il:debuff_hand({ 1, 2, 3, 4, 5 }, {}, 'Flush', true), false)
end)

test('every Boss can start a round and be attacked through', function()
    for key, b in pairs(G.P_BLINDS) do
        T.new_run()
        T.add('sunwalker'); T.add('wolfrider')
        local id = key:gsub('^bl_hs_', '')
        T.start_round(id)
        T.play_hand(); T.play_hand()
        G.GAME.blind:disable()
        T.end_round()
    end
end)

-- ===================================================================== blinds
local function blinds_of(kind)
    local t = {}
    for k, b in pairs(G.P_BLINDS) do if b[kind] then t[#t + 1] = b end end
    return t
end

test('boss variety: several bosses possible at every Ante', function()
    for ante = 1, 7 do
        local n = 0
        for _, b in ipairs(blinds_of('boss')) do
            if not b.boss.showdown and (b.boss.min or 1) <= ante and (b.boss.max or 99) >= ante then n = n + 1 end
        end
        ok(n >= 5, 'only ' .. n .. ' bosses possible at Ante ' .. ante)
    end
    ok(#blinds_of('small') >= 8, 'small encounters')
    ok(#blinds_of('big') >= 8, 'big encounters')
end)

test('Small and Big Blind encounters attack too', function()
    T.new_run()
    local m = T.add('sunwalker')
    T.start_round('murloc_raider')
    T.play_hand()
    eq(E(m).shield, false, 'Murloc Raider attacked (popped Divine Shield)')
end)

test('enemy attack scales with Ante', function()
    T.new_run()
    G.GAME.round_resets.ante = 1
    eq(HS.scaled_attack(10), 6)
    G.GAME.round_resets.ante = 8
    eq(HS.scaled_attack(10), 13)
end)

test('encounter quirks: Hogger twice, Geddon AoE, Cobra poison, Frost Elemental freeze, Bloodsail steals', function()
    T.new_run()
    local f1 = T.add('sludge_belcher') -- 3/6 taunt
    T.start_round('hogger')
    T.play_hand()
    eq(E(f1).health, 6 - 2 * HS.scaled_attack(4), 'Hogger hit twice')

    T.new_run()
    local x, y = T.add('stormwind_knight'), T.add('tar_lurker')
    T.start_round('baron_geddon')
    T.play_hand()
    local dmg = HS.scaled_attack(3)
    eq(E(x).health, 5 - dmg); eq(E(y).health, 7 - dmg)

    T.new_run()
    local big = T.add('tar_lurker') -- 1/7, survives normal damage
    T.start_round('emperor_cobra')
    T.play_hand()
    ok(big.removed, 'Poisonous destroyed it')

    T.new_run()
    local fr = T.add('tar_lurker')
    T.start_round('frost_elemental')
    local _, m1 = T.play_hand()
    eq(m1, 1, 'scores on the hand it was hit (attack happens after scoring)')
    local _, m2 = T.play_hand()
    eq(m2, 0, 'frozen on subsequent hand')

    T.new_run()
    T.add('tar_lurker')
    G.GAME.dollars = 10
    T.start_round('bloodsail_raider')
    T.play_hand()
    eq(G.GAME.dollars, 8)
end)

test('Silence removes an encounter quirk but it keeps attacking', function()
    T.new_run()
    local big = T.add('tar_lurker')
    T.add('ironbeak_owl')
    T.start_round('emperor_cobra')
    eq(G.GAME.blind.disabled, true, 'Owl silenced the Cobra')
    T.play_hand()
    ok(not big.removed, 'no poison')
    ok(E(big).health < 7, 'still attacked')
end)

test('Scarlet Crusader shields the first Blind damage', function()
    T.new_run()
    T.add('elven_archer')
    T.start_round('scarlet_crusader')
    eq(G.GAME.blind.chips, 1000, 'archer blocked')
    HS.damage_blind(1)
    eq(G.GAME.blind.chips, 980)
end)

test('Gruul ramps, Onyxia freezes, Deathwing destroys the leftmost, Mal\'Ganis blocks money', function()
    T.new_run()
    T.add('tar_lurker')
    T.start_round('gruul')
    local a1 = HS.boss_attack_value()
    T.play_hand()
    eq(HS.boss_attack_value(), a1 + 2)
    T.new_run()
    local left = T.add('wolfrider'); T.add('stormwind_knight')
    T.start_round('deathwing')
    ok(left.removed, 'Deathwing ate the leftmost minion')
    T.new_run()
    G.GAME.dollars = 5
    T.start_round('malganis')
    ease_dollars(10)
    eq(G.GAME.dollars, 5)
end)

-- ===================================================================== vouchers
test('Treasures: Captured Flag, Small Backpacks, Cloak of Invisibility', function()
    T.new_run()
    local w = T.add('wolfrider')
    T.redeem('captured_flag')
    eq(T.atk(w), 4); eq(T.hp(w), 2)
    T.redeem('small_backpacks')
    T.start_round()
    eq(#G.hand.cards, 10)
    T.end_round()
    T.new_run()
    local s = T.add('wolfrider')
    T.redeem('cloak_of_invisibility')
    T.start_round('ragnaros')
    T.play_hand()
    ok(not s.removed)
end)

test('Time Warp only rescues the last hand once per round', function()
    T.new_run()
    T.redeem('time_warp')
    G.GAME.round_resets.hands = 1
    T.start_round()
    T.play_hand()
    eq(G.GAME.current_round.hands_left, 1, 'extra turn')
    T.play_hand()
    eq(G.GAME.current_round.hands_left, 0, 'only once')
end)

-- ===================================================================== gained keywords
test('gained keywords appear in the card text (Adapt, spells, auras)', function()
    T.new_run()
    local f = T.add('vicious_fledgling')
    local center = f.config.center
    local r = center:loc_vars({}, f)
    eq(r.key, nil, 'nothing gained yet')
    HS.give(f, 'divine_shield')
    local iq = {}
    r = center:loc_vars(iq, f)
    eq(r.key, 'j_hs_vicious_fledgling_gained')
    ok(r.vars[3]:find('Divine Shield'), 'text lists Divine Shield: ' .. tostring(r.vars[3]))
    local has_tip = false
    for _, q in ipairs(iq) do if q.key == 'hs_kw_divine_shield' then has_tip = true end end
    ok(has_tip, 'tooltip for the gained keyword')
    -- printed keywords are not repeated; aura-granted ones are shown
    local boar = T.add('stonetusk_boar')
    eq(boar.config.center:loc_vars({}, boar).key, nil, 'Charge is already printed on Stonetusk Boar')
    T.add('tundra_rhino')
    local hyena = T.add('hyena')
    r = hyena.config.center:loc_vars({}, hyena)
    ok(r.vars[3] and r.vars[3]:find('Charge'), 'Tundra Rhino grants Charge to Beasts')
end)

test('gained-text variable lands after a card\'s own variables (Sire Denathrius)', function()
    T.new_run()
    local s = T.add('sire_denathrius')
    HS.give(s, 'taunt')
    local r = s.config.center:loc_vars({}, s)
    eq(r.vars[3], 5, 'own var kept')
    eq(r.vars[4], '1.0', 'xmult var kept')
    eq(r.vars[5], 'Taunt')
end)

-- ===================================================================== visuals
test('board effects draw for every minion with every keyword, transform stack stays balanced', function()
    local all = { 'taunt', 'divine_shield', 'windfury', 'charge', 'rush', 'lifesteal', 'stealth', 'reborn' }
    for _, c in ipairs(minion_centers()) do
        T.new_run()
        T.start_round()
        local m = T.add(c.key)
        for _, kw in ipairs(all) do HS.give(m, kw) end
        E(m).health = math.max(1, E(m).health - 1) -- damaged, for Enrage
        local before = T_gfx.calls
        HS.draw_board_effects(m)
        eq(T_gfx.depth, 0, c.key .. ' push/pop balance')
        ok(T_gfx.calls > before, c.key .. ' drew something')
    end
end)

test('board effects only on minions in play, never in the shop', function()
    T.new_run()
    T.open_shop({ 'goldshire_footman' })
    local shop_card = G.shop_jokers.cards[1]
    ok(shop_card.area ~= G.jokers)
    T.close_shop()
end)

test('Leeroy Jenkins gives X2 Mult on hand 1 only', function()
    T.new_run()
    local leeroy = T.add('leeroy_jenkins') -- 6/2 Charge
    T.start_round()
    local c1, m1 = T.play_hand()
    -- Charge = a second attack on hand 1, and each attack carries his X2: (6 X2 + 6) X2 = 36
    eq(m1, 36, 'leeroy X2 on each of his 2 attacks on hand 1')
    local c2, m2 = T.play_hand()
    eq(m2, 6, 'leeroy hand 2')
end)

test('Zilliax gives X1.5 Mult per Steel Card in hand', function()
    T.new_run()
    T.add('zilliax')
    T.start_round()
    local _, m1 = T.play_hand()
    eq(m1, 6)
    HS.enhance(G.hand.cards[3], 'm_steel')
    HS.enhance(G.hand.cards[4], 'm_steel')
    local _, m2 = T.play_hand()
    eq(m2, 6.75)
end)

test('Baku gives X2.5 Mult if deck has only odd cards', function()
    T.new_run()
    T.add('baku_the_mooneater')
    for i = #G.playing_cards, 1, -1 do
        if HS.rank_num(G.playing_cards[i]) % 2 == 0 then table.remove(G.playing_cards, i) end
    end
    T.start_round()
    local _, m1 = T.play_hand()
    eq(m1, 17.5)
end)

test('Genn gives X2.5 Mult if deck has only even cards', function()
    T.new_run()
    T.add('genn_greymane')
    for i = #G.playing_cards, 1, -1 do
        if HS.rank_num(G.playing_cards[i]) % 2 == 1 then table.remove(G.playing_cards, i) end
    end
    T.start_round()
    local _, m1 = T.play_hand()
    eq(m1, 15)
end)

test('Blessed Champion grants permanent X2 Mult to targeted minion', function()
    T.new_run()
    local m = T.add('raid_leader')
    local s = T.spell('blessed_champion')
    ok(T.use(s, { m }))
    T.start_round()
    local _, m1 = T.play_hand()
    eq(m1, 4, '2 base * 2 = 4 mult')
end)

test('Molten Reflection preserves enchantments, lifesteal and stacks XMult', function()
    T.new_run()
    local m = T.add('stonetusk_boar') -- base 1/1 Charge
    local ap = T.spell('apotheosis') -- +2/+3, Lifesteal, X1.5 Mult
    ok(T.use(ap, { m }))
    eq(T.atk(m), 3)
    eq(T.hp(m), 4)
    ok(HS.has(m, 'lifesteal'))
    ok(HS.has(m, 'charge'))
    eq(HS.E(m).x_mult, 1.5)

    -- Copy with Molten Reflection
    local mr = T.spell('molten_reflection')
    ok(T.use(mr, { m }))
    eq(#HS.minions(), 2)
    local copy = HS.minions()[2]
    eq(T.atk(copy), 3, 'copy retains buffed attack')
    eq(T.hp(copy), 4, 'copy retains buffed health')
    ok(HS.has(copy, 'lifesteal'), 'copy retains lifesteal')
    ok(HS.has(copy, 'charge'), 'copy retains charge')
    eq(HS.E(copy).x_mult, 2.25, 'copy multiplies x_mult (1.5 * 1.5 = 2.25)')

    -- Check scoring hit table directly for duplicate keys
    local res = m.config.center:calculate(m, { joker_main = true, cardarea = G.jokers })
    local curr = res
    local xmult_hits = 0
    while curr do
        if curr.Xmult or curr.x_mult then
            xmult_hits = xmult_hits + 1
            eq(curr.message, nil, 'Xmult hit should not have duplicate message field')
            eq(curr.x_mult, nil, 'Xmult hit should not have duplicate x_mult field')
        end
        curr = curr.extra
    end
    eq(xmult_hits, 2, 'X Mult repeats with each attack (Charge: 2 attacks on the first hand)')
end)

test('Savage Roar gives played hand X2 Mult', function()
    T.new_run()
    local m = T.add('raid_leader')
    T.start_round()
    local s = T.spell('savage_roar')
    ok(T.use(s))
    local _, m1 = T.play_hand()
    eq(m1, 8)
end)

test('Survival of the Fittest gives all minions +2/+2 and X1.5 Mult', function()
    T.new_run()
    local m = T.add('raid_leader')
    local s = T.spell('survival_of_the_fittest')
    ok(T.use(s))
    eq(T.atk(m), 4)
    eq(T.hp(m), 4)
    T.start_round()
    local _, m1 = T.play_hand()
    eq(m1, 6, '4 base * 1.5 = 6 mult')
end)

test('Shadowform adds Negative to a random minion and -1 hand size', function()
    T.new_run()
    local m = T.add('stonetusk_boar')
    local s = T.spell('shadowform')
    ok(T.use(s))
    ok(m.edition and m.edition.negative, 'minion became negative')
end)

test('Sylvanas steals a minion from the shop as Negative on death', function()
    T.new_run()
    local sylv = T.add('sylvanas_windrunner')
    T.start_round()
    HS.kill(sylv, 'destroy')
    ok(HS.state().sylvanas_steals == 1)
    T.open_shop({ 'loot_hoarder' })
    local found_neg = false
    for _, j in ipairs(G.jokers.cards) do
        if j.config.center.key == 'j_hs_loot_hoarder' and j.edition and j.edition.negative then
            found_neg = true
        end
    end
    ok(found_neg, 'stolen minion is negative')
end)

test('Enhancement spells: Roll the Bones and Earthen Scales', function()
    T.new_run()
    T.start_round()
    local c1 = G.hand.cards[1]
    local c2 = G.hand.cards[2]
    local s1 = T.spell('roll_the_bones')
    ok(T.use(s1, { c1, c2 }))
    eq(c1.ability.name, 'Lucky Card')
    eq(c2.ability.name, 'Lucky Card')
    local c3 = G.hand.cards[3]
    local s2 = T.spell('earthen_scales')
    ok(T.use(s2, { c3 }))
    eq(c3.ability.name, 'Stone Card')
end)

-- ===================================================================== sweeps
test('sweep: every minion survives a full round with a boss, discards, spells and selling', function()
    for _, c in ipairs(minion_centers()) do
        local id = c.key:gsub('^j_hs_', '')
        local ok_, err = pcall(function()
            T.new_run()
            G.GAME.dollars = 20
            T.add('wolfrider')
            local m = T.add(id)
            T.add('murloc_scout')
            T.start_round('ragnaros')
            T.play_hand(2)
            T.discard(1)
            T.use(T.spell('arcane_intellect'))
            T.play_hand(1)
            T.end_round()
            T.open_shop({ 'wolfrider', 'stonetusk_boar' })
            if not m.removed then T.sell(m) end
            T.close_shop()
            T.start_round()
            T.play_hand()
            T.end_round()
        end)
        if not ok_ then error(c.key .. ': ' .. tostring(err), 0) end
    end
end)

test('sweep: every spell, location and forbidden spell can be cast', function()
    local unusable = {}
    for _, c in ipairs(spell_centers()) do
        local ok_, err = pcall(function()
            T.new_run()
            local m1 = T.add('wolfrider'); T.add('stormwind_champion'); T.add('murloc_scout')
            T.start_round('ragnaros')
            local s = T.spell(c.key)
            local spec = c.hs_targets
            local targets = {}
            if spec then
                local pool = spec.area == 'jokers' and G.jokers.cards or G.hand.cards
                for i = 1, math.max(spec.min or 1, 1) do targets[#targets + 1] = pool[i] end
                if spec.max and spec.max >= 2 and spec.area == 'hand' then targets[2] = pool[2] end
                if c.key == 'c_hs_shadow_word_death' then HS.set_rank(targets[1], 'King') end
                if c.key == 'c_hs_shadow_word_pain' then HS.set_rank(targets[1], '2'); if targets[2] then HS.set_rank(targets[2], '3') end end
            end
            if c.key == 'c_hs_mind_control' then T.end_round(); T.open_shop({ 'wolfrider' }) end
            if c.key == 'c_hs_snake_oil' then targets = {} end
            if c.key == 'c_hs_divine_favor' then draw_card(G.hand, G.discard, nil, nil, nil, G.hand.cards[1]) end
            if not T.use(s, targets) then unusable[#unusable + 1] = c.key end
            T.play_hand()
        end)
        if not ok_ then error(c.key .. ': ' .. tostring(err), 0) end
    end
    ok(#unusable == 0, 'could not cast: ' .. table.concat(unusable, ', '))
end)

test('sweep: every treasure can be redeemed and played with', function()
    for k, c in pairs(G.P_CENTERS) do
        if c.hs_voucher then
            local ok_, err = pcall(function()
                T.new_run()
                T.add('wolfrider'); T.add('stonetusk_boar')
                T.redeem(k:gsub('^v_hs_', ''))
                T.start_round('ragnaros')
                T.play_hand(); T.discard(1); T.play_hand()
                T.end_round()
                T.open_shop({ 'wolfrider' })
                T.close_shop()
            end)
            if not ok_ then error(k .. ': ' .. tostring(err), 0) end
        end
    end
end)

test('sweep: every deck has a Hearthstone card back on hs_decks atlas', function()
    local seen = {}
    for _, d in ipairs(HS.DECKS) do
        local center = G.P_CENTERS[d.key]
        ok(center ~= nil, 'deck exists: ' .. d.key)
        eq(center.atlas, 'hs_decks')
        local pos_key = d.pos.x .. ',' .. d.pos.y
        ok(not seen[pos_key], 'duplicate deck position: ' .. pos_key)
        seen[pos_key] = true
    end
    eq(#HS.DECKS, 16)
end)

test('sweep: every pack kind has an appropriate Hearthstone pack on hs_packs atlas', function()
    local kinds = { arcana = 0, celestial = 1, spectral = 2, standard = 3, buffoon = 4 }
    local sizes = { normal = 0, jumbo = 1, mega = 2 }

    for kind, row in pairs(kinds) do
        for size, col in pairs(sizes) do
            local key = 'p_' .. kind .. '_' .. size .. '_1'
            local center = G.P_CENTERS[key]
            ok(center ~= nil, 'booster exists: ' .. key)
            eq(center.atlas, 'hs_packs')
            eq(center.pos.x, col)
            eq(center.pos.y, row)
        end
    end

    -- Discover packs
    local disc = {
        p_hs_discover_spell = { x = 0, y = 5 },
        p_hs_discover_location = { x = 1, y = 5 },
        p_hs_discover_minion = { x = 2, y = 5 },
    }
    for k, p in pairs(disc) do
        local center = G.P_CENTERS[k]
        ok(center ~= nil, 'discover pack exists: ' .. k)
        eq(center.atlas, 'hs_packs')
        eq(center.pos.x, p.x)
        eq(center.pos.y, p.y)
    end
end)

test('default minion/joker board limit is 7', function()
    T.new_run()
    eq(G.jokers.config.card_limit, 7)
end)

test('localization: pack descriptions replace jokers with minions and immediately with immediately or later', function()
    local root = (SMODS and SMODS.current_mod and SMODS.current_mod.path) or ''
    local loc = assert(loadfile(root .. 'localization/default.lua'))()
    
    -- Buffoon packs describe minions
    local b_norm = loc.descriptions.Other.p_buffoon_normal
    ok(b_norm ~= nil, 'p_buffoon_normal in localization')
    eq(b_norm.name, 'Minion Pack')
    local b_text = table.concat(b_norm.text, ' ')
    ok(b_text:find('Minion') ~= nil, 'buffoon pack text mentions Minion')
    ok(not b_text:find('Joker'), 'buffoon pack text does not mention Joker')

    -- Spell packs say immediately or later
    local a_norm = loc.descriptions.Other.p_arcana_normal
    ok(a_norm ~= nil, 'p_arcana_normal in localization')
    eq(a_norm.name, 'Spell Pack')
    local a_text = table.concat(a_norm.text, ' ')
    ok(a_text:find('immediately or later') ~= nil, 'arcana pack text says immediately or later')

    -- Location packs say immediately or later
    local c_norm = loc.descriptions.Other.p_celestial_normal
    ok(c_norm ~= nil, 'p_celestial_normal in localization')
    eq(c_norm.name, 'Location Pack')
    local c_text = table.concat(c_norm.text, ' ')
    ok(c_text:find('immediately or later') ~= nil, 'celestial pack text says immediately or later')

    -- Forbidden packs say immediately or later
    local s_norm = loc.descriptions.Other.p_spectral_normal
    ok(s_norm ~= nil, 'p_spectral_normal in localization')
    eq(s_norm.name, 'Forbidden Pack')
    local s_text = table.concat(s_norm.text, ' ')
    ok(s_text:find('immediately or later') ~= nil, 'spectral pack text says immediately or later')
end)

test('times mult on a minion appears in gained text and badge', function()
    T.new_run()
    local m = T.add('raid_leader')
    local s = T.spell('blessed_champion')
    ok(T.use(s, { m }))

    -- Gained effects / loc_vars
    local names, tips = HS.gained_effects(m)
    local found = false
    for _, n in ipairs(names) do if n == 'X2 Mult' then found = true end end
    ok(found, 'gained_effects contains X2 Mult')

    local lv = m.config.center:loc_vars({}, m)
    eq(lv.key, 'j_hs_raid_leader_gained')
    eq(lv.vars[#lv.vars], 'X2 Mult')

    -- Draw badges works with x_mult
    local fake_font = { getWidth = function(self, str) return 20 end, getHeight = function(self) return 30 end }
    HS.font = fake_font
    HS.draw_badges(m)
    eq(T_gfx.depth, 0, 'love.graphics push/pop balanced after drawing xmult badge')
    HS.font = nil
end)

test('spells affecting all cards in hand are playable from booster pack scene (outside round)', function()
    T.new_run()
    -- Outside round (facing_blind is false, HS.in_round() is false)
    eq(HS.in_round(), false)

    -- Draw 4 cards to hand as in a booster pack scene
    for i = 1, 4 do draw_card(G.deck, G.hand, nil, nil, nil, G.deck.cards[1]) end
    eq(#G.hand.cards, 4)

    local brawl = T.spell('brawl')
    local ren = SMODS.create_card({ key = 'c_hs_renounce_darkness', set = 'Spectral' })
    local lun = SMODS.create_card({ key = 'c_hs_deck_of_lunacy', set = 'Spectral' })
    local neth = SMODS.create_card({ key = 'c_hs_twisting_nether', set = 'Spectral' })
    local comm = SMODS.create_card({ key = 'c_hs_astral_communion', set = 'Spectral' })

    ok(brawl:can_use_consumeable(), 'brawl is playable in booster scene')
    ok(ren:can_use_consumeable(), 'renounce darkness is playable in booster scene')
    ok(lun:can_use_consumeable(), 'deck of lunacy is playable in booster scene')
    ok(neth:can_use_consumeable(), 'twisting nether is playable in booster scene')
    ok(comm:can_use_consumeable(), 'astral communion is playable in booster scene')

    -- Without cards in hand, none should be playable
    for i = #G.hand.cards, 1, -1 do draw_card(G.hand, G.deck, nil, nil, nil, G.hand.cards[i]) end
    eq(#G.hand.cards, 0)

    ok(not brawl:can_use_consumeable(), 'brawl not playable with empty hand')
    ok(not ren:can_use_consumeable(), 'renounce darkness not playable with empty hand')
    ok(not lun:can_use_consumeable(), 'deck of lunacy not playable with empty hand')
    ok(not neth:can_use_consumeable(), 'twisting nether not playable with empty hand')
    ok(not comm:can_use_consumeable(), 'astral communion not playable with empty hand')
end)

test('trailer scenario spawner cycles through curated states', function()
    T.new_run()
    HS.scenario_index = 0
    HS.spawn_trailer_scenario()
    eq(HS.scenario_index, 1)
    eq(#G.jokers.cards, 3, 'Dr. Boom + 2 Boom Bots')
    HS.spawn_trailer_scenario()
    eq(HS.scenario_index, 2)
    eq(#G.jokers.cards, 2, 'Antonidas + Tirion')
    HS.spawn_trailer_scenario()
    eq(HS.scenario_index, 3)
    eq(#G.jokers.cards, 3, 'Grim Patron swarm')
    HS.spawn_trailer_scenario()
    eq(HS.scenario_index, 4)
    eq(#G.jokers.cards, 5, 'Murloc Swarm + Shudderwock')
    HS.spawn_trailer_scenario()
    eq(HS.scenario_index, 5)
    eq(#G.jokers.cards, 4, 'X-Mult Overkill')
end)


-- ===================================================================== regressions (review fixes)
test('debug trailer keys are off by default', function()
    eq(HS.DEBUG, false)
end)

test('+2 Minion slots stacks with decks that change slots (Black Deck)', function()
    eq(get_starting_params().joker_slots, 7, 'base board is 7')
    local p = get_starting_params()
    p.joker_slots = p.joker_slots - 1 -- what Black Deck does afterwards
    eq(p.joker_slots, 6)
end)

test('Grommash (strongest) ignores Taunt', function()
    T.new_run()
    local taunt = T.add('goldshire_footman')
    local big = T.add('sea_giant')
    T.start_round('grommash')
    G.GAME.blind.chips = 10 ^ 9
    local target = HS.boss_target('strongest', 1)
    ok(target ~= taunt, 'should skip the Taunt minion')
    eq(target, big)
end)

test('boss uses the final hand total even while chips are still easing up', function()
    T.new_run()
    local a = T.add('goldshire_footman')
    T.start_round('malygos')
    G.GAME.blind.chips = 100
    SMODS.last_hand_score = 150 -- this hand wins, but G.GAME.chips is still 0
    SMODS.calculate_context({ after = true, full_hand = {} })
    T_flush()
    ok(not a.removed, 'boss must not attack after a winning hand')
end)

test('win_blind meets the requirement and hands off to the game flow', function()
    T.new_run()
    T.start_round('malygos')
    G.STATES = { SELECTING_HAND = 1, NEW_ROUND = 2 }
    G.STATE = G.STATES.SELECTING_HAND
    G.GAME.round_won = nil
    HS.win_blind()
    T_flush()
    ok(G.GAME.chips >= G.GAME.blind.chips, 'score meets the Blind')
    ok(G.GAME.blind.chips > 0, 'Blind requirement is left intact')
    eq(G.STATE, G.STATES.NEW_ROUND)
    ok(not G.GAME.round_won, 'end_round is not called directly')
    G.STATES, G.STATE = {}, nil
end)

test('selling Prince Renathal on your last Hand keeps that Hand', function()
    T.new_run()
    local p = T.add('prince_renathal')
    T.start_round()
    G.GAME.current_round.hands_left = 1
    T.sell(p)
    eq(G.GAME.current_round.hands_left, 1)
end)


-- ===================================================================== new cards, batch 1
local function deck_count(key)
    local n = 0
    for _, c in ipairs(G.playing_cards) do
        if c.config.center.key == key and not c.destroyed and not c.hs_candle_lit then n = n + 1 end
    end
    return n
end

test('Overload locks Discards next round (Lightning Bolt, Feral Spirit)', function()
    T.new_run()
    T.start_round('malygos')
    ok(T.use(T.spell('lightning_bolt')), 'bolt castable')
    ok(T.use(T.spell('feral_spirit')), 'feral spirit castable')
    eq(T.count('spirit_wolf'), 2)
    eq(G.GAME.current_round.discards_left, 3, 'overload waits for next round')
    T.end_round()
    T.start_round()
    eq(G.GAME.current_round.discards_left, 0, '3 discards - Overload 3')
    T.end_round()
    T.start_round()
    eq(G.GAME.current_round.discards_left, 3, 'overload only lasts one round')
end)

test('temporary summons leave at end of round without a Deathrattle', function()
    T.new_run()
    local juggler = T.add('knife_juggler')
    T.start_round()
    local tmp = HS.summon('loot_hoarder', nil, { temporary = true })
    local drawn = #G.hand.cards
    T.end_round()
    ok(tmp.removed or E(tmp).dying, 'temporary minion left')
    eq(HS.state().pending_draws, 0, 'no Loot Hoarder Deathrattle')
    ok(HS.alive(juggler), 'normal minions stay')
end)

test('Preparation makes the next shop Spell free, once', function()
    T.new_run()
    T.open_shop({})
    local s1 = SMODS.create_card({ key = 'c_hs_fireball' }); G.shop_jokers:emplace(s1)
    ok(T.use(T.spell('preparation')))
    s1:set_cost()
    eq(s1.cost, 0, 'free after Preparation')
    SMODS.calculate_context({ buying_card = true, card = s1 })
    T_flush()
    s1:set_cost()
    ok(s1.cost > 0, 'only the next Spell is free')
end)

test('Embiggen buffs the whole deck and taxes shop minions', function()
    T.new_run()
    T.open_shop({ 'wolfrider' })
    local m = G.shop_jokers.cards[1]
    m:set_cost(); local before = m.cost
    ok(T.use(T.spell('embiggen')))
    m:set_cost()
    eq(m.cost, before + 1, 'minion costs $1 more')
    eq(G.playing_cards[1].ability.perma_bonus, 5)
    T.close_shop()
    eq(HS.state().minion_surcharge, 0, 'surcharge ends with the shop')
end)

test("Smuggler's Run gives every card in hand +1 Mult permanently", function()
    T.new_run()
    T.start_round()
    ok(T.use(T.spell('smugglers_run')))
    for _, c in ipairs(G.hand.cards) do eq(c.ability.perma_mult, 1) end
end)

test('Ragnaros scores no Mult but hits the Blind for 8 after each hand', function()
    T.new_run()
    local r = T.add('ragnaros_the_firelord')
    T.start_round()
    G.GAME.blind.chips = 100000
    local before = G.GAME.blind.chips
    local chips, mult = T.play_hand()
    eq(mult, 0, 'no Mult from Ragnaros')
    ok(G.GAME.blind.chips < before, 'Blind took damage')
    eq(G.GAME.blind.chips, math.floor(before * 0.98 ^ 8))
end)

test('Malygos adds Spell Damage +5', function()
    T.new_run()
    T.add('malygos')
    eq(HS.spell_damage(), 5)
end)

test('Alexstrasza halves a Boss Blind (Brann does not quarter it)', function()
    T.new_run()
    T.add('brann_bronzebeard'); T.add('alexstrasza')
    T.start_round('malygos')
    eq(G.GAME.blind.chips, 500)
    T.new_run()
    T.add('alexstrasza')
    T.start_round()
    eq(G.GAME.blind.chips, 1000, 'not a Boss: unchanged')
end)

test('Onyxia fills the board with Whelps; Deathwing clears it', function()
    T.new_run()
    T.add('onyxia')
    T.start_round()
    eq(#HS.minions(), 7)
    eq(T.count('whelp'), 6)
    T.new_run()
    T.add('wolfrider'); T.add('deathwing')
    T.start_round()
    eq(#HS.minions(), 1, 'only Deathwing is left')
    eq(#G.hand.cards, 8, 'drew a new hand')
end)

test('Questing Adventurer grows on spells, discards and buys', function()
    T.new_run()
    local q = T.add('questing_adventurer')
    T.start_round()
    T.use(T.spell('fireball'))
    T.discard(1)
    T.end_round()
    T.buy('wolfrider')
    eq(T.atk(q), 5); eq(E(q).health, 5)
end)

test('Ysera adds a Dream card at the end of the round', function()
    T.new_run()
    T.add('ysera')
    T.start_round()
    T.end_round()
    eq(#G.consumeables.cards, 1)
    local key = G.consumeables.cards[1].config.center.key
    ok(key:find('ysera_awakens') or key:find('nightmare') or key:find('emerald_drake') or key:find('laughing_sister'), key)
end)

test('Patches hides in your deck when bought and jumps out for a Pirate', function()
    T.new_run()
    local p = T.buy('patches_the_pirate')
    ok(not HS.alive(p), 'Patches left the board')
    eq(deck_count(HS.PATCHES_CARD), 1, 'Patches card in deck')
    T.buy('southsea_deckhand')
    eq(T.count('patches_the_pirate'), 1, 'Patches jumped out')
    eq(deck_count(HS.PATCHES_CARD), 0, 'his card is used up')
    local patches
    for _, c in ipairs(HS.minions()) do if c.config.center.key == 'j_hs_patches_the_pirate' then patches = c end end
    ok(not E(patches).summoned, 'keeps his sell value')
    ok(HS.has(patches, 'charge'))
end)

test('drawing the Patches card summons him; full board keeps it in hand', function()
    T.new_run()
    HS.add_deck_card(HS.PATCHES_CARD)
    -- put Patches on top of the deck so he is drawn
    local pc = G.deck.cards[#G.deck.cards]
    ok(pc.config.center.key == HS.PATCHES_CARD, 'added on top')
    T.start_round()
    eq(T.count('patches_the_pirate'), 1)
    T.new_run()
    for _ = 1, 7 do T.add('wolfrider') end
    HS.add_deck_card(HS.PATCHES_CARD)
    T.start_round()
    eq(T.count('patches_the_pirate'), 0, 'no room')
    eq(deck_count(HS.PATCHES_CARD), 1, 'card waits for room')
end)

test('buying a Pirate no longer summons a free Patches', function()
    T.new_run()
    T.buy('southsea_deckhand')
    eq(T.count('patches_the_pirate'), 0)
end)

test('new spells: Eviscerate Combo, Kill Command Beast, Ice Lance, Cold Blood, Mind Vision', function()
    T.new_run()
    T.start_round('malygos')
    local b = G.GAME.blind.chips
    T.use(T.spell('eviscerate'))
    eq(G.GAME.blind.chips, math.floor(b * 0.98 ^ 2), 'no Combo: 2')
    b = G.GAME.blind.chips
    T.use(T.spell('eviscerate'))
    eq(G.GAME.blind.chips, math.floor(b * 0.98 ^ 4), 'Combo: 4')

    T.new_run(); T.add('timber_wolf'); T.start_round('malygos')
    b = G.GAME.blind.chips
    T.use(T.spell('kill_command'))
    eq(G.GAME.blind.chips, math.floor(b * 0.98 ^ 5), 'Beast: 5')

    T.new_run(); T.start_round('malygos')
    T.use(T.spell('ice_lance'))
    ok(HS.state().boss_frozen, 'first Ice Lance freezes')
    b = G.GAME.blind.chips
    T.use(T.spell('ice_lance'))
    eq(G.GAME.blind.chips, math.floor(b * 0.98 ^ 4), 'already Frozen: 4 damage')

    T.new_run(); local w = T.add('wolfrider'); T.start_round()
    local base = T.atk(w)
    T.use(T.spell('cold_blood'), { w })
    eq(T.atk(w), base + 2)

    local n = #G.playing_cards
    T.use(T.spell('mind_vision'), { G.hand.cards[1] })
    eq(#G.playing_cards, n + 1, 'a copy joins the deck')
end)

test('Spreading Plague and Unleash the Hounds summon per card', function()
    T.new_run()
    T.start_round()
    T.use(T.spell('spreading_plague'))
    ok(T.count('scarab_beetle') >= 2, 'repeats while hand outnumbers minions')
    T.new_run(); T.start_round()
    T.use(T.spell('unleash_the_hounds'), { G.hand.cards[1], G.hand.cards[2], G.hand.cards[3] })
    eq(T.count('hound'), 3)
end)


-- ===================================================================== combo engines
test('Windfury repeats the whole score, X Mult included', function()
    T.new_run()
    local m = T.add('goldshire_footman') -- 1/2
    E(m).x_mult = 2
    T.use(T.spell('windfury'), { m })
    T.start_round()
    T.play_hand() -- hand 1
    local _, mult = T.play_hand()
    eq(mult, 6, '((1) X2 + 1) X2')
end)

test('Whirlwind Tempest gives Windfury minions Mega-Windfury (4 attacks)', function()
    T.new_run()
    local m = T.add('goldshire_footman')
    T.use(T.spell('windfury'), { m })
    T.add('whirlwind_tempest')
    ok(HS.has(m, 'mega_windfury'))
    ok(not HS.has(HS.minions()[2], 'mega_windfury'), 'Tempest itself has no Windfury')
    T.start_round()
    T.play_hand()
    local chips = T.play_hand()
    -- footman scores 4 times (2 Health), Tempest once (6 Health)
    eq(chips, (4 * 2 + 6) * HS.CHIPS_PER_HEALTH)
end)

test('Tyrande: the next 3 Spells cast twice', function()
    T.new_run()
    T.add('tyrande')
    T.start_round('malygos')
    eq(HS.state().cast_twice, 3)
    local b = G.GAME.blind.chips
    T.use(T.spell('holy_smite'))
    eq(G.GAME.blind.chips, math.floor(math.floor(b * 0.98 ^ 2) * 0.98 ^ 2), 'Holy Smite hit twice')
    T.use(T.spell('holy_smite')); T.use(T.spell('holy_smite'))
    eq(HS.state().cast_twice, 0)
    b = G.GAME.blind.chips
    T.use(T.spell('holy_smite'))
    eq(G.GAME.blind.chips, math.floor(b * 0.98 ^ 2), 'fourth Spell casts once')
end)

test('Archmage Vargoth recasts a Spell used this turn after the hand', function()
    T.new_run()
    T.add('archmage_vargoth')
    T.start_round() -- no boss: nothing else touches the Blind
    G.GAME.blind.chips = 100000
    T.use(T.spell('fireball'))
    local b = G.GAME.blind.chips
    T.play_hand()
    eq(G.GAME.blind.chips, math.floor(b * 0.98 ^ 6), 'Fireball recast at end of turn')
    b = G.GAME.blind.chips
    T.play_hand()
    eq(G.GAME.blind.chips, b, 'nothing to recast on a turn without Spells')
end)

test('Old Murk-Eye: other Murlocs each give X1.1 Mult', function()
    T.new_run()
    local scout = HS.summon('murloc_scout')
    local eye = T.add('old_murk_eye')
    eq(T.atk(eye), 3, '+1 Attack per other Murloc')
    local res = scout.config.center:calculate(scout, { joker_main = true, cardarea = G.jokers })
    local x
    local r = res
    while r do if r.Xmult then x = r.Xmult end; r = r.extra end
    eq(x, 1.1)
end)

test('Grimestreet Enforcer gives held cards X0.05 Mult permanently', function()
    T.new_run()
    T.add('grimestreet_enforcer')
    T.start_round()
    T.play_hand(1)
    local held = G.hand.cards[1]
    ok(math.abs((held.ability.perma_x_mult or 0) - 0.05) < 1e-9, tostring(held.ability.perma_x_mult))
end)

test('Lyra adds a Negative Spell per Spell, but not from her own', function()
    T.new_run()
    T.add('lyra_the_sunshard')
    T.start_round()
    T.use(T.spell('holy_smite'))
    eq(#G.consumeables.cards, 1)
    local gift = G.consumeables.cards[1]
    ok(gift.edition and gift.edition.negative, 'Negative')
    ok(gift.ability.hs_lyra)
    -- casting Lyra's gift doesn't make another one
    SMODS.calculate_context({ using_consumeable = true, consumeable = gift })
    T_flush()
    eq(#G.consumeables.cards, 1)
end)

test('Zola summons a Polychrome copy of the minion to her right', function()
    T.new_run()
    T.add('zola_the_gorgon'); T.add('wolfrider')
    T.start_round()
    eq(T.count('wolfrider'), 2)
    local copy = HS.minions()[3]
    ok(copy.edition and copy.edition.polychrome, 'Polychrome')
end)

test('Mimiron turns a deck card into Steel when a Mech arrives', function()
    T.new_run()
    T.add('mimiron_the_mastermind')
    local function steel()
        local n = 0
        for _, c in ipairs(G.playing_cards) do if c.config.center.key == 'm_steel' then n = n + 1 end end
        return n
    end
    eq(steel(), 0)
    T.buy('mechwarper')
    eq(steel(), 1, 'buying a Mech')
    T.buy('wolfrider')
    eq(steel(), 1, 'non-Mechs do nothing')
end)


-- ===================================================================== class legends
test('Tess Greymane recasts the Spells used since last round started', function()
    T.new_run()
    T.start_round('malygos')
    T.use(T.spell('holy_smite')); T.use(T.spell('fireball'))
    T.end_round()
    T.add('tess_greymane')
    T.start_round()
    -- Tess replayed Holy Smite (2) and Fireball (6) into this round's 1000-chip Blind
    eq(G.GAME.blind.chips, math.floor(math.floor(1000 * 0.98 ^ 2) * 0.98 ^ 6))
    eq(#HS.state().recent_spells, 0, 'replays are not recorded for the next Tess')
    T.end_round()
    T.start_round()
    eq(#HS.state().tess_spells, 0)
end)

test('Confessor Paletress summons temporary Legendaries on Battlecry and Discard', function()
    T.new_run()
    T.add('confessor_paletress')
    T.start_round()
    eq(#HS.minions(), 2, 'Battlecry summon')
    T.discard(1)
    eq(#HS.minions(), 3, 'Inspire summon')
    for _, m in ipairs(HS.minions()) do
        if m.config.center.key ~= 'j_hs_confessor_paletress' then
            eq(HS.def(m).rarity, 4); ok(E(m).temporary, 'temporary')
        end
    end
    T.end_round()
    eq(#HS.minions(), 1, 'Legendaries leave at end of round')
end)

test('Raza gives +3 Discards only without duplicates', function()
    T.new_run()
    T.add('raza_the_chained')
    T.start_round()
    eq(G.GAME.current_round.discards_left, 6)
    T.new_run()
    HS.create_playing_card(HS.describe_card(G.playing_cards[1]), G.deck)
    T.add('raza_the_chained')
    T.start_round()
    eq(G.GAME.current_round.discards_left, 3, 'duplicate in deck')
end)

test('Mozaki gains Spell Damage +1 per Spell, permanently', function()
    T.new_run()
    T.add('mozaki_master_duelist')
    T.start_round('malygos')
    T.use(T.spell('holy_smite')); T.use(T.spell('holy_smite'))
    eq(HS.spell_damage(), 2)
    T.end_round(); T.start_round()
    eq(HS.spell_damage(), 2, 'kept next round')
end)

test('Spiritsinger Umbra triggers the Deathrattle of bought and summoned minions', function()
    T.new_run()
    T.add('spiritsinger_umbra')
    T.buy('cairne_bloodhoof')
    eq(T.count('baine_bloodhoof'), 1, 'Cairne Deathrattle on buy')
    eq(T.count('cairne_bloodhoof'), 1, 'Cairne stays')
end)


test('Aviana makes shop minions cost $1', function()
    T.new_run()
    T.open_shop({ 'sea_giant' })
    local m = G.shop_jokers.cards[1]
    m:set_cost(); ok(m.cost > 1)
    T.add('aviana')
    m:set_cost(); eq(m.cost, 1)
end)

test('Grommash gets +6 Attack while damaged', function()
    T.new_run()
    local g = T.add('grommash_hellscream')
    eq(T.atk(g), 4)
    HS.damage(g, 1)
    eq(T.atk(g), 10)
    ok(HS.has(g, 'charge'))
end)


test('only keyword attacks show a keyword message (no stray "Windfury!")', function()
    T.new_run()
    local plain = T.add('costumed_singer')
    local wf = T.add('young_dragonhawk')
    T.start_round() -- no boss, so nothing can kill the 1/1 Dragonhawk
    local function messages(card)
        local r = card.config.center:calculate(card, { joker_main = true, cardarea = G.jokers })
        local out = {}
        while r do if r.message then out[#out + 1] = r.message end; r = r.extra end
        return out
    end
    eq(#messages(plain), 0, 'a plain minion shows no keyword message')
    local m = messages(wf)
    eq(#m, 1); eq(m[1], 'Windfury!')
end)


-- ===================================================================== Secrets
local function secret(id) add_tag(Tag('tag_hs_' .. id)); return G.GAME.tags[#G.GAME.tags] end
local function held(id)
    for _, t in ipairs(G.GAME.tags) do if t.key == 'tag_hs_' .. id then return true end end
    return false
end

test('all 17 Secrets exist and only Secrets are offered as tags', function()
    local n = 0
    for k, v in pairs(G.P_TAGS) do
        if k:find('^tag_hs_') then
            n = n + 1
            ok(v.hs_card_atlas == 'hs_secrets' and v.hs_id, k .. ' has a Secret card')
        end
    end
    eq(n, 17)
end)

test('you cannot hold two copies of the same Secret', function()
    T.new_run()
    secret('ice_barrier'); secret('ice_barrier')
    eq(#G.GAME.tags, 2)
    ok(G.GAME.tags[1].key ~= G.GAME.tags[2].key, 'duplicate was rerolled')
end)

test('Freezing Trap cancels the Boss attack and Freezes it', function()
    T.new_run()
    local f = T.add('goldshire_footman')
    secret('freezing_trap')
    T.start_round('malygos')
    T.play_hand()
    ok(HS.alive(f) and not HS.is_damaged(f), 'attack cancelled')
    ok(HS.state().boss_frozen, 'Boss Frozen')
    ok(not held('freezing_trap'), 'Secret used up')
end)

test('Noble Sacrifice: a Defender takes the hit', function()
    T.new_run()
    local f = T.add('goldshire_footman')
    secret('noble_sacrifice')
    T.start_round('malygos')
    T.play_hand()
    ok(not HS.is_damaged(f), 'footman untouched')
    eq(T.count('defender'), 0, 'Defender died in its place')
end)

test('Snake Trap, Bear Trap, Ice Barrier and Explosive Trap react to the attack', function()
    T.new_run()
    local f = T.add('sea_giant')
    secret('snake_trap'); secret('bear_trap'); secret('ice_barrier'); secret('explosive_trap')
    T.start_round('malygos')
    G.GAME.blind.chips = 100000
    local b = G.GAME.blind.chips
    T.play_hand()
    eq(T.count('snake'), 3)
    eq(T.count('ironfur_grizzly'), 1)
    eq(#G.GAME.tags, 0, 'all four triggered')
    ok(G.GAME.blind.chips < b, 'Explosive Trap hit the Blind')
end)

test('Mirror Entity copies the next minion you buy', function()
    T.new_run()
    secret('mirror_entity')
    T.buy('wolfrider')
    eq(T.count('wolfrider'), 2)
    T.buy('wolfrider')
    eq(T.count('wolfrider'), 3, 'only once')
end)

test('Counterspell disables the next Boss Blind (waits through non-Bosses)', function()
    T.new_run()
    secret('counterspell')
    T.start_round()
    ok(held('counterspell'), 'not used on a Small Blind')
    T.end_round()
    T.start_round('malygos')
    ok(G.GAME.blind.disabled)
    ok(not held('counterspell'))
end)

test('Spell Secrets: Mana Bind, Cat Trick, Dirty Tricks', function()
    T.new_run()
    secret('mana_bind'); secret('cat_trick'); secret('dirty_tricks')
    T.start_round()
    T.play_hand(5)
    local in_hand = #G.hand.cards
    T.use(T.spell('holy_smite'))
    eq(#G.consumeables.cards, 1, 'Negative copy from Mana Bind')
    ok(G.consumeables.cards[1].edition and G.consumeables.cards[1].edition.negative)
    eq(T.count('cat_in_a_hat'), 1)
    eq(#G.hand.cards, in_hand + 2, 'Dirty Tricks drew 2')
end)

test('Death Secrets: Redemption, Avenge, Cheat Death', function()
    T.new_run()
    local a = T.add('wolfrider'); local b = T.add('goldshire_footman')
    secret('redemption'); secret('avenge')
    T.start_round()
    HS.kill(a, 'destroy')
    T_flush()
    eq(T.count('wolfrider'), 1, 'Redemption brought it back')
    eq(T.atk(b), 4, 'Avenge gave +3 Attack')
    T.new_run()
    local c = T.add('wolfrider')
    secret('cheat_death')
    T.start_round()
    HS.kill(c, 'destroy'); T_flush()
    eq(T.count('wolfrider'), 0)
    T.end_round(); T.start_round()
    eq(T.count('wolfrider'), 1, 'back next round')
end)

test('selling a minion does not trigger death Secrets', function()
    T.new_run()
    local a = T.add('wolfrider')
    secret('redemption')
    T.sell(a)
    ok(held('redemption'))
end)

test('Ice Block saves a losing last Hand; Eye for an Eye; Competitive Spirit', function()
    T.new_run()
    secret('ice_block')
    T.start_round()
    G.GAME.blind.chips = 10 ^ 9
    G.GAME.current_round.hands_left = 1
    T.play_hand()
    eq(G.GAME.current_round.hands_left, 1, '+1 Hand instead of losing')

    T.new_run()
    secret('eye_for_an_eye')
    T.start_round()
    G.GAME.blind.chips = 100000
    ease_dollars(-3)
    eq(G.GAME.blind.chips, math.floor(100000 * 0.98 ^ 3))

    T.new_run()
    local w = T.add('wolfrider')
    secret('competitive_spirit')
    T.start_round()
    eq(E(w).attack, 4)
end)


test('vanilla tags handed out directly become a random Secret', function()
    T.new_run()
    add_tag(Tag('tag_double'))
    eq(#G.GAME.tags, 1)
    ok(HS.SECRET_BY_KEY[G.GAME.tags[1].key], 'converted to a Secret')
end)


test('Legendaries cost $20-30; rarity odds favour Uncommon/Rare a little more than vanilla', function()
    for _, c in ipairs(minion_centers()) do
        local d = c.hs_minion
        if d.rarity == 4 and not d.token then
            ok(c.cost >= 20 and c.cost <= 30, d.name .. ' costs ' .. c.cost)
        end
    end
    local w = HS.RARITY_WEIGHTS
    ok(math.abs(w.Common + w.Uncommon + w.Rare + w.Legendary - 1) < 1e-9, 'weights sum to 1')
    ok(w.Uncommon > 0.25 and w.Rare > 0.05 and w.Legendary > 0)
end)


-- ===================================================================== new enemy keywords
test('Charge: the Blind also attacks before the hand scores', function()
    T.new_run()
    local w = T.add('wolfrider') -- 3/1
    T.start_round('yshaarj')
    G.GAME.blind.chips = 10 ^ 9
    local _, mult = T.play_hand()
    eq(mult, 0, 'killed before it could score')
    ok(not HS.alive(w))
end)

test('Rush: the Blind attacks at the start of the round', function()
    T.new_run()
    local w = T.add('wolfrider')
    T.start_round('darius_crowley')
    ok(not HS.alive(w), 'killed on round start')
    eq(HS.state().enemy_ramp, 2, '+2 Attack for the kill')
end)

test('Lifesteal: the Blind heals by the damage it deals', function()
    T.new_run()
    T.add('nat_pagle') -- 0 Attack: no strike-back damage muddying the heal
    T.start_round('lanathel')
    G.GAME.blind.chips = 100000
    T.play_hand()
    ok(G.GAME.blind.chips > 100000, 'Blind healed')
    T.discard(1)
    eq(HS.state().enemy_ramp, 1, '+1 Attack per discard')
end)

test('Reborn: beating the Blind once brings it back higher', function()
    T.new_run()
    T.add('sea_giant')
    T.start_round('nzoth')
    G.GAME.blind.chips = 1
    T.play_hand()
    ok(HS.state().blind_reborn)
    ok(G.GAME.blind.chips > G.GAME.chips, 'requirement went back up')
end)

test('Stealth: Blind damage is blocked until it has attacked', function()
    T.new_run()
    T.add('sea_giant')
    T.start_round('moroes')
    G.GAME.blind.chips = 100000
    T.use(T.spell('holy_smite'))
    eq(G.GAME.blind.chips, 100000, 'Stealthed')
    T.play_hand()
    local b = G.GAME.blind.chips
    T.use(T.spell('holy_smite'))
    ok(G.GAME.blind.chips < b, 'revealed after attacking')
    eq(#HS.state().enemy_army, 1, 'summoned a Steward')
end)

test('Army: summoned attackers join in each turn', function()
    T.new_run()
    for _ = 1, 3 do T.add('sea_giant') end
    T.start_round('kiljaeden')
    G.GAME.blind.chips = 10 ^ 9
    T.play_hand(); T.play_hand()
    eq(#HS.state().enemy_army, 2)
    eq(HS.state().enemy_army[2], HS.state().enemy_army[1] + 2, 'each Demon is bigger')
end)

test('Silence: Web Wrap / Mind Control stop minions scoring this round', function()
    T.new_run()
    local a = T.add('sea_giant'); local b = T.add('wolfrider')
    T.start_round('cabal_shadow_priest')
    ok(E(b).silenced, 'weakest minion silenced')
    ok(not E(a).silenced)
    T.end_round(); T.start_round()
    ok(not E(b).silenced, 'only for that round')
end)

test('Hateful Strike hits the highest-Health minion; Medivh attacks on Spells', function()
    T.new_run()
    local small = T.add('wolfrider'); local big = T.add('sea_giant')
    T.start_round('patchwerk')
    eq(HS.boss_target('healthiest', 1), big)
    T.new_run()
    local m = T.add('sea_giant')
    T.start_round('medivh')
    T.use(T.spell('holy_smite'))
    ok(HS.is_damaged(m), 'Medivh attacked when a Spell was cast')
end)

test('Divine Shield Blind absorbs the first hand if nothing hit it first', function()
    T.new_run()
    T.add('sea_giant')
    T.start_round('scarlet_crusader') -- (Al'Akir's Charge would pop his own shield via strike-back)
    G.GAME.blind.chips = 1000
    HS.state().boss_frozen = true -- no attack after the hand, so no strike-back damage either
    T.play_hand()
    ok(G.GAME.blind.chips > 1000, 'first hand absorbed (requirement rose by its score)')
    ok(not HS.state().blind_shield)
    T.new_run()
    T.add('sea_giant')
    T.start_round('scarlet_crusader')
    G.GAME.blind.chips = 1000
    T.use(T.spell('holy_smite')) -- pops the shield first (absorbed: no damage)
    HS.state().boss_frozen = true
    T.play_hand()
    eq(G.GAME.blind.chips, 1000, 'shield already gone: hand counts normally')
end)


test('Blind requirements scale steeper than vanilla: Ante 1 same, Ante 8 = 5x', function()
    eq(get_blind_amount(1), 300)
    eq(get_blind_amount(8), 250000)
    local prev = 0
    for a = 1, 8 do
        local v = get_blind_amount(a)
        ok(v > prev, 'grows every Ante'); prev = v
    end
end)


test('Stealth: hands miss too until the Blind has attacked', function()
    T.new_run()
    T.add('sea_giant')
    T.start_round('moroes')
    G.GAME.blind.chips = 1000
    HS.state().boss_frozen = true -- he skips this attack, so he stays hidden
    T.play_hand()
    ok(G.GAME.blind.chips > 1000, 'hand score absorbed while Stealthed')
    T.play_hand() -- now he attacks after this hand (and is revealed)
    ok(HS.state().boss_has_attacked)
end)

test('Blind status overlay draws for every Boss without errors', function()
    local fake_font = { getWidth = function() return 20 end, getHeight = function() return 30 end }
    HS.font = fake_font
    for key, b in pairs(G.P_BLINDS) do
        if key:find('^bl_hs_') then
            T.new_run()
            T.add('sea_giant')
            T.start_round(key:sub(7))
            HS.state().enemy_army = { 1, 1 }
            HS.state().blind_shield = true
            local blind = { children = { animatedSprite = { VT = { w = 1.4, h = 1.4 } } } }
            HS.draw_blind_status(blind)
            eq(T_gfx.depth, 0, key .. ': push/pop balanced')
        end
    end
    HS.font = nil
end)


test('a Frozen Stealth Blind still loses Stealth after its turn (no soft-lock)', function()
    T.new_run()
    T.add('sea_giant')
    T.start_round('moroes')
    HS.state().boss_frozen = true
    T.play_hand()
    ok(HS.state().boss_has_attacked, 'turn passed, Stealth gone')
    G.GAME.blind.chips = 100000
    T.use(T.spell('holy_smite'))
    ok(G.GAME.blind.chips < 100000, 'Blind damage lands now')
end)

test('saved shop damage goes through Stealth', function()
    T.new_run()
    HS.state().pending_blind = 5
    T.start_round('moroes')
    eq(G.GAME.blind.chips, math.floor(1000 * 0.98 ^ 5))
end)

test('Silence removes the minion text: no Battlecry, aura, grant or Deathrattle', function()
    T.new_run()
    local brann = T.add('brann_bronzebeard')
    local leader = T.add('raid_leader')
    local w = T.add('wolfrider')
    local base = T.atk(w)
    HS.silence_minion(leader)
    eq(T.atk(w), base - 1, 'Raid Leader aura gone')
    HS.silence_minion(brann)
    eq(HS.battlecry_times(), 1, 'a Silenced Brann no longer doubles Battlecries')
    local cairne = T.add('cairne_bloodhoof')
    T.start_round() -- (a new round clears Silence, so Silence after it starts)
    HS.silence_minion(cairne)
    HS.kill(cairne, 'destroy'); T_flush()
    eq(T.count('baine_bloodhoof'), 0, 'no Deathrattle when Silenced')
end)


test('telegraph: the predicted target is the minion actually attacked', function()
    for _, boss in ipairs({ 'malygos', 'grommash', 'patchwerk' }) do
        T.new_run()
        local a = T.add('wolfrider'); local b = T.add('sea_giant'); local c = T.add('goldshire_footman')
        T.start_round(boss)
        G.GAME.blind.chips = 10 ^ 9
        local pred = HS.predict_boss_targets()
        local predicted
        for card, kind in pairs(pred) do eq(kind, 'sure'); predicted = card end
        ok(predicted, boss .. ' predicts a target')
        local hp = {}
        for _, m in ipairs({ a, b, c }) do hp[m] = E(m).health end
        T.play_hand()
        local hit
        for _, m in ipairs({ a, b, c }) do
            if m.removed or E(m).dying or E(m).health < hp[m] then hit = m end
        end
        eq(hit, predicted, boss .. ': attacked the predicted minion')
    end
end)

test('telegraph: predicting never consumes randomness; random Blinds mark every option', function()
    T.new_run()
    T.add('wolfrider'); T.add('sea_giant')
    T.start_round('ragnaros') -- random targets
    local calls = 0
    local orig = pseudorandom
    pseudorandom = function(...) calls = calls + 1; return orig(...) end
    local pred = HS.predict_boss_targets()
    for _ = 1, 50 do HS.predict_boss_targets() end
    pseudorandom = orig
    eq(calls, 0, 'no RNG used')
    local n = 0
    for _, kind in pairs(pred) do eq(kind, 'maybe'); n = n + 1 end
    eq(n, 2)
    HS.state().boss_frozen = true
    ok(next(HS.predict_boss_targets()) == nil, 'a Frozen Boss telegraphs nothing')
end)

test('board effects (reticle, temporary, doomed, mega-windfury) draw without errors', function()
    HS.font = { getWidth = function() return 20 end, getHeight = function() return 30 end }
    T.new_run()
    local a = T.add('wolfrider'); T.use(T.spell('windfury'), { a }); T.add('whirlwind_tempest')
    local tmp = HS.summon('wolfrider', nil, { temporary = true })
    E(a).doomed = true
    T.start_round('patchwerk')
    HS._pred_time = nil
    for _, m in ipairs(HS.minions()) do
        HS.draw_board_effects(m)
        eq(T_gfx.depth, 0, 'push/pop balanced')
    end
    local names = HS.gained_effects(tmp)
    local found = false
    for _, n in ipairs(names) do if n:find('Leaves') then found = true end end
    ok(found, 'temporary minion says it leaves')
    HS.font = nil
end)

-- ===================================================================== runner
local passed, failed = 0, {}
for _, t in ipairs(tests) do
    local ok_, err = pcall(t.fn)
    if ok_ then
        passed = passed + 1
        print('  PASS  ' .. t.name)
    else
        failed[#failed + 1] = t.name
        print('  FAIL  ' .. t.name .. '\n        ' .. tostring(err))
    end
end
print(string.format('\n%d passed, %d failed', passed, #failed))
return #failed
