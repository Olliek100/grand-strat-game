extends SceneTree

# Headless balance check: plays whole games with the AI running every faction (the player's too)
# and reports the numbers the spine's "done when" targets are written in.
#   godot --headless --path game --script res://tools/balance_sim.gd -- [runs] [years] [--answer] [--idle] [--seed N] [--old-asks]
# Defaults: 3 runs of 4 years. Prints one table per run and a summary line, then a "stops" report:
# what would have stopped the player's clock (alerts, news, choice events, proposals, tasks), by cause.
#   --answer  the harness accepts every proposal at once (otherwise they lapse, as when ignored)
#   --idle    the player's faction has no AI: events and proposals are auto-answered (first valid option)
#   --old-asks  play with the rules of v1.43: no ask cooldowns, no claim notice floor (to compare against doc 18's changes)
#   --seed N  game r (0-based) is seeded N + r, so the same seed gives the same report; default: a random seed, printed
# Counting only observes: it reads no random numbers and changes no balance.

var city: CityMap
var counts = {}
var stops: StopLog
var other_alerts = {}

const WATCH = {
	"successions": "takes over",
	"civil_wars": "broke away",
	"wars": "declared war on",
	"raids": "launched Raid",
	"deserted": "deserted",
	"first_contact": "First contact",
	"threats": "launched Threaten",
	"tribute_paid": "tribute (",
	"demands_refused": "refused to pay",
	"reforms": "are no longer a",
	"purges": "PURGE",
	"bribes": "to buy off rival",
	"ambitions": "achieved ",
	"wounds": "was wounded",
	"claims": "justifying a claim",
	"decisions": "Decision: ",
	"gave_in": "gave in to the",
	"goal_won": "have won (",
	"goal_failed": "held out against",
	"backed": "will back the",
	"sent_early": "early",
	"houses_founded": "Their ruling family is now House",
	"cadet_houses": "founds House",
	"house_revolts": "broke away from the",
	"house_calls": "answers the call",
	"bound_families": "the two families are bound",
	"peace_between_ais": "have made peace",
	"peace_with_you": "Peace with the",
}

# War tempo (doc 18 groundwork): who takes land, how long it's held, and where the grievance comes from.
# CityMap reports grievance changes, takeovers and revolts; the daily scan below sees every change of owner
class TempoLog:
	var city: CityMap
	var added := {}
	var removed := {}
	var sources_today := {}
	var revolts_today := {}
	var revolts := 0
	var occupations := 0
	var liberations := 0
	var war_ends := {}
	var war_end_days := {}
	var owners := {}
	var flips := {"force": 0, "revolt": 0, "other": 0}
	var to_nobody := 0
	var taken := {}
	var lost := {}
	var held_days: Array = []
	var taken_total := 0
	var lost_in_year := 0
	var lost_by_revolt := 0
	var recaptured := 0
	var checks: Array = []
	var at_taking: Array = []
	var after := {30: [], 90: [], 180: []}
	var owned_samples := 0
	var owned_sum := 0.0
	var over65 := 0
	var over80 := 0
	var land_samples := 0
	var day_of_year_days := 0

	func grievance(source: String, amount: float):
		if amount > 0.0:
			added[source] = added.get(source, 0.0) + amount
		else:
			removed[source] = removed.get(source, 0.0) - amount

	func flip(district_id: int, actor_id: String):
		sources_today[district_id] = actor_id

	func revolt(district_id: int):
		revolts += 1
		revolts_today[district_id] = true

	func occupied(_district_id: int, _by_id: String):
		occupations += 1

	func liberated(_district_id: int, _by_id: String):
		liberations += 1

	func war_end(how: String, days: int):
		war_ends[how] = war_ends.get(how, 0) + 1
		war_end_days[how] = war_end_days.get(how, 0) + days

	func start():
		for d in city.districts:
			owners[d.id] = d.owner_id()

	# Called once a day after the simulation has run
	func scan():
		var day = city.day
		for d in city.districts:
			var now = d.owner_id()
			var before = owners[d.id]
			if now != before:
				var cause = "other"
				if revolts_today.has(d.id):
					cause = "revolt"
				elif sources_today.get(d.id, "") != "":
					cause = "force"
				flips[cause] += 1
				if now == "":
					to_nobody += 1
				if taken.has(d.id) and taken[d.id]["by"] == before:
					held_days.append(day - taken[d.id]["day"])
					if day - taken[d.id]["day"] <= 360:
						lost_in_year += 1
						if cause == "revolt" or now == "":
							lost_by_revolt += 1
					taken.erase(d.id)
				if lost.has(d.id) and lost[d.id]["owner"] == now and day - lost[d.id]["day"] <= 360:
					recaptured += 1
				if before != "":
					lost[d.id] = {"owner": before, "day": day}
				if cause == "force" and now != "":
					taken[d.id] = {"by": now, "day": day}
					taken_total += 1
					at_taking.append(d.grievance)
					for h in after:
						checks.append([day + h, d.id, now, h])
				owners[d.id] = now
		sources_today = {}
		revolts_today = {}
		for c in checks.duplicate():
			if day >= c[0]:
				checks.erase(c)
				if city.districts[c[1]].owner_id() == c[2]:
					after[c[3]].append(city.districts[c[1]].grievance)
		if day % 30 == 0:
			for d in city.districts:
				if d.owner_id() != "":
					land_samples += 1
					owned_sum += d.grievance
					over65 += 1 if d.grievance > 65.0 else 0
					over80 += 1 if d.grievance > 80.0 else 0

