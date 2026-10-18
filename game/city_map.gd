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

const SAVE_VERSION = 21
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
# Councillors' standing tasks (doc 13)
var tasks: Array[StandingTask] = []
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
# Factions whose first demand for tribute has already been shown as a pop-up
var demand_warned: Array = []
# Sim harness only (not saved): counts stops, grievance and land changing hands, see tools/balance_sim.gd
var sim_sink = null
# is_raider() answers, kept for the current day (not saved)
var raider_cache: Dictionary = {}
var raider_cache_day: int = -1
# war_enemies() answers, cleared whenever a war starts or ends (not saved)
var war_cache: Dictionary = {}
# shares_border() answers for the current day (not saved)
var border_cache: Dictionary = {}
var border_cache_day: int = -1
var day: int = 0
var rng := RandomNumberGenerator.new()
# Whose point of view the UI and alerts use
var player_id: String = ""
var player_defeated: bool = false

# Pass a dictionary from to_save() to restore a saved game; otherwise starts data/scenario.json.
# A seed (sim and tests only) makes a new game repeatable; without one every game is random
func _init(save_data: Dictionary = {}, seed_value: int = -1):
	_load_layout()
	if save_data.is_empty():
		if seed_value >= 0:
			rng.seed = seed_value
		else:
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
		# Gangs start at the bottom rung; the big factions start as Warlord crews
		f.government = "gang" if f.minor else "warlord"
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
	best.garrison = garrison_ceiling(best)

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
	home.garrison = garrison_ceiling(home)

# --- Queries ------------------------------------------------------------------

func faction_name(faction_id: String) -> String:
	return factions[faction_id].display_name if factions.has(faction_id) else "nobody"

# Land a faction holds: its own, unless an enemy occupies it, or an enemy'"'"'s that it occupies (an army advances from what it has taken)
func holds(faction_id: String, district: District) -> bool:
	if district.occupier != "":
		return district.occupier == faction_id
	return district.owner_id() == faction_id

func borders_territory(faction_id: String, district: District) -> bool:
	for n_id in district.neighbor_ids:
		if holds(faction_id, districts[n_id]):
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
	if district.occupier != "":
		return 0.0
	return GameData.rule("status_yield").get(district.get_control_status(), 0.0) * absorb_factor(district)

# Land just taken or settled yields a fraction of its worth until its people settle (doc 20)
func absorb_factor(district: District) -> float:
	var least: float = GameData.rule("absorb_min_yield")
	return least + (1.0 - least) * district.absorb

func has_venture_at(faction_id: String, district: District) -> bool:
	for v in ventures:
		if v.faction_id == faction_id and v.district == district:
			return true
	return false

# Raiders are a faction whose traits make raiding its first instinct (see FactionAI.temperament); nobody is
# labelled a raider, and a crew that stops raiding stops being one
func is_raider(faction_id: String) -> bool:
	# Asked for every border district on every AI move, so worked out once a day
	if raider_cache_day != day:
		raider_cache_day = day
		raider_cache.clear()
	if not raider_cache.has(faction_id):
		raider_cache[faction_id] = factions.has(faction_id) and FactionAI.temperament("harass", factions[faction_id]) >= GameData.rule("raider_temperament")
	return raider_cache[faction_id]

# How a faction behaves, in a word or two, read from the same trait leanings its AI uses
func faction_manner(faction_id: String) -> String:
	var f: Faction = factions[faction_id]
	if is_raider(faction_id):
		return "raiders"
	if FactionAI.temperament("buy", f) >= 1.5:
		return "traders"
	if FactionAI.temperament("control", f) >= 1.2:
		return "keeps to itself"
	return "independent"

# A venture's success chance as things stand now (it's rolled on these odds when it lands)
func venture_odds(v: ActiveVenture) -> float:
	var f: Faction = factions.get(v.faction_id)
	if f == null:
		return 0.0
	return VentureSystem.compute_odds(v.venture_id, f, v.district, self, v.target_id, character_by_id(v.leader_id), v.crew, v.funding)["odds"]

# How many defenders a faction could send to guard a district if it's attacked: its idle manpower, up to a full guard
func possible_defenders(faction_id: String) -> int:
	var f: Faction = factions.get(faction_id)
	if f == null:
		return 0
	return mini(int(f.manpower), int(GameData.venture("reinforce")["crew_range"][1]))

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
	# Asked for every pair on every diplomacy pass; land changes hands only when ventures land, so worked out once a day
	if border_cache_day != day:
		border_cache_day = day
		border_cache.clear()
	var key = a_id + "|" + b_id
	if not border_cache.has(key):
		var found = false
		for d in districts:
			if d.owner_id() == b_id and borders_territory(a_id, d):
				found = true
				break
		border_cache[key] = found
	return border_cache[key]

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
	# Asked thousands of times a day by the AI; kept until a war starts or ends, or a faction goes
	if not war_cache.has(faction_id):
		var enemies = []
		for fid in factions:
			if is_at_war(faction_id, fid):
				enemies.append(fid)
		war_cache[faction_id] = enemies
	return war_cache[faction_id]

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

func _stop(category: String, cause: String):
	if sim_sink != null:
		sim_sink.note(category, cause)

func _sim_grievance(d: District, source: String, amount: float):
	if sim_sink != null and amount != 0.0:
		sim_sink.grievance(d.id, source, amount)

func add_proposal(action_id: String, from_id: String):
	_stop("proposal", action_id)
	proposals.append({"action": action_id, "from": from_id, "expires_day": day + int(GameData.rule("proposal_expiry_days"))})
	if GameData.diplomacy_action(action_id)["kind"] == "demand":
		var price = Diplomacy._amount_text(Diplomacy.tribute_price(self, player_id, from_id))
		var text = "The %s demand tribute: %s, or they come and take it. Pay, and they leave you alone for %d days. Refuse, and their raids on you get +%d%% odds. Answer in Diplomacy (F4)." % [
			faction_name(from_id), price, GameData.diplomacy_action("demand")["spare_days"], roundi((GameData.rule("emboldened_odds") - 1.0) * 100)]
		# The first demand from a faction stops the game, so it can't slip past in the log
		if from_id not in demand_warned:
			demand_warned.append(from_id)
			major_event.emit("The %s demand tribute" % faction_name(from_id), text, from_id)
		else:
			event.emit(text, "alert")
		return
	if GameData.diplomacy_action(action_id)["kind"] == "tribute":
		var offered = Diplomacy._amount_text(Diplomacy.tribute_price(self, from_id, player_id))
		event.emit("The %s offer tribute (%s) if you stop raiding them for %d days. Accept or decline in Diplomacy (F4)." % [
			faction_name(from_id), offered, GameData.diplomacy_action("tribute")["spare_days"]], "alert")
		return
	event.emit("The %s propose %s. Answer in Diplomacy (F4)." % [faction_name(from_id), GameData.diplomacy_action(action_id).get("proposal", action_id)], "alert")

func answer_proposal(index: int, accept: bool, expired: bool = false):
	if index < 0 or index >= proposals.size():
		return
	var p = proposals[index]
	proposals.remove_at(index)
	_stop("proposal_expired" if expired else "proposal_answered", p["action"])
	if not factions.has(p["from"]):
		return
	# An ultimatum: give in, or it's war (a lapsed one is refused)
	if p["action"] == "ultimatum":
		answer_ultimatum(relation(p["from"], player_id), accept)
		return
	if accept and Diplomacy.check_action(self, p["action"], p["from"], player_id, true) == "":
		Diplomacy.form_treaty(self, p["action"], p["from"], player_id)
		Diplomacy.note_accepted(self, p["action"], p["from"], player_id)
	elif GameData.diplomacy_action(p["action"])["kind"] == "demand":
		Diplomacy._demand_refused(self, p["from"], player_id)
	else:
		change_opinion(p["from"], player_id, -5.0, "declined")
		Diplomacy.note_refusal(self, p["action"], p["from"], player_id)
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
		return "Tributaries can't start wars"
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
	# The attacker's allies stand with it too, so a weak faction with friends can press its claim (doc 15)
	for ally_id in factions:
		if ally_id != attacker_id and ally_id != defender_id and relation(attacker_id, ally_id).alliance:
			_join_war(ally_id, defender_id, attacker_id)

# Puts two factions at war (no checks); ends any treaties between them
func start_war(faction_id: String, target_id: String):
	var r = relation(faction_id, target_id)
	r.at_war = true
	war_cache.clear()
	r.war_start_day = day
	r.peace_offered_by = ""
	r.exhaustion = {r.a: 0.0, r.b: 0.0}
	r.peace_ready_told = false
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
	war_cache.clear()
	r.war_start_day = day
	r.peace_offered_by = ""
	r.exhaustion = {r.a: 0.0, r.b: 0.0}
	r.peace_ready_told = false
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
	war_cache.clear()
	r.peace_offered_by = ""
	# A white peace: any war goal lapses
	if not r.claim.is_empty():
		_claim_backed_off(r.claim["by"], r.other(r.claim["by"]))
	end_occupations_between(r.a, r.b)
	if sim_sink != null:
		sim_sink.war_end("white_peace", day - r.war_start_day)
	r.claim = {}
	r.war_points = 0.0
	r.truce_until_day = day + truce_days
	if r.involves(player_id):
		event.emit("Peace with the %s. A truce holds for %d days; borders stay where they are." % [
			faction_name(r.other(player_id)), truce_days], "alert")
	else:
		event.emit("The %s and the %s have made peace." % [faction_name(faction_id), faction_name(target_id)], "info")
	return ""

func offer_peace(faction_id: String, target_id: String):
	var r = relation(faction_id, target_id)
	# A standing offer (theirs or yours) is kept until the war ends: a second one must not replace it,
	# or two sides who both want peace overwrite each other for ever and neither can accept
	if not r.at_war or r.peace_offered_by != "":
		return
	r.peace_offered_by = faction_id
	if target_id == player_id:
		event.emit("The %s offer peace. Accept it in Diplomacy (F4), or fight on." % faction_name(faction_id), "alert")

# --- The cost of growth (doc 20, W2): reach and infamy -------------------------------------------

# Districts held per faction and each faction's reach, worked out once a day (not saved)
var held_cache: Dictionary = {}
var reach_cache: Dictionary = {}

# How many districts a faction can hold comfortably: what its council can administer. Past it, every district grumbles
func reach(faction_id: String) -> float:
	var seated = 0
	var best_steward = 0
	for c in characters_of(faction_id):
		if c.post != "":
			seated += 1
			best_steward = maxi(best_steward, int(c.skills["stewardship"]))
	return GameData.rule("reach_base") + seated * GameData.rule("reach_per_councillor") + best_steward * GameData.rule("reach_per_stewardship") + factions[faction_id].effect("reach_bonus")

func _reach_today(faction_id: String) -> float:
	if not reach_cache.has(faction_id):
		reach_cache[faction_id] = reach(faction_id)
	return reach_cache[faction_id]

# Grievance a day on each district still settling in, for holding more than the reach (0 when within it)
func strain_daily(faction_id: String) -> float:
	var over: float = held_cache.get(faction_id, 0) - _reach_today(faction_id)
	return minf(GameData.rule("reach_grievance_cap"), over * GameData.rule("reach_grievance_daily")) if over > 0.0 else 0.0

# The districts that carry the strain: yours, not occupied, still settling in
func strained_districts(faction_id: String) -> Array:
	return districts.filter(func(d): return d.owner_id() == faction_id and d.occupier == "" and d.absorb < 1.0)

func add_infamy(faction_id: String, amount: float):
	if factions.has(faction_id) and amount > 0.0:
		factions[faction_id].infamy = minf(200.0, factions[faction_id].infamy + amount)

# Everyone thinks a little less of a notorious faction each month, more the worse it is
func _infamy_opinions():
	for f in factions.values():
		if f.infamy < 5.0:
			continue
		for other in factions:
			if other != f.id:
				change_opinion(other, f.id, -f.infamy * GameData.rule("infamy_opinion_factor"), "notorious")

# What winning a war goal earns in infamy: the goal's weight, more with no cause, more against a faction that liked you
func _war_infamy(r: Relation):
	var by: String = r.claim["by"]
	var amount: float = GameData.rule("infamy_goal")[r.claim["goal"]]
	if r.claim.get("reason", "") == "":
		amount *= GameData.rule("infamy_no_cause_mult")
	if r.claim.get("friendly", false):
		amount *= GameData.rule("infamy_friendly_mult")
	add_infamy(by, amount)

func venture_id_is_raid(v: ActiveVenture) -> bool:
	return v.venture_id == "raid"

# --- Occupation (doc 20) ------------------------------------------------------------------------
# An assault takes a district's keeping, not its ownership: ownership changes only at the peace table.
# An occupied district pays nobody, its buildings stand idle, nothing can be launched there, and the
# crew who took it stay as its garrison (manpower tied up). Peace, or a successful assault by the owner, ends it.

func occupy(d: District, by_id: String, crew: int):
	var owner = d.owner_id()
	d.occupier = by_id
	d.occupied_day = day
	d.garrison = float(crew)
	if owner != "":
		add_exhaustion(owner, by_id, GameData.rule("occupation_exhaustion"))
	if sim_sink != null:
		sim_sink.occupied(d.id, by_id)
	if by_id == player_id:
		event.emit("You occupy %s: it pays nobody until the war is settled. %d of your crew stay to hold it." % [d.district_name, crew], "good")
	elif owner == player_id:
		event.emit("The %s have occupied %s: it pays you nothing until you retake it or the war is settled." % [faction_name(by_id), d.district_name], "alert")
	else:
		event.emit("The %s have occupied %s, held by the %s." % [faction_name(by_id), d.district_name, faction_name(owner)], "info")

# The occupation ends: the occupier's crew go home (unless they were beaten), the owner's garrison starts again from nothing
func release_occupation(d: District, crew_home: bool):
	if d.occupier == "":
		return
	if crew_home and factions.has(d.occupier):
		factions[d.occupier].manpower += d.garrison
	d.occupier = ""
	d.garrison = 0.0

# The owner drives the occupiers out: the crew who did it stay as the garrison
func liberate(d: District, by_id: String, crew: int):
	var occupier = d.occupier
	release_occupation(d, false)
	d.garrison = float(crew)
	if sim_sink != null:
		sim_sink.liberated(d.id, by_id)
	if by_id == player_id:
		event.emit("You have retaken %s from the %s." % [d.district_name, faction_name(occupier)], "good")
	elif d.owner_id() == player_id or occupier == player_id:
		event.emit("%s has been retaken by the %s." % [d.district_name, faction_name(by_id)], "alert" if occupier == player_id else "good")

func occupied_by(by_id: String, of_id: String) -> Array:
	return districts.filter(func(d): return d.occupier == by_id and d.owner_id() == of_id)

func end_occupations_between(a_id: String, b_id: String):
	for d in districts:
		if d.occupier != "" and ((d.occupier == a_id and d.owner_id() == b_id) or (d.occupier == b_id and d.owner_id() == a_id)):
			release_occupation(d, true)

# Whoever stops being at war with the occupier, or stops owning, ends the occupation
func _check_occupation(d: District):
	var owner = d.owner_id()
	if owner == "" or owner == d.occupier or not factions.has(d.occupier) or not is_at_war(owner, d.occupier):
		release_occupation(d, true)

# --- War goals and ultimatums (doc 15, P2) -------------------------------------------------
# No war without a goal: the claimant justifies it over some days (the target is told at once), then sends an
# ultimatum. Accepted, the terms apply without a fight; refused, it's war over that goal, ended when the war
# score reaches its price, a side is worn out, or by a white peace. Civil wars and allies joining in have no goal.

const WAR_GOALS = ["claim", "subjugate", "vassalize"]

# Why this faction has cause against the target ("" if none): a reason halves the justification
func claim_reason(faction_id: String, target_id: String) -> String:
	var r = relation(faction_id, target_id)
	if r.last_raid[target_id] > 0 and day - r.last_raid[target_id] <= int(GameData.rule("menace_memory_days")):
		return "they raided you"
	if r.last_demand[target_id] > 0 and day - r.last_demand[target_id] <= int(GameData.rule("menace_memory_days")):
		return "they demanded tribute of you"
	if opinion_of(target_id, faction_id) < -25.0 or opinion_of(faction_id, target_id) < -25.0:
		return "bad blood between you"
	return ""

# The district a claim would name: the one picked, if it can be, or their most populous on your border
func claim_district(faction_id: String, target_id: String, preferred: District = null) -> District:
	if preferred and preferred.owner_id() == target_id and borders_territory(faction_id, preferred):
		return preferred
	var best: District = null
	for d in districts:
		if d.owner_id() == target_id and borders_territory(faction_id, d) and (best == null or d.population > best.population):
			best = d
	return best

func justify_days(faction_id: String, target_id: String, goal_id: String) -> int:
	var days = int(GameData.war_goal(goal_id)["justify_days"])
	return days if claim_reason(faction_id, target_id) != "" else int(days * GameData.rule("claim_no_reason_mult"))

# What justifying costs: the goal's renown and wealth, half with a reason (a faction that's raided has its cause)
func justify_cost(faction_id: String, target_id: String, goal_id: String) -> Dictionary:
	var cost: Dictionary = GameData.war_goal(goal_id)["cost"].duplicate()
	if claim_reason(faction_id, target_id) != "":
		for resource_type in cost:
			cost[resource_type] = ceilf(cost[resource_type] / 2.0)
	return cost

# The promise a claim would break ("" if none): a pact, an alliance or a truce. It doesn't stop you;
# breaking your word costs your name with everyone for years
func oath_broken(faction_id: String, target_id: String) -> String:
	var r = relation(faction_id, target_id)
	if marriage_tie(faction_id, target_id):
		return "the marriage between your families"
	if r.alliance:
		return "your alliance"
	if r.pact:
		return "your non-aggression pact"
	if day < r.truce_until_day:
		return "the truce"
	return ""

# "" if this faction can start justifying this goal against the target, otherwise why not
func check_justify(faction_id: String, target_id: String, goal_id: String, district: District = null) -> String:
	if faction_id == target_id or not factions.has(target_id) or goal_id not in WAR_GOALS:
		return "No such faction"
	var r = relation(faction_id, target_id)
	if not r.claim.is_empty():
		return "A claim between you is already under way"
	for other in factions:
		if other != faction_id and relation(faction_id, other).claim.get("by", "") == faction_id and relation(faction_id, other).claim["stage"] != "war":
			return "You're already pressing a claim on the %s" % faction_name(other)
	if r.at_war:
		return "Already at war"
	if overlord_of(faction_id) != "":
		return "Tributaries can't start wars"
	if r.overlord == faction_id:
		return "They're already your tributary (absorb them in Diplomacy instead)"
	# Their strength doesn't stop you (the war decides), nor does a treaty or truce (it costs your name: see justify)
	if not shares_border(faction_id, target_id):
		return "You don't share a border with them"
	if GameData.war_goal(goal_id)["needs_district"] and claim_district(faction_id, target_id, district) == null:
		return "None of their districts borders yours"
	return factions[faction_id].shortfall(justify_cost(faction_id, target_id, goal_id))

func justify(faction_id: String, target_id: String, goal_id: String, district: District = null) -> String:
	var err = check_justify(faction_id, target_id, goal_id, district)
	if err != "":
		return err
	var r = relation(faction_id, target_id)
	var reason = claim_reason(faction_id, target_id)
	var d = claim_district(faction_id, target_id, district) if GameData.war_goal(goal_id)["needs_district"] else null
	var days = justify_days(faction_id, target_id, goal_id)
	factions[faction_id].pay(justify_cost(faction_id, target_id, goal_id))
	# Breaking a treaty or truce to press a claim: allowed, but everyone remembers it for years
	var oath = oath_broken(faction_id, target_id)
	if oath != "":
		if r.pact or r.alliance:
			Diplomacy.break_treaty(self, faction_id, target_id, "pact")
		r.truce_until_day = day
		for other in factions:
			if other != faction_id:
				change_opinion(other, faction_id, GameData.rule("claim_oathbreaker_opinion"), "oathbreaker")
		add_infamy(faction_id, GameData.rule("infamy_oath"))
		event.emit("The %s broke %s with the %s to press a claim. Everyone will remember it for years." % [
			faction_name(faction_id), oath.replace("your", "their"), faction_name(target_id)], "alert" if player_id in [faction_id, target_id] else "info")
	r.claim = {"by": faction_id, "goal": goal_id, "district": d.id if d else -1, "reason": reason, "stage": "justifying",
		"ready_day": day + days, "started": day, "told_early": false, "deadline": 0}
	r.claim["start_ratio"] = claim_strength_ratio(r)
	r.claim["friendly"] = opinion_of(target_id, faction_id) >= 20.0
	r.claim["start_their_strength"] = faction_strength(target_id)
	r.claim["step"] = strength_step(1.0 / maxf(0.01, r.claim["start_ratio"]))
	r.war_points = 0.0
	# The target resents it; onlookers think less of a faction that presses claims, more so without cause
	change_opinion(target_id, faction_id, GameData.rule("claim_target_opinion"), "claimed_us")
	for other in factions:
		if other != faction_id and other != target_id:
			change_opinion(other, faction_id, GameData.rule("claim_onlooker_opinion" if reason != "" else "claim_unjust_opinion"), "warmonger")
	var what = claim_text(r, player_id)
	if target_id == player_id:
		event.emit("The %s are justifying a claim on you: %s%s. Their ultimatum comes in %d to %d days: no sooner than the notice, and sooner than the latest only if their side grows strong enough. See the claim marker under the top bar." % [faction_name(faction_id), what,
			(" (because %s)" % reason) if reason != "" else " (with no cause: everyone thinks less of them)", mini(int(GameData.rule("min_claim_notice_days")), days), days], "alert")
	elif faction_id == player_id:
		event.emit("You're justifying a claim on the %s: %s. Your ultimatum goes out in %d days%s." % [faction_name(target_id), what, days,
			"" if reason != "" else " (no cause: half as long again, full price, and everyone thinks less of you)"], "info")
	else:
		event.emit("The %s are justifying a claim on the %s: %s." % [faction_name(faction_id), faction_name(target_id), what], "info")
	return ""

