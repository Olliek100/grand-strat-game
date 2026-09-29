# Earned Odds and Pace

Why ventures feel like gambling, why the game feels like a race, and what to change. Written 2026-09-27 from the v1.39 playtest and an audit of the code, measured in simulation. **Status: decided 2026-09-27 (see "Owner's decisions" at the end). A, B.1-B.2, C and D.2-D.5 to build in v1.39; B.3 and D.1 not now.**

Paradox games are the reference for *patterns only* (see 06-paradox-reference-notes.md). We're not copying their maths.

## What's already planned (so this builds on it rather than duplicating it)
- **Government reforms** (07 §3; spine S4): decisions unlocked by behaviour, costing wealth, renown or loyalty, with a transition of instability. Each government changes the succession rule and the risk profile (pillar 5).
- **A tech web on a new Knowledge resource** (07 §7): 20-30 techs over 3-4 eras. They unlock buildings, ventures, reforms, National Ambitions and culture policies. Research slows in war and is shared through trade. **Placed after the playbox, "likely vertical slice"** (decision log, 2026-09-25).
- **National Ambitions** (07 §6; spine S4): a shared pool, gated by situation, with renown invested for a lasting bonus.
- **Incentives against war** (07 §5): aggression memory and coalitions (S6), research needing peace, trade sharing knowledge.
- **Construction stays deterministic** (07 §4.5): no tiers.

Your hypothesis (internal development competing with external ventures for the same resources, for AI and player alike) is what reforms, tech and ambitions were meant to become. **What's missing is the timing and the shared budget.** Tech is placed too late to shape the pace, and nothing today makes internal and external spending compete.

---

## Audit 1: how odds work, and how far preparation goes

**The formula** (venture_system.gd): base × every factor, clamped to **5-95%**.

| Lever | Effect | Range |
|---|---|---|
| Leader's skill | ±5% a point from 4 | Skill 10: ×1.30 |
| Leader's traits | Veteran, Scarred, Brave… | ×0.92 to ×1.08 each |
| Council seat for that skill | ±2% a point from 4 | Skill 10: ×1.12 |
| Faction leader's ruling trait | Builder, Conqueror | ×1.10 |
| Faction traits | Militaristic, Merchant… | ×0.9 to ×1.4 |
| Crew above the usual | +6% each | Capped at ×1.35 |
| Extra funding | +10% a level | 2 levels: ×1.20 |
| Target | Danger, control, Watchtower, defenders, arms, blind | ×0.5 to ×1.0 |

**Tiers.** Triumph is 6% + 2% per skill point of the success chance. Disaster is 10% + danger − 2% per skill point of the failure chance.

**Measured, at day 200 in a test game** (your faction, with its real captains):

| Venture | No leader | Best leader, max crew, max funding |
|---|---|---|
| Scavenge | 80% | **95%** (disaster 0%) |
| Settle | 59% | **95%** (disaster 1%) |
| Safeguard | 62% | **95%** (disaster 1%) |
| Raid (defended district) | 23% | **45%** (disaster 22%) |

- **Near-certainty is reachable** for peaceful work. The AI reaches it all the time: **61% of all AI launches are at 85-95%** (2,542 of 4,163 over 3 games × 2 years). It always sends its best free captain.
- **Against a defended target, preparation tops out low.** Crew can add at most ×1.35, and nothing measures you against the defenders. So "overwhelming force" doesn't exist.
- **The player usually launches at 60-80%.** The planner defaults to the usual crew and no funding, and your best people are often wounded (v1.39: 1.8 of about 5.7 captains at once). At 70%, you fail about one venture in three. Over a session that reads as a coin flip, even though the levers are there.
- **Success is binary in size.** A success always gives the same amount; only a triumph adds a fixed bonus. Preparing well buys *whether*, never *how well*.
- **Failure is out of proportion.** A 6-day Scavenge setback can wound the leader for 30-60 days (30% chance). The cost of failing is mostly losing your captain for 5-10 times the length of the venture, whatever the venture.

## Audit 2: legibility before you commit

- **Odds are shown before commit**: the % on the button, the tier bar, and since v1.39 a plain breakdown with "To raise it" and the risk to the leader. Point 2 of your note is mostly covered.
- **But the odds can change after you commit, and nobody tells you.** A venture's odds are worked out again when it lands. **18% of aimed ventures (163 of 922) land at odds more than 2 points different from launch, on average 7.7 points worse**, mostly because defenders arrived (Reinforce). The reaction is by design (07 §4.2, "it can be reacted to"). The silence isn't: you committed at 70% and rolled at 55%.
- **Nothing warns you a target can reinforce** before you commit.

## Audit 3: does the AI pay for growing?

