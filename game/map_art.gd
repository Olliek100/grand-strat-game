class_name MapArt

# Procedural post-apocalyptic city art, drawn as 2.5D: the camera looks down on the city tilted
# slightly from the south, so every building is a solid: its south-facing walls are visible and
# its roof sits "up" the screen by its height. Solids are drawn back to front so nearer
# buildings overlap farther ones.
# Also: wasteland with forests, farmland and a railway, streets with wrecked cars, ruins,
# landmarks that match district names, the river and bridges.
# Built once from the layout into lists of shapes; the map's layers draw them.
# Purely visual: nothing here affects play.

const WASTELAND_DARK = Color("#221f1a")
const WASTELAND_LIGHT = Color("#453d30")
const WASTELAND_GREEN = Color("#30372a")
const WATER_BANK = Color("#141d23")
const WATER = Color("#253d4a")
const WATER_SHINE = Color("#2f4d5c")
const ROAD_EDGE = Color("#2a2824")
const ROAD = Color("#5a564d")
const ROAD_MARK = Color("#8a8064")
const RAIL_BED = Color("#2e2a26")
const RAIL = Color("#77706a")
const BRIDGE = Color("#8d877b")
const BRIDGE_EDGE = Color("#2a2824")
const TREE = Color("#2c4527")
const GRASS = Color("#3c5432")
const CONCRETE = Color("#8b867c")
const PAVING = Color("#6a665e")
const RUBBLE = Color("#56504a")
const RUST = Color("#6e4a36")
const OVERGROWTH = Color(0.3, 0.45, 0.22, 0.2)
const SCORCH = Color(0.06, 0.05, 0.04, 0.5)
const SHADOW = Color(0, 0, 0, 0.35)
const FIELD_COLORS = ["#4a5530", "#5b5634", "#3f4a2c", "#6a5f3a", "#51502f"]
const CAR_COLORS = ["#6b3b30", "#7a6f5f", "#3f4f5c", "#8a8578", "#5a5f3e", "#2b2826"]

# The illusion of height: one unit of building height lifts its roof this far up the screen
const UP = Vector2(0, -1)
const HEIGHT_SCALE = 4.0
# Light comes from the top left, so shadows fall down and to the right
const SHADOW_DIR = Vector2(0.7, 0.55)

# Landmarks by district name; districts without one get a landmark typical of their type
const NAMED_LANDMARKS = {
	"Stadium": "stadium", "Racecourse": "racecourse", "Power Station": "cooling_towers", "Gasworks": "gas_holders",
	"Water Works": "tanks", "Sewage Works": "tanks", "Chemical Works": "tanks", "Cathedral Quarter": "cathedral",
	"Church Lane": "church", "Chapel Street": "church", "Cemetery": "cemetery", "Cemetery Road": "cemetery",
	"Allotments": "allotments", "Agricultural Belt": "allotments", "Rail Yards": "rail", "Freight Yard": "rail",
	"Airfield": "runway", "Hospital Hill": "hospital", "Harbour": "cranes", "South Docks": "cranes", "Coal Wharf": "cranes",
	"Quarry": "quarry", "Landfill": "landfill", "Clock Tower": "tower", "Tower Blocks": "tower_blocks",
	"Retail Park": "retail", "Golf Links": "golf", "Memorial Park": "pond", "Botanic Gardens": "pond", "The Common": "pond",
	"Market Square": "plaza", "Guildhall": "plaza", "Civic Centre": "plaza", "Pylon Fields": "pylons",
	"Steelworks": "chimneys", "Brickfields": "chimneys", "Foundry Lane": "chimneys", "Barracks": "barracks",
	"Checkpoint": "camp", "Nomad Camp": "camp", "University Row": "quad", "Council Estate": "tower_blocks",
}
const TYPE_LANDMARKS = {
	"downtown": ["tower", "plaza", "tower_blocks"], "industrial": ["chimneys", "tanks", "rail"], "docks": ["cranes"],
	"park": ["pond", "cemetery", "allotments"], "suburb": ["retail", "church", ""], "outskirts": ["camp", "landfill", "pylons"],
	"residential": ["church", "quad", "", ""],
}

var map_size: Vector2
var ground_texture: Texture2D
var wasteland: Array = []        # [PackedVector2Array, Color]: fields and ruins outside the city
var ground: Array = []           # [PackedVector2Array, Color]
var streets: Array = []          # [PackedVector2Array, Color, width]
var roads: Array = []            # [PackedVector2Array, Color, width]
var road_marks: Array = []       # [Vector2, Vector2]
var rails: Array = []            # [PackedVector2Array, Color, width]
var flats: Array = []            # [PackedVector2Array, Color]: ground-level features (plots, paving, cars)
var shadows: Array = []          # [PackedVector2Array, Color]
var details: Array = []          # [Vector2, radius, Color]: rubble, overgrowth, scorch
# Everything with height, sorted back to front: [kind, data, color, width]
# kind 0 = polygon, 1 = polyline, 2 = circle (data = [center, radius])
var solids: Array = []
var river: PackedVector2Array
var bridges: Array = []          # [PackedVector2Array, Color]
# Where each district's landmark stands (district id -> Vector2)
var landmark_spots: Dictionary = {}

# Solids waiting to be sorted: [depth, parts]; the latest one can take features on its top
var _pending: Array = []
var _last: Array = []
var _last_height: float = 0.0

