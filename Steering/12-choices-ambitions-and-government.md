# S4 Choices: National Ambitions and Government

What S4 builds: chosen National Ambitions paid for with renown, and government reforms that change how a faction is run and how it breaks. Written 2026-09-28 from the spine (08), the outline (07 §3, §6), the UI plan (09 §5) and the game as of v1.39. **Status: decided 2026-09-28; S4a and S4b built in v1.40 (see "Built" at the end). S4c (portraits) parked.**

**Spine goal for S4:** "You pick a direction and can say what it costs you."

## Spine check
- **The arc (pillar 5):** governments change who succeeds and how a faction breaks. A mature state trades one risk for another; it doesn't remove risk.
- **The loop:** renown finally has a use. Deeds earn it, and ambitions spend it for a lasting return. Ambitions and reforms are the first real way to invest at home, which is the tall side of doc 11's tall/wide split. Tech stays after the playbox.
- **Pillar 2:** what a faction can choose is gated by its traits and situation, never picked from a tree. Each faction's options are its own, drawn from one pool in data.
- **Pillar 3:** every AI faction's current ambition and government show on its diplomacy card. The AI scores them on the same one list as ventures and buildings (doc 11, D.2).
- **Not-doing list:** one shared pool and a small set of reforms, both unlocked by state. That's the 2026-09-25 amendment exactly. No per-faction trees and no fixed branch to memorise.

## What exists today
- **21 automatic milestones** (data/ambitions.json: "Hold 8 districts", "Own a Workshop"…). Each pays 5-20 renown once. No choice involved.
- **Renown** comes from those milestones and from triumphs (+2 each). It passively raises:
  - the crew limit, by 1 per 20 renown;
  - the captain limit, by 1 per 60;
  - recruits' skill, up to +2;
  - the heir's claim, by renown ÷ 10;
  - treaty acceptance and other factions' respect.
- **Succession** has one rule, Warlord (built in S3):
  - the heir is the named heir, else the eldest child, the spouse, then family, then the strongest councillor;
  - contesters are councillors or family with loyalty under 40 or the Ambitious trait;
  - a failed succession splits off 30-45% of the land as a new faction at war with the old one.

---

## Part 1: National Ambitions

### How they work
- **One active at a time.** Starting one costs **renown** (and sometimes resources). It runs for a stated time, with a progress bar. When it finishes, a **lasting bonus** applies for the rest of the game.
- **Deterministic, like construction.** No odds and no tiers: you're investing, not gambling (consistent with "construction stays deterministic"). Some ambitions have a **condition while running**, shown on the card (e.g. "stay at peace"). Break it and the ambition fails, and the renown is lost.
- **Gated by your situation:** traits, government, treaties, what you hold, what has happened to you. Cards you don't qualify for show what's missing and where to get it (spine rule 5: no dead ends).
- **Some pairs are mutually exclusive.** Taking one closes the other for good, and the card says so.
- **Some unlock a government reform** (07 §6). That's the bridge between the two halves of S4.

### Renown: earned by deeds, spent on ambitions
Once renown is spent, its passive effects can't stay tied to the balance you hold, or spending it would shrink your crew limit. Proposal: **split it in two, both visible in the top bar hover.**

| | What it is | What it does |
|---|---|---|
| **Reputation** | Every point of renown you've ever earned. Never goes down | Everything renown does today (crew and captain limits, recruit quality, the heir's claim, respect) |
| **Renown** | What you have to spend | Starting ambitions and some reforms. Unspent renown still gives a **minor** diplomacy bonus (decided 2026-09-25) |

The milestones stay as the renown source, renamed **Deeds**. That keeps the "Earned by deeds" row in the spine's resource table, and it means spending never runs you dry (spine rule 5). They move to a second tab of the Ambitions window.

### Starter pool (12; the doc 07 target is about 30 over time)