# The claim in words: "claim Pylon Fields", "make them a tributary", "absorb them" ("you" when it's the viewer's side)
func claim_text(r: Relation, viewer_id: String = "") -> String:
	var them = "you" if viewer_id != "" and viewer_id == claim_target(r) else "them"
	match r.claim.get("goal", ""):
		"claim":
			return "claim %s" % districts[int(r.claim["district"])].district_name
		"subjugate":
			return "make %s a tributary" % them
		"vassalize":
			return "absorb %s" % them
	return ""

# The side a claim is pressed against
func claim_target(r: Relation) -> String:
	return r.other(r.claim["by"])

# War score from the claimant's side, -100 to 100 (doc 20): land occupied, fights won, the clock, and who's more worn down
func war_score(r: Relation) -> float:
	if r.claim.is_empty():
		return 0.0
	return war_score_parts(r)["total"]

# The parts of the score, for the war window: occupation (the share of the other's districts you hold, with a bonus
# for their home), battles (capped), a clock that favours the attacker at once and the defender after a delay, exhaustion
func war_score_parts(r: Relation) -> Dictionary:
	var by: String = r.claim["by"]
	var against = r.other(by)
	var days = day - r.war_start_day
	var rate: float = GameData.rule("war_tick_daily")
	var parts = {
		"occupation_for": occupation_score(by, against),
		"occupation_against": occupation_score(against, by),
		"battles": clampf(r.war_points, -GameData.rule("war_battle_cap_defender"), GameData.rule("war_battle_cap_attacker")),
		"clock_for": days * rate,
		"clock_against": maxf(0.0, days - GameData.rule("war_tick_defender_delay")) * rate,
		"exhaustion": (r.exhaustion[against] - r.exhaustion[by]) * GameData.rule("war_score_exhaustion")}
	parts["total"] = clampf(parts["occupation_for"] - parts["occupation_against"] + parts["battles"] + parts["clock_for"] - parts["clock_against"] + parts["exhaustion"], -100.0, 100.0)
	return parts

# What holding the other's districts is worth: their share held, times the scale, plus a bonus for their home
func occupation_score(holder_id: String, owner_id: String) -> float:
	var owned = districts_held(owner_id)
	if owned <= 0 or not factions.has(owner_id):
		return 0.0
	var score: float = GameData.rule("war_occupation_scale") * float(occupied_by(holder_id, owner_id).size()) / owned
	var home: int = factions[owner_id].home_id
	if home >= 0 and districts[home].occupier == holder_id and districts[home].owner_id() == owner_id:
		score += GameData.rule("war_home_bonus")
	return score

# Chance an AI target gives in to an ultimatum: likelier the more the claimant outweighs it and its friends,
# less likely the harsher the goal
func ultimatum_acceptance(r: Relation) -> float:
	return acceptance_of_goal(r.claim["by"], r.other(r.claim["by"]), r.claim["goal"])

func acceptance_of_goal(by: String, against: String, goal_id: String) -> float:
	var ratio = side_strength(by, against) / maxf(1.0, side_strength(against, by))
	var need: float = GameData.war_goal(goal_id)["accept_need"]
	# Giving up a district is easier than giving up your independence, or your existence
	return clampf(0.5 + (ratio - need) / need, 0.05, GameData.war_goal(goal_id)["accept_max"])

# A faction's strength in a quarrel with `enemy_id`, counting the friends who'd fight beside it:
# allies and backers of its claim in full, tributaries at the share of their force they bring
func side_strength(faction_id: String, enemy_id: String) -> float:
	var total = faction_strength(faction_id)
	var backers: Array = claim_backers(faction_id, enemy_id)
	for fid in factions:
		if fid == faction_id or fid == enemy_id:
			continue
		var r = relation(faction_id, fid)
		if r.alliance or r.overlord == fid or fid in backers:
			total += faction_strength(fid)
		elif r.overlord == faction_id:
			total += faction_strength(fid) * GameData.rule("tributary_war_share")
	return total

# Factions that have promised to back this faction's claim on `enemy_id`
func claim_backers(faction_id: String, enemy_id: String) -> Array:
	var r = relation(faction_id, enemy_id)
	if r.claim.get("by", "") != faction_id:
		return []
	return r.claim.get("backers", []).filter(func(fid): return factions.has(fid))

# How many times the other side the claimant's side is (with friends and backers), against what the goal needs
func claim_strength_ratio(r: Relation) -> float:
	var by: String = r.claim["by"]
	return side_strength(by, r.other(by)) / maxf(1.0, side_strength(r.other(by), by))

# "90 to 180 days" or "180 days": when the ultimatum can come, for every place that says so
func claim_clock(r: Relation) -> String:
	var latest = int(r.claim["ready_day"]) - day
	var left = claim_notice_left(r)
	if left >= latest:
		return "%d days" % latest
	return "up to %d days" % latest if left <= 0 else "%d to %d days" % [left, latest]

# --- What a war goal would mean, for the war goal window (doc 19) --------------------------------

const STRENGTH_WORDS = ["much weaker than", "weaker than", "similar to", "stronger than", "much stronger than"]

# Their side against yours in five steps (0 much weaker .. 4 much stronger); the ratio is theirs over yours
func strength_step(their_over_your: float) -> int:
	if their_over_your < 0.5:
		return 0
	if their_over_your < 0.8:
		return 1
	if their_over_your <= 1.25:
		return 2
	if their_over_your <= 2.0:
		return 3
	return 4

# Their side over yours, counting each side's friends (and the backers of a claim already under way)
func their_over_your(faction_id: String, target_id: String) -> float:
	return side_strength(target_id, faction_id) / maxf(1.0, side_strength(faction_id, target_id))

# The districts of `target_id` that border `faction_id`'s land: what "Acquire" can name
func claim_candidates(faction_id: String, target_id: String) -> Array:
	return districts.filter(func(d): return d.owner_id() == target_id and borders_territory(faction_id, d))

# Who would be called into a war between the two if it began now: [the attacker's side, the defender's side]
func war_sides(attacker_id: String, defender_id: String) -> Array:
	var mine = []
	var theirs = []
	for fid in defenders_of(defender_id):
		if _could_join(fid, attacker_id) and fid not in theirs:
			theirs.append(fid)
	for fid in vassals_of(attacker_id):
		if _could_join(fid, defender_id) and fid not in mine:
			mine.append(fid)
	for fid in factions:
		if fid != attacker_id and fid != defender_id and relation(attacker_id, fid).alliance and _could_join(fid, defender_id) and fid not in mine:
			mine.append(fid)
	for fid in claim_backers(attacker_id, defender_id):
		if fid not in mine:
			mine.append(fid)
	return [mine, theirs]

func _could_join(joiner_id: String, enemy_id: String) -> bool:
	return joiner_id != enemy_id and not is_at_war(joiner_id, enemy_id) and not relation(joiner_id, enemy_id).protected()

func cost_words(cost: Dictionary) -> String:
	var parts = []
	for resource_type in cost:
		parts.append("%d %s" % [cost[resource_type], resource_type])
	return ", ".join(parts) if not parts.is_empty() else "free"

# What each ending of a war goal would mean, as lines of [tone, text] (tone "good", "bad" or "plain")
func goal_outcomes(target_id: String, goal_id: String, d: District) -> Dictionary:
	var goal = GameData.war_goal(goal_id)
	var tname = faction_name(target_id)
	var win = [["plain", "If they give in at the ultimatum there is no war. If they refuse, it is war until the score reaches %d." % goal["price"]]]
	match goal_id:
		"claim":
			if d:
				var spoils = (", with its %s" % ", ".join(d.building_labels())) if not d.buildings.is_empty() else ""
				win.append(["good", "%s is yours: %d people%s. Its garrison is cleared." % [d.district_name, d.population, spoils]])
		"subjugate":
			win.append(["good", "The %s become your tributary: they keep their land and ruler and send you %d%% of their income in food, materials and wealth." % [tname, GameData.rule("tribute_rate") * 100]])
			win.append(["plain", "They trade only and start no wars."])
		"vassalize":
			win.append(["good", "The %s are absorbed: their %d districts, people and stores become yours, and their ruling family becomes a house of yours." % [tname, districts_held(target_id)]])
	var lose = [
		["bad", "If your side is worn out first you pay reparations, up to %d wealth." % GameData.rule("war_defeat_wealth")],
		["bad", "Everything you paid to press the claim is gone."],
		["plain", "They keep what they hold. A truce of %d days follows." % GameData.rule("truce_days")]]
	return {"win": win, "lose": lose}

# The requirements for pressing a goal, as [state, text] (state "ok", "warn" or "no"): ticks and crosses for the window
func justify_requirements(faction_id: String, target_id: String, goal_id: String, d: District) -> Array:
	var list = []
	var goal = GameData.war_goal(goal_id)
	var borders = shares_border(faction_id, target_id)
	list.append(["ok" if borders else "no", "You share a border with them" if borders else "You don't share a border with them yet"])
	if goal["needs_district"]:
		list.append(["ok" if d != null else "no", ("%s borders your land" % d.district_name) if d != null else "None of their districts borders yours"])
	var cost = justify_cost(faction_id, target_id, goal_id)
	var short = factions[faction_id].shortfall(cost)
	list.append(["ok" if short == "" else "no", ("You can pay %s" % cost_words(cost)) if short == "" else short])
	var reason = claim_reason(faction_id, target_id)
	if reason != "":
		list.append(["ok", "You have cause (%s): half price, and quicker" % reason])
	else:
		list.append(["warn", "No cause: half as long again, full price, and everyone thinks less of you"])
	var oath = oath_broken(faction_id, target_id)
	if oath != "":
		list.append(["warn", "Breaks %s: every faction thinks much less of you for years" % oath])
	var err = check_justify(faction_id, target_id, goal_id, d)
	if err != "" and err != short and borders and not (goal["needs_district"] and d == null):
		list.append(["no", err])
	return list

# Your own claim under way: when the balance turns against it, say so once, and again if it recovers and turns again
func _watch_own_claim(r: Relation):
	var by: String = r.claim["by"]
	var step = strength_step(1.0 / maxf(0.01, claim_strength_ratio(r)))
	if step > int(r.claim.get("step", step)):
		event.emit("The balance has turned against your claim on the %s: their side is now %s yours. Open the claim to hold or back down." % [
			faction_name(r.other(by)), STRENGTH_WORDS[step]], "alert")
	r.claim["step"] = step

# Days of the minimum notice still to run before an early ultimatum may go out (0 once served)
func claim_notice_left(r: Relation) -> int:
	return maxi(0, int(r.claim.get("started", r.claim.get("ready_day", 0))) + int(GameData.rule("min_claim_notice_days")) - day)

# What a claim on `viewer_id` means right now, in words: the earliest and latest ultimatum, what could bring it sooner, who backs it
func claim_notice_text(r: Relation, viewer_id: String) -> String:
	var by: String = r.claim["by"]
	var latest = int(r.claim["ready_day"]) - day
	var text = "The %s are justifying a claim: %s." % [faction_name(by), claim_text(r, viewer_id)]
	var left = claim_notice_left(r)
	if left >= latest:
		text += "\nTheir ultimatum comes in %d days." % latest
	else:
		var need: float = GameData.war_goal(r.claim["goal"])["accept_need"]
		var ratio = claim_strength_ratio(r)
		if left <= 0:
			text += "\nTheir ultimatum comes within %d days, and any day their side (with backers and friends) is %.1fx yours or more: it is %.1fx now." % [latest, need, ratio]
		else:
			text += "\nTheir ultimatum comes between %d and %d days from now. It can come early only when their side (with backers and friends) is %.1fx yours or more: it is %.1fx now." % [left, latest, need, ratio]
	var backers = claim_backers(by, r.other(by)).map(func(fid): return faction_name(fid))
	text += "\nBackers: %s." % (", ".join(backers) if not backers.is_empty() else "none")
	return text

# "" if the claimant can send its ultimatum before the claim is fully justified: only when its side is strong
# enough that the target would likely give in (the strength the goal needs)
func check_send_early(faction_id: String, other_id: String) -> String:
	var r = relation(faction_id, other_id)
	if r.claim.get("by", "") != faction_id or r.claim["stage"] != "justifying":
		return "You have no claim being justified against them"
	var notice_left = claim_notice_left(r)
	if notice_left > 0:
		return "The notice runs %d more days (%d days must pass before an early ultimatum)" % [notice_left, GameData.rule("min_claim_notice_days")]
	var need: float = GameData.war_goal(r.claim["goal"])["accept_need"]
	var ratio = claim_strength_ratio(r)
	if ratio < need:
		return "You need %.1fx their strength to send it early (you're %.1fx with your friends and backers)" % [need, ratio]
	return ""

func send_ultimatum_early(faction_id: String, other_id: String) -> String:
	var err = check_send_early(faction_id, other_id)
	if err != "":
		return err
	if faction_id == player_id:
		event.emit("You send your ultimatum to the %s early: your strength makes the case." % faction_name(other_id), "info")
	_send_ultimatum(relation(faction_id, other_id))
	return ""

# The claimant drops its claim before any war (what it paid is gone; the grudge fades in time)
func withdraw_claim(faction_id: String, other_id: String) -> String:
	var r = relation(faction_id, other_id)
	if r.claim.get("by", "") != faction_id or r.claim["stage"] == "war":
		return "You have no claim to withdraw against them"
	proposals = proposals.filter(func(p): return not (p["action"] == "ultimatum" and p["from"] == faction_id))
	r.claim = {}
	_claim_backed_off(faction_id, other_id)
	event.emit("The %s withdrew their claim on the %s." % [faction_name(faction_id), faction_name(other_id)], "info")
	return ""

# Another faction promises to back a claim: it counts toward the claimant's strength and joins the war if it comes
func add_backer(claimant_id: String, backer_id: String) -> String:
	for fid in factions:
		var r = relation(claimant_id, fid)
		if fid != claimant_id and fid != backer_id and r.claim.get("by", "") == claimant_id and r.claim["stage"] != "war":
			var backers: Array = r.claim.get("backers", [])
			if backer_id not in backers:
				backers.append(backer_id)
			r.claim["backers"] = backers
			event.emit("The %s will back the %s's claim on the %s." % [faction_name(backer_id), faction_name(claimant_id), faction_name(fid)],
				"good" if claimant_id == player_id else ("alert" if fid == player_id else "info"))
			return fid
	return ""

# The claim this faction is pressing (not yet at war), as its target's id ("" if none)
func pressing_claim_on(faction_id: String) -> String:
	for fid in factions:
		if fid != faction_id:
			var r = relation(faction_id, fid)
			if r.claim.get("by", "") == faction_id and r.claim["stage"] != "war":
				return fid
	return ""

# The claim is justified: the ultimatum goes out. The player answers theirs; the AI decides on the odds
func _send_ultimatum(r: Relation):
	var by: String = r.claim["by"]
	var against = claim_target(r)
	r.claim["stage"] = "ultimatum"
	r.claim["deadline"] = day + int(GameData.rule("ultimatum_days"))
	var demand = String(GameData.war_goal(r.claim["goal"])["demand"]).replace("{district}", districts[int(r.claim["district"])].district_name if int(r.claim["district"]) >= 0 else "")
	if against == player_id:
		_stop("proposal", "ultimatum")
	if against == player_id and factions[against].ai == null:
		proposals.append({"action": "ultimatum", "from": by, "expires_day": r.claim["deadline"]})
		major_event.emit("Ultimatum from the %s" % faction_name(by), "The %s demand that you %s. Accept and it's done, with no fight. Refuse, or let %d days pass, and it's war over it.\n\nAnswer in Diplomacy (F4), Proposals." % [
			faction_name(by), demand, GameData.rule("ultimatum_days")], by)
		return
	if against == player_id:
		_stop("proposal_answered", "ultimatum")
	answer_ultimatum(r, rng.randf() < ultimatum_acceptance(r))

func answer_ultimatum(r: Relation, accept: bool):
	if r.claim.is_empty() or r.claim["stage"] != "ultimatum":
		return
	var by: String = r.claim["by"]
	var against = claim_target(r)
	proposals = proposals.filter(func(p): return not (p["action"] == "ultimatum" and p["from"] == by))
	if accept:
		var text = "The %s gave in to the %s's ultimatum: %s." % [faction_name(against), faction_name(by), claim_text(r, player_id)]
		event.emit(text, "good" if by == player_id else ("bad" if against == player_id else "info"))
		_apply_war_goal(r)
		r.claim = {}
		r.truce_until_day = day + int(GameData.rule("truce_war_days"))
		return
	r.claim["stage"] = "war"
	r.war_points = 0.0
	start_war(by, against)
	call_to_arms(by, against)
	# Those who promised to back the claim keep their word
	for backer_id in r.claim.get("backers", []):
		if factions.has(backer_id):
			_join_war(backer_id, against, by)
	if by == player_id or against == player_id:
		event.emit("The %s refused the ultimatum: war with the %s over it (%s). The war ends when the war score reaches %d, a side is worn out, or by peace." % [
			faction_name(against), faction_name(by if against == player_id else against), claim_text(r, player_id), GameData.war_goal(r.claim["goal"])["price"]], "alert")

# "" if the claimant can end the war on its terms now, otherwise why not
func check_enforce(faction_id: String, other_id: String) -> String:
	var r = relation(faction_id, other_id)
	if r.claim.is_empty() or r.claim["stage"] != "war" or r.claim["by"] != faction_id:
		return "You have no war goal against them"
	var price: float = GameData.war_goal(r.claim["goal"])["price"]
	if war_score(r) >= price:
		return ""
	if r.claim["goal"] == "vassalize" and factions.has(other_id) and districts[factions[other_id].home_id].occupier == faction_id:
		return ""
	return "War score %d of %d needed" % [war_score(r), price]

# --- The peace table (doc 20) -------------------------------------------------------------------
# The claimant spends war score on demands: the war goal first, then other districts it occupies, then tribute.
# No consent is needed once the score allows it. A white peace is the status quo and needs the other side to agree.

func peace_district_cost(d: District) -> float:
	return GameData.rule("peace_district_cost") + d.population * GameData.rule("peace_district_cost_per_people")

# What the claimant could demand now: [{"id", "label", "cost", "kind" ("goal", "district" or "tribute")}]
func peace_demands(faction_id: String, other_id: String) -> Array:
	var r = relation(faction_id, other_id)
	var list = []
	if r.claim.get("stage", "") == "war" and r.claim["by"] == other_id:
		return held_demands(faction_id, other_id)
	if r.claim.get("stage", "") != "war" or r.claim["by"] != faction_id:
		return list
	var goal = GameData.war_goal(r.claim["goal"])
	list.append({"id": "goal", "label": claim_text(r, faction_id), "cost": float(goal["price"]), "kind": "goal"})
	# The faction absorbed whole has nothing left to take
	if r.claim["goal"] == "vassalize":
		return list
	for d in occupied_by(faction_id, other_id):
		if r.claim["goal"] == "claim" and d.id == int(r.claim["district"]):
			continue
		list.append({"id": "d:%d" % d.id, "label": "Take %s" % d.district_name, "cost": peace_district_cost(d), "kind": "district"})
	var wealth = minf(float(GameData.rule("peace_tribute_wealth")), factions[other_id].wealth)
	list.append({"id": "tribute", "label": "Tribute of %d wealth" % wealth, "cost": float(GameData.rule("peace_tribute_cost")), "kind": "tribute"})
	return list

# The demands an AI takes: the goal, then what the remaining score buys, cheapest first
func auto_demands(faction_id: String, other_id: String) -> Array:
	var r = relation(faction_id, other_id)
	var demands = peace_demands(faction_id, other_id)
	if demands.is_empty():
		return []
	var budget = side_score(r, faction_id) - demands[0]["cost"]
	var extras = demands.slice(1)
	extras.sort_custom(func(a, b): return a["cost"] < b["cost"])
	var picks = []
	for e in extras:
		if e["cost"] <= budget:
			picks.append(e["id"])
			budget -= e["cost"]
	return picks

# Take your terms: the goal and the demands picked, paid for in war score. Ends the war with a long truce
func enforce_claim(faction_id: String, other_id: String, picks: Array = []) -> String:
	var err = check_enforce(faction_id, other_id)
	if err != "":
		return err
	var r = relation(faction_id, other_id)
	var demands = peace_demands(faction_id, other_id)
	var budget = war_score(r) - demands[0]["cost"]
	var chosen = []
	for id in picks:
		for demand in demands:
			if demand["id"] == id and id != "goal":
				chosen.append(demand)
	var spend = 0.0
	for demand in chosen:
		spend += demand["cost"]
	if spend > maxf(budget, 0.0):
		return "Those demands cost %d war score; you have %d to spend after the goal" % [spend, maxf(budget, 0.0)]
	var by = faction_id
	for demand in chosen:
		if demand["kind"] == "district":
			_transfer_district(districts[int(demand["id"].substr(2))], by)
			add_infamy(by, GameData.rule("infamy_extra_district"))
		elif demand["kind"] == "tribute":
			var wealth = minf(float(GameData.rule("peace_tribute_wealth")), factions[other_id].wealth)
			factions[other_id].wealth -= wealth
			factions[by].wealth += wealth
	_end_claim_war(r, true)
	return ""

