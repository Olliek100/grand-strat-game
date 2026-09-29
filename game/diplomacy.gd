class_name Diplomacy

# Diplomatic actions (data/diplomacy.json), their acceptance odds, treaties, and opinion.
# The player and the AI use exactly the same rules and numbers, and every chance is shown
# with its reasons, so AI behaviour stays readable.

const MIN_CHANCE = 0.02
const MAX_CHANCE = 0.95

# --- Opinion ------------------------------------------------------------------------

# What `holder` thinks of `about` in the long run, as [[reason, value], ...].
# Day to day, opinion drifts toward this; gifts, raids and betrayals push it away for a while.
static func opinion_baseline(city: CityMap, holder_id: String, about_id: String) -> Array:
	var parts = []
	var holder: Faction = city.factions[holder_id]
	var about: Faction = city.factions[about_id]
	var their_traits = about.traits.get_active_traits()
	for t in holder.traits.faction_traits.values():
		if not t.active:
			continue
		for other_trait in their_traits:
			if other_trait in t.likes:
				parts.append(["Admires their %s ways" % other_trait, 15.0])
			elif other_trait in t.dislikes:
				parts.append(["Distrusts their %s ways" % other_trait, -15.0])
	var r = city.relation(holder_id, about_id)
	if r.trade:
		parts.append(["Trade partners", 10.0])
	if r.alliance:
		parts.append(["Allies", 20.0])
	elif r.pact:
		parts.append(["Non-aggression pact", 10.0])
	if r.overlord == about_id:
		parts.append(["Resents paying tribute", -10.0])
	elif r.overlord == holder_id:
		parts.append(["Protects them", 10.0])
	for fid in city.factions:
		if fid != holder_id and fid != about_id and city.is_at_war(holder_id, fid) and city.is_at_war(about_id, fid):
			parts.append(["Fighting the %s together" % city.faction_name(fid), 15.0])
			break
	if not r.protected() and not r.trade and city.shares_border(holder_id, about_id):
		parts.append(["Border tension", -5.0])
	# Everyone thinks a little better of a faction whose people choose its leaders
	var trust = about.effect("all_opinion")
	if trust != 0.0:
		parts.append(["Respects their elections", trust])
	# A neighbour known for keeping the peace (Good Neighbours) is easier to like
	var goodwill = about.effect("neighbour_opinion")
	if goodwill != 0.0 and city.shares_border(holder_id, about_id):
		parts.append(["Good neighbours", goodwill])
	# Renown earns respect from those with less of it
	var renown_gap = about.reputation - holder.reputation
	if renown_gap >= 10.0:
		parts.append(["Respects their renown", minf(GameData.rule("renown_respect_max"), renown_gap / GameData.rule("renown_respect_divisor"))])
	# With nowhere left to expand, neighbours start to look like the next frontier
	if city.shares_border(holder_id, about_id) and not city.has_open_frontier(holder_id):
		parts.append(["Covets their land", GameData.rule("land_hunger_opinion")])
	return parts

static func baseline_value(parts: Array) -> float:
	var total = 0.0
	for part in parts:
		total += part[1]
	return clampf(total, -100.0, 100.0)

# A third faction both sides are at war with or strongly dislike ("" if none)
static func common_threat(city: CityMap, a_id: String, b_id: String) -> String:
	for fid in city.factions:
		if fid == a_id or fid == b_id:
			continue
		var a_hostile = city.is_at_war(a_id, fid) or city.opinion_of(a_id, fid) < -25.0
		var b_hostile = city.is_at_war(b_id, fid) or city.opinion_of(b_id, fid) < -25.0
		if a_hostile and b_hostile:
			return fid
	return ""

# --- Actions ------------------------------------------------------------------------

# What an action costs `from_id`; integrating a vassal costs more the bigger it is. An action that can be paid
# in more than one way (a pact, tribute) is priced in whatever the payer can best spare.
static func action_cost(city: CityMap, action_id: String, from_id: String, to_id: String) -> Dictionary:
	var def = GameData.diplomacy_action(action_id)
	if def["kind"] == "tribute":
		return tribute_price(city, from_id, to_id)
	if def.has("cost_options"):
		return _best_option(city.factions[from_id], def["cost_options"])
	var cost: Dictionary = def["cost"].duplicate()
	var per_district: Dictionary = def.get("cost_per_district", {})
	for resource_type in per_district:
		cost[resource_type] = cost.get(resource_type, 0.0) + per_district[resource_type] * city.districts_held(to_id)
	return cost

