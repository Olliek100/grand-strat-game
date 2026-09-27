# Characters, Ventures, Government and Progression: Outline

**Status: design agreed in outline (2026-09-25). Build step 1 (venture overhaul) is done in v1.24; step 2 (council seats, loyalty, wages, character traits, portraits) in v1.26. Not built yet: the Crew → Captain → Council → Family → Leader status ladder beyond council seats, envoys led by characters, and steps 3 onwards. **Build order superseded by 08-spine.md (2026-09-25).**** It covers what the design docs (01-05) commit to, the decisions made since, and the proposed model for each system. Remaining open questions are marked **OPEN**.

Structural references come from `06-paradox-reference-notes.md` (CK2/CK3/HOI4/EU4, reference only).

---

## 1. Foundations

### From the design docs (01-05)
| Commitment | Source |
|---|---|
| You start as **the leader of a scav crew**, not a lone scav | One-pager; decision log |
| Characters are **mortal, CK2-style (not CK3)** | Pillar 4 |
| **Status gates relationships and succession** | Pillar 4 |
| Death is a real event, **not a game-over**; if a leader dies with no heir, a crew member succeeds | Pillar 4; decision log |
| **Leader traits** are earned from behaviour on the shared trait engine, and **can be inherited or shaped by history** | Pillar 2; glossary; decision log |
| A venture's odds are shaped by **who you send, their traits**, faction traits and **tech/policy** | One-pager; glossary; pillar 1 |
| **Spies are mortal crew members.** Failed agitation risks **capture or exposure** | Decision log |
| **A leader's death is the highest-risk moment.** Collapse odds = **succession strength × grievance** | Decision log; glossary |
| **Government type changes succession risk**: autocracy is fast, cheap and fragile; democracy is slower, safer and prone to gridlock | Pillar 5 |
| **Tech and policy choices shift culture stats**, which produce traits past a threshold (e.g. the long-form vs short-form media axis) | One-pager; pillar 2; glossary |
| **Portraits:** living characters get 2D layered portraits; dead leaders are archived as flat 2D. No 3D in v1 | Pillar 4; not-doing list |

