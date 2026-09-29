extends Control

# Real seconds per game day at speeds 1-5 (index 0 unused: that's "paused")
const SECONDS_PER_DAY = [0.0, 1.0, 0.5, 0.25, 0.1, 0.04]
const LOG_COLORS = {"info": "#c9c9c9", "good": "#8bd48b", "bad": "#e3876f", "alert": "#ffb347"}
# Id for dropdown rows that aren't a person ("Appoint...", "No captain is free"). Not -1: Godot turns -1 into the row's index
const NO_PICK = -3

var city: CityMap
var speed: int = 2
var paused: bool = true
var day_timer: float = 0.0
var selected: District = null
var hovered_venture: String = ""

# UI references - built programmatically
var map_view: CityMapView
var date_label: Label
var pause_button: Button
var speed_buttons: Array[Button] = []
var pause_on_alert: CheckBox
var district_info: RichTextLabel
var venture_buttons: Dictionary = {}
var odds_info: RichTextLabel
var trait_widgets: Dictionary = {}
var trait_fills: Dictionary = {}
var war_box: VBoxContainer
# Faction id -> card widgets (see _rebuild_faction_cards); rebuilt when the set of factions changes
var war_rows: Dictionary = {}
# Faction id -> diplomatic action id the mouse is over, for the detail text on that card
var hovered_diplomacy: Dictionary = {}
var proposals_box: VBoxContainer
var proposals_signature: String = ""
# The faction page in the Diplomacy window
var panel_body: VBoxContainer
var panel_fid: String = ""
var panel_card: Dictionary = {}
var buildings_info: RichTextLabel
var build_title: RichTextLabel
var build_buttons: Dictionary = {}
var building_info: RichTextLabel
var hovered_building: String = ""
var economy_info: RichTextLabel
# Ambitions window: the line on top, and one card per National Ambition (id -> widgets)
# Realm window, Government tab: the current government, and the reforms on offer (rebuilt when they change)
var government_info: RichTextLabel
var reform_box: VBoxContainer
var reform_signature: String = ""
var ambition_intro: RichTextLabel
var ambition_cards: Dictionary = {}
# Deeds tab
var ambitions_info: RichTextLabel
# The closest unfinished ambitions, each a label and a progress bar
var ambition_rows: Array = []
const AMBITION_ROWS = 5
var treaties_info: RichTextLabel
# Council window: a row per seat, a card per character (by id), kept and updated in place
var council_intro: RichTextLabel
var crew_intro: RichTextLabel
var crew_box: VBoxContainer
var departed_info: RichTextLabel
var succession_info: RichTextLabel
var seat_rows: Dictionary = {}
var crew_cards: Dictionary = {}
var pending_dismiss: int = -1
# Leader to pick in the planner next time it refreshes (set by "Lead a venture")
var preferred_leader: int = -1
# A task waiting for its district: {"venture", "character"} (empty when not picking)
var task_pick: Dictionary = {}
# The venture planner: the chosen venture (hovered_venture), its leader, crew and funding
var plan_box: VBoxContainer
var leader_select: OptionButton
# Switches the planner between the recommended plan and the cheapest one
var plan_toggle: Button
# Venture and district the planner last set a plan for
var plan_key: String = ""
var leader_signature: String = ""
var crew_slider: HSlider
var crew_label: Label
var funding_select: OptionButton
var tier_bar: HBoxContainer
var tier_text: RichTextLabel
var launch_button: Button
const TIER_COLORS = {"triumph": Color("#d9b35a"), "success": Color("#7ac07a"), "setback": Color("#d9904a"), "disaster": Color("#d0503c")}
# Bottom: a short ticker of what concerns you; the full, filterable log is the Log window
var log_view: RichTextLabel
var ticker: RichTextLabel
var log_entries: Array = []
var log_filter: String = "mine"
var log_filter_buttons: Dictionary = {}

# The frame (see Steering/09-ui-plan.md): top bar, alerts, one window at a time on the left,
# outliner and district panel on the right, window buttons and map modes at the bottom
var leader_button: Portrait
var faction_label: Label
var resource_chips: Dictionary = {}
var alert_row: HBoxContainer
var alert_buttons: Array = []
var current_alerts: Array = []
var dismissed_alerts: Dictionary = {}
var window_slot: PanelContainer
var window_title: Label
var window_top: VBoxContainer
var window_tab_bar: HBoxContainer
var window_body: VBoxContainer
var windows: Dictionary = {}
var open_window: String = ""
var menu_buttons: Dictionary = {}
var map_mode_buttons: Dictionary = {}
var right_column: VBoxContainer
var outliner_scroll: ScrollContainer
var outliner_fold: Button
var outliner_text: RichTextLabel
var district_panel: PanelContainer
var district_title: Label
var district_pages: Dictionary = {}
var district_tab_buttons: Dictionary = {}
var district_tab: String = "district"
var event_popup: PanelContainer
var event_title: Label
var event_text: RichTextLabel
var event_open: Button
var event_faction: String = ""
var event_queue: Array = []
var game_menu: PanelContainer
var subjects_info: RichTextLabel
# Character window: whose it is, and its parts
var character_shown: int = -1
var char_signature: String = ""
var char_portrait: Portrait
var char_name: RichTextLabel
var char_relatives: HBoxContainer
var char_stats: RichTextLabel
var char_actions: HFlowContainer
var char_family: VBoxContainer
var char_relations: RichTextLabel
var char_record: RichTextLabel
var char_skills: HBoxContainer
var char_traits: HFlowContainer
# District panel stat chips (key -> Label), the "+N unavailable" chip, and the planner's title line
var stat_chips: Dictionary = {}
var unavailable_chip: Label
var plan_title: RichTextLabel
var venture_district: int = -1
var nothing_here: bool = false
# Right-click menu on any portrait: item id -> what it does
var character_menu: PopupMenu
var character_menu_actions: Dictionary = {}
# Realm window
var realm_signature: String = ""
var succession_box: VBoxContainer
var dynasty_info: RichTextLabel
var dynasty_tree: VBoxContainer
var archive_box: VBoxContainer
var territory_info: RichTextLabel

func _ready():
	add_to_group("portrait_host")
	hovered_venture = GameData.ventures().keys()[0]
	_build_ui()
	_set_log_filter("mine")
	for problem in GameData.validate():
		push_error(problem)
		_log("Data error: " + problem, "bad")
	_set_city(CityMap.new())
	_log("You lead the Westgate Crew: one shelter in the west of a dead city, and not much food. The Iron Wardens (militarists), the Canal Guild (merchants) and the Southside Commune (socialists) are out there doing the same.", "info")
	_log("Space: pause. 1-5: speed. Esc: menu (save, load). F1-F7: windows. Click a district to act there; right-click another faction's land to deal with them.", "info")
	_log("The icons under the top bar are your problems, worst first: hover to read, click to deal with them, right-click to dismiss.", "info")
	_log("Start at home: Secure Food, Safeguard the Shelter and Gather Weapons. Once you're fed and secure, Scout the ruins next door, Scavenge them, then Settle.", "info")

func _set_city(new_city: CityMap):
	city = new_city
	city.event.connect(_on_city_event)
	city.factions_changed.connect(_rebuild_faction_cards, CONNECT_DEFERRED)
	city.first_contact.connect(func(fid): _open_faction_panel(fid, Vector2(-1, -1)), CONNECT_DEFERRED)
	city.major_event.connect(_on_major_event)
	map_view.set_city(city)
	# Start looking at your own shelter: that's where the first problems are
	var home_id = city.factions[city.player_id].home_id
	selected = city.districts[home_id] if home_id >= 0 else null
	proposals_signature = "-"
	event_queue.clear()
	event_popup.visible = false
	character_shown = -1
	_close_window()
	if true:
		_close_faction_panel()
	_rebuild_faction_cards()
	_refresh()

func _process(delta: float):
	if paused:
		return
	day_timer += delta
	var advanced = false
	while not paused and day_timer >= SECONDS_PER_DAY[speed]:
		day_timer -= SECONDS_PER_DAY[speed]
		city.advance_day()
		advanced = true
	if advanced:
		_refresh()

func _set_paused(value: bool):
	paused = value
	day_timer = 0.0
	_refresh_top_bar()

func _set_speed(value: int):
	speed = value
	_refresh_top_bar()

func _save():
	var err = city.save_game()
	_log(err if err != "" else "Game saved (%s)." % city.date_string(), "bad" if err != "" else "info")

func _load():
	var loaded = CityMap.load_game()
	if loaded == null:
		_log("No saved game to load.", "bad")
		return
	_set_paused(true)
	_set_city(loaded)
	_log("Game loaded (%s)." % city.date_string(), "info")

# --- UI construction ------------------------------------------------------------

func _build_ui():
	_build_theme()
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# The map fills the screen; everything else sits over it
	map_view = CityMapView.new()
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.district_clicked.connect(_on_district_clicked)
	map_view.district_right_clicked.connect(_on_district_right_clicked)
	add_child(map_view)

	_build_top_bar()
	_build_alert_row()
	_build_window_slot()
	_build_right_column()
	_build_bottom_bar()

	# Windows (see Steering/09-ui-plan.md): each is a set of tab pages in the left slot
	_build_character_window()
	_build_council_window()
	_build_realm_window()
	_build_diplomacy_window()
	_build_ambitions_window()
	_build_economy_window()
	_build_log_window()
	_build_district_panel()
	_explain_windows()

	_build_event_popup()
	_build_game_menu()
	character_menu = PopupMenu.new()
	character_menu.id_pressed.connect(func(id): if character_menu_actions.has(id): character_menu_actions[id].call())
	add_child(character_menu)

func _build_theme():
	# Tooltips get a solid panel so their text never mixes with the map behind them
	var ui_theme = Theme.new()
	var tooltip_style = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.07, 0.08, 0.09, 0.97)
	tooltip_style.border_color = Color(0.3, 0.32, 0.36)
	tooltip_style.set_border_width_all(1)
	tooltip_style.set_content_margin_all(8)
	ui_theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	# Buttons get a visible frame, so what can be clicked stands apart from what can't
	var button_styles = {
		"normal": [Color(0.19, 0.22, 0.26), Color(0.36, 0.41, 0.48)],
		"hover": [Color(0.25, 0.29, 0.34), Color(0.85, 0.7, 0.35)],
		"pressed": [Color(0.18, 0.32, 0.52), Color(0.45, 0.62, 0.9)],
		"hover_pressed": [Color(0.22, 0.37, 0.58), Color(0.85, 0.7, 0.35)],
		"disabled": [Color(0.12, 0.13, 0.14, 0.6), Color(0.18, 0.19, 0.2)],
	}
	for state in button_styles:
		ui_theme.set_stylebox(state, "Button", _box(button_styles[state][0], button_styles[state][1]))
	ui_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	ui_theme.set_color("font_color", "Button", Color(0.93, 0.93, 0.93))
	ui_theme.set_color("font_hover_color", "Button", Color(1, 1, 1))
	ui_theme.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	ui_theme.set_color("font_hover_pressed_color", "Button", Color(1, 1, 1))
	ui_theme.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.45))
	theme = ui_theme

# A dark panel for anything that sits over the map
func _panel(alpha: float = 0.95) -> PanelContainer:
	var p = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, alpha)
	style.border_color = Color(0.26, 0.28, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", style)
	return p

# --- Top bar: leader, resources, time --------------------------------------------------

const TOP_BAR_H = 40
const ALERT_ROW_H = 30
const BOTTOM_BAR_H = 46
const WINDOW_W = 470
const RIGHT_W = 400

func _build_top_bar():
	var bar = _panel(0.97)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_BAR_H
	add_child(bar)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	# Your leader: the way into their character window
	leader_button = Portrait.new()
	leader_button.custom_minimum_size = Vector2(26, 30)
	leader_button.clicked.connect(func(c): _show_character(c.id))
	row.add_child(leader_button)
	faction_label = Label.new()
	faction_label.add_theme_font_size_override("font_size", 14)
	row.add_child(faction_label)
	# Resources: short on the bar, the full breakdown on hover
	for key in ["manpower", "supplies", "materials", "arms", "wealth", "renown", "districts"]:
		var chip = Button.new()
		chip.flat = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.add_theme_font_size_override("font_size", 13)
		chip.add_theme_constant_override("h_separation", 0)
		chip.pressed.connect(func(): _open_window("economy"))
		row.add_child(chip)
		resource_chips[key] = chip
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	date_label = Label.new()
	date_label.add_theme_font_size_override("font_size", 14)
	row.add_child(date_label)
	pause_button = _button("", func(): _set_paused(not paused))
	pause_button.custom_minimum_size.x = 56
	pause_button.tooltip_text = "Space"
	row.add_child(pause_button)
	for i in range(1, 6):
		var b = _button(str(i), func(): _set_speed(i))
		b.toggle_mode = true
		b.tooltip_text = "Speed %d (key %d)" % [i, i]
		speed_buttons.append(b)
		row.add_child(b)
	row.add_child(_button("Menu", _toggle_game_menu))

# --- Alerts: one icon per problem, until it's fixed or dismissed --------------------------

func _build_alert_row():
	alert_row = HBoxContainer.new()
	alert_row.add_theme_constant_override("separation", 4)
	alert_row.position = Vector2(8, TOP_BAR_H + 3)
	alert_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(alert_row)

# --- Left window slot ---------------------------------------------------------------------

func _build_window_slot():
	window_slot = _panel(0.97)
	window_slot.anchor_bottom = 1.0
	window_slot.offset_left = 6
	window_slot.offset_top = TOP_BAR_H + ALERT_ROW_H + 4
	window_slot.offset_right = 6 + WINDOW_W
	window_slot.offset_bottom = -BOTTOM_BAR_H - 4
	window_slot.visible = false
	add_child(window_slot)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	window_slot.add_child(box)
	var header = HBoxContainer.new()
	box.add_child(header)
	window_title = Label.new()
	window_title.add_theme_font_size_override("font_size", 18)
	window_title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_title.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(window_title)
	var close = _button("X", _close_window)
	close.tooltip_text = "Close (Esc)"
	header.add_child(close)
	window_top = VBoxContainer.new()
	box.add_child(window_top)
	window_tab_bar = HBoxContainer.new()
	window_tab_bar.add_theme_constant_override("separation", 3)
	box.add_child(window_tab_bar)
	window_body = VBoxContainer.new()
	window_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(window_body)

# Registers a window: its title, hotkey and (optionally) a header shown above its tabs
func _window(id: String, title: String, hotkey: String) -> Dictionary:
	var w = {"id": id, "title": title, "hotkey": hotkey, "tabs": {}, "order": [], "current": "", "top": null}
	windows[id] = w
	return w

# Adds a tab page to a window; returns the container to fill
func _page(window_id: String, tab_id: String, label: String) -> VBoxContainer:
	var w = windows[window_id]
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.visible = false
	window_body.add_child(scroll)
	var page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 4)
	scroll.add_child(page)
	var tab_button = _button(label, func(): _show_tab(window_id, tab_id))
	tab_button.toggle_mode = true
	tab_button.add_theme_font_size_override("font_size", 13)
	tab_button.visible = false
	window_tab_bar.add_child(tab_button)
	w["tabs"][tab_id] = {"scroll": scroll, "page": page, "button": tab_button}
	w["order"].append(tab_id)
	if w["current"] == "":
		w["current"] = tab_id
	return page

func _window_top(window_id: String) -> VBoxContainer:
	var top = VBoxContainer.new()
	top.visible = false
	window_top.add_child(top)
	windows[window_id]["top"] = top
	return top

func _open_window(id: String, tab: String = ""):
	if open_window != "" and open_window != id:
		_hide_window_parts(open_window)
	open_window = id
	var w = windows[id]
	window_title.text = w["title"]
	if w["top"]:
		w["top"].visible = true
	for tab_id in w["order"]:
		w["tabs"][tab_id]["button"].visible = not (id == "diplomacy" and tab_id == "faction" and panel_fid == "")
	window_tab_bar.visible = w["order"].size() > 1
	window_slot.visible = true
	_show_tab(id, tab if tab != "" else w["current"])
	for key in menu_buttons:
		menu_buttons[key].set_pressed_no_signal(key == id)

func _hide_window_parts(id: String):
	var w = windows[id]
	if w["top"]:
		w["top"].visible = false
	for tab_id in w["order"]:
		w["tabs"][tab_id]["scroll"].visible = false
		w["tabs"][tab_id]["button"].visible = false

func _show_tab(id: String, tab_id: String):
	var w = windows[id]
	w["current"] = tab_id
	window_title.tooltip_text = w["tabs"][tab_id].get("tip", "")
	realm_signature = ""
	char_signature = ""
	for t in w["order"]:
		w["tabs"][t]["scroll"].visible = t == tab_id
		w["tabs"][t]["button"].set_pressed_no_signal(t == tab_id)
	_refresh_open_window()

func _close_window():
	if open_window == "":
		return
	_hide_window_parts(open_window)
	open_window = ""
	window_slot.visible = false
	for key in menu_buttons:
		menu_buttons[key].set_pressed_no_signal(false)

func _toggle_window(id: String):
	if open_window == id:
		_close_window()
	else:
		_open_window(id)

# --- Right column: outliner above, district panel below ---------------------------------

func _build_right_column():
	var column = VBoxContainer.new()
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = -RIGHT_W - 6
	column.offset_right = -6
	column.offset_top = TOP_BAR_H + 4
	column.offset_bottom = -BOTTOM_BAR_H - 4
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	right_column = column
	var outliner = _panel(0.9)
	column.add_child(outliner)
	var box = VBoxContainer.new()
	outliner.add_child(box)
	var header = HBoxContainer.new()
	box.add_child(header)
	var title = Label.new()
	title.text = "Outliner"
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var fold = _button("-", func(): outliner_scroll.visible = not outliner_scroll.visible; outliner_fold.text = "-" if outliner_scroll.visible else "+")
	fold.tooltip_text = "Fold the outliner away"
	header.add_child(fold)
	outliner_fold = fold
	outliner_scroll = ScrollContainer.new()
	outliner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outliner_scroll.custom_minimum_size.y = 170
	box.add_child(outliner_scroll)
	outliner_text = _rich()
	outliner_text.add_theme_font_size_override("normal_font_size", 13)
	outliner_text.add_theme_font_size_override("bold_font_size", 13)
	outliner_text.meta_clicked.connect(_on_link_clicked)
	outliner_scroll.add_child(outliner_text)

# --- Bottom bar: window buttons, ticker, map modes ---------------------------------------

const MENU = [["character", "Character", "F1"], ["council", "Council", "F2"], ["realm", "Realm", "F3"],
	["diplomacy", "Diplomacy", "F4"], ["ambitions", "Ambitions", "F5"], ["economy", "Economy", "F6"], ["log", "Log", "F7"]]

func _build_bottom_bar():
	var bar = _panel(0.97)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BOTTOM_BAR_H
	add_child(bar)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	for entry in MENU:
		var id: String = entry[0]
		var b = _button(entry[1], func(): _on_menu_button(id))
		b.toggle_mode = true
		b.tooltip_text = "%s (%s)" % [entry[1], entry[2]]
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		menu_buttons[id] = b
	ticker = RichTextLabel.new()
	ticker.bbcode_enabled = true
	ticker.scroll_active = false
	ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker.add_theme_font_size_override("normal_font_size", 12)
	ticker.add_theme_font_size_override("bold_font_size", 12)
	ticker.mouse_filter = Control.MOUSE_FILTER_PASS
	ticker.tooltip_text = "The latest news about you. The full log: Log (F7)"
	row.add_child(ticker)
	for mode in [["political", "Political"], ["grievance", "Grievance"], ["fog", "Full fog"]]:
		var key: String = mode[0]
		var b = _button(mode[1], func(): _set_map_mode(key))
		b.toggle_mode = true
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 13)
		row.add_child(b)
		map_mode_buttons[key] = b
	map_mode_buttons["political"].tooltip_text = "Who holds what"
	map_mode_buttons["grievance"].tooltip_text = "Unrest: green is calm, red is close to revolt"
	map_mode_buttons["fog"].tooltip_text = "Off: you see every faction, but unscouted ruins hide their salvage and danger.\nOn: you only see your land, the land next to it, and what you've scouted."
	map_mode_buttons["political"].set_pressed_no_signal(true)

func _on_menu_button(id: String):
	if id == "character":
		if open_window == "character":
			_close_window()
		else:
			_show_character(city.leader_of(city.player_id).id if city.leader_of(city.player_id) else -1)
		return
	_toggle_window(id)

