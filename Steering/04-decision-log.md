# Decision Log

Decisions that still stand: each with what was rejected and why. New entries go at the top. Check this before relitigating a settled question. Per-build detail (numbers, tuning, simulation results) is in /CHANGELOG.md.

**2026-09-29 (standing tasks; see 13-standing-tasks.md)**

- **Routine ventures on your own land become standing tasks:** Scavenge, Rebuild, Safeguard the Shelter, Secure Food, Relief, Gather Weapons and Reinforce. A councillor is assigned to a district and works it venture after venture until the district's own state says it's done (ruins stripped, fully rebuilt, fully controlled, food sources worked, calm, armoury full, threat gone). Every run is still a venture with the same odds and outcomes (pillar 1). The rule of thumb: the system takes actions, the player makes decisions. Rejected: launching every routine venture by hand (too many clicks for no decision), and queues or automatic reassignment (the player decides every assignment).
- **Only council seats hold tasks,** so choosing the council is the key decision. At most four tasks at once.
- **One-offs stay one-offs** where there's a real decision or someone else involved: Scout, Settle, Negotiate, scavenging unclaimed ruins (it builds a claim), Trade Runs, Raid, Assault, Agitate, Threaten.
- **Commitment:** an assigned councillor is committed for two runs of the task. Stopping costs nothing, but they take no new work until those two runs have passed. A task that ends naturally frees them at once. No queue, no auto-reassignment.
- **The opportunity cost of doc 11 stays:** every run pays its venture's cost, and the councillor and crew are taken for the whole task. A task that can't pay pauses; one whose councillor is wounded pauses until they heal. Task runs wound half as often as one-off launches.
- **The AI assigns tasks the same way,** from its one list, with the same eligibility (pillar 3).

**2026-09-28 (S4 choices; see 12-choices-ambitions-and-government.md)**

