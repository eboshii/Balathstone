-- Balathstone Blinds: Legendary Boss Blinds plus Small / Big Blind encounters.
-- Every Blind is a Hearthstone minion that attacks one of your minions each
-- time you play a hand (src/core.lua: HS.boss_attack). Attack is the printed
-- value scaled by Ante. Small/Big encounters use Steamodded's blind pools, so
-- each Ante rolls a random Small and Big encounter just like the Boss.
--
-- Optional fields read by the engine:
--   hs_atk        base Attack           hs_mode    'random' | 'strongest' | 'aoe'
--   hs_times      attacks per hand      hs_ramp    +Attack after each hand
--   hs_poison     destroys what it hits hs_freeze  Freezes what it hits
--   hs_steal      $ stolen per attack   hs_divine_shield  ignores your first Blind damage
--   hs_round_start(center)  acts at the start of the round
--   hs_charge     also attacks before each hand    hs_rush      attacks at round start
--   hs_lifesteal  its damage heals the Blind       hs_reborn    comes back once (+x of requirement)
--   hs_stealth    immune to Blind damage until it attacks
--   hs_army / hs_army_grow  summons an extra attacker every turn (Attack, growth per summon)
--   hs_enrage     attacks once more when half beaten   hs_kill_ramp  +Attack per kill
--   hs_attack_on_spell  attacks when you cast a Spell  hs_discard_ramp  +Attack per discard
--   hs_mode 'healthiest'  attacks your highest-Health minion
-- A Silenced (disabled) Blind keeps attacking but loses every other ability.
local HS = Balathstone or Balearthstone

local function atk_line(center, aoe)
    return aoe and 'Deals #1# damage to ALL your minions each turn' or 'Attacks a minion for #1# each turn'
end

