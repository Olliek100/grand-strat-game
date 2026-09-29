# Changelog

What each build changed, its tuning numbers and simulation results, newest first. Design decisions that still stand are in Steering/04-decision-log.md. From v1.38 on, each build is a git tag.

**2026-09-28 (v1.40, spine S4: choices; see Steering/12-choices-ambitions-and-government.md)**

- **Standing tasks** (Steering/13-standing-tasks.md): routine work on your own land is now a councillor's task, not a one-off launch.
  - **Which:** Scavenge, Rebuild, Safeguard the Shelter, Secure Food, Relief, Gather Weapons and Reinforce. Scavenging unclaimed ruins, Scout, Settle, Trade Runs and every attack stay one-off launches.
  - **How:** a seat card's **Task...** button lists the tasks (greyed with the reason when there's nowhere, or nobody free, to do one). Pick one and the eligible districts light up in gold on the map with the stat that matters ("Ruins 44%"). Click one to open its planner with the task and councillor chosen, then **ASSIGN**. The district panel also offers **ASSIGN** directly for these ventures on your land. Esc cancels a pick.
  - **Runs:** each run is an ordinary venture with the usual odds, graded outcomes and costs; the next starts as soon as one lands, until the district's own state says it's done (ruins under 10%, fully rebuilt, control 95, food sources worked, calm, armoury full, threat gone). Then you're told, and the councillor is free.
  - **Commitment:** two runs. **STOP** costs nothing (the current run finishes), but the councillor takes no new work until the two runs have passed.
  - **Waiting:** a task that can't pay its run waits and says why; a wounded councillor's task waits until they heal.
  - **Wounds:** task runs wound half as often as one-off launches (owner: wounds need rebalancing with council-only tasks).
  - **Seeing it:** an outliner **Tasks** section with progress; seat cards say what each councillor is doing; a digest line per task every 30 days (runs, gains, progress). Ordinary successes don't log one by one; triumphs, failures, wounds, completions and pauses still do.
  - **Only council seats hold tasks** (at most four). The AI assigns tasks the same way, from its one list.
  - Saves from before this build won't load (save version 7; v1.40's new fields also needed it).
  - **Result (3 games x 4 years):** 61-70% of the city claimed at year one (was 72-77%): councillors on tasks aren't leading expansion, which brings the pace close to the provisional 65%. No faction broke; civil wars 0-1 a game and the first purge; about 30 ms a day. Watch: one game had 57 AI threats against a raider, and one minor went hungry for 62 days.
- **Playtest fixes:**
  - **Scavenge and Gather Weapons suddenly cost wealth:** the planner's recommended plan was adding extra funding whenever you could spare it. It no longer adds funding; paying more is always your choice (the AI follows the same rule). Wealth is for buildings and relations.
  - **Danger in a rebuilt home still read "Low":** in land you hold, danger now falls as the ruins are cleared (x0.3 with no ruins left, full at 100% ruins), on top of Safeguard's direct cut. Raids and fighting bring ruins, and danger, back. New label "None" under 4%. The Danger hover shows the percentage and the ruins.
  - **Rust Dogs sat next to free land without expanding:** Militaristic no longer dampens expansion, and minor factions only grow at half speed while they're still a Gang (not once they're Warlord crews).

