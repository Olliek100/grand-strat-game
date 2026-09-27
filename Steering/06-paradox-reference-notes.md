# Paradox Reference Notes

Structural lessons from the CK2, CK3 and HOI4 game files in `Ref_PD_Games/`. **Reference only**: these notes describe how Paradox structures systems. No scripts, text, numbers or art are copied into this game (see decision log, 2026-09-25).

Each item says what Paradox does, then what it means for us: **adopt**, **adapt**, or **skip**.

## Map (next roadmap step: map overhaul)

- **The map is data, not generated geometry.** CK3's `default.map` points at `provinces.png`, a flat-colour image where every province is one RGB colour. `definition.csv` maps `id;R;G;B;name`, and there are ~14,000 rows. Adjacency comes from touching pixels. `adjacencies.csv` adds special links such as straits, with a crossing point. Terrain, heightmap, rivers and regions are separate layers over the same provinces.
  - **Adapt.** Replace the random Voronoi with a **district layout file**: a province image, or polygons in data, with names, types and adjacency. It can be generated procedurally now and hand-edited later, which gives a designed city (river, bridges, downtown core) instead of a jittered grid. Draw terrain and art as separate layers on top, as CK3 does.
- **Regions group provinces** (`geographical_regions`: counties into named regions, e.g. flood-risk regions). **Adapt:** group districts into boroughs such as Docklands, Old Town and the Industrial Belt. That's useful for events ("flooding in the riverside boroughs"), for crises, and for the UI at a zoomed-out level.
- **A tiered hierarchy** (CK3 baronies, counties, duchies, kingdoms). **Skip** for now. Districts plus boroughs is enough for a single city.

## Opinion and diplomacy (improves v1.19)

- **Opinion is a stack of named modifiers**, each with a value, a monthly change and a decaying/stacking flag (`opinion_modifiers`). **Adopt.** Today our gifts, raids and betrayals are an anonymous push on one number. Named, fading modifiers ("Raided us: -10, fading", "Sent gifts: +12, fading") would make every opinion change readable, which is pillar 3.
- **Acceptance is base plus labelled additive modifiers** (`ai_accept = { base = 20 modifier = { add = ... desc = REASON } }`), with hard refusals as `add = -1000` plus a reason. **Already close.** We multiply factors and use check errors for vetoes. Keep ours, but note the pattern of "refusal reasons" as modifiers rather than hidden rules.
- **Interactions share one shape:** `is_shown`, `is_valid` (with the failure shown), `on_accept`, `on_decline`, `ai_accept`, `ai_will_do`, plus optional `send_option`s that sweeten the deal (e.g. add gold, add a hook). **Adapt later.** Send options map well to "propose a pact **and** include a gift" in one envoy.
- **The AI holds a stance toward each other nation** (HOI4 `ai_attitudes`: antagonize, befriend, protect, threat, vassalize, ally, ignore). Its strategies weight these per target (`ai_strategy`: `type = befriend / antagonize / alliance / protect`, with values). **Adopt.** Give each AI faction an explicit stance toward every other faction ("sees you as a TARGET", "wants to protect you", "sees you as a THREAT") and show it on the diplomacy panel. This makes the AI's plans readable before it acts, and simplifies our AI scoring into "stance, then actions".

## Characters and succession (roadmap: characters)

- **Traits declare opposites** (`opposites = { craven }`), plus `same_opinion` and `opposite_opinion`. **Adopt** for character traits: a character can't be both, and like minds get along. This extends our faction-trait likes/dislikes to people.
- **Succession is two independent rules:** `order_of_succession` (inheritance, appointment, election, theocratic) and `title_division` (partition vs single heir). **Adapt.** For a crew, rules like "strongest takes over", "chosen successor" and "crew vote" fit better than dynastic inheritance. Keep the split between *who succeeds* and *what happens to the holdings*. Partition, where land splits between claimants, is a natural seed for collapse.

## Collapse cycle (roadmap: internal factions)

- **Internal factions accumulate discontent and compare their power to the ruler's** (CK3 `factions`: `discontent_progress`, `power_threshold`, `demand`, `ai_join_score`, `ai_demand_chance`). The demand arrives with a few days' warning, and demand chance rises sharply once the faction is about 10% stronger than the ruler. Types include independence, liberty (fewer ruler powers) and claimant (replace the ruler). **Adopt the shape.** Internal factions (Military, Socialists, etc.) each have discontent (from grievance, policies, traits) and power (the districts and crew that back them). When power passes a threshold they make a demand; a refusal means civil war, splitting the map along the districts that back them. This is pillar 5 with the telegraphing that pillar 3 requires.
- **Peasant/populist factions** grow from local unrest. **Adapt:** high-grievance districts can spawn a popular faction, not just a revolt.

## Crisis director and events (roadmap: crises)

- **HOI4 events** have a `trigger`, are either `is_triggered_only` (fired by on_actions or other events) or `mean_time_to_happen`, and have `option`s with `ai_chance` weights. **Adopt the shape** for crises: triggered by state conditions, with options, and the AI picks by weight.
- **CK3 story cycles** are long-running stories attached to an owner, with their own variables, visible counters ("tug of war" bars), modifiers, and events that fire over months. **Adapt.** A crisis (nomad horde, plague, tribute demand) should be a **story with a visible progress bar**, not a single event. That makes crises telegraphed and legible, as pillar 3 and the decision log require.

## Suggested changes, in roadmap order

1. **Map overhaul:** the district layout as a data file (procedurally generated, editable), boroughs, and separate art layers.
2. **Diplomacy polish:** named, fading opinion modifiers; visible AI stances toward each faction.
3. **Characters:** traits with opposites and same/opposite opinion; succession as "who succeeds" plus "what happens to holdings".
4. **Collapse:** internal factions with discontent, power, a threshold, a telegraphed demand, then civil war.
5. **Crises:** story cycles with visible progress and triggered events with weighted options.