# Plain counters keyed "category/cause"; CityMap calls note() where a stop originates (no strings stored per event)
class StopLog:
	const REPEAT_DAYS = 10
	const OUTCOMES = ["proposal_answered", "proposal_expired"]
	var city: CityMap
	var counts := {}
	var year_counts: Array = []
	var year_days: Array = []
	var repeats := 0
	var total := 0
	var last_seen := {}
	var last_stop_day := -1
	var tempo: TempoLog
	var merged := 0
	var alerts_today := {}
	var alerts_day := -1
	var digits := RegEx.create_from_string("\\d+")

	func _init(years: int):
		for y in years:
			year_counts.append({})
			year_days.append(0)

	func grievance(_district_id: int, source: String, amount: float):
		tempo.grievance(source, amount)

	func flip(district_id: int, before: String, _after: String, actor_id: String):
		# Settling unowned land is not conquest
		tempo.flip(district_id, actor_id if before != "" else "")

	func day_end():
		pass

	func occupied(district_id: int, by_id: String):
		tempo.occupied(district_id, by_id)

	func liberated(district_id: int, by_id: String):
		tempo.liberated(district_id, by_id)

	func war_end(how: String, days: int):
		tempo.war_end(how, days)

	func revolt(district_id: int):
		tempo.revolt(district_id)

	func note(category: String, cause: String):
		if category == "task_waiting":
			cause = digits.sub(cause, "#", true).substr(0, 40)
		var key = category + "/" + cause
		var year = clampi((city.day - 1) / 360, 0, year_counts.size() - 1)
		if category == "alert":
			if city.day != alerts_day:
				alerts_today = {}
				alerts_day = city.day
			alerts_today[cause] = alerts_today.get(cause, 0) + 1
		# An alert and the pop-up for the same news are one pause: keep the pop-up
		if category == "major" and alerts_day == city.day and alerts_today.get(cause, 0) > 0:
			alerts_today[cause] -= 1
			counts["alert/" + cause] -= 1
			year_counts[year]["alert/" + cause] -= 1
			total -= 1
			merged += 1
		counts[key] = counts.get(key, 0) + 1
		if category in OUTCOMES:
			return
		total += 1
		year_counts[year][key] = year_counts[year].get(key, 0) + 1
		if city.day != last_stop_day:
			last_stop_day = city.day
			year_days[year] += 1
		if last_seen.has(key) and city.day - last_seen[key] <= REPEAT_DAYS:
			repeats += 1
		last_seen[key] = city.day

# First matching phrase wins. Alerts are tagged by their wording; what no phrase matches is other_alert
# Counted as proposals where they are posted
const PROPOSAL_ALERTS = ["proposal_posted", "tribute_offered", "tribute_demanded"]

