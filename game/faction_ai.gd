class_name FactionAI

# Rule-based AI for one non-player faction. It scores every venture it could launch right now
# using the same odds the player sees, weighted by what that venture is for (its "ai_goal" in
# data/ventures.json) and by the faction's own traits, then takes the best move.
# It follows the same rules as the player, including war, and telegraphs war before declaring.

const GOALS = ["expand", "harass", "conquer", "income", "subvert", "stabilize", "food", "control", "arms", "materials", "scout", "buy", "develop", "defend", "deter"]
# What each building is for (its "ai_goal" in data/buildings.json)
const BUILD_GOALS = ["defend", "stabilize", "income", "supplies", "crew", "develop", "food", "materials", "recycle"]
# The AI only builds while it has this much wealth to spare
const BUILD_WEALTH_RESERVE = 15.0
const MAX_ACTIVE_VENTURES = 3
const MIN_SCORE = 0.12

var faction_id: String
var days_until_next_move: int = 3
# Daily food balance (income - upkeep), refreshed each day: hunger comes first
var food_net: float = 0.0
# Set each decision: whether scouted, unclaimed land is ready to settle
var has_settle_target: bool = false
var days_until_next_diplomacy: int = 12
# A planned war: who, and on what day it will be declared ("" / -1 when there's no plan)

func _init(p_faction_id: String):
	faction_id = p_faction_id

func think(city: CityMap):
	_think_war(city)
	_think_diplomacy(city)
	if city.day % 30 == 7:
		city.ai_manage_council(faction_id)
		_think_houses(city)
	days_until_next_move -= 1
	if days_until_next_move > 0:
		return
	days_until_next_move = city.rng.randi_range(3, 7)
	# The food balance is only needed to choose a move, so it is worked out only when one is due
	var econ = city.daily_economy(faction_id)["supplies"]
	food_net = econ["income"] - econ["upkeep"]
	_think_buy(city)
	# One move at a time, from one list: building at home competes with ventures abroad for the same
	# turn and the same stocks, so a faction that builds up grows outward more slowly (and the other way round)
	var me: Faction = city.factions[faction_id]
	# The best thing to do at home: a reform, an ambition or a building
	var home = _best_at_home(city)
	# Bigger factions run more operations at once
	if city.active_venture_count(faction_id) >= MAX_ACTIVE_VENTURES + city.districts_held(faction_id) / 8:
		if home["score"] > 0.0:
			home["act"].call()
		return

	# Whether any scouted, unclaimed land is ready to settle: if not, scouting comes first
	has_settle_target = false
	for d in city.districts:
		if d.owner_id() == "" and city.knows(faction_id, d) and city.borders_territory(faction_id, d):
			has_settle_target = true
			break
	var best_score = MIN_SCORE
	var best_venture = ""
	var best_district: District = null
	var council_free = not city.available_leaders(faction_id).filter(func(c): return c.post != "").is_empty()
	# The best war captain is the same for every fight weighed this turn: found once, when first needed
	var captain_found = false
	var captain: Character = null
	for d in city.districts:
		# One operation per district at a time, rather than piling on
		if city.has_venture_at(faction_id, d):
			continue
		# Only scouting and trade reach beyond your own land and its frontier, and most ventures can't apply to a district of the
		# wrong owner (the conditions check_launch applies first), so those pairs are not weighed at all
		var reach = city.can_reach(faction_id, d)
		var holder = d.owner_id()
		for venture_id in GameData.ventures():
			if not _could_apply(GameData.venture(venture_id)["target"], reach, holder, d):
				continue
			# Routine work on its own land is a councillor's standing task, by the same rules as the player's
			if city.is_task(faction_id, venture_id, d):
				if not council_free or city.task_at(faction_id, venture_id, d) or city.task_done_reason(faction_id, venture_id, d) != "":
					continue
				if city.check_launch(faction_id, venture_id, d, -2, -1, 0, true) != "":
					continue
			elif city.check_launch(faction_id, venture_id, d) != "":
				continue
			var target_id = city.venture_target(faction_id, venture_id, d)
			var odds = 0.0
			# A fight is judged at the crew it would really send, and not picked while outnumbered
			if GameData.venture(venture_id).has("force") and target_id != "":
				if not captain_found:
					captain = city.best_leader(faction_id, "command")
					captain_found = true
				var chances = VentureSystem.compute_odds(venture_id, me, d, city, target_id, captain, city.recommended_plan(faction_id, venture_id, d, captain)["crew"])
				if chances["force"]["ratio"] < 1.0:
					continue
				odds = chances["odds"]
			else:
				odds = VentureSystem.compute_odds(venture_id, me, d, city, target_id)["odds"]
			var goal: String = GameData.venture(venture_id)["ai_goal"]
			# Factions lean into what their traits make them good at
			var preference = me.traits.venture_modifier(venture_id)
			var score = odds * _value(goal, d, me, target_id, city) * preference * temperament(goal, me) * city.rng.randf_range(0.7, 1.3)
			if score > best_score:
				best_score = score
				best_venture = venture_id
				best_district = d

	if home["score"] > best_score:
		home["act"].call()
		return
	if best_district:
		if city.is_task(faction_id, best_venture, best_district):
			city.assign_task(faction_id, best_venture, best_district)
			return
		# The best free captain leads, with the same recommended crew and funding the player's planner offers
		var leader = city.best_leader(faction_id, GameData.venture(best_venture)["skill"])
		var plan = city.recommended_plan(faction_id, best_venture, best_district, leader)
		city.launch_venture(faction_id, best_venture, best_district, leader.id if leader else -2, plan["crew"], plan["funding"])

