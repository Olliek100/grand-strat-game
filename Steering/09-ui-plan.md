# UI Plan

How the screen is organised: what lives where, how the player gets to it, and how it explains itself. Written 2026-09-26 from the user's CK2, CK3 and HOI4 screenshots (Ref_UI) and the state of the game at v1.33. **Status: approved 2026-09-26; built in v1.34 (S3b). Ambitions window waits for S4.**

Paradox games are the reference for *patterns and information layout only*: no copied art, text or pixel layouts (same rule as the data files, see 04-decision-log.md).

## Why now
Everything lives in one 420px side panel: six tabs, long scrolling pages, a Problems line that keeps growing, and a diplomacy pop-up of its own. Playtests show the cost: the log was ignored, a war warning was missed, the leader's family had no visible stats, and diplomacy went unused because it was hard to find. S4 (Ambitions, governments) would add another big screen. The structure has to change before more goes in.

## Principles
1. **The map is the game.** Panels open over it and close with one click (Esc or right-click) instead of permanently taking a third of the screen. (CK2, CK3, HOI4 all do this.)
2. **One place per thing.** Every system has one home window. Other places *link* to it (click a name or portrait), they don't copy it.
3. **People are clickable everywhere.** Any portrait or character name opens that character's window. (CK3.)
4. **Numbers explain themselves on hover.** Every resource, odds figure, opinion, loyalty and defence value has a tooltip breaking it into named parts. We already compute the parts; this is about showing them consistently. (HOI4 manpower tooltip, CK3 opinion tooltip.)
5. **"Can't" always says why,** as a requirements list with ticks and crosses, and where to get what's missing. (CK2 diplomacy menu, HOI4 focus popup.)
6. **Alerts are persistent icons, not text.** They stay until the problem is gone or you dismiss them. (HOI4, CK3.)
7. **Simpler than Paradox.** We have 4 skills, a handful of traits and 5 resources. Screens should be sparser and more readable than CK2's icon walls. If a Paradox screen section has no system behind it in our game, we leave it out.

## Screen regions

```
┌───────────────────────────────────────────────────────────────────────────┐
│ [Leader] │ Resources (hover = breakdown)          │ Date · speed · menu     │  top bar
│ portrait ├────────────────────────────────────────┴─────────────────────────┤
│          │ Alert icons (war coming, incoming raid, empty seat, hungry ...)   │
│          │                                                                  │
│  LEFT    │                                                   RIGHT          │
│  WINDOW  │               M A P                               OUTLINER       │
│ (opens   │                                                   (collapsible)  │
│  over    │                                                                  │
│  map)    │                                                                  │
│          │                                  [District panel on selection]   │
│          ├──────────────────────────────────────────────────────────────────┤
│          │ Menu row: Character · Council · Realm · Diplomacy · Ambitions ·   │
│          │           Economy · Log                     │ map modes · minimap │
└───────────────────────────────────────────────────────────────────────────┘
```

