# The Spine

What the game is built around, and the test every feature must pass. Written 2026-09-25 after the v1.26 review, when it became clear systems were being added one at a time without a shared loop. **This replaces the build order in 07-characters-and-ventures-outline.md** (the designs there still stand; only the order changes).

## One sentence
You lead a scav crew that **turns ruins into a living territory**, one venture at a time. Every step of growth makes the crew stronger and **harder to hold together**, until a death or crisis tests whether it holds or breaks.

## The three parts

### 1. The loop: what you need, where it comes from, what it becomes

```
 Ruined land ──Scavenge──▶ Materials ──Build──▶ Buildings
      ▲                                              │
      │                                       grow and house
 Scout / Settle                                      ▼
      │                                         Population
  Ventures ◀── manpower + named leaders ── (manpower, taxes, food needs)
      │
      └──▶ Growth creates STRAIN: upkeep, grievance, council loyalty, rivals' fear
```

Every resource has **one clear source and one clear use**, and every use grows with your size, so nothing piles up.

| Resource | Comes from | Spent on | Why it matters |
|---|---|---|---|
| **Materials** (new: salvage) | Scavenging ruins; Salvage Yards; trade | Settling districts; buildings; repairs | The build input; ruins run out, so you must push outward or trade |
| **Supplies** (food) | Developed districts; gardens; trade | Feeding population and manpower | Survival pressure; grows with population |
| **Wealth** | Taxes on population; markets; trade | Council wages; diplomacy; venture funding | Grows with population, and so do its costs (wages, administration) |
| **Manpower** (was "crew") | Population: developed districts produce it | Ventures (away while out; lost on disasters); settlers (gone for good) | The bodies you can send. Named characters are separate: they lead, manpower goes |
| **Renown** | Triumphs; bold ventures; deeds | **Invested in National Ambitions** (S4): a completed ambition grants a lasting bonus, so renown is spent for a return | The trade-off: renown you hold adds a **minor** diplomacy bonus. Spend it for a lasting return, or keep it for weight in negotiations |

**Population is the engine.** It is what buildings grow, what produces manpower and taxes, and what eats food. Today it only feeds recruits, and the crew cap mostly limits that; income ignores it. Settling a district costs manpower permanently, but as that district develops its own population produces more: expansion is an investment that pays back.

### 2. The verb: ventures (pillar 1)
Every meaningful act is a venture: a named leader, a crew, a cost, odds you can read, and four outcome tiers. Scout, Scavenge, Settle, Raid, Assault, Trade Run, Agitate, Envoy, Relief. There is no second way to act.

### 3. The arc: success creates the next crisis (pillars 4 and 5)
Growth makes strain gauges rise: administration cost, grievance, council loyalty, rivals' fear. The **leader's death** is the trigger. Succession follows the government's rule; weak succession plus high strain means claimants from the council, then a split (civil war on the same district map). The player plays on inside whichever side they belong to. **This is what gives a run its shape, and none of it is built yet.**

## Territory: a ladder that costs something to climb
Your not-doing list already defines control as a spectrum. The build skips most of it: two successful Expeditions (+25 influence each) claim a district. That's why claiming feels cheap and the map feels small.

| Step | How you get there | What it gives |
|---|---|---|
| **Unexplored** | (start) | Only the outline is visible; salvage and danger are unknown |
| **Scouted** | Scout venture (cheap, fast) | Reveals salvage stock, danger and population |
| **Worked** | Scavenge venture (repeatable) | Materials home; the salvage stock depletes; a little influence |
| **Claimed** | Settle venture: materials + manpower who **stay** as settlers | Becomes yours; small yield; 1 building slot |
| **Secured** | **Control ventures inside the district** (below) raise its control | Full yield; 2 slots |
| **Developed** | Buildings raise development; population grows | The payoff: taxes, food, manpower |

Expanding is now a run of ventures and a real investment of materials and people. That's slower, a decision each time, and it makes the 61 districts feel bigger without redrawing the map.

### Control ventures: how a district becomes truly yours
Every district you hold has a **control** track. You raise it with risky ventures **inside** the district, each tied to one need:

| Venture | Need | Yields | Can go wrong |
|---|---|---|---|
| **Secure Food** | Food | Supplies, plus a lasting food source | Spoiled stores, a fight over a garden |
| **Safeguard the Shelter** | Safety | Defence; lower grievance | Collapse, injuries |
| **Gather Weapons** | Strength | Arms (raises raid and defence odds) | Ambush, lost manpower |
| (later) **Settle Disputes** | Order | Lower grievance | Feuds, resentment |

Each success raises control and yields something. Control is what moves a district up the ladder (Claimed → Secured) and what rivals must wear down to take it. These are the same ventures anywhere you hold land, so **they're the opening of the game and the way you consolidate every district later**: one system, reused (pillar 1).

## The opening: one district
Each faction starts with **one district**: its shelter. The first minutes are control ventures at home: feed people, make the shelter safe, arm the crew. Each carries risk and, with a named leader, starts earning traits and loyalty from the first minute. Once the home district produces surplus food, materials and manpower, you look outward: Scout, Scavenge, Settle. The core loop's first two words, **Survive → Organise**, finally have a phase of their own.

Rivals start the same way (same rules, pillar 3), so the city begins mostly empty. The early race is for the best ruins near you, not for each other's land.

**Guardrail:** control is a track raised by ventures, not a base-builder inside the district. No placing structures on a grid (the not-doing list excludes block-by-block simulation).

## What each system is for

| System | Its job in the spine | State after v1.38 |
|---|---|---|
| Ventures | The verb | **Built**, including control ventures, Scout/Scavenge/Settle, Rebuild, Trade Run and Reinforce |
| Economy | The loop: scavenge → build → population → crew and taxes | **Working:** materials from scavenging and Recycling Works, food drives population and manpower, hoards leak. Nothing piles up over 8 simulated years (v1.38) |
| Territory | What you grow; each step should cost something | **Built:** the full ladder (Scout → Scavenge → Settle → control → Rebuild); settlers stay for good. Fog of war: both options playable, not yet decided |
| Buildings | Turn materials into population and output | **In the loop:** each changes a loop number and needs materials upkeep (disrepair otherwise). Few types yet |
| Characters and council | The people who act. Loyalty measures strain; succession is the crisis | **Mostly built:** leaders, families, personality and ruling traits, loyalty feeding claims, a named heir. No council agendas yet |
| Diplomacy | A way to get what the loop needs without war | **Built:** Trade Runs swap wealth for materials and food; vassals, alliances, first contact and likely deals shown. More actions parked |
| Traits (faction) | The memory of what you did becomes identity, and unlocks options | Built; the leader's nature now pulls them. Still unlock little |
| National Ambitions | You choose a direction, with a cost and a payoff | **Not built (S4):** current "ambitions" are automatic milestones |
| Government and succession | How strain is handled; what breaks at a death | **Half built:** Warlord succession with contested claims. Reforms and other governments are S4 |
| Collapse and civil war | The pay-off of strain | **Built:** a failed succession splits the faction and starts a war. Some simulated games still have none (S3 target: at least one per 4 years) |
| Map art | Makes the loop visible: ruins, salvage, growth, strain | 2.5D procedural drawing (v1.23). The agreed 3D map (option B) not started |

## Build order (replaces the steps in doc 07)

