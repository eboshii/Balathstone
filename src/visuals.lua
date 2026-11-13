-- Balathstone board visuals
-- Hearthstone-style effects drawn over minions that are IN PLAY (your Minion
-- slots). Shop / collection / pack cards are left clean, like Hearthstone only
-- shows these on the board. Everything is drawn procedurally in card-local
-- coordinates (0..w, 0..h) so it scales with the card.
local HS = Balathstone or Balearthstone
local E = HS.E

local TRIGGER_HOOKS = { 'on_spell', 'on_summon', 'on_damaged', 'on_any_damaged', 'on_death', 'on_heal',
    'end_turn', 'start_turn', 'on_play', 'on_tag', 'on_survive', 'after_attack', 'end_round', 'spellburst' }

local function has_trigger(d)
    for _, k in ipairs(TRIGGER_HOOKS) do if d[k] then return true end end
    return false
end

local lg
local function rrect(mode, x, y, w, h, r) lg.rectangle(mode, x, y, w, h, r, r, 16) end

-- ------------------------------------------------------------------ effects
local function draw_stealth(w, h, t)
    lg.setColor(0.08, 0.06, 0.14, 0.42)
    rrect('fill', 0, 0, w, h, w * 0.06)
    for i = 0, 4 do
        local y = (h * (i / 5 + 0.08 * math.sin(t * 0.7 + i * 1.7))) % h
        lg.setColor(0.35, 0.3, 0.45, 0.16)
        lg.ellipse('fill', w * (0.5 + 0.18 * math.sin(t * 0.5 + i)), y, w * 0.55, h * 0.06)
    end
end

local function draw_tint(w, h, t, r, g, b, base, amp, speed)
    local a = base + amp * (0.5 + 0.5 * math.sin(t * (speed or 3)))
    lg.setColor(r, g, b, a)
    rrect('fill', 0, 0, w, h, w * 0.06)
end

local function draw_taunt(w, h)
    local pad, r = w * 0.035, w * 0.09
    lg.setLineWidth(w * 0.065)
    lg.setColor(0.36, 0.33, 0.28, 0.95)
    rrect('line', -pad, -pad, w + 2 * pad, h + 2 * pad, r)
    lg.setLineWidth(w * 0.022)
    lg.setColor(0.72, 0.66, 0.55, 0.95)
    rrect('line', -pad, -pad, w + 2 * pad, h + 2 * pad, r)
    -- shield crest at the top
    local cx, cy, s = w / 2, -pad, w * 0.13
    local pts = { cx - s, cy - s * 0.55, cx + s, cy - s * 0.55, cx + s * 0.9, cy + s * 0.45, cx, cy + s * 1.05,
        cx - s * 0.9, cy + s * 0.45 }
    lg.setColor(0.42, 0.38, 0.32, 1)
    lg.polygon('fill', pts)
    lg.setLineWidth(w * 0.015)
    lg.setColor(0.8, 0.73, 0.6, 1)
    lg.polygon('line', pts)
end

local function draw_divine_shield(w, h, t)
    local p = 0.5 + 0.5 * math.sin(t * 2.6)
    local pad = w * 0.06
    lg.setColor(1, 0.86, 0.35, 0.13 + 0.07 * p)
    rrect('fill', -pad, -pad, w + 2 * pad, h + 2 * pad, w * 0.14)
    lg.setLineWidth(w * 0.028)
    lg.setColor(1, 0.92, 0.5, 0.65 + 0.3 * p)
    rrect('line', -pad, -pad, w + 2 * pad, h + 2 * pad, w * 0.14)
    -- moving highlight
    local hx = -pad + (w + 2 * pad) * ((t * 0.35) % 1)
    lg.setColor(1, 1, 0.85, 0.25)
    lg.ellipse('fill', hx, h * 0.15, w * 0.05, h * 0.08)
end