# Founds cadet houses as it grows (doc 16): one house per five districts, for a grown family member who isn't the
# heir, on a district far from home. The same grant the player makes, by the same rules
func _think_houses(city: CityMap):
	if city.houses_of(faction_id).size() >= city.districts_held(faction_id) / 5:
		return
	var heir = city.succession_outlook(faction_id)["heir"]
	var me: Faction = city.factions[faction_id]
	var home: District = city.districts[me.home_id] if me.home_id >= 0 else null
	var lords = city.characters_of(faction_id).filter(func(c): return c.family and c != heir and c.house_id < 0)
	if lords.is_empty() or home == null:
		return
	var land: District = null
	for d in city.districts:
		if city.check_grant(faction_id, lords[0], d) == "" and (land == null or d.center.distance_to(home.center) > land.center.distance_to(home.center)):
			land = d
	if land:
		city.grant_land(faction_id, lords[0], land)

# Buys what it's short of with wealth it can spare, by the player's prices: materials when low,
# arms when low and threatened (at war, or next to raiders)
func _think_buy(city: CityMap):
	var me: Faction = city.factions[faction_id]
	var reserve: float = GameData.rule("ai_buy_wealth_reserve")
	var wants = {}
	if me.materials < 15.0:
		wants["materials"] = 15
	var threatened = not city.war_enemies(faction_id).is_empty() or city.factions.keys().any(func(fid): return fid != faction_id and city.is_raider(fid) and city.shares_border(faction_id, fid))
	if threatened and me.arms < 8.0:
		wants["arms"] = 8 - int(me.arms)
	for resource_type in wants:
		var amount: int = wants[resource_type]
		while amount > 0 and me.wealth - city.buy_price(faction_id, resource_type, amount) < reserve:
			amount -= 1
		if amount > 0:
			city.buy(faction_id, resource_type, amount)

