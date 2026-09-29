class_name District

var id: int
var district_name: String

# Influence share per faction id (0-100, total <= 100). A share of 50+ controls the district.
var influence: Dictionary = {}

# State
var population: float = 50.0
var grievance: float = 20.0
var ruin_level: float = 0.5
var development: float = 0.3
# Lasting food sources found by Secure Food ventures (food per day, before buildings)
var food_yield: float = 0.0
# Danger 0-0.6: ferals, traps, raiders. Hurts odds and raises disaster chances; scouting reveals it
var hazard: float = 0.15
# No raids here before this day: raiders pull back after a raid, longer after a failed one
var raid_safe_until: int = 0

# Map shape
var polygon: PackedVector2Array
var center: Vector2
# Indices into CityMap.districts (ids, not references, to avoid reference cycles)
var neighbor_ids: Array[int] = []

# Set once the player has been warned about unrest, cleared when it calms down
var unrest_warned: bool = false

# From the map layout: what kind of place this is, and which borough it belongs to
var district_type: String = "residential"
var borough: String = ""

# Building ids from data/buildings.json, in the order they were built
var buildings: Array[String] = []

# Effects buildings can declare (see effects in data/buildings.json)
const BUILDING_EFFECTS = ["defence_mult", "grievance_daily", "growth_mult", "wealth_daily", "supplies_daily", "materials_daily",
	"ruin_daily", "crew_cap", "recruit_mult", "development_daily", "trade_income"]

# Combined value of a named effect across this district's buildings.
# Effects ending in "_mult" multiply together (default 1.0); others add up (default 0.0).
func building_effect(effect_name: String) -> float:
	var multiplicative = effect_name.ends_with("_mult")
	var total = 1.0 if multiplicative else 0.0
	for building_id in buildings:
		var effects: Dictionary = GameData.building(building_id)["effects"]
		if effects.has(effect_name):
			total = total * effects[effect_name] if multiplicative else total + effects[effect_name]
	return total

func building_labels() -> Array:
	var labels = []
	for building_id in buildings:
		labels.append(GameData.building(building_id)["label"])
	return labels

func _init(p_id: int, p_name: String, p_polygon: PackedVector2Array):
	id = p_id
	district_name = p_name
	polygon = p_polygon
	for point in polygon:
		center += point
	center /= polygon.size()

func share(faction_id: String) -> float:
	return influence.get(faction_id, 0.0)

# Gaining influence squeezes other factions' shares so the total never exceeds 100
func add_influence(faction_id: String, amount: float):
	influence[faction_id] = clampf(share(faction_id) + amount, 0.0, 100.0)
	var total = 0.0
	for fid in influence:
		total += influence[fid]
	if total <= 100.0:
		return
	var excess = total - 100.0
	var others = total - influence[faction_id]
	for fid in influence:
		if fid != faction_id and others > 0.0:
			influence[fid] -= excess * influence[fid] / others

func owner_id() -> String:
	for fid in influence:
		if influence[fid] >= 50.0:
			return fid
	return ""

# unexplored -> contested -> claimed -> secured
func get_control_status() -> String:
	var top = 0.0
	for value in influence.values():
		top = maxf(top, value)
	if top < 10.0:
		return "unexplored"
	if top >= 75.0:
		return "secured"
	if top >= 50.0:
		return "claimed"
	return "contested"

# Geometry isn't saved: the map is regenerated from its fixed seed, then this state is applied
func to_dict() -> Dictionary:
	return {
		"influence": influence.duplicate(), "population": population, "grievance": grievance,
		"ruin_level": ruin_level, "development": development, "unrest_warned": unrest_warned,
		"buildings": buildings.duplicate(), "food_yield": food_yield, "hazard": hazard, "raid_safe_until": raid_safe_until,
	}

func load_dict(data: Dictionary):
	influence = data["influence"]
	population = data["population"]
	grievance = data["grievance"]
	ruin_level = data["ruin_level"]
	development = data["development"]
	unrest_warned = data["unrest_warned"]
	buildings.assign(data["buildings"])
	food_yield = data["food_yield"]
	hazard = data["hazard"]
	raid_safe_until = data["raid_safe_until"]
