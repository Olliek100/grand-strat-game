class_name TraitEngine

var faction_traits: Dictionary = {}

var culture_stats: Dictionary = {
	"media_axis": 0.5,
	"welfare_axis": 0.5,
	"authority_axis": 0.5,
}

func _init():
	for trait_name in GameData.traits():
		faction_traits[trait_name] = Trait.new(trait_name, GameData.traits()[trait_name])

# Returns 1 if the trait just became active, -1 if it just lapsed, 0 otherwise
func add_faction_trait_value(trait_name: String, amount: float) -> int:
	if not faction_traits.has(trait_name):
		return 0
	var t: Trait = faction_traits[trait_name]
	return t.set_value(t.value + amount)

func is_active(trait_name: String) -> bool:
	return faction_traits.has(trait_name) and faction_traits[trait_name].active

func get_active_traits() -> Array:
	var active = []
	for trait_name in faction_traits:
		if is_active(trait_name):
			active.append(trait_name)
	return active

# Odds factors from active traits for a venture, as [[label, multiplier], ...]
func get_venture_factors(venture_id: String) -> Array:
	var factors = []
	for t in faction_traits.values():
		if t.active and t.venture_odds.has(venture_id):
			factors.append([t.name, t.venture_odds[venture_id]])
	return factors

func venture_modifier(venture_id: String) -> float:
	var modifier = 1.0
	for factor in get_venture_factors(venture_id):
		modifier *= factor[1]
	return modifier

# Combined value of a named effect across active traits.
# Effects ending in "_mult" multiply together (default 1.0); others add up (default 0.0).
func effect(effect_name: String) -> float:
	var multiplicative = effect_name.ends_with("_mult")
	var total = 1.0 if multiplicative else 0.0
	for t in faction_traits.values():
		if t.active and t.effects.has(effect_name):
			total = total * t.effects[effect_name] if multiplicative else total + t.effects[effect_name]
	return total

# Active traits carrying an effect, as [[trait name, value], ...], for labelled odds factors
func traits_with_effect(effect_name: String) -> Array:
	var found = []
	for t in faction_traits.values():
		if t.active and t.effects.has(effect_name):
			found.append([t.name, t.effects[effect_name]])
	return found

# Daily drift back toward zero; returns the names of traits that lapsed
func decay() -> Array:
	var lapsed = []
	var amount: float = GameData.rule("trait_daily_decay")
	for t in faction_traits.values():
		if t.value > 0.0 and t.set_value(t.value - amount) == -1:
			lapsed.append(t.name)
	return lapsed

func update_culture(axis: String, delta: float):
	if culture_stats.has(axis):
		culture_stats[axis] = clamp(culture_stats[axis] + delta, 0.0, 1.0)
		_check_culture_trait_threshold(axis)

func _check_culture_trait_threshold(axis: String):
	if axis == "media_axis":
		if culture_stats[axis] > 0.7:
			add_faction_trait_value("Merchant", 5.0)
		elif culture_stats[axis] < 0.3:
			add_faction_trait_value("Militaristic", 3.0)

	if axis == "welfare_axis":
		if culture_stats[axis] > 0.7:
			add_faction_trait_value("Socialist", 5.0)
		elif culture_stats[axis] < 0.3:
			add_faction_trait_value("Militaristic", 3.0)

func to_dict() -> Dictionary:
	var values = {}
	var active = []
	for t in faction_traits.values():
		values[t.name] = t.value
		if t.active:
			active.append(t.name)
	return {"values": values, "active": active, "culture": culture_stats.duplicate()}

func load_dict(data: Dictionary):
	for trait_name in data.get("values", {}):
		if faction_traits.has(trait_name):
			faction_traits[trait_name].value = data["values"][trait_name]
			faction_traits[trait_name].active = trait_name in data.get("active", [])
	for axis in data.get("culture", {}):
		culture_stats[axis] = data["culture"][axis]
