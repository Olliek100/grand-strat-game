extends "res://main.gd"

# Screenshots of named scenarios, for checking the UI by eye.
#   godot --path game res://tools/render_shot.tscn -- <out_dir> [scenario ...]
# Scenarios: opening, district, character, council, realm, diplomacy, economy, menu, event
# A scenario name followed by @days (e.g. character@700) plays that many days with the AI first.

var frame = 0
var queue: Array = []
var out_dir = "user://shots"
var current = ""

func _ready():
	super._ready()
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	queue = args.slice(1) if args.size() > 1 else ["opening", "district", "character", "council", "realm"]
	DirAccess.make_dir_recursive_absolute(out_dir)

func _process(delta):
	super._process(delta)
	frame += 1
	# Every 6 frames: set up the next scenario, then capture it 4 frames later
	if frame % 6 == 2:
		if queue.is_empty():
			get_tree().quit()
			return
		current = queue.pop_front()
		_setup(current)
	elif frame % 6 == 0 and current != "":
		var path = "%s/%s.png" % [out_dir, current.replace("@", "_")]
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)

func _setup(scenario: String):
	var name = scenario.get_slice("@", 0)
	var days = int(scenario.get_slice("@", 1)) if scenario.contains("@") else (0 if name in ["opening", "district"] else 400)
	if days > 0 and city.day < days:
		city.factions[city.player_id].ai = FactionAI.new(city.player_id)
		while city.day < days:
			city.advance_day()
		city.factions[city.player_id].ai = null
	event_queue.clear()
	event_popup.visible = false
	game_menu.visible = false
	_close_window()
	var me = city.player_id
	match name:
		"opening":
			pass
		"district":
			selected = city.districts[city.factions[me].home_id]
			_show_district("district")
		"character":
			_show_character(city.leader_of(me).id)
		"council":
			_open_window("council", "seats")
		"realm":
			_open_window("realm", "succession")
		"diplomacy":
			for fid in city.factions:
				if fid != me:
					_open_faction_panel(fid)
					break
		"economy":
			_open_window("economy", "economy")
		"menu":
			_toggle_game_menu()
		"event":
			_on_major_event("First contact: a test", "A faction now borders you.", city.factions.keys()[1])
	_refresh()
