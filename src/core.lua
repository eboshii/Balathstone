-- Balathstone Core Engine
-- =========================================================================
-- One shared rules engine for every Hearthstone card. Individual cards only
-- describe WHAT they do (battlecry / deathrattle / aura / triggers); this file
-- decides WHEN things happen, so every card with the same keyword behaves the
-- same way.
--
-- Hearthstone -> Balatro translation (shown to players as keyword tooltips):
--   Minion stats      Attack = +Mult, Health = +Chips, scored every turn.
--   Turn              One played hand. "This turn" = until that hand is scored.
--   Battlecry         Triggers at the start of every round (after the first
--                     hand is drawn). Brann Bronzebeard doubles it.
--   Start of Game     Also at the start of every round, never doubled.
--   Deathrattle       Triggers when the minion dies (Boss damage, spells...)
--                     or is sold. Baron Rivendare doubles it.
--   The Blind         The enemy hero. 1 damage = -2% score requirement.
--                     Healing the Blind raises it by 2% per point.
--   Your hero         Your money. Restoring Health gives $ (never above $30),
--                     damage costs $, Armor gives $ with no cap.
--   Summon            Creates that exact minion in a free Minion slot.
--   Spell             Any Spell or Forbidden Spell consumable you use.
--   Combo             You used a Spell or a Mulligan earlier this turn.
--   Secret            A Tag (Encounter skip reward). Ante is kept as Ante.
--   Freeze (Boss)     The Boss skips its next attack.
--   Silence (Boss)    Disables the Boss Blind's ability.
-- =========================================================================

Balathstone = Balathstone or Balearthstone or {}
Balearthstone = Balathstone
local HS = Balathstone
HS.version = "2.0.0"
HS.defs = HS.defs or {}           -- center key -> minion definition
HS.spells = HS.spells or {}       -- list of spell definitions
HS.BLIND_DMG_PCT = 0.02           -- each point of damage = 2% of the Blind
HS.CHIPS_PER_HEALTH = 1           -- each point of minion Health scores 1 Chip
HS.HERO_MAX = 30                  -- hero Health cap for healing ($)

function HS.voucher(id)
    return G.GAME and G.GAME.used_vouchers and G.GAME.used_vouchers['v_hs_' .. id] and true or false
end

function HS.hero_max()
    return HS.voucher('potion_of_vitality') and 2 * HS.HERO_MAX or HS.HERO_MAX
end

-- -------------------------------------------------------------------------
-- Run state
-- -------------------------------------------------------------------------
function HS.state()
    G.GAME.hs = G.GAME.hs or {
        pending_blind = 0,      -- blind damage dealt outside a round
        pending_draws = 0,      -- cards to draw at the start of the next round
        turn_cards = 0,         -- spells + discards used this turn (Combo)
        hand_index = 0,         -- hands played this round
        spells_cast = 0,        -- spells used this run (Yogg-Saron)
        deaths = 0,             -- friendly minions that died this run
        died_this_turn = {},    -- for Kel'Thuzad
        boss_frozen = false,
        boss_disarmed = false,
        boss_half = false,
        shop_discount = 0,      -- Emperor Thaurissan
        tribe_discount = {},    -- Kindling Elemental / Frequency Oscillator
        shop_steals = 0,        -- Mind Control Tech
        shop_extra_minions = 0, -- Dirty Rat
        turn_pending = false,
        end_of_turn_summons = {},
    }
    return G.GAME.hs
end

function HS.play_sound(key, per, vol)
    if play_sound then
        pcall(play_sound, 'hs_' .. key, per or 1, vol or 1)
    end
end

-- -------------------------------------------------------------------------
-- Small helpers
-- -------------------------------------------------------------------------
local function E(card)
    return card and card.ability and type(card.ability.extra) == 'table' and card.ability.extra or nil
end
HS.E = E

function HS.def(card)
    return card and card.config and card.config.center and card.config.center.hs_minion or nil
end

function HS.is_minion(card)
    return HS.def(card) ~= nil and E(card) ~= nil
end

function HS.alive(card)
    local e = E(card)
    return HS.is_minion(card) and not e.dying and not card.getting_sliced and not card.removed
end

