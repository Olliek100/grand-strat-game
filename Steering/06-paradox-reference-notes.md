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

## Characters-first (2026-09-29, roadmap: doc 14, characters as the reason to play)

Looked at CK2/CK3 events, activities, education/childhood, lifestyles and leveled traits, and marriage interactions, with an eye on reusing our "venture" verb and a possible single "choice event" building block.

### Events: how they're triggered and how the AI picks

- **Two trigger styles, both still alive.** CK2 events carry their own `mean_time_to_happen` (a base time plus modifiers that speed up or slow the pulse) and fire when their `trigger` is met. CK3 mostly dropped per-event MTTH in favour of **on_action hooks**: a small set of fixed moments (a birthday, a death, a phase of an activity) call a named on_action, which is often a *weighted random pick* among several candidate events, or a `first_valid_on_action` chain that tries handlers in order until one's trigger passes. **Adapt.** We don't need per-event timers; we already have a daily tick. A small table of "moments that can fire a character event" (birthday, trait threshold crossed, venture resolved, council seat vacated) each pulling from a weighted pool is simpler to reason about than hundreds of independent MTTHs, and keeps determinism through `city.rng`.
- **Every option carries its own trigger (can it even be chosen) and its own AI weight.** CK2's `ai_chance` is a base factor plus situational modifiers ("if wealth is very low, multiply by 10"), so the AI's choice is legible from the same numbers the player sees. **Adopt this shape outright** for a "choice event" building block: one prompt, 2-4 options, each with an availability check and a weight formula built from the same factors as our odds system. This is effectively a venture without a crew or a % roll — good for the character moments that shouldn't need a leader/crew commitment (a courtier's request, a childhood incident, a rival's insult).
- **Chains carry state forward as scoped variables, not new systems.** A CK3 "story cycle" (see crisis notes above) and CK2's multi-part events (e.g. a loan event triggering a follow-up in N days with a flag already set) both just stash a flag or variable on the character and check it later, rather than inventing a new object. **Adopt.** A trait-earning arc ("proved brave three times") can be a counter variable on the character bumped by matching venture/event outcomes, read by a later event or by the trait-grant check itself. No new subsystem needed.
- **Cooldowns are ordinary flags with an expiry**, checked in the trigger of the next event of the same family, not a separate cooldown manager. **Adopt.** Cheap to build, cheap to read.
- **Volume needed to feel alive is modest.** A single activity (see below) or a single character flow (e.g. childhood) is built from on the order of a dozen to a few dozen small events feeding 2-4 shared building blocks (a generic "flavour pulse", a generic "outcome" event), not hundreds of bespoke ones. **Adopt the ratio**, not the count: a handful of reusable event *shapes* (choice event, flavour pulse, outcome reveal) parameterised by data, matching our "content lives in JSON, code provides building blocks" rule.

### Activities (CK3) / feasts, hunts, pilgrimages (CK2)

