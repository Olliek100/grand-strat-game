# Standing Tasks: Routine Ventures as Council Assignments

Routine ventures (Scavenge, Rebuild, Safeguard…) become standing tasks: assign a councillor to a district once, and they work it, venture after venture, until the district's own state says the job is done. Written 2026-09-29 against the code at v1.40 and doc 11. **Status: decided 2026-09-29; built in v1.40 (see "Built" at the end).**

**Principle:** the system takes actions; the player makes decisions. A process that runs until a condition ends it belongs to the councillor. A choice between exclusive options (who, where, what to build, whether to raid) belongs to the player.

## Which ventures become tasks

| Venture | Becomes | Why |
|---|---|---|
| Scavenge (your own land) | **Task** | A process: strips ruins until they're gone |
| Rebuild | **Task** | A process: raises development to the ceiling |
| Safeguard the Shelter | **Task** | A process: raises control (and cuts danger) until the district is fully yours |
| Secure Food | **Task** | A process: adds food sources until the district's cap |
| Relief | **Task** | A process: calms grievance until the district is calm |
| Scavenge (unclaimed ruins) | **Stays a one-off** | It's how you reach for new land (+3 influence toward a claim): external, and a decision |
| Scout, Settle, Negotiate, Raid, Assault, Agitate, Threaten, Trade Run | **Stay one-offs** | Aimed outward or at someone else: where the tension belongs |
| **Unclear, flagged:** Gather Weapons | Task, probably | A process, but its end is faction-wide (armoury full at 30 arms), not tied to the district |
| **Unclear, flagged:** Reinforce | Stays a one-off, probably | Guarding until a threat passes is a process, but *where* to put guards during an attack is the decision the player makes under pressure |
| **Unclear, flagged:** Trade Run | Stays a one-off, probably | Routine income, but at another faction's market (their goodwill, your wealth): external |

## Answers to the seven questions

### 1. What ends each task
Every routine venture already has a stop rule: the check that refuses a launch today (`check_launch`, "needs"). **A task ends when that check would refuse the next run for its stop reason.** Nothing new is needed.

| Task | Ends when | Current rule |
|---|---|---|
| Scavenge | Ruins under 10% | "Nothing left to salvage: the ruins here are stripped bare" |
| Rebuild | Development 99%+ (the ceiling is 100%; building slots are separate) | "Fully rebuilt" |
| Safeguard | Your control 95+ | "Already fully under your control" |
| Secure Food | Food sources at the district cap (0.6 a day) | "Every food source here is already worked" |
| Relief | Grievance under 15 | "The district is already calm" |
| Gather Weapons | Armoury full (30 arms), **faction-wide** | "Your armoury is full" |

- **Every routine venture has a ceiling.** Gather Weapons is the only one whose ceiling isn't the district's.
- **Things outside the councillor's control also end or pause a task:**
  - the district is lost (it changes hands) → the task ends;
  - the leader is wounded or killed → it ends;
  - the costs can't be paid → it pauses with an alert, and resumes when you can pay;
  - Relief can re-arm: grievance comes back after raids. The task still ends at calm; you reassign if it flares.
- **Safeguard and danger:** since v1.40 danger falls as ruins are cleared, so Safeguard doesn't need a danger stop. Control 95 stays the end.

### 2. Minimum commitment
**Proposal: two runs of that task, as long as the task's venture takes this leader** (a skilled leader's runs are shorter).

| Task | Run length (base) | Committed for |
|---|---|---|
| Scavenge | 6 days | ~12 days |
| Secure Food | 8 | ~16 |
| Safeguard | 10 | ~20 |
| Rebuild | 12 | ~24 |
| Relief | 8 | ~16 |

