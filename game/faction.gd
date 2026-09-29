class_name Faction

var id: String
var display_name: String
var color: Color
var is_player: bool

# Manpower: idle bodies to send on ventures (those out on ventures are away until they return).
# Food ("supplies") feeds them and the population; materials build and settle; arms make fighters.
var manpower: float = 15.0
var supplies: float = 40.0
var materials: float = 20.0
# Weapons on hand: stronger raids and defence; used up by fighting
var arms: float = 0.0
var wealth: float = 30.0

var traits: TraitEngine
var starving: bool = false
# Set when wealth runs out: buildings stop working until upkeep can be paid again
var broke: bool = false
# Set when materials run out: buildings fall into disrepair and stop working until repaired
var disrepair: bool = false
# Decision-maker for non-player factions; null for the player
var ai: FactionAI = null
# District the faction started from; used as its capital on the map
var home_id: int = -1
# Minor factions (gangs, enclaves) start small and grow slowly; what they like doing comes from their traits
var minor: bool = false
var blurb: String = ""
# Districts this faction has scouted: id -> day scouted. It knows their salvage, danger and people
var scouted: Dictionary = {}
# Renown is earned by deeds (data/deeds.json) and triumphs, and spent on National Ambitions; unspent, it
# helps treaties get accepted. Reputation is every point ever earned and never goes down: it carries
# renown's lasting effects (crew and captain limits, recruits, the heir's claim, respect).
var renown: float = 0.0
var reputation: float = 0.0
var deeds_done: Array = []
# National Ambitions (data/national_ambitions.json): the one being pursued and days left, those completed
# (their bonuses last for good) and those closed off for good by a rival choice
var ambition: String = ""
var ambition_days_left: int = 0
var ambitions_done: Array = []
var ambitions_closed: Array = []
# effect() answers for the current day: asked for every district several times a day. Cleared each morning
# (and when an ambition completes); not saved
var effect_cache: Dictionary = {}
# Government (data/governments.json): how the faction is run, who succeeds, and how it breaks
var government: String = "warlord"
# No new reform before this day; a caretaker government (Democracy, after a death) until this day;
# the day the last leader died (Hold Elections is only on offer just after)
var reform_locked_until: int = 0
var caretaker_until: int = 0
var last_succession_day: int = -1000
# Counts that some deeds measure
var stats: Dictionary = {"districts_conquered": 0, "wars_won": 0, "buildings_built": 0}
# Character id the leader has chosen as heir (-1: the usual order of succession)
var designated_heir: int = -1
# What the faction has been putting its effort into lately: moves at home and abroad, fading over about 90 days
var lean: Dictionary = {"home": 0.0, "abroad": 0.0}

func _init(p_id: String, p_name: String, p_color: Color, p_is_player: bool):
	id = p_id
	display_name = p_name
	color = p_color
	is_player = p_is_player
	traits = TraitEngine.new()
	if not is_player:
		ai = FactionAI.new(id)

const RESOURCE_NAMES = {"supplies": "food", "manpower": "manpower", "materials": "materials", "arms": "arms", "wealth": "wealth", "renown": "renown"}
# Where each resource comes from, for "you can't afford this" messages
const RESOURCE_SOURCES = {
	"supplies": "Secure Food, Allotments, Trade Runs",
	"materials": "Scavenge ruins, Trade Runs (spend wealth), Salvage Yards, Recycling Works (never run out)",
	"wealth": "taxes (more people), Markets, trade agreements",
	"renown": "deeds (the milestones in the Ambitions window) and triumphs",
	"arms": "Gather Weapons",
	"manpower": "grows from the food your districts produce",
}

# What's missing to pay these costs, e.g. "Need 6 more materials (have 2 of 8): Scavenge ruins, ...",
# or "" if affordable
func shortfall(costs: Dictionary) -> String:
	var parts = []
	var sources = []
	for resource_type in costs:
		var have: float = get(resource_type)
		var need: float = costs[resource_type]
		if have < need:
			parts.append("%d more %s (have %d of %d)" % [ceili(need - have), RESOURCE_NAMES.get(resource_type, resource_type), int(have), ceili(need)])
			sources.append("%s from %s" % [RESOURCE_NAMES.get(resource_type, resource_type).capitalize(), RESOURCE_SOURCES.get(resource_type, "?")])
	if parts.is_empty():
		return ""
	return "Need %s. %s" % [" and ".join(parts), ". ".join(sources)]

