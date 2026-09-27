class_name VentureSystem

# Venture definitions live in data/ventures.json. This file holds the building blocks those
# definitions are assembled from: who they can target, what shifts their odds, and what they do.
# Adding a venture that reuses these blocks needs no code; a genuinely new mechanic adds a block here.

# Where a venture can be launched (checked in CityMap.check_launch)
const TARGET_KINDS = ["unclaimed_border", "enemy_border", "war_border", "own", "scavenge", "scout", "market"]
# Odds modifiers a venture can list in "odds_factors"
const ODDS_FACTORS = ["ruin_density", "claimant_present", "target_secured", "defender_traits",
	"defender_on_site", "development", "unrest", "grievance_bonus", "hostile_on_site", "locals_mood", "trade_partner"]
# Operations a venture can list in "success_effects" / "failure_effects"
const EFFECT_OPS = ["influence", "grievance", "gain", "steal", "development", "ruin", "population", "food_source", "scout", "scout_around", "hazard", "pay_owner",
	"crew_loss", "crew_share_loss", "exhaustion", "opinion", "destroy_building"]
# Outcome tiers, best to worst
const TIERS = ["triumph", "success", "setback", "disaster"]

const MIN_ODDS = 0.05
const MAX_ODDS = 0.95

# Odds of a venture: who leads it, how many crew go, how well it's funded, the faction's traits,
# and the target. Returns {"odds": success chance, "base", "factors": [[label, multiplier], ...],
# "tiers": {"triumph", "success", "setback", "disaster"} chances summing to 1}.
# leader may be null (odds without a leader); crew < 0 means the venture's usual crew.
static func compute_odds(venture_id: String, faction: Faction, district: District, city: CityMap, target_id: String,
		leader: Character = null, crew: int = -1, funding: int = 0) -> Dictionary:
	var def = GameData.venture(venture_id)
	var factors: Array = faction.traits.get_venture_factors(venture_id)
	for factor_id in def["odds_factors"]:
		_add_factor(factors, factor_id, faction, district, city, target_id)
	_add_building_factors(factors, venture_id, def, faction, district, city, target_id)
	var skill_name: String = def["skill"]
	var skill = int(GameData.rule("skill_neutral"))
	if leader:
		skill = int(leader.skills[skill_name])
		factors.append(["Led by %s (%s %d)" % [leader.name, skill_name.capitalize(), skill],
			1.0 + (skill - GameData.rule("skill_neutral")) * GameData.rule("skill_odds_step")])
		factors.append_array(leader.trait_factors(skill_name))
	var council_factor = city.council_factor(faction.id, skill_name)
	if council_factor.size() > 0:
		factors.append(council_factor)
	var leader_bonus = city.leader_factor(faction.id, skill_name)
	if leader_bonus.size() > 0:
		factors.append(leader_bonus)
	# Arms: your weapons strengthen attacks; the target's weapons strengthen their defence
	var arms_cap: float = GameData.rule("arms_effect_cap")
	if skill_name == "command" and def.get("hostile", false) and faction.arms >= 1.0:
		factors.append(["Armed (%d arms)" % faction.arms, 1.0 + minf(faction.arms, arms_cap) * GameData.rule("arms_odds_step")])
	var target: Faction = city.factions.get(target_id)
	if def.get("hostile", false) and target and target.arms >= 1.0:
		factors.append(["Defenders armed (%d arms)" % target.arms, 1.0 - minf(target.arms, arms_cap) * GameData.rule("arms_defence_step")])
	if crew >= 0 and crew != int(def["crew"]):
		factors.append(["Crew of %d" % crew, clampf(1.0 + (crew - int(def["crew"])) * GameData.rule("crew_odds_step"), 0.7, 1.35)])
	if funding > 0:
		factors.append(["Extra funding x%d" % funding, 1.0 + funding * GameData.rule("funding_odds_step")])
	# Danger: known if you hold or have scouted the district; otherwise you go in blind.
	# Scouts are exempt: finding out is their job.
	var extra_disaster = 0.0
	if venture_id != "scout":
		if city.knows(faction.id, district):
			if district.hazard >= 0.05:
				factors.append(["Danger here (%s)" % danger_label(district.hazard), 1.0 - district.hazard * GameData.rule("hazard_odds_step")])
				extra_disaster = district.hazard * GameData.rule("hazard_disaster_share")
		else:
			factors.append(["Unscouted: going in blind", GameData.rule("blind_odds")])
			extra_disaster = GameData.rule("blind_disaster_share")
	var odds: float = def["base_success"]
	for factor in factors:
		odds *= factor[1]
	odds = clampf(odds, MIN_ODDS, MAX_ODDS)
	# Skill widens the top of success into Triumph; danger widens the bottom of failure into Disaster
	var triumph_share = clampf(GameData.rule("triumph_share_base") + skill * GameData.rule("triumph_share_per_skill")
		+ (leader.triumph_bonus() if leader else 0.0), 0.05, 0.5)
	var disaster_share = clampf(GameData.rule("disaster_share_base") + def["danger"] + extra_disaster - skill * GameData.rule("disaster_share_per_skill"), 0.03, 0.7)
	var tiers = {
		"triumph": odds * triumph_share, "success": odds * (1.0 - triumph_share),
		"setback": (1.0 - odds) * (1.0 - disaster_share), "disaster": (1.0 - odds) * disaster_share,
	}
	return {"odds": odds, "base": def["base_success"], "factors": factors, "tiers": tiers}

