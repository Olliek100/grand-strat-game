#!/usr/bin/env bash
# Before an edit: frozen builds and Paradox reference material are never modified
. "$(dirname "$0")/_path.sh"
case "$FILE" in
	*/Archive/*|*/Ref_PD_Games/*|*/Ref_UI/*|*/v1.[0-9]*/*)
		echo "Blocked: $FILE is frozen history or Paradox reference material (read-only; see CLAUDE.md)." >&2
		exit 2 ;;
esac
exit 0