local function draw_windfury(w, h, t)
    local cx, cy = w / 2, h * 0.45
    lg.setLineWidth(w * 0.03)
    for i = 0, 2 do
        local a = t * 2.4 + i * (2 * math.pi / 3)
        lg.setColor(0.85, 0.97, 1, 0.75)
        lg.arc('line', 'open', cx, cy, w * 0.62, a, a + 0.9, 12)
        lg.setColor(0.85, 0.97, 1, 0.35)
        lg.arc('line', 'open', cx, cy, w * 0.5, -a, -a + 0.6, 10)
    end
end

local function draw_ready(w, h, t)
    local p = 0.5 + 0.5 * math.sin(t * 4)
    lg.setLineWidth(w * 0.035)
    lg.setColor(0.25, 1, 0.3, 0.55 + 0.4 * p)
    rrect('line', -w * 0.02, -w * 0.02, w * 1.04, h + w * 0.04, w * 0.08)
end

local function draw_skull(x, y, s)
    lg.setColor(0.12, 0.1, 0.1, 0.9)
    lg.circle('fill', x, y, s * 1.25)
    lg.setColor(0.92, 0.88, 0.8, 1)
    lg.circle('fill', x, y - s * 0.12, s * 0.75)
    lg.rectangle('fill', x - s * 0.42, y + s * 0.3, s * 0.84, s * 0.45)
    lg.setColor(0.12, 0.1, 0.1, 1)
    lg.circle('fill', x - s * 0.28, y - s * 0.12, s * 0.2)
    lg.circle('fill', x + s * 0.28, y - s * 0.12, s * 0.2)
    lg.rectangle('fill', x - s * 0.05, y + s * 0.32, s * 0.1, s * 0.4)
end

local function draw_bolt(x, y, s)
    lg.setColor(0.12, 0.1, 0.1, 0.9)
    lg.circle('fill', x, y, s * 1.25)
    lg.setColor(1, 0.83, 0.2, 1)
    lg.polygon('fill', x + s * 0.15, y - s * 0.9, x - s * 0.5, y + s * 0.15, x - s * 0.02, y + s * 0.12,
        x - s * 0.18, y + s * 0.9, x + s * 0.5, y - s * 0.18, x + s * 0.03, y - s * 0.14)
end

local function draw_frozen_minion(w, h, t)
    local pulse = 0.5 + 0.5 * math.sin(t * 2.8)
    lg.setColor(0.22, 0.68, 1.0, 0.35 + 0.1 * pulse)
    rrect('fill', 0, 0, w, h, w * 0.06)

    -- Bottom ice shards
    local shards = {
        { 0.14, 0.98, 0.16, 0.32 },
        { 0.36, 0.98, 0.18, 0.44 },
        { 0.58, 0.98, 0.20, 0.46 },
        { 0.78, 0.98, 0.16, 0.34 },
    }
    for _, s in ipairs(shards) do
        local bx = s[1] * w
        local by = s[2] * h
        local sw = s[3] * w
        local sh = s[4] * h
        lg.setColor(0.15, 0.46, 0.82, 0.88)
        lg.polygon('fill', bx - sw * 0.5, by, bx, by - sh, bx, by)
        lg.setColor(0.78, 0.94, 1.0, 0.92)
        lg.polygon('fill', bx, by, bx, by - sh, bx + sw * 0.5, by)
        lg.setLineWidth(w * 0.015)
        lg.setColor(0.9, 0.98, 1.0, 0.95)
        lg.polygon('line', bx - sw * 0.5, by, bx, by - sh, bx + sw * 0.5, by)
    end

    -- Ice cracks across minion
    lg.setLineWidth(w * 0.02)
    lg.setColor(0.85, 0.96, 1.0, 0.85)
    lg.line(w * 0.12, h * 0.28, w * 0.42, h * 0.48, w * 0.68, h * 0.38, w * 0.88, h * 0.65)
    lg.line(w * 0.42, h * 0.48, w * 0.46, h * 0.78)

    -- Frost border
    lg.setLineWidth(w * 0.03)
    lg.setColor(0.65, 0.9, 1.0, 0.7 + 0.2 * pulse)
    rrect('line', 0, 0, w, h, w * 0.06)