# Wars come from a goal justified in the open (doc 15, P2): against a weaker neighbour, the harsher the goal
# the bigger the gap. At war it takes its terms once the war score allows, and makes peace when worn down
func _think_war(city: CityMap):
	var wars = city.war_enemies(faction_id)
	if not wars.is_empty():
		# Call its houses to fight (each may decline), by the player's rules
		for h in city.houses_of(faction_id):
			if city.check_call_house(faction_id, int(h["id"])) == "":
				city.call_house(faction_id, int(h["id"]))
		for enemy_id in wars:
			var r = city.relation(faction_id, enemy_id)
			if city.check_enforce(faction_id, enemy_id) == "":
				city.enforce_claim(faction_id, enemy_id, city.auto_demands(faction_id, enemy_id))
				continue
			var mine: float = r.exhaustion[faction_id]
			var war_days = city.day - r.war_start_day
			# Sue for peace when worn down, or when a war has dragged on with no end
			if (mine > 50.0 and mine >= r.exhaustion[enemy_id]) or war_days > 180:
				city.offer_peace(faction_id, enemy_id)
			# Accept another AI's offer once the war has cost something
			if r.peace_offered_by == enemy_id and (mine >= 30.0 or war_days > 90):
				city.make_peace(faction_id, enemy_id)
		return
	# One claim at a time: while pressing one, send the ultimatum early if it's strong enough
	for fid in city.factions:
		if fid != faction_id and city.relation(faction_id, fid).claim.get("by", "") == faction_id:
			if city.check_send_early(faction_id, fid) == "":
				city.send_ultimatum_early(faction_id, fid)
			return
	if city.day % 10 != 0:
		return
	for enemy_id in city.factions:
		if enemy_id == faction_id:
			continue
		# Recourse against a raider: a district claim, even when weaker, if it and its friends can make a fight of it
		if city.claim_reason(faction_id, enemy_id) != "" and city.is_raider(enemy_id) \
				and city.side_strength(faction_id, enemy_id) >= city.side_strength(enemy_id, faction_id) * 0.7 and city.rng.randf() < 0.3:
			if city.justify(faction_id, enemy_id, "claim") == "":
				return
		var appeal = war_appeal(city, enemy_id)
		if appeal.is_empty() or city.rng.randf() >= 0.4:
			continue
		# (a pact in the way is broken by justify, at the cost of everyone's trust)
		# The harshest goal the gap allows, then milder ones
		var ratio = city.faction_strength(enemy_id) / maxf(1.0, city.faction_strength(faction_id))
		var goals = ["claim"]
		if ratio < GameData.war_goal("subjugate")["ai_max_strength_ratio"]:
			goals.push_front("subjugate")
		if ratio < GameData.war_goal("vassalize")["ai_max_strength_ratio"] and temperament("conquer", city.factions[faction_id]) >= 1.0:
			goals.push_front("vassalize")
		for goal_id in goals:
			if city.justify(faction_id, enemy_id, goal_id) == "":
				return

# Whether this faction sees `enemy_id` as a war target right now: {"pact_only", "reason"}, or {} if not.
# No randomness, so the diplomacy panel shows exactly the judgement the AI acts on.
func war_appeal(city: CityMap, enemy_id: String) -> Dictionary:
	var me: Faction = city.factions[faction_id]
	var r = city.relation(faction_id, enemy_id)
	# A non-aggression pact (not an alliance or vassalage) only holds while it's worth keeping
	var pact_only = r.pact and not r.alliance and r.overlord == ""
	if city.check_declare_war(faction_id, enemy_id) != "" and not pact_only:
		return {}
	var opinion = city.opinion_of(faction_id, enemy_id)
	if opinion > 20.0:
		return {}
	if pact_only:
		# Only betray a pact if war could follow at once
		var ready = city.day >= r.truce_until_day and city.shares_border(faction_id, enemy_id) and me.can_afford(GameData.rule("war_cost"))
		if opinion > 0.0 or not ready:
			return {}
	var my_strength = city.faction_strength(faction_id)
	for vassal_id in city.vassals_of(faction_id):
		my_strength += city.faction_strength(vassal_id)
	# A full war chest makes a faction bolder
	var aggression = me.effect("aggression_mult") * (1.0 + minf(me.wealth / 1000.0, 1.5))
	if opinion < -25.0:
		aggression *= 1.2
	if r.trade:
		aggression *= 0.7
	# Count everyone who would come to their defence
	var their_strength = city.faction_strength(enemy_id)
	for defender_id in city.defenders_of(enemy_id):
		if defender_id != faction_id:
			their_strength += city.faction_strength(defender_id)
	var margin = 1.5 if pact_only else 1.2
	if my_strength * aggression <= their_strength * margin:
		return {}
	var reason = "They outmatch you (%d vs %d, counting your allies) and their opinion of you is %+d" % [my_strength, their_strength, opinion]
	if pact_only:
		reason += "; your pact may not hold"
	return {"pact_only": pact_only, "reason": reason}