- **No hidden bonuses.** The AI runs on the same rules for odds, costs, succession, civil war, administration cost, grievance and hoard losses (pillar 3 holds).
- **The AI already spends most of its effort at home:** of 4,163 ventures, 2,795 were internal (control, food, weapons, rebuild), 1,036 external (scout, settle, scavenging new land) and 332 hostile.
- **But the city still fills in about a year and a half:** unclaimed districts average 34 at day 180, 14 at day 360, 2 at day 540 and 1 at day 720. That is the race.

**Why it's a race even though nobody cheats:**
1. **Land is the only thing that keeps compounding.** A district's own growth stops fast: development tops out at 100% and it has at most 2 building slots. Past that, the only way to grow is more districts. Tall has a ceiling; wide doesn't.
2. **Unclaimed land is first come, first served,** and it's gone by year two. Whoever settles first keeps it.
3. **Internal and external spending don't compete.** Building runs on its own timer out of spare wealth (above a reserve of 15). Ventures cost a captain's time and a few food or materials. Expanding costs almost nothing you would otherwise have invested at home, so there's no reason not to do both at full speed.
4. **The "internal tax" mostly bites at a death.** Administration cost grows with territory, but it's paid in wealth, which piles up by year two. Strain only really lands at succession.

**One tension with pillar 2 to flag:** minor factions carry an authored personality (raider, trader, hermit) that multiplies their goals. That's a faction-type flag, which your note wants to avoid. It came in v1.31 as content for the minors.

---

## Proposals

### A. Preparation buys certainty and quality (pillar 1: the same venture, better shaped)
1. **Outnumber the defenders.** For aimed ventures, a new odds factor compares your crew with their defenders on site, from ×0.8 (outnumbered) to ×1.4 (three to one). It replaces the flat crew bonus there. Overwhelming force can then push a raid on a defended district to 85%+. The price is bodies away from home, which is the point.
2. **Raise the ceiling to 98%**, reachable only when every lever is pulled. Keep the 5% floor.
3. **The roll decides how well, not just whether.** Every success scales its gains by how far the roll beat the odds: ×0.8 for a scrape, ×1.2 for a clean win. Triumph's share grows with the odds as well as skill. A well-prepared venture then shows up as bigger, cleaner results, which is the Paradox "bounded variance" pattern.
4. **Above 90% odds there's no Disaster.** A failure is always a Setback.
5. **The planner starts on the recommended plan**: the best free leader, crew to the point where extra crew stops adding much, and funding if you can afford it without dropping below a reserve. One click back to the cheapest plan. Launching at 70% should be a choice, not the default.

### B. What you see is what you roll (pillar 3)
1. **Warn before commit:** "They can reinforce: up to 4 defenders could arrive (−25%)" in the odds explanation, for aimed ventures.
2. **Tell you when odds change after commit.** The outliner shows the live odds on each venture, and the log says "Raid on Chapel Street: odds fell from 70% to 55%: 3 defenders arrived".
3. **Optional, later:** lock the odds at launch except for named reactions, so the only thing that moves them is something you were told about.

### C. Failure you can recover from (pillar 4 kept)
1. **Wounds scale with the venture's danger:** low-danger work (Scavenge, Settle, Secure Food) wounds for 10-20 days; raids and assaults 30-60. The setback wound chance scales with danger too (10-30%, down from a flat 30%).
2. Deaths stay rare and tied to Disasters, so mortality keeps its weight. What changes is that careful work stops costing your best people for months.

### D. Growing tall competes with growing wide (build on 07, don't add a new system)
1. **Pull a compact tech web into S4**, before the playbox gate. Keep it small: about 10 techs in 2 eras, not 20-30. Research is a project like construction (deterministic, no tiers, consistent with the decision log), paid in **wealth and materials, the same resources that fund expansion**, plus Knowledge. **Techs raise the per-district ceilings**: development above 100%, a third building slot, better yields, better defence. That makes tall compound. Knowledge comes from districts with libraries or hospitals and from Salvage-type ventures that find manuals, so ventures still feed it (pillar 1).
2. **Reforms (already S4) and research share one visible budget with ventures.** The AI scores "research X", "reform Y", "settle Z" and "raid W" on one list with the same weighted scoring, so choosing one means not choosing another. The player faces the same choice through prices, not rules.
3. **Tall or wide emerges from state, not a flag.** Traits already carry this: Builder, Merchant, Steadfast and a Socialist or Diplomatic lean weight internal goals; Conqueror, Militaristic and Ambitious weight external ones. Over time, **replace the minors' authored personality with the same trait weights** (a raider crew is a crew whose traits say "raid").
4. **Expansion costs something you'd otherwise invest.** Administration cost becomes wealth *and* materials, and a newly settled district starts restless (grievance +15). Tuned so the city is still about a third unclaimed at year one (it's 14 of 61 today) and fills around year three, not year one and a half.
5. **Show each faction's lean** on its diplomacy card: "Building up (70% of the last 90 days at home)" or "Expanding fast (60% abroad)". That makes a wide faction's weakness readable before you strike (pillar 3). A wide faction's thin development already means lower control and defence, and tech makes the gap wider.