func _set_map_mode(key: String):
	match key:
		"political":
			map_view.show_heat = false
		"grievance":
			map_view.show_heat = not map_view.show_heat
		"fog":
			map_view.full_fog = not map_view.full_fog
	map_mode_buttons["political"].set_pressed_no_signal(not map_view.show_heat)
	map_mode_buttons["grievance"].set_pressed_no_signal(map_view.show_heat)
	map_mode_buttons["fog"].set_pressed_no_signal(map_view.full_fog)
	map_view.refresh()

# --- Event pop-ups: the big moments, one at a time -----------------------------------------

func _build_event_popup():
	event_popup = _panel(0.98)
	event_popup.set_anchors_preset(Control.PRESET_CENTER)
	event_popup.custom_minimum_size = Vector2(500, 0)
	event_popup.visible = false
	add_child(event_popup)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	event_popup.add_child(box)
	event_title = Label.new()
	event_title.add_theme_font_size_override("font_size", 20)
	event_title.add_theme_color_override("font_color", Color(0.9, 0.78, 0.5))
	box.add_child(event_title)
	event_text = _rich()
	event_text.custom_minimum_size.x = 480
	box.add_child(event_text)
	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	event_open = _button("Open diplomacy", func(): var fid = event_faction; _close_event(); _open_faction_panel(fid, Vector2(-1, -1)))
	buttons.add_child(event_open)
	buttons.add_child(_button("OK", _close_event))

func _on_major_event(title: String, text: String, faction_id: String):
	event_queue.append([title, text, faction_id])
	if not event_popup.visible:
		_next_event()

func _next_event():
	if event_queue.is_empty():
		event_popup.visible = false
		return
	var e = event_queue.pop_front()
	event_title.text = e[0]
	event_text.text = e[1]
	event_faction = e[2] if city.factions.has(e[2]) and e[2] != city.player_id else ""
	event_open.visible = event_faction != ""
	event_popup.visible = true
	event_popup.reset_size()
	event_popup.position = (get_viewport_rect().size - event_popup.size) * 0.5
	if not paused:
		_set_paused(true)

func _close_event():
	_next_event()

# --- Game menu (Esc) ---------------------------------------------------------------------

func _build_game_menu():
	game_menu = _panel(0.98)
	game_menu.custom_minimum_size = Vector2(260, 0)
	game_menu.visible = false
	add_child(game_menu)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	game_menu.add_child(box)
	var title = Label.new()
	title.text = "Game menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	box.add_child(_button("Resume", _toggle_game_menu))
	box.add_child(_button("Save", func(): _save(); _toggle_game_menu()))
	box.add_child(_button("Load", func(): _toggle_game_menu(); _load()))
	pause_on_alert = CheckBox.new()
	pause_on_alert.text = "Pause when something needs you"
	pause_on_alert.button_pressed = true
	pause_on_alert.focus_mode = Control.FOCUS_NONE
	box.add_child(pause_on_alert)
	box.add_child(_button("Quit", func(): get_tree().quit()))

func _toggle_game_menu():
	game_menu.visible = not game_menu.visible
	if game_menu.visible:
		_set_paused(true)
		game_menu.reset_size()
		game_menu.position = (get_viewport_rect().size - game_menu.size) * 0.5

# --- Windows -----------------------------------------------------------------------------

func _build_diplomacy_window():
	_window("diplomacy", "Diplomacy", "F4")
	var list = _page("diplomacy", "factions", "Factions")
	list.add_child(_header("Your treaties"))
	treaties_info = _rich()
	list.add_child(treaties_info)
	list.add_child(_header("Factions you know"))
	war_box = VBoxContainer.new()
	war_box.add_theme_constant_override("separation", 6)
	list.add_child(war_box)
	proposals_box = VBoxContainer.new()
	_page("diplomacy", "proposals", "Proposals").add_child(proposals_box)
	subjects_info = _rich()
	_page("diplomacy", "subjects", "Subjects").add_child(subjects_info)
	panel_body = _page("diplomacy", "faction", "Faction")

func _build_economy_window():
	_window("economy", "Economy", "F6")
	economy_info = _rich()
	_page("economy", "economy", "Economy").add_child(economy_info)
	var traits_page = _page("economy", "traits", "Faction traits")
	for trait_name in GameData.traits():
		var t = Trait.new(trait_name, GameData.traits()[trait_name])
		if t.source != "":
			traits_page.add_child(_trait_row(t))

# Ambitions (F5): the National Ambitions you can pursue, and the deeds that earn the renown to pay for them
func _build_ambitions_window():
	_window("ambitions", "Ambitions", "F5")
	var page = _page("ambitions", "ambitions", "Ambitions")
	ambition_intro = _rich()
	page.add_child(ambition_intro)
	var kinds = []
	for id in GameData.national_ambitions():
		var kind: String = GameData.national_ambition(id)["kind"]
		if kind not in kinds:
			kinds.append(kind)
	for kind in kinds:
		page.add_child(_header(kind))
		for id in GameData.national_ambitions():
			if GameData.national_ambition(id)["kind"] == kind:
				ambition_cards[id] = _make_ambition_card(id)
				page.add_child(ambition_cards[id]["root"])
	var milestones = _page("ambitions", "deeds", "Deeds")
	ambitions_info = _rich()
	milestones.add_child(ambitions_info)
	for k in AMBITION_ROWS:
		var row = HBoxContainer.new()
		var label = _rich()
		row.add_child(label)
		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(110, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		var bar_bg = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.2, 0.21, 0.24)
		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.85, 0.7, 0.35)
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", bar_fill)
		row.add_child(bar)
		milestones.add_child(row)
		ambition_rows.append({"label": label, "bar": bar})

func _build_log_window():
	_window("log", "Log", "F7")
	var page = _page("log", "log", "Log")
	var filters = HBoxContainer.new()
	page.add_child(filters)
	for key in ["mine", "neighbours", "all"]:
		var b = _button({"mine": "About you", "neighbours": "Neighbours", "all": "Everyone"}[key], func(): _set_log_filter(key))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 13)
		filters.add_child(b)
		log_filter_buttons[key] = b
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.fit_content = true
	log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_view.add_theme_font_size_override("normal_font_size", 13)
	page.add_child(log_view)

# Refreshes only the window that's open (the others update when you open them)
func _refresh_open_window():
	if city == null:
		return
	match open_window:
		"character":
			_refresh_character()
		"council":
			_refresh_captains()
		"realm":
			_refresh_realm()
		"diplomacy":
			_refresh_diplomacy()
			_refresh_treaties()
			_refresh_subjects()
		"economy":
			_refresh_economy()
			_refresh_traits()
		"ambitions":
			_refresh_ambition_cards()
			_refresh_ambitions()

func _refresh_subjects():
	var me = city.player_id
	var lines = []
	var overlord = city.overlord_of(me)
	if overlord != "":
		lines.append("You are a vassal of [url=f:%s][color=%s]%s[/color][/url]: you pay them tribute and can't declare war." % [overlord, _hex(overlord), city.faction_name(overlord)])
	for vid in city.vassals_of(me):
		var r = city.relation(me, vid)
		lines.append("[url=f:%s][color=%s][b]%s[/b][/color][/url]: vassal for %d days, opinion of you %+d, %d districts" % [
			vid, _hex(vid), city.faction_name(vid), city.day - r.vassal_since_day, r.opinion[vid], city.districts_held(vid)])
	subjects_info.text = "\n".join(lines) if lines.size() > 0 else "[color=#999999]No vassals yet. Small factions up to 70% of your strength may accept you as their patron (Demand vassalage).[/color]"

# --- District panel (right, when a district is selected) -----------------------------------

func _show_district_tab(key: String):
	district_tab = key
	for k in district_pages:
		district_pages[k]["scroll"].visible = k == key
		district_tab_buttons[k].set_pressed_no_signal(k == key)

func _show_district(tab: String = ""):
	district_panel.visible = selected != null
	if tab != "":
		_show_district_tab(tab)

func _deselect():
	selected = null
	district_panel.visible = false
	_refresh()

# Selects a district, opens its panel on a venture, and brings it into view
func _goto_venture(d: District, venture_id: String):
	if d == null:
		return
	selected = d
	_show_district("district")
	map_view.center_on(d)
	_refresh()
	_on_venture_pressed(venture_id)

func _on_link_clicked(meta):
	var s = str(meta)
	var kind = s.get_slice(":", 0)
	var value = s.get_slice(":", 1)
	match kind:
		"d":
			var d: District = city.districts[int(value)]
			selected = d
			_show_district()
			map_view.center_on(d)
			_refresh()
		"f":
			_open_faction_panel(value, Vector2(-1, -1))
		"c":
			_show_character(int(value))

# --- Outliner --------------------------------------------------------------------------------

func _refresh_outliner():
	var me = city.player_id
	var lines = []
	# Standing tasks first: who works where, and how far there is to go
	var my_tasks = city.tasks.filter(func(t): return t.faction_id == me)
	if not my_tasks.is_empty():
		lines.append("[b]Tasks (%d)[/b]" % my_tasks.size())
		for t in my_tasks:
			var holder = city.character_by_id(t.character_id)
			var td: District = city.districts[t.district_id]
			lines.append("[url=d:%d]%s %s[/url] [color=#999999]%s, %s[/color]%s" % [td.id, GameData.venture(t.venture_id)["task_label"], td.district_name,
				holder.name.get_slice(" ", 0) if holder else "?", city.task_progress_text(t).to_lower(), ("  [color=#ffb347]waiting[/color]" if t.paused != "" else "")])
	var mine = city.ventures.filter(func(v): return v.faction_id == me and not v.task)
	if not mine.is_empty():
		lines.append("[b]Your ventures (%d)[/b]" % mine.size())
		for v in mine:
			var leader = city.character_by_id(v.leader_id)
			# Live odds: the target can react after launch, so show when the chance has fallen
			var now = city.venture_odds(v)
			var odds_text = "%d%%" % (now * 100)
			if now < v.launch_odds - 0.02:
				odds_text = "[color=#e3876f]%d%% (was %d%%)[/color]" % [now * 100, v.launch_odds * 100]
			lines.append("[url=d:%d]%s in %s[/url] [color=#999999]%s, %dd, [/color]%s" % [v.district.id, GameData.venture(v.venture_id)["label"],
				v.district.district_name, leader.name.get_slice(" ", 0) if leader else "", v.days_left, odds_text])
	var incoming = city.incoming_attacks(me)
	if not incoming.is_empty():
		lines.append("[b][color=#ff7a5c]Incoming (%d)[/color][/b]" % incoming.size())
		for v in incoming:
			lines.append("[color=#ff9a80][url=d:%d]%s %s on %s[/url] in %dd[/color]" % [v.district.id, city.faction_name(v.faction_id),
				GameData.venture(v.venture_id)["label"], v.district.district_name, v.days_left])
	var builds = city.constructions.filter(func(c): return c.faction_id == me)
	if not builds.is_empty():
		lines.append("[b]Building (%d)[/b]" % builds.size())
		for c in builds:
			lines.append("[url=d:%d]%s in %s[/url] [color=#999999]%dd[/color]" % [c.district.id, GameData.building(c.building_id)["label"], c.district.district_name, c.days_left])
	var envoys = city.missions.filter(func(m): return m.from_id == me)
	if not envoys.is_empty():
		lines.append("[b]Envoys (%d)[/b]" % envoys.size())
		for m in envoys:
			lines.append("[url=f:%s]%s to the %s[/url] [color=#999999]%dd[/color]" % [m.to_id, GameData.diplomacy_action(m.action_id)["label"], city.faction_name(m.to_id), m.days_left])
	var wars = city.war_enemies(me)
	if not wars.is_empty():
		lines.append("[b][color=#ff7a5c]At war[/color][/b]")
		for fid in wars:
			var r = city.relation(me, fid)
			lines.append("[url=f:%s][color=%s]%s[/color][/url] [color=#999999]%d days, your weariness %d, theirs %d[/color]" % [fid, _hex(fid), city.faction_name(fid),
				city.day - r.war_start_day, r.exhaustion[me], r.exhaustion[fid]])
	var neighbours = city.factions.keys().filter(func(fid): return fid != me and city.shares_border(me, fid))
	if not neighbours.is_empty():
		lines.append("[b]Neighbours[/b]")
		lines.append("  ".join(neighbours.map(func(fid): return "[url=f:%s][color=%s]%s[/color][/url]" % [fid, _hex(fid), city.faction_name(fid)])))
	outliner_text.text = "\n".join(lines) if lines.size() > 0 else "[color=#777777]Nothing under way. Pick a district and launch a venture.[/color]"

# --- Top bar -------------------------------------------------------------------------------

func _refresh_top_bar():
	date_label.text = "Y%d M%d D%d" % [city.day / 360 + 1, (city.day / 30) % 12 + 1, city.day % 30 + 1]
	date_label.tooltip_text = city.date_string()
	date_label.mouse_filter = Control.MOUSE_FILTER_PASS
	pause_button.text = "Play" if paused else "Pause"
	for i in speed_buttons.size():
		speed_buttons[i].button_pressed = (i + 1 == speed)
	var p = _player()
	var leader = city.leader_of(p.id)
	leader_button.setup(leader, p.color)
	if leader:
		leader_button.tooltip_text = "%s, %d, leader of the %s\nClick: character window (F1)" % [leader.name, leader.age, p.display_name]
	# Just a war flag: your name is on the portrait's tooltip, and the space goes to resources
	faction_label.text = "AT WAR" if city.at_war_with_anyone(p.id) else ""
	faction_label.tooltip_text = "At war with: " + ", ".join(city.war_enemies(p.id).map(func(fid): return city.faction_name(fid)))
	faction_label.mouse_filter = Control.MOUSE_FILTER_PASS
	faction_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if city.at_war_with_anyone(p.id) else Color(0.85, 0.85, 0.85))
	var e = city.daily_economy(p.id)
	var food_day = e["supplies"]["income"] - e["supplies"]["upkeep"]
	var mat_day = e["materials"]["income"] - e["materials"]["upkeep"]
	var wealth_day = e["wealth"]["income"] - e["wealth"]["upkeep"]
	_chip("manpower", "Manpower %d/%d" % [p.manpower, city.crew_cap(p.id)], 0.0, _manpower_tooltip(e))
	_chip("supplies", "Food %d %s" % [p.supplies, _signed(food_day)], food_day, _resource_tooltip("supplies", "Food", e, food_day))
	_chip("materials", "Materials %d %s" % [p.materials, _signed(mat_day)], mat_day, _resource_tooltip("materials", "Materials", e, mat_day))
	_chip("arms", "Arms %d" % p.arms, 0.0, "Arms: %d (store up to %d)\nFrom Gather Weapons. Raids use 2 and assaults 4.\nEach arm makes your attacks 1.5%% likelier to succeed, and attacks on you 1%% less likely (counts up to %d)." % [
		p.arms, GameData.rule("arms_cap"), GameData.rule("arms_effect_cap")])
	_chip("wealth", "Wealth %d %s" % [p.wealth, _signed(wealth_day)], wealth_day, _resource_tooltip("wealth", "Wealth", e, wealth_day))
	_chip("renown", "Renown %d" % p.renown, 0.0, "Renown: %d to spend on National Ambitions (F5). Earned by deeds and triumphs. Unspent, it helps your proposals get accepted.\n\nReputation: %d, everything you've ever earned (it never goes down). It raises your manpower and captain limits, draws better recruits, strengthens your heir's claim and earns respect.%s" % [
		p.renown, p.reputation, ("\n\nPursuing %s: %d days left." % [GameData.national_ambition(p.ambition)["label"], p.ambition_days_left]) if p.ambition != "" else "\n\nNo ambition under way."])
	_chip("districts", "Land %d" % city.districts_held(p.id), 0.0, "Districts held: %d\nThe first %d cost no administration; after that the cost climbs faster than your territory (now %.2f wealth a day)." % [
		city.districts_held(p.id), GameData.rule("admin_free_districts"), city.admin_upkeep(p.id)])

func _chip(key: String, text: String, change: float, tooltip: String):
	var chip: Button = resource_chips[key]
	chip.text = text
	chip.tooltip_text = tooltip + "\n\nClick: Economy (F6)"
	chip.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if change < -0.005 else Color(0.9, 0.9, 0.9))

# Where a resource comes from and where it goes, per day
func _resource_tooltip(key: String, label: String, e: Dictionary, net: float) -> String:
	var p = _player()
	var lines = ["%s: %d (%s a day)" % [label, p.get(key), _signed(net)], "", "Comes from:"]
	var sources = []
	for d in city.districts:
		if d.owner_id() == p.id:
			var amount: float = city.district_income(d)[key]
			if amount > 0.005:
				sources.append([d.district_name, amount])
	sources.sort_custom(func(a, b): return a[1] > b[1])
	for s in sources.slice(0, 6):
		lines.append("  %s  +%.2f" % [s[0], s[1]])
	if sources.size() > 6:
		var rest = 0.0
		for s in sources.slice(6):
			rest += s[1]
		lines.append("  %d more districts  +%.2f" % [sources.size() - 6, rest])
	if key == "wealth" and e["trade"] > 0.0:
		lines.append("  Trade agreements  +%.2f" % e["trade"])
	if key in e["tribute"] and absf(e["tribute"][key]) > 0.005:
		lines.append("  Tribute  %s" % _signed(e["tribute"][key]))
	if sources.is_empty() and lines.size() == 3:
		lines.append("  nothing yet")
	lines.append("")
	lines.append("Goes to:")
	for part in city.upkeep_breakdown(p.id)[key]:
		if part[1] > 0.005:
			lines.append("  %s  -%.2f" % [part[0], part[1]])
	match key:
		"materials":
			lines.append("\nMore: Scavenge ruins, Trade Runs, Salvage Yards, and Recycling Works (never run out).")
		"supplies":
			lines.append("\nMore: Secure Food, Allotments, Trade Runs. Food over %d spoils." % GameData.rule("food_fresh_store"))
		"wealth":
			lines.append("\nMore: more people pay more tax; Markets; trade agreements.")
	return "\n".join(lines)

func _manpower_tooltip(e: Dictionary) -> String:
	var p = _player()
	var lines = ["Manpower: %d idle, %d away on ventures" % [p.manpower, city.crew_away(p.id)], "",
		"Limit %d:" % city.crew_cap(p.id)]
	for part in city.crew_cap_breakdown(p.id):
		lines.append("  %s  +%d" % [part[0], part[1]])
	lines.append("")
	lines.append("New manpower +%.2f a day, grown from each district's food (and a share of your land next door):" % e["manpower"])
	var sources = []
	for d in city.districts:
		if d.owner_id() == p.id:
			var amount: float = city.district_income(d)["recruits"]
			if amount > 0.001:
				sources.append([d.district_name, amount])
	sources.sort_custom(func(a, b): return a[1] > b[1])
	for s in sources.slice(0, 6):
		lines.append("  %s  +%.3f" % [s[0], s[1]])
	lines.append("\nSettlers who stay in new land are gone for good.")
	return "\n".join(lines)

# --- Alerts ----------------------------------------------------------------------------------

const ALERT_STYLES = {"urgent": [Color(0.42, 0.12, 0.09, 0.95), Color(1.0, 0.45, 0.35)],
	"pressing": [Color(0.38, 0.27, 0.08, 0.95), Color(0.95, 0.72, 0.3)],
	"chance": [Color(0.12, 0.3, 0.14, 0.95), Color(0.5, 0.85, 0.5)]}

