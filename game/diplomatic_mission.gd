class_name DiplomaticMission

# An envoy on the way to another faction. When it arrives, the action resolves:
# gifts are delivered, and proposals are accepted or refused (or, to the player, await an answer).

var action_id: String
var from_id: String
var to_id: String
var days_total: int
var days_left: int

func _init(p_action_id: String, p_from_id: String, p_to_id: String, p_days: int):
	action_id = p_action_id
	from_id = p_from_id
	to_id = p_to_id
	days_total = p_days
	days_left = p_days

func to_dict() -> Dictionary:
	return {"action": action_id, "from": from_id, "to": to_id, "days_total": days_total, "days_left": days_left}

static func from_dict(data: Dictionary) -> DiplomaticMission:
	var m = DiplomaticMission.new(data["action"], data["from"], data["to"], int(data["days_total"]))
	m.days_left = int(data["days_left"])
	return m