# War score from one side's view: positive when that side is ahead
func side_score(r: Relation, faction_id: String) -> float:
	if r.claim.is_empty():
		return 0.0
	return war_score(r) * (1.0 if r.claim["by"] == faction_id else -1.0)

# A defender who has held out (the score is far enough their way) may dictate terms (doc 20, defender's victory):
# the claim fails and the claimant pays reparations; spare score buys the districts the defender holds, or tribute
func check_hold(faction_id: String, other_id: String) -> String:
	var r = relation(faction_id, other_id)
	if r.claim.get("stage", "") != "war" or r.claim["by"] != other_id:
		return "They have no war goal against you"
	var need: float = GameData.rule("held_price")
	if side_score(r, faction_id) >= need:
		return ""
	return "War score %d of %d needed. Hold their raids off, occupy their districts, or outlast them" % [side_score(r, faction_id), need]

func held_demands(defender_id: String, claimant_id: String) -> Array:
	var reparations = minf(float(GameData.rule("war_defeat_wealth")), factions[claimant_id].wealth)
	var list = [{"id": "goal", "label": "Their claim fails and they pay %d wealth" % reparations, "cost": float(GameData.rule("held_price")), "kind": "goal"}]
	for d in occupied_by(defender_id, claimant_id):
		list.append({"id": "d:%d" % d.id, "label": "Take %s" % d.district_name, "cost": peace_district_cost(d), "kind": "district"})
	var wealth = minf(float(GameData.rule("peace_tribute_wealth")), factions[claimant_id].wealth)
	list.append({"id": "tribute", "label": "More tribute: %d wealth" % wealth, "cost": float(GameData.rule("peace_tribute_cost")), "kind": "tribute"})
	return list

func enforce_hold(defender_id: String, claimant_id: String, picks: Array = []) -> String:
	var err = check_hold(defender_id, claimant_id)
	if err != "":
		return err
	var r = relation(defender_id, claimant_id)
	var demands = held_demands(defender_id, claimant_id)
	var budget = side_score(r, defender_id) - demands[0]["cost"]
	var chosen = []
	var spend = 0.0
	for id in picks:
		for demand in demands:
			if demand["id"] == id and id != "goal":
				chosen.append(demand)
				spend += demand["cost"]
	if spend > maxf(budget, 0.0):
		return "Those demands cost %d war score; you have %d to spend after the goal" % [spend, maxf(budget, 0.0)]
	for demand in chosen:
		if demand["kind"] == "district":
			_transfer_district(districts[int(demand["id"].substr(2))], defender_id)
			add_infamy(defender_id, GameData.rule("infamy_extra_district"))
		elif demand["kind"] == "tribute":
			var wealth = minf(float(GameData.rule("peace_tribute_wealth")), factions[claimant_id].wealth)
			factions[claimant_id].wealth -= wealth
			factions[defender_id].wealth += wealth
	_end_claim_war(r, false)
	return ""

# A district changes hands at the peace table (the only place ownership changes in a war)
func _transfer_district(d: District, to_id: String):
	var owner_before = d.owner_id()
	release_occupation(d, true)
	var share = maxf(d.share(owner_before), 51.0)
	d.influence.erase(owner_before)
	d.add_influence(to_id, share)
	d.garrison = 0.0
	_announce_ownership_change(d, owner_before, to_id)

# Pressing a claim and then backing off (withdrawing, or a white peace) costs the one who pressed it, and brings a truce
func _claim_backed_off(by_id: String, against_id: String):
	if not factions.has(by_id) or not factions.has(against_id):
		return
	var f: Faction = factions[by_id]
	var lost = minf(f.renown, float(GameData.rule("claim_failed_renown")))
	f.renown -= lost
	change_opinion(against_id, by_id, -10.0, "backed_off")
	for other in factions:
		if other != by_id and other != against_id:
			change_opinion(other, by_id, -3.0, "backed_off")
	var r = relation(by_id, against_id)
	r.truce_until_day = maxi(r.truce_until_day, day + int(GameData.rule("truce_days")))
	if by_id == player_id:
		event.emit("You backed off your claim on the %s: -%d renown, and a truce of %d days." % [faction_name(against_id), lost, GameData.rule("truce_days")], "bad")
	elif against_id == player_id:
		event.emit("The %s backed off their claim on you: a truce of %d days." % [faction_name(by_id), GameData.rule("truce_days")], "good")

# The side a claim is pressed against gives in, in the middle of the war
func concede_claim(faction_id: String, other_id: String) -> String:
	var r = relation(faction_id, other_id)
	if r.claim.is_empty() or r.claim["stage"] != "war" or claim_target(r) != faction_id:
		return "They have no war goal against you"
	_end_claim_war(r, true)
	return ""

# A war over a goal ends: the claimant gets its terms, or (worn out first) pays and backs off for two years
func _end_claim_war(r: Relation, claimant_won: bool):
	var by: String = r.claim["by"]
	var against = r.other(by)
	var text = ""
	if claimant_won:
		text = "The war is over: the %s have won (%s)." % [faction_name(by), claim_text(r, player_id)]
	else:
		var reparations: float = minf(GameData.rule("war_defeat_wealth"), factions[by].wealth)
		factions[by].wealth -= reparations
		factions[against].wealth += reparations
		factions[against].stats["wars_won"] += 1
		text = "The war is over: the %s held out against the %s, who pay %d wealth." % [faction_name(against), faction_name(by), reparations]
	event.emit(text, "alert" if r.involves(player_id) else "info")
	if claimant_won:
		factions[by].stats["wars_won"] += 1
		_apply_war_goal(r)
	var war_days = day - r.war_start_day
	r.claim = {}
	r.war_points = 0.0
	end_occupations_between(r.a, r.b)
	if r.at_war:
		r.at_war = false
		war_cache.clear()
		r.peace_offered_by = ""
		r.truce_until_day = day + int(GameData.rule("truce_war_days"))
		if sim_sink != null:
			sim_sink.war_end("victory" if claimant_won else "held_out", war_days)

# The terms take effect: the district changes hands, they become a tributary, or they're absorbed
func _apply_war_goal(r: Relation):
	var by: String = r.claim["by"]
	var against = r.other(by)
	_war_infamy(r)
	match r.claim["goal"]:
		"claim":
			var d: District = districts[int(r.claim["district"])]
			if d.owner_id() != by:
				_transfer_district(d, by)
		"subjugate":
			r.overlord = by
			r.vassal_since_day = day
			r.pact = false
			r.alliance = false
		"vassalize":
			# The player's faction is never absorbed (as with "Integrate"): it becomes a tributary and plays on
			if against == player_id:
				r.overlord = by
				r.vassal_since_day = day
				r.pact = false
				r.alliance = false
				event.emit("The %s couldn't absorb you, but you are now their tributary: you pay them tribute in food, materials and wealth, trade only, and start no wars. Declare independence in Diplomacy when you're strong enough." % faction_name(by), "alert")
			else:
				_absorb(against, by)

# Vassalize: their land and people merge into the claimant's; their ruling family comes too, as a house of its own
func _absorb(faction_id: String, into_id: String):
	var people = everyone_of(faction_id)
	var lands = districts.filter(func(d): return d.owner_id() == faction_id)
	# Their ruling family becomes a house in the absorbing faction, holding the land it had (doc 16)
	var ruling = people.filter(func(c): return c.family or c.is_leader)
	var dynasty = ruling[0].dynasty if not ruling.is_empty() else faction_name(faction_id)
	for c in people:
		c.faction_id = into_id
		c.is_leader = false
		c.post = ""
		c.family = false
		c.change_loyalty(-20.0, "absorbed")
	var name = faction_name(faction_id)
	retire_faction(faction_id, into_id, people)
	var held = lands.filter(func(d): return d.owner_id() == into_id)
	if not ruling.is_empty() and not held.is_empty():
		_found_house(into_id, dynasty if dynasty != "" else name, ruling, held)
	event.emit("The %s have absorbed the %s: their land, people and stores. Their ruling family is now House %s, holding %d districts." % [
		faction_name(into_id), name, dynasty, held.size()], "alert" if into_id == player_id else "info")

# Daily: justifications ripen into ultimatums; wars over a goal end when it's taken or a side is worn out
func _update_claims():
	for r in relations.values():
		if r.claim.is_empty():
			continue
		var by: String = r.claim["by"]
		if not factions.has(by) or not factions.has(r.other(by)):
			r.claim = {}
			continue
		match r.claim["stage"]:
			"justifying":
				if day >= int(r.claim["ready_day"]):
					_send_ultimatum(r)
				elif r.other(by) == player_id and not r.claim.get("told_early", false) and check_send_early(by, player_id) == "":
					r.claim["told_early"] = true
					event.emit("The %s's side now outweighs yours: their ultimatum can come any day. Pay it off, back up your side, or make your own deals in Diplomacy (F4)." % faction_name(by), "alert")
				elif by == player_id:
					_watch_own_claim(r)
			"ultimatum":
				# The player's answer is a proposal; one left too long is a refusal
				if day >= int(r.claim["deadline"]) and not proposals.any(func(p): return p["action"] == "ultimatum" and p["from"] == by):
					answer_ultimatum(r, false)
			"war":
				if not r.at_war:
					r.claim = {}
					continue
				var against = r.other(by)
				if r.exhaustion[by] >= 100.0:
					_end_claim_war(r, false)
				elif r.exhaustion[against] >= 100.0:
					_end_claim_war(r, true)

func feed_trait_by_name(f: Faction, trait_name: String, amount: float):
	if f.traits.add_faction_trait_value(trait_name, amount) == 1:
		_announce_trait(f, trait_name)

const BASELINE_REFRESH_DAYS = 6

func _simulate_relations():
	var daily_exhaustion: float = GameData.rule("war_daily_exhaustion")
	var drift: float = GameData.rule("opinion_daily_drift")
	for r in relations.values():
		for fid in [r.a, r.b]:
			# The baseline follows changes in who they are and what binds them gradually;
			# memories fade at their own pace
			# (the target is worked out every few days, staggered by pair: it changes slowly, and it was most of the relations' cost)
			if not r.baseline_target.has(fid) or (day + r.a.hash()) % BASELINE_REFRESH_DAYS == 0:
				r.baseline_target[fid] = Diplomacy.baseline_value(Diplomacy.opinion_baseline(self, fid, r.other(fid)))
			r.baseline[fid] = move_toward(r.baseline[fid], r.baseline_target[fid], drift)
			var memories: Array = r.modifiers[fid]
			for m in memories.duplicate():
				m["value"] = move_toward(m["value"], 0.0, GameData.opinion_modifier(m["id"])["decay"])
				if absf(m["value"]) < 0.5:
					memories.erase(m)
			r.recompute_opinion(fid)
			if r.at_war:
				r.exhaustion[fid] = minf(100.0, r.exhaustion[fid] + daily_exhaustion)
		# Tell the player once when a war could end now, so it doesn't run on unseen
		if r.at_war and r.involves(player_id) and not r.peace_ready_told and check_peace(player_id, r.other(player_id)) == "":
			r.peace_ready_told = true
			event.emit("The %s would accept peace now (weariness: yours %d, theirs %d). Make peace in Diplomacy (F4), or fight on." % [
				faction_name(r.other(player_id)), r.exhaustion[player_id], r.exhaustion[r.other(player_id)]], "alert")
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
			_sim_grievance(d, "war_daily", 0.05)

# Removes a faction from the game. With into_id, it merges: its land, crew and stores pass to that faction.
# `keep`: people already moved into the absorbing faction who stay whatever its captain limit (a house taken in)
func retire_faction(faction_id: String, into_id: String = "", keep: Array = []):
	var f: Faction = factions.get(faction_id)
	if f == null:
		return
	war_cache.clear()
	for t in tasks.duplicate():
		if t.faction_id == faction_id:
			tasks.erase(t)
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
		var hired = characters_of(into_id).filter(func(c): return not c.family and c not in keep)
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
		"enemy_border", "raider_border":
			var owner = district.owner_id()
			return owner if owner != faction_id else ""
		"war_border":
			# An occupied district is retaken from its occupier (by its owner); otherwise the owner at war with you is the target
			var enemies = war_enemies(faction_id)
			if district.occupier != "":
				return district.occupier if district.occupier in enemies and district.owner_id() == faction_id else ""
			var holder = district.owner_id()
			return holder if holder in enemies else ""
	return ""

# What launching a venture costs, including any extra funding
# --- Buying with wealth (dead-end fix after the P1 playtest) ------------------------------------
# Wealth buys materials and arms at once. Each unit bought lately raises the price a little, so wealth
# eases a shortage but can't replace scavenging, salvage and Gather Weapons. The AI buys the same way.

const BUYABLE = ["materials", "arms"]

# What `amount` more units cost now: each one a little dearer than the last
func buy_price(faction_id: String, resource_type: String, amount: int) -> float:
	var base: float = GameData.rule("buy_price")[resource_type]
	var recent: float = factions[faction_id].bought.get(resource_type, 0.0)
	var rise: float = GameData.rule("buy_price_rise")
	return base * (amount + rise * (amount * recent + amount * (amount - 1) / 2.0))

# "" if the faction can buy this now, otherwise why not
func check_buy(faction_id: String, resource_type: String, amount: int) -> String:
	var f: Faction = factions[faction_id]
	if resource_type not in BUYABLE or amount <= 0:
		return "Nothing to buy"
	if resource_type == "arms" and f.arms + amount > GameData.rule("arms_cap"):
		return "Your armoury holds %d arms (have %d)" % [GameData.rule("arms_cap"), f.arms]
	var price = ceilf(buy_price(faction_id, resource_type, amount))
	if f.wealth < price:
		return "Need %d wealth (have %d)" % [price, f.wealth]
	return ""

func buy(faction_id: String, resource_type: String, amount: int) -> String:
	var err = check_buy(faction_id, resource_type, amount)
	if err != "":
		return err
	var f: Faction = factions[faction_id]
	var price = ceilf(buy_price(faction_id, resource_type, amount))
	f.wealth -= price
	f.set(resource_type, f.get(resource_type) + amount)
	f.bought[resource_type] = f.bought.get(resource_type, 0.0) + amount
	if faction_id == player_id:
		event.emit("Bought %d %s for %d wealth." % [amount, resource_type, price], "info")
	return ""

# Daily: the price eases back toward normal
func _ease_prices():
	for f in factions.values():
		for resource_type in BUYABLE:
			f.bought[resource_type] = f.bought.get(resource_type, 0.0) * (1.0 - GameData.rule("buy_recent_decay"))

# A standing task's run costs a share of the one-off price (doc 15 / 08, owner's decision: passive work costs far less)
func venture_cost(venture_id: String, funding: int, as_task: bool = false) -> Dictionary:
	var def = GameData.venture(venture_id)
	var cost: Dictionary = def["cost"].duplicate()
	if as_task:
		for resource_type in cost:
			cost[resource_type] = ceilf(cost[resource_type] * GameData.rule("task_cost_mult"))
	if funding > 0:
		cost["wealth"] = cost.get("wealth", 0.0) + def["funding_cost"] * funding
	return cost

# The plan a careful commander picks: crew until one more adds little, stopping once the odds are safe. Extra
# funding is never added for you: wealth is for buildings and relations, so paying more is always your call.
# The planner starts on it and the AI launches with it: one rule for both.
func recommended_plan(faction_id: String, venture_id: String, d: District, leader: Character) -> Dictionary:
	var f: Faction = factions[faction_id]
	var def = GameData.venture(venture_id)
	var target_id = venture_target(faction_id, venture_id, d)
	var safe: float = GameData.rule("no_disaster_odds")
	var crew = int(def["crew"])
	var spare = int(f.manpower) - int(GameData.rule("plan_manpower_reserve"))
	# A fight: the smallest crew that outnumbers the defence 2 to 1, or as many as can be spared
	if def.has("force") and target_id != "":
		var defence: float = defence_force(d, venture_id)["value"] * GameData.rule("ai_target_ratio")
		crew = int(def["crew_range"][0])
		while crew < crew_max(faction_id, venture_id) and crew + 1 <= spare and attack_force(faction_id, crew, leader)["value"] < defence:
			crew += 1
		return {"crew": crew, "funding": 0}
	var odds: float = VentureSystem.compute_odds(venture_id, f, d, self, target_id, leader, crew, 0)["odds"]
	while crew < crew_max(faction_id, venture_id) and crew + 1 <= spare and odds < safe:
		var next: float = VentureSystem.compute_odds(venture_id, f, d, self, target_id, leader, crew + 1, 0)["odds"]
		if next - odds < GameData.rule("plan_min_gain"):
			break
		crew += 1
		odds = next
	return {"crew": crew, "funding": 0}

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

# How dangerous a district is to work in: its ferals, traps and rotten floors (hazard, cut by Safeguard the
# Shelter), less as its ruins are cleared, for whoever holds it. A rebuilt home with the rubble gone is
# near safe; raids and fighting bring the ruins, and the danger, back.
func danger(d: District) -> float:
	if d.owner_id() == "":
		return d.hazard
	return d.hazard * (GameData.rule("danger_cleared") + (1.0 - GameData.rule("danger_cleared")) * d.ruin_level)

# How much a raid here is worth, as a multiplier on its loot: a fresh claim yields little,
# a rebuilt district with working buildings a lot
func raid_worth(d: District) -> float:
	var working = d.buildings.size() if buildings_active(d) else 0
	return minf(GameData.rule("raid_worth_max"), GameData.rule("raid_worth_base") + d.development + GameData.rule("raid_worth_per_building") * working)

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

# --- Force (doc 15, P1): for raids and assaults, the balance of force sets the odds -----------------

# The most a district's people will hold as its garrison: more people, more fighters (control makes them fight harder: defence_force)
func garrison_ceiling(d: District) -> float:
	var owner = d.owner_id()
	if owner == "":
		return 0.0
	return d.population * GameData.rule("garrison_per_pop")

# The largest crew this venture can take: for an assault, all your idle manpower (a trial, doc 15)
func crew_max(faction_id: String, venture_id: String) -> int:
	var def = GameData.venture(venture_id)
	if def.get("force", {}).get("crew_up_to_manpower", false):
		# A tributary fights its suzerain's wars with only part of its force (doc 15)
		var share: float = GameData.rule("tributary_war_share") if overlord_of(faction_id) != "" else 1.0
		return maxi(int(def["crew_range"][0]), int(factions[faction_id].manpower * share))
	return int(def["crew_range"][1])

# Arms a fight uses up: a share of those its crew carry (none needed to go: unarmed crew just count for less)
func arms_used(faction_id: String, venture_id: String, crew: int) -> int:
	if not GameData.venture(venture_id).has("force"):
		return 0
	return ceili(minf(factions[faction_id].arms, crew) * GameData.rule("arms_used_per_armed"))

# Your attack force: the crew sent, how many of them carry arms, and how well they're led. {"value", "parts"}
func attack_force(faction_id: String, crew: int, leader: Character) -> Dictionary:
	var f: Faction = factions[faction_id]
	var armed = minf(f.arms, crew)
	var arms_mult = 1.0 + GameData.rule("force_armed_bonus") * armed / maxf(1.0, crew)
	var command = int(leader.skills["command"]) if leader else int(GameData.rule("skill_neutral"))
	var lead_mult = maxf(0.5, 1.0 + (command - GameData.rule("skill_neutral")) * GameData.rule("skill_odds_step"))
	var parts = [["%d crew" % crew, float(crew)]]
	if armed >= 1.0:
		parts.append(["%d of them armed" % armed, arms_mult])
	parts.append(["Led by %s (Command %d)" % [leader.name, command] if leader else "No captain (Command %d)" % command, lead_mult])
	return {"value": crew * arms_mult * lead_mult, "parts": parts}

# A district's defence force against this venture: its garrison and guards, armed, behind its walls,
# held firmly. A raid slips past part of it (the venture's "defence_weight"). {"value", "parts"}
func defence_force(d: District, venture_id: String) -> Dictionary:
	var owner = d.owner_id()
	var parts = []
	if owner == "":
		return {"value": 1.0, "parts": parts}
	var f: Faction = factions[owner]
	var guards = defenders_at(owner, d)
	var men = d.garrison + guards
	parts.append(["Garrison %d" % roundi(d.garrison), d.garrison])
	if guards > 0:
		parts.append(["%d guards posted" % guards, float(guards)])
	var mult = 1.0
	var armed = minf(f.arms, men)
	if armed >= 1.0:
		var m = 1.0 + GameData.rule("force_armed_bonus") * armed / maxf(1.0, men)
		parts.append(["%d of them armed" % armed, m])
		mult *= m
	var grip = 1.0 / control_defence(d)
	if grip > 1.001:
		parts.append(["Control %d" % d.share(owner), grip])
		mult *= grip
	if buildings_active(d):
		for building_id in d.buildings:
			var effects = GameData.building(building_id)["effects"]
			if effects.has("defence_mult"):
				parts.append([GameData.building(building_id)["label"], 1.0 / effects["defence_mult"]])
				mult *= 1.0 / effects["defence_mult"]
	for entry in f.effects_with_labels("defence_mult"):
		parts.append(["Defenders: %s" % entry[0], 1.0 / entry[1]])
		mult *= 1.0 / entry[1]
	var weight: float = GameData.venture(venture_id).get("force", {}).get("defence_weight", 1.0)
	if weight < 0.999:
		parts.append(["A raid slips past some of them", weight])
		mult *= weight
	return {"value": maxf(0.5, men * mult), "parts": parts}

