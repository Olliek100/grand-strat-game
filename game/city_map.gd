class_name CityMap

# Everything that happens in the world is reported through this signal.
# kind: "info", "good", "bad", or "alert" (alerts can pause the game)
signal event(text: String, kind: String)
# Emitted when a faction is created, merged or destroyed, so the UI can rebuild its faction panels
signal factions_changed
# Emitted the first time another faction's land touches the player's
signal first_contact(faction_id: String)
# Big moments that deserve a pop-up: first contact, war on you, civil war, a leader's death
signal major_event(title: String, text: String, faction_id: String)

const SAVE_VERSION = 5
const SAVE_PATH = "user://savegame.sav"

const DAYS_PER_MONTH = 30
const MONTHS_PER_YEAR = 12

var districts: Array[District] = []
# Size of the map in map units, from data/map.json
var map_size: Vector2 = Vector2.ZERO
# Faction id -> Faction, in scenario order
var factions: Dictionary = {}
# "a|b" (ids sorted) -> Relation, created on first use
var relations: Dictionary = {}
var ventures: Array[ActiveVenture] = []
var constructions: Array[Construction] = []
# Named characters of every faction (see character.gd)
var characters: Array[Character] = []
var next_character_id: int = 1
# Characters who are gone: killed, deserted or dismissed, as {"name", "faction", "post", "fate", "day", "ventures", "triumphs"}
var departed: Array = []
# Factions the player has met (bordered at least once): id -> day
var player_met: Dictionary = {}
# The dead, kept for family trees and the archive of past leaders
var graveyard: Array[Character] = []
var missions: Array[DiplomaticMission] = []
# Proposals from AI factions waiting for the player's answer: {"action", "from", "expires_day"}
var proposals: Array = []
var day: int = 0
var rng := RandomNumberGenerator.new()
# Whose point of view the UI and alerts use
var player_id: String = ""
var player_defeated: bool = false

# Pass a dictionary from to_save() to restore a saved game; otherwise starts data/scenario.json
func _init(save_data: Dictionary = {}):
	_load_layout()
	if save_data.is_empty():
		rng.randomize()
		_randomize_district_stats()
		_setup_scenario(GameData.scenario())
	else:
		_load(save_data.duplicate(true))

# --- Map layout -------------------------------------------------------------------

# Districts come from data/map.json (built by tools/generate_map.gd): shape, type, borough and
# neighbours. Across the river, districts are only neighbours where a bridge crosses.
func _load_layout():
	var layout = GameData.map()
	map_size = Vector2(layout["size"][0], layout["size"][1])
	for entry in layout["districts"]:
		var poly = PackedVector2Array()
		for p in entry["polygon"]:
			poly.append(Vector2(p[0], p[1]))
		var d = District.new(int(entry["id"]), entry["name"], poly)
		d.center = Vector2(entry["center"][0], entry["center"][1])
		d.district_type = entry["type"]
		d.borough = entry["borough"]
		for n in entry["neighbors"]:
			d.neighbor_ids.append(int(n))
		districts.append(d)

# Starting stats depend on the district type (see data/district_types.json)
func _randomize_district_stats():
	for d in districts:
		var t = GameData.district_type(d.district_type)
		d.population = rng.randf_range(t["population"][0], t["population"][1])
		d.grievance = rng.randf_range(10, 30)
		d.ruin_level = rng.randf_range(t["ruin"][0], t["ruin"][1])
		d.development = rng.randf_range(t["development"][0], t["development"][1])
		# Danger: heavy industry and the docks are worse, parks and suburbs calmer
		d.hazard = rng.randf_range(0.05, 0.3) + {"industrial": 0.12, "docks": 0.1, "downtown": 0.06, "parkland": -0.04, "suburb": -0.03}.get(d.district_type, 0.0)

func _setup_scenario(scenario: Dictionary):
	for def in scenario["factions"]:
		var f = Faction.new(def["id"], def["name"], Color.html(def["color"]), def.get("player", false))
		f.manpower = def.get("manpower", 15.0)
		f.supplies = def.get("supplies", 40.0)
		f.wealth = def.get("wealth", 30.0)
		f.materials = def.get("materials", 15.0)
		f.arms = def.get("arms", 0.0)
		f.minor = def.get("minor", false)
		f.personality = def.get("personality", "")
		f.blurb = def.get("blurb", "")
		for trait_name in def.get("traits", {}):
			f.traits.add_faction_trait_value(trait_name, def["traits"][trait_name])
		factions[f.id] = f
		if f.is_player:
			player_id = f.id
	for def in scenario["factions"]:
		if def.has("home"):
			_claim_home(def["id"], Vector2(def["home"][0], def["home"][1]) * map_size)
	# Minor factions settle two districts out from a big faction: not touching anyone yet, but met within months
	for def in scenario["factions"]:
		if not def.has("home"):
			_place_minor(def["id"], def["near"])
	# Each faction starts with a few captains, one strong in each skill
	for fid in factions:
		for k in (2 if factions[fid].minor else int(GameData.rule("captains_at_start"))):
			_new_captain(fid, Character.SKILLS[k % Character.SKILLS.size()])
		_found_dynasty(fid)
		# Rivals start with two seats filled (War Chief and Quartermaster); the player picks their own
		if fid != player_id:
			for post in (["war_chief"] if factions[fid].minor else ["war_chief", "quartermaster"]):
				var best = best_candidate(fid, post)
				if best:
					best.post = post
	var ids = factions.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var r = relation(ids[i], ids[j])
			r.truce_until_day = int(scenario.get("opening_truce_days", 0))
			# First impressions come from who each faction is
			for fid in [r.a, r.b]:
				r.baseline[fid] = Diplomacy.baseline_value(Diplomacy.opinion_baseline(self, fid, r.other(fid)))
				r.recompute_opinion(fid)

# A minor faction's single district: two steps from the big faction it's placed near, not bordering anyone,
# and as far as possible from the other minors
func _place_minor(faction_id: String, near_id: String):
	var start: District = districts[factions[near_id].home_id]
	var steps = {start.id: 0}
	var frontier = [start]
	while not frontier.is_empty():
		var d: District = frontier.pop_front()
		for n_id in d.neighbor_ids:
			if not steps.has(n_id):
				steps[n_id] = steps[d.id] + 1
				frontier.append(districts[n_id])
	var best: District = null
	var best_score = -1.0
	for d in districts:
		if not steps.has(d.id) or steps[d.id] < 2 or steps[d.id] > 3 or d.owner_id() != "":
			continue
		var touching = false
		for n_id in d.neighbor_ids:
			if districts[n_id].owner_id() != "":
				touching = true
		if touching:
			continue
		# Prefer two steps out, well away from other factions' homes
		var score = (2.0 if steps[d.id] == 2 else 1.0) * 1000.0
		var nearest = INF
		for f in factions.values():
			if f.home_id >= 0:
				nearest = minf(nearest, d.center.distance_to(districts[f.home_id].center))
		score += nearest + rng.randf() * 50.0
		if score > best_score:
			best_score = score
			best = d
	if best == null:
		return
	factions[faction_id].home_id = best.id
	best.influence.clear()
	best.add_influence(faction_id, 62.0)
	best.grievance = 25.0
	best.population = maxf(best.population, 45.0)
	best.hazard = minf(best.hazard, 0.15)

# Each faction starts with a single shelter district
func _claim_home(faction_id: String, near: Vector2):
	var home = districts[0]
	for d in districts:
		if d.center.distance_to(near) < home.center.distance_to(near):
			home = d
	factions[faction_id].home_id = home.id
	# One shelter, held but not yet secure: the opening is about making it safe and fed
	home.add_influence(faction_id, 58.0)
	home.development = 0.45
	home.ruin_level = 0.35
	home.grievance = 25.0
	home.hazard = 0.05
	home.population = 80.0

# --- Queries ------------------------------------------------------------------

func faction_name(faction_id: String) -> String:
	return factions[faction_id].display_name if factions.has(faction_id) else "nobody"

func borders_territory(faction_id: String, district: District) -> bool:
	for n_id in district.neighbor_ids:
		if districts[n_id].owner_id() == faction_id:
			return true
	return false

# A faction can act in districts it owns and on its frontier (districts bordering one it owns)
func can_reach(faction_id: String, district: District) -> bool:
	return district.owner_id() == faction_id or borders_territory(faction_id, district)

# Whether a faction knows a district's salvage, danger and people: its own land, or land it has scouted
func knows(faction_id: String, district: District) -> bool:
	if district.owner_id() == faction_id:
		return true
	var f: Faction = factions.get(faction_id)
	return f != null and f.scouted.has(str(district.id))

# Whether a faction can see a district at all under full fog: what it knows, plus the land next to its own
func sees(faction_id: String, district: District) -> bool:
	return knows(faction_id, district) or borders_territory(faction_id, district)

func mark_scouted(faction_id: String, district: District):
	var f: Faction = factions.get(faction_id)
	if f:
		f.scouted[str(district.id)] = day

# Scouting reaches out step by step: next to your land, or next to somewhere already scouted
func can_scout_from(faction_id: String, district: District) -> bool:
	if borders_territory(faction_id, district):
		return true
	for n_id in district.neighbor_ids:
		if factions[faction_id].scouted.has(str(n_id)):
			return true
	return false

# Income/recruit multiplier the owner gets from a district (0 if unowned)
func yield_multiplier(district: District) -> float:
	if district.owner_id() == "":
		return 0.0
	return GameData.rule("status_yield").get(district.get_control_status(), 0.0)

func has_venture_at(faction_id: String, district: District) -> bool:
	for v in ventures:
		if v.faction_id == faction_id and v.district == district:
			return true
	return false

func active_venture_count(faction_id: String) -> int:
	var count = 0
	for v in ventures:
		if v.faction_id == faction_id:
			count += 1
	return count

func crew_away(faction_id: String) -> int:
	var total = 0
	for v in ventures:
		if v.faction_id == faction_id:
			total += v.crew
	return total

func districts_held(faction_id: String) -> int:
	var count = 0
	for d in districts:
		if d.owner_id() == faction_id:
			count += 1
	return count

# Rough military weight, used by the AI to judge whether a war is winnable
func faction_strength(faction_id: String) -> float:
	return factions[faction_id].manpower + crew_away(faction_id) + districts_held(faction_id) * 2

# True if there's still unclaimed land on this faction's border to expand into
func has_open_frontier(faction_id: String) -> bool:
	for d in districts:
		if d.owner_id() == "" and borders_territory(faction_id, d):
			return true
	return false

# True if a owns a district that borders land b owns
func shares_border(a_id: String, b_id: String) -> bool:
	for d in districts:
		if d.owner_id() == b_id and borders_territory(a_id, d):
			return true
	return false

func date_string() -> String:
	var year = day / (DAYS_PER_MONTH * MONTHS_PER_YEAR) + 1
	var month = (day / DAYS_PER_MONTH) % MONTHS_PER_YEAR + 1
	var day_of_month = day % DAYS_PER_MONTH + 1
	return "Year %d, Month %d, Day %d" % [year, month, day_of_month]

# --- Diplomacy ------------------------------------------------------------------

func relation(a_id: String, b_id: String) -> Relation:
	var key = a_id + "|" + b_id if a_id < b_id else b_id + "|" + a_id
	if not relations.has(key):
		relations[key] = Relation.new(a_id, b_id)
	return relations[key]

func is_at_war(a_id: String, b_id: String) -> bool:
	if a_id == b_id or not factions.has(a_id) or not factions.has(b_id):
		return false
	return relation(a_id, b_id).at_war

func war_enemies(faction_id: String) -> Array:
	var enemies = []
	for fid in factions:
		if is_at_war(faction_id, fid):
			enemies.append(fid)
	return enemies

func at_war_with_anyone(faction_id: String) -> bool:
	return not war_enemies(faction_id).is_empty()

# The faction this one is a vassal of ("" if independent)
func overlord_of(faction_id: String) -> String:
	for fid in factions:
		if fid != faction_id and relation(faction_id, fid).overlord == fid:
			return fid
	return ""

func vassals_of(faction_id: String) -> Array:
	var found = []
	for fid in factions:
		if fid != faction_id and relation(faction_id, fid).overlord == faction_id:
			found.append(fid)
	return found

# Factions that would come to this one's defence: allies, overlord and vassals
func defenders_of(faction_id: String) -> Array:
	var found = []
	for fid in factions:
		if fid == faction_id:
			continue
		var r = relation(faction_id, fid)
		if r.alliance or r.overlord != "":
			found.append(fid)
	return found

