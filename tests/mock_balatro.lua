-- Minimal Balatro + Steamodded simulation for headless tests.
-- Mirrors the pieces of the real game the mod touches: card areas, the event
-- queue, centers, contexts and a round/hand loop.
local MOD_ROOT = ...

local function deepcopy(t, seen)
    if type(t) ~= 'table' then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local o = {}
    seen[t] = o
    for k, v in pairs(t) do o[deepcopy(k, seen)] = deepcopy(v, seen) end
    return setmetatable(o, getmetatable(t))
end
copy_table = function(t) return deepcopy(t) end

-- ---------------------------------------------------------------- RNG
local rng_state = 12345
function T_seed(n) rng_state = n end
local function rnd()
    rng_state = (rng_state * 1103515245 + 12345) % 2147483648
    return rng_state / 2147483648
end
pseudoseed = function(s) return s end
pseudorandom = function(seed, min, max)
    local r = rnd()
    if min and max then return min + math.floor(r * (max - min + 1)) end
    return r
end
pseudorandom_element = function(t, seed)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    if #keys == 0 then return nil end
    local k = keys[math.floor(rnd() * #keys) + 1]
    return t[k], k
end

-- ---------------------------------------------------------------- misc globals
HEX = function() return { 1, 1, 1, 1 } end
-- love.graphics stub that tracks push/pop balance
T_gfx = { depth = 0, calls = 0 }
love = { graphics = setmetatable({
    push = function() T_gfx.depth = T_gfx.depth + 1 end,
    pop = function()
        T_gfx.depth = T_gfx.depth - 1
        if T_gfx.depth < 0 then error('love.graphics.pop underflow') end
    end,
    getLineWidth = function() return 1 end,
}, { __index = function() return function() T_gfx.calls = T_gfx.calls + 1 end end }) }
prep_draw = function() love.graphics.push() end
G_TIMERS_REAL = 0
number_format = function(n) return tostring(n) end
delay = function() end
play_sound = function() end
create_badge = function() return {} end
localize = function(k) return k end

T_messages = {}
card_eval_status_text = function(card, kind, a, b, c, extra)
    T_messages[#T_messages + 1] = { card = card, msg = extra and extra.message }
end

-- ---------------------------------------------------------------- events
Event = function(t) return t end
local EM = { queue = {} }
function EM:add_event(e) self.queue[#self.queue + 1] = e end
function T_flush()
    local guard = 0
    while #EM.queue > 0 do
        guard = guard + 1
        if guard > 5000 then error('event queue did not settle') end
        local e = table.remove(EM.queue, 1)
        if e.func then e.func() end
    end
end

-- ---------------------------------------------------------------- CardArea
CardArea = {}
CardArea.__index = CardArea
function CardArea.new(cfg)
    local a = setmetatable({ cards = {}, highlighted = {}, config = cfg or {} }, CardArea)
    a.config.card_limit = a.config.card_limit or 999
    a.config.highlighted_limit = a.config.highlighted_limit or 1
    return a
end
function CardArea:emplace(card)
    if card.area and card.area ~= self then card.area:remove_card(card) end
    self.cards[#self.cards + 1] = card
    card.area = self
end
function CardArea:remove_card(card)
    for i, c in ipairs(self.cards) do if c == card then table.remove(self.cards, i); break end end
    for i, c in ipairs(self.highlighted) do if c == card then table.remove(self.highlighted, i); break end end
    if card.area == self then card.area = nil end
    return card
end
function CardArea:add_to_highlighted(card, silent)
    if #self.highlighted >= self.config.highlighted_limit then
        self:remove_from_highlighted(self.highlighted[1])
    end
    self.highlighted[#self.highlighted + 1] = card
    card:highlight(true)
end
function CardArea:remove_from_highlighted(card, force)
    for i, c in ipairs(self.highlighted) do
        if c == card then table.remove(self.highlighted, i); break end
    end
    card:highlight(false)
end
function CardArea:unhighlight_all()
    for i = #self.highlighted, 1, -1 do self:remove_from_highlighted(self.highlighted[i]) end
end
function CardArea:change_size(n) self.config.card_limit = self.config.card_limit + n end
function CardArea:shuffle() end

-- ---------------------------------------------------------------- Card
Card = {}
Card.__index = Card
local card_id = 0
function Card.new(center, base)
    card_id = card_id + 1
    local c = setmetatable({ id = card_id, config = {}, ability = {}, base = base, children = {},
        T = { x = card_id, y = 0, w = 1, h = 1 } }, Card)
    c:set_ability(center)
    return c
end
function Card:set_ability(center, initial, delay)
    local keep_bonus = self.ability and self.ability.perma_bonus
    self.config.center = center
    self.config.center_key = center.key
    self.ability = { set = center.set, name = center.name or center.key, perma_bonus = keep_bonus }
    for k, v in pairs(center.config or {}) do self.ability[k] = deepcopy(v) end
    if center.set == 'Tarot' or center.set == 'Planet' or center.set == 'Spectral' then
        self.ability.consumeable = deepcopy(center.config or {})
    end
end
function Card:set_cost()
    local center = self.config.center
    local disc = (G.GAME and G.GAME.discount_percent) or 0
    self.cost = math.max(1, math.floor(((center.cost or 1) + 0.5) * (100 - disc) / 100))
    self.sell_cost = math.max(1, math.floor(self.cost / 2)) + (self.ability.extra_value or 0)
    self.sell_cost_label = self.sell_cost
end
function Card:add_to_deck(from_debuff)
    local c = self.config.center
    if c.add_to_deck then c:add_to_deck(self, from_debuff) end
end
function Card:remove_from_deck(from_debuff)
    local c = self.config.center
    if c.remove_from_deck then c:remove_from_deck(self, from_debuff) end
end
function Card:start_dissolve()
    if self.removed then return end
    self.removed = true
    if self.area then self.area:remove_card(self) end
    if self.config.center.set == 'Joker' then self:remove_from_deck() end
    for i, c in ipairs(G.playing_cards) do if c == self then table.remove(G.playing_cards, i); break end end
end
Card.remove = Card.start_dissolve
Card.start_materialize = function() end
Card.juice_up = function() end
function Card:highlight(b) self.highlighted = b end
function Card:set_seal(s) self.seal = s end
function Card:set_edition(e) self.edition = e end
function Card:is_suit(s) return self.base and self.base.suit == s end
function Card:is_face()
    local v = self.base and self.base.value
    return v == 'Jack' or v == 'Queen' or v == 'King'
end
function Card:can_use_consumeable() return self.config.center:can_use(self) end

local NOMINAL = { Jack = 10, Queen = 10, King = 10, Ace = 11 }
local function make_base(suit, rank)
    return { suit = suit, value = rank, nominal = NOMINAL[rank] or tonumber(rank) }
end

copy_card = function(other, new_card, a, b)
    local c = Card.new(other.config.center, deepcopy(other.base))
    c.ability = deepcopy(other.ability)
    c.seal, c.edition = other.seal, other.edition
    return c
end

draw_card = function(from, to, pct, dir, sort, card)
    card = card or from.cards[#from.cards]
    if not card then return end
    from:remove_card(card)
    to:emplace(card)
end

-- ---------------------------------------------------------------- tags, editions, hands
Tag = function(key, for_collection, blind_type) return { key = key, ability = { blind_type = blind_type } } end
add_tag = function(tag) G.GAME.tags[#G.GAME.tags + 1] = tag end
get_next_tag_key = function() return 'tag_test' end
poll_edition = function() return { foil = true } end

level_up_hand = function(card, hand, instant, amount)
    G.GAME.hands[hand].level = G.GAME.hands[hand].level + (amount or 1)
end
ease_dollars = function(n) G.GAME.dollars = G.GAME.dollars + n end
ease_hands_played = function(n) G.GAME.current_round.hands_left = G.GAME.current_round.hands_left + n end
ease_discard = function(n) G.GAME.current_round.discards_left = G.GAME.current_round.discards_left + n end
change_shop_size = function(n) G.GAME.shop_size = (G.GAME.shop_size or 2) + n end
end_round = function() G.GAME.round_won = true end
create_card_for_shop = function(area)
    local c = SMODS.create_card({ set = 'Joker' })
    return c
end

-- ---------------------------------------------------------------- Balatro classes the mod hooks
Sprite = { draw_self = function() end }
Game = { init_game_object = function() return {} end }
get_current_pool = function() return {}, 'pool' end
Blind = {}
Blind.__index = Blind
function Blind:press_play()
    local c = self.config.blind
    if c and c.press_play and not self.disabled then c:press_play() end
end
function Blind:disable()
    self.disabled = true
    local c = self.config.blind
    if c and c.disable then c:disable() end
end

-- ---------------------------------------------------------------- G
local function C() return setmetatable({}, { __index = function() return { 1, 1, 1, 1 } end }) end
G = {
    C = C(), STATES = {}, FUNCS = { can_buy = function(e) e.config.button = 'buy' end },
    P_CENTERS = {}, P_BLINDS = {}, P_CENTER_POOLS = {},
    E_MANAGER = EM, I = { CARD = {} },
}
G.C.SECONDARY_SET = C()
G.C.UI = C()
G.C.HAND_LEVELS = {}
-- the exact vanilla booster list (number of variants per kind and size)
local VANILLA_PACKS = {
    arcana = { normal = 4, jumbo = 2, mega = 2 }, celestial = { normal = 4, jumbo = 2, mega = 2 },
    standard = { normal = 4, jumbo = 2, mega = 2 }, spectral = { normal = 2, jumbo = 1, mega = 1 },
    buffoon = { normal = 2, jumbo = 1, mega = 1 },
}
for kind, sizes in pairs(VANILLA_PACKS) do
    for size, count in pairs(sizes) do
        for n = 1, count do
            local k = 'p_' .. kind .. '_' .. size .. '_' .. n
            G.P_CENTERS[k] = { set = 'Booster', kind = kind:sub(1,1):upper() .. kind:sub(2), key = k, config = {} }
        end
    end
end
get_blind_amount = function(ante)
    local amounts = { 300, 800, 2000, 5000, 11000, 20000, 35000, 50000 }
    return amounts[ante] or 100
end
get_starting_params = function() return { joker_slots = 5, consumable_slots = 2, hand_size = 8 } end

local ENH = { 'm_bonus', 'm_mult', 'm_wild', 'm_glass', 'm_steel', 'm_stone', 'm_gold', 'm_lucky' }
local ENH_NAMES = {
    m_bonus = 'Bonus Card', m_mult = 'Mult Card', m_wild = 'Wild Card', m_glass = 'Glass Card',
    m_steel = 'Steel Card', m_stone = 'Stone Card', m_gold = 'Gold Card', m_lucky = 'Lucky Card'
}
G.P_CENTERS.c_base = { key = 'c_base', set = 'Default', name = 'Default Base', config = {} }
for _, k in ipairs(ENH) do G.P_CENTERS[k] = { key = k, set = 'Enhanced', name = ENH_NAMES[k] or k, config = {} } end

local DECKS_LIST = { 'red', 'blue', 'yellow', 'green', 'black', 'magic', 'nebula', 'ghost', 'abandoned', 'checkered', 'zodiac', 'painted', 'anaglyph', 'plasma', 'erratic', 'challenge' }
for _, k in ipairs(DECKS_LIST) do
    G.P_CENTERS['b_' .. k] = { key = 'b_' .. k, set = 'Back', name = k .. ' Deck', pos = { x = 0, y = 0 }, config = {} }
end

-- ---------------------------------------------------------------- SMODS
SMODS = { Mods = { Balathstone = { path = MOD_ROOT }, Balearthstone = { path = MOD_ROOT } }, current_mod = { path = MOD_ROOT, id = 'Balathstone' } }
SMODS.Atlas = function() end
SMODS.DrawStep = function() end
SMODS.Back = {
    take_ownership = function(self, key, obj)
        local center = G.P_CENTERS['b_' .. key]
        if center and obj then
            for k, v in pairs(obj) do center[k] = v end
        end
    end
}
SMODS.load_file = function(path)
    return assert(loadfile(MOD_ROOT .. path))
end
local function register(prefix, set)
    return function(t)
        local center = deepcopy(t)
        for k, v in pairs(t) do if type(v) == 'function' then center[k] = v end end
        -- Steamodded adds the mod prefix unless the key already has it
        local k = t.key
        if k:sub(1, 3) ~= 'hs_' then k = 'hs_' .. k end
        center.key = prefix .. k
        center.set = set or t.set
        center.name = t.loc_txt and t.loc_txt.name or t.key
        center.config = center.config or {}
        G.P_CENTERS[center.key] = center
        return center
    end
end
G.P_TAGS = G.P_TAGS or {}
SMODS.Tag = function(t)
    local center = register('tag_', 'Tag')(t)
    G.P_CENTERS[center.key] = nil
    G.P_TAGS[center.key] = center
    return center
end
SMODS.Joker = register('j_', 'Joker')
SMODS.Consumable = register('c_')
SMODS.Voucher = register('v_', 'Voucher')
SMODS.Enhancement = register('m_', 'Enhanced')
SMODS.Booster = setmetatable({
    take_ownership = function(self, key, obj)
        local center = G.P_CENTERS['p_' .. key]
        if center and obj then
            for k, v in pairs(obj) do center[k] = v end
        end
    end
}, {
    __call = function(self, t)
        local center = register('p_', 'Booster')(t)
        return center
    end })
SMODS.Blind = setmetatable({ take_ownership = function() end }, {
    __call = function(self, t)
        local center = register('bl_', 'Blind')(t)
        G.P_BLINDS[center.key] = center
        return center
    end })

local RANKS = { '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King', 'Ace' }
local SUITS = { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }

local function pool_of(set)
    local keys = {}
    for k, c in pairs(G.P_CENTERS) do
        local ok = c.set == set and (not c.in_pool or c.in_pool(c) ~= false)
        if ok then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return keys
end

function SMODS.create_card(t)
    local key = t.key
    if not key then
        if t.set == 'Enhanced' then key = t.enhancement or pseudorandom_element(ENH)
        elseif t.set == 'Base' then key = 'c_base'
        else key = pseudorandom_element(pool_of(t.set)) end
    end
    local center = assert(G.P_CENTERS[key], 'no center ' .. tostring(key))
    local base
    if center.set == 'Enhanced' or center.set == 'Default' then
        base = make_base(t.suit or pseudorandom_element(SUITS), t.rank or pseudorandom_element(RANKS))
    end
    local c = Card.new(center, base)
    if t.seal then c.seal = t.seal end
    if t.edition then c.edition = t.edition end
    c:set_cost()
    return c
end

function SMODS.add_card(t)
    local c = SMODS.create_card(t)
    local area = t.area
    if not area then
        if c.ability.set == 'Joker' then area = G.jokers
        elseif c.base then area = G.hand
        else area = G.consumeables end
    end
    if c.base then
        G.playing_cards[#G.playing_cards + 1] = c
    end
    area:emplace(c)
    if c.ability.set == 'Joker' then c:add_to_deck() end
    return c
end

function SMODS.destroy_cards(cards)
    if cards.config then cards = { cards } end
    for _, c in ipairs(cards) do c.destroyed = true; c:start_dissolve() end
end

function SMODS.change_base(card, suit, rank)
    if suit then card.base.suit = suit end
    if rank then card.base.value = rank; card.base.nominal = NOMINAL[rank] or tonumber(rank) end
    return card
end

SMODS.last_hand_score = 0

-- dispatch a context the way Steamodded does: jokers area, consumables,
-- vouchers, then the mod-level calculate
function SMODS.calculate_context(ctx)
    local rets = {}
    for _, area in ipairs({ G.jokers, G.consumeables }) do
        local snapshot = {}
        for i, c in ipairs(area.cards) do snapshot[i] = c end
        for _, c in ipairs(snapshot) do
            if not c.removed and c.config.center.calculate then
                local r = c.config.center:calculate(c, ctx)
                if r then rets[#rets + 1] = r end
            end
        end
    end
    local vkeys = {}
    for k in pairs(G.GAME.used_vouchers) do vkeys[#vkeys + 1] = k end
    table.sort(vkeys)
    for _, k in ipairs(vkeys) do
        local center = G.P_CENTERS[k]
        if center and center.calculate then
            local r = center:calculate({ ability = {} }, ctx)
            if r then rets[#rets + 1] = r end
        end
    end
    if SMODS.current_mod.calculate then
        local r = SMODS.current_mod.calculate(SMODS.current_mod, ctx)
        if r then rets[#rets + 1] = r end
    end
    return rets
end

-- ---------------------------------------------------------------- test driver
T = {}

local HAND_NAMES = { 'High Card', 'Pair', 'Two Pair', 'Three of a Kind', 'Straight', 'Flush', 'Full House',
    'Four of a Kind', 'Straight Flush', 'Five of a Kind', 'Flush House', 'Flush Five' }

function T.new_run()
    T_messages = {}
    EM.queue = {}
    G.GAME = {
        dollars = 10, discount_percent = 0, inflation = 0, round = 0,
        round_resets = { hands = 4, discards = 3, ante = 1, blind_tags = { Small = 'tag_small', Big = 'tag_big' } },
        current_round = { hands_left = 4, discards_left = 3 },
        probabilities = { normal = 1 },
        used_vouchers = {}, tags = {}, hands = {},
        facing_blind = false,
    }
    for _, h in ipairs(HAND_NAMES) do G.GAME.hands[h] = { level = 1, played = 0, visible = true } end
    SMODS.last_hand_score = 0
    -- board size comes from the mod's patched get_starting_params, like a real run
    G.jokers = CardArea.new({ type = 'joker', card_limit = get_starting_params().joker_slots })
    G.consumeables = CardArea.new({ type = 'joker', card_limit = 2 })
    G.hand = CardArea.new({ type = 'hand', card_limit = 8, highlighted_limit = 5 })
    G.deck = CardArea.new({ type = 'deck' })
    G.play = CardArea.new({ type = 'play' })
    G.discard = CardArea.new({ type = 'discard' })
    G.shop_jokers = nil
    G.playing_cards = {}
    for _, s in ipairs(SUITS) do
        for _, r in ipairs(RANKS) do
            local c = Card.new(G.P_CENTERS.c_base, make_base(s, r))
            G.playing_cards[#G.playing_cards + 1] = c
            G.deck:emplace(c)
        end
    end
end

function T.add(id, slot_limit)
    if slot_limit then G.jokers.config.card_limit = slot_limit end
    local key = id:find('^j_') and id or ('j_hs_' .. id)
    return SMODS.add_card({ key = key, area = G.jokers })
end

function T.buy(id)
    local c = T.add(id)
    SMODS.calculate_context({ buying_card = true, card = c })
    T_flush()
    return c
end

function T.spell(id)
    local key = id:find('^c_') and id or ('c_hs_' .. id)
    return SMODS.add_card({ key = key, area = G.consumeables })
end

function T.redeem(id)
    local key = 'v_hs_' .. id
    G.GAME.used_vouchers[key] = true
    local center = G.P_CENTERS[key]
    if center.redeem then center:redeem({}) end
    T_flush()
end

function T.minion_keys()
    local t = {}
    for _, c in ipairs(G.jokers.cards) do t[#t + 1] = c.config.center.key end
    return t
end

function T.count(id)
    local n = 0
    for _, c in ipairs(G.jokers.cards) do if c.config.center.key == 'j_hs_' .. id then n = n + 1 end end
    return n
end

function T.start_round(boss)
    G.GAME.round = G.GAME.round + 1
    local center = boss and G.P_BLINDS['bl_hs_' .. boss] or nil
    G.GAME.blind = setmetatable({ chips = 1000, boss = boss ~= nil, disabled = false,
        config = { blind = center or { key = 'bl_small' } } }, Blind)
    G.GAME.blind_on_deck = boss and 'Boss' or 'Small'
    G.GAME.facing_blind = true
    G.GAME.chips = 0
    G.GAME.current_round.hands_left = G.GAME.round_resets.hands
    G.GAME.current_round.discards_left = G.GAME.round_resets.discards
    if center and center.set_blind then center:set_blind() end
    SMODS.calculate_context({ setting_blind = true, blind = center })
    T_flush()
    local drawn = {}
    while #G.hand.cards < G.hand.config.card_limit and #G.deck.cards > 0 do
        local c = G.deck.cards[#G.deck.cards]
        draw_card(G.deck, G.hand, nil, nil, nil, c)
        drawn[#drawn + 1] = c
    end
    SMODS.calculate_context({ first_hand_drawn = true, hand_drawn = drawn })
    T_flush()
end

-- Play `n` cards from hand; returns the chips and mult your minions added
function T.play_hand(n)
    n = n or 1
    G.GAME.blind:press_play()
    T_flush()
    for i = 1, math.min(n, #G.hand.cards) do draw_card(G.hand, G.play, nil, nil, nil, G.hand.cards[1]) end
    SMODS.calculate_context({ before = true, full_hand = G.play.cards })
    T_flush()
    local chips, mult = 0, 0
    local snapshot = {}
    for i, c in ipairs(G.jokers.cards) do snapshot[i] = c end
    for _, c in ipairs(snapshot) do
        local r = c.config.center.calculate and c.config.center:calculate(c, { joker_main = true, cardarea = G.jokers })
        while r do
            chips = chips + (r.chips or 0)
            mult = mult + (r.mult or 0)
            if r.Xmult or r.x_mult then mult = mult * (r.Xmult or r.x_mult) end
            r = r.extra
        end
    end
    -- NOTE: like Steamodded, joker_main only goes to cards, never the mod-level calculate
    T_flush()
    SMODS.last_hand_score = chips * math.max(1, mult)
    G.GAME.current_round.hands_left = G.GAME.current_round.hands_left - 1
    -- Like the real game: context.after runs while G.GAME.chips still holds the
    -- old total; the score lands via an ease event queued before after's events.
    SMODS.calculate_context({ after = true, full_hand = G.play.cards })
    G.GAME.chips = G.GAME.chips + SMODS.last_hand_score
    T_flush()
    for i = #G.play.cards, 1, -1 do draw_card(G.play, G.discard, nil, nil, nil, G.play.cards[i]) end
    local drawn = {}
    while #G.hand.cards < G.hand.config.card_limit and #G.deck.cards > 0 do
        local c = G.deck.cards[#G.deck.cards]
        draw_card(G.deck, G.hand, nil, nil, nil, c)
        drawn[#drawn + 1] = c
    end
    SMODS.calculate_context({ hand_drawn = drawn })
    T_flush()
    return chips, mult
end

function T.discard(n)
    n = n or 1
    local cards = {}
    for i = 1, math.min(n, #G.hand.cards) do cards[i] = G.hand.cards[i] end
    SMODS.calculate_context({ pre_discard = true, full_hand = cards })
    for _, c in ipairs(cards) do draw_card(G.hand, G.discard, nil, nil, nil, c) end
    G.GAME.current_round.discards_left = G.GAME.current_round.discards_left - 1
    T_flush()
end

function T.end_round()
    SMODS.calculate_context({ end_of_round = true })
    T_flush()
    G.GAME.facing_blind = false
    for _, area in ipairs({ G.hand, G.play, G.discard }) do
        for i = #area.cards, 1, -1 do draw_card(area, G.deck, nil, nil, nil, area.cards[i]) end
    end
end

function T.open_shop(minions)
    G.shop_jokers = CardArea.new({ type = 'shop', card_limit = 2 })
    for _, id in ipairs(minions or {}) do
        local c = SMODS.create_card({ key = 'j_hs_' .. id })
        G.shop_jokers:emplace(c)
    end
    SMODS.calculate_context({ starting_shop = true })
    T_flush()
end

function T.close_shop()
    SMODS.calculate_context({ ending_shop = true })
    G.shop_jokers = nil
    T_flush()
end

function T.sell(card)
    SMODS.calculate_context({ selling_card = true, card = card })
    card:start_dissolve()
    T_flush()
end

-- select targets then try to use a consumable; returns whether it was usable
function T.use(card, targets)
    G.jokers:unhighlight_all()
    G.hand:unhighlight_all()
    G.consumeables:unhighlight_all()
    G.consumeables:add_to_highlighted(card)
    for _, t in ipairs(targets or {}) do
        if t.area == G.jokers then G.jokers:add_to_highlighted(t) else G.hand:add_to_highlighted(t) end
    end
    if not card.config.center:can_use(card) then return false end
    card.config.center:use(card, G.consumeables)
    G.consumeables:remove_card(card)
    SMODS.calculate_context({ using_consumeable = true, consumeable = card })
    T_flush()
    return true
end

function T.atk(c) return (Balathstone or Balearthstone).attack(c) end
function T.hp(c) return (Balathstone or Balearthstone).health(c) end
