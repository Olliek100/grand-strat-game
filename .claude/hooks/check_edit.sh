#!/usr/bin/env bash
# After an edit in game/: parse-check GDScript, lint simulation code for unseeded randomness, validate data files.
# Exit 2 sends the message back to Claude to fix.
. "$(dirname "$0")/_path.sh"
case "$FILE" in */game/*) ;; *) exit 0 ;; esac
GAME="${FILE%%/game/*}/game"
REL="${FILE#*/game/}"
case "$REL" in
	*.gd)
		OUT=$("$GODOT" --headless --path "$GAME" --check-only --script "res://$REL" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Failed to load" | head -5)
		if [ -n "$OUT" ]; then
			echo "GDScript error in $REL:" >&2; echo "$OUT" >&2; exit 2
		fi
		case "$REL" in
			tools/*|tests/*|portrait.gd|map_art.gd|map_painter.gd|city_map_view.gd|main.gd) ;;
			*)
				LINT=$(grep -nE '(^|[^.a-zA-Z_])(randf|randi|randf_range|randi_range)\(|\.shuffle\(\)|RandomNumberGenerator\.new\(\)' "$FILE" | grep -v "var rng := RandomNumberGenerator.new()")
				if [ -n "$LINT" ]; then
					echo "Unseeded randomness in simulation code ($REL): use city.rng so saves replay identically." >&2
					echo "$LINT" >&2; exit 2
				fi ;;
		esac ;;
	data/*.json)
		OUT=$("$GODOT" --headless --path "$GAME" --script res://tools/validate_data.gd 2>&1 | grep "DATA PROBLEM" | head -8)
		if [ -n "$OUT" ]; then
			echo "$OUT" >&2; exit 2
		fi ;;
esac
exit 0