static func build(city: CityMap) -> MapArt:
	var art = MapArt.new()
	art._build(city)
	return art

func _build(city: CityMap):
	var layout = GameData.map()
	map_size = city.map_size
	var map_seed = int(layout["seed"])
	ground_texture = _wasteland_texture(map_seed)
	river = _smooth(_points(layout["river"]), 3)

	# Buildings keep clear of the river, the railway and the main roads
	var avoid = []
	for k in river.size() - 1:
		avoid.append([river[k], river[k + 1], 18.0])
	for pair in layout["roads"]:
		var a = city.districts[int(pair[0])].center
		var b = city.districts[int(pair[1])].center
		avoid.append([a, b, 7.0])
		roads.append([PackedVector2Array([a, b]), ROAD_EDGE, 9.0])
		roads.append([PackedVector2Array([a, b]), ROAD, 6.0])
		road_marks.append([a, b])
	var railway = _railway(city, map_seed)
	for k in railway.size() - 1:
		avoid.append([railway[k], railway[k + 1], 9.0])

	var boundary = _points(layout["boundary"])
	_build_wasteland(boundary, map_seed)
	for d in city.districts:
		_build_district(d, avoid)
	for b in layout["bridges"]:
		_build_bridge(Vector2(b["x"], b["y"]))

	# Back to front: whatever stands further south is nearer the camera
	_pending.sort_custom(func(x, y): return x[0] < y[0])
	for entry in _pending:
		solids.append_array(entry[1])
	_pending.clear()

func draw_ground(canvas: CanvasItem):
	canvas.draw_texture_rect(ground_texture, Rect2(Vector2.ZERO, map_size), false)
	for item in wasteland:
		canvas.draw_colored_polygon(item[0], item[1])
	for item in ground:
		canvas.draw_colored_polygon(item[0], item[1])
	for item in streets:
		canvas.draw_polyline(item[0], item[1], item[2])
	for item in roads:
		canvas.draw_polyline(item[0], item[1], item[2])
	for mark in road_marks:
		canvas.draw_dashed_line(mark[0], mark[1], ROAD_MARK, 0.8, 5.0)
	for item in rails:
		canvas.draw_polyline(item[0], item[1], item[2])
	for item in flats:
		canvas.draw_colored_polygon(item[0], item[1])
	for item in details:
		canvas.draw_circle(item[0], item[1], item[2])
	for item in shadows:
		canvas.draw_colored_polygon(item[0], item[1])
	draw_parts(canvas, solids)

# Water sits above the faction colours so the river always reads as a river
func draw_water(canvas: CanvasItem):
	if river.size() < 2:
		return
	canvas.draw_polyline(river, WATER_BANK, 30.0, true)
	canvas.draw_polyline(river, WATER, 22.0, true)
	canvas.draw_polyline(river, WATER_SHINE, 6.0, true)
	for item in bridges:
		canvas.draw_colored_polygon(item[0], item[1])

static func draw_parts(canvas: CanvasItem, parts: Array):
	for part in parts:
		match part[0]:
			0:
				canvas.draw_colored_polygon(part[1], part[2])
			1:
				canvas.draw_polyline(part[1], part[2], part[3])
			2:
				canvas.draw_circle(part[1][0], part[1][1], part[2])

# --- Solids -------------------------------------------------------------------------

# The faces of a solid standing on `footprint`, `height` units tall: the walls that face the
# camera (shaded by which way they face) and the roof. Returned as drawable parts.
static func prism_parts(footprint: PackedVector2Array, height: float, color: Color) -> Array:
	var lift = UP * height * HEIGHT_SCALE
	var center = Vector2.ZERO
	for p in footprint:
		center += p
	center /= footprint.size()
	var parts = []
	var count = footprint.size()
	for k in count:
		var p = footprint[k]
		var q = footprint[(k + 1) % count]
		var edge = q - p
		var normal = Vector2(edge.y, -edge.x).normalized()
		if normal.dot((p + q) * 0.5 - center) < 0.0:
			normal = -normal
		# Only walls facing the camera (south) can be seen
		if normal.y <= 0.05:
			continue
		# Light from the west: west-facing walls are lighter, east-facing darker
		var shade = 0.3 + 0.25 * maxf(normal.x, 0.0) - 0.1 * maxf(-normal.x, 0.0)
		parts.append([0, PackedVector2Array([p, q, q + lift, p + lift]), color.darkened(shade), 0.0])
	var roof = PackedVector2Array()
	for p in footprint:
		roof.append(p + lift)
	parts.append([0, roof, color, 0.0])
	return parts

static func lifted(poly: PackedVector2Array, height: float) -> PackedVector2Array:
	var out = PackedVector2Array()
	for p in poly:
		out.append(p + UP * height * HEIGHT_SCALE)
	return out

# Adds a solid and its shadow; later _top calls decorate its roof
func _solid(footprint: PackedVector2Array, color: Color, height: float):
	_shadow(footprint, height)
	_last = prism_parts(footprint, height, color)
	_last_height = height
	var depth = -INF
	for p in footprint:
		depth = maxf(depth, p.y)
	_pending.append([depth, _last])

# A feature on the roof of the latest solid (extra lifts it further, e.g. a rooftop tower)
func _top(poly: PackedVector2Array, color: Color, extra: float = 0.0):
	_last.append([0, lifted(poly, _last_height + extra), color, 0.0])

