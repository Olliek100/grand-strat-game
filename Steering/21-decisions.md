# 21. Decisions (BUILT 2026-10-16, with the recommended options: a tab in Ambitions, the starter list, save version 21)

Written 2026-10-14. Takes the "Decisions" idea from `docs/16-opening-and-emergence.md` (owner position 2) and cuts it to the smallest slice that fits the gang-to-organised-city arc. Nothing is built. Paradox's decision screens are structure only; the names, costs and effects below are ours.

## Why
The playtest said the game is clicking districts, taking them, repairing them, then more districts. Wealth has nowhere to go except buildings, and nothing in the middle of a run says "your gang is becoming a government". A Decision is a small, visible step on that road: pay something, change how the faction is run, and see the result.

## Where it sits
| | Happens | Costs | Example today |
|---|---|---|---|
| **Venture** | Acts on the world: crew, odds, days | Resources, crew | Raid, Settle, Trade |
| **Event** | Comes to you | Nothing; timed effects | "Of Age" |
| **Decision** *(new)* | You pick it, it resolves at once | Wealth, sometimes renown or a stock | none |
| **Ambition** | Long direction | Renown, time | A Name to Fear |

**One-verb check.** A Decision does not act on the world. Like constructing a building or starting an Ambition, it changes how *you* run things, so it is not a second verb. The rule is simple: if it needs a crew, rolls odds or takes days to land, it is a venture, not a Decision.

## How one works
- Listed in a window, each with: what it costs, what it does, for how long, and a lock reason when you cannot take it ("Needs 3 districts: you hold 2" / "On cooldown: 140 days").
- Click, pay, effect applies now. Effects are the same timed modifiers events already use (`diplomacy_mult`, `wealth_income_mult`, `owned_daily_grievance`...), so no new effect engine. Gates are the same `requires` lists Ambitions use.
- Each has a **cooldown** (repeatable) or is **once only** (an institution you have built).
- **The AI takes them from the same list**, scored by `ai_goal` like events and ambitions. No hidden extras.
- Content lives in a new `data/decisions.json`; code adds the window, the gate check and the AI scoring.

## Three kinds (first slice: about eight, numbers are placeholders for the sim)
**Desperation** (appear only when you are in trouble; the "no dead end" valve; each costs something real):
1. *Ration the stores*: food needs -20% for 60 days, grievance +0.03 a day. Needs food low.
2. *Press volunteers*: +6 manpower now, grievance +3 in your districts. Needs manpower short of what you hold.
3. *Strip a building for materials*: lose one building, gain half its cost back. Needs no materials in stock.

**Running things** (repeatable, wealth for a timed gain):
4. *Market day*: 40 wealth, trade income +20% for 90 days, cooldown 360. Needs 3 districts.
5. *Pay the watch*: 30 wealth, grievance -0.03 a day and defence +10% for 180 days, cooldown 360.
6. *A feast for the district*: 25 wealth, grievance in the districts you hold -4 once. Cooldown 180.

**Institutions** (once only; these mark the arc from gang toward order):
7. *Open a records office*: 80 wealth, +1 reach for good (the Reach rule from doc 20). Needs a councillor with Stewardship 3 or more.
8. *Set up a court*: 100 wealth, fewer councillors lose loyalty after a failed succession, and tribute demands against you are refused less. Needs a Warlord or better government. *(Starter; the full ladder waits for the council doc.)*

## Window
**Option A (recommended): a second tab in the Ambitions window (F5)**, "Ambitions | Decisions". No new hotkey, and both are "how you run things". **Option B:** its own window on F8. Your call.

## Left out on purpose (later, each needs the council)
Asking the council to approve a policy or reform and council patience; the council voting on war or tax; "contact a state specialist" (there is no state in the gang arc). Focuses and Activities are separate slices.

## Rules check
- Hard rules: no new verb, no per-faction trees (one pool, gated by situation), no randomness added (Decisions are deterministic), no fantasy.
- Spine: strengthens the **loop** (wealth gets a sink that is not a district) and the **arc** (institutions are steps toward order). No dead ends: every lock names what is missing and where to get it; the desperation set is the way out.
- Decision log: no override needed.

## Build size
Small: data file and validation, the tab, the gate and cost check, AI scoring, tests, the sim. Saving which once-only decisions you took and the cooldowns **changes the save**, so it needs a save-version bump: I will not do that without your yes.

## For the owner to decide
1. Window: tab in Ambitions (A) or its own window (B)?
2. Are these three kinds right, and is the starter list right (add, drop, rename)?
3. Should desperation decisions also warn the player before the stock runs out, or only appear once it has?
4. OK to bump the save version for this build (old saves will not load)?
