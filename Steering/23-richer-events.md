# 23. Richer events: story, risk and things at stake (DRAFT for the owner to mark up)

Written 2026-10-18. Takes doc 16's event notes (section 4, "Notes on events") and the owner's playtest ("events with story, risk and things at stake"). Nothing is built. Paradox's event and journey systems are structural reference only; every title, text and number here is ours.

## Owner's decisions (2026-10-18)
1. **Risk in events is appropriate.** Doc 14's rule "event options cost nothing" is retired: an option may cost something, risk something, or both.
2. **The Blackout lore is not wanted as player-facing text yet.** Events here carry the city's day-to-day, not the backstory.

## What events are today (checked in the code and `data/events.json`)
- 20 events: 7 random "pulse" events (about one every 90-120 days), 7 childhood, and one each for birth, death, coming of age, education, match, a venture triumph and a venture disaster.
- **Every option is a pick between two or three timed modifiers** (for example, Rats: burn the stock, food x0.9 for 30 days; or set traps, food x0.95 for 90 days). Nothing is rolled, nothing is paid, nothing follows. There is no wrong answer and no consequence you did not choose, which is why they read as flavour.
- Events only come as a pulse or at a life moment. Nothing happens *during* a venture or because of what is going on in a district.

## What this changes
An event becomes a short story with a stake: something you could win or lose, a choice that has a price, and sometimes a second chapter.