# Success chance from the balance of force: even is 50%, 2 to 1 about 85%, 3 to 1 about 95%
static func force_odds(ratio: float) -> float:
	var k = pow(maxf(ratio, 0.01), GameData.rule("force_exponent"))
	return k / (k + 1.0)

# Garrisons fill from the district's people: a little every day, three times as fast while Safeguard works
# there; the district's own recruits go to its garrison before they join your manpower
func _update_garrison(d: District, recruits: float) -> float:
	var ceiling = garrison_ceiling(d)
	if d.garrison >= ceiling:
		d.garrison = ceiling
		return recruits
	var regen = ceiling * GameData.rule("garrison_regen")
	var owner = d.owner_id()
	for v in ventures:
		if v.faction_id == owner and v.district == d and v.venture_id == "safeguard":
			regen *= GameData.rule("garrison_safeguard_mult")
			break
	var needed = ceiling - d.garrison
	var from_recruits = minf(recruits, maxf(0.0, needed - regen))
	d.garrison = minf(ceiling, d.garrison + regen + from_recruits)
	return recruits - from_recruits

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
			if is_at_war(faction_id, other) or (is_raider(other) and relation(faction_id, other).spare_until[other] <= day):
				return true
	return false

# Returns "" if the venture can be launched, otherwise the reason it can't.
# leader_id -2 means "any available leader" (the best one is picked at launch); crew -1 means the usual crew.
func check_launch(faction_id: String, venture_id: String, district: District, leader_id: int = -2, crew: int = -1, funding: int = 0, as_task: bool = false) -> String:
	var f: Faction = factions[faction_id]
	var def = GameData.venture(venture_id)
	# Routine work on your own land is a councillor's standing task, not a one-off launch (doc 13)
	if is_task(faction_id, venture_id, district) and not as_task:
		return "Assign a councillor to this as a standing task"
	var owner = district.owner_id()
	if district.occupier != "" and def["target"] != "war_border":
		return "%s is occupied by the %s: nothing can be done there until the war is settled" % [district.district_name, faction_name(district.occupier)]
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
			if def.has("raid_cooldown"):
				var promised = relation(faction_id, owner).spare_until[faction_id] - day
				if promised > 0:
					return "You promised the %s no raids for %d more days" % [faction_name(owner), promised]
				if day < district.raid_safe_until:
					return "Raided recently: safe from raids for %d more days" % (district.raid_safe_until - day)
				for v in ventures:
					if v.district == district and v.venture_id == venture_id and v.faction_id != faction_id:
						return "The %s are already raiding it" % faction_name(v.faction_id)
		"raider_border":
			if owner == "" or owner == faction_id:
				return "Only a faction that raids you can be threatened"
			if not borders_territory(faction_id, district):
				return "Not on your border"
			var r = relation(faction_id, owner)
			if not r.menaced_recently(owner, day, int(GameData.rule("menace_memory_days"))):
				return "The %s haven't raided you or demanded tribute lately" % faction_name(owner)
			if r.spare_until[owner] > day:
				return "The %s already keep away (%d more days)" % [faction_name(owner), r.spare_until[owner] - day]
		"war_border":
			if not at_war_with_anyone(faction_id):
				return "Declare war first (Diplomacy, F4)"
			# Assault occupies land an enemy owns, or retakes your own land from its occupier
			if district.occupier == faction_id:
				return "You already hold it: it stays yours to hold until the war is settled"
			if owner == faction_id and district.occupier == "":
				return "Already yours: assault takes land an enemy owns, or retakes your own land from an occupier"
			if venture_target(faction_id, venture_id, district) == "":
				return "No faction you are at war with owns this district"
			if owner != faction_id and not borders_territory(faction_id, district):
				return "Not on your border"
		"own":
			if owner != faction_id:
				return "Only in districts you control"
			match def.get("needs", ""):
				"food":
					if district.food_yield >= GameData.rule("food_source_cap") - 0.001:
						return "Every food source here is already worked (build Allotments for more)"
				"control":
					# Safeguard keeps going while there's danger left, so a district can be made fully Safe
					if district.share(faction_id) >= 95.0 and danger(district) < 0.04:
						return "Already fully under your control, and safe"
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
		# A councillor on a standing task is only busy for their own task while a run is out
		var out_now = ventures.any(func(other): return other.leader_id == leader.id)
		if out_now or (not as_task and leader_busy(leader)):
			return "%s is already out on a venture" % leader.name if out_now else "%s is committed to a task" % leader.name
	var size = int(def["crew"]) if crew < 0 else crew
	if size < int(def["crew_range"][0]) or size > crew_max(faction_id, venture_id):
		return "Crew must be %d-%d" % [def["crew_range"][0], crew_max(faction_id, venture_id)]
	if int(f.manpower) < size:
		return "Need %d idle manpower (have %d). Manpower grows from the food your districts produce" % [size, f.manpower]
	# A fight is won by force, not money: wealth helps by buying arms (Economy)
	if funding > 0 and def.has("force"):
		return "Fights take no funding: buy arms instead (Economy window)"
	var cost = venture_cost(venture_id, funding, as_task)
	var short = f.shortfall(cost)
	if short != "":
		return short + (" (or pick less extra funding)" if funding > 0 and f.can_afford(venture_cost(venture_id, 0, as_task)) else "")
	# Standing tasks leave a reserve of materials for your own plans (settling, building, one-off ventures)
	var reserve: float = GameData.rule("task_materials_reserve")
	if as_task and cost.get("materials", 0.0) > 0.0 and f.materials - cost["materials"] < reserve:
		return "Keeping %d materials in reserve for your own plans: needs %d to run (have %d)" % [reserve, cost["materials"] + reserve, f.materials]
	return ""

func launch_venture(faction_id: String, venture_id: String, district: District, leader_id: int = -2, crew: int = -1, funding: int = 0, as_task: bool = false) -> String:
	var err = check_launch(faction_id, venture_id, district, leader_id, crew, funding, as_task)
	if err != "":
		return err
	var f: Faction = factions[faction_id]
	var def = GameData.venture(venture_id)
	var leader = best_leader(faction_id, def["skill"]) if leader_id == -2 else character_by_id(leader_id)
	var size = int(def["crew"]) if crew < 0 else crew
	var target_id = venture_target(faction_id, venture_id, district)
	f.pay(venture_cost(venture_id, funding, as_task))
	f.manpower -= size
	var v = ActiveVenture.new(venture_id, faction_id, target_id, district, size, venture_days(venture_id, leader, district))
	v.leader_id = leader.id
	v.task = as_task
	v.funding = funding
	v.launch_odds = VentureSystem.compute_odds(venture_id, f, district, self, target_id, leader, size, funding)["odds"]
	# Reaching past your own land (claiming, raiding, trading at their market) counts as abroad
	var abroad = def["target"] in ["unclaimed_border", "scout", "enemy_border", "war_border", "raider_border", "market"] or (def["target"] == "scavenge" and district.owner_id() != faction_id)
	f.lean["abroad" if abroad else "home"] += 1.0
	# Raiding breaks an ambition that must be pursued in peace (Welfare for All)
	if def.get("hostile", false) and f.ambition != "" and GameData.national_ambition(f.ambition).get("while", "") == "no_raids":
		fail_ambition(faction_id, "you launched a %s" % def["label"].to_lower())
	ventures.append(v)
	_feed_trait(f, venture_id, 2.0)
	# Attacking someone who promised to leave you alone (you paid them, or they backed down) frees them of it
	if def.get("hostile", false) and target_id != "" and relation(faction_id, target_id).spare_until[target_id] > day:
		relation(faction_id, target_id).spare_until[target_id] = 0
		event.emit("The %s attacked the %s, so the %s's promise not to raid them is void." % [
			faction_name(faction_id), faction_name(target_id), faction_name(target_id)], "bad" if player_id in [faction_id, target_id] else "info")
	# Raiding or stirring up a trade partner ends the deal
	if def.get("hostile", false) and target_id != "" and relation(faction_id, target_id).trade:
		relation(faction_id, target_id).trade = false
		change_opinion(target_id, faction_id, -15.0, "betrayed_trade")
		event.emit("The trade agreement between the %s and the %s collapsed over the %s." % [
			faction_name(faction_id), faction_name(target_id), def["label"].to_lower()], "bad" if target_id == player_id or faction_id == player_id else "info")

	# A task's runs are summed up in its digest, not announced one by one
	if as_task:
		return ""
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

# A crew-loss effect scaled by how badly a fight went (other effects unchanged)
func _scaled_loss(e: Dictionary, severity: float) -> Dictionary:
	if e["op"] != "crew_share_loss":
		return e
	var scaled = e.duplicate()
	scaled["share"] = e["share"] * severity
	return scaled

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
		if v.task:
			_task_run_over(v, {})
		return

	var owner_before = d.owner_id()
	var chances = VentureSystem.compute_odds(v.venture_id, f, d, self, v.target_id, leader, v.crew, v.funding)
	# The target may have reacted since launch (defenders arriving): say so, with the reason
	var moved = chances["odds"] - v.launch_odds
	var odds_note = ""
	if absf(moved) > 0.02 and v.launch_odds > 0.0:
		var guards = defenders_at(v.target_id, d) if v.target_id != "" else 0
		odds_note = "odds had %s from %d%% to %d%%%s" % ["fallen" if moved < 0.0 else "risen", v.launch_odds * 100, chances["odds"] * 100,
			" (%d defenders on guard)" % guards if guards > 0 and moved < 0.0 else ""]
	var outcome = VentureSystem.roll_outcome(chances["tiers"], rng)
	var tier: String = outcome["tier"]
	var success = tier == "triumph" or tier == "success"
	var effects: Array = (def["success_effects"] if success else def["failure_effects"]).duplicate()
	if tier == "triumph":
		effects.append_array(def.get("triumph_effects", []))
	elif tier == "disaster":
		effects.append_array(def.get("disaster_effects", []))
		# In a fight, how badly a disaster goes depends on how badly you were outnumbered
		if not chances["force"].is_empty():
			var severity = clampf(GameData.rule("force_no_disaster_ratio") - chances["force"]["ratio"], 0.3, 1.0)
			effects = effects.map(func(e): return _scaled_loss(e, severity))
	# What the district was worth before the raid wrecked any of it
	var worth = raid_worth(d)
	var grievance_before = d.grievance
	var result = VentureSystem.apply_effects(effects, f, v.target_id, d, self, v.crew, outcome["quality"])
	_sim_grievance(d, "venture:" + v.venture_id, d.grievance - grievance_before)
	if odds_note != "":
		result["notes"].push_front(odds_note)
	# How cleanly a success went scales what it brought home
	if outcome["quality"] >= 1.1:
		result["notes"].push_front("a clean job (x%.1f)" % outcome["quality"])
	elif success and outcome["quality"] <= 0.9:
		result["notes"].push_front("only just (x%.1f)" % outcome["quality"])
	# A fight leaves its mark: a close win still costs lives, and the garrison is knocked down win or lose
	if not chances["force"].is_empty():
		var ratio: float = chances["force"]["ratio"]
		f.arms = maxf(0.0, f.arms - arms_used(f.id, v.venture_id, v.crew))
		# In a war over a goal, every fight moves the war score
		var war_r = relation(f.id, v.target_id) if v.target_id != "" else null
		if war_r and war_r.at_war and war_r.claim.get("stage", "") == "war":
			var points = (GameData.rule("war_points_assault") if v.venture_id == "assault" else GameData.rule("war_points_raid")) if success \
				else (-GameData.rule("war_points_assault_lost") if v.venture_id == "assault" else 0.0)
			war_r.war_points += points if war_r.claim["by"] == f.id else -points
		if success:
			var close = clampf((2.0 - ratio) * GameData.rule("force_close_win_loss"), 0.0, 0.15)
			var fallen = mini(int(round(v.crew * close * rng.randf_range(0.5, 1.0))), v.crew - result["lost"])
			if fallen > 0:
				result["lost"] += fallen
				result["notes"].append("a close fight: %d fell" % fallen)
		d.garrison *= 1.0 - GameData.rule("garrison_knock_success" if success else "garrison_knock_failure")
		# Taken: the new owner's garrison starts from nothing
		if d.owner_id() != owner_before:
			d.garrison = 0.0
	# Attackers who fail against a guarded district are driven off with extra losses
	if def.get("hostile", false) and not success and v.target_id != "" and defenders_at(v.target_id, d) >= 2:
		var driven_off = mini(rng.randi_range(1, 3), v.crew - result["lost"])
		result["lost"] += driven_off
		result["notes"].append("driven off by %d defenders (%d more lost)" % [defenders_at(v.target_id, d), driven_off])
	var lost = mini(result["lost"], v.crew)
	if def.has("raid_cooldown"):
		d.raid_safe_until = maxi(d.raid_safe_until, day + int(def["raid_cooldown"][tier]))
		if v.target_id != "":
			var raided = relation(f.id, v.target_id)
			raided.last_raid[f.id] = day
			# Raiding someone who's pressing a claim on you hardens their cause: their ultimatum comes sooner
			if raided.claim.get("stage", "") == "justifying" and raided.claim["by"] == v.target_id:
				var sooner = mini(int(GameData.rule("claim_raid_cut_days")), int(raided.claim["ready_day"]) - day)
				raided.claim["ready_day"] = int(raided.claim["ready_day"]) - sooner
				if v.target_id == player_id and sooner > 0:
					event.emit("The %s raided you: your claim on them is justified %d days sooner (ultimatum in %d days)." % [
						f.display_name, sooner, int(raided.claim["ready_day"]) - day], "good")
		if success and venture_id_is_raid(v):
			add_infamy(f.id, GameData.rule("infamy_raid"))
		if not success and defenders_at(v.target_id, d) >= 2:
			result["notes"].append("the %s lick their wounds" % f.display_name)
		result["notes"].append("no raids on %s for %d days" % [d.district_name, d.raid_safe_until - day])
		# Hitting a built-up district worries everyone next door to the victim
		if success and v.target_id != "" and worth >= 1.0:
			for fid in factions:
				if fid != f.id and fid != v.target_id and shares_border(fid, v.target_id):
					change_opinion(fid, f.id, GameData.rule("raid_neighbour_anger"), "raids_neighbours")
	# Settlers stay for good and become the district's people: expansion costs people
	var settlers = 0
	if def.get("settlers", false) and success:
		settlers = v.crew - lost
		d.population += settlers * GameData.rule("settler_population")
	# An assault that wins occupies the district (or retakes your own); half the survivors stay to hold it
	var holders = 0
	if result["values"].get("occupy", false) and success:
		holders = mini(v.crew - lost, maxi(1, ceili((v.crew - lost) * GameData.rule("occupation_crew_share"))))
		if holders > 0:
			if d.owner_id() == f.id:
				liberate(d, f.id, holders)
			else:
				occupy(d, f.id, holders)
	f.manpower += v.crew - lost - settlers - holders
	if success:
		_feed_trait(f, v.venture_id, 6.0 if tier == "triumph" else 4.0)
	if tier == "triumph":
		f.add_renown(2.0)

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
	var fate = _leader_outcome(leader, tier, def, v.task, chances["odds"])
	# A triumph or a disaster can bring a choice about what it means (in place of the next everyday event)
	if leader and tier in ["triumph", "disaster"] and day >= f.next_event_day:
		_fire_moment(f.id, "venture_" + tier, leader, v.venture_id)
	if fate != "":
		text += ". " + fate
	var kind = "info"
	if f.id == player_id:
		kind = "good" if success else "bad"
	elif v.target_id == player_id and def.get("hostile", false):
		kind = "bad" if success else "good"
	# A task's ordinary successes go into its monthly digest; triumphs, failures, wounds and deaths still show
	if not (v.task and tier == "success" and fate == ""):
		event.emit(text, kind)
	if v.task:
		_task_run_over(v, result["values"])
	if def["target"] == "war_border" and owner_before != f.id and d.owner_id() == f.id:
		f.stats["districts_conquered"] += 1
	_announce_ownership_change(d, owner_before, f.id)

# A task's run has landed (or been called off): count what it brought, then carry on, wait or finish
func _task_run_over(v: ActiveVenture, values: Dictionary):
	for t in tasks:
		if t.character_id == v.leader_id and t.venture_id == v.venture_id and t.district_id == v.district.id:
			for key in values:
				t.gains[key] = t.gains.get(key, 0) + int(values[key])
			t.digest_runs += 1
			_continue_task(t)
			return

# What happens to the leader: skill grows with triumphs, setbacks can wound, disasters can kill.
# Returns a sentence for the log ("" if nothing notable).
# The chance a venture's leader dies if it goes this badly (doc 14): the venture's own danger, worse the longer
# the odds were; standing tasks on home ground are safer. Nothing happens to the leader on a success
func venture_death_chance(def: Dictionary, tier: String, odds: float, task_run: bool = false) -> float:
	var weight: float = GameData.rule("death_weight_disaster") if tier == "disaster" else (GameData.rule("death_weight_setback") if tier == "setback" else 0.0)
	var longer_odds = 0.5 + (1.0 - clampf(odds, 0.0, 1.0))
	return clampf(def["danger"] * weight * longer_odds * (GameData.rule("task_wound_mult") if task_run else 1.0), 0.0, GameData.rule("death_chance_cap"))

func _leader_outcome(leader: Character, tier: String, def: Dictionary, task_run: bool = false, odds: float = 0.5) -> String:
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
			# A failure can kill, by how dangerous the venture is and how long the odds were; or wound (half as often on a standing task)
			var setback_roll = rng.randf()
			var setback_death = venture_death_chance(def, tier, odds, task_run)
			if setback_roll < setback_death:
				_character_died(leader, "killed leading a %s" % def["label"])
				return "%s was killed" % leader.name
			if setback_roll < setback_death + setback_wound_chance(def) * (GameData.rule("task_wound_mult") if task_run else 1.0):
				notes.append(_wound(leader, def))
		"disaster":
			var roll = rng.randf()
			var death = venture_death_chance(def, tier, odds, task_run)
			if roll < death:
				_character_died(leader, "killed leading a %s" % def["label"])
				return "%s was killed" % leader.name
			if roll < death + GameData.rule("disaster_wound_chance"):
				notes.append(_wound(leader, def))
			_earn_trait(leader, "shaken", notes)
	if leader.ventures_led >= int(GameData.rule("veteran_ventures")):
		_earn_trait(leader, "veteran", notes)
	if leader.triumphs >= int(GameData.rule("hero_triumphs")):
		_earn_trait(leader, "hero", notes)
	return ". ".join(notes)

# Careful work (a scavenge, a settlement) wounds less often and less badly than a raid or an assault
func setback_wound_chance(def: Dictionary) -> float:
	return clampf(def["danger"], GameData.rule("setback_wound_min"), GameData.rule("setback_wound_chance"))

# Days out of action after a wound on this venture, as [shortest, longest]
func wound_days(def: Dictionary) -> Array:
	var safe: Array = GameData.rule("wound_days_safe")
	var worst: Array = GameData.rule("wound_days")
	var t = clampf((def["danger"] - GameData.rule("wound_danger_low")) / (GameData.rule("wound_danger_high") - GameData.rule("wound_danger_low")), 0.0, 1.0)
	return [roundi(lerpf(safe[0], worst[0], t)), roundi(lerpf(safe[1], worst[1], t))]

func _wound(leader: Character, def: Dictionary) -> String:
	var days_range: Array = wound_days(def)
	var days = rng.randi_range(int(days_range[0]), int(days_range[1]))
	if leader.faction_id == player_id and leader.post != "":
		_stop("task", "councillor_wounded")
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
		var why = unavailable_reason(c)
		if why != "":
			parts.append("%s %s" % [c.name, why])
	if characters_of(faction_id).is_empty():
		return "You have no captains left. New ones join over time while you're under your limit (%d)" % captain_cap(faction_id)
	return "No captain is free: " + ", ".join(parts)

# Why someone can't lead a venture now ("wounded for 20 days", "back in 6 days (Settle)"), or "" if free
func unavailable_reason(c: Character) -> String:
	if c.is_wounded(day):
		return "wounded for %d days" % (c.wounded_until - day)
	var t = task_of(c)
	if t:
		return "%s %s" % [GameData.venture(t.venture_id)["task_label"].to_lower(), districts[t.district_id].district_name]
	for v in ventures:
		if v.leader_id == c.id:
			return "back in %d days (%s)" % [v.days_left, GameData.venture(v.venture_id)["label"]]
	if c.committed_until > day:
		return "free in %d days (after a task)" % (c.committed_until - day)
	return ""

# Removes a character who died; their comrades take it hard and any council seat falls empty
func _character_died(c: Character, fate: String):
	var was_leader = c.is_leader
	_record_departure(c, fate)
	characters.erase(c)
	c.death_day = day
	# A death in the family or on the council brings the question of how to grieve
	if c.family or c.post != "" or was_leader:
		_fire_moment(c.faction_id, "death", c)
	c.fate = fate
	if c.family or was_leader:
		graveyard.append(c)
	for other in characters_of(c.faction_id):
		other.change_loyalty(-4.0, "comrade_lost")
	if c.post != "" and c.faction_id == player_id:
		_stop("task", "councillor_died")
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

