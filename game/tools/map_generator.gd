class_name MapGenerator

# Builds the city layout that data/map.json holds: district shapes, types, names and boroughs,
# the river and its bridges, and the main roads. Run tools/generate_map.gd to regenerate it.
# The game only reads the JSON, so the layout can also be edited by hand.

const SIZE = Vector2(2000, 1300)
const CITY_RADIUS = Vector2(840, 520)
# Districts are closer together downtown and further apart towards the edge
const MIN_SPACING = 118.0
const VERTEX_MERGE = 1.0
const BOROUGH_COUNT = 8

const NAMES = {
	"downtown": ["Central Hub", "Cathedral Quarter", "Market Square", "Civic Centre", "The Exchange", "Old Town",
		"Clock Tower", "Guildhall", "Arcade Row", "Tower Blocks", "Bank Street"],
	"residential": ["Terrace Row", "Church Lane", "Council Estate", "Canal Quarter", "Hospital Hill", "University Row",
		"Brewery Lane", "Chapel Street", "Mill Street", "Station Road", "Albion Heights", "Grove Street", "Kingsway",
		"Orchard Rise", "Cemetery Road", "Tannery Row", "Viaduct", "Victoria Estate"],
	"industrial": ["Gasworks", "Rail Yards", "Power Station", "Printworks", "Scrapyard", "Steelworks", "Foundry Lane",
		"Water Works", "Bus Depot", "Brickfields", "Chemical Works", "Freight Yard"],
	"docks": ["South Docks", "Ferry Landing", "Harbour", "Wharfside", "Riverside", "Boatyard", "Lock Gates",
		"Warehouse Row", "Quayside", "Coal Wharf"],
	"park": ["Allotments", "Memorial Park", "Botanic Gardens", "The Common", "Cemetery", "Racecourse"],
	"suburb": ["Garden Suburb", "Retail Park", "Stadium", "Outer Ring", "Airfield", "Golf Links", "Hillcrest",
		"Meadowbank", "Highfield", "Ashgrove", "Elm Park", "Bramble Close"],
	"outskirts": ["Nomad Camp", "Deep Ruins", "Motorway Junction", "Landfill", "Barracks", "Quarry", "Burnt Farms",
		"Pylon Fields", "Service Station", "Checkpoint", "Outer Settlement", "Agricultural Belt", "Sewage Works"],
}

# Boroughs are named by where they sit in the city, echoing the factions' home turf
const BOROUGH_NAMES = {
	"centre": "Old Quarter", "N": "Canal District", "NE": "Ironside", "E": "Eastfield", "SE": "Marshgate",
	"S": "Southside", "SW": "Kilnworth", "W": "Westgate", "NW": "Northbank",
}