# Of several ways to pay, the one the payer can best spare (the most left over for its price);
# if none is affordable, the first, so the shortfall message names something to aim for
static func _best_option(payer: Faction, options: Array) -> Dictionary:
	var best: Dictionary = options[0]
	var best_ratio = -1.0
	for option in options:
		if not payer.can_afford(option):
			continue
		var resource_type: String = option.keys()[0]
		var ratio = payer.get(resource_type) / maxf(1.0, option[resource_type])
		if ratio > best_ratio:
			best_ratio = ratio
			best = option
	return best.duplicate()

# What `payer` hands `receiver` as tribute: food or materials, more for a stronger receiver
static func tribute_price(city: CityMap, payer_id: String, receiver_id: String) -> Dictionary:
	var def = GameData.diplomacy_action("tribute")
	var amount = roundf(def["tribute_base"] + city.faction_strength(receiver_id) * def["tribute_per_strength"])
	return _best_option(city.factions[payer_id], [{"supplies": amount}, {"materials": amount}])

# Tribute changes hands: the payer is left alone for a while
static func _receive_tribute(city: CityMap, payer_id: String, receiver_id: String, paid: Dictionary):
	var receiver: Faction = city.factions[receiver_id]
	for resource_type in paid:
		receiver.set(resource_type, receiver.get(resource_type) + paid[resource_type])
	var r = city.relation(payer_id, receiver_id)
	r.spare_until[receiver_id] = maxi(r.spare_until[receiver_id], city.day + int(GameData.diplomacy_action("tribute")["spare_days"]))
	city.change_opinion(receiver_id, payer_id, 5.0, "paid_tribute")
	var text = "The %s paid the %s tribute (%s): no raids from the %s for %d days." % [city.faction_name(payer_id), city.faction_name(receiver_id),
		_amount_text(paid), city.faction_name(receiver_id), r.spare_until[receiver_id] - city.day]
	city.event.emit(text, "info" if city.player_id not in [payer_id, receiver_id] else "good")

# A refused demand: the demander's raids on the refuser get better odds for a while
static func _demand_refused(city: CityMap, from_id: String, to_id: String):
	var r = city.relation(from_id, to_id)
	r.bold_until[from_id] = maxi(r.bold_until[from_id], city.day + int(GameData.diplomacy_action("demand")["refused_days"]))
	city.change_opinion(from_id, to_id, -5.0, "declined")
	var text = "The %s refused to pay the %s tribute: their raids get +%d%% odds for %d days." % [city.faction_name(to_id), city.faction_name(from_id),
		roundi((GameData.rule("emboldened_odds") - 1.0) * 100), r.bold_until[from_id] - city.day]
	city.event.emit(text, "alert" if to_id == city.player_id else "info")

static func _amount_text(amounts: Dictionary) -> String:
	var parts = []
	for resource_type in amounts:
		parts.append("%d %s" % [amounts[resource_type], "food" if resource_type == "supplies" else resource_type])
	return ", ".join(parts)

# Trade needs a connection: touching territory, or a Market on both sides
static func has_connection(city: CityMap, a_id: String, b_id: String) -> bool:
	if city.shares_border(a_id, b_id):
		return true
	var a_market = false
	var b_market = false
	for d in city.districts:
		if d.building_effect("trade_income") > 0.0:
			if d.owner_id() == a_id:
				a_market = true
			elif d.owner_id() == b_id:
				b_market = true
	return a_market and b_market

# True if a stronger neighbour dislikes this faction: a reason to seek protection
static func _feels_threatened(city: CityMap, faction_id: String) -> bool:
	for fid in city.factions:
		if fid == faction_id or city.opinion_of(fid, faction_id) >= -25.0:
			continue
		if city.shares_border(fid, faction_id) and city.faction_strength(fid) > city.faction_strength(faction_id):
			return true
	return false

