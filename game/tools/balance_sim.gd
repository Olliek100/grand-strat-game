extends SceneTree

# Headless balance check: plays whole games with the AI running every faction (the player's too)
# and reports the numbers the spine's "done when" targets are written in.
#   godot --headless --path game --script res://tools/balance_sim.gd -- [runs] [years]
# Defaults: 3 runs of 4 years. Prints one table per run and a summary line.

var city: CityMap
var counts = {}

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
}

func _on_event(text: String, _kind: String):
	for key in WATCH:
		if text.contains(WATCH[key]):
			counts[key] = counts.get(key, 0) + 1

func _init():
	var args = OS.get_cmdline_user_args()
	var runs = int(args[0]) if args.size() > 0 else 3
	var years = int(args[1]) if args.size() > 1 else 4
	var summary = {"broke_days": 0, "starve_days": 0, "civil_wars": 0, "largest": 0, "first_expand": []}
	for run in runs:
		counts = {}
		city = CityMap.new()
		city.factions[city.player_id].ai = FactionAI.new(city.player_id)
		city.event.connect(_on_event)
		var broke = {}
		var starve = {}
		var first_expand = {}
		var t0 = Time.get_ticks_msec()
		for i in years * 360:
			city.advance_day()
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
	var fe: Array = summary["first_expand"]
	fe.sort()
	print("SUMMARY runs %d years %d | civil wars %.1f/game | largest faction %d | broke days %d | starving days %d | first expansion days %s-%s" % [
		runs, years, float(summary["civil_wars"]) / runs, summary["largest"], summary["broke_days"], summary["starve_days"],
		fe[0] if fe.size() > 0 else "-", fe[-1] if fe.size() > 0 else "-"])
	quit()