# --- Matches within the faction (doc 16, H1) -------------------------------------------------

# The best match among the faction's own captains for a grown family member: unmarried, the other sex,
# of a fitting age, not family; councillors first, then the most able (null if nobody fits)
func match_candidate(c: Character) -> Character:
	var best: Character = null
	var best_score = -1.0
	for other in characters_of(c.faction_id):
		if other == c or other.family or other.spouse_id >= 0 or other.sex == c.sex or absi(other.age - c.age) > 12:
			continue
		var score = other.best_skill_value() + (5.0 if other.post != "" else 0.0)
		if score > best_score:
			best_score = score
			best = other
	return best

# The best match from one of the faction's houses: unmarried, the other sex, of a fitting age (null if none)
func house_match_candidate(c: Character) -> Character:
	var best: Character = null
	for other in characters:
		if other.faction_id != c.faction_id or other.house_id < 0 or other == c or other.spouse_id >= 0 or other.sex == c.sex \
				or not other.is_adult() or absi(other.age - c.age) > 12:
			continue
		if best == null or other.best_skill_value() > best.best_skill_value():
			best = other
	return best

# A match is made: the spouse joins the family, and their children are family
func _wed(c: Character, kind: String, candidate: Character):
	var spouse: Character = null
	match kind:
		"captain":
			spouse = candidate
			spouse.family = true
			spouse.change_loyalty(GameData.rule("married_in_loyalty"), "married_in")
		"house":
			# One of a house marries into the family: the house is bound to you
			spouse = candidate
			var head = house_head(spouse.house_id)
			if head:
				head.change_loyalty(20.0, "house_match")
			spouse.house_id = -1
			spouse.family = true
		"people":
			# One of your people: the children lean Of the People
			spouse = _marry(c)
			spouse.dynasty = c.dynasty
			if "of_the_people" not in spouse.traits and "born_to_rule" not in spouse.traits:
				spouse.traits.append("of_the_people")
			return
	if spouse:
		spouse.spouse_id = c.id
		c.spouse_id = spouse.id

# Living family members of a faction (the cap keeps a family from swelling without end)
func family_size(faction_id: String) -> int:
	return everyone_of(faction_id).filter(func(c): return c.family or c.is_leader).size()

# --- Houses (doc 16, H2) -------------------------------------------------------------------
# A house is a family inside a faction, not the ruling one, holding land of its own: the faction's still
# on the map, but the house keeps a share of its districts' income. Its loyalty is its head's; a disloyal
# house warns, then may break away with its land. Houses come from Vassalize (the absorbed ruling family)
# and from land granted to a grown family member or a loyal captain (a cadet house).

func house(house_id: int) -> Dictionary:
	for h in houses:
		if int(h["id"]) == house_id:
			return h
	return {}

func houses_of(faction_id: String) -> Array:
	return houses.filter(func(h): return h["faction"] == faction_id)

func house_members(house_id: int) -> Array:
	return characters.filter(func(c): return c.house_id == house_id)

func house_districts(house_id: int) -> Array:
	var h = house(house_id)
	return districts.filter(func(d): return d.house_id == house_id and d.owner_id() == h.get("faction", ""))

# The eldest grown member speaks for the house
func house_head(house_id: int) -> Character:
	var head: Character = null
	for c in house_members(house_id):
		if c.is_adult() and (head == null or c.age > head.age):
			head = c
	return head

func house_loyalty(house_id: int) -> float:
	var head = house_head(house_id)
	return head.loyalty() if head else 0.0

func is_house_head(c: Character) -> bool:
	return c.house_id >= 0 and house_head(c.house_id) == c

# Founds a house in a faction with these people and districts; returns its id
func _found_house(faction_id: String, name: String, members: Array, lands: Array) -> int:
	var id = next_house_id
	next_house_id += 1
	houses.append({"id": id, "name": name, "faction": faction_id, "founded": day, "restless_since": -1, "asked_war": -1})
	for c in members:
		c.house_id = id
	for d in lands:
		d.house_id = id
	return id

# "" if this person can be granted this district to found a house, otherwise why not
func check_grant(faction_id: String, c: Character, d: District) -> String:
	if c == null or c.faction_id != faction_id or c.death_day >= 0:
		return "No such person"
	if not c.is_adult():
		return "%s is too young to hold land" % c.name
	if c.is_leader:
		return "The leader holds everything already"
	if c.house_id >= 0:
		return "%s already has a house" % c.name
	if not c.family and c.loyalty() < GameData.rule("house_grant_min_loyalty"):
		return "%s isn't loyal enough to trust with land (loyalty %d, needs %d)" % [c.name, c.loyalty(), GameData.rule("house_grant_min_loyalty")]
	if d == null or d.owner_id() != faction_id:
		return "Select one of your districts first"
	if d.id == factions[faction_id].home_id:
		return "Not your home district"
	if d.house_id >= 0:
		return "%s is already held by House %s" % [d.district_name, house(d.house_id).get("name", "?")]
	# Keep land of your own: at least one district no house holds
	var own = districts.filter(func(x): return x.owner_id() == faction_id and x.house_id < 0).size()
	if own <= 1:
		return "Keep at least one district for yourself"
	return ""

# A cadet house: the grantee, their spouse and children hold the district and keep a share of its income
func grant_land(faction_id: String, c: Character, d: District) -> String:
	var err = check_grant(faction_id, c, d)
	if err != "":
		return err
	var surname = c.dynasty if c.dynasty != "" else c.name.get_slice(" ", 1)
	var members = [c]
	var spouse = character_by_id(c.spouse_id)
	if spouse and spouse.house_id < 0:
		members.append(spouse)
	for kid in characters:
		if c.id in kid.parent_ids and kid.house_id < 0:
			members.append(kid)
	var id = _found_house(faction_id, "%s of %s" % [surname, d.district_name], members, [d])
	c.change_loyalty(15.0, "granted_land")
	if faction_id == player_id:
		event.emit("%s is granted %s and founds House %s. They keep %d%% of its income; their loyalty is the house's." % [
			c.name, d.district_name, house(id)["name"], GameData.rule("house_income_share") * 100], "good")
	else:
		event.emit("The %s granted %s to %s, who founds House %s." % [faction_name(faction_id), d.district_name, c.name, house(id)["name"]], "info")
	return ""

# The share of a district's income its owner gets (a house keeps the rest)
func house_keep(d: District) -> float:
	return 1.0 - GameData.rule("house_income_share") if d.house_id >= 0 else 1.0

# At war, the faction asks a house to fight: it may decline (likelier the less loyal it is); if it agrees, it
# sends fighters from its districts' garrisons into your manpower, and earns your gratitude
func check_call_house(faction_id: String, house_id: int) -> String:
	var h = house(house_id)
	if h.is_empty() or h["faction"] != faction_id:
		return "No such house"
	if not at_war_with_anyone(faction_id):
		return "You're not at war"
	if int(h["asked_war"]) >= 0 and day - int(h["asked_war"]) < 180:
		return "Asked already (again in %d days)" % (180 - (day - int(h["asked_war"])))
	return ""

func call_house(faction_id: String, house_id: int) -> String:
	var err = check_call_house(faction_id, house_id)
	if err != "":
		return err
	var h = house(house_id)
	h["asked_war"] = day
	var chance = clampf(house_loyalty(house_id) / 100.0 + 0.2, 0.1, 0.95)
	if rng.randf() >= chance:
		event.emit("House %s declined to fight for the %s." % [h["name"], faction_name(faction_id)], "bad" if faction_id == player_id else "info")
		return ""
	var levy = 0.0
	for d in house_districts(house_id):
		var sent = d.garrison * GameData.rule("house_levy_share")
		d.garrison -= sent
		levy += sent
	factions[faction_id].manpower += roundf(levy)
	var head = house_head(house_id)
	if head:
		head.change_loyalty(5.0, "fought_with_you")
	event.emit("House %s answers the call: %d fighters join the %s." % [h["name"], roundi(levy), faction_name(faction_id)], "good" if faction_id == player_id else "info")
	return ""

# Monthly: houses with no land or people fade; a disloyal house warns, then may break away with its land
func _update_houses():
	for h in houses.duplicate():
		var id = int(h["id"])
		if not factions.has(h["faction"]) or house_head(id) == null or house_districts(id).is_empty():
			for d in districts:
				if d.house_id == id:
					d.house_id = -1
			for c in characters:
				if c.house_id == id:
					c.house_id = -1
			houses.erase(h)
			continue
		var loyalty = house_loyalty(id)
		if loyalty >= GameData.rule("loyalty_defect") + 5.0:
			h["restless_since"] = -1
			continue
		if loyalty >= GameData.rule("loyalty_defect"):
			continue
		if int(h["restless_since"]) < 0:
			h["restless_since"] = day
			if h["faction"] == player_id:
				event.emit("House %s is restless (loyalty %d): if it stays below %d it may break away with %s. Win them back: a match with your family, a seat, their land kept safe." % [
					h["name"], loyalty, GameData.rule("loyalty_defect"), ", ".join(house_districts(id).map(func(d): return d.district_name))], "alert")
		elif day - int(h["restless_since"]) >= int(GameData.rule("house_restless_days")) and rng.randf() < GameData.rule("house_revolt_chance"):
			_house_revolt(h)

# A house breaks away with its districts and people, at war with its old faction (the civil-war split)
func _house_revolt(h: Dictionary):
	var faction_id: String = h["faction"]
	var id = int(h["id"])
	var head = house_head(id)
	var lands = house_districts(id)
	if head == null or lands.is_empty() or districts_held(faction_id) - lands.size() < 1:
		return
	var members = house_members(id)
	houses.erase(h)
	for d in lands:
		d.house_id = -1
	for c in members:
		c.house_id = -1
	_split(faction_id, head, lands, members, "House %s broke away from" % h["name"])

# A house's land is lost in a war: it blames you
func _house_lost_land(d: District):
	if d.house_id < 0:
		return
	var head = house_head(d.house_id)
	if head:
		head.change_loyalty(-10.0, "lost_land")
	d.house_id = -1

# --- Marriage between factions (doc 16, H3) ----------------------------------------------------

# The faction's best unmarried grown family member to offer in a match (not the leader; null if none)
func match_offer(faction_id: String) -> Character:
	var best: Character = null
	for c in characters_of(faction_id):
		if c.family and character_by_id(c.spouse_id) == null and c.age <= 45 and (best == null or c.best_skill_value() > best.best_skill_value()):
			best = c
	return best

# Someone of theirs (family or a house) to match with `mine`: unmarried, the other sex, of a fitting age
func match_partner(mine: Character, faction_id: String) -> Character:
	var best: Character = null
	for c in characters_of(faction_id):
		if (c.family or c.house_id >= 0) and character_by_id(c.spouse_id) == null and c.sex != mine.sex and absi(c.age - mine.age) <= 12 \
				and (best == null or c.best_skill_value() > best.best_skill_value()):
			best = c
	return best

# Whether a living marriage binds the two factions' families
func marriage_tie(a_id: String, b_id: String) -> bool:
	for pair in relation(a_id, b_id).marriages:
		var x = character_by_id(int(pair[0]))
		var y = character_by_id(int(pair[1]))
		if x and y and x.spouse_id == y.id:
			return true
	return false

# The match is made: theirs joins the proposer's family, and the factions are bound while both live
func cross_match(proposer_id: String, other_id: String) -> String:
	var mine = match_offer(proposer_id)
	if mine == null:
		return ""
	var theirs = match_partner(mine, other_id)
	if theirs == null:
		return ""
	theirs.faction_id = proposer_id
	theirs.post = ""
	theirs.house_id = -1
	theirs.family = true
	theirs.spouse_id = mine.id
	mine.spouse_id = theirs.id
	relation(proposer_id, other_id).marriages.append([mine.id, theirs.id])
	for side in [proposer_id, other_id]:
		var r = relation(proposer_id, other_id)
		r.baseline[side] = Diplomacy.baseline_value(Diplomacy.opinion_baseline(self, side, r.other(side)))
		r.recompute_opinion(side)
	var text = "%s of the %s marries %s of the %s: the two families are bound." % [theirs.name, faction_name(other_id), mine.name, faction_name(proposer_id)]
	event.emit(text, "good" if player_id in [proposer_id, other_id] else "info")
	return ""

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
			# Grown before the story starts: their nature stuck
			child.traits = child.leanings.keys()
			_grow_up(child)
		elif child.age >= int(GameData.rule("schooling_age")):
			# Children already at school age when the story starts were raised at home
			child.upbringing = "parents"
			for y in child.age - int(GameData.rule("schooling_age")):
				_grow_year(child)

func _new_child(parent: Character, age: int) -> Character:
	var child = _new_person(parent.faction_id, parent.dynasty, age, "m" if rng.randf() < 0.5 else "f")
	# Born to the ruling family, or into a house (doc 16): a house's children are its own
	child.house_id = parent.house_id
	child.family = parent.family or parent.is_leader or parent.house_id < 0
	child.parent_ids = [parent.id]
	if parent.spouse_id >= 0:
		child.parent_ids.append(parent.spouse_id)
	for s in Character.SKILLS:
		child.skills[s] = 0
	# The nature they're born with is only a leaning: how they're raised decides whether it sticks (settled at 16)
	for t in child.traits:
		child.leanings[t] = GameData.rule("nature_at_birth")
	child.traits.clear()
	return child

# A year of childhood under their upbringing: skills rise (most of all the ones being taught), and so do leanings
func _grow_year(c: Character):
	var def = GameData.council()["upbringings"].get(c.upbringing, GameData.council()["upbringings"]["parents"])
	var parents = c.parent_ids.map(func(id): return person_by_id(id)).filter(func(p): return p != null)
	var focus = {}
	for key in def["skills"]:
		var taught = []
		match key:
			"$tutor":
				taught = [c.tutor_skill] if c.tutor_skill != "" else []
			"$parents":
				taught = parents.map(func(p): return p.best_skill())
			_:
				taught = [key]
		for s in taught:
			focus[s] = focus.get(s, 0.0) + float(def["skills"][key])
	for s in Character.SKILLS:
		if rng.randf() < GameData.rule("childhood_skill_chance") + focus.get(s, 0.0):
			c.skills[s] = mini(10, int(c.skills[s]) + 1)
	for key in def["leanings"]:
		var amount: float = def["leanings"][key]
		var natures = []
		match key:
			"$tutor_nature":
				var tutor = person_by_id(c.tutor_id)
				natures = tutor.traits if tutor else []
			"$parents_nature":
				for p in parents:
					natures += p.traits
			_:
				natures = [key]
		for t in natures:
			if GameData.character_trait(t)["kind"] in ["personality", "upbringing"]:
				c.leanings[t] = float(c.leanings.get(t, 0.0)) + amount * rng.randf_range(0.5, 1.5)

# Chance a leaning settles into a trait at 16
func settle_chance(c: Character, trait_id: String) -> float:
	return minf(GameData.rule("leaning_settle_max"), float(c.leanings.get(trait_id, 0.0)) * GameData.rule("leaning_settle_per_point"))

# Coming of age: the strongest leanings may settle into traits (an upbringing biases this, never guarantees it)
func _settle_traits(c: Character) -> Array:
	var order = c.leanings.keys()
	order.sort_custom(func(a, b): return c.leanings[a] > c.leanings[b])
	var settled = []
	for t in order:
		if settled.size() >= 3 or t in c.traits or _has_opposite(c, t):
			continue
		if rng.randf() < settle_chance(c, t):
			c.traits.append(t)
			settled.append(t)
	for s in Character.SKILLS:
		c.skills[s] = maxi(1, int(c.skills[s]))
	return settled

# "Tutored by Karel Marsh (Command)", for the child's card
func upbringing_label(c: Character) -> String:
	if c.upbringing == "":
		return ""
	var tutor = person_by_id(c.tutor_id)
	var label: String = GameData.council()["upbringings"][c.upbringing]["label"]
	return label.replace("{tutor}", "%s (%s)" % [tutor.name, c.tutor_skill.capitalize()] if tutor else "a tutor").replace("{skill}", c.tutor_skill.capitalize())

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
	# Age alone decides (doc 14); a leader's extra risk is the ventures they choose to lead
	var base: float = GameData.rule("adult_death_chance")
	return base + GameData.rule("age_death_chance") * maxf(c.age - 50, 0)

func yearly_death_chance(c: Character) -> float:
	return 1.0 - pow(1.0 - monthly_death_chance(c), 12)

# Births, deaths, birthdays and respect for the leader
func _life_cycle():
	if day % 360 == 0:
		var schooling = int(GameData.rule("schooling_age"))
		for c in characters.duplicate():
			c.age += 1
			# A grown, unmarried family member (or a widow) is matched: from 18, then every couple of years if "not yet"
			if c.family and not c.is_leader and c.age >= int(GameData.rule("match_age")) and c.age <= 45 and character_by_id(c.spouse_id) == null \
					and day >= c.match_day:
				c.match_day = day + int(GameData.rule("match_again_years")) * 360 - 1
				_fire_moment(c.faction_id, "match", c)
			if not c.family or c.age < schooling or c.age > 16:
				continue
			# At six, who raises them; then a year of growing up each birthday, and now and then an event
			if c.upbringing == "":
				if c.age == schooling:
					_fire_moment(c.faction_id, "education", c)
				if c.upbringing == "" and (c.age > schooling or not (c.faction_id == player_id and factions[c.faction_id].ai == null)):
					c.upbringing = "parents"
			# Growing up starts the year after the choice (the player's may still be waiting for an answer)
			if c.age == schooling or c.upbringing == "":
				continue
			_grow_year(c)
			if c.age < 16:
				if rng.randf() < GameData.rule("childhood_event_chance"):
					_fire_moment(c.faction_id, "childhood", c)
				continue
			var settled = _settle_traits(c)
			_fire_moment(c.faction_id, "coming_of_age", c)
			if c.faction_id == player_id:
				var best = c.best_skill()
				var became = ", ".join(settled.map(func(t): return GameData.character_trait(t)["label"]))
				event.emit("%s comes of age and joins your crew (%s %d)%s." % [c.name, best.capitalize(), c.skills[best], (": " + became) if became != "" else ""], "good")
	if day % 30 != 20:
		return
	_update_houses()
	for c in characters.duplicate():
		if not characters.has(c):
			continue
		if rng.randf() < monthly_death_chance(c):
			_character_died(c, "died of old age" if c.age >= 65 else "died of illness")
	# Every married couple can have children, not only the leader: first the news, then a birth about nine months on
	for mother in characters.duplicate():
		if mother.sex != "f" or not mother.is_adult() or mother.spouse_id < 0:
			continue
		var father = character_by_id(mother.spouse_id)
		# A child on the way is born even if the father has died since
		if mother.due_day > 0:
			if day >= mother.due_day:
				mother.due_day = 0
				# The child belongs to whichever parent is of the family (the leader's line), and to both parents
				var parent: Character = mother if mother.family or mother.is_leader or father == null else father
				var child = _new_child(parent, 0)
				if mother.id not in child.parent_ids:
					child.parent_ids.append(mother.id)
				if mother.spouse_id >= 0 and mother.spouse_id not in child.parent_ids:
					child.parent_ids.append(mother.spouse_id)
				if mother.faction_id == player_id:
					event.emit("%s is born to %s%s." % [child.name, mother.name, (" and " + father.name) if father else ""], "good")
				_fire_moment(mother.faction_id, "birth", child)
			continue
		if father == null or father.faction_id != mother.faction_id:
			continue
		if mother.age >= 45 or father.age >= 60:
			continue
		var kids = everyone_of(mother.faction_id).filter(func(c): return mother.id in c.parent_ids or (father.id in c.parent_ids and mother.id in c.parent_ids))
		# The family has a limit, so it branches without swelling for ever (doc 16)
		if family_size(mother.faction_id) >= int(GameData.rule("family_cap")):
			continue
		if kids.size() < int(GameData.rule("children_per_couple")) and rng.randf() < GameData.rule("birth_chance"):
			mother.due_day = day + int(GameData.rule("pregnancy_days"))
			if mother.faction_id == player_id:
				event.emit("%s is expecting a child (due in about nine months)." % mother.name, "good")
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
	var gov = GameData.government(factions[faction_id].government)
	if gov["heir_rule"] != "blood":
		return "Under a %s nobody can be named heir: %s" % [gov["label"], gov["succession"]]
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
	# The government sets who succeeds (data/governments.json "heir_rule")
	var gov = GameData.government(factions[faction_id].government)
	var council = crew.filter(func(c): return c.post != "")
	match gov["heir_rule"]:
		"council_elects", "election":
			# The council's strongest, most loyal member (an election adds chance: see _succession)
			var best = -1.0
			for c in council:
				if _skill_total(c) + c.loyalty() > best:
					best = _skill_total(c) + c.loyalty()
					heir = c
		"best_steward":
			for c in council:
				if heir == null or c.skills["stewardship"] > heir.skills["stewardship"]:
					heir = c
	if leader and heir == null and gov["heir_rule"] == "blood":
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
		+ heir.triumphs * 2.0 + factions[faction_id].reputation / 10.0 + factions[faction_id].effect("heir_claim")
	for t in heir.traits:
		claim += float(GameData.character_trait(t).get("claim", 0.0))
	var contesters = []
	for c in crew:
		# Councillors, the family, and the heads of houses (their land is their claim) may contest it
		if c == heir or not (c.post != "" or c.family or is_house_head(c)):
			continue
		var loyalty = c.loyalty()
		if loyalty >= gov.get("contest_loyalty", 40.0) and not c.has_trait("ambitious"):
			continue
		var theirs = c.best_skill_value() * 3.0 + c.triumphs * 2.0 + maxf(45.0 - loyalty, 0.0) + (10.0 if c.has_trait("ambitious") else 0.0)
		if is_house_head(c):
			theirs += 5.0 * house_districts(c.house_id).size()
		if theirs > claim * 0.6:
			contesters.append([c, theirs])
	contesters.sort_custom(func(a, b): return a[1] > b[1])
	var chance = 0.0
	for entry in contesters:
		chance += entry[1] / (entry[1] + claim) * GameData.rule("split_weight")
	chance *= factions[faction_id].effect("split_chance_mult")
	# An heir the people trust is harder to contest
	for t in heir.traits:
		chance *= float(GameData.character_trait(t).get("split_mult", 1.0))
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
	# Democracy elects: the front-runner usually wins, but not always. A caretaker runs things meanwhile.
	var gov = GameData.government(f.government)
	if gov["heir_rule"] == "election":
		var candidates = characters_of(faction_id).filter(func(c): return c.post != "" and c != dead)
		if not candidates.is_empty():
			var weights = candidates.map(func(c): return float(_skill_total(c)) + c.loyalty())
			var pick = rng.randf() * weights.reduce(func(total, w): return total + w, 0.0)
			for i in candidates.size():
				pick -= weights[i]
				if pick <= 0.0:
					heir = candidates[i]
					break
		f.caretaker_until = day + int(gov.get("caretaker_days", 0))
	f.last_succession_day = day
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
	var contesters = outlook["contesters"].filter(func(entry): return entry[0] != heir)
	var chance: float = outlook["split_chance"]
	# An oligarchy buys off its rivals, if it can afford to: each 50 wealth (up to half the treasury) cuts the risk by a quarter
	if gov.get("bribes", false) and not contesters.is_empty() and chance > 0.0:
		var payments = mini(int(f.wealth * 0.5 / 50.0), 6)
		if payments > 0:
			f.wealth -= payments * 50.0
			chance *= pow(0.75, payments)
			event.emit("The %s paid %d wealth to buy off rival claimants (civil war risk now %d%%)." % [f.display_name, payments * 50, chance * 100], "alert" if faction_id == player_id else "info")
	if not contesters.is_empty() and rng.randf() < chance:
		if gov.get("splits", "") == "purge":
			_purge(faction_id, contesters[0][0])
		else:
			_split(faction_id, contesters[0][0])