const ALERT_CAUSES = [
	["demand tribute", "tribute_demanded"], ["offer tribute", "tribute_offered"], ["Answer in Diplomacy", "proposal_posted"],
	["You declared war", "own_war_declared"], ["WAR!", "war_on_you"], ["offer peace", "peace_offered"], ["would accept peace", "peace_possible"],
	["Peace with", "own_peace_made"], ["justifying a claim on you", "claim_on_you"], ["You're justifying", "own_claim_started"],
	["to press a claim", "treaty_broken"], ["turned against your claim", "own_claim_turned"], ["side now outweighs yours", "claim_early_possible"], ["ultimatum", "ultimatum"], ["lapses in", "treaty_lapsing"], ["has lapsed", "treaty_lapsed"],
	["couldn't absorb you", "made_tributary"], ["have absorbed", "absorbed"], ["last district", "last_district"],
	["seat is empty", "seat_empty"], ["moves from", "seat_moved"], ["is restless", "restless"], ["deserted", "deserted"],
	["buy off rival", "bribe_rivals"], ["PURGE", "purge"], ["CIVIL WAR", "civil_war"], ["Civil war in", "civil_war"], ["broke away", "house_revolt"],
	["You now control", "district_gained"], ["have taken", "district_taken"], ["lost control", "district_lost"],
	["REVOLT", "revolt"], ["Unrest rising", "unrest"], ["Out of materials", "no_materials"], ["Food has run out", "starving"],
	["Out of wealth", "broke"], ["First contact", "first_contact"], ["joined the war", "ally_joined"], ["has died", "death"], ["is dead", "death"],
	["is now", "reform_or_trait"], ["launched", "hostile_venture_on_you"], ["ended the trade", "trade_ended"], [", leader of", "leader_news"], ["will back the", "backing_claim"], ["war", "war_news"],
]

func _alert_cause(text: String) -> String:
	for pair in ALERT_CAUSES:
		if text.contains(pair[0]):
			return pair[1]
	# Keep the leftovers readable: their first six words, digits gone
	var words = text.split(" ")
	var head = " ".join(words.slice(0, 6))
	other_alerts[head] = other_alerts.get(head, 0) + 1
	return "other_alert"

func _major_cause(title: String, text: String) -> String:
	for pair in [["dead", "death"], ["demand tribute", ""], ["Ultimatum", ""], ["First contact", "first_contact"],
			["Civil war", "civil_war"], ["breaks away", "house_revolt"], ["Purge", "purge"], ["War", "war_on_you"], ["has achieved", "ambition"]]:
		if title.contains(pair[0]) or text.contains(pair[0]):
			return pair[1]
	return "other_major"

# Auto-answer for the stops report: the first option that can be taken, and "accept" for proposals
func _answer_player():
	while not city.pending_events.is_empty():
		var entry = city.pending_events[0]
		var options: Array = GameData.events()[entry["event"]]["options"]
		var pick = 0
		for i in options.size():
			if city.event_option_blocked(city.player_id, entry, options[i]) == "":
				pick = i
				break
		city.answer_event(pick)
	while not city.proposals.is_empty():
		city.answer_proposal(0, true)