# "At the start you don't have goals, you have problems": one icon per problem, worst first
func _refresh_alerts(economy: Dictionary):
	var p = _player()
	var list = []
	var home: District = city.districts[p.home_id] if p.home_id >= 0 else null
	var food_day = economy["supplies"]["income"] - economy["supplies"]["upkeep"]
	if p.starving:
		list.append(_alert("food", "urgent", "Starving", "Starving: manpower is deserting and people are leaving.\nSecure Food, or build Allotments.", func(): _goto_venture(home, "secure_food")))
	elif food_day < 0.0:
		var days = int(p.supplies / -food_day)
		list.append(_alert("food", "urgent" if days < 30 else "pressing", "Food %dd" % days, "Food runs out in %d days (%s a day).\nSecure Food, or build Allotments." % [days, _signed(food_day)], func(): _goto_venture(home, "secure_food")))
	for v in city.incoming_attacks(p.id):
		var attacker: Faction = city.factions.get(v.faction_id)
		if attacker == null:
			continue
		var odds = VentureSystem.compute_odds(v.venture_id, attacker, v.district, city, p.id, city.character_by_id(v.leader_id), v.crew, v.funding)["odds"]
		var d = v.district
		list.append(_alert("incoming:%d:%s" % [d.id, v.faction_id], "urgent", "%s %dd" % [GameData.venture(v.venture_id)["label"], v.days_left],
			"INCOMING: %s %s on %s lands in %d days (%d%% to succeed).\nClick to Reinforce it." % [attacker.display_name, GameData.venture(v.venture_id)["label"], d.district_name, v.days_left, odds * 100],
			func(): _goto_venture(d, "reinforce")))
	for fid in city.factions:
		var ai: FactionAI = city.factions[fid].ai
		if ai and ai.war_plan_target == p.id and ai.war_plan_day >= city.day:
			var them = fid
			list.append(_alert("war:" + fid, "urgent", "War %dd" % (ai.war_plan_day - city.day),
				"WAR COMING: the %s will likely declare war in %d days.\nOffer gifts or a pact, or arm up and Reinforce your border. Click for diplomacy." % [city.faction_name(fid), ai.war_plan_day - city.day],
				func(): _open_faction_panel(them, Vector2(-1, -1))))
	if home and home.owner_id() != p.id:
		list.append(_alert("home_lost", "urgent", "Shelter lost", "You've lost your shelter.", func(): pass))
	elif home and home.share(p.id) < GameData.rule("secure_threshold"):
		list.append(_alert("shelter", "pressing", "Shelter %d/%d" % [home.share(p.id), GameData.rule("secure_threshold")],
			"Your shelter isn't secure (control %d of %d).\nSafeguard the Shelter raises control." % [home.share(p.id), GameData.rule("secure_threshold")], func(): _goto_venture(home, "safeguard")))
	if p.disrepair:
		list.append(_alert("disrepair", "urgent", "Disrepair", "Out of materials: your buildings are in disrepair and not working.\nScavenge or run trade for materials.", func(): _goto_venture(home, "scavenge")))
	elif p.materials < 10.0:
		list.append(_alert("materials", "pressing", "Materials %d" % p.materials, "Few materials (%d).\nScavenge ruins, yours or unclaimed next door." % p.materials, func(): _goto_venture(home, "scavenge")))
	var wealth_day = economy["wealth"]["income"] - economy["wealth"]["upkeep"]
	if wealth_day < 0.0 and p.wealth < 20.0:
		list.append(_alert("wealth", "urgent", "Wealth", "Wealth is running out (%s a day): buildings stop and the council goes unpaid." % _signed(wealth_day), func(): _open_window("economy")))
	for d in city.districts:
		if d.owner_id() == p.id and d.grievance >= 65.0:
			var here = d
			list.append(_alert("revolt:%d" % d.id, "urgent", "Unrest: %s" % d.district_name, "%s is close to revolt (grievance %d).\nRelief calms it." % [d.district_name, d.grievance], func(): _goto_venture(here, "relief")))
	# Neighbours who might come for your food and materials
	for fid in city.factions:
		if fid == p.id or not city.shares_border(p.id, fid) or city.relation(p.id, fid).protected() or city.is_at_war(p.id, fid) or city.relation(p.id, fid).spare_until[fid] > city.day:
			continue
		var them: Faction = city.factions[fid]
		var why = "raiders" if city.is_raider(fid) else ("hungry" if them.supplies < 15.0 or them.starving else ("hostile" if city.opinion_of(fid, p.id) <= -25.0 else ""))
		if why == "":
			continue
		var target = fid
		list.append(_alert("threat:" + fid, "urgent" if them.arms > p.arms + 4.0 else "pressing", "%s (%s)" % [them.display_name, why],
			"The %s (%s) border you. Your arms %d, theirs %d.\nGather Weapons, Safeguard, a Watchtower or Reinforce; or make a pact, pay tribute or Threaten them. Click for diplomacy." % [them.display_name, why, p.arms, them.arms],
			func(): _open_faction_panel(target, Vector2(-1, -1))))
	if p.arms < 2.0:
		list.append(_alert("arms", "pressing", "No arms", "No weapons: you can't raid or assault, and raiders face no armed defence.\nGather Weapons.", func(): _goto_venture(home, "gather_weapons")))
	if p.manpower < 3.0:
		list.append(_alert("manpower", "pressing", "Manpower", "Almost no idle manpower. People come from food: feed your districts.", func(): _open_window("economy")))
	# People: empty seats, restless crew, the succession
	var empty = GameData.council()["posts"].keys().filter(func(post): return city.council_member(p.id, post) == null)
	if not empty.is_empty():
		list.append(_alert("seats", "pressing", "Empty seats %d" % empty.size(), "%d council seats are empty: %s.\nEach seat boosts every venture using its skill." % [empty.size(),
			", ".join(empty.map(func(post): return GameData.council_post(post)["label"]))], func(): _open_window("council", "seats")))
	var restless = city.characters_of(p.id).filter(func(c): return c.loyalty() < GameData.rule("loyalty_restless"))
	if not restless.is_empty():
		list.append(_alert("restless", "pressing", "Restless %d" % restless.size(), "Restless (may desert below %d loyalty): %s" % [GameData.rule("loyalty_defect"),
			", ".join(restless.map(func(c): return "%s (%d)" % [c.name, c.loyalty()]))], func(): _open_window("council", "crew")))
	var outlook = city.succession_outlook(p.id)
	if outlook["heir"] == null:
		list.append(_alert("no_heir", "urgent", "No heir", "No one could take over if your leader died.", func(): _open_window("realm", "succession")))
	elif outlook["split_chance"] >= 0.25:
		list.append(_alert("split", "pressing", "Civil war risk %d%%" % (outlook["split_chance"] * 100), "If your leader died today, %d%% chance of civil war.\nSee who would contest it." % (outlook["split_chance"] * 100), func(): _open_window("realm", "succession")))
	if city.proposals.size() > 0:
		list.append(_alert("proposals", "chance", "Proposals %d" % city.proposals.size(), "%d proposals are waiting for your answer." % city.proposals.size(), func(): _open_window("diplomacy", "proposals")))
	# Deals that would probably work with the factions on your border
	for fid in city.factions:
		if fid == p.id or not city.shares_border(p.id, fid) or city.is_at_war(p.id, fid):
			continue
		var r = city.relation(p.id, fid)
		for action_id in (["vassalage", "pact", "trade"] if city.factions[fid].minor else ["pact", "trade"]):
			if (action_id == "pact" and (r.pact or r.alliance)) or (action_id == "trade" and r.trade) or Diplomacy.check_action(city, action_id, p.id, fid) != "":
				continue
			var chance = Diplomacy.acceptance(city, action_id, p.id, fid)["chance"]
			if chance >= 0.5:
				var them = fid
				list.append(_alert("deal:%s:%s" % [fid, action_id], "chance", "Deal %d%%" % (chance * 100),
					"%s with the %s: %d%% likely to be accepted. Click for diplomacy." % [GameData.diplomacy_action(action_id)["label"], city.faction_name(fid), chance * 100],
					func(): _open_faction_panel(them, Vector2(-1, -1))))
				break
	# Dismissed alerts stay hidden until the problem goes away
	var ids = list.map(func(a): return a["id"])
	for id in dismissed_alerts.keys():
		if id not in ids:
			dismissed_alerts.erase(id)
	current_alerts = list.filter(func(a): return not dismissed_alerts.has(a["id"]))
	while alert_buttons.size() < current_alerts.size():
		var index = alert_buttons.size()
		var b = _button("", func(): _on_alert_pressed(index))
		b.add_theme_font_size_override("font_size", 12)
		b.gui_input.connect(func(event): if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: _dismiss_alert(index))
		alert_row.add_child(b)
		alert_buttons.append(b)
	for i in alert_buttons.size():
		var b: Button = alert_buttons[i]
		b.visible = i < current_alerts.size()
		if not b.visible:
			continue
		var a = current_alerts[i]
		b.text = a["short"]
		b.tooltip_text = a["text"] + "\n\nClick to deal with it. Right-click to dismiss."
		var colours = ALERT_STYLES[a["level"]]
		b.add_theme_stylebox_override("normal", _box(colours[0], colours[1]))
		b.add_theme_stylebox_override("hover", _box(colours[0].lightened(0.15), Color(1, 1, 1)))

func _alert(id: String, level: String, short: String, text: String, act: Callable) -> Dictionary:
	return {"id": id, "level": level, "short": short, "text": text, "act": act}

func _on_alert_pressed(index: int):
	if index < current_alerts.size():
		current_alerts[index]["act"].call()

func _dismiss_alert(index: int):
	if index < current_alerts.size():
		dismissed_alerts[current_alerts[index]["id"]] = true
		_refresh()

# --- Character window ---------------------------------------------------------------------

func _show_character(id: int):
	if id < 0 or city.person_by_id(id) == null:
		return
	character_shown = id
	char_signature = ""
	_open_window("character")

# All the relatives of a character, living and dead
func _relatives(c: Character) -> Dictionary:
	var everyone = city.characters + city.graveyard
	var parents = c.parent_ids.map(func(id): return city.person_by_id(id)).filter(func(x): return x != null)
	var children = everyone.filter(func(x): return c.id in x.parent_ids)
	children.sort_custom(func(a, b): return a.age > b.age)
	var siblings = everyone.filter(func(x): return x != c and x.parent_ids.any(func(pid): return pid in c.parent_ids))
	return {"parents": parents, "spouse": city.person_by_id(c.spouse_id), "children": children, "siblings": siblings}

func _person_cell(c: Character, caption: String, cell_size: Vector2 = Vector2(50, 58)) -> VBoxContainer:
	var cell = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	var portrait = Portrait.new()
	portrait.custom_minimum_size = cell_size
	var f: Faction = city.factions.get(c.faction_id)
	portrait.setup(c, f.color if f else Color(0.4, 0.4, 0.4), c.death_day < 0 and c.is_wounded(city.day), _badge(c))
	portrait.clicked.connect(func(x): _show_character(x.id))
	cell.add_child(portrait)
	var label = Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.custom_minimum_size.x = cell_size.x
	label.clip_text = true
	cell.add_child(label)
	return cell

func _badge(c: Character) -> String:
	if c.death_day >= 0:
		return "dead"
	if c.is_leader:
		return "leader"
	if city.factions.has(c.faction_id) and city.succession_outlook(c.faction_id)["heir"] == c:
		return "heir"
	return ""

func _designate(character_id: int):
	var err = city.designate_heir(city.player_id, character_id)
	if err != "":
		_log(err, "bad")
	char_signature = ""
	realm_signature = ""
	_refresh()

# --- Realm window --------------------------------------------------------------------------

func _build_realm_window():
	_window("realm", "Realm", "F3")
	var succession = _page("realm", "succession", "Succession")
	succession_info = _rich()
	succession.add_child(succession_info)
	succession_box = VBoxContainer.new()
	succession_box.add_theme_constant_override("separation", 6)
	succession.add_child(succession_box)
	var dynasty = _page("realm", "dynasty", "Dynasty")
	dynasty_info = _rich()
	dynasty.add_child(dynasty_info)
	dynasty_tree = VBoxContainer.new()
	dynasty_tree.add_theme_constant_override("separation", 4)
	dynasty.add_child(dynasty_tree)
	dynasty.add_child(_header("Past leaders"))
	archive_box = VBoxContainer.new()
	archive_box.add_theme_constant_override("separation", 4)
	dynasty.add_child(archive_box)
	dynasty.add_child(_header("Fallen and departed"))
	departed_info = _rich()
	dynasty.add_child(departed_info)
	territory_info = _rich()
	territory_info.meta_clicked.connect(_on_link_clicked)
	_page("realm", "territory", "Territory").add_child(territory_info)
	var government = _page("realm", "government", "Government")
	government_info = _rich()
	government.add_child(government_info)
	reform_box = VBoxContainer.new()
	reform_box.add_theme_constant_override("separation", 6)
	government.add_child(reform_box)

func _refresh_realm():
	var me = city.player_id
	var p = _player()
	var leader = city.leader_of(me)
	match windows["realm"]["current"]:
		"succession":
			succession_info.text = _succession_text(me, true)
			var candidates = city.characters_of(me).filter(func(c): return c.family or c.post != "")
			var outlook = city.succession_outlook(me)
			var signature = "%s|%d|%s|%s" % [str(outlook["heir"].id) if outlook["heir"] else "-", p.designated_heir,
				",".join(candidates.map(func(c): return "%d:%d" % [c.id, int(c.loyalty())])), str(leader.id) if leader else "-"]
			if signature == realm_signature:
				return
			realm_signature = signature
			for child in succession_box.get_children():
				child.queue_free()
			succession_box.add_child(_header("Who could be heir"))
			candidates.sort_custom(func(a, b): return (a == outlook["heir"]) or (b != outlook["heir"] and a.family and not b.family))
			for c in candidates:
				var row = HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				row.add_child(_person_cell(c, "", Vector2(44, 52)))
				var text = _rich()
				var best = c.best_skill()
				text.text = "[b]%s[/b], %d  %s\n%s  ·  %s %d  ·  loyalty %d%s" % [c.name, c.age, "[color=#d9b35a]HEIR[/color]" if c == outlook["heir"] else "",
					"family" if c.family else GameData.council_post(c.post)["label"], best.capitalize(), c.skills[best], c.loyalty(),
					"  ·  Ambitious" if c.has_trait("ambitious") else ""]
				row.add_child(text)
				if c != outlook["heir"] and GameData.government(p.government)["heir_rule"] == "blood":
					var cid = c.id
					var b = _button("Name heir", func(): _designate(cid))
					b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					row.add_child(b)
				succession_box.add_child(row)
			if candidates.is_empty():
				var none = Label.new()
				none.text = "No family or council members yet."
				succession_box.add_child(none)
		"dynasty":
			_refresh_departed()
			var house = leader.dynasty if leader else ""
			var members = (city.characters + city.graveyard).filter(func(c): return c.dynasty == house and c.faction_id == me)
			var signature = "%s|%d|%d|%d" % [house, members.size(), city.graveyard.size(), city.day / 360]
			if signature == realm_signature:
				return
			realm_signature = signature
			var living = members.filter(func(c): return c.death_day < 0).size()
			dynasty_info.text = "[font_size=17][b]House %s[/b][/font_size]\n%d members, %d living. [color=#999999]Click anyone to see them.[/color]" % [house, members.size(), living]
			for child in dynasty_tree.get_children():
				child.queue_free()
			# Generations: founders first, then their children, and so on
			var depth = {}
			for c in members:
				depth[c.id] = _generation(c, members, 0)
			var generations = {}
			for c in members:
				generations[depth[c.id]] = generations.get(depth[c.id], []) + [c]
			var keys = generations.keys()
			keys.sort()
			for g in keys:
				dynasty_tree.add_child(_header("Generation %d" % (g + 1)))
				var flow = HFlowContainer.new()
				flow.add_theme_constant_override("h_separation", 6)
				dynasty_tree.add_child(flow)
				for c in generations[g]:
					flow.add_child(_person_cell(c, "%s, %d" % [c.name.get_slice(" ", 0), c.age]))
			for child in archive_box.get_children():
				child.queue_free()
			var past = city.graveyard.filter(func(c): return c.faction_id == me and c.is_leader)
			for c in past:
				var row = HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				row.add_child(_person_cell(c, "", Vector2(40, 46)))
				var text = _rich()
				text.text = "[b]%s[/b] of House %s\nLed %d days; %s at %d, %s" % [c.name, c.dynasty, c.death_day - c.ruling_since, c.fate, c.age, _date_of(c.death_day)]
				row.add_child(text)
				archive_box.add_child(row)
			if past.is_empty():
				var none = Label.new()
				none.text = "None yet: this is the first leader."
				none.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				archive_box.add_child(none)
		"government":
			_refresh_government()
		"territory":
			var lines = ["[b]%d districts[/b] [color=#999999](click to go there)[/color]" % city.districts_held(me)]
			for d in city.districts:
				if d.owner_id() == me:
					lines.append("[url=d:%d][b]%s[/b][/url]  control %d  ·  food %+.2f  ·  people %d  ·  defence %d%%  ·  grievance %d%s" % [
						d.id, d.district_name, d.share(me), city.district_food(d), d.population, city.defence_total(d) * 100, d.grievance,
						("  ·  " + ", ".join(d.building_labels())) if not d.buildings.is_empty() else ""])
			territory_info.text = "\n".join(lines)

# Your government, how it passes on and breaks, and the reforms you could take: what each needs,
# what it costs, and who on the council is for or against it
func _refresh_government():
	var me = city.player_id
	var p = _player()
	var gov = GameData.government(p.government)
	var lines = ["[font_size=17][b]%s[/b][/font_size]  [color=#999999]%s[/color]" % [gov["label"], gov["description"]],
		"[b]Succession:[/b] %s" % gov["succession"], "[b]While in power:[/b] %s" % gov["in_power"]]
	if p.caretaker_until > city.day:
		lines.append("[color=#ffb347]Caretaker government: ventures -10%% for %d more days.[/color]" % (p.caretaker_until - city.day))
	if p.reform_locked_until > city.day:
		lines.append("[color=#999999]No new reform for %d more days.[/color]" % (p.reform_locked_until - city.day))
	government_info.text = "\n".join(lines)
	var options = city.reform_options(me)
	var signature = "%s|%d|%d|%s" % [p.government, p.reform_locked_until, city.day / 5, ",".join(options.map(func(g): return g + ":" + city.check_reform(me, g)))]
	if signature == reform_signature:
		return
	reform_signature = signature
	for child in reform_box.get_children():
		child.queue_free()
	reform_box.add_child(_header("Reforms"))
	for gov_id in options:
		var target = GameData.government(gov_id)
		var reform: Dictionary = target["reform"]
		var err = city.check_reform(me, gov_id)
		var stance = city.council_stance(me, gov_id)
		var needs = city.reform_requirements(me, gov_id).map(func(option): return " + ".join(option.map(func(s): return ("[color=#8bd48b]✓ %s[/color]" if s[0] else "[color=#e3876f]✗ %s[/color]") % s[1])))
		var text = _rich()
		var council_line = "[color=#999999]The council has no strong feelings.[/color]"
		if not (stance["for"].is_empty() and stance["against"].is_empty()):
			council_line = "Council: [color=#8bd48b]for %s[/color]  ·  [color=#e3876f]against %s[/color]%s" % [
				", ".join(stance["for"].map(func(c): return c.name)) if not stance["for"].is_empty() else "nobody",
				", ".join(stance["against"].map(func(c): return c.name)) if not stance["against"].is_empty() else "nobody",
				"  [color=#ffb347](they vote: a majority against blocks it)[/color]" if GameData.government(p.government).get("votes", false) else "  [color=#999999](those against lose 10 loyalty if you go ahead)[/color]"]
		text.text = "[b]%s[/b] → %s\n[color=#b8a988]%s[/color]\nSuccession: %s\nWhile in power: %s\nNeeds: %s\n%s\n[color=#ffb347]Transition: grievance +10 in every district; no other reform for 2 years.[/color]" % [
			reform["label"], target["label"], reform["description"], target["succession"], target["in_power"],
			"  [color=#999999]or[/color]  ".join(needs), council_line]
		reform_box.add_child(text)
		var id = gov_id
		var b = _button("%s  ·  %s" % [reform["label"], _cost_text(city.reform_cost(me, gov_id))], func(): _on_reform(id))
		b.disabled = err != ""
		b.tooltip_text = err
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		reform_box.add_child(b)

func _on_reform(gov_id: String):
	var err = city.take_reform(city.player_id, gov_id)
	if err != "":
		_log(err, "bad")
	reform_signature = ""
	_refresh()

func _generation(c: Character, members: Array, guard: int) -> int:
	if guard > 12:
		return 0
	var best = -1
	for pid in c.parent_ids:
		for m in members:
			if m.id == pid:
				best = maxi(best, _generation(m, members, guard + 1))
	return best + 1


# --- Input --------------------------------------------------------------------------------

const WINDOW_KEYS = {KEY_F1: "character", KEY_F2: "council", KEY_F3: "realm", KEY_F4: "diplomacy", KEY_F5: "ambitions", KEY_F6: "economy", KEY_F7: "log"}

