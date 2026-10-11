# 18. Diplomacy restraints: asking, backing, calling, coalitions (DRAFT for the owner to mark up)

Written 2026-10-11 after a playtest where two claims on the player were backed by five factions, none of whom had a reason, and the AI had asked every faction repeatedly until it got a yes. Structural findings from CK3, HOI4 and CK2 are in `06-paradox-reference-notes.md` (last section); this doc compares our menu against them and proposes the fix. Nothing here is built.

## The owner's decisions so far (this session)
1. **Pre-war backing stays**, as a way for factions with their own grievance against the target to stand behind a claim (a raided AI faction should want to back the player). Alongside it, factions at war call their allies and vassals in.
2. **Every ask gets a per-pair cooldown and a remembered refusal.**
3. **Every possible backer gets real stakes and hard blocks**, built so culture, ideals, actions (raided by the target, recent wars) and opinion can be added later.
4. **Pile-ons are capped and cost something.** A faction that wins big finds others won't trade or deal with it; coalitions may form against it.
5. **The claimant's timer is binding and visible**, and can be stopped (marriage, paying off, other outs).

## Owner's answers (2026-10-11)
- **Cooldown scale:** a year for gifts; 3-4 years for larger asks; longer again for the biggest (alliance, backing a war goal).
- **Volunteering:** yes. A faction raided or threatened by the raider, or otherwise better off if it is weakened, offers to back a claim against it without being asked.
- **Minimum notice:** 90 days, as a playtest value (an early ultimatum can't arrive sooner than 90 days after the target is told).
- **Paying off a claim:** a small payoff is a neutral deal; it is a *defeat* (a memory others see) only if the target gives up the district or similar.
- **Notoriety:** from conquest that is unjustified (for example declaring on a friendly faction that never raided you), and also from raids, broken pacts and the like. Higher notoriety alienates the faction.
- **Who is restrained first:** the AI strictly; the player gets cooldowns too but lighter (the player doesn't run things as effectively as the AI).

## 1. Our menu against Paradox's

Our actions are the ten in `data/diplomacy.json` plus the war flow (justify a goal, send early, withdraw, ultimatum, peace). Each row says what limits the Paradox version and where ours leaks.

| Ours | Paradox equivalent | What limits it there | Gap in ours |
|---|---|---|---|
| Send gifts (envoy) | CK3 gift; HOI4 lend-lease | cost, opinion caps, cooldowns | no per-pair cooldown; the AI may repeat |
| Trade agreement | HOI4 trade deals | resource limits, both sides need something | repeatable renewal asks; nothing blocks trading with a pariah |
| Non-aggression pact | HOI4 NAP | breaking it costs tension and support; CK3 uses truces | breaking costs opinion only |
| Defensive alliance | CK3 negotiate alliance, then join war; HOI4 factions and guarantees | cooldown per pair; accepting is judged on stake; refusing an ally costs prestige and opinion; HOI4 guarantee cost rises with each one given | **allies join automatically** at war start (`call_to_arms`); no accept check, no refusal cost |
| Demand submission / Vassalize / tributary | CK3 offer vassalization, demand tributary, become tributary; HOI4 puppet | acceptance by strength and opinion; cooldown | fine in shape; no cooldown |
| Propose a match | CK3 arrange marriage | cooldowns, acceptance, family distance | already limited by who is free; no cooldown |
| **Ask them to back your claim** | no direct equivalent: CK3 claimant and other factions are joined by members' own score (blockers, opinion of target, power); calls to arms happen inside a war | members join on their own stake; the leader doesn't poll everyone | **the whole problem**: any faction can be asked, with a flat base chance; no blockers; the AI asks again and again |
| Demand tribute / Pay tribute | CK3 exact/demand tributary | opinion, strength, cooldown | AI demands on a short cycle; fine otherwise |
| Justify a war goal | CK3 casus belli; HOI4 justify | HOI4: cost rises with each nation at war or justified against, visible threat builds as it goes | announced time isn't binding (send early); no cost for stacking claims |
| Send ultimatum / accept or refuse | HOI4 demands; CK3 has none | n/a | only two answers, no outs |
| Peace / white peace | CK3 offer peace, war score; HOI4 peace conference | the AI is reluctant early in a war | fixed this session (standing offers) |
| Call a house to war | CK3 call house member | each may decline | ours has this: the model to copy |
| (missing) coalition / tension | HOI4 world tension; CK2 coalition interaction (defines only, not read in depth) | aggression raises others' hostility | none: a runaway conqueror is treated like anyone |
| (missing) guarantee / defend the target | HOI4 guarantee | third parties take the target's side at a cost | the target has no equivalent of asking its friends to stand behind it |

**Where the AI can repeat an ask today:** the AI's diplomacy turn (`faction_ai.gd`, every 8-15 days) scores every action against every faction by *want x chance* and takes the best. The best score is the highest-chance ask, so an ask refused yesterday is nearly the first thing tried again. There is no per-pair or per-action memory. This applies to **all ten actions**, not just backing.

## 2. Proposed design

### A. Asks (all actions)
- A **per-pair, per-action cooldown** after any ask, longer after a refusal, longer again if refused repeatedly (a "pestering" opinion memory that fades slowly). Values to tune; Paradox's are years for the same pair, for us probably a game year or two.
- A **remembered refusal**: the refuser holds an opinion memory of the asker's repeated asks, so asking again makes a later yes less likely, not more.
- The AI considers a short **target list** (neighbours, partners, friends, enemies of its enemies), not every faction.

### B. Backing a claim, in two directions
1. **Volunteering (the main route).** When a claim starts, every faction judges it once, then again now and then, by a **stake score**:
   - *hard blocks* (never): tied to the target by treaty or marriage; no border or contact with either side; already at war with the claimant; backing would break its own pact; at war with someone else and stretched.
   - *for*: raided or threatened by the target lately; opinion of the target low; ally or friend of the claimant; the target is a faster-growing rival.
   - *against*: opinion of the claimant low; claimant is the faster-growing rival; claimant has raided them lately.
   - Culture and ideals are slots in the same list, empty for now.
   The volunteer is shown to the claimant as an offer ("the St Brigid's Ward will back your claim: accept?"), so the player decides, as the AI does.
2. **Inviting.** The claimant can still ask, at a cost and under cooldown (A), judged by the same stake score. A faction with a hard block says why ("they trade with the target").

### C. Calls into a war that has started
- Allies and vassals are **called**, and each **decides** on a stake score like B (defence of an ally; the war is of little benefit; against family or friends; stretched elsewhere).
- **Refusing** an ally costs opinion with the caller and a mark on your name; accepting costs manpower and exposure. Vassals can decline as houses already do.
- The caller **stops calling** when its side is already much stronger than the enemy's (Paradox's AI does the same).

### D. Caps and costs for pile-ons
- A **cap on backers per claim** and a **cost per backer** to the claimant (renown and wealth, scaling with how many claims and wars it already has).
- **Aggression memory:** successful conquest raises a faction's notoriety, which fades slowly. A faction with high notoriety finds new trade, pacts and alliances **blocked or costlier**, others' opinion of it falls, and above a threshold neighbours may form a **coalition** against it (a visible standing alliance). Coalitions are S6's job; the notoriety and the trade block come first.

### E. The timer and the outs
- **Claim on you is a persistent marker** (top bar and the faction card): who, which district, the reason, the earliest and latest day of the ultimatum, the backers.
- **The date is binding.** An early ultimatum (backers raised its strength) can never come sooner than a **minimum notice** after the claim became known, and any change of date is announced as a new countdown. The ultimatum's own deadline stays.
- **More than two answers to an ultimatum:** hand it over; refuse; **pay it off** (wealth, food or materials, price scaled to what they asked); **offer a match** between the families (the claim lapses while the marriage lives, using doc 16's tie); **concede something else** (a different, smaller district); **call your own backers and allies** first.
- The claimant can withdraw, and a claim lapses if its reason disappears (peace treaty, marriage, tribute accepted).

## 3. Order of building (proposed)
1. **A and the timer (E):** per-pair cooldowns and remembered refusals for all asks; binding, visible claim timer; the claim marker. Smallest change that stops the repeated-ask exploit and the surprise.
2. **B and C:** volunteering with the stake score, inviting under cooldown, allies deciding on a call. Replaces automatic alliance joins.
3. **E's outs** (pay off, match, concession).
4. **D:** caps, costs, notoriety, trade blocks; coalitions go to S6.

Measure each with `/sim` (stop counter, `TEMPO` lines, a new count of war participants per war) and the play log, so we see the change in numbers before and after.

## 4. Built so far (build 1, 2026-10-11)
Per-pair per-action ask cooldowns with remembered refusals (AI full length, player 35%; gifts a year, trade and pacts 3 years, matches and submission 4, alliance and backing 5; each refusal lengthens the wait up to 3x, and asking on after a refusal costs a small "pestered" opinion memory); pacts and alliances can still be renewed in their window. The 90-day notice floor for early ultimatums, a clock that reads "90 to 180 days" everywhere it appears (top-bar marker, outliner, faction card), and a one-time warning when their side has grown strong enough for an early ultimatum. Saves from v1.43 don't load (save version 17). Not yet built: volunteering and stake-based backing, allies deciding on a call, pay-off and marriage outs, notoriety and trade blocks, an AI target shortlist.

## 5. Still open
1. The numbers above are first guesses for the playtest.
2. Does the player's cooldown multiplier (35%) feel right in play?