# How this faction regards another, with the reason, as [STANCE, reason]. Shown on the diplomacy
# panel so the player can read the AI's intentions before it acts (war only comes from TARGET).
func stance_toward(city: CityMap, other_id: String) -> Array:
	if city.is_at_war(faction_id, other_id):
		return ["ENEMY", "At war"]
	var pressing = city.relation(faction_id, other_id)
	if pressing.claim.get("by", "") == faction_id:
		return ["PRESSING A CLAIM", "%s; %s" % [city.claim_text(pressing, other_id), "ultimatum in " + city.claim_clock(pressing) if pressing.claim["stage"] == "justifying" else "awaiting an answer"]]
	var appeal = war_appeal(city, other_id)
	if not appeal.is_empty():
		return ["TARGET", appeal["reason"]]
	var r = city.relation(faction_id, other_id)
	var view = city.opinion_of(faction_id, other_id)
	var threat = Diplomacy.common_threat(city, faction_id, other_id)
	if threat != "" and view > 0.0 and not r.alliance:
		return ["WANTS ALLIANCE", "You both face the %s" % city.faction_name(threat)]
	if r.alliance or r.overlord != "":
		return ["FRIENDLY", "Bound to you by treaty"]
	if view >= 20.0:
		return ["FRIENDLY", "Thinks well of you"]
	if city.faction_strength(other_id) > city.faction_strength(faction_id) * 1.2 and view < 0.0:
		return ["WARY", "Sees you as a stronger rival"]
	if r.trade or r.pact:
		return ["CORDIAL", "Keeps to your agreements"]
	return ["NEUTRAL", "No strong feelings either way"]

# Every couple of weeks, pursue the diplomatic move that best serves the faction: trade with
# friends, pacts when threatened, alliances against a common enemy, vassals from weak neighbours
func _think_diplomacy(city: CityMap):
	days_until_next_diplomacy -= 1
	if days_until_next_diplomacy > 0:
		return
	days_until_next_diplomacy = city.rng.randi_range(8, 15)
	var me: Faction = city.factions[faction_id]
	var best_score = 0.2
	var best_action = ""
	var best_target = ""
	# A strong, resentful vassal breaks away
	var overlord_id = city.overlord_of(faction_id)
	var strong_enough = overlord_id != "" and city.faction_strength(faction_id) >= city.faction_strength(overlord_id) * 0.7
	if strong_enough and city.opinion_of(faction_id, overlord_id) < -20.0:
		Diplomacy.break_treaty(city, faction_id, overlord_id, "vassal")
		return
	for other_id in city.factions:
		if other_id == faction_id:
			continue
		# Walk away from trade with factions it has come to despise
		var r = city.relation(faction_id, other_id)
		if r.trade and city.opinion_of(faction_id, other_id) < -40.0:
			Diplomacy.break_treaty(city, faction_id, other_id, "trade")
			return
		for action_id in GameData.diplomacy_actions():
			if Diplomacy.check_action(city, action_id, faction_id, other_id) != "":
				continue
			var want = _diplomacy_value(action_id, other_id, me, city)
			if want <= 0.0:
				continue
			var chance: float = Diplomacy.acceptance(city, action_id, faction_id, other_id)["chance"]
			var score = want * chance * city.rng.randf_range(0.8, 1.2)
			if score > best_score:
				best_score = score
				best_action = action_id
				best_target = other_id
	if best_action != "":
		Diplomacy.start_action(city, best_action, faction_id, best_target)

# A cheap necessary condition for a venture to apply to a district, so most pairs are never weighed (mirrors check_launch)
func _could_apply(target: String, reach: bool, holder: String, d: District) -> bool:
	if target == "scout":
		return holder == ""
	if target == "market":
		return holder != "" and holder != faction_id
	if not reach:
		return false
	match target:
		"own":
			return holder == faction_id
		"unclaimed_border":
			return holder == ""
		"scavenge":
			return holder == "" or holder == faction_id
		"enemy_border", "raider_border":
			return holder != "" and holder != faction_id
		"war_border":
			return (holder != "" and holder != faction_id) or d.occupier != ""
	return true

