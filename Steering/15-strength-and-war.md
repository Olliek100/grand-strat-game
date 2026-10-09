# Strength and War

Spine stages **P1 (strength over dice)** and **P2 (war goals and ultimatums)**, agreed as the next builds on 2026-10-02 (08-spine.md, "Owner's decisions"). Written the same day from the playtest notes. **Status: decided 2026-10-02 (see "Owner's decisions"). P1 and P2 built in v1.42 (see "Built"). Vassal houses get their own doc next, with doc 14's marriage slice.**

Paradox games are the reference for *patterns only* (06-paradox-reference-notes.md): HOI4's justified war goals, ultimatums and battles weighed by the forces on each side. We're not copying their maths.

## Why
The owner's notes, 2026-10-02:
- "The game is still running on gambling, not accounting for the strength of a faction." More manpower, better command and more arms should make an assault easier.
- "Even with 82% I can still face a Disaster, opening my territory to be invaded easily."
- "The Rust Dogs seemingly randomly declared war, then Assault can be spammed to claim their territory." War needs a reason and a warning, like a casus belli and an ultimatum, with war only as the last step.
- "Defence doesn't gradually increase": the owner has to keep launching Safeguard.

## What happens today (checked in the code)

| | Today | The problem |
|---|---|---|
| **Assault odds** | 50% base, then a stack of multipliers: leader's Command (±5% a point), their control, defenders' traits, guards on site (your crew against theirs, up to ×1.4), your arms (+1.5% each, up to 20), their arms (-1% each), funding, faction traits | Your total strength never enters. A huge faction and a tiny one attack at much the same odds. The crew you can send is capped at 12 |
| **Disasters** | Possible below 90%. An assault Disaster kills 45% of the crew sent and adds war exhaustion | At 82% a Disaster is still possible, and it loses nearly half your attackers, which leaves home thin |
| **Defence** | Control (passive only up to a cap, then Safeguard), Watchtower, arms, guards posted by Reinforce | Nothing builds up just by holding land well; defence is a stack of things you keep doing |
| **War** | The AI picks a weaker neighbour it dislikes, posts "massing on your border" in the log, and declares 15 days later. Two successful assaults take a district; land taken stays taken | No reason given, a warning that's easy to miss, no demands first, and no limit on what a war is for |

---

## P1. Strength over dice

**The idea:** for raids and assaults, the **balance of force** sets the odds. Dice still decide, but within a range the forces allow. Everything else (traits, ambitions, government, emboldened raiders) stays as smaller adjustments on top, listed after the force.

### 1. Attack force against defence force
- **Your attack force** = the crew you send × how well armed they are × how well they're led.
  - Armed: each crew member counts more for each arm the venture carries (arms are already spent on Raid and Assault; you choose how many, up to a cap).
  - Led: the leader's Command, as now, but as part of the force rather than a separate factor.
- **Their defence force** = the district's **garrison** (new, see 2) + guards posted by Reinforce, × their arms × their buildings (Watchtower) × their control.
- **Odds from the ratio** (a smooth curve, tuned in simulation):

| Your force : theirs | Success (about) | Disaster |
|---|---|---|
| 1 : 2 | 20% | up to 25% of failures |
| 1 : 1 | 50% | about 10% of failures |
| 1.5 : 1 | 70% | none |
| 2 : 1 | 85% | none |
| 3 : 1 | 95% | none |