# Returns "" if `from` can start this action toward `to`, otherwise why not.
# With for_resolution, skips the checks that only matter when sending the envoy.
static func check_action(city: CityMap, action_id: String, from_id: String, to_id: String, for_resolution: bool = false) -> String:
	var def = GameData.diplomacy_action(action_id)
	if from_id == to_id or not city.factions.has(to_id) or not city.factions.has(from_id):
		return "No such faction"
	var r = city.relation(from_id, to_id)
	var min_opinion: float = def.get("min_opinion", -100.0)
	if not for_resolution:
		if city.mission_between(from_id, to_id):
			return "An envoy is already on the way"
		if city.proposal_between(from_id, to_id) >= 0:
			return "A proposal is already waiting for an answer"
	if def["kind"] != "gift" and r.at_war:
		return "You're at war (make peace first)"
	match action_id:
		"trade":
			if r.trade:
				return "You already trade with them"
			if not has_connection(city, from_id, to_id):
				return "No connection: your territories must touch, or you both need a Market"
		"pact":
			if r.overlord != "" or r.alliance:
				return "Already covered by a treaty"
			if r.pact and not in_renewal_window(city, r):
				return "Pact holds for %d more days (renewal opens %d days before it lapses)" % [r.treaty_until_day - city.day, GameData.rule("treaty_renewal_days")]
			# Raids, agitation and war all need a shared border, so a pact only means something between neighbours
			if not r.pact and not city.shares_border(from_id, to_id):
				return "You don't share a border: a pact only matters between neighbours"
		"alliance":
			if r.alliance and not in_renewal_window(city, r):
				return "Alliance holds for %d more days (renewal opens %d days before it lapses)" % [r.treaty_until_day - city.day, GameData.rule("treaty_renewal_days")]
			if r.overlord != "":
				return "Vassals already fight together"
			if city.opinion_of(to_id, from_id) < min_opinion:
				return "They need to think well of you first (opinion %d+, now %d)" % [min_opinion, city.opinion_of(to_id, from_id)]
		"vassalage":
			if r.overlord != "":
				return "Already bound by vassalage"
			if city.overlord_of(from_id) != "":
				return "A vassal can't take vassals"
			if city.overlord_of(to_id) != "":
				return "They already serve the %s" % city.faction_name(city.overlord_of(to_id))
			# A small faction will take a patron much closer to its own size than a great one would
			var max_ratio: float = GameData.rule("minor_vassal_max_strength_ratio" if city.factions[to_id].minor else "vassal_max_strength_ratio")
			if city.faction_strength(to_id) > city.faction_strength(from_id) * max_ratio:
				return "They're too strong to submit (must be under %d%% of your strength)" % (max_ratio * 100)
		"tribute":
			if not r.menaced_recently(to_id, city.day, int(GameData.rule("menace_memory_days"))):
				return "Only for a faction that raided you or demanded tribute lately"
			if r.spare_until[to_id] > city.day:
				return "They already leave you alone (%d more days)" % (r.spare_until[to_id] - city.day)
		"demand":
			if not city.shares_border(from_id, to_id):
				return "You don't share a border with them"
			if r.protected():
				return "You have a treaty with them"
			if r.spare_until[from_id] > city.day:
				return "You promised them no raids for %d more days" % (r.spare_until[from_id] - city.day)
			if not for_resolution and r.last_demand[from_id] > 0 and city.day - r.last_demand[from_id] < int(GameData.rule("menace_memory_days")):
				return "You demanded tribute %d days ago; wait until %d have passed" % [city.day - r.last_demand[from_id], GameData.rule("menace_memory_days")]
		"integrate":
			if r.overlord != from_id:
				return "They're not your vassal"
			if to_id == city.player_id:
				return "The player can't be integrated"
			var days_as_vassal = city.day - r.vassal_since_day
			var needed = int(GameData.rule("integrate_min_vassal_days"))
			if days_as_vassal < needed:
				return "Vassal for %d days (needs %d)" % [days_as_vassal, needed]
			if city.opinion_of(to_id, from_id) < min_opinion:
				return "Not loyal enough (opinion %d, needs %d)" % [city.opinion_of(to_id, from_id), min_opinion]
	if not for_resolution and not city.factions[from_id].can_afford(action_cost(city, action_id, from_id, to_id)):
		return city.factions[from_id].shortfall(action_cost(city, action_id, from_id, to_id))
	return ""

# Pacts and alliances can be renewed in their final months
static func in_renewal_window(city: CityMap, r: Relation) -> bool:
	return r.treaty_until_day - city.day <= int(GameData.rule("treaty_renewal_days"))