# Picks an outcome tier from the chances in compute_odds
static func roll_tier(tiers: Dictionary, rng: RandomNumberGenerator) -> String:
	var roll = rng.randf()
	for tier in TIERS:
		if roll < tiers[tier]:
			return tier
		roll -= tiers[tier]
	return "disaster"

static func _add_factor(factors: Array, factor_id: String, faction: Faction, d: District, city: CityMap, target_id: String):
	var target: Faction = city.factions.get(target_id)
	match factor_id:
		"ruin_density":
			factors.append(["Ruin density %d%%" % (d.ruin_level * 100), 0.7 + d.ruin_level * 0.6])
		"claimant_present":
			for fid in city.factions:
				if fid != faction.id and d.share(fid) >= 20.0:
					factors.append(["%s also here" % city.factions[fid].display_name, 0.85])
		"target_secured":
			# The owner's grip on the district: every point of control above a bare claim makes it harder
			if target and d.owner_id() == target_id:
				var mult = city.control_defence(d)
				if mult < 0.999:
					factors.append(["Their control %d" % d.share(target_id), mult])
		"defender_traits":
			if target:
				for entry in target.traits.traits_with_effect("defence_mult"):
					factors.append(["Defenders are %s" % entry[0], entry[1]])
		"defender_on_site":
			if target:
				var guards = city.defenders_at(target_id, d)
				if guards > 0:
					factors.append(["%d defenders on guard" % guards, city.guard_defence(guards)])
		"development":
			factors.append(["Development %d%%" % (d.development * 100), 0.8 + d.development * 0.4])
		"unrest":
			if d.grievance > 60.0:
				factors.append(["Unrest disrupts trade", 0.8])
		"grievance_bonus":
			factors.append(["Grievance %d" % d.grievance, 0.7 + d.grievance / 100.0 * 0.8])
		"locals_mood":
			factors.append(["Locals' mood (grievance %d)" % d.grievance, 0.7 + (1.0 - d.grievance / 100.0) * 0.6])
		"trade_partner":
			if target_id != "" and city.relation(faction.id, target_id).trade:
				factors.append(["Trade agreement with them", 1.2])
		"hostile_on_site":
			for fid in city.factions:
				if fid != faction.id and city.has_venture_at(fid, d):
					factors.append(["%s crew stirring trouble" % city.factions[fid].display_name, 0.8])
					break