| Stage | What | Done when (checked in simulation and in play) |
|---|---|---|
| **S1a. The opening** (built in v1.27) | One-district start for every faction; control track; control ventures (Secure Food, Safeguard the Shelter, Gather Weapons); Materials and Manpower as resources; population produces manpower, taxes and food needs | The first minutes are a readable survival phase with real risk. A faction reaches a surplus and looks outward in roughly the first 2-3 game months |
| **S1b. Expansion** (built in v1.30) | Scout, Settle (Scavenge pulled into v1.28); the territory ladder; salvage that runs out; buildings each change a loop number; trade swaps materials and food | Claiming a district takes several ventures and a visible investment. No resource keeps piling up over 4 simulated years. A faction that stops growing still faces rising costs |
| **S2. Pressure** (reordered 2026-09-25, built in v1.31) | Minor factions (gangs, enclaves, raider crews, one district each) seeded between the big factions, so you meet neighbours in the first months; raids that steal food and materials, driven by need or personality; raid threats shown in Problems; Trade Runs go to another faction's market (they gain the wealth, you gain goods); Rebuild shows its payoff in numbers | Defence, arms, diplomacy and raiding each get used in the first year because a neighbour makes them matter. Playtest: "I had a reason to defend / deal / raid" |
| **S3. The arc** (built in v1.33) | Faction leader (a character) who ages and dies; family (the first dynasty); family and renown as sources of better council members; succession under a Warlord rule; council agendas and loyalty feeding claims; a failed succession splits the faction on the map | A leader's death is the most tense moment of a run. At least one split per 4 simulated years across all factions, and it can be read coming |
| **S3b. Legacy and the UI frame** (built in v1.34) | The new screen layout (top bar hovers, alert icons, left windows, district panel, outliner) with Character and Realm windows; personality and ruling traits, spouse always present, designate heir | Every function reachable in the new layout; the heir, a rival's weak succession and why a deal is refused can be found unaided |
| **S4. Choices** | National Ambitions screen (each faction's own ambitions, drawn from one data pool by its situation, pros and cons shown, one active at a time, **renown invested to start one**, a lasting bonus on completion); government reforms (Autocracy, Politburo, Oligarchy, Democracy), each changing the succession rule. Minor factions can climb too: Junkie raiders → Warlord → Autocracy | You pick a direction and can say what it costs you |
| **S5. Blood** | Bloodlines and marriage between factions, which create pacts, claims and heirs | Marriage is worth considering as an alternative to war |
| **S6. Wider pressure** | Aggression memory and coalitions; the off-map crisis director (vertical slice) | Runaway conquest provokes a readable response |
| Later | Tech tree; regional map | After the playbox gate |

**Art runs alongside, after S1a:** map art moves to **real 3D generated in code (option B)**: a Godot 3D scene under a fixed top-down camera, low-poly buildings and rubble built from each district's shape, real lighting, shadows and fog. The simulation doesn't change. First a style guide from the user's reference images, then a one-borough test compared side by side with the current map. The map should show the loop: ruins being stripped, shelters growing, control rising.

## The test for every new idea
1. **Which link does it strengthen:** the loop, the verb, or the arc? If none, it goes on the parked list.
2. **Does it add a resource, or reuse one?** Prefer reuse.
3. **Is it the venture pattern?** If it's a new kind of action, it should be a venture.
4. **Can the player read it?** Odds, timers, reasons and consequences shown (pillar 3).
5. **No dead ends.** Every resource needs a source that doesn't cost that same resource, and every "can't" must say what's missing and where to get it. (Added after v1.27: Expedition cost materials and was also the main source of materials, so a player who ran out was stuck for good.)

## Parked (not cut, but not until their stage)
Bloodlines and marriage (S5). Tech tree (later). **Portraits that evolve with the leader and the faction** (user idea, 2026-09-25): portraits age with the character, and their look follows the faction's era and government. A Junkie raider (vest, messy hair, mean look) decades later as an Autocrat wears an open white shirt, a gold chain and a sharp street-gang cut: cleaner, still a raider. For all factions. Belongs with S3 (ageing leaders) and S4 (governments); portraits are already layered procedural drawing, so this is a set of extra layers keyed to age and government, not a new system. More building types, beyond those S1 needs. More diplomacy actions. Automatic milestone ambitions (to be replaced by chosen ones in S4). Map art polish (after S1).

## Decided (2026-09-25)
- **Materials is a new resource**: the build input, from scavenging.
- **Manpower** replaces "crew" as the resource name. Settlers are **gone for good**, but a developing district's population produces new manpower, so expansion pays back.
- **Map art: option B** (real 3D generated in code), after S1a.
- **Opening: one district per faction**, with control ventures at home before expansion.
- **Renown is a currency:** invested in National Ambitions for lasting bonuses; unspent renown gives a minor diplomacy bonus. Its current effects (crew limit, respect) are to be reviewed in S4.

## Open questions
- **Fog of war: how far it reaches.** To explore during S1b. Options:
  1. **Unknown ruins only:** you see every faction's land, but a district's salvage and danger stay hidden until scouted. Simplest, and keeps diplomacy fully readable.
  2. **Terra incognita:** you see only what you hold, what borders you, and what you've scouted. Beyond that, outlines only. Rivals are discovered, which makes a one-district start feel like waking up in the dark.
  3. **Stale intel:** like 2, but what you scouted goes out of date. You see the district as it was when last scouted, with its age shown. Rich, but the most UI.

  Leaning: build 1 in S1a, then try 2 in S1b and play both.
