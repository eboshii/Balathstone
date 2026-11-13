-- Balathstone Card Backs (Hearthstone Card Backs replacing Balatro Decks)
local HS = Balathstone or Balearthstone

local DECKS = {
    { key = 'b_red', id = 'red', name = 'Molten Core', pos = { x = 0, y = 0 } },
    { key = 'b_blue', id = 'blue', name = 'Icecrown', pos = { x = 1, y = 0 } },
    { key = 'b_yellow', id = 'yellow', name = 'Golden Celebration', pos = { x = 2, y = 0 } },
    { key = 'b_green', id = 'green', name = 'Naxxramas', pos = { x = 3, y = 0 } },
    { key = 'b_black', id = 'black', name = 'Black Temple', pos = { x = 0, y = 1 } },
    { key = 'b_magic', id = 'magic', name = 'Dalaran Flame', pos = { x = 1, y = 1 } },
    { key = 'b_nebula', id = 'nebula', name = 'Legacy of the Void', pos = { x = 2, y = 1 } },
    { key = 'b_ghost', id = 'ghost', name = 'Heroic Naxxramas', pos = { x = 3, y = 1 } },
    { key = 'b_abandoned', id = 'abandoned', name = 'Shadowmoon Valley', pos = { x = 0, y = 2 } },
    { key = 'b_checkered', id = 'checkered', name = 'Ninjas!', pos = { x = 1, y = 2 } },
    { key = 'b_zodiac', id = 'zodiac', name = 'Lunar New Year', pos = { x = 2, y = 2 } },
    { key = 'b_painted', id = 'painted', name = 'Rainbow!', pos = { x = 3, y = 2 } },
    { key = 'b_anaglyph', id = 'anaglyph', name = 'Overwatch', pos = { x = 0, y = 3 } },
    { key = 'b_plasma', id = 'plasma', name = 'Clutch of Yogg-Saron', pos = { x = 1, y = 3 } },
    { key = 'b_erratic', id = 'erratic', name = 'Hogger', pos = { x = 2, y = 3 } },
    { key = 'b_challenge', id = 'challenge', name = 'Classic', pos = { x = 3, y = 3 } },
}

HS.DECKS = DECKS

function HS.apply_deck_skins()
    for _, d in ipairs(DECKS) do
        if G.P_CENTERS and G.P_CENTERS[d.key] then
            G.P_CENTERS[d.key].atlas = 'hs_decks'
            G.P_CENTERS[d.key].pos = d.pos
        end
        if SMODS and SMODS.Back and SMODS.Back.take_ownership then
            pcall(function()
                SMODS.Back:take_ownership(d.id, {
                    atlas = 'hs_decks',
                    pos = d.pos,
                })
            end)
        end
    end
end

HS.apply_deck_skins()

-- Hook Back:set_sprites to ensure custom Hearthstone deck texture is always used
if Back and Back.set_sprites then
    local orig_back_set_sprites = Back.set_sprites
    function Back:set_sprites()
        orig_back_set_sprites(self)
        if self.effect and self.effect.center and self.effect.center.atlas == 'hs_decks' then
            self.atlas = 'hs_decks'
            self.pos = self.effect.center.pos
        end
    end
end

-- Hook Card:set_sprites to guarantee playing cards use the Hearthstone deck back
if Card and Card.set_sprites then
    local orig_card_set_sprites = Card.set_sprites
    function Card:set_sprites(_center, _front)
        orig_card_set_sprites(self, _center, _front)
        if self.children and self.children.back and G.GAME and (G.GAME.selected_back or G.GAME.viewed_back) then
            local b = G.GAME.viewed_back or G.GAME.selected_back
            local center = b and b.effect and b.effect.center
            if center and center.atlas == 'hs_decks' and G.ASSET_ATLAS and G.ASSET_ATLAS['hs_decks'] then
                self.children.back.atlas = G.ASSET_ATLAS['hs_decks']
                self.children.back.scale = { x = self.children.back.atlas.px, y = self.children.back.atlas.py }
                self.children.back:set_sprite_pos(self.params.bypass_back or center.pos)
            end
        end
    end
end

return { apply_deck_skins = HS.apply_deck_skins }
