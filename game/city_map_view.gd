class_name CityMapView
extends Control

# The city map. Layers, bottom to top:
#   art      - the procedural city (MapArt), drawn once
#   overlay  - faction colours, borders, selection; redrawn as the world changes
#   water    - the river and bridges, above the colours so it always reads as water
#   screen   - labels, markers, routes and the legend, in screen space so text stays crisp
# The first three sit inside `world`, which the camera moves and scales.
# Controls: scroll to zoom, drag (left or middle) or WASD/arrow keys to pan.

signal district_clicked(district: District)
signal district_right_clicked(district: District, screen_pos: Vector2)

const CALM_COLOR = Color(0.25, 0.55, 0.3)
const ANGRY_COLOR = Color(0.9, 0.2, 0.15)
const BUILDING_COLOR = Color(0.9, 0.78, 0.42)
const TRADE_COLOR = Color(0.95, 0.8, 0.3)
const ALLIANCE_COLOR = Color(0.6, 0.85, 1.0)
const UNCLAIMED_COLOR = Color(0.45, 0.42, 0.38)
const LABEL_SIZE = 12

const ZOOM_MAX = 6.0
const ZOOM_STEP = 1.15
# Below this zoom the map shows borough names; above it, district names and details
const DISTRICT_LABEL_ZOOM = 0.62
const DRAG_THRESHOLD = 6.0
const KEY_PAN_SPEED = 700.0

var city: CityMap
var selected: District = null
var hovered: District = null
var show_heat: bool = false
# Full fog: you only see your land, the land next to it, and what you've scouted
var full_fog: bool = false
# Picking a district for a councillor's task: eligible district id -> the stat to show on it (empty when not picking)
var pick_labels: Dictionary = {}
# Where the frame's panels sit over the map (left, bottom, right), so the legend stays visible
var legend_margin: Vector3 = Vector3.ZERO
var show_legend: bool = true
# Two-letter codes for the rings on the map (several ventures share a first letter); hover a district for names
const VENTURE_CODES = {"secure_food": "Fd", "safeguard": "Sg", "gather_weapons": "Wp", "scavenge": "Sv", "scout": "Sc",
	"settle": "St", "rebuild": "Rb", "reinforce": "Gd", "negotiate": "Ng", "raid": "Ra", "assault": "As", "trade": "Tr",
	"agitation": "Ag", "relief": "Rl"}

var world: Node2D
var art_layer: MapPainter
var overlay_layer: MapPainter
var life_layer: MapPainter
var water_layer: MapPainter
var screen_layer: MapPainter
var art: MapArt

var zoom: float = 1.0
var zoom_min: float = 0.2
var pan: Vector2 = Vector2.ZERO
var city_bounds: Rect2
var fitted: bool = false
var drag_start = null
var dragging: bool = false
# Shared border segments between touching districts: [a_id, b_id, from, to]
var shared_edges: Array = []

func _ready():
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	world = Node2D.new()
	add_child(world)
	art_layer = _layer(world, func(canvas): if art: art.draw_ground(canvas))
	# The project defaults to pixel-art filtering; the map art is smooth
	art_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	overlay_layer = _layer(world, _draw_overlay)
	life_layer = _layer(world, _draw_life)
	water_layer = _layer(world, func(canvas): if art: art.draw_water(canvas))
	screen_layer = _layer(self, _draw_screen)
	resized.connect(_on_resized)

func _layer(parent: Node, paint: Callable) -> MapPainter:
	var layer = MapPainter.new()
	layer.paint = paint
	parent.add_child(layer)
	return layer

func set_city(new_city: CityMap):
	city = new_city
	art = MapArt.build(city)
	_compute_bounds()
	_compute_shared_edges()
	art_layer.queue_redraw()
	water_layer.queue_redraw()
	if not fitted and size.x > 0.0:
		fit()
	refresh()