func _unhandled_input(event: InputEvent):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_SPACE:
		_set_paused(not paused)
	elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
		_set_speed(event.keycode - KEY_0)
	elif WINDOW_KEYS.has(event.keycode):
		_on_menu_button(WINDOW_KEYS[event.keycode])
	elif event.keycode == KEY_ESCAPE:
		# Esc closes whatever is in front; with nothing open, it opens the game menu
		if not task_pick.is_empty():
			_cancel_task_pick()
			_log("Task cancelled: no district picked.", "info")
		elif event_popup.visible:
			_close_event()
		elif game_menu.visible:
			_toggle_game_menu()
		elif open_window != "":
			_close_window()
		elif selected:
			_deselect()
		else:
			_toggle_game_menu()

# --- Refresh -------------------------------------------------------------------------------

func _refresh():
	var economy = city.daily_economy(city.player_id)
	_refresh_top_bar()
	_refresh_alerts(economy)
	_refresh_outliner()
	district_panel.visible = selected != null
	if selected:
		district_title.text = selected.district_name
		_refresh_district_info()
		_refresh_venture_buttons()
		_refresh_plan()
		_refresh_buildings()
		_refresh_building_info()
	_refresh_open_window()
	# The legend sits in the open stretch of map above the bottom bar; with a window open it would be squeezed, so it hides
	map_view.legend_margin = Vector3(6.0, BOTTOM_BAR_H + 6.0, RIGHT_W + 12.0)
	map_view.show_legend = open_window == ""
	map_view.selected = selected
	map_view.refresh()

func _on_district_clicked(district: District):
	# Picking a district for a councillor's task: open its planner with the task and councillor chosen, to confirm
	if not task_pick.is_empty():
		if not map_view.pick_labels.has(district.id):
			_log("Not there: pick one of the districts lit in gold, or press Esc.", "bad")
			return
		hovered_venture = task_pick["venture"]
		preferred_leader = task_pick["character"]
		_cancel_task_pick()
	selected = district
	_show_district()
	_refresh()

# Right-click: a faction's land opens their diplomacy page; your own land selects it
func _on_district_right_clicked(district: District, _screen_pos: Vector2):
	var fid = district.owner_id()
	if fid == "":
		var best = 0.0
		for other in city.factions:
			if other != city.player_id and district.share(other) > best:
				best = district.share(other)
				fid = other
	if fid == city.player_id:
		_on_district_clicked(district)
		return
	if fid != "":
		_open_faction_panel(fid, Vector2(-1, -1))

# A faction's page in the Diplomacy window
func _open_faction_panel(fid: String, _at: Vector2 = Vector2(-1, -1)):
	if fid == city.player_id or not city.factions.has(fid):
		return
	for child in panel_body.get_children():
		child.queue_free()
	panel_fid = fid
	panel_card = _make_card(fid)
	panel_body.add_child(panel_card["root"])
	windows["diplomacy"]["tabs"]["faction"]["button"].text = city.faction_name(fid)
	_open_window("diplomacy", "faction")
	_refresh_card(panel_card, fid)

func _close_faction_panel():
	panel_fid = ""
	panel_card = {}
	if windows.has("diplomacy"):
		windows["diplomacy"]["tabs"]["faction"]["button"].visible = false
		if open_window == "diplomacy" and windows["diplomacy"]["current"] == "faction":
			_show_tab("diplomacy", "factions")

# The Diplomacy window's list: one line per faction, with a button that opens the same
# panel you get by right-clicking their territory on the map
func _rebuild_faction_cards():
	for child in war_box.get_children():
		child.queue_free()
	war_rows.clear()
	for fid in city.factions:
		if fid == city.player_id:
			continue
		var row = HBoxContainer.new()
		war_box.add_child(row)
		var summary = _rich()
		row.add_child(summary)
		var open = _button("Open", func(): _open_faction_panel(fid, Vector2(-1, -1)))
		open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(open)
		war_rows[fid] = summary
	if panel_fid != "" and not city.factions.has(panel_fid):
		_close_faction_panel()
	_refresh()

# A diplomacy card for one faction: who they are, how they feel about you and why,
# and every diplomatic action you can take with them
# Wrapped text needs a known width before it can measure its height, so the card is fixed-width
const CARD_WIDTH = 410

func _make_card(fid: String) -> Dictionary:
	var card = VBoxContainer.new()
	card.custom_minimum_size.x = CARD_WIDTH
	card.add_theme_constant_override("separation", 4)
	var info = _rich()
	info.custom_minimum_size.x = CARD_WIDTH
	card.add_child(info)
	# Their council: who you'd be dealing with
	var council = HBoxContainer.new()
	council.add_theme_constant_override("separation", 6)
	card.add_child(council)
	var flow = HFlowContainer.new()
	flow.custom_minimum_size.x = CARD_WIDTH
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	card.add_child(flow)
	var actions = {}
	for action_id in GameData.diplomacy_actions():
		var b = _button("", func(): _on_diplomacy_pressed(action_id, fid))
		b.mouse_entered.connect(func(): hovered_diplomacy[fid] = action_id; _refresh_diplomacy())
		flow.add_child(b)
		actions[action_id] = b
	var breaks = {}
	for treaty in ["trade", "pact", "vassal"]:
		var b = _button("", func(): _on_break_pressed(treaty, fid))
		b.mouse_entered.connect(func(): hovered_diplomacy[fid] = "break_" + treaty; _refresh_diplomacy())
		flow.add_child(b)
		breaks[treaty] = b
	var war_button = _button("", func(): _on_war_button_pressed(fid))
	war_button.mouse_entered.connect(func(): hovered_diplomacy[fid] = "war"; _refresh_diplomacy())
	flow.add_child(war_button)
	# Why the greyed-out actions can't be taken, spelled out rather than hidden in tooltips
	var blocked = _rich()
	blocked.custom_minimum_size.x = CARD_WIDTH
	card.add_child(blocked)
	var detail = _rich()
	detail.custom_minimum_size.x = CARD_WIDTH
	card.add_child(detail)
	return {"root": card, "info": info, "actions": actions, "breaks": breaks, "war": war_button, "blocked": blocked, "detail": detail, "council": council, "council_signature": ""}

# --- Faction panel (right-click a faction's territory) ------------------------------

# Opens the diplomacy panel for a faction at a screen position (beside the side panel if none given)
# Keeps the panel fully on screen as its content grows and shrinks
# A scrollable tab page; returns the container to fill
func _button(text: String, on_pressed: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Space free for pausing
	b.pressed.connect(on_pressed)
	return b

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

func _rich() -> RichTextLabel:
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

func _header(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	return l

func _trait_row(t: Trait) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.tooltip_text = "%s\nEarned by: %s\nBenefit: %s\nCost: %s\nActive at %d, fades if you stop." % [t.description, t.source, t.benefit, t.cost, t.threshold]
	var name_label = Label.new()
	name_label.text = t.name
	name_label.custom_minimum_size.x = 100
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_label)
	var bar = ProgressBar.new()
	bar.max_value = t.threshold * 2
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size.y = 14
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.21, 0.24)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.35, 0.55, 0.85)
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	trait_fills[t.name] = bar_fill
	row.add_child(bar)
	var status = Label.new()
	status.custom_minimum_size.x = 70
	status.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(status)
	trait_widgets[t.name] = {"bar": bar, "status": status}
	return row

# --- UI refresh ---------------------------------------------------------------

func _player() -> Faction:
	return city.factions[city.player_id]

func _hex(faction_id: String) -> String:
	return "#" + city.factions[faction_id].color.lightened(0.2).to_html(false)

# Tab titles double as status badges, so you notice war or activity without opening the tab
# "At the start you don't have goals, you have problems": what's wrong right now, worst first
# What this district's control level means, so the reason to expand and secure is visible
func _refresh_diplomacy():
	_refresh_proposals()
	for fid in war_rows:
		if city.factions.has(fid):
			war_rows[fid].text = _faction_summary(fid)
	if panel_fid != "":
		if city.factions.has(panel_fid):
			_refresh_card(panel_card, panel_fid)
		else:
			_close_faction_panel()

# One line per faction for the Diplomacy window's list
func _faction_summary(fid: String) -> String:
	var r = city.relation(city.player_id, fid)
	var status = "[color=#ff7a66]AT WAR[/color]" if r.at_war else "at peace"
	return "[color=%s][b]%s[/b][/color]: %s, opinion of you %+d. %s\n[color=#999999]Treaties: %s[/color]" % [
		_hex(fid), city.faction_name(fid), status, r.opinion[fid], _stance_text(fid), _treaties_text(r)]

# How an AI faction regards you, coloured by danger, with its reason
const STANCE_COLORS = {"ENEMY": "#ff5a4a", "PREPARING WAR": "#ff5a4a", "TARGET": "#ff9a4a", "WARY": "#e0c060",
	"NEUTRAL": "#b0b0b0", "CORDIAL": "#9ad08a", "FRIENDLY": "#7ad07a", "WANTS ALLIANCE": "#7ac0e0"}

func _stance_text(fid: String) -> String:
	var f: Faction = city.factions[fid]
	if f.ai == null:
		return ""
	var stance = f.ai.stance_toward(city, city.player_id)
	return "Stance toward you: [color=%s][b]%s[/b][/color] [color=#999999](%s)[/color]" % [STANCE_COLORS.get(stance[0], "#b0b0b0"), stance[0], stance[1]]

# Treaties with their remaining time, so it's always clear when something runs out
func _treaties_text(r: Relation) -> String:
	var parts = []
	if r.trade:
		parts.append("Trade agreement")
	if r.alliance or r.pact:
		var days_left = r.treaty_until_day - city.day
		var renew = " [color=#ffb347]renew now[/color]" if Diplomacy.in_renewal_window(city, r) else ""
		parts.append("%s (%d days left%s)" % ["Defensive alliance" if r.alliance else "Non-aggression pact", days_left, renew])
	if r.overlord != "":
		parts.append("Your vassal" if r.overlord == city.player_id else "Your overlord")
	return ", ".join(parts) if parts.size() > 0 else "none"

func _refresh_card(row: Dictionary, fid: String):
	var me = city.player_id
	var f: Faction = city.factions[fid]
	var r = city.relation(me, fid)
	var active = f.traits.get_active_traits()
	_refresh_card_council(row, fid)

	var text = "[color=%s][font_size=16][b]%s[/b][/font_size][/color]  %s\n" % [_hex(fid), f.display_name,
		", ".join(active) if active.size() > 0 else "no traits yet"]
	if f.minor:
		text += "[color=#b8a988]Minor faction, %s. %s[/color]\n" % [city.faction_manner(fid), f.blurb]
	text += "Districts %d, strength %d (yours %d), wealth %d, renown %d\n" % [city.districts_held(fid), city.faction_strength(fid),
		city.faction_strength(me), f.wealth, f.renown]
	var their_leader = city.leader_of(fid)
	if their_leader:
		text += "Led by [b]%s[/b], %d [color=#999999](%d%% chance of dying this year)[/color]\n%s\n" % [their_leader.name, their_leader.age,
			city.yearly_death_chance(their_leader) * 100, _succession_text(fid, false)]
	text += _stance_text(fid) + "\n"
	if r.at_war:
		text += "[color=#ff7a66][b]AT WAR[/b][/color] for %d days. Exhaustion: you %d, them %d.%s\n" % [
			city.day - r.war_start_day, r.exhaustion[me], r.exhaustion[fid],
			" [color=#8bd48b]They offer peace.[/color]" if r.peace_offered_by == fid else ""]
	elif city.day < r.truce_until_day:
		text += "At peace (truce for %d more days)\n" % (r.truce_until_day - city.day)
	else:
		text += "At peace\n"
	text += "Treaties: %s\n" % _treaties_text(r)
	# Where its effort has gone lately: a faction growing wide leaves its home land thin, one building up gets harder to hit
	var lean: Dictionary = city.factions[fid].lean
	if lean["home"] + lean["abroad"] >= 3.0:
		var home_share = lean["home"] / (lean["home"] + lean["abroad"])
		text += "Lately: %s\n" % ("building up at home (%d%% of its moves)" % (home_share * 100) if home_share >= 0.55 else
			("expanding and reaching out (%d%% of its moves abroad)" % ((1.0 - home_share) * 100) if home_share <= 0.45 else "balanced between home and abroad"))
	# Where they're heading: the ambition under way and the ones achieved (pillar 3: the AI's choices are visible)
	var them: Faction = city.factions[fid]
	var their_gov = GameData.government(them.government)
	text += "Government: [b][hint=\"%s\n\n%s\"]%s[/hint][/b]\n" % [their_gov["succession"], their_gov["in_power"], their_gov["label"]]
	if them.ambition != "":
		text += "Pursuing: [b]%s[/b] (%d days left)\n" % [GameData.national_ambition(them.ambition)["label"], them.ambition_days_left]
	if not them.ambitions_done.is_empty():
		text += "Achieved: %s\n" % ", ".join(them.ambitions_done.map(func(a): return GameData.national_ambition(a)["label"]))
	# Raiding between you: promises and grudges with a clock on them
	if r.spare_until[fid] > city.day:
		text += "[color=#8bd48b]No raids from them for %d more days[/color]\n" % (r.spare_until[fid] - city.day)
	if r.bold_until[fid] > city.day:
		text += "[color=#e3876f]Emboldened: their raids on you get +%d%% odds for %d more days[/color]\n" % [roundi((GameData.rule("emboldened_odds") - 1.0) * 100), r.bold_until[fid] - city.day]
	if r.spare_until[me] > city.day:
		text += "You promised them no raids for %d more days\n" % (r.spare_until[me] - city.day)
	text += "Their opinion of you: [b]%+d[/b]\n" % r.opinion[fid]
	var reasons = []
	for part in Diplomacy.opinion_baseline(city, fid, me):
		# Reasons are written from their side ("their ways"); on your screen, "their" means you
		reasons.append("%+d %s" % [part[1], part[0].replace("their", "your")])
	if reasons.size() > 0:
		text += "[color=#999999]Lasting: %s[/color]\n" % ", ".join(reasons)
	var memories = []
	for m in r.modifiers[fid]:
		memories.append("%+d %s" % [m["value"], GameData.opinion_modifier(m["id"])["label"]])
	if memories.size() > 0:
		text += "[color=#999999]Fading memories: %s[/color]" % ", ".join(memories)
	row["info"].text = text

	var blocked = []
	for action_id in row["actions"]:
		var def = GameData.diplomacy_action(action_id)
		var b: Button = row["actions"][action_id]
		var err = Diplomacy.check_action(city, action_id, me, fid)
		var label: String = def["label"]
		if (action_id == "pact" and r.pact) or (action_id == "alliance" and r.alliance):
			label = label.replace("Propose", "Renew")
		if def["kind"] in ["gift", "tribute"]:
			label += " (%s)" % _cost_text(Diplomacy.action_cost(city, action_id, city.player_id, fid))
		elif err == "":
			label += " %d%%" % (Diplomacy.acceptance(city, action_id, me, fid)["chance"] * 100)
		b.text = label
		b.disabled = err != ""
		b.tooltip_text = err
		# Hide actions that can't apply to this relationship at all, to keep the card short
		var applies = not (action_id == "integrate" and r.overlord != me)
		if action_id == "tribute":
			applies = r.menaced_recently(fid, city.day, int(GameData.rule("menace_memory_days")))
		elif action_id == "demand":
			applies = city.shares_border(me, fid)
		b.visible = applies
		if err != "" and applies:
			blocked.append("[color=#bbbbbb]%s:[/color] %s" % [def["label"], err])
	row["breaks"]["trade"].text = "End trade agreement"
	row["breaks"]["trade"].visible = r.trade
	row["breaks"]["pact"].text = "Break alliance" if r.alliance else "Break pact"
	row["breaks"]["pact"].visible = (r.pact or r.alliance) and r.overlord == ""
	row["breaks"]["vassal"].text = "Release vassal" if r.overlord == me else "Declare independence"
	row["breaks"]["vassal"].visible = r.overlord != ""
	var war_button: Button = row["war"]
	var err = ""
	if r.at_war:
		war_button.text = "Accept their peace offer" if r.peace_offered_by == fid else "Offer peace"
		err = city.check_peace(me, fid)
	else:
		war_button.text = "Declare war (%d wealth)" % GameData.rule("war_cost").get("wealth", 0)
		err = city.check_declare_war(me, fid)
	war_button.disabled = err != ""
	war_button.tooltip_text = err
	if err != "":
		blocked.append("[color=#bbbbbb]%s:[/color] %s" % ["Peace" if r.at_war else "War", err])
	row["blocked"].text = ("[font_size=13][color=#e3a86f]Not available now[/color]\n[color=#999999]%s[/color][/font_size]" % "\n".join(blocked)) if blocked.size() > 0 else ""
	row["detail"].text = _diplomacy_detail(fid, hovered_diplomacy.get(fid, ""))

# Explains the action under the mouse: what it does, and why the odds are what they are
func _diplomacy_detail(fid: String, action_id: String) -> String:
	var me = city.player_id
	match action_id:
		"":
			return "[color=#999999]Hover an action to see what it does and its odds.[/color]"
		"break_trade":
			return "Ends the trade agreement. They take it badly (opinion -10)."
		"break_pact":
			return "Breaks the treaty so you can attack them. They'll hate you for it (opinion -30, -40 for an alliance), and every other faction trusts you less (-10)."
		"break_vassal":
			if city.relation(me, fid).overlord == me:
				return "Frees them. They'll be grateful (opinion +20), but you lose their tribute."
			return "Stop paying tribute. Your overlord will declare war on you."
		"war":
			return "War unlocks Assault on their border districts. Their allies, overlord and vassals join in. Treaties between you end."
	var def = GameData.diplomacy_action(action_id)
	var text = "[b]%s[/b]: %s\nEnvoy travels %d days. Costs %s." % [def["label"], def["description"], def["days"],
		_cost_text(Diplomacy.action_cost(city, action_id, city.player_id, fid))]
	var err = Diplomacy.check_action(city, action_id, me, fid)
	if err != "":
		return text + "\n[color=#ffb347]%s[/color]" % err
	if def["kind"] not in ["gift", "tribute"]:
		var result = Diplomacy.acceptance(city, action_id, me, fid)
		text += "\nBase %d%%" % (result["base"] * 100)
		for factor in result["factors"]:
			var color = "#8bd48b" if factor[1] >= 1.0 else "#e3876f"
			text += "  [color=%s]x%.2f %s[/color]" % [color, factor[1], factor[0]]
		text += "  = [b]%d%%[/b] chance they agree" % (result["chance"] * 100)
	return text

# Proposals from AI factions, each with Accept / Decline; rebuilt only when the list changes
func _refresh_proposals():
	var signature = str(city.proposals)
	if signature == proposals_signature:
		return
	proposals_signature = signature
	for child in proposals_box.get_children():
		child.queue_free()
	if city.proposals.is_empty():
		return
	proposals_box.add_child(_header("Proposals awaiting your answer"))
	for i in city.proposals.size():
		var p = city.proposals[i]
		var def = GameData.diplomacy_action(p["action"])
		var label = _rich()
		label.text = "[color=%s]%s[/color] propose %s. [color=#999999]%s Expires in %d days.[/color]" % [
			_hex(p["from"]), city.faction_name(p["from"]), def.get("proposal", p["action"]), def["description"], p["expires_day"] - city.day]
		proposals_box.add_child(label)
		var buttons = HBoxContainer.new()
		buttons.add_child(_button("Accept", func(): city.answer_proposal(i, true); _refresh()))
		buttons.add_child(_button("Decline", func(): city.answer_proposal(i, false); _refresh()))
		proposals_box.add_child(buttons)

func _on_diplomacy_pressed(action_id: String, faction_id: String):
	var err = Diplomacy.start_action(city, action_id, city.player_id, faction_id)
	if err != "":
		_log(err, "bad")
	_refresh()

func _on_break_pressed(treaty: String, faction_id: String):
	var err = Diplomacy.break_treaty(city, city.player_id, faction_id, treaty)
	if err != "":
		_log(err, "bad")
	_refresh()

func _on_war_button_pressed(faction_id: String):
	var err = ""
	if city.is_at_war(city.player_id, faction_id):
		err = city.make_peace(city.player_id, faction_id)
	else:
		err = city.declare_war(city.player_id, faction_id)
	if err != "":
		_log(err, "bad")
	_refresh()

# --- Venture planner ----------------------------------------------------------------

# Who leads, how many go and how well it's funded, with the chance of each outcome shown
# before anything is committed
func _row_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.custom_minimum_size.x = 64
	return l

