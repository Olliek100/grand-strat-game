extends "res://main.gd"

# Screenshots of named scenarios, for checking the UI by eye.
#   godot --path game res://tools/render_shot.tscn -- <out_dir> [scenario ...]
# Scenarios: opening, district, character, council, realm, government, diplomacy, ambitions, deeds, economy, menu, event,
# choice, child (a child's card mid-upbringing), upbringing (the choice at six), rechoice (changing it later),
# raid (the raid planner on a neighbour, with the force line), paused (an alert's reason by the clock, Economy open)
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
			_show_character.call_deferred(city.leader_of(me).id)
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
			_open_window.call_deferred("economy", "economy")
		"ambitions":
			_open_window("ambitions", "ambitions")
		"deeds":
			_open_window("ambitions", "deeds")
		"government":
			_open_window("realm", "government")
		"choice":
			city.pending_events.append({"event": "council_quarrel", "subject": city.leader_of(me).name, "venture": ""})
		"child":
			# A child four years into a council tutor's lessons, with a childhood event behind them
			var kid = city._new_child(city.leader_of(me), 10)
			var tutor = city.characters_of(me).filter(func(c): return c.post != "")
			kid.upbringing = "tutor" if not tutor.is_empty() else "hired"
			kid.tutor_id = tutor[0].id if not tutor.is_empty() else -1
			kid.tutor_skill = tutor[0].best_skill() if not tutor.is_empty() else "command"
			for y in 4:
				city._grow_year(kid)
			kid.leanings["brave"] = float(kid.leanings.get("brave", 0.0)) + 2.0
			# Deferred, after any first-contact window the played days queued
			_show_character.call_deferred(kid.id)
		"upbringing":
			city.pending_events.clear()
			city._fire_moment(me, "education", city._new_child(city.leader_of(me), 6))
		"rechoice":
			# Changing a child's upbringing from the right-click menu
			var pupil = city._new_child(city.leader_of(me), 11)
			pupil.upbringing = "parents"
			city.pending_events.clear()
			city.request_upbringing_change(pupil)
		"raid":
			# The raid planner on a neighbour's district: the force line and garrison (doc 15)
			for d in city.districts:
				var owner = d.owner_id()
				if owner != "" and owner != me and city.borders_territory(me, d):
					city.factions[me].manpower = maxf(city.factions[me].manpower, 12.0)
					_goto_venture.call_deferred(d, "raid")
					break
		"paused":
			# An alert pauses the game and says why beside the clock
			paused = false
			city.event.emit("WAR! The Rust Dogs have declared war on you. Expect assaults on your border districts.", "alert")
			_open_window.call_deferred("economy", "economy")
		"goals", "ultimatum":
			# A neighbour's card with the war-goal buttons (doc 15), or an ultimatum from them waiting in Proposals
			var them = ""
			for fid in city.factions:
				if fid != me and city.shares_border(me, fid):
					them = fid
					break
			if them != "":
				var r = city.relation(me, them)
				r.truce_until_day = 0
				city.factions[me].renown = maxf(city.factions[me].renown, 60.0)
				city.factions[me].wealth = maxf(city.factions[me].wealth, 120.0)
				if name == "ultimatum":
					var d = city.claim_district(them, me)
					r.claim = {"by": them, "goal": "claim", "district": d.id if d else -1, "reason": "you raided them", "stage": "justifying", "ready_day": city.day, "deadline": 0}
					city._update_claims()
					event_queue.clear()
					_open_window.call_deferred("diplomacy", "proposals")
				else:
					_open_faction_panel.call_deferred(them, Vector2(-1, -1))
					_scroll_down.call_deferred()
		"pressing", "backing":
			# Your claim under way: its card (odds, send now, withdraw), or a third faction's card (back our claim)
			var them = ""
			var other = ""
			for fid in city.factions:
				if fid != me and city.shares_border(me, fid) and them == "":
					them = fid
			# Any third faction can be asked to back the claim, neighbour or not
			for fid in city.factions:
				if fid != me and fid != them and other == "":
					other = fid
			if them != "":
				city.relation(me, them).truce_until_day = 0
				city.factions[me].renown = maxf(city.factions[me].renown, 100.0)
				city.factions[me].wealth = maxf(city.factions[me].wealth, 200.0)
				city.justify(me, them, "vassalize")
				event_queue.clear()
				_open_faction_panel.call_deferred(them if name == "pressing" or other == "" else other, Vector2(-1, -1))
				_scroll_down.call_deferred()
		"fullcontrol", "overslots":
			# Your home at full control but still dangerous (Safeguard lowers danger), or holding more buildings than its slots
			var home = city.districts[city.factions[me].home_id]
			home.influence.clear()
			home.add_influence(me, 100.0)
			home.hazard = 0.3
			home.ruin_level = 0.5
			if name == "overslots":
				home.buildings.assign(["allotments", "watchtower", "market", "hostel"])
			selected = home
			_show_district("district")
			if name == "fullcontrol":
				_on_venture_pressed.call_deferred("safeguard")
			else:
				_show_district.call_deferred("build")
		"houses":
			# A cadet house founded on one of your districts: the Houses tab (doc 16)
			var lord = city.characters_of(me).filter(func(c): return c.family)
			if lord.is_empty():
				lord = [city._new_child(city.leader_of(me), 22)]
			var land: District = null
			for d in city.districts:
				if city.check_grant(me, lord[0], d) == "":
					land = d
			if land:
				city.grant_land(me, lord[0], land)
				selected = land
				_show_district("district")
			_open_window.call_deferred("realm", "houses")
		"crossmatch":
			# A neighbour's card offering a match between the families (doc 16, H3)
			for fid in city.factions:
				if fid != me and city.shares_border(me, fid):
					var son = city._new_child(city.leader_of(me), 24)
					son.sex = "m"
					var bride = city._new_child(city.leader_of(fid), 22)
					bride.sex = "f"
					city.factions[me].wealth = maxf(city.factions[me].wealth, 100.0)
					_open_faction_panel.call_deferred(fid, Vector2(-1, -1))
					_scroll_down.call_deferred()
					break
		"menu":
			_toggle_game_menu()
		"event":
			_on_major_event("First contact: a test", "A faction now borders you.", city.factions.keys()[1])
	# Hold the clock, so nothing new (a first contact opening Diplomacy) happens before the capture
	_set_paused(true)
	_refresh()
	if name in ["choice", "upbringing", "rechoice"]:
		_show_choice()

# Scrolls every scrolling window to the bottom (to see the end of a long card)
func _scroll_down():
	await get_tree().process_frame
	for s in find_children("*", "ScrollContainer", true, false):
		s.scroll_vertical = 100000
