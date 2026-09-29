class_name GameData

# Loads the game's content from res://data. Ventures, traits, the starting scenario and the
# tuning numbers live in JSON, so content can be added or rebalanced without touching code.
# Code provides the building blocks (targeting rules, odds factors, effect ops) that data combines.

const DATA_DIR = "res://data/"

static var _cache: Dictionary = {}

static func ventures() -> Dictionary:
	return _load("ventures")

static func venture(id: String) -> Dictionary:
	return ventures()[id]

static func buildings() -> Dictionary:
	return _load("buildings")

static func building(id: String) -> Dictionary:
	return buildings()[id]

static func diplomacy_actions() -> Dictionary:
	return _load("diplomacy")

static func diplomacy_action(id: String) -> Dictionary:
	return diplomacy_actions()[id]

static func map() -> Dictionary:
	return _load("map")

static func district_types() -> Dictionary:
	return _load("district_types")

static func district_type(id: String) -> Dictionary:
	return district_types()[id]

static func opinion_modifier(id: String) -> Dictionary:
	return _load("opinion_modifiers")[id]

static func opinion_modifiers() -> Dictionary:
	return _load("opinion_modifiers")

static func deeds() -> Dictionary:
	return _load("deeds")

static func national_ambitions() -> Dictionary:
	return _load("national_ambitions")

static func national_ambition(id: String) -> Dictionary:
	return national_ambitions()[id]

static func governments() -> Dictionary:
	return _load("governments")

static func government(id: String) -> Dictionary:
	return governments()[id]

static func council() -> Dictionary:
	return _load("council")

static func council_post(id: String) -> Dictionary:
	return council()["posts"][id]

static func character_trait(id: String) -> Dictionary:
	return council()["traits"][id]

static func loyalty_modifier(id: String) -> Dictionary:
	return council()["loyalty"][id]

static func names() -> Dictionary:
	return _load("names")

static func traits() -> Dictionary:
	return _load("traits")

static func scenario() -> Dictionary:
	return _load("scenario")

static func rules() -> Dictionary:
	return _load("rules")

static func rule(key: String):
	return rules()[key]

static func _load(file_name: String) -> Dictionary:
	if not _cache.has(file_name):
		var path = DATA_DIR + file_name + ".json"
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY:
			push_error("Could not load %s (missing file or invalid JSON)" % path)
			data = {}
		_cache[file_name] = data
	return _cache[file_name]