# The district shown as a faction's capital on the map (-1 if it holds no land)
func capital_of(faction_id: String) -> int:
	var f: Faction = factions.get(faction_id)
	if f and f.home_id >= 0 and districts[f.home_id].owner_id() == faction_id:
		return f.home_id
	var best = -1
	for d in districts:
		if d.owner_id() == faction_id and (best < 0 or d.share(faction_id) > districts[best].share(faction_id)):
			best = d.id
	return best

func add_exhaustion(faction_id: String, other_id: String, amount: float):
	var r = relation(faction_id, other_id)
	if r.at_war:
		r.exhaustion[faction_id] = minf(100.0, r.exhaustion[faction_id] + amount)

# Gives `holder` a named memory of `about` (see data/opinion_modifiers.json). Repeats of the same
# memory stack up to its limit; every memory fades by its decay each day.
func change_opinion(holder_id: String, about_id: String, amount: float, modifier_id: String):
	if holder_id == about_id or not factions.has(holder_id) or not factions.has(about_id):
		return
	var r = relation(holder_id, about_id)
	var limit: float = GameData.opinion_modifier(modifier_id)["limit"]
	var memories: Array = r.modifiers[holder_id]
	var found = false
	for m in memories:
		if m["id"] == modifier_id:
			m["value"] = clampf(m["value"] + amount, -limit, limit)
			found = true
	if not found:
		memories.append({"id": modifier_id, "value": clampf(amount, -limit, limit)})
	r.recompute_opinion(holder_id)

func opinion_of(holder_id: String, about_id: String) -> float:
	return relation(holder_id, about_id).opinion[holder_id]

func mission_between(from_id: String, to_id: String) -> bool:
	for m in missions:
		if m.from_id == from_id and m.to_id == to_id:
			return true
	return false

# Index of a pending proposal from `from_id` to `to_id` (the player), or -1
func proposal_between(from_id: String, to_id: String) -> int:
	if to_id != player_id:
		return -1
	for i in proposals.size():
		if proposals[i]["from"] == from_id:
			return i
	return -1

func add_proposal(action_id: String, from_id: String):
	proposals.append({"action": action_id, "from": from_id, "expires_day": day + int(GameData.rule("proposal_expiry_days"))})
	event.emit("The %s propose %s. Answer in Diplomacy (F4)." % [faction_name(from_id), GameData.diplomacy_action(action_id).get("proposal", action_id)], "alert")

func answer_proposal(index: int, accept: bool, expired: bool = false):
	if index < 0 or index >= proposals.size():
		return
	var p = proposals[index]
	proposals.remove_at(index)
	if not factions.has(p["from"]):
		return
	if accept and Diplomacy.check_action(self, p["action"], p["from"], player_id, true) == "":
		Diplomacy.form_treaty(self, p["action"], p["from"], player_id)
	else:
		change_opinion(p["from"], player_id, -5.0, "declined")
		var what = "went unanswered and lapsed" if expired else "was turned down"
		event.emit("The %s's proposal %s." % [faction_name(p["from"]), what], "info")

# Returns "" if the faction can declare war on the target now, otherwise why not
func check_declare_war(faction_id: String, target_id: String) -> String:
	if faction_id == target_id or not factions.has(target_id):
		return "No such faction"
	var r = relation(faction_id, target_id)
	if r.at_war:
		return "Already at war"
	if r.protected():
		return "You have a treaty with them (break it first)"
	if overlord_of(faction_id) != "":
		return "Vassals can't declare war"
	if day < r.truce_until_day:
		return "Truce holds for %d more days" % (r.truce_until_day - day)
	if not shares_border(faction_id, target_id):
		return "You don't share a border with them yet"
	var cost: Dictionary = GameData.rule("war_cost")
	if not factions[faction_id].can_afford(cost):
		return "Declaring war costs %d wealth" % cost.get("wealth", 0)
	return ""

func declare_war(faction_id: String, target_id: String) -> String:
	var err = check_declare_war(faction_id, target_id)
	if err != "":
		return err
	factions[faction_id].pay(GameData.rule("war_cost"))
	start_war(faction_id, target_id)
	call_to_arms(faction_id, target_id)
	return ""

# Treaties pull others in: the defender's allies, overlord and vassals; the attacker's vassals
func call_to_arms(attacker_id: String, defender_id: String):
	for ally_id in defenders_of(defender_id):
		_join_war(ally_id, attacker_id, defender_id)
	for vassal_id in vassals_of(attacker_id):
		_join_war(vassal_id, defender_id, attacker_id)

# Puts two factions at war (no checks); ends any treaties between them
func start_war(faction_id: String, target_id: String):
	var r = relation(faction_id, target_id)
	r.at_war = true
	r.war_start_day = day
	r.peace_offered_by = ""
	r.exhaustion = {r.a: 0.0, r.b: 0.0}
	r.trade = false
	r.pact = false
	r.alliance = false
	r.overlord = ""
	change_opinion(target_id, faction_id, GameData.rule("war_declared_opinion"), "declared_war")
	if faction_id == player_id:
		event.emit("You declared war on the %s. Assault their border districts to take them." % faction_name(target_id), "alert")
	elif target_id == player_id:
		event.emit("WAR! The %s have declared war on you. Expect assaults on your border districts." % faction_name(faction_id), "alert")
		major_event.emit("War", "The %s have declared war on you. Expect raids and assaults on your border districts. Reinforce the districts they border, and look for allies or a peace deal in Diplomacy." % faction_name(faction_id), faction_id)
	else:
		event.emit("The %s have declared war on the %s." % [faction_name(faction_id), faction_name(target_id)], "info")

func _join_war(joiner_id: String, enemy_id: String, friend_id: String):
	if joiner_id == enemy_id or is_at_war(joiner_id, enemy_id) or relation(joiner_id, enemy_id).protected():
		return
	var r = relation(joiner_id, enemy_id)
	r.at_war = true
	r.war_start_day = day
	r.peace_offered_by = ""
	r.exhaustion = {r.a: 0.0, r.b: 0.0}
	r.trade = false
	var text = "The %s join the war on the side of the %s against the %s." % [faction_name(joiner_id), faction_name(friend_id), faction_name(enemy_id)]
	if joiner_id == player_id:
		text = "Your treaty with the %s draws you into their war against the %s." % [faction_name(friend_id), faction_name(enemy_id)]
	event.emit(text, "alert" if joiner_id == player_id or enemy_id == player_id or friend_id == player_id else "info")

# The side asking for peace gets it if the other side is more exhausted, or has an offer pending
func check_peace(faction_id: String, target_id: String) -> String:
	var r = relation(faction_id, target_id)
	if not r.at_war:
		return "Not at war"
	if r.peace_offered_by == target_id:
		return ""
	if day - r.war_start_day < int(GameData.rule("min_war_days_for_peace")):
		return "Too early: the war is only %d days old" % (day - r.war_start_day)
	if r.exhaustion[target_id] < r.exhaustion[faction_id] and r.exhaustion[target_id] < 40.0:
		return "They refuse: their war exhaustion (%d) is lower than yours (%d)" % [r.exhaustion[target_id], r.exhaustion[faction_id]]
	return ""

func make_peace(faction_id: String, target_id: String) -> String:
	var err = check_peace(faction_id, target_id)
	if err != "":
		return err
	var r = relation(faction_id, target_id)
	var truce_days = int(GameData.rule("truce_days"))
	# The less exhausted side is counted as the winner of a war that lasted
	if day - r.war_start_day >= 30 and r.exhaustion[r.a] != r.exhaustion[r.b]:
		var winner = r.a if r.exhaustion[r.a] < r.exhaustion[r.b] else r.b
		factions[winner].stats["wars_won"] += 1
	r.at_war = false
	r.peace_offered_by = ""
	r.truce_until_day = day + truce_days
	if r.involves(player_id):
		event.emit("Peace with the %s. A truce holds for %d days; borders stay where they are." % [
			faction_name(r.other(player_id)), truce_days], "alert")
	else:
		event.emit("The %s and the %s have made peace." % [faction_name(faction_id), faction_name(target_id)], "info")
	return ""

func offer_peace(faction_id: String, target_id: String):
	var r = relation(faction_id, target_id)
	if not r.at_war or r.peace_offered_by == faction_id:
		return
	r.peace_offered_by = faction_id
	if target_id == player_id:
		event.emit("The %s offer peace. Accept it in Diplomacy (F4), or fight on." % faction_name(faction_id), "alert")

func announce_war_plan(faction_id: String, target_id: String, days: int):
	if target_id == player_id:
		event.emit("The %s are massing on your border. War is likely within %d days." % [faction_name(faction_id), days], "alert")
	else:
		event.emit("The %s are massing on the border of the %s." % [faction_name(faction_id), faction_name(target_id)], "info")

func feed_trait_by_name(f: Faction, trait_name: String, amount: float):
	if f.traits.add_faction_trait_value(trait_name, amount) == 1:
		_announce_trait(f, trait_name)

func _simulate_relations():
	var daily_exhaustion: float = GameData.rule("war_daily_exhaustion")
	var drift: float = GameData.rule("opinion_daily_drift")
	for r in relations.values():
		for fid in [r.a, r.b]:
			# The baseline follows changes in who they are and what binds them gradually;
			# memories fade at their own pace
			var target = Diplomacy.baseline_value(Diplomacy.opinion_baseline(self, fid, r.other(fid)))
			r.baseline[fid] = move_toward(r.baseline[fid], target, drift)
			var memories: Array = r.modifiers[fid]
			for m in memories.duplicate():
				m["value"] = move_toward(m["value"], 0.0, GameData.opinion_modifier(m["id"])["decay"])
				if absf(m["value"]) < 0.5:
					memories.erase(m)
			r.recompute_opinion(fid)
			if r.at_war:
				r.exhaustion[fid] = minf(100.0, r.exhaustion[fid] + daily_exhaustion)
		# Warn both sides a month before a pact or alliance lapses
		var warning = int(GameData.rule("treaty_warning_days"))
		if (r.pact or r.alliance) and r.overlord == "" and not r.lapse_warned and r.treaty_until_day - day <= warning:
			r.lapse_warned = true
			if r.involves(player_id):
				event.emit("Your %s with the %s lapses in %d days. Renew it from their diplomacy panel." % [
					"alliance" if r.alliance else "non-aggression pact", faction_name(r.other(player_id)), r.treaty_until_day - day], "alert")
		# Pacts and alliances lapse unless renewed
		if (r.pact or r.alliance) and r.overlord == "" and day >= r.treaty_until_day:
			var kind = "alliance" if r.alliance else "non-aggression pact"
			r.pact = false
			r.alliance = false
			event.emit("The %s between the %s and the %s has lapsed. It can be renewed." % [kind, faction_name(r.a), faction_name(r.b)],
				"alert" if r.involves(player_id) else "info")
		# Trade agreements pay both sides every day
		if r.trade:
			for fid in [r.a, r.b]:
				factions[fid].wealth += Diplomacy.trade_income(self, fid, r.other(fid))
	# Everyone's people suffer while their faction is at war
	for d in districts:
		var owner = d.owner_id()
		if owner != "" and at_war_with_anyone(owner):
			d.grievance = minf(100.0, d.grievance + 0.05)

# Removes a faction from the game. With into_id, it merges: its land, crew and stores pass to that faction.
func retire_faction(faction_id: String, into_id: String = ""):
	var f: Faction = factions.get(faction_id)
	if f == null:
		return
	var into: Faction = factions.get(into_id)
	for d in districts:
		if d.influence.has(faction_id):
			var share: float = d.influence[faction_id]
			d.influence.erase(faction_id)
			if into:
				d.add_influence(into_id, share)
	for v in ventures.duplicate():
		if v.faction_id == faction_id:
			ventures.erase(v)
			if into:
				into.manpower += v.crew
		elif v.target_id == faction_id:
			ventures.erase(v)
			factions[v.faction_id].manpower += v.crew
	for c in constructions.duplicate():
		if c.faction_id == faction_id:
			constructions.erase(c)
	# Captains join the faction that absorbs theirs, or scatter with it
	for ch in characters.duplicate():
		if ch.faction_id == faction_id:
			if into and ch.is_adult():
				ch.faction_id = into_id
				ch.post = ""
				ch.is_leader = false
				ch.family = false
			else:
				characters.erase(ch)
	# The absorbing faction keeps its best people, up to its captain limit; the rest drift away
	if into:
		var hired = characters_of(into_id).filter(func(c): return not c.family)
		hired.sort_custom(func(a, b): return a.best_skill_value() > b.best_skill_value())
		for k in range(captain_cap(into_id), hired.size()):
			if not leader_busy(hired[k]) and hired[k].post == "":
				_record_departure(hired[k], "left after the %s were absorbed" % f.display_name)
				characters.erase(hired[k])
	for m in missions.duplicate():
		if m.from_id == faction_id or m.to_id == faction_id:
			missions.erase(m)
	proposals = proposals.filter(func(p): return p["from"] != faction_id)
	if into:
		into.manpower += f.manpower
		into.supplies += f.supplies
		into.wealth += f.wealth
	for key in relations.keys():
		if relations[key].involves(faction_id):
			relations.erase(key)
	factions.erase(faction_id)
	factions_changed.emit()