# The Politburo doesn't split: it purges. The rival is expelled (joining a rival faction or leaving the city),
# and everyone left on the council has seen what happens to dissenters
func _purge(faction_id: String, rival: Character):
	var f: Faction = factions[faction_id]
	var text = "PURGE in the %s: %s challenged the new leadership and was expelled. The council is shaken." % [f.display_name, rival.name]
	_defect(rival)
	for c in characters_of(faction_id):
		c.change_loyalty(-10.0, "purge_fear")
	event.emit(text, "alert" if faction_id == player_id else "info")
	if faction_id == player_id:
		major_event.emit("Purge", text, "")

# Civil war: a rival claimant breaks away with a block of districts furthest from the capital
var next_split_id: int = 1
# Houses inside factions (doc 16, H2): [{"id", "name", "faction", "founded", "restless_since", "asked_war"}]
var houses: Array = []
var next_house_id: int = 1

# A faction splits: a claimant breaks away with part of its land, at war with it. A house revolt (doc 16)
# passes its own districts (`lands`) and people (`house`), and `why` for the news
func _split(faction_id: String, claimant: Character, lands: Array = [], house: Array = [], why: String = ""):
	var f: Faction = factions[faction_id]
	var owned = districts.filter(func(d): return d.owner_id() == faction_id)
	if owned.size() < 2:
		return
	var seed: District = owned[0]
	var take = lands
	if take.is_empty():
		var capital: District = districts[f.home_id] if f.home_id >= 0 and districts[f.home_id].owner_id() == faction_id else owned[0]
		for d in owned:
			if d != capital and d.center.distance_to(capital.center) > seed.center.distance_to(capital.center):
				seed = d
		var others = owned.filter(func(d): return d != capital)
		others.sort_custom(func(a, b): return a.center.distance_to(seed.center) < b.center.distance_to(seed.center))
		# How much a breakaway takes depends on the government: an autocracy breaks rarely but badly
		var portion: Array = GameData.government(f.government).get("split_share", [0.3, 0.45])
		take = others.slice(0, clampi(int(round(owned.size() * rng.randf_range(portion[0], portion[1]))), 1, owned.size() - 1))
	else:
		seed = take[0]
	var surname = claimant.name.get_slice(" ", 1)
	var id = "split_%d" % next_split_id
	next_split_id += 1
	var color = Color.from_hsv(fposmod(f.color.h + 0.07, 1.0), f.color.s * 0.75, f.color.v * 0.8)
	var rebels = Faction.new(id, "%s's %s" % [surname, SPLIT_NAMES[rng.randi() % SPLIT_NAMES.size()]], color, false)
	rebels.blurb = "Broke away from the %s when %s claimed the leadership." % [f.display_name, claimant.name]
	rebels.government = "warlord"
	rebels.traits.load_dict(f.traits.to_dict())
	# A fighter's breakaway leans to the gun
	if claimant.best_skill() == "command":
		rebels.traits.add_faction_trait_value("Militaristic", 20.0)
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
	# A house that breaks away takes all its people: they're the new faction's ruling family
	for c in house:
		if c != claimant and c.faction_id == faction_id and c.death_day < 0:
			c.faction_id = id
			c.post = ""
			c.family = true
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
	if why != "":
		rebels.blurb = "%s the %s, led by %s." % [why, f.display_name, claimant.name]
		event.emit("%s the %s with %s, as the %s. They are at war with the %s." % [why, f.display_name, names, rebels.display_name, f.display_name],
			"alert" if faction_id == player_id or shares_border(player_id, id) else "info")
		if faction_id == player_id:
			major_event.emit("A house breaks away", "%s you with %s, as the %s, and is at war with you." % [why, names, rebels.display_name], id)
		factions_changed.emit()
		return
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
	# On a standing task (even one waiting to resume), or still committed after stopping one
	return task_of(c) != null or c.committed_until > day

func available_leaders(faction_id: String) -> Array:
	return characters_of(faction_id).filter(func(c): return not c.is_wounded(day) and not leader_busy(c))

# The free captain best at a skill (null if nobody is free)
func best_leader(faction_id: String, skill: String) -> Character:
	var best: Character = null
	for c in available_leaders(faction_id):
		if best == null or c.skills[skill] > best.skills[skill]:
			best = c
	return best

# How many captains a faction can keep: more with territory and reputation
func captain_cap(faction_id: String) -> int:
	return mini(int(GameData.rule("captain_max")), int(GameData.rule("captain_base")) + districts_held(faction_id) / int(GameData.rule("captain_per_districts")) \
		+ int(factions[faction_id].reputation / GameData.rule("captain_per_renown")))

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
	c.skills[specialty] = mini(10, rng.randi_range(5, 8) + mini(2, int(factions[faction_id].reputation / 40.0)))
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
	if sim_sink != null:
		sim_sink.flip(d.id, owner_before, owner_after, actor_id)
	if owner_after != "":
		d.absorb = GameData.rule("absorb_start")
		if owner_before != "":
			d.grievance = minf(100.0, d.grievance + GameData.rule("conquest_grievance"))
	# A house that held it has lost its land, and blames its faction (doc 16)
	_house_lost_land(d)
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
		event.emit("%s have become %s (%s)." % [f.display_name, trait_name, t.benefit], "good")

# --- Buildings ------------------------------------------------------------------

# Building effects only work while the owner can pay upkeep
func buildings_active(district: District) -> bool:
	var owner: Faction = factions.get(district.owner_id())
	return district.occupier == "" and owner != null and not owner.broke and not owner.disrepair

# Where a district's building slots come from, as [[label, slots], ...] (for the Build tab's hover)
func building_slot_parts(district: District) -> Array:
	var parts = []
	if district.owner_id() == "":
		return parts
	var status: String = district.get_control_status()
	parts.append([status.capitalize(), int(GameData.rule("building_slots").get(status, 0))])
	if district_payoffs(district)["rebuilt"]:
		parts.append(["Rebuilt (development 100%)", int(GameData.rule("payoff_rebuilt_slots"))])
	if status == "secured" and factions.has(district.owner_id()):
		for entry in factions[district.owner_id()].effects_with_labels("secured_slots"):
			parts.append([entry[0], int(entry[1])])
	return parts

func building_slots(district: District) -> int:
	if district.owner_id() == "":
		return 0
	var slots = int(GameData.rule("building_slots").get(district.get_control_status(), 0))
	if district_payoffs(district)["rebuilt"]:
		slots += int(GameData.rule("payoff_rebuilt_slots"))
	# A City Again: Secured districts take one more building
	if district.get_control_status() == "secured" and factions.has(district.owner_id()):
		slots += int(factions[district.owner_id()].effect("secured_slots"))
	return slots

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
	cap += int(factions[faction_id].reputation / GameData.rule("renown_per_crew"))
	return int(cap * factions[faction_id].effect("crew_cap_mult"))

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
	# Some ambitions speed a building up (Walls and Watches: Watchtowers in half the time)
	var days = int(ceil(def["days"] * f.effect(building_id + "_build_mult")))
	constructions.append(Construction.new(building_id, faction_id, district, int(def["crew"]), days))
	factions[faction_id].lean["home"] += 1.0
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
	if not factions.has(d.owner_id()):
		return food
	# Cleared ground grows more (a district payoff)
	return food * factions[d.owner_id()].effect("food_mult") * (GameData.rule("payoff_cleared_food") if district_payoffs(d)["cleared"] else 1.0)

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
	return (GameData.rule("housing_base") + d.development * GameData.rule("housing_per_development")) * (GameData.rule("payoff_restored_mult") if district_payoffs(d)["restored"] else 1.0)

# The first time a faction brings a district to Restored, it earns renown (once per owner)
func _check_restored():
	for d in districts:
		var owner = d.owner_id()
		if owner == "" or d.restored_by == owner or not district_payoffs(d)["restored"]:
			continue
		d.restored_by = owner
		factions[owner].add_renown(GameData.rule("payoff_restored_renown"))
		if owner == player_id:
			event.emit("%s is Restored: the ruins are gone, it's safe, fully rebuilt and firmly yours. More taxes and housing there for good (+%d renown)." % [d.district_name, GameData.rule("payoff_restored_renown")], "good")

# What a district of yours has earned by reaching its ceilings (the same for every faction): Cleared (ruins
# under 10%: more food), Safe (no danger: more manpower), Rebuilt (fully developed: one more building slot),
# and all three plus Secured: Restored (more taxes and housing)
func district_payoffs(d: District) -> Dictionary:
	var owned = d.owner_id() != ""
	var cleared = owned and d.ruin_level < 0.1
	var safe = owned and danger(d) < 0.04
	var rebuilt = owned and d.development >= 0.99
	return {"cleared": cleared, "safe": safe, "rebuilt": rebuilt,
		"restored": cleared and safe and rebuilt and d.get_control_status() == "secured"}

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
		* owner.effect("wealth_income_mult") * (GameData.rule("payoff_restored_mult") if district_payoffs(d)["restored"] else 1.0)
	var recruit_mult = 1.0
	if buildings_active(d):
		income["materials"] += d.building_effect("materials_daily")
		income["wealth"] += d.building_effect("wealth_daily")
		recruit_mult = d.building_effect("recruit_mult")
	var calm = 1.0 if d.grievance < 50.0 else (0.5 if d.grievance < 80.0 else 0.0)
	# Rebuilt districts turn food into fighters better: more homes, more young people
	income["recruits"] = district_growth_food(d) * GameData.rule("manpower_per_food") * calm * recruit_mult * (0.5 + d.development) * (GameData.rule("payoff_safe_manpower") if district_payoffs(d)["safe"] else 1.0)
	return income

# Running more districts costs more than proportionally: the brake on endless expansion
func admin_upkeep(faction_id: String) -> float:
	# The first few districts run themselves; beyond that, costs climb faster than territory
	return GameData.rule("admin_upkeep_per_district") * pow(maxf(districts_held(faction_id) - GameData.rule("admin_free_districts"), 0.0), GameData.rule("admin_upkeep_exponent"))

# Holding more land also wears on materials: patrols, barricades and repairs across a wider front
func admin_materials(faction_id: String) -> float:
	return GameData.rule("admin_materials_per_district") * pow(maxf(districts_held(faction_id) - GameData.rule("admin_free_districts"), 0.0), GameData.rule("admin_upkeep_exponent"))

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
	parts["materials"].append(["Administration (%d districts)" % districts_held(faction_id), admin_materials(faction_id)])
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
	var from_renown = int(factions[faction_id].reputation / GameData.rule("renown_per_crew"))
	if from_renown > 0:
		parts.append(["Reputation", from_renown])
	var extra = crew_cap(faction_id) - parts.reduce(func(total, part): return total + part[1], 0)
	if extra != 0:
		parts.append(["Ambitions", extra])
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
	for f in factions.values():
		f.effect_cache.clear()
		f.infamy = maxf(0.0, f.infamy - GameData.rule("infamy_decay_daily"))
	held_cache.clear()
	reach_cache.clear()
	for d in districts:
		var holder = d.owner_id()
		if holder != "":
			held_cache[holder] = held_cache.get(holder, 0) + 1
	if day % 30 == 5:
		_infamy_opinions()
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
	_check_deeds()
	_update_ambitions()
	_check_restored()
	_update_events()
	_ease_prices()
	_update_claims()
	_update_tasks()
	_check_recruitment()
	for fid in factions:
		for side in factions[fid].lean:
			factions[fid].lean[side] *= 1.0 - 1.0 / 90.0
	_update_loyalty()
	_check_first_contacts()
	_life_cycle()
	if sim_sink != null:
		sim_sink.day_end()

func _simulate_district(d: District):
	if d.occupier != "":
		_check_occupation(d)
	var owner = d.owner_id()
	var owner_faction: Faction = factions.get(owner)
	var active = buildings_active(d)
	var claimants = 0
	for fid in d.influence:
		if d.influence[fid] >= 20.0:
			claimants += 1

	d.grievance -= 0.15
	_sim_grievance(d, "daily_calming", -0.15)
	if d.occupier != "":
		d.grievance += GameData.rule("occupied_grievance_daily")
		_sim_grievance(d, "occupation", GameData.rule("occupied_grievance_daily"))
	if d.occupier == "" and owner != "":
		if d.absorb < 1.0:
			# People settle faster with a garrison among them, and slower while they are angry
			var guard = 0.5 + 0.5 * clampf(d.garrison / maxf(garrison_ceiling(d), 1.0), 0.0, 1.0)
			d.absorb = minf(1.0, d.absorb + guard * (0.5 if d.grievance > 50.0 else 1.0) / GameData.rule("absorb_days"))
			var restless = GameData.rule("absorb_grievance_daily") * (1.0 - d.absorb)
			d.grievance += restless
			_sim_grievance(d, "unsettled", restless)
		# Past your reach the strain falls on the land you added last: districts still settling in (doc 22)
		var stretched = strain_daily(owner)
		if stretched > 0.0 and d.absorb < 1.0:
			d.grievance += stretched
			_sim_grievance(d, "overstretched", stretched)
	if claimants >= 2:
		d.grievance += 0.35
		_sim_grievance(d, "rival_claimants", 0.35)
	if owner_faction:
		d.grievance += owner_faction.effect("owned_daily_grievance")
		_sim_grievance(d, "faction_effects", owner_faction.effect("owned_daily_grievance"))
	if active:
		d.grievance += d.building_effect("grievance_daily")
		_sim_grievance(d, "buildings", d.building_effect("grievance_daily"))
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

	# Only the owner is paid, and secured land pays more; an occupied district pays nobody and keeps the occupier's garrison
	if d.occupier != "":
		pass
	elif owner_faction:
		var income = district_income(d)
		# Tributaries send part of their income to their suzerain: food, materials and wealth (doc 15)
		var overlord: Faction = factions.get(overlord_of(owner))
		var rate: float = GameData.rule("tribute_rate") if overlord else 0.0
		# A house holding the district keeps its share first (doc 16)
		var keep = house_keep(d)
		for resource_type in ["supplies", "materials", "wealth"]:
			owner_faction.set(resource_type, owner_faction.get(resource_type) + income[resource_type] * keep * (1.0 - rate))
			if overlord:
				overlord.set(resource_type, overlord.get(resource_type) + income[resource_type] * keep * rate)
		# Recruits come from calm land: first to the district's own garrison, then to your manpower, up to what
		# your territory can support
		var recruits = _update_garrison(d, income["recruits"])
		if owner_faction.manpower + crew_away(owner) < crew_cap(owner):
			owner_faction.manpower += recruits
	else:
		d.garrison = 0.0

	if d.occupier == "":
		_check_unrest(d, owner)

func _check_unrest(d: District, owner: String):
	# Secured districts don't revolt
	if owner != "" and d.grievance > 80.0 and d.share(owner) < GameData.rule("secure_threshold") and rng.randf() < 0.04:
		if sim_sink != null:
			sim_sink.revolt(d.id)
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
		"tasks": tasks.map(func(t): return t.to_dict()), "pending_events": pending_events.duplicate(true), "proposals": proposals.duplicate(true), "demand_warned": demand_warned.duplicate(), "player_defeated": player_defeated,
		"characters": characters.map(func(c): return c.to_dict()), "next_character_id": next_character_id, "departed": departed.duplicate(true), "player_met": player_met.duplicate(), "next_split_id": next_split_id, "houses": houses.duplicate(true), "next_house_id": next_house_id, "graveyard": graveyard.map(func(c): return c.to_dict()),
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
	for td in data["tasks"]:
		tasks.append(StandingTask.from_dict(td))
	pending_events = data["pending_events"]
	proposals = data["proposals"]
	demand_warned = data["demand_warned"]
	player_defeated = data["player_defeated"]
	for cd in data["characters"]:
		characters.append(Character.from_dict(cd))
	next_character_id = int(data["next_character_id"])
	departed = data["departed"]
	player_met = data["player_met"]
	next_split_id = int(data["next_split_id"])
	houses = data["houses"]
	next_house_id = int(data["next_house_id"])
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

# What a deed's condition can measure (see data/deeds.json)
const DEED_CONDITIONS = ["districts_held", "secured_districts", "buildings_owned", "building_type", "trade_agreements",
	"alliances", "vassals", "crew_total", "traits_active", "population", "districts_conquered", "wars_won"]

# Progress toward a deed as [current, target]
func deed_progress(faction_id: String, deed_id: String) -> Array:
	var condition: Dictionary = GameData.deeds()[deed_id]["condition"]
	return [measure(faction_id, condition), int(condition["amount"])]

# How much of something a faction has, for deeds and ambition requirements ("districts_held", ...)
func measure(faction_id: String, condition: Dictionary) -> int:
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
	return current

# Deeds: the same milestones for every faction; each one done earns renown (and reputation)
func _check_deeds():
	for f in factions.values():
		for id in GameData.deeds():
			if id in f.deeds_done:
				continue
			var progress = deed_progress(f.id, id)
			if progress[0] < progress[1]:
				continue
			var deed = GameData.deeds()[id]
			f.deeds_done.append(id)
			f.add_renown(deed["renown"])
			if f.id == player_id:
				event.emit("Deed done: %s. %s (+%d renown)" % [deed["label"], deed["description"], deed["renown"]], "good")
			else:
				event.emit("The %s: \"%s\" (+%d renown)." % [f.display_name, deed["label"], deed["renown"]], "info")

# --- Choice events (doc 14, slice 1) -------------------------------------------------------

# The moments that can bring a choice event, and the faction effects an event option can apply (for a time)
const EVENT_MOMENTS = ["coming_of_age", "birth", "death", "venture_triumph", "venture_disaster", "pulse", "education", "childhood", "match"]
# What an option can need before it can be picked ("" for nothing)
const EVENT_NEEDS = ["", "school", "councillor", "match", "house_match"]
# Who a "marry" option weds: a captain or councillor, someone from the people, or one of a house
const MARRY_KINDS = ["captain", "people", "house"]
const EVENT_EFFECTS = ["wealth_income_mult", "trade_income_mult", "food_mult", "scavenge_yield_mult", "defence_mult",
	"diplomacy_mult", "crew_cap_mult", "owned_daily_grievance", "split_chance_mult", "heir_claim", "demand_acceptance_mult", "reach_bonus"]
# How the effects read, for the option buttons and the outliner
const EFFECT_WORDS = {"wealth_income_mult": "wealth income", "trade_income_mult": "trade income", "food_mult": "food",
	"scavenge_yield_mult": "scavenging yield", "defence_mult": "attacks on your land", "diplomacy_mult": "treaty acceptance",
	"crew_cap_mult": "manpower limit", "owned_daily_grievance": "grievance a day", "split_chance_mult": "split chance at a succession",
	"heir_claim": "the heir's claim", "demand_acceptance_mult": "demands for tribute paid", "reach_bonus": "districts you can hold well"}
const EVENT_PULSE_DAYS = [90, 120]

# Choice events waiting for the player's answer: [{"event", "subject", "venture"}] (the game waits on them)
var pending_events: Array = []

func _first_upper(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)

