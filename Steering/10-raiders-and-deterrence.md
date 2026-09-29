# Raiders and Deterrence

How raiders pick their targets, what a raid is worth, and what you can do about raiders besides fighting. Written 2026-09-27 from the v1.39 playtest (the Rust Dogs raiding a district claimed days earlier, with no answer in Diplomacy). **Status: approved 2026-09-27 (the four recommended decisions below); built in v1.39. Where the build differs from this draft, it says "Built:".**

Already done in v1.39, so not repeated below: a raided district can't be raided again for 30 days (45 if the raid failed, 60 after a disaster); the Watchtower costs 25 materials and no wealth; faction names on the zoomed-out map.

## Spine check
- **Strengthens the loop:** raids take from what your land actually produces, so building up a district makes it a target, and defending it matters.
- **Strengthens the verb:** Threaten becomes a venture (leader, crew, odds, four tiers). Tribute stays a deal, like gifts.
- **Pillar 3 (readable AI):** raiders say what they want before they come ("pay or we raid"), and the log says why they back off.
- **No new resource.** Tribute and pacts can be paid in food or materials, so being short of wealth is never a dead end.

## Part 1: what a raid is worth

### Today
- The loot comes out of your **whole stockpile**: up to 12 food, 8 materials and 6 wealth, plus a bonus the raider gets even when you have nothing to take. A district you claimed yesterday is as good a target as your capital.
- The AI's value for a raid is `0.4 x (1.5 if hungry, else 0.8)`. It never looks at the target. Raiders multiply it by 3.
- Measured over 4 runs x 180 days: raiders scavenge about twice as often as they raid. About a quarter of raids (13 of 55) hit a low-value district (development under 30%, no buildings); most early land is home districts, which are more developed. Which district gets hit is chance and adjacency, not worth: the raid is about the raider's hunger, and a fresh claim on their border is as likely a target as anything else.

### Proposed
1. **Loot scales with the district.** Loot = today's amounts x a *worth* of `0.4 + development + 0.15 per working building`, capped at 1.5. A fresh claim (development 25%, no buildings) is worth about 0.65 of today's raid; a rebuilt district with two buildings about 1.5.
2. **The bonus loot only comes on a Triumph.** An ordinary success takes only what's there.
3. **The AI weighs a raid by its expected loot:** `worth x its need for food or materials`, compared with what scavenging nearby would bring. Raider temperament goes from x3 to x2. Hungry raiders still raid; fed raiders with ruins nearby scavenge.
4. **Richer targets cost more to hit.** Nothing new is needed here: control, Watchtowers, defenders and arms already lower the odds. What's added is that the district's worth is shown in its tooltip ("Raid worth: low"), so you can see what you're protecting.
5. **Raiding a built-up district angers its neighbours.** Every faction bordering the victim gets -5 opinion of the raider ("Raids our neighbours"). This is a small early piece of S6's aggression memory, and it only applies when the district's worth is 1.0 or more.

**Target (simulation):** in the first year, raids on districts with development under 30% and no buildings fall from about 1 in 4 to under 1 in 10. Raids per raider per year stay within 20% of today's count, so the S2 pressure target still holds.

## Part 2: answering raiders

### Today
- The diplomacy actions exist and none of them are locked to a faction type: gifts (25 wealth), trade (10), non-aggression pact (10), alliance (20, opinion 20+), vassalage (20). **A non-aggression pact already blocks raids.**
- In the playtest you had 7 wealth, so everything was greyed out, and the card showed only "Not available now".
- Each raid costs the raider 10 of your opinion, and their Militaristic trait makes them less keen on pacts (x0.8), so they're hard to talk to even with the wealth.

### Proposed

