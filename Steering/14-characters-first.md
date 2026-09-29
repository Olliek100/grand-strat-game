# Characters First

A revision of the spine: the dynasty becomes the reason to play and replay, and the territory becomes its stage. Written 2026-09-29 after the v1.40 playtest ("it lacks a reason to replay; characters feel like a resource") and the CK2/CK3 structural research (06-paradox-reference-notes.md, "Characters-first"). **Status: partly decided 2026-09-29 (see "Owner's decisions" at the end). District payoffs building now; slice 1 next.**

## Why
- The spine (08) centres the territory loop: scavenge → build → population → crew. Characters were built to serve it: they lead ventures, hold seats, die and succeed. They're a means, not the point.
- Playtests say the loop alone doesn't bring players back. There's no reason to replay, and once routine work went to the council (doc 13) nothing took its place.
- CK2 and CK3 keep players for thousands of hours with the same kind of simulation because every run is a **family's story**: who married whom, which heir turned out cruel, which child you shaped. The map is where it happens.

## The spine, revised
**Old:** You lead a scav crew that turns ruins into a living territory, one venture at a time.

**New:** **You lead a family through the fall and rebuilding of a city. Every generation inherits what the last one built and broke, and you shape who they become.** The territory is what they fight over, build up and pass on.

- **The loop stays:** land, resources, ventures and tasks are the stage and the stakes.
- **The verb stays:** ventures remain the one way to act in the world (pillar 1). What's added are **choices about people**, and they come to you as events.
- **The arc gets personal:** growth and strain still end in a death and a succession (pillar 5), but you now care about *who* inherits, because you raised them.

**Pillar check:** nothing here breaks a pillar.
- **Pillar 2 (earned, not chosen):** education biases a roll, and traits grow with use. There is no tree.
- **Pillar 3 (legible AI):** the AI answers the same events, using weights built from visible factors.
- **Pillar 4 (mortality):** becomes the centre, not a side effect.
- **The not-doing list** holds: no focus or perk trees, no authored per-faction branches.

## The building blocks (from the research, in priority order)

### 1. Choice events (the core block)
- **What it is:** a prompt with 2-4 options. Each option has:
  - a condition (can you pick it, e.g. "needs Diplomacy 5" or "costs 20 wealth");
  - an effect: resources, loyalty, opinion, a trait nudge, a flag for a follow-up, or a venture to launch;
  - an AI weight built from the same visible factors (traits, loyalty, resources).
