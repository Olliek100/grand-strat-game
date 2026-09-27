extends SceneTree

# Regenerates data/map.json. Run from the project folder:
#   godot --headless --path . --script res://tools/generate_map.gd -- [seed]

const DEFAULT_SEED = 1983
const OUTPUT = "res://data/map.json"

func _init():
	var map_seed = DEFAULT_SEED
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		map_seed = int(args[0])
	var layout = MapGenerator.generate(map_seed)
	var file = FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(layout, "\t", false))
	var type_counts = {}
	for d in layout["districts"]:
		type_counts[d["type"]] = type_counts.get(d["type"], 0) + 1
	print("Seed %d: %d districts, %d boroughs, river %d points, %d bridges, %d roads" % [
		map_seed, layout["districts"].size(), layout["boroughs"].size(), layout["river"].size(),
		layout["bridges"].size(), layout["roads"].size()])
	print("Types: ", type_counts)
	print("Boroughs: ", layout["boroughs"].map(func(b): return b["name"]))
	quit()