func _selected_leader_id() -> int:
	if leader_select.item_count == 0 or leader_select.selected < 0:
		return -2
	# "No captain is free" (NO_PICK): ask for any free leader, which explains who is away
	var id = leader_select.get_item_id(leader_select.selected)
	return -2 if id < 0 else id

# Why a venture can't be started here ("" if it can): a standing task on your own land, a one-off elsewhere
func _venture_error(venture_id: String, leader_id: int = -2, crew: int = -1, funding: int = 0) -> String:
	if city.is_task(city.player_id, venture_id, selected):
		return city.check_task(city.player_id, venture_id, selected, leader_id, crew)
	return city.check_launch(city.player_id, venture_id, selected, leader_id, crew, funding)

func _on_launch_pressed():
	if not selected:
		return
	var t = city.task_at(city.player_id, hovered_venture, selected)
	var err = ""
	if t:
		city.stop_task(t)
	elif city.is_task(city.player_id, hovered_venture, selected):
		err = city.assign_task(city.player_id, hovered_venture, selected, _selected_leader_id(), int(crew_slider.value))
	else:
		err = city.launch_venture(city.player_id, hovered_venture, selected, _selected_leader_id(), int(crew_slider.value), funding_select.selected)
	if err != "":
		_log(err, "bad")
	_refresh()

# --- Council window ----------------------------------------------------------------------

# Four seats you fill from your crew, then a card per character. Widgets are kept and updated
# in place (not rebuilt daily), so an open dropdown or a hovered button survives the clock ticking.
func _make_crew_card(character_id: int) -> Dictionary:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16)
	style.border_color = Color(0.25, 0.27, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(64, 74)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	row.add_child(box)
	var info = _rich()
	box.add_child(info)
	var loyalty_row = HBoxContainer.new()
	box.add_child(loyalty_row)
	var loyalty_label = Label.new()
	loyalty_label.custom_minimum_size.x = 86
	loyalty_label.add_theme_font_size_override("font_size", 13)
	loyalty_row.add_child(loyalty_label)
	var bar = ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.21, 0.24)
	var bar_fill = StyleBoxFlat.new()
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	loyalty_row.add_child(bar)
	var reasons = _rich()
	box.add_child(reasons)
	var buttons = HBoxContainer.new()
	box.add_child(buttons)
	var lead = _button("Lead a venture", func(): _lead_with(character_id))
	lead.add_theme_font_size_override("font_size", 13)
	buttons.add_child(lead)
	var dismiss = _button("Dismiss", func(): _on_dismiss_pressed(character_id))
	dismiss.add_theme_font_size_override("font_size", 13)
	buttons.add_child(dismiss)
	return {"root": panel, "portrait": portrait, "info": info, "loyalty": loyalty_label, "bar": bar, "fill": bar_fill,
		"reasons": reasons, "lead": lead, "dismiss": dismiss}

func _refresh_departed():
	var lines = []
	for entry in city.departed:
		if entry["faction"] != city.player_id:
			continue
		var seat = (", %s" % GameData.council_post(entry["post"])["label"]) if entry["post"] != "" else ""
		if entry.get("role", "") == "Leader":
			seat = ", [color=#d9b35a]Leader for %d days[/color]" % entry.get("ruled_days", 0)
		elif entry.get("role", "") == "Family":
			seat += ", family"
		lines.push_front("[b]%s[/b]%s: [color=#e3876f]%s[/color], %s [color=#999999](%d ventures, %d triumphs)[/color]" % [
			entry["name"], seat, entry["fate"], _date_of(entry["day"]), entry["ventures"], entry["triumphs"]])
	departed_info.text = "\n".join(lines) if lines.size() > 0 else "[color=#777777]Nobody yet.[/color]"

func _date_of(day: int) -> String:
	return "Year %d, Month %d" % [day / 360 + 1, (day / 30) % 12 + 1]

func _fill_crew_card(w: Dictionary, c: Character):
	var wounded = c.is_wounded(city.day)
	w["portrait"].setup(c, _player().color, wounded)
	var status = "[color=#8bd48b]Ready[/color]"
	var busy = false
	if wounded:
		status = "[color=#e3876f]Wounded, %d days[/color]" % (c.wounded_until - city.day)
	for v in city.ventures:
		if v.leader_id == c.id:
			busy = true
			status = "[color=#6fa0ff]%s in %s, back in %d days[/color]" % [GameData.venture(v.venture_id)["label"], v.district.district_name, v.days_left]
	var title = "[b]%s[/b], %d%s" % [c.name, c.age, "  [color=#c9a0e0]family[/color]" if c.family else ""]
	if c.post != "":
		title += "  [color=#d9b35a]%s[/color]" % GameData.council_post(c.post)["label"]
	var skills = []
	for s in Character.SKILLS:
		var text = "%s %d" % [s.substr(0, 3).capitalize(), c.skills[s]]
		skills.append("[b]%s[/b]" % text if s == c.best_skill() else text)
	var traits = []
	for t in c.traits:
		var def = GameData.character_trait(t)
		traits.append("[hint=\"%s\"][color=#c9a0e0]%s[/color][/hint]" % [def["description"], def["label"]])
	w["info"].text = "%s\n%s\n%s%s\n[color=#999999]%d ventures led, %d triumphs, %d wounds[/color]" % [
		title, "  ".join(skills), status, ("  ·  " + ", ".join(traits)) if traits.size() > 0 else "", c.ventures_led, c.triumphs, c.wounds]
	var loyalty = c.loyalty()
	w["loyalty"].text = "Loyalty %d" % loyalty
	w["bar"].value = loyalty
	w["fill"].bg_color = Color(0.45, 0.75, 0.45) if loyalty >= 60 else (Color(0.85, 0.7, 0.35) if loyalty >= GameData.rule("loyalty_restless") else Color(0.85, 0.35, 0.3))
	var reasons = []
	for part in c.loyalty_breakdown():
		if part[0] != "Base":
			reasons.append("[color=%s]%+d %s[/color]" % ["#8bd48b" if part[1] > 0 else "#e3876f", part[1], part[0]])
	w["reasons"].visible = false
	w["loyalty"].tooltip_text = _loyalty_tip(c)
	w["loyalty"].mouse_filter = Control.MOUSE_FILTER_PASS
	w["bar"].tooltip_text = _loyalty_tip(c)
	var lead: Button = w["lead"]
	lead.disabled = busy or wounded or selected == null
	lead.tooltip_text = "Out on a venture" if busy else ("Recovering from wounds" if wounded else ("Select a district on the map first" if selected == null else "Plan a venture in %s with %s leading" % [selected.district_name, c.name]))
	var dismiss: Button = w["dismiss"]
	dismiss.disabled = busy
	dismiss.text = "Click again to dismiss" if pending_dismiss == c.id else "Dismiss"

# The tasks a seat holder could take, each greyed with its reason when there's nowhere (or nobody free) to do it
func _fill_task_menu(menu: MenuButton, post: String):
	var popup = menu.get_popup()
	popup.clear()
	var p = _player()
	var holder = city.council_member(p.id, post)
	var k = 0
	for venture_id in GameData.ventures():
		var def = GameData.venture(venture_id)
		if not def.get("task", false):
			continue
		popup.add_item("%s  (%s %d)" % [def["label"], def["skill"].substr(0, 3).capitalize(), holder.skills[def["skill"]] if holder else 0], k)
		var reason = ""
		if holder == null:
			reason = "Nobody holds this seat"
		elif city.leader_busy(holder) or holder.is_wounded(city.day):
			reason = "%s isn't free: %s" % [holder.name, city.unavailable_reason(holder)]
		elif _task_targets(venture_id, holder.id).is_empty():
			reason = "Nowhere to do it: " + _no_task_reason(venture_id)
		popup.set_item_disabled(k, reason != "")
		popup.set_item_tooltip(k, reason if reason != "" else "Pick the district on the map. Runs until %s." % city.task_goal(def))
		popup.set_item_metadata(k, venture_id)
		k += 1

# Your districts where this councillor could take this task now: district id -> the stat to show on the map
func _task_targets(venture_id: String, character_id: int) -> Dictionary:
	var found = {}
	for d in city.districts:
		if d.owner_id() == city.player_id and city.check_task(city.player_id, venture_id, d, character_id) == "":
			found[d.id] = city.task_stat_text(city.player_id, venture_id, d)
	return found

# Why a task has nowhere to run, from the first district of yours that refuses it
func _no_task_reason(venture_id: String) -> String:
	for d in city.districts:
		if d.owner_id() == city.player_id:
			var done = city.task_done_reason(city.player_id, venture_id, d)
			if done != "":
				return "in %s %s" % [d.district_name, done]
	return "no district of yours needs it"

func _cancel_task_pick():
	task_pick = {}
	map_view.pick_labels = {}
	map_view.refresh()

func _on_task_chosen(post: String, index: int):
	var holder = city.council_member(city.player_id, post)
	var menu: MenuButton = seat_rows[post]["task"]
	var venture_id: String = menu.get_popup().get_item_metadata(menu.get_popup().get_item_index(index))
	if holder == null:
		return
	var targets = _task_targets(venture_id, holder.id)
	if targets.is_empty():
		_log("Nowhere to do that: " + _no_task_reason(venture_id), "bad")
		return
	task_pick = {"venture": venture_id, "character": holder.id}
	map_view.pick_labels = targets
	map_view.refresh()
	_log("Pick a district for %s to take on %s (lit in gold). Esc cancels." % [holder.name, GameData.venture(venture_id)["label"]], "info")

func _on_seat_picked(post: String, character_id: int):
	if character_id == NO_PICK:
		return
	var holder = city.council_member(city.player_id, post)
	var err = ""
	if character_id == -2:
		err = city.remove_from_council(holder.id) if holder else ""
	else:
		err = city.appoint(character_id, post)
	if err != "":
		_log(err, "bad")
	seat_rows[post]["signature"] = ""
	_refresh()

# Opens the planner in the selected district with this character leading, on a venture that suits them
func _lead_with(character_id: int):
	var c = city.character_by_id(character_id)
	if c == null or selected == null:
		return
	var current_skill: String = GameData.venture(hovered_venture)["skill"]
	if current_skill != c.best_skill() or city.check_launch(city.player_id, hovered_venture, selected) != "":
		for venture_id in GameData.ventures():
			if GameData.venture(venture_id)["skill"] == c.best_skill() and city.check_launch(city.player_id, venture_id, selected) == "":
				hovered_venture = venture_id
				break
	preferred_leader = character_id
	_show_district("district")
	_refresh()
	_on_venture_pressed(hovered_venture)

func _on_dismiss_pressed(character_id: int):
	if pending_dismiss != character_id:
		pending_dismiss = character_id
		_refresh_captains()
		return
	pending_dismiss = -1
	var err = city.dismiss_character(character_id)
	if err != "":
		_log(err, "bad")
	_refresh()

func _refresh_traits():
	var engine: TraitEngine = _player().traits
	for trait_name in trait_widgets:
		var t: Trait = engine.faction_traits[trait_name]
		var w = trait_widgets[trait_name]
		w["bar"].value = t.value
		w["status"].text = "ACTIVE" if t.active else "%d / %d" % [t.value, t.threshold]
		w["status"].add_theme_color_override("font_color", Color(0.55, 0.85, 0.55) if t.active else Color(0.7, 0.7, 0.7))
		trait_fills[trait_name].bg_color = Color(0.4, 0.75, 0.45) if t.active else Color(0.35, 0.55, 0.85)

func _signed(value: float) -> String:
	return "%+.1f" % value

# The selected district's buildings, free slots, and a build button per building type
const RESOURCE_NAMES = {"supplies": "food", "manpower": "manpower", "materials": "materials", "arms": "arms", "wealth": "wealth"}

func _cost_text(costs: Dictionary) -> String:
	var parts = []
	for resource_type in costs:
		var amount: float = costs[resource_type]
		parts.append("%s %s" % [str(int(amount)) if is_equal_approx(amount, roundf(amount)) else str(snappedf(amount, 0.01)), RESOURCE_NAMES.get(resource_type, resource_type)])
	return ", ".join(parts) if parts.size() > 0 else "free"

# Where resources come from and go, so you can see what buildings cost you
func _refresh_economy():
	var p = _player()
	var e = city.daily_economy(p.id)
	var text = "[b]Daily economy[/b]\n"
	for resource_type in ["supplies", "wealth"]:
		var income: float = e[resource_type]["income"]
		var upkeep: float = e[resource_type]["upkeep"]
		text += "%s: +%.1f income, -%.1f upkeep = [b]%s[/b]/day\n" % [resource_type.capitalize(), income, upkeep, _signed(income - upkeep)]
	text += "[color=#999999]Income includes trade %s wealth" % _signed(e["trade"])
	if e["tribute"]["wealth"] != 0.0 or e["tribute"]["supplies"] != 0.0:
		text += " and tribute %s wealth, %s supplies" % [_signed(e["tribute"]["wealth"]), _signed(e["tribute"]["supplies"])]
	text += ". Upkeep: crew food; buildings; administration %.1f wealth (grows faster than your territory); council wages %.1f. Food over 40 spoils; wealth over 300 and materials over 200 leak to theft and graft (1%% a day).[/color]\n" % [
		city.admin_upkeep(p.id), city.council_size(p.id) * city.council_wage(p.id)]
	text += "Crew: %d idle, %d away, limit %d [color=#999999](5 per district + Hostels)[/color]\n" % [
		p.manpower, city.crew_away(p.id), city.crew_cap(p.id)]
	# What your buildings give you, type by type
	var counts = {}
	for d in city.districts:
		if d.owner_id() == p.id:
			for building_id in d.buildings:
				counts[building_id] = counts.get(building_id, 0) + 1
	if counts.is_empty():
		text += "Buildings: none yet. Select a district you control and press Build."
	else:
		text += "[b]Your buildings[/b]"
		for building_id in counts:
			var def = GameData.building(building_id)
			text += "
%s x%d: [color=#8bd48b]%s[/color] each" % [def["label"], counts[building_id], def["summary"]]
	text += "
Renown %d adds %d to your crew limit and improves your treaty odds." % [p.renown, int(p.renown / GameData.rule("renown_per_crew"))]
	if p.broke:
		text += "\n[color=#e3876f]Out of wealth: buildings have stopped working until upkeep is paid.[/color]"
	economy_info.text = text

# The closest unfinished ambitions, so there's always a next goal in view
func _refresh_ambitions():
	var p = _player()
	var open = []
	for id in GameData.deeds():
		if id not in p.deeds_done:
			var progress = city.deed_progress(p.id, id)
			open.append([id, float(progress[0]) / maxf(1.0, progress[1]), progress])
	open.sort_custom(func(a, b): return a[1] > b[1])
	ambitions_info.text = "Renown [b]%d[/b] to spend  ·  reputation %d  ·  %d of %d deeds done" % [
		p.renown, p.reputation, p.deeds_done.size(), GameData.deeds().size()]
	for k in ambition_rows.size():
		var row = ambition_rows[k]
		if k >= open.size():
			row["label"].text = ""
			row["bar"].visible = false
			continue
		var amb = GameData.deeds()[open[k][0]]
		var progress = open[k][2]
		row["label"].text = "[b]%s[/b] [color=#999999](%s)[/color] %s [color=#d9b35a]+%d renown[/color]  %d/%d" % [
			amb["label"], amb["category"], amb["description"], amb["renown"], mini(progress[0], progress[1]), progress[1]]
		row["bar"].visible = true
		row["bar"].max_value = progress[1]
		row["bar"].value = progress[0]

# One National Ambition: what it gives, what it takes, what you need, and the button to start it
func _make_ambition_card(id: String) -> Dictionary:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16)
	style.border_color = Color(0.25, 0.27, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var info = _rich()
	box.add_child(info)
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.21, 0.24)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.85, 0.7, 0.35)
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	box.add_child(bar)
	var start = _button("Start", func(): _on_start_ambition(id))
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(start)
	return {"root": panel, "style": style, "info": info, "bar": bar, "button": start}

func _on_start_ambition(id: String):
	var err = city.start_ambition(city.player_id, id)
	if err != "":
		_log(err, "bad")
	_refresh()

# Each card shows its state: under way (with a bar), done, closed, ready to start, or what's still missing
func _refresh_ambition_cards():
	var p = _player()
	if p.ambition != "":
		var active = GameData.national_ambition(p.ambition)
		ambition_intro.text = "Pursuing [b]%s[/b]: %d days left.  [color=#999999]Renown %d to spend.[/color]" % [active["label"], p.ambition_days_left, p.renown]
	else:
		ambition_intro.text = "[color=#d9b35a]No ambition under way.[/color] Renown [b]%d[/b] to spend. [color=#999999]Earn more from deeds and triumphs.[/color]" % p.renown
	for id in ambition_cards:
		var def = GameData.national_ambition(id)
		var w = ambition_cards[id]
		var status = ""
		var border = Color(0.25, 0.27, 0.3)
		w["bar"].visible = p.ambition == id
		w["button"].visible = false
		if id in p.ambitions_done:
			status = "[color=#8bd48b]Achieved[/color]"
			border = Color(0.35, 0.55, 0.35)
		elif p.ambition == id:
			status = "[color=#d9b35a]Under way: %d days left[/color]" % p.ambition_days_left
			border = Color(0.85, 0.7, 0.35)
			var total = city.ambition_days(p.id, id)
			w["bar"].max_value = total
			w["bar"].value = total - p.ambition_days_left
		elif id in p.ambitions_closed:
			status = "[color=#777777]Closed for good[/color]"
		else:
			var err = city.check_ambition(p.id, id)
			w["button"].visible = true
			w["button"].disabled = err != ""
			w["button"].tooltip_text = err
			w["button"].text = "Start  ·  %s  ·  %d days" % [_cost_text(def["cost"]), city.ambition_days(p.id, id)]
			status = "[color=#8bd48b]You can start this[/color]" if err == "" else ("[color=#999999]Not yet[/color]" if city.ambition_qualifies(p.id, id) else "[color=#999999]You don't qualify yet[/color]")
		w["style"].border_color = border
		var lines = ["[b]%s[/b]  %s" % [def["label"], status], "[color=#b8a988]%s[/color]" % def["description"],
			"[color=#8bd48b]For good:[/color] %s" % def["bonus_text"]]
		if def.get("while", "") == "no_raids":
			lines.append("[color=#e3876f]While it runs: no raids, or it fails and the renown is lost[/color]")
		if not def.get("closes", []).is_empty():
			lines.append("[color=#e3876f]Closes for good: %s[/color]" % ", ".join(def["closes"].map(func(o): return GameData.national_ambition(o)["label"])))
		if id not in p.ambitions_done and p.ambition != id:
			# Requirements, ticked: any one full line qualifies
			var options = city.ambition_options(p.id, id)
			var texts = options.map(func(option): return " + ".join(option.map(func(s): return ("[color=#8bd48b]✓ %s[/color]" if s[0] else "[color=#e3876f]✗ %s[/color]") % s[1])))
			lines.append("Needs: " + "  [color=#999999]or[/color]  ".join(texts))
		w["info"].text = "\n".join(lines)

# Every treaty you hold, with the time left on each
func _refresh_treaties():
	var lines = []
	for fid in city.factions:
		if fid != city.player_id:
			var r = city.relation(city.player_id, fid)
			var text = _treaties_text(r)
			if text != "none":
				lines.append("[color=%s]%s[/color]: %s" % [_hex(fid), city.faction_name(fid), text])
	treaties_info.text = "
