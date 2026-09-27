---
description: Check a proposal or the current changes against the design rules
argument-hint: "[proposal text, doc path, or blank for the uncommitted diff]"
---
Use the design-auditor agent on: $ARGUMENTS (if blank, the output of `git diff` and `git status`).

It checks against `Steering/02-design-pillars.md`, `03-not-doing-list.md`, the spine test in `08-spine.md`, the UI rules in `09-ui-plan.md` and CLAUDE.md, and standing decisions in `04-decision-log.md`.
Report: violations (rule, where, why), risks, and which spine link (loop / verb / arc) the change strengthens. If it strengthens none, say it should be parked.