HS.blind_index = HS.blind_index or 0
local function B(b)
    HS.blind_index = HS.blind_index + 1
    local text = { atk_line(b, b.hs_mode == 'aoe') }
    for _, l in ipairs(b.text or {}) do text[#text + 1] = l end
    local def = {
        key = b.key,
        loc_txt = { name = b.name, text = text },
        atlas = 'hs_blinds',
        pos = { x = 0, y = HS.blind_index - 1 },
        discovered = true,
        dollars = b.dollars or 5,
        mult = b.mult or 2,
        boss_colour = b.colour or HEX('4A3B2A'),
        hs_id = b.hs_id,
        hs_atk = b.atk,
        hs_mode = b.hs_mode, hs_times = b.hs_times, hs_ramp = b.hs_ramp,
        hs_poison = b.hs_poison, hs_freeze = b.hs_freeze, hs_steal = b.hs_steal,
        hs_divine_shield = b.hs_divine_shield, hs_round_start = b.hs_round_start,
        loc_vars = function(self) return { vars = { HS.scaled_attack(b.atk) } } end,
        collection_loc_vars = function(self) return { vars = { b.atk } } end,
        recalc_debuff = b.recalc_debuff,
        debuff_hand = b.debuff_hand,
        stay_flipped = b.stay_flipped,
        press_play = b.press_play,
        set_blind = b.set_blind,
        disable = b.disable,
        defeat = b.defeat,
    }
    for k, v in pairs(b) do
        if type(k) == 'string' and k:sub(1, 3) == 'hs_' and def[k] == nil then def[k] = v end
    end
    if b.kind == 'small' then
        def.small = { min = b.min or 1, max = b.max }
        def.boss_colour = b.colour or HEX('3C6E8C')
    elseif b.kind == 'big' then
        def.big = { min = b.min or 1, max = b.max }
        def.boss_colour = b.colour or HEX('8C6A3C')
    else
        def.boss = { min = b.min or 1, max = b.max, showdown = b.showdown }
    end
    SMODS.Blind(def)
end

-- =========================================================================
-- BOSSES (five are possible from Ante 1)
-- =========================================================================
B { key = 'ragnaros', name = 'Ragnaros the Firelord', hs_id = 'VAN_EX1_298', atk = 8, min = 1,
    colour = HEX('FF4500'), hs_mode = 'random',
    text = { 'DIE, INSECT! Attacks a random', 'minion, ignoring Taunt' } }

B { key = 'hogger', name = 'Hogger', hs_id = 'VAN_NEW1_040', atk = 4, min = 1, colour = HEX('8B5A2B'),
    hs_times = 2, text = { 'Attacks twice each turn' } }

B { key = 'baron_geddon', name = 'Baron Geddon', hs_id = 'VAN_EX1_249', atk = 3, min = 1,
    colour = HEX('C0392B'), hs_mode = 'aoe', text = { '(Living Bomb)' } }

B { key = 'illidan', name = 'Illidan Stormrage', hs_id = 'VAN_EX1_614', atk = 6, min = 1, colour = HEX('00FF7F'),
    text = { 'You are not prepared!', 'Hands must contain 5 cards' },
    debuff_hand = function(self, cards, hand, handname, check) return #cards < 5 end }

B { key = 'edwin', name = 'Edwin VanCleef', hs_id = 'VAN_EX1_613', atk = 5, min = 1, colour = HEX('708090'),
    text = { 'Only the first hand type you', 'play can be played this round' },
    set_blind = function(self) HS.state().edwin_hand = nil end,
    debuff_hand = function(self, cards, hand, handname, check)
        local st = HS.state()
        if not st.edwin_hand then
            if not check then st.edwin_hand = handname end
            return false
        end
        return handname ~= st.edwin_hand
    end }

B { key = 'loatheb', name = 'Loatheb', hs_id = 'FP1_030', atk = 5, min = 2, colour = HEX('2E8B57'),
    text = { 'You can\'t cast Spells', 'this round' } }

B { key = 'malygos', name = 'Malygos', hs_id = 'VAN_EX1_563', atk = 4, min = 2, colour = HEX('4169E1'),
    text = { 'All Spade cards are debuffed' },
    recalc_debuff = function(self, card) return card:is_suit('Spades', true) end }

B { key = 'sylvanas', name = 'Sylvanas Windrunner', hs_id = 'VAN_EX1_016', atk = 5, min = 2, colour = HEX('9370DB'),
    text = { 'Minions with less than 3', 'Health give no Mult' } }

B { key = 'ysera', name = 'Ysera', hs_id = 'VAN_EX1_572', atk = 4, min = 2, colour = HEX('3CB371'),
    text = { 'Dream: 1 in 4 cards are', 'drawn face down' },
    stay_flipped = function(self, area, card)
        return area == G.hand and pseudorandom('hs_ysera') < 0.25
    end }

B { key = 'dr_boom', name = 'Dr. Boom', hs_id = 'CORE_GVG_110', atk = 7, min = 3, colour = HEX('FFD700'),
    text = { '1 in 4 cards are debuffed', '(Boom Bots!)' },
    recalc_debuff = function(self, card)
        local round = G.GAME.round or 0
        if card.hs_boom_round ~= round then
            card.hs_boom_round = round
            card.hs_boom_hit = pseudorandom('hs_boom') < 0.25
        end
        return card.hs_boom_hit
    end }

B { key = 'nozdormu', name = 'Nozdormu', hs_id = 'VAN_EX1_560', atk = 6, min = 3, colour = HEX('DAA520'),
    text = { 'Start the round with', '0 Mulligans' },
    set_blind = function(self) ease_discard(-G.GAME.current_round.discards_left) end }

B { key = 'gruul', name = 'Gruul', hs_id = 'VAN_NEW1_038', atk = 5, min = 3, colour = HEX('6B8E23'),
    hs_ramp = 2, text = { 'Gains +2 Attack after', 'every turn' } }

B { key = 'malganis', name = "Mal'Ganis", hs_id = 'GVG_021', atk = 6, min = 3, colour = HEX('4B0082'),
    text = { 'Your hero is Immune...', 'you can\'t gain money this round' } }

B { key = 'jaraxxus', name = 'Lord Jaraxxus', hs_id = 'VAN_EX1_323', atk = 4, min = 4, mult = 3,
    colour = HEX('8B0000'), text = { 'YOU FACE JARAXXUS!', 'Very large Blind' } }

B { key = 'kel_thuzad', name = "Kel'Thuzad", hs_id = 'FP1_013', atk = 6, min = 4, colour = HEX('483D8B'),
    text = { 'All Heart and Diamond cards', 'are debuffed' },
    recalc_debuff = function(self, card) return card:is_suit('Hearts', true) or card:is_suit('Diamonds', true) end }

B { key = 'onyxia', name = 'Onyxia', hs_id = 'VAN_EX1_562', atk = 6, min = 4, colour = HEX('2F4F4F'),
    text = { 'Deep Breath: Freezes a random', 'minion every turn' },
    press_play = function(self)
        local m = HS.pick(HS.minions(), 'hs_onyxia')
        if m then HS.blind_say('Deep Breath!', G.C.BLUE); HS.freeze_minion(m) end
    end }

B { key = 'grommash', name = 'Grommash Hellscream', hs_id = 'VAN_EX1_414', atk = 9, min = 5, colour = HEX('B22222'),
    hs_mode = 'strongest', text = { 'Attacks your strongest minion,', 'ignoring Taunt' } }

B { key = 'yogg_saron', name = 'Yogg-Saron, Hope\'s End', hs_id = 'OG_134', atk = 7, min = 5, colour = HEX('556B2F'),
    text = { 'Madness: every turn, 2 cards', 'in your hand get a random rank' },
    press_play = function(self)
        local pool = {}
        for _, c in ipairs(G.hand.cards) do pool[#pool + 1] = c end
        if #pool > 0 then HS.blind_say('Madness!', G.C.PURPLE) end
        for _ = 1, math.min(2, #pool) do
            local i = math.floor(pseudorandom('hs_yogg_boss') * #pool) + 1
            local c = table.remove(pool, i)
            HS.set_rank(c, HS.pick(HS.RANKS, 'hs_yogg_rank'))
        end
    end }

-- Showdown (Ante 8)
B { key = 'lich_king', name = 'The Lich King', hs_id = 'ICC_314', atk = 8, min = 8, showdown = true,
    colour = HEX('00BFFF'), mult = 2.5, text = { 'All Face cards are Frozen', '(debuffed)' },
    recalc_debuff = function(self, card) return card:is_face(true) end }

B { key = 'deathwing', name = 'Deathwing', hs_id = 'VAN_NEW1_030', atk = 12, min = 8, showdown = true,
    colour = HEX('800000'), mult = 3, text = { 'I AM POWER INCARNATE! Destroys', 'your leftmost minion at round start' },
    hs_round_start = function()
        local m = HS.minions()[1]
        if m then HS.blind_say('I AM POWER INCARNATE!', G.C.RED); HS.kill(m, 'destroy') end
    end }

B { key = 'c_thun', name = "C'Thun", hs_id = 'OG_280', atk = 10, min = 8, showdown = true,
    colour = HEX('800080'), mult = 2.5, text = { 'Your deck will betray you!', '-1 hand size' },
    set_blind = function(self)
        G.hand:change_size(-1)
        HS.state().cthun_shrunk = true
    end,
    disable = function(self)
        if HS.state().cthun_shrunk then HS.state().cthun_shrunk = false; G.hand:change_size(1) end
    end,
    defeat = function(self)
        if HS.state().cthun_shrunk then HS.state().cthun_shrunk = false; G.hand:change_size(1) end
    end }

B { key = 'denathrius', name = 'Sire Denathrius', hs_id = 'REV_906', atk = 10, min = 8, showdown = true,
    colour = HEX('4A0E17'), mult = 2.5, text = { 'A toast to your demise! The', 'Blind grows 10% every turn' },
    press_play = function(self)
        G.GAME.blind.chips = math.floor(G.GAME.blind.chips * 1.1)
        HS.update_blind_text()
        HS.blind_say('+10%!', G.C.RED)
    end }

-- =========================================================================
-- MORE BOSSES (Hearthstone abilities as enemy keywords)
-- =========================================================================
B { key = 'moroes', name = 'Moroes', hs_id = 'KAR_044', atk = 3, min = 1, colour = HEX('5B4A6B'),
    hs_stealth = true, hs_army = 1, hs_army_name = 'Steward',
    text = { 'Stealth: your hands and Blind', 'damage miss until it attacks.', 'Summons a 1/1 Steward each turn' } }

B { key = 'darius_crowley', name = 'Darius Crowley', hs_id = 'GIL_547', atk = 5, min = 2, colour = HEX('7A5230'),
    hs_rush = true, hs_kill_ramp = 2,
    text = { 'Rush: attacks at the start of', 'the round. +2 Attack whenever', 'it kills a minion' } }

B { key = 'maexxna', name = 'Maexxna', hs_id = 'FP1_010', atk = 4, min = 2, colour = HEX('3D4F2F'),
    hs_poison = true,
    text = { 'Poisonous. Web Wrap: Silences', '2 random minions at the start', 'of the round' },
    hs_round_start = function()
        local pool = HS.minions()
        for _ = 1, 2 do
            if #pool == 0 then break end
            if _ == 1 then HS.blind_say('Web Wrap!', G.C.UI.TEXT_INACTIVE) end
            local i = math.floor(HS.rand('hs_web') * #pool) + 1
            HS.silence_minion(table.remove(pool, i))
        end
    end }

B { key = 'nefarian', name = 'Nefarian', hs_id = 'BRM_030', atk = 8, min = 3, colour = HEX('2B1B1B'),
    text = { 'Steals a random Spell from', 'your hand at the start of', 'the round' },
    hs_round_start = function()
        local victim = HS.pick((G.consumeables and G.consumeables.cards) or {}, 'hs_nefarian')
        if victim then
            HS.event(function() victim:start_dissolve(nil, true) end)
            HS.blind_say('Stole a Spell!', G.C.PURPLE)
        end
    end }

B { key = 'al_akir', name = "Al'Akir the Windlord", hs_id = 'VAN_NEW1_010', atk = 3, min = 3, colour = HEX('6FA8DC'),
    hs_charge = true, hs_times = 2, hs_divine_shield = true,
    text = { 'Charge, Windfury, Divine Shield:', 'attacks twice before AND after', 'each hand' } }

B { key = 'medivh', name = 'Medivh, the Guardian', hs_id = 'KAR_097', atk = 6, min = 3, colour = HEX('3B5BA5'),
    hs_attack_on_spell = true,
    text = { 'Atiesh: attacks every time', 'you cast a Spell' } }

B { key = 'lanathel', name = "Blood-Queen Lana'thel", hs_id = 'ICC_841', atk = 4, min = 3, colour = HEX('8E1B3A'),
    hs_lifesteal = true, hs_discard_ramp = 1,
    text = { 'Lifesteal: its damage heals the', 'Blind. +1 Attack for each card', 'you discard this round' } }

B { key = 'patchwerk', name = 'Patchwerk', hs_id = 'RLK_071', atk = 8, min = 4, colour = HEX('6B8E5A'),
    hs_mode = 'healthiest', hs_enrage = true,
    text = { 'Hateful Strike: attacks your', 'highest-Health minion. Attacks', 'twice once half beaten' } }

B { key = 'sindragosa', name = 'Sindragosa', hs_id = 'ICC_838', atk = 7, min = 4, colour = HEX('9FD3F2'),
    text = { 'Frost Breath: Freezes your', '2 leftmost minions every turn' },
    press_play = function(self)
        local ms = HS.minions()
        if #ms > 0 then HS.blind_say('Frost Breath!', G.C.BLUE) end
        for i = 1, math.min(2, #ms) do HS.freeze_minion(ms[i]) end
    end }

B { key = 'hakkar', name = 'Hakkar, the Soulflayer', hs_id = 'TRL_541', atk = 5, min = 4, colour = HEX('7B1E1E'),
    text = { 'Corrupted Blood: 1 damage to', 'ALL your minions every turn,', '+1 more each turn' },
    set_blind = function(self) HS.state().hakkar_blood = 0 end,
    press_play = function(self)
        local st = HS.state()
        st.hakkar_blood = (st.hakkar_blood or 0) + 1
        HS.blind_say('Corrupted Blood ' .. st.hakkar_blood, G.C.RED)
        for _, m in ipairs(HS.minions()) do HS.damage(m, st.hakkar_blood, 'boss') end
    end }

B { key = 'archimonde', name = 'Archimonde', hs_id = 'GDB_128', atk = 6, min = 5, colour = HEX('2E7D32'),
    hs_army = 3, hs_army_name = 'Demon',
    text = { 'Legion: summons a 3-Attack', 'Demon after every turn; each', 'Demon attacks too' } }

-- Showdowns (Ante 8, and every 8 Antes in endless)
B { key = 'kiljaeden', name = "Kil'jaeden", hs_id = 'GDB_145', atk = 7, min = 8, showdown = true,
    colour = HEX('1B5E20'), mult = 2.5, hs_army = 2, hs_army_grow = 2, hs_army_name = 'Demon',
    text = { 'Endless Portal: summons a Demon', 'after every turn, each +2 Attack', 'bigger than the last' } }

B { key = 'yshaarj', name = "Y'Shaarj, Rage Unbound", hs_id = 'OG_042', atk = 10, min = 8, showdown = true,
    colour = HEX('4A2C2A'), mult = 2.5, hs_charge = true, hs_mode = 'strongest',
    text = { 'Charge: attacks your strongest', 'minion before AND after', 'each hand' } }

B { key = 'nzoth', name = "N'Zoth, the Corruptor", hs_id = 'OG_133', atk = 6, min = 8, showdown = true,
    colour = HEX('3E2350'), mult = 2.5, hs_reborn = 0.5,
    text = { 'Reborn: the first time you beat', 'it, it returns with +50% of', 'its requirement' } }

-- =========================================================================
-- SMALL BLIND ENCOUNTERS (no abilities)
-- =========================================================================
local function small(key, name, hs_id, atk, min) B { kind = 'small', key = key, name = name, hs_id = hs_id, atk = atk, min = min, mult = 1, dollars = 3 } end
small('wisp', 'Wisp', 'VAN_CS2_231', 1)
small('murloc_raider', 'Murloc Raider', 'VAN_CS2_168', 2)
small('river_crocolisk', 'River Crocolisk', 'VAN_CS2_120', 2)
small('oasis_snapjaw', 'Oasis Snapjaw', 'VAN_CS2_119', 2)
small('defias_ringleader', 'Defias Ringleader', 'VAN_EX1_131', 2)
small('frostwolf_grunt', 'Frostwolf Grunt', 'VAN_CS2_121', 2)
small('razorfen_hunter', 'Razorfen Hunter', 'VAN_CS2_196', 2)
small('bloodfen_raptor', 'Bloodfen Raptor', 'VAN_CS2_172', 3)
small('ironfur_grizzly', 'Ironfur Grizzly', 'VAN_CS2_125', 3, 2)
small('magma_rager', 'Magma Rager', 'VAN_CS2_118', 5, 3)
small('silverback_patriarch', 'Silverback Patriarch', 'VAN_CS2_127', 1)
small('senjin_shieldmasta', "Sen'jin Shieldmasta", 'VAN_CS2_179', 3, 2)
small('spiteful_smith', 'Spiteful Smith', 'VAN_CS2_221', 4, 3)
small('booty_bay_bodyguard', 'Booty Bay Bodyguard', 'VAN_CS2_187', 5, 3)
small('lord_of_the_arena', 'Lord of the Arena', 'VAN_CS2_162', 6, 4)
small('war_golem', 'War Golem', 'VAN_CS2_186', 7, 5)
small('core_hound', 'Core Hound', 'VAN_CS2_201', 9, 6)

-- =========================================================================
-- BIG BLIND ENCOUNTERS (one mild quirk each; Silence removes it)
-- =========================================================================
local function big(t) t.kind = 'big'; t.mult = 1.5; t.dollars = 4; B(t) end
big { key = 'chillwind_yeti', name = 'Chillwind Yeti', hs_id = 'VAN_CS2_182', atk = 4 }
big { key = 'thrallmar_farseer', name = 'Thrallmar Farseer', hs_id = 'VAN_EX1_021', atk = 2, hs_times = 2,
    text = { 'Windfury: attacks twice' } }
big { key = 'frost_elemental', name = 'Frost Elemental', hs_id = 'VAN_EX1_283', atk = 5, hs_freeze = true,
    text = { 'Freezes the minion it attacks' } }
big { key = 'gurubashi_berserker', name = 'Gurubashi Berserker', hs_id = 'VAN_EX1_399', atk = 2, hs_ramp = 3,
    text = { 'Gains +3 Attack after every turn' } }
big { key = 'emperor_cobra', name = 'Emperor Cobra', hs_id = 'VAN_EX1_170', atk = 2, hs_poison = true,
    text = { 'Poisonous: destroys any minion', 'it damages' } }
big { key = 'bloodsail_raider', name = 'Bloodsail Raider', hs_id = 'VAN_NEW1_018', atk = 2, hs_steal = 2,
    text = { 'Steals $2 every time it attacks' } }
big { key = 'scarlet_crusader', name = 'Scarlet Crusader', hs_id = 'VAN_EX1_020', atk = 3, hs_divine_shield = true,
    text = { 'Divine Shield: blocks the first', 'damage, or your first hand if', 'nothing has hit it yet' } }
big { key = 'priestess_of_elune', name = 'Priestess of Elune', hs_id = 'VAN_EX1_583', atk = 5,
    text = { 'Heals the Blind for 4', 'every turn' },
    press_play = function(self) HS.heal_blind(4); HS.blind_say('Heals 4', G.C.GREEN) end }
big { key = 'stormpike_commando', name = 'Stormpike Commando', hs_id = 'VAN_CS2_150', atk = 4,
    text = { 'Deals 2 damage to a random', 'minion at the start of the round' },
    hs_round_start = function()
        local m = HS.pick(HS.minions(), 'hs_stormpike')
        if m then HS.blind_say('Snipe!', G.C.RED); HS.damage(m, 2, 'boss') end
    end }
big { key = 'boulderfist_ogre', name = 'Boulderfist Ogre', hs_id = 'VAN_CS2_200', atk = 6, min = 3 }
big { key = 'reckless_rocketeer', name = 'Reckless Rocketeer', hs_id = 'VAN_CS2_213', atk = 4, min = 2, hs_charge = true,
    text = { 'Charge: also attacks before', 'each hand' } }
big { key = 'cabal_shadow_priest', name = 'Cabal Shadow Priest', hs_id = 'VAN_EX1_091', atk = 4, min = 2,
    text = { 'Mind Control: your weakest', 'minion is Silenced this round' },
    hs_round_start = function()
        local weakest
        for _, m in ipairs(HS.minions()) do
            if not weakest or HS.attack(m) < HS.attack(weakest) then weakest = m end
        end
        if weakest then HS.silence_minion(weakest) end
    end }
big { key = 'patient_assassin', name = 'Patient Assassin', hs_id = 'VAN_EX1_522', atk = 1, min = 2, hs_stealth = true,
    hs_poison = true, text = { 'Stealth, Poisonous: your hands', 'and Blind damage miss until', 'it attacks' } }
big { key = 'imp_master', name = 'Imp Master', hs_id = 'VAN_EX1_597', atk = 2, hs_army = 1, hs_army_name = 'Imp',
    text = { 'Summons a 1/1 Imp after every', 'turn; each Imp attacks too' } }
big { key = 'wrapped_golem', name = 'Wrapped Golem', hs_id = 'ULD_215', atk = 5, min = 3, hs_reborn = 0.25,
    text = { 'Reborn: the first time you beat', 'it, it returns with +25%' } }
big { key = 'amani_war_bear', name = 'Amani War Bear', hs_id = 'TRL_550', atk = 5, min = 3, hs_rush = true,
    text = { 'Rush: attacks at the start', 'of the round' } }