func _top_line(line: PackedVector2Array, color: Color, width: float):
	_last.append([1, lifted(line, _last_height), color, width])

func _cylinder(center: Vector2, radius: float, height: float, color: Color):
	_solid(_ellipse(center, radius, radius * 0.8, 0.0, 20), color, height)

# A tree is a small raised canopy, sorted with the buildings so it can stand in front of them
func _tree(at: Vector2, radius: float, color: Color):
	details.append([at + SHADOW_DIR * radius * 0.6, radius, Color(0, 0, 0, 0.28)])
	_pending.append([at.y, [[2, [at + UP * radius * 0.7, radius], color, 0.0]]])

func _shadow(poly: PackedVector2Array, height: float):
	var offset = SHADOW_DIR * height * HEIGHT_SCALE * 0.6
	var moved = PackedVector2Array()
	for p in poly:
		moved.append(p + offset)
	shadows.append([moved, SHADOW])

# --- Wasteland ----------------------------------------------------------------------

func _wasteland_texture(map_seed: int) -> Texture2D:
	var noise = FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var detail = FastNoiseLite.new()
	detail.seed = map_seed + 1
	detail.frequency = 0.09
	var w = 512
	var h = int(w * map_size.y / map_size.x)
	var image = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var n = noise.get_noise_2d(x, y) * 0.5 + 0.5
			var g = detail.get_noise_2d(x, y)
			var color = WASTELAND_DARK.lerp(WASTELAND_LIGHT, n)
			if g > 0.2:
				color = color.lerp(WASTELAND_GREEN, 0.6)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

# Beyond the city edge: forests, abandoned farmland, old tracks and scattered ruins
func _build_wasteland(boundary: PackedVector2Array, map_seed: int):
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed + 5
	var center = map_size * 0.5
	for k in 9:
		var angle = rng.randf() * TAU
		var from = center + Vector2.from_angle(angle) * 500.0
		var to = center + Vector2.from_angle(angle + rng.randf_range(-0.15, 0.15)) * 1400.0
		for piece in Geometry2D.clip_polyline_with_polygon(PackedVector2Array([from, to]), boundary):
			roads.append([piece, ROAD_EDGE.lerp(WASTELAND_LIGHT, 0.3), 5.0])

	# Farmland: patchworks of old fields with hedgerows, gone to seed
	for patch in 10:
		var at = _outside_point(rng, boundary, 60.0)
		var dir = Vector2.from_angle(rng.randf() * PI)
		var perp = dir.orthogonal()
		var plot = Vector2(rng.randf_range(40, 70), rng.randf_range(30, 50))
		for i in 4:
			for j in 3:
				var c = at + dir * (i - 1.5) * plot.x + perp * (j - 1) * plot.y
				if Geometry2D.is_point_in_polygon(c, boundary) or rng.randf() < 0.15:
					continue
				var rect = _rect(c, dir, perp, plot.x - 3, plot.y - 3)
				wasteland.append([rect, Color(FIELD_COLORS[rng.randi() % FIELD_COLORS.size()]).darkened(rng.randf_range(0.0, 0.15))])
				rails.append([_closed(rect), Color("#2c3322"), 1.5])

	# Forests: dense stands of trees, thickest at their heart
	for patch in 14:
		var at = _outside_point(rng, boundary, 100.0)
		var radius = rng.randf_range(50, 110)
		for k in int(radius * 1.6):
			var p = at + Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
			if Geometry2D.is_point_in_polygon(p, boundary):
				continue
			_tree(p, rng.randf_range(4.0, 7.5), TREE.darkened(rng.randf_range(0.0, 0.25)).lightened(rng.randf_range(0.0, 0.1)))

	for k in 700:
		var p = Vector2(rng.randf_range(0, map_size.x), rng.randf_range(0, map_size.y))
		if Geometry2D.is_point_in_polygon(p, boundary):
			continue
		# Denser near the city, thinning out into the wastes
		var near = 1.0 - clampf(p.distance_to(center) / map_size.length(), 0.0, 1.0)
		if rng.randf() > near * near:
			continue
		var size = rng.randf_range(4, 11)
		var dir = Vector2.from_angle(rng.randf() * PI)
		wasteland.append([_rect(p, dir, dir.orthogonal(), size, size * rng.randf_range(0.5, 1.2)),
			RUBBLE.darkened(rng.randf_range(0.2, 0.5))])

func _outside_point(rng: RandomNumberGenerator, boundary: PackedVector2Array, margin: float) -> Vector2:
	for attempt in 50:
		var p = Vector2(rng.randf_range(margin, map_size.x - margin), rng.randf_range(margin, map_size.y - margin))
		if not Geometry2D.is_point_in_polygon(p, boundary):
			return p
	return Vector2(margin, margin)

