# 20. War as negotiation, the cost of growth, and a bigger map (DRAFT for the owner to mark up)

Written 2026-10-11 after a playtest and the owner's answers below. Research is in `06-paradox-reference-notes.md` (last section). Nothing here is built.

## What the playtest showed
- An assault changes ownership at once (two wins take a district: -40 and +40 influence), so districts flip with no negotiation and the defender can lose land "for no reason".
- White peace keeps whatever you took ("borders stay where they are"); it is a ceasefire, not a status quo.
- The way to take your war goal ("Enforce") exists but is hidden: it unlocks at a war score of 40 (a claim), shown nowhere on the war screen.
- 61 districts; about 13 unclaimed after a year and almost none after two. After that the only way on is war.
- The family, council and ambitions barely touch the loop: click, scavenge, settle, build, then wars.

## The owner's decisions (2026-10-11)
1. **Wars work like Paradox's: assaults occupy; ownership changes only at the peace negotiation.**
2. **Growth is bounded by cost** (CK2's infamy, revolts where grievance is high). Absorbing and stabilising a district takes time, after conquest *and* after settling.
3. **A bigger, slower map.**

## Part A: occupation, war score and the peace table

**Occupation.** A district has an *owner* (unchanged by war) and may have an *occupier*. A successful assault makes the attacker the occupier instead of moving influence. An occupied district:
- pays nothing to its owner while occupied; its people carry on, with grievance rising slowly (the owner is "not in charge");
- earns the occupier war score; the occupier's crew who took it stay as its garrison (manpower tied up, which is the cost of holding it);
- is retaken by the owner's assault on the occupiers, or ends when the war ends.

**War score** (from the claimant's side, -100 to 100) has three sources, as in CK3:
- *Occupation:* the share of the enemy's districts you hold (weighted by size), with a bonus for their home district.
- *Battles:* assaults won and lost, capped.
- *Ticking:* a slow daily gain for the attacker from the start, for the defender only after a delay, so wars end.
The existing exhaustion stays as a modifier. The score is **shown in the war window as a bar with the thresholds marked**.

**The peace table.** Ending a war is a deal, opened from the war window, in the same style as the war goal window (doc 19):
- *The winner* (score in their favour) spends score on demands: **the war goal** (a claim needs most of the score, as CK3's 80%), **other occupied districts** at a score cost scaled by size, **tribute**. Costs rise for land they have no claim on.
- *White peace* is the status quo: every occupation ends, ownership unchanged, a truce follows. The AI accepts it more readily when it is not winning and refuses it when it is "close to victory".
- *Surrender:* the loser can accept the demands the winner could afford.
- The player gets the same table the AI uses (no hidden rules).
- After the war, a **long truce** (years, as CK2's) between the two, so the same pair can't fight again at once.

**The AI** occupies, presses to take its goal once the score allows, offers or accepts white peace by the same thresholds, and will not offer what it cannot afford.

**What goes away:** the war score of 40 and the hidden "Enforce" button; ownership flipping at assault; the hand-written instant white peace.

## Part B: the cost of growth

1. **Newly held land starts unsettled and ramps.** Conquest at the peace table drops a district's control by most of its value (CK3: -75 of 100); a freshly settled district starts low too. Yield (taxes, food, manpower) scales with control, as the existing `yield_multiplier` already does; control climbs back over months with time, Safeguard, and a garrison. HOI4 adds tiers: more of the yield and less garrison needed at each step.
2. **Unrest where grievance is high and control is low.** Revolt risk rises for newly taken land and falls with garrison, with a claim on it, and at peace. A revolt makes it unowned or flips it to rebels, as now.
3. **Infamy (our notoriety, doc 18 D).** Added by taking land, by raids, by broken pacts, more for no cause or against a friendly faction, with a per-goal multiplier (a plain claim cheap, vassalize dear). It fades slowly, makes others cooler toward you, blocks or costs more for trade and pacts, and above a threshold neighbours form a coalition (S6).
4. **Reach.** The existing admin upkeep (first districts free, then rising faster than land) stays; add how much you can hold *well*: past your reach, grievance rises across the realm. Reach grows with councillors' skill and administration buildings.

## Part C: a bigger, slower map
- More districts (the generator, `tools/generate_map.gd`, takes a seed and a size): a target around 120 for the first test, up from 61, with 10-12 factions so neighbours still meet in year one.
- Slower early expansion: longer Settle and Scavenge times, and the Part B ramp, so a district is not "done" the day it is claimed.
- A pacing target the sim can check: unclaimed districts at the end of year 2, 4 and 8, and the first war's day.

## Order of building
1. **W1: occupation, war score, the peace table, white peace as status quo, the war window's score bar.** The biggest piece: new fields (saved, save version up), the assault rewrite, the AI, the UI. Measured with the war tempo and wars lines in `/sim`.
2. **W2: Part B** (ramping control after conquest and settling, unrest, infamy with its first effects, reach).
3. **W3: Part C** (the map and pacing), measured by the pacing target.
Each is a build you can play before the next.

## Owner's answers (2026-10-11)
1. **Occupied land pays nothing to either side**: it is out of order while occupied.
2. **About 120 districts**, 10-12 factions.
3. **A ten-year truce after a war.** It is a deliberate brake on AI overexpansion: with a decade between wars for any pair, an AI has to ask whether a war is really in its interest.
4. **Backing off costs the aggressor:** pressing a claim, declaring, or being at the ultimatum stage and then ending in white peace (or backing down) costs the aggressor something for the attempt, and also gives a truce.
5. **W1 first.**

## Defaults I will use (change them if wrong)
- Truce after a war that ends in a deal (victory or surrender): 3600 days (ten game years).
- Truce after a white peace or backing down: 1800 days. The aggressor loses 10 renown and the target and onlookers hold "pressed a claim and backed off" against it.
- The loser can always concede; the winner's demands need no consent once the score allows them (as in CK3). White peace needs the other side to accept.

## Built: W1 (2026-10-11)
Occupation, war score, the peace table, a status-quo white peace, the cost and truce for backing off, and the ten-year truce are built as described (see the changelog). Not yet built: a defender's victory demands, parts B and C (W2, W3). Measured side effect: factions go hungrier and poorer at war, since occupied districts pay nobody; not retuned.
