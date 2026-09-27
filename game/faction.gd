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
# Minor factions (gangs, enclaves) start small and grow slowly; personality shapes what their AI likes doing
var minor: bool = false
var personality: String = ""
var blurb: String = ""
# Districts this faction has scouted: id -> day scouted. It knows their salvage, danger and people
var scouted: Dictionary = {}
# Renown: earned by achieving ambitions (data/ambitions.json). Helps treaties get accepted,
# earns respect from other factions, and raises the crew limit.
var renown: float = 0.0
var ambitions_done: Array = []
# Deeds that some ambitions count
var stats: Dictionary = {"districts_conquered": 0, "wars_won": 0, "buildings_built": 0}
# Character id the leader has chosen as heir (-1: the usual order of succession)
var designated_heir: int = -1

func _init(p_id: String, p_name: String, p_color: Color, p_is_player: bool):
	id = p_id
	display_name = p_name
	color = p_color
	is_player = p_is_player
	traits = TraitEngine.new()
	if not is_player:
		ai = FactionAI.new(id)

const RESOURCE_NAMES = {"supplies": "food", "manpower": "manpower", "materials": "materials", "arms": "arms", "wealth": "wealth"}
# Where each resource comes from, for "you can't afford this" messages
const RESOURCE_SOURCES = {
	"supplies": "Secure Food, Allotments, Trade Runs",
	"materials": "Scavenge ruins, Trade Runs (spend wealth), Salvage Yards, Recycling Works (never run out)",
	"wealth": "taxes (more people), Markets, trade agreements",
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
		"manpower": manpower, "supplies": supplies, "materials": materials, "arms": arms, "wealth": wealth, "starving": starving, "broke": broke, "home_id": home_id, "renown": renown, "ambitions_done": ambitions_done.duplicate(), "stats": stats.duplicate(), "scouted": scouted.duplicate(), "disrepair": disrepair, "minor": minor, "personality": personality, "blurb": blurb, "designated_heir": designated_heir,
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
	f.ambitions_done = data["ambitions_done"]
	f.stats = data["stats"]
	f.stats["buildings_built"] = f.stats.get("buildings_built", 0)
	f.scouted = data["scouted"]
	f.disrepair = data["disrepair"]
	f.minor = data["minor"]
	f.personality = data["personality"]
	f.blurb = data["blurb"]
	f.designated_heir = int(data["designated_heir"])
	f.traits.load_dict(data["traits"])
	if f.ai:
		f.ai.load_dict(data["ai"])
	return f