static func generate(map_seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed
	var noise = FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = 0.004
	var center = SIZE * 0.5
	var boundary = _city_boundary(rng, center)
	var seeds = _scatter_seeds(rng, boundary, center)
	var polygons = _voronoi(seeds, boundary)
	var neighbors = _adjacency(polygons)
	var river = _river(rng, polygons, center)
	var bridges = _bridges(river, polygons, neighbors)
	var types = _district_types(rng, noise, polygons, center, river["pairs"])
	var centers = []
	for poly in polygons:
		centers.append(_centroid(poly))
	var boroughs = _boroughs(rng, centers, center)
	var names = _names(rng, types)
	var roads = _roads(centers, neighbors)

	var districts = []
	for i in polygons.size():
		var points = []
		for p in polygons[i]:
			points.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		districts.append({
			"id": i, "name": names[i], "type": types[i], "borough": boroughs["assignment"][i],
			"center": [snappedf(centers[i].x, 0.01), snappedf(centers[i].y, 0.01)],
			"neighbors": neighbors[i], "polygon": points,
		})
	var river_points = []
	for p in river["line"]:
		river_points.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	var boundary_points = []
	for p in boundary:
		boundary_points.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	return {
		"seed": map_seed, "size": [SIZE.x, SIZE.y], "boundary": boundary_points, "river": river_points,
		"bridges": bridges, "roads": roads, "boroughs": boroughs["list"], "districts": districts,
	}

# An organic blob: an ellipse whose radius wobbles with a few low-frequency waves
static func _city_boundary(rng: RandomNumberGenerator, center: Vector2) -> PackedVector2Array:
	var out = PackedVector2Array()
	var phases = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	for i in 72:
		var angle = TAU * i / 72.0
		var wobble = 1.0 + 0.10 * sin(3.0 * angle + phases[0]) + 0.06 * sin(5.0 * angle + phases[1]) + 0.04 * sin(7.0 * angle + phases[2])
		out.append(center + Vector2(cos(angle) * CITY_RADIUS.x, sin(angle) * CITY_RADIUS.y) * wobble)
	return out

static func _scatter_seeds(rng: RandomNumberGenerator, boundary: PackedVector2Array, center: Vector2) -> Array:
	var seeds = []
	for attempt in 8000:
		var p = Vector2(rng.randf_range(0, SIZE.x), rng.randf_range(0, SIZE.y))
		if not Geometry2D.is_point_in_polygon(p, boundary):
			continue
		var spacing = MIN_SPACING * (0.8 + 0.45 * _normalized_distance(p, center))
		var ok = true
		for s in seeds:
			if s.distance_to(p) < spacing:
				ok = false
				break
		if ok:
			seeds.append(p)
	return seeds

static func _normalized_distance(p: Vector2, center: Vector2) -> float:
	return ((p - center) / CITY_RADIUS).length()

# Voronoi cells clipped to the city boundary; empty or tiny cells are dropped
static func _voronoi(seeds: Array, boundary: PackedVector2Array) -> Array:
	var polygons = []
	var bounds = PackedVector2Array([Vector2.ZERO, Vector2(SIZE.x, 0), SIZE, Vector2(0, SIZE.y)])
	for i in seeds.size():
		var poly = bounds
		for j in seeds.size():
			if i != j:
				poly = _clip_half_plane(poly, seeds[i], seeds[j])
		var best = PackedVector2Array()
		for piece in Geometry2D.intersect_polygons(poly, boundary):
			if absf(_area(piece)) > absf(_area(best)):
				best = piece
		if absf(_area(best)) > 1500.0:
			polygons.append(_dedupe(best))
	return polygons

static func _clip_half_plane(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var mid = (a + b) * 0.5
	var normal = b - a
	var out = PackedVector2Array()
	var count = poly.size()
	for k in count:
		var p = poly[k]
		var q = poly[(k + 1) % count]
		var dp = (p - mid).dot(normal)
		var dq = (q - mid).dot(normal)
		if dp <= 0.0:
			out.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			out.append(p + (q - p) * (dp / (dp - dq)))
	return out

static func _dedupe(poly: PackedVector2Array) -> PackedVector2Array:
	var out = PackedVector2Array()
	for p in poly:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.5:
			out.append(p)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= 0.5:
		out.remove_at(out.size() - 1)
	return out

static func _area(poly: PackedVector2Array) -> float:
	var total = 0.0
	for k in poly.size():
		total += poly[k].cross(poly[(k + 1) % poly.size()])
	return total * 0.5

static func _centroid(poly: PackedVector2Array) -> Vector2:
	var area = _area(poly)
	if absf(area) < 0.001:
		var sum = Vector2.ZERO
		for p in poly:
			sum += p
		return sum / poly.size()
	var c = Vector2.ZERO
	for k in poly.size():
		var p = poly[k]
		var q = poly[(k + 1) % poly.size()]
		c += (p + q) * p.cross(q)
	return c / (6.0 * area)

# Two cells are neighbours if they share an edge (two or more vertices on each other's boundary)
static func _adjacency(polygons: Array) -> Array:
	var neighbors = []
	for i in polygons.size():
		neighbors.append([])
	for i in polygons.size():
		for j in range(i + 1, polygons.size()):
			if _shared_points(polygons[i], polygons[j]).size() >= 2:
				neighbors[i].append(j)
				neighbors[j].append(i)
	return neighbors

static func _shared_points(a: PackedVector2Array, b: PackedVector2Array) -> Array:
	var shared = []
	for v in a:
		for k in b.size():
			if Geometry2D.get_closest_point_to_segment(v, b[k], b[(k + 1) % b.size()]).distance_to(v) < VERTEX_MERGE:
				shared.append(v)
				break
	return shared

# The river follows district borders from the west edge of the city to the east edge, so it
# separates districts instead of running through them. Returns the line and the district
# pairs it separates, in order along its course.
static func _river(rng: RandomNumberGenerator, polygons: Array, center: Vector2) -> Dictionary:
	# Merge the cells' vertices into one graph
	var vertices: Array[Vector2] = []
	var edges = {}  # "i|j" -> [cells]
	for c in polygons.size():
		var poly: PackedVector2Array = polygons[c]
		var ids = []
		for p in poly:
			ids.append(_vertex_id(vertices, p))
		for k in ids.size():
			var a = ids[k]
			var b = ids[(k + 1) % ids.size()]
			if a == b:
				continue
			var key = "%d|%d" % [mini(a, b), maxi(a, b)]
			if not edges.has(key):
				edges[key] = []
			if c not in edges[key]:
				edges[key].append(c)
	# Interior edges (shared by two cells) can carry the river; boundary vertices are its mouths
	var graph = {}
	var on_boundary = {}
	for key in edges:
		var parts = key.split("|")
		var a = int(parts[0])
		var b = int(parts[1])
		if edges[key].size() == 2:
			var weight = vertices[a].distance_to(vertices[b]) * rng.randf_range(0.5, 1.6)
			graph.get_or_add(a, []).append([b, weight, key])
			graph.get_or_add(b, []).append([a, weight, key])
		else:
			on_boundary[a] = true
			on_boundary[b] = true
	var start = -1
	var finish = -1
	for v in on_boundary:
		if not graph.has(v) or absf(vertices[v].y - center.y) > 220.0:
			continue
		if start < 0 or vertices[v].x < vertices[start].x:
			start = v
		if finish < 0 or vertices[v].x > vertices[finish].x:
			finish = v
	if start < 0 or finish < 0:
		return {"line": [], "pairs": []}
	# Dijkstra over the interior edges
	var dist = {start: 0.0}
	var prev = {}
	var open = [start]
	while not open.is_empty():
		var best_i = 0
		for i in open.size():
			if dist[open[i]] < dist[open[best_i]]:
				best_i = i
		var u = open[best_i]
		open.remove_at(best_i)
		if u == finish:
			break
		for link in graph.get(u, []):
			var nd = dist[u] + link[1]
			if nd < dist.get(link[0], INF):
				if not dist.has(link[0]):
					open.append(link[0])
				dist[link[0]] = nd
				prev[link[0]] = [u, link[2]]
	if not prev.has(finish):
		return {"line": [], "pairs": []}
	var path = [finish]
	var pairs = []
	var node = finish
	while prev.has(node):
		var step = prev[node]
		pairs.push_front(edges[step[1]].duplicate())
		node = step[0]
		path.push_front(node)
	var line = [Vector2(0, vertices[start].y + rng.randf_range(-60, 60)),
		(Vector2(0, vertices[start].y) + vertices[start]) * 0.5 + Vector2(0, rng.randf_range(-40, 40))]
	for v in path:
		line.append(vertices[v])
	line.append((Vector2(SIZE.x, vertices[finish].y) + vertices[finish]) * 0.5 + Vector2(0, rng.randf_range(-40, 40)))
	line.append(Vector2(SIZE.x, vertices[finish].y + rng.randf_range(-60, 60)))
	return {"line": line, "pairs": pairs}

static func _vertex_id(vertices: Array[Vector2], p: Vector2) -> int:
	for i in vertices.size():
		if vertices[i].distance_to(p) < VERTEX_MERGE:
			return i
	vertices.append(p)
	return vertices.size() - 1

# Districts on opposite banks are only neighbours where a bridge crosses. Removes the other
# river crossings from the neighbour lists and returns the bridges.
static func _bridges(river: Dictionary, polygons: Array, neighbors: Array) -> Array:
	var pairs: Array = river["pairs"]
	var bridges = []
	if pairs.is_empty():
		return bridges
	var spacing = maxi(2, int(pairs.size() / 5.0))
	var chosen = {}
	for k in pairs.size():
		var pair = pairs[k]
		var key = "%d|%d" % [mini(pair[0], pair[1]), maxi(pair[0], pair[1])]
		if k % spacing == spacing / 2 and not chosen.has(key):
			chosen[key] = true
			var shared = _shared_points(polygons[pair[0]], polygons[pair[1]])
			var mid = (shared[0] + shared[shared.size() - 1]) * 0.5 if shared.size() > 0 else _centroid(polygons[pair[0]])
			bridges.append({"a": pair[0], "b": pair[1], "x": snappedf(mid.x, 0.01), "y": snappedf(mid.y, 0.01)})
	for pair in pairs:
		var key = "%d|%d" % [mini(pair[0], pair[1]), maxi(pair[0], pair[1])]
		if not chosen.has(key):
			neighbors[pair[0]].erase(pair[1])
			neighbors[pair[1]].erase(pair[0])
	return bridges

static func _district_types(rng: RandomNumberGenerator, noise: FastNoiseLite, polygons: Array, center: Vector2, river_pairs: Array) -> Array:
	var riverside = {}
	for pair in river_pairs:
		riverside[pair[0]] = true
		riverside[pair[1]] = true
	var types = []
	var parks = 0
	for i in polygons.size():
		var c = _centroid(polygons[i])
		var dn = _normalized_distance(c, center)
		var t = "residential"
		if dn < 0.3:
			t = "downtown"
		elif riverside.has(i) and dn < 0.9 and rng.randf() < 0.4:
			t = "docks"
		elif dn > 0.82:
			t = "outskirts" if rng.randf() < 0.6 else "suburb"
		elif dn > 0.62:
			t = "suburb" if noise.get_noise_2dv(c) > -0.1 else "residential"
		else:
			t = "industrial" if noise.get_noise_2dv(c) > 0.0 else "residential"
		if t in ["residential", "suburb"] and rng.randf() < 0.1:
			t = "park"
		if t == "park":
			parks += 1
		types.append(t)
	if parks == 0:
		for i in types.size():
			if types[i] == "residential":
				types[i] = "park"
				break
	return types

# k-means clusters of district centres, named by compass direction from the city centre
static func _boroughs(rng: RandomNumberGenerator, centers: Array, city_center: Vector2) -> Dictionary:
	var k = mini(BOROUGH_COUNT, centers.size())
	var means = []
	var shuffled = centers.duplicate()
	for i in shuffled.size():
		var j = rng.randi_range(i, shuffled.size() - 1)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	for i in k:
		means.append(shuffled[i])
	var assignment = []
	for iteration in 20:
		assignment.clear()
		var sums = []
		var counts = []
		for i in k:
			sums.append(Vector2.ZERO)
			counts.append(0)
		for c in centers:
			var best = 0
			for i in k:
				if c.distance_to(means[i]) < c.distance_to(means[best]):
					best = i
			assignment.append(best)
			sums[best] += c
			counts[best] += 1
		for i in k:
			if counts[i] > 0:
				means[i] = sums[i] / counts[i]
	# The most central borough is the Old Quarter; the rest each take the unused compass direction
	# closest to where they sit, outermost first
	var names = []
	var order = []
	for i in k:
		names.append("")
		order.append(i)
	order.sort_custom(func(a, b): return (means[a] - city_center).length() < (means[b] - city_center).length())
	names[order[0]] = BOROUGH_NAMES["centre"]
	var sector_keys = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	var sector_angles = [0.0, PI / 4, PI / 2, 3 * PI / 4, PI, -3 * PI / 4, -PI / 2, -PI / 4]
	var outer = order.slice(1)
	var angles = []
	for i in outer:
		angles.append(((means[i] - city_center) / CITY_RADIUS).angle())
	var best_assignment = _best_sectors(angles, sector_angles, [], {}, [INF, []])[1]
	for idx in outer.size():
		names[outer[idx]] = BOROUGH_NAMES[sector_keys[best_assignment[idx]]]
	var list = []
	for i in k:
		list.append({"name": names[i], "center": [snappedf(means[i].x, 0.01), snappedf(means[i].y, 0.01)]})
	var named_assignment = []
	for a in assignment:
		named_assignment.append(names[a])
	return {"list": list, "assignment": named_assignment}

# Exhaustive search for the sector per borough that minimises the total angle mismatch
# (at most 8 boroughs, so this is small). best is [cost, assignment].
static func _best_sectors(angles: Array, sector_angles: Array, chosen: Array, used: Dictionary, best: Array) -> Array:
	if chosen.size() == angles.size():
		var cost = 0.0
		for i in chosen.size():
			cost += absf(angle_difference(angles[i], sector_angles[chosen[i]]))
		if cost < best[0]:
			best[0] = cost
			best[1] = chosen.duplicate()
		return best
	for s in sector_angles.size():
		if not used.has(s):
			used[s] = true
			chosen.append(s)
			_best_sectors(angles, sector_angles, chosen, used, best)
			chosen.pop_back()
			used.erase(s)
	return best

static func _names(rng: RandomNumberGenerator, types: Array) -> Array:
	var pools = {}
	for t in NAMES:
		var pool = NAMES[t].duplicate()
		for i in pool.size():
			var j = rng.randi_range(i, pool.size() - 1)
			var tmp = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		pools[t] = pool
	var names = []
	var counts = {}
	for t in types:
		var name = ""
		if not pools[t].is_empty():
			name = pools[t].pop_back()
		else:
			counts[t] = counts.get(t, 1) + 1
			name = "%s %d" % [NAMES[t][0], counts[t]]
		names.append(name)
	return names

# Arterial roads: a minimum spanning tree over the district graph (bridges included)
static func _roads(centers: Array, neighbors: Array) -> Array:
	var in_tree = {0: true}
	var roads = []
	while in_tree.size() < centers.size():
		var best = []
		var best_len = INF
		for a in in_tree:
			for b in neighbors[a]:
				if not in_tree.has(b) and centers[a].distance_to(centers[b]) < best_len:
					best_len = centers[a].distance_to(centers[b])
					best = [a, b]
		if best.is_empty():
			break
		in_tree[best[1]] = true
		roads.append(best)
	return roads
