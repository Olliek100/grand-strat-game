# 22. Something to do: strain, building tiers and Activities (DRAFT; part A built 2026-10-16, tiers next)

Written 2026-10-16 from the owner's CK2 playtest. Nothing here is built. Paradox's games are structure only; names, costs and numbers are ours.

## What the playtest said
- The game is clicking districts, taking them, restoring them, then taking more. In CK2 nobody attacks you much and there is still always something to do.
- Going over your reach is fixed by clicking Relief on district after district. It is dull.
- A district takes 1 to 3 buildings, picked once and never improved.
- Nothing rewards playing tall over wide.

## What the code does today (checked)
- **Reach:** 5, plus one per seated councillor, plus half the best Stewardship (and +1 per records office). Past it, *every* district gains 0.1 grievance a day per district over (cap 0.6). The sim shows this is by far the biggest grievance source (about 7,100 a game year against 400 for the next).
- **Relief** is a standing task per district. Captains are capped (5, +1 per 5 districts, max 10), so with 15+ districts you cannot cover them all. The cause is realm-wide, the cure is per-district.
- **Buildings:** 9 of them (recycler, allotments, watchtower, clinic, market, salvage yard, hostel, school, workshop), one level each, no upgrades. Slots: 1 when claimed, 2 when secured, 1 more from a rebuilt-district payoff.
- **Things to do:** 15 ventures, most of them about land (settle, rebuild, assault...). Trade Run is a flat bargain. 20 events in all, 7 of them random pulses. Decisions (doc 21) are the first thing that is not about a district.

## Spine check
- **Loop:** gives wealth, materials and time more places to go than "another district".
- **Verb:** festivals, trade and leader activities are **ventures** (crew, odds, four outcomes). Upgrades and projects are deterministic investments, like construction and ambitions today. No second verb.
- **Arc:** tall play is a real road to "organised city"; wide play is a real road to overreach and collapse.
- No dead ends: every locked item says what is missing and where to get it.

---

## Part A. Strain: fix it at the realm, not district by district

**The rule stays** (more land than you can run makes people angry). **What changes is the answer.**
1. **One number, shown once.** The realm shows "Strain: 3 districts over reach (+0.3 grievance a day everywhere)" in one place (Realm tab and the top-bar hover) instead of a quiet rise in every district. Hover says the levers.
2. **Realm levers (all choices with a cost):**
   - **Raise reach:** records office (built); a tiered **Administration** line of buildings (Part B); a seated Steward with higher skill.
   - **Calm the realm now:** a Decision, *Open the city's tables* (a festival for the whole city): wealth cost scaled by districts, grievance down in every district you hold, cooldown about a year. It buys time; it does not fix the cause.
   - **Hand land off:** a district can be given to a house (doc 16 houses) to run: it stops counting against your reach (later; needs vassal-house work).
3. **Per-district Relief stays**, for a district that is angry for its own reasons (a raid, a revolt). It is no longer the way to pay for owning too much.
4. **Measured:** overstretch grievance per game and how many districts a player can hold before unrest above 80.

## Part B. Buildings that grow (tiers)
Each building gets **up to three tiers**. Upgrading is an investment in a district you already hold, in the same slot.
- **Upgrade, not new building:** costs materials and wealth, takes days, raises the effect (roughly +60% a tier) and the upkeep (roughly +80%).
- **Gates:** tier 2 needs the district Secured; tier 3 needs it Restored plus either a skilled councillor (Stewardship 3) or the matching institution. A locked upgrade says which.
- **Examples:** Allotments 0.4 food, then Greenhouses 0.65, then a Farm Hall 1.0 plus population growth. Market, then Bazaar (more trade income), then Exchange (a trade-run bonus). A new **Administration** line: Clerk's Office (+0.5 reach), Registry (+1), Town Hall (+1.5, and the Decision list gains an entry).
- **Why this makes tall viable:** a faction with 8 deep districts out-produces one with 14 shallow districts that are angry and over reach, at the price of fewer sources of new land.
- **AI:** upgrades are scored with new buildings on the same scale, by the same rules.
- **Save:** buildings are saved as ids today. Tiers change the saved shape: save version bump (I will ask first).

## Part C. Activities: things to do that are not land
Three kinds, built in slices, each with its own check against the sim.
1. **Festival (a venture).** The leader or a councillor hosts a festival in a district: crew, funding, odds, four outcomes. Success: grievance down there and next door, renown, neighbours think better of you; disaster: a riot or a death. Repeatable with a cooldown. This is the "host festivals" the owner asked for.
2. **Trade routes (richer Trade Run).** A route you set up between two districts or with a neighbour, which then runs on its own for months and pays by the route's length and safety (a standing task, like routine work). Raiders can cut it. This is "go on trading runs".
3. **City projects (deterministic).** Multi-month investments for the whole city (repair the water main, a market square, a wall), each with a cost, a timer and a lasting bonus, one at a time, gated by what you hold. These are the "construction projects", and the first step toward the doc 16 "services restored" idea. Distinct from Ambitions: shorter and practical, not a direction.
4. **Leader activities (later).** Personal ventures for the leader alone with small risk and a small reward (train, hold court, spend time with family). They need a stress or morale meter that does not exist yet, so they wait for the council and illness work.

## Tall against wide, in one table
| | Wide | Tall |
|---|---|---|
| Gains | more sources of food, materials, people | deeper yield per district, tiers, festivals and trade routes that scale with what you hold |
| Costs | strain over reach, infamy, war | upgrade costs and upkeep, fewer places to put new people |
| Risk | grievance and revolt, coalition | a rich target and fewer fall-backs |
| Road to | warlord and conquest | organised city |

## Build order (each is playable on its own)
1. **A1. Strain made visible, plus *Open the city's tables*.** Smallest; changes how the reach problem feels. No save change.
2. **B1. Building tiers**, starting with Allotments, Market and the Administration line. Needs a save bump.
3. **C1. Festival venture.**
4. **C2. Trade routes**, then **C3. City projects.**
5. Leader activities with the council and illness work.

## Left out on purpose
Tech (the spine defers it until the early game has more choices); deeper diplomacy beyond war (the "blood" stage); more life events (cheap data, its own small build); voxel characters and event art (separate decision, doc 22 does not depend on them).

## For the owner to decide
1. Is A1 first the right order, or do you want tiers (B1) first?
2. Should going over reach stay a penalty on every district, or only on the districts you added last?
3. Tier cost: a modest investment (about the price of a new building) or a real commitment (twice that)?
4. OK to bump the save version for B1 when we get there?