# Factions with no land left scatter; the player is told the game is lost
func _check_eliminations():
	for fid in factions.keys():
		if districts_held(fid) > 0:
			continue
		if fid == player_id:
			if not player_defeated:
				player_defeated = true
				event.emit("Your crew has lost its last district. The game is lost, but you can keep watching or load a save.", "alert")
		else:
			event.emit("The %s have lost their last district and scattered." % faction_name(fid), "alert")
			retire_faction(fid)

# --- Ventures -----------------------------------------------------------------

# The faction a venture in this district would be aimed at ("" if it isn't aimed at anyone)
func venture_target(faction_id: String, venture_id: String, district: District) -> String:
	match GameData.venture(venture_id)["target"]:
		"market":
			return district.owner_id() if district.owner_id() != faction_id else ""
		"enemy_border":
			var owner = district.owner_id()
			return owner if owner != faction_id else ""
		"war_border":
			# The enemy with the biggest hold here
			var best = ""
			var best_share = 0.0
			for enemy_id in war_enemies(faction_id):
				if district.share(enemy_id) >= 20.0 and district.share(enemy_id) > best_share:
					best = enemy_id
					best_share = district.share(enemy_id)
			return best
	return ""

# What launching a venture costs, including any extra funding
func venture_cost(venture_id: String, funding: int) -> Dictionary:
	var def = GameData.venture(venture_id)
	var cost: Dictionary = def["cost"].duplicate()
	if funding > 0:
		cost["wealth"] = cost.get("wealth", 0.0) + def["funding_cost"] * funding
	return cost

# Days a venture takes: a skilled leader gets it done faster
# Days a venture takes: a skilled leader is quicker; attacks on a well-defended district take longer
func venture_days(venture_id: String, leader: Character, district: District = null) -> int:
	var def = GameData.venture(venture_id)
	var days = int(def["days"])
	if leader:
		days -= maxi(0, int(leader.skills[def["skill"]]) - int(GameData.rule("skill_neutral"))) / 2
	if district and def.get("hostile", false) and district.owner_id() != "":
		days += int(ceil(days * (1.0 - defence_total(district)) * 0.8))
	return maxi(3, days)

# --- Defence ---------------------------------------------------------------------------

# How much the owner's control shields a district: 1.0 at a bare claim (50), 0.65 at full control
func control_defence(d: District) -> float:
	var owner = d.owner_id()
	if owner == "":
		return 1.0
	return 1.0 - clampf((d.share(owner) - 50.0) / 50.0, 0.0, 1.0) * 0.35

# Crew the owner has in a district right now: Reinforce ventures count fully, other work there by half
func defenders_at(faction_id: String, d: District) -> int:
	var guards = 0.0
	for v in ventures:
		if v.faction_id == faction_id and v.district == d:
			guards += v.crew if v.venture_id == "reinforce" else v.crew * 0.5
	return int(guards)

func guard_defence(guards: int) -> float:
	return maxf(0.45, 1.0 - guards * 0.06)

# Everything that makes attacks on a district harder, as [[label, multiplier], ...] (for the owner)
func defence_factors(d: District) -> Array:
	var owner = d.owner_id()
	var factors = []
	if owner == "":
		return factors
	var f: Faction = factions[owner]
	if control_defence(d) < 0.999:
		factors.append(["Control %d" % d.share(owner), control_defence(d)])
	if buildings_active(d):
		for building_id in d.buildings:
			var effects = GameData.building(building_id)["effects"]
			if effects.has("defence_mult"):
				factors.append([GameData.building(building_id)["label"], effects["defence_mult"]])
	if f.arms >= 1.0:
		factors.append(["%d arms" % f.arms, 1.0 - minf(f.arms, GameData.rule("arms_effect_cap")) * GameData.rule("arms_defence_step")])
	var guards = defenders_at(owner, d)
	if guards > 0:
		factors.append(["%d defenders on guard" % guards, guard_defence(guards)])
	return factors

func defence_total(d: District) -> float:
	var total = 1.0
	for factor in defence_factors(d):
		total *= factor[1]
	return total

# Hostile ventures under way against a faction's districts
func incoming_attacks(faction_id: String) -> Array:
	return ventures.filter(func(v): return v.target_id == faction_id and GameData.venture(v.venture_id).get("hostile", false))

# Whether a district of yours is under threat: attacked right now, or bordering an enemy at war or raiders
func district_threatened(faction_id: String, d: District) -> bool:
	for v in incoming_attacks(faction_id):
		if v.district == d:
			return true
	for n_id in d.neighbor_ids:
		var other = districts[n_id].owner_id()
		if other != "" and other != faction_id:
			if is_at_war(faction_id, other) or factions[other].personality == "raider":
				return true
	return false

# Returns "" if the venture can be launched, otherwise the reason it can't.
# leader_id -2 means "any available leader" (the best one is picked at launch); crew -1 means the usual crew.
func check_launch(faction_id: String, venture_id: String, district: District, leader_id: int = -2, crew: int = -1, funding: int = 0) -> String:
	var f: Faction = factions[faction_id]
	var def = GameData.venture(venture_id)
	var owner = district.owner_id()
	match def["target"]:
		"unclaimed_border":
			if owner == faction_id:
				return "Already yours: %s only works on unclaimed land" % def["label"]
			if owner != "":
				return "Held by the %s: raid it, agitate it, or declare war and assault it" % faction_name(owner)
			if not borders_territory(faction_id, district):
				return "Not on your border: expand outward from land you own"
		"market":
			if owner == "" or owner == faction_id:
				return "Trade happens at another faction's market: pick a district they hold"
			if is_at_war(faction_id, owner):
				return "You're at war with the %s" % faction_name(owner)
			if not borders_territory(faction_id, district) and not relation(faction_id, owner).trade:
				return "Too far: trade next door, or anywhere the %s hold once you have a trade agreement" % faction_name(owner)
		"scout":
			if owner == faction_id:
				return "Already yours: you know this district"
			if owner != "":
				return "Held by the %s: scouting is for unclaimed land (trade, raid, assault or talk to them instead)" % faction_name(owner)
			if knows(faction_id, district):
				return "Already scouted"
			if not can_scout_from(faction_id, district):
				return "Too far: scout next to your land or next to a district you've scouted"
		"scavenge":
			if owner != faction_id and owner != "":
				return "Held by the %s: you can only scavenge your own land or unclaimed ruins" % faction_name(owner)
			if owner == "" and not borders_territory(faction_id, district):
				return "Not on your border: scavenge your own land or unclaimed ruins next to it"
			if district.ruin_level < 0.1:
				return "Nothing left to salvage: the ruins here are stripped bare"
		"enemy_border":
			if owner == "" or owner == faction_id:
				return "Only districts held by another faction can be targeted"
			if relation(faction_id, owner).protected():
				return "You have a treaty with the %s (break it first)" % faction_name(owner)
			if not borders_territory(faction_id, district):
				return "Not on your border"
		"war_border":
			if not at_war_with_anyone(faction_id):
				return "Declare war first (Diplomacy, F4)"
			if venture_target(faction_id, venture_id, district) == "":
				return "No faction you're at war with has a real hold here"
			if not borders_territory(faction_id, district):
				return "Not on your border"
		"own":
			if owner != faction_id:
				return "Only in districts you control"
			match def.get("needs", ""):
				"food":
					if district.food_yield >= GameData.rule("food_source_cap") - 0.001:
						return "Every food source here is already worked (build Allotments for more)"
				"control":
					if district.share(faction_id) >= 95.0:
						return "Already fully under your control"
				"threat":
					if not district_threatened(faction_id, district):
						return "No threat here: reinforce a district that's under attack, or borders an enemy or raiders"
				"development":
					if district.development >= 0.99:
						return "Fully rebuilt"
				"arms":
					if f.arms >= GameData.rule("arms_cap"):
						return "Your armoury is full (%d arms)" % GameData.rule("arms_cap")
	for v in ventures:
		if v.faction_id == faction_id and v.venture_id == venture_id and v.district == district:
			return "Already under way here"
	if def.get("needs_scouted", false) and not knows(faction_id, district):
		return "Scout it first: you don't know what's in there"
	if district.grievance < def.get("min_grievance", 0.0):
		return "The district is already calm"
	if leader_id == -2:
		if available_leaders(faction_id).is_empty():
			return leader_availability(faction_id)
	else:
		var leader = character_by_id(leader_id)
		if leader == null or leader.faction_id != faction_id:
			return "Choose a captain to lead it"
		if leader.is_wounded(day):
			return "%s is recovering from wounds" % leader.name
		if leader_busy(leader):
			return "%s is already out on a venture" % leader.name
	var size = int(def["crew"]) if crew < 0 else crew
	if size < int(def["crew_range"][0]) or size > int(def["crew_range"][1]):
		return "Crew must be %d-%d" % [def["crew_range"][0], def["crew_range"][1]]
	if int(f.manpower) < size:
		return "Need %d idle manpower (have %d). Manpower grows from the food your districts produce" % [size, f.manpower]
	var short = f.shortfall(venture_cost(venture_id, funding))
	if short != "":
		return short + (" (or pick less extra funding)" if funding > 0 and f.can_afford(venture_cost(venture_id, 0)) else "")
	return ""

func launch_venture(faction_id: String, venture_id: String, district: District, leader_id: int = -2, crew: int = -1, funding: int = 0) -> String:
	var err = check_launch(faction_id, venture_id, district, leader_id, crew, funding)
	if err != "":
		return err
	var f: Faction = factions[faction_id]
	var def = GameData.venture(venture_id)
	var leader = best_leader(faction_id, def["skill"]) if leader_id == -2 else character_by_id(leader_id)
	var size = int(def["crew"]) if crew < 0 else crew
	var target_id = venture_target(faction_id, venture_id, district)
	f.pay(venture_cost(venture_id, funding))
	f.manpower -= size
	var v = ActiveVenture.new(venture_id, faction_id, target_id, district, size, venture_days(venture_id, leader, district))
	v.leader_id = leader.id
	v.funding = funding
	ventures.append(v)
	_feed_trait(f, venture_id, 2.0)
	# Raiding or stirring up a trade partner ends the deal
	if def.get("hostile", false) and target_id != "" and relation(faction_id, target_id).trade:
		relation(faction_id, target_id).trade = false
		change_opinion(target_id, faction_id, -15.0, "betrayed_trade")
		event.emit("The trade agreement between the %s and the %s collapsed over the %s." % [
			faction_name(faction_id), faction_name(target_id), def["label"].to_lower()], "alert" if target_id == player_id or faction_id == player_id else "info")

	var tiers = VentureSystem.compute_odds(venture_id, f, district, self, target_id, leader, size, funding)["tiers"]
	var odds_text = "%d%% success, %d%% disaster" % [(tiers["triumph"] + tiers["success"]) * 100, tiers["disaster"] * 100]
	if faction_id == player_id:
		event.emit("%s leads %d crew on a %s in %s: back in %d days (%s)." % [leader.name, size, def["label"], district.district_name, v.days_total, odds_text], "info")
	else:
		var hostile: bool = def.get("hostile", false)
		var text = "%s launched %s %s %s, led by %s: lands in %d days (%s)" % [
			f.display_name, def["label"], "against" if hostile else "in", district.district_name, leader.name, v.days_total, odds_text
		]
		event.emit(text, "alert" if hostile and target_id == player_id else "info")
	return ""

const TIER_LABELS = {"triumph": "TRIUMPH", "success": "success", "setback": "setback", "disaster": "DISASTER"}