func _print_tempo(logs: Array, runs: int, years: int):
	var per_year = float(runs * years)
	var t = {"force": 0, "revolt": 0, "other": 0}
	var sums = {"nobody": 0, "taken": 0, "lost": 0, "revolt_loss": 0, "recaptured": 0, "revolts": 0, "samples": 0, "owned": 0.0, "o65": 0, "o80": 0}
	var held: Array = []
	var at_taking: Array = []
	var after = {30: [], 90: [], 180: []}
	var added := {}
	var removed := {}
	for s in logs:
		var g: TempoLog = s.tempo
		for k in t:
			t[k] += g.flips[k]
		sums["nobody"] += g.to_nobody
		sums["taken"] += g.taken_total
		sums["lost"] += g.lost_in_year
		sums["revolt_loss"] += g.lost_by_revolt
		sums["recaptured"] += g.recaptured
		sums["revolts"] += g.revolts
		sums["samples"] += g.land_samples
		sums["owned"] += g.owned_sum
		sums["o65"] += g.over65
		sums["o80"] += g.over80
		held.append_array(g.held_days)
		at_taking.append_array(g.at_taking)
		for h in after:
			after[h].append_array(g.after[h])
		for k in g.added:
			added[k] = added.get(k, 0.0) + g.added[k]
		for k in g.removed:
			removed[k] = removed.get(k, 0.0) + g.removed[k]
	held.sort()
	var changes = t["force"] + t["revolt"] + t["other"]
	print("TEMPO land changing hands: %.1f a game year (taken by force %.1f, revolt %.1f, other %.1f), %.1f of them to nobody" % [
		changes / per_year, t["force"] / per_year, t["revolt"] / per_year, t["other"] / per_year, sums["nobody"] / per_year])
	print("TEMPO taken by force %.1f a game year: lost again within a year %d%% (by revolt or to nobody %d%%), won back by the old owner within a year %d%% of all losses; median hold %s days (%d lost, rest still held at the end)" % [
		sums["taken"] / per_year, roundi(100.0 * sums["lost"] / maxi(sums["taken"], 1)), roundi(100.0 * sums["revolt_loss"] / maxi(sums["taken"], 1)),
		roundi(100.0 * sums["recaptured"] / maxi(changes, 1)), str(held[held.size() / 2]) if held.size() > 0 else "-", held.size()])
	var avg = func(a: Array): return "-" if a.is_empty() else "%d" % roundi(a.reduce(func(x, y): return x + y, 0.0) / a.size())
	print("TEMPO grievance of land taken by force: at the taking %s, after 30 days %s, 90 days %s, 180 days %s (still held; n %d/%d/%d/%d) | all owned land %.0f, %d%% over 65, %d%% over 80" % [
		avg.call(at_taking), avg.call(after[30]), avg.call(after[90]), avg.call(after[180]), at_taking.size(), after[30].size(), after[90].size(), after[180].size(),
		sums["owned"] / maxi(sums["samples"], 1), roundi(100.0 * sums["o65"] / maxi(sums["samples"], 1)), roundi(100.0 * sums["o80"] / maxi(sums["samples"], 1))])
	print("TEMPO revolts %.1f a game year" % (sums["revolts"] / per_year))
	var occ = 0
	var lib = 0
	var ends = {}
	var end_days = {}
	for s in logs:
		occ += s.tempo.occupations
		lib += s.tempo.liberations
		for k in s.tempo.war_ends:
			ends[k] = ends.get(k, 0) + s.tempo.war_ends[k]
			end_days[k] = end_days.get(k, 0) + s.tempo.war_end_days[k]
	var end_parts = []
	for k in ends:
		end_parts.append("%s %.1f a game (avg %d days)" % [k, float(ends[k]) / runs, end_days[k] / maxi(ends[k], 1)])
	print("TEMPO occupations %.1f a game year, retaken by the owner %.1f | wars ended: %s" % [occ / per_year, lib / per_year, ", ".join(end_parts)])
	for pair in [["added", added], ["removed", removed]]:
		var list = []
		for k in pair[1]:
			list.append([k, pair[1][k]])
		list.sort_custom(func(a, b): return a[1] > b[1])
		print("TEMPO grievance %s a game year, all districts, by source: %s" % [pair[0], ", ".join(list.slice(0, 10).map(func(p): return "%s %.0f" % [p[0], p[1] / per_year]))])

