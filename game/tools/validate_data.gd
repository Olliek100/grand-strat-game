extends SceneTree

# Parses every data/*.json file and runs GameData.validate(). Prints "DATA OK" or each problem; exit 1 on problems.
#   godot --headless --path game --script res://tools/validate_data.gd

func _init():
	var problems = []
	for file_name in DirAccess.get_files_at("res://data"):
		if file_name.ends_with(".json"):
			var text = FileAccess.get_file_as_string("res://data/" + file_name)
			var json = JSON.new()
			if json.parse(text) != OK:
				problems.append("%s line %d: %s" % [file_name, json.get_error_line(), json.get_error_message()])
	if problems.is_empty():
		problems = GameData.validate()
	for p in problems:
		print("DATA PROBLEM: ", p)
	if problems.is_empty():
		print("DATA OK")
	quit(1 if problems.size() > 0 else 0)