- **The assault crew limit is your idle manpower** (owner's decision, to trial; was a flat 12), so a big faction can commit a big force. The price is bodies away from home; garrisons (2) keep home from being empty. Tuned in simulation: if all-in assaults dominate, cap it at a share of manpower.
- Raids use the same rule with lighter numbers: a raid wants loot, not a fight.

### 2. Garrisons: defence that grows by itself
- Every district you hold has a **garrison**: the fight it puts up with nobody posted. It grows a little each day toward a ceiling set by the district's **population, control and buildings** (a Watchtower raises the ceiling).
- A raid or assault knocks it down, win or lose; it recovers over the following weeks. Safeguard the Shelter and Reinforce speed the recovery or add on top.
- **Population fills the garrison first; manpower comes from what's left** (owner's decision). Each district's people first keep its garrison up to its ceiling; of the population beyond that, a share becomes manpower, as today's recruiting does. So a district whose garrison was knocked down by a raid sends fewer recruits until it has rebuilt its defence: defence and manpower draw on the same people, and a well-defended, populous district gives both.
- Shown on the district panel as "Garrison 14 / 20" (hover: what sets the ceiling, how fast it's recovering), in place of today's Defence %.

### 3. Outcomes scale with the gap
- **No Disaster at 1.5 : 1 or better.** Below that, Disaster's share grows as you're outnumbered.
- **A Disaster costs crew and time, never land.** Losses scale with the gap (badly outnumbered: heavy; nearly even: light). Exhaustion as now.
- **Winning is bloody when it's close:** a success at even odds still loses some crew; at 3 : 1 almost none.
- How cleanly a success went still scales what it brings (doc 11, A.3).

### 4. Readable before you commit
- The planner leads with the force: **"Your force 24 against their 15 (1.6 to 1): 74%"**, each side broken down on hover.
- "To raise it" names the force levers first: "Send 6 more crew (→ 2 to 1, 85%)", "Carry 10 more arms".
- If they can still reinforce before you land, it says so (doc 11, B.1).

### 5. The AI
Same rules. The AI sizes its crew to reach a target ratio (bolder factions accept worse), and won't assault below 1 : 1 unless desperate. Its defence comes from the same garrisons.

### P1 is done when
- **Simulation:** a side with twice the force wins about 9 assaults in 10 with no Disasters; at even force about half, with Disasters around 1 in 20 attempts; raids per game don't jump; speed holds.
- **Playtest:** "I lost because I was weaker, and I could see it."

---

## P2. War goals and ultimatums

**The idea:** no war without a goal, a reason the target can see, and a demand they can accept. War is the last step.

### The sequence
1. **Justify a war goal** (Diplomacy, on the target's panel). Pick the goal; it takes days. **The target is told at once** in the top bar, with the goal, the reason and the days left. **Costs renown and wealth** (owner's decision), more for a bigger goal; while you're justifying, everyone who notices thinks a bit less of you.
2. **Ultimatum.** When the claim is ready, you send it: the goal's terms and a **deadline** (about 15 days). For the player this is a pop-up that pauses the game, showing the terms, the force on both sides, and who would join each side.
3. **They accept:** the terms take effect now, with no war. **They refuse, or the deadline passes:** war, fought over that goal.
4. **Peace:** when the attacker's war score reaches the goal's price, they can enforce it. Either side can offer a white peace (the claim lapses, 120-day truce). If the defender wins (the attacker is exhausted first), the attacker pays and can't justify against them again for 2 years.

### The three war goals (owner's definitions, 2026-10-02)

| Goal | Who it's for | Justify | Ultimatum demands | War won when |
|---|---|---|---|---|
| **Claim a district** | Any neighbour; one district on your shared border | ~30 days | Hand over the district. Accepted: it changes faction at once | You take it by assault (or war score 40) |
| **Subjugate** | A faction under about 60% of your strength | ~60 days | Become our subject: you keep your land and your ruler and run your own affairs, but pay tribute in **food, materials and wealth**, and make **no diplomacy except marriage and trade**, and **no wars** | War score 70 |
| **Vassalize** | A faction under about 40% of your strength | ~90 days | Join us: your land merges into ours, and your ruler and family become a **vassal house inside our faction** | War score 100, or their home district taken |

- **Subjugate** is today's vassal treaty made stricter: tribute in all three resources (not a share of income), and their foreign policy is yours apart from marriage and trade. They can't start wars, but they **join their suzerain's wars with about half their force**. A subjugated faction is a **tributary**.
- **Vassalize** absorbs them, like today's "Integrate vassal" but by force. Their ruling family isn't erased: it becomes a house in your faction. **What a vassal house does inside your faction is a design of its own** (does it hold its old districts? have loyalty that can turn into a revolt? marry into your family?). It ties into doc 14's dynasties and the civil-war arc. Until that's designed, P2 builds Vassalize as: land and people merge into yours; the ruler and family join your faction as family members with lowered loyalty.
- These names swap today's game words: the existing "vassal" treaty becomes **Subjugate** (a subject), and **Vassalize** means absorbing them.

### Reasons (casus belli)
A reason shortens the justification and spares you the opinion penalty with onlookers:
- they raided you, or demanded tribute of you, in the last 90 days;
- they hold a district you held within the last 2 years;
- border tension (their opinion of you below -25);
- later: a claim through marriage (doc 14 slice 4).

Without a reason you can still justify, but it takes twice as long and everyone thinks less of you. That's the hook for S6's aggression memory and coalitions.

### War score
One bar both sides can see, from -100 to +100: districts taken (the goal's districts count double), assaults won and lost, raids during the war, and the gap in war exhaustion. Shown in the war's alert and on both factions' Diplomacy panels.

### Fighting the war
- Once a war starts, **both sides can raid and assault** across their shared border, as now; assault is how land changes hands.
- **Claim a district:** taking the claimed district by assault wins the war.
- **Subjugate, Vassalize:** each district taken counts toward the score, and land taken stays taken.
- What stops the "Rust Dogs at war out of nowhere, then Assault spam" problem is that no war starts without a justified goal, a warning and a refused ultimatum, and that P1's force ratio makes spamming assaults with a small crew a losing move.

### Raiders, demands and civil wars
- **Raids stay outside war.** A raid needs no goal: it's harassment, with the cooldowns and tribute of doc 10. Raiders' tribute demands are unchanged.
- **A civil war** starts at once (no ultimatum: the split *is* the refusal), with Vassalize (merging the split back) as both sides' goal.

### The AI
The same steps, in the open. Its choice of goal follows the strength gap and its traits (Militaristic factions justify more, Diplomatic ones prefer Subjugate, the lighter goal). It answers an ultimatum by weighing the force on both sides (allies included), the severity of the goal and its opinion of the attacker. Its card in Diplomacy shows what it's justifying and against whom.

### P2 is done when
- **Simulation:** no war starts without a justified goal and a refused ultimatum; some ultimatums are accepted (no war); wars end by their goal more often than by exhaustion.
- **Playtest:** the player always has the warning in the top bar, with a reason and a timer, at least 30 days before a war can start.

---

## What this replaces
- **Decision log 2026-09-24:** "War is declared (with a cost)… The AI telegraphs war 15 days ahead." Replaced by justification → ultimatum → war.
- **Doc 11, A.1:** the "your crew against their defenders" factor folds into the force ratio.
- The **Defence %** chip on the district panel becomes the Garrison.
- The **Declare war** button becomes **Justify a war goal**.

## Owner's decisions (2026-10-02)
1. **Subjugate and Vassalize as defined above** (inverted from the first draft): Subjugate = a tribute-paying subject that keeps its land and ruler but has no diplomacy except marriage and trade, and no wars; Vassalize = their land merges into yours and their ruler becomes a vassal inside your faction.
2. **Claim a district:** accepted, the district changes faction; refused, war, with raids and assaults, and assault takes the land.
3. **Justifying costs renown and wealth.**
4. **The assault crew limit follows manpower** (trial).
5. **Population fills garrisons first; a share of the rest becomes manpower.**
6. **Two builds:** P1 first, played, then P2.

7. **Who fights in whose wars** (2026-10-02):
   - **Tributaries** (subjugated factions) **join their suzerain's wars automatically, with a fraction of their force** (about half).
   - **Vassal houses** (inside your faction, after Vassalize) **don't join automatically.** The liege can ask; the vassal is free to decline, and joining must give them something (for example a share of loot or land taken, renown, or loyalty earned).
8. **Vassal houses** (2026-10-02): a vassal house **holds its old districts**, has **loyalty that can turn into revolt**, **marries into your family**, and **marries other factions' vassal houses**.

## Where vassal houses fit
Vassal houses are the dynasty idea (doc 14) applied to land: houses inside a faction, each with its own districts, loyalty and marriages. That's the "gangs become the great houses of a rebuilt city" in the agreed spine sentence, and a new path into the civil-war arc (a disloyal house revolts with its districts). It's too big to fold into P2, so:
- **P2 builds the simple version:** after Vassalize, their land joins yours and their family joins yours with lowered loyalty.
- **Vassal houses get their own design doc and build after P2**, together with doc 14's marriage slice (marriage between houses needs both). It answers: how a house holds districts (what it pays you, what you can still do there), how its loyalty is set and shown, how a revolt starts and what it takes, and how a call to arms and its reward work.

## Logged in the decision log (2026-10-02)
1. **Strength before dice:** for raids and assaults, the force ratio sets the odds; no Disaster at 1.5 : 1 or better; a Disaster costs crew and time, never land.
2. **Garrisons:** every held district defends itself, growing with population, control and buildings.
3. **War needs a justified goal and a refused ultimatum** (replaces 2026-09-24).
4. **The three war goals** as defined above (agreed 2026-10-02).


## Built
- **P1 (v1.42):** force-based odds for Raid and Assault, garrisons, no Disaster at 1.5 to 1, losses scaled to the gap, assault crew up to all idle manpower, the planner and buttons leading with the force, the AI sizing fights to 2 to 1. Differences from the text above: the crew is armed from your stock automatically (no choice of arms per venture); control strengthens a garrison rather than enlarging it (the ceiling is 8% of the district's people); the AI never attacks while outnumbered (no "unless desperate" yet). Measured in CHANGELOG.md.
- **P2 (v1.42):** war goals (Claim a district, Subjugate, Vassalize) justified in the open with renown and wealth, ultimatums with a 15-day deadline (the player's in Proposals, with a pop-up), war score, wars ending on the goal's price, a worn-out side losing, or a white peace; tributaries trade only, pay food, materials and wealth, and fight with half their force; the AI follows the same steps. Differences from the text above: the ultimatum goes out by itself once justified; "they hold land you held" isn't a reason yet; civil wars still have no goal; Vassalize brings the ruling family in as ordinary members with lowered loyalty (vassal houses come later). Measured in CHANGELOG.md.
- **Owner's changes to P2 (2026-10-04, built):** the "Who it's for" strength limits and the justify days in the goals table above are replaced: no strength gate (any neighbour, any goal; the AI keeps the gaps as its own judgement), months to justify (180 / 270 / 360 days with a reason, half as long again without), 60 days to answer an ultimatum, each raid by the target brings it 30 days sooner, a reason halves the cost, treaties and truces can be broken to press a claim at -30 opinion with everyone (fading over years), the claimant's allies join its war, and the 2-year ban after a failed claim is gone. See the decision log, 2026-10-04.