**Order:** C and B.1-B.2 are small and fix the feel quickly. A is a formula change to test in `/sim` and in play. D is S4-sized and wants its own build.

---

## Needs a decision-log entry before building
1. **The 5-95% clamp** is written into 07 §4.3. Raising it to 98% and adding "no Disaster above 90%" changes a documented rule (A.2, A.4).
2. **Tech moves from "after the playbox / likely vertical slice" into S4** (D.1). That changes the agreed build order and the spine.
3. **Research as deterministic projects**: consistent with "construction stays deterministic", but a research venture (a Knowledge find) is a new venture using existing blocks. It should be named in the entry.
4. **Minor faction personalities** (raider, trader, hermit) are an authored type flag. Keep them as content, or replace them with trait weights (D.3)? Either way it should be written down.
5. **Wound rules** (C): pillar 4 is about mortality's weight, so shortening wounds should be recorded with the reason.
6. **A shared budget for the AI** (D.2) changes how the AI chooses. It isn't a pillar change, but it's a standing design decision worth logging.

Not needed: none of this adds per-faction trees or authored branches (not-doing list). The tech web is one shared web, which 07 already allows.

## Decisions for the owner
1. **A.3, success scaled by the roll:** yes? It's the core of "prepared means better outcomes", but it makes rewards vary.
2. **B.3, locking odds at launch:** now, or only warn (B.1-B.2) for now?
3. **D.1, tech in S4:** accept pulling a small web forward, or keep tech later and use reforms and ambitions as the only internal sinks for now?
4. **D.3, minors' personality:** keep it as content, or move it to trait weights?
5. **Pace target:** how full should the city be at year one? (Today it's 77% claimed; proposed about 65%.)

## Owner's decisions (2026-09-27)
1. **A.3, success scaled by the roll: yes.** It's the core fix.
2. **B.3, locking odds at launch: no, not yet.** Keep the warnings (B.1, B.2). Locking would remove the "it can be reacted to" intent from 07 §4.2 for a problem that being open about it already solves.
3. **D.1, tech in S4: deferred** past the playbox, as planned. Re-measure the pace after D.2 and D.4 first.
4. **D.3, minors' personality to trait weights: yes.** It's a known inconsistency; no reason to keep two systems.
5. **Pace target: about 65% claimed at year one, provisional** until D.2 and D.4 are tuned in simulation.

## Built in v1.39 (where it differs from the proposals above)
- **A.1 Outnumber the defenders:** x0.8 when outnumbered, up to x1.4 at three to one, replacing the flat crew bonus only when defenders are on guard.
- **A.5 Recommended plan:** crew until one more adds under 2 points, then funding while at least 20 wealth is left, stopping at 90%. A button switches to the cheapest plan and back. The AI launches with the same rule, so its launches are now mostly at 90%+ too.
- **B.1** warns in the odds explanation how many defenders the target could send (its idle manpower, up to a full guard of 12).
- **C** uses the venture's danger directly as the setback wound chance (10-30%); wound length slides from 10-20 days (danger 0.1 or less) to 30-60 (0.3 or more).
- **D.2** folds building into the AI's move: each move it picks the single best of all ventures and buildings. The separate build timer is gone.
- **D.3** puts the leanings in data/traits.json ("ai_goals"): Militaristic (raid x2, conquer x1.5, arms x1.5, expand x0.7), Merchant (buy x2, income x1.5, raid x0.3), Socialist (raid x0.3, control x1.3, develop and food x1.2), Diplomatic, Subversive, Slaver. "Raiders" means raiding weighs x1.5 or more. The Iron Wardens start Militaristic, so they now lean the raiders' way too.
- **D.4** administration costs 0.01 x (districts - 3)^1.7 materials a day on top of wealth; a new settlement starts at grievance +15.
- **D.5** the faction card shows its lean from a tally of moves at home and abroad that fades over about 90 days.
- **Pace so far (6 games x 4 years):** 71% claimed at year one (v1.38: 77%), not yet the provisional 65%. Doubling the materials share of administration barely moved it and made hunger worse, so year-one pace is set by how fast the early settling goes rather than by the running cost of land. The next lever would be the cost or length of Settle, which this doc didn't propose; to decide.
- **Watch:** high odds add at most +15% to the Triumph share. At +30%, more triumphs and fewer wounds kept captains so loyal that no civil war happened in 4 games (pillar 5).