# Redraws what changes with the world (called whenever the game state changes)
func refresh():
	overlay_layer.queue_redraw()
	life_layer.queue_redraw()
	screen_layer.queue_redraw()

# --- Camera -------------------------------------------------------------------------

func fit():
	zoom_min = minf(size.x / city_bounds.size.x, size.y / city_bounds.size.y) * 0.95
	zoom = zoom_min
	pan = size * 0.5 - city_bounds.get_center() * zoom
	fitted = true
	_apply_camera()

func _on_resized():
	if city == null:
		return
	# Until the player zooms in, keep the whole city fitted as the layout settles
	if not fitted or is_equal_approx(zoom, zoom_min):
		fit()
	else:
		zoom_min = minf(size.x / city_bounds.size.x, size.y / city_bounds.size.y) * 0.95
		_apply_camera()

func _zoom_at(screen_pos: Vector2, factor: float):
	var before = to_map(screen_pos)
	zoom = clampf(zoom * factor, zoom_min, ZOOM_MAX)
	pan = screen_pos - before * zoom
	_apply_camera()

# Keeps the city in view, then moves the world layers
func _apply_camera():
	var shown = Rect2(city_bounds.position * zoom + pan, city_bounds.size * zoom)
	var margin = size * 0.4
	if shown.end.x < margin.x:
		pan.x += margin.x - shown.end.x
	if shown.position.x > size.x - margin.x:
		pan.x -= shown.position.x - (size.x - margin.x)
	if shown.end.y < margin.y:
		pan.y += margin.y - shown.end.y
	if shown.position.y > size.y - margin.y:
		pan.y -= shown.position.y - (size.y - margin.y)
	world.position = pan
	world.scale = Vector2(zoom, zoom)
	screen_layer.queue_redraw()
	overlay_layer.queue_redraw()

func to_map(screen_pos: Vector2) -> Vector2:
	return (screen_pos - pan) / zoom

func to_screen(map_pos: Vector2) -> Vector2:
	return map_pos * zoom + pan

func _process(delta: float):
	if city == null or not is_visible_in_tree():
		return
	var move = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x += 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x -= 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y -= 1
	if move != Vector2.ZERO:
		pan += move * KEY_PAN_SPEED * delta
		_apply_camera()

# --- Input --------------------------------------------------------------------------

func district_at(screen_pos: Vector2) -> District:
	var map_pos = to_map(screen_pos)
	for d in city.districts:
		if Geometry2D.is_point_in_polygon(map_pos, d.polygon):
			return d
	return null

