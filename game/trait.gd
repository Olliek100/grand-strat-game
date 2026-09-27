class_name Trait

# A trait's definition comes from data/traits.json; value and active state are per faction

var name: String
var value: float = 0.0
var description: String
var benefit: String
var cost: String
# Behaviour that feeds this trait; empty if nothing in the game grants it yet
var source: String
var threshold: float = 30.0
# venture id -> odds multiplier while active
var venture_odds: Dictionary = {}
# named effect -> value while active (see TraitEngine.effect)
var effects: Dictionary = {}
# Traits a faction with this trait likes or distrusts in others (feeds opinion)
var likes: Array = []
var dislikes: Array = []
var active: bool = false

# Once active, a trait only lapses after falling this far below the threshold,
# so it doesn't flicker on and off around the line
const LAPSE_MARGIN = 5.0

func _init(p_name: String, def: Dictionary):
	name = p_name
	description = def.get("description", "")
	benefit = def.get("benefit", "")
	cost = def.get("cost", "")
	source = def.get("source", "")
	threshold = def.get("threshold", 30.0)
	venture_odds = def.get("venture_odds", {})
	effects = def.get("effects", {})
	likes = def.get("likes", [])
	dislikes = def.get("dislikes", [])

# Returns 1 if the trait just became active, -1 if it just lapsed, 0 otherwise
func set_value(new_value: float) -> int:
	value = clampf(new_value, 0.0, 100.0)
	if not active and value >= threshold:
		active = true
		return 1
	if active and value < threshold - LAPSE_MARGIN:
		active = false
		return -1
	return 0