# A railway crossing the city west to east through its industrial districts
func _railway(city: CityMap, map_seed: int) -> PackedVector2Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed + 11
	var stops = []
	for d in city.districts:
		if d.district_type == "industrial" or NAMED_LANDMARKS.get(d.district_name, "") == "rail":
			stops.append(d.center + Vector2(0, 30))
	if stops.size() < 2:
		return PackedVector2Array()
	stops.sort_custom(func(a, b): return a.x < b.x)
	var line = PackedVector2Array([Vector2(0, stops[0].y + rng.randf_range(-80, 80))])
	for s in stops:
		line.append(s)
	line.append(Vector2(map_size.x, stops[stops.size() - 1].y + rng.randf_range(-80, 80)))
	line = _smooth(line, 3)
	rails.append([line, RAIL_BED, 8.0])
	# Two rails, with sleepers drawn as a dashed band between them
	var offset_line = func(sign: float) -> PackedVector2Array:
		var out = PackedVector2Array()
		for k in line.size():
			var a = line[maxi(k - 1, 0)]
			var b = line[mini(k + 1, line.size() - 1)]
			out.append(line[k] + (b - a).normalized().orthogonal() * 1.8 * sign)
		return out
	rails.append([offset_line.call(1.0), RAIL, 0.8])
	rails.append([offset_line.call(-1.0), RAIL, 0.8])
	return line

# --- Districts -----------------------------------------------------------------------

func _build_district(d: District, avoid: Array):
	var t = GameData.district_type(d.district_type)
	var rng = RandomNumberGenerator.new()
	rng.seed = d.id * 7919 + 101
	ground.append([d.polygon, Color(t["ground"]).darkened(rng.randf_range(0.0, 0.12))])

	# A street grid at a random angle, clipped to the district
	var angle = rng.randf() * PI
	var dir = Vector2.from_angle(angle)
	var perp = dir.orthogonal()
	var spacing: float = t["street_spacing"]
	var street_width: float = t["street_width"]
	var reach = 240.0
	var steps = int(reach / spacing) + 1
	var street_color = Color(t["street"])
	for i in range(-steps, steps + 1):
		for axes in [[dir, perp], [perp, dir]]:
			var origin: Vector2 = d.center + axes[1] * i * spacing
			var line = PackedVector2Array([origin - axes[0] * reach, origin + axes[0] * reach])
			for piece in Geometry2D.intersect_polyline_with_polygon(line, d.polygon):
				streets.append([piece, street_color, street_width])
				_cars(rng, piece, axes[0], d.ruin_level)

	# A landmark near the middle, then blocks of buildings, trees and rubble around it
	var reserves = _landmark(rng, d, t, dir, perp, avoid)
	var lots: int = t["lots"]
	var block = spacing - street_width - 2.0
	var lot = block / lots
	for i in range(-steps, steps):
		for j in range(-steps, steps):
			var cell = d.center + dir * (i + 0.5) * spacing + perp * (j + 0.5) * spacing
			if not Geometry2D.is_point_in_polygon(cell, d.polygon) or _near(cell, avoid, block * 0.3) or _reserved(cell, reserves, 0.0):
				continue
			if rng.randf() < t["trees"]:
				_trees(rng, cell, block * 0.45)
				continue
			for a in lots:
				for b in lots:
					if rng.randf() > t["building_fill"]:
						continue
					var at = cell + dir * ((a + 0.5) * lot - block * 0.5) + perp * ((b + 0.5) * lot - block * 0.5)
					_building(rng, d, t, at, dir, perp, lot, avoid, reserves)

	# The longer a place has been left to rot, the more it is overgrown and scarred
	for k in int(d.ruin_level * 7):
		details.append([_random_point_in(rng, d.polygon), rng.randf_range(10, 24), OVERGROWTH])
	if d.ruin_level > 0.55:
		for k in rng.randi_range(1, 3):
			details.append([_random_point_in(rng, d.polygon), rng.randf_range(6, 13), SCORCH])

func _building(rng: RandomNumberGenerator, d: District, t: Dictionary, at: Vector2, dir: Vector2, perp: Vector2, lot: float, avoid: Array, reserves: Array):
	var w = lot * rng.randf_range(0.6, 0.92)
	var h = lot * rng.randf_range(0.6, 0.92)
	var rect = _rect(at, dir, perp, w, h)
	for p in rect:
		if not Geometry2D.is_point_in_polygon(p, d.polygon):
			return
	if _near(at, avoid, maxf(w, h) * 0.5) or _reserved(at, reserves, maxf(w, h) * 0.5):
		return
	var roofs: Array = t["roofs"]
	var roof = Color(roofs[rng.randi() % roofs.size()]).darkened(rng.randf_range(0.0, 0.12))
	var height = rng.randf_range(t["height"][0], t["height"][1])
	var walls = Color("#8a8278").lerp(roof, 0.35).darkened(rng.randf_range(0.0, 0.15))

	if rng.randf() < d.ruin_level * 0.6:
		_ruin(rng, rect, at, w, h, roof, walls, height)
		return
	var shape = rng.randf()
	if shape < 0.5 and minf(w, h) > 5.0:
		_pitched(rect, at, dir, perp, w, h, height, roof, walls)
	elif shape < 0.65 and w > 11.0 and h > 11.0:
		# L-shaped block: two wings at slightly different heights
		_solid(_rect(at - perp * h * 0.25, dir, perp, w, h * 0.5), walls, height)
		_top(_rect(at - perp * h * 0.25, dir, perp, w, h * 0.5), roof)
		_solid(_rect(at - dir * w * 0.25 + perp * h * 0.25, dir, perp, w * 0.5, h * 0.5), walls, height * 0.8)
		_top(_rect(at - dir * w * 0.25 + perp * h * 0.25, dir, perp, w * 0.5, h * 0.5), roof.darkened(0.06))
	elif shape < 0.78 and w > 16.0 and h > 16.0:
		# Block around a courtyard, which sits in shadow
		_solid(rect, walls, height)
		_top(rect, roof)
		_top(_rect(at, dir, perp, w * 0.45, h * 0.45), Color(t["ground"]).darkened(0.35))
	else:
		# Flat roof with a parapet and rooftop plant
		_solid(rect, walls, height)
		_top(rect, roof)
		if w > 7.0 and h > 7.0:
			_top(_rect(at, dir, perp, w * 0.78, h * 0.78), roof.lightened(0.08))
			if rng.randf() < 0.5:
				_top(_rect(at + dir * w * 0.15, dir, perp, 2.2, 2.2), roof.darkened(0.3), 0.3)