end

-- Telegraph: the Boss's next target (crosshair + incoming damage; skull if lethal)
local function predicted_targets()
    local now = (G.TIMERS and G.TIMERS.REAL) or 0
    if HS._pred_time ~= now then
        HS._pred_time = now
        local selecting = not (G.STATES and G.STATE) or G.STATE == G.STATES.SELECTING_HAND
        HS._pred = (HS.in_round() and selecting and HS.predict_boss_targets) and HS.predict_boss_targets() or {}
    end
    return HS._pred or {}
end

local function outlined(text, x, y, size, col)
    local font = HS.load_font and HS.load_font()
    if not font then return end
    lg.setFont(font)
    local s = size / (HS.BELWE_DIGIT_H64 or 43)
    local ox, oy = font:getWidth(text) / 2, font:getHeight() / 2
    lg.setColor(0, 0, 0, col[4] or 1)
    for a = 0, 7 do
        local ang = a * math.pi / 4
        lg.print(text, x + math.cos(ang) * size * 0.1, y + math.sin(ang) * size * 0.1, 0, s, s, ox, oy)
    end
    lg.setColor(col)
    lg.print(text, x, y, 0, s, s, ox, oy)
end

local function draw_reticle(card, w, h, t, kind)
    local atk = HS.boss_attack_value()
    local center = HS.enemy()
    local e = E(card)
    local lethal = not e.shield and (HS.health(card) <= atk
        or (center and center.hs_poison and HS.enemy_quirks() and atk > 0))
    local cx, cy = w / 2, h * 0.33
    local p = 0.5 + 0.5 * math.sin(t * 5)
    local sure = kind == 'sure'
    local a = sure and (0.75 + 0.25 * p) or 0.45
    local r = w * 0.3
    lg.setLineWidth(w * (sure and 0.035 or 0.02))
    lg.setColor(0.95, 0.15, 0.1, a)
    lg.circle('line', cx, cy, r)
    lg.line(cx - r * 1.3, cy, cx - r * 0.55, cy)
    lg.line(cx + r * 0.55, cy, cx + r * 1.3, cy)
    lg.line(cx, cy - r * 1.3, cx, cy - r * 0.55)
    lg.line(cx, cy + r * 0.55, cx, cy + r * 1.3)
    local label = sure and ('-' .. atk) or ('?-' .. atk)
    outlined(label, cx, cy, w * 0.16, { 1, 0.3, 0.25, sure and 1 or 0.7 })
    if lethal and sure then draw_skull(cx + r * 1.05, cy - r * 1.05, w * 0.07) end
end

