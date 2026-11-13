-- Balathstone generated playing cards
-- Hearthstone cards that get shuffled into your deck appear as themselves:
-- custom enhancements that replace the whole card face with the real card art.
-- They have no rank or suit and never appear randomly.
local HS = Balathstone or Balearthstone

HS.enh_count = HS.enh_count or 0
local function card_enh(t)
    HS.enh_count = HS.enh_count + 1
    local idx = HS.enh_count - 1
    SMODS.Enhancement({
        key = t.id,
        loc_txt = { name = t.name, text = t.text },
        atlas = 'hs_cards',
        pos = { x = idx % 8, y = math.floor(idx / 8) },
        config = t.config or {},
        replace_base_card = true,
        no_rank = true,
        no_suit = true,
        always_scores = t.always_scores,
        weight = 0,
        in_pool = function() return false end,
        hs_id = t.hs_id,
        hs_text = t.text,
        calculate = t.calculate,
        loc_vars = function(self, info_queue)
            for _, k in ipairs(HS.keyword_tips(t.text)) do info_queue[#info_queue + 1] = { set = 'Other', key = k } end
            return { vars = {} }
        end,
    })
end

-- Waxadred's Deathrattle shuffles this in; drawing it summons Waxadred (core.lua: HS.check_candles)
card_enh { id = 'waxadreds_candle', name = "Waxadred's Candle", hs_id = 'DRG_036t',
    text = { 'Casts When Drawn:', '{C:attention}Summon{} Waxadred' } }

-- Buying Patches the Pirate hides him here (core.lua: HS.patches_on_buy)
card_enh { id = 'patches_the_pirate', name = 'Patches the Pirate', hs_id = 'CFM_637',
    text = { 'Casts When Drawn:', '{C:attention}Summon{} Patches.', 'Also jumps out when you', 'buy a {C:attention}Pirate{}' } }

-- Map to the Golden Monkey shuffles this in
card_enh { id = 'golden_monkey', name = 'Golden Monkey', hs_id = 'LOE_019t2', always_scores = true,
    text = { 'Always scores.', 'Earn {C:money}$5{} when scored' },
    calculate = function(self, card, context)
        if context.main_scoring and context.cardarea == G.play then
            return { dollars = 5 }
        end
    end }