# How much the faction wants this diplomatic outcome with `other_id`, before acceptance odds
func _diplomacy_value(action_id: String, other_id: String, me: Faction, city: CityMap) -> float:
	var my_view = city.opinion_of(faction_id, other_id)
	var their_view = city.opinion_of(other_id, faction_id)
	match action_id:
		"match":
			# Bind a family it gets on with, or one it would rather not fight
			return 0.5 if my_view > 0.0 and their_view > -10.0 else 0.0
		"backing":
			# Rally friends behind a claim the target isn't likely to give in to
			var target = city.pressing_claim_on(faction_id)
			if target == "":
				return 0.0
			return 0.9 if city.ultimatum_acceptance(city.relation(faction_id, target)) < 0.6 else 0.0
		"envoy":
			# Court factions it wants something from, when it can spare the wealth
			if me.wealth < 80.0 or other_id == city.player_id or my_view < -10.0 or their_view > 30.0:
				return 0.0
			return 0.4
		"trade":
			return (0.6 if my_view > -20.0 else 0.0) * me.effect("trade_interest_mult")
		"pact":
			if city.relation(faction_id, other_id).pact:
				return 0.9 if my_view > -10.0 else 0.0
			if my_view < -30.0:
				return 0.0
			# A pact is worth asking for from a stronger neighbour with reason to be feared: raiders, someone
			# who raided us lately, or someone who dislikes us. Being merely weaker isn't reason enough.
			var r = city.relation(faction_id, other_id)
			var stronger = city.faction_strength(other_id) > city.faction_strength(faction_id) * 1.2
			var menacing = city.is_raider(other_id) or r.menaced_recently(other_id, city.day, int(GameData.rule("menace_memory_days"))) or my_view < 0.0
			var threatened = (stronger and menacing) or city.at_war_with_anyone(faction_id)
			# Raiders live by raiding: they rarely offer to stop
			return (0.7 if threatened else 0.1) * (0.3 if city.is_raider(faction_id) else 1.0)
		"alliance":
			if city.relation(faction_id, other_id).alliance:
				return 1.0 if my_view > 0.0 else 0.0
			return 1.0 if my_view > 0.0 and Diplomacy.common_threat(city, faction_id, other_id) != "" else 0.0
		"vassalage":
			return 0.6 if my_view > -10.0 else 0.0
		"integrate":
			return 1.5
		"tribute":
			# Buy peace from a stronger faction that keeps raiding us
			var r = city.relation(faction_id, other_id)
			var raided = r.last_raid[other_id] > 0 and city.day - r.last_raid[other_id] <= 60
			return 0.8 if raided and city.faction_strength(other_id) > city.faction_strength(faction_id) else 0.0
		"demand":
			# Raiders ask before they take, more often the stronger the victim
			var ratio = clampf(city.faction_strength(other_id) / maxf(1.0, city.faction_strength(faction_id)), 0.3, 1.5)
			return 0.4 * temperament("harass", me) * ratio if temperament("harass", me) > 1.0 else 0.0
	return 0.0

# Every week or so, spend spare wealth on the building that best fits its situation
# The best of the three things a faction can do at home, as {"score", "act"} (act is what doing it means)
func _best_at_home(city: CityMap) -> Dictionary:
	var best = {"score": 0.0, "act": func(): pass}
	var build = _best_build(city)
	if build["district"]:
		best = {"score": build["score"], "act": func(): city.start_construction(faction_id, build["building"], build["district"])}
	var pursuit = _best_ambition(city)
	if pursuit["id"] != "" and pursuit["score"] > best["score"]:
		best = {"score": pursuit["score"], "act": func(): city.start_ambition(faction_id, pursuit["id"])}
	var reform = _best_reform(city)
	if reform["id"] != "" and reform["score"] > best["score"]:
		best = {"score": reform["score"], "act": func(): city.take_reform(faction_id, reform["id"])}
	return best

# The reform it most wants, if it can take one: a gang is keen to become a Warlord crew; after that, its
# traits lean it (a Militaristic crew wants Autocracy, a Socialist one the Politburo)
func _best_reform(city: CityMap) -> Dictionary:
	var me: Faction = city.factions[faction_id]
	var best = {"id": "", "score": 0.0}
	if me.reform_locked_until > city.day:
		return best
	for gov_id in city.reform_options(faction_id):
		if city.check_reform(faction_id, gov_id) != "":
			continue
		var gov = GameData.government(gov_id)
		var want = 1.5 if gov_id == "warlord" else GameData.rule("ai_reform_weight") * temperament(gov["ai_goal"], me)
		var score = want * city.rng.randf_range(0.7, 1.3)
		if score > best["score"]:
			best = {"id": gov_id, "score": score}
	return best

