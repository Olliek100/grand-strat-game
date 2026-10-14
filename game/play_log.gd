extends RefCounted

# Writes what happens to your land while you play, to user://playlog.txt (beside the save), so a bad stretch can be
# reviewed afterwards: why grievance rose, who took what, what stopped the clock. It only observes: no random numbers,
# nothing saved with the game, no effect on play. A new game starts a fresh file; a loaded game adds to it.

const PATH = "user://playlog.txt"
const MONTH_DAYS = 30
# Grievance changes this big or bigger are written the moment they happen; the daily ones are summed per month
const BIG_CHANGE = 0.5
const PREVIOUS = "user://playlog_previous.txt"

var city: CityMap
var file: FileAccess
# district id -> {source: net change this month}
var month := {}

func _init(for_city: CityMap, fresh: bool):
	city = for_city
	# Starting a new game keeps the last session's log as playlog_previous.txt
	if fresh and FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PREVIOUS))
	file = FileAccess.open(PATH, FileAccess.WRITE if fresh else FileAccess.READ_WRITE)
	if file == null:
		return
	if not fresh:
		file.seek_end()
	_line("START" if fresh else "LOADED", "%s, you are the %s" % [city.date_string(), city.faction_name(city.player_id)])
	city.event.connect(_on_event)

func _line(kind: String, text: String):
	if file == null:
		return
	file.store_line("day %d | %s | %s" % [city.day, kind, text])
	file.flush()

func _name(d: District) -> String:
	return "%s (#%d)" % [d.district_name, d.id]

func _on_event(text: String, kind: String):
	if kind == "alert" or kind == "bad":
		_line("NEWS", text)

# --- Hooks from CityMap (see CityMap.sim_sink) ---

func note(category: String, cause: String):
	if not category.ends_with("answered") and not category.ends_with("expired"):
		_line("STOP", "%s / %s" % [category, cause])

func grievance(district_id: int, source: String, amount: float):
	if not month.has(district_id):
		month[district_id] = {}
	month[district_id][source] = month[district_id].get(source, 0.0) + amount
	# One-off changes (ventures, reforms) on your own land are written as they happen
	if absf(amount) >= BIG_CHANGE and not source.begins_with("daily") and city.districts[district_id].owner_id() == city.player_id:
		var d: District = city.districts[district_id]
		_line("GRIEVANCE", "%s %+.1f from %s (now %d)" % [_name(d), amount, source, d.grievance])

func flip(district_id: int, before: String, after: String, actor_id: String):
	var d: District = city.districts[district_id]
	var mine = before == city.player_id or after == city.player_id
	_line("LAND" if mine else "land", "%s: %s -> %s%s | grievance %d, population %d" % [
		_name(d), before if before != "" else "nobody", after if after != "" else "nobody",
		" taken by %s" % actor_id if actor_id != "" else "", d.grievance, d.population])

func revolt(district_id: int):
	var d: District = city.districts[district_id]
	_line("REVOLT" if d.owner_id() == city.player_id else "revolt", "%s (grievance %d)" % [_name(d), d.grievance])

func occupied(district_id: int, by_id: String):
	var d: District = city.districts[district_id]
	_line("OCCUPIED" if d.owner_id() == city.player_id or by_id == city.player_id else "occupied", "%s held by %s, owned by %s" % [_name(d), by_id, d.owner_id()])

func liberated(district_id: int, by_id: String):
	_line("LIBERATED", "%s retaken by %s" % [_name(city.districts[district_id]), by_id])

func war_end(how: String, days: int):
	_line("WAR_END", "%s after %d days" % [how, days])

func day_end():
	if city.day % MONTH_DAYS != 0:
		return
	var wars = city.war_enemies(city.player_id)
	_line("MONTH", "at war with: %s" % (", ".join(wars) if not wars.is_empty() else "nobody"))
	for d in city.districts:
		if d.owner_id() != city.player_id:
			continue
		var parts = []
		var sources: Dictionary = month.get(d.id, {})
		for source in sources:
			if absf(sources[source]) >= 0.05:
				parts.append("%s %+.1f" % [source, sources[source]])
		_line("MONTH", "%s grievance %d, control %d%% | %s" % [_name(d), d.grievance, d.share(city.player_id), ", ".join(parts)])
	month = {}
