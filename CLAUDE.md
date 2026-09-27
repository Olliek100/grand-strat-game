# Grand Strategy (working title)

Solo-developed strategy game: one fictional Western European city, contemporary tech, from post-collapse toward a
"civilised" state, with a recurring collapse/civil-war cycle. Godot 4.7.2, GDScript. The game is in `game/`; design
docs in `Steering/`. The owner judges builds by playing them: show consequences, timers and reasons in the UI.

## Hard rules (change only with a decision-log entry the owner agreed)
- Real-time with pause (Paradox model). Never turns.
- No fantasy, magic, supernatural or non-human anything. Contemporary tech only.
- Characters are mortal (CK2-style). A death is an event, never a game over.
- Traits are earned from behaviour and policy, never chosen from a tree.
- One verb: every meaningful action is a venture (leader, crew, cost, readable odds, 4 outcome tiers).
- AI plays by the player's rules, odds and data. No hidden bonuses.
- No per-faction focus trees; National Ambitions are one shared pool gated by the faction's situation.
- Read `Steering/03-not-doing-list.md` before adding any system. Test every idea against the spine
  (`Steering/08-spine.md`): does it strengthen the loop, the verb or the arc? No dead ends: every resource needs a
  source that doesn't cost itself, and every "can't" says what's missing and where to get it.
- `Ref_PD_Games/` (CK2/CK3/HOI4 data) and `Ref_UI/` (screenshots) are structural reference only: never copy script,
  text, numbers, art or pixel layouts, and never commit them. Findings go in `Steering/06-paradox-reference-notes.md`.
- `Archive/` holds frozen old builds: read them to compare, never edit them.

## UI rules
- Map-first frame: see `Steering/09-ui-plan.md`. Windows open on the left, one at a time.
- How a system works goes in a tooltip (`_explain(window, tab, text)` for tabs/titles/menu buttons); screen bodies
  show only what the player decides with. Every number explains itself on hover.
- Never show the same fact twice on one screen. Costs sit on the button where you commit.
- Every portrait: left-click opens the person, right-click their options.

## Code rules
- Content lives in `game/data/*.json`; code provides building blocks (venture targets, odds factors, effect ops).
  A new block must be added to the lists in `venture_system.gd` / `faction_ai.gd` and pass `GameData.validate()`.
- All simulation randomness goes through `city.rng`, so a saved game replays identically. No global
  `randf()`/`randi()`/`shuffle()` in simulation code (portraits and map art seed their own generators; that's fine).
- Changing what's saved: update `to_dict`/`from_dict` and bump `CityMap.SAVE_VERSION`.
- Only the open window refreshes; keep the daily simulation under ~30 ms/day (speed 5 allows 40).
- Match the surrounding style: short comments that say why, plain names.

## Checks (from `game/`, `$GODOT` is set in `.claude/settings.json`)
- `/test`: regression tests (`tests/spine_test.gd`) plus the UI smoke test (`tools/ui_smoke.tscn`).
- `/sim [runs] [years]`: balance simulation against the current spine stage's targets.
- `/render [scenario@days ...]`: screenshots to check the UI by eye.
- A change is done when `/test` passes, `/sim` is within targets (for gameplay changes), `/render` looks right (for UI
  changes), and `CHANGELOG.md` has an entry. `/release` does the wrap-up and tags the build.

## Workflow
- One git repo; each build is a tag (`v1.38`, `v1.39`, ...). No more copied version folders.
- Design first for anything big: a short doc in `Steering/` the owner marks up before code (as with 08 and 09).
- Standing decisions: `Steering/04-decision-log.md`. Per-build detail: `CHANGELOG.md`.
- Write for the owner in plain language; they're a designer, not a programmer. Say what changed in play, not in code.