func _resolve(v: ActiveVenture):
	var f: Faction = factions.get(v.faction_id)
	if f == null:
		return
	var def = GameData.venture(v.venture_id)
	var d = v.district
	var leader = character_by_id(v.leader_id)

	# The situation may have changed while the crew was out (e.g. peace was signed)
	if def["target"] == "war_border" and not is_at_war(f.id, v.target_id):
		f.manpower += v.crew
		event.emit("%s: %s on %s called off, the war is over." % [f.display_name, def["label"], d.district_name], "info")
		return
	# Peaceful work aimed at unclaimed or your own land stops if someone else has since taken it: once land is
	# claimed, others can only trade there, raid or assault it
	var now_owner = d.owner_id()
	if not def.get("hostile", false) and def["target"] != "market" and now_owner != "" and now_owner != f.id:
		f.manpower += v.crew
		var note = "%s: %s in %s called off, the %s hold it now." % [f.display_name, def["label"], d.district_name, faction_name(now_owner)]
		event.emit(note, "bad" if f.id == player_id else "info")
		return

	var owner_before = d.owner_id()
	var chances = VentureSystem.compute_odds(v.venture_id, f, d, self, v.target_id, leader, v.crew, v.funding)
	var tier = VentureSystem.roll_tier(chances["tiers"], rng)
	var success = tier == "triumph" or tier == "success"
	var effects: Array = (def["success_effects"] if success else def["failure_effects"]).duplicate()
	if tier == "triumph":
		effects.append_array(def.get("triumph_effects", []))
	elif tier == "disaster":
		effects.append_array(def.get("disaster_effects", []))
	var result = VentureSystem.apply_effects(effects, f, v.target_id, d, self, v.crew)
	# Attackers who fail against a guarded district are driven off with extra losses
	if def.get("hostile", false) and not success and v.target_id != "" and defenders_at(v.target_id, d) >= 2:
		var driven_off = mini(rng.randi_range(1, 3), v.crew - result["lost"])
		result["lost"] += driven_off
		result["notes"].append("driven off by %d defenders (%d more lost)" % [defenders_at(v.target_id, d), driven_off])
	var lost = mini(result["lost"], v.crew)
	# Settlers stay for good and become the district's people: expansion costs people
	var settlers = 0
	if def.get("settlers", false) and success:
		settlers = v.crew - lost
		d.population += settlers * GameData.rule("settler_population")
	f.manpower += v.crew - lost - settlers
	if success:
		_feed_trait(f, v.venture_id, 6.0 if tier == "triumph" else 4.0)
	if tier == "triumph":
		f.renown += 2.0

	var log_key = {"triumph": "triumph_log", "success": "success_log", "setback": "failure_log", "disaster": "disaster_log"}[tier]
	var detail: String = def.get(log_key, def["success_log"] if success else def["failure_log"]).format(result["values"])
	for note in result["notes"]:
		detail += ", " + note
	var led_by = " led by %s" % leader.name if leader else ""
	var text = "%s: %s in %s%s: %s, %s" % [f.display_name, def["label"], d.district_name, led_by, TIER_LABELS[tier], detail]
	if lost > 0:
		text += ", %d crew lost" % lost
	if settlers > 0:
		text += ", %d settle there for good" % settlers
	var fate = _leader_outcome(leader, tier, def)
	if fate != "":
		text += ". " + fate
	var kind = "info"
	if f.id == player_id:
		kind = "good" if success else ("alert" if fate.contains("killed") else "bad")
	elif v.target_id == player_id and def.get("hostile", false):
		kind = "bad" if success else "good"
	event.emit(text, kind)
	if def["target"] == "war_border" and owner_before != f.id and d.owner_id() == f.id:
		f.stats["districts_conquered"] += 1
	_announce_ownership_change(d, owner_before, f.id)

# What happens to the leader: skill grows with triumphs, setbacks can wound, disasters can kill.
# Returns a sentence for the log ("" if nothing notable).
func _leader_outcome(leader: Character, tier: String, def: Dictionary) -> String:
	if leader == null:
		return ""
	leader.ventures_led += 1
	var skill: String = def["skill"]
	var notes = []
	match tier:
		"triumph":
			leader.triumphs += 1
			leader.change_loyalty(8.0, "glory")
			if leader.has_trait("shaken"):
				leader.traits.erase("shaken")
				notes.append("%s has shaken off the last disaster" % leader.name)
			if leader.skills[skill] < 10 and rng.randf() < 0.5:
				leader.skills[skill] += 1
				notes.append("%s's %s rose to %d" % [leader.name, skill.capitalize(), leader.skills[skill]])
		"success":
			if leader.skills[skill] < 10 and rng.randf() < 0.12:
				leader.skills[skill] += 1
				notes.append("%s's %s rose to %d" % [leader.name, skill.capitalize(), leader.skills[skill]])
		"setback":
			if rng.randf() < GameData.rule("setback_wound_chance"):
				notes.append(_wound(leader))
		"disaster":
			var roll = rng.randf()
			if roll < GameData.rule("disaster_death_chance"):
				_character_died(leader, "killed leading a %s" % def["label"])
				return "%s was killed" % leader.name
			if roll < GameData.rule("disaster_death_chance") + GameData.rule("disaster_wound_chance"):
				notes.append(_wound(leader))
			_earn_trait(leader, "shaken", notes)
	if leader.ventures_led >= int(GameData.rule("veteran_ventures")):
		_earn_trait(leader, "veteran", notes)
	if leader.triumphs >= int(GameData.rule("hero_triumphs")):
		_earn_trait(leader, "hero", notes)
	return ". ".join(notes)

func _wound(leader: Character) -> String:
	var days_range: Array = GameData.rule("wound_days")
	var days = rng.randi_range(int(days_range[0]), int(days_range[1]))
	leader.wounded_until = day + days
	leader.wounds += 1
	leader.change_loyalty(-6.0, "wounded_in_service")
	var text = "%s was wounded (out for %d days)" % [leader.name, days]
	var notes = []
	_earn_trait(leader, "scarred", notes)
	return text if notes.is_empty() else text + ". " + notes[0]

func _earn_trait(c: Character, trait_id: String, notes: Array):
	if c.has_trait(trait_id):
		return
	c.traits.append(trait_id)
	notes.append("%s is now %s" % [c.name, GameData.character_trait(trait_id)["label"]])

func _record_departure(c: Character, fate: String):
	departed.append({"name": c.name, "faction": c.faction_id, "post": c.post, "fate": fate, "day": day,
		"ventures": c.ventures_led, "triumphs": c.triumphs, "role": "Leader" if c.is_leader else ("Family" if c.family else ""),
		"ruled_days": day - c.ruling_since if c.is_leader else 0})

# Why nobody can lead right now: who's away and when they're back, e.g.
# "No captain is free: Yara Moreau back in 6 days (Settle), Rafe Duval wounded for 20 days"
func leader_availability(faction_id: String) -> String:
	var parts = []
	for c in characters_of(faction_id):
		if c.is_wounded(day):
			parts.append("%s wounded for %d days" % [c.name, c.wounded_until - day])
		else:
			for v in ventures:
				if v.leader_id == c.id:
					parts.append("%s back in %d days (%s)" % [c.name, v.days_left, GameData.venture(v.venture_id)["label"]])
	if characters_of(faction_id).is_empty():
		return "You have no captains left. New ones join over time while you're under your limit (%d)" % captain_cap(faction_id)
	return "No captain is free: " + ", ".join(parts)

# Removes a character who died; their comrades take it hard and any council seat falls empty
func _character_died(c: Character, fate: String):
	var was_leader = c.is_leader
	_record_departure(c, fate)
	characters.erase(c)
	c.death_day = day
	c.fate = fate
	if c.family or was_leader:
		graveyard.append(c)
	for other in characters_of(c.faction_id):
		other.change_loyalty(-4.0, "comrade_lost")
	if c.post != "" and c.faction_id == player_id:
		event.emit("Your %s seat is empty now that %s is dead. Appoint someone in the Council window (F2)." % [
			GameData.council_post(c.post)["label"], c.name], "alert")
	if was_leader:
		_succession(c.faction_id, c, fate)

# --- Council ----------------------------------------------------------------------------

func council_member(faction_id: String, post: String) -> Character:
	for c in characters:
		if c.faction_id == faction_id and c.post == post:
			return c
	return null

# The council seat covering a skill boosts every venture that uses it: [label, multiplier], or [] if empty
func council_factor(faction_id: String, skill: String) -> Array:
	for post in GameData.council()["posts"]:
		if GameData.council_post(post)["skill"] == skill:
			var c = council_member(faction_id, post)
			if c:
				return ["%s %s (%s %d)" % [GameData.council_post(post)["label"], c.name, skill.capitalize(), c.skills[skill]],
					1.0 + (c.skills[skill] - GameData.rule("skill_neutral")) * GameData.rule("council_skill_step")]
	return []

# The captain without a seat who is best at a post's skill (null if none)
func best_candidate(faction_id: String, post: String) -> Character:
	var skill: String = GameData.council_post(post)["skill"]
	var best: Character = null
	for c in characters_of(faction_id):
		if c.post == "" and (best == null or c.skills[skill] > best.skills[skill]):
			best = c
	return best

func council_size(faction_id: String) -> int:
	return characters_of(faction_id).filter(func(c): return c.post != "").size()

# Seats a character on the council. Anyone better suited who was passed over resents it.
func appoint(character_id: int, post: String) -> String:
	var c = character_by_id(character_id)
	if c == null:
		return "No such character"
	if c.post == post:
		return "%s already holds that seat" % c.name
	var skill: String = GameData.council_post(post)["skill"]
	var current = council_member(c.faction_id, post)
	if current:
		_unseat(current)
	var moved_from = c.post
	c.post = post
	if moved_from != "" and c.faction_id == player_id:
		event.emit("%s moves from %s to %s: the %s seat is now empty." % [c.name, GameData.council_post(moved_from)["label"],
			GameData.council_post(post)["label"], GameData.council_post(moved_from)["label"]], "alert")
	c.change_loyalty(12.0, "appointed")
	for other in characters_of(c.faction_id):
		if other != c and other.post == "" and other.skills[skill] > c.skills[skill]:
			other.change_loyalty(-10.0, "passed_over")
	if c.faction_id == player_id:
		event.emit("%s is your new %s." % [c.name, GameData.council_post(post)["label"]], "good")
	return ""

func remove_from_council(character_id: int) -> String:
	var c = character_by_id(character_id)
	if c == null or c.post == "":
		return "Not on the council"
	_unseat(c)
	return ""

func _unseat(c: Character):
	c.change_loyalty(-15.0, "dismissed")
	if c.faction_id == player_id:
		event.emit("%s no longer sits on your council as %s." % [c.name, GameData.council_post(c.post)["label"]], "info")
	c.post = ""

# Sends a character away for good; the rest of the crew notices
func dismiss_character(character_id: int) -> String:
	var c = character_by_id(character_id)
	if c == null:
		return "No such character"
	if leader_busy(c):
		return "%s is out on a venture" % c.name
	_record_departure(c, "dismissed")
	characters.erase(c)
	for other in characters_of(c.faction_id):
		other.change_loyalty(-3.0, "comrade_dismissed")
	if c.faction_id == player_id:
		event.emit("%s has been sent away from your crew." % c.name, "info")
	return ""

# AI: fill empty seats with the best candidate, and swap in someone much better
func ai_manage_council(faction_id: String):
	for post in GameData.council()["posts"]:
		var skill: String = GameData.council_post(post)["skill"]
		var current = council_member(faction_id, post)
		var best = best_candidate(faction_id, post)
		if best == null:
			continue
		if current == null:
			# Only take on a wage the treasury can carry
			var e = daily_economy(faction_id)["wealth"]
			if e["income"] - e["upkeep"] < council_wage(faction_id) * 1.5:
				continue
			appoint(best.id, post)
		elif best.skills[skill] >= current.skills[skill] + 3:
			appoint(best.id, post)

# Daily: memories fade; an unpaid council grumbles. Monthly: restless crew may defect.
func _update_loyalty():
	for c in characters:
		c.decay_loyalty()
		if c.post != "" and factions[c.faction_id].broke:
			c.change_loyalty(-0.5, "unpaid")
	if day % 30 != 15:
		return
	for c in characters.duplicate():
		if c.is_leader or not c.is_adult():
			continue
		var loyalty = c.loyalty()
		if loyalty < GameData.rule("loyalty_restless"):
			if not c.restless_warned and c.faction_id == player_id:
				c.restless_warned = true
				event.emit("%s is restless (loyalty %d). Below %d they may leave for a rival. See the Council window (F2) for why." % [
					c.name, loyalty, GameData.rule("loyalty_defect")], "alert")
		else:
			c.restless_warned = false
		if loyalty < GameData.rule("loyalty_defect") and rng.randf() < GameData.rule("defect_chance"):
			_defect(c)

