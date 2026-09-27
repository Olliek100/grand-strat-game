---
description: Run the regression tests and the UI smoke test; report failures only
---
From `game/`, run both and report in plain language:

1. `"$GODOT" --headless --path game --script res://tests/spine_test.gd` — report any `[FAIL]` lines and the final ALL PASSED / N FAILED line.
2. `"$GODOT" --path game res://tools/ui_smoke.tscn` — must print `UI SMOKE OK`; report any `SCRIPT ERROR` with its file and line.

If everything passes, say so in one line. If something fails, say which check, what it means for play, and the likely cause. Don't fix anything unless asked.
