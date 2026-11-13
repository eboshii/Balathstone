-- Balathstone Locations (replace Planet cards)
-- Each real Hearthstone Location levels up one poker hand.
local HS = Balathstone or Balearthstone
HS.location_for_hand = HS.location_for_hand or {}

local function location(id, name, hs_id, hand, mult, chips)
    HS.location_for_hand[hand] = 'c_hs_' .. id
    HS.spell {
        id = id, name = name, hs_id = hs_id, set = 'Planet', mana = 2, random = false,
        config = { hand_type = hand },
        text = { '{S:0.8}({S:0.8,V:1}lvl.#1#{S:0.8}){} Level up', '{C:attention}' .. hand .. '{}',
            '{C:mult}+' .. mult .. '{} Mult and', '{C:chips}+' .. chips .. '{} Chips' },
        art_text = { 'Level up {C:attention}' .. hand .. '{}:', '{C:mult}+' .. mult .. '{} Mult and {C:chips}+' .. chips .. '{} Chips' },
        vars = function()
            local h = G.GAME and G.GAME.hands and G.GAME.hands[hand]
            local lvl = h and h.level or 1
            return { lvl, colours = { lvl == 1 and G.C.UI.TEXT_DARK or G.C.HAND_LEVELS[math.min(7, lvl)] } }
        end,
        effect = function(card)
            if SMODS.smart_level_up_hand then
                SMODS.smart_level_up_hand(card, hand, nil, 1)
            else
                level_up_hand(card, hand, nil, 1)
            end
        end,
    }
end

-- hand, +mult, +chips per level (matches vanilla planet values)
location('hedge_maze', 'Hedge Maze', 'CORE_REV_333', 'High Card', 1, 10)
location('castle_kennels', 'Castle Kennels', 'CORE_REV_362', 'Pair', 1, 15)
location('great_hall', 'Great Hall', 'CORE_REV_983', 'Two Pair', 1, 20)
location('sinstone_graveyard', 'Sinstone Graveyard', 'CORE_REV_750', 'Three of a Kind', 2, 20)
location('hiking_trail', 'Hiking Trail', 'VAC_517', 'Straight', 3, 30)
location('tide_pools', 'Tide Pools', 'VAC_522', 'Flush', 2, 15)
location('cathedral_of_atonement', 'Cathedral of Atonement', 'CORE_REV_290', 'Full House', 2, 25)
location('forge_of_wills', 'Forge of Wills', 'TTN_465', 'Four of a Kind', 3, 30)
location('prison_of_yogg_saron', 'Prison of Yogg-Saron', 'TTN_090', 'Straight Flush', 4, 40)
location('amirdrassil', 'Amirdrassil', 'FIR_907', 'Five of a Kind', 3, 35)
location('spire_of_solitude', 'Spire of Solitude', 'JAIL_511', 'Flush House', 4, 40)
location('the_eternal_hold', 'The Eternal Hold', 'TIME_446', 'Flush Five', 3, 50)
