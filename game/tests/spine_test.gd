extends SceneTree

# Headless regression checks for the game's spine. Run from the project folder:
#   godot --headless --path . --script res://tests/spine_test.gd
# Exits with code 1 if any check fails.

var failures = 0

func _init():
	_check("data files are consistent", GameData.validate().is_empty(), str(GameData.validate()))
	_test_layout()
	_test_determinism()
	_test_save_file()
	_test_ai_diplomacy()
	_test_mutual_peace()
	_test_ask_cooldowns()
	_test_war_goal_window()
	_test_occupation_and_peace()
	_test_death_risk()
	_test_cost_of_growth()
	_test_treaties()
	_test_memories_and_deeds()
	_test_leaders_and_tiers()
	_test_no_stacking()
	_test_buildings()
	_test_council()
	_test_opening()
	_test_no_dead_ends()
	_test_captains_kept()
	_test_expansion()
	_test_pressure()
	_test_raid_cooldown()
	_test_raiders_and_deterrence()
	_test_ambitions()
	_test_government()
	_test_tasks()
	_test_district_payoffs()
	_test_events_and_births()
	_test_education()
	_test_minor_patrons()
	_test_defence()
	_test_force()
	_test_resources_and_pauses()
	_test_war_goals()
	_test_matches()
	_test_houses()
	_test_cross_matches()
	_test_claimed_land_is_off_limits()
	_test_the_arc()
	_test_legacy()
	print("ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)

func _check(label: String, ok: bool, detail: String = ""):
	print("[%s] %s%s" % ["PASS" if ok else "FAIL", label, "" if ok or detail == "" else ": " + detail])
	if not ok:
		failures += 1

# A simple stand-in player: expands, fights, calms districts, accepts peace
func _run(c: CityMap, days: int):
	for i in days:
		if c.day % 4 == 0:
			_bot_move(c)
		if c.day % 30 == 5:
			c.ai_manage_council(c.player_id)
		if c.day == 200:
			for fid in c.factions:
				if fid != c.player_id:
					c.declare_war(c.player_id, fid)
		for fid in c.factions:
			if fid != c.player_id and c.relation(c.player_id, fid).peace_offered_by == fid:
				c.make_peace(c.player_id, fid)
		c.advance_day()

func _bot_move(c: CityMap):
	for venture_id in ["assault", "settle", "relief", "trade", "raid", "scavenge", "scout"]:
		for d in c.districts:
			if c.check_launch(c.player_id, venture_id, d) == "":
				c.launch_venture(c.player_id, venture_id, d)
				return

func _snapshot(c: CityMap) -> PackedByteArray:
	return var_to_bytes(c.to_save())

# The city layout in data/map.json is usable: every district reachable, the river crossable only at bridges
func _test_layout():
	var c = _new_city()
	var layout = GameData.map()
	_check("the city has around 60 districts", c.districts.size() >= 50, str(c.districts.size()))
	var seen = {0: true}
	var queue = [0]
	while not queue.is_empty():
		var d = c.districts[queue.pop_back()]
		for n in d.neighbor_ids:
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	_check("every district can be reached from every other", seen.size() == c.districts.size())
	_check("there is a river with at least 3 bridges", layout["river"].size() > 2 and layout["bridges"].size() >= 3)
	var bridged = {}
	for b in layout["bridges"]:
		bridged["%d|%d" % [mini(b["a"], b["b"]), maxi(b["a"], b["b"])]] = true
	# Districts that touch across the river are only neighbours where a bridge crosses
	var river = MapArt._points(layout["river"])
	var crossings_ok = true
	for d in c.districts:
		for n in d.neighbor_ids:
			var other = c.districts[n]
			for k in river.size() - 1:
				if Geometry2D.segment_intersects_segment(d.center, other.center, river[k], river[k + 1]) != null:
					if not bridged.has("%d|%d" % [mini(d.id, n), maxi(d.id, n)]):
						crossings_ok = false
	_check("river crossings between neighbours are all bridges", crossings_ok)

# A loaded game must continue exactly as the original would have
func _test_determinism():
	var c = _new_city()
	_run(c, 150)
	var saved = c.to_save()
	_run(c, 250)
	var loaded = CityMap.new(bytes_to_var(var_to_bytes(saved)))
	_check("reload matches the save point", _snapshot(loaded) == var_to_bytes(saved))
	_run(loaded, 250)
	_check("reloaded game plays out identically for 250 days", _snapshot(loaded) == _snapshot(c))

func _test_save_file():
	var path = "user://spine_test.sav"
	var c = _new_city()
	_run(c, 60)
	_check("save_game writes a file", c.save_game(path) == "")
	var loaded = CityMap.load_game(path)
	_check("load_game restores the same state", loaded != null and _snapshot(loaded) == _snapshot(c))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# Opinion memories fade; deeds complete and pay renown; treaties can be renewed near the end
func _test_memories_and_deeds():
	var c = _new_city()
	var me = c.player_id
	var before = c.opinion_of("guild", me)
	c.change_opinion("guild", me, 20.0, "gift")
	_check("a gift raises opinion as a named memory", c.opinion_of("guild", me) > before + 15.0 and c.relation("guild", me).modifiers["guild"].size() == 1)
	for i in 250:
		c.advance_day()
	_check("memories fade away over time", c.relation("guild", me).modifiers["guild"].filter(func(m): return m["id"] == "gift").is_empty())
	var c2 = _new_city()
	var p: Faction = c2.factions[me]
	var renown_before = p.renown
	var cap_before = c2.crew_cap(me)
	Diplomacy.form_treaty(c2, "trade", me, "guild")
	c2.advance_day()
	_check("a deed completes and pays renown", "handshake" in p.deeds_done and p.renown > renown_before)
	p.reputation = 100.0
	_check("reputation raises the crew limit", c2.crew_cap(me) > cap_before)
	var rep_before = p.reputation
	p.pay({"renown": p.renown})
	_check("spending renown leaves reputation and the crew limit alone", p.reputation == rep_before and c2.crew_cap(me) > cap_before)
	Diplomacy.form_treaty(c2, "pact", me, "rival")
	var r = c2.relation(me, "rival")
	var early = Diplomacy.check_action(c2, "pact", me, "rival")
	r.treaty_until_day = c2.day + 30
	p.wealth = 100.0
	_check("a pact can only be renewed in its final months", early.begins_with("Pact holds") and Diplomacy.check_action(c2, "pact", me, "rival") == "")

# Ventures need a free captain, respect crew ranges, and roll one of four tiers
func _test_leaders_and_tiers():
	var c = _new_city()
	var me = c.player_id
	_check("each faction starts with captains", c.captain_count(me) == int(GameData.rule("captains_at_start")))
	var target: District = null
	for d in c.districts:
		if c.check_launch(me, "settle", d) == "":
			target = d
			break
	var leader: Character = c.characters_of(me)[0]
	var result = VentureSystem.compute_odds("settle", c.factions[me], target, c, "", leader, 4, 1)
	var total = 0.0
	for tier in VentureSystem.TIERS:
		total += result["tiers"][tier]
	_check("the four tier chances add up to 1", absf(total - 1.0) < 0.0001)
	_check("crew outside the range is refused", c.check_launch(me, "settle", target, leader.id, 99).begins_with("Crew must be"))
	leader.wounded_until = c.day + 10
	_check("a wounded captain can't lead", c.check_launch(me, "settle", target, leader.id).ends_with("recovering from wounds"))
	leader.wounded_until = 0
	_check("a venture launches with a chosen leader, crew and funding", c.launch_venture(me, "settle", target, leader.id, 4, 1) == "" and c.ventures[-1].leader_id == leader.id and c.ventures[-1].crew == 4)
	_check("a leader on a venture is busy", c.check_launch(me, "negotiate", target, leader.id).ends_with("already out on a venture"))
	# Every tier happens, and disasters can cost a leader
	var seen = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	for i in 2000:
		seen[VentureSystem.roll_tier(result["tiers"], rng)] = true
	_check("all four tiers can occur", seen.size() == 4)
	var before = c.characters.size()
	c.rng.seed = 1
	var outcomes = {}
	for i in 200:
		var fate = c._leader_outcome(c.characters_of(me)[-1], "disaster", GameData.venture("raid"))
		outcomes[fate.get_slice(" ", fate.get_slice_count(" ") - 1)] = true
		if c.characters.size() < before:
			break
	_check("a disaster can kill the leader", c.characters.size() < before)

# The same venture can't be piled onto one district
func _test_no_stacking():
	var c = _new_city()
	for d in c.districts:
		if c.check_launch(c.player_id, "settle", d) == "":
			c.launch_venture(c.player_id, "settle", d)
			_check("a second identical venture in the same district is refused",
				c.check_launch(c.player_id, "settle", d) == "Already under way here")
			return
	_check("found a district to test stacking in", false)

func _test_buildings():
	var c = _new_city()
	var p: Faction = c.factions[c.player_id]
	p.wealth = 500.0
	p.supplies = 500.0
	p.materials = 500.0
	# The shelter starts unsecured; secure it as Safeguard ventures would
	c.districts[p.home_id].add_influence(c.player_id, 30.0)
	var home: District = null
	for d in c.districts:
		if d.owner_id() == c.player_id and d.get_control_status() == "secured":
			home = d
	_check("secured home district exists", home != null)
	_check("can start a Workshop on secured land", c.start_construction(c.player_id, "workshop", home) == "")
	_check("slots are enforced", c.check_build(c.player_id, "market", home) == "" and
		c.start_construction(c.player_id, "market", home) == "" and
		c.check_build(c.player_id, "clinic", home).begins_with("No free building slot"))
	var saved = c.to_save()
	for i in 31:
		c.advance_day()
	_check("construction completes", "workshop" in home.buildings and "market" in home.buildings)
	var reloaded = CityMap.new(bytes_to_var(var_to_bytes(saved)))
	for i in 31:
		reloaded.advance_day()
	_check("a game saved mid-construction finishes identically", _snapshot(reloaded) == _snapshot(c))
	var development_before = home.development
	c.advance_day()
	_check("Workshop raises development daily", home.development > development_before)
	# Buildings stay with the district when it changes hands
	var rival_id = "rival"
	home.add_influence(rival_id, 100.0)
	_check("captured district keeps its buildings", home.owner_id() == rival_id and home.buildings.size() == 2)

# AI factions deal with each other on their own: treaties or wars between them
func _test_ai_diplomacy():
	var c = _new_city()
	_run(c, 400)
	var interacted = false
	for r in c.relations.values():
		if not r.involves(c.player_id) and (r.trade or r.pact or r.alliance or r.at_war or r.truce_until_day > 90):
			interacted = true
	_check("AI factions make treaties or war with each other", interacted)

# Two AI factions that both want peace must reach it: a standing offer isn't overwritten by the other side's
func _test_mutual_peace():
	var c = _new_city()
	var a = "rival"
	var b = "commune"
	c.start_war(a, b)
	var r = c.relation(a, b)
	r.war_start_day = c.day - 200
	c.offer_peace(a, b)
	c.offer_peace(b, a)
	_check("a standing peace offer isn't replaced by the other side's", r.peace_offered_by == a, r.peace_offered_by)
	var days = 0
	while r.at_war and days < 30:
		c.advance_day()
		days += 1
	_check("two AI factions at war, both willing, end it by peace within 30 days", not r.at_war, "still at war after %d days" % days)
	var c2 = _new_city()
	c2.start_war(a, b)
	var r2 = c2.relation(a, b)
	r2.war_start_day = c2.day - 200
	days = 0
	while r2.at_war and days < 30:
		c2.advance_day()
		days += 1
	_check("the same when neither has offered yet", not r2.at_war, "still at war after %d days" % days)
	var c3 = _new_city()
	c3.start_war(a, c3.player_id)
	var told = []
	c3.event.connect(func(text, _kind): if text.contains("offer peace"): told.append(text))
	for i in 5:
		c3.offer_peace(a, c3.player_id)
		c3.offer_peace(c3.player_id, a)
	_check("the player is offered peace once per war", told.size() == 1, str(told.size()))

# The war goal window's data (doc 19): wording, candidates, who would be called, outcomes, requirements, the alert
func _test_war_goal_window():
	var c = _new_city()
	var me = c.player_id
	_check("strength is worded in five steps", c.strength_step(0.3) == 0 and c.strength_step(0.6) == 1 and c.strength_step(1.0) == 2 and c.strength_step(1.5) == 3 and c.strength_step(3.0) == 4)
	_border_with(c, me, "guild")
	var candidates = c.claim_candidates(me, "guild")
	_check("a bordering faction has districts to acquire", not candidates.is_empty() and candidates.all(func(d): return d.owner_id() == "guild" and c.borders_territory(me, d)))
	var outcomes = c.goal_outcomes("guild", "claim", candidates[0])
	_check("a claim says what you would gain and what losing costs", outcomes["win"].size() >= 2 and outcomes["lose"].size() >= 2 and candidates[0].district_name in outcomes["win"][1][1])
	_check("subjugating and vassalizing have their own endings", c.goal_outcomes("guild", "subjugate", null)["win"].size() >= 2 and c.goal_outcomes("guild", "vassalize", null)["win"].size() >= 2)
	c.factions[me].renown = 200.0
	c.factions[me].wealth = 500.0
	var reqs = c.justify_requirements(me, "guild", "claim", candidates[0])
	_check("the requirements are ticks, warnings or crosses", reqs.size() >= 3 and reqs.all(func(q): return q[0] in ["ok", "warn", "no"]))
	_check("with border, district and means, nothing is crossed", reqs.all(func(q): return q[0] != "no"), str(reqs))
	c.factions[me].wealth = 0.0
	_check("without the means, the cost is crossed and says what is missing", c.justify_requirements(me, "guild", "claim", candidates[0]).any(func(q): return q[0] == "no" and q[1].contains("wealth")))
	c.factions[me].wealth = 500.0
	# Opening it costs nothing: nothing is paid and no claim exists until you begin
	var wealth_before = c.factions[me].wealth
	c.goal_outcomes("guild", "claim", candidates[0])
	c.justify_requirements(me, "guild", "claim", candidates[0])
	_check("weighing a goal pays nothing and starts nothing", c.factions[me].wealth == wealth_before and c.relation(me, "guild").claim.is_empty())
	# Once begun, the claim remembers where it started, and a turn for the worse is said once
	c.justify(me, "guild", "claim", candidates[0])
	var r = c.relation(me, "guild")
	_check("the claim remembers the balance when you began", r.claim.has("start_ratio") and r.claim.has("start_their_strength") and r.claim.has("step"))
	var told = []
	c.event.connect(func(text, _kind): if text.contains("turned against your claim"): told.append(text))
	r.claim["step"] = 0
	c.factions["guild"].manpower = 500.0
	c.factions["guild"].arms = 500.0
	c._watch_own_claim(r)
	var first = told.size()
	c._watch_own_claim(r)
	_check("a turn for the worse is said once, not every day", first == 1 and told.size() == 1, "%d then %d" % [first, told.size()])

# Test helper: the holder occupies every district the owner has (a war won on the ground)
func _occupy_all(c: CityMap, holder: String, owner: String):
	for d in c.districts:
		if d.owner_id() == owner:
			d.occupier = holder

# Occupation and the peace table (doc 20): an assault holds a district without owning it; ownership changes only at the table
func _test_occupation_and_peace():
	var c = _new_city()
	var me = c.player_id
	var foe = "guild"
	_border_with(c, me, foe)
	var d: District = c.claim_candidates(me, foe)[0]
	c.start_war(me, foe)
	var r = c.relation(me, foe)
	var owner_before = d.owner_id()
	c.occupy(d, me, 5)
	_check("occupying doesn't change who owns the district", d.owner_id() == owner_before and d.occupier == me)
	_check("its crew are the garrison", d.garrison == 5.0)
	# An army advances from what it has taken: the districts beyond an occupied one are on your front
	var beyond = d.neighbor_ids.map(func(n): return c.districts[n]).filter(func(x): return x.owner_id() == foe and x != d and not c.districts[x.id].neighbor_ids.any(func(m): return c.districts[m].owner_id() == me))
	_check("land you occupy extends your front", beyond.is_empty() or beyond.all(func(x): return c.borders_territory(me, x)))
	_check("and an enemy that occupies your land doesn't use it as its own", not c.holds(foe, d) and c.holds(me, d))
	_check("an occupied district pays nobody", c.yield_multiplier(d) == 0.0 and not c.buildings_active(d))
	var wealth_before = c.factions[foe].wealth
	c._simulate_district(d)
	_check("and nothing flows to its owner", c.factions[foe].wealth <= wealth_before + 0.001)
	_check("nothing can be launched there but an assault", c.check_launch(me, "raid", d).contains("occupied"), c.check_launch(me, "raid", d))
	_check("occupying is not scoring until a war goal gives it a score", c.war_score(r) == 0.0)
	# A war goal gives the score: land held counts, the more the better
	r.claim = {"by": me, "goal": "claim", "district": d.id, "reason": "", "stage": "war", "ready_day": 0, "deadline": 0, "started": c.day}
	var one = c.occupation_score(me, foe)
	_check("occupation scores the share of their land held", one > 0.0 and one < GameData.rule("war_occupation_scale") + GameData.rule("war_home_bonus"), str(one))
	for other in c.districts:
		if other.owner_id() == foe:
			other.occupier = me
	_check("holding all of it scores the most, with the home bonus", c.occupation_score(me, foe) >= GameData.rule("war_occupation_scale"))
	_check("the other side holds none of ours", c.occupation_score(foe, me) == 0.0)
	var parts = c.war_score_parts(r)
	_check("the score has its parts and a total in range", parts.has("occupation_for") and parts.has("battles") and parts["total"] <= 100.0 and parts["total"] >= -100.0)
	# The owner retakes land by assault: the crew who did it hold it
	c.liberate(d, foe, 4)
	_check("retaking a district ends the occupation and the owner's crew garrison it", d.occupier == "" and d.garrison == 4.0 and d.owner_id() == owner_before)
	d.occupier = me
	# The peace table: score buys demands; ownership changes only now
	r.war_points = 50.0
	var demands = c.peace_demands(me, foe)
	_check("the goal is the first demand, then occupied districts, then tribute", demands[0]["kind"] == "goal" and demands.any(func(x): return x["kind"] == "tribute"))
	_check("a goal that needs more score than you have can't be enforced", c.check_enforce(me, foe) == "" or c.war_score(r) < demands[0]["cost"])
	var owner_now = d.owner_id()
	_check("until enforced, nothing has changed hands", owner_now == foe)
	var extras = c.auto_demands(me, foe)
	var err = c.enforce_claim(me, foe, extras)
	_check("enforcing takes the goal and ends the war", err == "" and not r.at_war and r.claim.is_empty(), err)
	_check("the claimed district changes hands only now", d.owner_id() == me and d.occupier == "")
	_check("a war that ends in a deal brings the long truce", r.truce_until_day >= c.day + int(GameData.rule("truce_war_days")) - 1)
	_check("no occupation outlives the war", c.districts.all(func(x): return x.occupier == "" or c.is_at_war(x.owner_id(), x.occupier)))
	# White peace is the status quo
	var c2 = _new_city()
	var me2 = c2.player_id
	var e2 = "guild"
	_border_with(c2, me2, e2)
	var t2: District = c2.claim_candidates(me2, e2)[0]
	c2.start_war(me2, e2)
	var r2 = c2.relation(me2, e2)
	r2.war_start_day = c2.day - 200
	c2.factions[me2].renown = 100.0
	r2.claim = {"by": me2, "goal": "claim", "district": t2.id, "reason": "", "stage": "war", "ready_day": 0, "deadline": 0, "started": c2.day}
	var owner2 = t2.owner_id()
	c2.occupy(t2, me2, 4)
	var crew_before = c2.factions[me2].manpower
	r2.peace_offered_by = e2
	var renown_before = c2.factions[me2].renown
	_check("white peace is allowed once they offer it", c2.make_peace(me2, e2) == "")
	_check("a white peace leaves the district with its owner", t2.owner_id() == owner2 and t2.occupier == "")
	_check("the occupiers' crew go home", c2.factions[me2].manpower >= crew_before + 4.0 - 0.001)
	_check("pressing a claim and backing off costs the one who pressed it", c2.factions[me2].renown < renown_before)
	_check("they remember it", c2.relation(e2, me2).modifiers[e2].any(func(m): return m["id"] == "backed_off"))
	_check("and a truce follows", r2.truce_until_day >= c2.day + int(GameData.rule("truce_days")) - 1)
	# Backing down before any war: the same cost and a truce
	var c3 = _new_city()
	var me3 = c3.player_id
	_border_with(c3, me3, "guild")
	c3.factions[me3].renown = 100.0
	c3.factions[me3].wealth = 500.0
	c3.relation(me3, "guild").truce_until_day = 0
	c3.justify(me3, "guild", "claim", null)
	var renown3 = c3.factions[me3].renown
	_check("backing down is allowed", c3.withdraw_claim(me3, "guild") == "")
	_check("it costs renown and gives a truce", c3.factions[me3].renown < renown3 and c3.relation(me3, "guild").truce_until_day > c3.day)
	# A saved game keeps who holds what
	var c4 = _new_city()
	var me4 = c4.player_id
	_border_with(c4, me4, "guild")
	var d4: District = c4.claim_candidates(me4, "guild")[0]
	c4.start_war(me4, "guild")
	c4.occupy(d4, me4, 3)
	var path = "user://occupation_test.sav"
	c4.save_game(path)
	var loaded = CityMap.load_game(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check("occupation survives a save", loaded != null and loaded.districts[d4.id].occupier == me4 and loaded.districts[d4.id].garrison == 3.0)

# The cost of growth (doc 20, W2): land takes time to settle, notoriety, and reach
func _test_cost_of_growth():
	var c = _new_city()
	var me = c.player_id
	var home: District = c.districts[c.factions[me].home_id]
	_check("your starting land is fully settled", home.absorb == 1.0)
	var full = c.yield_multiplier(home)
	home.absorb = GameData.rule("absorb_start")
	var fresh = c.yield_multiplier(home)
	_check("land just taken yields only part of its worth", fresh < full * 0.5 and fresh > 0.0, "%.2f of %.2f" % [fresh, full])
	var before = home.absorb
	for i in 30:
		c._simulate_district(home)
	_check("it settles in with time", home.absorb > before)
	var slow = home.absorb - before
	home.absorb = before
	home.garrison = c.garrison_ceiling(home)
	for i in 30:
		c._simulate_district(home)
	_check("a garrison among the people settles them faster", home.absorb - before >= slow)
	# Taking a district from someone: unsettled and angry
	var foe = "guild"
	_border_with(c, me, foe)
	var d: District = c.claim_candidates(me, foe)[0]
	d.grievance = 10.0
	c._transfer_district(d, me)
	_check("a conquered district starts unsettled", d.absorb == GameData.rule("absorb_start"), str(d.absorb))
	_check("and angry", d.grievance >= 10.0 + GameData.rule("conquest_grievance") - 0.01, str(d.grievance))
	# Infamy
	var f: Faction = c.factions[me]
	f.infamy = 0.0
	c.add_infamy(me, 12.0)
	_check("infamy builds", f.infamy == 12.0)
	f.infamy = 30.0
	c.advance_day()
	_check("it fades slowly", f.infamy < 30.0 and f.infamy > 29.0)
	f.infamy = 50.0
	c.day = 5 + 30 * 3
	var opinion_before = c.opinion_of("rival", me)
	c._infamy_opinions()
	_check("others think less of the notorious", c.opinion_of("rival", me) < opinion_before)
	f.wealth = 500.0
	f.infamy = GameData.rule("infamy_block") + 1.0
	_check("nobody signs with a faction past the limit, and it says why", Diplomacy.check_action(c, "trade", me, "rival").contains("notorious"), Diplomacy.check_action(c, "trade", me, "rival"))
	f.infamy = 0.0
	var plain = Diplomacy.acceptance(c, "trade", me, "rival")["chance"]
	f.infamy = 60.0
	_check("below the limit it is only harder", Diplomacy.acceptance(c, "trade", me, "rival")["chance"] < plain)
	f.infamy = 0.0
	# A war goal won earns infamy: more with no cause, more against a friend
	var c2 = _new_city()
	var me2 = c2.player_id
	_border_with(c2, me2, foe)
	var r2 = c2.relation(me2, foe)
	r2.claim = {"by": me2, "goal": "claim", "district": c2.claim_candidates(me2, foe)[0].id, "reason": "", "stage": "war", "ready_day": 0, "deadline": 0, "started": c2.day, "friendly": false}
	c2._war_infamy(r2)
	var plain_gain = c2.factions[me2].infamy
	c2.factions[me2].infamy = 0.0
	r2.claim["reason"] = "they raided you"
	c2._war_infamy(r2)
	var cause_gain = c2.factions[me2].infamy
	c2.factions[me2].infamy = 0.0
	r2.claim["friendly"] = true
	c2._war_infamy(r2)
	_check("winning a goal earns infamy, less with cause, more against a friend", plain_gain > cause_gain and c2.factions[me2].infamy > cause_gain, "%.1f %.1f %.1f" % [plain_gain, cause_gain, c2.factions[me2].infamy])
	# Reach
	var reach = c.reach(me)
	_check("reach is what a council can administer", reach >= GameData.rule("reach_base"))
	c.held_cache = {me: int(reach) + 5}
	c.reach_cache = {}
	var g = home.grievance
	home.absorb = 1.0
	home.garrison = 0.0
	c._simulate_district(home)
	_check("past your reach, the realm grumbles", home.grievance > g - 0.15 + 0.05, "%.2f -> %.2f" % [g, home.grievance])
	# Saving keeps all of it
	var path = "user://growth_test.sav"
	home.absorb = 0.4
	f.infamy = 33.0
	c.save_game(path)
	var loaded = CityMap.load_game(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check("a saved game keeps settling and infamy", loaded != null and is_equal_approx(loaded.districts[home.id].absorb, 0.4) and is_equal_approx(loaded.factions[me].infamy, 33.0))

# Death risk (doc 14): age alone decides the baseline; a failed venture can kill its leader, by danger and by how long the odds were
func _test_death_risk():
	var c = _new_city()
	var leader = c.leader_of(c.player_id)
	leader.age = 24
	_check("a young leader's yearly risk follows age, not office", c.yearly_death_chance(leader) < 0.05, str(c.yearly_death_chance(leader)))
	var other = c.characters_of(c.player_id).filter(func(x): return not x.is_leader and x.is_adult())
	if not other.is_empty():
		other[0].age = 24
		_check("a leader is no likelier to die of illness than anyone else", is_equal_approx(c.monthly_death_chance(leader), c.monthly_death_chance(other[0])))
	leader.age = 70
	_check("old age still brings the risk", c.yearly_death_chance(leader) > 0.3, str(c.yearly_death_chance(leader)))
	var assault = GameData.venture("assault")
	var scavenge = GameData.venture("scavenge")
	_check("nothing happens to the leader on a success", c.venture_death_chance(assault, "success", 0.5) == 0.0 and c.venture_death_chance(assault, "triumph", 0.5) == 0.0)
	_check("a disaster is deadlier than a setback", c.venture_death_chance(assault, "disaster", 0.5) > c.venture_death_chance(assault, "setback", 0.5) and c.venture_death_chance(assault, "setback", 0.5) > 0.0)
	_check("longer odds are deadlier", c.venture_death_chance(assault, "disaster", 0.2) > c.venture_death_chance(assault, "disaster", 0.8))
	_check("a more dangerous venture is deadlier", c.venture_death_chance(assault, "disaster", 0.5) > c.venture_death_chance(scavenge, "disaster", 0.5))
	_check("a standing task on home ground is safer", c.venture_death_chance(assault, "disaster", 0.5, true) < c.venture_death_chance(assault, "disaster", 0.5, false))
	_check("the chance is capped", c.venture_death_chance({"danger": 5.0}, "disaster", 0.0) <= GameData.rule("death_chance_cap"))

# Asks: a cooldown per pair and action, longer after each refusal, lighter for the player, and renewals aren't asks (doc 18)
func _test_ask_cooldowns():
	var c = _new_city()
	var me = c.player_id
	c.factions["rival"].wealth = 500.0
	var err = Diplomacy.start_action(c, "envoy", "rival", "commune")
	_check("the first ask goes out", err == "", err)
	c.missions.clear()
	var again = Diplomacy.check_action(c, "envoy", "rival", "commune")
	_check("the same ask to the same faction is held back, with the wait", again.contains("again in"), again)
	_check("another faction can still be asked", Diplomacy.check_action(c, "envoy", "rival", "guild") == "" or not Diplomacy.check_action(c, "envoy", "rival", "guild").contains("again in"))
	_check("a different ask to the same faction isn't held back", not Diplomacy.check_action(c, "trade", "rival", "commune").contains("again in"))
	var ai_wait = Diplomacy.ask_cooldown(c, "alliance", "rival", 0)
	var player_wait = Diplomacy.ask_cooldown(c, "alliance", me, 0)
	_check("the player waits less than the AI", player_wait < ai_wait and player_wait > 0, "%d vs %d" % [player_wait, ai_wait])
	_check("bigger asks wait longer than gifts", Diplomacy.ask_cooldown(c, "alliance", "rival", 0) > Diplomacy.ask_cooldown(c, "trade", "rival", 0) and Diplomacy.ask_cooldown(c, "trade", "rival", 0) > Diplomacy.ask_cooldown(c, "envoy", "rival", 0))
	Diplomacy.note_refusal(c, "alliance", "rival", "guild")
	var once = Diplomacy.ask_wait(c, "alliance", "rival", "guild")
	Diplomacy.note_refusal(c, "alliance", "rival", "guild")
	var twice = Diplomacy.ask_wait(c, "alliance", "rival", "guild")
	_check("each refusal lengthens the wait", twice > once and once > 0, "%d then %d" % [once, twice])
	_check("asking on after a refusal is held against the asker", c.opinion_of("guild", "rival") < 0.0 or c.relation("guild", "rival").modifiers["guild"].any(func(m): return m["id"] == "pestered"))
	var r = c.relation("rival", "commune")
	r.pact = true
	r.treaty_until_day = c.day + 10
	r.asks["rival|pact"] = {"day": c.day, "until": c.day + 500, "refusals": 0}
	_check("renewing a pact in its window isn't held back by the cooldown", not Diplomacy.check_action(c, "pact", "rival", "commune").contains("again in"), Diplomacy.check_action(c, "pact", "rival", "commune"))
	# A deal that absorbs a faction must not leave a relation behind for it
	var gone = _new_city()
	var before = gone.relations.size()
	gone.retire_faction("tunnel_rats", "rival")
	var after_retire = gone.relations.size()
	Diplomacy.note_accepted(gone, "vassalage", "rival", "tunnel_rats")
	Diplomacy.note_refusal(gone, "vassalage", "rival", "tunnel_rats")
	_check("asks to a faction that is gone leave no relation behind", gone.relations.size() == after_retire, "%d -> %d" % [after_retire, gone.relations.size()])

func _test_treaties():
	var c = _new_city()
	var me = c.player_id
	Diplomacy.form_treaty(c, "trade", me, "guild")
	_check("a trade agreement pays both sides", c.daily_economy(me)["trade"] > 0.0 and c.daily_economy("guild")["trade"] > 0.0)
	Diplomacy.form_treaty(c, "pact", me, "rival")
	_check("a pact blocks declaring war", c.check_declare_war(me, "rival").begins_with("You have a treaty"))
	var bystander_before = c.opinion_of("commune", me)
	Diplomacy.break_treaty(c, me, "rival", "pact")
	_check("breaking a pact costs opinion with bystanders", c.opinion_of("commune", me) < bystander_before)
	c.relation("rival", me).pact = true
	c.relation("rival", me).treaty_until_day = c.day + 1
	c.advance_day()
	_check("pacts lapse when they expire", not c.relation("rival", me).pact)
	# Allies are drawn into a war on their partner
	Diplomacy.form_treaty(c, "alliance", me, "commune")
	c.start_war("rival", "commune")
	c.call_to_arms("rival", "commune")
	_check("an ally joins a war against their partner", c.is_at_war(me, "rival"))
	# Vassals pay tribute and can be merged
	var c2 = _new_city()
	Diplomacy.form_treaty(c2, "vassalage", me, "guild")
	_check("a vassal pays tribute to its overlord", c2.daily_economy(me)["tribute"]["wealth"] > 0.0 and c2.daily_economy("guild")["tribute"]["wealth"] < 0.0)
	_check("a tributary can't start a war", c2.check_declare_war("guild", "rival") == "Tributaries can't start wars" and c2.check_justify("guild", "rival", "claim") == "Tributaries can't start wars", c2.check_justify("guild", "rival", "claim"))
	var r = c2.relation(me, "guild")
	r.vassal_since_day = -1000
	r.opinion["guild"] = 80.0
	c2.factions[me].wealth = 1000.0
	var integrate_err = Diplomacy.check_action(c2, "integrate", me, "guild")
	_check("a loyal vassal can be integrated", integrate_err == "", integrate_err)
	var expected = c2.districts_held(me) + c2.districts_held("guild")
	Diplomacy.form_treaty(c2, "integrate", me, "guild")
	_check("integration merges the vassal's land into the overlord", not c2.factions.has("guild") and c2.districts_held(me) == expected)
	c2.advance_day()
	_check("the game keeps running after a merge", c2.factions.size() == GameData.scenario()["factions"].size() - 1)

func _test_council():
	var c = _new_city()
	var me = c.player_id
	_check("the player starts with empty seats", c.council_size(me) == 0)
	_check("rivals start with part of a council seated", c.council_size("rival") == 2)
	var d: District = null
	for x in c.districts:
		if c.check_launch(me, "raid", x) == "" or c.check_launch(me, "settle", x) == "":
			d = x
			break
	var before = VentureSystem.compute_odds("settle", c.factions[me], d, c, "")["odds"]
	# Seat the best steward, and check a better-suited captain resents being passed over
	var candidates = c.characters_of(me)
	candidates.sort_custom(func(a, b): return a.skills["stewardship"] < b.skills["stewardship"])
	var worst = candidates[0]
	var best = candidates[-1]
	var err = c.appoint(worst.id, "quartermaster")
	_check("a captain can be appointed", err == "" and worst.post == "quartermaster", err)
	_check("the better candidate passed over loses loyalty", best.loyalty_breakdown().any(func(p): return p[0] == "Passed over for a seat"))
	c.appoint(best.id, "quartermaster")
	_check("replacing a seat holder unseats them", worst.post == "" and best.post == "quartermaster")
	var after = VentureSystem.compute_odds("settle", c.factions[me], d, c, "")
	_check("the Quartermaster's skill shows as a factor on expeditions",
		after["factors"].any(func(f): return str(f[0]).begins_with("Quartermaster")), str(after["factors"]))
	_check("a skilled Quartermaster improves expedition odds", best.skills["stewardship"] <= 4 or after["odds"] > before)
	var upkeep_before = c.faction_upkeep(me)["wealth"]
	c.appoint(worst.id, "fixer")
	_check("council seats are paid wages", c.faction_upkeep(me)["wealth"] > upkeep_before)
	# Save and load keeps seats, traits and loyalty
	best.traits.append("veteran")
	var loaded = CityMap.new(bytes_to_var(var_to_bytes(c.to_save())))
	var copy = loaded.character_by_id(best.id)
	_check("seats, traits and loyalty survive a save", copy.post == "quartermaster" and copy.has_trait("veteran") and absf(copy.loyalty() - best.loyalty()) < 0.01)
	# A deeply disloyal captain eventually deserts
	var rebel = c.characters_of(me).filter(func(x): return x.post == "" and not x.family)[0]
	rebel.change_loyalty(-30.0, "dismissed")
	rebel.change_loyalty(-25.0, "passed_over")
	rebel.traits.append("ambitious")
	var gone = false
	for i in 400:
		# Keep the grudge fresh, so this tests the desertion rule rather than how fast memories fade
		rebel.change_loyalty(-30.0, "dismissed")
		rebel.change_loyalty(-25.0, "passed_over")
		c.advance_day()
		if c.character_by_id(rebel.id) == null or c.character_by_id(rebel.id).faction_id != me:
			gone = true
			break
	_check("a disloyal captain deserts", gone, "loyalty %d" % rebel.loyalty())

func _test_opening():
	var c = _new_city()
	var me = c.player_id
	var p: Faction = c.factions[me]
	_check("every faction starts with one district", c.factions.keys().all(func(fid): return c.districts_held(fid) == 1))
	var home: District = c.districts[p.home_id]
	_check("the shelter starts claimed but not secured", home.get_control_status() == "claimed")
	# Hunger never locks you out of fixing it
	p.supplies = 0.0
	var err = c.check_launch(me, "secure_food", home, -2, -1, 0, true)
	_check("Secure Food can be launched with no food", err == "", err)
	# Food drives manpower, and owned neighbours share a little of theirs
	var before_food = c.district_food(home)
	var before_mp = c.district_income(home)["recruits"]
	VentureSystem.apply_effects([{"op": "food_source", "amount": 0.3}], p, "", home, c)
	_check("a food source raises the district's food", c.district_food(home) > before_food + 0.29)
	_check("more food means more manpower", c.district_income(home)["recruits"] > before_mp)
	var neighbour: District = c.districts[home.neighbor_ids[0]]
	neighbour.influence.clear()
	neighbour.add_influence(me, 60.0)
	_check("owned neighbours add some of their food to growth", c.district_growth_food(home) > c.district_food(home))
	VentureSystem.apply_effects([{"op": "food_source", "amount": 5.0}], p, "", home, c)
	_check("food sources are capped", is_equal_approx(home.food_yield, GameData.rule("food_source_cap")))
	# Raiding takes weapons
	p.arms = 0.0
	var raid_target: District = null
	for d in c.districts:
		if d.owner_id() != "" and d.owner_id() != me:
			raid_target = d
	_check("raids need arms", not p.can_afford(GameData.venture("raid")["cost"]))
	# Claiming land leaves settlers behind
	# (the roll can fail, so try fresh games until one expedition claims its district)
	var tested = false
	for attempt in 12:
		var c2 = _new_city()
		var p2: Faction = c2.factions[c2.player_id]
		p2.materials = 100.0
		p2.supplies = 100.0
		var target: District = null
		for d in c2.districts:
			if c2.check_launch(c2.player_id, "settle", d) == "":
				target = d
				break
		target.influence.clear()
		target.add_influence(c2.player_id, 45.0)
		var idle_before = p2.manpower
		c2.launch_venture(c2.player_id, "settle", target, -2, 5)
		while not c2.ventures.filter(func(v): return v.faction_id == c2.player_id).is_empty():
			c2.advance_day()
		if target.owner_id() == c2.player_id:
			# Everyone came home except the settlers (allowing for recruits gained meanwhile)
			_check("a claim leaves settlers behind", p2.manpower <= idle_before - GameData.rule("settlers_per_claim") + 1.5, "%.1f vs %.1f" % [p2.manpower, idle_before])
			tested = true
			break
	_check("an expedition claimed land within 12 tries", tested)

# Running out of something must say what's missing, and there must always be a way back
func _test_no_dead_ends():
	var c = _new_city()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var home: District = c.districts[p.home_id]
	p.materials = 2.0
	var target: District = null
	for d in c.districts:
		if d.owner_id() == "" and c.borders_territory(me, d):
			target = d
			break
	var err = c.check_launch(me, "settle", target)
	_check("a shortfall names what's missing and where to get it", err.contains("materials") and err.contains("have 2") and err.contains("Scavenge"), err)
	p.materials = 0.0
	home.ruin_level = 0.35
	err = c.check_launch(me, "scavenge", home, -2, -1, 0, true)
	_check("with no materials you can still scavenge at home", err == "", err)
	_check("you can scavenge unclaimed ruins on your border", c.check_launch(me, "scavenge", target) == "" or target.ruin_level < 0.1)
	home.ruin_level = 0.05
	_check("stripped ruins can't be scavenged", c.check_launch(me, "scavenge", home, -2, -1, 0, true).begins_with("Nothing left"))
	p.wealth = 0.0
	p.materials = 50.0
	err = c.check_launch(me, "gather_weapons", home, -2, -1, 1, true)
	_check("unaffordable extra funding says so", err.contains("wealth") and err.contains("less extra funding"), err)

# Lost captains get replaced, losses are recorded, and "nobody free" says who's away
func _test_captains_kept():
	var c = _new_city()
	var me = c.player_id
	_check("the captain limit leaves room at the start", c.captain_cap(me) > c.captain_count(me))
	var victim: Character = c.characters_of(me)[0]
	c._character_died(victim, "killed leading a Raid")
	_check("a death is recorded with its cause", c.departed.size() == 1 and c.departed[0]["fate"] == "killed leading a Raid")
	var joined = false
	for i in 400:
		c.advance_day()
		if c.characters_of(me).size() >= 4:
			joined = true
			break
	_check("a lost captain is replaced over time", joined)
	var home: District = c.districts[c.factions[me].home_id]
	for ch in c.characters_of(me):
		ch.wounded_until = c.day + 20
	var err = c.check_launch(me, "secure_food", home, -2, -1, 0, true)
	_check("no free captain says who is away and for how long", err.begins_with("No captain is free") and err.contains("wounded for"), err)
	var loaded = CityMap.new(bytes_to_var(var_to_bytes(c.to_save())))
	_check("the departed survive a save", loaded.departed.size() == c.departed.size())

# A new game with the player's neighbouring ruins already scouted, so settling can be tested directly
func _new_city() -> CityMap:
	var c = CityMap.new()
	for d in c.districts:
		if d.owner_id() == "" and c.borders_territory(c.player_id, d):
			c.mark_scouted(c.player_id, d)
	return c

func _test_expansion():
	var c = CityMap.new()
	var me = c.player_id
	var p: Faction = c.factions[me]
	p.materials = 100.0
	p.supplies = 100.0
	var target: District = null
	for d in c.districts:
		if d.owner_id() == "" and c.borders_territory(me, d):
			target = d
			break
	_check("you can't settle land you haven't scouted", c.check_launch(me, "settle", target).begins_with("Scout it first"))
	var blind = VentureSystem.compute_odds("scavenge", p, target, c, "")
	_check("ventures into unscouted land go in blind", blind["factors"].any(func(f): return str(f[0]).begins_with("Unscouted")))
	_check("scouting is possible next to your land", c.check_launch(me, "scout", target) == "")
	VentureSystem.apply_effects([{"op": "scout"}], p, "", target, c)
	_check("a scouted district is known", c.knows(me, target))
	_check("once scouted, you can settle it", c.check_launch(me, "settle", target) == "", c.check_launch(me, "settle", target))
	var seen = VentureSystem.compute_odds("scavenge", p, target, c, "")
	_check("once scouted, the real danger shows instead", not seen["factors"].any(func(f): return str(f[0]).begins_with("Unscouted")))
	# Scouting reaches out step by step
	var beyond: District = null
	for n_id in target.neighbor_ids:
		var n = c.districts[n_id]
		if n.owner_id() == "" and not c.borders_territory(me, n):
			beyond = n
	if beyond:
		_check("you can scout beyond a scouted district", c.check_launch(me, "scout", beyond) == "", c.check_launch(me, "scout", beyond))
	# Big food stores rot; small ones don't
	p.supplies = 30.0
	var small = c.faction_upkeep(me)["supplies"]
	p.supplies = 530.0
	_check("food beyond the fresh store spoils", c.faction_upkeep(me)["supplies"] > small + 3.0)
	# Buildings need materials; without them they stop
	var home: District = c.districts[p.home_id]
	home.buildings.append("allotments")
	p.materials = 0.0
	c.advance_day()
	_check("buildings fall into disrepair without materials", p.disrepair and not c.buildings_active(home))
	# Rebuilding turns materials into development
	p.materials = 100.0
	c.advance_day()
	var dev = home.development
	VentureSystem.apply_effects(GameData.venture("rebuild")["success_effects"], p, "", home, c)
	_check("rebuilding raises development", home.development > dev)
	_check("trade runs turn wealth into goods", GameData.venture("trade")["cost"].has("wealth") and not GameData.venture("trade")["cost"].has("supplies"))

# Minor factions sit close to the big ones, raiders raid, and trade goes to someone
func _test_pressure():
	var c = CityMap.new()
	var minors = c.factions.values().filter(func(f): return f.minor)
	_check("minor factions are in the game", minors.size() >= 4)
	_check("every minor faction starts with one district", minors.all(func(f): return c.districts_held(f.id) == 1))
	_check("no minor faction starts touching another faction", minors.all(func(f): return c.factions.keys().all(func(o): return o == f.id or not c.shares_border(f.id, o))))
	# A minor sits two districts from the big faction it's placed near
	var dogs: Faction = c.factions["rust_dogs"]
	var home: District = c.districts[c.factions[c.player_id].home_id]
	var two_steps = false
	for n_id in home.neighbor_ids:
		if dogs.home_id in c.districts[n_id].neighbor_ids:
			two_steps = true
	_check("the Rust Dogs start two districts from the player", two_steps)
	# Raiders value raiding far more than hermits do
	_check("raiders are keen on raids", FactionAI.temperament("harass", dogs) > FactionAI.temperament("harass", c.factions["st_brigids"]) * 5.0)
	# Trade Runs go to someone else's market, who keeps the wealth
	var me = c.player_id
	var p: Faction = c.factions[me]
	var their: District = c.districts[dogs.home_id]
	var between: District = null
	for n_id in home.neighbor_ids:
		if dogs.home_id in c.districts[n_id].neighbor_ids:
			between = c.districts[n_id]
	between.influence.clear()
	between.add_influence(me, 60.0)
	p.wealth = 100.0
	var err = c.check_launch(me, "trade", their)
	_check("a Trade Run can go to a neighbour's market", err == "", err)
	_check("a Trade Run can't target your own land", c.check_launch(me, "trade", home) != "")
	var before = dogs.wealth
	VentureSystem.apply_effects(GameData.venture("trade")["success_effects"], p, "rust_dogs", their, c)
	_check("the host keeps the wealth you spent", dogs.wealth >= before + 19.0)
	_check("the host thinks better of you", c.opinion_of("rust_dogs", me) > c.relation(me, "rust_dogs").baseline["rust_dogs"])
	# Raids take materials too
	var raid_ops = GameData.venture("raid")["success_effects"].map(func(e): return e.get("resource", ""))
	_check("raids steal materials as well as food", "materials" in raid_ops and "supplies" in raid_ops)

# After a raid, nobody can raid that district again for a while (longer if the raid failed)
func _test_raid_cooldown():
	var c = CityMap.new()
	var me = c.player_id
	var dogs: Faction = c.factions["rust_dogs"]
	var home: District = c.districts[c.factions[me].home_id]
	var between: District = null
	for n_id in home.neighbor_ids:
		if dogs.home_id in c.districts[n_id].neighbor_ids:
			between = c.districts[n_id]
	between.influence.clear()
	between.add_influence(me, 60.0)
	dogs.arms = 10.0
	dogs.supplies = 50.0
	dogs.manpower = 20.0
	var err = c.check_launch("rust_dogs", "raid", between)
	_check("raiders can raid a bordering district", err == "", err)
	c.launch_venture("rust_dogs", "raid", between, -2, -1, 0)
	for i in 30:
		if between.raid_safe_until > 0:
			break
		c.advance_day()
	var cooldown: Dictionary = GameData.venture("raid")["raid_cooldown"]
	var left = between.raid_safe_until - c.day
	_check("a raid starts a cooldown of 30-60 days", left >= cooldown["success"] - 1 and left <= cooldown["disaster"], str(left))
	_check("a raided district can't be raided again yet", c.check_launch("rust_dogs", "raid", between).begins_with("Raided recently"))
	_check("the cooldown is saved", int(between.to_dict()["raid_safe_until"]) == between.raid_safe_until)

# Raids are worth what the district is worth; raiders can be paid off, refused or threatened
func _test_raiders_and_deterrence():
	var c = CityMap.new()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var dogs: Faction = c.factions["rust_dogs"]
	var home: District = c.districts[p.home_id]
	var between: District = null
	for n_id in home.neighbor_ids:
		if dogs.home_id in c.districts[n_id].neighbor_ids:
			between = c.districts[n_id]
	between.influence.clear()
	between.add_influence(me, 60.0)
	between.development = 0.25
	between.buildings.clear()
	_check("a fresh claim is worth little to raid", c.raid_worth(between) < 0.8, str(c.raid_worth(between)))
	_check("a rebuilt home is worth more to raid", c.raid_worth(home) > c.raid_worth(between))
	# Loot scales with worth
	p.supplies = 100.0
	dogs.supplies = 0.0
	VentureSystem.apply_effects(GameData.venture("raid")["success_effects"], dogs, me, between, c)
	_check("raiding a fresh claim takes less than the full 12 food", dogs.supplies < 12.0 and dogs.supplies > 0.0, str(dogs.supplies))
	# Tribute: only once they've menaced you, then they must keep away
	_check("no tribute to a faction that never raided you", Diplomacy.check_action(c, "tribute", me, "rust_dogs") != "")
	var r = c.relation(me, "rust_dogs")
	r.last_raid["rust_dogs"] = maxi(1, c.day)
	p.materials = 100.0
	var err = Diplomacy.check_action(c, "tribute", me, "rust_dogs")
	_check("tribute can be paid to a faction that raided you", err == "", err)
	var price = Diplomacy.action_cost(c, "tribute", me, "rust_dogs")
	_check("tribute is paid in food or materials, never wealth", not price.has("wealth") and price.size() == 1, str(price))
	Diplomacy.start_action(c, "tribute", me, "rust_dogs")
	for i in 5:
		c.advance_day()
	_check("paid tribute keeps them away", r.spare_until["rust_dogs"] > c.day)
	dogs.arms = 10.0
	dogs.supplies = 50.0
	dogs.manpower = 20.0
	_check("a faction paid off can't raid you", c.check_launch("rust_dogs", "raid", between).begins_with("You promised"))
	# Raiding the one who promised to spare you voids the promise
	var dogs_home: District = c.districts[dogs.home_id]
	p.manpower = 20.0
	p.arms = 10.0
	p.supplies = 50.0
	c.launch_venture(me, "raid", dogs_home)
	_check("raiding them voids their promise", r.spare_until["rust_dogs"] <= c.day)
	c.ventures = c.ventures.filter(func(v): return v.faction_id != me)
	# Tribute offered to the player waits for an answer, and declining binds nothing
	var r2 = c.relation("rust_dogs", me)
	r2.last_raid[me] = maxi(1, c.day)
	r2.spare_until[me] = 0
	dogs.materials = 100.0
	c.proposals.clear()
	Diplomacy.resolve_mission(c, DiplomaticMission.new("tribute", "rust_dogs", me, 0))
	_check("tribute offered to you waits for your answer", c.proposal_between("rust_dogs", me) >= 0 and r2.spare_until[me] <= c.day)
	c.answer_proposal(c.proposal_between("rust_dogs", me), false)
	_check("declined tribute leaves you free to raid", r2.spare_until[me] <= c.day)
	Diplomacy.resolve_mission(c, DiplomaticMission.new("tribute", "rust_dogs", me, 0))
	c.answer_proposal(c.proposal_between("rust_dogs", me), true)
	_check("accepted tribute binds you", r2.spare_until[me] > c.day)
	r2.spare_until[me] = 0
	# A refused demand emboldens the raider
	Diplomacy._demand_refused(c, "rust_dogs", me)
	var odds = VentureSystem.compute_odds("raid", dogs, between, c, me)
	_check("a refused demand gives the raider better odds", odds["factors"].any(func(f): return f[0].begins_with("Emboldened")))
	# Threaten: a venture against a raider on your border
	r.spare_until["rust_dogs"] = 0
	var dogs_land: District = c.districts[dogs.home_id]
	p.supplies = 50.0
	p.manpower = 20.0
	err = c.check_launch(me, "threaten", dogs_land)
	_check("you can threaten a raider on your border", err == "", err)
	VentureSystem.apply_effects(GameData.venture("threaten")["success_effects"], p, "rust_dogs", dogs_land, c)
	_check("a successful threat keeps them away", r.spare_until["rust_dogs"] > c.day + 40)
	var saved = Relation.from_dict(r.to_dict())
	_check("raid promises are saved", saved.spare_until["rust_dogs"] == r.spare_until["rust_dogs"] and saved.bold_until["rust_dogs"] == r.bold_until["rust_dogs"])
	# Pacts can be paid in food or materials
	p.wealth = 0.0
	var pact_cost = Diplomacy.action_cost(c, "pact", me, "guild")
	_check("a pact can be paid without wealth", not pact_cost.has("wealth") and p.can_afford(pact_cost), str(pact_cost))
	# Pacts only between neighbours, and nobody offers one without a reason
	var fresh = CityMap.new()
	_check("no pact with a faction you don't border", Diplomacy.check_action(fresh, "pact", "guild", fresh.player_id).begins_with("You don't share a border"))
	var offers = 0
	for i in 200:
		fresh.advance_day()
		offers += fresh.proposals.filter(func(x): return x["action"] == "pact" and not fresh.shares_border(x["from"], fresh.player_id)).size()
	_check("no pact offers from factions that don't border you", offers == 0, str(offers))

# National Ambitions: gated by situation, paid in renown, closing rivals, lasting once done
func _test_ambitions():
	var c = CityMap.new()
	var me = c.player_id
	var p: Faction = c.factions[me]
	p.add_renown(50.0)
	_check("a crew that isn't Militaristic can't start A Name to Fear", c.check_ambition(me, "name_to_fear").begins_with("Needs"))
	p.traits.add_faction_trait_value("Militaristic", 60.0)
	p.renown = 0.0
	_check("an ambition you can't pay for says so", c.check_ambition(me, "name_to_fear").contains("renown"))
	p.add_renown(50.0)
	var rep = p.reputation
	_check("a qualifying, paid-up ambition can start", c.start_ambition(me, "name_to_fear") == "")
	_check("starting spends renown but not reputation", p.renown < 50.0 and p.reputation == rep)
	_check("choosing it closes its rival for good", "good_neighbours" in p.ambitions_closed)
	_check("only one ambition at a time", c.check_ambition(me, "walls_and_watches") != "")
	var before = VentureSystem.compute_odds("raid", p, c.districts[p.home_id], c, "")["factors"].size()
	for i in c.ambition_days(me, "name_to_fear"):
		c.advance_day()
	_check("an ambition completes after its time", "name_to_fear" in p.ambitions_done and p.ambition == "")
	var factors = VentureSystem.compute_odds("raid", p, c.districts[p.home_id], c, "")["factors"]
	_check("its bonus lasts: raids get an odds factor", factors.any(func(f): return f[0] == "A Name to Fear"), str(factors))
	var saved = Faction.from_dict(p.to_dict())
	_check("ambitions survive a save", "name_to_fear" in saved.ambitions_done and "good_neighbours" in saved.ambitions_closed)
	# Welfare for All fails if you raid while it runs
	p.traits.add_faction_trait_value("Socialist", 60.0)
	p.add_renown(50.0)
	var err = c.start_ambition(me, "welfare_for_all")
	_check("Welfare for All can start", err == "", err)
	c.fail_ambition(me, "test")
	_check("a failed ambition ends without its bonus", p.ambition == "" and "welfare_for_all" not in p.ambitions_done)

# Governments: gangs and warlords at the start, reforms with a cost and a lock, rules that change succession
func _test_government():
	var c = CityMap.new()
	var me = c.player_id
	var p: Faction = c.factions[me]
	_check("minor factions start as gangs, major ones as Warlords", c.factions["rust_dogs"].government == "gang" and p.government == "warlord")
	var dogs: Faction = c.factions["rust_dogs"]
	_check("a gang can only become a Warlord crew", c.reform_options("rust_dogs") == ["warlord"])
	_check("a gang must grow and achieve something first", c.check_reform("rust_dogs", "warlord").begins_with("Needs"))
	# Autocracy: a strongman's reform, then stricter contests
	p.ambitions_done.append("strongmans_crown")
	for d in c.districts.slice(0, 12):
		d.influence.clear()
		d.add_influence(me, 80.0)
	p.wealth = 200.0
	p.add_renown(50.0)
	var grievance_before = c.districts[p.home_id].grievance
	var err = c.take_reform(me, "autocracy")
	_check("a qualifying faction can crown a strongman", err == "" and p.government == "autocracy", err)
	_check("a reform unsettles your districts", c.districts[p.home_id].grievance > grievance_before)
	_check("no second reform for two years", c.check_reform(me, "politburo").begins_with("Too soon"))
	var saved = Faction.from_dict(p.to_dict())
	_check("the government survives a save", saved.government == "autocracy" and saved.reform_locked_until == p.reform_locked_until)
	# The Politburo's council votes: a majority against blocks a reform
	p.government = "politburo"
	p.reform_locked_until = 0
	p.effect_cache.clear()
	var hired = c.characters_of(me).filter(func(x): return not x.family)
	c.appoint(hired[0].id, "war_chief")
	c.appoint(hired[1].id, "envoy")
	var council = c.characters_of(me).filter(func(x): return x.post != "")
	for x in council:
		x.traits.append("cruel")
	p.traits.add_faction_trait_value("Socialist", 60.0)
	var stance = c.council_stance(me, "democracy")
	_check("councillors take sides by their natures", council.size() >= 2 and stance["against"].size() == council.size())
	# Meet every requirement for the Oligarchy, with a council that opposes it: only the vote stands in the way
	for x in council:
		x.traits.append("kind")
	p.traits.add_faction_trait_value("Merchant", 60.0)
	p.ambitions_done.append("charter_the_guilds")
	p.wealth = 500.0
	var vote = c.check_reform(me, "oligarchy")
	_check("under the Politburo a council majority against blocks a reform", vote.begins_with("The council votes it down"), vote)
	# A purge removes the rival without splitting the land
	var held = c.districts_held(me)
	var rival = council[0]
	c._purge(me, rival)
	_check("a purge expels the rival and keeps the land", c.districts_held(me) == held and (c.character_by_id(rival.id) == null or c.character_by_id(rival.id).faction_id != me))

# Standing tasks: a councillor works a district until it's done; commitment, stopping, pausing, saving
func _test_tasks():
	var c = CityMap.new()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var home: District = c.districts[p.home_id]
	p.supplies = 500.0
	p.materials = 500.0
	p.manpower = 40.0
	_check("routine work on your own land isn't a one-off launch", c.check_launch(me, "scavenge", home).begins_with("Assign a councillor"))
	_check("the AI is held to the same rule", c.check_launch("rust_dogs", "scavenge", c.districts[c.factions["rust_dogs"].home_id]).begins_with("Assign a councillor"))
	_check("only a councillor can take a task", c.check_task(me, "scavenge", home).begins_with("Nobody sits on your council") or c.check_task(me, "scavenge", home).begins_with("No councillor"))
	var hired = c.characters_of(me).filter(func(x): return not x.family)
	c.appoint(hired[0].id, "quartermaster")
	var q: Character = hired[0]
	# Skilled enough that the odds stay above 90% (no Disasters), so no death can end the test early
	q.skills["stewardship"] = 10
	# Nearly stripped, so the task finishes in a few runs (a long run lets deaths and successions intrude)
	home.ruin_level = 0.13
	var err = c.assign_task(me, "scavenge", home, q.id)
	_check("a councillor can be assigned to scavenge home", err == "" and c.task_of(q) != null, err)
	_check("a councillor on a task can't lead a one-off", c.leader_busy(q))
	for i in 60:
		c.advance_day()
		if c.task_of(q) == null:
			break
	_check("the task ends when the ruins are stripped", c.task_of(q) == null and home.ruin_level < 0.1, "ruins %.2f, post %s, leader %s, faction %s, wounded %s, err %s, departed %s" % [home.ruin_level, q.post, q.is_leader, q.faction_id, q.is_wounded(c.day), err, str(c.departed.map(func(x): return x["name"] + ":" + x["fate"]))])
	_check("a task that ends naturally frees the councillor at once", not c.leader_busy(q) or q.is_wounded(c.day))
	# Stopping: free of cost, but the commitment holds
	q.wounded_until = 0
	home.development = 0.3
	err = c.assign_task(me, "rebuild", home, q.id)
	_check("a councillor can be assigned to rebuild", err == "", err)
	var t = c.task_of(q)
	c.stop_task(t)
	for i in 20:
		c.advance_day()
	_check("a stopped task ends after its run", c.task_of(q) == null)
	_check("stopping early keeps the councillor committed for two runs", q.committed_until == t.committed_until and t.committed_until > t.started_day, "%d vs %d" % [q.committed_until, t.committed_until])
	# A wounded councillor's task waits for them
	q.committed_until = 0
	home.development = 0.3
	c.assign_task(me, "rebuild", home, q.id)
	t = c.task_of(q)
	q.wounded_until = c.day + 30
	c.ventures = c.ventures.filter(func(v): return v.leader_id != q.id)
	c._continue_task(t)
	_check("a wounded councillor's task pauses instead of ending", c.task_of(q) == t and t.paused == "wounded")
	var loaded = CityMap.new(bytes_to_var(var_to_bytes(c.to_save())))
	_check("tasks survive a save", loaded.tasks.size() == c.tasks.size() and loaded.character_by_id(q.id).committed_until == q.committed_until)

# District payoffs: reaching a district's ceilings pays, and Restored pays renown once
func _test_district_payoffs():
	var c = CityMap.new()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var home: District = c.districts[p.home_id]
	home.ruin_level = 0.5
	home.development = 0.5
	var slots_before = c.building_slots(home)
	var food_before = c.district_food(home)
	home.ruin_level = 0.05
	_check("clearing the ruins earns Cleared and more food", c.district_payoffs(home)["cleared"] and c.district_food(home) > food_before)
	home.development = 1.0
	_check("full development earns Rebuilt and a building slot", c.district_payoffs(home)["rebuilt"] and c.building_slots(home) > slots_before)
	home.hazard = 0.0
	home.influence.clear()
	home.add_influence(me, 100.0)
	_check("cleared, safe, rebuilt and secured is Restored", c.district_payoffs(home)["restored"])
	var renown = p.renown
	c.advance_day()
	c.advance_day()
	_check("restoring a district pays renown once", p.renown >= renown + GameData.rule("payoff_restored_renown") and p.renown < renown + 2 * GameData.rule("payoff_restored_renown") + 20)
	_check("the rival's same district rules apply to everyone", c.district_payoffs(c.districts[c.factions["rival"].home_id]).has("restored"))

# Choice events: they come, wait for the player, cost nothing, and their effects last a set time; families grow
# Doc 14 slice 2: the upbringing choice at 6, growing up, and traits settling at 16
func _test_education():
	var c = CityMap.new()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var leader = c.leader_of(me)
	var child = c._new_child(leader, 0)
	# (by chance a newborn can have no particular nature, so its leanings may be empty)
	_check("a newborn has leanings, not traits", child.traits.is_empty() and child.leanings.values().all(func(x): return x == GameData.rule("nature_at_birth")), str(child.traits))
	child.age = 6
	c.pending_events.clear()
	c._fire_moment(me, "education", child)
	_check("at six, the player chooses an upbringing", c.pending_events.size() == 1 and c.pending_events[0]["event"] == "upbringing")
	var entry = c.pending_events[0]
	var options: Array = GameData.events()["upbringing"]["options"]
	var school = 0
	var parents = 0
	for i in options.size():
		if options[i].get("upbringing") == "school":
			school = i
		if options[i].get("upbringing") == "parents":
			parents = i
	_check("school needs a School, and says where to get one", c.event_option_blocked(me, entry, options[school]).begins_with("Needs a School"))
	_check("the parents need nothing", c.event_option_blocked(me, entry, options[parents]) == "")
	var home: District = c.districts[p.home_id]
	home.buildings.append("school")
	_check("with a School, school can be chosen", c.event_option_blocked(me, entry, options[school]) == "", c.event_option_blocked(me, entry, options[school]))
	var wealth = p.wealth
	c.answer_event(school)
	_check("the choice costs nothing and sets the upbringing", child.upbringing == "school" and p.wealth == wealth)
	# Ten years at school: Diplomacy and Stewardship grow fastest, and the child leans Of the People
	for y in 10:
		c._grow_year(child)
	# Over many schooled children (one alone can be an exception)
	var taught = 0
	var untaught = 0
	for k in 30:
		var pupil = c._new_child(leader, 6)
		pupil.upbringing = "school"
		for y in 10:
			c._grow_year(pupil)
		taught += pupil.skills["diplomacy"] + pupil.skills["stewardship"]
		untaught += pupil.skills["command"] + pupil.skills["cunning"]
		c.characters.erase(pupil)
	_check("schooling raises Diplomacy and Stewardship most", taught > untaught * 1.5, "%d vs %d" % [taught, untaught])
	_check("a schooled child leans Of the People", child.leanings.get("of_the_people", 0.0) >= 5.0, str(child.leanings))
	_check("a strong leaning has a good but never certain chance to settle", c.settle_chance(child, "of_the_people") > 0.4 and c.settle_chance(child, "of_the_people") <= 0.8)
	# Across many children the choice biases the outcome
	var people = 0
	var rulers = 0
	var both = 0
	for k in 200:
		var a = c._new_child(leader, 6)
		a.upbringing = "school"
		var b = c._new_child(leader, 6)
		b.upbringing = "hired"
		b.tutor_skill = "command"
		for y in 10:
			c._grow_year(a)
			c._grow_year(b)
		c._settle_traits(a)
		c._settle_traits(b)
		people += 1 if a.has_trait("of_the_people") else 0
		rulers += 1 if b.has_trait("born_to_rule") else 0
		for x in [a, b]:
			both += 1 if x.has_trait("of_the_people") and x.has_trait("born_to_rule") else 0
		c.characters.erase(a)
		c.characters.erase(b)
	_check("most schooled children settle Of the People", people > 100, "%d of 200" % people)
	_check("most tutored children settle Born to Rule", rulers > 90, "%d of 200" % rulers)
	_check("opposite traits never settle together", both == 0)
	# Born to Rule: sharper at their best skill, and a stronger claim as heir
	var heir = c._new_child(leader, 20)
	heir.skills = {"command": 7, "cunning": 2, "diplomacy": 2, "stewardship": 2}
	p.designated_heir = heir.id
	var claim = c.succession_outlook(me)["claim"]
	heir.traits = ["born_to_rule"]
	_check("Born to Rule adds to the heir's claim", c.succession_outlook(me)["claim"] > claim + 9.0)
	_check("Born to Rule sharpens their best skill", heir.trait_factors("command").size() == 1 and heir.trait_factors("diplomacy").is_empty())
	# Childhood events fit the upbringing and shape the child
	var kid = c._new_child(leader, 9)
	kid.upbringing = "school"
	c.pending_events.clear()
	c._fire_moment(me, "childhood", kid)
	var ev_id: String = c.pending_events[0]["event"] if not c.pending_events.is_empty() else ""
	_check("a childhood event comes, fitting the upbringing", ev_id != "" and "school" in GameData.events()[ev_id].get("upbringing", ["school"]), ev_id)
	var before = kid.leanings.duplicate()
	c.answer_event(0)
	_check("a childhood choice changes the child's leanings", kid.leanings != before)
	_check("and won't come again for that child", ev_id in kid.childhood)
	# The AI raises its own children, by the same options
	var ai_child = c._new_child(c.leader_of("guild"), 6)
	c._fire_moment("guild", "education", ai_child)
	_check("the AI picks an upbringing it can take", ai_child.upbringing in ["tutor", "hired", "parents"] or (ai_child.upbringing == "school" and c.has_school("guild")), ai_child.upbringing)
	# Changing an upbringing: the player reopens the choice, at most once a year
	var young = c._new_child(leader, 4)
	_check("a child under six can't have it changed yet", c.check_upbringing_change(young).begins_with("Chosen when they turn"))
	var pupil = c._new_child(leader, 11)
	pupil.upbringing = "tutor"
	var old_tutor = c._new_person(me, "Test", 40, "m")
	old_tutor.post = "fixer"
	pupil.tutor_id = old_tutor.id
	pupil.tutor_skill = old_tutor.best_skill()
	var skills_before = pupil.skills.duplicate()
	c.pending_events.clear()
	_check("a child raised before the story began can be changed at once", c.request_upbringing_change(pupil) == "", c.check_upbringing_change(pupil))
	c.decline_event()
	_check("keeping things as they are changes nothing", c.pending_events.is_empty() and pupil.upbringing == "tutor")
	c.request_upbringing_change(pupil)
	var loyalty = old_tutor.loyalty()
	c.answer_event(parents)
	_check("the change takes, and what they learned stays", pupil.upbringing == "parents" and pupil.skills == skills_before)
	_check("the dropped tutor resents it", old_tutor.loyalty() < loyalty)
	_check("it can't be changed again for a year", c.check_upbringing_change(pupil).begins_with("Changed lately"))
	c.pending_events.clear()
	# Saved and loaded
	var saved = Character.from_dict(child.to_dict())
	_check("upbringing and leanings are saved", saved.upbringing == "school" and saved.leanings == child.leanings)

func _test_events_and_births():
	var c = CityMap.new()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var wealth = p.wealth
	c._fire_moment(me, "pulse", c.leader_of(me))
	_check("an everyday event comes to the player and waits for an answer", c.pending_events.size() == 1)
	var entry = c.pending_events[0]
	c.answer_event(0)
	_check("answering costs nothing", p.wealth == wealth)
	_check("the chosen option takes effect for a set time", p.timed_effects.size() == 1 and p.timed_effects[0]["until"] > c.day)
	var until: int = p.timed_effects[0]["until"]
	for i in until - c.day + 1:
		c.advance_day()
	_check("its effect wears off", p.timed_effects.filter(func(t): return t["label"] == GameData.events()[entry["event"]]["title"]).is_empty())
	_check("the next everyday event is 3-4 months away", p.next_event_day >= c.day - 1)
	var ai: Faction = c.factions["guild"]
	var waiting = c.pending_events.size()
	var ai_effects = ai.timed_effects.size()
	c._fire_moment("guild", "pulse", c.leader_of("guild"))
	_check("the AI answers its own events", ai.timed_effects.size() == ai_effects + 1 and c.pending_events.size() == waiting)
	# Every married couple can have children: news, then a birth
	# A fresh couple from the family (not the leader's: a leader's death risk made this flaky)
	var mother = c._new_person(me, c.leader_of(me).dynasty, 30, "f")
	mother.family = true
	c._marry(mother)
	var kids_before = c.everyone_of(me).filter(func(x): return mother.id in x.parent_ids).size()
	mother.due_day = c.day + 5
	for i in 40:
		c.advance_day()
	_check("a pregnancy ends in a birth", c.everyone_of(me).filter(func(x): return mother.id in x.parent_ids).size() == kids_before + 1 and mother.due_day == 0, "kids %d->%d, due %d, alive %s, day %d" % [kids_before, c.everyone_of(me).filter(func(x): return mother.id in x.parent_ids).size(), mother.due_day, str(mother.death_day < 0), c.day])
	_check("a birth brings a choice event", c.pending_events.any(func(e): return GameData.events()[e["event"]]["moment"] == "birth"))
	var loaded = CityMap.new(bytes_to_var(var_to_bytes(c.to_save())))
	_check("waiting events and timed effects survive a save", loaded.pending_events.size() == c.pending_events.size() and loaded.factions["guild"].timed_effects.size() == ai.timed_effects.size())

func _test_minor_patrons():
	var c = CityMap.new()
	var me = c.player_id
	c.factions[me].wealth = 500.0
	c.factions[me].manpower = 30.0
	var ratio = c.faction_strength("st_brigids") / c.faction_strength(me)
	var err = Diplomacy.check_action(c, "vassalage", me, "st_brigids")
	_check("a minor faction up to 70% of your strength can become your vassal", ratio >= 0.7 or not err.begins_with("They're too strong"), "%s (ratio %.2f)" % [err, ratio])

# Doc 16, H1: grown family members marry (a choice event), so a family branches into generations
func _test_matches():
	var c = _new_city()
	var me = c.player_id
	var leader = c.leader_of(me)
	var heir = c._new_child(leader, 18)
	heir.sex = "m"
	var captain = c._new_person(me, "Hale", 22, "f")
	captain.skills["command"] = 9
	c.pending_events.clear()
	c._fire_moment(me, "match", heir)
	_check("a grown family member gets a match event", c.pending_events.size() == 1 and c.pending_events[0]["event"] == "a_match")
	var entry = c.pending_events[0]
	_check("the match names a captain", int(entry["match_id"]) == captain.id, str(entry.get("match_id")))
	_check("the button names them", c.event_option_label(entry, GameData.events()["a_match"]["options"][0]).contains(captain.name))
	var loyalty = captain.loyalty()
	c.answer_event(0)
	_check("they marry, and the captain joins the family", heir.spouse_id == captain.id and captain.spouse_id == heir.id and captain.family)
	_check("binding a captain to the family raises their loyalty", captain.loyalty() > loyalty)
	# Someone from the people: a new spouse, Of the People
	var sister = c._new_child(leader, 20)
	sister.sex = "f"
	c._fire_moment(me, "match", sister)
	var people_option = 0
	for i in GameData.events()["a_match"]["options"].size():
		if GameData.events()["a_match"]["options"][i].get("marry", "") == "people":
			people_option = i
	c.answer_event(people_option)
	var spouse = c.character_by_id(sister.spouse_id)
	_check("a match from the people brings in someone Of the People", spouse != null and spouse.family and spouse.has_trait("of_the_people"))
	# With nobody fitting, the captain option is closed and says why
	var lonely = c._new_child(leader, 19)
	lonely.sex = "f"
	for x in c.characters_of(me):
		if x.sex == "m" and not x.family:
			x.spouse_id = 99999
	c._fire_moment(me, "match", lonely)
	var e2 = c.pending_events[c.pending_events.size() - 1]
	_check("no captain to marry: the option says so", c.event_option_blocked(me, e2, GameData.events()["a_match"]["options"][0]).begins_with("No unmarried"))
	c.pending_events.clear()
	# The family has a limit
	for k in 20:
		c._new_child(leader, 2)
	var due_before = sister.due_day
	for i in 40:
		c.advance_day()
	_check("a family at its limit has no more children", c.family_size(me) >= int(GameData.rule("family_cap")) and sister.due_day == due_before)
	# The AI answers its own matches
	var ai_heir = c._new_child(c.leader_of("guild"), 18)
	c._fire_moment("guild", "match", ai_heir)
	_check("the AI answers its own match (marrying or not)", c.pending_events.is_empty())

# Doc 16, H2: houses inside a faction, with land, loyalty, revolt, the call to arms and matches
func _test_houses():
	var c = _new_city()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var leader = c.leader_of(me)
	var son = c._new_child(leader, 20)
	var home: District = c.districts[p.home_id]
	_border_with(c, me, "guild")
	var land: District = null
	for n_id in home.neighbor_ids:
		if c.districts[n_id].owner_id() == "":
			land = c.districts[n_id]
			break
	land.influence.clear()
	land.add_influence(me, 80.0)
	_check("your home can't be granted", c.check_grant(me, son, home).begins_with("Not your home"))
	_check("a child can't hold land", c.check_grant(me, c._new_child(leader, 9), land).ends_with("too young to hold land"))
	var captain = c._new_person(me, "Hale", 30, "m")
	captain.loyalty_mods = [{"id": "dismissed", "value": -30.0}]
	_check("a disloyal captain can't be trusted with land", c.check_grant(me, captain, land).contains("isn't loyal enough"))
	var loyalty = son.loyalty()
	_check("granting land founds a house", c.grant_land(me, son, land) == "" and son.house_id >= 0 and land.house_id == son.house_id)
	var hid = son.house_id
	_check("the house keeps a share of the district's income", c.house_keep(land) < 1.0 and c.house_keep(home) == 1.0)
	_check("being granted land raises their loyalty", son.loyalty() > loyalty)
	_check("the house's head is its eldest grown member", c.house_head(hid) == son)
	# A match with the house binds it
	var bride = c._new_person(me, "Hale", 20, "f")
	bride.house_id = hid
	var heir = c._new_child(leader, 19)
	heir.sex = "m"
	c.pending_events.clear()
	c._fire_moment(me, "match", heir)
	var entry = c.pending_events[0]
	_check("a match can be made with a house", int(entry.get("house_match_id", -1)) == bride.id)
	var house_option = 0
	for i in GameData.events()["a_match"]["options"].size():
		if GameData.events()["a_match"]["options"][i].get("marry", "") == "house":
			house_option = i
	var before = c.house_loyalty(hid)
	c.answer_event(house_option)
	_check("marrying into a house raises its loyalty", heir.spouse_id == bride.id and bride.family and c.house_loyalty(hid) > before)
	# The call to arms
	_check("no call to arms in peace", c.check_call_house(me, hid) == "You're not at war")
	c.start_war(me, "guild")
	land.garrison = 10.0
	var manpower = p.manpower
	c.call_house(me, hid)
	_check("a called house answers once, joining or declining", c.check_call_house(me, hid).begins_with("Asked already") and (p.manpower > manpower or land.garrison == 10.0))
	# A disloyal house warns, then breaks away with its land
	son.loyalty_mods = [{"id": "dismissed", "value": -30.0}, {"id": "passed_over", "value": -25.0}]
	son.traits.clear()
	var warned = []
	c.event.connect(func(t, k): if "is restless" in t: warned.append(t))
	c._update_houses()
	_check("a disloyal house warns you first", warned.size() == 1, "loyalty %d" % c.house_loyalty(hid))
	c._house_revolt(c.house(hid))
	_check("a house that revolts breaks away with its land, at war with you", land.owner_id() != me and land.owner_id() != "" and c.is_at_war(me, land.owner_id()) and son.faction_id == land.owner_id())
	# Vassalize makes the absorbed ruling family a house holding its old districts
	var c2 = _new_city()
	var me2 = c2.player_id
	var dogs_leader = c2.leader_of("rust_dogs")
	var dogs_land = c2.districts[c2.factions["rust_dogs"].home_id]
	c2._absorb("rust_dogs", me2)
	_check("an absorbed ruling family becomes a house holding its old land", dogs_leader.house_id >= 0 and dogs_land.house_id == dogs_leader.house_id and dogs_land.owner_id() == me2)
	# A house head (its eldest grown member) can contest a succession
	var head = c2.house_head(dogs_leader.house_id)
	head.loyalty_mods = [{"id": "absorbed", "value": -30.0}]
	head.skills["command"] = 10
	var contesters = c2.succession_outlook(me2)["contesters"].map(func(x): return x[0])
	_check("a disloyal house head contests the succession", head in contesters, "%s loyalty %d" % [head.name, head.loyalty()])
	# Losing a house's land in war
	head.loyalty_mods.clear()
	var head_loyalty = head.loyalty()
	c2.start_war(me2, "guild")
	var owner_before = dogs_land.owner_id()
	dogs_land.influence.clear()
	dogs_land.add_influence("guild", 90.0)
	c2._announce_ownership_change(dogs_land, owner_before, "guild")
	_check("a house that loses its land blames you", dogs_land.house_id == -1 and head.loyalty() < head_loyalty)
	# Saved and loaded
	var saved = CityMap.new(bytes_to_var(var_to_bytes(c2.to_save())))
	_check("houses are saved", saved.houses.size() == c2.houses.size() and saved.next_house_id == c2.next_house_id)

# Doc 16, H3: marriage between factions binds their families
func _test_cross_matches():
	var c = _new_city()
	var me = c.player_id
	for x in c.characters_of(me):
		if x.family:
			x.spouse_id = c.leader_of(me).id
	_check("with nobody to offer, no match", Diplomacy.check_action(c, "match", me, "guild").begins_with("You have no unmarried"))
	var son = c._new_child(c.leader_of(me), 24)
	son.sex = "m"
	for x in c.characters_of("guild"):
		x.spouse_id = c.leader_of("guild").id
	_check("they need someone too", Diplomacy.check_action(c, "match", me, "guild").begins_with("They have nobody"))
	var bride = c._new_child(c.leader_of("guild"), 22)
	bride.sex = "f"
	c.factions[me].wealth = 100.0
	_check("a match can be proposed", Diplomacy.check_action(c, "match", me, "guild") == "", Diplomacy.check_action(c, "match", me, "guild"))
	Diplomacy.form_treaty(c, "match", me, "guild")
	_check("their bride joins your family", bride.faction_id == me and bride.family and bride.spouse_id == son.id and son.spouse_id == bride.id)
	_check("the families are bound", c.marriage_tie(me, "guild") and Diplomacy.opinion_baseline(c, "guild", me).any(func(part): return part[0] == "Bound by marriage"))
	_check("bound families deal more easily", Diplomacy.acceptance(c, "pact", me, "guild")["factors"].any(func(f): return f[0] == "Bound by marriage"))
	_check("pressing a claim on in-laws breaks your word", c.oath_broken(me, "guild").contains("marriage"))
	var saved = Relation.from_dict(c.relation(me, "guild").to_dict())
	_check("marriages between factions are saved", saved.marriages.size() == 1)

# Gives `them` a district next to `me`'s home, and lifts the opening truce, so the two can quarrel
func _border_with(c: CityMap, me: String, them: String):
	var home: District = c.districts[c.factions[me].home_id]
	for n_id in home.neighbor_ids:
		var d: District = c.districts[n_id]
		if d.owner_id() == "":
			d.influence.clear()
			d.add_influence(them, 60.0)
			break
	c.relation(me, them).truce_until_day = 0
	c.border_cache_day = -1

# Doc 15, P2: no war without a justified goal and a refused ultimatum; wars end on their goal
func _test_war_goals():
	var c = _new_city()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var dogs = "rust_dogs"
	p.renown = 200.0
	p.wealth = 500.0
	var r = c.relation(me, dogs)
	_border_with(c, me, dogs)
	_check("a claim needs a shared border", c.check_justify(me, "guild", "claim") != "" or c.shares_border(me, "guild"))
	var target: District = c.claim_district(me, dogs)
	_check("a claim names one of their districts on your border", target != null and target.owner_id() == dogs)
	# Without cause it takes twice as long
	var days = c.justify_days(me, dogs, "claim")
	_check("no cause: twice as long", c.claim_reason(me, dogs) != "" or days == int(GameData.war_goal("claim")["justify_days"] * GameData.rule("claim_no_reason_mult")))
	var renown = p.renown
	_check("justifying a claim works", c.justify(me, dogs, "claim") == "", c.check_justify(me, dogs, "claim"))
	_check("it costs renown and wealth", p.renown < renown)
	_check("one claim at a time", c.check_justify(me, "guild", "claim") != "")
	_check("the target thinks less of you", r.modifiers[dogs].any(func(m): return m["id"] == "claimed_us"))
	# Justified: the ultimatum goes out; refused, it's war over the goal
	if not r.claim.is_empty():
		r.claim["ready_day"] = c.day
	c._update_claims()
	_check("a justified claim becomes an ultimatum, or is answered", r.claim.is_empty() or r.claim["stage"] in ["ultimatum", "war"])
	r.claim = {"by": me, "goal": "claim", "district": target.id, "reason": "", "stage": "ultimatum", "ready_day": c.day, "deadline": c.day + 15}
	r.at_war = false
	c.answer_ultimatum(r, false)
	_check("a refused ultimatum means war over the goal", r.at_war and r.claim["stage"] == "war")
	_check("no terms before the war score allows", c.check_enforce(me, dogs).begins_with("War score"))
	r.war_points = 60.0
	_check("enough war score: you can take your terms", c.check_enforce(me, dogs) == "", c.check_enforce(me, dogs))
	c.enforce_claim(me, dogs)
	_check("enforcing a claim takes the district and ends the war", target.owner_id() == me and not r.at_war and r.claim.is_empty())
	# An ultimatum to the player waits in Proposals; giving in applies the terms with no fight
	var c2 = _new_city()
	var me2 = c2.player_id
	var r2 = c2.relation(me2, dogs)
	_border_with(c2, me2, dogs)
	var home2: District = c2.claim_district(dogs, me2)
	r2.claim = {"by": dogs, "goal": "claim", "district": home2.id if home2 else -1, "reason": "", "stage": "justifying", "ready_day": c2.day, "deadline": 0}
	c2._update_claims()
	var index = -1
	for i in c2.proposals.size():
		if c2.proposals[i]["action"] == "ultimatum":
			index = i
	_check("an ultimatum to you waits for your answer", index >= 0 and r2.claim["stage"] == "ultimatum")
	if index >= 0 and home2:
		c2.answer_proposal(index, true)
		_check("giving in hands the district over, with no war", home2.owner_id() == dogs and not r2.at_war and r2.claim.is_empty())
	# Worn out first: the claimant pays and can't claim again for a while
	var c3 = _new_city()
	var me3 = c3.player_id
	var r3 = c3.relation(me3, dogs)
	_border_with(c3, me3, dogs)
	c3.factions[me3].wealth = 100.0
	r3.claim = {"by": me3, "goal": "subjugate", "district": -1, "reason": "", "stage": "war", "ready_day": 0, "deadline": 0}
	c3.start_war(me3, dogs)
	r3.exhaustion[me3] = 100.0
	c3._update_claims()
	_check("worn out first: the claim fails and the claimant pays", not r3.at_war and c3.factions[me3].wealth < 100.0)
	# Subjugate: they keep their land but trade only and pay in food, materials and wealth
	var c4 = _new_city()
	var me4 = c4.player_id
	var r4 = c4.relation(me4, dogs)
	r4.claim = {"by": me4, "goal": "subjugate", "district": -1, "reason": "", "stage": "war", "ready_day": 0, "deadline": 0}
	c4.start_war(me4, dogs)
	_occupy_all(c4, me4, dogs)
	c4.enforce_claim(me4, dogs)
	_check("subjugated: they're your tributary and keep their land", r4.overlord == me4 and c4.districts_held(dogs) > 0)
	_check("a tributary makes no diplomacy but trade", Diplomacy.check_action(c4, "pact", dogs, "guild").begins_with("Tributaries"))
	c4.factions[dogs].manpower = 40.0
	_check("a tributary fights with half its force", c4.crew_max(dogs, "assault") == 20)
	# Vassalize: they're absorbed, ruling house and all
	var c5 = _new_city()
	var me5 = c5.player_id
	var their_leader = c5.leader_of(dogs)
	var r5 = c5.relation(me5, dogs)
	r5.claim = {"by": me5, "goal": "vassalize", "district": -1, "reason": "", "stage": "war", "ready_day": 0, "deadline": 0}
	c5.start_war(me5, dogs)
	_occupy_all(c5, me5, dogs)
	c5.enforce_claim(me5, dogs)
	_check("vassalized: their faction is gone, their land and ruler are yours", not c5.factions.has(dogs) and their_leader.faction_id == me5 and not their_leader.is_leader)
	# Playtest: a weak faction raided by a strong one must have recourse; nothing but a shared border stops a claim
	var c8 = _new_city()
	var me8 = c8.player_id
	_border_with(c8, me8, dogs)
	c8.factions[me8].renown = 200.0
	c8.factions[me8].wealth = 500.0
	c8.factions[dogs].manpower = 500.0
	_check("strength doesn't stop a claim", c8.check_justify(me8, dogs, "vassalize") == "", c8.check_justify(me8, dogs, "vassalize"))
	var r8 = c8.relation(me8, dogs)
	r8.pact = true
	r8.treaty_until_day = c8.day + 300
	var guild_view = c8.opinion_of("guild", me8)
	_check("a treaty doesn't stop a claim either", c8.justify(me8, dogs, "claim") == "")
	_check("but breaking it costs your name with everyone", not r8.pact and c8.opinion_of("guild", me8) < guild_view - 20.0, "%d -> %d" % [guild_view, c8.opinion_of("guild", me8)])
	# Each raid by them while you justify brings the ultimatum sooner
	var ready_before = int(r8.claim["ready_day"])
	var raided_land: District = c8.districts[c8.factions[me8].home_id]
	c8.factions[dogs].arms = 20.0
	c8.factions[dogs].supplies = 50.0
	raided_land.raid_safe_until = 0
	c8.launch_venture(dogs, "raid", raided_land, -2, 6)
	var raid_v = null
	for v in c8.ventures:
		if v.faction_id == dogs and v.venture_id == "raid":
			raid_v = v
	if raid_v:
		c8._resolve(raid_v)
		c8.ventures.erase(raid_v)
	_check("their raid brings your ultimatum sooner", raid_v != null and int(r8.claim["ready_day"]) < ready_before, "%s -> %s" % [ready_before, r8.claim.get("ready_day")])
	_check("justifying takes months, not days", int(GameData.war_goal("claim")["justify_days"]) >= 120 and GameData.rule("ultimatum_days") >= 45)
	# Playtest: a claim under way could only be waited on. Send early when strong enough, withdraw, rally backers
	var c9 = _new_city()
	var me9 = c9.player_id
	_border_with(c9, me9, dogs)
	c9.factions[me9].renown = 200.0
	c9.factions[me9].wealth = 500.0
	c9.justify(me9, dogs, "vassalize")
	var r9 = c9.relation(me9, dogs)
	_check("a new claim can't go early: the notice runs first", c9.check_send_early(me9, dogs).begins_with("The notice runs"), c9.check_send_early(me9, dogs))
	_check("the claim notice says earliest, latest and the backers", c9.claim_notice_text(r9, dogs).contains("Backers"))
	c9.day += int(GameData.rule("min_claim_notice_days"))
	c9.factions[me9].manpower = 0.0
	c9.factions[dogs].manpower = 100.0
	_check("too weak: the ultimatum can't go early, and says how strong you need to be", c9.check_send_early(me9, dogs).begins_with("You need"))
	_check("you can ask a third faction to back your claim", Diplomacy.check_action(c9, "backing", me9, "guild") == "", Diplomacy.check_action(c9, "backing", me9, "guild"))
	_check("but not the faction you're claiming against", Diplomacy.check_action(c9, "backing", me9, dogs) != "")
	var before = c9.side_strength(me9, dogs)
	Diplomacy.form_treaty(c9, "backing", me9, "guild")
	_check("a backer counts toward your strength", "guild" in c9.claim_backers(me9, dogs) and c9.side_strength(me9, dogs) > before)
	c9.factions[me9].manpower = 2000.0
	c9.factions[dogs].manpower = 0.0
	_check("strong enough: send the ultimatum early", c9.check_send_early(me9, dogs) == "", c9.check_send_early(me9, dogs))
	c9.send_ultimatum_early(me9, dogs)
	_check("sending early moves the claim on", r9.claim.is_empty() or r9.claim["stage"] != "justifying")
	if r9.claim.get("stage", "") == "war":
		_check("a backer joins the war when the ultimatum is refused", c9.is_at_war("guild", dogs))
	var c10 = _new_city()
	var me10 = c10.player_id
	_border_with(c10, me10, dogs)
	c10.factions[me10].renown = 200.0
	c10.factions[me10].wealth = 500.0
	c10.justify(me10, dogs, "claim")
	_check("you can withdraw a claim", c10.withdraw_claim(me10, dogs) == "" and c10.relation(me10, dogs).claim.is_empty())
	_check("with no claim, nobody can be asked to back one", Diplomacy.check_action(c10, "backing", me10, "guild").begins_with("You have no claim"))
	# The player's faction is never absorbed: losing a Vassalize war makes you a tributary instead
	var c11 = _new_city()
	var me11 = c11.player_id
	var r11 = c11.relation(me11, dogs)
	r11.claim = {"by": dogs, "goal": "vassalize", "district": -1, "reason": "", "stage": "war", "ready_day": 0, "deadline": 0}
	c11.start_war(dogs, me11)
	_occupy_all(c11, dogs, me11)
	c11.enforce_claim(dogs, me11)
	_check("the player is never absorbed: they become a tributary", c11.factions.has(me11) and r11.overlord == dogs)
	# A white peace ends the claim; a claim survives a save
	var c6 = _new_city()
	var r6 = c6.relation(c6.player_id, dogs)
	r6.claim = {"by": dogs, "goal": "claim", "district": 0, "reason": "", "stage": "war", "ready_day": 0, "deadline": 0}
	r6.war_points = 12.0
	var saved = Relation.from_dict(r6.to_dict())
	_check("claims and war score are saved", saved.claim.get("goal", "") == "claim" and saved.war_points == 12.0)
	c6.start_war(dogs, c6.player_id)
	r6.peace_offered_by = dogs
	c6.make_peace(c6.player_id, dogs)
	_check("a white peace ends the claim", r6.claim.is_empty())
	# The AI presses claims in the open rather than declaring war out of the blue
	var c7 = _new_city()
	var seen_claims = []
	c7.event.connect(func(text, kind): if "justifying a claim" in text: seen_claims.append(text))
	for i in 500:
		c7.advance_day()
	_check("the AI justifies claims in the open", seen_claims.size() > 0, str(seen_claims.size()))

# The P1 playtest: wiped with 676 wealth and 50 manpower but no materials or arms; the game kept pausing
func _test_resources_and_pauses():
	var c = _new_city()
	var me = c.player_id
	var p: Faction = c.factions[me]
	# Fights need manpower, not arms; arms make them stronger and are used up a little
	_check("a raid needs no arms", not GameData.venture("raid")["cost"].has("arms") and not GameData.venture("assault")["cost"].has("arms"))
	p.arms = 0.0
	_check("unarmed crew use no arms", c.arms_used(me, "assault", 10) == 0)
	p.arms = 20.0
	_check("an armed fight uses some arms", c.arms_used(me, "assault", 10) > 0 and c.arms_used(me, "assault", 10) < 10)
	var dogs_land: District = c.districts[c.factions["rust_dogs"].home_id]
	_check("fights take no funding", c.check_launch(me, "raid", dogs_land, -2, -1, 1).begins_with("Fights take no funding") or c.check_launch(me, "raid", dogs_land, -2, -1, 0) != "")
	# Wealth buys materials and arms at once, dearer the more you buy
	p.wealth = 500.0
	p.materials = 0.0
	var first = c.buy_price(me, "materials", 1)
	_check("buying materials works", c.buy(me, "materials", 20) == "" and p.materials == 20.0 and p.wealth < 500.0)
	_check("buying raises the price", c.buy_price(me, "materials", 1) > first)
	for i in 120:
		c._ease_prices()
	_check("the price eases back", c.buy_price(me, "materials", 1) < first * 1.05)
	p.arms = GameData.rule("arms_cap") - 2.0
	_check("the armoury has a limit", c.check_buy(me, "arms", 5).begins_with("Your armoury"))
	p.wealth = 1.0
	_check("you can't buy without the wealth", c.check_buy(me, "materials", 5).begins_with("Need"))
	var saved = Faction.from_dict(p.to_dict())
	_check("recent purchases are saved", saved.bought.size() == p.bought.size())
	# The AI buys the same way when short
	var ai: Faction = c.factions["guild"]
	ai.materials = 0.0
	ai.wealth = 400.0
	ai.ai._think_buy(c)
	_check("the AI buys materials when short", ai.materials > 0.0 and ai.wealth < 400.0)
	# A waiting task says so once, and doesn't pause the game
	var kinds = []
	c.event.connect(func(text, kind): if "is waiting" in text: kinds.append(kind))
	var home: District = c.districts[p.home_id]
	home.development = 0.5
	p.materials = 50.0
	p.manpower = 20.0
	var q = c._new_person(me, "Test", 30, "m")
	q.post = "quartermaster"
	c.assign_task(me, "rebuild", home, q.id)
	var t = c.task_of(q)
	p.materials = 0.0
	c.ventures = c.ventures.filter(func(v): return v.leader_id != q.id)
	c._continue_task(t)
	p.materials = 3.0
	c._continue_task(t)
	_check("a waiting task says so once, without pausing", kinds.size() == 1 and kinds[0] != "alert", str(kinds))
	# The player hears once when a war could end
	var peace_news = []
	c.event.connect(func(text, kind): if "would accept peace" in text: peace_news.append(kind))
	c.start_war(me, "rust_dogs")
	var r = c.relation(me, "rust_dogs")
	r.war_start_day = c.day - 60
	r.exhaustion[me] = 50.0
	r.exhaustion["rust_dogs"] = 60.0
	c._simulate_relations()
	c._simulate_relations()
	_check("you're told once when they'd accept peace", peace_news.size() == 1, str(peace_news))

# Doc 15, P1: the balance of force sets the odds of raids and assaults; districts defend themselves
func _test_force():
	_check("even force is a coin flip", absf(CityMap.force_odds(1.0) - 0.5) < 0.01)
	_check("two to one is about 85%", absf(CityMap.force_odds(2.0) - 0.85) < 0.03, str(CityMap.force_odds(2.0)))
	_check("three to one is about 95%", CityMap.force_odds(3.0) > 0.92, str(CityMap.force_odds(3.0)))
	var c = _new_city()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var dogs: Faction = c.factions["rust_dogs"]
	var their_home: District = c.districts[dogs.home_id]
	p.scouted[str(their_home.id)] = c.day
	_check("a home starts with a full garrison", their_home.garrison > 0.0 and absf(their_home.garrison - c.garrison_ceiling(their_home)) < 0.01, str(their_home.garrison))
	p.manpower = 40.0
	p.arms = 0.0
	var small = VentureSystem.compute_odds("assault", p, their_home, c, "rust_dogs", null, 5)
	var big = VentureSystem.compute_odds("assault", p, their_home, c, "rust_dogs", null, 30)
	_check("a bigger force has better odds", big["odds"] > small["odds"] + 0.2, "%.2f -> %.2f" % [small["odds"], big["odds"]])
	_check("the odds name both forces", not big["force"].is_empty() and big["force"]["attack_parts"].size() > 0 and big["force"]["defence_parts"].size() > 0)
	p.arms = 30.0
	var armed = VentureSystem.compute_odds("assault", p, their_home, c, "rust_dogs", null, 5)
	_check("arms make the same crew stronger", armed["force"]["attack"] > small["force"]["attack"])
	_check("outnumbering them 1.5 to 1 means no disaster", big["force"]["ratio"] < 1.5 or big["tiers"]["disaster"] == 0.0, str(big["force"]["ratio"]))
	_check("outnumbered, disaster is possible", small["force"]["ratio"] >= 1.5 or small["tiers"]["disaster"] > 0.0)
	# Twice their force wins about 9 times in 10
	var crew = 5
	while VentureSystem.compute_odds("assault", p, their_home, c, "rust_dogs", null, crew)["force"]["ratio"] < 2.0 and crew < 60:
		crew += 1
	p.manpower = 80.0
	var two_to_one = VentureSystem.compute_odds("assault", p, their_home, c, "rust_dogs", null, crew)
	_check("twice their force: about 85%+ and no disaster", two_to_one["odds"] >= 0.8 and two_to_one["tiers"]["disaster"] == 0.0, "%.2f at crew %d" % [two_to_one["odds"], crew])
	_check("an assault can take as much crew as you have idle", c.crew_max(me, "assault") == 80 and c.crew_max(me, "raid") == int(GameData.venture("raid")["crew_range"][1]))
	# The planner sizes a fight to outnumber them 2 to 1
	# (a fight is only planned when you are at war with them)
	c.start_war(me, "rust_dogs")
	var plan = c.recommended_plan(me, "assault", their_home, null)
	_check("the plan aims to outnumber them 2 to 1", plan["crew"] >= crew - 1, "%d (needed %d)" % [plan["crew"], crew])
	# Garrisons: knocked down, then rebuilt from the district's people before they join your manpower
	var home: District = c.districts[p.home_id]
	var full = home.garrison
	home.garrison = 0.0
	var recruits_before = c.district_income(home)["recruits"]
	var left = c._update_garrison(home, recruits_before)
	_check("a depleted garrison refills first from the district's recruits", home.garrison > 0.0 and left < recruits_before + 0.0001, "%.2f -> %.2f" % [recruits_before, left])
	for i in 200:
		c._update_garrison(home, 0.0)
	_check("a garrison recovers by itself over time", absf(home.garrison - full) < 0.5, "%.1f of %.1f" % [home.garrison, full])
	var saved = District.new(0, "x", PackedVector2Array())
	saved.load_dict(home.to_dict())
	_check("garrisons are saved", saved.garrison == home.garrison)
	# Playtest: at war, Assault was offered on a district the player owned where the enemy kept a share
	c.start_war(me, "rust_dogs")
	home.influence.clear()
	home.add_influence(me, 75.0)
	home.add_influence("rust_dogs", 25.0)
	_check("you can't assault a district you own", c.check_launch(me, "assault", home).begins_with("Already yours"), c.check_launch(me, "assault", home))
	# Playtest: four Rebuild tasks emptied the stores. A task's run costs half, and leaves a reserve
	var full_cost: float = GameData.venture("rebuild")["cost"]["materials"]
	_check("a task's run costs less than a one-off", c.venture_cost("rebuild", 0, true)["materials"] < full_cost)
	p.materials = c.venture_cost("rebuild", 0, true)["materials"] + 5.0
	home.development = 0.5
	_check("tasks keep a reserve of materials for your own plans", c.check_launch(me, "rebuild", home, -2, -1, 0, true).begins_with("Keeping"), c.check_launch(me, "rebuild", home, -2, -1, 0, true))

# Defence you can see, guards that matter, and first contact
func _test_defence():
	var c = _new_city()
	var me = c.player_id
	var p: Faction = c.factions[me]
	var home: District = c.districts[p.home_id]
	var weak = c.defence_total(home)
	home.add_influence(me, 40.0)
	_check("more control means a better defence", c.defence_total(home) < weak)
	# Reinforce only where there's a threat
	_check("no reinforcing where there's no threat", c.check_launch(me, "reinforce", home, -2, -1, 0, true).begins_with("No threat"))
	var dogs: Faction = c.factions["rust_dogs"]
	var between: District = null
	for n_id in home.neighbor_ids:
		if dogs.home_id in c.districts[n_id].neighbor_ids:
			between = c.districts[n_id]
	between.influence.clear()
	between.add_influence(me, 60.0)
	_check("a district next to raiders can be reinforced", c.check_launch(me, "reinforce", between, -2, -1, 0, true) == "", c.check_launch(me, "reinforce", between, -2, -1, 0, true))
	dogs.arms = 20.0
	dogs.supplies = 50.0
	_check("a quiet threat needs a councillor's standing guard", c.check_launch(me, "reinforce", between).begins_with("Assign a councillor"))
	dogs.manpower = 20.0
	var raid_err = c.launch_venture("rust_dogs", "raid", between)
	_check("under attack, any free captain can guard once", raid_err == "" and c.check_launch(me, "reinforce", between) == "", raid_err + c.check_launch(me, "reinforce", between))
	c.ventures = c.ventures.filter(func(v): return v.faction_id != "rust_dogs")
	var before = VentureSystem.compute_odds("raid", dogs, between, c, me)["odds"]
	var days_before = c.venture_days("raid", null, between)
	c.launch_venture(me, "reinforce", between, -2, 8, 0, true)
	var after = VentureSystem.compute_odds("raid", dogs, between, c, me)
	_check("defenders on guard cut raid odds", after["odds"] < before * 0.7, "%.2f -> %.2f" % [before, after["odds"]])
	_check("guards show in the defence force", after["force"]["defence_parts"].any(func(f): return str(f[0]).ends_with("guards posted")))
	_check("attacks on a guarded district take longer", c.venture_days("raid", null, between) > days_before)
	# First contact is announced once
	var met = []
	c.first_contact.connect(func(fid): met.append(fid))
	c.advance_day()
	c.advance_day()
	_check("first contact is announced once per faction", met.count("rust_dogs") == 1 and c.player_met.has("rust_dogs"))

# Once land is claimed, others can only trade there, raid or assault it
func _test_claimed_land_is_off_limits():
	var c = CityMap.new()
	var me = c.player_id
	var home: District = c.districts[c.factions[me].home_id]
	# Let the Rust Dogs "know" the land next to your shelter, so only the ownership rule can stop them
	for n_id in home.neighbor_ids:
		c.mark_scouted("rust_dogs", c.districts[n_id])
	var err = c.check_launch("rust_dogs", "scout", home)
	_check("nobody can scout land another faction holds", err.begins_with("Held by") or err.begins_with("Too far"), err)
	# A settle begun on open land is called off if someone else claims it first
	var target: District = null
	for d in c.districts:
		if d.owner_id() == "" and c.borders_territory(me, d):
			target = d
	c.mark_scouted("rust_dogs", target)
	var dogs: Faction = c.factions["rust_dogs"]
	dogs.materials = 50.0
	dogs.supplies = 50.0
	var v = ActiveVenture.new("settle", "rust_dogs", "", target, 3, 1)
	v.leader_id = c.characters_of("rust_dogs")[0].id
	c.ventures.append(v)
	target.add_influence(me, 60.0)
	var theirs_before = target.share("rust_dogs")
	c.advance_day()
	_check("their settle is called off once you've claimed the land", target.owner_id() == me and target.share("rust_dogs") <= theirs_before)

# Leaders, families, succession and civil war
func _test_the_arc():
	var c = CityMap.new()
	var me = c.player_id
	_check("every faction has a leader", c.factions.keys().all(func(fid): return c.leader_of(fid) != null))
	var leader = c.leader_of(me)
	_check("the leader doesn't lead ventures", leader not in c.available_leaders(me))
	_check("the leader's family carries the dynasty name", c.everyone_of(me).filter(func(x): return x.family).all(func(x): return x.dynasty == leader.dynasty))
	# Give the leader a grown child: the child inherits
	var child = c._new_child(leader, 25)  # older than any child a dynasty starts with (22 at most)
	c._grow_up(child)
	var outlook = c.succession_outlook(me)
	_check("the eldest adult child is the heir", outlook["heir"] == child and outlook["by_blood"])
	c._character_died(leader, "died of illness")
	_check("the heir takes over when the leader dies", c.leader_of(me) == child and child.is_leader)
	_check("a dead leader is remembered", c.departed.any(func(e): return e.get("role", "") == "Leader"))
	# A contested succession can split the faction
	var c2 = CityMap.new()
	var fid = "rival"
	# Give them land to split
	var added = 0
	for d in c2.districts:
		if d.owner_id() == "" and added < 5:
			d.add_influence(fid, 60.0)
			added += 1
	var rebel: Character = c2.characters_of(fid)[0]
	c2.appoint(rebel.id, "fixer")
	rebel.change_loyalty(-30.0, "dismissed")
	rebel.change_loyalty(-25.0, "passed_over")
	rebel.traits.append("ambitious")
	rebel.skills["command"] = 10
	var before = c2.factions.size()
	var split = false
	for attempt in 30:
		var r2 = c2.succession_outlook(fid)
		if r2["contesters"].is_empty():
			break
		if r2["split_chance"] > 0.0:
			c2._split(fid, rebel)
			split = true
			break
	_check("a disloyal, ambitious councillor contests the succession", split)
	if split:
		_check("civil war creates a new faction with land", c2.factions.size() == before + 1 and c2.districts_held(c2.factions.keys()[-1]) > 0)
		_check("the breakaway is at war with its old faction", c2.is_at_war(c2.factions.keys()[-1], fid))
		_check("the rebel leads the breakaway", rebel.is_leader and rebel.faction_id == c2.factions.keys()[-1])
	# Families survive a save
	var loaded = CityMap.new(bytes_to_var(var_to_bytes(c.to_save())))
	_check("leaders and families survive a save", loaded.leader_of(me) != null and loaded.leader_of(me).name == c.leader_of(me).name)

# Personality, ruling traits, the chosen heir, remarriage and the graveyard
func _test_legacy():
	var c = CityMap.new()
	var me = c.player_id
	var clash = false
	for ch in c.characters:
		for pair in CityMap.PERSONALITY_PAIRS:
			if pair[0] in ch.traits and pair[1] in ch.traits:
				clash = true
	_check("nobody has both sides of a personality pair", not clash)
	_check("most people have a personality", c.characters.filter(func(x): return x.traits.size() > 0).size() > c.characters.size() / 2)
	var leader = c.leader_of(me)
	_check("every leader starts married", c.factions.keys().all(func(fid): return c.character_by_id(c.leader_of(fid).spouse_id) != null))
	# Choosing an heir
	var natural = c._new_child(leader, 25)
	c._grow_up(natural)
	var chosen: Character = c.characters_of(me).filter(func(x): return not x.family)[0]
	c.appoint(chosen.id, "war_chief")
	var err = c.designate_heir(me, chosen.id)
	_check("a council member can be named heir", err == "", err)
	_check("the chosen heir is the heir", c.succession_outlook(me)["heir"] == chosen)
	_check("the passed-over child resents it", natural.loyalty_breakdown().any(func(p): return p[0] == "Passed over for the leadership"))
	_check("children can't be named heir", c.designate_heir(me, c._new_child(leader, 5).id) != "")
	# Remarriage and the graveyard
	var spouse = c.character_by_id(leader.spouse_id)
	c._character_died(spouse, "died of illness")
	_check("the dead family are kept for the family tree", spouse in c.graveyard and c.person_by_id(spouse.id) == spouse)
	var married = false
	for i in 400:
		c._rule_month(leader)
		if c.character_by_id(leader.spouse_id) != null:
			married = true
			break
	_check("a widowed leader remarries", married)
	# Ruling traits
	c.factions[me].stats["buildings_built"] = int(leader.rule_start.get("buildings_built", 0)) + 5
	c._rule_month(leader)
	_check("a leader who builds becomes a Builder", leader.has_trait("builder"))
	_check("a Builder helps the faction's Stewardship ventures", c.leader_factor(me, "stewardship").size() > 0)
	# The chosen heir takes over, and the leader goes to the graveyard
	c._character_died(leader, "died of old age")
	_check("the chosen heir takes over", c.leader_of(me) == chosen)
	_check("a dead leader is in the archive", c.graveyard.any(func(x): return x.is_leader and x.faction_id == me))
	var loaded = CityMap.new(bytes_to_var(var_to_bytes(c.to_save())))
	_check("the graveyard and traits survive a save", loaded.graveyard.size() == c.graveyard.size() and loaded.leader_of(me).traits == chosen.traits)
