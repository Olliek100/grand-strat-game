---
description: Wrap up a build - checks, changelog, readme, version bump, commit and tag
argument-hint: "[version, e.g. 1.39]"
---
Release build v$ARGUMENTS:

1. Run /test. Stop and report if anything fails.
2. If gameplay changed since the last tag (`git diff --stat $(git describe --tags --abbrev=0) -- game/`), run /sim and include the numbers.
3. Add a CHANGELOG.md entry at the top: `**<date> (v$ARGUMENTS, <short title>)**` with what changed in play, tuning numbers, sim results and open issues — the same style as existing entries.
4. If a decision was made that should outlast this build, add it to `Steering/04-decision-log.md` (standing rules section or a dated entry) and update the stage row in `Steering/08-spine.md` if a stage finished.
5. Update `game/README.md` only where how-to-play or the developer commands changed.
6. Set `config/version="$ARGUMENTS.0"` in `game/project.godot`.
7. Commit (`git add -A`, message `v$ARGUMENTS: <title>`), tag `v$ARGUMENTS`, and push with tags if a remote is set.

Report the tag and a three-line summary for the owner.
