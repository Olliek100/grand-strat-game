class_name Construction

# A building under construction. Its crew is tied up until it's finished.

var building_id: String
var faction_id: String
var district: District
var crew: int
var days_total: int
var days_left: int

func _init(p_building_id: String, p_faction_id: String, p_district: District, p_crew: int, p_days: int):
	building_id = p_building_id
	faction_id = p_faction_id
	district = p_district
	crew = p_crew
	days_total = p_days
	days_left = p_days

func progress() -> float:
	return 1.0 - float(days_left) / days_total

func to_dict() -> Dictionary:
	return {
		"building": building_id, "faction": faction_id, "district": district.id,
		"crew": crew, "days_total": days_total, "days_left": days_left,
	}

static func from_dict(data: Dictionary, districts: Array[District]) -> Construction:
	var c = Construction.new(data["building"], data["faction"], districts[int(data["district"])],
		int(data["crew"]), int(data["days_total"]))
	c.days_left = int(data["days_left"])
	return c