func _gui_input(event: InputEvent):
	if city == null:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
					accept_event()
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					drag_start = event.position
					dragging = event.button_index == MOUSE_BUTTON_MIDDLE
				else:
					# A left press that didn't turn into a drag is a click
					if event.button_index == MOUSE_BUTTON_LEFT and not dragging:
						var d = district_at(event.position)
						if d:
							district_clicked.emit(d)
					drag_start = null
					dragging = false
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					var d = district_at(event.position)
					if d:
						district_right_clicked.emit(d, get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if drag_start != null:
			if not dragging and event.position.distance_to(drag_start) > DRAG_THRESHOLD:
				dragging = true
			if dragging:
				pan += event.relative
				_apply_camera()
		var d = district_at(event.position)
		if d != hovered:
			hovered = d
			tooltip_text = _tooltip_for(d)
			overlay_layer.queue_redraw()

func _tooltip_for(d: District) -> String:
	if not d:
		return ""
	if _hidden(d):
		return "Unknown ground\nScout toward it to see who's there."
	var shares = []
	for fid in city.factions:
		if d.share(fid) >= 1.0:
			shares.append("%s %d%%" % ["You" if fid == city.player_id else city.faction_name(fid), d.share(fid)])
	var owner = d.owner_id()
	var hint = "\nRight-click for diplomacy with the %s" % city.faction_name(owner) if owner != "" and owner != city.player_id else ""
	# What's under way here, by whom
	for v in city.ventures:
		if v.district == d:
			hint += "\n%s: %s (%s), %d days left" % [VENTURE_CODES.get(v.venture_id, "?"), GameData.venture(v.venture_id)["label"],
				"you" if v.faction_id == city.player_id else city.faction_name(v.faction_id), v.days_left]
	return "%s (%s, %s)\n%s: %s\n%s\nGrievance %d%s" % [
		d.district_name, GameData.district_type(d.district_type)["label"], d.borough, d.get_control_status().capitalize(),
		", ".join(shares) if shares.size() > 0 else "nobody holds influence here",
		GameData.district_type(d.district_type)["description"], d.grievance, hint
	]

# --- Overlay: faction colours and borders ------------------------------------------------

func _draw_overlay(canvas: CanvasItem):
	if city == null:
		return
	for d in city.districts:
		if _hidden(d):
			canvas.draw_colored_polygon(d.polygon, Color(0.02, 0.02, 0.03, 0.85))
			continue
		var wash = _wash(d)
		if d == hovered:
			wash = Color(wash.r, wash.g, wash.b, wash.a + 0.12).lightened(0.15)
		if wash.a > 0.0:
			canvas.draw_colored_polygon(d.polygon, wash)
		if not show_heat and not city.can_reach(city.player_id, d):
			canvas.draw_colored_polygon(d.polygon, Color(0, 0, 0, 0.3))
	# Thin district lines everywhere; heavy borders where ownership changes
	for d in city.districts:
		canvas.draw_polyline(_closed(d.polygon), Color(0, 0, 0, 0.35), 1.2 / zoom)
	for edge in shared_edges:
		if _hidden(city.districts[edge[0]]) or _hidden(city.districts[edge[1]]):
			continue
		if city.districts[edge[0]].owner_id() != city.districts[edge[1]].owner_id():
			canvas.draw_line(edge[2], edge[3], Color(0.03, 0.03, 0.03, 0.9), 4.0 / zoom)
	for d in city.districts:
		var owner = d.owner_id()
		if owner != "" and not show_heat and not _hidden(d):
			canvas.draw_polyline(_closed(d.polygon), city.factions[owner].color.lightened(0.1), 2.5 / zoom)
	for id in pick_labels:
		canvas.draw_polyline(_closed(city.districts[id].polygon), Color(0.95, 0.78, 0.35), 3.5 / zoom)
	if selected:
		canvas.draw_polyline(_closed(selected.polygon), Color.WHITE, 3.0 / zoom)

# --- Life: who lives where, and what they've built ------------------------------------------

# Owned districts show their people: faction flags on the rooftops (more when secured), campfires,
# gardens as the district develops, and each building as a structure in the streets.
# Drawn in map units, so it all comes into view as you zoom in.
const BUILDING_SLOTS = [Vector2(-34, 24), Vector2(34, 24), Vector2(0, 44)]

func _draw_life(canvas: CanvasItem):
	if city == null or art == null:
		return
	for d in city.districts:
		if _hidden(d):
			continue
		var owner = d.owner_id()
		var rng = RandomNumberGenerator.new()
		rng.seed = d.id * 104729 + 7
		if owner != "":
			var color: Color = city.factions[owner].color
			var flags = 1 + (1 if d.get_control_status() == "secured" else 0) + (1 if city.capital_of(owner) == d.id else 0)
			for k in flags:
				_flag(canvas, _spot(rng, d, 40.0), color)
			if d.population > 60.0:
				for k in 1 + int(d.population / 80.0):
					var p = _spot(rng, d, 50.0)
					canvas.draw_circle(p, 5.0, Color(1.0, 0.5, 0.15, 0.18))
					canvas.draw_circle(p, 1.6, Color(1.0, 0.7, 0.3, 0.95))
			for k in int(d.development * 4.0):
				var p = _spot(rng, d, 45.0)
				for row in 3:
					canvas.draw_rect(Rect2(p + Vector2(0, row * 3.0), Vector2(10, 2)), Color(0.33, 0.45, 0.2, 0.9))
		var slot = 0
		for building_id in d.buildings:
			_structure(canvas, building_id, _slot_position(d, slot), 1.0, owner)
			slot += 1
		for c in city.constructions_at(d):
			_structure(canvas, c.building_id, _slot_position(d, slot), c.progress(), c.faction_id)
			slot += 1

func _spot(rng: RandomNumberGenerator, d: District, radius: float) -> Vector2:
	for attempt in 10:
		var p = d.center + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		if Geometry2D.is_point_in_polygon(p, d.polygon):
			return p
	return d.center

func _slot_position(d: District, slot: int) -> Vector2:
	var p = d.center + BUILDING_SLOTS[slot % BUILDING_SLOTS.size()]
	return p if Geometry2D.is_point_in_polygon(p, d.polygon) else d.center + BUILDING_SLOTS[slot % BUILDING_SLOTS.size()] * 0.5

func _flag(canvas: CanvasItem, at: Vector2, color: Color):
	canvas.draw_line(at, at + Vector2(0, -8), Color(0.1, 0.1, 0.1), 0.8)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -8), at + Vector2(6, -6.5), at + Vector2(0, -5)]), color.lightened(0.15))