# The National Ambition it most wants to start, on the same scale as ventures: {"id", "score"}. Its traits
# lean it (a Militaristic crew wants War ambitions), and it only starts one it qualifies for and can pay for.
func _best_ambition(city: CityMap) -> Dictionary:
	var me: Faction = city.factions[faction_id]
	var best = {"id": "", "score": 0.0}
	if me.ambition != "":
		return best
	for id in GameData.national_ambitions():
		if city.check_ambition(faction_id, id) != "":
			continue
		var def = GameData.national_ambition(id)
		var score = def["ai_value"] * temperament(def["ai_goal"], me) * GameData.rule("ai_ambition_weight") * city.rng.randf_range(0.7, 1.3)
		if score > best["score"]:
			best = {"id": id, "score": score}
	return best

# The building it most wants now, scored on the same scale as ventures: {"building", "district", "score"}
func _best_build(city: CityMap) -> Dictionary:
	var me: Faction = city.factions[faction_id]
	# Don't take on upkeep the treasury can't carry
	var econ = city.daily_economy(faction_id)["wealth"]
	var net: float = econ["income"] - econ["upkeep"]
	var best_score = 0.2
	var best_building = ""
	var best_district: District = null
	for d in city.districts:
		if d.owner_id() != faction_id:
			continue
		for building_id in GameData.buildings():
			var def = GameData.building(building_id)
			# Keep a wealth reserve for buildings that cost wealth; ones paid in materials alone are fine
			var needs_wealth = def["cost"].get("wealth", 0.0) > 0.0 and me.wealth - def["cost"]["wealth"] < BUILD_WEALTH_RESERVE
			if city.check_build(faction_id, building_id, d) != "" or needs_wealth or def["upkeep"].get("wealth", 0.0) > net:
				continue
			var goal: String = GameData.building(building_id)["ai_goal"]
			var score = _build_value(goal, d, me, city) * temperament(goal, me) * GameData.rule("ai_build_weight") * city.rng.randf_range(0.7, 1.3)
			if score > best_score:
				best_score = score
				best_building = building_id
				best_district = d
	return {"building": best_building, "district": best_district, "score": best_score}

func _build_value(goal: String, d: District, me: Faction, city: CityMap) -> float:
	match goal:
		"defend":
			# Border districts facing another faction need defences most
			for n_id in d.neighbor_ids:
				var other = city.districts[n_id].owner_id()
				if other != "" and other != faction_id:
					return 1.0
			return 0.1
		"stabilize":
			return d.grievance / 50.0
		"income":
			return d.development * 1.2
		"food":
			return 1.6 if food_net < 0.1 else (0.6 if food_net < 0.4 else 0.15)
		"recycle":
			# The renewable source: most wanted where the ruins are stripped and stocks are low
			return (1.4 if me.materials < 30.0 else (0.5 if me.materials < 80.0 else 0.0)) * (1.2 - d.ruin_level)
		"materials":
			return d.ruin_level * (1.5 if me.materials < 30.0 else (0.5 if me.materials < 80.0 else 0.0))
		"supplies":
			return d.ruin_level * (1.5 if me.supplies < 40.0 else 0.6)
		"crew":
			return 1.2 if me.manpower + city.crew_away(faction_id) >= city.crew_cap(faction_id) - 2 else 0.2
		"develop":
			return (1.0 - d.development) * 0.9
	return 0.0