| Answer | Kind | What it does | Gated by | Cost |
|---|---|---|---|---|
| **Pay tribute** | Diplomacy (a deal, like gifts) | They won't raid you for 60 days. The log and their card show the countdown | Only toward a faction that raided you or demanded tribute in the last 90 days | Food or materials, your choice: 10 + their strength / 5. Always accepted |
| **Threaten** | **Venture** (leader, crew, four tiers) against a raider's district on your border | Triumph: no raids from them for 90 days, plus the usual +2 renown for a triumph. Success: 45 days. Setback: their opinion of you -10. Disaster: they raid you within 10 days, with +20% odds | Command skill; odds from your strength against theirs, your arms, your War Chief | 2 food, 3 crew, 4 days |
| **Pacts** | Diplomacy | Unchanged, but can be paid in wealth, food or materials | Unchanged | 10 wealth, or 15 food, or 12 materials |
| **The card says why** | UI | Every greyed-out action shows its own reason on hover, not one "Not available now" | | |

*Built:* the card already gave each greyed action its own reason on hover and listed them all under "Not available now"; in the playtest the list was below the fold. Pay tribute only shows on the card of a faction that menaced you, Demand tribute only for neighbours. Raiders halve their willingness to sign a pact ("Raiders would rather keep a free hand"): once pacts could be paid in food or materials, every AI faction signed one with its raiders and raiding almost stopped (37 raids in year one across 4 test games, against 200 in v1.38).

### Raiders act in more than one way
- **Demand tribute (new AI behaviour).** Before raiding, a raider may send you a demand: "pay 15 food or we come for it", answered in Proposals. Accepting counts as Pay tribute. Refusing (or letting it expire) means their next raid on you gets +20% odds for 60 days, and the log says so. *Built: one "emboldened" bonus of +20% for both a refused demand and a threat that backfires, so there is one number to learn.* The AI demands only from factions it would raid anyway; the odds of a demand rather than a straight raid rise with the victim's strength.
- **Back off after a beating.** A raid driven off by defenders already brings the 45-day cooldown; the log now says "the Rust Dogs lick their wounds".
- **What raiders already do** (scavenge, secure food, gather weapons, settle) stays as it is. It happens on their own land, so the change you'll notice is the demand, not the list.

## Decisions for the owner
1. **Is Threaten a venture?** Recommended: yes. It's risky, it needs a leader, and it has a real downside, which is what the one-verb rule is for. Pay tribute stays a deal, like gifts, because nothing about it is uncertain.
2. **Should tribute be paid in wealth as well?** Recommended: no. Food and materials are what raiders take anyway, and keeping wealth out means a poor faction always has an answer.
3. **Neighbours' anger at raids (Part 1, point 5):** now, or wait for S6? Recommended: now, since it's small and it's the only thing that makes raiding a rich target cost reputation.
4. **Demands: shown as an event pop-up (pauses) or only in Proposals?** Recommended: a pop-up the first time a faction demands tribute, then Proposals only.

## Built: other differences from the draft
- **You can demand tribute too.** The AI plays by your rules, so Demand tribute is an action for everyone: the player can lean on weaker neighbours the way raiders lean on you.
- **Threaten's disaster** makes their raids on you +20% likelier to succeed for 30 days (rather than "they raid you within 10 days"); a raider that's emboldened is keener to raid, so it usually comes soon.
- **Pacts need a shared border** (renewals excepted), and the AI only asks a stronger neighbour it has reason to fear; raiders rarely offer one. Found in playtest: every faction offered the player a pact before bordering them.
- **AI tuning:** raids are valued at 0.75 x worth x need (raider temperament x2); the AI threatens a faction that raided it in the last 60 days, at a modest priority, so it doesn't repeat failed threats endlessly.
- **Result (v1.39):** 12 of 104 first-year raids hit a low-value district (was about 1 in 4; slightly over the target of 1 in 10); raids per 4-year game 47/118/102/62, between v1.38 and the cooldown alone; no faction broke, hunger at most 20 days.

## Checks when built
- `/sim`: the raid targets above; no raider starves because it stopped raiding; S2 targets still met.
- A playtest: "When the Rust Dogs came, I had something to do about it other than fight."
- Decision-log entries for the choices above.
