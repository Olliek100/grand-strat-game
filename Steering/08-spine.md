# The Spine

What the game is built around, and the test every feature must pass. Written 2026-09-25 after the v1.26 review, when it became clear systems were being added one at a time without a shared loop. **This replaces the build order in 07-characters-and-ventures-outline.md** (the designs there still stand; only the order changes).

**Updated 2026-10-02** to the state after v1.41 and the unreleased education build: what's built, the docs that changed direction since (10, 11, 12, 13, 14), and a proposed next spine at the end ("Proposed next spine"), **not yet agreed**.

## One sentence
**Agreed 2026-10-02:** You lead a crew of survivors out of the collapse. Over generations, marriages, children and what you teach them turn your crew into a dynasty, and the gangs around you into the great houses of a rebuilt city. What you've built (land, people, arms and the people you raised) decides what you can take and hold, and growth strains it until a death tests whether it holds.

*Before: "You lead a scav crew that turns ruins into a living territory, one venture at a time. Every step of growth makes the crew stronger and harder to hold together, until a death or crisis tests whether it holds or breaks." Doc 14 proposed a family-only version; the owner kept both: the scav crew is how a run starts, the dynasty is what it becomes.*

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
| **Renown** | Triumphs; bold ventures; deeds | **Invested in National Ambitions** (built in v1.40): a completed ambition grants a lasting bonus, so renown is spent for a return | The trade-off: renown you hold adds a **minor** diplomacy bonus. Everything you've ever earned also counts as **reputation** (never goes down), which sets manpower and captain limits, recruit quality, the heir's claim and respect |

**Population is the engine.** It is what buildings grow, what produces manpower and taxes, and what eats food. Today it only feeds recruits, and the crew cap mostly limits that; income ignores it. Settling a district costs manpower permanently, but as that district develops its own population produces more: expansion is an investment that pays back.

### 2. The verb: ventures (pillar 1)
Every meaningful act is a venture: a named leader, a crew, a cost, odds you can read, and four outcome tiers. Scout, Scavenge, Settle, Raid, Assault, Trade Run, Agitate, Envoy, Relief. There is no second way to act.

Since written, two things sit beside it:
- **Standing tasks** (doc 13, v1.40): routine work on your own land (Scavenge, Rebuild, Safeguard, Secure Food, Relief, Gather Weapons, Reinforce) is a councillor's task that repeats until the district has nothing left to give. Each run is still a venture roll. When an attack is already on its way, any free captain can Reinforce once (v1.42).
- **Choice events** (doc 14, v1.41): decisions about people (births, deaths, coming of age, upbringing, everyday life). Options cost nothing; each gives a timed effect or shapes a child. A second core pattern next to ventures (decision log, 2026-09-29).

### 3. The arc: success creates the next crisis (pillars 4 and 5)
Growth makes strain gauges rise: administration cost, grievance, council loyalty, rivals' fear. The **leader's death** is the trigger. Succession follows the government's rule; weak succession plus high strain means claimants from the council, then a split (civil war on the same district map). The player plays on inside whichever side they belong to. **This is what gives a run its shape. Built in S3 (v1.33), with government-specific succession in S4 (v1.40).**

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