| Region | Job | Replaces (today) | Reference |
|---|---|---|---|
| **Leader portrait** (top-left) | Your leader's face, age and a health/danger pip. Click: Character window | Leader section of the Council tab | CK2 top-left, CK3 bottom-left |
| **Top bar** | Manpower, Food, Materials, Arms, Wealth, Renown, Districts, each value and daily change. Hover: full breakdown (sources, costs, what it's for). Date, pause and speed on the right. **Esc** opens the game menu (see below) | Resource line, top-bar buttons | HOI4 top bar + manpower tooltip |
| **Alert icons** (under the top bar) | One icon per active problem, coloured by urgency, a count badge, hover explains, click jumps to the fix, right-click dismisses | Problems line, Chances line, banner (partly) | HOI4 alert row, CK3 diamonds |
| **Left window** (one at a time) | The big windows below. Opens over the left of the map, ~560px wide, closes with Esc/X/right-click | The whole side panel and the diplomacy pop-up | CK2/CK3 character, council, laws; HOI4 politics |
| **District panel** (bottom-right, on selection) | The selected district: status, control, defence, food, buildings, and its venture buttons + planner | District and Build tabs | CK3 county view, HOI4 state panel |
| **Outliner** (right edge, collapsible) | Live list: your ventures (with rings/progress), incoming attacks, constructions, envoys, neighbours at war. Click an entry: jump to it | Activity tab's "Under way" | CK3/HOI4 outliner |
| **Menu row** (bottom) | Buttons for the windows, each with a hotkey (F1-F7) | Tab strip | CK2 menu, CK3 bottom-right, HOI4 top buttons |
| **Map mode buttons** (bottom-right) | Political, Grievance, Fog, (later) Danger, Salvage | Grievance/Full fog toggles in the top bar | HOI4 map modes |
| **Ticker** (bottom, small) | Last 2-3 lines about you; click: Log window | Keeps v1.32's ticker, smaller | — |

Event pop-ups (first contact, war declared, civil war, a leader's death) appear centre-screen, pause the game, and offer 1-3 responses. This replaces the v1.32 banner for major events; minor alerts stay as icons.

## Windows

Each opens in the left window slot. Tabs are listed in order; the first is the default.

### 1. Character (F1), anyone's
The CK-style character window. Opens for your leader from the portrait, and for anyone from any portrait or name.
- **Header:** large portrait, spouse beside them, heir as a small portrait; name, dynasty, age, role (Leader / Family / Council seat / Captain), faction.
- **Strip:** four skills (icon + number), trait icons (hover: what it does, how earned), loyalty bar with hover breakdown (for your people), health: yearly chance of dying, wounded days.
- **Tabs:**
  - **Family:** Parents · Spouse · Children · Siblings, as portraits with age; skulls on the dead; opinion/loyalty number on each. Children show "comes of age in N years".
  - **Relations:** who likes and dislikes them, and why (named reasons). Later: marriage ties to other dynasties (S5).
  - **Record:** ventures led, triumphs, wounds, seats held, notable events (the one-line history that becomes the archive entry).
- **Actions** (your people): appoint to a seat, make heir, assign tutor, lead a venture, dismiss. (Rivals: open their faction's diplomacy.)
- For a **rival leader**: the same, plus their opinion of you with the breakdown (CK3 opinion tooltip), and their succession outlook.

### 2. Council (F2)
- **Tab Seats:** the four seats as cards (portrait, name, the skill it uses, its bonus, loyalty); an empty seat is a "+" card; click to appoint (candidate list sorted by that skill, with passed-over warnings). (CK2/CK3 council.)
- **Tab Crew:** everyone who can lead ventures, one row each: portrait, skills, status (ready / away N days / wounded), loyalty. Sort by any skill.

### 3. Realm (F3)
- **Tab Succession:** heir and rival claimants as portraits, each with their claim strength and why; civil war chance with its causes; "Designate heir" button. (CK3 realm succession, CK2 laws "Heir / Pretenders".) Government and succession law appear here in S4.
- **Tab Dynasty:** family tree of your dynasty (living and dead), header with members, living members, founder, generations; the **archive of past leaders** (portrait, years ruled, how they died). Replaces the Fallen & departed list. (CK2/CK3 dynasty.)
- **Tab Territory:** your districts as a sortable list (control, food, population, defence, buildings, grievance). Click to select on the map.

### 4. Diplomacy (F4)
- **Tab Factions:** every faction you've met, one row: flag colour, name, leader portrait, stance toward you, treaties with timers, war status. Click: that faction's page.
- **Faction page** (also opened by right-clicking their land): leader, council portraits, stance and opinion with breakdown, treaties and timers, then **actions as a menu**. Each action shows acceptance odds; hover shows the requirements list with ticks/crosses and the odds breakdown (CK2 menu + tooltip, CK3 acceptance). Replaces today's diplomacy card and its "Not available now" block.
- **Tab Proposals:** offers waiting for your answer.
- **Tab Subjects:** your vassals and patrons (the CK2 "Vassals" tab, reduced to a short list, as agreed).

### 5. Ambitions (F5), built in S4
One shared pool, not a tree (see 03-not-doing-list). Cards grouped by category; each shows renown cost, duration, requirements (ticked), effects, and any risk in red. One active at a time with a progress bar. Start button. (HOI4 focus popup layout, without the tree.) Today's automatic milestone list is retired or folded in.

### 6. Economy (F6)
Where each resource comes from and goes, per day, as a table; buildings list; hoard and spoilage warnings; faction traits with progress. Replaces the Faction tab's Economy and Traits sections. The top-bar hovers are the short version of this window.

### 7. Log (F7)
The full log with filters (About you / Neighbours / Everyone), as v1.32, moved from the Activity tab.

## Where today's UI goes

| Today | Goes to |
|---|---|
| Top bar buttons (save, load, grievance, fog, auto-pause) | Esc game menu (save, load, settings incl. auto-pause), map mode buttons |
| Resource line | Top bar with hover breakdowns |
| Problems line | Alert icons |
| Chances line | Alert icon "A deal is likely" → opens Diplomacy on that faction |
| Banner | Event pop-ups (major) and alert icons (minor) |
| District tab (info, venture grid, planner) | District panel |
| Build tab | District panel (a Build section / button) |
| Faction tab: Ambitions | Ambitions window |
| Faction tab: Treaties | Diplomacy → Factions |
| Faction tab: Economy, Traits | Economy window |
| Council tab: Leader, Family | Character window (your leader) |
| Council tab: Succession text | Realm → Succession |
| Council tab: Seats, Crew | Council window |
| Council tab: Fallen & departed | Realm → Dynasty (archive) |
| Diplomacy tab + right-click card | Diplomacy window / faction page |
| Activity tab: Under way | Outliner |
| Activity tab: Log | Log window |
| Ticker | Stays, smaller |

## Shared building blocks
Built once and reused everywhere, so every window behaves the same:
- **Portrait widget:** click opens the character; hover shows name, role, age, skills, loyalty; small badges for dead, wounded, heir, leader.
- **Breakdown tooltip:** a title, a total, then named parts with signs and colours. Used for resources, odds, opinion, loyalty, defence, claim strength.
- **Requirements tooltip:** a ticks-and-crosses list for anything disabled.
- **Window frame:** title, tabs, close, hotkey; opens in the left slot, replaces whatever was there, remembers its last tab.
- **Alert:** id, urgency, icon, count, tooltip, click target, dismissible or not.

## What S3b builds (the first step)
"S3b: Legacy and the UI frame", in one build:
1. The **frame**: top bar with hover breakdowns, alert icons (replacing Problems/Chances), leader portrait, menu row, left window slot, district panel, outliner, map mode buttons.
2. The shared blocks above.
3. **Character window** and **Realm window** (Succession, Dynasty, Territory), with the legacy systems they need:
   - personality traits for everyone (a few opposite pairs), and leader traits earned from ruling;
   - a spouse always present, remarriage after a death;
   - designate heir (loyalty cost for passing over the eldest). Tutors for children are deferred to S5 (Blood), where children and marriage matter most;
   - the leader's traits pull the faction's traits their way.
4. **Council**, **Diplomacy**, **Economy** and **Log** windows, moved over from the old tabs with little change beyond the new tooltips.

**Ambitions** waits for S4. Event pop-ups start with the four events named above, and only inform (no choices) until S4 defines them.

Done when: every current function is reachable in the new layout; no window scrolls more than one screen at 1920×1080; every number the player sees has a hover breakdown; a playtester can find their leader's heir, a rival's weak succession and the reason a deal is refused without being told where to look.

## Out of scope
- UI art (skins, icon sets, window ornaments): after the layout settles. Plain dark panels until then.
- CK3 lifestyles, stress, schemes; lovers; the CK2 icon rows for religion and culture.
- Portrait evolution by government: with S4.
- Resolution scaling beyond 1920×1080 and 1280×720 until later.

## Esc and the game menu
Esc closes whatever is open, in order: an event pop-up, then the left window, then the selection. With nothing open, Esc opens the **game menu** and pauses: Resume, Save, Load, Settings (auto-pause on alerts, and later audio/UI scale), Quit. F5/F9 quick save/load are removed; F1-F7 open the windows.

## Decisions (user, 2026-09-26)
1. **Windows open on the left; the outliner is on the right.**
2. **Heir and tutors:** left to Claude on scope. *Decided:* designate heir is in S3b (the Succession tab needs an action, and it's small). Tutors wait for S5, where children and dynastic marriage give them a purpose.
3. **Event pop-ups inform only** until S4 defines choices.
4. **Save/load live in a menu opened with Esc**, not on hotkeys.
