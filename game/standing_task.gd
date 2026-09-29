class_name StandingTask

# A councillor's standing task (doc 13): they work one district with one routine venture, run after run,
# until the district's own state says the job is done. Each run is an ordinary venture marked with this task.

var venture_id: String
var faction_id: String
var character_id: int
var district_id: int
var crew: int
var started_day: int
# The councillor takes no new work before this day (two runs), even if the task is stopped early
var committed_until: int
var runs: int = 0
# What the runs have brought in since the last digest, e.g. {"materials": 34}; and how many runs that was
var gains: Dictionary = {}
var digest_runs: int = 0
# Why the task is waiting instead of running ("" while it runs): "wounded", or what it can't pay
var paused: String = ""
# The player asked it to stop: the run under way finishes, then the task ends
var stopping: bool = false

func _init(p_venture_id: String, p_faction_id: String, p_character_id: int, p_district_id: int, p_crew: int, p_day: int, p_committed_until: int):
	venture_id = p_venture_id
	faction_id = p_faction_id
	character_id = p_character_id
	district_id = p_district_id
	crew = p_crew
	started_day = p_day
	committed_until = p_committed_until

func to_dict() -> Dictionary:
	return {"venture": venture_id, "faction": faction_id, "character": character_id, "district": district_id, "crew": crew,
		"started_day": started_day, "committed_until": committed_until, "runs": runs, "gains": gains.duplicate(),
		"digest_runs": digest_runs, "paused": paused, "stopping": stopping}

static func from_dict(data: Dictionary) -> StandingTask:
	var t = StandingTask.new(data["venture"], data["faction"], int(data["character"]), int(data["district"]), int(data["crew"]),
		int(data["started_day"]), int(data["committed_until"]))
	t.runs = int(data["runs"])
	t.gains = data["gains"]
	t.digest_runs = int(data["digest_runs"])
	t.paused = data["paused"]
	t.stopping = data["stopping"]
	return t