- **Why runs rather than a fixed number:** the commitment then scales with the job. A councillor always gets at least two rolls, so an assignment always means something. Short jobs stay short, and a misclick costs about two weeks, not a season.
- **Why two:** one run is what a manual launch already costs. Two makes assigning a real commitment, a little more than launching once, and removes the flick-assign exploit (assign, collect one roll, reassign).
- **"Unassigning is free" (your note), read with the lock:** pulling a councillor off costs no resources, and whatever the current run brings back still arrives. **But until the committed time has passed they can't take a new task or lead a venture:** the button shows "free in 6 days". After that, unassigning is instant and free. A task that ends naturally (ruins gone) frees them at once. **This is my reading of two rules that pull against each other; please confirm.**

### 3. Several councillors in one district
- **Different tasks in one district: allowed, and they don't stack.** Each task rolls its own venture on its own odds. They interact only through the district's state: scavenging clears ruins, which lowers danger (v1.40), which improves every other task's odds there. That makes Scavenge + Rebuild a natural pair. No stacking bonus or penalty is needed.
- **The same task twice in one district: not allowed.** The existing "Already under way here" rule already enforces it.
- **Doc 11's formulas apply per run, unchanged:** leader skill, crew, danger, the graded roll (x0.8-x1.2), no Disaster at 90%+. Nothing in the odds needs to know about other tasks.

### 4. The AI plays the same way (pillar 3)
- **Eligibility is the same code path for everyone:** `check_launch` has no AI-only exceptions today. Task assignment would go through the same check, so the AI can only task-scavenge land it holds, just like you.
- **Unclaimed scavenging stays a one-off launch for everyone.**
- **The AI's single self-limit** (one operation per district) is its own choice, not a rule. It becomes "one task of each type per district", the same as yours.
- **The AI assigns tasks from its one list** (doc 11, D.2): an assignment competes with builds, ambitions, reforms and ventures at the moment it's made.

### 5. Seeing what tasks produce
- **The outliner gets a "Tasks" section:** one line per task, with the councillor, the district, the stop stat as a bar ("ruins 31% → 10%"), and the live odds.
- **A digest every 30 days** in the log, one line per task: "Ines, Scavenging Chapel Street: 4 runs, +41 materials (one clean job), ruins 44% → 31%".
- **These still interrupt directly:**
  - a **Disaster**, a **wound** or a **death**, as today, with the usual pause;
  - **completion**: "Chapel Street is stripped bare. Ines is free for a new task";
  - a **pause** for lack of funds.
- **Triumphs** stay individual log lines in green ("a clean job x1.2"). The earned feeling of A.3 shows in the digest's totals and in the stat bar moving faster.

### 6. The district picker
- Clicking a task (see the flow below) puts the map into **pick mode**:
  - eligible districts are lit; the rest are dimmed;
  - each lit district's label shows the stat that matters for that task ("ruins 44%", "dev 62% → 100%", "control 71 → 95", "food 0.3 of 0.6");
  - hovering one shows the odds and risk for that councillor there, as the planner does (doc 11, B).
- **With no eligible district,** the task button stays visible but disabled, with the reason: "No ruins left to strip in land you hold. Scavenge unclaimed ruins instead (a one-off launch)".
- **With no free councillor,** the same rule applies: "Everyone on the council is busy: Ines free in 6 days, Rafe wounded 12 days".

### 7. Fit with doc 11
- **No second system.** A task re-launches the same venture on a cycle: the same `compute_odds`, graded roll, danger-scaled wounds, costs and log. A.1-A.4 apply to every run, unchanged.
- **The budget (D.2, D.4) holds, with one condition:** **each run pays its venture's cost, and the crew stays committed for the whole task**, not just during a run. The opportunity cost of doc 11 then carries on:
  - the councillor can't lead anything else;
  - that manpower isn't idle;
  - every run takes its food or materials.

  Without that, "always on" would erase it. This is the point I'd check hardest in simulation.