# A structure for each building type, drawn as solids like the rest of the city; under
# construction it's a scaffold that rises as work progresses
func _structure(canvas: CanvasItem, building_id: String, at: Vector2, progress: float, owner: String):
	var parts = []
	var box = func(center: Vector2, size: Vector2, height: float, color: Color):
		var footprint = PackedVector2Array([center - size * 0.5, center + Vector2(size.x, -size.y) * 0.5, center + size * 0.5, center + Vector2(-size.x, size.y) * 0.5])
		canvas.draw_colored_polygon(_moved(footprint, MapArt.SHADOW_DIR * height * MapArt.HEIGHT_SCALE * 0.6), Color(0, 0, 0, 0.35))
		parts.append_array(MapArt.prism_parts(footprint, height, color))
	var on_top = func(center: Vector2, size: Vector2, height: float, color: Color):
		var footprint = PackedVector2Array([center - size * 0.5, center + Vector2(size.x, -size.y) * 0.5, center + size * 0.5, center + Vector2(-size.x, size.y) * 0.5])
		parts.append([0, MapArt.lifted(footprint, height), color, 0.0])
	if progress < 1.0:
		var height = 3.0 * progress
		box.call(at, Vector2(22, 16), maxf(height, 0.1), Color(0.55, 0.5, 0.42))
		# Scaffold poles standing to the full height
		for x in [-11.0, 0.0, 11.0]:
			parts.append([1, PackedVector2Array([at + Vector2(x, 8), at + Vector2(x, 8) + MapArt.UP * 3.0 * MapArt.HEIGHT_SCALE]), Color(0.8, 0.66, 0.32), 0.8])
		MapArt.draw_parts(canvas, parts)
		return
	var faction_color: Color = city.factions[owner].color if city.factions.has(owner) else Color.GRAY
	match building_id:
		"market":
			canvas.draw_rect(Rect2(at - Vector2(16, 12), Vector2(32, 24)), Color(0.42, 0.4, 0.37))
			var awnings = [Color("#b0503a"), Color("#d9a13b"), Color("#4a7a8a"), Color("#8a9a4a"), Color("#b0503a"), Color("#4a7a8a")]
			for k in 6:
				box.call(at + Vector2(-9 + (k % 3) * 9, -5 + int(k / 3.0) * 11), Vector2(7, 5), 0.9, awnings[k])
		"watchtower":
			box.call(at, Vector2(8, 8), 7.0, Color(0.45, 0.38, 0.3))
			on_top.call(at, Vector2(10, 10), 7.0, Color(0.55, 0.47, 0.37))
			var top = at + MapArt.UP * 7.0 * MapArt.HEIGHT_SCALE
			parts.append([1, PackedVector2Array([top, top + Vector2(0, -9)]), Color(0.1, 0.1, 0.1), 0.8])
			parts.append([0, PackedVector2Array([top + Vector2(0, -9), top + Vector2(7, -7.5), top + Vector2(0, -6)]), faction_color.lightened(0.15), 0.0])
		"clinic":
			box.call(at, Vector2(20, 14), 2.5, Color(0.82, 0.8, 0.76))
			on_top.call(at, Vector2(8, 2.4), 2.5, Color("#b83a30"))
			on_top.call(at, Vector2(2.4, 8), 2.5, Color("#b83a30"))
		"salvage_yard":
			for k in 5:
				var p = at + Vector2((k % 3) * 8 - 8, int(k / 3.0) * 8 - 4)
				box.call(p, Vector2(7, 6), 0.6 + (k % 2) * 0.4, [Color("#6e4a36"), Color("#5a5650"), Color("#7a6a55")][k % 3])
			parts.append([1, PackedVector2Array([at + Vector2(12, 6), at + Vector2(12, 6) + MapArt.UP * 24, at + Vector2(-2, -14)]), Color("#b89a45"), 1.4])
		"hostel":
			box.call(at, Vector2(30, 10), 3.2, Color(0.55, 0.46, 0.4))
			for k in 6:
				# Lit windows along the south wall
				var w = at + Vector2(-13 + k * 5, 5) + MapArt.UP * 6.0
				parts.append([0, PackedVector2Array([w, w + Vector2(2.2, 0), w + Vector2(2.2, -2.5), w + Vector2(0, -2.5)]), Color(1.0, 0.8, 0.45), 0.0])
		"workshop":
			box.call(at, Vector2(26, 16), 2.2, Color(0.5, 0.48, 0.44))
			# A sawtooth roof: north-light factory glazing
			var base = at + MapArt.UP * 2.2 * MapArt.HEIGHT_SCALE
			for k in 4:
				var x = -13 + k * 6.5
				parts.append([0, PackedVector2Array([base + Vector2(x, 8), base + Vector2(x + 6.5, 8) + MapArt.UP * 5, base + Vector2(x + 6.5, -8) + MapArt.UP * 5, base + Vector2(x, -8)]), Color(0.6, 0.58, 0.54), 0.0])
				parts.append([0, PackedVector2Array([base + Vector2(x + 6.5, 8), base + Vector2(x + 6.5, 8) + MapArt.UP * 5, base + Vector2(x + 6.5, -8) + MapArt.UP * 5, base + Vector2(x + 6.5, -8)]), Color(0.45, 0.55, 0.6), 0.0])
			parts.append([2, [base + Vector2(9, -12), 1.5], Color(1.0, 0.8, 0.3), 0.0])
		_:
			box.call(at, Vector2(16, 16), 2.0, Color(0.5, 0.5, 0.5))
	MapArt.draw_parts(canvas, parts)