- **Mixed outcomes:** options trade short-term gains for costs ("+20 loyalty from the council now, -10% income for 60 days").
- **Content lives in data** (`data/events.json`); the code provides the block, the effect operations and the triggers, like ventures.
- **Chains and cooldowns:** a follow-up is a flag remembered on the character and checked by a later event. There's no separate story system.
- **Pausing:** player events pause the game (they're decisions). AI events resolve quietly and show in the log only when they touch you.

### 2. Moments that can trigger an event
A short fixed list checked by the daily simulation. Each moment draws from a weighted pool of events that qualify:
- **A birthday**, and coming of age at 16 (a proper event, replacing "of age in N years" on the child's card).
- **A birth.**
- **A death in the family or on the council.**
- **A venture resolving,** especially a Triumph or a Disaster.
- **A council change,** and a councillor's loyalty crossing a line.
- **A slow pulse** (about monthly) for everyday life: a rivalry, a request, a rumour.

### 3. Family life, made real
- **Every married couple can have children**, not only the leader: the heir's marriage, a councillor's, a grown child's.
- **A pregnancy is announced, and a birth is an event**, with names, and a rare twin or a difficult birth.
- **A birth rate that gives a family** over a run: roughly 2-4 children per couple in their prime, so there are heirs, spares and rivals.
- **Children:** a child's card shows who raises them and what they're being pushed toward, instead of "of age in N years".

### 4. Education shapes the heir (the owner's example)
- **The first choice comes around age 6 (a choice event):** who raises the child, and toward what.
  - **A school** (needs a School building in your land): the child grows among the people. Biased toward traits that tie them to the faction and the populace, such as a new **"Of the People"** trait (the populace trusts them, and succession is steadier), and toward Diplomacy and Stewardship.
  - **A home tutor** (a councillor you name, or a hired tutor for wealth): the child grows apart, groomed to rule. Biased toward **"Born to Rule"** (self-belief, sharper specialist skill, a stronger claim), and toward the tutor's own best skill and nature. A cruel tutor makes a crueller heir.
  - **Left to the parents,** free: biased toward the parents' own traits.
- **Childhood events** (a few, between 6 and 16) add to hidden scores ("the child stood up to a bully", "the child hid during a raid"), shaped by the choice above.
- **At 16, coming of age rolls the traits,** weighted by those scores. The choice biases the outcome; it never guarantees it. **No numbers are shown until the reveal**, though the child's card hints at how they're turning out ("growing bold", "withdrawn").

### 5. Traits that grow with use
- **The Veteran/Hero pattern, extended:** a hidden count per kind of behaviour rises as a character does it, and steps up at fixed points (e.g. Scout → Pathfinder → Wayfinder for scouting; Negotiator → Silver-tongued for deals; Butcher for cruel choices in events).
- **Each step carries** a small bonus and sometimes a cost, like faction traits.
- **Nothing is picked from a menu.** What a character does, through tasks, ventures and event choices, is what they become.

### 6. Family activities (one cut-down shape)
- **A gathering:** a short duration, a small guest list (family and council), each guest with a quiet intent drawn from their nature and feelings, and one outcome event.
- **It covers** weddings, wakes, a feast for the council, a coming-of-age celebration.
- **It costs** wealth, which is one of the jobs wealth needs (doc 11's "what is wealth for?"). It pays back in loyalty, opinion, a betrothal, or trouble.

### 7. Marriage (pulled forward from S5)
- **Marrying within your faction:** your children to councillors' children or captains, as a family event.
- **Marrying into other factions:** a diplomatic offer scored like treaties. It creates the family tie (opinion, better odds for pacts and trade) and **claims:** a grandchild may inherit another faction.
- **The family tie is the lasting thing;** any alliance hangs off it and breaks with it.

## The territory as backdrop (so land stays meaningful)
- **District payoffs:** reaching a district's ceiling gives a lasting reward and a deed: ruins cleared, danger gone, development maxed, fully Secured. For example: a stripped, safe, rebuilt district becomes **"Restored"**, with +1 building slot, more people, and a little renown.
- **Buildings with depth:** upgrades (a School, then a College), and slots that grow with development, instead of a flat 2. New buildings that serve the characters: a **School** (education), a **Chapel or Hall** (gatherings, weddings, wakes).
- **Grand ventures** (parked earlier: the tanker, the expedition, the laboratory) become **chains of choice events** around one or more ventures. That's how wealth buys big, risky, story-rich moments.

## What changes for existing systems
- **Ventures and tasks:** unchanged. Events can launch ventures, and venture outcomes can trigger events.
- **Ambitions:** stay faction-level. The early, ungated tier (from the v1.40 feedback) still makes sense.
- **Council:** gains weight. Councillors tutor children, attend gatherings, marry into your family, and turn up in events.
- **The UI needs:**
  - an **event pop-up with choices** (today's pop-up only informs);
  - a **richer family view** (Realm → Dynasty) with children's upbringing and marriages;
  - the child's card showing upbringing instead of "of age in N years".

## Build order (small, playable slices)
1. **Slice 1, choice events:** the block, the trigger moments, the pop-up with choices, the AI's choices, and about 10-12 events: coming of age, a birth, a death, a council quarrel, a venture triumph or disaster, a few everyday ones. Plus **births for every married couple.** *Play check: "something about my people happened that I had to decide."*
2. **Slice 2, education:** the choice at 6, the School and tutors, childhood events, the roll at 16, "Of the People" and "Born to Rule". *Play check: "my heir turned out the way they did because of what I chose."*
3. **Slice 3, traits that grow with use:** a few behaviour counts with steps.
4. **Slice 4, marriage within the faction, then between factions.**
5. **Slice 5, gatherings** (weddings, wakes, feasts).
6. **Alongside:** district payoffs and building depth; the early ambition tier; grand ventures as event chains.

Each slice is one build: test, one simulation pass, then play.

## Needs a decision-log entry before building
1. **The spine's one sentence and priority change:** characters first, territory as the stage. This updates 08-spine.md's build order (S5 marriage moves up; S6 coalitions and crises move back).
2. **Choice events as a second core pattern next to ventures.** Pillar 1 says "one verb"; events are *decisions about people*, not a second way to act in the world, and they can launch ventures. Worth writing down so it doesn't drift.
3. **Births for every married couple,** at a rate that builds families.
4. **Education biases a hidden roll,** revealed at 16, with no numbers shown before. Pillar 2, applied.
5. **New traits "Of the People" and "Born to Rule",** and traits that grow with use.
6. **Event pop-ups pause the game** for the player's own choices.

## Decisions for the owner
1. **The new one-sentence spine:** right as written, or reword?
2. **Slice 1 first** (choice events and births), or education first since it's your headline example? (Recommendation: events first; education is built on them.)
3. **Hidden until 16:** show nothing about how a child is turning out, only hints ("growing bold"), or show the scores?
4. **How often events come:** roughly one choice a month for the player at the start, rising as the family grows? Too many decisions tire; too few and it's the old game.
5. **Territory backdrop:** district payoffs and building depth as a parallel small build now, or after slice 1?

## Owner's decisions (2026-09-29)
1. **Event choices cost nothing.** Each option is a decision whose effect is a **timed buff or debuff to a specific system** (e.g. "+15% Scavenge odds for 90 days", "council loyalty -5 for 60 days", "raids on you +10% for 30 days"). No wealth, food or other resources are paid to pick an option. This replaces block 1's "costs 20 wealth" examples; conditions on options can still depend on a character (skills, traits).
2. **A child's development is visible** on their character panel: their skills rising, and traits as they emerge, with the upbringing that's shaping them. At 16 it settles into the adult they are. This replaces "hidden until 16".
3. **Events come every 3-4 months** for the player at the start (not monthly).
4. **District payoffs: now**, as a small build of their own before slice 1.
5. **Not yet answered** (the draft stands unless changed): the new one-sentence spine, and events before education.

## Built
- **v1.41: district payoffs** (Cleared, Safe, Rebuilt, Restored) and **slice 1**: the choice-event block with 12 events in data, triggered by coming of age, births, deaths, a venture's triumph or disaster, and an everyday pulse every 3-4 months; options cost nothing and give timed effects, shown in the outliner; the AI answers its own; births for every married couple (6% a month, pregnancy then birth). **Next: slice 2, education** (upbringing choice at 6, childhood events, the child's rising skills and emerging traits on their card, "Of the People" / "Born to Rule").