".join(lines) if lines.size() > 0 else "[color=#999999]None yet. Right-click a faction's territory to propose one.[/color]"

func _on_build_pressed(building_id: String):
	if not selected:
		return
	var err = city.start_construction(city.player_id, building_id, selected)
	if err != "":
		_log(err, "bad")
	_refresh()

# --- Events -------------------------------------------------------------------

const LOG_LIMIT = 400

func _log(message: String, kind: String):
	var entry = {"day": (city.day + 1) if city else 0, "text": message, "kind": kind, "scope": _log_scope(message, kind)}
	log_entries.append(entry)
	if log_entries.size() > LOG_LIMIT:
		log_entries.pop_front()
	if _passes_filter(entry):
		log_view.append_text(_log_line(entry))
	_refresh_ticker()

# "mine": about you (your results, attacks on you, warnings); "neighbours": factions on your border; else "all"
func _log_scope(text: String, kind: String) -> String:
	if city == null or kind != "info":
		return "mine"
	var p = city.factions.get(city.player_id)
	if p and text.contains(p.display_name):
		return "mine"
	for fid in city.factions:
		if fid != city.player_id and city.shares_border(city.player_id, fid) and text.contains(city.faction_name(fid)):
			return "neighbours"
	return "all"

func _passes_filter(entry: Dictionary) -> bool:
	match log_filter:
		"mine":
			return entry["scope"] == "mine"
		"neighbours":
			return entry["scope"] != "all"
	return true

func _log_line(entry: Dictionary) -> String:
	var stamp = "Day %d" % entry["day"] if entry["day"] > 0 else "Start"
	return "[color=#777777]%s[/color]  [color=%s]%s[/color]\n" % [stamp, LOG_COLORS[entry["kind"]], entry["text"]]

func _set_log_filter(key: String):
	log_filter = key
	for k in log_filter_buttons:
		log_filter_buttons[k].set_pressed_no_signal(k == key)
	log_view.clear()
	for entry in log_entries:
		if _passes_filter(entry):
			log_view.append_text(_log_line(entry))

func _refresh_ticker():
	var lines = []
	for i in range(log_entries.size() - 1, -1, -1):
		if log_entries[i]["scope"] == "mine":
			lines.push_front(_log_line(log_entries[i]).strip_edges())
			if lines.size() == 2:
				break
	ticker.text = "\n".join(lines)

func _on_city_event(text: String, kind: String):
	_log(text, kind)
	if kind == "alert":
		if pause_on_alert.button_pressed and not paused:
			_set_paused(true)


# Choosing a venture opens it in the planner below the list
func _on_venture_pressed(venture_id: String):
	hovered_venture = venture_id
	_refresh_plan()
	# Bring the planner into view
	var scroll = plan_box.get_parent().get_parent() as ScrollContainer
	if scroll:
		scroll.ensure_control_visible.call_deferred(launch_button)

# A faction's council on its diplomacy card: portraits with the seat, skill and loyalty
func _refresh_card_council(row: Dictionary, fid: String):
	var members = []
	if city.leader_of(fid):
		members.append(city.leader_of(fid))
	for post in GameData.council()["posts"]:
		var c = city.council_member(fid, post)
		if c:
			members.append(c)
	var signature = ",".join(members.map(func(c): return "%d:%s:%s" % [c.id, c.post, c.traits.size()]))
	if signature == row["council_signature"]:
		return
	row["council_signature"] = signature
	var box: HBoxContainer = row["council"]
	for child in box.get_children():
		child.queue_free()
	for c in members:
		var post = {"label": "Leader", "skill": c.best_skill()} if c.is_leader else GameData.council_post(c.post)
		var cell = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var portrait = Portrait.new()
		portrait.custom_minimum_size = Vector2(46, 52)
		portrait.setup(c, city.factions[fid].color, c.is_wounded(city.day))
		var traits = c.traits.map(func(t): return GameData.character_trait(t)["label"])
		portrait.tooltip_text = "%s, %s\n%s %d · loyalty %d%s" % [c.name, post["label"], post["skill"].capitalize(), c.skills[post["skill"]], c.loyalty(),
			("\n" + ", ".join(traits)) if traits.size() > 0 else ""]
		cell.add_child(portrait)
		var label = Label.new()
		label.text = post["label"]
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		label.custom_minimum_size.x = 46
		label.clip_text = true
		cell.add_child(label)
		box.add_child(cell)
	if members.is_empty():
		var none = Label.new()
		none.text = "No council seated"
		box.add_child(none)

# What one successful Rebuild would change in this district, worked out from the real formulas
func _rebuild_payoff(d: District) -> String:
	var step: float = 0.0
	for e in GameData.venture("rebuild")["success_effects"]:
		if e["op"] == "development":
			step = e["amount"]
	var before = city.district_income(d)
	var housing_before = city.housing(d)
	var dev = d.development
	d.development = minf(dev + step, 1.0)
	var after = city.district_income(d)
	var housing_after = city.housing(d)
	d.development = dev
	return "If it succeeds: food %+.2f/day, manpower %+.3f/day, wealth %+.2f/day now, and room for %+d more people (who pay more tax as they arrive)." % [
		after["supplies"] - before["supplies"], after["recruits"] - before["recruits"], after["wealth"] - before["wealth"], housing_after - housing_before]

# --- Leader, family and succession ------------------------------------------------------

# "If X died today: Y takes over ... Z would contest it: N% chance of civil war"
func _succession_text(fid: String, yours: bool) -> String:
	var leader = city.leader_of(fid)
	var outlook = city.succession_outlook(fid)
	var heir: Character = outlook["heir"]
	if leader == null or heir == null:
		return "[color=#e3876f]No one is ready to take over.[/color]"
	var text = "[b]If %s died today:[/b] %s (%d, %s) takes over." % [leader.name.get_slice(" ", 0), heir.name, heir.age,
		"family" if outlook["by_blood"] else "strongest on the council, no heir of the blood"]
	if outlook["contesters"].is_empty():
		text += " [color=#8bd48b]Nobody would contest it.[/color]"
	else:
		var names = outlook["contesters"].map(func(e): return "%s (loyalty %d%s)" % [e[0].name, e[0].loyalty(), ", Ambitious" if e[0].has_trait("ambitious") else ""])
		var chance = outlook["split_chance"]
		text += " [color=%s]%s would contest it: %d%% chance of civil war[/color]" % ["#ffb347" if chance < 0.3 else "#e3876f", ", ".join(names), chance * 100]
		if yours:
			text += "[color=#999999] (raise their loyalty: seats, glory, pay; or send them away)[/color]"
	return text

# --- Explanations live in tooltips (v1.35) -----------------------------------------------
# How a system works goes on its tab (and window title / menu button) as a tooltip, not in the body

func _explain(window_id: String, tab_id: String, text: String):
	var w = windows[window_id]
	w["tabs"][tab_id]["tip"] = text
	w["tabs"][tab_id]["button"].tooltip_text = text
	if open_window == window_id and w["current"] == tab_id:
		window_title.tooltip_text = text
	if tab_id == w["order"][0] and menu_buttons.has(window_id):
		menu_buttons[window_id].tooltip_text = "%s (%s)\n\n%s" % [w["title"], w["hotkey"], text]

# A small labelled box with its own tooltip (skills, traits, district stats)
func _chip_label(text: String, fill: Color, border: Color, tip: String = "") -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", s)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.tooltip_text = tip
	return l

func _card_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16)
	style.border_color = Color(0.25, 0.27, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _loyalty_tip(c: Character) -> String:
	var lines = ["Loyalty %d (below %d they may desert to a rival)" % [c.loyalty(), GameData.rule("loyalty_defect")]]
	for part in c.loyalty_breakdown():
		lines.append("  %+d %s" % [part[1], part[0]])
	return "\n".join(lines)

func _loyalty_color(value: float) -> String:
	return "#8bd48b" if value >= 60 else ("#ffb347" if value >= GameData.rule("loyalty_restless") else "#e3876f")

# --- Council window: seats as cards -----------------------------------------------------------

func _build_council_window():
	_window("council", "Council", "F2")
	var seats = _page("council", "seats", "Seats")
	council_intro = _rich()
	seats.add_child(council_intro)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	seats.add_child(grid)
	for post in GameData.council()["posts"]:
		var def = GameData.council_post(post)
		var card = _card_panel()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)
		var seat_label = Label.new()
		seat_label.text = def["label"]
		seat_label.add_theme_font_size_override("font_size", 14)
		seat_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.4))
		seat_label.mouse_filter = Control.MOUSE_FILTER_PASS
		seat_label.tooltip_text = "%s. Uses %s." % [def["summary"], def["skill"].capitalize()]
		box.add_child(seat_label)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var portrait = Portrait.new()
		portrait.custom_minimum_size = Vector2(52, 60)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		portrait.clicked.connect(func(c): _show_character(c.id))
		row.add_child(portrait)
		var info = _rich()
		info.add_theme_font_size_override("normal_font_size", 13)
		info.add_theme_font_size_override("bold_font_size", 13)
		row.add_child(info)
		var pick = OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.fit_to_longest_item = false
		pick.clip_text = true
		pick.add_theme_font_size_override("font_size", 12)
		pick.item_selected.connect(func(index): _on_seat_picked(post, pick.get_item_id(index)))
		box.add_child(pick)
		# Give the seat holder a standing task: choose which, then pick the district on the map
		var task_menu = MenuButton.new()
		task_menu.text = "Task..."
		task_menu.flat = false
		task_menu.focus_mode = Control.FOCUS_NONE
		task_menu.about_to_popup.connect(func(): _fill_task_menu(task_menu, post))
		task_menu.get_popup().id_pressed.connect(func(index): _on_task_chosen(post, index))
		box.add_child(task_menu)
		seat_rows[post] = {"portrait": portrait, "info": info, "pick": pick, "task": task_menu, "signature": ""}
	var crew = _page("council", "crew", "Crew")
	crew_intro = _rich()
	crew.add_child(crew_intro)
	crew_box = VBoxContainer.new()
	crew_box.add_theme_constant_override("separation", 6)
	crew.add_child(crew_box)

func _refresh_captains():
	var p = _player()
	_explain("council", "seats", "The council: four seats, each tied to one skill.\nA seat boosts every venture that uses its skill: +%d%% per point above %d (the Envoy also helps treaties get accepted).\nSeated members still lead ventures. Each seat is paid %.2f wealth a day (rising with territory); unpaid seats grow disloyal.\nPassing over a better candidate costs their loyalty. Click a portrait to open that person." % [
		GameData.rule("council_skill_step") * 100, GameData.rule("skill_neutral"), city.council_wage(p.id)])
	_explain("council", "crew", "Your named crew: they lead ventures and can hold seats.\nMore join with territory and renown, up to your captain limit.\nLoyalty falls when they're passed over, wounded on your orders or unpaid; below %d they may desert to a rival. Hover a loyalty value for why." % GameData.rule("loyalty_defect"))
	var empty = GameData.council()["posts"].keys().filter(func(post): return city.council_member(p.id, post) == null).size()
	council_intro.text = ("[color=#ffb347]%d empty seat%s[/color]" % [empty, "s" if empty > 1 else ""]) if empty > 0 else ""
	council_intro.visible = empty > 0
	for post in seat_rows:
		var def = GameData.council_post(post)
		var skill: String = def["skill"]
		var w = seat_rows[post]
		var holder = city.council_member(p.id, post)
		w["portrait"].setup(holder, p.color, holder != null and holder.is_wounded(city.day))
		if holder:
			var bonus = (holder.skills[skill] - GameData.rule("skill_neutral")) * GameData.rule("council_skill_step") * 100
			var extra = ""
			if post == "envoy":
				extra = "\n%+d%% treaty acceptance" % ((holder.skills[skill] - GameData.rule("skill_neutral")) * GameData.rule("envoy_acceptance_step") * 100)
			w["info"].text = "[b]%s[/b]\n%s %d → [color=%s]%+d%%[/color]%s\n[color=%s]Loyalty %d[/color]" % [
				holder.name, skill.substr(0, 3).capitalize(), holder.skills[skill], "#8bd48b" if bonus >= 0 else "#e3876f", bonus, extra,
				_loyalty_color(holder.loyalty()), holder.loyalty()]
			# A seat holder can still lead ventures, so say when they can't right now
			var away = city.unavailable_reason(holder)
			if away != "":
				w["info"].text += "\n[color=%s]%s[/color]" % ["#e3876f" if holder.is_wounded(city.day) else "#6fa0ff", away[0].to_upper() + away.substr(1)]
			w["info"].tooltip_text = "%s\n\n%s" % [holder.name, _loyalty_tip(holder)]
		else:
			w["info"].text = "[color=#ffb347]Empty[/color]\n[color=#999999]Needs %s[/color]" % skill.capitalize()
			w["info"].tooltip_text = def["summary"]
		# The dropdown is rebuilt only when the candidates change
		var candidates = city.characters_of(p.id)
		candidates.sort_custom(func(a, b): return a.skills[skill] > b.skills[skill])
		var signature = "%s|%s" % [holder.id if holder else -1, ",".join(candidates.map(func(c): return "%d:%d:%s" % [c.id, c.skills[skill], c.post]))]
		if signature == w["signature"]:
			continue
		w["signature"] = signature
		var pick: OptionButton = w["pick"]
		pick.clear()
		pick.add_item("Replace..." if holder else "Appoint...", NO_PICK)
		for c in candidates:
			if c == holder:
				continue
			var note = ""
			if c.post != "":
				note = " (leaves %s empty)" % GameData.council_post(c.post)["label"]
			elif c.has_trait("ambitious"):
				note = " (Ambitious)"
			pick.add_item("%s: %s %d%s" % [c.name, skill.substr(0, 3).capitalize(), c.skills[skill], note], c.id)
		if holder:
			pick.add_item("Leave the seat empty", -2)
		pick.select(0)
	# One card per character, kept between refreshes
	var chars = city.characters_of(p.id)
	crew_intro.text = "[color=#999999]%d of %d named crew[/color]" % [chars.size(), city.captain_cap(p.id)]
	var ids = chars.map(func(c): return c.id)
	for id in crew_cards.keys():
		if id not in ids:
			crew_cards[id]["root"].queue_free()
			crew_cards.erase(id)
	chars.sort_custom(func(a, b): return (a.post != "") and (b.post == "") or ((a.post != "") == (b.post != "") and a.id < b.id))
	for i in chars.size():
		var c: Character = chars[i]
		if not crew_cards.has(c.id):
			crew_cards[c.id] = _make_crew_card(c.id)
			crew_box.add_child(crew_cards[c.id]["root"])
		var w = crew_cards[c.id]
		crew_box.move_child(w["root"], i)
		_fill_crew_card(w, c)

# --- Character window: who they are on top, everyone else in the tabs --------------------------

const SKILL_TIPS = {
	"command": "Command: leading fights. Raids, assaults, Safeguard, Reinforce.",
	"cunning": "Cunning: guile. Scouting, Gather Weapons, agitation.",
	"diplomacy": "Diplomacy: talking. Negotiate, and the Envoy's treaty bonus.",
	"stewardship": "Stewardship: running things. Food, scavenging, settling, trade, relief, rebuilding.",
}
const TRAIT_COLORS = {"personality": [Color(0.24, 0.17, 0.3), Color(0.62, 0.45, 0.78)], "earned": [Color(0.14, 0.22, 0.3), Color(0.45, 0.66, 0.85)],
	"ruling": [Color(0.3, 0.24, 0.1), Color(0.85, 0.7, 0.35)]}

func _build_character_window():
	_window("character", "Character", "F1")
	var top = _window_top("character")
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)
	char_portrait = Portrait.new()
	char_portrait.custom_minimum_size = Vector2(92, 106)
	char_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(char_portrait)
	var mid = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	row.add_child(mid)
	char_name = _rich()
	mid.add_child(char_name)
	char_skills = HBoxContainer.new()
	char_skills.add_theme_constant_override("separation", 4)
	mid.add_child(char_skills)
	char_traits = HFlowContainer.new()
	char_traits.add_theme_constant_override("h_separation", 4)
	char_traits.add_theme_constant_override("v_separation", 4)
	mid.add_child(char_traits)
	char_relatives = HBoxContainer.new()
	char_relatives.add_theme_constant_override("separation", 6)
	char_relatives.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(char_relatives)
	char_actions = HFlowContainer.new()
	char_actions.add_theme_constant_override("h_separation", 4)
	top.add_child(char_actions)
	char_family = _page("character", "family", "Family")
	char_relations = _rich()
	_page("character", "relations", "Relations").add_child(char_relations)
	char_record = _rich()
	_page("character", "record", "Record").add_child(char_record)
	_explain("character", "family", "Parents, children and siblings. The spouse and heir are shown at the top.\nA star marks the heir, a cross the dead. Click anyone to open them.")
	_explain("character", "relations", "For your people: their loyalty and why.\nFor a rival leader: their faction's opinion of you and why, and their succession.")
	_explain("character", "record", "What they've done: ventures led, triumphs, wounds, and for leaders their reign.")

func _role_text(c: Character) -> String:
	var f = city.factions.get(c.faction_id)
	var of = (" · %s" % f.display_name) if f else ""
	if c.death_day >= 0:
		return "[color=#e3876f]%s, %s[/color]" % [c.fate.capitalize(), _date_of(c.death_day)]
	if c.is_leader:
		return "[color=#d9b35a]Leader[/color]" + of
	if c.post != "":
		return "[color=#d9b35a]%s[/color]%s" % [GameData.council_post(c.post)["label"], of]
	if c.family:
		return ("Child" if not c.is_adult() else "Family") + of
	return "Captain" + of

func _refresh_character():
	var c = city.person_by_id(character_shown)
	if c == null:
		_close_window()
		return
	var mine = c.faction_id == city.player_id
	var alive = c.death_day < 0
	var f: Faction = city.factions.get(c.faction_id)
	var color = f.color if f else Color(0.4, 0.4, 0.4)
	char_portrait.setup(c, color, alive and c.is_wounded(city.day), _badge(c))
	var status = ""
	var tip = []
	if alive and c.is_adult():
		var risk = city.yearly_death_chance(c)
		status = "  ·  [color=%s]Risk %d%%[/color]" % ["#8bd48b" if risk < 0.2 else ("#ffb347" if risk < 0.35 else "#e3876f"), risk * 100]
		tip.append("Chance of dying this year: %d%% (leaders carry the strain of rule; it rises with age)" % (risk * 100))
		if c.is_wounded(city.day):
			status += "  ·  [color=#e3876f]Wounded %dd[/color]" % (c.wounded_until - city.day)
		if mine and not c.is_leader:
			status += "  ·  [color=%s]Loyalty %d[/color]" % [_loyalty_color(c.loyalty()), c.loyalty()]
			tip.append(_loyalty_tip(c))
	elif alive:
		status = "  ·  [color=#999999]of age in %d years[/color]" % (16 - c.age)
	char_name.text = "[font_size=18][b]%s[/b][/font_size]\n%s\n[color=#999999]House %s · %d[/color]%s" % [c.name, _role_text(c),
		c.dynasty if c.dynasty != "" else c.name.get_slice(" ", 1), c.age, status]
	char_name.tooltip_text = "\n\n".join(tip)
	var rel = _relatives(c)
	var heir: Character = city.succession_outlook(c.faction_id)["heir"] if c.is_leader and alive and f else null
	var signature = "%d|%d|%d|%s|%s|%d|%d|%s|%s|%d" % [c.id, c.age, c.spouse_id, str(c.traits), str(c.skills), rel["children"].size(), rel["siblings"].size(),
		c.post, str(heir.id) if heir else "-", f.designated_heir if f else -1]
	if signature != char_signature:
		char_signature = signature
		_rebuild_character(c, rel, heir, mine, alive)
	# Relations
	var lines = []
	if mine and not c.is_leader and alive:
		lines.append("[b]Loyalty %d[/b] [color=#999999](below %d they may desert)[/color]" % [c.loyalty(), GameData.rule("loyalty_defect")])
		for part in c.loyalty_breakdown():
			lines.append("  [color=%s]%+d[/color] %s" % ["#8bd48b" if part[1] >= 0 else "#e3876f", part[1], part[0]])
	elif c.is_leader and alive and not mine and f:
		var r = city.relation(city.player_id, c.faction_id)
		lines.append("[b]The %s's opinion of you: %+d[/b]" % [f.display_name, r.opinion[c.faction_id]])
		# The same reason can come from more than one of their traits: show it once, summed
		var merged = {}
		for part in Diplomacy.opinion_baseline(city, c.faction_id, city.player_id):
			var label = part[0].replace("their", "your")
			merged[label] = merged.get(label, 0.0) + part[1]
		for label in merged:
			lines.append("  [color=%s]%+d[/color] %s" % ["#8bd48b" if merged[label] >= 0 else "#e3876f", merged[label], label])
		for m in r.modifiers[c.faction_id]:
			lines.append("  [color=%s]%+d[/color] %s [color=#777777](fading)[/color]" % ["#8bd48b" if m["value"] >= 0 else "#e3876f", m["value"], GameData.opinion_modifier(m["id"])["label"]])
		lines.append("")
		lines.append(_succession_text(c.faction_id, false))
	elif c.is_leader and alive and mine:
		lines.append("[b]How others see you[/b]")
		for fid in city.player_met:
			if city.factions.has(fid):
				lines.append("  [url=f:%s][color=%s]%s[/color][/url]: %+d" % [fid, _hex(fid), city.faction_name(fid), city.opinion_of(fid, city.player_id)])
		if city.player_met.is_empty():
			lines.append("  [color=#777777]You haven't met anyone yet.[/color]")
	else:
		lines.append("[color=#777777]Nothing to show.[/color]")
	char_relations.text = "\n".join(lines)
	if not char_relations.meta_clicked.is_connected(_on_link_clicked):
		char_relations.meta_clicked.connect(_on_link_clicked)
	# Record
	var record = ["Ventures led %d · triumphs %d · wounds %d" % [c.ventures_led, c.triumphs, c.wounds]]
	if c.is_leader:
		var until = c.death_day if c.death_day >= 0 else city.day
		record.append("Leader for %d days" % (until - c.ruling_since))
		if f:
			record.append("Since taking power: %d districts taken by force, %d buildings, %d days of peace" % [
				f.stats["districts_conquered"] - int(c.rule_start.get("districts_conquered", 0)), f.stats.get("buildings_built", 0) - int(c.rule_start.get("buildings_built", 0)), c.peace_days])
		record.append("[color=#999999]Leaders earn Conqueror (3 districts by force), Builder (5 buildings) and Peacemaker (a year of peace with 2+ treaties).[/color]")
	char_record.text = "\n".join(record)

