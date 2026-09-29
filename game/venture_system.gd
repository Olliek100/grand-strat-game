class_name VentureSystem

# Venture definitions live in data/ventures.json. This file holds the building blocks those
# definitions are assembled from: who they can target, what shifts their odds, and what they do.
# Adding a venture that reuses these blocks needs no code; a genuinely new mechanic adds a block here.

# Where a venture can be launched (checked in CityMap.check_launch)
const TARGET_KINDS = ["unclaimed_border", "enemy_border", "war_border", "own", "scavenge", "scout", "market", "raider_border"]
# Odds modifiers a venture can list in "odds_factors"
const ODDS_FACTORS = ["ruin_density", "claimant_present", "target_secured", "defender_traits",
	"defender_on_site", "development", "unrest", "grievance_bonus", "hostile_on_site", "locals_mood", "trade_partner",
	"emboldened", "strength_ratio", "your_arms"]
# Operations a venture can list in "success_effects" / "failure_effects"
const EFFECT_OPS = ["influence", "grievance", "gain", "steal", "development", "ruin", "population", "food_source", "scout", "scout_around", "hazard", "pay_owner",
	"crew_loss", "crew_share_loss", "exhaustion", "opinion", "destroy_building", "spare", "embolden"]
# Outcome tiers, best to worst
const TIERS = ["triumph", "success", "setback", "disaster"]

const MIN_ODDS = 0.05
const MAX_ODDS = 0.98

# Odds of a venture: who leads it, how many crew go, how well it's funded, the faction's traits,
# and the target. Returns {"odds": success chance, "base", "factors": [[label, multiplier], ...],
# "tiers": {"triumph", "success", "setback", "disaster"} chances summing to 1}.
# leader may be null (odds without a leader); crew < 0 means the venture's usual crew.
static func compute_odds(venture_id: String, faction: Faction, district: District, city: CityMap, target_id: String,
		leader: Character = null, crew: int = -1, funding: int = 0) -> Dictionary:
	var def = GameData.venture(venture_id)
	var factors: Array = faction.venture_factors(venture_id)
	if faction.caretaker_until > city.day:
		factors.append(["Caretaker government (%d days)" % (faction.caretaker_until - city.day), 0.9])
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
	# Against defenders on guard, what counts is how many you bring compared with them: overwhelming
	# force can make an attack nearly certain. Otherwise more hands help, up to a point.
	var size = int(def["crew"]) if crew < 0 else crew
	var guards = city.defenders_at(target_id, district) if def.get("hostile", false) and target_id != "" else 0
	if guards > 0:
		factors.append(["Your crew of %d against %d defenders" % [size, guards], clampf(0.8 + 0.2 * float(size) / guards, 0.8, GameData.rule("outnumber_max"))])
	elif crew >= 0 and crew != int(def["crew"]):
		factors.append(["Crew of %d" % crew, clampf(1.0 + (crew - int(def["crew"])) * GameData.rule("crew_odds_step"), 0.7, 1.35)])
	if funding > 0:
		factors.append(["Extra funding x%d" % funding, 1.0 + funding * GameData.rule("funding_odds_step")])
	# Danger: known if you hold or have scouted the district; otherwise you go in blind.
	# Scouts are exempt: finding out is their job.
	var extra_disaster = 0.0
	if venture_id != "scout":
		if city.knows(faction.id, district):
			if city.danger(district) >= 0.05:
				factors.append(["Danger here (%s)" % danger_label(city.danger(district)), 1.0 - city.danger(district) * GameData.rule("hazard_odds_step")])
				extra_disaster = city.danger(district) * GameData.rule("hazard_disaster_share")
		else:
			factors.append(["Unscouted: going in blind", GameData.rule("blind_odds")])
			extra_disaster = GameData.rule("blind_disaster_share")
	var odds: float = def["base_success"]
	for factor in factors:
		odds *= factor[1]
	odds = clampf(odds, MIN_ODDS, MAX_ODDS)
	# Skill and good odds widen the top of success into Triumph; danger widens the bottom of failure into
	# Disaster. A well-prepared venture (90%+) can still fail, but never disastrously.
	var triumph_share = clampf(GameData.rule("triumph_share_base") + skill * GameData.rule("triumph_share_per_skill")
		+ (leader.triumph_bonus() if leader else 0.0) + maxf(0.0, odds - 0.5) * GameData.rule("triumph_share_per_odds"), 0.05, 0.6)
	var disaster_share = clampf(GameData.rule("disaster_share_base") + def["danger"] + extra_disaster - skill * GameData.rule("disaster_share_per_skill"), 0.03, 0.7)
	if odds >= GameData.rule("no_disaster_odds"):
		disaster_share = 0.0
	var tiers = {
		"triumph": odds * triumph_share, "success": odds * (1.0 - triumph_share),
		"setback": (1.0 - odds) * (1.0 - disaster_share), "disaster": (1.0 - odds) * disaster_share,
	}
	return {"odds": odds, "base": def["base_success"], "factors": factors, "tiers": tiers}