# How much the faction wants this outcome, before odds
func _value(goal: String, d: District, me: Faction, target_id: String, city: CityMap) -> float:
	match goal:
		"expand":
			# Finish claims already under way before starting new ones. Only a fed faction with a
			# secure home looks outward in earnest.
			var ready = food_net >= 0.0 and me.supplies >= 15.0 and _home_secured(city)
			return (0.5 + d.ruin_level * 0.5 + d.share(faction_id) / 100.0) * (1.0 if ready else 0.3)
		"food":
			if food_net < 0.0 or me.supplies < 15.0:
				return 1.6 + (0.8 if me.supplies < 8.0 else 0.0)
			return 0.5 if food_net < 0.3 else 0.12
		"scout":
			# Scout when there's nothing known to settle, most of all when ready to grow
			var ready = food_net >= 0.0 and me.supplies >= 15.0 and _home_secured(city)
			if not has_settle_target:
				return 1.1 if ready else 0.35
			return 0.15 if city.borders_territory(faction_id, d) else 0.06
		"buy":
			# Turn spare wealth into what's short
			if me.wealth < 40.0:
				return 0.0
			var short = me.materials < 25.0 or food_net < 0.0 or me.supplies < 20.0
			if short:
				return 1.0 + minf(me.wealth / 400.0, 0.6)
			return 0.3 if me.wealth > 400.0 else 0.0
		"develop":
			# Surplus materials go into rebuilding: more housing, food and taxes
			var gap = 1.0 - d.development
			if me.materials > 60.0:
				return 0.5 + gap + minf(me.materials / 100.0, 2.5)
			return gap * 0.5 if me.materials > 30.0 else 0.0
		"materials":
			# Scavenge when stocks run low; heavier ruins pay better
			var need = 1.3 if me.materials < 15.0 else (0.5 if me.materials < 40.0 else 0.05)
			return need * (0.4 + d.ruin_level)
		"defend":
			# Rush guards to a district under attack; keep a watch on a hot border
			for v in city.incoming_attacks(faction_id):
				if v.district == d:
					return 1.6 if v.venture_id == "assault" else 1.1
			return 0.3 if not city.war_enemies(faction_id).is_empty() else 0.08
		"control":
			var share = d.share(faction_id)
			if share >= GameData.rule("secure_threshold"):
				return 0.12
			return 0.7 + (GameData.rule("secure_threshold") - share) / 40.0 + (0.4 if d.id == me.home_id else 0.0)
		"arms":
			var threatened = not city.war_enemies(faction_id).is_empty()
			if me.arms < 6.0:
				return 0.6 + (0.8 if threatened else 0.0)
			return 0.3 if me.arms < 15.0 else 0.08
		"harass":
			# Raid for what's worth taking, most of all when short; hold off while a demand is out
			if target_id != "" and (city.mission_between(faction_id, target_id) or city.proposal_between(faction_id, target_id) >= 0):
				return 0.0
			# Don't throw away a promise of safety it paid for
			if target_id != "" and city.relation(faction_id, target_id).spare_until[target_id] > city.day:
				return 0.0
			var need = 1.5 if me.supplies < 20.0 or me.materials < 15.0 else 0.8
			var bold = 1.5 if target_id != "" and city.relation(faction_id, target_id).bold_until[faction_id] > city.day else 1.0
			return 0.75 * city.raid_worth(d) * need * bold
		"deter":
			# Warn off whoever raided us in the last two months
			var raided_on = city.relation(faction_id, target_id).last_raid[target_id] if target_id != "" else 0
			return 0.45 if raided_on > 0 and city.day - raided_on <= 60 else 0.0
		"conquer":
			return 1.2 + d.share(faction_id) / 100.0
		"income":
			return d.development * (1.4 if me.wealth < 25.0 else 0.5)
		"subvert":
			var target: Faction = city.factions.get(target_id)
			var draw = target.effect("draws_agitation_mult") if target else 1.0
			return (d.grievance / 100.0 + 0.2) * draw
		"stabilize":
			return maxf(0.0, d.grievance - 40.0) / 30.0
	return 0.0

func to_dict() -> Dictionary:
	return {"days_until_next_move": days_until_next_move, "days_until_next_diplomacy": days_until_next_diplomacy}

func load_dict(data: Dictionary):
	days_until_next_move = int(data.get("days_until_next_move", 3))
	days_until_next_diplomacy = int(data.get("days_until_next_diplomacy", 12))

func _home_secured(city: CityMap) -> bool:
	var me: Faction = city.factions[faction_id]
	if me.home_id < 0 or city.districts[me.home_id].owner_id() != faction_id:
		return true
	return city.districts[me.home_id].share(faction_id) >= GameData.rule("secure_threshold")

# What a faction is keen on (or reluctant about) comes from its active traits (data/traits.json "ai_goals"):
# a Militaristic crew raids, a Merchant one trades, a Socialist one digs in. The same for every faction,
# player included, so a crew that stops raiding stops being raiders. Gangs grow slowly until they become Warlord crews.
static func temperament(goal: String, me: Faction) -> float:
	var mult = 1.0
	for trait_name in me.traits.get_active_traits():
		mult *= float(GameData.traits()[trait_name].get("ai_goals", {}).get(goal, 1.0))
	# A gang grows slowly; once it becomes a Warlord crew it expands like anyone else
	if me.minor and me.government == "gang" and goal in ["expand", "scout"]:
		mult *= 0.5
	return mult