func _rebuild_character(c: Character, rel: Dictionary, heir: Character, mine: bool, alive: bool):
	# Skills: four boxes, the best one highlighted
	for child in char_skills.get_children():
		child.queue_free()
	for s in Character.SKILLS:
		var best = s == c.best_skill()
		char_skills.add_child(_chip_label("%s %d" % [s.substr(0, 3).to_upper(), c.skills[s]], Color(0.16, 0.18, 0.21),
			Color(0.85, 0.7, 0.35) if best else Color(0.3, 0.33, 0.37), SKILL_TIPS[s]))
	# Traits: chips coloured by kind, explained on hover
	for child in char_traits.get_children():
		child.queue_free()
	for t in c.traits:
		var def = GameData.character_trait(t)
		var colours = TRAIT_COLORS.get(def["kind"], TRAIT_COLORS["personality"])
		var kind = {"personality": "Nature", "earned": "Earned", "ruling": "Earned as leader"}.get(def["kind"], "")
		char_traits.add_child(_chip_label(def["label"], colours[0], colours[1], "%s (%s)\n%s" % [def["label"], kind, def["description"]]))
	# Spouse and heir: top right, and nowhere else as separate entries
	for child in char_relatives.get_children():
		child.queue_free()
	if rel["spouse"]:
		char_relatives.add_child(_person_cell(rel["spouse"], "Spouse", Vector2(48, 56)))
	if heir:
		char_relatives.add_child(_person_cell(heir, "Heir", Vector2(48, 56)))
	# Actions: only what does something to this person
	for child in char_actions.get_children():
		child.queue_free()
	var f: Faction = city.factions.get(c.faction_id)
	if mine and alive and not c.is_leader and c.is_adult():
		if (c.family or c.post != "") and f.designated_heir != c.id and heir != c:
			var b = _button("Name as heir", func(): _designate(c.id))
			b.tooltip_text = "Make %s the next leader. Passing over the natural heir costs loyalty." % c.name
			char_actions.add_child(b)
		var lead = _button("Lead a venture", func(): _lead_with(c.id))
		lead.disabled = selected == null or c.is_wounded(city.day) or city.leader_busy(c)
		lead.tooltip_text = "Select a district first" if selected == null else "Plan a venture in %s with %s leading" % [selected.district_name, c.name]
		char_actions.add_child(lead)
	elif f and alive and not mine:
		var fid = c.faction_id
		char_actions.add_child(_button("Diplomacy with the %s" % f.display_name, func(): _open_faction_panel(fid, Vector2(-1, -1))))
	char_actions.visible = char_actions.get_child_count() > 0
	# Family tab: one line per group, spouse left out (it's at the top)
	for child in char_family.get_children():
		child.queue_free()
	for section in [["Parents", rel["parents"]], ["Children", rel["children"]], ["Siblings", rel["siblings"]]]:
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		char_family.add_child(line)
		var label = Label.new()
		label.text = section[0]
		label.custom_minimum_size.x = 64
		label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(label)
		var flow = HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 6)
		line.add_child(flow)
		for person in section[1]:
			flow.add_child(_person_cell(person, "%s, %d" % [person.name.get_slice(" ", 0), person.age], Vector2(44, 52)))
		if section[1].is_empty():
			var none = Label.new()
			none.text = "none" if section[0] != "Parents" else "unknown"
			none.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			flow.add_child(none)

# --- District panel: the numbers you decide with; the reasons on hover ---------------------------

const STAT_KEYS = ["control", "people", "grievance", "food", "manpower", "defence", "raid_safe", "danger", "ruins", "development", "buildings"]

