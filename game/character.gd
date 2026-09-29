class_name Character

# A named member of a faction's crew who can lead ventures. Captains can be given one of the
# four council seats (data/council.json); families and succession build on this later
# (see 07-characters-and-ventures-outline.md).

const SKILLS = ["command", "cunning", "diplomacy", "stewardship"]

var id: int
var faction_id: String
var name: String
var age: int
# Each skill 0-10; the skill a venture uses shapes its odds and its chance of Triumph
var skills: Dictionary = {"command": 0, "cunning": 0, "diplomacy": 0, "stewardship": 0}
# Unavailable until this day while recovering from a wound
var wounded_until: int = 0
# A councillor who worked a standing task takes no new work before this day (doc 13: the commitment)
var committed_until: int = 0
var ventures_led: int = 0
var triumphs: int = 0
var wounds: int = 0
# Council seat held ("" for a plain captain), see data/council.json "posts"
var post: String = ""
# Trait ids from data/council.json: personality ones from birth, the rest earned
var traits: Array = []
# Loyalty memories as [{"id", "value"}, ...] that fade over time, like faction opinion
var loyalty_mods: Array = []
var restless_warned: bool = false
# "m" or "f"
var sex: String = "m"
# The faction's ruler (at most one per faction); rulers don't lead ventures
var is_leader: bool = false
# Part of the ruling family: preferred heirs. Their dynasty is the family name
var family: bool = false
var dynasty: String = ""
var parent_ids: Array = []
var spouse_id: int = -1
# Loyalty from how much they respect the current leader (set by the city each month)
var respect: float = 0.0
var respect_label: String = ""
# Day this character took power (leaders only)
var ruling_since: int = 0
# The faction's deeds when this leader took power, and days of peace since: ruling traits are earned from the difference
var rule_start: Dictionary = {}
var peace_days: int = 0
# For the dead (kept for family trees): the day and how they died
var death_day: int = -1
var fate: String = ""

func _init(p_id: int, p_faction_id: String, p_name: String, p_age: int):
	id = p_id
	faction_id = p_faction_id
	name = p_name
	age = p_age

func is_wounded(day: int) -> bool:
	return day < wounded_until

func best_skill() -> String:
	var best = SKILLS[0]
	for s in SKILLS:
		if skills[s] > skills[best]:
			best = s
	return best

func has_trait(trait_id: String) -> bool:
	return trait_id in traits

# Loyalty to the faction's leadership, 0-100, with the reasons behind it as [[label, value], ...]
func loyalty_breakdown() -> Array:
	var parts = [["Base", float(GameData.rule("loyalty_base"))]]
	for t in traits:
		var def = GameData.character_trait(t)
		if def.has("loyalty"):
			parts.append([def["label"], float(def["loyalty"])])
		if def.has("loyalty_off_council") and post == "":
			parts.append(["%s, no council seat" % def["label"], float(def["loyalty_off_council"])])
	if respect_label != "" and absf(respect) >= 0.5:
		parts.append([respect_label, respect])
	for m in loyalty_mods:
		if absf(m["value"]) >= 0.5:
			parts.append([GameData.loyalty_modifier(m["id"])["label"], m["value"]])
	return parts

func loyalty() -> float:
	var total = 0.0
	for part in loyalty_breakdown():
		total += part[1]
	return clampf(total, 0.0, 100.0)

func change_loyalty(amount: float, modifier_id: String):
	var limit: float = GameData.loyalty_modifier(modifier_id)["limit"]
	for m in loyalty_mods:
		if m["id"] == modifier_id:
			m["value"] = clampf(m["value"] + amount, -limit, limit)
			return
	loyalty_mods.append({"id": modifier_id, "value": clampf(amount, -limit, limit)})

# Memories fade a little each day
func decay_loyalty():
	for i in range(loyalty_mods.size() - 1, -1, -1):
		var m = loyalty_mods[i]
		var decay: float = GameData.loyalty_modifier(m["id"])["decay"]
		m["value"] = move_toward(m["value"], 0.0, decay)
		if m["value"] == 0.0:
			loyalty_mods.remove_at(i)

# Odds multiplier from this leader's traits for a venture using the given skill, as [[label, mult], ...]
func trait_factors(skill: String) -> Array:
	var factors = []
	for t in traits:
		var def = GameData.character_trait(t)
		var mult = float(def.get("odds", 1.0)) * float(def.get("skill_odds", {}).get(skill, 1.0))
		if mult != 1.0:
			factors.append(["%s is %s" % [name, def["label"]], mult])
	return factors

func triumph_bonus() -> float:
	var bonus = 0.0
	for t in traits:
		bonus += float(GameData.character_trait(t).get("triumph_share", 0.0))
	return bonus

func to_dict() -> Dictionary:
	return {"id": id, "faction": faction_id, "name": name, "age": age, "skills": skills.duplicate(),
		"wounded_until": wounded_until, "committed_until": committed_until, "ventures_led": ventures_led, "triumphs": triumphs, "wounds": wounds,
		"post": post, "traits": traits.duplicate(), "loyalty_mods": loyalty_mods.duplicate(true), "restless_warned": restless_warned,
		"sex": sex, "is_leader": is_leader, "family": family, "dynasty": dynasty, "parent_ids": parent_ids.duplicate(), "spouse_id": spouse_id,
		"respect": respect, "respect_label": respect_label, "ruling_since": ruling_since,
		"rule_start": rule_start.duplicate(), "peace_days": peace_days, "death_day": death_day, "fate": fate}

static func from_dict(data: Dictionary) -> Character:
	var c = Character.new(int(data["id"]), data["faction"], data["name"], int(data["age"]))
	c.skills = data["skills"]
	c.wounded_until = int(data["wounded_until"])
	c.committed_until = int(data["committed_until"])
	c.ventures_led = int(data["ventures_led"])
	c.triumphs = int(data["triumphs"])
	c.wounds = int(data["wounds"])
	c.post = data["post"]
	c.traits = data["traits"]
	c.loyalty_mods = data["loyalty_mods"]
	c.restless_warned = data["restless_warned"]
	c.sex = data["sex"]
	c.is_leader = data["is_leader"]
	c.family = data["family"]
	c.dynasty = data["dynasty"]
	c.parent_ids = data["parent_ids"]
	c.spouse_id = int(data["spouse_id"])
	c.respect = data["respect"]
	c.respect_label = data["respect_label"]
	c.ruling_since = int(data["ruling_since"])
	c.rule_start = data["rule_start"]
	c.peace_days = int(data["peace_days"])
	c.death_day = int(data["death_day"])
	c.fate = data["fate"]
	return c

func is_adult() -> bool:
	return age >= 16

func best_skill_value() -> int:
	return int(skills[best_skill()])
