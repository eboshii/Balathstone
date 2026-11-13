# Balathstone design notes

## How Hearthstone maps onto Balatro

| Hearthstone | Balatro |
|---|---|
| Minion Attack / Health | +Mult / +Chips, scored every hand |
| Turn | One played hand ("this turn" = until that hand is scored) |
| Battlecry | Start of every round, after the opening hand is drawn. Brann doubles it |
| Start of Game | Start of every round, never doubled |
| Deathrattle | When the minion dies (Boss damage, spells, battlecries) **or is sold**. Rivendare doubles it |
| Enemy hero | The Blind. 1 damage = -2% score requirement; healing it raises it. Damage dealt outside a round hits the next Blind |
| Your hero | Your money. Restoring Health gives $ (capped at $30, $60 with Potion of Vitality); damage costs $; Armor gives $ uncapped |
| Summon | Creates that exact minion (tokens are summon-only and never appear in shops). Summoned minions sell for $0 |
| "Choose a friendly minion" in a Battlecry | The minion to its right |
| Destroy / transform an *enemy* minion (spells) | Destroy / transform playing cards you select |
| Cast a Spell | Use a Spell (Tarot) or Forbidden Spell (Spectral). Locations (Planets) are not spells |
| Combo | You used a Spell or a Discard earlier this turn |
| Secret | Replaces every Tag (`src/secrets.lua`). Earned by skipping a Blind; triggers once when its condition happens, mostly on the Boss's attack |
| Hero Power | A Discard |
| Mana / Manathirst | The current Ante |
| Boss Blind | Attacks one minion every hand (Taunt first, Stealth skipped); the defender strikes back at the Blind for its Attack |
| Freeze (Boss) | Skips its next attack |
| Enemy keywords | Charge: also attacks before each hand. Rush: attacks at round start. Windfury: attacks twice. Lifesteal: its damage heals the Blind. Reborn: comes back once with a higher requirement. Stealth: immune to Blind damage until it attacks. Divine Shield: blocks the first damage, or your first hand if nothing hit it yet. Poisonous, Freeze, Silence (your minion doesn't score this round), summoned armies |
| Blind scaling | Vanilla curve x `Balathstone.ANTE_GROWTH`^(Ante-1): Ante 8 = 5x vanilla (250,000), still compounding in endless |
| Silence (Boss) | Disables the Boss Blind's ability |
| Overload (N) | You have N fewer Discards next round |
| Minions in your hand / deck (buffs) | Your playing cards gain permanent Chips / Mult / X Mult |
| Golden copy | Polychrome edition |
| "Cast twice" / recast | The spell's effect runs again (same or random targets) |
| Temporary summons | Leave at the end of the round without dying (no Deathrattle) |
| Patches the Pirate | Buying him hides him in your deck as a card; he jumps out when you buy a Pirate or draw him |

Keywords: Taunt, Divine Shield (restored each round), Windfury (the minion's whole score repeats, X Mult
included, like a Balatro retrigger), Mega-Windfury (four times), Charge (all its attacks again on the first
hand of a round), Rush (its attacks again without Chips on the first hand), Lifesteal (heal your hero by its
Attack at end of round), Stealth (untargetable until it has scored this round), Reborn, Enrage, Spell Damage.

All of these appear in game as keyword tooltips (`localization/*.lua`, `hs_kw_*`).

## Code layout

- `src/core.lua` – the rules engine. Every timing window is dispatched centrally from
  `Balathstone.calculate` (wired to `SMODS.current_mod.calculate`), so all cards with the same keyword
  behave identically. Minion scoring is `HS.minion_calculate`.
- `src/minions.lua` – one declarative `M { ... }` per minion (+ tokens). `text` is both the tooltip and
  the text printed on the card art.
- `src/spells.lua`, `src/locations.lua`, `src/spectrals.lua` – `HS.spell { ... }` consumables, with
  `targets = { area = 'jokers' | 'hand', min, max }`.
- `src/vouchers.lua` – Hearthstone treasures. `src/bosses.lua` – Boss Blinds.

## Tools

- `python tests/run_tests.py` – headless test-suite (LuaJIT via `lupa`) against a Balatro/Steamodded
  simulation in `tests/mock_balatro.lua`. Covers every keyword, the timing rules, deck spells, bosses,
  treasures, plus crash sweeps over every card.
- `python tools/build_art.py [--sample]` – rebuilds `assets/1x|2x/{minions,consumables,vouchers}.png`
  from official renders, painting out the Hearthstone text and typesetting each card's Balatro text.
  Card ids, positions and text are read from the Lua definitions, so re-run it after changing any card.
  Atlases are 142x190 per card at 1x.

`legacy/` holds the old generator scripts; don't run them, they overwrite the current Lua and atlases.

## Dev files and the game

The whole project folder is the installed mod (junction `%APPDATA%\Balatro\Mods\Balathstone`). Steamodded
parses every `.json` within 2 levels of the mod root as possible mod metadata, so dev data lives one level
deeper: raw HearthstoneJSON dumps in `data/raw/`, generated reports in `test_output/reports/`. Don't put
new `.json` files in the root or a first-level folder.

Trailer tools: F8 (spawn scenario, **wipes your board**) and F9 (screenshot) only work with `HS.DEBUG = true`.