- **Renown splits in two.** *Reputation* is everything a faction has ever earned and never goes down; it carries renown's passive effects (crew and captain limits, recruit quality, the heir's claim, respect). *Renown* is what you spend, on ambitions and some reforms; unspent, it adds a minor diplomacy bonus. Rejected: one number, where spending renown would shrink your crew limit.
- **The automatic milestones stay, as Deeds,** the source of renown. Rejected: replacing them with chosen ambitions (the spine's parked note), which would leave renown with almost no income.
- **National Ambitions are deterministic:** a renown cost, a timer, a lasting bonus, sometimes a condition while running. One at a time, gated by situation, some mutually exclusive, some unlocking reforms. Rejected: ambitions as ventures with odds (you're investing, not gambling).
- **Governments:** Gang (new, where minor factions start), Warlord (majors), Autocracy, Politburo, Merchant Oligarchy, Democracy. Each sets its own succession rule and way of breaking: Autocracy splits rarely but badly; the Politburo purges instead of splitting; the Oligarchy bribes its way through a succession; Democracy is slow and safe.
- **Reforms are decisions:** a cost, a transition (grievance and a loyalty test), and a 2-year lock. Gates that 07 tied to tech use the faction's situation instead, since tech comes after the playbox. **Democracy is only reachable at a leader's death.**
- **Council approval:** councillors back or oppose each reform by their traits, and opposing costs loyalty when it's taken anyway. Under the Politburo, the Oligarchy and Democracy the council votes, and a majority against blocks it.
- **Portraits by government stay parked.**

**2026-09-27 (earned odds and pace; see 11-earned-odds-and-pace.md)**

- **Preparation buys certainty and quality.** Odds are clamped to 5-98% (was 5-95%, set in 07 §4.3). A success's gains scale x0.8 to x1.2 with how cleanly the roll landed, and Triumph's share grows with the odds. No Disaster above 90% odds. Aimed ventures compare your crew with the defenders on site ("outnumber the defenders"). Rejected: a fixed success band, where preparing well bought *whether* but never *how well*.
- **Odds can still change after you commit (the target can react, 07 §4.2), but never silently:** the planner warns when defenders could arrive, the outliner shows live odds, and the log says when and why the odds moved. Rejected for now: locking odds at launch, which would remove the reaction for a problem that transparency solves.
- **Wounds scale with the venture's danger:** low-danger work wounds less often and for less time than raids and assaults. Deaths stay tied to Disasters, so mortality keeps its weight (pillar 4). Rejected: a flat 30% wound chance for 30-60 days on every setback, which punished careful play.
- **Minor factions lose their authored personality** (raider, trader, hermit). What a faction is keen on comes from its traits, for minors and major factions alike (pillar 2). Rejected: keeping a separate personality flag next to the trait engine.
- **The AI weighs building and ventures on one list,** so spending at home competes with expanding (pillar 3: the same weighted scoring). Expansion carries a running cost in materials as well as wealth. The pace target (about 65% of the city claimed at year one) is provisional until tuned in simulation.
- **Tech stays after the playbox** (unchanged). Re-measure the pace once the shared AI budget and expansion costs are tuned.

**2026-09-27 (raiders and deterrence; see 10-raiders-and-deterrence.md)**

- **A raid is worth what the district is worth.** Loot scales with the target district's development and working buildings (x0.4 to x1.5), and the AI weighs raids by that worth. Bonus loot only on a Triumph. Rejected: loot from the victim's whole stockpile, which made a fresh claim as good a target as a capital.
- **Raids have a per-district cooldown:** 30 days after a raid, 45 if it failed, 60 after a disaster, for all raiders. Rejected: a per-raider cooldown, which would let a second gang take its turn straight away.
- **Threaten is a venture** (Command, odds from your strength and arms; success buys 45 days without raids, a triumph 90; a disaster emboldens them). **Pay tribute is a deal**, like gifts: no odds, always accepted. Rejected: Threaten as a diplomatic action, since it's risky and needs a leader, which is what the one-verb rule is for.
- **Tribute is paid in food or materials, never wealth,** so a poor faction always has an answer. Pacts can be paid in wealth, food or materials. Raiders halve their willingness to sign pacts; tribute and threats are the raider answer. **A pact needs a shared border** (it only forbids raids, agitation and war, which all need one), and the AI only offers one to a stronger neighbour it has reason to fear. Rejected: pacts with anyone, which had every faction offering the player a pact before meeting them.
- **Anyone can demand tribute** (AI plays by the player's rules). Refusing emboldens the demander (+20% raid odds for 60 days). The first demand from each faction is a pop-up; later ones go to Proposals.
- **Raiding a built-up district (worth 1.0+) costs the raider -5 opinion with every neighbour of the victim.** An early piece of S6's aggression memory, taken now because it's small and it's what makes raiding rich targets cost reputation.
- **Watchtower costs materials only** (25). Rejected: an emergency discount under threat, a hidden rule the player would have to discover.

**2026-09-27 (wording only; no rule changed)**

- **"Shared pool" means shared data, not a shared list.** Each faction has its own National Ambitions: which ones it can pursue depends on its traits, government, tech and situation, so factions see different lists. They are still written once in one data pool, not authored per faction (the 2026-09-25 amendment stands). Docs reworded to say this; National Ambitions and the renown review are S4, not S3 (stale references from the old build order fixed).

**Standing rules established during builds (v1.16–v1.38)**

- **No dead ends (spine rule 5).** Every resource needs a source that doesn't cost that same resource, and every "can't" says what's missing and where to get it. Materials have a renewable source (Recycling Works) and ruins regrow. (v1.28, v1.38)
- **Once land is claimed, other factions can only trade, raid or assault it.** Scouting is limited to unclaimed land; peaceful work on land someone else has claimed is called off. (v1.33)
- **Expansion costs people:** Scout → Scavenge → Settle; settlers stay for good. One-district start; control ventures consolidate land. (v1.27–v1.30)
- **Food is the engine:** a district's food (plus 25% of its owned neighbours') grows population and manpower. Hoards leak: food spoils, big wealth and materials stockpiles lose 1% a day. (v1.27, v1.31)
- **Pressure before the arc:** minor factions sit close to the big ones so neighbours matter in the first months. (v1.31)
- **Threats are visible and answerable:** war countdowns, incoming-attack alerts, defence shown per district, Reinforce as the counter. (v1.32)
- **Warlord succession** with contested claims and civil-war splits; leaders always married; heir can be named at a loyalty cost; ruling traits are earned. (v1.33, v1.34)
- **UI:** map-first frame (09-ui-plan.md); explanations live in tooltips; nothing shown twice; costs on the button where you commit. (v1.34–v1.37)
- **Determinism:** all randomness through the game's own RNG so saves replay identically. (v1.34)
- **Paradox files are structural reference only:** never copy script, text, numbers or art; screenshots and zips are never committed. (v1.20)

**2026-09-26 (UI plan approved; see 09-ui-plan.md)**

- **The one-panel, six-tab UI is replaced** by a map-first frame: top bar with hover breakdowns, alert icons, the leader's portrait, one window at a time on the left, a district panel, an outliner on the right, and a menu row. Built from the user's CK2/CK3/HOI4 screenshots (patterns only, no copied art or layouts). Rejected: adding a Dynasty tab to the existing panel, because the panel was already overloaded and S4 would add more.
- **Decisions:** windows open on the left and the outliner on the right; event pop-ups inform only until S4; Esc opens a game menu with save/load (F5/F9 removed; F1-F7 open windows); designate heir is in S3b, tutors wait for S5.

**2026-09-25 (spine decisions)**

- **Materials** becomes a resource (the build input, from scavenging). **Manpower** replaces "crew" as the resource name. Settlers are gone for good, but developing districts produce new manpower.
- **One-district start for every faction.** The opening is control ventures at home (Secure Food, Safeguard the Shelter, Gather Weapons); the same ventures consolidate every district later. Rejected: a base-builder inside the district (not-doing list: no block-by-block simulation).
- **Map art: option B**, real 3D generated in code, after S1a.
- **Fog of war:** undecided. Build "unknown ruins only" first, then try terra incognita in S1b.
- **Renown becomes a currency (S3):** invested to start a National Ambition, which grants a lasting bonus on completion. Unspent renown gives only a minor diplomacy bonus, so the choice is a return on investment versus weight in negotiations. Rejected: renown as a passive standing with many small effects, where nothing was ever spent.
- **08-spine.md approved by the user** as written.

**2026-09-25 (the spine; see 08-spine.md)**

- **Stop adding systems one at a time; build around one loop (scavenge → build → population → crew and taxes), one verb (ventures) and one arc (growth → strain → a death → hold or split).** Every new idea must say which of these it strengthens. Rejected: continuing the outline's step list (bloodlines next), because the economy has no working loop and nothing yet can fall apart, so each new system could only be a bonus.
- **New build order:** S1 the loop (materials, Scout/Scavenge/Settle, territory ladder, population as the engine), S2 the arc (leader death, succession, council agendas, splits), S3 choices (National Ambitions screen, government reforms), S4 bloodlines and marriage, S5 coalitions and crises. Map art after S1.

**2026-09-25 (design: characters, government, progression; see 07-characters-and-ventures-outline.md; not built)**

- **The crew is the council; the bloodline is the family.** Named crew hold four council posts (War Chief, Quartermaster, Envoy, Fixer, mapping to CK2's council), lead ventures and carry political weight. The leader's family supplies heirs and marries into other factions' bloodlines. Rejected: bloodline-only (CK2 default; conflicts with pillar 4's persistent crew) and crew-only (loses marriage diplomacy).
- **Marriage between bloodlines is a diplomatic venture.** It creates lasting family ties (better odds for pacts, alliances and trade) and claims on the other faction's succession: a peaceful route to power that also feeds the collapse cycle.
- **Government emerges from play, then is confirmed by reform decisions.** Everyone starts as Warlord; decisions unlock when behaviour qualifies (e.g. Autocracy, a socialist Politburo, a Merchant Oligarchy, or Democracy by holding elections on a leader's death). Reforms cost something and bring a transition period. Each government sets the succession rule and risk profile (pillar 5).
- **Ventures get four outcome tiers (Triumph, Success, Setback, Disaster), each with its chance shown before you commit,** plus a leader, player-chosen crew size and optional funding. Rejected: two tiers (every failure would risk the leader, making death cheap) and three (no upside for sending skilled leaders).
- **Deliberate incentives against war:** aggression memory leading to coalitions (EU4 pattern), research slowed by war and shared through trade, marriage ties, and peaceful ambitions.
- **National Ambitions as a shared, condition-gated pool, not per-faction trees.** This amends the not-doing list's exclusion of HOI4-style focus trees. The exclusion existed because of the solo authoring cost and "players solve for the optimal branch"; a single shared pool gated by emergent state (traits, government, tech) avoids both. The AI picks by weighted scoring, and its current pick is shown. The existing automatic ambitions become Milestones.
- **A tech web (longer term)** on a new Knowledge resource: 20-30 techs over 3-4 eras, unlocking buildings, ventures, reforms, National Ambitions, and policies that shift culture stats (the design docs' media axis). Likely vertical-slice scope.
- **Build order agreed:** venture overhaul → characters → bloodlines and marriage → mortality and succession → government → aggression memory and coalitions (Playbox scope), then National Ambitions and tech.

**2026-09-24**

- **Time is continuous and pausable (Paradox-style), not turn-based.** Days tick in real time at 5 speeds. Ventures take days to resolve, several run in parallel, and the AI acts on the same clock, so the world keeps moving while your crews are out. Threats are telegraphed as alerts that can auto-pause the game. Rejected: discrete turns, which made the world feel static and unreactive. Implemented in v1.16.
- **Territory is frontier-based: factions act only in districts they own or that border land they own.** Expeditions only claim unclaimed land; raids and agitation only target enemy-held land and never grant influence. Rejected: reach from any 10% foothold, which let factions chain influence across the map into the far side of enemy territory.
- **Ownership pays; influence alone doesn't.** Only the owner (50+) gets income and recruits; Secured (75+) gives 1.5x yield, is 30% harder to raid/assault/agitate, and can't revolt. Crew is capped per district held. Rejected: income split by influence share, which made securing land pointless.
- **Taking enemy land requires war (Assault) or engineered revolt (Agitation).** War is declared (with a cost), builds war exhaustion on both sides, and ends in peace plus a 120-day truce. The AI telegraphs war 15 days ahead. Raids are economic harassment only.
- **Relief venture feeds the Socialist trait.** Spending supplies and wealth to lower grievance is the counter to agitation and the welfare behaviour that pillar 2 names as the source of Socialist identity.

**2026-09-22 — Logged retrospectively from the initial design conversation.**

- **Portraits start 2D, layered (CK2-style).** Rejected: 3D portraits as a v1 commitment — real ageing/inheritance/resemblance system is a months-long solo QA cost (see CK3 vs CK2 precedent); revisit only after playbox proves the core loop.
- **Player death → successor from the same crew, or restart.** Rejected: hard game-over on leaderless death (CK2 default) — too punishing for a fragile early-game scav and would wreck playbox retention. Player starts as a *crew*, not a lone scav, specifically to support this.
- **Faction and leader traits are behaviour/policy-derived, on one shared trait engine.** Rejected: HOI4-style authored branching trees — too much writing/balancing/art for solo scope, and players tend to solve for the optimal branch. Each trait needs a benefit, a cost, and a diplomatic consequence.
- **Tech/policy choices (e.g. long-form vs short-form media) shift population culture stats over time, which cross thresholds into traits.** Rejected: policy choices granting traits directly — keeps everything flowing through one trait pipeline. Policy changes are slow and costly to reverse; a switch mid-game causes a destabilising transition period rather than an instant re-spec.
- **City map is district-based (25–40 districts), not block-based.** Rejected: Infection Free Zone-style block-by-block capture — wrong genre fit (city-builder/RTS scope) for a strategy game whose systems (grievance, agitation, revolt, civil war) are all keyed to area-level decisions.
- **Districts support fractional influence/ownership; highest share controls.** Enables gradual border shift and contested districts as natural flashpoints for agitation/revolt, and clean civil-war territory splits.
- **Regional map is a node graph (settlements, nomad territories, remnant state) with stats only — not simulated cities.** Rejected: fully simulated multi-city regional layer — scope multiplier the project can't absorb solo. Added at vertical slice, not in the playbox.
- **Faction AI uses weighted scoring over standing goals + available actions (Paradox `ai_will_do`/`ai_chance` pattern).** Rejected: machine-learned or LLM-driven runtime AI — unpredictable, hard to debug, unreadable to players. AI and player use the same action set; difficulty scaling via resources, not hidden cheating.
- **Endgame is open-ended sandbox with a collapse cycle, not a fixed win state.** A leader's death is the highest-risk moment; collapse odds are probabilistic (succession strength × accumulated grievance), not scripted. Rejected: a defined victory condition (e.g. "recognised nation") — would turn the late game into a victory lap and remove the pressure the design otherwise relies on.
- **Internal political factions (Military, Socialists, Conservatives, player's own faction, etc.) run on the same trait/AI engine as external factions.** Civil war plays out as a territory split on the existing district map; the player continues play within whichever faction they belong to rather than hitting a game-over.
- **Players can deliberately engineer a rival faction's collapse** via spies (mortal crew members with traits) and an opt-in agitation heat map, using the same fund-a-venture pattern as expeditions. Failure has consequences (capture/exposure) that feed the "Subversive"-type trait pipeline. AI factions have access to the same tools against the player and each other.
- **Agitation visibility is opt-in with threshold alerts.** Players who don't monitor the heat map still get notified as a district nears revolt, so collapses don't feel arbitrary to non-watchers.
- **Off-map pressure (nomad hordes, remnant-state tribute demands, etc.) is handled by a small set of authored "crisis" templates (a crisis/event director)**, triggered by state conditions (size, wealth, era, stability) and telegraphed in advance, in the spirit of EU4 disasters / Stellaris endgame crises. Start with 5–8 templates.
- **Game development process follows the discover → definition → design (lo-fi/greybox → hi-fi/vertical slice) → build (production → alpha → beta → gold) programme model, with kill-gates and pre-defined exit criteria at each stage, and a promotional/community workstream running in parallel starting from the earliest showable build (playbox clip or vertical slice).**
- **Playbox is the first gate.** Greybox city map, resource loop, workers, and the first two-to-three faction tiers. Exit criteria: players voluntarily start a second run and generate stories worth telling/clipping — not just "bug-free."
