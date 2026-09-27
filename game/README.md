# Grand Strategy Game (working title) — Godot prototype

A post-apocalyptic strategy game in one Western European city. Time runs continuously and can be paused (the
Paradox model). You lead a scav crew from a single shelter toward a living territory, one venture at a time; every step
of growth makes the crew harder to hold together, until a leader's death tests whether it holds or breaks.

What changed in each build: `../CHANGELOG.md`. Design: `../Steering/` (start with `08-spine.md`).

## Play
1. Open Godot 4.7, **Import**, and select `game/project.godot`. Press **F5**.
2. **Space** pauses, **1-5** set the speed, **Esc** closes what's open or opens the menu (save, load, settings).
3. **F1-F7** open the windows: Character, Council, Realm, Diplomacy, Economy, Log.

## How it plays
**You start with problems, not goals.** Every faction begins with one shelter, short of food, with no weapons. The
alert icons under the top bar are your problems, worst first: hover to read, click to deal with it, right-click to dismiss.

**Everything you do is a venture:** pick a district, pick a venture, choose who leads it, how many go and what you
spend, then LAUNCH. Each has four outcomes (Triumph, Success, Setback, Disaster); hover the odds bar for the full
working-out. Leaders improve, get wounded and die.

**The loop:** food grows people and manpower; people pay taxes and eat food; materials (from ruins, trade and
Recycling Works) build and settle. Nothing piles up for free: food spoils, big stockpiles leak, buildings wear.

**Growing:** secure your shelter (Secure Food, Safeguard the Shelter, Gather Weapons), then Scout the ruins next
door, Scavenge them and Settle them. Settlers stay for good. Rebuild raises what a district gives.

**Neighbours:** four great factions and six minor ones (raiders, traders, hermits). Raiders take your food and
materials: watch the alerts, arm up, Reinforce threatened districts, or make a deal. Right-click another faction's land
or leader for diplomacy: gifts, trade, pacts, alliances, vassals, war.

**Your dynasty:** your leader has a family, a nature and a reign; children come of age at 16. Name an heir, keep the
council loyal, and watch the succession: when a leader dies, a disloyal or ambitious councillor may contest it and
split the faction in civil war. Click any portrait to open that person; right-click for what you can do with them.

**Hover anything** for how it works. Tabs, window titles and every number explain themselves.

## Develop
Godot 4.7.2, GDScript; the UI is built in code (`main.gd`), content is JSON in `data/`.

| Check | Command (from `game/`) |
|---|---|
| Regression tests | `godot --headless --path . --script res://tests/spine_test.gd` |
| UI smoke test | `godot --path . res://tools/ui_smoke.tscn` (prints `UI SMOKE OK`) |
| Balance simulation | `godot --headless --path . --script res://tools/balance_sim.gd -- [runs] [years]` |
| Screenshots | `godot --path . res://tools/render_shot.tscn -- <out_dir> [scenario[@days] ...]` |
| New city map | `godot --headless --path . --script res://tools/generate_map.gd -- [seed]` |

Claude Code commands wrap these: `/test`, `/sim`, `/render`, `/design-check`, `/triage`, `/release`.

### Content is data
| File | Holds |
|---|---|
| `data/ventures.json` | Every venture: cost, crew, days, odds, target, odds factors, effects per outcome, trait fed, AI goal |
| `data/buildings.json` | Buildings: cost, crew, days, slot requirement, upkeep, effects, AI goal |
| `data/scenario.json` | Starting factions (add one here to add it to the game) |
| `data/rules.json` | Tuning numbers |
| `data/council.json` | Council seats, loyalty reasons, character traits |
| `data/traits.json` | Faction traits: threshold, odds modifiers, effects, likes and dislikes |
| `data/diplomacy.json`, `opinion_modifiers.json` | Diplomatic actions; named opinion memories |
| `data/map.json`, `district_types.json` | The generated city layout; district type stats and art |
| `data/ambitions.json`, `names.json` | Milestones; name pools |

Ventures are assembled from building blocks in `venture_system.gd` (targets, odds factors, effect ops). A venture
made of existing blocks needs no code; typos show at startup (`GameData.validate()`).

### Code
| File | Role |
|---|---|
| `city_map.gd` | World state and the daily simulation: economy, ventures, diplomacy hooks, council, dynasties, succession, save/load |
| `main.gd` | Clock, input and all UI (frame, windows, district panel, planner, alerts) |
| `faction_ai.gd` | Weighted-scoring AI, one per non-player faction |
| `venture_system.gd`, `active_venture.gd` | Venture odds, tiers and effects; a venture under way |
| `diplomacy.gd`, `relation.gd`, `diplomatic_mission.gd` | Treaties, acceptance odds, opinion; pair state; envoys |
| `character.gd`, `portrait.gd` | People; procedural portraits |
| `faction.gd`, `district.gd`, `construction.gd` | Faction resources and state; one district; a building under way |
| `trait.gd`, `trait_engine.gd`, `game_data.gd` | Faction traits; data loading and validation |
| `city_map_view.gd`, `map_art.gd`, `map_painter.gd` | The map: drawing, procedural 2.5D art, layers |
| `tools/`, `tests/` | Map generator, balance sim, UI smoke, screenshots; regression tests |

## Known gaps
- Governments, National Ambitions (milestones only so far), marriage between factions, tech: see `../Steering/08-spine.md`
- Map art is procedural placeholder quality
- One save slot; saves from older builds aren't migrated when the format changes
- Under full fog, the log still reports rivals' actions you can't see
- One faction occasionally snowballs; coalitions come in spine stage S6
- Balance numbers are first-pass
