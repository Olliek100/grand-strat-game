class_name ActiveVenture

# A venture that has been funded and is under way; it resolves when days_left hits zero

var venture_id: String
var faction_id: String
# Faction the venture is aimed at ("" for expeditions and work in your own districts)
var target_id: String
var district: District
var crew: int
# The character leading it (-1 if none) and how many levels of extra funding were paid
var leader_id: int = -1
var funding: int = 0
var days_total: int
var days_left: int

func _init(p_venture_id: String, p_faction_id: String, p_target_id: String, p_district: District, p_crew: int, p_days: int):
	venture_id = p_venture_id
	faction_id = p_faction_id
	target_id = p_target_id
	district = p_district
	crew = p_crew
	days_total = p_days
	days_left = p_days

func progress() -> float:
	return 1.0 - float(days_left) / days_total

func to_dict() -> Dictionary:
	return {
		"venture": venture_id, "faction": faction_id, "target": target_id, "district": district.id,
		"crew": crew, "days_total": days_total, "days_left": days_left, "leader": leader_id, "funding": funding,
	}

static func from_dict(data: Dictionary, districts: Array[District]) -> ActiveVenture:
	var v = ActiveVenture.new(data["venture"], data["faction"], data["target"], districts[int(data["district"])],
		int(data["crew"]), int(data["days_total"]))
	v.days_left = int(data["days_left"])
	v.leader_id = int(data["leader"])
	v.funding = int(data["funding"])
	return v
