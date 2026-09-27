# Decision Log

Decisions that still stand: each with what was rejected and why. New entries go at the top. Check this before relitigating a settled question. Per-build detail (numbers, tuning, simulation results) is in /CHANGELOG.md.

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