func _build_district_panel():
	district_panel = _panel(0.95)
	district_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	district_panel.visible = false
	right_column.add_child(district_panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	district_panel.add_child(box)
	var header = HBoxContainer.new()
	box.add_child(header)
	district_title = Label.new()
	district_title.add_theme_font_size_override("font_size", 17)
	district_title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	district_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	district_title.clip_text = true
	district_title.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(district_title)
	for key in ["district", "build"]:
		var b = _button("Act" if key == "district" else "Build", func(): _show_district_tab(key))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 13)
		header.add_child(b)
		district_tab_buttons[key] = b
	district_tab_buttons["district"].tooltip_text = "Ventures here: pick one, choose who leads it and how many go, then LAUNCH.\nHover the odds bar for how the chance is worked out."
	district_tab_buttons["build"].tooltip_text = "Buildings here. Claimed districts have 1 slot, Secured 2. Hover a building for what it does."
	var close = _button("X", _deselect)
	close.tooltip_text = "Close (Esc)"
	header.add_child(close)
	for key in ["district", "build"]:
		var scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(scroll)
		var page = VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 4)
		scroll.add_child(page)
		district_pages[key] = {"scroll": scroll, "page": page}
	var district_page: VBoxContainer = district_pages["district"]["page"]
	district_info = _rich()
	district_info.add_theme_font_size_override("normal_font_size", 13)
	district_page.add_child(district_info)
	var stats = HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 4)
	stats.add_theme_constant_override("v_separation", 4)
	district_page.add_child(stats)
	for key in STAT_KEYS:
		var l = _chip_label("", Color(0.14, 0.15, 0.18), Color(0.28, 0.3, 0.34))
		stats.add_child(l)
		stat_chips[key] = l
	district_page.add_child(HSeparator.new())
	var venture_grid = GridContainer.new()
	venture_grid.columns = 2
	venture_grid.add_theme_constant_override("h_separation", 4)
	venture_grid.add_theme_constant_override("v_separation", 4)
	district_page.add_child(venture_grid)
	for venture_id in GameData.ventures():
		var b = _button("", func(): _on_venture_pressed(venture_id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		venture_buttons[venture_id] = b
		venture_grid.add_child(b)
	unavailable_chip = _chip_label("", Color(0.12, 0.13, 0.15), Color(0.25, 0.26, 0.28))
	unavailable_chip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	unavailable_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unavailable_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	venture_grid.add_child(unavailable_chip)
	_build_planner(district_page)
	odds_info = _rich()
	odds_info.add_theme_font_size_override("normal_font_size", 13)
	district_page.add_child(odds_info)
	var build_page: VBoxContainer = district_pages["build"]["page"]
	build_title = _rich()
	build_title.visible = false
	build_page.add_child(build_title)
	buildings_info = _rich()
	buildings_info.add_theme_font_size_override("normal_font_size", 13)
	build_page.add_child(buildings_info)
	for building_id in GameData.buildings():
		var b = _button("", func(): _on_build_pressed(building_id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		build_buttons[building_id] = b
		build_page.add_child(b)
	building_info = _rich()
	build_page.add_child(building_info)
	_show_district_tab("district")

func _stat(key: String, show: bool, text: String, tip: String, color: Color = Color(0.9, 0.9, 0.9)):
	var l: Label = stat_chips[key]
	l.visible = show
	if show:
		l.text = text
		l.tooltip_text = tip
		l.add_theme_color_override("font_color", color)

func _refresh_district_info():
	var d = selected
	var p = _player()
	var owner = d.owner_id()
	var mine = owner == p.id
	var place = GameData.district_type(d.district_type)
	var known = city.knows(p.id, d)
	district_title.tooltip_text = "%s, %s\n%s" % [place["label"], d.borough, place["description"]]
	var status = "Unclaimed" if owner == "" else "%s by %s" % [d.get_control_status().capitalize(), "you" if mine else city.faction_name(owner)]
	var line = "[color=#999999]%s · %s ·[/color] %s" % [place["label"], d.borough, status]
	if not known:
		line += "\n[color=#ffb347]Unscouted: salvage, danger and people unknown. Scout it first.[/color]"
	if not city.can_reach(p.id, d):
		line += "\n[color=#999999]Out of reach: you can act on your land and next to it.[/color]"
	district_info.text = line
	# Control / claim
	var claim: int = GameData.rule("claim_threshold")
	var secure: int = GameData.rule("secure_threshold")
	var shares = []
	for fid in city.factions:
		if d.share(fid) >= 1.0:
			shares.append("  %s %d" % ["You" if fid == p.id else city.faction_name(fid), d.share(fid)])
	var share_text = ("\nInfluence here:\n" + "\n".join(shares)) if shares.size() > 0 else ""
	if mine:
		_stat("control", true, "Control %d/%d" % [d.share(p.id), secure], ("Your hold on %s. Claimed at %d, Secured at %d (%.1fx income and manpower, harder to attack, can't revolt).\nRaise it with Safeguard the Shelter (most), Secure Food and Gather Weapons; a calm district drifts up to %d on its own.%s") % [
			d.district_name, claim, secure, GameData.rule("status_yield")["secured"], GameData.rule("control_consolidation_cap"), share_text],
			Color(0.55, 0.85, 0.55) if d.share(p.id) >= secure else Color(0.95, 0.75, 0.4))
	elif owner != "":
		_stat("control", true, "Their control %d" % d.share(owner), "The %s's hold on it. Take it by war (Assault) or by agitating it into revolt.%s" % [city.faction_name(owner), share_text])
	else:
		_stat("control", true, "Claim %d/%d" % [d.share(p.id), claim], "Unclaimed: pays nobody. Scout it, Scavenge it (+3 influence each), then Settle it (+30; the settlers stay). %d influence claims it.%s" % [claim, share_text])
	_stat("people", known, "People %d/%d" % [d.population, city.housing(d)], "Population %d; housing for %d (Rebuild adds room).\nPeople grow with food, pay taxes and eat food." % [d.population, city.housing(d)])
	_stat("grievance", known, "Grievance %d" % d.grievance, "Unrest %d of 100. Above 65 it's restless; above 80 it can revolt.\nRelief calms it; raids, war and a cruel rule stir it." % d.grievance,
		Color(0.55, 0.85, 0.55) if d.grievance < 40 else (Color(0.95, 0.72, 0.3) if d.grievance < 65 else Color(0.95, 0.45, 0.4)))
	if mine:
		var food = city.district_food(d)
		var from_buildings = d.building_effect("supplies_daily") if city.buildings_active(d) else 0.0
		_stat("food", true, "Food %+.2f" % food, "Food grown here each day: %+.2f\n  Land %+.2f (more with development, less in ruins)\n  Food sources %+.2f of %.1f (Secure Food adds them)\n  Buildings %+.2f (Allotments)" % [
			food, food - d.food_yield - from_buildings, d.food_yield, GameData.rule("food_source_cap"), from_buildings])
		var growth = city.district_growth_food(d)
		var income = city.district_income(d)
		_stat("manpower", true, "Manpower %+.2f" % income["recruits"], "New manpower each day: %+.3f\nGrown from %.2f food (this district's own%s), more in rebuilt districts; less when restless." % [
			income["recruits"], growth, " plus a share of your land next door" if growth > food + 0.001 else ""])
	else:
		_stat("food", false, "", "")
		_stat("manpower", false, "", "")
	if owner != "":
		var parts = city.defence_factors(d).map(func(f): return "  x%.2f %s" % [f[1], f[0]])
		var worth = city.raid_worth(d)
		_stat("defence", true, "Defence %d%%" % (city.defence_total(d) * 100), "Attacks here succeed at %d%% of normal odds, and take longer.\n%s\n\nWorth raiding: %s (a raid takes x%.2f of the usual loot; more with development and working buildings)" % [city.defence_total(d) * 100,
			"\n".join(parts) if parts.size() > 0 else "  Undefended: raise control, arms, a Watchtower, or Reinforce.",
			"low" if worth < 0.8 else ("high" if worth >= 1.2 else "medium"), worth])
	else:
		_stat("defence", false, "", "")
	var safe_days = d.raid_safe_until - city.day
	var cooldown: Dictionary = GameData.venture("raid")["raid_cooldown"]
	_stat("raid_safe", owner != "" and safe_days > 0, "Safe from raids %dd" % safe_days,
		"Raided recently: nobody can raid it for %d more days.\nAfter a raid: %d days if it worked, %d if it was driven off, %d after a disaster." % [
		safe_days, cooldown["success"], cooldown["setback"], cooldown["disaster"]], Color(0.55, 0.85, 0.55))
	var danger = city.danger(d)
	_stat("danger", known, "Danger %s" % VentureSystem.danger_label(danger), "Danger %d%%: ferals, traps and rotten floors. Lowers venture odds here and raises the chance of disaster.\nSafeguard the Shelter lowers it directly; in land you hold it also falls as the ruins are cleared (ruins %d%% now)." % [danger * 100, d.ruin_level * 100],
		Color(0.9, 0.9, 0.9) if danger < 0.25 else Color(0.95, 0.55, 0.45))
	_stat("ruins", known, "Ruins %d%%" % (d.ruin_level * 100), "Salvage left to strip. Scavenge takes materials from it; each trip strips it further, and a stripped district grows more food.")
	_stat("development", known, "Dev %d%%" % (d.development * 100), "How rebuilt it is. Raises food, how much manpower that food makes, housing and taxes. Rebuild raises it.")
	if owner != "":
		var labels = d.building_labels()
		for c in city.constructions_at(d):
			labels.append("%s (building, %dd)" % [GameData.building(c.building_id)["label"], c.days_left])
		_stat("buildings", true, "Buildings %d/%d" % [d.buildings.size() + city.constructions_at(d).size(), city.building_slots(d)],
			("\n".join(labels) if labels.size() > 0 else "None yet.") + ("\nNot working: out of wealth or materials." if not city.buildings_active(d) else ""))
	else:
		_stat("buildings", false, "", "")

func _refresh_venture_buttons():
	var p = _player()
	# A newly selected district starts on a venture you can actually launch there
	if selected.id != venture_district:
		venture_district = selected.id
		if _venture_error(hovered_venture) != "":
			for venture_id in venture_buttons:
				if _venture_error(venture_id) == "":
					hovered_venture = venture_id
					break
	var unavailable = []
	for venture_id in venture_buttons:
		var def = GameData.venture(venture_id)
		var b: Button = venture_buttons[venture_id]
		var err = _venture_error(venture_id)
		var under_way = city.ventures.any(func(v): return v.faction_id == p.id and v.venture_id == venture_id and v.district == selected) or city.task_at(p.id, venture_id, selected) != null
		b.visible = err == "" or under_way or (venture_id == hovered_venture and not err.begins_with("Held by") and not err.begins_with("Too far") and not err.begins_with("Only"))
		if not b.visible:
			unavailable.append("%s: %s" % [def["label"], err])
			continue
		# Shown with the best free captain and the usual crew; the planner below fine-tunes it
		var target_id = city.venture_target(p.id, venture_id, selected)
		var leader = city.best_leader(p.id, def["skill"])
		var result = VentureSystem.compute_odds(venture_id, p, selected, city, target_id, leader)
		var odds = result["odds"]
		b.text = "%s  %d%%" % [def["label"], odds * 100]
		b.disabled = false
		b.modulate = Color(1, 1, 1) if err == "" else Color(0.6, 0.6, 0.6)
		b.tooltip_text = "%s\n\n%s" % [_wrap(def["description"]), err if err != "" else _odds_explainer(venture_id, selected, leader, -1, 0, result)]
	# Nothing to do here at all: say so, and hide the planner
	nothing_here = venture_buttons.values().all(func(b): return not b.visible)
	unavailable_chip.visible = unavailable.size() > 0
	unavailable_chip.text = "+%d unavailable" % unavailable.size()
	unavailable_chip.tooltip_text = "Not possible here right now:\n" + "\n".join(unavailable)

# --- Venture planner ---------------------------------------------------------------------------

func _build_planner(parent: Control):
	plan_box = VBoxContainer.new()
	plan_box.add_theme_constant_override("separation", 4)
	parent.add_child(plan_box)
	plan_box.add_child(HSeparator.new())
	plan_title = _rich()
	plan_title.mouse_filter = Control.MOUSE_FILTER_PASS
	plan_box.add_child(plan_title)
	var leader_row = HBoxContainer.new()
	plan_box.add_child(leader_row)
	leader_row.add_child(_row_label("Leader"))
	leader_select = OptionButton.new()
	leader_select.focus_mode = Control.FOCUS_NONE
	leader_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leader_select.clip_text = true
	leader_select.fit_to_longest_item = false
	leader_select.item_selected.connect(func(_index): _refresh_plan())
	leader_row.add_child(leader_select)
	var crew_row = HBoxContainer.new()
	plan_box.add_child(crew_row)
	crew_row.add_child(_row_label("Crew"))
	crew_slider = HSlider.new()
	crew_slider.step = 1
	crew_slider.focus_mode = Control.FOCUS_NONE
	crew_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crew_slider.value_changed.connect(func(_value): _refresh_plan())
	crew_row.add_child(crew_slider)
	crew_label = Label.new()
	crew_label.custom_minimum_size.x = 90
	crew_row.add_child(crew_label)
	var funding_row = HBoxContainer.new()
	plan_box.add_child(funding_row)
	funding_row.add_child(_row_label("Funding"))
	funding_select = OptionButton.new()
	funding_select.focus_mode = Control.FOCUS_NONE
	funding_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	funding_select.fit_to_longest_item = false
	for level in int(GameData.rule("funding_levels")) + 1:
		funding_select.add_item("")
	funding_select.select(0)
	funding_select.item_selected.connect(func(_index): _refresh_plan())
	funding_row.add_child(funding_select)
	plan_toggle = _button("Cheapest", func():
		_apply_plan(plan_toggle.text == "Cheapest")
		_refresh_plan())
	funding_row.add_child(plan_toggle)
	var odds_row = HBoxContainer.new()
	odds_row.add_theme_constant_override("separation", 6)
	plan_box.add_child(odds_row)
	tier_bar = HBoxContainer.new()
	tier_bar.add_theme_constant_override("separation", 0)
	tier_bar.custom_minimum_size.y = 14
	tier_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for tier in VentureSystem.TIERS:
		var segment = ColorRect.new()
		segment.color = TIER_COLORS[tier]
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_PASS
		segment.name = tier
		tier_bar.add_child(segment)
	odds_row.add_child(tier_bar)
	tier_text = _rich()
	tier_text.size_flags_horizontal = Control.SIZE_SHRINK_END
	tier_text.custom_minimum_size.x = 60
	tier_text.mouse_filter = Control.MOUSE_FILTER_PASS
	odds_row.add_child(tier_text)
	launch_button = _button("Launch", _on_launch_pressed)
	launch_button.custom_minimum_size.y = 36
	launch_button.add_theme_font_size_override("font_size", 15)
	launch_button.clip_text = true
	launch_button.add_theme_stylebox_override("normal", _box(Color(0.2, 0.42, 0.24), Color(0.45, 0.78, 0.5)))
	launch_button.add_theme_stylebox_override("hover", _box(Color(0.26, 0.52, 0.3), Color(0.85, 0.7, 0.35)))
	launch_button.add_theme_stylebox_override("pressed", _box(Color(0.16, 0.34, 0.2), Color(0.45, 0.78, 0.5)))
	launch_button.add_theme_color_override("font_disabled_color", Color(0.9, 0.62, 0.4))
	plan_box.add_child(launch_button)

# Sets the crew and funding to the recommended plan, or to the cheapest one
func _apply_plan(cheapest: bool):
	var def = GameData.venture(hovered_venture)
	if cheapest:
		crew_slider.set_value_no_signal(def["crew_range"][0])
		funding_select.select(0)
		return
	var plan = city.recommended_plan(city.player_id, hovered_venture, selected, city.character_by_id(_selected_leader_id()))
	crew_slider.set_value_no_signal(plan["crew"])
	funding_select.select(plan["funding"])

func _refresh_plan():
	var p = _player()
	var def = GameData.venture(hovered_venture)
	var skill: String = def["skill"]
	for venture_id in venture_buttons:
		venture_buttons[venture_id].set_pressed_no_signal(venture_id == hovered_venture)
	# Free captains, best at this venture's skill first; rebuilt only when the list changes
	# A standing task takes a free councillor; a one-off, any free captain
	var as_task = city.is_task(p.id, hovered_venture, selected) if selected else false
	var leaders = city.free_councillors(p.id, skill) if as_task else city.available_leaders(p.id)
	leaders.sort_custom(func(a, b): return a.skills[skill] > b.skills[skill])
	var ids = ",".join(leaders.map(func(c): return str(c.id)))
	var signature = "%s|%s|%s" % [hovered_venture, as_task, ids]
	if signature != leader_signature:
		var venture_changed = not leader_signature.begins_with(hovered_venture + "|")
		var keep = -1 if venture_changed else _selected_leader_id()
		leader_signature = signature
		leader_select.clear()
		for c in leaders:
			leader_select.add_item("%s: %s %d%s" % [c.name, skill.substr(0, 3).capitalize(), c.skills[skill],
				("  (%s)" % GameData.council_post(c.post)["label"]) if c.post != "" else ""], c.id)
		if leaders.is_empty():
			leader_select.add_item("No councillor is free" if as_task else "No captain is free", NO_PICK)
		var index = leader_select.get_item_index(keep) if keep >= 0 else -1
		leader_select.select(index if index >= 0 else 0)
	if preferred_leader >= 0:
		var index = leader_select.get_item_index(preferred_leader)
		if index >= 0:
			leader_select.select(index)
		preferred_leader = -1
	crew_slider.min_value = def["crew_range"][0]
	crew_slider.max_value = def["crew_range"][1]
	for level in funding_select.item_count:
		funding_select.set_item_text(level, "None" if level == 0 else "+%d wealth (+%d%%)" % [
			def["funding_cost"] * level, level * GameData.rule("funding_odds_step") * 100])
		# Funding you can't pay for can't be picked; fall back to the most you can afford
		funding_select.set_item_disabled(level, level > 0 and not p.can_afford(city.venture_cost(hovered_venture, level)))
	if funding_select.is_item_disabled(funding_select.selected):
		var best_level = 0
		for level in funding_select.item_count:
			if not funding_select.is_item_disabled(level):
				best_level = level
		funding_select.select(best_level)
	# A new venture or district starts on the recommended plan
	var key = "%s|%d" % [hovered_venture, selected.id if selected else -1]
	if key != plan_key and selected:
		plan_key = key
		_apply_plan(false)
	if selected:
		var plan = city.recommended_plan(p.id, hovered_venture, selected, city.character_by_id(_selected_leader_id()))
		var on_plan = int(crew_slider.value) == plan["crew"] and funding_select.selected == plan["funding"]
		plan_toggle.text = "Cheapest" if on_plan else "Recommended"
		plan_toggle.tooltip_text = ("Switch to the cheapest plan: fewest crew, no extra funding" if on_plan else
			"Switch to the recommended plan: crew until one more adds little, stopping once the odds are %d%%+. Extra funding is up to you." % (GameData.rule("no_disaster_odds") * 100))
	var leader = city.character_by_id(_selected_leader_id())
	var crew = int(crew_slider.value)
	var funding = funding_select.selected
	crew_label.text = "%d (%d idle)" % [crew, p.manpower]
	plan_box.visible = selected != null and not nothing_here
	if nothing_here:
		odds_info.text = "[color=#999999]Nothing you can do here right now. Hover \"unavailable\" for why; right-click their land for diplomacy.[/color]" if selected else ""
		return
	if not selected:
		return
	var target_id = city.venture_target(p.id, hovered_venture, selected)
	var result = VentureSystem.compute_odds(hovered_venture, p, selected, city, target_id, leader, crew, funding)
	var tiers: Dictionary = result["tiers"]
	for tier in VentureSystem.TIERS:
		var segment: ColorRect = tier_bar.get_node(tier)
		segment.size_flags_stretch_ratio = maxf(tiers[tier], 0.001)
	var odds_tip = _odds_tooltip(def, _odds_explainer(hovered_venture, selected, leader, crew, funding, result), result)
	for tier in VentureSystem.TIERS:
		tier_bar.get_node(tier).tooltip_text = odds_tip
	tier_text.text = "[b]%d%%[/b]" % (result["odds"] * 100)
	tier_text.tooltip_text = odds_tip
	var days = city.venture_days(hovered_venture, leader, selected)
	var cost = _cost_text(city.venture_cost(hovered_venture, funding))
	plan_title.text = "[b]%s[/b]" % def["label"]
	var about = def["description"]
	if hovered_venture == "rebuild" and selected.owner_id() == p.id:
		about += "\n\n" + _rebuild_payoff(selected)
	if def.get("feeds_trait", "") != "":
		about += "\n\nBuilds the %s trait." % def["feeds_trait"]
	plan_title.tooltip_text = _wrap(about)
	var err = _venture_error(hovered_venture, _selected_leader_id(), crew, funding)
	launch_button.disabled = err != ""
	launch_button.tooltip_text = odds_tip if err == "" else err
	# What it costs sits on the button itself, so you see the price at the moment you commit
	launch_button.text = ("LAUNCH  ·  %s  ·  %d days" % [cost, days]) if err == "" else "Can't launch: %s  ·  %d days" % [cost, days]
	if as_task:
		launch_button.text = ("ASSIGN  ·  %s a run  ·  %d-day runs" % [cost, days]) if err == "" else "Can't assign: %s a run" % cost
	funding_select.disabled = as_task
	funding_select.tooltip_text = "Standing tasks run without extra funding" if as_task else ""
	# What the leader stakes is part of the decision, so it sits in view, not in a tooltip
	var risk = _leader_risk(def, tiers)
	odds_info.text = ("[color=#ffb347]%s[/color]" % err) if err != "" else "[color=#999999]Risk to %s: %s wounded · %s killed[/color]" % [
		leader.name if leader else "the leader", _percent(risk[0]), _percent(risk[1])]
	for v in city.ventures:
		if v.faction_id == p.id and v.venture_id == hovered_venture and v.district == selected:
			launch_button.text = "Under way: back in %d days" % v.days_left
			odds_info.text = ""
	# A standing task here: show where it stands, and let the player pull the councillor off
	var t = city.task_at(p.id, hovered_venture, selected) if selected else null
	if as_task and t == null and err == "":
		odds_info.text += "
[color=#999999]Runs until %s. The councillor is committed for about %d days.[/color]" % [city.task_goal(def), days * int(GameData.rule("task_commit_runs"))]
	if t:
		var holder = city.character_by_id(t.character_id)
		launch_button.disabled = t.stopping
		launch_button.text = "Stopping after this run" if t.stopping else "STOP  ·  %s %s" % [holder.name if holder else "?", def["task_label"].to_lower()]
		launch_button.tooltip_text = "Stopping costs nothing; the run under way finishes. %s" % ("Free for new work in %d days (the commitment)." % (t.committed_until - city.day) if t.committed_until > city.day else "Free for new work at once.")
		odds_info.text = "[color=#d9b35a]%s (%d runs)%s[/color]" % [city.task_progress_text(t), t.runs, ("  Waiting: " + t.paused) if t.paused != "" else ""]

# A chance as a percentage; a small risk shows as "<1%", never as a reassuring "0%"
func _percent(chance: float) -> String:
	return "<1%" if chance > 0.0 and chance < 0.01 else "%d%%" % roundi(chance * 100)

# Chance the leader comes back wounded, and chance they don't come back, as [wounded, killed]
func _leader_risk(def: Dictionary, tiers: Dictionary) -> Array:
	return [tiers["setback"] * city.setback_wound_chance(def) + tiers["disaster"] * GameData.rule("disaster_wound_chance"),
		tiers["disaster"] * GameData.rule("disaster_death_chance")]

# Why a venture's chance is what it is, in plain words, what would raise it, and what the leader risks
func _odds_explainer(venture_id: String, d: District, leader: Character, crew: int, funding: int, result: Dictionary) -> String:
	var p = _player()
	var def = GameData.venture(venture_id)
	var skill: String = def["skill"]
	var neutral = int(GameData.rule("skill_neutral"))
	var lines = ["%s: %d%% to succeed" % [def["label"], result["odds"] * 100], "", "Starts at %d%%, then:" % (result["base"] * 100)]
	for factor in result["factors"]:
		var change = roundi((factor[1] - 1.0) * 100)
		if change != 0:
			lines.append("  %+d%%  %s" % [change, factor[0]])
	if leader == null:
		lines.append("  No captain free: counted as %s %d" % [skill.capitalize(), neutral])
	# The target can react while you're on the way: say how badly, before you commit
	var target_id = city.venture_target(p.id, venture_id, d)
	if def.get("hostile", false) and target_id != "":
		var could = city.possible_defenders(target_id) - city.defenders_at(target_id, d)
		if could > 0:
			lines.append("")
			lines.append("Watch out: the %s could send up to %d defenders before you arrive (%+d%%, less if you bring a bigger crew)." % [
				city.faction_name(target_id), could, roundi((city.guard_defence(could) - 1.0) * 100)])
	var tips = []
	# The best captain you have for this, free or not
	var current = leader.skills[skill] if leader else neutral
	var best: Character = null
	for c in city.characters_of(p.id):
		if c != leader and c.skills[skill] > current and (best == null or c.skills[skill] > best.skills[skill]):
			best = c
	if best:
		var why = city.unavailable_reason(best)
		tips.append("A leader with more %s: %s has %d%s (+%d%% a point)" % [skill.capitalize(), best.name, best.skills[skill],
			(", " + why) if why != "" else "", GameData.rule("skill_odds_step") * 100])
	if city.council_factor(p.id, skill).is_empty():
		for post in GameData.council()["posts"]:
			if GameData.council_post(post)["skill"] == skill:
				tips.append("Seat a %s (Council): someone good at %s helps every venture like this" % [GameData.council_post(post)["label"], skill.capitalize()])
	var size = int(def["crew"]) if crew < 0 else crew
	if size < int(def["crew_range"][1]) and (size - int(def["crew"])) * GameData.rule("crew_odds_step") < 0.35:
		tips.append("More crew: +%d%% for each one over %d (up to %d)" % [GameData.rule("crew_odds_step") * 100, def["crew"], def["crew_range"][1]])
	if funding < int(GameData.rule("funding_levels")):
		tips.append("Extra funding: +%d%% a level (%d wealth each)" % [GameData.rule("funding_odds_step") * 100, def["funding_cost"]])
	if venture_id != "scout" and not city.knows(p.id, d):
		tips.append("Scout it first: going in blind costs %d%% and makes disaster likelier" % ((1.0 - GameData.rule("blind_odds")) * 100))
	if venture_id != "safeguard" and d.owner_id() == p.id and city.danger(d) >= 0.05:
		tips.append("Safeguard the Shelter here: it lowers the danger")
	if def["skill"] == "command" and def.get("hostile", false) and p.arms < GameData.rule("arms_effect_cap"):
		tips.append("Arms: +%.1f%% each (Gather Weapons)" % (GameData.rule("arms_odds_step") * 100))
	if not tips.is_empty():
		lines.append("")
		lines.append("To raise it:")
		for tip in tips:
			lines.append("  · " + tip)
	var risk = _leader_risk(def, result["tiers"])
	lines.append("")
	var wound_days: Array = city.wound_days(def)
	lines.append("Risk to the leader: %s wounded (out %d-%d days), %s killed. More skill makes disaster rarer." % [
		_percent(risk[0]), wound_days[0], wound_days[1], _percent(risk[1])])
	lines.append("A success pays x0.8 to x1.2 of its gains, more the cleaner the win; at %d%%+ odds a failure is never a disaster." % (GameData.rule("no_disaster_odds") * 100))
	return "\n".join(lines)

# Tooltips don't wrap on their own: break long lines at spaces
func _wrap(text: String, width: int = 80) -> String:
	var out = []
	for line in text.split("\n"):
		var current = ""
		for word in line.split(" "):
			if current != "" and current.length() + word.length() + 1 > width:
				out.append(current)
				current = word
			else:
				current = word if current == "" else current + " " + word
		out.append(current)
	return "\n".join(out)

# The whole working-out of a venture's chance, and what each outcome does
func _odds_tooltip(def: Dictionary, explainer: String, result: Dictionary) -> String:
	var tiers: Dictionary = result["tiers"]
	var lines = [explainer]
	lines.append("")
	lines.append("Triumph %d%%: %s; %s. The leader may improve." % [tiers["triumph"] * 100, def["on_success"], def.get("on_triumph", "")])
	lines.append("Success %d%%: %s" % [tiers["success"] * 100, def["on_success"]])
	lines.append("Setback %d%%: %s. The leader may be wounded (%d%%)." % [tiers["setback"] * 100, def["on_failure"], city.setback_wound_chance(def) * 100])
	lines.append("Disaster %d%%: %s; %s. The leader may be killed (%d%%) or wounded (%d%%)." % [tiers["disaster"] * 100, def["on_failure"], def.get("on_disaster", ""),
		GameData.rule("disaster_death_chance") * 100, GameData.rule("disaster_wound_chance") * 100])
	return "\n".join(lines)

# --- Build tab --------------------------------------------------------------------------------

func _refresh_buildings():
	var p = _player()
	if not selected:
		return
	var built = selected.building_labels()
	var building = []
	for c in city.constructions_at(selected):
		building.append("%s (%dd)" % [GameData.building(c.building_id)["label"], c.days_left])
	var text = "Slots [b]%d/%d[/b]  ·  %s" % [built.size() + building.size(), city.building_slots(selected), ", ".join(built) if built.size() > 0 else "nothing built"]
	if building.size() > 0:
		text += "  ·  building: %s" % ", ".join(building)
	if selected.owner_id() != "" and not city.buildings_active(selected):
		text += "\n[color=#e3876f]Not working: out of wealth or materials.[/color]"
	if selected.owner_id() != p.id:
		text = "[color=#999999]You can only build in districts you hold.[/color]"
	buildings_info.text = text
	for building_id in build_buttons:
		var def = GameData.building(building_id)
		var b: Button = build_buttons[building_id]
		var err = city.check_build(p.id, building_id, selected)
		b.text = "%s  (%s)" % [def["label"], def["summary"]]
		b.disabled = err != ""
		var upkeep = _cost_text(def["upkeep"]) if not def["upkeep"].is_empty() else "none"
		b.tooltip_text = "%s: %s\nCosts %s, takes %d days and %d crew. Needs a %s district. Upkeep per day: %s.%s" % [
			def["label"], def["description"], _cost_text(def["cost"]), def["days"], def["crew"], def["requires"].capitalize(), upkeep,
			("\n\n" + err) if err != "" else ""]
		b.visible = selected.owner_id() == p.id

func _refresh_building_info():
	building_info.text = ""

# How each window works, on its tabs (numbers that change are refreshed by the window itself)
func _explain_windows():
	_explain("realm", "succession", "Who takes over when your leader dies, and whether anyone would fight it. The rule depends on your government (see the Government tab): a Warlord's family inherits, a Politburo's council elects, a Democracy votes.
Disloyal or Ambitious councillors and family may contest it, and a contest can split the faction in civil war (a Politburo purges them instead).
Where you can name an heir, passing over the natural heir costs loyalty: the natural heir -15; a non-family heir, -8 with every family member.")
	_explain("realm", "government", "How your crew is run. Each government has its own succession rule and its own way of breaking. Reforms unlock from how you've played and what you've achieved (ambitions); each costs something, unsettles your districts for a while, and locks further reform for 2 years. Councillors back or oppose each reform by their natures; under a Politburo, Oligarchy or Democracy they vote.")
	_explain("realm", "dynasty", "Your house by generation, living and dead, the leaders who came before, and everyone you've lost. Click anyone to open them.")
	_explain("realm", "territory", "Every district you hold. Click one to go there.")
	_explain("diplomacy", "factions", "Everyone you've met: stance, treaties and war. Open a faction, or right-click their land on the map.")
	_explain("diplomacy", "proposals", "Offers from other factions, waiting for your answer. They expire if you ignore them.")
	_explain("diplomacy", "subjects", "Your vassals, and your patron if you have one. Vassals pay tribute and join your wars.")
	_explain("diplomacy", "faction", "One faction: who leads them, how they see you and why, and what you can propose. Hover an action for its odds or why it's not possible.")
	_explain("economy", "economy", "Where your food, materials and wealth come from and go, each day. Hover the resources in the top bar for the same, in short.")
	_explain("economy", "traits", "Your faction's identity grows from what you do, and from your leader's nature. Hover a trait for what it gives and costs.")
	_explain("ambitions", "ambitions", "National Ambitions: choose a direction and pay renown to pursue it. One at a time; each takes weeks, then its bonus lasts for good. What you can pursue depends on your traits and situation, and some choices close others for good. Some unlock a change of government. Other factions pursue theirs too: see their card in Diplomacy.")
	_explain("ambitions", "deeds", "Deeds: milestones every faction can reach. Each pays renown once. Renown you earn also adds to your reputation, which never goes down and keeps your crew and captain limits, better recruits and your heir's claim.")
	_explain("log", "log", "Everything that's happened. Filter to what's about you, your neighbours, or everyone.")

# --- Right-click on any portrait: what you can do with this person (CK-style) ---------------------

func _open_character_menu(id: int, at: Vector2):
	var c = city.person_by_id(id)
	if c == null:
		return
	character_menu.clear()
	character_menu_actions.clear()
	var add = func(label: String, action: Callable, reason: String = ""):
		var item = character_menu.item_count
		character_menu.add_item(label, item)
		character_menu_actions[item] = action
		if reason != "":
			character_menu.set_item_disabled(item, true)
			character_menu.set_item_tooltip(item, reason)
	character_menu.add_separator(c.name)
	add.call("Open character", func(): _show_character(c.id))
	var alive = c.death_day < 0
	var me = city.player_id
	var f: Faction = city.factions.get(c.faction_id)
	if alive and c.faction_id == me and not c.is_leader and c.is_adult():
		var heir_reason = ""
		if not (c.family or c.post != ""):
			heir_reason = "Only family and council members can be named heir"
		elif city.succession_outlook(me)["heir"] == c:
			heir_reason = "%s is already your heir" % c.name
		add.call("Name as heir", func(): _designate(c.id), heir_reason)
		var lead_reason = "Select a district first" if selected == null else ("Recovering from wounds" if c.is_wounded(city.day) else ("Out on a venture" if city.leader_busy(c) else ""))
		add.call("Lead a venture here", func(): _lead_with(c.id), lead_reason)
		for post in GameData.council()["posts"]:
			if c.post != post:
				var p_id = post
				var holder = city.council_member(me, post)
				add.call("Seat as %s%s" % [GameData.council_post(post)["label"], (" (replaces %s)" % holder.name) if holder else ""], func(): _on_seat_picked(p_id, c.id))
		if c.post != "":
			add.call("Remove from the council", func(): city.remove_from_council(c.id); _refresh())
		add.call("Dismiss from the crew", func(): _on_dismiss_pressed(c.id); _on_dismiss_pressed(c.id), "Out on a venture" if city.leader_busy(c) else "")
	elif alive and f and c.faction_id != me:
		var fid = c.faction_id
		add.call("Diplomacy with the %s" % f.display_name, func(): _open_faction_panel(fid))
		# The proposals themselves, with their odds or why not (as CK's right-click on a ruler)
		for action_id in GameData.diplomacy_actions():
			var def = GameData.diplomacy_action(action_id)
			if action_id == "integrate" and city.relation(me, fid).overlord != me:
				continue
			var err = Diplomacy.check_action(city, action_id, me, fid)
			var label: String = def["label"]
			if err == "" and def["kind"] != "gift":
				label += "  (%d%%)" % (Diplomacy.acceptance(city, action_id, me, fid)["chance"] * 100)
			var a_id = action_id
			add.call(label, func(): _on_diplomacy_pressed(a_id, fid), err)
	character_menu.reset_size()
	character_menu.position = Vector2i(at)
	character_menu.popup()