# A pitched roof: walls up to the eaves, then two roof slopes meeting at a raised ridge
func _pitched(rect: PackedVector2Array, at: Vector2, dir: Vector2, perp: Vector2, w: float, h: float, height: float, roof: Color, walls: Color):
	_solid(rect, walls, height)
	var long_axis = dir if w >= h else perp
	var short_axis = perp if w >= h else dir
	var length = maxf(w, h) * 0.5
	var half = minf(w, h) * 0.5
	var ridge_lift = UP * (height * HEIGHT_SCALE + half * 0.8)
	var eave_lift = UP * height * HEIGHT_SCALE
	var ridge_a = at - long_axis * length + ridge_lift
	var ridge_b = at + long_axis * length + ridge_lift
	for side in [-1.0, 1.0]:
		var eave_a = at - long_axis * length + short_axis * half * side + eave_lift
		var eave_b = at + long_axis * length + short_axis * half * side + eave_lift
		# The slope facing the camera (south) is lit; the far one darker
		var facing = (short_axis * side).y > 0.0
		_last.append([0, PackedVector2Array([eave_a, eave_b, ridge_b, ridge_a]), roof.lightened(0.08) if facing else roof.darkened(0.15), 0.0])
	_last.append([1, PackedVector2Array([ridge_a, ridge_b]), roof.lightened(0.22), 0.6])

# Ruins come in three kinds: gutted shells, collapsed heaps and burnt-out husks
func _ruin(rng: RandomNumberGenerator, rect: PackedVector2Array, at: Vector2, w: float, h: float, roof: Color, walls: Color, height: float):
	var kind = rng.randf()
	if kind < 0.4:
		# Standing walls with no roof: the inside is dark and full of rubble
		_solid(rect, walls.darkened(0.2), height * rng.randf_range(0.3, 0.6))
		_last[_last.size() - 1][2] = Color(0.12, 0.11, 0.1)
		for k in 3:
			details.append([at + Vector2(rng.randf_range(-w, w), rng.randf_range(-h, h)) * 0.3, rng.randf_range(1.0, 2.0), RUBBLE])
	elif kind < 0.75:
		var heap = PackedVector2Array([rect[0], rect[1].lerp(rect[2], rng.randf_range(0.2, 0.7)), rect[2].lerp(rect[3], rng.randf_range(0.3, 0.8)), rect[3]])
		_solid(heap, roof.darkened(0.45), rng.randf_range(0.2, 0.5))
		for k in 4:
			details.append([at + Vector2(rng.randf_range(-w, w), rng.randf_range(-h, h)) * 0.6, rng.randf_range(1.0, 2.4), RUBBLE])
	else:
		_solid(rect, Color(0.12, 0.1, 0.09), height * 0.7)
		_last[_last.size() - 1][2] = Color(0.07, 0.06, 0.05)

# Wrecked and abandoned cars along a street, more of them the more ruined the district
func _cars(rng: RandomNumberGenerator, street: PackedVector2Array, along: Vector2, ruin: float):
	if street.size() < 2:
		return
	var length = street[0].distance_to(street[street.size() - 1])
	var count = int(length / 45.0 * (0.3 + ruin) * rng.randf())
	for k in count:
		var at = street[0].lerp(street[street.size() - 1], rng.randf()) + along.orthogonal() * rng.randf_range(-1.2, 1.2)
		var heading = along.rotated(rng.randf_range(-0.5, 0.5))
		var color = Color(CAR_COLORS[rng.randi() % CAR_COLORS.size()])
		flats.append([_rect(at, heading, heading.orthogonal(), 4.6, 2.2), color])

func _trees(rng: RandomNumberGenerator, at: Vector2, radius: float):
	for k in rng.randi_range(3, 6):
		var offset = Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		_tree(at + offset, rng.randf_range(3.0, 6.0), TREE.lightened(rng.randf_range(0.0, 0.14)))

func _build_bridge(at: Vector2):
	# Bridges run across the river's local direction
	var best = 0
	for k in river.size() - 1:
		var closest = Geometry2D.get_closest_point_to_segment(at, river[k], river[k + 1])
		var best_closest = Geometry2D.get_closest_point_to_segment(at, river[best], river[best + 1])
		if closest.distance_to(at) < best_closest.distance_to(at):
			best = k
	var along = (river[best + 1] - river[best]).normalized()
	var across = along.orthogonal()
	var center = Geometry2D.get_closest_point_to_segment(at, river[best], river[best + 1])
	bridges.append([_rect(center + SHADOW_DIR * 3.0, across, along, 50.0, 14.0), SHADOW])
	bridges.append([_rect(center, across, along, 50.0, 14.0), BRIDGE_EDGE])
	bridges.append([_rect(center, across, along, 46.0, 10.0), BRIDGE])

# --- Landmarks ------------------------------------------------------------------------