| System | Its job in the spine | State after v1.41 (+ what v1.42 added) |
|---|---|---|
| Ventures | The verb | **Built**, including control ventures, Scout/Scavenge/Settle, Rebuild, Trade Run, Reinforce and Threaten. Odds explain themselves with a "To raise it" list, and your crew is weighed against defenders on site (v1.39). **Gap:** the factions' overall strength (manpower, arms) doesn't count, and a Disaster can still come at 80-90% |
| Standing tasks | Routine work at home without a launch per run | **Built (v1.40, doc 13):** a councillor runs a task until the district is done; committed for two runs. Still one district per task, each run a roll |
| Economy | The loop: scavenge → build → population → crew and taxes | **Working:** materials from scavenging and Recycling Works, food drives population and manpower, hoards leak. Nothing piles up over 8 simulated years (v1.38) |
| Territory | What you grow; each step should cost something | **Built:** the full ladder (Scout → Scavenge → Settle → control → Rebuild); settlers stay for good. **District payoffs (v1.41):** Cleared, Safe, Rebuilt and Restored. A calm district gains control by itself only up to a cap; beyond it takes Safeguard. Fog of war: both options playable, not yet decided |
| Buildings | Turn materials into population and output | **In the loop:** 9 types (School added in v1.42), each changing a loop number, with upkeep. **Gap:** the School does little for the population |
| Characters and council | The people who act. Loyalty measures strain; succession is the crisis | **Built:** leaders, families, personality and ruling traits, loyalty feeding claims, a named heir; births for every married couple (v1.41); **education** (v1.42): upbringing at 6, yearly growth, childhood events, traits settling at 16, Of the People and Born to Rule. Skills rise from successes. No council agendas |
| Choice events | Decisions about people | **Built (v1.41):** 12 events, then 8 more for education (v1.42); options cost nothing and give timed effects; the AI answers its own |
| Diplomacy | A way to get what the loop needs without war | **Built:** Trade Runs, pacts, alliances, vassals, gifts, tribute and demands (v1.39), first contact. Tribute offered to the player is a proposal (v1.42) |
| War | Taking land by force | **Built:** declared with a cost, war exhaustion, peace and a truce; the AI picks a weaker neighbour and declares 15 days later. **Gap:** no war goal, no demands before war, the warning is only a log line, and Assault can be repeated on any of their land |
| Raiders | Early pressure (S2, doc 10) | **Built (v1.39):** raid cooldowns, tribute, Threaten, emboldened raids after a refused demand |
| Traits (faction) | The memory of what you did becomes identity, and unlocks options | Built; the leader's nature pulls them. Still unlock little |
| National Ambitions | You choose a direction, with a cost and a payoff | **Built (v1.40):** 12 ambitions paid in renown, gated by situation; the milestones became Deeds |
| Government and succession | How strain is handled; what breaks at a death | **Built (v1.40):** Gang, Warlord, Autocracy, Politburo, Merchant Oligarchy, Democracy, each with its own succession and way of breaking; reforms with council approval |
| Collapse and civil war | The pay-off of strain | **Built:** a failed succession splits the faction and starts a war. Civil wars 0-1 per game in the latest simulations |
| Map art | Makes the loop visible: ruins, salvage, growth, strain | 2.5D procedural drawing (v1.23). The agreed 3D map (option B) not started |
| Speed | Under 30 ms a simulated day (40 at speed 5) | **Over budget:** about 50 ms a day in the profile on the 117-district map after the 2026-10-14 speed work (80-140 with the sim's own counters). The AI's venture search is 54% of a day and district simulation 24% |

## Build order (replaces the steps in doc 07)

| Stage | What | Done when (checked in simulation and in play) |
|---|---|---|
| **S1a. The opening** (built in v1.27) | One-district start for every faction; control track; control ventures (Secure Food, Safeguard the Shelter, Gather Weapons); Materials and Manpower as resources; population produces manpower, taxes and food needs | The first minutes are a readable survival phase with real risk. A faction reaches a surplus and looks outward in roughly the first 2-3 game months |
| **S1b. Expansion** (built in v1.30) | Scout, Settle (Scavenge pulled into v1.28); the territory ladder; salvage that runs out; buildings each change a loop number; trade swaps materials and food | Claiming a district takes several ventures and a visible investment. No resource keeps piling up over 4 simulated years. A faction that stops growing still faces rising costs |
| **S2. Pressure** (reordered 2026-09-25, built in v1.31) | Minor factions (gangs, enclaves, raider crews, one district each) seeded between the big factions, so you meet neighbours in the first months; raids that steal food and materials, driven by need or personality; raid threats shown in Problems; Trade Runs go to another faction's market (they gain the wealth, you gain goods); Rebuild shows its payoff in numbers | Defence, arms, diplomacy and raiding each get used in the first year because a neighbour makes them matter. Playtest: "I had a reason to defend / deal / raid" |
| **S3. The arc** (built in v1.33) | Faction leader (a character) who ages and dies; family (the first dynasty); family and renown as sources of better council members; succession under a Warlord rule; council agendas and loyalty feeding claims; a failed succession splits the faction on the map | A leader's death is the most tense moment of a run. At least one split per 4 simulated years across all factions, and it can be read coming |
| **S3b. Legacy and the UI frame** (built in v1.34) | The new screen layout (top bar hovers, alert icons, left windows, district panel, outliner) with Character and Realm windows; personality and ruling traits, spouse always present, designate heir | Every function reachable in the new layout; the heir, a rival's weak succession and why a deal is refused can be found unaided |
| **S4. Choices** (built in v1.40; see 12) | National Ambitions screen (each faction's own ambitions, drawn from one data pool by its situation, pros and cons shown, one active at a time, **renown invested to start one**, a lasting bonus on completion); government reforms (Autocracy, Politburo, Oligarchy, Democracy), each changing the succession rule. Minor factions can climb too: Junkie raiders → Warlord → Autocracy | You pick a direction and can say what it costs you |
| **S4b. Fixes from play** (v1.39, v1.40; docs 10, 11, 13) | Raiders you can answer (cooldowns, tribute, Threaten); odds that explain themselves; standing tasks for routine work at home | Raids can be answered; "why 59%?" has an answer on screen |
| **C1. Characters first, slice 1** (v1.41; doc 14) | Choice events (12) and births for every married couple; district payoffs alongside | "Something about my people happened that I had to decide" |
| **C2. Education** (v1.42; doc 14) | Upbringing at 6 (changeable once a year), School, childhood events, traits settling at 16, Of the People and Born to Rule | "My heir turned out the way they did because of what I chose" |
| **P1. Strength over dice** (v1.42; doc 15) | Force-based odds for raids and assaults; Disasters scaled to the gap | Built |
| **P2. War goals and ultimatums** (v1.42; doc 15) | Claim, Subjugate, Vassalize; justify, ultimatum, war only on refusal; the AI plays the same steps | Built. Superseded in part by doc 20: wars are now fought over occupation and settled at a peace table |
| **H1-H3. Houses and marriage** (v1.42; doc 16) | Matches within the faction, houses with land, loyalty and revolt, marriage between factions | Built |
| **D1. Diplomacy restraints, build 1** (2026-10-11; doc 18) | A cooldown on every ask per pair and action (AI full length, player 35%), refusals remembered, a 90-day notice before an early ultimatum, a claim clock that reads as a range | Built. Pile-ons did not fall: build 2 (stake-based backing) is the fix |
| **D2. The war goal window** (2026-10-11; doc 19) | A free assessment screen before committing to a goal: balance in five steps, one objective list, outcomes, requirements, the trend once under way, back down | Built |
| **W1. War as negotiation** (2026-10-11; doc 20) | An assault occupies and the district pays nobody; war score from occupation, fights and a clock; a peace table; a status-quo white peace; a ten-year truce after a deal; backing off costs renown | Built. Wars mostly end in white peace after about 170 days |
| **Death risk** (2026-10-14; doc 14) | Risk follows age; a failed venture can kill its leader, by danger and odds | Built. Successions fell from about 10 to about 3 a game and civil wars nearly vanish |
| **W2-W3. The cost of growth and a bigger map** (2026-10-14; doc 20) | 117 districts and 12 factions; land settles in over months; infamy; reach; Settle slower | Built. **Pacing target not met:** the map still fills by year 3 |
| **W4. A defender's victory** (2026-10-14; doc 20) | A defender whose war score reaches 65 can dictate terms: the claim fails, reparations, and spare score buys occupied districts or tribute; the AI does the same | Built (v1.44) |
| **D1. Decisions** (2026-10-16; doc 21) | Eight instant decisions in a tab of Ambitions: desperation, running things, institutions; the AI takes them from the same list | Built (v1.44) |
| **A1. Strain** (2026-10-16; doc 22 part A) | Going over reach strains only the newest land; one clear chip; Open the city's tables. Building tiers (B1) and Activities (C1-C3) come next | Built (v1.44); tiers next |
| **S5. Blood** | Bloodlines and marriage between factions, which create pacts, claims and heirs. *Doc 14 splits this: marriage within the faction first (its slice 4), then between factions* | Marriage is worth considering as an alternative to war |
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
Tech tree (later). **Portraits that evolve with the leader and the faction** (user idea, 2026-09-25): portraits age with the character, and their look follows the faction's era and government. A Junkie raider (vest, messy hair, mean look) decades later as an Autocrat wears an open white shirt, a gold chain and a sharp street-gang cut: cleaner, still a raider. For all factions. Belongs with S3 (ageing leaders) and S4 (governments); portraits are already layered procedural drawing, so this is a set of extra layers keyed to age and government, not a new system. More building types, beyond those S1 needs (a College after the School, a Chapel or Hall for gatherings: doc 14). More diplomacy actions. Map art polish (after S1). Grand ventures as chains of choice events (doc 14).

## Decided (2026-09-25)
- **Materials is a new resource**: the build input, from scavenging.
- **Manpower** replaces "crew" as the resource name. Settlers are **gone for good**, but a developing district's population produces new manpower, so expansion pays back.
- **Map art: option B** (real 3D generated in code), after S1a.
- **Opening: one district per faction**, with control ventures at home before expansion.
- **Renown is a currency:** invested in National Ambitions for lasting bonuses; unspent renown gives a minor diplomacy bonus. Reviewed in S4 (v1.40): its lasting effects (crew limit, respect, recruits, the heir's claim) moved to reputation, which never goes down.

## Decided since (2026-09-27 to 2026-09-29; details in 11, 13 and 14)
- **Earned odds** (doc 11, v1.39): odds explain themselves; your crew is weighed against the defenders on site; no Disaster above 90%; a success scales with how well the roll went; the planner starts on the recommended plan. **Deferred:** locking odds at launch (B.3) and tech in S4 (D.1). **Still missing:** the two factions' overall strength (manpower, arms, command) doesn't enter the odds.
- **Standing tasks** (doc 13): routine work at home is a councillor's task, not a launch per run.
- **Characters first** (doc 14, partly decided): choice events cost nothing and give timed effects; a child's development is visible; events every 3-4 months; district payoffs first. Choice events as a second pattern is logged (2026-09-29). **Open:** decision-log entries for education biasing traits and the two new traits (built, v1.42).

## Open questions
- **Fog of war: how far it reaches.** To explore during S1b. Options:
  1. **Unknown ruins only:** you see every faction's land, but a district's salvage and danger stay hidden until scouted. Simplest, and keeps diplomacy fully readable.
  2. **Terra incognita:** you see only what you hold, what borders you, and what you've scouted. Beyond that, outlines only. Rivals are discovered, which makes a one-district start feel like waking up in the dark.
  3. **Stale intel:** like 2, but what you scouted goes out of date. You see the district as it was when last scouted, with its age shown. Rich, but the most UI.

  Leaning: build 1 in S1a, then try 2 in S1b and play both.

---

## Proposed next spine (2026-10-02; the owner's answers are at the end of this section)

Written after the playtest of the education build. The owner's notes: "the game is still running on gambling, not the strength of a faction"; Rust Dogs declared war "seemingly randomly", then Assault could be repeated to take their land; a Disaster at 82% opened the player's land; defence doesn't grow unless you keep launching Safeguard; the player decides at too fine a grain (Secure Food, Scavenge) where Paradox games run on passive rates and long assignments; councillors should get better at what they do. "Functional but not fun in its loops."

**The diagnosis:** the loop, verb and arc all exist, but minute to minute the player launches small gambles, and the outcome of each is mostly dice. Strength (land, people, arms, able councillors) doesn't decide enough, and conflict arrives without a reason you could see coming. Nothing in S5 or S6 addresses that.

### One sentence (proposed; replaced by the owner's decision 1 below)
You lead a family and its crew through the fall and rebuilding of a city. **What you've built (land, people, arms and the people you raised) decides what you can take and hold.** Every generation inherits it, and growth strains it until a death tests whether it holds.

This keeps doc 14's family at the centre, keeps the original strain-and-collapse arc, and adds the missing promise: strength counts.

### The three parts, revised

1. **The loop runs on rates, set by your choices in the council.** You decide the routine work at home (Secure Food here, Safeguard there) in the Council screen; once assigned it runs passively for months and cheaply, and its output rises with the councillor's skill and time on the job. *Changes doc 13's standing tasks from repeated rolls to steady rates; folds in doc 14 slice 3 (characters improve with use). Amended by the owner's decision 3 below: the player still decides; it's not automatic.*
2. **The verb is for what matters, and strength sets the odds.** Ventures stay the one way to act in the world, but only for consequential acts: settle, raid, assault, trade runs, envoys, agitation, threats. Their odds come first from the balance of force (crew sent, arms and command against guards, control, buildings and arms); the dice then pick within a range the forces allow. Overwhelming force can't end in Disaster, and a Disaster costs crew and time, not your land. **Choice events** stay the second pattern, for decisions about people.
3. **The arc: conflict and collapse you can see coming.** No war without a war goal: the aggressor justifies a claim over some days (you're told, with the reason), then sends an **ultimatum** with a deadline (give up the district, pay, or submit). Only a refusal starts the war, and the war is fought over that goal. Strain, death, succession and civil war stay as built.

### New tests, added to the five above
6. **Strength before dice.** Could a stronger, better-prepared side lose this to a single roll? If so, the roll is too big.
7. **Rates before launches.** Is this something a Paradox game would run passively? Then it's a rate set by people and priorities, not a venture.
8. **No surprises.** Every hostile act against you is announced with its reason and a timer before it lands.

### Proposed build order

| Stage | What | Done when |
|---|---|---|
| **Now (small)** | The School pays the population (taxes or development there; better recruits). Find the cause of the 75-80 ms days | The School is worth building without children; days back under 30 ms |
| **P1. Strength over dice** ([doc 15](15-strength-and-war.md); built in v1.42) | Force-based odds for raid and assault (both factions' crew, arms, command, guards, control, buildings); Disasters scaled to the gap and costing crew, not land; defence and control grow passively with time held and buildings, Safeguard speeds it | Simulation: a side with twice the force wins about 9 assaults in 10 with no Disasters. Playtest: "I lost because I was weaker, and I could see it" |
| **P2. War goals and ultimatums** (doc 15; built in v1.42) | Three war goals (Claim a district, Vassalize, Subjugate); justify one over days (visible to the target); ultimatum with a deadline; war only on refusal, fought over the goal; the AI plays the same steps | No war in simulation starts without a claim and a refused ultimatum; the player always gets the warning in the top bar, not just the log |
| **P3. Council work** (doc 17, not written) | Routine work at home is assigned by the player in the Council screen and then runs passively for months, cheaply (far less than its one-off cost), with no per-run rolls; councillors' skills grow with time on the job | The player assigns a handful of jobs a game year instead of launching runs; the loop never breaks because a passive job eats more than it brings; a long-serving Quartermaster visibly out-produces a new one |
| **C3-C4. Houses and marriage** ([doc 16](16-houses-and-marriage.md); H1-H3 built in v1.42) | Marriage within the faction, then between factions (the old S5); **vassal houses** inside a faction (from Vassalize, doc 15): each holds its old districts, has loyalty that can turn into revolt, marries into your family and into other factions' houses, and may answer (or decline) a call to arms for a reward; gatherings | The gangs of the opening have become houses: a run has at least one house that matters by year 10, and a disloyal house can be seen coming before it revolts |
| **S6. Wider pressure** | Aggression memory and coalitions (they hang naturally off P2's war goals), the crisis director | Runaway conquest provokes a readable response |

### Status, 2026-10-14
Built: P1, P2, H1-H3, doc 18 build 1, the war goal window, W1, the death-risk change, W2 and W3 (see the build order above and the changelog). **Still to build:** P3 (council work; doc 17 not written), S6 (coalitions; infamy is its first half), doc 18 build 2 (stake-based volunteering and backing, allies deciding on a call, pay-off and marriage outs), a defender's victory at the peace table, an illness state with choices and a healer or clinic, a stronger early brake on expansion (the pacing target), and the speed goal.

### Needs a decision-log entry before building
1. The new one-sentence spine.
2. **"One verb" narrowed:** ventures for consequential acts; routine work becomes rates run by the council (P3). Pillar 1 changes wording, not intent.
3. ~~Choice events as the second pattern~~ (already logged 2026-09-29).
4. **Strength before dice:** forces set the odds; the dice pick within a range (P1).
5. **War needs a claim and an ultimatum** (P2), replacing the 2026-09-24 rule that war is simply declared with a cost and a 15-day AI warning.

### For the owner to decide
1. The sentence: as proposed, doc 14's, or reworded?
2. Order: P1 → P2 → P3 as above, or P3 first (it changes the moment-to-moment game most, but it's the biggest)?
3. P3's reach: should **all** routine home work become rates (Scavenge, Secure Food, Safeguard, Rebuild, Gather Weapons, Relief), or keep one or two as ventures?
4. P2's scope: one kind of war goal to start (claim a bordering district), or also "submit as vassal" and "pay tribute"?

### Owner's decisions (2026-10-02)
1. **The sentence: both are right, at different times.** A run starts with scavengers, gangs, soldiers and bureaucrats; as they marry, raise and educate children, they become dynasties, and after 2-3 generations they are the great houses of a rebuilt city (no CK titles needed). The arc of a run is **anarchic gangs → an organised post-apocalyptic city**. Agreed sentence:

   > **You lead a crew of survivors out of the collapse. Over generations, marriages, children and what you teach them turn your crew into a dynasty, and the gangs around you into the great houses of a rebuilt city. What you've built (land, people, arms and the people you raised) decides what you can take and hold, and growth strains it until a death tests whether it holds.**
2. **Order: P1 → P2 → P3.**
3. **P3: routine work stays the player's decision**, made in the Council screen: the player assigns Secure Food, Safeguard the Shelter and the rest, and nothing is automatic. Once assigned it runs passively, and **passive work must cost much less than its one-off version**: if a passive Rebuild ate 20+ materials a cycle, a player who didn't also keep scavenging would break the loop. So P3 is "assign in the Council, run cheaply for months", not "the council decides for you".
4. **War goals: Claim a district, Vassalize, Subjugate.** Not tribute (that stays the raiders' demand, not a war). Designed in doc 15.