static func _moved(poly: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out = PackedVector2Array()
	for p in poly:
		out.append(p + offset)
	return out

# HOI4-style see-through colour: owned land is washed in its faction's colour, stronger when
# secured; unclaimed land shows a faint tint of whoever is working on claiming it
func _wash(d: District) -> Color:
	if show_heat:
		var c = CALM_COLOR.lerp(ANGRY_COLOR, d.grievance / 100.0)
		return Color(c.r, c.g, c.b, 0.55)
	var owner = d.owner_id()
	if owner != "":
		var c: Color = city.factions[owner].color
		return Color(c.r, c.g, c.b, (0.5 if d.get_control_status() == "secured" else 0.36) * _wash_fade())
	var tint = Color(0, 0, 0, 0)
	for fid in city.factions:
		var s = d.share(fid) / 100.0
		if s > 0.0:
			var c: Color = city.factions[fid].color
			tint = Color(c.r, c.g, c.b, maxf(tint.a, s * 0.4 * _wash_fade()))
	return tint

# Zoomed in, the colours thin out so the streets and buildings underneath show through
func _wash_fade() -> float:
	return lerpf(1.0, 0.12, clampf((zoom - DISTRICT_LABEL_ZOOM) / 1.8, 0.0, 1.0))

func _compute_bounds():
	var boundary = MapArt._points(GameData.map()["boundary"])
	var lo = boundary[0]
	var hi = boundary[0]
	for p in boundary:
		lo = lo.min(p)
		hi = hi.max(p)
	city_bounds = Rect2(lo, hi - lo).grow(40.0)

func _compute_shared_edges():
	shared_edges.clear()
	for a in city.districts:
		for b in city.districts:
			if b.id <= a.id:
				continue
			var shared = []
			for v in a.polygon:
				for k in b.polygon.size():
					var q = b.polygon[(k + 1) % b.polygon.size()]
					if Geometry2D.get_closest_point_to_segment(v, b.polygon[k], q).distance_to(v) < 1.0:
						shared.append(v)
						break
			if shared.size() >= 2:
				shared_edges.append([a.id, b.id, shared[0], shared[shared.size() - 1]])

# --- Screen layer: labels, markers, routes, legend ----------------------------------------

func _draw_screen(canvas: CanvasItem):
	if city == null:
		return
	var font = get_theme_default_font()
	_draw_connections(canvas)
	if zoom < DISTRICT_LABEL_ZOOM:
		_draw_faction_labels(canvas, font)
	else:
		for d in city.districts:
			var pos = to_screen(d.center)
			if Rect2(Vector2.ZERO, size).grow(60).has_point(pos) and not _hidden(d):
				_label(canvas, font, pos, d.district_name, LABEL_SIZE, Color(0.97, 0.97, 0.97))
				_label(canvas, font, pos + Vector2(0, 13), _status_label(d), LABEL_SIZE - 2, Color(0.82, 0.82, 0.82))
		# Up close the buildings are drawn in the streets; tiles only help at middle zoom
		if zoom < 1.6:
			_draw_buildings(canvas, font)
	if selected and zoom < DISTRICT_LABEL_ZOOM:
		_label(canvas, font, to_screen(selected.center) + Vector2(0, 20), selected.district_name, LABEL_SIZE, Color.WHITE)
	for id in pick_labels:
		_label(canvas, font, to_screen(city.districts[id].center) + Vector2(0, 30), pick_labels[id], LABEL_SIZE, Color(0.95, 0.8, 0.4))
	_draw_ventures(canvas, font)
	_draw_legend(canvas, font)

# Zoomed out, each faction's name sits over its land (HOI4-style), bigger for bigger factions.
# One label per connected block of land: the main one, plus any cut-off block of 3+ districts.
# Borough names moved to the district hover; showing both here would stack two labels on the same land.
func _draw_faction_labels(canvas: CanvasItem, font: Font):
	var fade = clampf((DISTRICT_LABEL_ZOOM - zoom) / 0.15, 0.8, 1.0)
	for fid in city.factions:
		var f: Faction = city.factions[fid]
		var blocks = _land_blocks(fid)
		blocks.sort_custom(func(a, b): return a.size() > b.size())
		for i in blocks.size():
			var block: Array = blocks[i]
			if i > 0 and block.size() < 3:
				break
			var seen = block.filter(func(d): return not _hidden(d))
			if seen.is_empty():
				continue
			var center = Vector2.ZERO
			for d in seen:
				center += d.center
			var font_size = mini(24, 12 + int(3.0 * sqrt(block.size())))
			_label(canvas, font, to_screen(center / seen.size()), f.display_name, font_size, Color(f.color.lightened(0.55), 0.95 * fade))

# A faction's land split into blocks of districts that touch each other
func _land_blocks(faction_id: String) -> Array:
	var blocks = []
	var placed = {}
	for d in city.districts:
		if d.owner_id() != faction_id or placed.has(d.id):
			continue
		var block = []
		var frontier = [d]
		placed[d.id] = true
		while not frontier.is_empty():
			var current: District = frontier.pop_back()
			block.append(current)
			for n_id in current.neighbor_ids:
				var n: District = city.districts[n_id]
				if not placed.has(n_id) and n.owner_id() == faction_id:
					placed[n_id] = true
					frontier.append(n)
		blocks.append(block)
	return blocks

func _status_label(d: District) -> String:
	var owner = d.owner_id()
	if owner != "":
		return d.get_control_status().capitalize()
	if not city.knows(city.player_id, d):
		return "Unscouted"
	var best = 0.0
	for fid in city.factions:
		best = maxf(best, d.share(fid))
	return "Unclaimed" if best < 1.0 else "Claiming %d/%d" % [best, GameData.rule("claim_threshold")]

func _label(canvas: CanvasItem, font: Font, pos: Vector2, text: String, font_size: int, color: Color):
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin = pos - Vector2(width * 0.5, 0)
	canvas.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.75 * color.a))
	canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