- **An activity is: duration/phase(s), a guest list, a per-guest "intent", and a resolution.** Concretely: a phase advances on a timer; while active it schedules a fixed sequence of events (start, complication, end) plus lighter "random pulse" events aimed only at player-controlled attendees (the AI doesn't need flavour, only outcome); each guest picks an **intent** (a goal for attending, e.g. "build influence", "make trouble") scored the same way as an event option (a weighted `ai_will_do`), and the intent's effect resolves when the activity ends. **Adapt heavily, don't adopt whole.** This is the CK3 team's answer to "how do many characters do something together over time" — exactly our dynasty-gathering problem (a wedding, a wake, a council dinner). A cut-down version — one duration, a small guest list, each guest silently assigned an intent from personality + relationship, one resolution event — would give family gatherings weight without the enormous file size CK3's hunt.txt shows (thousands of lines); that size comes from years of DLC content, not from the underlying shape.
- **Cost and duration are on the activity type, not negotiated per-instance.** **Adopt**: fits our venture-style "cost sits on the button" rule directly — an activity is really a venture variant (leader = host, crew = guests, cost = gold/time, outcome tiers = how it lands with each guest).

### Education / childhood

- **A guardian (educator) plus a chosen focus plus the child's inborn personality traits determine an accumulating, hidden score; the actual trait is a weighted roll at coming-of-age, not a direct pick.** CK3: a court position (tutor/guru) contributes skill; the player or AI picks one of a handful of skill-track focuses for the child; that combination adds to a hidden per-skill variable across the following years' childhood events; at 16 a `random_list` weighted by that accumulated variable rolls the education trait's level. CK2's version is lighter: a childhood **focus** just lists a small set of `potential_traits` it can lead to, again gated by an AI `chance` factor, with the actual trait decided later, not chosen. **Adopt the structure, skip the scale.** This already matches "traits are earned, never picked from a tree" almost exactly: the focus/guardian choice is a *bias*, not a guarantee, and the trait itself only appears once the child has lived through it. For us: choosing who raises a child (which council member, or the parent) and what they're pushed toward (which skill) should bias a hidden accumulator that childhood events add to, resolving into an earned trait at 16 — no separate "trait tree" screen, no player-visible numbers until the reveal.
- **Childhood events read the guardian's own traits and skew.** A cruel guardian's events skew toward Shaken/Craven-adjacent outcomes; a brave one skews toward Brave. **Adopt.** This gives council assignment ("who mentors the heir") real weight without new mechanics — it's just who supplies the bias to an existing accumulator.

### Lifestyles, focuses and leveled traits — what's a tree (skip) vs what's earned (adopt)

- **CK3 splits "lifestyle" into two very different things that look similar.** (1) **Focuses**: a chosen branch (diplomacy/martial/etc., then a specific focus within it) that just grants a flat passive bonus while active and biases which further perks unlock — this is the tree, chosen by the player or by an AI weight formula. **Skip entirely** — this is exactly the "traits chosen from a tree" our not-doing list forbids. (2) **Leveled/tracked traits** (e.g. a hunter-type trait with named sub-tracks): each sub-track has a hidden point total that rises only from *doing the matching activity* (attending hunts, resolving related events), and at fixed thresholds (checked, never copied here) the character's bonus for that track steps up — no player choice of "which level," it just accrues. **Adopt this half.** It's functionally identical to our Veteran/Hero/Scarred/Shaken: a counter tied to a category of behaviour, read by a threshold check, producing a stepped bonus. We already do this; CK3's sub-track split (e.g. two flavours of the same broad activity building different bonuses) is a reasonable way to let one recurring venture type (say, "trade run") earn two different specialisations depending on which choices within it the player leans on.
- **CK2 has no real perk tree** for lifestyle — mostly ambitions (one-off ruler objectives) and ordinary traits gained from events/decisions. Less to borrow here structurally; CK3's split above is the more useful reference.
- **Net verdict for doc 14: no focus/perk tree, ever.** Any "lifestyle" feel we want should come entirely from side (2): trackable counters against categories of venture/behaviour, each with a small number of fixed thresholds, exactly like the existing earned traits — just more categories of "doing," not a menu of "becoming."

### Marriage and family (kept short — later stage)

- **A proposal is a generic "interaction" building block**: `is_shown`/`is_valid` gates (can this even be offered), an `ai_accept` score (base + labelled modifiers, mirroring `ai_chance`), and on_accept/on_decline effects. Our decision log (2026-09-25 era note above) already flags this pattern for diplomacy; marriage/betrothal is the same shape aimed at people instead of factions. **Adopt when we build it**: reuse the acceptance-score building block rather than inventing a marriage-specific one.
- **Alliances piggyback on the marriage, not the other way round**: the family tie is the persistent fact; the alliance is a modifier/flag hung off it that can be checked and can break. **Adopt the ordering** — marry first as a character/family event, derive any mechanical alliance benefit from the existing tie rather than modelling "alliance" as its own object.

### What not to copy, explicitly

- **Do not copy focus/perk trees** (CK3 lifestyle focuses, CK2-style menus of "pick a path") — direct violation of "traits are earned, never chosen."
- **Do not copy activity file scale.** The multi-thousand-line hunt/wedding files are DLC-accumulated content bloat, not a required shape; a single duration + guest list + intents + one resolution event is the whole pattern worth keeping.
- **Do not copy CK3's separate lifestyle-XP-and-perk-point economy** (XP pools spent on a perk tree). That's the tree again, just gated by a resource.
- **Do not copy the sheer number of on_actions/hook points** (CK3 has dozens of birthday/age/court on_actions). A handful of moments (birthday/coming-of-age, venture resolved, council change, death) covers what a solo dev needs.

### Recommended minimum set, in priority order

1. **One "choice event" block**: prompt + 2-4 options, each with an availability check and an AI weight formula built from existing odds factors (reuses venture-scoring code, no crew/roll needed). This is the single most reusable piece — childhood incidents, courtier requests, council friction, rival slights all run through it.
2. **A small table of trigger moments** that can pull a choice event from a weighted pool: birthday/coming-of-age (16), venture resolved, council seat change, death nearby. Not per-event timers; a fixed list checked on the daily tick.
3. **Leveled/earned traits generalised**: the existing Veteran/Hero/Scarred/Shaken pattern (counter against a behaviour category, stepped threshold, no player pick) extended to a couple of new categories so more of what a character does leaves a mark.
4. **Education as a biased accumulator**: choice of mentor (existing council member or parent) plus a chosen skill emphasis nudges a hidden per-skill counter through childhood; coming-of-age resolves it into a weighted trait roll. No visible numbers until the reveal, no tree.
5. **One cut-down "activity"**: fixed short duration, small guest list drawn from family/council, each guest silently assigned an intent from their personality/relationship (reusing the choice-event weight formula), one resolution event. Covers weddings, wakes, and family gatherings as a single reusable shape rather than one-off content.
6. **Marriage/betrothal as an interaction**: acceptance score built the same way as existing diplomacy acceptance, family tie as the persistent object, alliance (if any) as a modifier hung off the tie.

## Suggested changes, in roadmap order

1. **Map overhaul:** the district layout as a data file (procedurally generated, editable), boroughs, and separate art layers.
2. **Diplomacy polish:** named, fading opinion modifiers; visible AI stances toward each faction.
3. **Characters:** traits with opposites and same/opposite opinion; succession as "who succeeds" plus "what happens to holdings".
4. **Collapse:** internal factions with discontent, power, a threshold, a telegraphed demand, then civil war.
5. **Crises:** story cycles with visible progress and triggered events with weighted options.

## Restraints on asking, aggression and pile-ons (2026-10-11, for doc 18)

Read from CK3 (character interactions, AI defines), HOI4 (defines) and a skim of CK2 (defines). Patterns only; nothing copied. Prompted by a playtest where five factions that all liked the player backed two claims against them, the AI having asked each repeatedly until it got a yes.

**1. One ask per pair per long while (CK3).** Almost every interaction carries a cooldown against the same recipient, usually 3-10 years, sometimes 15-25; a few carry a plain cooldown of months to years. The AI also tries each kind of interaction only every several years (frequency set by tier), from a short list of sensible targets, not everyone. *Ours: the AI retries every envoy cycle, with no memory of a refusal.*

**2. The recipient decides on its own stake, with hard blocks.** An ally asked to join a war starts from a modest base and then adds or subtracts: a flat block if the war is of little benefit, if the target is its own family, heir, friend or suzerain, if it is a conqueror (helps nobody but itself), or if it is saving money; softer factors for opinion, shared culture or language, and joining defensive wars more readily. *Ours: backing's only target-side factor is a multiplier on opinion of the target, so liking the target still leaves a real chance of a yes.*

**3. There is no pre-war "back my claim".** In CK3 the other side joins by a standing alliance, once a war exists, by calling; the ask is a call to arms inside a war, not a recruitment drive before one. Vassals and factions act on their own opinions, not on being asked. *Ours: backing is a pre-war recruitment action with no counterpart.*

**4. Saying yes is costly to break, saying no costs little at first.** Refusing a call you are bound to costs the one who refused prestige and costs the caller an opinion hit; alliances themselves are rare, negotiated, and refused with a lasting memory. The AI also won't call a brand-new ally into an old war, nor the player in against their own family.

**5. The caller stops when strong enough.** A setting makes the AI keep calling allies only while it isn't much stronger than the enemy: no piling on for its own sake. HOI4's AI generates at most a couple of extra war goals at once.

**6. Cadence and cost for the aggressor.** CK3's AI has a minimum gap between its own offensive wars and a chance that falls with its penalty for aggression (unless rationality is low or it is a warmonger). HOI4 makes a war goal cost more for each nation already at war or being justified against, takes at least days to justify, builds visible *threat* gradually as it justifies, and raises a world tension meter that other countries react to; guarantees cost more for each one already given.

**7. Policy, not clicks.** CK3's war behaviour is a chosen *stance* (attacker/defender, by relative strength), tasks run for years on the council, and the player acts on a few big levers. The AI's long-running choices are stances and tasks too.

Not read in depth: HOI4's diplomatic AI scripts beyond the defines, and CK2's coalition interaction (only its defines).

**What it suggests for us (to design, not built):** drop pre-war backing in favour of calls to arms inside a war from standing alliances; give every ask a per-pair cooldown and a remembered refusal; give each possible backer stakes and hard blocks (border, family, existing friendship, nothing to gain); cap and cost pile-ons (cost per concurrent war or claim, stop calling when strong enough); keep the claimant's timer binding and visible.

## War score, occupation and the cost of holding land (2026-10-11, for doc 20)

Read from CK3 (casus belli types, defines, AI defines), HOI4 (defines, resistance and compliance files), and a skim of CK2 (casus belli types, defines). Patterns only; nothing copied. Prompted by the owner's playtest: districts change hands at once, white peace keeps what you took, the "enforce" lever is invisible, and the map is full by month 18.

**1. Occupation and ownership are different things (CK3, HOI4).** A fight occupies territory; who *owns* it changes only when the war ends in a peace deal. Occupation is what earns war score.

**2. War score has three sources (CK3).** *Occupation* (the share of the enemy's land you hold, times a scale, with a bonus for their capital); *battles* (won fights, capped per side); and a *ticking* score that grows each day, immediately for the attacker and only after a delay for the defender, so a war can't drag on for ever. Each war goal sets how large each source can be.

**3. A goal needs a percentage of the score (CK3).** Pressing a claim to full victory needs the attacker's score at a set fraction of the maximum (80% for a plain claim), not just any lead. Below it, the attacker can still end the war by white peace or take a lesser deal.

**4. Peace is a table of demands bought with score (CK3, HOI4).** Victory, white peace and defeat are the three endings. In HOI4's peace conference each demand has a cost in peace score and the winner spends what it has earned; costs rise for taking things you have no claim on and fall when the target is a state you hold a claim on.

**5. White peace is the status quo (CK3).** No title changes; occupiers go home. A truce follows. The AI's willingness to accept it falls as it gains, and rises as it nears defeat: it has "close to victory" and "desperate" thresholds in score.

**6. Newly taken land is unruly for a while (CK3, HOI4).** CK3: when a county changes hands by conquest its *control* drops by most of its value, then climbs back; income and levies scale with control (none at zero). HOI4: a captured state starts with low *compliance* and some *resistance*; resistance rises with unhappiness and falls with compliance, with a claim on the state, at peace, and with garrisons; compliance climbs over time in tiers, and each tier unlocks more of the state's yield and lowers the garrison it needs.

**7. Growth is bounded by cost (CK2, CK3, HOI4).** CK2's *infamy* is added by each war (each casus belli carries its own multiplier, and "no cause" costs the most), makes others hostile, and above a threshold lets neighbours form a *coalition* against you; a conquest also brings a *truce* of years before the same two can fight again. CK3 caps how many holdings a ruler can hold directly (the domain limit, raised by skill and buildings) and adds tyranny for abuses. HOI4's non-core states are less productive and more restive.

**What it suggests for us:** occupation as its own state on a district; war score from occupation, battles and a ticking clock; a peace table where score buys demands; a real white peace; conquest and settling both start with low control and ramp up; infamy (our "notoriety") per goal, with a truce of years; a cap on how much you can hold well.
