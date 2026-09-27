class_name Relation

# The diplomatic state between one pair of factions

var a: String
var b: String
var at_war: bool = false
var war_start_day: int = 0
var truce_until_day: int = 0
# Per faction id: how worn down that side is by this war (0-100)
var exhaustion: Dictionary = {}
# Per faction id: how that side feels about the other (-100 to 100). It is the baseline (who they
# both are and what binds them, see Diplomacy.opinion_baseline) plus named memories that fade.
var opinion: Dictionary = {}
var baseline: Dictionary = {}
# Per faction id: that side's memories of the other, as [{"id", "value"}, ...] (see data/opinion_modifiers.json)
var modifiers: Dictionary = {}
# Faction id that has offered peace and is waiting for an answer, or ""
var peace_offered_by: String = ""

# Treaties
var trade: bool = false
var pact: bool = false
var alliance: bool = false
# Faction id of the overlord if one side is the other's vassal, else ""
var overlord: String = ""
var vassal_since_day: int = 0
# Pacts and alliances lapse on this day unless renewed
var treaty_until_day: int = 0
# Set once both sides have been warned that the pact or alliance is about to lapse
var lapse_warned: bool = false

func _init(p_a: String, p_b: String):
	a = p_a
	b = p_b
	exhaustion = {a: 0.0, b: 0.0}
	opinion = {a: 0.0, b: 0.0}
	baseline = {a: 0.0, b: 0.0}
	modifiers = {a: [], b: []}

func other(faction_id: String) -> String:
	return b if faction_id == a else a

func involves(faction_id: String) -> bool:
	return faction_id == a or faction_id == b

# Recomputes one side's opinion from its baseline and memories
func recompute_opinion(faction_id: String):
	var total: float = baseline[faction_id]
	for m in modifiers[faction_id]:
		total += m["value"]
	opinion[faction_id] = clampf(total, -100.0, 100.0)

# Treaties that forbid hostile acts between the two sides
func protected() -> bool:
	return pact or alliance or overlord != ""

func treaty_labels(viewer_id: String) -> Array:
	var labels = []
	if trade:
		labels.append("Trade agreement")
	if alliance:
		labels.append("Defensive alliance")
	elif pact:
		labels.append("Non-aggression pact")
	if overlord != "":
		labels.append("Your vassal" if overlord == viewer_id else ("Your overlord" if other(viewer_id) == overlord else "Vassalage"))
	return labels

func to_dict() -> Dictionary:
	return {
		"a": a, "b": b, "at_war": at_war, "war_start_day": war_start_day, "truce_until_day": truce_until_day,
		"exhaustion": exhaustion.duplicate(), "opinion": opinion.duplicate(), "peace_offered_by": peace_offered_by,
		"trade": trade, "pact": pact, "alliance": alliance, "overlord": overlord, "vassal_since_day": vassal_since_day, "treaty_until_day": treaty_until_day,
		"baseline": baseline.duplicate(), "modifiers": modifiers.duplicate(true), "lapse_warned": lapse_warned,
	}

static func from_dict(data: Dictionary) -> Relation:
	var r = Relation.new(data["a"], data["b"])
	r.at_war = data["at_war"]
	r.war_start_day = int(data["war_start_day"])
	r.truce_until_day = int(data["truce_until_day"])
	r.exhaustion = data["exhaustion"]
	r.opinion = data["opinion"]
	r.peace_offered_by = data["peace_offered_by"]
	r.trade = data["trade"]
	r.pact = data["pact"]
	r.alliance = data["alliance"]
	r.overlord = data["overlord"]
	r.vassal_since_day = int(data["vassal_since_day"])
	r.treaty_until_day = int(data["treaty_until_day"])
	r.baseline = data["baseline"]
	r.modifiers = data["modifiers"]
	r.lapse_warned = data["lapse_warned"]
	return r
