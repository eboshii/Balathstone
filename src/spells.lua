-- Balathstone Spells (replace Tarot cards)
-- Shared spell framework + the Hearthstone spells themselves.
-- Damage spells hit the Blind (enemy hero); Spell Damage adds to them.
-- Spells that "choose a minion" use the minions you highlight.
local HS = Balathstone or Balearthstone
local E = HS.E

HS.cons_count = HS.cons_count or 0
HS.spell_by_key = HS.spell_by_key or {}

local function highlighted(area_name)
    local area = area_name == 'jokers' and G.jokers or G.hand
    return (area and area.highlighted) or {}
end

-- Can the spell be used with these targets?
function HS.spell_ready(s, targets)
    local t = s.targets
    if t then
        local n = #targets
        if n < (t.min or 1) or n > (t.max or 1) then return false end
        if t.area == 'jokers' then
            for _, c in ipairs(targets) do if not HS.alive(c) then return false end end
        end
        if t.area == 'hand' and not (G.hand and G.hand.cards and #G.hand.cards > 0) then return false end
    end
    if s.in_round and not HS.in_round() then return false end
    if s.set ~= 'Planet' and HS.boss_is('loatheb') then return false end
    if s.can and not s.can(targets) then return false end
    return true
end

function HS.sd(n) return n + HS.spell_damage() end

-- Register a spell-like consumable
function HS.spell(s)
    HS.cons_count = HS.cons_count + 1
    local idx = s.pos_index or (HS.cons_count - 1)
    s.set = s.set or 'Tarot'
    s.key = 'c_hs_' .. s.id
    HS.spell_by_key[s.key] = s
    if s.set == 'Tarot' then HS.spells[#HS.spells + 1] = s end
    local tips = HS.keyword_tips(s.text or {})
    SMODS.Consumable({
        key = 'hs_' .. s.id,
        set = s.set,
        loc_txt = { name = s.name, text = s.text },
        config = s.config or {},
        pos = { x = idx % 10, y = math.floor(idx / 10) },
        atlas = 'hs_consumables',
        cost = s.cost or (s.set == 'Spectral' and 4 or 3),
        hs_spell = s,
        hs_id = s.hs_id,
        hs_text = s.art_text or s.text,
        hs_targets = s.targets,
        select_card = function(self, card, pack)
            return 'consumeables', true
        end,
        in_pool = s.token and function() return false end or nil,
        loc_vars = function(self, info_queue, card)
            for _, k in ipairs(tips) do info_queue[#info_queue + 1] = { set = 'Other', key = k } end
            return { vars = s.vars and s.vars(card) or {} }
        end,
        can_use = function(self, card)
            local targets = s.targets and highlighted(s.targets.area) or {}
            return HS.spell_ready(s, targets)
        end,
        use = function(self, card, area, copier)
            local targets = s.targets and highlighted(s.targets.area) or {}
            local copy = {}
            for i, c in ipairs(targets) do copy[i] = c end
            s.effect(card, copy)
            HS.maybe_cast_twice(s, card, copy)
            if s.targets and s.targets.area == 'jokers' and G.jokers then G.jokers:unhighlight_all() end
        end,
    })
    return s
end

-- Tyrande: the next N Spells you use cast twice (same targets, if they're still there)
function HS.maybe_cast_twice(s, card, targets)
    local st = HS.state()
    if (st.cast_twice or 0) <= 0 then return end
    st.cast_twice = st.cast_twice - 1
    local still = {}
    for _, c in ipairs(targets) do
        local gone = c.removed or c.destroyed or c.getting_sliced
        if s.targets and s.targets.area == 'hand' and c.area ~= G.hand then gone = true end
        if not gone then still[#still + 1] = c end
    end
    if HS.spell_ready(s, still) then
        s.effect(card, still)
        HS.say(card, 'Cast twice!', G.C.SECONDARY_SET.Tarot)
    end
end

-- Pick random valid targets for a spell
local function random_targets(s, seed)
    local targets = {}
    local t = s.targets
    if t then
        local candidates = t.area == 'jokers' and HS.minions() or ((G.hand and G.hand.cards) or {})
        local want = math.max(t.min or 1, math.min(t.max or 1, #candidates))
        local copy = {}
        for i, c in ipairs(candidates) do copy[i] = c end
        for _ = 1, want do
            if #copy == 0 then break end
            local i = math.floor(HS.rand(seed) * #copy) + 1
            targets[#targets + 1] = table.remove(copy, i)
        end
    end
    return targets
end

-- Cast a spell definition with random targets (Yogg-Saron, Archmage Vargoth); false if it can't
function HS.cast_spell(s, source)
    local targets = random_targets(s, 'hs_cast_t')
    if not HS.spell_ready(s, targets) then return false end
    s.effect(source, targets)
    if source then HS.say(source, s.name, G.C.SECONDARY_SET.Tarot) end
    HS.on_spell_cast(G.P_CENTERS[s.key] or { key = s.key, set = 'Tarot' }, source)
    return true
end

-- Yogg-Saron: cast a random Spell with random targets
function HS.cast_random_spell(source)
    local pool = {}
    for _, s in ipairs(HS.spells) do
        if not s.token and s.random ~= false then pool[#pool + 1] = s end
    end
    for attempt = 1, 12 do
        local s = HS.pick(pool, 'hs_yogg' .. attempt)
        if not s then return end
        if HS.cast_spell(s, source) then return s end
    end
end

local function one_minion(min) return { area = 'jokers', min = min or 1, max = 1 } end
local function heal_target(n)
    return function(card, t)
        if t[1] then HS.heal(t[1], n) else HS.heal_hero(n, card) end
    end
end

-- =========================================================================
HS.spell { id = 'blessing_of_kings', name = 'Blessing of Kings', hs_id = 'VAN_CS2_092', mana = 4,
    targets = one_minion(),
    text = { 'Give a minion {C:attention}+4/+4{}' },
    effect = function(card, t) HS.buff(t[1], 4, 4) end }

HS.spell { id = 'bloodlust', name = 'Bloodlust', hs_id = 'VAN_CS2_046', mana = 5, in_round = true,
    text = { 'Give your minions {C:mult}+3{}', 'Attack this turn' },
    can = function() return #HS.minions() > 0 end,
    effect = function(card) for _, m in ipairs(HS.minions()) do HS.buff(m, 3, 0, 'turn') end end }

HS.spell { id = 'wild_growth', name = 'Wild Growth', hs_id = 'VAN_CS2_013', mana = 2,
    text = { 'Gain an empty Mana Crystal:', '{C:blue}+1{} Turn each round', '{C:inactive}(at 6 Turns, draw a card){}' },
    effect = function(card)
        if G.GAME.round_resets.hands >= 6 then HS.draw(1, card); return end
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + 1
        if HS.in_round() then ease_hands_played(1) end
        HS.say(card, '+1 Turn', G.C.BLUE)
    end }

HS.spell { id = 'innervate', name = 'Innervate', hs_id = 'VAN_EX1_169', mana = 0, in_round = true,
    text = { 'Gain Mana Crystals this', 'turn only: {C:blue}+1{} Turn', 'this round' },
    effect = function(card) ease_hands_played(1); HS.say(card, '+1 Turn', G.C.BLUE) end }

HS.spell { id = 'power_overwhelming', name = 'Power Overwhelming', hs_id = 'VAN_EX1_316', mana = 1,
    targets = one_minion(),
    text = { 'Give a minion {C:attention}+4/+4{}. At the', 'end of your next turn, it dies.', 'Horribly.' },
    effect = function(card, t) HS.buff(t[1], 4, 4); E(t[1]).doomed = true end }

HS.spell { id = 'pyroblast', name = 'Pyroblast', hs_id = 'VAN_EX1_279', mana = 10,
    text = { 'Deal {C:red}10{} damage to the Blind' },
    effect = function(card) HS.damage_blind(HS.sd(10), card) end }

HS.spell { id = 'lay_on_hands', name = 'Lay on Hands', hs_id = 'VAN_EX1_354', mana = 8,
    targets = one_minion(0),
    text = { 'Restore {C:chips}8{} Health to a minion', '{C:inactive}(or your hero if none chosen){}.', 'Draw 3 cards' },
    effect = function(card, t) heal_target(8)(card, t); HS.draw(3, card) end }

HS.spell { id = 'brawl', name = 'Brawl', hs_id = 'VAN_EX1_407', mana = 5,
    text = { 'Destroy all cards in your hand', 'except one {C:inactive}(chosen randomly){}' },
    can = function() return G.hand and #G.hand.cards >= 2 end,
    effect = function(card)
        local keep = HS.pick(G.hand.cards, 'hs_brawl')
        local doomed = {}
        for _, c in ipairs(G.hand.cards) do if c ~= keep then doomed[#doomed + 1] = c end end
        HS.destroy_cards(doomed, card)
    end }

HS.spell { id = 'mind_control', name = 'Mind Control', hs_id = 'VAN_CS1_113', mana = 10,
    text = { 'Take control of an enemy', 'minion {C:inactive}(a random minion', '{C:inactive}in the Tavern){}' },
    can = function()
        if HS.board_space() <= 0 or not (G.shop_jokers and G.shop_jokers.cards) then return false end
        for _, c in ipairs(G.shop_jokers.cards) do if HS.def(c) then return true end end
        return false
    end,
    effect = function(card) HS.steal_from_shop(card) end }

HS.spell { id = 'frostbolt', name = 'Frostbolt', hs_id = 'VAN_CS2_024', mana = 2,
    text = { 'Deal {C:red}3{} damage to the Blind', 'and {C:attention}Freeze{} it' },
    effect = function(card) HS.damage_blind(HS.sd(3), card); HS.freeze_boss(card) end }

HS.spell { id = 'shield_slam', name = 'Shield Slam', hs_id = 'VAN_EX1_410', mana = 1,
    text = { 'Deal 1 damage to the Blind for', 'each {C:money}$5{} you have {C:inactive}(your Armor){}' },
    effect = function(card)
        HS.damage_blind(HS.sd(math.floor(math.max(0, G.GAME.dollars or 0) / 5)), card)
    end }

HS.spell { id = 'holy_smite', name = 'Holy Smite', hs_id = 'VAN_CS1_130', mana = 1,
    text = { 'Deal {C:red}2{} damage to the Blind' },
    effect = function(card) HS.damage_blind(HS.sd(2), card) end }

HS.spell { id = 'flash_heal', name = 'Flash Heal', hs_id = 'CORE_AT_055', mana = 1,
    targets = one_minion(0),
    text = { 'Restore {C:chips}5{} Health to a minion', '{C:inactive}(or your hero if none chosen){}' },
    effect = heal_target(5) }

HS.spell { id = 'sprint', name = 'Sprint', hs_id = 'VAN_CS2_077', mana = 7,
    text = { 'Draw 4 cards' },
    effect = function(card) HS.draw(4, card) end }

local function hand(min, max) return { area = 'hand', min = min or 1, max = max or 1 } end
local function rank_of(c) local n = HS.rank_num(c); return n end

HS.spell { id = 'equality', name = 'Equality', hs_id = 'VAN_EX1_619', mana = 2,
    targets = hand(2, 3),
    text = { 'Select 2-3 cards. They all', 'become the rank of the', '{C:attention}rightmost{} one' },
    effect = function(card, t)
        local right = t[1]
        for _, c in ipairs(t) do if c.T and right.T and c.T.x > right.T.x then right = c end end
        for _, c in ipairs(t) do if c ~= right then HS.set_rank(c, right.base.value) end end
    end }

HS.spell { id = 'polymorph', name = 'Polymorph', hs_id = 'VAN_CS2_022', mana = 4,
    targets = hand(1, 2),
    text = { 'Transform up to 2 selected', 'cards into {C:attention}Aces{}', '{C:inactive}(1/1 Sheep){}' },
    effect = function(card, t) for _, c in ipairs(t) do HS.set_rank(c, 'Ace') end end }

HS.spell { id = 'shadow_word_death', name = 'Shadow Word: Death', hs_id = 'VAN_EX1_622', mana = 3,
    targets = hand(1, 1),
    text = { 'Destroy a selected card', 'ranked {C:attention}5 or higher{}' },
    can = function(t) return t[1] and (rank_of(t[1]) >= 5 or rank_of(t[1]) == 1) end,
    effect = function(card, t) HS.destroy_cards(t, card) end }

HS.spell { id = 'shadow_word_pain', name = 'Shadow Word: Pain', mana = 2,
    targets = hand(1, 2),
    text = { 'Destroy up to 2 selected', 'cards ranked {C:attention}3 or lower{}', '{C:inactive}(Aces count as 1){}' },
    can = function(t)
        for _, c in ipairs(t) do if rank_of(c) > 3 then return false end end
        return true
    end,
    effect = function(card, t) HS.destroy_cards(t, card) end }

local function enhance_spell(id, name, enh, label, max, extra_text, after)
    local text = { 'Enhance up to ' .. max .. ' selected', 'card' .. (max > 1 and 's' or '') .. ' into ' .. label }
    if extra_text then text[#text + 1] = extra_text end
    HS.spell { id = id, name = name, mana = 1, targets = hand(1, max), text = text,
        effect = function(card, t)
            for _, c in ipairs(t) do HS.enhance(c, enh) end
            if after then after(card, t) end
        end }
end
enhance_spell('mark_of_the_wild', 'Mark of the Wild', 'm_wild', '{C:attention}Wild Cards{}', 2)
enhance_spell('blessing_of_might', 'Blessing of Might', 'm_mult', '{C:attention}Mult Cards{}', 2)
enhance_spell('power_word_shield', 'Power Word: Shield', 'm_bonus', '{C:attention}Bonus Cards{}', 2,
    'Draw a card', function(card) HS.draw(1, card) end)
enhance_spell('hand_of_protection', 'Hand of Protection', 'm_steel', 'a {C:attention}Steel Card{}', 1)
enhance_spell('mirror_image', 'Mirror Image', 'm_glass', 'a {C:attention}Glass Card{}', 1)
enhance_spell('the_coin', 'The Coin', 'm_gold', 'a {C:attention}Gold Card{}', 1)
enhance_spell('roll_the_bones', 'Roll the Bones', 'm_lucky', '{C:attention}Lucky Cards{}', 2)
enhance_spell('earthen_scales', 'Earthen Scales', 'm_stone', 'a {C:attention}Stone Card{}', 1)

HS.spell { id = 'bananas', name = 'Bananas', hs_id = 'EX1_014t', mana = 1, targets = hand(1, 2),
    text = { 'Give up to 2 selected', 'cards {C:attention}+1{} rank' },
    effect = function(card, t) for _, c in ipairs(t) do HS.shift_rank(c, 1) end end }

local function suit_spell(id, name, suit, colour_tag, dmg)
    HS.spell { id = id, name = name, mana = 1, targets = hand(1, 3),
        text = { 'Convert up to 3 selected', 'cards to {C:' .. colour_tag .. '}' .. suit .. '{}.',
            'Deal {C:red}' .. dmg .. '{} damage to the Blind' },
        effect = function(card, t)
            for _, c in ipairs(t) do HS.set_suit(c, suit) end
            HS.damage_blind(HS.sd(dmg), card)
        end }
end
suit_spell('moonfire', 'Moonfire', 'Spades', 'spades', 1)
suit_spell('starfire', 'Starfire', 'Diamonds', 'diamonds', 1)
suit_spell('holy_fire', 'Holy Fire', 'Hearts', 'hearts', 1)
suit_spell('earth_shock', 'Earth Shock', 'Clubs', 'clubs', 1)

HS.spell { id = 'divine_spirit', name = 'Divine Spirit', hs_id = 'VAN_CS2_236', mana = 2,
    targets = one_minion(),
    text = { "Double a minion's Health" },
    effect = function(card, t) HS.buff(t[1], 0, E(t[1]).health) end }

HS.spell { id = 'inner_fire', name = 'Inner Fire', hs_id = 'VAN_CS1_129', mana = 1,
    targets = one_minion(),
    text = { "Change a minion's Attack to", 'be equal to its Health' },
    effect = function(card, t) HS.set_stats(t[1], HS.health(t[1]), nil) end }

HS.spell { id = 'windfury', name = 'Windfury', hs_id = 'VAN_CS2_039', mana = 2,
    targets = one_minion(),
    text = { 'Give a minion {C:attention}Windfury{}' },
    can = function(t) return t[1] and not HS.has(t[1], 'windfury') end,
    effect = function(card, t) HS.give(t[1], 'windfury'); HS.say(t[1], 'Windfury!', G.C.GREEN) end }

HS.spell { id = 'ancestral_spirit', name = 'Ancestral Spirit', hs_id = 'VAN_CS2_038', mana = 2,
    targets = one_minion(),
    text = { 'Choose a minion. When it', 'dies, {C:attention}summon{} it again' },
    effect = function(card, t) E(t[1]).ancestral = true; HS.say(t[1], 'Ancestral!', G.C.GREEN) end }

HS.spell { id = 'arcane_intellect', name = 'Arcane Intellect', hs_id = 'VAN_CS2_023', mana = 3,
    text = { 'Draw 2 cards' },
    effect = function(card) HS.draw(2, card) end }

HS.spell { id = 'fireball', name = 'Fireball', hs_id = 'VAN_CS2_029', mana = 4,
    text = { 'Deal {C:red}6{} damage to the Blind' },
    effect = function(card) HS.damage_blind(HS.sd(6), card) end }

HS.spell { id = 'snake_oil', name = 'Snake Oil', hs_id = 'WW_331t', mana = 0, token = true, cost = 6,
    text = { 'Deal {C:red}0{} damage to the Blind.', 'This seems useless...', '{C:inactive}(Tradeable: sells for $3){}' },
    effect = function(card)
        local n = HS.sd(0)
        if n > 0 then HS.damage_blind(n, card) else HS.say(card, 'Useless...', G.C.UI.TEXT_INACTIVE) end
    end }

HS.spell { id = 'blessed_champion', name = 'Blessed Champion', hs_id = 'VAN_EX1_355', mana = 5,
    targets = one_minion(),
    text = { 'Choose a minion.', 'Double its Attack: give it', '{X:mult,C:white}X2{} Mult permanently' },
    effect = function(card, t)
        E(t[1]).x_mult = (E(t[1]).x_mult or 1) * 2
        HS.say(t[1], 'X2 Mult!', G.C.MULT)
    end }

HS.spell { id = 'savage_roar', name = 'Savage Roar', hs_id = 'VAN_CS2_011', mana = 3, in_round = true,
    text = { 'Give all minions {C:mult}+2{} Attack', 'and {X:mult,C:white}X2{} Mult this turn' },
    can = function() return #HS.minions() > 0 end,
    effect = function(card)
        for _, m in ipairs(HS.minions()) do HS.buff(m, 2, 0, 'turn') end
        HS.state().turn_x_mult = (HS.state().turn_x_mult or 1) * 2
        HS.say(card, 'X2 Mult!', G.C.MULT)
    end }

HS.spell { id = 'apotheosis', name = 'Apotheosis', hs_id = 'BT_257', mana = 3,
    targets = one_minion(),
    text = { 'Give a minion {C:attention}+2/+3{},', '{C:attention}Lifesteal{}, and', '{X:mult,C:white}X1.5{} Mult permanently' },
    effect = function(card, t)
        HS.buff(t[1], 2, 3)
        HS.give(t[1], 'lifesteal')
        E(t[1]).x_mult = (E(t[1]).x_mult or 1) * 1.5
        HS.say(t[1], 'Apotheosis!', G.C.MULT)
    end }

HS.spell { id = 'molten_reflection', name = 'Molten Reflection', hs_id = 'UNG_948', mana = 4,
    targets = one_minion(),
    text = { 'Choose a minion.', '{C:attention}Summon{} an exact copy of it', 'with {X:mult,C:white}X1.5{} Mult' },
    can = function() return HS.board_space() > 0 end,
    effect = function(card, t)
        local c = HS.clone_minion(t[1], card)
        if c then
            local e = E(c)
            e.x_mult = (e.x_mult or 1) * 1.5
            HS.say(c, 'X' .. string.format('%.2f', e.x_mult):gsub('%.?0+$', '') .. ' Mult!', G.C.MULT)
        end
    end }

HS.spell { id = 'shield_block', name = 'Shield Block', hs_id = 'VAN_EX1_606', mana = 3,
    text = { 'Gain 5 {C:attention}Armor{} {C:inactive}(+$5){}.', 'If you hold a {C:attention}Steel Card{}', 'in hand, gain {C:money}$5{} more' },
    effect = function(card)
        local extra = 0
        for _, c in ipairs((G.hand and G.hand.cards) or {}) do
            if c.ability and (c.ability.name == 'Steel Card' or c.ability.effect == 'Steel Card') then extra = 5; break end
        end
        ease_dollars(5 + extra)
        HS.say(card, '+$' .. (5 + extra), G.C.MONEY)
    end }

-- =========================================================================
-- New spells (batch 1)
-- =========================================================================
local function combo() return (HS.state().turn_cards or 0) > 0 end
local function in_hand() return (G.hand and G.hand.cards) or {} end

HS.spell { id = 'eviscerate', name = 'Eviscerate', hs_id = 'VAN_EX1_124', mana = 2,
    text = { 'Deal {C:red}2{} damage to the Blind.', '{C:attention}Combo:{} Deal {C:red}4{} instead' },
    effect = function(card) HS.damage_blind(HS.sd(combo() and 4 or 2), card) end }

HS.spell { id = 'preparation', name = 'Preparation', hs_id = 'VAN_EX1_145', mana = 0, cost = 1,
    text = { 'The next {C:attention}Spell{} you buy', 'in the shop is {C:money}free{}' },
    effect = function(card)
        HS.state().next_spell_free = true
        HS.refresh_costs()
        HS.say(card, 'Next Spell free!', G.C.MONEY)
    end }

HS.spell { id = 'lightning_bolt', name = 'Lightning Bolt', hs_id = 'VAN_EX1_238', mana = 1,
    text = { 'Deal {C:red}3{} damage to the Blind.', '{C:attention}Overload:{} {C:red}1{}' },
    effect = function(card) HS.damage_blind(HS.sd(3), card); HS.overload(1, card) end }

HS.spell { id = 'ice_lance', name = 'Ice Lance', hs_id = 'VAN_CS2_031', mana = 1, in_round = true,
    text = { '{C:attention}Freeze{} the Blind. If it is', 'already Frozen, deal {C:red}4{}', 'damage instead' },
    effect = function(card)
        if HS.state().boss_frozen then HS.damage_blind(HS.sd(4), card) else HS.freeze_boss(card) end
    end }

HS.spell { id = 'soulfire', name = 'Soulfire', hs_id = 'VAN_EX1_308', mana = 0,
    text = { 'Deal {C:red}4{} damage to the Blind.', 'Discard a random card', 'from your hand' },
    effect = function(card)
        HS.damage_blind(HS.sd(4), card)
        if HS.in_round() and #in_hand() > 0 then
            local victim = HS.pick(in_hand(), 'hs_soulfire')
            HS.event(function() draw_card(G.hand, G.discard, nil, nil, nil, victim) end)
        end
    end }

HS.spell { id = 'kill_command', name = 'Kill Command', hs_id = 'VAN_EX1_539', mana = 3,
    text = { 'Deal {C:red}3{} damage to the Blind.', 'If you have a {C:attention}Beast{},', 'deal {C:red}5{} instead' },
    effect = function(card)
        local beast = false
        for _, m in ipairs(HS.minions()) do if HS.is_tribe(m, 'Beast') then beast = true end end
        HS.damage_blind(HS.sd(beast and 5 or 3), card)
    end }

HS.spell { id = 'unleash_the_hounds', name = 'Unleash the Hounds', hs_id = 'VAN_EX1_538', mana = 3,
    targets = hand(1, 3),
    text = { 'For each selected card', '{C:inactive}(up to 3){}, {C:attention}summon{} a 1/1', 'Hound with {C:attention}Charge{}' },
    can = function() return HS.board_space() > 0 end,
    effect = function(card, t) for _ = 1, #t do HS.summon('hound', card) end end }

HS.ANIMAL_COMPANIONS = { 'huffer', 'leokk', 'misha' }
HS.spell { id = 'animal_companion', name = 'Animal Companion', hs_id = 'VAN_NEW1_031', mana = 3,
    text = { '{C:attention}Summon{} Huffer, Leokk', 'or Misha' },
    can = function() return HS.board_space() > 0 end,
    effect = function(card) HS.summon(HS.pick(HS.ANIMAL_COMPANIONS, 'hs_companion'), card) end }

HS.spell { id = 'spreading_plague', name = 'Spreading Plague', hs_id = 'CORE_ICC_054', mana = 6,
    text = { '{C:attention}Summon{} a 1/5 {C:attention}Taunt{} Scarab.', 'Repeat while cards in hand', 'outnumber your minions' },
    can = function() return HS.board_space() > 0 end,
    effect = function(card)
        HS.summon('scarab_beetle', card)
        local guard = 0
        while guard < 7 and HS.board_space() > 0 and #in_hand() > #HS.minions() do
            guard = guard + 1
            HS.summon('scarab_beetle', card)
        end
    end }

HS.spell { id = 'primordial_glyph', name = 'Primordial Glyph', hs_id = 'CORE_UNG_941', mana = 2,
    text = { '{C:attention}Discover{} a Spell. Your next', 'Spell in the shop costs', '{C:money}$2{} less' },
    effect = function(card)
        HS.state().next_spell_discount = 2
        HS.discover('spell', card)
        HS.refresh_costs()
    end }

HS.spell { id = 'cold_blood', name = 'Cold Blood', hs_id = 'VAN_CS2_073', mana = 1,
    targets = one_minion(),
    text = { 'Give a minion {C:mult}+2{} Attack.', '{C:attention}Combo:{} {C:mult}+4{} instead' },
    effect = function(card, t) HS.buff(t[1], combo() and 4 or 2, 0) end }

HS.spell { id = 'divine_favor', name = 'Divine Favor', hs_id = 'VAN_EX1_349', mana = 3, in_round = true,
    text = { 'Draw cards until your', 'hand is full' },
    can = function()
        return G.hand and #G.hand.cards < G.hand.config.card_limit and G.deck and #G.deck.cards > 0
    end,
    effect = function(card) HS.draw(G.hand.config.card_limit - #G.hand.cards, card) end }

HS.spell { id = 'mind_vision', name = 'Mind Vision', hs_id = 'VAN_CS2_003', mana = 1,
    targets = hand(1, 1),
    text = { 'Add a copy of a selected', 'card to your deck' },
    effect = function(card, t)
        HS.create_playing_card(HS.describe_card(t[1]), G.deck)
        HS.say(card, 'Copied!', G.C.FILTER)
    end }

HS.spell { id = 'feral_spirit', name = 'Feral Spirit', hs_id = 'VAN_EX1_248', mana = 3,
    text = { '{C:attention}Summon{} two 2/3 Spirit Wolves', 'with {C:attention}Taunt{}.', '{C:attention}Overload:{} {C:red}2{}' },
    can = function() return HS.board_space() > 0 end,
    effect = function(card)
        HS.summon('spirit_wolf', card)
        HS.summon('spirit_wolf', card)
        HS.overload(2, card)
    end }

HS.spell { id = 'smugglers_run', name = "Smuggler's Run", hs_id = 'CFM_305', mana = 1,
    text = { 'Every card in your hand', 'permanently gains {C:mult}+1{} Mult' },
    can = function() return #in_hand() > 0 end,
    effect = function(card)
        for _, c in ipairs(in_hand()) do
            c.ability.perma_mult = (c.ability.perma_mult or 0) + 1
            if c.juice_up then c:juice_up(0.3, 0.3) end
        end
        HS.say(card, '+1 Mult', G.C.MULT)
    end }

HS.spell { id = 'embiggen', name = 'Embiggen', hs_id = 'DRG_315', mana = 0,
    text = { 'Every card in your deck', 'permanently gains {C:chips}+5{} Chips.',
        'Shop minions cost {C:money}$1{} more', '{C:inactive}(this shop){}' },
    effect = function(card)
        for _, c in ipairs(G.playing_cards or {}) do
            c.ability.perma_bonus = (c.ability.perma_bonus or 0) + 5
        end
        local st = HS.state()
        st.minion_surcharge = (st.minion_surcharge or 0) + 1
        HS.refresh_costs()
        HS.say(card, '+5 Chips to your deck', G.C.CHIPS)
    end }

-- Ysera's Dream cards (only from Ysera)
HS.spell { id = 'ysera_awakens', name = 'Ysera Awakens', hs_id = 'VAN_DREAM_02', mana = 2, token = true,
    text = { 'Deal {C:red}5{} damage to the Blind' },
    effect = function(card) HS.damage_blind(HS.sd(5), card) end }

HS.spell { id = 'nightmare', name = 'Nightmare', hs_id = 'VAN_DREAM_05', mana = 0, token = true,
    targets = one_minion(),
    text = { 'Give a minion {C:attention}+5/+5{}. At the', 'end of your next turn, it dies' },
    effect = function(card, t) HS.buff(t[1], 5, 5); E(t[1]).doomed = true end }

HS.spell { id = 'emerald_drake', name = 'Emerald Drake', hs_id = 'VAN_DREAM_03', mana = 4, token = true,
    text = { '{C:attention}Summon{} a 7/6 Emerald Drake' },
    can = function() return HS.board_space() > 0 end,
    effect = function(card) HS.summon('emerald_drake', card) end }

HS.spell { id = 'laughing_sister', name = 'Laughing Sister', hs_id = 'VAN_DREAM_01', mana = 2, token = true,
    text = { '{C:attention}Summon{} a 3/5 Laughing Sister', 'with {C:attention}Stealth{}' },
    can = function() return HS.board_space() > 0 end,
    effect = function(card) HS.summon('laughing_sister', card) end }


return HS.spells