### 1. Stakes: an option can cost, risk, or both
Each option can carry any of:
- **A cost** paid now (wealth, materials, food, arms, manpower, renown). Shown on the option, like costs on buttons elsewhere. If you cannot pay, the option is greyed with what is missing.
- **A risk:** the option resolves into outcomes. **The odds are shown before you choose** (pillar 3: readable odds), built from the same factors as ventures (the leader's skill, faction traits, the council, what you are carrying), so "Bluff them" is a Cunning roll and "Fight" is a Command roll, and you can see why it is 60%.
- **Outcome tiers:** the same four tiers as a venture (triumph, success, setback, disaster), but an event may use two or three of them. Each tier has its own effects and a line of text.
- **Losses are real.** A loss may take stock, injure or kill a character (the same death-risk rules as ventures), cost a building, raise grievance, or cost renown. Nothing is taken without the option text saying it could be.
- **Safe options still exist** in most events (decline, wait, pay to avoid), so a player is never forced into a gamble: they choose which risk to carry. The cost of the safe option is usually a smaller, certain loss.

This does not add a second verb. A venture is *you acting on the world*. An event is *something that comes to you*; the risk is in how you answer it, with the odds and tiers the venture engine already uses.

### 2. Triggers: events happen in more places
Today: pulse and life moments. Add:
- **During a venture** (the "journey" feel): when a long, dangerous or leader-led venture is under way, it can roll an event partway (an ambush on the trade road, a find in the ruins). Standing tasks (routine work) roll rarely or never.
- **From a district's situation:** high grievance, a district freshly settled, strain over reach, a run of raids, ruins at a certain level, a building finished.
- **From the faction's situation:** food short, broke, a leader's age, the council split, a war just ended.
- **Chains:** an option can queue a **follow-up** that arrives after some days, and only if you chose that path (a stranger you took in returns with a request; a deal you broke comes back).

### 3. Passive events: the city keeps moving without stopping you
- **Passive** events apply and log with no pop-up (a small buff, a debuff, a trait nudge, a note). They can be frequent.
- **Prompting** events pause the game and ask. Cadence stays about one every 3-4 months at the start, then more as you hold more (a larger faction has more going on). A hard cap per year keeps it from becoming an interruption.
- The log line for a passive event says what changed, so it is not a hidden effect.

### 4. A journal for each venture
A venture keeps a short list of what happened to it ("Day 3: a collapse blocked the road; Day 5: found a cache"), shown on the venture and in the leader's record. This is the story that makes a scavenge or a trade run feel like a trip.

### 5. An optional picture
Each event may carry a picture slot. No picture is needed for any event to work; a placeholder fills it until art exists. (This is the HOI4-style event window the owner asked for.)

### 6. The AI
AI factions get the same events with the same options and odds, and answer by `ai_goal` weights as they do now, now also weighing risk by their traits (a cautious faction takes the safe option, a bold one gambles). No hidden bonuses.

## Starter set: twelve events (all titles and numbers are placeholders)
Tied to the stages of the loop the owner called stale, so each stage can surprise you.

| Event | Trigger | The choice and its stake |
|---|---|---|
| **A cache in the ruins** | During Scavenge or Scout | Dig it out now (a Stewardship roll; setback: a collapse, crew hurt) / mark it and come back (certain, but a rival may find it first) |
| **Squatters at the gate** | A district just settled | Let them stay (people, but grievance) / move them on (a Command roll; disaster: a riot) / pay them to leave (wealth) |
| **A road ambush** | During a Trade Run | Fight (Command), pay the toll (lose some goods, certain), turn back (lose the trip) |
| **Bad stock** | Food short, or random | Eat it (risk of fever across the shelters) / throw it out (certain loss) / sell it on (a Cunning roll; disaster: a name for cheating) |
| **A stranger with news** | Pulse | Hear them out (a rumour of land; may be bait for a raid) / ignore |
| **A burst main** | A district with high ruin | Repair now (materials, certain) / patch it (cheaper, may fail later: a chained follow-up) |
| **The council splits** | Council loyalty low | Side with one / buy them off (wealth) / dismiss one (a loyal man gone, a rival made) |
| **Raiders' envoy** | After a raid on you | Pay tribute (certain) / refuse (a Command roll; disaster: they come back harder) / counter-offer (Diplomacy) |
| **The harvest festival** | A good season / many districts fed | Throw a feast (wealth, grievance down, renown) / skip it (people mutter) |
| **A deserter's word** | A captain unhappy | Pardon / punish (loyalty of the others) |
| **Strain at the edges** | Over reach | Send officials (a Stewardship roll) / loosen the rules (grievance falls, tribute falls) / press on |
| **A death in the family** | A leader's relative dies | (Exists as Mourning, now with a cost: a funeral costs wealth; hurrying it costs loyalty) |

## Data shape (so the content can grow without new code)
Events stay in `data/events.json`. An option gains optional parts: `cost`, `risk` (skill, base odds, factors, the outcome tiers each with `effects` and `text`), `follow_up` (an event id and a number of days), and `journal` text. A trigger gains `during_venture`, `district_if`, `faction_if` (reusing the requirement conditions Ambitions and Decisions already use). `GameData.validate()` checks all of it, as it does now.

## Rules check
- **Hard rules:** no new verb (an event is not an action on the world); all randomness through `city.rng`; the AI plays by the same rules and odds; no fantasy.
- **Spine:** strengthens the loop (every stage can surprise you) and the arc (the events and their consequences are where traits and stories come from).
- **No dead ends:** a locked option names what is missing; a safe option usually exists.
- **Decision log:** one entry to record the retirement of "event options cost nothing" (written with this doc).

## Build slices (each playable on its own)
1. **E1. Stakes.** Option costs, risk with tiers and shown odds, and the first six events from the table, rewritten from today's. Needs a small change to how an event option is applied and shown. No save change beyond pending events (to be checked).
2. **E2. Triggers.** During-venture and situation triggers; passive events; the venture journal; the yearly caps. Save version bump.
3. **E3. Chains.** Follow-up events and the rest of the starter set.
4. **E4. Pictures.** The picture slot.

## Open questions for the owner
1. Should a risky option's loss ever kill a named character outright (the same rules as ventures), or only injure?
2. How many prompting events a year is too many (my suggestion: 4 a year at the start, up to 10 for a large faction)?
3. Should passive events be hidden from the pop-up queue but always in the log, or also marked on the map?
4. Is the starter set the right flavour (add, drop, rename)?