# A disloyal character leaves, joining the rival that thinks worst of their old faction
func _defect(c: Character):
	var old_id = c.faction_id
	var target = ""
	var worst = 1000.0
	for fid in factions:
		if fid != old_id and captain_count(fid) < captain_cap(fid) and opinion_of(fid, old_id) < worst:
			worst = opinion_of(fid, old_id)
			target = fid
	var seat = GameData.council_post(c.post)["label"] if c.post != "" else ""
	_record_departure(c, "deserted to the %s" % faction_name(target) if target != "" else "deserted and left the city")
	c.post = ""
	c.loyalty_mods.clear()
	c.restless_warned = false
	if target == "":
		characters.erase(c)
	else:
		c.faction_id = target
	var where = "joined the %s" % faction_name(target) if target != "" else "left the city"
	if old_id == player_id:
		event.emit("%s%s deserted you and %s." % [c.name, ", your %s," % seat if seat != "" else "", where], "alert")
	elif target == player_id:
		event.emit("%s deserted the %s and joined your crew." % [c.name, faction_name(old_id)], "good")
	else:
		event.emit("%s deserted the %s and %s." % [c.name, faction_name(old_id), where], "info")

# --- Leaders, families and succession (spine S3: the arc) ------------------------------

const SPLIT_NAMES = ["Breakaways", "Loyalists", "Free Crew", "Rebels", "Faithful"]

func _new_person(faction_id: String, surname: String, age: int, sex: String) -> Character:
	var names = GameData.names()
	var taken = everyone_of(faction_id).map(func(c): return c.name)
	var name = ""
	for attempt in 20:
		name = "%s %s" % [_first_name(sex), surname]
		if name not in taken:
			break
	var c = Character.new(next_character_id, faction_id, name, age)
	next_character_id += 1
	c.sex = sex
	c.dynasty = surname
	for s in Character.SKILLS:
		c.skills[s] = rng.randi_range(1, 4)
	_give_personality(c)
	characters.append(c)
	return c

# Personality from birth: at most one side of each opposite pair, one or two traits in all
const PERSONALITY_PAIRS = [["ambitious", "steadfast"], ["brave", "craven"], ["cruel", "kind"], ["greedy", "generous"]]