| Ambition | Kind | You qualify when | Cost | Time | Lasting bonus | Closes |
|---|---|---|---|---|---|---|
| **A Name to Fear** | War | Militaristic | 25 renown | 60 days | Raids and assaults +10%; demands for tribute more likely accepted | Good Neighbours |
| **Good Neighbours** | Diplomacy | 2 treaties, or Diplomatic | 25 | 60 | Treaty acceptance +15%; every neighbour's opinion +10 | A Name to Fear |
| **Open for Trade** | Trade | Merchant, or own a Market | 30 | 90 | Trade income +25%; Trade Runs +10% | — |
| **Walls and Watches** | Order | Raided or at war in the last 90 days | 20 | 45 | Attacks on all your districts x0.9; Watchtowers build in half the time | — |
| **Feed the City** | People | Food short (under +0.5 a day), or Socialist | 20 | 60 | Food +10% in every district | Every Hand a Soldier |
| **Salvage Rights** | Build | 3+ districts and materials under 30 | 20 | 45 | Scavenge yields +25% | — |
| **A City Again** | Build | 4+ buildings | 40 | 120 | +1 building slot in Secured districts (the first tall ceiling-raiser) | — |
| **Loyal Lieutenants** | People | A councillor under 40 loyalty, or civil war risk 30%+ | 25 | 60 | Council loyalty +10 (lasting); split chance at a succession x0.75 | — |
| **Every Hand a Soldier** | War | Militaristic and 6+ districts | 35 | 90 | Manpower limit +20% | Feed the City |
| **Welfare for All** | Order | Socialist | 30 | 90. **While running:** no raids launched | Grievance falls 0.05 a day everywhere; **unlocks the Politburo** | — |
| **The Strongman's Crown** | Order | Leader with Command 7+, or Conqueror | 40 | 90 | Leader's claim +20 for the heir; **unlocks Autocracy** | — |
| **Charter the Guilds** | Trade | 3 trade agreements, or Merchant and 2 | 40 | 90 | Trade +10%; **unlocks the Merchant Oligarchy** | — |

Lasting bonuses reuse blocks that already exist (venture odds, trait-style effects such as wealth_income_mult and defence_mult, opinion baselines, building slots, manpower limit). Each bonus is an effects list in data, applied the way trait effects are. There's no new mechanic per ambition.

### The AI
- It scores "start ambition X" on the same one list as ventures and buildings: the value of the bonus in its situation × its trait leanings (for example, Militaristic weights War ambitions). So pursuing an ambition competes with expanding.
- Its current pick shows on its diplomacy card: "Pursuing: Walls and Watches, 30 days left".

---

## Part 2: Government

### Governments

| Government | Who starts here / how you get it | Succession | How it breaks (pillar 5) | While in power |
|---|---|---|---|---|
| **Gang** (new) | Every **minor** faction starts here | The strongest takes it; no named heir | Very fragile: split chance x1.3 | Only one reform on offer: "Become a Warlord crew" (4+ districts and one ambition completed). The junkies-to-warlord climb from the spine |
| **Warlord** | Every major faction starts here | Today's rule (above) | Fast, fragile | As now |
| **Autocracy** | Reform "Crown a Strongman": completed The Strongman's Crown, 10+ districts. 40 wealth + 20 renown | The named heir gets +25 claim; contesters need loyalty under 30 | **Rarer splits, bigger ones:** a split takes 45-60% of the land | Command ventures +10%; council wages -25%; treaty acceptance -10% |
| **Politburo** | Reform "Form the Party": Socialist, completed Welfare for All. 30 wealth; every non-Socialist councillor loses 10 loyalty | The council elects its strongest, most loyal member | **Purges instead of civil wars:** a contester is expelled (joins a rival or leaves), and the others lose 10 loyalty. No land splits | Grievance lower; wealth income x0.9 |
| **Merchant Oligarchy** | Reform "Charter the Guilds": Merchant, completed Charter the Guilds. 60 wealth | The best Stewardship councillor | **Bribery:** at a succession the faction spends wealth to calm contesters (each 50 wealth cuts split chance by a quarter, up to half its treasury). Poor oligarchies split | Trade +20%; raids -10% |
| **Democracy** | **Only at a leader's death:** the succession pop-up offers "Hold elections" if average grievance is under 30, the faction isn't at war, and it has 3 treaties | An election among the council (skill + loyalty, with some chance), after a **30-day caretaker** period of -10% venture odds | Slow, safe: split chance x0.5. **Gridlock:** ambitions take 50% longer, reforms cost double | Opinion of you +10 with everyone; council loyalty steadier |

### Reforms
- **Decisions, not ventures:** a cost, a deterministic result, and a **transition**: 60 days of grievance +10 in all districts and a loyalty test. The not-doing list amendment already frames reforms as "a small set of decisions unlocked the same way".
- **Hard to reverse:** another reform can't be taken for 2 years.
- **Council approval** (the S3 loose end: council agendas). Each councillor **backs or opposes** a reform according to their traits. For example, Ambitious and Cruel back Autocracy; Kind backs the Politburo; Greedy backs the Oligarchy. The card shows who's for and against. Taking a reform they oppose costs their loyalty. Under the Politburo, the Oligarchy and Democracy, the council **votes**: a majority against blocks the reform (07 §2.5).
- **The AI** scores reforms on the same one list and takes them when it qualifies and its traits lean that way. Its government shows on its card.