- **Renown and reputation.** Renown is now spent; *reputation* (everything you've ever earned, never goes down) takes over renown's lasting effects: manpower and captain limits, recruit quality, the heir's claim, respect. Unspent renown still helps treaties get accepted. The top bar's Renown hover shows both.
- **Deeds:** the 21 milestones (was data/ambitions.json, now data/deeds.json) keep paying renown, and move from the Economy window to the new Ambitions window.
- **National Ambitions (Ambitions window, F5):** 12 in data/national_ambitions.json. One at a time; each costs 20-40 renown and takes 45-120 days, then its bonus lasts for good. Each is gated by your situation (traits, treaties, raids, food, buildings, your leader). Some close a rival for good (A Name to Fear / Good Neighbours; Feed the City / Every Hand a Soldier); Welfare for All fails if you raid while it runs; three unlock a reform. Cards show the bonus, what it closes, the requirements ticked or crossed, and a Start button with cost and time.
- **Governments (Realm window, new Government tab):** data/governments.json.
  - **Gang** (minor factions start here; splits 30% likelier; the strongest takes over).
  - **Warlord** (major factions; as before).
  - **Autocracy** (the heir's claim +25, fewer contesters, but a split takes 45-60% of the land; Command +10%).
  - **Politburo** (the council elects; contesters are purged instead of splitting).
  - **Merchant Oligarchy** (the best Stewardship councillor; the treasury buys off rivals at a succession).
  - **Democracy** (an election after a 30-day caretaker period; splits half as likely; ambitions slower and reforms dearer).
  - Where no heir can be named, the Succession tab hides "Name heir".
- **Reforms:** unlocked by situation and ambitions. Each costs wealth or renown, unsettles every district (grievance +10), and locks further reform for 2 years. **The council takes sides by their natures** (e.g. Ambitious and Cruel back Autocracy, Kind opposes it); those overruled lose loyalty. Under the Politburo, Oligarchy and Democracy they vote, and a majority against blocks it. Hold Elections is only on offer for 30 days after a leader's death.
- **The AI** weighs reforms, ambitions and buildings together ("what to do at home") against its ventures, leaning by its traits. Each faction's card in Diplomacy shows its government, the ambition it's pursuing and those it has achieved.
- **One effect lookup:** traits, completed ambitions and government combine in one place (cached per day), so every bonus shows up wherever traits already did, labelled in odds breakdowns.
- **Tools:** screenshots can show the Ambitions window, Deeds and the Government tab, and now pause the game before capturing (a first contact used to open Diplomacy over the shot). The balance simulation counts reforms, purges, bribes and ambitions.
- **Result (4 games x 4 years):** governments at year four: 4 Warlord, 5 Oligarchy, 5 Politburo, 2 Autocracy, 1 Democracy; every surviving gang became a Warlord crew; about 8 reforms a game; civil wars 1.0 a game; ambitions completed per faction 4-9. Timed back to back, within about 5% of v1.38.
- **Watch:** purges and bribes didn't happen in these games (covered by tests); Walls and Watches and Feed the City are taken by almost everyone, Every Hand a Soldier rarely.

**2026-09-27 (v1.39, captains who looked idle; raiders you can answer; earned odds; released inside the v1.40 tag)**

- **Playtest:** "No captain is free" while the Council showed Ines, Ada and Kasper apparently idle; it looked like characters were vanishing. They were wounded (30-60 days from a setback or disaster); the only sign was a bandage on the portrait.
- **Bug:** the "No captain is free" row (and "Appoint...") had id -1, which Godot turns into the row's index, so the planner looked up another faction's character: it said "Choose a captain to lead it" instead of who is away and for how long, and worked out the odds with that stranger's skills. Now the planner names everyone who's wounded or out and when they're back.
- **Council seat cards** say when the holder can't lead right now: "Wounded for 4 days" or "Back in 4 days (Scavenge)".
- **Playtest:** "no user-friendly explanation for why an action has only a 59% success chance, no direction on how to improve it." The breakdown was a list of x0.85-style multipliers on the odds bar only; hovering the venture button showed the description.
- **Odds explain themselves** on the venture button, the odds bar and LAUNCH: where the chance starts, each reason it goes up or down as +/-%, a **To raise it** list built from your actual situation (a better leader and whether they're wounded or away, an empty council seat for that skill, more crew, funding, scout first, Safeguard to lower danger, arms), and the **risk to the leader** (wounded, killed).
- **Risk to the leader** also sits under the odds bar in the planner ("Risk to Rosa Dunmore: 12% wounded · <1% killed"), since it's part of the decision. Long tooltip descriptions now wrap instead of running off the screen.
- **Measured (6 x 120 days, every free captain kept busy as a human would):** on average 1.8 of about 5.7 captains are wounded at once; deaths are rare (1 in 6 runs). The AI keeps only about 1.2 captains busy, so it rarely meets this. Wound rules unchanged for now.
- **Playtest:** the Rust Dogs raided the same newly claimed district again and again; a Watchtower needed wealth the raids were taking; no faction names on the zoomed-out map.
- **Raid cooldown:** after a raid, nobody can raid that district for 30 days (45 if the raid failed, 60 after a disaster), and two factions can't raid the same district at once. Shown as a "Safe from raids 18d" chip on the district and in the raid's log line. Saves from before v1.39 won't load (save version 6).
- **Watchtower** costs 25 materials and no wealth (was 20 materials and 10 wealth), so the answer to raids doesn't cost what raids steal.
- **Zoomed-out map** shows faction names over their land, sized by territory, instead of borough names (the borough is still in the district hover). The selected district's name sits just below.
- **Result (3 x 4 years, before → after):** raids 113/54/113 → 54/48/33; factions left at year four 4/3/3 → 7/4/5; largest faction 25/44/32 → 15/26/26; about 29 ms a day either way. Watch: one minor (Ashgrove Kin) starved for 216 days in one run, and the AI-played player faction for 41 in another (before: at most 26).
- **Raiders and deterrence** (Steering/10-raiders-and-deterrence.md, approved with the recommended decisions):
  - **A raid is worth what the district is worth:** loot x0.4 (fresh claim) to x1.5 (rebuilt, with working buildings); bonus loot only on a Triumph. The Defence hover says how worth raiding a district is. The AI weighs raids by that worth (0.75 x worth x need; raider temperament x3 → x2).
  - **Pay tribute** (Diplomacy, to a faction that raided you or demanded tribute in the last 90 days): 10 + their strength / 5 in food or materials, whichever you can better spare; always accepted; no raids from them for 60 days.
  - **Threaten** (new venture, Command) against a raider's district on your border: odds from your strength against theirs, your arms and your War Chief. Success: no raids from them for 45 days; Triumph 90; Setback: their opinion -10; Disaster: their raids on you +20% for 30 days.
  - **Demand tribute** (anyone, AI included): if they pay, you promise no raids for 60 days; if they refuse, your raids on them get +20% for 60 days. Raiders now demand before they raid; the first demand from each faction is a pop-up.
  - **Pacts** can be paid in wealth, food or materials. Raiders are half as willing to sign one ("Raiders would rather keep a free hand"): without that, every AI signed pacts with its raiders and raiding nearly stopped.
  - Raiding a built-up district costs the raider -5 opinion with every neighbour of the victim. Failed raids against defenders: "they lick their wounds". The raider warning stops while a promise holds; the faction card shows promises and grudges with their countdowns.
  - **Playtest:** every faction offered the player a non-aggression pact, before sharing a border. The AI wanted a pact from anyone stronger, and cheaper pacts meant all could now afford one (103 offers in 4 test years, none from a neighbour). **A pact now needs a shared border** (renewals excepted), and the AI only asks a stronger neighbour it has reason to fear (raiders, someone who raided it lately, someone who dislikes it); raiders rarely offer one. Now 4 offers in 4 test years, all from neighbours.
  - **Result (4 x 4 years):** raids 47/118/102/62 (v1.38: 113/54/113; with the cooldown alone: 54/48/33); tribute paid 10-26 and demands refused 14-24 per game; threats 1-11; no faction broke; hunger at most 20 days; about 32 ms a day (was about 29). First-year raids on low-value districts: 12 of 104 (was about 1 in 4; target under 1 in 10, so slightly over).
- **Earned odds and pace** (Steering/11-earned-odds-and-pace.md, with the owner's decisions). **Playtest:** ventures felt like gambling, and the game like a race to grab land.
  - **Preparation buys certainty and quality.** Odds now reach 98% (was capped at 95%). A success pays x0.8 to x1.2 of its gains depending on how cleanly the roll landed ("a clean job", "only just" in the log), and Triumphs get more likely as odds rise. At 90%+ odds a failure is never a Disaster.
  - **Outnumber the defenders:** against defenders on guard, your crew is compared with theirs (x0.8 outnumbered, up to x1.4 at three to one), in place of the flat crew bonus. Overwhelming force can now make an attack nearly certain.
  - **The planner starts on the recommended plan:** the best free leader, crew until one more adds under 2 points, and extra funding you can spare (keeping 20 wealth), stopping at 90%. A button switches to the cheapest plan and back. The AI launches with the same rule.
  - **No silent surprises:** the odds explanation warns when the target could send defenders before you arrive; the outliner shows each venture's live odds (red, "was 85%", when they've fallen); the log says when odds moved between launch and landing and why. Odds are not locked: the target can still react (07 §4.2).
  - **Wounds scale with danger:** a setback wounds 10-30% of the time (the venture's danger; was a flat 30%), for 10-20 days on safe work up to 30-60 on raids and assaults. Scavenge and Settle: 15% for 12-25 days.
  - **Minor factions lose their authored personality.** What any faction is keen on comes from its active traits (Militaristic raids, Merchant trades, Socialist digs in), defined in data/traits.json. Ashgrove Kin start Socialist. "Raiders" is now a reading of a faction's traits, so a crew that stops raiding stops being raiders, and a Militaristic major faction leans the same way.
  - **One list for the AI:** building competes with ventures for the same move and the same stocks (the separate build timer is gone). **Expansion costs more:** administration now also costs materials (0.01 x (districts - 3)^1.7 a day), and a newly settled district starts with grievance +15.
  - **Each faction's lean** shows on its diplomacy card ("Lately: building up at home (70% of its moves)" or "expanding and reaching out"), from a tally that fades over about 90 days.
  - **Speed:** shared-border and war checks are now cached (for the day, and until a war starts or ends); timed back to back, this build runs at the same speed as v1.38.
  - **Tuning:** high odds add up to +15% to the Triumph share (tried +30%: triumphs and fewer wounds kept captains so loyal that no civil war happened in 4 games). Doubling the materials share of administration barely slowed claiming (70%) and made hunger worse (59 days), so it stays at 0.01.
  - **Result (6 x 4 years):** 71% of the city claimed at year one (v1.38: 77%; provisional target 65%, not yet reached); civil wars 0.7 per game (as before); longest hunger in a game 0-29 days; 84% of AI launches now at 90%+ odds; factions spread from 2% to 93% of their moves at home by year two. 4 x 4 years: raids 24-53 a game, tribute paid 7-16, demands refused 8-16; no faction broke.

**2026-09-26 (v1.38, renewable materials)**

- **Playtest:** Scavenge and the Salvage Yard both strip ruins, which only fell, so materials were finite; boxed in without a trade partner, the game could lock up (breaks spine rule 5, no dead ends).
- **Recycling Works** (Secured; 20 materials, 25 wealth; +0.25 materials a day; 0.12 wealth upkeep): a renewable source that turns wealth into materials locally. AI builds it where ruins are stripped and stocks low.
- **Ruins return:** raids +3%, assaults +6% (and -4% development), revolts +10%; land nobody holds regrows 0.05%/day toward its type's natural ruin level.
- **Result (3 x 8 years):** no faction ever in disrepair; 2-6 Recycling Works per game; average ruin 0.33 at year 2, about 0.1 by year 8.

**2026-09-26 (v1.37)**

- Cost and duration are back on the LAUNCH button ("LAUNCH · 5 materials · 10 days"), where you commit; the planner title shows only the venture name (user: the cost had vanished in v1.35).

**2026-09-26 (v1.36, portraits)**

- Every portrait opens its person on left-click (the diplomacy card's portraits weren't wired; now portraits fall back to the game screen themselves, so none can be missed). Right-click opens a CK-style menu: own people get heir, venture, seat and dismiss actions; other factions' people get that faction's diplomacy actions with odds, disabled ones with the reason on hover.
- A district with nothing you can launch hides the planner and says so.

**2026-09-26 (v1.35, tightening pass)**

- **Rule (user):** how a system works is a tooltip on its tab/title/menu button; the body shows only what you decide with, and every figure explains itself on hover. Applied to Council, Realm, Diplomacy, Economy, Character, Log and the district panel.
- **Character window:** removed the duplicates the user found (name in the title bar, spouse and heir repeated in Family, a role line, filler). Skills as boxes, traits as chips by kind, spouse and heir top-right only, family on one line per group.
- **Council:** a 2×2 grid of seat cards; the rules paragraph is a tooltip.
- **District panel:** stat chips with breakdowns on hover; only launchable ventures shown (plus "+N unavailable" with reasons); a new district auto-selects a venture you can launch; the odds breakdown and outcome tiers are a tooltip on the odds bar; the Build tab's details are button tooltips.
- **Next candidate:** the Diplomacy faction page is still text-heavy (opinion reasons, stance, succession inline).

**2026-09-26 (v1.34, spine S3b: Legacy and the UI frame)**

- **The frame from 09-ui-plan.md is built:** map full-screen; top bar with hover breakdowns built from the real formulas (new `upkeep_breakdown`, `crew_cap_breakdown`); alert icons (click to act, right-click to dismiss until the problem clears) replacing the Problems/Chances lines and banner; windows on the left (Character, Council, Realm, Diplomacy, Economy, Log; F1-F4, F6, F7); outliner and district panel on the right; Esc chain and game menu (F5/F9 removed); event pop-ups for first contact, war on you, civil war and leader deaths (inform only). Only the open window refreshes: UI costs about 7 ms a game day.
- **Legacy:**
  - personality from four opposite pairs (Brave/Craven, Cruel/Kind, Greedy/Generous, Ambitious/Steadfast), one or two each, inherited without clashes;
  - a leader's nature pulls faction traits (+1 a month) and moves everyone's respect (Cruel -3, Kind +3);
  - ruling traits (Conqueror, Builder, Peacemaker) with faction-wide effects;
  - leaders always start married and remarry (30% a month);
  - **Name heir** for family or council members (the natural heir -15 loyalty; a non-family heir costs every family member -8);
  - dead family and leaders are kept in a graveyard for family trees and the archive of past leaders;
  - first names by sex, and captains are now men and women.
- **Found on the way:** personality shuffling used Godot's global random generator, which broke save/replay determinism (fixed to use the game's own); a flaky heir test (founding children can be 22).
- **Result (4 x 4 years):** 4-13 successions, 0-3 civil wars (1 on average; 0 in two runs, below the S3 target of 1+), largest faction 24-33 districts; Builder and Peacemaker are common, Conqueror rare.
- **Watch:** simulation costs about 28 ms per day by year 2.5, close to the 40 ms budget of speed 5.

**2026-09-26 (v1.33, spine S3: the arc)**

- **Bug (playtest):** a rival's "S" venture ran inside the player's claimed district. Scouting didn't check ownership, and ventures begun on open land kept running after it was claimed. **Rule (user):** once land is claimed, others can only trade, raid or assault it. Scouting is limited to unclaimed land; peaceful ventures on land since claimed by someone else are called off on landing. Rings now use two-letter codes, and hover lists the ventures in a district.
- **Leaders and dynasties:** each faction has a leader (not in the venture pool), spouse (75%) and 0-3 children. Monthly death chance: leader 2%, adult 0.2%, +0.25% per year over 50. Births: 3% a month while the leader is under 55 and the spouse under 45. Children come of age at 16 with inherited strengths (4-6 in a parent's best skill, +1 if the parent leads) and may take a parent's personality trait.
- **Respect:** loyalty moves ±3 per point of the leader's best skill away from 5. **Renown** adds up to +2 to recruits' specialty. **The captain limit** is 5 + 1 per 5 districts, capped at 10. Absorbed factions bring only their best, up to the limit; households hold 10-16 characters (the outline aimed for 8-12).
- **Succession (Warlord):** the heir is the eldest adult child, then the spouse, then other family, then the strongest councillor (new dynasty). Claim: 30 by blood or 12, + best skill × 3 + triumphs × 2 + renown/10. Contesters are councillors or family with loyalty under 40 or Ambitious, claiming best skill × 3 + triumphs × 2 + (45 − loyalty) + 10 if Ambitious. Split chance: sum of claim/(claim + heir claim) × 0.8, capped at 85%; none with under 2 districts.
- **Civil war:** the claimant takes the districts nearest the one furthest from the capital (30-45% of the land), 35% of the stores, and crew under 35 loyalty, and goes to war with the old faction.
- **Result (5 x 4 years):** 49 successions and 7 civil wars (about 1.4 per game).
- **Portraits:** sex (no beards on women) and age (children, crow's feet at 45, brow lines at 55, white hair after 60). Evolution by government waits for S4.

**2026-09-26 (v1.32, seeing and answering threats)**

- **Playtest:** the log took half the screen and was ignored, so a 15-day war warning (which did auto-pause) went unread. Now there's a 3-line ticker of what concerns you, the full log sits in the Activity tab with filters, and alerts that pause show as a banner over the map (with Open diplomacy). A war countdown sits in Problems.
- **Defence made visible and continuous:** control shields a district smoothly (x1.0 at 50 up to x0.65 at 100; replaces the binary "Secured x0.7"). The district panel lists every defence factor. Attack duration grows with defence (+80% of the odds reduction, in days).
- **Reinforce** (user idea): a venture that guards a threatened district; x(1 − 0.06 per defender), floor 0.45. Attackers who fail against 2+ defenders lose 1-3 extra crew. The AI reinforces districts under attack. Result: about 90 reinforcements per 4-year game; raid success 29-50%; the largest faction at year four holds 23-27 districts (no runaway in 3 runs).
- **First contact** pauses and opens the new neighbour's card; **Chances** lists deals at 50%+ acceptance with neighbours. This answers "I haven't used diplomacy": the moment and the likely deal are now put in front of you.

**2026-09-25 (v1.31, spine S2: pressure; reordered ahead of the arc)**

- **Why reordered:** in playtest, defence, Rebuild, diplomacy and raiding all went unused. The root cause was that nothing threatened the player early. The arc (leader, dynasty, succession) moves to S3.
- **Six minor factions**, one district each, placed by map distance (two steps from a big faction's shelter, touching nobody). Personalities are raider, trader or hermit, and they weight the AI's goals (raiders x3 on raids). Minors expand at half speed and start with 2 captains and 1 council seat. Rejected: fixed map coordinates (collisions with homes).
- **Raids steal food, materials and a little wealth.** Problems warns of raider, hungry or hostile neighbours on your border, with both sides' arms.
- **Trade Run** targets another faction's district (next door, or anywhere with a trade agreement). The host keeps the 20 wealth and gains +4 opinion ("Trades at our market"); +20% odds with a trade agreement.
- **Development matters more:** food is 0.2 + 0.3 × development, manpower × (0.5 + development), and Rebuild gives +8%. The planner shows Rebuild's payoff in numbers.
- **Anti-runaway and anti-hoard:**
  - Vassalage: big factions get x0.3 acceptance ("too proud to kneel"); minors x1.4 and can be made vassals up to 70% of your strength (big factions: 40%).
  - Administration is free for 3 districts, then 0.02 × (n − 3)^1.7.
  - Council wage per district is 0.01.
  - Wealth over 300 and materials over 200 leak 1% a day.
- **Result (4 x 4-year simulations, AI playing all factions):** first contact at days 66-194; 44-58 raids in year one; 1-3 vassals by year one; no faction broke except an AI-played player faction raided 29 times in one run. Year-four wealth is at most about 1,100 (was up to 10,000 mid-tuning). Some minors grew into big factions (Bishop's Men 34, Tunnel Rats 24 districts), which fits the user's Junkie → Warlord idea.
- **Still open:** one runaway in four runs (44 districts), for coalitions in S6. Most minors are gone by year four.
- **Portrait evolution** (leaders' looks aging and changing with government) is parked for S3/S4; see 08-spine.md.

**2026-09-25 (v1.30, spine S1b: expansion)**

- **Expedition is replaced by Scout → Scavenge → Settle.** Scout reveals salvage, danger and people, and chains outward from scouted land. Settle needs a scouted district, costs 12 materials and 5 food, gives +30 influence, and **the whole surviving crew stays** as the district's people (+4 population each). Rejected: keeping Expedition as a combined scavenge-and-claim venture; it hid the investment.
- **Going in blind:** ventures into unscouted land get x0.85 odds and +10% disaster share. Once scouted, the real danger applies instead. Districts have a danger level (0.05-0.4, worse in industry and the docks); Safeguard lowers it by 0.05.
- **Rebuild** (20 materials): +6% development, the last rung of the ladder and the main materials sink once land runs out.
- **Sinks so nothing piles up:** food above 40 spoils at 0.8% a day; each building needs 0.03 materials a day (disrepair stops buildings otherwise); Trade Run now turns 20 wealth into 10 materials and 8 food. Population eats 0.004 food a day each (was 0.003); land grows a little more food (base 0.2).
- **AI:** scouts when nothing known is ready to settle; buys goods only when short (or with over 400 wealth); prefers Rebuild as materials build up; funds ventures at 120+ and 300+ wealth; seats a council only when it can pay the wage. Rivals start with 2 seats, not 4. The base council wage is now 0.02 (+0.02 per district); at one district the old wages equalled a faction's whole income.
- **Fixed on the way:** the AI never built anything while its wealth was under 15, even buildings paid only in materials (a Commune starved for 187 days with 112 materials). The AI was converting surplus wealth into materials through 139 late-game Trade Runs, faster than it could spend them.
- **Result (5 x 4-year simulations with the AI also playing the player's faction):** first expansion at days 57-137; 5-10 districts at year one; the city fills around year four; 9-21 districts at year four; no faction goes broke; starvation at most 12 days. Year-four stocks: food 16-778, materials 51-323, wealth 70-368 (were in the thousands).
- **Fog of war:** both options are built, with a "Full fog" toggle so both can be played. Known gap: the event log still reports rivals' actions in fogged places.
- **Still open:** once the city is full (around year four), little new happens. That's where S2 (the arc) must take over.

**2026-09-25 (v1.29, captains that seemed to vanish)**

- **The captain limit was left over from the multi-district start** (3 + 1 per 4 districts). With one district, factions started over it (4 captains), so a dead or deserted captain was never replaced. Now 5 + 1 per 3 districts.
- **Losses are kept:** a Fallen and departed list on the Council tab (who, seat, how, when, record). This is the first piece of pillar 4's archive of the dead.
- **Moving a seat holder says it empties their old seat,** in the dropdown and in the log (the user saw seats empty as one person moved between them).
- **"No captain is free" names who's away and for how long,** instead of "Choose a captain to lead it".

**2026-09-25 (v1.28, no dead ends)**

- **Playtest bug: a materials deadlock.** Expedition cost 8 materials, and expeditions were the main source of materials, while the Salvage Yard cost 10. A player who used materials on Safeguard dropped to 2, with no way back. The AI avoided it only by luck of priorities.
- **Scavenge pulled forward from S1b:** in your own district or unclaimed ruins on your border; costs 2 food; yields 3 + 12 × ruin materials, strips ruins 4% each time, +3 influence. The district's ruin level acts as its salvage stock, so it can run out.
- **Every "Can't afford it" now names the shortfall and its source** ("Need 6 more materials (have 2 of 8). Materials from Scavenge ruins, ..."). Unaffordable extra funding is disabled in the planner. The player had 0 wealth with +6 funding still selected.
- **New spine rule 5: no dead ends.**
- **Parity check:** with the AI's own logic driving the player faction, it expands at the same pace as the rivals (9 districts at year one). The gap the user saw came from information and the trap, not an AI advantage.

**2026-09-25 (v1.27, spine S1a: the opening)**

- **"At the start you don't have goals, you have problems"** (user, after a Project Zomboid review). Every faction starts with one unsecured shelter, short on food, with no weapons. A Problems line lists what's wrong, worst first.
- **Control ventures:** Secure Food (lasting food source, capped at +0.6 a day per district), Safeguard the Shelter (the main control raiser; Secured at 75), Gather Weapons (arms). Calm districts now drift up only to 55 control; above that takes ventures. Secure Food is free, because charging food for it let a starving faction deadlock (seen in simulation).
- **Food is the engine:** manpower and population grow from a district's food plus 25% of the food of the owner's neighbouring districts (the user's idea). Population is capped by housing (development), pays taxes and eats food.
- **Arms:** raids and assaults use them up (2 and 4); each arm adds 1.5% to attacks and takes 1% off attacks against you (capped at 20 arms).
- **Settlers:** a claiming Expedition leaves 3 crew behind for good. Claims take about 3 successes (+18 influence each, was +25).
- **Tuning result (3 x 4-year simulations):** AI homes are secured at days 11-101 and first expansion comes at days 25-170. No AI faction starves. **Still open for S1b:** year-one expansion of 7-14 districts, and wealth and materials pile up late (the Salvage Yard was halved, taxes cut, AI stops building yards above 80 materials). Manpower sits near its cap for big factions, so it doesn't constrain them yet.
- **Fog of war** moved to S1b: without Scout or salvage stocks there's nothing meaningful to hide yet.

**2026-09-25 (v1.26, build step 2: council and crew)**

- **Diplomacy panel glitch fixed:** the card could grow taller than the screen and was pushed off the top. It now scrolls within the screen height.
- **Council = four seats (War Chief, Quartermaster, Envoy, Fixer), each tied to one skill.** A seat adds +2% per skill point above 4 to every venture using that skill; the Envoy also adds +3% per point to treaty acceptance. Seated members still lead ventures. Rejected: council members being unable to lead (too restrictive with 4-8 characters).
- **Wages:** 0.05 + 0.02 per district held, per seat, per day. They scale with size so they bite late, when wealth piles up. The first try (0.1 + 0.03) left AI factions broke for 50-145 days; the AI now also won't start a building whose upkeep exceeds its daily surplus.
- **Loyalty** works like faction opinion: base 50 plus traits plus named, fading memories. Restless warning below 30; below 20, a 35% monthly chance to desert to the rival that thinks worst of their old faction. Simulated: 1-2 desertions per 4 years across all factions.
- **Traits:** personality (Ambitious 30%, Steadfast 20%) from birth; Veteran, Hero, Scarred and Shaken are earned from what happens on ventures.
- **Portraits** are procedural 2D, seeded by character id (so a save needs no appearance data). Scars and wounds show on the face.
- **The player's seats start empty** (the AI's are filled), so appointing is the first choice you make.
- **Not yet:** families, marriage, faction leaders, succession (steps 3-4); envoy missions led by characters.

**2026-09-25 (v1.25, readability fix)**

- **Buttons get a visible frame; disabled ones are clearly dimmed.** The playtest showed Godot's default button frame is nearly invisible on the dark UI, so every action looked greyed out even when trade and pact were available.
- **Reasons are shown as text, not just tooltips.** Each diplomacy card lists "Not available now" with the reason for every blocked action. The venture planner's large green LAUNCH button names the venture, or shows the blocking reason in orange, or "Under way: back in N days" once launched.

**2026-09-25 (v1.24, build step 1: venture overhaul)**

- **Every venture needs a leader: a named captain** with four skills (Command, Cunning, Diplomacy, Stewardship). The venture's skill shapes its odds (±5% per point from 4), its Triumph share and its speed. Captains start at 4 per faction; more join monthly, up to a cap that grows with territory and renown. Council posts, families and succession come later on this Character class.
- **The planner:** choose the leader, a crew size within the venture's range (+6% odds per extra crew; losses on Setback and Disaster scale with crew), and 0-2 levels of extra funding (+10% odds each). All four tier chances are shown before you commit.
- **Tier split:** the Triumph share of success is 6% + 2% per leader skill point; the Disaster share of failure is 10% + the venture's danger − 2% per skill point. Tuned by simulation: the first values made Triumph 29% of all outcomes, far too common to feel special. Now about 21%, with Disaster about 1%, because factions mostly pick good odds. Disasters kill the leader 25% of the time (5 deaths across 4 factions in 4 simulated years).
- **Construction and envoy missions don't take leaders yet.** Envoys become led ventures when the council's Envoy post arrives (build step 2).

**2026-09-25 (v1.23, 2.5D map)**

- **Buildings are 2.5D solids in the existing 2D renderer (option A).** An implied camera tilted from the south: each building shows its camera-facing walls (shaded by direction) and a roof lifted by its height; pitched roofs have gables; everything is drawn back to front and cached once. Also terrain beyond the city (forests, farmland, a railway) for an HOI4-like surround. Rejected for now: (B) a real 3D map view, which conflicts with the one-pager's "2D, UI-heavy" solo scope and would look blocky without modelled art; (C) pre-rendered sprites, which need an art pipeline. Revisit C, then B, only after the playbox proves the loop is fun (same logic as the 3D portraits decision).

**2026-09-25 (v1.22, purpose, diplomacy polish, living map)**

- **Ambitions and renown give the game goals.** Milestone ambitions in five areas (data/ambitions.json) with visible progress; achieving one earns renown (crew limit, treaty odds, respect). AI factions pursue the same ambitions. Inspired by CK3 ruler objectives. Rejected: a fixed win condition (pillar 5 stays open-ended).
- **Renown earns respect only from those with less of it.** In simulation, an absolute respect bonus lifted everyone's opinion of everyone and ended all wars; the relative version keeps rivalries alive.
- **Opinion is a lasting baseline plus named, fading memories** (data/opinion_modifiers.json, CK3 opinion modifiers). Every change has a visible reason and a fade rate; broken treaties are remembered longest.
- **AI stances are visible, and war only comes from TARGET.** The stance uses the same deterministic war judgement the AI acts on (HOI4 AI attitudes), so what the panel shows is what the AI will do.
- **Treaty timers everywhere, a 30-day lapse warning, renewal in the final 90 days.** Answers the question of when a pact runs out.
- **The map shows life, not just ownership.** Close zoom (6x), the faction wash fades to borders up close, buildings with roofs and shadows, name-matched landmarks, wrecked cars, and each faction's flags, campfires, gardens and built structures. Building something now changes the city you look at.
- **Known:** late-game wealth still piles up; late ambitions need war or diplomacy.

**2026-09-25 (v1.21, map overhaul)**

- **The city layout is data (data/map.json), generated by a design-time tool** (tools/generate_map.gd), following CK3's map-as-data approach. The game only reads the file, so the layout can be regenerated with another seed or edited by hand. Rejected: generating the map at game start, which made the city an accident of the RNG rather than something designed.
- **Bigger, organic city:** ~60 Voronoi districts clipped to a wobbly city outline inside wasteland, denser downtown, grouped into 8 compass-named boroughs that echo the factions' home turf (Westgate, Canal District, Southside, Eastfield).
- **A river along district borders, crossable only at a few bridges.** Districts on opposite banks are neighbours only where a bridge crosses, which makes bridges strategic chokepoints. Rejected: a river drawn through districts with no effect on play.
- **District types** (downtown, residential, industrial, docks, parkland, suburb, outskirts) set starting stats and the art. Gameplay differences beyond starting stats are deferred.
- **Procedural art in code** (user's choice): wasteland texture, street grids, building footprints ruined in proportion to ruin level, rubble, overgrowth, parks, roads, river and bridges. It's built once and cached, so it costs nothing per frame. HOI4-style presentation: a see-through faction wash (thinning as you zoom in), heavy borders where ownership changes, and screen-space labels that switch from boroughs to districts with zoom.

**2026-09-25 (v1.20)**

- **Diplomacy is opened by right-clicking a faction's territory** (a panel at the cursor), Paradox-style. The Diplomacy tab becomes an overview of proposals and one line per faction. Rejected: a tab of full faction cards, which felt detached from the map.
- **Paradox game files are reference only.** The user has HOI4 script zips locally; they may be read to study how Paradox structures systems (AI weighting, opinion modifiers, events), but no scripts, text, numbers or art are copied into this game.

**2026-09-25 (v1.19, diplomacy)**

- **Diplomacy before the map overhaul.** The one-pager's core loop is Survive → Organise → Diplomacy → Scale → Compete, but diplomacy was only war or peace, so play collapsed into "destroy the other faction". With only two factions there was nobody to trade or ally with, so the scenario now has four factions with distinct trait identities.
- **Opinion drifts toward a trait- and treaty-driven baseline.** Each trait lists traits it likes and distrusts in others (the "diplomatic consequence" every trait needs); treaties, common enemies, border tension and land hunger add to it; gifts, raids and betrayals are temporary pushes. Every reason is shown to the player. Rejected: a single hidden relations number.
- **Diplomatic actions follow the venture shape:** pay, send an envoy that travels for days, then resolve against a shown acceptance chance with its factors. AI proposals to the player wait for an answer instead of rolling. Data-driven in data/diplomacy.json.
- **Treaties:** trade (needs a connection: touching borders or Markets on both sides), non-aggression pact (2 years), defensive alliance (3 years, allies join wars), vassalage (tribute, joins wars) and integration (peaceful merging). Rejected: permanent treaties, which froze the city into perpetual peace in simulation.
- **Anti-snowball and anti-stagnation pressure.** Administration upkeep grows faster than territory; vassalage needs a strength gap and a reason to seek protection; integration needs a year of loyalty and costs more for bigger vassals; resentful strong vassals break away. Against stagnation: treaties lapse, land-hungry factions covet neighbours, rich factions grow bolder, and AIs will betray a pact when a war is worth it. Tuned by simulation: before these, one faction absorbed the whole city by day 677; after, four factions coexist with recurring wars and shifting treaties.

**2026-09-24 (v1.18, buildings)**

- **Buildings live in district slots (Claimed 1, Secured 2), take crew and days to build, and cost daily upkeep.** They mostly buy things resources can't otherwise buy (defence, stability, crew capacity, development) rather than more resources, so they act as a sink. They transfer with the district when it changes hands, and raids and revolts can wreck them. Data-driven in data/buildings.json.
- **Construction is deterministic, not a venture with odds.** Building is investment, not a gamble; a failed roll that wastes the cost felt punishing with no upside. It still follows the venture shape (commit crew and resources, wait days). This is a deliberate exception to pillar 1.
- **One venture of each type per district per faction at a time.** Rejected: unlimited stacking, which let players queue 15 expeditions into one district.
- **Known issue:** buildings absorb wealth for about the first 18 months; once all slots are full, wealth piles up again. The long-term sinks are expected from characters (step 2), internal factions (step 4) and crises such as tribute demands (step 5), plus possibly building upgrades or wealth-spending ventures.

**2026-09-24 (v1.17, spine refactor)**

- **The simulation supports any number of factions; diplomacy is per pair.** War, truce, exhaustion and opinion live on a Relation between each pair of factions, and each AI faction runs its own FactionAI. Rejected: hard-coded player/rival with a single global war flag, which would block internal factions and civil war (pillar 5).
- **Content lives in data/*.json; code provides building blocks.** Ventures are assembled from named targets, odds factors and effect ops; traits declare venture modifiers and named effects; the scenario and tuning numbers are data too. Data is validated at startup. Rejected: per-venture code branches (every new venture meant code changes in several files).
- **Save files use Godot's binary Variant format, not JSON.** JSON doesn't round-trip floats exactly, and the tiny errors grow until a loaded game plays out differently from the original. Determinism (a reloaded game plays out identically) is enforced by tests/spine_test.gd.