### Decisions made (2026-09-25)
1. **The crew is the council** (CK2's council). Named crew hold council posts, lead ventures, and carry political weight.
2. **The bloodline is the family.** The leader's family supplies heirs and **marries into other factions' bloodlines**, which creates ties that make alliances, pacts and trade easier.
3. **Government emerges from how you play, then is confirmed by decisions** that the player and AI take. Example paths: a warlord evolving into an autocracy, or into a socialist politburo, or holding elections for democracy on a leader's death.
4. **Four outcome tiers** for ventures: Triumph, Success, Setback, Disaster.
5. **Incentives not to go to war** are a design goal.
6. **A tech tree** (longer term), which gives players and AI a reason to gather resources and advance.
7. **National Ambitions**, inspired by HOI4 national focuses, **as a shared pool gated by conditions, not per-faction trees.** This amends the not-doing list (see the decision log).

---

## 2. Characters

### 2.1 The cast
- **Crew pool (anonymous):** the current crew number. It supplies the manpower for ventures and construction.
- **Council (named crew):** four posts, each tied to one skill and one kind of venture.

| Council post | CK2 equivalent | Skill | Leads |
|---|---|---|---|
| **War Chief** | Marshal | Command | Raids, assaults, defence |
| **Quartermaster** | Steward | Stewardship | Expeditions, trade runs, relief; speeds construction |
| **Envoy** | Chancellor | Diplomacy | Envoy missions, negotiation, marriages |
| **Fixer** | Spymaster | Cunning | Agitation, spying, assassination, rescue |

- **Captains (named crew without a post):** can lead ventures. They are promoted from veterans of successful ventures, or attracted by renown.
- **Bloodline (the family):** the leader, spouse, children and close kin. They are the preferred heirs, and they're what you marry off.
- **Size:** about 8-12 named characters per faction (the council, a few captains, the family). That keeps it readable and cheap to simulate for four or more factions.

### 2.2 Character sheet
- **Name, age, sex, portrait** (2D layered, procedural placeholder).
- **Four skills (0-10):** Command, Cunning, Diplomacy, Stewardship.
- **Leader traits:** earned from what they do (2.4).
- **Health:** healthy, wounded (unavailable for a while), maimed (lasting penalty), dead.
- **Status (2.3).**
- **Loyalty to the leader:** named, fading memories, using the same system as faction opinion. Disloyal council members back internal factions, contest succession or defect.
- **Family links:** parent, spouse, children, and which bloodline they belong to.

### 2.3 Status ladder (pillar 4)
**Crew → Captain → Council → Family → Leader** (the family ranks by closeness to the leader).
- Only council members and family can be heirs or claimants.
- Marriage needs matching status: a leader's child marries another faction's leader's family, not a captain.
- **Earning rank:** ventures led, renown, service. **Losing rank:** failures, being captured, disloyalty.

### 2.4 Leader traits (pillar 2: earned, not chosen)
- **Earned from what they do:** leading raids builds *Ruthless*, surviving a disaster gives *Scarred*, envoy successes build *Silver-tongued*, repeated relief builds *Beloved*, and so on.
- **Inherited:** children can pick up a parent's trait, partly (glossary: "can be inherited").
- **Opposites and like-minds (CK3 pattern):** a character can't be both Ruthless and Beloved. Characters who share traits like each other; opposite traits breed dislike, including between factions' leaders.
- **The leader's traits spread to the faction:** a Ruthless leader moves the faction toward Militaristic.

### 2.5 Council politics
- Council members advise on and **vote on reform decisions** once the government allows it (Council, Politburo, Democracy), as CK2's council does.
- A disloyal council member can **lead an internal faction** (the collapse pillar). Firing them costs loyalty from the others.

### 2.6 Bloodlines and marriage
- **Marriage is a diplomatic venture** led by the Envoy. It needs eligible characters of matching status on both sides, and both factions must agree (shown acceptance odds, as with treaties).
- **What a marriage gives:**
  - a lasting **"Family ties"** opinion bonus between the two factions
  - better odds for pacts, alliances and trade between them
  - both leaders' opinions of each other shaped by their traits
- **Claims:** children of a mixed marriage have **a claim** on the other faction's succession. When that faction's leader dies with a weak succession, the claimant can inherit it (a merger) or contest it (civil war). A peaceful road to power, and a source of emergent drama.
- **War with in-laws** costs council loyalty and breaks the family tie.

### 2.7 Mortality
- **Causes:** venture Disasters (4.4), assassination (a hostile Fixer venture), illness (more likely in crowded, high-grievance districts), old age, execution after capture.
- **Life expectancy:** a leader's expected term is **3-6 in-game years**, so a run of a few hours sees several successions.
- **Telegraphed where fair** (pillar 3): wounded, ill or elderly characters show a risk indicator.
- Dead leaders go to an **archive** of portraits, one line each, a chronicle of the faction's history.

### 2.8 AI factions
Every faction has the same council and family, and runs the same succession (pillar 3). The diplomacy panel shows its leader (portrait, traits, age, health), its heir and its marriageable family. An ageing leader with a weak heir is a readable opportunity.

---

## 3. Government

### 3.1 Governments and paths
Every faction starts as a **Warlord** crew. Reform decisions move it along paths. A decision **unlocks when the faction's behaviour qualifies it** (traits, culture stats, tech, situation), and then **the player or AI chooses** to take it.

| Government | How it's reached (example requirements) | Succession | Risk profile (pillar 5) |
|---|---|---|---|
| **Warlord** | Starting government | Strongest council member or named heir; contested easily | Fast, very fragile |
| **Autocracy** | Decision "Crown a Strongman": strong leader, Militaristic or high renown, 12+ districts | Named heir (family first) | Fast, fragile |
| **Politburo** (socialist one-party) | Decision "Form the Party": Socialist trait, high welfare culture, a Relief record | The council elects from party members | Medium speed; purges instead of civil wars |
| **Merchant Oligarchy** | Decision "Charter the Guilds": Merchant trait, 3+ trade agreements | The wealthiest council member | Medium; bribery and corruption |
| **Democracy** | Decision "Hold Elections", taken **on a leader's death**: stability, a civic tech | Election among qualified characters; caretaker period | Slow, safe, prone to gridlock |

Reforms **cost something** (wealth, renown or loyalty) and bring a **transition period of instability**: higher grievance, and council loyalty tested. Some are hard to reverse. Each government changes the **succession rule**, the **council's powers**, and which **National Ambitions** are available.

### 3.2 Succession
- **Succession strength (0-100)** is a single visible number, made of:
  - how legitimate the heir is (their status, whether they were named, bloodline)
  - rivals' and claimants' combined power, including foreign claimants through marriage
  - council loyalty
  - the heir's renown
- **On a leader's death:** collapse odds = (1 − strength) × accumulated grievance (from the decision log). High odds mean internal factions and claimants press demands (the CK3 faction pattern), which can lead to civil war and a split map.

---

## 4. Ventures, defined

### 4.1 What a venture is
A **venture** is an operation your faction launches: **a leader and crew, committed with resources, against a target, for a stated time, with odds you can read in advance, resolving into one of four outcome tiers that change the world, the leader and the faction's identity.**

| Part | Today (v1.23) | Proposed |
|---|---|---|
| **Sponsor** | ✓ | — |
| **Leader** | — | **Required**: a council member, captain or family member. Their skill and traits shape the odds |
| **Crew** | Fixed per type | **Player-chosen** within a range: more crew means better odds and more lives at risk |
| **Resources** | ✓ | Optional **extra funding** for better odds (a wealth sink) |
| **Target** | District or faction | — |
| **Duration** | Fixed | Base, adjusted by leader skill |
| **Odds** | Shown with every factor | Adds leader skill, leader traits, crew size, funding |
| **Outcome** | Success or failure | **Four tiers** |
| **Feedback** | Faction traits, world | Also the **leader's** traits, rank, health and loyalty |

### 4.2 Life cycle
1. **Plan:** choose the target, type, leader, crew size and funding. The odds for each tier update live.
2. **Commit:** pay the cost; the leader and crew become unavailable.
3. **Under way:** shown on the map. It can be **reacted to**: the target sees hostile ventures and can reinforce or counter.
4. **Resolve:** a roll gives the outcome tier.
5. **Return:** survivors come back, the leader's fate is applied, and the log tells the story.

### 4.3 Odds
**Base × leader skill × leader traits × faction traits × council post bonus × crew size × funding × target factors**, clamped to 5-95%. Every factor is shown.

### 4.4 Outcome tiers
| Tier | Chance (all four shown before you commit) | Effect | Leader |
|---|---|---|---|
| **Triumph** | The top slice of the success chance; **leader skill widens it** | Full effect plus a bonus (extra loot or influence, renown) | Experience; may earn a positive trait or rank |
| **Success** | The rest of the success chance | Full effect | Experience |
| **Setback** | Most of the failure chance | Nothing gained; some crew lost | May be wounded |
| **Disaster** | The bottom slice of the failure chance; **danger widens it** (hostile target, defenders, low skill) | Heavier crew losses; diplomatic fallout on hostile ventures | May be **captured** or **killed**; may earn *Scarred* |

**Why four:** separating Setback from Disaster keeps leader deaths rare and feared (pillar 4), and Triumph rewards sending your best people. Example of what the panel shows: *Triumph 12% · Success 46% · Setback 34% · Disaster 8%*.

### 4.5 Catalogue
| Venture | Skill | Council post | Notes |
|---|---|---|---|
| Expedition | Stewardship | Quartermaster | Claims unclaimed land |
| Negotiate | Diplomacy | Envoy | Peaceful claim |
| Trade Run | Stewardship | Quartermaster | Wealth |
| Relief | Stewardship | Quartermaster | Calms grievance |
| Raid | Command | War Chief | Economic harassment |
| Assault | Command | War Chief | War only; takes land |
| Agitation | Cunning | Fixer | The spy loop: capture or exposure on Disaster |
| **Envoy missions** (gifts, treaties) | Diplomacy | Envoy | Become ventures with a leader (pillar 1) |
| **Marriage** | Diplomacy | Envoy | New: see 2.6 |
| **Assassinate / Rescue / Ransom** | Cunning / Command / Diplomacy | Fixer / War Chief / Envoy | New: need characters. **OPEN:** now or later |
| Construction | — | Quartermaster speeds it | **Stays deterministic** (decision log); no tiers |

### 4.6 Scale
The playbox stays at city level. Off-map dilemmas and regional ventures reuse this anatomy at the vertical slice stage (pillar 1; not-doing list).

---

## 5. Incentives not to go to war

- **Aggression memory (EU4's aggressive expansion):** taking land by force gives *every* faction a long-lasting memory, "Conquered our neighbours". Enough of it and the others form a **coalition** against you, built from the existing alliance system.
- **Research needs peace:** research slows while at war, and war exhaustion raises grievance.
- **Trade shares knowledge:** trade partners exchange research, so war cuts you off from it.
- **Marriage ties:** war with in-laws costs council loyalty and the family bond.
- **Peaceful ambitions:** milestones such as "A Decade of Peace" and "Three Trade Partners"; many National Ambitions need stability.
- **Existing costs stay:** war costs wealth, war exhaustion, grievance, lost trade and broken treaties.

---

## 6. National Ambitions and Milestones

- **Milestones:** the current automatic ambitions (achievement-style, pay renown). Kept.
- **National Ambitions (new, inspired by HOI4 focuses):**
  - The player and each AI faction **pursue one at a time**. Each takes months, costs resources, and gives a concrete national effect: a building bonus, a unit of culture shift, a new venture or decision, a claim, a diplomatic effect.
  - They come from **one shared pool** of about 30, defined in data, **not per-faction trees**.
  - Each is **available only when your state qualifies** (traits, government, tech, situation). Some are **mutually exclusive**. What you can pursue emerges from how you've played, so there's no fixed optimal branch to memorise.
  - The **AI chooses by weighted scoring**, and its current pick is shown ("The Iron Wardens pursue: Militarise the Docks"), keeping pillar 3's readability.
  - Some unlock or enable **government reform decisions** (3.1), connecting ambitions to the government paths.

---

## 7. Tech (longer term)

- **A new resource, Knowledge.** It comes from districts (University Row, hospitals, a Library building), from expedition finds (salvaged manuals and hard drives), and from trade partners (shared research).
- **A compact tech web of about 20-30 techs across 3-4 eras:** Scavenging → Recovery → Reconstruction → Civic.
- **What techs unlock:** buildings, ventures, reform decisions (e.g. *Hold Elections* needs a civic tech), National Ambitions, and **policies that shift culture stats** (the media axis from the design docs). Culture stats then produce traits (pillar 2).
- **Pace:** research slows during war and speeds up through trade.
- **OPEN:** whether tech is needed for the Playbox gate or belongs to the vertical slice (recommended: vertical slice, unless playtests show otherwise).

---

## 8. How it all connects

- **Wealth sink:** council **wages** (by rank), extra venture funding, marriage dowries, ransoms, reform costs, research.
- **Renown:** attracts captains; strengthens succession; improves marriage odds.
- **Diplomacy:** marriages, family ties and leader traits feed the opinion baseline; captured characters become bargaining chips.
- **Collapse (pillar 5):** council loyalty, claimants and government type all feed succession strength.
- **Map:** the leader's banner on the capital; venture rings show a portrait or initials; the archive of dead leaders.

---

## 9. Build order (once development starts)

1. **Venture overhaul:** leaders (generic captains at first), crew size, funding, the four tiers, leader consequences.
2. **Characters:** council posts, skills, earned traits, loyalty, wages, the status ladder.
3. **Bloodlines:** families, marriage as a venture, family ties, claims.
4. **Mortality and succession:** ageing, death causes, succession strength, the archive.
5. **Government:** Warlord plus reform decisions and transitions; elections on death.
6. **Aggression memory and coalitions:** cheap, and gives the anti-war incentive early.
7. **National Ambitions:** the shared, condition-gated pool.
8. **Knowledge and tech:** likely vertical slice.

**Playbox scope:** steps 1-6 serve the Playbox gate ("players voluntarily start a second run and generate stories"). Steps 7-8 are the next candidates, pending playtests.

## 10. Still open
- **OPEN:** Assassinate, Rescue and Ransom ventures: Playbox or later?
- **OPEN:** Portraits: procedural 2D layers now (recommended) or placeholders?
- **OPEN:** How many named characters per faction: 8-12 proposed.
- **OPEN:** Whether tech belongs to the Playbox or the vertical slice.
