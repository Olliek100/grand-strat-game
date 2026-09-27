extends "res://main.gd"

# UI smoke test: plays a year with the AI, then opens every window, tab, character, district,
# alert, link and menu once. Any script error shows in the output; "UI SMOKE OK" means it all ran.
#   godot --path game res://tools/ui_smoke.tscn

var frame = 0

func _process(delta):
	super._process(delta)
	frame += 1
	if frame != 3:
		return
	city.factions[city.player_id].ai = FactionAI.new(city.player_id)
	for i in 400:
		city.advance_day()
	city.factions[city.player_id].ai = null
	event_queue.clear()
	event_popup.visible = false
	for id in windows:
		for tab in windows[id]["order"]:
			if not (id == "diplomacy" and tab == "faction"):
				_open_window(id, tab)
				_refresh()
	for fid in city.factions:
		if fid != city.player_id:
			_open_faction_panel(fid)
			_refresh()
	for c in city.characters.slice(0, 15) + city.graveyard:
		_show_character(c.id)
		for tab in ["family", "relations", "record"]:
			_show_tab("character", tab)
		_open_character_menu(c.id, Vector2(100, 100))
	character_menu.hide()
	for d in city.districts:
		selected = d
		_show_district("district")
		_refresh()
		_show_district_tab("build")
		_refresh()
	_show_district_tab("district")
	for i in current_alerts.size():
		_on_alert_pressed(i)
	for meta in ["d:0", "f:%s" % city.factions.keys()[1], "c:%d" % city.characters[0].id]:
		_on_link_clicked(meta)
	_toggle_game_menu()
	_toggle_game_menu()
	_on_major_event("Test", "text", city.factions.keys()[1])
	_close_event()
	for mode in ["grievance", "fog", "political"]:
		_set_map_mode(mode)
	_deselect()
	print("UI SMOKE OK")
	get_tree().quit()