# What would have stopped the clock, per game year, by category and cause (averaged over the runs)
func _print_stops(logs: Array, runs: int, years: int, mode: String):
	var per_year = float(runs * years)
	var totals := {}
	var by_cat := {}
	var total = 0
	var repeats = 0
	var days = 0
	for s in logs:
		total += s.total
		repeats += s.repeats
		for d in s.year_days:
			days += d
		for key in s.counts:
			totals[key] = totals.get(key, 0) + s.counts[key]
	for key in totals:
		var cat = key.get_slice("/", 0)
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append([key.get_slice("/", 1), totals[key]])
	var self_caused = 0
	for cat in by_cat:
		for pair in by_cat[cat]:
			if pair[0].begins_with("own_") and cat not in StopLog.OUTCOMES:
				self_caused += pair[1]
	print("STOPS mode: %s | %d runs x %d years" % [mode, runs, years])
	print("STOPS total %.1f a game year = %.1f per game minute at speed 2 (a year is 3 minutes) | on %.1f different days a year | %.1f a year came from your own act (own_*) | repeats within %d days: %d%%" % [
		total / per_year, total / per_year / 3.0, days / per_year, self_caused / per_year, StopLog.REPEAT_DAYS, roundi(100.0 * repeats / maxi(total, 1))])
	for cat in ["alert", "major", "choice", "proposal", "proposal_answered", "proposal_expired", "task", "task_waiting"]:
		if not by_cat.has(cat):
			continue
		var list: Array = by_cat[cat]
		list.sort_custom(func(a, b): return a[1] > b[1])
		var sum = 0
		var parts = []
		for pair in list:
			if pair[1] <= 0:
				continue
			sum += pair[1]
			parts.append("%s %.1f" % [pair[0], pair[1] / per_year])
		print("STOPS %-17s %5.1f a year | %s" % [cat, sum / per_year, ", ".join(parts)])
	var other_head = []
	for head in other_alerts:
		other_head.append([head, other_alerts[head]])
	other_head.sort_custom(func(a, b): return a[1] > b[1])
	if not other_head.is_empty():
		print("STOPS other_alert is: %s" % ", ".join(other_head.slice(0, 8).map(func(p): return "'%s' x%d" % [p[0], p[1]])))
	var years_list = []
	for r in logs.size():
		for y in logs[r].year_counts.size():
			var sum = 0
			var causes = []
			for key in logs[r].year_counts[y]:
				sum += logs[r].year_counts[y][key]
				causes.append([key, logs[r].year_counts[y][key]])
			causes.sort_custom(func(a, b): return a[1] > b[1])
			years_list.append([sum, "run %d year %d: %d stops (%s)" % [r, y + 1, sum, ", ".join(causes.slice(0, 3).map(func(p): return "%s %d" % [p[0], p[1]]))]])
	years_list.sort_custom(func(a, b): return a[0] > b[0])
	print("STOPS busiest years: %s" % " | ".join(years_list.slice(0, 3).map(func(p): return p[1])))

func _on_event(text: String, kind: String):
	for key in WATCH:
		if text.contains(WATCH[key]):
			counts[key] = counts.get(key, 0) + 1
	if kind == "alert":
		var cause = _alert_cause(text)
		if cause not in PROPOSAL_ALERTS:
			stops.note("alert", cause)

func _on_major(title: String, text: String, _faction_id: String):
	var cause = _major_cause(title, text)
	if cause != "":
		stops.note("major", cause)