# Trade routes (gold) and alliances (pale blue) between capitals; capitals get a marker
func _draw_connections(canvas: CanvasItem):
	for r in city.relations.values():
		if not (r.trade or r.alliance):
			continue
		var a = city.capital_of(r.a)
		var b = city.capital_of(r.b)
		if a < 0 or b < 0 or _hidden(city.districts[a]) or _hidden(city.districts[b]):
			continue
		var from = to_screen(city.districts[a].center)
		var to = to_screen(city.districts[b].center)
		if r.trade:
			canvas.draw_line(from, to, Color(0, 0, 0, 0.5), 5.0)
			canvas.draw_dashed_line(from, to, TRADE_COLOR, 3.0, 10.0)
		if r.alliance:
			var offset = (to - from).orthogonal().normalized() * 5.0
			canvas.draw_dashed_line(from + offset, to + offset, ALLIANCE_COLOR, 2.0, 6.0)
	for fid in city.factions:
		var capital = city.capital_of(fid)
		if capital >= 0 and not _hidden(city.districts[capital]):
			var pos = to_screen(city.districts[capital].center) + Vector2(0, -18)
			canvas.draw_circle(pos, 7.0, Color.WHITE)
			canvas.draw_circle(pos, 5.0, city.factions[fid].color)

# Buildings are small lettered tiles; ones under construction fill up as they progress
func _draw_buildings(canvas: CanvasItem, font: Font):
	for d in city.districts:
		var items = []
		for building_id in d.buildings:
			items.append([GameData.building(building_id).get("icon", "?"), 1.0])
		for c in city.constructions_at(d):
			items.append([GameData.building(c.building_id).get("icon", "?"), c.progress()])
		if items.is_empty() or _hidden(d):
			continue
		var dimmed = not city.buildings_active(d)
		var start = to_screen(d.center) + Vector2(-items.size() * 8.0, 19)
		for i in items.size():
			var rect = Rect2(start + Vector2(i * 16, 0), Vector2(14, 14))
			var built = items[i][1] >= 1.0
			canvas.draw_rect(rect, Color(0.05, 0.05, 0.06, 0.85))
			var fill_height = rect.size.y * items[i][1]
			var fill = BUILDING_COLOR.darkened(0.5) if dimmed else BUILDING_COLOR
			fill.a = 0.95 if built else 0.5
			canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - fill_height), Vector2(rect.size.x, fill_height)), fill)
			if not built:
				canvas.draw_rect(rect, BUILDING_COLOR, false, 1.0)
			canvas.draw_string(font, rect.position + Vector2(3, 11), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.08, 0.08))