# Chance the other side agrees: {"chance", "base", "factors": [[reason, multiplier], ...]}
static func acceptance(city: CityMap, action_id: String, from_id: String, to_id: String) -> Dictionary:
	var def = GameData.diplomacy_action(action_id)
	if def["kind"] in ["gift", "tribute"]:
		return {"chance": 1.0, "base": 1.0, "factors": []}
	if def["kind"] == "demand":
		return _demand_acceptance(city, from_id, to_id)
	var from: Faction = city.factions[from_id]
	var to: Faction = city.factions[to_id]
	var factors = []
	var opinion = city.opinion_of(to_id, from_id)
	factors.append(["Their opinion of you (%+d)" % opinion, clampf(1.0 + opinion / 100.0, 0.1, 2.0)])
	var reputation = from.effect("diplomacy_mult")
	if reputation != 1.0:
		factors.append(["Your Diplomatic reputation", reputation])
	if from.renown >= 1.0:
		factors.append(["Your renown (%d)" % from.renown, 1.0 + from.renown / GameData.rule("renown_acceptance_divisor")])
	var leader = city.leader_of(from_id)
	if leader:
		for t in leader.traits:
			var mult = float(GameData.character_trait(t).get("acceptance", 1.0))
			if mult != 1.0:
				factors.append(["Your leader is a %s" % GameData.character_trait(t)["label"], mult])
	var envoy = city.council_member(from_id, "envoy")
	if envoy:
		factors.append(["Your Envoy %s (Diplomacy %d)" % [envoy.name, envoy.skills["diplomacy"]],
			1.0 + (envoy.skills["diplomacy"] - GameData.rule("skill_neutral")) * GameData.rule("envoy_acceptance_step")])
	match action_id:
		"trade":
			var interest = to.effect("trade_interest_mult")
			if interest != 1.0:
				factors.append(["They value trade", interest])
			if city.shares_border(from_id, to_id):
				factors.append(["Neighbours", 1.2])
		"pact":
			var interest = to.effect("pact_interest_mult")
			if interest != 1.0:
				factors.append(["They prefer a free hand", interest])
			# Raiding is how a raider crew lives: a promise not to is a big ask (tribute or threats work better)
			if city.is_raider(to_id):
				factors.append(["Raiders would rather keep a free hand", 0.5])
			if city.at_war_with_anyone(to_id):
				factors.append(["They're busy with another war", 1.3])
			if city.faction_strength(from_id) > city.faction_strength(to_id) * 1.3:
				factors.append(["You're stronger than them", 1.3])
		"alliance":
			var threat = common_threat(city, from_id, to_id)
			if threat != "":
				factors.append(["Common enemy: the %s" % city.faction_name(threat), 1.6])
			else:
				factors.append(["No common enemy", 0.6])
		"vassalage":
			var ratio = city.faction_strength(to_id) / maxf(1.0, city.faction_strength(from_id))
			factors.append(["They're %d%% of your strength" % (ratio * 100), clampf(1.6 - ratio * 2.0, 0.3, 1.5)])
			if city.at_war_with_anyone(to_id) or _feels_threatened(city, to_id):
				factors.append(["They need protection", 1.5])
			else:
				factors.append(["They value their independence", 0.5])
			# A small gang can live as someone's client; a great faction would rather fight on
			if to.minor:
				factors.append(["A small faction, glad of a patron", 1.4])
			else:
				factors.append(["A great faction, too proud to kneel", 0.3])
	var chance: float = def["base"]
	for factor in factors:
		chance *= factor[1]
	return {"chance": clampf(chance, MIN_CHANCE, MAX_CHANCE), "base": def["base"], "factors": factors}

# Whether a faction gives in to a demand for tribute: fear of the demander, and whether it can pay
static func _demand_acceptance(city: CityMap, from_id: String, to_id: String) -> Dictionary:
	var factors = []
	var ratio = city.faction_strength(from_id) / maxf(1.0, city.faction_strength(to_id))
	factors.append(["They're %d%% of your strength" % (100.0 / maxf(0.01, ratio)), clampf(0.4 + ratio * 0.6, 0.3, 1.8)])
	var feared = city.factions[from_id].effect("demand_acceptance_mult")
	if feared != 1.0:
		factors.append(["Their name is feared", feared])
	var price = tribute_price(city, to_id, from_id)
	if not city.factions[to_id].can_afford(price):
		factors.append(["They can't pay %s" % _amount_text(price), 0.0])
	if city.at_war_with_anyone(to_id):
		factors.append(["They're busy with a war", 1.3])
	var chance: float = GameData.diplomacy_action("demand")["base"]
	for factor in factors:
		chance *= factor[1]
	return {"chance": clampf(chance, 0.0, MAX_CHANCE), "base": GameData.diplomacy_action("demand")["base"], "factors": factors}