func _init():
	var args = OS.get_cmdline_user_args()
	var idle = "--idle" in args
	if "--old-asks" in args:
		GameData.rules()["ask_cooldown_days"] = {}
		GameData.rules()["min_claim_notice_days"] = 0
		print("RULES old asks: no cooldowns, no notice floor")
	var seed_base = int(Time.get_ticks_usec() % 1000000)
	var seed_at = args.find("--seed")
	if seed_at >= 0 and seed_at + 1 < args.size():
		seed_base = int(args[seed_at + 1])
		args = Array(args)
		args.remove_at(seed_at + 1)
	var answer = idle or "--answer" in args
	args = Array(args).filter(func(a): return not a.begins_with("--"))
	var runs = int(args[0]) if args.size() > 0 else 3
	var years = int(args[1]) if args.size() > 1 else 4
	var all_stops: Array = []
	var war_totals = {"started": 0, "ended": 0, "days": 0, "ongoing": 0, "peace": 0}
	var ties = {"trade": 0, "pact": 0, "alliance": 0}
	var growth = {"infamy_sum": 0.0, "infamy_max": 0.0, "factions": 0, "over_reach": 0, "unsettled": 0, "districts": 0}
	print("SEED %d (game r uses %d + r)" % [seed_base, seed_base])
	var summary = {"broke_days": 0, "starve_days": 0, "civil_wars": 0, "largest": 0, "first_expand": []}
	for run in runs:
		counts = {}
		city = CityMap.new({}, seed_base + run)
		var war_start := {}
		var couples := {}
		if not idle:
			city.factions[city.player_id].ai = FactionAI.new(city.player_id)
		stops = StopLog.new(years)
		stops.city = city
		stops.tempo = TempoLog.new()
		stops.tempo.city = city
		stops.tempo.start()
		city.sim_sink = stops
		all_stops.append(stops)
		city.event.connect(_on_event)
		city.major_event.connect(_on_major)
		var broke = {}
		var starve = {}
		var first_expand = {}
		var t0 = Time.get_ticks_msec()
		for i in years * 360:
			city.advance_day()
			if answer:
				_answer_player()
			stops.tempo.scan()
			# Every marriage, whoever's and however made: a new couple is a new pair of spouse links
			for c in city.characters:
				if c.spouse_id > c.id:
					couples[c.id * 100000 + c.spouse_id] = true
			for key in city.relations:
				var r: Relation = city.relations[key]
				if r.at_war and not war_start.has(key):
					war_start[key] = city.day
					war_totals["started"] += 1
				elif not r.at_war and war_start.has(key):
					war_totals["ended"] += 1
					war_totals["days"] += city.day - war_start[key]
					war_start.erase(key)
			for fid in city.factions:
				var f: Faction = city.factions[fid]
				if f.broke:
					broke[fid] = broke.get(fid, 0) + 1
				if f.starving:
					starve[fid] = starve.get(fid, 0) + 1
				if not first_expand.has(fid) and city.districts_held(fid) > 1:
					first_expand[fid] = i
			if (i + 1) % 360 == 0:
				var row = []
				for fid in city.factions:
					var f: Faction = city.factions[fid]
					row.append("%s d%d f%d m%d w%d mp%d" % [fid, city.districts_held(fid), f.supplies, f.materials, f.wealth, f.manpower])
				print("run %d year %d unclaimed %d | %s" % [run, (i + 1) / 360, city.districts.filter(func(d): return d.owner_id() == "").size(), "  ".join(row)])
		counts["marriages"] = couples.size()
		for fid in city.factions:
			growth["factions"] += 1
			growth["infamy_sum"] += city.factions[fid].infamy
			growth["infamy_max"] = maxf(growth["infamy_max"], city.factions[fid].infamy)
			growth["over_reach"] += 1 if city.districts_held(fid) > city.reach(fid) else 0
		for d in city.districts:
			if d.owner_id() != "":
				growth["districts"] += 1
				growth["unsettled"] += 1 if d.absorb < 0.9 else 0
		for r in city.relations.values():
			ties["trade"] += 1 if r.trade else 0
			ties["pact"] += 1 if r.pact else 0
			ties["alliance"] += 1 if r.alliance else 0
		war_totals["ongoing"] += war_start.size()
		war_totals["peace"] += counts.get("peace_between_ais", 0) + counts.get("peace_with_you", 0)
		var ms_per_day = float(Time.get_ticks_msec() - t0) / (years * 360)
		var largest = 0
		for fid in city.factions:
			largest = maxi(largest, city.districts_held(fid))
		print("run %d events %s | factions left %d, largest %d | broke %s | starving %s | first expansion %s | %.1f ms/day" % [
			run, counts, city.factions.size(), largest, broke, starve, first_expand, ms_per_day])
		for v in broke.values():
			summary["broke_days"] += v
		for v in starve.values():
			summary["starve_days"] += v
		summary["civil_wars"] += counts.get("civil_wars", 0)
		summary["largest"] = maxi(summary["largest"], largest)
		summary["first_expand"].append_array(first_expand.values())
	print("GROWTH at the end of a game: infamy avg %.1f, worst %.0f | %.1f factions over their reach | %d%% of held land still settling in" % [growth["infamy_sum"] / maxi(growth["factions"], 1), growth["infamy_max"], float(growth["over_reach"]) / runs, roundi(100.0 * growth["unsettled"] / maxi(growth["districts"], 1))])
	print("TIES standing at the end of a game: trade %.1f, pacts %.1f, alliances %.1f" % [float(ties["trade"]) / runs, float(ties["pact"]) / runs, float(ties["alliance"]) / runs])
	print("WARS started %d, ended %d (by peace %d), still on at the end %d, average length of the ended %.0f days" % [
		war_totals["started"], war_totals["ended"], war_totals["peace"], war_totals["ongoing"], float(war_totals["days"]) / maxi(war_totals["ended"], 1)])
	var fe: Array = summary["first_expand"]
	fe.sort()
	print("SUMMARY runs %d years %d | civil wars %.1f/game | largest faction %d | broke days %d | starving days %d | first expansion days %s-%s" % [
		runs, years, float(summary["civil_wars"]) / runs, summary["largest"], summary["broke_days"], summary["starve_days"],
		fe[0] if fe.size() > 0 else "-", fe[-1] if fe.size() > 0 else "-"])
	_print_tempo(all_stops, runs, years)
	_print_stops(all_stops, runs, years, "idle (no AI), auto-answer" if idle else ("AI plays the player, proposals accepted" if answer else "AI plays the player, proposals lapse"))
	quit()