# Each venture under way is a ring that fills as it nears completion
func _draw_ventures(canvas: CanvasItem, font: Font):
	var slots = {}
	var radius = 10.0 if zoom >= DISTRICT_LABEL_ZOOM else 7.0
	var below = 48.0 if zoom >= DISTRICT_LABEL_ZOOM else 10.0
	for v in city.ventures:
		if _hidden(v.district):
			continue
		var n = slots.get(v.district.id, 0)
		slots[v.district.id] = n + 1
		var pos = to_screen(v.district.center) + Vector2(-radius + n * radius * 2.2, below)
		var color = city.factions[v.faction_id].color
		# Attacks on you get a red warning ring around the district marker
		if v.target_id == city.player_id and GameData.venture(v.venture_id).get("hostile", false):
			canvas.draw_arc(pos, radius + 5.0, 0.0, TAU, 32, Color(1.0, 0.25, 0.2, 0.9), 3.0)
			canvas.draw_arc(to_screen(v.district.center), 26.0, 0.0, TAU, 40, Color(1.0, 0.25, 0.2, 0.7), 2.0)
		canvas.draw_circle(pos, radius, Color(0.05, 0.05, 0.06, 0.9))
		canvas.draw_arc(pos, radius, -PI / 2, -PI / 2 + TAU * maxf(v.progress(), 0.02), 24, color.lightened(0.2), 3.0)
		if radius >= 10.0:
			var code: String = VENTURE_CODES.get(v.venture_id, GameData.venture(v.venture_id)["label"].substr(0, 2))
			canvas.draw_string(font, pos + Vector2(-7, 4), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _draw_legend(canvas: CanvasItem, font: Font):
	# Two rows: factions on top, map keys below. Entries are [colour, label, is_line]
	var rows = []
	if show_heat:
		rows.append([[CALM_COLOR, "Calm", false], [CALM_COLOR.lerp(ANGRY_COLOR, 0.5), "Restless", false], [ANGRY_COLOR, "Revolt risk", false]])
	else:
		# Big factions on one row, minor ones on the next
		var faction_row = []
		var minor_row = []
		for f in city.factions.values():
			(minor_row if f.minor else faction_row).append([f.color, f.display_name + (" (you)" if f.id == city.player_id else ""), false])
		rows.append(faction_row)
		if not minor_row.is_empty():
			rows.append(minor_row)
		rows.append([[UNCLAIMED_COLOR, "Unclaimed", false], [Color(0.15, 0.15, 0.15), "Out of reach", false],
			[TRADE_COLOR, "Trade route", true], [ALLIANCE_COLOR, "Alliance", true]])
	rows.append([[Color(0, 0, 0, 0), "Scroll: zoom  ·  Drag or WASD: pan  ·  Right-click a faction: diplomacy", false]])
	if not show_legend:
		return
	var y = size.y - legend_margin.y - 12 - (rows.size() - 1) * 16
	canvas.draw_rect(Rect2(Vector2(legend_margin.x + 4, y - 16), Vector2(size.x - legend_margin.x - legend_margin.z - 8, rows.size() * 16 + 8)), Color(0.06, 0.06, 0.07, 0.8))
	for row in rows:
		var pos = Vector2(legend_margin.x + 10, y)
		for entry in row:
			if entry[2]:
				canvas.draw_dashed_line(pos + Vector2(0, -5), pos + Vector2(14, -5), entry[0], 3.0, 4.0)
			elif entry[0].a > 0.0:
				canvas.draw_rect(Rect2(pos + Vector2(0, -11), Vector2(12, 12)), entry[0])
			var text_x = 18 if entry[0].a > 0.0 or entry[2] else 0
			canvas.draw_string(font, pos + Vector2(text_x, 0), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))
			pos.x += 32 + font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		y += 16

static func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out = poly.duplicate()
	out.append(poly[0])
	return out

# Under full fog, districts you neither hold, border nor have scouted are unknown
func _hidden(d: District) -> bool:
	return full_fog and city != null and not city.sees(city.player_id, d)

# Moves the camera so a district is in the middle of the screen (for outliner and alert links)
func center_on(d: District):
	pan = size * 0.5 - d.center * zoom
	_apply_camera()
	refresh()
