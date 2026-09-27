---
description: Screenshots of named UI scenarios, checked for layout problems
argument-hint: "[scenario[@days] ...]  (opening district character council realm diplomacy economy menu event)"
---
Use the render-check agent on scenarios `$ARGUMENTS` (default: opening district character council realm).
It runs `"$GODOT" --path game res://tools/render_shot.tscn -- <scratchpad>/shots <scenarios>` and reviews each image against the UI rules in CLAUDE.md: nothing clipped or overflowing, no fact shown twice, explanations in tooltips not bodies, costs on the commit button.

Report each problem with the scenario, where on screen, and which rule it breaks. Send me the screenshots worth seeing.