func _give_personality(c: Character):
	var pairs = PERSONALITY_PAIRS.duplicate()
	# Shuffle with the game's own dice, so saved games replay identically
	for i in range(pairs.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var swap = pairs[i]
		pairs[i] = pairs[j]
		pairs[j] = swap
	var wanted = 1 if rng.randf() < 0.6 else 2
	for pair in pairs:
		if wanted <= 0:
			break
		if pair[0] in c.traits or pair[1] in c.traits:
			continue
		if rng.randf() < 0.55:
			c.traits.append(pair[rng.randi() % 2])
			wanted -= 1

func _has_opposite(c: Character, trait_id: String) -> bool:
	var opposite: String = GameData.character_trait(trait_id).get("opposite", "")
	return opposite != "" and opposite in c.traits

# Takes power: remembers the faction's deeds so ruling traits can be earned from what happens next
func _crown(c: Character):
	c.is_leader = true
	c.post = ""
	c.ruling_since = day
	c.peace_days = 0
	var f: Faction = factions[c.faction_id]
	c.rule_start = {"districts_conquered": f.stats["districts_conquered"], "buildings_built": f.stats.get("buildings_built", 0)}
	f.designated_heir = -1

# A spouse for someone in the ruling family, from the faction's own people
func _marry(c: Character) -> Character:
	var spouse = _new_person(c.faction_id, c.dynasty, clampi(c.age + rng.randi_range(-6, 4), 18, 70), "f" if c.sex == "m" else "m")
	spouse.family = true
	spouse.skills[Character.SKILLS[rng.randi() % Character.SKILLS.size()]] = rng.randi_range(4, 7)
	spouse.spouse_id = c.id
	c.spouse_id = spouse.id
	return spouse

# A leader, a spouse, and a few children: the faction's first dynasty
func _found_dynasty(faction_id: String):
	var names = GameData.names()
	var surname: String = names["last"][rng.randi() % names["last"].size()]
	var leader = _new_person(faction_id, surname, rng.randi_range(28, 50), "m" if rng.randf() < 0.6 else "f")
	leader.family = true
	_crown(leader)
	var best = Character.SKILLS[rng.randi() % Character.SKILLS.size()]
	for s in Character.SKILLS:
		leader.skills[s] = rng.randi_range(2, 5)
	leader.skills[best] = rng.randi_range(6, 9)
	_marry(leader)
	var children = rng.randi_range(0, 3) if leader.age >= 30 else rng.randi_range(0, 1)
	if factions[faction_id].minor:
		children = mini(children, 1)
	for k in children:
		var child = _new_child(leader, clampi(rng.randi_range(0, leader.age - 18), 0, 22))
		if child.is_adult():
			_grow_up(child)

func _new_child(parent: Character, age: int) -> Character:
	var child = _new_person(parent.faction_id, parent.dynasty, age, "m" if rng.randf() < 0.5 else "f")
	child.family = true
	child.parent_ids = [parent.id]
	if parent.spouse_id >= 0:
		child.parent_ids.append(parent.spouse_id)
	for s in Character.SKILLS:
		child.skills[s] = 0
	return child

# Coming of age: some of each parent's strength, and a little of their nature
func _grow_up(c: Character):
	for s in Character.SKILLS:
		c.skills[s] = rng.randi_range(1, 3)
	for parent_id in c.parent_ids:
		var parent = character_by_id(parent_id)
		if parent == null:
			continue
		var s = parent.best_skill()
		c.skills[s] = maxi(c.skills[s], rng.randi_range(4, 6) + (1 if parent.is_leader else 0))
		for t in parent.traits:
			if GameData.character_trait(t)["kind"] == "personality" and t not in c.traits and not _has_opposite(c, t) and rng.randf() < 0.3:
				c.traits.append(t)

# Chance a character dies in a given month: leaders carry the strain of rule; age weighs on everyone
func monthly_death_chance(c: Character) -> float:
	if not c.is_adult():
		return GameData.rule("child_death_chance")
	var base: float = GameData.rule("leader_death_chance") if c.is_leader else GameData.rule("adult_death_chance")
	return base + GameData.rule("age_death_chance") * maxf(c.age - 50, 0)

func yearly_death_chance(c: Character) -> float:
	return 1.0 - pow(1.0 - monthly_death_chance(c), 12)

# Births, deaths, birthdays and respect for the leader
func _life_cycle():
	if day % 360 == 0:
		for c in characters:
			c.age += 1
			if c.family and c.age == 16:
				_grow_up(c)
				if c.faction_id == player_id:
					var best = c.best_skill()
					event.emit("%s comes of age and joins your crew (%s %d)." % [c.name, best.capitalize(), c.skills[best]], "good")
	if day % 30 != 20:
		return
	for c in characters.duplicate():
		if not characters.has(c):
			continue
		if rng.randf() < monthly_death_chance(c):
			_character_died(c, "died of old age" if c.age >= 65 else "died of illness")
	for leader in characters.duplicate():
		if not leader.is_leader or leader.spouse_id < 0 or leader.age >= 55:
			continue
		var spouse = character_by_id(leader.spouse_id)
		if spouse == null or spouse.faction_id != leader.faction_id or spouse.age >= 45:
			continue
		var kids = everyone_of(leader.faction_id).filter(func(c): return leader.id in c.parent_ids)
		if kids.size() < 5 and rng.randf() < GameData.rule("birth_chance"):
			var child = _new_child(leader, 0)
			if leader.faction_id == player_id:
				event.emit("%s is born to %s." % [child.name, leader.name], "good")
	for fid in factions:
		var leader = leader_of(fid)
		if leader:
			_rule_month(leader)
		# Respect: an able leader steadies everyone; a weak one, or none, unsettles them. Some natures help or hurt
		var respect = -10.0
		if leader:
			respect = (leader.best_skill_value() - 5) * GameData.rule("respect_per_skill")
			for t in leader.traits:
				respect += float(GameData.character_trait(t).get("respect", 0.0))
		for c in characters_of(fid):
			c.respect = respect
			c.respect_label = (("Respects %s" if respect >= 0 else "Doubts %s") % leader.name) if leader else "No leader"

# A leader's month: remarry if widowed, pull the faction toward their nature, and earn ruling traits
func _rule_month(leader: Character):
	var f: Faction = factions[leader.faction_id]
	var spouse = character_by_id(leader.spouse_id)
	if (spouse == null or spouse.faction_id != leader.faction_id) and rng.randf() < GameData.rule("remarry_chance"):
		var new_spouse = _marry(leader)
		if leader.faction_id == player_id:
			event.emit("%s has married %s." % [leader.name, new_spouse.name], "good")
	for t in leader.traits:
		var pull: String = GameData.character_trait(t).get("faction_trait", "")
		if pull != "":
			feed_trait_by_name(f, pull, GameData.rule("leader_trait_pull"))
	leader.peace_days = leader.peace_days + 30 if not at_war_with_anyone(f.id) else 0
	var treaties = 0
	for other in factions:
		if other != f.id:
			var r = relation(f.id, other)
			if r.trade or r.pact or r.alliance:
				treaties += 1
	var earned = []
	if f.stats["districts_conquered"] - int(leader.rule_start.get("districts_conquered", 0)) >= 3:
		earned.append("conqueror")
	if f.stats.get("buildings_built", 0) - int(leader.rule_start.get("buildings_built", 0)) >= 5:
		earned.append("builder")
	if leader.peace_days >= 360 and treaties >= 2:
		earned.append("peacemaker")
	for t in earned:
		if t not in leader.traits:
			leader.traits.append(t)
			var text = "%s of the %s is now known as a %s: %s." % [leader.name, f.display_name, GameData.character_trait(t)["label"], GameData.character_trait(t)["description"]]
			event.emit(text, "good" if f.id == player_id else "info")

# The faction-wide bonus the leader's ruling traits give ventures using this skill: [label, mult] or []
func leader_factor(faction_id: String, skill: String) -> Array:
	var leader = leader_of(faction_id)
	if leader == null:
		return []
	var mult = 1.0
	for t in leader.traits:
		mult *= float(GameData.character_trait(t).get("faction_skill_odds", {}).get(skill, 1.0))
	return [] if is_equal_approx(mult, 1.0) else ["Leader %s's reputation" % leader.name, mult]

# Names someone the next leader. Passing over the eldest child, or the family altogether, costs loyalty
func designate_heir(faction_id: String, character_id: int) -> String:
	var leader = leader_of(faction_id)
	var c = character_by_id(character_id)
	if leader == null or c == null or c.faction_id != faction_id or c == leader:
		return "No such candidate"
	if not c.is_adult():
		return "%s is too young to rule" % c.name
	if not (c.family or c.post != ""):
		return "Only family and council members can be named heir"
	var f: Faction = factions[faction_id]
	if f.designated_heir == c.id:
		return "%s is already your heir" % c.name
	var natural = succession_outlook(faction_id, leader, false)["heir"]
	f.designated_heir = c.id
	if natural and natural != c:
		natural.change_loyalty(-15.0, "passed_over_rule")
	if not c.family:
		for other in characters_of(faction_id):
			if other.family:
				other.change_loyalty(-8.0, "passed_over_rule")
	if faction_id == player_id:
		event.emit("%s is now your chosen heir.%s" % [c.name, (" %s, who would have inherited, resents it." % natural.name) if natural and natural != c else ""], "info")
	return ""

func person_by_id(id: int) -> Character:
	var c = character_by_id(id)
	if c:
		return c
	for dead in graveyard:
		if dead.id == id:
			return dead
	return null

# Who would take over if the leader died today, who'd contest it, and the chance the faction splits.
# {"heir": Character or null, "claim": float, "by_blood": bool, "contesters": [[Character, claim]], "split_chance": float}
func succession_outlook(faction_id: String, leader: Character = null, honour_choice: bool = true) -> Dictionary:
	if leader == null:
		leader = leader_of(faction_id)
	var crew = characters_of(faction_id).filter(func(c): return c != leader)
	var heir: Character = null
	var by_blood = false
	if leader:
		# The leader's chosen heir first, then the eldest adult child, the spouse, then anyone else of the family
		var chosen = character_by_id(factions[faction_id].designated_heir)
		if honour_choice and chosen and chosen in crew:
			heir = chosen
		var children = crew.filter(func(c): return leader.id in c.parent_ids)
		children.sort_custom(func(a, b): return a.age > b.age)
		if heir:
			pass
		elif not children.is_empty():
			heir = children[0]
		elif leader.spouse_id >= 0 and character_by_id(leader.spouse_id) in crew:
			heir = character_by_id(leader.spouse_id)
		else:
			for c in crew:
				if c.family and c.dynasty == leader.dynasty:
					heir = c
					break
		by_blood = heir != null and heir.family and heir.dynasty == leader.dynasty
	if heir == null:
		# The strongest on the council, or failing that anyone, takes charge
		var best_score = -1
		for c in crew:
			var score = (100 if c.post != "" else 0) + _skill_total(c)
			if score > best_score:
				best_score = score
				heir = c
	if heir == null:
		return {"heir": null, "claim": 0.0, "by_blood": false, "contesters": [], "split_chance": 0.0}
	var claim = (GameData.rule("blood_claim") if by_blood else GameData.rule("council_claim")) + heir.best_skill_value() * 3.0 \
		+ heir.triumphs * 2.0 + factions[faction_id].renown / 10.0
	var contesters = []
	for c in crew:
		if c == heir or not (c.post != "" or c.family):
			continue
		var loyalty = c.loyalty()
		if loyalty >= 40.0 and not c.has_trait("ambitious"):
			continue
		var theirs = c.best_skill_value() * 3.0 + c.triumphs * 2.0 + maxf(45.0 - loyalty, 0.0) + (10.0 if c.has_trait("ambitious") else 0.0)
		if theirs > claim * 0.6:
			contesters.append([c, theirs])
	contesters.sort_custom(func(a, b): return a[1] > b[1])
	var chance = 0.0
	for entry in contesters:
		chance += entry[1] / (entry[1] + claim) * GameData.rule("split_weight")
	if districts_held(faction_id) < 2:
		chance = 0.0
	return {"heir": heir, "claim": claim, "by_blood": by_blood, "contesters": contesters, "split_chance": clampf(chance, 0.0, 0.85)}

func _skill_total(c: Character) -> int:
	var total = 0
	for s in Character.SKILLS:
		total += int(c.skills[s])
	return total

# The leader is dead: the heir takes over, rivals may contest it, and the faction may split
func _succession(faction_id: String, dead: Character, fate: String):
	var f: Faction = factions.get(faction_id)
	if f == null:
		return
	var outlook = succession_outlook(faction_id, dead)
	var heir: Character = outlook["heir"]
	if heir == null:
		heir = _new_captain(faction_id, Character.SKILLS[rng.randi() % Character.SKILLS.size()])
	var was_chosen = f.designated_heir == heir.id
	var old_post = heir.post
	_crown(heir)
	if not heir.family or heir.dynasty != dead.dynasty:
		# A new house: the old family keeps its name but loses its claim
		for c in everyone_of(faction_id):
			if c.family and c.dynasty == dead.dynasty:
				c.family = false
		heir.family = true
		heir.dynasty = heir.name.get_slice(" ", 1)
		var spouse = character_by_id(heir.spouse_id)
		if spouse:
			spouse.family = true
	for c in characters_of(faction_id):
		c.change_loyalty(-8.0, "new_leader")
	for entry in outlook["contesters"]:
		entry[0].change_loyalty(-12.0, "passed_over_rule")
	var how = "%s's %s" % [dead.name.get_slice(" ", 0), "child" if outlook["by_blood"] and dead.id in heir.parent_ids else "kin"] if outlook["by_blood"] else "the strongest of the crew"
	if was_chosen:
		how = "the chosen heir"
	var died = ("was " + fate) if fate.begins_with("killed") else fate
	var text = "%s, leader of the %s, %s at %d. %s (%s, %d) takes over." % [dead.name, f.display_name, died, dead.age, heir.name, how, heir.age]
	if old_post != "":
		text += " Their %s seat is empty." % GameData.council_post(old_post)["label"]
	event.emit(text, "alert" if faction_id == player_id else "info")
	if faction_id == player_id or player_met.has(faction_id):
		major_event.emit("%s is dead" % dead.name, text, faction_id)
	if not outlook["contesters"].is_empty() and rng.randf() < outlook["split_chance"]:
		_split(faction_id, outlook["contesters"][0][0])


# Civil war: a rival claimant breaks away with a block of districts furthest from the capital
var next_split_id: int = 1

func _split(faction_id: String, claimant: Character):
	var f: Faction = factions[faction_id]
	var owned = districts.filter(func(d): return d.owner_id() == faction_id)
	if owned.size() < 2:
		return
	var capital: District = districts[f.home_id] if f.home_id >= 0 and districts[f.home_id].owner_id() == faction_id else owned[0]
	var seed: District = owned[0]
	for d in owned:
		if d != capital and d.center.distance_to(capital.center) > seed.center.distance_to(capital.center):
			seed = d
	var others = owned.filter(func(d): return d != capital)
	others.sort_custom(func(a, b): return a.center.distance_to(seed.center) < b.center.distance_to(seed.center))
	var take = others.slice(0, clampi(int(round(owned.size() * rng.randf_range(0.3, 0.45))), 1, owned.size() - 1))
	var surname = claimant.name.get_slice(" ", 1)
	var id = "split_%d" % next_split_id
	next_split_id += 1
	var color = Color.from_hsv(fposmod(f.color.h + 0.07, 1.0), f.color.s * 0.75, f.color.v * 0.8)
	var rebels = Faction.new(id, "%s's %s" % [surname, SPLIT_NAMES[rng.randi() % SPLIT_NAMES.size()]], color, false)
	rebels.personality = "raider" if claimant.best_skill() == "command" else ""
	rebels.blurb = "Broke away from the %s when %s claimed the leadership." % [f.display_name, claimant.name]
	rebels.traits.load_dict(f.traits.to_dict())
	for resource_type in ["manpower", "supplies", "materials", "wealth", "arms"]:
		var share: float = f.get(resource_type) * 0.35
		f.set(resource_type, f.get(resource_type) - share)
		rebels.set(resource_type, share)
	rebels.home_id = seed.id
	rebels.scouted = f.scouted.duplicate()
	factions[id] = rebels
	for d in take:
		var held = d.share(faction_id)
		d.influence.erase(faction_id)
		d.influence[id] = held
	# The claimant leads; the disloyal follow
	claimant.faction_id = id
	claimant.post = ""
	_crown(claimant)
	claimant.family = true
	claimant.dynasty = surname
	claimant.loyalty_mods.clear()
	for c in characters_of(faction_id):
		if c.loyalty() < 35.0 and not c.family:
			c.faction_id = id
			c.post = ""
			c.loyalty_mods.clear()
	while captain_count(id) < 2:
		_new_captain(id, Character.SKILLS[rng.randi() % Character.SKILLS.size()])
	for other in factions:
		if other == id:
			continue
		var r = relation(id, other)
		for side in [r.a, r.b]:
			r.baseline[side] = Diplomacy.baseline_value(Diplomacy.opinion_baseline(self, side, r.other(side)))
			r.recompute_opinion(side)
	start_war(id, faction_id)
	var names = ", ".join(take.map(func(d): return d.district_name))
	if faction_id == player_id:
		event.emit("CIVIL WAR! %s refused to accept the new leader and broke away with %s, as the %s." % [claimant.name, names, rebels.display_name], "alert")
	else:
		event.emit("Civil war in the %s: %s broke away with %d districts as the %s." % [f.display_name, claimant.name, take.size(), rebels.display_name], "alert" if shares_border(player_id, id) else "info")
	if faction_id == player_id or player_met.has(faction_id):
		major_event.emit("Civil war", ("%s refused to accept the new leader and broke away with %s, as the %s. They are at war with you." if faction_id == player_id else "%s broke away from the %s with %s, as the %s.") % ([claimant.name, names, rebels.display_name] if faction_id == player_id else [claimant.name, f.display_name, names, rebels.display_name]), id)
	factions_changed.emit()

# --- Characters -----------------------------------------------------------------------

# The working crew: adults who can lead ventures and hold seats (everyone but the leader and children)
func characters_of(faction_id: String) -> Array:
	return characters.filter(func(c): return c.faction_id == faction_id and not c.is_leader and c.is_adult())

# Everyone: the leader, the family (children too) and the crew
func everyone_of(faction_id: String) -> Array:
	return characters.filter(func(c): return c.faction_id == faction_id)

# Hired captains (not family): what the captain limit counts
func captain_count(faction_id: String) -> int:
	return characters_of(faction_id).filter(func(c): return not c.family).size()

func leader_of(faction_id: String) -> Character:
	for c in characters:
		if c.faction_id == faction_id and c.is_leader:
			return c
	return null

func character_by_id(id: int) -> Character:
	for c in characters:
		if c.id == id:
			return c
	return null

func leader_busy(c: Character) -> bool:
	for v in ventures:
		if v.leader_id == c.id:
			return true
	return false

func available_leaders(faction_id: String) -> Array:
	return characters_of(faction_id).filter(func(c): return not c.is_wounded(day) and not leader_busy(c))

# The free captain best at a skill (null if nobody is free)
func best_leader(faction_id: String, skill: String) -> Character:
	var best: Character = null
	for c in available_leaders(faction_id):
		if best == null or c.skills[skill] > best.skills[skill]:
			best = c
	return best

# How many captains a faction can keep: more with territory and renown
func captain_cap(faction_id: String) -> int:
	return mini(int(GameData.rule("captain_max")), int(GameData.rule("captain_base")) + districts_held(faction_id) / int(GameData.rule("captain_per_districts")) \
		+ int(factions[faction_id].renown / GameData.rule("captain_per_renown")))

func _new_captain(faction_id: String, specialty: String) -> Character:
	var names = GameData.names()
	var taken = everyone_of(faction_id).map(func(c): return c.name)
	var sex = "m" if rng.randf() < 0.5 else "f"
	var name = ""
	for attempt in 20:
		name = "%s %s" % [_first_name(sex), names["last"][rng.randi() % names["last"].size()]]
		if name not in taken:
			break
	var c = Character.new(next_character_id, faction_id, name, rng.randi_range(20, 55))
	next_character_id += 1
	c.sex = sex
	for s in Character.SKILLS:
		c.skills[s] = rng.randi_range(1, 4)
	# Renown draws better people: up to +2 on their specialty
	c.skills[specialty] = mini(10, rng.randi_range(5, 8) + mini(2, int(factions[faction_id].renown / 40.0)))
	_give_personality(c)
	characters.append(c)
	return c

# Every month or so, factions with room for more captains may gain one
func _check_recruitment():
	if day % int(GameData.rule("captain_recruit_days")) != 0:
		return
	for fid in factions:
		if captain_count(fid) >= captain_cap(fid) or rng.randf() > 0.6:
			continue
		var c = _new_captain(fid, Character.SKILLS[rng.randi() % Character.SKILLS.size()])
		if fid == player_id:
			var best = c.best_skill()
			event.emit("%s joins your crew as a captain (%s %d)." % [c.name, best.capitalize(), c.skills[best]], "good")

func _announce_ownership_change(d: District, owner_before: String, actor_id: String = ""):
	var owner_after = d.owner_id()
	if owner_after == owner_before:
		return
	if owner_before != "" and actor_id != "" and is_at_war(owner_before, actor_id):
		add_exhaustion(owner_before, actor_id, 10.0)
	var spoils = ""
	if owner_after != "" and not d.buildings.is_empty():
		spoils = " Its %s changed hands too." % ", ".join(d.building_labels())
	if owner_after == player_id:
		event.emit("You now control %s. It will pay income and supply recruits.%s" % [d.district_name, spoils], "good")
	elif owner_after != "":
		event.emit("The %s have taken %s.%s" % [faction_name(owner_after), d.district_name, spoils], "alert" if owner_before == player_id else "info")
	elif owner_before == player_id:
		event.emit("You have lost control of %s." % d.district_name, "alert")
	else:
		event.emit("The %s have lost control of %s. It's up for grabs." % [faction_name(owner_before), d.district_name], "good")

func _feed_trait(f: Faction, venture_id: String, amount: float):
	var trait_name: String = GameData.venture(venture_id).get("feeds_trait", "")
	if trait_name == "":
		return
	if f.traits.add_faction_trait_value(trait_name, amount) == 1:
		_announce_trait(f, trait_name)

func _announce_trait(f: Faction, trait_name: String):
	var t: Trait = f.traits.faction_traits[trait_name]
	if f.id == player_id:
		event.emit("Your crew is now known as %s. Benefit: %s. Cost: %s." % [trait_name, t.benefit, t.cost], "good")
	else:
		event.emit("%s have become %s (%s)." % [f.display_name, trait_name, t.benefit], "alert")

# --- Buildings ------------------------------------------------------------------

# Building effects only work while the owner can pay upkeep
func buildings_active(district: District) -> bool:
	var owner: Faction = factions.get(district.owner_id())
	return owner != null and not owner.broke and not owner.disrepair

func building_slots(district: District) -> int:
	if district.owner_id() == "":
		return 0
	return int(GameData.rule("building_slots").get(district.get_control_status(), 0))

func constructions_at(district: District) -> Array:
	var found = []
	for c in constructions:
		if c.district == district:
			found.append(c)
	return found

# Most crew a faction's territory can support
func crew_cap(faction_id: String) -> int:
	var cap = int(GameData.rule("crew_base")) + districts_held(faction_id) * int(GameData.rule("crew_per_district"))
	for d in districts:
		if d.owner_id() == faction_id and buildings_active(d):
			cap += int(d.building_effect("crew_cap"))
	# Renowned factions draw volunteers
	cap += int(factions[faction_id].renown / GameData.rule("renown_per_crew"))
	return cap

# Returns "" if the building can be started here, otherwise why not
func check_build(faction_id: String, building_id: String, district: District) -> String:
	var f: Faction = factions[faction_id]
	var def = GameData.building(building_id)
	if district.owner_id() != faction_id:
		return "Only in districts you control"
	if def["requires"] == "secured" and district.get_control_status() != "secured":
		return "Needs a Secured district"
	if district.ruin_level < def.get("min_ruin", 0.0):
		return "Not enough ruins left here"
	if building_id in district.buildings:
		return "Already built here"
	for c in constructions_at(district):
		if c.building_id == building_id:
			return "Already under construction here"
	var slots = building_slots(district)
	if district.buildings.size() + constructions_at(district).size() >= slots:
		return "No free building slot (%s districts have %d)" % [district.get_control_status().capitalize(), slots]
	if int(f.manpower) < def["crew"]:
		return "Need %d idle manpower (have %d)" % [def["crew"], f.manpower]
	if not f.can_afford(def["cost"]):
		return f.shortfall(def["cost"])
	return ""

func start_construction(faction_id: String, building_id: String, district: District) -> String:
	var err = check_build(faction_id, building_id, district)
	if err != "":
		return err
	var f: Faction = factions[faction_id]
	var def = GameData.building(building_id)
	f.pay(def["cost"])
	f.manpower -= def["crew"]
	constructions.append(Construction.new(building_id, faction_id, district, int(def["crew"]), int(def["days"])))
	if faction_id == player_id:
		event.emit("Started building a %s in %s: ready in %d days." % [def["label"], district.district_name, def["days"]], "info")
	return ""

func _finish_construction(c: Construction):
	var f: Faction = factions.get(c.faction_id)
	if f == null:
		return
	f.manpower += c.crew
	var label = GameData.building(c.building_id)["label"]
	# The district may have changed hands while it was being built
	if c.district.owner_id() != c.faction_id:
		if c.faction_id == player_id:
			event.emit("Construction of the %s in %s abandoned: you lost the district." % [label, c.district.district_name], "bad")
		return
	c.district.buildings.append(c.building_id)
	f.stats["buildings_built"] = f.stats.get("buildings_built", 0) + 1
	if c.faction_id == player_id:
		event.emit("Your %s in %s is complete: %s." % [label, c.district.district_name, GameData.building(c.building_id)["summary"]], "good")

# --- Economy --------------------------------------------------------------------

# Food a district produces for its owner each day: the land, lasting food sources (Secure Food)
# and working buildings (Allotments). Unowned land feeds nobody.
func district_food(d: District) -> float:
	var mult = yield_multiplier(d)
	if mult <= 0.0:
		return 0.0
	var food = mult * (0.2 + d.development * 0.3) * (1.0 - d.ruin_level * 0.5) + d.food_yield
	if buildings_active(d):
		food += d.building_effect("supplies_daily")
	return food

# The food that drives a district's growth: its own, plus a share of what the owner's
# neighbouring districts grow (food travels a little way)
func district_growth_food(d: District) -> float:
	var owner = d.owner_id()
	if owner == "":
		return 0.0
	var food = district_food(d)
	for n_id in d.neighbor_ids:
		if districts[n_id].owner_id() == owner:
			food += district_food(districts[n_id]) * GameData.rule("food_spill_share")
	return food

# How many people a district can house: rebuilding (development) makes room
func housing(d: District) -> float:
	return GameData.rule("housing_base") + d.development * GameData.rule("housing_per_development")

# What a district gives its owner each day: food, materials, wealth (taxes on its people)
# and manpower (grown from food, if the district is calm enough)
func district_income(d: District) -> Dictionary:
	var income = {"supplies": 0.0, "materials": 0.0, "wealth": 0.0, "recruits": 0.0}
	var mult = yield_multiplier(d)
	if mult <= 0.0:
		return income
	var owner: Faction = factions[d.owner_id()]
	income["supplies"] = district_food(d)
	income["wealth"] = mult * d.population * (GameData.rule("tax_per_pop") + d.development * GameData.rule("tax_per_pop_development")) \
		* owner.traits.effect("wealth_income_mult")
	var recruit_mult = 1.0
	if buildings_active(d):
		income["materials"] += d.building_effect("materials_daily")
		income["wealth"] += d.building_effect("wealth_daily")
		recruit_mult = d.building_effect("recruit_mult")
	var calm = 1.0 if d.grievance < 50.0 else (0.5 if d.grievance < 80.0 else 0.0)
	# Rebuilt districts turn food into fighters better: more homes, more young people
	income["recruits"] = district_growth_food(d) * GameData.rule("manpower_per_food") * calm * recruit_mult * (0.5 + d.development)
	return income

# Running more districts costs more than proportionally: the brake on endless expansion
func admin_upkeep(faction_id: String) -> float:
	# The first few districts run themselves; beyond that, costs climb faster than territory
	return GameData.rule("admin_upkeep_per_district") * pow(maxf(districts_held(faction_id) - GameData.rule("admin_free_districts"), 0.0), GameData.rule("admin_upkeep_exponent"))

# Daily running costs, itemised: {"supplies": [[label, amount]], "wealth": [...], "materials": [...]}.
# Manpower and population eat food, buildings cost upkeep, territory costs administration, hoards leak
func upkeep_breakdown(faction_id: String) -> Dictionary:
	var f: Faction = factions[faction_id]
	var parts = {"supplies": [], "wealth": [], "materials": []}
	var population = 0.0
	var building_count = 0
	var building_costs = {"supplies": 0.0, "wealth": 0.0, "materials": 0.0}
	for d in districts:
		if d.owner_id() == faction_id:
			population += d.population
			building_count += d.buildings.size()
			for building_id in d.buildings:
				var upkeep: Dictionary = GameData.building(building_id)["upkeep"]
				for resource_type in upkeep:
					building_costs[resource_type] += upkeep[resource_type]
	parts["supplies"].append(["Your people eat (%d)" % population, population * GameData.rule("food_per_pop")])
	parts["supplies"].append(["Manpower eats (%d)" % (f.manpower + crew_away(faction_id)), (f.manpower + crew_away(faction_id)) * GameData.rule("crew_daily_upkeep")])
	parts["supplies"].append(["Food spoiling (stores over %d)" % GameData.rule("food_fresh_store"), maxf(f.supplies - GameData.rule("food_fresh_store"), 0.0) * GameData.rule("food_spoil_rate")])
	parts["wealth"].append(["Administration (%d districts)" % districts_held(faction_id), admin_upkeep(faction_id)])
	parts["wealth"].append(["Council wages (%d seats)" % council_size(faction_id), council_size(faction_id) * council_wage(faction_id)])
	parts["wealth"].append(["Theft and graft (over %d)" % GameData.rule("wealth_safe_hoard"), maxf(f.wealth - GameData.rule("wealth_safe_hoard"), 0.0) * GameData.rule("hoard_loss_rate")])
	parts["materials"].append(["Building wear (%d buildings)" % building_count, building_count * GameData.rule("building_materials_upkeep")])
	parts["materials"].append(["Theft and graft (over %d)" % GameData.rule("materials_safe_hoard"), maxf(f.materials - GameData.rule("materials_safe_hoard"), 0.0) * GameData.rule("hoard_loss_rate")])
	for resource_type in building_costs:
		if building_costs[resource_type] > 0.0:
			parts[resource_type].append(["Building upkeep", building_costs[resource_type]])
	return parts

func faction_upkeep(faction_id: String) -> Dictionary:
	var costs = {"supplies": 0.0, "wealth": 0.0, "materials": 0.0}
	var parts = upkeep_breakdown(faction_id)
	for resource_type in parts:
		for part in parts[resource_type]:
			costs[resource_type] += part[1]
	return costs

# Manpower limit, itemised: [[label, amount]]
func crew_cap_breakdown(faction_id: String) -> Array:
	var parts = [["Base", int(GameData.rule("crew_base"))], ["%d districts" % districts_held(faction_id), districts_held(faction_id) * int(GameData.rule("crew_per_district"))]]
	var from_buildings = 0
	for d in districts:
		if d.owner_id() == faction_id and buildings_active(d):
			from_buildings += int(d.building_effect("crew_cap"))
	if from_buildings > 0:
		parts.append(["Hostels", from_buildings])
	var from_renown = int(factions[faction_id].renown / GameData.rule("renown_per_crew"))
	if from_renown > 0:
		parts.append(["Renown", from_renown])
	return parts
# Daily totals for the UI: {"supplies" (food), "materials", "wealth": {"income", "upkeep"}, "manpower": new per day,
# "trade": wealth from trade agreements, "tribute": {"supplies", "wealth"} (negative when paying)}
func daily_economy(faction_id: String) -> Dictionary:
	var totals = {"supplies": {"income": 0.0, "upkeep": 0.0}, "materials": {"income": 0.0, "upkeep": 0.0}, "wealth": {"income": 0.0, "upkeep": 0.0}, "manpower": 0.0,
		"trade": 0.0, "tribute": {"supplies": 0.0, "wealth": 0.0}}
	var rate: float = GameData.rule("tribute_rate")
	var pays_tribute = overlord_of(faction_id) != ""
	var vassals = vassals_of(faction_id)
	for d in districts:
		var owner = d.owner_id()
		if owner == faction_id or owner in vassals:
			var income = district_income(d)
			if owner == faction_id:
				totals["manpower"] += income["recruits"]
				totals["materials"]["income"] += income["materials"]
			for resource_type in ["supplies", "wealth"]:
				if owner == faction_id:
					var kept = income[resource_type] * (1.0 - rate if pays_tribute else 1.0)
					totals[resource_type]["income"] += kept
					if pays_tribute:
						totals["tribute"][resource_type] -= income[resource_type] * rate
				else:
					totals[resource_type]["income"] += income[resource_type] * rate
					totals["tribute"][resource_type] += income[resource_type] * rate
	for fid in factions:
		if fid != faction_id and relation(faction_id, fid).trade:
			var trade = Diplomacy.trade_income(self, faction_id, fid)
			totals["trade"] += trade
			totals["wealth"]["income"] += trade
	var upkeep = faction_upkeep(faction_id)
	totals["supplies"]["upkeep"] = upkeep["supplies"]
	totals["wealth"]["upkeep"] = upkeep["wealth"]
	totals["materials"]["upkeep"] = upkeep["materials"]
	return totals

# --- Simulation ---------------------------------------------------------------

func advance_day():
	day += 1
	for d in districts:
		_simulate_district(d)
	_simulate_relations()
	for f in factions.values():
		_upkeep(f)
	for v in ventures.duplicate():
		v.days_left -= 1
		if v.days_left <= 0:
			ventures.erase(v)
			_resolve(v)
	for c in constructions.duplicate():
		c.days_left -= 1
		if c.days_left <= 0:
			constructions.erase(c)
			_finish_construction(c)
	for m in missions.duplicate():
		m.days_left -= 1
		if m.days_left <= 0:
			missions.erase(m)
			Diplomacy.resolve_mission(self, m)
	for i in range(proposals.size() - 1, -1, -1):
		if day >= proposals[i]["expires_day"]:
			answer_proposal(i, false, true)
	for f in factions.values().duplicate():
		if f.ai and factions.has(f.id):
			f.ai.think(self)
	_check_eliminations()
	_check_ambitions()
	_check_recruitment()
	_update_loyalty()
	_check_first_contacts()
	_life_cycle()

func _simulate_district(d: District):
	var owner = d.owner_id()
	var owner_faction: Faction = factions.get(owner)
	var active = buildings_active(d)
	var claimants = 0
	for fid in d.influence:
		if d.influence[fid] >= 20.0:
			claimants += 1

	d.grievance -= 0.15
	if claimants >= 2:
		d.grievance += 0.35
	if owner_faction:
		d.grievance += owner_faction.traits.effect("owned_daily_grievance")
	if active:
		d.grievance += d.building_effect("grievance_daily")
	d.grievance = clampf(d.grievance, 0.0, 100.0)
	# Land nobody holds keeps falling apart: its ruins creep back toward what the district naturally is
	if owner_faction == null:
		var natural: float = GameData.district_type(d.district_type)["ruin"][1]
		if d.ruin_level < natural:
			d.ruin_level = minf(d.ruin_level + GameData.rule("ruin_regrowth"), natural)

	# A calm district holds on to its owner's claim (control above that takes Safeguard ventures); an angry one slips away
	if owner_faction:
		if d.grievance < 40.0 and d.share(owner) < GameData.rule("control_consolidation_cap"):
			d.add_influence(owner, GameData.rule("daily_consolidation"))
		elif d.grievance > 65.0:
			d.add_influence(owner, -0.12)

	# People follow food: a fed district grows (helped by food from the owner's land next door),
	# up to what its rebuilt housing holds. Hunger and anger drive them away.
	if owner_faction:
		if owner_faction.starving:
			d.population *= 0.996
		elif d.grievance < 60.0:
			d.population *= 1.0 + GameData.rule("growth_per_food") * district_growth_food(d) * (d.building_effect("growth_mult") if active else 1.0)
	if d.grievance > 70.0:
		d.population *= 0.997
	var room = housing(d)
	if d.population > room:
		d.population -= (d.population - room) * 0.01
	d.population = clampf(d.population, 5.0, 200.0)

	if active:
		d.ruin_level = clampf(d.ruin_level + d.building_effect("ruin_daily"), 0.0, 1.0)
		d.development = clampf(d.development + d.building_effect("development_daily"), 0.0, 1.0)

	# Only the owner is paid, and secured land pays more
	if owner_faction:
		var income = district_income(d)
		# Vassals send part of their income to their overlord
		var overlord: Faction = factions.get(overlord_of(owner))
		var rate: float = GameData.rule("tribute_rate") if overlord else 0.0
		owner_faction.materials += income["materials"]
		for resource_type in ["supplies", "wealth"]:
			owner_faction.set(resource_type, owner_faction.get(resource_type) + income[resource_type] * (1.0 - rate))
			if overlord:
				overlord.set(resource_type, overlord.get(resource_type) + income[resource_type] * rate)
		# Recruits come from calm land, up to what your territory can support
		if owner_faction.manpower + crew_away(owner) < crew_cap(owner):
			owner_faction.manpower += income["recruits"]

	_check_unrest(d, owner)

func _check_unrest(d: District, owner: String):
	# Secured districts don't revolt
	if owner != "" and d.grievance > 80.0 and d.share(owner) < GameData.rule("secure_threshold") and rng.randf() < 0.04:
		d.add_influence(owner, -30.0)
		d.grievance = 45.0
		d.population *= 0.85
		d.ruin_level = clampf(d.ruin_level + 0.1, 0.0, 1.0)
		var wrecked = ""
		if not d.buildings.is_empty():
			var index = rng.randi_range(0, d.buildings.size() - 1)
			wrecked = " Rioters wrecked the %s." % GameData.building(d.buildings[index])["label"]
			d.buildings.remove_at(index)
		if owner == player_id:
			event.emit("REVOLT! %s has risen against you.%s" % [d.district_name, wrecked], "alert")
		else:
			event.emit("%s has revolted against the %s.%s" % [d.district_name, faction_name(owner), wrecked], "good")
		_announce_ownership_change(d, owner)
		return

	if owner == player_id:
		if d.grievance >= 65.0 and not d.unrest_warned:
			d.unrest_warned = true
			event.emit("Unrest rising in %s (grievance %d). It may revolt above 80 unless Secured." % [d.district_name, d.grievance], "alert")
		elif d.grievance < 50.0:
			d.unrest_warned = false

func _upkeep(f: Faction):
	var costs = faction_upkeep(f.id)
	f.arms = minf(f.arms, GameData.rule("arms_cap"))
	f.supplies -= costs["supplies"]
	f.wealth -= costs["wealth"]
	f.materials -= costs["materials"]
	if f.materials < 0.0:
		f.materials = 0.0
		if not f.disrepair:
			f.disrepair = true
			if f.id == player_id:
				event.emit("Out of materials: your buildings are falling into disrepair and have stopped working. Scavenge or trade for materials.", "alert")
	elif f.disrepair and f.materials > 3.0:
		f.disrepair = false
		if f.id == player_id:
			event.emit("Repairs are done. Your buildings are working again.", "good")
	if f.supplies < 0.0:
		f.supplies = 0.0
		f.manpower = maxf(0.0, f.manpower - 0.1)
		if not f.starving:
			f.starving = true
			if f.id == player_id:
				event.emit("Food has run out. Your people are going hungry: manpower is deserting and the population is shrinking. Secure Food, or build Allotments.", "alert")
	elif f.supplies > 5.0:
		f.starving = false

	if f.wealth < 0.0:
		f.wealth = 0.0
		if not f.broke:
			f.broke = true
			if f.id == player_id:
				event.emit("Out of wealth: you can't pay building upkeep, so your buildings have stopped working.", "alert")
	elif f.broke and f.wealth > 5.0:
		f.broke = false
		if f.id == player_id:
			event.emit("Upkeep is paid again. Your buildings are working.", "good")

	for trait_name in f.traits.decay():
		var who = "Your crew is" if f.id == player_id else "%s are" % f.display_name
		event.emit("%s no longer seen as %s." % [who, trait_name], "info")

# --- Save / load --------------------------------------------------------------

func to_save() -> Dictionary:
	var data = {
		"version": SAVE_VERSION, "day": day, "player_id": player_id,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"factions": [], "relations": [], "districts": [], "ventures": [], "constructions": [], "missions": [],
		"proposals": proposals.duplicate(true), "player_defeated": player_defeated,
		"characters": characters.map(func(c): return c.to_dict()), "next_character_id": next_character_id, "departed": departed.duplicate(true), "player_met": player_met.duplicate(), "next_split_id": next_split_id, "graveyard": graveyard.map(func(c): return c.to_dict()),
	}
	for f in factions.values():
		data["factions"].append(f.to_dict())
	for r in relations.values():
		data["relations"].append(r.to_dict())
	for d in districts:
		data["districts"].append(d.to_dict())
	for v in ventures:
		data["ventures"].append(v.to_dict())
	for c in constructions:
		data["constructions"].append(c.to_dict())
	for m in missions:
		data["missions"].append(m.to_dict())
	return data

func _load(data: Dictionary):
	day = int(data["day"])
	player_id = data["player_id"]
	rng.seed = String(data["rng_seed"]).to_int()
	rng.state = String(data["rng_state"]).to_int()
	for fd in data["factions"]:
		var f = Faction.from_dict(fd)
		factions[f.id] = f
	for rd in data["relations"]:
		var r = Relation.from_dict(rd)
		relations[r.a + "|" + r.b if r.a < r.b else r.b + "|" + r.a] = r
	for i in districts.size():
		districts[i].load_dict(data["districts"][i])
	for vd in data["ventures"]:
		ventures.append(ActiveVenture.from_dict(vd, districts))
	for cd in data["constructions"]:
		constructions.append(Construction.from_dict(cd, districts))
	for md in data["missions"]:
		missions.append(DiplomaticMission.from_dict(md))
	proposals = data["proposals"]
	player_defeated = data["player_defeated"]
	for cd in data["characters"]:
		characters.append(Character.from_dict(cd))
	next_character_id = int(data["next_character_id"])
	departed = data["departed"]
	player_met = data["player_met"]
	next_split_id = int(data["next_split_id"])
	for entry in data["graveyard"]:
		graveyard.append(Character.from_dict(entry))

# Saves use Godot's binary Variant format rather than JSON: JSON doesn't round-trip floats
# exactly, and tiny differences grow until a loaded game plays out differently from the original
func save_game(path: String = SAVE_PATH) -> String:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Could not write save file (%s)" % error_string(FileAccess.get_open_error())
	file.store_var(to_save())
	return ""

# Returns the loaded world, or null if there's no usable save
static func load_game(path: String = SAVE_PATH) -> CityMap:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data = file.get_var()
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return null
	return CityMap.new(data)

# --- Ambitions ------------------------------------------------------------------------

# What an ambition's condition can measure (see data/ambitions.json)
const AMBITION_CONDITIONS = ["districts_held", "secured_districts", "buildings_owned", "building_type", "trade_agreements",
	"alliances", "vassals", "crew_total", "traits_active", "population", "districts_conquered", "wars_won"]

# Progress toward an ambition as [current, target]
func ambition_progress(faction_id: String, ambition_id: String) -> Array:
	var condition: Dictionary = GameData.ambitions()[ambition_id]["condition"]
	var f: Faction = factions[faction_id]
	var current = 0
	match condition["type"]:
		"districts_held":
			current = districts_held(faction_id)
		"secured_districts", "buildings_owned", "building_type", "population":
			for d in districts:
				if d.owner_id() != faction_id:
					continue
				match condition["type"]:
					"secured_districts":
						current += 1 if d.get_control_status() == "secured" else 0
					"buildings_owned":
						current += d.buildings.size()
					"building_type":
						current += d.buildings.count(condition["building"])
					"population":
						current += int(d.population)
		"trade_agreements", "alliances":
			for fid in factions:
				if fid != faction_id:
					var r = relation(faction_id, fid)
					current += 1 if (r.trade if condition["type"] == "trade_agreements" else r.alliance) else 0
		"vassals":
			current = vassals_of(faction_id).size()
		"crew_total":
			current = int(f.manpower) + crew_away(faction_id)
		"traits_active":
			current = f.traits.get_active_traits().size()
		"districts_conquered", "wars_won":
			current = int(f.stats[condition["type"]])
	return [current, int(condition["amount"])]

# Every faction pursues the same ambitions; achieving one earns renown
func _check_ambitions():
	for f in factions.values():
		for id in GameData.ambitions():
			if id in f.ambitions_done:
				continue
			var progress = ambition_progress(f.id, id)
			if progress[0] < progress[1]:
				continue
			var ambition = GameData.ambitions()[id]
			f.ambitions_done.append(id)
			f.renown += ambition["renown"]
			if f.id == player_id:
				event.emit("Ambition achieved: %s. %s (+%d renown)" % [ambition["label"], ambition["description"], ambition["renown"]], "good")
			else:
				event.emit("The %s achieved \"%s\" (+%d renown)." % [f.display_name, ambition["label"], ambition["renown"]], "info")

# Daily wealth paid to each council member: a bigger faction's council expects more
func council_wage(faction_id: String) -> float:
	return GameData.rule("council_wage") + GameData.rule("council_wage_per_district") * districts_held(faction_id)

# The first time a faction's land touches the player's, say who they are
func _check_first_contacts():
	for fid in factions:
		if fid == player_id or player_met.has(fid) or not shares_border(player_id, fid):
			continue
		player_met[fid] = day
		var f: Faction = factions[fid]
		var who = f.blurb if f.blurb != "" else "One of the city's great factions."
		event.emit("First contact: the %s now border you. %s" % [f.display_name, who], "alert")
		major_event.emit("First contact: the %s" % f.display_name, "The %s now border you. %s

Their card is open in Diplomacy: see who leads them, how they see you, and what they'd accept." % [f.display_name, who], fid)
		first_contact.emit(fid)

func _first_name(sex: String) -> String:
	var pool: Array = GameData.names()["first_f" if sex == "f" else "first_m"]
	return pool[rng.randi() % pool.size()]