# Picks an outcome tier and, for a success, how cleanly it went: {"tier", "quality"}. Quality runs from
# x0.8 (only just made it) to x1.2 (a clean job) and scales what the success gains
static func roll_outcome(tiers: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var roll = rng.randf()
	var success = tiers["triumph"] + tiers["success"]
	if roll < success:
		var margin = 1.0 - roll / maxf(0.001, success)
		return {"tier": "triumph" if roll < tiers["triumph"] else "success", "quality": lerpf(0.8, 1.2, margin)}
	roll -= success
	return {"tier": "setback" if roll < tiers["setback"] else "disaster", "quality": 1.0}

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
				for entry in target.effects_with_labels("defence_mult"):
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
		"emboldened":
			if target and city.relation(faction.id, target_id).bold_until[faction.id] > city.day:
				factors.append(["Emboldened against the %s" % target.display_name, GameData.rule("emboldened_odds")])
		"strength_ratio":
			if target:
				var mine = city.faction_strength(faction.id)
				var theirs = maxf(1.0, city.faction_strength(target_id))
				factors.append(["Your strength %d vs their %d" % [mine, theirs], clampf(0.6 + 0.4 * mine / theirs, 0.6, 1.4)])
		"your_arms":
			if faction.arms >= 1.0:
				factors.append(["Your arms (%d)" % faction.arms, 1.0 + minf(faction.arms, GameData.rule("arms_effect_cap")) * GameData.rule("arms_odds_step")])
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

# Applies a list of effects from venture data. `quality` (x0.8 to x1.2, from how cleanly a success went)
# scales what the actor gains: resources, loot, influence, food sources and rebuilding.
# Returns {"lost": crew lost, "values": numbers for the log text (e.g. {supplies}), "notes": extra log phrases}
static func apply_effects(effects: Array, actor: Faction, target_id: String, d: District, city: CityMap, crew: int = 0, quality: float = 1.0) -> Dictionary:
	var target: Faction = city.factions.get(target_id)
	var lost = 0
	var values = {}
	var notes = []
	for e in effects:
		match e["op"]:
			"influence":
				var who = actor.id if e.get("who", "self") == "self" else target_id
				if who != "":
					d.add_influence(who, e["amount"] * (quality if who == actor.id and e["amount"] > 0.0 else 1.0))
			"grievance":
				var amount: float = e["amount"]
				if e.get("scaled", false):
					amount *= actor.effect("hostile_grievance_mult")
				d.grievance = clampf(d.grievance + amount, 0.0, 100.0)
			"gain":
				var amount: float = (e["amount"] + e.get("per_ruin", 0.0) * d.ruin_level) * quality
				if e.has("mult_effect"):
					amount *= actor.effect(e["mult_effect"])
				actor.set(e["resource"], actor.get(e["resource"]) + amount)
				values[e["resource"]] = int(amount)
			"steal":
				var taken = 0.0
				# A built-up district yields more loot than a fresh claim
				var want: float = e["amount"] * (city.raid_worth(d) if e.get("worth", false) else 1.0) * quality
				if target:
					taken = minf(want, target.get(e["resource"]))
					target.set(e["resource"], target.get(e["resource"]) - taken)
				var amount: float = taken + e.get("bonus", 0.0)
				actor.set(e["resource"], actor.get(e["resource"]) + amount)
				values[e["resource"]] = int(amount)
			"development":
				d.development = clampf(d.development + e["amount"] * (quality if e["amount"] > 0.0 else 1.0), 0.1, 1.0)
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
				d.food_yield = minf(d.food_yield + e["amount"] * quality, GameData.rule("food_source_cap"))
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
			"spare":
				# The target promises not to raid the actor for a while
				if target:
					var r = city.relation(actor.id, target_id)
					r.spare_until[target_id] = maxi(r.spare_until[target_id], city.day + int(e["days"]))
					notes.append("no raids from the %s for %d days" % [target.display_name, r.spare_until[target_id] - city.day])
			"embolden":
				# The target's raids on the actor get better odds for a while
				if target:
					var r = city.relation(actor.id, target_id)
					r.bold_until[target_id] = maxi(r.bold_until[target_id], city.day + int(e["days"]))
					notes.append("their raids on you get +%d%% odds for %d days" % [roundi((GameData.rule("emboldened_odds") - 1.0) * 100), e["days"]])
			"destroy_building":
				if not d.buildings.is_empty() and city.rng.randf() < e.get("chance", 1.0):
					var index = city.rng.randi_range(0, d.buildings.size() - 1)
					notes.append("wrecked the %s" % GameData.building(d.buildings[index])["label"])
					d.buildings.remove_at(index)
	return {"lost": lost, "values": values, "notes": notes}

static func danger_label(hazard: float) -> String:
	if hazard < 0.04:
		return "none"
	if hazard < 0.12:
		return "low"
	if hazard < 0.25:
		return "moderate"
	if hazard < 0.4:
		return "high"
	return "deadly"