# What an option does, in words: "Food -10%, grievance a day -0.02, for 30 days"
func event_option_text(option: Dictionary, venture_id: String = "", entry: Dictionary = {}) -> String:
	var shaping = _child_shaping_text(option, entry)
	match option.get("marry", ""):
		"captain":
			shaping = "They join the family: their loyalty +%d for good; the children lean toward their skills and nature" % GameData.rule("married_in_loyalty")
		"people":
			shaping = "One of your people joins the family (Of the People): the children lean that way too"
		"house":
			shaping = "They leave their house to join your family; the house's loyalty +20 for good (a house bound by marriage rarely revolts)"
	if shaping == "" and option.has("note"):
		shaping = option["note"]
	if not option.has("days"):
		return shaping
	var timed = _timed_option_text(option, venture_id, entry)
	return timed if shaping == "" else "%s. %s" % [shaping, timed]

# How an option shapes the child: "Leans Brave +2, Command +1", or what an upbringing does each year
func _child_shaping_text(option: Dictionary, entry: Dictionary) -> String:
	if option.has("upbringing"):
		var def = GameData.council()["upbringings"][option["upbringing"]]
		var skills = []
		for s in def["skills"]:
			skills.append(_entry_tutor_skill(entry, option["upbringing"]).capitalize() if s == "$tutor" else ("the parents' best skills" if s == "$parents" else s.capitalize()))
		var leans = []
		for t in def["leanings"]:
			if t.begins_with("$"):
				leans.append({"$tutor_nature": "the tutor's nature", "$parents_nature": "the parents' nature"}[t])
			else:
				leans.append(GameData.character_trait(t)["label"])
		return "Each year: %s %s faster; leans toward %s" % [" and ".join(skills), "grow" if skills.size() > 1 or "skills" in skills[0] else "grows", " and ".join(leans)]
	var parts = []
	var shaping: Dictionary = option.get("child", {})
	for t in shaping.get("leanings", {}):
		parts.append("%s %+d" % [GameData.character_trait(t)["label"], shaping["leanings"][t]])
	for s in shaping.get("skills", {}):
		parts.append("%s %+d" % ["Best skill" if s == "$best" else s.capitalize(), shaping["skills"][s]])
	return "" if parts.is_empty() else "%s leans %s" % [entry.get("subject", "The child").get_slice(" ", 0) if entry.get("subject", "") != "" else "The child", ", ".join(parts)]

func _timed_option_text(option: Dictionary, venture_id: String, entry: Dictionary) -> String:
	var parts = []
	for name in option.get("effects", {}):
		var value: float = option["effects"][name]
		if name.ends_with("_mult"):
			parts.append("%s %+d%%" % [_first_upper(EFFECT_WORDS.get(name, name)) if parts.is_empty() else EFFECT_WORDS.get(name, name), roundi((value - 1.0) * 100)])
		else:
			parts.append("%s %+.2f" % [_first_upper(EFFECT_WORDS.get(name, name)) if parts.is_empty() else EFFECT_WORDS.get(name, name), value] if absf(value) < 1.0 else "%s %+d" % [EFFECT_WORDS.get(name, name), value])
	for v in option.get("venture_odds", {}):
		var id = venture_id if v == "$venture" else v
		var label = GameData.venture(id)["label"] if GameData.ventures().has(id) else "that venture"
		parts.append("%s odds %+d%%" % [label, roundi((option["venture_odds"][v] - 1.0) * 100)])
	for s in option.get("skill_odds", {}):
		# A councillor who teaches has less time for their own work
		var skill = ("%s's teaching: %s" % [character_by_id(int(entry["tutor_id"])).name, _entry_tutor_skill(entry, "tutor")]) if s == "$tutor" and character_by_id(int(entry.get("tutor_id", -1))) else s
		parts.append("%s ventures %+d%%" % [skill.capitalize() if s != "$tutor" else skill, roundi((option["skill_odds"][s] - 1.0) * 100)])
	return "%s, for %d days" % [", ".join(parts), option["days"]]

# Something happened to a character: a choice event of that kind may follow. The player answers theirs;
# the AI picks by the same visible leanings (pillar 3)
func _fire_moment(faction_id: String, moment: String, subject: Character, venture_id: String = ""):
	var f: Faction = factions.get(faction_id)
	if f == null:
		return
	var pool = []
	var total = 0.0
	for id in GameData.events():
		var ev = GameData.events()[id]
		if ev["moment"] != moment:
			continue
		# The same everyday event won't come back for two years
		if moment == "pulse" and day - int(f.event_last.get(id, -9999)) < 720:
			continue
		# Childhood events fit how the child is being raised, and each comes once per child
		if moment == "childhood" and subject and (id in subject.childhood or (ev.has("upbringing") and subject.upbringing not in ev["upbringing"])):
			continue
		pool.append(id)
		total += float(ev.get("weight", 1.0))
	if pool.is_empty():
		return
	var roll = rng.randf() * total
	var chosen = pool[0]
	for id in pool:
		roll -= float(GameData.events()[id].get("weight", 1.0))
		if roll <= 0.0:
			chosen = id
			break
	f.event_last[chosen] = day
	f.next_event_day = day + rng.randi_range(EVENT_PULSE_DAYS[0], EVENT_PULSE_DAYS[1])
	if faction_id == player_id:
		_stop("choice", moment)
	var entry = {"event": chosen, "subject": subject.name if subject else "", "subject_id": subject.id if subject else -1, "venture": venture_id}
	if moment == "childhood":
		subject.childhood.append(chosen)
	if moment == "education":
		_offer_tutors(faction_id, entry)
		subject.upbringing_day = day
	if moment == "match":
		var candidate = match_candidate(subject)
		entry["match_id"] = candidate.id if candidate else -1
		var from_house = house_match_candidate(subject)
		entry["house_match_id"] = from_house.id if from_house else -1
	if faction_id == player_id and f.ai == null:
		pending_events.append(entry)
		return
	# The AI weighs each option it can take by its own leanings, and picks
	var options: Array = GameData.events()[chosen]["options"]
	var weights = options.map(func(o): return 0.0 if event_option_blocked(faction_id, entry, o) != "" else float(o.get("ai_weight", 1.0)) * FactionAI.temperament(o["ai_goal"], f))
	var pick = rng.randf() * weights.reduce(func(a, b): return a + b, 0.0)
	var index = 0
	for i in options.size():
		pick -= weights[i]
		if pick <= 0.0:
			index = i
			break
	apply_event_option(faction_id, entry, index)

# An option's effects take hold for its days
func apply_event_option(faction_id: String, entry: Dictionary, index: int):
	var f: Faction = factions.get(faction_id)
	if f == null:
		return
	var ev = GameData.events()[entry["event"]]
	var option: Dictionary = ev["options"][index]
	if event_option_blocked(faction_id, entry, option) != "":
		return
	var label = event_option_label(entry, option)
	var summary = event_option_text(option, entry["venture"], entry)
	if option.has("days"):
		var odds = {}
		for v in option.get("venture_odds", {}):
			odds[entry["venture"] if v == "$venture" else v] = option["venture_odds"][v]
		var skill_odds = {}
		for s in option.get("skill_odds", {}):
			skill_odds[_entry_tutor_skill(entry, "tutor") if s == "$tutor" else s] = option["skill_odds"][s]
		f.timed_effects.append({"label": ev["title"], "choice": label, "summary": summary,
			"until": day + int(option["days"]), "effects": option.get("effects", {}).duplicate(), "venture_odds": odds, "skill_odds": skill_odds})
		f.effect_cache.clear()
	var child = character_by_id(int(entry.get("subject_id", -1)))
	if child and option.has("marry") and child.spouse_id < 0:
		_wed(child, option["marry"], character_by_id(int(entry.get("house_match_id" if option["marry"] == "house" else "match_id", -1))))
		if faction_id == player_id:
			var spouse = character_by_id(child.spouse_id)
			if spouse:
				event.emit("%s marries %s." % [child.name, spouse.name], "good")
	if child:
		if option.has("upbringing"):
			# A councillor taken off the child's lessons resents it
			var old_tutor = character_by_id(child.tutor_id) if child.upbringing == "tutor" else null
			if old_tutor and not (option["upbringing"] == "tutor" and int(entry["tutor_id"]) == old_tutor.id):
				old_tutor.change_loyalty(GameData.rule("dropped_tutor_loyalty"), "dropped_tutor")
				if faction_id == player_id:
					event.emit("%s is no longer %s's tutor, and resents it (loyalty %d)." % [old_tutor.name, child.name, GameData.rule("dropped_tutor_loyalty")], "bad")
			child.upbringing_day = day
			child.upbringing = option["upbringing"]
			child.tutor_id = int(entry["tutor_id"]) if child.upbringing == "tutor" else -1
			child.tutor_skill = _entry_tutor_skill(entry, child.upbringing) if child.upbringing in ["tutor", "hired"] else ""
		var shaping: Dictionary = option.get("child", {})
		for t in shaping.get("leanings", {}):
			child.leanings[t] = float(child.leanings.get(t, 0.0)) + float(shaping["leanings"][t])
		for s in shaping.get("skills", {}):
			var skill = child.best_skill() if s == "$best" else s
			child.skills[skill] = mini(10, int(child.skills[skill]) + int(shaping["skills"][s]))
	if faction_id == player_id:
		event.emit("%s: %s. %s." % [ev["title"], label, summary], "info")

# The tutor on offer is the ablest councillor; a hired one teaches one skill
func _offer_tutors(faction_id: String, entry: Dictionary):
	var tutor: Character = null
	for c in characters_of(faction_id):
		if c.post != "" and (tutor == null or c.best_skill_value() > tutor.best_skill_value()):
			tutor = c
	entry["tutor_id"] = tutor.id if tutor else -1
	entry["hired_skill"] = Character.SKILLS[rng.randi() % Character.SKILLS.size()]

# "" if this child's upbringing can be changed now, otherwise why not
func check_upbringing_change(c: Character) -> String:
	if c == null or c.death_day >= 0:
		return "No such child"
	if c.is_adult():
		return "%s is grown: their upbringing is behind them" % c.name
	if c.upbringing == "":
		return "Chosen when they turn %d (in %d years)" % [GameData.rule("schooling_age"), int(GameData.rule("schooling_age")) - c.age]
	if pending_events.any(func(e): return int(e.get("subject_id", -1)) == c.id):
		return "A choice about %s is already waiting" % c.name
	var wait = c.upbringing_day + int(GameData.rule("upbringing_change_days")) - day
	if wait > 0:
		return "Changed lately: wait %d more days" % wait
	return ""

# The player reopens the choice: the years so far stay with the child, the new upbringing shapes the rest
func request_upbringing_change(c: Character) -> String:
	var err = check_upbringing_change(c)
	if err != "":
		return err
	var entry = {"event": "upbringing", "subject": c.name, "subject_id": c.id, "venture": "", "change": true}
	_offer_tutors(c.faction_id, entry)
	pending_events.append(entry)
	return ""

# The player keeps things as they are (only a change of upbringing can be turned down)
func decline_event():
	if not pending_events.is_empty() and pending_events[0].get("change", false):
		pending_events.pop_front()

# "" if the option can be picked, otherwise what's missing and where to get it
func event_option_blocked(faction_id: String, entry: Dictionary, option: Dictionary) -> String:
	var child = character_by_id(int(entry.get("subject_id", -1)))
	if entry.get("change", false) and child and option.get("upbringing", "") == child.upbringing:
		if child.upbringing != "tutor" or int(entry.get("tutor_id", -1)) == child.tutor_id:
			return "Already raised this way"
	match option.get("needs", ""):
		"school":
			if not has_school(faction_id):
				return "Needs a School in your land (Build, in any district you hold)"
		"councillor":
			if int(entry.get("tutor_id", -1)) < 0 or character_by_id(int(entry["tutor_id"])) == null:
				return "Nobody sits on your council to teach: seat a captain in the Council window"
		"match":
			var candidate = character_by_id(int(entry.get("match_id", -1)))
			if candidate == null or candidate.spouse_id >= 0:
				return "No unmarried captain of a fitting age (recruit more captains, or look to your people)"
		"house_match":
			var from_house = character_by_id(int(entry.get("house_match_id", -1)))
			if from_house == null or from_house.spouse_id >= 0 or from_house.house_id < 0:
				return "No house has an unmarried match of a fitting age (houses come from Vassalize, or granting land)"
	return ""

func has_school(faction_id: String) -> bool:
	for d in districts:
		if d.owner_id() == faction_id and d.building_effect("school") > 0.0 and buildings_active(d):
			return true
	return false

# The skill a tutor on offer would teach: the councillor's best, or the hired tutor's
func _entry_tutor_skill(entry: Dictionary, upbringing: String) -> String:
	var tutor = character_by_id(int(entry.get("tutor_id", -1)))
	if upbringing == "tutor" and tutor:
		return tutor.best_skill()
	return String(entry.get("hired_skill", "stewardship"))

# An option's label, with the tutor on offer named
func event_option_label(entry: Dictionary, option: Dictionary) -> String:
	var label: String = option["label"]
	var tutor = character_by_id(int(entry.get("tutor_id", -1)))
	label = label.replace("{tutor}", "%s (%s %d)" % [tutor.name, tutor.best_skill().capitalize(), tutor.best_skill_value()] if tutor else "nobody free")
	var from_house = character_by_id(int(entry.get("house_match_id", -1)))
	label = label.replace("{house}", house(from_house.house_id).get("name", "?") if from_house and from_house.house_id >= 0 else "(none)")
	label = label.replace("{house_match}", "%s (%d, %s %d)" % [from_house.name, from_house.age, from_house.best_skill().capitalize(), from_house.best_skill_value()] if from_house else "nobody")
	var candidate = character_by_id(int(entry.get("match_id", -1)))
	label = label.replace("{match}", "%s (%s, %d, %s %d)" % [candidate.name, GameData.council_post(candidate.post)["label"] if candidate.post != "" else "captain", candidate.age, candidate.best_skill().capitalize(), candidate.best_skill_value()] if candidate else "a captain")
	return label.replace("{hired}", String(entry.get("hired_skill", "")).capitalize())

# The player answers the first waiting event
func answer_event(index: int):
	if pending_events.is_empty():
		return
	var entry = pending_events.pop_front()
	apply_event_option(player_id, entry, index)

# The text of a waiting event, with names filled in
func event_text(entry: Dictionary) -> String:
	var ev = GameData.events()[entry["event"]]
	var label = GameData.venture(entry["venture"])["label"].to_lower() if entry["venture"] != "" and GameData.ventures().has(entry["venture"]) else "venture"
	var text: String = ev["change_text"] if entry.get("change", false) and ev.has("change_text") else ev["text"]
	return text.replace("{name}", entry["subject"] if entry["subject"] != "" else "Someone").replace("{venture}", label)

# Daily: effects wear off; every 3-4 months, an everyday event for each faction
func _update_events():
	for f in factions.values():
		var before = f.timed_effects.size()
		f.timed_effects = f.timed_effects.filter(func(t): return t["until"] > day)
		if f.timed_effects.size() != before:
			f.effect_cache.clear()
		if day >= f.next_event_day:
			_fire_moment(f.id, "pulse", leader_of(f.id))

# --- Standing tasks (doc 13) --------------------------------------------------------------

# Routine work that, on your own land, is done as a councillor's standing task
func is_task(faction_id: String, venture_id: String, d: District) -> bool:
	var def = GameData.venture(venture_id)
	if not def.get("task", false) or d.owner_id() != faction_id:
		return false
	# Answering an attack under way is no routine: any free captain can lead the guard, once
	return not (def.get("needs", "") == "threat" and under_attack(faction_id, d))

func under_attack(faction_id: String, d: District) -> bool:
	return incoming_attacks(faction_id).any(func(v): return v.district == d)

func task_of(c: Character) -> StandingTask:
	for t in tasks:
		if t.character_id == c.id:
			return t
	return null

func task_at(faction_id: String, venture_id: String, d: District) -> StandingTask:
	for t in tasks:
		if t.faction_id == faction_id and t.venture_id == venture_id and t.district_id == d.id:
			return t
	return null

# Councillors free to take a task, best at the skill first
func free_councillors(faction_id: String, skill: String) -> Array:
	var free = available_leaders(faction_id).filter(func(c): return c.post != "")
	free.sort_custom(func(a, b): return a.skills[skill] > b.skills[skill])
	return free

# Why nobody on the council can take a task right now
func council_availability(faction_id: String) -> String:
	var seated = characters_of(faction_id).filter(func(c): return c.post != "")
	if seated.is_empty():
		return "Nobody sits on your council: seat captains in the Council window to give them tasks"
	var parts = []
	for c in seated:
		var t = task_of(c)
		if t:
			parts.append("%s %s %s" % [c.name, GameData.venture(t.venture_id)["task_label"].to_lower(), districts[t.district_id].district_name])
		elif c.committed_until > day:
			parts.append("%s free in %d days" % [c.name, c.committed_until - day])
		else:
			var why = unavailable_reason(c)
			if why != "":
				parts.append("%s %s" % [c.name, why])
	return "No councillor is free: " + ", ".join(parts)

# "" if this councillor (-2: the best free one) can take this task here, otherwise why not
func check_task(faction_id: String, venture_id: String, d: District, character_id: int = -2, crew: int = -1) -> String:
	if not is_task(faction_id, venture_id, d):
		if d.owner_id() == faction_id and under_attack(faction_id, d):
			return "Under attack: any free captain can lead this now, as a one-off"
		return "Only on your own land"
	if task_at(faction_id, venture_id, d):
		return "Already under way here"
	var done = task_done_reason(faction_id, venture_id, d)
	if done != "":
		return "Nothing to do: %s" % done
	var c: Character = null
	if character_id == -2:
		var free = free_councillors(faction_id, GameData.venture(venture_id)["skill"])
		c = free[0] if not free.is_empty() else null
		if c == null:
			return council_availability(faction_id)
	else:
		c = character_by_id(character_id)
		if c == null or c.faction_id != faction_id or c.post == "":
			return "Only a councillor can take a standing task"
		if leader_busy(c) or c.is_wounded(day):
			return "%s isn't free: %s" % [c.name, unavailable_reason(c) if unavailable_reason(c) != "" else "committed for %d more days" % (c.committed_until - day)]
	var size = crew if crew > 0 else recommended_plan(faction_id, venture_id, d, c)["crew"]
	return check_launch(faction_id, venture_id, d, c.id, size, 0, true)

# Why a task here would have nothing left to do ("" while there's work): the district's own state
func task_done_reason(faction_id: String, venture_id: String, d: District) -> String:
	var def = GameData.venture(venture_id)
	if def["target"] == "scavenge" and d.ruin_level < 0.1:
		return "the ruins are stripped bare"
	if d.grievance < def.get("min_grievance", 0.0):
		return "the district is calm"
	match def.get("needs", ""):
		"food":
			if d.food_yield >= GameData.rule("food_source_cap") - 0.001:
				return "every food source is worked"
		"control":
			if d.share(faction_id) >= 95.0 and danger(d) < 0.04:
				return "it's fully under your control, and safe"
		"development":
			if d.development >= 0.99:
				return "it's fully rebuilt"
		"arms":
			if factions[faction_id].arms >= GameData.rule("arms_cap"):
				return "the armoury is full"
		"threat":
			if not district_threatened(faction_id, d):
				return "the threat has passed"
	return ""

# The councillor goes to the district and starts at once; they're committed for two runs
func assign_task(faction_id: String, venture_id: String, d: District, character_id: int = -2, crew: int = -1) -> String:
	var err = check_task(faction_id, venture_id, d, character_id, crew)
	if err != "":
		return err
	var def = GameData.venture(venture_id)
	var c: Character = character_by_id(character_id) if character_id != -2 else free_councillors(faction_id, def["skill"])[0]
	var size = crew if crew > 0 else recommended_plan(faction_id, venture_id, d, c)["crew"]
	var runs = int(GameData.rule("task_commit_runs"))
	var t = StandingTask.new(venture_id, faction_id, c.id, d.id, size, day, day + runs * venture_days(venture_id, c, d))
	launch_venture(faction_id, venture_id, d, c.id, size, 0, true)
	t.runs = 1
	tasks.append(t)
	if faction_id == player_id:
		event.emit("%s starts %s %s with %d crew, until %s. Committed for %d days." % [c.name, def["task_label"].to_lower(), d.district_name,
			size, task_goal(def), t.committed_until - day], "good")
	return ""

# What ends a task, in words, for the log and the planner
func task_goal(def: Dictionary) -> String:
	if def["target"] == "scavenge":
		return "the ruins are stripped"
	if def.has("min_grievance"):
		return "the district is calm"
	return {"food": "every food source is worked", "control": "it's fully under your control and safe", "development": "it's fully rebuilt",
		"arms": "the armoury is full", "threat": "the threat passes"}.get(def.get("needs", ""), "the job is done")

# The player pulls a councillor off: the run under way finishes, then the task ends
func stop_task(t: StandingTask):
	var running = ventures.any(func(v): return v.task and v.leader_id == t.character_id)
	if running:
		t.stopping = true
	else:
		_end_task(t, "stopped", false)

