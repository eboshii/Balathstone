-- Balathstone Complete UI Localization (Hearthstone Theming)
return {
    descriptions = {
        Back = {
            b_red = { name = "Molten Core Deck", text = { "{C:red}+#1#{} discard", "every round" } },
            b_blue = { name = "Icecrown Deck", text = { "{C:blue}+#1#{} hand", "every round" } },
            b_yellow = { name = "Golden Celebration Deck", text = { "Start with an", "extra {C:money}$#1#{}" } },
            b_green = { name = "Naxxramas Deck", text = { "At end of each Round:", "{C:money}$#1#{} per remaining {C:blue}Hand{}", "{C:money}$#2#{} per remaining {C:red}Discard{}", "Earn no {C:attention}Interest{}" } },
            b_black = { name = "Black Temple Deck", text = { "{C:attention}+#1#{} Minion slot", "", "{C:blue}#2#{} hand", "every round" } },
            b_magic = { name = "Dalaran Deck", text = { "Start run with the", "{C:tarot,T:v_crystal_ball}#1#{} Voucher", "and {C:attention}2{} copies", "of {C:tarot,T:c_fool}#2#{}" } },
            b_nebula = { name = "Void Deck", text = { "Start run with the", "{C:planet,T:v_telescope}#1#{} Voucher", "", "{C:red}#2#{} consumable slot" } },
            b_ghost = { name = "Heroic Naxxramas Deck", text = { "{C:spectral}Forbidden Spells{} may", "appear in the shop,", "start with a {C:spectral,T:c_hex}#1#{} card" } },
            b_abandoned = { name = "Shadowmoon Deck", text = { "Start run with", "no {C:attention}Face Cards{}", "in your deck" } },
            b_checkered = { name = "Ninja Deck", text = { "Start run with", "{C:attention}26{C:spades} Spades{} and", "{C:attention}26{C:hearts} Hearts{} in deck" } },
            b_zodiac = { name = "Lunar Deck", text = { "Start run with", "{C:tarot,T:v_tarot_merchant}#1#{},", "{C:planet,T:v_planet_merchant}#2#{},", "and {C:attention,T:v_overstock_norm}#3#{}" } },
            b_painted = { name = "Rainbow Deck", text = { "{C:attention}+#1#{} hand size,", "{C:red}#2#{} Minion slot" } },
            b_anaglyph = { name = "Overwatch Deck", text = { "After defeating each", "{C:attention}Boss Blind{}, gain a", "random {C:attention}Secret{}" } },
            b_plasma = { name = "Yogg-Saron Deck", text = { "Balance {C:blue}Chips{} and", "{C:red}Mult{} when calculating", "score for played hand", "{C:red}X#1#{} base Blind size" } },
            b_erratic = { name = "Hogger Deck", text = { "All {C:attention}Ranks{} and", "{C:attention}Suits{} in deck", "are randomized" } },
        },
        Other = {
            hs_kw_stats = { name = "Minion", text = { "{C:mult}Attack{} scores as {C:mult}+Mult{},", "each {C:chips}Health{} scores {C:chips}+1 Chip{}.", "Every Blind attacks one minion", "each turn" } },
            hs_kw_discover = { name = "Discover", text = { "Choose 1 of 3 cards. In a", "round, you choose when", "the next Tavern opens" } },
            hs_kw_battlecry = { name = "Battlecry", text = { "Triggers at the {C:attention}start of", "{C:attention}every round{}, after your", "first hand is drawn" } },
            hs_kw_deathrattle = { name = "Deathrattle", text = { "Triggers when this minion", "{C:attention}dies{} or is {C:attention}sold{}" } },
            hs_kw_start_of_game = { name = "Start of Game", text = { "Triggers at the start of", "every round. Not doubled", "by Brann Bronzebeard" } },
            hs_kw_taunt = { name = "Taunt", text = { "Enemies must attack", "this minion first" } },
            hs_kw_divine_shield = { name = "Divine Shield", text = { "Blocks the first damage", "this minion takes", "{C:inactive}(restored every round){}" } },
            hs_kw_windfury = { name = "Windfury", text = { "This minion scores {C:attention}twice{}:", "its whole score repeats,", "{X:mult,C:white}X Mult{} included" } },
            hs_kw_mega_windfury = { name = "Mega-Windfury", text = { "This minion scores {C:attention}four{}", "times, {X:mult,C:white}X Mult{} included" } },
            hs_kw_charge = { name = "Charge", text = { "Attacks again (all its", "attacks) on the {C:attention}first turn{}", "of each round" } },
            hs_kw_rush = { name = "Rush", text = { "Attacks again without its", "Chips on the {C:attention}first turn{}", "of each round" } },
            hs_kw_lifesteal = { name = "Lifesteal", text = { "At the end of each round,", "restore Health to your hero", "equal to its Attack" } },
            hs_kw_stealth = { name = "Stealth", text = { "Enemies can't attack this", "minion until it has scored", "this round" } },
            hs_kw_reborn = { name = "Reborn", text = { "The first time this minion", "dies, it returns with", "{C:chips}1{} Health" } },
            hs_kw_enrage = { name = "Enrage", text = { "Active while this minion", "is damaged" } },
            hs_kw_spell_damage = { name = "Spell Damage", text = { "Your Spells deal extra", "damage to the Blind" } },
            hs_kw_combo = { name = "Combo", text = { "Active if you used a {C:attention}Spell{}", "or a {C:attention}Mulligan{} earlier", "this turn" } },
            hs_kw_overload = { name = "Overload", text = { "You have {C:red}N{} fewer", "Discards next round" } },
            hs_kw_spellburst = { name = "Spellburst", text = { "Triggers after the first", "Spell you cast each round" } },
            hs_kw_manathirst = { name = "Manathirst", text = { "Stronger once you have", "enough Mana {C:inactive}(Mana = Ante){}" } },
            hs_kw_infuse = { name = "Infuse", text = { "Upgrades after friendly", "minions die" } },
            hs_kw_adapt = { name = "Adapt", text = { "Gain a random bonus:", "+3 Attack, +3 Health, +1/+1,", "Divine Shield, Taunt,", "Windfury or Stealth" } },
            hs_kw_freeze = { name = "Freeze", text = { "A Frozen Blind skips its next", "attack. A Frozen minion", "doesn't score on its next turn" } },
            hs_kw_silence = { name = "Silence", text = { "A Silenced Blind loses its", "ability (it still attacks).", "A Silenced minion loses its", "text and doesn't score this round" } },
            hs_kw_secret = { name = "Secret", text = { "Earned by skipping a Blind.", "Stays hidden until its", "condition happens, then", "triggers {C:attention}once{}" } },
            hs_kw_armor = { name = "Armor", text = { "Gaining Armor gives you", "{C:money}$1{} per point" } },
            hs_kw_blind = { name = "The Blind", text = { "The Blind is the enemy hero.", "Each damage lowers its score", "requirement by {C:attention}2%{}. Damage", "outside a round hits the next Blind" } },
            hs_kw_hero = { name = "Your Hero", text = { "Your money is your hero's", "Health. Restoring Health", "gives {C:money}${}, never above {C:money}$30{}.", "Damage costs {C:money}${}" } },
            hs_kw_summon = { name = "Summon", text = { "Creates that exact minion", "in an empty Minion slot.", "Summoned minions sell for {C:money}$0{}" } },
            hs_kw_spell = { name = "Spell", text = { "Using a Spell or Forbidden", "Spell counts as casting", "a Spell" } },

            -- Minion (Buffoon) Packs
            p_buffoon_normal = {
                name = "Minion Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:joker} Minion{} cards",
                },
            },
            p_buffoon_jumbo = {
                name = "Jumbo Minion Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:joker} Minion{} cards",
                },
            },
            p_buffoon_mega = {
                name = "Mega Minion Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:joker} Minion{} cards",
                },
            },

            -- Spell (Arcana) Packs: used immediately or later
            p_arcana_normal = {
                name = "Spell Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:tarot} Spell{} cards to",
                    "be used immediately or later",
                },
            },
            p_arcana_jumbo = {
                name = "Jumbo Spell Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:tarot} Spell{} cards to",
                    "be used immediately or later",
                },
            },
            p_arcana_mega = {
                name = "Mega Spell Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:tarot} Spell{} cards to",
                    "be used immediately or later",
                },
            },

            -- Location (Celestial) Packs: used immediately or later
            p_celestial_normal = {
                name = "Location Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:planet} Location{} cards to",
                    "be used immediately or later",
                },
            },
            p_celestial_jumbo = {
                name = "Jumbo Location Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:planet} Location{} cards to",
                    "be used immediately or later",
                },
            },
            p_celestial_mega = {
                name = "Mega Location Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:planet} Location{} cards to",
                    "be used immediately or later",
                },
            },

            -- Forbidden Spell (Spectral) Packs: used immediately or later
            p_spectral_normal = {
                name = "Forbidden Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:spectral} Forbidden Spell{} cards to",
                    "be used immediately or later",
                },
            },
            p_spectral_jumbo = {
                name = "Jumbo Forbidden Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:spectral} Forbidden Spell{} cards to",
                    "be used immediately or later",
                },
            },
            p_spectral_mega = {
                name = "Mega Forbidden Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:spectral} Forbidden Spell{} cards to",
                    "be used immediately or later",
                },
            },

            -- Playing Card (Standard) Packs
            p_standard_normal = {
                name = "Card Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:attention} Playing{} cards to",
                    "add to your deck",
                },
            },
            p_standard_jumbo = {
                name = "Jumbo Card Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:attention} Playing{} cards to",
                    "add to your deck",
                },
            },
            p_standard_mega = {
                name = "Mega Card Pack",
                text = {
                    "Choose {C:attention}#1#{} of up to",
                    "{C:attention}#2#{C:attention} Playing{} cards to",
                    "add to your deck",
                },
            },
        },
        Tag = {
            tag_buffoon = {
                name = "Minion Secret",
                text = {
                    "Gives a free",
                    "{C:attention}Mega Minion Pack{}",
                },
            },
            tag_rare = {
                name = "Rare Minion Secret",
                text = {
                    "Tavern has a free",
                    "{C:red}Rare Minion{}",
                },
            },
            tag_uncommon = {
                name = "Uncommon Minion Secret",
                text = {
                    "Tavern has a free",
                    "{C:green}Uncommon Minion{}",
                },
            },
            tag_foil = {
                name = "Foil Secret",
                text = {
                    "Next base edition Tavern",
                    "Minion is free and",
                    "becomes {C:dark_edition}Foil{}",
                },
            },
            tag_holo = {
                name = "Holographic Secret",
                text = {
                    "Next base edition Tavern",
                    "Minion is free and",
                    "becomes {C:dark_edition}Holographic{}",
                },
            },
            tag_polychrome = {
                name = "Polychrome Secret",
                text = {
                    "Next base edition Tavern",
                    "Minion is free and",
                    "becomes {C:dark_edition}Polychrome{}",
                },
            },
            tag_negative = {
                name = "Negative Secret",
                text = {
                    "Next base edition Tavern",
                    "Minion is free and",
                    "becomes {C:dark_edition}Negative{}",
                },
            },
            tag_top_up = {
                name = "Top-up Secret",
                text = {
                    "Create up to {C:attention}#1#{}",
                    "{C:blue}Common{} Minions",
                    "{C:inactive}(Must have room){}",
                },
            },
            tag_charm = {
                name = "Spell Secret",
                text = {
                    "Gives a free",
                    "{C:tarot}Mega Spell Pack{}",
                },
            },
            tag_meteor = {
                name = "Location Secret",
                text = {
                    "Gives a free",
                    "{C:planet}Mega Location Pack{}",
                },
            },
            tag_ethereal = {
                name = "Forbidden Secret",
                text = {
                    "Gives a free",
                    "{C:spectral}Spectral Pack{}",
                },
            },
        },
        Stake = {
            stake_black = {
                name = "Black Stake",
                text = {
                    "The Tavern can have {C:attention}Eternal{} Minions",
                    "{C:inactive,s:0.8}(Can't be sold or destroyed){}",
                },
            },
            stake_orange = {
                name = "Orange Stake",
                text = {
                    "The Tavern can have {C:attention}Perishable{} Minions",
                    "{C:inactive,s:0.8}(Debuffed after 5 rounds){}",
                },
            },
            stake_gold = {
                name = "Gold Stake",
                text = {
                    "The Tavern can have {C:attention}Rental{} Minions",
                    "{C:inactive,s:0.8}(Costs {C:money}$3{C:inactive} per round){}",
                },
            },
        },
        Voucher = {
            v_antimatter = {
                name = "Antimatter",
                text = {
                    "{C:dark_edition}+1{} Minion Slot",
                },
            },
            v_omen_globe = {
                name = "Omen Globe",
                text = {
                    "{C:spectral}Forbidden Spells{} may",
                    "appear in any of",
                    "the {C:tarot}Spell Packs{}",
                },
            },
            v_telescope = {
                name = "Telescope",
                text = {
                    "{C:planet}Location Packs{} always",
                    "contain the {C:planet}Location{}",
                    "for your most",
                    "played {C:attention}poker hand{}",
                },
            },
            v_tarot_merchant = {
                name = "Spell Merchant",
                text = {
                    "{C:tarot}Spells{} appear",
                    "{C:attention}#1#X{} more frequently",
                    "in the Tavern",
                },
            },
            v_planet_merchant = {
                name = "Location Merchant",
                text = {
                    "{C:planet}Locations{} appear",
                    "{C:attention}#1#X{} more frequently",
                    "in the Tavern",
                },
            },
            v_tarot_tycoon = {
                name = "Spell Tycoon",
                text = {
                    "{C:tarot}Spells{} appear",
                    "{C:attention}#1#X{} more frequently",
                    "in the Tavern",
                },
            },
            v_planet_tycoon = {
                name = "Location Tycoon",
                text = {
                    "{C:planet}Locations{} appear",
                    "{C:attention}#1#X{} more frequently",
                    "in the Tavern",
                },
            },
        },
    },
    misc = {
        dictionary = {
            -- Jokers -> Minions
            b_jokers = "Minions",
            b_stat_jokers = "Minions",
            k_jokers_cap = "MINIONS",
            k_joker = "Minion",
            k_jokers = "Minions",
            k_joker_stickers = "Minion Stickers",
            k_no_other_jokers = "No other Minions!",
            k_plus_joker = "+1 Minion",
            ph_stat_joker = "Total completed rounds with this minion",
            ph_stat_jokers = "Total completed rounds with these minions",
            k_buffoon_pack = "Minion Pack",
            ml_joker_opt = "Minions",
            ml_joker_undiscovered = "Undiscovered Minion",
            ml_all_jokers = "All Minions",
            k_view_jokers = "View Minions",
            ph_click_to_view_jokers = "Click to view Minions",
            joker_stencil = "Minion slot",

            -- Consumables -> Spells & Locations
            k_cap_consumables = "SPELLS & LOCATIONS",
            b_stat_consumables = "Spells & Locations",

            -- Tarot -> Spells
            b_tarot_cards = "Spells",
            b_stat_tarots = "Spells",
            k_tarot = "Spell",
            k_plus_tarot = "+1 Spell",
            k_arcana_pack = "Spell Pack",

            -- Planets -> Locations
            b_planet_cards = "Locations",
            b_stat_planets = "Locations",
            k_planet = "Location",
            k_planet_q = "Location?",
            k_dwarf_planet = "Landmark",
            k_plus_planet = "+1 Location",
            k_celestial_pack = "Location Pack",

            -- Spectrals -> Quests & Artifacts
            b_spectral_cards = "Forbidden Spells",
            b_stat_spectrals = "Forbidden Spells",
            k_spectral = "Forbidden Spell",
            k_plus_spectral = "+1 Forbidden Spell",
            k_spectral_pack = "Forbidden Pack",

            -- Vouchers -> Adventure Treasures
            b_vouchers = "Adventure Treasures",
            b_stat_vouchers = "Adventure Treasures",
            k_voucher = "Treasure",
            k_vouchers_cap = "TREASURES",
            ph_vouchers_redeemed = "Treasures collected this run",
            ph_no_vouchers = "No treasures collected this run",
            ph_stat_voucher = "Number of times this Treasure has been found",

            -- Blinds -> Encounters & Bosses
            b_blinds = "Encounters & Bosses",
            b_skip_blind = "Skip Encounter",
            ph_choose_blind_1 = "Choose your",
            ph_choose_blind_2 = "next Encounter",
            ph_defeat_this_blind_1 = "Defeat this encounter",
            ph_defeat_this_blind_2 = "to discover it",
            ph_defeat_the_boss = "Defeat the Legendary Boss",
            ph_up_ante_2 = "Raise all Encounters",
            ph_up_ante_3 = "Refresh Encounters",
            b_reroll_boss = "Reroll Legendary Boss",
            ph_boss_disabled = "Legendary Boss Silenced!",
            ph_no_boss_active = "no boss active",
            boss_streak = "Most Legendary Bosses Defeated",

            -- Booster Packs
            b_booster_packs = "Card Packs",
            k_booster = "Pack",
            k_buffoon_pack = "Minion Pack",
            k_standard_pack = "Card Pack",
            k_booster_group_p_buffoon_normal = "Minion Pack",
            k_booster_group_p_buffoon_jumbo = "Minion Pack",
            k_booster_group_p_buffoon_mega = "Minion Pack",
            k_booster_group_p_arcana_normal = "Spell Pack",
            k_booster_group_p_arcana_jumbo = "Spell Pack",
            k_booster_group_p_arcana_mega = "Spell Pack",
            k_booster_group_p_celestial_normal = "Location Pack",
            k_booster_group_p_celestial_jumbo = "Location Pack",
            k_booster_group_p_celestial_mega = "Location Pack",
            k_booster_group_p_spectral_normal = "Forbidden Pack",
            k_booster_group_p_spectral_jumbo = "Forbidden Pack",
            k_booster_group_p_spectral_mega = "Forbidden Pack",
            k_booster_group_p_standard_normal = "Card Pack",
            k_booster_group_p_standard_jumbo = "Card Pack",
            k_booster_group_p_standard_mega = "Card Pack",
            ph_deck_preview_effective = "Effective total due to Minions, Encounters, and card enhancements",

            -- Hands & Discards -> Turns & Mulligans
            k_hud_hands = "Turns",
            k_hud_discards = "Mulligans",
            b_discard = "Mulligan",
            b_set_play_discard_pos = "Play/Mulligan Button Position",

            -- Shop -> The Tavern & Refresh
            b_shop = "The Tavern",
            k_shop = "Tavern",
            k_shop_cap = "THE TAVERN",
            b_stat_shop = "The Tavern",
            ph_enter_shop = "Visit the Tavern",
            ph_stat_shop = "Times visited the Tavern",
            k_reroll = "Refresh",
            b_reroll_boss = "Refresh Legendary Boss",

            -- Tags -> Secrets
            b_tags = "Secrets",
            b_stat_tags = "Secrets",
            k_tag = "Secret",
            k_tags = "Secrets",
            k_tag_cap = "SECRETS",
            k_banned_tags = "Banned Secrets",
            ml_tag_undiscovered = "Undiscovered Secret",
            ml_all_tags = "All Secrets",
            ph_stat_tag = "Total times this Secret has triggered"
        },
        labels = {
            joker = "Minion",
            tarot = "Spell",
            planet = "Location",
            spectral = "Forbidden Spell",
            voucher = "Treasure",
            tag = "Secret"
        },
        v_dictionary = {
            ante_x_voucher = "ANTE #1# TREASURE",
            joker_slots = "+#1# Minion Slot",
            joker_slots_plus = "+#1# Minion Slots",
            ml_negative_desc = {
                "Negative",
                "+#1# Minion Slot"
            },
            ml_negative_consumable_desc = {
                "Negative",
                "+#1# Spell Slot"
            }
        }
    }
}