static func start_action(city: CityMap, action_id: String, from_id: String, to_id: String) -> String:
	var err = check_action(city, action_id, from_id, to_id)
	if err != "":
		return err
	var def = GameData.diplomacy_action(action_id)
	# Tribute is handed over when the envoy arrives, so it's never lost if things change on the way
	if def["kind"] != "tribute":
		city.factions[from_id].pay(action_cost(city, action_id, from_id, to_id))
	if def["kind"] == "demand":
		city.relation(from_id, to_id).last_demand[from_id] = city.day
	city.missions.append(DiplomaticMission.new(action_id, from_id, to_id, int(def["days"])))
	city.feed_trait_by_name(city.factions[from_id], "Diplomatic", 2.0)
	if from_id == city.player_id:
		var chance = acceptance(city, action_id, from_id, to_id)["chance"]
		var odds = "" if def["kind"] in ["gift", "tribute"] else " (%d%% chance they agree)" % (chance * 100)
		city.event.emit("Envoy sent to the %s: %s, arrives in %d days%s." % [city.faction_name(to_id), def["label"].to_lower(), def["days"], odds], "info")
	return ""

static func resolve_mission(city: CityMap, m: DiplomaticMission):
	if not city.factions.has(m.from_id) or not city.factions.has(m.to_id):
		return
	var def = GameData.diplomacy_action(m.action_id)
	var player_involved = m.from_id == city.player_id or m.to_id == city.player_id
	if def["kind"] == "gift":
		var current = city.opinion_of(m.to_id, m.from_id)
		var gain: float = def["opinion"] * (1.0 - maxf(0.0, current) / 100.0) * city.factions[m.from_id].effect("diplomacy_mult")
		city.change_opinion(m.to_id, m.from_id, gain, "gift")
		if player_involved:
			city.event.emit("The %s accepted gifts from the %s (opinion %+d)." % [city.faction_name(m.to_id), city.faction_name(m.from_id), gain], "good" if m.from_id == city.player_id else "info")
		return
	if def["kind"] == "tribute":
		var price = tribute_price(city, m.from_id, m.to_id)
		if city.factions[m.from_id].can_afford(price):
			city.factions[m.from_id].pay(price)
			_receive_tribute(city, m.from_id, m.to_id, price)
		elif m.from_id == city.player_id:
			city.event.emit("Your tribute to the %s never arrived: %s." % [city.faction_name(m.to_id), city.factions[m.from_id].shortfall(price).to_lower()], "bad")
		return
	var err = check_action(city, m.action_id, m.from_id, m.to_id, true)
	if err != "":
		if m.from_id == city.player_id:
			city.event.emit("Your envoy to the %s turned back: %s." % [city.faction_name(m.to_id), err.to_lower()], "bad")
		return
	# The player answers proposals made to them; AI factions decide on the odds
	if m.to_id == city.player_id:
		city.add_proposal(m.action_id, m.from_id)
		return
	if def["kind"] == "demand":
		if city.rng.randf() < _demand_acceptance(city, m.from_id, m.to_id)["chance"]:
			form_treaty(city, m.action_id, m.from_id, m.to_id)
		else:
			_demand_refused(city, m.from_id, m.to_id)
		return
	var chance = acceptance(city, m.action_id, m.from_id, m.to_id)["chance"]
	if city.rng.randf() < chance:
		form_treaty(city, m.action_id, m.from_id, m.to_id)
		city.feed_trait_by_name(city.factions[m.from_id], "Diplomatic", 4.0)
	elif player_involved:
		city.event.emit("The %s turned down your offer: %s (%d%% chance)." % [city.faction_name(m.to_id), def["label"].to_lower(), chance * 100], "bad")