# After each run (and daily while paused): carry on, wait, or finish
func _continue_task(t: StandingTask):
	var f: Faction = factions.get(t.faction_id)
	var c = character_by_id(t.character_id)
	var d: District = districts[t.district_id]
	if f == null or c == null or c.faction_id != t.faction_id:
		_stop_task_end(t, "councillor_gone")
		_end_task(t, "%s is gone" % (c.name if c else "the councillor"), true)
		return
	if c.post == "":
		_stop_task_end(t, "left_council")
		_end_task(t, "%s left the council" % c.name, true)
		return
	if d.owner_id() != t.faction_id:
		_stop_task_end(t, "district_lost")
		_end_task(t, "%s was lost" % d.district_name, true)
		return
	if d.occupier != "":
		_stop_task_end(t, "district_occupied")
		_end_task(t, "%s was occupied" % d.district_name, true)
		return
	if t.stopping:
		_end_task(t, "stopped", false)
		return
	var done = task_done_reason(t.faction_id, t.venture_id, d)
	if done != "":
		_stop_task_end(t, "completed")
		_end_task(t, done, true)
		return
	if c.is_wounded(day):
		t.paused = "wounded"
		return
	var err = check_launch(t.faction_id, t.venture_id, d, c.id, t.crew, 0, true)
	if err != "":
		# Said once when it starts waiting (the outliner keeps the reason up to date); news, not a reason to pause
		if t.paused == "" and t.faction_id == player_id:
			_stop("task_waiting", err)
			event.emit("%s's %s in %s is waiting: %s." % [c.name, GameData.venture(t.venture_id)["label"], d.district_name, err.to_lower()], "bad")
		t.paused = err
		return
	t.paused = ""
	launch_venture(t.faction_id, t.venture_id, d, c.id, t.crew, 0, true)
	t.runs += 1

func _stop_task_end(t: StandingTask, cause: String):
	if t.faction_id == player_id:
		_stop("task", cause)

# The task ends: done (the councillor is free at once) or stopped (free once the commitment has passed)
func _end_task(t: StandingTask, why: String, natural: bool):
	tasks.erase(t)
	var c = character_by_id(t.character_id)
	if c and not natural:
		c.committed_until = maxi(c.committed_until, t.committed_until)
	if t.faction_id != player_id:
		return
	var def = GameData.venture(t.venture_id)
	var who = c.name if c else "The councillor"
	var text = "%s has finished %s %s: %s (%d runs%s)." % [who, def["task_label"].to_lower(), districts[t.district_id].district_name, why, t.runs, _gains_text(t.gains)]
	if natural:
		text += " %s is free for a new task." % who
	elif c and c.committed_until > day:
		text += " %s is free in %d days." % [who, c.committed_until - day]
	event.emit(text, "good" if natural else "info")

func _gains_text(gains: Dictionary) -> String:
	var parts = []
	for key in gains:
		if int(gains[key]) != 0:
			parts.append("%+d %s" % [gains[key], "food" if key == "supplies" else key])
	return (", " + ", ".join(parts)) if not parts.is_empty() else ""

# Daily: paused tasks try again; every 30 days, one digest line per task of yours
func _update_tasks():
	for t in tasks.duplicate():
		if t.paused != "":
			_continue_task(t)
	if day % int(GameData.rule("task_digest_days")) != 0:
		return
	for t in tasks:
		if t.faction_id != player_id:
			continue
		var c = character_by_id(t.character_id)
		var d: District = districts[t.district_id]
		event.emit("%s, %s %s: %d runs this month%s. %s%s" % [c.name if c else "?", GameData.venture(t.venture_id)["task_label"].to_lower(), d.district_name,
			t.digest_runs, _gains_text(t.gains), task_progress_text(t), ("  Waiting: " + t.paused) if t.paused != "" else ""], "info")
		t.gains = {}
		t.digest_runs = 0

# Where a task stands against its end, e.g. "Ruins 31% (done under 10%)"
func task_progress_text(t: StandingTask) -> String:
	return task_stat_text(t.faction_id, t.venture_id, districts[t.district_id])

# The stat a task works on in a district, against its end (also shown on the map when picking a district)
func task_stat_text(faction_id: String, venture_id: String, d: District) -> String:
	var def = GameData.venture(venture_id)
	if def["target"] == "scavenge":
		return "Ruins %d%% (done under 10%%)" % (d.ruin_level * 100)
	if def.has("min_grievance"):
		return "Grievance %d (done under %d)" % [d.grievance, def["min_grievance"]]
	match def.get("needs", ""):
		"food":
			return "Food sources %.2f of %.1f" % [d.food_yield, GameData.rule("food_source_cap")]
		"control":
			return "Control %d of 95, danger %d%%" % [d.share(faction_id), danger(d) * 100]
		"development":
			return "Development %d%% of 100%%" % (d.development * 100)
		"arms":
			return "Arms %d of %d" % [factions[faction_id].arms, GameData.rule("arms_cap")]
		"threat":
			return "Guarding while the threat lasts"
	return ""

# --- National Ambitions (S4, doc 12) --------------------------------------------------------

# What an ambition's requirements can check: everything a deed can count, plus these
const AMBITION_CONDITIONS = ["districts_held", "secured_districts", "buildings_owned", "building_type", "trade_agreements",
	"alliances", "vassals", "crew_total", "traits_active", "population", "districts_conquered", "wars_won",
	"trait", "treaties", "raided_or_war", "food_short", "materials_below", "council_loyalty_below", "split_risk",
	"leader_skill", "leader_trait", "ambitions_done", "ambition_done", "recent_succession", "grievance_below", "at_peace", "past_gang", "over_reach"]

# Whether one requirement holds, and how to say it: [met, "Militaristic", "2 treaties (you have 1)"]
func condition_status(faction_id: String, condition: Dictionary) -> Array:
	var f: Faction = factions[faction_id]
	var leader = leader_of(faction_id)
	match condition["type"]:
		"trait":
			return [f.traits.is_active(condition["trait"]), condition["trait"]]
		"treaties":
			var count = 0
			for fid in factions:
				if fid != faction_id:
					var r = relation(faction_id, fid)
					count += 1 if (r.trade or r.pact or r.alliance or r.overlord != "") else 0
			return [count >= int(condition["amount"]), "%d treaties (you have %d)" % [condition["amount"], count]]
		"raided_or_war":
			var hit = at_war_with_anyone(faction_id)
			for fid in factions:
				if fid != faction_id and relation(faction_id, fid).last_raid[fid] > 0 and day - relation(faction_id, fid).last_raid[fid] <= int(condition["days"]):
					hit = true
			return [hit, "raided or at war in the last %d days" % condition["days"]]
		"food_short":
			var econ = daily_economy(faction_id)["supplies"]
			var net: float = econ["income"] - econ["upkeep"]
			return [net < condition["below"], "food short (under %+.1f a day; you make %+.2f)" % [condition["below"], net]]
		"materials_below":
			return [f.materials < condition["amount"], "materials under %d (you have %d)" % [condition["amount"], f.materials]]
		"council_loyalty_below":
			var low = characters_of(faction_id).filter(func(c): return c.post != "" and c.loyalty() < condition["amount"])
			return [not low.is_empty(), "a councillor under %d loyalty" % condition["amount"]]
		"split_risk":
			var risk: float = succession_outlook(faction_id)["split_chance"]
			return [risk >= condition["amount"], "civil war risk %d%%+ (now %d%%)" % [condition["amount"] * 100, risk * 100]]
		"leader_skill":
			var value = int(leader.skills[condition["skill"]]) if leader else 0
			return [value >= int(condition["amount"]), "a leader with %s %d+ (yours: %d)" % [String(condition["skill"]).capitalize(), condition["amount"], value]]
		"leader_trait":
			var label: String = GameData.character_trait(condition["trait"])["label"]
			return [leader != null and leader.has_trait(condition["trait"]), "a %s leader" % label]
		"ambitions_done":
			return [f.ambitions_done.size() >= int(condition["amount"]), "%d ambition%s achieved (you have %d)" % [condition["amount"], "" if int(condition["amount"]) == 1 else "s", f.ambitions_done.size()]]
		"ambition_done":
			return [condition["ambition"] in f.ambitions_done, "%s achieved" % GameData.national_ambition(condition["ambition"])["label"]]
		"recent_succession":
			var since = day - f.last_succession_day
			return [since <= int(condition["days"]), "a leader who died in the last %d days" % condition["days"]]
		"grievance_below":
			var total = 0.0
			var count = 0
			for d in districts:
				if d.owner_id() == faction_id:
					total += d.grievance
					count += 1
			var average = total / maxf(1.0, count)
			return [average < condition["amount"], "average grievance under %d (now %d)" % [condition["amount"], average]]
		"at_peace":
			return [not at_war_with_anyone(faction_id), "at peace"]
		"over_reach":
			var held_now = districts_held(faction_id)
			return [held_now > reach(faction_id), "more land than your reach (you hold %d of %d)" % [held_now, roundi(reach(faction_id))]]
		"past_gang":
			return [f.government != "gang", "a government past the gang crew (a reform, in Ambitions)"]
	var have = measure(faction_id, condition)
	var names = {"districts_held": "districts", "secured_districts": "Secured districts", "buildings_owned": "buildings", "trade_agreements": "trade agreements",
		"alliances": "alliances", "vassals": "tributaries", "building_type": GameData.building(condition.get("building", "market"))["label"] + "s"}
	return [have >= int(condition["amount"]), "%d %s (you have %d)" % [condition["amount"], names.get(condition["type"], condition["type"]), have]]

# Every way of qualifying for an ambition, each a list of [met, text]: any one fully met option will do
func ambition_options(faction_id: String, ambition_id: String) -> Array:
	var options = []
	for option in GameData.national_ambition(ambition_id)["requires"]:
		options.append(option.map(func(condition): return condition_status(faction_id, condition)))
	return options

func ambition_qualifies(faction_id: String, ambition_id: String) -> bool:
	return ambition_options(faction_id, ambition_id).any(func(option): return option.all(func(s): return s[0]))

# How long an ambition takes this faction
func ambition_days(faction_id: String, ambition_id: String) -> int:
	return int(ceil(GameData.national_ambition(ambition_id)["days"] * factions[faction_id].effect("ambition_days_mult")))

# "" if the faction can start this ambition now, otherwise why not (and what to do about it)
func check_ambition(faction_id: String, ambition_id: String) -> String:
	var f: Faction = factions[faction_id]
	var def = GameData.national_ambition(ambition_id)
	if ambition_id in f.ambitions_done:
		return "Already achieved"
	if ambition_id in f.ambitions_closed:
		return "Closed for good by an ambition you chose"
	if f.ambition != "":
		return "You're already pursuing %s (%d days left)" % [GameData.national_ambition(f.ambition)["label"], f.ambition_days_left]
	if not f.can_afford(def["cost"]):
		return f.shortfall(def["cost"])
	if not ambition_qualifies(faction_id, ambition_id):
		var options = ambition_options(faction_id, ambition_id).map(func(option): return " and ".join(option.filter(func(s): return not s[0]).map(func(s): return s[1])))
		return "Needs " + " or ".join(options)
	return ""

func start_ambition(faction_id: String, ambition_id: String) -> String:
	var err = check_ambition(faction_id, ambition_id)
	if err != "":
		return err
	var f: Faction = factions[faction_id]
	var def = GameData.national_ambition(ambition_id)
	f.pay(def["cost"])
	f.ambition = ambition_id
	f.ambition_days_left = ambition_days(faction_id, ambition_id)
	f.lean["home"] += 1.0
	# Choosing one road closes the other for good
	for other in def.get("closes", []):
		if other not in f.ambitions_closed:
			f.ambitions_closed.append(other)
	if faction_id == player_id:
		event.emit("You set out on %s: %d days. %s" % [def["label"], f.ambition_days_left, def["bonus_text"]], "good")
	elif player_met.has(faction_id):
		event.emit("The %s set out on %s." % [f.display_name, def["label"]], "info")
	return ""

# An ambition's condition while running was broken (e.g. a raid during Welfare for All): it fails, the renown is gone
func fail_ambition(faction_id: String, why: String):
	var f: Faction = factions[faction_id]
	if f.ambition == "":
		return
	var label: String = GameData.national_ambition(f.ambition)["label"]
	f.ambition = ""
	f.ambition_days_left = 0
	if faction_id == player_id:
		event.emit("%s has failed: %s. The renown spent on it is lost." % [label, why], "bad")
	elif player_met.has(faction_id):
		event.emit("The %s abandoned %s (%s)." % [f.display_name, label, why], "info")

# Daily: ambitions under way count down; a finished one's bonus lasts for good
func _update_ambitions():
	for f in factions.values():
		if f.ambition == "":
			continue
		f.ambition_days_left -= 1
		if f.ambition_days_left > 0:
			continue
		var id = f.ambition
		var def = GameData.national_ambition(id)
		f.ambition = ""
		f.ambitions_done.append(id)
		f.effect_cache.clear()
		var loyalty: float = def["bonus"].get("council_loyalty", 0.0)
		if loyalty != 0.0:
			for c in characters_of(f.id):
				if c.post != "":
					c.change_loyalty(loyalty, "sworn_loyalty")
		if f.id == player_id:
			major_event.emit(def["label"], "Your crew has achieved %s. From now on: %s." % [def["label"], def["bonus_text"]], "")
		elif player_met.has(f.id):
			event.emit("The %s achieved %s: %s." % [f.display_name, def["label"], def["bonus_text"]], "info")

# --- Decisions (doc 21) ----------------------------------------------------------------------------
# Instant and deterministic: pay, and the change takes hold at once. They change how the faction is run, they don't act
# on the world, so there is no crew and no odds (anything with those is a venture).

const DECISION_INSTANT = ["manpower", "owned_grievance", "strip_building"]

# What a decision costs now: its fixed cost plus any amount for each district held
func decision_cost(faction_id: String, decision_id: String) -> Dictionary:
	var def = GameData.decision(decision_id)
	var cost: Dictionary = def["cost"].duplicate()
	for resource_type in def.get("cost_per_district", {}):
		cost[resource_type] = cost.get(resource_type, 0.0) + def["cost_per_district"][resource_type] * districts_held(faction_id)
	return cost

func decision_options(faction_id: String, decision_id: String) -> Array:
	var options = []
	for option in GameData.decision(decision_id)["requires"]:
		options.append(option.map(func(condition): return condition_status(faction_id, condition)))
	return options

# "" if the faction can take this decision now, otherwise why not (and what to do about it)
func check_decision(faction_id: String, decision_id: String) -> String:
	var f: Faction = factions[faction_id]
	var def = GameData.decision(decision_id)
	if def.get("once", false) and decision_id in f.decisions_done:
		return "Already done"
	var ready = int(f.decision_ready.get(decision_id, 0))
	if day < ready:
		return "Ready again in %d days" % (ready - day)
	var options = decision_options(faction_id, decision_id)
	if not options.any(func(option): return option.all(func(s): return s[0])):
		return "Needs " + " or ".join(options.map(func(option): return " and ".join(option.filter(func(s): return not s[0]).map(func(s): return s[1]))))
	var cost = decision_cost(faction_id, decision_id)
	if not f.can_afford(cost):
		return f.shortfall(cost)
	return ""

func take_decision(faction_id: String, decision_id: String) -> String:
	var err = check_decision(faction_id, decision_id)
	if err != "":
		return err
	var f: Faction = factions[faction_id]
	var def = GameData.decision(decision_id)
	f.pay(decision_cost(faction_id, decision_id))
	var instant: Dictionary = def.get("instant", {})
	if instant.has("manpower"):
		f.manpower += int(instant["manpower"])
	if instant.has("owned_grievance"):
		for d in districts:
			if d.owner_id() == faction_id:
				d.grievance = clampf(d.grievance + float(instant["owned_grievance"]), 0.0, 100.0)
	if instant.has("strip_building"):
		_strip_a_building(faction_id, float(instant["strip_building"]))
	if def.has("timed"):
		f.timed_effects.append({"label": def["label"], "choice": "Decision", "summary": def["result"], "until": day + int(def["timed"]["days"]),
			"effects": def["timed"].get("effects", {}).duplicate(), "venture_odds": {}, "skill_odds": {}})
	if def.get("once", false):
		f.decisions_done.append(decision_id)
	else:
		f.decision_ready[decision_id] = day + int(def["cooldown"])
	f.effect_cache.clear()
	if faction_id == player_id:
		event.emit("Decision: %s. %s" % [def["label"], def["result"]], "good")
	elif player_met.has(faction_id):
		event.emit("The %s took a decision: %s." % [f.display_name, def["label"].to_lower()], "info")
	return ""

# Takes the fittings out of one of the faction's buildings (the one that cost most) for a share of its materials
func _strip_a_building(faction_id: String, share: float):
	var best_district: District = null
	var best_index = -1
	var best_value = -1.0
	for d in districts:
		if d.owner_id() != faction_id:
			continue
		for i in d.buildings.size():
			var value: float = GameData.building(d.buildings[i])["cost"].get("materials", 0.0)
			if value > best_value:
				best_value = value
				best_district = d
				best_index = i
	if best_district == null:
		return
	factions[faction_id].materials += ceilf(best_value * share)
	best_district.buildings.remove_at(best_index)

# --- Government reforms (S4b, doc 12) --------------------------------------------------------

const REFORM_LOCK_DAYS = 720
const REFORM_GRIEVANCE = 10.0

# Governments a faction could reform into from where it stands: a gang can only become a Warlord crew;
# anyone past that can aim for any of the others
func reform_options(faction_id: String) -> Array:
	var current: String = factions[faction_id].government
	if current == "gang":
		return ["warlord"]
	return GameData.governments().keys().filter(func(id): return id != current and id not in ["gang", "warlord"])

func reform_requirements(faction_id: String, gov_id: String) -> Array:
	var options = []
	for option in GameData.government(gov_id)["reform"]["requires"]:
		options.append(option.map(func(condition): return condition_status(faction_id, condition)))
	return options

# What it costs this faction (a Democracy argues everything twice over)
func reform_cost(faction_id: String, gov_id: String) -> Dictionary:
	var cost: Dictionary = GameData.government(gov_id)["reform"]["cost"].duplicate()
	var mult = factions[faction_id].effect("reform_cost_mult")
	for resource_type in cost:
		cost[resource_type] = ceilf(cost[resource_type] * mult)
	return cost

# Where the council stands, by their natures: {"for": [characters], "against": [characters]}
func council_stance(faction_id: String, gov_id: String) -> Dictionary:
	var reform: Dictionary = GameData.government(gov_id)["reform"]
	var stance = {"for": [], "against": []}
	for c in characters_of(faction_id):
		if c.post == "":
			continue
		if reform.get("opposers", []).any(func(t): return c.has_trait(t)):
			stance["against"].append(c)
		elif reform.get("backers", []).any(func(t): return c.has_trait(t)):
			stance["for"].append(c)
	return stance

# "" if the faction can take this reform now, otherwise why not
func check_reform(faction_id: String, gov_id: String) -> String:
	var f: Faction = factions[faction_id]
	if gov_id not in reform_options(faction_id):
		return "Not a step you can take from %s" % GameData.government(f.government)["label"]
	if f.reform_locked_until > day:
		return "Too soon after the last reform: %d more days" % (f.reform_locked_until - day)
	var options = reform_requirements(faction_id, gov_id)
	if not options.any(func(option): return option.all(func(s): return s[0])):
		return "Needs " + " or ".join(options.map(func(option): return " and ".join(option.filter(func(s): return not s[0]).map(func(s): return s[1]))))
	var cost = reform_cost(faction_id, gov_id)
	if not f.can_afford(cost):
		return f.shortfall(cost)
	# Where the council votes, a majority against blocks it
	if GameData.government(f.government).get("votes", false):
		var stance = council_stance(faction_id, gov_id)
		if stance["against"].size() > stance["for"].size():
			return "The council votes it down (%d against, %d for)" % [stance["against"].size(), stance["for"].size()]
	return ""

func take_reform(faction_id: String, gov_id: String) -> String:
	var err = check_reform(faction_id, gov_id)
	if err != "":
		return err
	var f: Faction = factions[faction_id]
	var old_label: String = GameData.government(f.government)["label"]
	var gov = GameData.government(gov_id)
	var stance = council_stance(faction_id, gov_id)
	f.pay(reform_cost(faction_id, gov_id))
	f.government = gov_id
	f.reform_locked_until = day + REFORM_LOCK_DAYS
	f.effect_cache.clear()
	f.lean["home"] += 1.0
	if gov["heir_rule"] != "blood":
		f.designated_heir = -1
	# The transition: an unsettled city, and a council that remembers who got their way
	for d in districts:
		if d.owner_id() == faction_id:
			d.grievance = clampf(d.grievance + REFORM_GRIEVANCE, 0.0, 100.0)
			_sim_grievance(d, "reform", REFORM_GRIEVANCE)
	for c in stance["against"]:
		c.change_loyalty(-10.0, "reform_opposed")
	for c in stance["for"]:
		c.change_loyalty(5.0, "reform_backed")
	var text = "The %s are no longer a %s: they are now a %s. %s" % [f.display_name, old_label, gov["label"], gov["succession"]]
	if faction_id == player_id:
		major_event.emit(gov["reform"]["label"], "%s\n\nThe change unsettles your districts (grievance +%d)%s." % [text, REFORM_GRIEVANCE,
			(", and %s resent%s being overruled" % [", ".join(stance["against"].map(func(c): return c.name)), "s" if stance["against"].size() == 1 else ""]) if not stance["against"].is_empty() else ""], "")
		event.emit(text, "good")
	else:
		event.emit(text, "info")
	return ""

# Daily wealth paid to each council member: a bigger faction's council expects more
func council_wage(faction_id: String) -> float:
	return (GameData.rule("council_wage") + GameData.rule("council_wage_per_district") * districts_held(faction_id)) * factions[faction_id].effect("council_wage_mult")

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