# Builds the district's landmark and returns the areas buildings must keep clear of: [[center, radius], ...]
func _landmark(rng: RandomNumberGenerator, d: District, t: Dictionary, dir: Vector2, perp: Vector2, avoid: Array) -> Array:
	var kind: String = NAMED_LANDMARKS.get(d.district_name, "")
	if kind == "":
		var options: Array = TYPE_LANDMARKS.get(d.district_type, [""])
		kind = options[rng.randi() % options.size()]
	# Stand it a little above the label, if that spot is inside the district and clear of river and roads
	var spot = d.center + Vector2(0, -34)
	if not Geometry2D.is_point_in_polygon(spot, d.polygon) or _near(spot, avoid, 20.0):
		spot = d.center
	landmark_spots[d.id] = spot
	if kind == "":
		return [[spot, 14.0]]
	var s = spot
	match kind:
		"stadium":
			_solid(_ellipse(s, 44, 31, dir.angle()), CONCRETE, 2.2)
			_top(_ellipse(s, 34, 22, dir.angle()), CONCRETE.darkened(0.2))
			_top(_ellipse(s, 29, 18, dir.angle()), GRASS, -1.6)
			return [[s, 50.0]]
		"racecourse":
			flats.append([_ellipse(s, 58, 33, dir.angle()), Color("#7a6a4f")])
			flats.append([_ellipse(s, 48, 24, dir.angle()), GRASS.darkened(0.1)])
			_solid(_rect(s + perp * 38, dir, perp, 30, 7), CONCRETE, 2.0)
			return [[s, 60.0]]
		"cooling_towers":
			_solid(_rect(s + perp * 30, dir, perp, 60, 14), Color(t["roofs"][0]).lerp(CONCRETE, 0.4), 2.5)
			for k in 3:
				var c = s + dir * (k - 1) * 30
				_cylinder(c, 13, 7.0, CONCRETE.darkened(0.08))
				_top(_ellipse(c, 9, 7, 0.0, 20), Color(0.14, 0.14, 0.14))
				details.append([c + UP * 36 + Vector2(6, -8), 11.0, Color(0.75, 0.75, 0.72, 0.14)])
			return [[s, 55.0]]
		"gas_holders":
			for k in 2:
				var c = s + dir * (k - 0.5) * 38
				_cylinder(c, 16, 4.0, RUST)
				_top_line(_closed(_ellipse(c, 11, 8.8, 0.0, 20)), RUST.darkened(0.35), 1.0)
			return [[s, 45.0]]
		"tanks":
			for k in 4:
				var c = s + dir * ((k % 2) - 0.5) * 22 + perp * (int(k / 2.0) - 0.5) * 22
				_cylinder(c, 8, 2.5, Color("#9a948a"))
				_top(_ellipse(c, 5, 4, 0.0, 16), Color("#7a746a"))
			return [[s, 32.0]]
		"cathedral":
			var stone = Color("#8a8075")
			var roof = Color("#5d554d")
			_pitched(_rect(s, dir, perp, 64, 18), s, dir, perp, 64, 18, 4.0, roof, stone)
			_pitched(_rect(s + dir * 10, dir, perp, 16, 44), s + dir * 10, dir, perp, 16, 44, 4.0, roof.darkened(0.05), stone)
			_solid(_rect(s - dir * 30, dir, perp, 12, 12), stone.lightened(0.05), 9.0)
			_top(_rect(s - dir * 30, dir, perp, 7, 7), roof, 1.5)
			return [[s, 42.0]]
		"church":
			var stone = Color("#857b70")
			var roof = Color("#5f554c")
			_pitched(_rect(s, dir, perp, 32, 11), s, dir, perp, 32, 11, 2.5, roof, stone)
			_solid(_rect(s - dir * 19, dir, perp, 8, 8), stone, 6.0)
			_top(_rect(s - dir * 19, dir, perp, 4, 4), roof, 1.2)
			return [[s, 24.0]]
		"cemetery":
			for i in 7:
				for j in 5:
					if rng.randf() < 0.85:
						var p = s + dir * (i - 3) * 7 + perp * (j - 2) * 7
						flats.append([_rect(p, dir, perp, 3, 1.6), Color("#8a8a82").darkened(rng.randf_range(0.0, 0.3))])
			for k in 8:
				_tree(s + Vector2.from_angle(TAU * k / 8.0) * 32, 4.5, TREE)
			return [[s, 40.0]]
		"allotments":
			var greens = ["#4b5e38", "#5a4a32", "#3f5230", "#6a5a3a", "#556b3c"]
			for i in 5:
				for j in 3:
					var p = s + dir * (i - 2) * 13 + perp * (j - 1) * 10
					flats.append([_rect(p, dir, perp, 12, 9), Color(greens[rng.randi() % greens.size()])])
			_solid(_rect(s + perp * 22, dir, perp, 8, 6), Color("#6a5a45"), 1.2)
			return [[s, 36.0]]
		"rail":
			for k in 5:
				var offset = perp * (k - 2) * 7
				rails.append([PackedVector2Array([s - dir * 70 + offset, s + dir * 70 + offset]), RAIL, 1.2])
				if rng.randf() < 0.6:
					var wagon = s + offset + dir * rng.randf_range(-45, 45)
					_solid(_rect(wagon, dir, perp, 24, 4.5), RUST.lightened(rng.randf_range(-0.1, 0.15)), 1.1)
			return [[s, 30.0], [s + dir * 45, 22.0], [s - dir * 45, 22.0]]
		"runway":
			flats.append([_rect(s, dir, perp, 170, 16), Color("#5a5750")])
			road_marks.append([s - dir * 80, s + dir * 80])
			_solid(_rect(s + perp * 26 + dir * 40, dir, perp, 22, 14), Color("#6b6a66"), 2.0)
			return [[s, 30.0], [s + dir * 60, 25.0], [s - dir * 60, 25.0]]
		"hospital":
			var white = Color("#b4b0a8")
			_solid(_rect(s - dir * 16, dir, perp, 9, 40), white, 3.0)
			_solid(_rect(s, dir, perp, 32, 9), white.darkened(0.05), 2.6)
			_top(_rect(s, dir, perp, 7, 2.2), Color("#a83a30"))
			_top(_rect(s, dir, perp, 2.2, 7), Color("#a83a30"))
			_solid(_rect(s + dir * 16, dir, perp, 9, 40), white, 3.0)
			return [[s, 30.0]]
		"cranes":
			var colors = ["#7a3f30", "#3f5a6b", "#5a6b3f", "#8a7a52"]
			for i in 4:
				for j in 3:
					var p = s + dir * (i - 1.5) * 13 + perp * (j - 1) * 6
					_solid(_rect(p, dir, perp, 12, 5), Color(colors[rng.randi() % colors.size()]), 0.7 * rng.randi_range(1, 2))
			for k in 2:
				var base = s + perp * 22 + dir * (k - 0.5) * 36
				_solid(_rect(base, dir, perp, 4, 4), Color("#a08a40"), 8.0)
				_top_line(PackedVector2Array([base - dir * 6, base + dir * 26]), Color("#b89a45"), 2.0)
			return [[s, 38.0]]
		"quarry":
			for ring in [[40.0, 28.0, "#5d5040"], [30.0, 20.0, "#4d4234"], [19.0, 12.0, "#3d3428"]]:
				flats.append([_ellipse(s, ring[0], ring[1], dir.angle()), Color(ring[2])])
			return [[s, 45.0]]
		"landfill":
			_solid(_ellipse(s, 42, 30, dir.angle()), Color("#4a4438"), 1.5)
			for k in 40:
				var p = s + Vector2(rng.randf_range(-36, 36), rng.randf_range(-24, 24))
				_top(_ellipse(p, 1.5, 1.2, 0.0, 6), Color(CAR_COLORS[rng.randi() % CAR_COLORS.size()]).darkened(0.2))
			return [[s, 45.0]]
		"tower":
			var roof = Color(t["roofs"][rng.randi() % t["roofs"].size()])
			var glass = Color("#56606a")
			_solid(_rect(s, dir, perp, 30, 30), glass, 9.0)
			_top(_rect(s, dir, perp, 30, 30), roof)
			_solid(_rect(s, dir, perp, 18, 18), glass.lightened(0.05), 12.0)
			_top(_rect(s, dir, perp, 18, 18), roof.lightened(0.12))
			return [[s, 26.0]]
		"tower_blocks":
			for k in 3:
				var c = s + dir * (k - 1) * 22
				_solid(_rect(c, dir, perp, 11, 38), Color("#77736c").darkened(k * 0.06), 8.0)
				_top(_rect(c, dir, perp, 11, 38), Color("#5f5b55"))
			return [[s, 36.0]]
		"retail":
			flats.append([_rect(s + perp * 16, dir, perp, 70, 26), Color("#3e3d3a")])
			for k in 7:
				flats.append([_rect(s + perp * 16 + dir * (k - 3) * 10, dir, perp, 0.6, 22), Color("#6a6760")])
			for k in 5:
				var p = s + perp * rng.randf_range(8, 26) + dir * rng.randf_range(-30, 30)
				flats.append([_rect(p, perp, dir, 4.6, 2.2), Color(CAR_COLORS[rng.randi() % CAR_COLORS.size()])])
			_solid(_rect(s - perp * 16, dir, perp, 70, 26), Color("#7a776f"), 2.0)
			_top(_rect(s - perp * 16, dir, perp, 70, 26), Color("#6f6d68"))
			return [[s, 42.0]]
		"golf":
			flats.append([_ellipse(s, 50, 18, dir.angle()), GRASS.lightened(0.08)])
			flats.append([_ellipse(s + dir * 20, 7, 5, 0), Color("#8a7a55")])
			for k in 6:
				_tree(s + perp * 26 + dir * (k - 2.5) * 12, 5.0, TREE)
			return [[s, 50.0]]
		"pond":
			flats.append([_ellipse(s, 30, 19, dir.angle()), WATER_BANK])
			flats.append([_ellipse(s, 27, 16, dir.angle()), WATER])
			rails.append([_closed(_ellipse(s, 38, 26, dir.angle())), Color("#6a5d45"), 1.5])
			return [[s, 42.0]]
		"plaza":
			flats.append([_rect(s, dir, perp, 48, 48), PAVING])
			_cylinder(s, 5, 0.6, CONCRETE.lightened(0.1))
			_top(_ellipse(s, 3.5, 2.8, 0.0, 12), WATER)
			for k in 6:
				var p = s + dir * rng.randf_range(-18, 18) + perp * rng.randf_range(-18, 18)
				_solid(_rect(p, dir, perp, 5, 4), Color(["#8a4a3a", "#4a6a7a", "#7a7a4a"][k % 3]), 0.8)
			return [[s, 34.0]]
		"pylons":
			var previous = Vector2.ZERO
			for k in 5:
				var p = s + dir * (k - 2) * 34
				_solid(_rect(p, dir, perp, 4, 4), Color("#7a7670"), 8.0)
				if k > 0:
					_pending.append([p.y, [[1, PackedVector2Array([previous + UP * 30, p + UP * 30]), Color("#9a968e", 0.6), 0.5]]])
				previous = p
			return [[s, 18.0]]
		"chimneys":
			var roof = Color(t["roofs"][0]).darkened(0.05)
			_solid(_rect(s, dir, perp, 56, 30), roof.lerp(CONCRETE, 0.3), 3.0)
			for k in 4:
				_top_line(PackedVector2Array([s - dir * 28 + perp * (k - 1.5) * 7, s + dir * 28 + perp * (k - 1.5) * 7]), roof.lightened(0.15), 0.8)
			for k in 2:
				var c = s + dir * (k - 0.5) * 24 - perp * 22
				_cylinder(c, 4.0, 12.0, Color("#4a3e38"))
				details.append([c + UP * 54 + Vector2(6, -10), 10.0, Color(0.6, 0.6, 0.6, 0.16)])
			return [[s, 40.0]]
		"barracks":
			rails.append([_closed(_rect(s, dir, perp, 70, 50)), Color("#8a857a"), 1.2])
			for k in 3:
				_pitched(_rect(s + perp * (k - 1) * 14, dir, perp, 50, 8), s + perp * (k - 1) * 14, dir, perp, 50, 8, 1.8, Color("#5a6048"), Color("#6a6a58"))
			for corner in _rect(s, dir, perp, 70, 50):
				_solid(_rect(corner, dir, perp, 5, 5), Color("#6a6a60"), 5.0)
			return [[s, 44.0]]
		"camp":
			for k in 8:
				var p = s + Vector2.from_angle(TAU * k / 8.0 + rng.randf()) * rng.randf_range(10, 24)
				var tent_dir = Vector2.from_angle(rng.randf() * TAU)
				var color = Color(["#7a6a4a", "#5a6a5a", "#6a4a3a"][k % 3])
				_pending.append([p.y, [[0, PackedVector2Array([p + tent_dir * 5, p + tent_dir.orthogonal() * 4 + UP * 5, p - tent_dir.orthogonal() * 4]), color, 0.0]]])
			details.append([s, 5.0, Color(1.0, 0.55, 0.2, 0.25)])
			details.append([s, 2.0, Color(1.0, 0.65, 0.3, 0.9)])
			return [[s, 30.0]]
		"quad":
			var roof = Color(t["roofs"][0])
			var walls = Color("#8a8278").lerp(roof, 0.35)
			flats.append([_rect(s, dir, perp, 26, 26), GRASS])
			for side in [[0, -1], [-1, 0], [1, 0], [0, 1]]:
				var offset = dir * side[0] * 18 + perp * side[1] * 18
				var along = perp if side[0] != 0 else dir
				_pitched(_rect(s + offset, along, along.orthogonal(), 44, 8), s + offset, along, along.orthogonal(), 44, 8, 2.5, roof, walls)
			return [[s, 30.0]]
	return [[spot, 14.0]]