- **A.5 (the planner's recommended plan)** is used **once, at assignment**, to set the crew. Each run then reuses that crew. It isn't redundant for tasks; it just stops being per-run.
- **Watch:** an always-on task rolls more often than a busy player would launch by hand, so more rolls means more wounds. Doc 11's danger-scaled wounds and v1.40's cleared-ruins danger keep careful work fairly safe, but wound and death rates for task-holders need measuring.

## The flow

1. **Choose the task.** In the Council window, each councillor card gets a **Task** button listing the five tasks. Each is enabled or disabled with its reason, and shows the councillor's skill for it. The district panel's routine ventures also get **Assign** next to Launch, with a councillor dropdown. That path skips the map pick, because the district is already chosen.
2. **Pick the district.** The map pick mode from question 6. Clicking a lit district shows a small confirm with the crew (the recommended plan), the odds, the cost per run, the commitment, and the stop condition. Then Assign.
3. **The councillor goes.** No travel step; the first run launches at once. The councillor's portrait shows the task.
4. **Runs repeat.** When one run lands, the next launches the same day if the task can continue. If it can't pay, the task pauses with an alert. If its stop condition is met, it ends.
5. **It ends.** You get a notification and a log line with the totals, and the councillor is free. There's **no auto-reassignment and no queue.**
6. **Pulling off early:** the task's card or the outliner line has **Stop**. The current run finishes, and the councillor is free once the commitment has passed.

**Game state and saves.** A new record per task:
- task (the venture id), faction, character, district;
- crew, the day it started, the day the commitment ends;
- runs so far, running totals (for the digest), and a paused reason;
- the run under way: an ordinary venture, marked with its task.

Saves change version (old saves won't load).

## Needs a decision-log entry before building
1. **Routine ventures become standing tasks.** This changes how the player interacts with the verb (pillar 1 kept: every run is still a venture).
2. **Who can hold a task:** only the 4 council seats, or any captain? Four seats means at most four tasks, which is a tight and meaningful limit. Captains would allow more, with less weight. **Recommendation:** council seats only, so the seat choice becomes the key decision. It follows "the crew is the council" (decision log, 2026-09-25).
3. **Scavenging splits:** tasks on land you hold, one-offs on unclaimed ruins (which build a claim).
4. **The commitment rule** (two runs; unassign free after that) and **no queue.**
5. **Costs every run and the crew held for the whole task.** This keeps doc 11's opportunity cost.
6. **The same rules for the AI,** assigning from its one list.

## Decisions for the owner
1. **Council seats only, or captains too?** (Recommendation: seats only.)
2. **The commitment, as read above:** can't take new work until two runs have passed; after that, stopping is free. Right?
3. **The three flagged cases:** Gather Weapons a task (faction-wide end)? Reinforce and Trade Run stay one-offs?
4. **Digest every 30 days,** or weekly?

## Owner's decisions (2026-09-29)
1. **Council seats only** hold tasks. **Wounds need rebalancing** for this. Built: a wound *pauses* the task until the councillor heals (they keep the assignment), and task runs wound half as often as one-off launches (familiar work on your own ground). One rule in data, to revisit after play.
2. **The commitment rule is fine for now** (two runs; after that, stopping is free).
3. **Gather Weapons is a task:** run at home, it produces arms, and ends when the armoury is full.
4. **Reinforce is a task:** a councillor guards a district until the threat passes.
5. **Trade Runs stay the player's decision** (one-off launches).
6. **Digest every 30 days**, for now.

## Built in v1.40
- As proposed, with the owner's decisions. **Entry points:** the seat card's Task... button (then the map pick, then ASSIGN in the district planner), or ASSIGN straight from the district planner. **The map picker lights eligible districts in gold with their stat.** The Council window and the outliner show each task.
- **Result (3 games x 4 years):** 61-70% of the city claimed at year one (was 72-77%; the provisional target is 65%), because councillors on tasks aren't leading expansion. No faction broke; hunger mostly under 20 days (one minor starved 62 days in one game). Civil wars 0-1 a game; the first purge showed up. About 30 ms a day.
- **Watch:** in one game the AI threatened a raider 57 times; one minor went hungry for 62 days.