# A named effect across everything that shapes the faction: its active traits, the lasting bonuses of
# completed ambitions, and its government. Effects ending in "_mult" multiply (default 1.0); the rest add up (default 0.0).
func effect(effect_name: String) -> float:
	if effect_cache.has(effect_name):
		return effect_cache[effect_name]
	var total = traits.effect(effect_name)
	var multiplicative = effect_name.ends_with("_mult")
	for id in ambitions_done:
		var value = GameData.national_ambition(id)["bonus"].get("effects", {}).get(effect_name)
		if value != null:
			total = total * value if multiplicative else total + value
	var from_government = GameData.government(government)["effects"].get(effect_name)
	if from_government != null:
		total = total * from_government if multiplicative else total + from_government
	effect_cache[effect_name] = total
	return total

# The same, labelled, for odds and breakdowns: [[source, value], ...]
func effects_with_labels(effect_name: String) -> Array:
	var found = traits.traits_with_effect(effect_name)
	for id in ambitions_done:
		var def = GameData.national_ambition(id)
		if def["bonus"].get("effects", {}).has(effect_name):
			found.append([def["label"], def["bonus"]["effects"][effect_name]])
	var gov = GameData.government(government)
	if gov["effects"].has(effect_name):
		found.append([gov["label"], gov["effects"][effect_name]])
	return found

# Odds factors a venture gets from the faction itself (traits, completed ambitions, government), as [[label, multiplier], ...]
func venture_factors(venture_id: String) -> Array:
	var factors = traits.get_venture_factors(venture_id)
	for id in ambitions_done:
		var def = GameData.national_ambition(id)
		if def["bonus"].get("venture_odds", {}).has(venture_id):
			factors.append([def["label"], def["bonus"]["venture_odds"][venture_id]])
	var gov = GameData.government(government)
	if gov.get("venture_odds", {}).has(venture_id):
		factors.append([gov["label"], gov["venture_odds"][venture_id]])
	var skill: String = GameData.venture(venture_id)["skill"]
	if gov.get("skill_odds", {}).has(skill):
		factors.append(["%s rule" % gov["label"], gov["skill_odds"][skill]])
	return factors

# Renown earned by deeds and triumphs also adds to reputation, which never goes down
func add_renown(amount: float):
	renown += amount
	reputation += amount

func can_afford(costs: Dictionary) -> bool:
	for resource_type in costs:
		if get(resource_type) < costs[resource_type]:
			return false
	return true

func pay(costs: Dictionary):
	for resource_type in costs:
		set(resource_type, get(resource_type) - costs[resource_type])

func to_dict() -> Dictionary:
	return {
		"id": id, "name": display_name, "color": color.to_html(false), "player": is_player,
		"manpower": manpower, "supplies": supplies, "materials": materials, "arms": arms, "wealth": wealth, "starving": starving, "broke": broke, "home_id": home_id, "renown": renown, "reputation": reputation, "deeds_done": deeds_done.duplicate(), "ambition": ambition, "ambition_days_left": ambition_days_left, "ambitions_done": ambitions_done.duplicate(), "ambitions_closed": ambitions_closed.duplicate(), "government": government, "reform_locked_until": reform_locked_until, "caretaker_until": caretaker_until, "last_succession_day": last_succession_day, "stats": stats.duplicate(), "scouted": scouted.duplicate(), "disrepair": disrepair, "minor": minor, "blurb": blurb, "designated_heir": designated_heir, "lean": lean.duplicate(),
		"traits": traits.to_dict(), "ai": ai.to_dict() if ai else {},
	}

static func from_dict(data: Dictionary) -> Faction:
	var f = Faction.new(data["id"], data["name"], Color.html(data["color"]), data["player"])
	f.manpower = data["manpower"]
	f.supplies = data["supplies"]
	f.materials = data["materials"]
	f.arms = data["arms"]
	f.wealth = data["wealth"]
	f.starving = data["starving"]
	f.broke = data["broke"]
	f.home_id = int(data["home_id"])
	f.renown = data["renown"]
	f.reputation = data["reputation"]
	f.deeds_done = data["deeds_done"]
	f.ambition = data["ambition"]
	f.ambition_days_left = int(data["ambition_days_left"])
	f.ambitions_done = data["ambitions_done"]
	f.ambitions_closed = data["ambitions_closed"]
	f.government = data["government"]
	f.reform_locked_until = int(data["reform_locked_until"])
	f.caretaker_until = int(data["caretaker_until"])
	f.last_succession_day = int(data["last_succession_day"])
	f.stats = data["stats"]
	f.stats["buildings_built"] = f.stats.get("buildings_built", 0)
	f.scouted = data["scouted"]
	f.disrepair = data["disrepair"]
	f.minor = data["minor"]
	f.blurb = data["blurb"]
	f.designated_heir = int(data["designated_heir"])
	f.lean = {"home": float(data["lean"]["home"]), "abroad": float(data["lean"]["abroad"])}
	f.traits.load_dict(data["traits"])
	if f.ai:
		f.ai.load_dict(data["ai"])
	return f
