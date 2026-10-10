extends SceneTree

# Headless balance check: plays whole games with the AI running every faction (the player's too)
# and reports the numbers the spine's "done when" targets are written in.
#   godot --headless --path game --script res://tools/balance_sim.gd -- [runs] [years] [--answer] [--idle] [--seed N]
# Defaults: 3 runs of 4 years. Prints one table per run and a summary line, then a "stops" report:
# what would have stopped the player's clock (alerts, news, choice events, proposals, tasks), by cause.
#   --answer  the harness accepts every proposal at once (otherwise they lapse, as when ignored)
#   --idle    the player's faction has no AI: events and proposals are auto-answered (first valid option)
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
	var merged := 0
	var alerts_today := {}
	var alerts_day := -1
	var digits := RegEx.create_from_string("\\d+")

	func _init(years: int):
		for y in years:
			year_counts.append({})
			year_days.append(0)

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
	["to press a claim", "treaty_broken"], ["ultimatum", "ultimatum"], ["lapses in", "treaty_lapsing"], ["has lapsed", "treaty_lapsed"],
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
		city.stop_sink = stops
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
	print("WARS started %d, ended %d (by peace %d), still on at the end %d, average length of the ended %.0f days" % [
		war_totals["started"], war_totals["ended"], war_totals["peace"], war_totals["ongoing"], float(war_totals["days"]) / maxi(war_totals["ended"], 1)])
	var fe: Array = summary["first_expand"]
	fe.sort()
	print("SUMMARY runs %d years %d | civil wars %.1f/game | largest faction %d | broke days %d | starving days %d | first expansion days %s-%s" % [
		runs, years, float(summary["civil_wars"]) / runs, summary["largest"], summary["broke_days"], summary["starve_days"],
		fe[0] if fe.size() > 0 else "-", fe[-1] if fe.size() > 0 else "-"])
	_print_stops(all_stops, runs, years, "idle (no AI), auto-answer" if idle else ("AI plays the player, proposals accepted" if answer else "AI plays the player, proposals lapse"))
	quit()