static func form_treaty(city: CityMap, action_id: String, from_id: String, to_id: String):
	var def = GameData.diplomacy_action(action_id)
	var r = city.relation(from_id, to_id)
	var names = [city.faction_name(from_id), city.faction_name(to_id)]
	var text = ""
	match def.get("treaty", def["kind"]):
		"demand":
			# The one the demand was made of pays up
			var price = tribute_price(city, to_id, from_id)
			if not city.factions[to_id].can_afford(price):
				_demand_refused(city, from_id, to_id)
				return
			city.factions[to_id].pay(price)
			_receive_tribute(city, to_id, from_id, price)
			return
		"trade":
			r.trade = true
			text = "The %s and the %s signed a trade agreement." % names
		"pact":
			text = "The %s and the %s %s a non-aggression pact." % [names[0], names[1], "renewed" if r.pact else "signed"]
			r.pact = true
			r.treaty_until_day = city.day + int(GameData.rule("pact_duration_days"))
			r.lapse_warned = false
		"alliance":
			text = "The %s and the %s %s a defensive alliance." % [names[0], names[1], "renewed" if r.alliance else "formed"]
			r.alliance = true
			r.pact = true
			r.treaty_until_day = city.day + int(GameData.rule("alliance_duration_days"))
			r.lapse_warned = false
		"vassal":
			r.overlord = from_id
			r.vassal_since_day = city.day
			text = "The %s became vassals of the %s." % [names[1], names[0]]
		"integrate":
			text = "The %s have merged into the %s." % [names[1], names[0]]
			city.retire_faction(to_id, from_id)
	if from_id == city.player_id or to_id == city.player_id:
		city.event.emit(text, "good")
	else:
		city.event.emit(text, "info")

# Ends a treaty early. Breaking promises costs opinion, with the other side and with everyone watching.
static func break_treaty(city: CityMap, faction_id: String, other_id: String, treaty: String) -> String:
	var r = city.relation(faction_id, other_id)
	var other_name = city.faction_name(other_id)
	match treaty:
		"trade":
			if not r.trade:
				return "No trade agreement to end"
			r.trade = false
			city.change_opinion(other_id, faction_id, -10.0, "ended_trade")
			_announce(city, faction_id, "ended the trade agreement with the %s" % other_name)
		"pact", "alliance":
			if not (r.pact or r.alliance):
				return "No pact to break"
			var was_alliance = r.alliance
			r.pact = false
			r.alliance = false
			city.change_opinion(other_id, faction_id, -40.0 if was_alliance else -30.0, "broke_treaty")
			_betrayal(city, faction_id, other_id)
			_announce(city, faction_id, "broke their %s with the %s" % ["alliance" if was_alliance else "non-aggression pact", other_name])
		"vassal":
			if r.overlord == "":
				return "No vassalage to end"
			if r.overlord == faction_id:
				r.overlord = ""
				city.change_opinion(other_id, faction_id, 20.0, "released")
				_announce(city, faction_id, "released the %s from vassalage" % other_name)
			else:
				# Declaring independence: the overlord answers with war
				r.overlord = ""
				_announce(city, faction_id, "declared independence from the %s" % other_name)
				city.start_war(other_id, faction_id)
		_:
			return "Unknown treaty"
	return ""

static func _betrayal(city: CityMap, faction_id: String, victim_id: String):
	for fid in city.factions:
		if fid != faction_id and fid != victim_id:
			city.change_opinion(fid, faction_id, GameData.rule("betrayal_opinion"), "treaty_breaker")

static func _announce(city: CityMap, faction_id: String, what: String):
	if faction_id == city.player_id:
		city.event.emit("You %s." % what, "info")
	else:
		city.event.emit("The %s %s." % [city.faction_name(faction_id), what], "alert" if what.contains(city.faction_name(city.player_id)) else "info")

# --- Economy ------------------------------------------------------------------------

# Daily wealth a faction earns from one trade agreement: grows with shared borders and Markets
static func trade_income(city: CityMap, faction_id: String, partner_id: String) -> float:
	var contacts = 0
	var markets = 0.0
	for d in city.districts:
		if d.owner_id() != faction_id:
			continue
		if city.buildings_active(d):
			markets += d.building_effect("trade_income")
		for n_id in d.neighbor_ids:
			if city.districts[n_id].owner_id() == partner_id:
				contacts += 1
				break
	var income = GameData.rule("trade_base_income") + contacts * GameData.rule("trade_income_per_contact") + markets
	return income * city.factions[faction_id].effect("trade_income_mult")
