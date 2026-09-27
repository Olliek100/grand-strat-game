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
	_test_treaties()
	_test_memories_and_ambitions()
	_test_leaders_and_tiers()
	_test_no_stacking()
	_test_buildings()
	_test_council()
	_test_opening()
	_test_no_dead_ends()
	_test_captains_kept()
	_test_expansion()
	_test_pressure()
	_test_minor_patrons()
	_test_defence()
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

# Opinion memories fade; ambitions complete and pay renown; treaties can be renewed near the end
func _test_memories_and_ambitions():
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
	_check("an ambition completes and pays renown", "handshake" in p.ambitions_done and p.renown > renown_before)
	p.renown = 100.0
	_check("renown raises the crew limit", c2.crew_cap(me) > cap_before)
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
	_check("a vassal can't declare war", c2.check_declare_war("guild", "rival") == "Vassals can't declare war")
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
	var rebel = c.characters_of(me).filter(func(x): return x.post == "")[0]
	rebel.change_loyalty(-30.0, "dismissed")
	rebel.change_loyalty(-25.0, "passed_over")
	rebel.traits.append("ambitious")
	var gone = false
	for i in 400:
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
	var err = c.check_launch(me, "secure_food", home)
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
	err = c.check_launch(me, "scavenge", home)
	_check("with no materials you can still scavenge at home", err == "", err)
	_check("you can scavenge unclaimed ruins on your border", c.check_launch(me, "scavenge", target) == "" or target.ruin_level < 0.1)
	home.ruin_level = 0.05
	_check("stripped ruins can't be scavenged", c.check_launch(me, "scavenge", home).begins_with("Nothing left"))
	p.wealth = 0.0
	p.materials = 50.0
	err = c.check_launch(me, "gather_weapons", home, -2, -1, 1)
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
	var err = c.check_launch(me, "secure_food", home)
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
	_check("raiders are keen on raids", dogs.ai._temperament("harass", dogs) > c.factions["st_brigids"].ai._temperament("harass", c.factions["st_brigids"]) * 5.0)
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

func _test_minor_patrons():
	var c = CityMap.new()
	var me = c.player_id
	c.factions[me].wealth = 500.0
	c.factions[me].manpower = 30.0
	var ratio = c.faction_strength("st_brigids") / c.faction_strength(me)
	var err = Diplomacy.check_action(c, "vassalage", me, "st_brigids")
	_check("a minor faction up to 70% of your strength can become your vassal", ratio >= 0.7 or not err.begins_with("They're too strong"), "%s (ratio %.2f)" % [err, ratio])

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
	_check("no reinforcing where there's no threat", c.check_launch(me, "reinforce", home).begins_with("No threat"))
	var dogs: Faction = c.factions["rust_dogs"]
	var between: District = null
	for n_id in home.neighbor_ids:
		if dogs.home_id in c.districts[n_id].neighbor_ids:
			between = c.districts[n_id]
	between.influence.clear()
	between.add_influence(me, 60.0)
	_check("a district next to raiders can be reinforced", c.check_launch(me, "reinforce", between) == "", c.check_launch(me, "reinforce", between))
	dogs.arms = 20.0
	dogs.supplies = 50.0
	var before = VentureSystem.compute_odds("raid", dogs, between, c, me)["odds"]
	var days_before = c.venture_days("raid", null, between)
	c.launch_venture(me, "reinforce", between, -2, 8)
	var after = VentureSystem.compute_odds("raid", dogs, between, c, me)
	_check("defenders on guard cut raid odds", after["odds"] < before * 0.7, "%.2f -> %.2f" % [before, after["odds"]])
	_check("defenders show as a named factor", after["factors"].any(func(f): return str(f[0]).ends_with("defenders on guard")))
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