### Portraits that change with government (parked in the spine for S4)
Optional, and last: extra portrait layers keyed to government. A Warlord looks as now; an Autocrat gets the white shirt, gold chain and sharp cut from the user's idea; a Politburo leader a plain jacket; an Oligarch a suit. The layered drawing makes this a set of layers, not a new system.

---

## UI (09-ui-plan)
- **Ambitions window (F5)**, as planned in 09 §5.
  - Tab **Ambitions:** cards grouped by kind. Each card shows its cost, time, requirements (ticked or with what's missing), bonus, what it closes, and any risk in red. The active one has a progress bar.
  - Tab **Deeds:** the milestones.
- **Realm window, new tab Government:**
  - the current government and its succession rule in one line;
  - reforms on offer, with requirements, cost, transition, and who on the council backs or opposes each.
- **Faction card (Diplomacy):** government, current ambition with days left, and completed ambitions as chips.
- **Top bar:** Renown shows what you have to spend; its hover shows Reputation and what each does.
- How each system works goes in tooltips on the tab titles, per the UI rules.

## Build order
1. **S4a, Ambitions:**
   - the reputation/renown split;
   - Deeds;
   - the 12 ambitions and their effects in data;
   - the Ambitions window;
   - AI scoring;
   - showing it on the faction card.
2. **S4b, Government:**
   - the Gang government and the four new governments with their succession rules;
   - reforms with transitions and council approval;
   - the Government tab;
   - AI scoring.
3. **S4c (optional):** portraits by government.

## Checks (simulation and play)
- **By year 4, every surviving faction has completed at least 2 ambitions**, and no single ambition is taken by more than half of them (a variety check).
- **At least one reform per 4-year game;** at least one minor faction becomes a Warlord crew in some games.
- **Civil wars stay at 0.5+ per game**, while purges and Oligarchy bribes show up as their own events.
- **Speed** stays within the budget.
- **In play:** "I picked X and I can say what it cost me."

## Needs a decision-log entry before building
1. **Renown splits into Reputation (lifetime) and Renown (spendable).** It changes a resource the spine describes.
2. **Milestones are kept as Deeds,** the renown source. The spine's parked list says automatic milestones are "to be replaced by chosen ones"; this proposes keeping them alongside, as the income.
3. **The Gang government for minors,** a new rung below Warlord.
4. **Gates that 07 tied to tech are replaced by situation,** since tech is after the playbox. For example, Democracy needed "a civic tech"; here it needs low grievance, peace and 3 treaties.
5. **Democracy is only reachable at a leader's death** (as 07 says). Recorded because it's the only reform with a timing rule.
6. **Politburo purges instead of splits.** It changes what "collapse" means for one government. It fits pillar 5, but it's a new outcome.

## Decisions for the owner
1. **Reputation/Renown split:** yes, or keep one number and accept that spending renown shrinks your crew limit?
2. **Ambitions deterministic** (a cost and a timer, like construction), or run as ventures with odds?
3. **Starter pool:** are these 12 the right flavour? Add, cut or rename freely.
4. **Council approval and votes in S4b,** or leave agendas for later?
5. **S4c portraits:** in S4, or parked again?

## Owner's decisions (2026-09-28)
1. **Reputation/Renown split: yes.**
2. **Ambitions are deterministic** (a cost and a timer, like construction).
3. **The first 12 ambitions are fine.**
4. **Council approval: yes.** Councillors back or oppose reforms, and vote under the Politburo, the Oligarchy and Democracy.
5. **Portraits by government: parked**, not needed yet.

## Built in v1.40 (where it differs from the draft)
- **Democracy's timing:** "Hold Elections" is on offer for 30 days after a leader's death, from the Government tab, rather than as a choice inside the death pop-up.
- **A gang's reform** ("Become a Warlord crew") costs 10 renown; the draft named no cost.
- **Everyone else can reform to any of the four** once they qualify (Autocracy, Politburo, Oligarchy, Democracy); nobody reforms back to Gang or Warlord.
- **The AI** weighs reforms, ambitions and buildings together as "what to do at home" against its ventures. A gang is keen to become a Warlord crew; after that, its traits lean it (Militaristic to Autocracy, Socialist to the Politburo, Merchant to the Oligarchy).
- **Result (4 games x 4 years):** governments at year four: 4 Warlord, 5 Oligarchy, 5 Politburo, 2 Autocracy, 1 Democracy; every surviving gang became a Warlord crew; about 8 reforms a game; civil wars 1.0 a game. Ambitions completed per faction by year four: 4-9. Purges and bribes didn't happen in these games (the governments came late and their successions were rarely contested); both are covered by tests.
- **Watch:** Walls and Watches and Feed the City are taken by almost everyone (easy gates); their AI weight was lowered. Every Hand a Soldier was rarely taken.
