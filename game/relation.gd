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
# The player has been told this war could end now (said once per war)
var peace_ready_told: bool = false

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

# Raiding between the two, per faction id (days; 0 = never):
# the last day that side raided the other, or demanded tribute from it
var last_raid: Dictionary = {}
var last_demand: Dictionary = {}
# That side has promised not to raid the other until this day (tribute paid, or threatened off)
var spare_until: Dictionary = {}
# That side raids the other with better odds until this day (a demand refused, a threat that backfired)
var bold_until: Dictionary = {}

# A war goal one side is pressing on the other (doc 15, P2), or {} if none:
# {"by", "goal" (see data/war_goals.json), "district" (id, or -1), "reason" ("" if none), "stage" ("justifying",
# "ultimatum" or "war"), "ready_day" (justified on this day), "started" (the day the target was told), "told_early" (the target
# has been warned the ultimatum can now come at any time), "deadline" (the ultimatum's answer is due)}
var claim: Dictionary = {}
# War score from the claimant's side, before exhaustion is counted (see CityMap.war_score)
var war_points: float = 0.0
# Marriages between the two factions' families (doc 16, H3): [[a character id, b character id], ...]
var marriages: Array = []
# Where each side's opinion baseline is heading, refreshed every few days (saved, so a reloaded game plays out the same)
var baseline_target: Dictionary = {}
# Asks made between the two (doc 18): "from_id|action_id" -> {"day", "until" (asking again is blocked until this day), "refusals"}
var asks: Dictionary = {}

func _init(p_a: String, p_b: String):
	a = p_a
	b = p_b
	exhaustion = {a: 0.0, b: 0.0}
	opinion = {a: 0.0, b: 0.0}
	baseline = {a: 0.0, b: 0.0}
	modifiers = {a: [], b: []}
	last_raid = {a: 0, b: 0}
	last_demand = {a: 0, b: 0}
	spare_until = {a: 0, b: 0}
	bold_until = {a: 0, b: 0}

# Whether `faction_id` raided the other side, or demanded tribute from it, in the last `days` days
func menaced_recently(faction_id: String, day: int, days: int) -> bool:
	return (last_raid[faction_id] > 0 and day - last_raid[faction_id] <= days) or (last_demand[faction_id] > 0 and day - last_demand[faction_id] <= days)

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
		labels.append("Your tributary" if overlord == viewer_id else ("Your suzerain" if other(viewer_id) == overlord else "Tributary"))
	return labels

func to_dict() -> Dictionary:
	return {
		"a": a, "b": b, "at_war": at_war, "war_start_day": war_start_day, "truce_until_day": truce_until_day,
		"exhaustion": exhaustion.duplicate(), "opinion": opinion.duplicate(), "peace_offered_by": peace_offered_by, "peace_ready_told": peace_ready_told,
		"trade": trade, "pact": pact, "alliance": alliance, "overlord": overlord, "vassal_since_day": vassal_since_day, "treaty_until_day": treaty_until_day,
		"baseline": baseline.duplicate(), "modifiers": modifiers.duplicate(true), "lapse_warned": lapse_warned,
		"last_raid": last_raid.duplicate(), "last_demand": last_demand.duplicate(), "spare_until": spare_until.duplicate(), "bold_until": bold_until.duplicate(),
		"claim": claim.duplicate(), "war_points": war_points, "marriages": marriages.duplicate(true), "asks": asks.duplicate(true), "baseline_target": baseline_target.duplicate(),
	}

static func from_dict(data: Dictionary) -> Relation:
	var r = Relation.new(data["a"], data["b"])
	r.at_war = data["at_war"]
	r.war_start_day = int(data["war_start_day"])
	r.truce_until_day = int(data["truce_until_day"])
	r.exhaustion = data["exhaustion"]
	r.opinion = data["opinion"]
	r.peace_offered_by = data["peace_offered_by"]
	r.peace_ready_told = data["peace_ready_told"]
	r.trade = data["trade"]
	r.pact = data["pact"]
	r.alliance = data["alliance"]
	r.overlord = data["overlord"]
	r.vassal_since_day = int(data["vassal_since_day"])
	r.treaty_until_day = int(data["treaty_until_day"])
	r.baseline = data["baseline"]
	r.modifiers = data["modifiers"]
	r.lapse_warned = data["lapse_warned"]
	r.claim = data["claim"]
	r.war_points = data["war_points"]
	r.marriages = data["marriages"]
	r.asks = data["asks"]
	r.baseline_target = data["baseline_target"]
	for key in ["last_raid", "last_demand", "spare_until", "bold_until"]:
		var saved: Dictionary = data[key]
		for fid in saved:
			r.get(key)[fid] = int(saved[fid])
	return r
