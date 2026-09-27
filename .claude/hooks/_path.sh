# Shared by the hooks: reads the tool call JSON on stdin and sets FILE to the edited file (forward slashes)
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4 | tr '\\' '/' | sed 's#//*#/#g')
GODOT="${GODOT:-D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