-- Living minions, left to right (a snapshot, safe to iterate while summoning)
function HS.minions()
    local t = {}
    if G.jokers and G.jokers.cards then
        for _, c in ipairs(G.jokers.cards) do
            if HS.alive(c) then t[#t + 1] = c end
        end
    end
    return t
end

function HS.others(card)
    local t = {}
    for _, c in ipairs(HS.minions()) do if c ~= card then t[#t + 1] = c end end
    return t
end

function HS.index(card)
    if not (G.jokers and G.jokers.cards) then return nil end
    for i, c in ipairs(G.jokers.cards) do if c == card then return i end end
end

function HS.neighbour(card, dir)
    local i = HS.index(card)
    if not i then return nil end
    local j = i + dir
    while G.jokers.cards[j] do
        local c = G.jokers.cards[j]
        if HS.alive(c) then return c end
        j = j + dir
    end
    return nil
end
function HS.right(card) return HS.neighbour(card, 1) end
function HS.left(card) return HS.neighbour(card, -1) end
function HS.adjacent(card)
    local t = {}
    local l, r = HS.left(card), HS.right(card)
    if l then t[#t + 1] = l end
    if r then t[#t + 1] = r end
    return t
end

-- living, non-Silenced copies of a minion (Brann, Rivendare, Kel'Thuzad... lose their ability when Silenced)
function HS.count(id)
    local n = 0
    for _, c in ipairs(HS.minions()) do
        if c.config.center.key == 'j_hs_' .. id and not HS.silenced(c) then n = n + 1 end
    end
    return n
end
function HS.has_minion(id) return HS.count(id) > 0 end

function HS.is_tribe(card, tribe)
    local d = HS.def(card)
    if not d or not d.tribe then return false end
    if type(d.tribe) == 'table' then
        for _, t in ipairs(d.tribe) do if t == tribe or t == 'All' then return true end end
        return false
    end
    return d.tribe == tribe or d.tribe == 'All'
end

function HS.event(fn, delay)
    if G.E_MANAGER and Event then
        G.E_MANAGER:add_event(Event({
            trigger = delay and 'after' or nil,
            delay = delay,
            func = function() fn(); return true end
        }))
    else
        fn()
    end
end

function HS.say(card, msg, colour)
    if card and card_eval_status_text then
        card_eval_status_text(card, 'extra', nil, nil, nil, { message = msg, colour = colour or G.C.FILTER })
    end
end

function HS.rand(seed)
    if pseudorandom then return pseudorandom(pseudoseed and pseudoseed(seed) or seed) end
    return math.random()
end

function HS.pick(list, seed)
    if not list or #list == 0 then return nil end
    if pseudorandom_element then return pseudorandom_element(list, pseudoseed(seed)) end
    return list[math.random(#list)]
end

function HS.in_round()
    return G.GAME and G.GAME.facing_blind and G.GAME.blind and (G.GAME.blind.chips or 0) > 0 and true or false
end

function HS.is_boss()
    return HS.in_round() and G.GAME.blind.boss and true or false
end

-- The current Blind's definition if it attacks your minions (bosses and encounters)
function HS.enemy()
    if not HS.in_round() then return nil end
    local c = G.GAME.blind.config and G.GAME.blind.config.blind
    if c and (c.hs_atk or c.boss_atk) then return c end
    return nil
end

-- Is the Blind's ability (quirk / boss effect) active, i.e. not Silenced?
function HS.enemy_quirks()
    return HS.enemy() ~= nil and not G.GAME.blind.disabled
end

-- Is the current (non-disabled) Boss Blind this one?
function HS.boss_is(id)
    return HS.is_boss() and not G.GAME.blind.disabled and G.GAME.blind.config and G.GAME.blind.config.blind
        and G.GAME.blind.config.blind.key == 'bl_hs_' .. id or false
end

function HS.mana()
    return (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
end

-- -------------------------------------------------------------------------
-- Stats & keywords
-- -------------------------------------------------------------------------
HS.KEYWORDS = { 'taunt', 'divine_shield', 'windfury', 'mega_windfury', 'charge', 'rush', 'lifesteal',
    'stealth', 'reborn', 'poisonous' }

function HS.is_damaged(card)
    local e = E(card)
    return e and e.health < e.max_health
end

-- keyword check: own keywords, enrage, granted by other minions' auras
function HS.has(card, kw)
    local e = E(card)
    if not e then return false end
    if e.kw and e.kw[kw] and not e.silenced then return true end
    if kw == 'rush' and HS.voucher('rocket_backpacks') then return true end
    if kw == 'stealth' and HS.voucher('cloak_of_invisibility') then return true end
    local d = HS.def(card)
    if d and not e.silenced then
        if d.enrage and d.enrage[kw] and HS.is_damaged(card) then return true end
        if d.dyn_kw and d.dyn_kw(card, kw) then return true end
    end
    for _, o in ipairs(HS.others(card)) do
        local od = HS.def(o)
        if od.grant and not HS.silenced(o) and od.grant(o, card, kw) then return true end
    end
    return false
end

function HS.attack(card)
    local e = E(card)
    if not e then return 0 end
    local a = (e.attack or 0) + (e.turn_atk or 0) + (e.round_atk or 0)
    if HS.voucher('captured_flag') then a = a + 1 end
    local d = HS.def(card)
    if d and not e.silenced then
        if d.enrage and d.enrage.atk and HS.is_damaged(card) then a = a + d.enrage.atk end
        if d.dyn_atk then a = a + (d.dyn_atk(card) or 0) end
    end
    for _, o in ipairs(HS.others(card)) do
        local od = HS.def(o)
        if od.aura and not HS.silenced(o) then
            local da = od.aura(o, card)
            a = a + (da or 0)
        end
    end
    return math.max(0, a)
end

function HS.health(card)
    local e = E(card)
    if not e then return 0 end
    local h = e.health or 0
    if HS.voucher('captured_flag') then h = h + 1 end
    for _, o in ipairs(HS.others(card)) do
        local od = HS.def(o)
        if od.aura and not HS.silenced(o) then
            local _, dh = od.aura(o, card)
            h = h + (dh or 0)
        end
    end
    return math.max(0, h)
end

-- Permanent buff (mode nil), or 'turn' / 'round' temporary Attack
function HS.buff(card, atk, hp, mode, silent)
    local e = E(card)
    if not e or e.dying then return end
    atk, hp = atk or 0, hp or 0
    if mode == 'turn' then
        e.turn_atk = (e.turn_atk or 0) + atk
    elseif mode == 'round' then
        e.round_atk = (e.round_atk or 0) + atk
    else
        e.attack = math.max(0, (e.attack or 0) + atk)
        if hp ~= 0 then
            e.max_health = math.max(1, e.max_health + hp)
            e.health = math.max(1, e.health + hp)
        end
    end
    if not silent then
        HS.say(card, string.format("%+d/%+d", atk, hp), (atk < 0 or hp < 0) and G.C.RED or G.C.GREEN)
    end
end

function HS.set_stats(card, atk, hp)
    local e = E(card)
    if not e then return end
    if atk then e.attack = atk end
    if hp then e.health = hp; e.max_health = hp end
    HS.say(card, string.format("%d/%d", e.attack, e.health), G.C.FILTER)
end

function HS.give(card, kw)
    local e = E(card)
    if not e then return end
    e.kw = e.kw or {}
    e.kw[kw] = true
    if kw == 'divine_shield' then e.shield = true end
end

-- -------------------------------------------------------------------------
-- Damage, healing, death
-- -------------------------------------------------------------------------
-- notify every living minion that has a handler `name` (left to right)
function HS.silenced(card)
    local e = E(card)
    return e and e.silenced and true or false
end

function HS.notify(name, ...)
    for _, c in ipairs(HS.minions()) do
        local d = HS.def(c)
        if d and d[name] and not HS.silenced(c) then d[name](c, ...) end
    end
end

function HS.heal(card, n)
    local e = E(card)
    if not e or e.dying or n <= 0 then return 0 end
    local healed = math.min(n, e.max_health - e.health)
    if healed <= 0 then return 0 end
    e.health = e.health + healed
    HS.say(card, '+' .. healed .. ' Health', G.C.GREEN)
    HS.notify('on_heal', card, healed)
    return healed
end

function HS.damage(card, n, source)
    local e = E(card)
    if not e or e.dying or not n or n <= 0 then return 0 end
    if e.shield then
        e.shield = false
        HS.say(card, 'Divine Shield!', G.C.GOLD)
        return 0
    end
    e.health = e.health - n
    HS.say(card, '-' .. n .. ' Health', G.C.RED)
    local d = HS.def(card)
    if d.on_damaged and not e.silenced then d.on_damaged(card, n, source) end
    for _, o in ipairs(HS.others(card)) do
        local od = HS.def(o)
        if od.on_any_damaged and not HS.silenced(o) then od.on_any_damaged(o, card, n) end
    end
    if e.health <= 0 then
        HS.kill(card, 'damage')
    elseif d.on_survive and not e.silenced then
        d.on_survive(card, n, source)
    end
    return n
end

-- how: 'damage' | 'destroy' | 'sold'
function HS.kill(card, how)
    local e = E(card)
    if not e or e.dying then return end
    e.dying = true
    local d = HS.def(card)
    local st = HS.state()
    st.deaths = st.deaths + 1
    if how ~= 'sold' then
        st.died_this_turn[#st.died_this_turn + 1] = card.config.center.key
    end
    -- Deathrattles (doubled by Baron Rivendare)
    local times = HS.has_minion('baron_rivendare') and 2 or 1
    local has_dr = (d.deathrattle or e.ancestral) and not e.silenced
    if has_dr then
        for i = 1, times do
            if d.deathrattle then d.deathrattle(card, i) end
            if e.ancestral then HS.summon(card.config.center.key, card) end
        end
        HS.say(card, times > 1 and 'Deathrattle x2!' or 'Deathrattle!', G.C.PURPLE)
    end
    for _, o in ipairs(HS.others(card)) do
        local od = HS.def(o)
        if od.on_death and not HS.silenced(o) then od.on_death(o, card, how) end
    end
    if how == 'sold' then return end
    if e.kw and e.kw.reborn then
        e.kw.reborn = false
        e.dying = nil
        e.health = 1
        e.shield = false
        HS.say(card, 'Reborn!', G.C.GREEN)
        return
    end
    card.getting_sliced = true
    HS.event(function()
        if card.start_dissolve then card:start_dissolve({ G.C.RED }, nil, 1.6) end
    end)
    if HS.trigger_secret then HS.trigger_secret('minion_death', card) end
end

-- -------------------------------------------------------------------------
-- Summoning / creating cards
-- -------------------------------------------------------------------------
function HS.board_space()
    if not G.jokers then return 0 end
    local used = 0
    for _, c in ipairs(G.jokers.cards) do
        local e = E(c)
        if not (c.getting_sliced or c.removed or (e and e.dying)) then used = used + 1 end
    end
    return G.jokers.config.card_limit - used
end

-- Summon an exact minion (id like 'murloc_scout' or full key 'j_hs_murloc_scout')
function HS.summon(id, source, opts)
    local key = id:find('^j_') and id or ('j_hs_' .. id)
    if not (G.P_CENTERS and G.P_CENTERS[key]) then return nil end
    if HS.board_space() <= 0 then
        if source then HS.say(source, 'Board full!', G.C.RED) end
        return nil
    end
    local card = SMODS.add_card({ set = 'Joker', key = key, area = G.jokers, key_append = 'hs_summon' })
    if not card then return nil end
    local e = E(card)
    if e then
        e.summoned = true
        if opts then
            -- temporary summons leave quietly at the end of the round (no Deathrattle)
            if opts.temporary then e.temporary = true end
            if opts.health then e.health = opts.health end
            if opts.kw then for _, k in ipairs(opts.kw) do HS.give(card, k) end end
            if opts.extra then for k, v in pairs(opts.extra) do e[k] = v end end
        end
    end
    if card.set_cost then card:set_cost() end
    HS.notify('on_summon', card)
    return card
end

function HS.clone_minion(target, source)
    if not (target and HS.alive(target)) then return nil end
    if HS.board_space() <= 0 then
        if source then HS.say(source, 'Board full!', G.C.RED) end
        return nil
    end
    local key = target.config.center.key
    local card = SMODS.add_card({ set = 'Joker', key = key, area = G.jokers, key_append = 'hs_summon' })
    if not card then return nil end
    local src_e = E(target)
    local dst_e = E(card)
    if src_e and dst_e then
        local copy_fn = copy_table or function(t)
            if type(t) ~= 'table' then return t end
            local r = {}
            for k, v in pairs(t) do r[k] = type(v) == 'table' and copy_fn(v) or v end
            return r
        end
        local cloned_extra = copy_fn(src_e)
        cloned_extra.summoned = true
        cloned_extra.dying = nil
        cloned_extra.frozen = nil
        cloned_extra.scored_this_hand = nil
        card.ability.extra = cloned_extra
    end
    if target.edition then
        local copy_fn = copy_table or function(t)
            if type(t) ~= 'table' then return t end
            local r = {}
            for k, v in pairs(t) do r[k] = v end
            return r
        end
        card:set_edition(copy_fn(target.edition), true)
    end
    if card.set_cost then card:set_cost() end
    HS.notify('on_summon', card)
    return card
end

function HS.summon_random(filter, source, opts)
    local pool = {}
    for key, d in pairs(HS.defs) do
        if not d.token and (not filter or filter(d)) then pool[#pool + 1] = key end
    end
    table.sort(pool)
    local key = HS.pick(pool, 'hs_summon_random')
    if key then return HS.summon(key, source, opts) end
end

function HS.consumable_space()
    if not G.consumeables then return 0 end
    return G.consumeables.config.card_limit - #G.consumeables.cards - (G.GAME.consumeable_buffer or 0)
end

-- Add a spell to your "hand" (consumable slots). key nil = random Spell.
function HS.add_spell(key, source, filter)
    if HS.consumable_space() <= 0 then
        if source then HS.say(source, 'No room!', G.C.RED) end
        return nil
    end
    if not key and filter then
        local pool = {}
        for _, s in ipairs(HS.spells) do
            if not s.token and filter(s) then pool[#pool + 1] = s.key end
        end
        key = HS.pick(pool, 'hs_add_spell')
    end
    local t = { set = 'Tarot', area = G.consumeables, key_append = 'hs_spell' }
    if key then t.key = key:find('^c_') and key or ('c_hs_' .. key) end
    return SMODS.add_card(t)
end

-- -------------------------------------------------------------------------
-- The Blind (enemy hero) and your hero (money)
-- -------------------------------------------------------------------------
function HS.update_blind_text()
    if G.GAME.blind then
        G.GAME.blind.chip_text = number_format and number_format(G.GAME.blind.chips) or tostring(G.GAME.blind.chips)
    end
end

function HS.damage_blind(n, source, ignore_stealth)
    if not n or n == 0 then return end
    if not HS.in_round() then
        local st = HS.state()
        st.pending_blind = st.pending_blind + n
        if source then HS.say(source, (n > 0 and n .. ' dmg' or -n .. ' heal') .. ' (next Blind)', G.C.FILTER) end
        return
    end
    local st0 = HS.state()
    if n > 0 and not ignore_stealth and HS.enemy_quirks() and G.GAME.blind.config.blind.hs_stealth
        and not st0.boss_has_attacked then
        if source then HS.say(source, 'Stealthed!', G.C.UI.TEXT_INACTIVE) end
        HS.blind_say('Stealthed!', G.C.UI.TEXT_INACTIVE)
        return
    end
    if n > 0 and st0.blind_shield and HS.enemy_quirks() then
        st0.blind_shield = false
        if source then HS.say(source, 'Blocked by Divine Shield', G.C.GOLD) end
        HS.blind_say('Divine Shield!', G.C.GOLD)
        return
    end
    local factor = (1 - HS.BLIND_DMG_PCT) ^ n
    G.GAME.blind.chips = math.max(1, math.floor(G.GAME.blind.chips * factor))
    HS.update_blind_text()
    if source then
        if n > 0 then
            HS.say(source, n .. ' damage to Blind!', G.C.RED)
        else
            HS.say(source, 'Blind healed ' .. (-n), G.C.BLUE)
        end
    end
end

function HS.heal_blind(n, source) HS.damage_blind(-n, source) end

-- Pop a message on the Blind itself (its abilities have no card to speak from)
function HS.blind_say(msg, colour)
    local blind = G.GAME and G.GAME.blind
    local sprite = blind and blind.children and blind.children.animatedSprite
    if blind and blind.wiggle then blind:wiggle() end
    if not (attention_text and sprite) then return end
    attention_text({ text = msg, scale = 0.55, hold = 1.1, major = sprite, align = 'cm',
        offset = { x = 0, y = -0.95 }, colour = colour or G.C.RED, emboss = 0.05 })
end

function HS.heal_hero(n, source)
    local have = G.GAME.dollars or 0
    local gain = math.max(0, math.min(n, HS.hero_max() - have))
    if gain > 0 then ease_dollars(gain) end
    if source then HS.say(source, gain > 0 and ('+$' .. gain) or 'Full Health', G.C.MONEY) end
    return gain
end

function HS.damage_hero(n, source)
    local have = math.max(0, G.GAME.dollars or 0)
    local loss = math.min(n, have)
    if loss > 0 then ease_dollars(-loss) end
    if source then HS.say(source, '-$' .. loss, G.C.RED) end
end

function HS.armor(n, source)
    if n <= 0 then return end
    ease_dollars(n)
    if source then HS.say(source, '+$' .. n .. ' Armor', G.C.MONEY) end
end

function HS.draw(n, source)
    if n <= 0 then return end
    if HS.in_round() and G.hand and G.deck then
        HS.event(function()
            for i = 1, math.min(n, #G.deck.cards) do
                draw_card(G.deck, G.hand, i * 100 / n, 'up', true)
            end
        end)
    else
        local st = HS.state()
        st.pending_draws = st.pending_draws + n
    end
    if source then HS.say(source, n == 1 and 'Draw!' or ('Draw ' .. n .. '!'), G.C.BLUE) end
end

-- Overload (N): you have N fewer Discards next round (Discards are your Hero Power)
function HS.overload(n, source)
    if not n or n <= 0 then return end
    local st = HS.state()
    st.overload = (st.overload or 0) + n
    if source then HS.say(source, 'Overload (' .. n .. ')', G.C.RED) end
end

function HS.freeze_boss(source)
    HS.state().boss_frozen = true
    if G.GAME and G.GAME.blind and G.GAME.blind.wiggle then
        G.GAME.blind:wiggle()
    end
    if source then HS.say(source, 'Boss Frozen!', G.C.BLUE) end
end

function HS.silence_boss(source)
    if HS.in_round() and not G.GAME.blind.disabled then
        G.GAME.blind:disable()
        if source then HS.say(source, 'Silenced!', G.C.FILTER) end
        return true
    end
    return false
end

-- Win the round by meeting the score requirement, then let the game's own
-- flow end it (calling end_round() directly can run it twice).
function HS.win_blind(source)
    if not HS.in_round() then return end
    G.GAME.chips = math.max(G.GAME.chips or 0, G.GAME.blind.chips)
    if source then HS.say(source, 'DESTROYED!', G.C.RED) end
    HS.event(function()
        -- mid-hand, the normal "score >= Blind" check ends the round; while
        -- choosing cards (e.g. after selling) nothing would check, so do it here
        if G.STATES and G.STATE == G.STATES.SELECTING_HAND then
            G.STATE = G.STATES.NEW_ROUND
            G.STATE_COMPLETE = false
        end
    end)
end

-- Spell Damage +N from your minions
function HS.spell_damage()
    local n = 0
    for _, c in ipairs(HS.minions()) do
        local d = HS.def(c)
        if not HS.silenced(c) then
            if d.spell_damage then n = n + d.spell_damage end
            n = n + (E(c).spell_damage or 0) -- gained Spell Damage (Mozaki)
        end
    end
    return n
end

-- -------------------------------------------------------------------------
-- Deck checks (Reno, Zephrys, Keleseth, Baku, Genn)
-- -------------------------------------------------------------------------
local RANK_NUM = { Ace = 1, Jack = 11, Queen = 12, King = 13 }
function HS.rank_num(card)
    local v = card.base and card.base.value
    return RANK_NUM[v] or tonumber(v) or (card.base and card.base.id) or 0
end

function HS.deck_has_duplicates()
    local seen = {}
    for _, c in ipairs(G.playing_cards or {}) do
        if c.base and c.base.suit and c.base.value then
            local k = c.base.suit .. '_' .. c.base.value
            if seen[k] then return true end
            seen[k] = true
        end
    end
    return false
end

function HS.deck_all(pred)
    if not G.playing_cards or #G.playing_cards == 0 then return false end
    for _, c in ipairs(G.playing_cards) do
        if not pred(c) then return false end
    end
    return true
end

-- -------------------------------------------------------------------------
-- Boss attacks (once per played hand)
-- -------------------------------------------------------------------------
-- Enemy attack: printed Attack scaled by Ante (x0.6 at Ante 1 ... x1.3 at Ante 8)
function HS.scaled_attack(base)
    return math.max(1, math.floor(base * (0.5 + 0.1 * HS.mana()) + 0.5))
end

function HS.boss_attack_value()
    local center = G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind
    local base = (center and (center.hs_atk or center.boss_atk)) or math.max(3, HS.mana() * 2)
    local atk = HS.scaled_attack(base) + (HS.state().enemy_ramp or 0)
    if HS.state().boss_half then atk = math.floor(atk / 2) end
    if HS.voucher('glyph_of_warding') then atk = atk - 2 end
    return math.max(0, atk)
end

function HS.boss_target(mode, atk, center, quirks)
    atk = atk or HS.boss_attack_value()
    local ms = HS.minions()
    local cloak = HS.voucher('cloak_of_invisibility')
    local function targetable(c)
        if not (c and HS.alive(c)) then return false end
        if cloak then return false end
        return not (HS.has(c, 'stealth') and not E(c).stealth_broken)
    end

    local valid = {}
    local taunts = {}
    for _, c in ipairs(ms) do
        if targetable(c) then
            valid[#valid + 1] = c
            if HS.has(c, 'taunt') then
                taunts[#taunts + 1] = c
            end
        end
    end
    if #valid == 0 then return nil end

    -- 'strongest' bosses ignore Taunt (see their card text)
    local pool = (#taunts > 0 and mode ~= 'strongest') and taunts or valid

    if mode == 'random' then
        return HS.pick(pool, 'hs_enemy_target')
    elseif mode == 'strongest' then
        local best
        for _, c in ipairs(pool) do
            if not best or HS.attack(c) > HS.attack(best) then best = c end
        end
        return best
    elseif mode == 'healthiest' then
        local best
        for _, c in ipairs(pool) do
            if not best or HS.health(c) > HS.health(best) then best = c end
        end
        return best
    end

    -- Smart targeting: aim to kill the best minion it can
    local function minion_val(c)
        local d = HS.def(c) or {}
        local r = d.rarity or 1
        local m = d.mana or 1
        return HS.attack(c) * 10 + HS.health(c) * 5 + r * 15 + m * 4
    end

    local function can_kill(c)
        local e = E(c)
        if e and e.shield then return false end -- Divine Shield absorbs damage
        if quirks and center and center.hs_poison and atk > 0 then return true end
        return HS.health(c) <= atk
    end

    local killable = {}
    for _, c in ipairs(pool) do
        if can_kill(c) then
            killable[#killable + 1] = c
        end
    end

    local target_list = #killable > 0 and killable or pool
    local best = target_list[1]
    local best_val = minion_val(best)
    for i = 2, #target_list do
        local c = target_list[i]
        local val = minion_val(c)
        if val > best_val then
            best = c
            best_val = val
        end
    end
    return best
end

-- Telegraph: who the Blind will hit next. Returns { [card] = 'sure' | 'maybe' }.
-- Random-target Blinds mark every possible target as 'maybe' (no RNG is consumed).
function HS.predict_boss_targets()
    local out = {}
    local center = HS.enemy()
    if not center then return out end
    local st = HS.state()
    if st.boss_frozen or st.boss_disarmed then return out end
    local quirks = not G.GAME.blind.disabled
    local mode = quirks and center.hs_mode or nil
    if mode == 'aoe' then
        for _, m in ipairs(HS.minions()) do out[m] = 'sure' end
        return out
    end
    if mode == 'random' then
        local cloak = HS.voucher('cloak_of_invisibility')
        local valid, taunts = {}, {}
        for _, c in ipairs(HS.minions()) do
            if not cloak and not (HS.has(c, 'stealth') and not E(c).stealth_broken) then
                valid[#valid + 1] = c
                if HS.has(c, 'taunt') then taunts[#taunts + 1] = c end
            end
        end
        for _, c in ipairs(#taunts > 0 and taunts or valid) do out[c] = 'maybe' end
        return out
    end
    local t = HS.boss_target(mode, HS.boss_attack_value(), center, quirks)
    if t then out[t] = 'sure' end
    return out
end

-- One enemy attack on one minion; the defender strikes back at the Blind
function HS.attack_minion(target, atk, center, quirks)
    HS.play_sound('attack')
    if target then
        target.hs_attack_anim = {
            start_time = (G.TIMERS and G.TIMERS.REAL) or 0,
            duration = 0.7,
            atk = atk
        }
        if target.juice_up then target:juice_up(0.85, 0.45) end
    end
    if G.GAME and G.GAME.blind then
        if G.GAME.blind.wiggle then G.GAME.blind:wiggle() end
        if G.GAME.blind.children and G.GAME.blind.children.animatedSprite and G.GAME.blind.children.animatedSprite.juice_up then
            G.GAME.blind.children.animatedSprite:juice_up(0.6, 0.5)
        end
    end
    if G.ROOM and G.ROOM.jiggle then
        G.ROOM.jiggle = G.ROOM.jiggle + 2.5
    end
    -- Secrets react first (Freezing Trap cancels, Noble Sacrifice redirects...)
    local sec = HS.trigger_secret and HS.trigger_secret('boss_attack', target, atk)
    if sec and sec.cancel then return end
    if sec and sec.redirect then target = sec.redirect end
    local d = HS.def(target)
    local back = HS.attack(target) + (d.defend_atk or 0)
    local dealt = HS.damage(target, atk, 'boss')
    if quirks and center then
        if center.hs_poison and dealt > 0 and HS.alive(target) then HS.kill(target, 'destroy') end
        if center.hs_freeze and HS.alive(target) then HS.freeze_minion(target) end
        if center.hs_steal then
            HS.damage_hero(center.hs_steal)
            HS.blind_say('Stole $' .. center.hs_steal .. '!', G.C.MONEY)
        end
        -- Lifesteal: the damage it deals heals the Blind
        if center.hs_lifesteal and dealt > 0 then
            HS.heal_blind(dealt)
            HS.blind_say('Lifesteal +' .. dealt, G.C.GREEN)
        end
        -- grows when it kills a minion (Darius Crowley)
        if center.hs_kill_ramp and not HS.alive(target) then
            local st = HS.state()
            st.enemy_ramp = (st.enemy_ramp or 0) + center.hs_kill_ramp
            HS.blind_say('+' .. center.hs_kill_ramp .. ' Attack', G.C.RED)
        end
    end
    if back > 0 then HS.damage_blind(back, target) end
end

-- The Blind's turn: runs after hand scoring (if Blind is not defeated)
function HS.boss_attack()
    local center = HS.enemy()
    if not center then return end
    local st = HS.state()
    -- its turn has come: Stealth lifts even if it then can't attack (Frozen, disarmed)
    st.boss_has_attacked = true
    if st.boss_disarmed then return end
    if st.boss_frozen then
        st.boss_frozen = false
        return
    end
    local quirks = not G.GAME.blind.disabled
    local atk = HS.boss_attack_value()
    local mode = quirks and center.hs_mode or nil
    if mode == 'aoe' then
        local sec = HS.trigger_secret and HS.trigger_secret('boss_attack', nil, atk)
        if sec and sec.cancel then return end
        for _, m in ipairs(HS.minions()) do
            m.hs_attack_anim = {
                start_time = (G.TIMERS and G.TIMERS.REAL) or 0,
                duration = 0.7,
                atk = atk
            }
            if m.juice_up then m:juice_up(0.7, 0.4) end
            HS.damage(m, atk, 'boss')
        end
        if G.GAME and G.GAME.blind then
            if G.GAME.blind.wiggle then G.GAME.blind:wiggle() end
            if G.GAME.blind.children and G.GAME.blind.children.animatedSprite and G.GAME.blind.children.animatedSprite.juice_up then
                G.GAME.blind.children.animatedSprite:juice_up(0.7, 0.6)
            end
        end
        if G.ROOM and G.ROOM.jiggle then G.ROOM.jiggle = G.ROOM.jiggle + 3.5 end
    else
        local times = quirks and center.hs_times or 1
        -- Enrage: once you have scored half the Blind, it attacks one more time
        if quirks and center.hs_enrage and (G.GAME.chips or 0) * 2 >= (G.GAME.blind.chips or 0) then
            times = times + 1
            HS.blind_say('Enraged!', G.C.RED)
        end
        for _ = 1, times do
            local target = HS.boss_target(mode, atk, center, quirks)
            if target then HS.attack_minion(target, atk, center, quirks) end
        end
    end
    -- its summoned army (Stewards, Imps, Demons) each attack a random minion
    for _, a in ipairs(st.enemy_army or {}) do
        local target = HS.boss_target('random', a, center, false)
        if target then HS.attack_minion(target, HS.scaled_attack(a), nil, false) end
    end
    if quirks and center.hs_army then
        st.enemy_army = st.enemy_army or {}
        st.enemy_army[#st.enemy_army + 1] = center.hs_army + (center.hs_army_grow or 0) * #st.enemy_army
        HS.blind_say('Summons a ' .. (center.hs_army_name or 'minion') .. '!', G.C.RED)
    end
    if quirks and center.hs_ramp then
        st.enemy_ramp = (st.enemy_ramp or 0) + center.hs_ramp
        HS.blind_say('+' .. center.hs_ramp .. ' Attack', G.C.RED)
    end
end

-- A Silenced minion doesn't score for the rest of the round (Web Wrap, Mind Control)
function HS.silence_minion(card)
    local e = E(card)
    if not e then return end
    e.silenced = true
    HS.say(card, 'Silenced!', G.C.UI.TEXT_INACTIVE)
end

-- A Frozen minion doesn't score on its next turn
function HS.freeze_minion(card, source)
    local e = E(card)
    if not e then return end
    e.frozen = true
    HS.say(card, 'Frozen!', G.C.BLUE)
end

-- -------------------------------------------------------------------------
-- Round / turn flow (driven from the mod-level calculate)
-- -------------------------------------------------------------------------
function HS.battlecry_times()
    return HS.has_minion('brann_bronzebeard') and 2 or 1
end

-- Run one minion's Battlecry (respecting Brann)
function HS.run_battlecry(card, times)
    local d = HS.def(card)
    if not d or not d.battlecry or HS.silenced(card) then return end
    times = times or HS.battlecry_times()
    for i = 1, times do
        if not HS.alive(card) then break end
        d.battlecry(card, i)
    end
    HS.say(card, times > 1 and 'Battlecry x2!' or 'Battlecry!', G.C.GOLD)
end

function HS.start_of_turn()
    HS.notify('start_turn')
end

function HS.on_setting_blind()
    local st = HS.state()
    st.boss_frozen, st.boss_disarmed, st.boss_half = false, false, false
    st.enemy_ramp = 0
    st.enemy_army = {}
    st.boss_has_attacked = false
    st.blind_reborn = false
    local bc = G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind
    st.blind_shield = bc and bc.hs_divine_shield or false
    st.turn_cards, st.hand_index = 0, 0
    st.turn_spells = {}
    st.tess_spells = st.recent_spells or {}
    st.recent_spells = {}
    st.died_this_turn = {}
    st.turn_pending = false
    for _, c in ipairs(HS.minions()) do
        local e = E(c)
        e.turn_atk, e.round_atk = 0, 0
        e.stealth_broken = false
        e.spellburst_used = false
        e.round_flag = nil
        e.frozen = nil
        e.silenced = nil
        if HS.has(c, 'divine_shield') then e.shield = true end
    end
    -- the Blind's full requirement before any damage (Alexstrasza)
    st.blind_base = G.GAME.blind and G.GAME.blind.chips or 0
    if st.pending_blind ~= 0 then
        local n = st.pending_blind
        st.pending_blind = 0
        HS.damage_blind(n, nil, true) -- dealt before the Blind appeared: Stealth can't dodge it
        HS.blind_say(n > 0 and (n .. ' stored damage!') or ('Healed ' .. (-n) .. '!'), n > 0 and G.C.RED or G.C.BLUE)
    end
    -- Overload from last turn locks Discards this round
    if (st.overload or 0) > 0 then
        local cr = G.GAME.current_round
        local n = math.min(st.overload, (cr and cr.discards_left) or 0)
        st.overload = 0
        if n > 0 and ease_discard then
            ease_discard(-n)
            HS.blind_say('Overloaded: -' .. n .. ' Discard' .. (n > 1 and 's' or ''), G.C.BLUE)
        end
    end
    HS.notify('on_blind')
    if HS.return_cheated then HS.return_cheated() end
    if HS.trigger_secret then HS.trigger_secret('blind_set') end
end

function HS.on_round_start()
    local st = HS.state()
    if st.pending_draws > 0 then
        local n = st.pending_draws
        st.pending_draws = 0
        HS.draw(n)
    end
    -- the enemy acts first (Stormpike Commando, Deathwing...)
    local bc = HS.enemy_quirks() and G.GAME.blind.config.blind
    if bc and bc.hs_round_start then bc.hs_round_start(bc) end
    -- Rush: it attacks as soon as the round starts
    if bc and bc.hs_rush then HS.blind_say('Rush!', G.C.ORANGE); HS.boss_attack() end
    -- Start of Game effects (not doubled by Brann)
    for _, c in ipairs(HS.minions()) do
        local d = HS.def(c)
        if d.start_of_game and HS.alive(c) and not HS.silenced(c) then d.start_of_game(c) end
    end
    -- Battlecries, left to right
    for _, c in ipairs(HS.minions()) do
        if HS.alive(c) then HS.run_battlecry(c) end
    end
    if HS.trigger_secret then HS.trigger_secret('round_start') end
    HS.start_of_turn()
end

function HS.on_hand_played()
    local st = HS.state()
    st.hand_index = st.hand_index + 1
    -- Charge: the Blind also attacks before your hand scores
    local bc = HS.enemy_quirks() and G.GAME.blind.config.blind
    if bc and bc.hs_charge then HS.blind_say('Charge!', G.C.RED); HS.boss_attack() end
    HS.notify('on_play', st.turn_cards)
end

function HS.on_end_of_turn()
    local st = HS.state()
    HS.notify('end_turn')
    st.turn_spells = {}
    -- Power Overwhelming etc.
    for _, c in ipairs(HS.minions()) do
        local e = E(c)
        if e.doomed then HS.kill(c, 'destroy') end
    end
    -- Kel'Thuzad
    local kt = HS.count('kelthuzad')
    if kt > 0 and #st.died_this_turn > 0 then
        local died = st.died_this_turn
        st.died_this_turn = {}
        for _ = 1, kt do
            for _, key in ipairs(died) do HS.summon(key) end
        end
    end
    st.died_this_turn = {}
    -- Dreadsteed-style "at the end of the turn" summons
    local later = st.end_of_turn_summons
    st.end_of_turn_summons = {}
    for _, key in ipairs(later) do HS.summon(key) end
    for _, c in ipairs(HS.minions()) do E(c).turn_atk = 0 end
    st.turn_cards = 0
    st.turn_pending = true

    -- Blind Divine Shield: if nothing has damaged the Blind yet, it absorbs this hand's score
    local bc = HS.enemy_quirks() and G.GAME.blind.config.blind
    local hand_score = math.floor(SMODS and SMODS.last_hand_score or 0)
    -- Stealth: your hand can't reach it either until it has attacked
    if bc and bc.hs_stealth and not st.boss_has_attacked and hand_score > 0 then
        G.GAME.blind.chips = G.GAME.blind.chips + hand_score
        HS.update_blind_text()
        HS.blind_say('Stealthed! Hand missed', G.C.UI.TEXT_INACTIVE)
    elseif bc and st.blind_shield and hand_score > 0 then
        st.blind_shield = false
        G.GAME.blind.chips = G.GAME.blind.chips + hand_score
        HS.update_blind_text()
        HS.blind_say('Divine Shield!', G.C.GOLD)
        HS.play_sound('attack')
    end
    -- Reborn: the first time you beat it, it comes back with a higher requirement
    if bc and bc.hs_reborn and not st.blind_reborn then
        local total = (G.GAME.chips or 0) + (SMODS and SMODS.last_hand_score or 0)
        if total >= (G.GAME.blind.chips or 0) then
            st.blind_reborn = true
            G.GAME.blind.chips = total + math.floor((st.blind_base or G.GAME.blind.chips) * bc.hs_reborn)
            HS.update_blind_text()
            HS.blind_say('Reborn!', G.C.GREEN)
        end
    end
    -- Ice Block: your last Hand failed to beat the Blind
    do
        local cr = G.GAME.current_round
        local total = (G.GAME.chips or 0) + (SMODS and SMODS.last_hand_score or 0)
        if cr and cr.hands_left == 0 and G.GAME.blind and total < (G.GAME.blind.chips or 0)
            and HS.trigger_secret then
            HS.trigger_secret('would_lose')
        end
    end
    -- Boss Blind attacks AFTER hand scoring is finished (if Blind is still alive and hands remain).
    -- G.GAME.chips is still easing up when this runs, so use the final total the hand will reach.
    local final_chips = (G.GAME.chips or 0) + (SMODS and SMODS.last_hand_score or 0)
    local function trigger_boss_attack_post_scoring()
        local blind_chips = G.GAME and G.GAME.blind and G.GAME.blind.chips or 0
        local cur_chips = math.max(G.GAME and G.GAME.chips or 0, final_chips)
        local hands_left = G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left or 0
        if blind_chips > 0 and cur_chips < blind_chips and hands_left > 0 then
            HS.boss_attack()
            if G.E_MANAGER and G.E_MANAGER.add_event and Event then
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 0.7,
                    blocking = true,
                    func = function() return true end
                }))
            end
        end
        -- Stealth breaks after the hand and boss attack complete
        for _, c in ipairs(HS.minions()) do
            local e = E(c)
            if e and e.scored_this_hand then
                e.scored_this_hand = false
                e.stealth_broken = true
            end
        end
    end

    if G.E_MANAGER and G.E_MANAGER.add_event and Event then
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.3,
            blocking = true,
            func = function()
                trigger_boss_attack_post_scoring()
                return true
            end
        }))
    else
        trigger_boss_attack_post_scoring()
    end
end

function HS.on_end_of_round()
    for _, c in ipairs(HS.minions()) do
        local e = E(c)
        if HS.has(c, 'lifesteal') then
            HS.heal_hero(HS.attack(c), c)
        end
        local d = HS.def(c)
        if d.end_round then d.end_round(c) end
        e.round_atk = 0
        e.turn_atk = 0
    end
    -- temporary summons (Parachute Pirates, Portal Demons...) leave without dying
    for _, c in ipairs(HS.minions()) do
        local e = E(c)
        if e.temporary then
            e.dying = true
            c.getting_sliced = true
            HS.event(function() if c.start_dissolve then c:start_dissolve(nil, true) end end)
        end
    end
    local st = HS.state()
    st.end_of_turn_summons = {}
    st.turn_x_mult = nil
end

function HS.on_spell_cast(center, source_card)
    local st = HS.state()
    st.spells_cast = st.spells_cast + 1
    st.turn_cards = st.turn_cards + 1
    -- spells used this turn (Archmage Vargoth recasts one)
    st.turn_spells = st.turn_spells or {}
    if center and center.key then st.turn_spells[#st.turn_spells + 1] = center.key end
    -- every Spell since last round started (Tess Greymane replays them); replays aren't recorded
    st.recent_spells = st.recent_spells or {}
    if center and center.key and not st.recasting then st.recent_spells[#st.recent_spells + 1] = center.key end
    HS.notify('on_spell', center, source_card)
    do
        local bc = HS.enemy_quirks() and G.GAME.blind.config.blind
        if bc and bc.hs_attack_on_spell then HS.blind_say('Atiesh!', G.C.PURPLE); HS.boss_attack() end
    end
    if HS.trigger_secret then HS.trigger_secret('cast_spell', center, source_card) end
    -- Spellburst (once per round)
    for _, c in ipairs(HS.minions()) do
        local d, e = HS.def(c), E(c)
        if d.spellburst and not e.spellburst_used and not e.silenced then
            e.spellburst_used = true
            d.spellburst(c, center)
        end
    end
end

function HS.is_spell(center)
    return center and (center.set == 'Tarot' or center.set == 'Spectral') and center.key and center.key:find('_hs_') and true or false
end

-- -------------------------------------------------------------------------
-- Shop interactions
-- -------------------------------------------------------------------------
function HS.cost_discount(card)
    local center = card.config and card.config.center
    if not center then return 0 end
    local st = HS.state()
    local d = st.shop_discount or 0
    local md = center.hs_minion
    if md and md.tribe then
        for tribe, n in pairs(st.tribe_discount or {}) do
            if HS.is_tribe(card, tribe) then d = d + n end
        end
    end
    for _, c in ipairs(HS.minions()) do
        local od = HS.def(c)
        if od.discount then d = d + (od.discount(c, card) or 0) end
    end
    if md and md.cost_mod then d = d + (md.cost_mod(card) or 0) end
    local set = card.ability and card.ability.set
    if HS.voucher('scrying_orb') and (set == 'Tarot' or set == 'Spectral') then d = d + 2 end
    -- Primordial Glyph: your next Spell is cheaper; Embiggen: minions cost more this shop
    if (set == 'Tarot' or set == 'Spectral') and card.area == G.shop_jokers then d = d + (st.next_spell_discount or 0) end
    if md and card.area == G.shop_jokers then d = d - (st.minion_surcharge or 0) end
    if HS.voucher('emerald_goggles') and G.shop_jokers and G.shop_jokers.cards[1] == card then d = d + 2 end
    return d
end

-- final price adjustments that are caps rather than discounts
function HS.cost_cap(card, cost)
    if HS.def(card) and card.area == G.shop_jokers then
        if HS.voucher('scepter_of_summoning') then cost = math.min(cost, 5) end
        -- price caps from your minions (Aviana: minions cost $1)
        for _, c in ipairs(HS.minions()) do
            local d = HS.def(c)
            if d.shop_cap then cost = math.min(cost, d.shop_cap(c, card)) end
        end
        if HS.voucher('boots_of_haste') and not HS.state().boots_used then cost = 0 end
    end
    -- Preparation: the next Spell you buy is free
    local set = card.ability and card.ability.set
    if (set == 'Tarot' or set == 'Spectral') and card.area == G.shop_jokers and HS.state().next_spell_free then
        cost = 0
    end
    return cost
end

function HS.refresh_costs()
    for _, area in ipairs({ G.shop_jokers, G.shop_booster, G.shop_vouchers, G.jokers, G.consumeables }) do
        if area and area.cards then
            for _, c in ipairs(area.cards) do if c.set_cost then c:set_cost() end end
        end
    end
end

function HS.steal_from_shop(source, make_negative)
    if not (G.shop_jokers and G.shop_jokers.cards) then return false end
    local pool = {}
    for _, c in ipairs(G.shop_jokers.cards) do
        if HS.def(c) then pool[#pool + 1] = c end
    end
    local target = HS.pick(pool, 'hs_steal')
    if not target then return false end
    if not make_negative and HS.board_space() <= 0 then return false end
    local key = target.config.center.key
    local new
    if make_negative then
        new = SMODS.add_card({ set = 'Joker', key = key, area = G.jokers, edition = 'e_negative', key_append = 'hs_sylvanas' })
        if new then
            new:set_edition({ negative = true }, true)
            local e = E(new)
            if e then e.summoned = true end
            if new.set_cost then new:set_cost() end
            HS.notify('on_summon', new)
        end
    else
        new = HS.summon(key, source)
    end
    if new then
        target:start_dissolve(nil, true)
        if source then HS.say(source, 'Mind Control!', G.C.PURPLE) end
        return true
    end
    return false
end

function HS.on_starting_shop()
    local st = HS.state()
    for _ = 1, (st.shop_steals or 0) do HS.steal_from_shop() end
    st.shop_steals = 0
    for _ = 1, (st.sylvanas_steals or 0) do HS.steal_from_shop(nil, true) end
    st.sylvanas_steals = 0
    -- Mind Control Tech: only if the shop has 2+ minions
    for _ = 1, (st.mct_steals or 0) do
        local n = 0
        for _, c in ipairs((G.shop_jokers and G.shop_jokers.cards) or {}) do
            if HS.def(c) then n = n + 1 end
        end
        if n >= 2 then HS.steal_from_shop() end
    end
    st.mct_steals = 0
    if st.shop_extra_minions > 0 and G.shop_jokers and create_card_for_shop then
        for _ = 1, st.shop_extra_minions do
            G.shop_jokers.config.card_limit = G.shop_jokers.config.card_limit + 1
            local c = create_card_for_shop(G.shop_jokers)
            G.shop_jokers:emplace(c)
        end
        st.shop_extra_minions = 0
    end
    HS.refresh_costs()
end

function HS.on_ending_shop()
    local st = HS.state()
    st.shop_discount = 0
    st.tribe_discount = {}
    st.minion_surcharge = 0
end

-- -------------------------------------------------------------------------
-- Mod-level calculate: the single dispatcher for every timing window
-- -------------------------------------------------------------------------
function HS.calculate(context)
    if not (G.GAME and G.jokers) then return end
    if context.individual or context.repetition or context.blueprint or context.post_trigger
        or context.retrigger_joker_check or context.other_joker then return end
    local st = HS.state()

    if context.setting_blind then
        HS.on_setting_blind()
    elseif context.first_hand_drawn then
        HS.check_candles()
        HS.on_round_start()
    elseif context.hand_drawn then
        HS.check_candles()
        if st.turn_pending then
            st.turn_pending = false
            HS.start_of_turn()
        end
    elseif context.before then
        HS.on_hand_played()
    elseif context.after then
        HS.on_end_of_turn()
    elseif context.end_of_round and not context.game_over then
        HS.on_end_of_round()
    elseif context.using_consumeable then
        if HS.is_spell(context.consumeable and context.consumeable.config.center) then
            HS.on_spell_cast(context.consumeable.config.center, context.consumeable)
        end
        HS.refresh_costs()
    elseif context.pre_discard then
        st.turn_cards = st.turn_cards + 1
        local bc = HS.enemy_quirks() and G.GAME.blind.config.blind
        if bc and bc.hs_discard_ramp then
            st.enemy_ramp = (st.enemy_ramp or 0) + bc.hs_discard_ramp
            HS.blind_say('+' .. bc.hs_discard_ramp .. ' Attack', G.C.RED)
        end
        HS.notify('on_discard', context.full_hand)
    elseif context.selling_card then
        if HS.is_minion(context.card) then HS.kill(context.card, 'sold') end
        HS.event(HS.refresh_costs)
    elseif context.buying_card then
        local bought = context.card
        if bought and HS.def(bought) then
            -- buying a minion = playing it: it counts as being summoned
            for _, c in ipairs(HS.others(bought)) do
                local d = HS.def(c)
                if d.on_summon then d.on_summon(c, bought) end
                if d.on_buy then d.on_buy(c, bought) end
            end
            HS.patches_on_buy(bought)
            if HS.trigger_secret then HS.trigger_secret('buy_minion', bought) end
        elseif bought and HS.is_spell(bought.config and bought.config.center) then
            st.next_spell_free = nil
            st.next_spell_discount = nil
        end
        HS.event(HS.refresh_costs)
    elseif context.starting_shop then
        HS.on_starting_shop()
    elseif context.ending_shop then
        HS.on_ending_shop()
    end
end

-- -------------------------------------------------------------------------
-- Playing-card (deck) manipulation helpers
-- -------------------------------------------------------------------------
HS.RANKS = { '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King', 'Ace' }
HS.SUITS = { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }

function HS.enhance(card, enh_key, source)
    if not (card and G.P_CENTERS[enh_key]) then return end
    card:set_ability(G.P_CENTERS[enh_key], nil, true)
    HS.say(card, G.P_CENTERS[enh_key].name or 'Enhanced', G.C.SECONDARY_SET.Enhanced or G.C.FILTER)
end

function HS.set_rank(card, rank)
    if card and SMODS.change_base then SMODS.change_base(card, nil, rank) end
end

function HS.shift_rank(card, delta)
    local v = card and card.base and card.base.value
    for i, r in ipairs(HS.RANKS) do
        if r == v then
            local j = math.max(1, math.min(#HS.RANKS, i + delta))
            HS.set_rank(card, HS.RANKS[j])
            return
        end
    end
end

function HS.set_suit(card, suit)
    if card and SMODS.change_base then SMODS.change_base(card, suit, nil) end
end

function HS.destroy_cards(cards, source)
    if not cards or #cards == 0 then return end
    if SMODS.destroy_cards then SMODS.destroy_cards(cards) end
    if source then HS.say(source, 'Destroyed ' .. #cards .. (#cards == 1 and ' card' or ' cards'), G.C.RED) end
end

-- remember a playing card so it can be recreated later (Carnivorous Cube)
function HS.describe_card(card)
    local center = card.config and card.config.center
    return {
        suit = card.base and card.base.suit,
        rank = card.base and card.base.value,
        enhancement = center and center.key ~= 'c_base' and center.key or nil,
        seal = card.seal,
        edition = card.edition and card.edition.key or nil,
    }
end

function HS.create_playing_card(desc, area)
    if not (SMODS.add_card and desc) then return end
    return SMODS.add_card({
        set = desc.enhancement and 'Enhanced' or 'Base',
        enhancement = desc.enhancement, rank = desc.rank, suit = desc.suit,
        seal = desc.seal, edition = desc.edition,
        area = area or G.deck, skip_materialize = area == G.deck,
    })
end

function HS.lowest_in_hand()
    local low
    for _, c in ipairs((G.hand and G.hand.cards) or {}) do
        if not low or HS.rank_num(c) < HS.rank_num(low) then low = c end
    end
    return low
end

function HS.highest_in_hand()
    local high
    for _, c in ipairs((G.hand and G.hand.cards) or {}) do
        local n = HS.rank_num(c) == 1 and 14 or HS.rank_num(c)
        if not high or n > (HS.rank_num(high) == 1 and 14 or HS.rank_num(high)) then high = c end
    end
    return high
end

-- Shuffle a "Casts When Drawn" card (src/enhancements.lua) into your deck
function HS.add_deck_card(enh_key)
    if not (SMODS and SMODS.add_card and G.deck) then return end
    return SMODS.add_card({ set = 'Enhanced', enhancement = enh_key, area = G.deck, skip_materialize = true })
end

-- Waxadred's Candle: when drawn it resummons Waxadred
function HS.add_candle() return HS.add_deck_card('m_hs_waxadreds_candle') end

-- What each "Casts When Drawn" card does. Return false to stay in hand (e.g. board full).
HS.ON_DRAW = {
    m_hs_waxadreds_candle = function(c) HS.summon('waxadred'); return true end,
    m_hs_patches_the_pirate = function(c) return HS.release_patches(c) end,
}

function HS.check_candles()
    if not (G.hand and G.hand.cards) then return end
    local snapshot = {}
    for i, c in ipairs(G.hand.cards) do snapshot[i] = c end
    for _, c in ipairs(snapshot) do
        local fn = HS.ON_DRAW[c.config.center.key]
        if fn and not c.hs_candle_lit then
            -- release_patches destroys its own card; the rest are consumed here
            if c.config.center.key == HS.PATCHES_CARD then
                fn(c)
            elseif fn(c) ~= false then
                c.hs_candle_lit = true
                if SMODS.destroy_cards then SMODS.destroy_cards({ c }) end
            end
        end
    end
end

-- Adapt: a random bonus
HS.ADAPTS = {
    { '+3 Attack', function(c) HS.buff(c, 3, 0, nil, true) end },
    { '+3 Health', function(c) HS.buff(c, 0, 3, nil, true) end },
    { '+1/+1', function(c) HS.buff(c, 1, 1, nil, true) end },
    { 'Divine Shield', function(c) HS.give(c, 'divine_shield') end },
    { 'Taunt', function(c) HS.give(c, 'taunt') end },
    { 'Windfury', function(c) HS.give(c, 'windfury') end },
    { 'Stealth', function(c) HS.give(c, 'stealth') end },
}
function HS.adapt(card)
    local a = HS.pick(HS.ADAPTS, 'hs_adapt')
    a[2](card)
    HS.say(card, 'Adapt: ' .. a[1], G.C.GREEN)
    return a[1]
end

-- Patches the Pirate: buying him hides him in your deck (as a Patches card,
-- taking no Minion slot). He jumps out when you buy a Pirate or draw his card.
HS.PATCHES_CARD = 'm_hs_patches_the_pirate'

local function patches_cards()
    local t = {}
    for _, c in ipairs(G.playing_cards or {}) do
        if c.config and c.config.center and c.config.center.key == HS.PATCHES_CARD and not c.hs_candle_lit then
            t[#t + 1] = c
        end
    end
    return t
end

-- summon Patches from one of his deck cards; false if there's no room
function HS.release_patches(deck_card, source)
    if HS.board_space() <= 0 then return false end
    deck_card.hs_candle_lit = true
    -- he was bought, not summoned: keep his normal sell value
    HS.summon('patches_the_pirate', source, { extra = { summoned = false } })
    if SMODS.destroy_cards then SMODS.destroy_cards({ deck_card }) end
    return true
end

function HS.patches_on_buy(bought)
    if bought.config.center.key == 'j_hs_patches_the_pirate' then
        local e = E(bought)
        e.dying = true -- leaves the board without dying
        HS.event(function()
            HS.add_deck_card(HS.PATCHES_CARD)
            if bought.start_dissolve then bought:start_dissolve(nil, true) end
            HS.say(bought, 'Hides in your deck!', G.C.FILTER)
        end)
        return
    end
    if not HS.is_tribe(bought, 'Pirate') then return end
    local hidden = patches_cards()[1]
    if hidden then HS.release_patches(hidden, bought) end
end

-- -------------------------------------------------------------------------
-- Per-minion calculate: scoring + nothing else (all triggers are central)
-- -------------------------------------------------------------------------
function HS.minion_calculate(self, card, context)
    if not context.joker_main or context.blueprint then return end
    if not HS.alive(card) then return end
    local e = E(card)
    local d = HS.def(card)
    if e.frozen then
        e.frozen = nil
        return { message = 'Frozen', colour = G.C.BLUE, card = card }
    end
    if e.silenced then
        return { message = 'Silenced', colour = G.C.UI.TEXT_INACTIVE, card = card }
    end
    local atk, hp = HS.attack(card), HS.health(card)
    if HS.boss_is('sylvanas') and hp < 3 then atk = 0 end
    if d.no_attack then atk = 0 end -- "Can't attack" (Ragnaros): scores no Mult
    hp = hp * HS.CHIPS_PER_HEALTH
    local first_hand = HS.state().hand_index <= 1
    local hits = {}
    local function hit(m, c)
        local r = {}
        if m and m > 0 then r.mult = m end
        if c and c > 0 then r.chips = c end
        if next(r) then hits[#hits + 1] = r end
    end
    -- One attack = the minion's whole score: +Mult, +Chips, its own effect, its X Mult and
    -- any tribe lord's X Mult. Windfury / Mega-Windfury / Charge / Rush repeat ALL of it,
    -- like Balatro retriggers, so X Mult stacks (X2 with Windfury = X4).
    local function attack(with_chips)
        hit(atk, with_chips and hp or nil)
        if d.score then
            local r = d.score(card, context)
            if r then
                local copy = {}
                for k, v in pairs(r) do if k ~= 'extra' then copy[k] = v end end
                hits[#hits + 1] = copy
            end
        end
        if e.x_mult and e.x_mult > 1 then hits[#hits + 1] = { Xmult = e.x_mult, card = card } end
        for _, o in ipairs(HS.others(card)) do
            local od = HS.def(o)
            local x = od.lord_x and od.lord_x(o, card)
            if x and x > 1 then hits[#hits + 1] = { Xmult = x, card = o } end
        end
    end
    local per_turn = HS.has(card, 'mega_windfury') and 4 or (HS.has(card, 'windfury') and 2 or 1)
    local wf_msg = per_turn == 4 and 'Mega-Windfury!' or 'Windfury!'
    local function attacks(with_chips, first_msg, col)
        for i = 1, per_turn do
            -- (not `i == 1 and first_msg or wf_msg`: a nil first_msg would fall through to "Windfury!")
            local msg
            if i == 1 then msg = first_msg else msg = wf_msg end
            if msg then hits[#hits + 1] = { message = msg, colour = (i == 1 and col) or G.C.BLUE, card = card } end
            attack(with_chips)
        end
    end
    attacks(true, nil)
    if first_hand and HS.has(card, 'charge') then
        attacks(true, 'Charge!', G.C.RED)
    elseif first_hand and HS.has(card, 'rush') then
        attacks(false, 'Rush!', G.C.ORANGE)
    end
    local st = HS.state()
    -- the board-wide "X Mult this turn" rides on the last minion that will actually score
    local last_scorer
    for _, c in ipairs(HS.minions()) do
        if not c.debuff and (c == card or not E(c).frozen) then last_scorer = c end
    end
    if st.turn_x_mult and st.turn_x_mult > 1 and last_scorer == card then
        hits[#hits + 1] = {
            Xmult = st.turn_x_mult,
            card = card
        }
        st.turn_x_mult = nil
    end
    e.scored_this_hand = true
    if d.after_attack then d.after_attack(card) end
    if #hits == 0 then return end
    local ret = hits[1]
    local tail = ret
    for i = 2, #hits do
        tail.extra = hits[i]
        tail = hits[i]
    end
    ret.card = card
    return ret
end

-- -------------------------------------------------------------------------
-- Minion registration
-- -------------------------------------------------------------------------
HS.KW_TIPS = {
    Battlecry = 'hs_kw_battlecry', Deathrattle = 'hs_kw_deathrattle', Taunt = 'hs_kw_taunt',
    ['Divine Shield'] = 'hs_kw_divine_shield', Windfury = 'hs_kw_windfury', Charge = 'hs_kw_charge',
    Rush = 'hs_kw_rush', Lifesteal = 'hs_kw_lifesteal', ['Mega-Windfury'] = 'hs_kw_mega_windfury', Stealth = 'hs_kw_stealth', Reborn = 'hs_kw_reborn',
    Enrage = 'hs_kw_enrage', ['Spell Damage'] = 'hs_kw_spell_damage', Combo = 'hs_kw_combo',
    Freeze = 'hs_kw_freeze', Silence = 'hs_kw_silence', ['Start of Game'] = 'hs_kw_start_of_game',
    Spellburst = 'hs_kw_spellburst', Manathirst = 'hs_kw_manathirst', Infuse = 'hs_kw_infuse',
    Adapt = 'hs_kw_adapt', Secret = 'hs_kw_secret', Overload = 'hs_kw_overload',
    Armor = 'hs_kw_armor', hero = 'hs_kw_hero', Summon = 'hs_kw_summon',
    Spell = 'hs_kw_spell',
}
local KW_ORDER = { 'Battlecry', 'Deathrattle', 'Start of Game', 'Taunt', 'Divine Shield', 'Mega-Windfury', 'Windfury',
    'Charge', 'Rush', 'Lifesteal', 'Stealth', 'Reborn', 'Enrage', 'Spell Damage', 'Combo', 'Spellburst',
    'Manathirst', 'Infuse', 'Adapt', 'Overload', 'Freeze', 'Silence', 'Secret', 'Armor', 'hero',
    'Summon' }

function HS.keyword_tips(text_lines)
    local blob = table.concat(text_lines, ' ')
    local out = {}
    for _, kw in ipairs(KW_ORDER) do
        local pat = kw == 'hero' and '[Yy]our hero' or kw
        if blob:find(pat) then out[#out + 1] = HS.KW_TIPS[kw] end
    end
    return out
end

-- Keywords and effects a minion has now but that aren't printed on its card
HS.KW_NAMES = {
    taunt = 'Taunt', divine_shield = 'Divine Shield', windfury = 'Windfury', mega_windfury = 'Mega-Windfury',
    charge = 'Charge', rush = 'Rush',
    lifesteal = 'Lifesteal', stealth = 'Stealth', reborn = 'Reborn', poisonous = 'Poisonous',
}
local KW_TIP = {
    taunt = 'hs_kw_taunt', divine_shield = 'hs_kw_divine_shield', windfury = 'hs_kw_windfury',
    mega_windfury = 'hs_kw_mega_windfury',
    charge = 'hs_kw_charge', rush = 'hs_kw_rush', lifesteal = 'hs_kw_lifesteal', stealth = 'hs_kw_stealth',
    reborn = 'hs_kw_reborn',
}
function HS.gained_effects(card)
    local d, e = HS.def(card), E(card)
    if not (d and e) then return {}, {} end
    local printed = {}
    for _, k in ipairs(d.kw or {}) do printed[k] = true end
    if d.enrage then for k in pairs(d.enrage) do printed[k] = true end end
    local names, tips = {}, {}
    for _, k in ipairs(HS.KEYWORDS) do
        if not printed[k] and HS.has(card, k) then
            names[#names + 1] = HS.KW_NAMES[k] or k
            tips[#tips + 1] = KW_TIP[k]
        end
    end
    if e.ancestral then
        names[#names + 1] = 'Deathrattle: Resummon this'
        tips[#tips + 1] = 'hs_kw_deathrattle'
    end
    if e.doomed then names[#names + 1] = 'Dies at the end of your turn' end
    if e.temporary then names[#names + 1] = 'Leaves at the end of the round' end
    if e.x_mult and e.x_mult > 1 then
        names[#names + 1] = 'X' .. string.format('%.2f', e.x_mult):gsub('%.?0+$', '') .. ' Mult'
    end
    return names, tips
end

-- Shift a card's own #1#, #2#... vars past the two stat vars
local function shift_vars(line)
    return (line:gsub('#(%d+)#', function(n) return '#' .. (tonumber(n) + 2) .. '#' end))
end

-- Shop price: Mana + 2 (max $12). Legendaries are a splurge: $18 + Mana, between $20 and $30.
function HS.default_cost(d)
    local mana = d.mana or 1
    if (d.rarity or 1) == 4 then return math.max(20, math.min(30, 18 + mana)) end
    return math.min(12, mana + 2)
end

-- Minion rarity odds in shops and Minion packs (vanilla Balatro: 70 / 25 / 5 / 0).
-- Legendaries can show up in the shop, but they're expensive (see HS.default_cost).
HS.RARITY_WEIGHTS = { Common = 0.64, Uncommon = 0.27, Rare = 0.08, Legendary = 0.01 }
if SMODS and SMODS.Rarities then
    for key, w in pairs(HS.RARITY_WEIGHTS) do
        local r = SMODS.Rarities[key]
        if r then
            local orig = r.get_weight
            r.get_weight = function(self, weight, object_type)
                if object_type and object_type.key == 'Joker' then return w end
                return orig and orig(self, weight, object_type) or weight
            end
        end
    end
end

HS.minion_count = HS.minion_count or 0
function HS.minion(d)
    HS.minion_count = HS.minion_count + 1
    local idx = d.pos_index or (HS.minion_count - 1)
    local key = 'hs_' .. d.id
    d.key = 'j_' .. key
    HS.defs[d.key] = d
    local kw = {}
    for _, k in ipairs(d.kw or {}) do kw[k] = true end
    local extra = {
        attack = d.atk, health = d.hp, max_health = d.hp,
        base_attack = d.atk, base_health = d.hp,
        kw = kw, shield = kw.divine_shield or false,
        turn_atk = 0, round_atk = 0,
    }
    for k, v in pairs(d.extra or {}) do extra[k] = v end
    local text = { '{C:mult}+#1#{} Mult  {C:chips}+#2#{} Chips' }
    for _, l in ipairs(d.text or {}) do text[#text + 1] = shift_vars(l) end
    local tips = HS.keyword_tips(d.text or {})
    -- variant text used once the minion has gained keywords: one extra line
    local n_own = 0
    if d.vars then
        local okv, v = pcall(d.vars, nil)
        if okv and v then n_own = #v end
    end
    local gained_var = 3 + n_own
    local text_gained = {}
    for i, l in ipairs(text) do text_gained[i] = l end
    text_gained[#text_gained + 1] = '{C:green}+{} {C:attention}#' .. gained_var .. '#{}'
    local tribe = d.tribe
    if type(tribe) == 'table' then tribe = table.concat(tribe, ' / ') end
    SMODS.Joker({
        key = key,
        loc_txt = { name = d.name, text = text },
        config = { extra = extra },
        rarity = d.rarity or 1,
        cost = d.cost or HS.default_cost(d),
        pos = { x = idx % 10, y = math.floor(idx / 10) },
        atlas = 'hs_minions',
        blueprint_compat = false,
        eternal_compat = true,
        perishable_compat = true,
        hs_minion = d,
        hs_id = d.hs_id,
        hs_text = d.text,
        hs_tribe = tribe,
        in_pool = d.token and function() return false end or nil,
        no_collection = nil,
        loc_vars = function(self, info_queue, card)
            for _, k in ipairs(tips) do info_queue[#info_queue + 1] = { set = 'Other', key = k } end
            local atk, hp
            if card and card.ability and E(card) and G.jokers then
                atk, hp = HS.attack(card), HS.health(card)
            else
                atk, hp = d.atk, d.hp
            end
            local vars = { atk, hp * HS.CHIPS_PER_HEALTH }
            if d.vars then
                for _, v in ipairs(d.vars(card) or {}) do vars[#vars + 1] = v end
            end
            if card and E(card) and G.jokers then
                local names, gtips = HS.gained_effects(card)
                if #names > 0 then
                    for _, k in ipairs(gtips) do info_queue[#info_queue + 1] = { set = 'Other', key = k } end
                    while #vars < gained_var - 1 do vars[#vars + 1] = '' end
                    vars[gained_var] = table.concat(names, ', ')
                    return { vars = vars, key = self.key .. '_gained' }
                end
            end
            return { vars = vars }
        end,
        -- register the "_gained" text variant next to the normal one
        process_loc_text = function(self)
            SMODS.process_loc_text(G.localization.descriptions.Joker, self.key, self.loc_txt)
            SMODS.process_loc_text(G.localization.descriptions.Joker, self.key .. '_gained',
                { name = d.name, text = text_gained })
        end,
        add_to_deck = function(self, card, from_debuff)
            local e = E(card)
            if e and HS.has(card, 'divine_shield') then e.shield = true end
            if d.on_add and not from_debuff then d.on_add(card) end
        end,
        remove_from_deck = function(self, card, from_debuff)
            if d.on_remove and not from_debuff then d.on_remove(card) end
        end,
        calculate = HS.minion_calculate,
        set_badges = tribe and function(self, card, badges)
            badges[#badges + 1] = create_badge(tribe, G.C.SECONDARY_SET.Joker or G.C.FILTER, G.C.WHITE, 1.0)
        end or nil,
    })
    return d
end

-- -------------------------------------------------------------------------
-- Cost hook: shop discounts, summoned minions sell for $0
-- -------------------------------------------------------------------------
if Card and Card.set_cost then
    local orig_set_cost = Card.set_cost
    function Card:set_cost(...)
        local ret = orig_set_cost(self, ...)
        if G.GAME then
            local center = self.config and self.config.center
            if center and center.key and center.key:find('_hs_') then
                local in_shop = self.area and (self.area == G.shop_jokers or self.area == G.shop_booster
                    or self.area == G.shop_vouchers or self.area == G.pack_cards)
                local cm = center.hs_minion and center.hs_minion.cost_mod
                if in_shop or cm then
                    local disc = 0
                    if in_shop then disc = HS.cost_discount(self)
                    elseif cm then disc = cm(self) or 0 end
                    if disc ~= 0 and not (self.ability and self.ability.couponed) then
                        self.cost = math.max(1, self.cost - disc)
                    end
                    if in_shop then self.cost = HS.cost_cap(self, self.cost) end
                end
                local e = E(self)
                if e and e.summoned then self.sell_cost = 0 end
                self.sell_cost_label = self.facing == 'back' and '?' or self.sell_cost
            end
        end
        return ret
    end
end

-- Mal'Ganis: you can't gain money while facing him
if ease_dollars then
    local orig_ease_dollars = ease_dollars
    function ease_dollars(mod, instant)
        if mod and mod < 0 and HS.in_round() and HS.trigger_secret then
            HS.trigger_secret('lose_money', -mod)
        end
        if mod and mod > 0 and HS.boss_is('malganis') then
            HS.blind_say("Mal'Ganis: no money!", G.C.RED)
            return
        end
        return orig_ease_dollars(mod, instant)
    end
end

-- Secrets = Tags
if add_tag then
    local orig_add_tag = add_tag
    function add_tag(...)
        local r = orig_add_tag(...)
        if G.jokers then HS.notify('on_tag') end
        return r
    end
end

-- -------------------------------------------------------------------------
-- Stat badges drawn over the card's printed Attack / Health
-- -------------------------------------------------------------------------
-- The minion atlas has blank Attack/Health gems (tools/stat_gems.py); the live numbers are
-- drawn here in Belwe like real Hearthstone. Geometry measured from the official renders,
-- as fractions of the card tile: gem centres and the printed digit height.
HS.BADGE = { ax = 0.1586, ay = 0.9144, hx = 0.8666, hy = 0.9176, digit_h = 0.0942 }
HS.BELWE_DIGIT_H64 = 43 -- digit glyph height of Belwe Bold at size 64 (measured with PIL)

function HS.load_font()
    if HS.font ~= nil then return HS.font end
    HS.font = false
    local font_file = "assets/fonts/belwe-bd-bt-bold.ttf"
    local mod = SMODS and SMODS.Mods and (SMODS.Mods["Balathstone"] or SMODS.Mods["Balearthstone"])
    if mod and mod.path and NFS and NFS.newFileData then
        local ok, data = pcall(NFS.newFileData, mod.path .. font_file)
        if ok and data then
            local ok2, f = pcall(love.graphics.newFont, data, 64)
            if ok2 then HS.font = f end
        end
    end
    return HS.font
end

function HS.draw_badges(card)
    local e = E(card)
    if not e then return end
    if card.dissolve and card.dissolve > 0 then return end -- don't float over a burning card
    local atk, hp = HS.attack(card), HS.health(card)
    local xm = e.x_mult
    local has_xm = xm and xm > 1
    local font = HS.load_font()
    if not font then return end
    prep_draw(card, 1)
    love.graphics.setFont(font)
    local cw, ch = card.T.w, card.T.h
    local B = HS.BADGE
    -- scale Belwe so its digits are exactly as tall as the printed ones were
    local s = (ch * B.digit_h) / HS.BELWE_DIGIT_H64
    local function print_outlined(text, cx, cy, col)
        local ox, oy = font:getWidth(text) / 2, font:getHeight() / 2
        local ow = ch * B.digit_h * 0.09 -- Hearthstone's thick black outline
        love.graphics.setColor(0, 0, 0, 1)
        for a = 0, 15 do
            local r = a * math.pi / 8
            love.graphics.print(text, cx + math.cos(r) * ow, cy + math.sin(r) * ow, 0, s, s, ox, oy)
        end
        love.graphics.setColor(col)
        love.graphics.print(text, cx, cy, 0, s, s, ox, oy)
    end
    local green, red, white = { 0.22, 0.92, 0.25, 1 }, { 0.95, 0.22, 0.22, 1 }, { 1, 1, 1, 1 }
    -- Attack: white at base, green when buffed, red when reduced
    local atk_col = atk > e.base_attack and green or (atk < e.base_attack and red or white)
    print_outlined(tostring(atk), cw * B.ax, ch * B.ay, atk_col)
    -- Health: red when damaged, green when buffed above base, else white
    local hp_col = HS.is_damaged(card) and red or (hp > e.base_health and green or white)
    print_outlined(tostring(hp), cw * B.hx, ch * B.hy, hp_col)
    if has_xm then
        local xm_str = 'X' .. string.format('%.2f', xm):gsub('%.?0+$', '')
        local mx, my = cw * 0.514, ch * 0.913
        local tw = font:getWidth(xm_str) * s
        local bw = math.max(cw * 0.20, tw + cw * 0.07)
        local bh = cw * 0.17
        local br = bh * 0.45
        love.graphics.setColor(0.12, 0.08, 0.08, 0.95)
        love.graphics.rectangle('fill', mx - bw / 2 - s * 1.5, my - bh / 2 - s * 1.5, bw + s * 3.0, bh + s * 3.0, br, br, 16)
        love.graphics.setColor(0.88, 0.68, 0.15, 1)
        love.graphics.rectangle('fill', mx - bw / 2, my - bh / 2, bw, bh, br, br, 16)
        love.graphics.setColor(0.85, 0.16, 0.22, 1)
        love.graphics.rectangle('fill', mx - (bw - s * 3.0) / 2, my - (bh - s * 3.0) / 2, bw - s * 3.0, bh - s * 3.0, br * 0.8, br * 0.8, 16)
        print_outlined(xm_str, mx, my, white)
    end
    love.graphics.pop()
end

if SMODS and SMODS.DrawStep then
    SMODS.DrawStep {
        key = 'hs_minion_badges',
        order = 48,
        conditions = { vortex = false, facing = 'front' },
        func = function(card, layer)
            if HS.is_minion(card) and card.children and card.children.center then
                HS.draw_badges(card)
            end
        end
    }
end

-- -------------------------------------------------------------------------
-- Spell targeting
-- NOTE: Balatro creates BOTH G.jokers and G.consumeables with type 'joker',
-- so every check here compares the actual areas, never config.type.
-- -------------------------------------------------------------------------
function HS.targeting_spell()
    if not (G.consumeables and G.consumeables.highlighted) then return nil end
    local sel = G.consumeables.highlighted[1]
    local spec = sel and sel.config and sel.config.center and sel.config.center.hs_targets
    if spec and spec.area == 'jokers' then return sel, spec end
end

if CardArea then
    local orig_add = CardArea.add_to_highlighted
    function CardArea:add_to_highlighted(card, silent)
        if self == G.consumeables then
            local spec = card and card.config and card.config.center and card.config.center.hs_targets
            if G.jokers then
                if spec and spec.area == 'jokers' then
                    G.jokers.config.highlighted_limit = spec.max or 1
                else
                    G.jokers.config.highlighted_limit = 1
                end
                -- drop any excess minion selection
                while #G.jokers.highlighted > G.jokers.config.highlighted_limit do
                    G.jokers:remove_from_highlighted(G.jokers.highlighted[1])
                end
            end
        end
        return orig_add(self, card, silent)
    end

    local orig_remove = CardArea.remove_from_highlighted
    function CardArea:remove_from_highlighted(card, force)
        local r = orig_remove(self, card, force)
        if self == G.consumeables and G.jokers and not HS.targeting_spell() then
            G.jokers.config.highlighted_limit = 1
        end
        return r
    end
end

if Card and Card.highlight then
    -- While aiming a spell at minions, hide the minions' Sell buttons so a
    -- target click can never sell a minion by accident.
    local orig_highlight = Card.highlight
    function Card:highlight(is_highlighted)
        local r = orig_highlight(self, is_highlighted)
        if self.area == G.jokers and self.highlighted and HS.targeting_spell() then
            if self.children.use_button then
                self.children.use_button:remove()
                self.children.use_button = nil
            end
        end
        return r
    end
end

-- -------------------------------------------------------------------------
-- In-Game Trailer Scenario Spawner & Screenshot Capture
-- Press F8 to cycle through epic Hearthstone combos directly in your live run!
-- Press F9 to take an authentic in-engine frame screenshot to %APPDATA%/Balatro/
-- -------------------------------------------------------------------------
HS.scenario_index = 0

function HS.spawn_trailer_scenario()
    if not (G and G.jokers and G.consumeables and SMODS and SMODS.add_card) then return end
    HS.scenario_index = (HS.scenario_index % 5) + 1
    
    -- Clear current minions and consumables
    for i = #G.jokers.cards, 1, -1 do
        local c = G.jokers.cards[i]
        c:remove()
    end
    for i = #G.consumeables.cards, 1, -1 do
        local c = G.consumeables.cards[i]
        c:remove()
    end
    
    -- Ensure 7 slots
    G.jokers.config.card_limit = math.max(7, G.jokers.config.card_limit or 7)
    
    local banner_msg = ""
    
    if HS.scenario_index == 1 then
        banner_msg = "Scenario 1: Dr. Boom & Boom Bots!"
        SMODS.add_card({ key = 'j_hs_boom_bot', area = G.jokers })
        local doc = SMODS.add_card({ key = 'j_hs_dr_boom', area = G.jokers })
        SMODS.add_card({ key = 'j_hs_boom_bot', area = G.jokers })
        SMODS.add_card({ key = 'c_hs_brawl', area = G.consumeables })
        SMODS.add_card({ key = 'c_hs_the_coin', area = G.consumeables })
        if doc then HS.say(doc, "Dr. Boom Deployed!", G.C.GOLD) end
        
    elseif HS.scenario_index == 2 then
        banner_msg = "Scenario 2: Archmage Antonidas & Fireballs!"
        local ant = SMODS.add_card({ key = 'j_hs_archmage_antonidas', area = G.jokers })
        local tir = SMODS.add_card({ key = 'j_hs_tirion_fordring', area = G.jokers })
        if tir and E(tir) then E(tir).shield = true end
        SMODS.add_card({ key = 'c_hs_fireball', area = G.consumeables })
        SMODS.add_card({ key = 'c_hs_frostbolt', area = G.consumeables })
        if ant then HS.say(ant, "'AHA!'", G.C.GOLD) end
        
    elseif HS.scenario_index == 3 then
        banner_msg = "Scenario 3: Grim Patron Swarm!"
        local p1 = SMODS.add_card({ key = 'j_hs_grim_patron', area = G.jokers })
        local p2 = SMODS.add_card({ key = 'j_hs_grim_patron', area = G.jokers })
        local p3 = SMODS.add_card({ key = 'j_hs_grim_patron', area = G.jokers })
        if p1 and E(p1) then E(p1).health = 2 end -- Damaged to show active survive
        SMODS.add_card({ key = 'c_hs_brawl', area = G.consumeables })
        if p2 then HS.say(p2, "EVERYONE, GET IN HERE!", G.C.ORANGE) end
        
    elseif HS.scenario_index == 4 then
        banner_msg = "Scenario 4: Murloc Swarm & Shudderwock!"
        SMODS.add_card({ key = 'j_hs_brann_bronzebeard', area = G.jokers })
        SMODS.add_card({ key = 'j_hs_murloc_warleader', area = G.jokers })
        SMODS.add_card({ key = 'j_hs_murloc_tidehunter', area = G.jokers })
        SMODS.add_card({ key = 'j_hs_murloc_scout', area = G.jokers })
        local sw = SMODS.add_card({ key = 'j_hs_shudderwock', area = G.jokers })
        SMODS.add_card({ key = 'c_hs_bloodlust', area = G.consumeables })
        if sw then HS.say(sw, "My claws that catch!", G.C.BLUE) end
        
    elseif HS.scenario_index == 5 then
        banner_msg = "Scenario 5: Maximum X-Mult Overkill!"
        local leeroy = SMODS.add_card({ key = 'j_hs_leeroy_jenkins', area = G.jokers })
        local raid = SMODS.add_card({ key = 'j_hs_raid_leader', area = G.jokers })
        if raid and E(raid) then E(raid).x_mult = 2.0 end
        local wolf = SMODS.add_card({ key = 'j_hs_dire_wolf_alpha', area = G.jokers })
        if wolf and E(wolf) then E(wolf).x_mult = 1.5 end
        local zill = SMODS.add_card({ key = 'j_hs_zilliax', area = G.jokers })
        if zill and E(zill) then E(zill).x_mult = 1.5; E(zill).shield = true end
        SMODS.add_card({ key = 'c_hs_savage_roar', area = G.consumeables })
        if leeroy then HS.say(leeroy, "LEEROY JENKINS!", G.C.RED) end
    end
    
    if G.ROOM then G.ROOM.jiggle = (G.ROOM.jiggle or 0) + 2 end
    print("[Balathstone] " .. banner_msg)
end

-- Debug keys are OFF in normal play: F8 wipes your board. Set HS.DEBUG = true
-- (e.g. from the DebugPlus console) to record trailer footage.
HS.DEBUG = HS.DEBUG or false

if love and love.keypressed then
    local orig_keypressed = love.keypressed
    function love.keypressed(key, ...)
        if orig_keypressed then orig_keypressed(key, ...) end
        if HS.DEBUG and G and G.jokers and G.consumeables then
            if key == 'f8' then
                HS.spawn_trailer_scenario()
            elseif key == 'f9' and love.graphics and love.graphics.captureScreenshot then
                love.graphics.captureScreenshot(function(imgData)
                    pcall(function()
                        local fname = 'balathstone_capture_' .. tostring(os.time()) .. '.png'
                        imgData:encode('png', fname)
                        print('[Balathstone] Captured in-engine screenshot to ' .. fname)
                    end)
                end)
            end
        end
    end
end

return HS