func _reserved(p: Vector2, reserves: Array, extra: float) -> bool:
	for r in reserves:
		if p.distance_to(r[0]) < r[1] + extra:
			return true
	return false

# --- Geometry helpers ----------------------------------------------------------------

static func _points(raw: Array) -> PackedVector2Array:
	var out = PackedVector2Array()
	for p in raw:
		out.append(Vector2(p[0], p[1]))
	return out

# Chaikin smoothing: rounds off a polyline's corners (keeps its ends)
static func _smooth(line: PackedVector2Array, passes: int) -> PackedVector2Array:
	var out = line
	for pass_index in passes:
		if out.size() < 3:
			return out
		var next = PackedVector2Array([out[0]])
		for k in out.size() - 1:
			next.append(out[k].lerp(out[k + 1], 0.25))
			next.append(out[k].lerp(out[k + 1], 0.75))
		next.append(out[out.size() - 1])
		out = next
	return out

static func _rect(center: Vector2, dir: Vector2, perp: Vector2, w: float, h: float) -> PackedVector2Array:
	var x = dir * w * 0.5
	var y = perp * h * 0.5
	return PackedVector2Array([center - x - y, center + x - y, center + x + y, center - x + y])

static func _ellipse(center: Vector2, rx: float, ry: float, rotation: float, segments: int = 24) -> PackedVector2Array:
	var out = PackedVector2Array()
	for k in segments:
		var a = TAU * k / segments
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rotation))
	return out

static func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out = poly.duplicate()
	out.append(poly[0])
	return out

# True if a point is within a segment's clearance (plus extra) of any segment in the list
static func _near(p: Vector2, segments: Array, extra: float) -> bool:
	for s in segments:
		if Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p) < s[2] + extra:
			return true
	return false

static func _random_point_in(rng: RandomNumberGenerator, poly: PackedVector2Array) -> Vector2:
	var lo = poly[0]
	var hi = poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	for attempt in 30:
		var p = Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if Geometry2D.is_point_in_polygon(p, poly):
			return p
	return (lo + hi) * 0.5