-- ------------------------------------------------------------------ main
local function effects_body(card, e, d)
    local t = (G.TIMERS and G.TIMERS.REAL) or 0
    local w, h = card.T.w, card.T.h

    if HS.has(card, 'stealth') and not e.stealth_broken then draw_stealth(w, h, t) end
    if HS.has(card, 'reborn') then draw_tint(w, h, t, 0.45, 1, 0.75, 0.08, 0.1, 2) end
    if d.enrage and HS.is_damaged(card) then draw_tint(w, h, t, 1, 0.12, 0.05, 0.08, 0.12, 5) end
    if HS.has(card, 'taunt') then draw_taunt(w, h) end
    if e.shield then draw_divine_shield(w, h, t) end
    if HS.has(card, 'windfury') then draw_windfury(w, h, t) end
    if HS.has(card, 'mega_windfury') then draw_windfury(w, h * 0.8, -t * 1.6) end -- a second, counter-spinning whirl
    -- Temporary summons shimmer (they leave at the end of the round); Doomed minions pulse red
    if e.temporary then
        draw_tint(w, h, t, 0.65, 0.88, 1, 0.08, 0.1, 1.5)
        lg.setLineWidth(w * 0.02)
        lg.setColor(0.75, 0.92, 1, 0.5 + 0.3 * math.sin(t * 2))
        rrect('line', 0, 0, w, h, w * 0.06)
    end
    if e.doomed then draw_tint(w, h, t, 1, 0.1, 0.05, 0.06, 0.16, 7) end
    if e.frozen then draw_frozen_minion(w, h, t) end
    if e.silenced then draw_tint(w, h, t, 0.25, 0.25, 0.28, 0.45, 0.05, 1) end -- Silenced this round
    local st = G.GAME and G.GAME.hs
    if HS.in_round() and st and st.hand_index == 0 and (HS.has(card, 'charge') or HS.has(card, 'rush')) then
        draw_ready(w, h, t)
    end

    -- Deathrattle (skull) / trigger (lightning) icons under the portrait
    local icons = {}
    if d.deathrattle or e.ancestral then icons[#icons + 1] = draw_skull end
    if has_trigger(d) then icons[#icons + 1] = draw_bolt end
    local s = w * 0.055
    for i, fn in ipairs(icons) do
        local x = w / 2 + (i - (#icons + 1) / 2) * s * 2.8
        fn(x, h * 0.505, s)
    end

    -- the Boss's next target
    local kind = predicted_targets()[card]
    if kind then draw_reticle(card, w, h, t, kind) end
end

-- prep_draw pushes a transform; always pop it, even if drawing fails
function HS.draw_board_effects(card)
    local e = E(card)
    local d = HS.def(card)
    if not (e and d) then return end
    lg = love.graphics
    prep_draw(card, 1)
    local lw = lg.getLineWidth()
    local ok, err = pcall(effects_body, card, e, d)
    lg.setLineWidth(lw)
    lg.setColor(1, 1, 1, 1)
    lg.pop()
    if not ok then error(err, 0) end
end

-- Draw authentic Hearthstone circular Frozen effect over Boss/Blind token
function HS.draw_blind_frozen(blind)
    local sprite = blind and blind.children and blind.children.animatedSprite
    if not sprite or not love or not love.graphics then return end
    local lg = love.graphics
    local t = (G.TIMERS and G.TIMERS.REAL) or 0
    prep_draw(sprite, 1)
    local w, h = sprite.VT.w, sprite.VT.h
    local cx, cy = w / 2, h / 2
    local r = w * 0.46

    -- 1. Icy Cyan Frost Tint over the circular token
    local pulse = 0.5 + 0.5 * math.sin(t * 2.8)
    lg.setColor(0.22, 0.68, 1.0, 0.38 + 0.12 * pulse)
    lg.circle('fill', cx, cy, r)

    -- 2. Jagged Ice Crystals / Stalagmites along the bottom rim
    local shards = {
        { -0.34, 0.28, 0.14, 0.42 },
        { -0.21, 0.35, 0.13, 0.50 },
        { -0.07, 0.38, 0.16, 0.56 },
        {  0.08, 0.36, 0.14, 0.52 },
        {  0.22, 0.32, 0.14, 0.45 },
        {  0.33, 0.25, 0.12, 0.38 },
    }
    for _, s in ipairs(shards) do
        local bx = cx + s[1] * w
        local by = cy + s[2] * h
        local sw = s[3] * w
        local sh = s[4] * h
        -- Left / dark facet
        lg.setColor(0.12, 0.44, 0.8, 0.88)
        lg.polygon('fill', bx - sw * 0.5, by, bx, by - sh, bx, by)
        -- Right / light facet
        lg.setColor(0.76, 0.93, 1.0, 0.92)
        lg.polygon('fill', bx, by, bx, by - sh, bx + sw * 0.5, by)
        -- Shard outline
        lg.setLineWidth(w * 0.015)
        lg.setColor(0.9, 0.98, 1.0, 0.95)
        lg.polygon('line', bx - sw * 0.5, by, bx, by - sh, bx + sw * 0.5, by)
    end

    -- 3. Sharp Ice Cracks across the portrait with cyan glow
    lg.setLineWidth(w * 0.035)
    lg.setColor(0.3, 0.8, 1.0, 0.4)
    lg.line(cx - r * 0.6, cy - r * 0.2, cx - r * 0.2, cy + r * 0.1, cx + r * 0.1, cy - r * 0.15, cx + r * 0.65, cy + r * 0.1)
    lg.line(cx - r * 0.2, cy + r * 0.1, cx - r * 0.1, cy + r * 0.5)
    lg.line(cx + r * 0.1, cy - r * 0.15, cx + r * 0.3, cy - r * 0.55)

    lg.setLineWidth(w * 0.02)
    lg.setColor(0.85, 0.96, 1.0, 0.85)
    lg.line(cx - r * 0.6, cy - r * 0.2, cx - r * 0.2, cy + r * 0.1, cx + r * 0.1, cy - r * 0.15, cx + r * 0.65, cy + r * 0.1)
    lg.line(cx - r * 0.2, cy + r * 0.1, cx - r * 0.1, cy + r * 0.5)
    lg.line(cx + r * 0.1, cy - r * 0.15, cx + r * 0.3, cy - r * 0.55)

    -- 4. Outer Frost Ring
    lg.setLineWidth(w * 0.035)
    lg.setColor(0.65, 0.9, 1.0, 0.75 + 0.2 * pulse)
    lg.circle('line', cx, cy, r)

    -- 5. Shimmer Sparkles
    for i = 1, 4 do
        local a = t * 1.5 + i * 1.57
        local sx = cx + math.cos(a) * r * 0.45
        local sy = cy + math.sin(a * 1.3) * r * 0.45
        local sp = 0.5 + 0.5 * math.sin(t * 5 + i * 2)
        lg.setColor(1, 1, 1, 0.7 * sp)
        lg.circle('fill', sx, sy, w * 0.02 * sp)
    end

    lg.setColor(1, 1, 1, 1)
    lg.pop()
end

-- The Blind's live state drawn on its portrait, so its abilities are visible:
-- Attack (yellow gem), summoned army (red counter), Stealth (smoke),
-- Divine Shield (gold ring) and an unused Reborn (green ring).
local function blind_badge(x, y, r, fill, text)
    local lg = love.graphics
    lg.setColor(0.08, 0.06, 0.05, 1)
    lg.circle('fill', x, y, r * 1.15)
    lg.setColor(fill)
    lg.circle('fill', x, y, r)
    local font = HS.load_font and HS.load_font()
    if not font then return end
    lg.setFont(font)
    local s = (r * 1.25) / (HS.BELWE_DIGIT_H64 or 43)
    local ox, oy = font:getWidth(text) / 2, font:getHeight() / 2
    local ow = r * 0.12
    lg.setColor(0, 0, 0, 1)
    for a = 0, 7 do
        local ang = a * math.pi / 4
        lg.print(text, x + math.cos(ang) * ow, y + math.sin(ang) * ow, 0, s, s, ox, oy)
    end
    lg.setColor(1, 1, 1, 1)
    lg.print(text, x, y, 0, s, s, ox, oy)
end

function HS.draw_blind_status(blind)
    local sprite = blind and blind.children and blind.children.animatedSprite
    local bc = HS.enemy()
    if not (sprite and bc and love and love.graphics) then return end
    local lg = love.graphics
    local st = HS.state()
    local quirks = HS.enemy_quirks()
    local t = (G.TIMERS and G.TIMERS.REAL) or 0
    prep_draw(sprite, 1)
    local ok, err = pcall(function()
        local w, h = sprite.VT.w, sprite.VT.h
        local cx, cy, r = w / 2, h / 2, w * 0.46
        -- Stealth: dark drifting smoke until it has attacked
        if quirks and bc.hs_stealth and not st.boss_has_attacked then
            lg.setColor(0.07, 0.05, 0.12, 0.55)
            lg.circle('fill', cx, cy, r)
            for i = 0, 3 do
                local y = cy + r * 0.7 * math.sin(t * 0.8 + i * 1.6)
                lg.setColor(0.4, 0.34, 0.5, 0.22)
                lg.ellipse('fill', cx + r * 0.25 * math.sin(t * 0.6 + i), y, r * 0.75, r * 0.16)
            end
        end
        -- Divine Shield: pulsing gold ring
        if quirks and st.blind_shield then
            local p = 0.5 + 0.5 * math.sin(t * 2.6)
            lg.setLineWidth(w * 0.07)
            lg.setColor(1, 0.86, 0.35, 0.65 + 0.3 * p)
            lg.circle('line', cx, cy, r * 1.04)
        end
        -- Reborn still to come: green ring
        if quirks and bc.hs_reborn and not st.blind_reborn then
            lg.setLineWidth(w * 0.04)
            lg.setColor(0.45, 1, 0.6, 0.55 + 0.25 * math.sin(t * 2))
            lg.circle('line', cx, cy, r * 0.92)
        end
        -- Attack (bottom left) and summoned army (bottom right)
        local br = w * 0.17
        blind_badge(cx - r * 0.78, cy + r * 0.78, br, { 0.9, 0.68, 0.12, 1 }, tostring(HS.boss_attack_value()))
        local army = st.enemy_army and #st.enemy_army or 0
        if army > 0 then
            blind_badge(cx + r * 0.78, cy + r * 0.78, br, { 0.75, 0.12, 0.12, 1 }, 'x' .. army)
        end
    end)
    lg.setLineWidth(1)
    lg.setColor(1, 1, 1, 1)
    lg.pop()
    if not ok then error(err, 0) end
end

-- Hook Blind:draw: live status on the current Blind, and the Frozen effect
if Blind and Blind.draw then
    local orig_blind_draw = Blind.draw
    function Blind:draw(...)
        orig_blind_draw(self, ...)
        if not (self.children and self.children.animatedSprite) then return end
        if self == (G.GAME and G.GAME.blind) and HS.in_round() then
            local ok, err = pcall(HS.draw_blind_status, self)
            if not ok and not HS.blind_status_error_logged then
                HS.blind_status_error_logged = true
                print('Balathstone blind status error: ' .. tostring(err))
            end
        end
        local st = G.GAME and G.GAME.hs
        if st and st.boss_frozen then
            pcall(HS.draw_blind_frozen, self)
        end
    end
end

-- Draw dramatic attack targeting reticle, slash impact, and sparks on attacked minions
function HS.draw_attack_fx(card)
    local anim = card.hs_attack_anim
    if not anim or not love or not love.graphics then return end
    local lg = love.graphics
    local now = (G.TIMERS and G.TIMERS.REAL) or 0
    local progress = (now - anim.start_time) / (anim.duration or 0.7)
    if progress < 0 then progress = 0 end
    if progress >= 1 then
        card.hs_attack_anim = nil
        return
    end

    prep_draw(card, 1)
    local w, h = card.T.w, card.T.h
    local cx, cy = w / 2, h / 2
    local fade = 1 - progress

    -- 1. Red Damage Flash tint over card
    lg.setColor(1, 0.06, 0.06, 0.35 * fade)
    rrect('fill', 0, 0, w, h, w * 0.06)

    -- 2. Incoming Attack Streak from the direction of the Boss
    if G.GAME and G.GAME.blind and G.GAME.blind.T and card.T then
        local bx = (G.GAME.blind.T.x + (G.GAME.blind.T.w or 0) / 2) - (card.T.x + w / 2)
        local by = (G.GAME.blind.T.y + (G.GAME.blind.T.h or 0) / 2) - (card.T.y + h / 2)
        local angle = math.atan2(by, bx)
        local trail_len = w * 1.1 * (1 - progress * 0.7)
        lg.setLineWidth(w * 0.08 * fade)
        lg.setColor(1, 0.2, 0.1, 0.85 * fade)
        lg.line(cx + math.cos(angle) * trail_len, cy + math.sin(angle) * trail_len, cx, cy)
        lg.setLineWidth(w * 0.03 * fade)
        lg.setColor(1, 0.9, 0.4, 0.95 * fade)
        lg.line(cx + math.cos(angle) * trail_len * 0.7, cy + math.sin(angle) * trail_len * 0.7, cx, cy)
    end

    -- 3. Targeting Crosshair / Reticle (prominent during first half)
    if progress < 0.75 then
        local r_fade = 1 - (progress / 0.75)
        local rad = w * 0.38 * (1 + 0.1 * math.sin(progress * 16))
        lg.setLineWidth(w * 0.035)
        lg.setColor(1, 0.12, 0.12, 0.95 * r_fade)
        lg.circle('line', cx, cy, rad)
        -- Crosshair ticks
        local tick = w * 0.09
        lg.line(cx - rad - tick, cy, cx - rad + tick * 0.3, cy)
        lg.line(cx + rad - tick * 0.3, cy, cx + rad + tick, cy)
        lg.line(cx, cy - rad - tick, cx, cy - rad + tick * 0.3)
        lg.line(cx, cy + rad - tick * 0.3, cx, cy + rad + tick)
        lg.circle('fill', cx, cy, w * 0.035)
    end

    -- 4. Double 'X' Slash Impact Marks
    -- Primary slash
    lg.setLineWidth(w * 0.095 * fade)
    lg.setColor(0.95, 0.08, 0.08, 0.95 * fade)
    lg.line(w * 0.12, h * 0.16, w * 0.88, h * 0.84)
    -- Primary hot molten core
    lg.setLineWidth(w * 0.035 * fade)
    lg.setColor(1, 0.85, 0.25, fade)
    lg.line(w * 0.16, h * 0.20, w * 0.84, h * 0.80)

    -- Secondary counter slash
    lg.setLineWidth(w * 0.075 * fade)
    lg.setColor(0.95, 0.1, 0.1, 0.85 * fade)
    lg.line(w * 0.84, h * 0.18, w * 0.16, h * 0.82)
    -- Secondary molten core
    lg.setLineWidth(w * 0.025 * fade)
    lg.setColor(1, 0.85, 0.25, 0.9 * fade)
    lg.line(w * 0.80, h * 0.22, w * 0.20, h * 0.78)

    -- 5. Expanding Shockwave Ring
    local ring_rad = w * (0.12 + 0.65 * progress)
    lg.setLineWidth(w * 0.04 * fade)
    lg.setColor(1, 0.35, 0.1, 0.85 * fade)
    lg.circle('line', cx, cy, ring_rad)

    -- 6. Flying Hit Sparks
    for i = 0, 7 do
        local a = i * (math.pi / 4) + 0.25
        local dist = w * (0.2 + 0.5 * progress)
        local sx = cx + math.cos(a) * dist
        local sy = cy + math.sin(a) * dist
        lg.setColor(1, 0.88, 0.3, fade)
        lg.circle('fill', sx, sy, w * 0.035 * fade)
    end

    lg.setColor(1, 1, 1, 1)
    lg.pop()
end

if SMODS and SMODS.DrawStep then
    SMODS.DrawStep {
        key = 'hs_board_effects',
        order = 47, -- just under the stat badges (48)
        conditions = { vortex = false, facing = 'front' },
        func = function(card, layer)
            if G.jokers and card.area == G.jokers and HS.is_minion(card) and not card.removed then
                local ok, err = pcall(HS.draw_board_effects, card)
                if not ok then
                    if not HS.visual_error_logged then
                        HS.visual_error_logged = true
                        print('Balathstone visuals error: ' .. tostring(err))
                    end
                end
            end
        end
    }

    SMODS.DrawStep {
        key = 'hs_attack_fx',
        order = 96, -- above cards, borders, and badges
        conditions = { vortex = false, facing = 'front' },
        func = function(card, layer)
            if card.hs_attack_anim then
                local ok, err = pcall(HS.draw_attack_fx, card)
                if not ok and not HS.attack_fx_error_logged then
                    HS.attack_fx_error_logged = true
                    print('Balathstone attack fx error: ' .. tostring(err))
                end
            end
        end
    }
end