# Lists problems in the data files (empty if everything is consistent), so a typo in JSON
# shows up as a clear message at startup instead of a crash mid-game
static func validate() -> Array:
	var problems = []
	var required = ["label", "description", "base_success", "crew", "cost", "days", "target",
		"odds_factors", "success_effects", "failure_effects", "ai_goal", "on_success", "on_failure"]
	for id in ventures():
		var v: Dictionary = ventures()[id]
		for key in required:
			if not v.has(key):
				problems.append("Venture '%s' is missing '%s'" % [id, key])
		if v.get("target") not in VentureSystem.TARGET_KINDS:
			problems.append("Venture '%s' has unknown target '%s'" % [id, v.get("target")])
		if v.get("ai_goal") not in FactionAI.GOALS:
			problems.append("Venture '%s' has unknown ai_goal '%s'" % [id, v.get("ai_goal")])
		for tier in VentureSystem.TIERS:
			if v.has("raid_cooldown") and not v["raid_cooldown"].has(tier):
				problems.append("Venture '%s' raid_cooldown has no '%s' days" % [id, tier])
		for factor in v.get("odds_factors", []):
			if factor not in VentureSystem.ODDS_FACTORS:
				problems.append("Venture '%s' has unknown odds factor '%s'" % [id, factor])
		for effect in v.get("success_effects", []) + v.get("failure_effects", []):
			if effect.get("op") not in VentureSystem.EFFECT_OPS:
				problems.append("Venture '%s' has unknown effect op '%s'" % [id, effect.get("op")])
		if v.get("skill") not in Character.SKILLS:
			problems.append("Venture '%s' has unknown skill '%s'" % [id, v.get("skill")])
		var crew_range: Array = v.get("crew_range", [])
		if crew_range.size() != 2 or v.get("crew", 0) < crew_range[0] or v.get("crew", 0) > crew_range[1]:
			problems.append("Venture '%s' needs a crew_range that includes its crew" % id)
		for effect in v.get("triumph_effects", []) + v.get("disaster_effects", []):
			if effect.get("op") not in VentureSystem.EFFECT_OPS:
				problems.append("Venture '%s' has unknown effect op '%s'" % [id, effect.get("op")])
		var fed = v.get("feeds_trait", "")
		if fed != "" and not traits().has(fed):
			problems.append("Venture '%s' feeds unknown trait '%s'" % [id, fed])
	var building_keys = ["label", "description", "summary", "requires", "cost", "crew", "days", "upkeep", "effects", "ai_goal"]
	for id in buildings():
		var b: Dictionary = buildings()[id]
		for key in building_keys:
			if not b.has(key):
				problems.append("Building '%s' is missing '%s'" % [id, key])
		if b.get("requires") not in ["claimed", "secured"]:
			problems.append("Building '%s' requires unknown status '%s'" % [id, b.get("requires")])
		if b.get("ai_goal") not in FactionAI.BUILD_GOALS:
			problems.append("Building '%s' has unknown ai_goal '%s'" % [id, b.get("ai_goal")])
		for effect_name in b.get("effects", {}):
			if effect_name not in District.BUILDING_EFFECTS:
				problems.append("Building '%s' has unknown effect '%s'" % [id, effect_name])
		for venture_id in b.get("venture_odds", {}):
			if not ventures().has(venture_id):
				problems.append("Building '%s' modifies unknown venture '%s'" % [id, venture_id])
	for trait_name in traits():
		for venture_id in traits()[trait_name].get("venture_odds", {}):
			if not ventures().has(venture_id):
				problems.append("Trait '%s' modifies unknown venture '%s'" % [trait_name, venture_id])
		for goal in traits()[trait_name].get("ai_goals", {}):
			if goal not in FactionAI.GOALS:
				problems.append("Trait '%s' weights unknown AI goal '%s'" % [trait_name, goal])
	for id in deeds():
		var amb: Dictionary = deeds()[id]
		if amb.get("condition", {}).get("type") not in CityMap.DEED_CONDITIONS:
			problems.append("Deed '%s' has unknown condition '%s'" % [id, amb.get("condition", {}).get("type")])
	for id in ventures():
		for effect in ventures()[id].get("success_effects", []) + ventures()[id].get("failure_effects", []):
			if effect.get("op") == "opinion" and not opinion_modifiers().has(effect.get("modifier", "raided")):
				problems.append("Venture '%s' uses unknown opinion modifier '%s'" % [id, effect.get("modifier")])
	var layout_districts: Array = map().get("districts", [])
	if layout_districts.is_empty():
		problems.append("data/map.json has no districts (run tools/generate_map.gd)")
	for d in layout_districts:
		if not district_types().has(d.get("type", "")):
			problems.append("District '%s' has unknown type '%s'" % [d.get("name"), d.get("type")])
		for n in d.get("neighbors", []):
			if int(n) >= layout_districts.size() or int(d["id"]) not in layout_districts[int(n)]["neighbors"].map(func(x): return int(x)):
				problems.append("District '%s' has a one-way or invalid neighbour %s" % [d.get("name"), n])
	for trait_name in traits():
		for other in traits()[trait_name].get("likes", []) + traits()[trait_name].get("dislikes", []):
			if not traits().has(other):
				problems.append("Trait '%s' likes or dislikes unknown trait '%s'" % [trait_name, other])
	for id in diplomacy_actions():
		var action: Dictionary = diplomacy_actions()[id]
		if action.get("kind") not in ["gift", "treaty", "integrate", "tribute", "demand"]:
			problems.append("Diplomatic action '%s' has unknown kind '%s'" % [id, action.get("kind")])
		for key in ["label", "description", "cost", "days"]:
			if not action.has(key):
				problems.append("Diplomatic action '%s' is missing '%s'" % [id, key])
	for id in national_ambitions():
		var amb: Dictionary = national_ambitions()[id]
		for key in ["label", "kind", "description", "requires", "cost", "days", "bonus", "bonus_text", "ai_goal"]:
			if not amb.has(key):
				problems.append("National ambition '%s' is missing '%s'" % [id, key])
		for option in amb.get("requires", []):
			for condition in option:
				if condition.get("type") not in CityMap.AMBITION_CONDITIONS:
					problems.append("National ambition '%s' has unknown requirement '%s'" % [id, condition.get("type")])
		for other in amb.get("closes", []):
			if not national_ambitions().has(other):
				problems.append("National ambition '%s' closes unknown ambition '%s'" % [id, other])
		if amb.get("ai_goal") not in FactionAI.GOALS:
			problems.append("National ambition '%s' has unknown ai_goal '%s'" % [id, amb.get("ai_goal")])
	for id in governments():
		var gov: Dictionary = governments()[id]
		for key in ["label", "description", "succession", "heir_rule", "effects", "ai_goal"]:
			if not gov.has(key):
				problems.append("Government '%s' is missing '%s'" % [id, key])
		var reform: Dictionary = gov.get("reform", {})
		for option in reform.get("requires", []):
			for condition in option:
				if condition.get("type") not in CityMap.AMBITION_CONDITIONS:
					problems.append("Reform to '%s' has unknown requirement '%s'" % [id, condition.get("type")])
				if condition.get("type") == "ambition_done" and not national_ambitions().has(condition.get("ambition")):
					problems.append("Reform to '%s' needs unknown ambition '%s'" % [id, condition.get("ambition")])
		for t in reform.get("backers", []) + reform.get("opposers", []):
			if not council()["traits"].has(t):
				problems.append("Reform to '%s' names unknown character trait '%s'" % [id, t])
	for id in national_ambitions():
		var unlock = national_ambitions()[id].get("unlocks", "")
		if unlock != "" and not governments().has(unlock):
			problems.append("National ambition '%s' unlocks unknown government '%s'" % [id, unlock])
	for f in scenario().get("factions", []):
		for trait_name in f.get("traits", {}):
			if not traits().has(trait_name):
				problems.append("Scenario faction '%s' starts with unknown trait '%s'" % [f.get("id"), trait_name])
	return problems
