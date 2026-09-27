---
description: Balance simulation against the current spine stage's targets
argument-hint: "[runs] [years]"
---
Use the balance-sim agent to run `tools/balance_sim.gd` with arguments `$ARGUMENTS` (default 3 runs of 4 years) and compare the results with the "done when" targets of the current stage in `Steering/08-spine.md` and the standing numbers in `CHANGELOG.md` (last few entries).

Report back a short table: each target, the measured range, pass/miss. Then list anything that moved noticeably since the previous build (civil wars per game, largest faction, broke/starving days, first expansion, ms per day). Keep it under 20 lines.