# Buildings count automatically: the owner's own bonuses (e.g. a Market for trade), and
# defences (e.g. a Watchtower) against hostile ventures aimed at the owner
static func _add_building_factors(factors: Array, venture_id: String, def: Dictionary, faction: Faction, d: District, city: CityMap, target_id: String):
	if not city.buildings_active(d):
		return
	var owner = d.owner_id()
	for building_id in d.buildings:
		var building = GameData.building(building_id)
		if owner == faction.id and building.get("venture_odds", {}).has(venture_id):
			factors.append([building["label"], building["venture_odds"][venture_id]])
		if def.get("hostile", false) and owner == target_id and building["effects"].has("defence_mult"):
			factors.append(["Defended by %s" % building["label"], building["effects"]["defence_mult"]])

# Applies a list of effects from venture data.
# Returns {"lost": crew lost, "values": numbers for the log text (e.g. {supplies}), "notes": extra log phrases}
static func apply_effects(effects: Array, actor: Faction, target_id: String, d: District, city: CityMap, crew: int = 0) -> Dictionary:
	var target: Faction = city.factions.get(target_id)
	var lost = 0
	var values = {}
	var notes = []
	for e in effects:
		match e["op"]:
			"influence":
				var who = actor.id if e.get("who", "self") == "self" else target_id
				if who != "":
					d.add_influence(who, e["amount"])
			"grievance":
				var amount: float = e["amount"]
				if e.get("scaled", false):
					amount *= actor.traits.effect("hostile_grievance_mult")
				d.grievance = clampf(d.grievance + amount, 0.0, 100.0)
			"gain":
				var amount: float = e["amount"] + e.get("per_ruin", 0.0) * d.ruin_level
				actor.set(e["resource"], actor.get(e["resource"]) + amount)
				values[e["resource"]] = int(amount)
			"steal":
				var taken = 0.0
				if target:
					taken = minf(e["amount"], target.get(e["resource"]))
					target.set(e["resource"], target.get(e["resource"]) - taken)
				var amount: float = taken + e.get("bonus", 0.0)
				actor.set(e["resource"], actor.get(e["resource"]) + amount)
				values[e["resource"]] = int(amount)
			"development":
				d.development = clampf(d.development + e["amount"], 0.1, 1.0)
			"ruin":
				d.ruin_level = clampf(d.ruin_level + e["amount"], 0.0, 1.0)
			"scout":
				city.mark_scouted(actor.id, d)
			"scout_around":
				for n_id in d.neighbor_ids:
					if city.districts[n_id].owner_id() != actor.id:
						city.mark_scouted(actor.id, city.districts[n_id])
			"pay_owner":
				# The host keeps what you spent at their market
				if target:
					target.wealth += e["amount"]
			"hazard":
				d.hazard = clampf(d.hazard + e["amount"], 0.0, 0.6)
			"food_source":
				d.food_yield = minf(d.food_yield + e["amount"], GameData.rule("food_source_cap"))
			"population":
				d.population *= e["mult"]
			"crew_loss":
				var chance: float = e.get("chance", 1.0)
				if chance >= 1.0 or city.rng.randf() < chance:
					lost += city.rng.randi_range(int(e["min"]), int(e["max"]))
			"crew_share_loss":
				# Losses in proportion to the crew sent: bigger crews risk more lives
				lost += int(round(crew * e["share"] * city.rng.randf_range(0.6, 1.0)))
			"exhaustion":
				if target:
					city.add_exhaustion(actor.id, target_id, e["amount"])
			"opinion":
				if target:
					city.change_opinion(target_id, actor.id, e["amount"], e.get("modifier", "raided"))
			"destroy_building":
				if not d.buildings.is_empty() and city.rng.randf() < e.get("chance", 1.0):
					var index = city.rng.randi_range(0, d.buildings.size() - 1)
					notes.append("wrecked the %s" % GameData.building(d.buildings[index])["label"])
					d.buildings.remove_at(index)
	return {"lost": lost, "values": values, "notes": notes}

static func danger_label(hazard: float) -> String:
	if hazard < 0.12:
		return "low"
	if hazard < 0.25:
		return "moderate"
	if hazard < 0.4:
		return "high"
	return "deadly"
