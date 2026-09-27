class_name Portrait
extends Control

# A character's face, drawn in code from their id so it's always the same person:
# skin, hair, beard, coat and a few scavenged accessories. Wounds and scars show on the face.

const SKIN = [Color("#f1c9a5"), Color("#e0ac85"), Color("#c68a62"), Color("#a86f4c"), Color("#7d4f35"), Color("#5a3826")]
const HAIR = [Color("#1d1a18"), Color("#3b2a1e"), Color("#6b4a2e"), Color("#a67b4f"), Color("#c9b28a"), Color("#8e8e8e"), Color("#7a2f22")]
const COATS = [Color("#4a4f3a"), Color("#5a4632"), Color("#3e4550"), Color("#2e3a4d"), Color("#6b3b2a"), Color("#4d4d4d")]

signal clicked(character: Character)

var character: Character
var faction_color: Color = Color(0.4, 0.4, 0.4)
var wounded: bool = false
# Small marks in the corner: "leader" (gold band), "heir" (gold dot), "dead" (greyed, with a cross)
var badge: String = ""

func setup(c: Character, color: Color, is_wounded: bool = false, p_badge: String = ""):
	character = c
	faction_color = color
	wounded = is_wounded
	badge = p_badge
	if c == null:
		tooltip_text = ""
	else:
		var role = "Leader" if c.is_leader and c.death_day < 0 else (c.fate.capitalize() if c.death_day >= 0 else "")
		tooltip_text = "%s, %d%s\nClick to open" % [c.name, c.age, ("  (%s)" % role) if role != "" else ""]
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if c else Control.CURSOR_ARROW
	queue_redraw()

func _gui_input(event: InputEvent):
	if character == null or not (event is InputEventMouseButton and event.pressed):
		return
	# Every portrait works the same everywhere: left-click opens the person, right-click their options.
	# The game screen answers through the "portrait_host" group, so no portrait can be left unwired.
	if event.button_index == MOUSE_BUTTON_LEFT:
		if clicked.get_connections().is_empty():
			get_tree().call_group("portrait_host", "_show_character", character.id)
		else:
			clicked.emit(character)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		get_tree().call_group("portrait_host", "_open_character_menu", character.id, get_global_mouse_position())
		accept_event()

func _draw():
	var w = size.x
	var h = size.y
	var bg = faction_color.darkened(0.6)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	if character == null:
		draw_string(get_theme_default_font(), Vector2(w * 0.35, h * 0.62), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.4), Color(0.6, 0.6, 0.6))
		return
	# The same person every time: every choice comes from the character's id
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(character.id * 7919 + 17)
	var skin: Color = SKIN[rng.randi() % SKIN.size()]
	var hair: Color = HAIR[rng.randi() % HAIR.size()]
	if character.age > 48 and rng.randf() < 0.6:
		hair = HAIR[5]
	var coat: Color = COATS[rng.randi() % COATS.size()]
	var hair_style = rng.randi() % 6
	var has_beard = rng.randf() < 0.35
	var goggles = rng.randf() < 0.18
	var patch = rng.randf() < 0.07
	var head_w = w * rng.randf_range(0.26, 0.31)
	var head_h = h * rng.randf_range(0.3, 0.34)
	var head = Vector2(w * 0.5, h * 0.44)
	# Who they are, and how old: no beards for women or children; age greys and then whitens the hair
	if character.sex == "f":
		has_beard = false
		hair_style = [1, 2, 2, 5, 4][hair_style % 5]
	var age = character.age
	if age < 16:
		has_beard = false
		goggles = false
		patch = false
		head_w *= 1.12
		head_h *= 1.06
		head.y += h * 0.05
	elif age > 60:
		hair = Color("#dedad2")
		if character.sex == "m" and hair_style != 4 and rng.randf() < 0.45:
			hair_style = 0

	# Long hair falls behind the shoulders
	if hair_style == 2:
		_ellipse(head + Vector2(0, head_h * 0.35), Vector2(head_w * 1.15, head_h * 1.05), hair)
	# Coat and shoulders, with the faction's colour on the collar
	_ellipse(Vector2(w * 0.5, h * 1.02), Vector2(w * 0.48, h * 0.3), coat)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.38, h * 0.74), Vector2(w * 0.5, h * 0.86), Vector2(w * 0.62, h * 0.74), Vector2(w * 0.66, h * 0.8), Vector2(w * 0.5, h * 0.93), Vector2(w * 0.34, h * 0.8)]), faction_color)
	draw_rect(Rect2(head.x - head_w * 0.35, head.y + head_h * 0.6, head_w * 0.7, h * 0.14), skin.darkened(0.12))
	# Head
	_ellipse(head, Vector2(head_w, head_h), skin)
	if has_beard:
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(-head_w * 0.95, head_h * 0.1), head + Vector2(-head_w * 0.6, head_h * 0.85),
			head + Vector2(0, head_h * 1.08), head + Vector2(head_w * 0.6, head_h * 0.85),
			head + Vector2(head_w * 0.95, head_h * 0.1), head + Vector2(head_w * 0.5, head_h * 0.55),
			head + Vector2(0, head_h * 0.62), head + Vector2(-head_w * 0.5, head_h * 0.55)]), hair)
	# Hair on top
	match hair_style:
		1, 2, 5:
			_half_ellipse(head - Vector2(0, head_h * 0.18), Vector2(head_w * 1.04, head_h * 0.95), hair)
			if hair_style == 5:
				_ellipse(head - Vector2(0, head_h * 1.05), Vector2(head_w * 0.35, head_h * 0.28), hair)
		3:
			draw_rect(Rect2(head.x - head_w * 0.18, head.y - head_h * 1.12, head_w * 0.36, head_h * 0.8), hair)
		4:
			# A hood in the coat's colour
			_half_ellipse(head - Vector2(0, head_h * 0.05), Vector2(head_w * 1.25, head_h * 1.2), coat.darkened(0.1))
	# Eyes, brows, mouth
	var eye_y = head.y - head_h * 0.02
	var eye_dx = head_w * 0.4
	for side in [-1, 1]:
		var eye = Vector2(head.x + side * eye_dx, eye_y)
		if patch and side == -1:
			draw_line(head + Vector2(-head_w, -head_h * 0.45), head + Vector2(head_w, head_h * 0.1), Color(0.1, 0.1, 0.1), maxf(1.0, w * 0.02))
			_ellipse(eye, Vector2(head_w * 0.26, head_h * 0.18), Color(0.08, 0.08, 0.08))
		else:
			_ellipse(eye, Vector2(head_w * 0.12, head_h * 0.08), Color(0.12, 0.1, 0.09))
		draw_line(eye + Vector2(-head_w * 0.2, -head_h * 0.2), eye + Vector2(head_w * 0.2, -head_h * 0.22), hair.darkened(0.2), maxf(1.0, w * 0.025))
	var mouth_y = head.y + head_h * (0.72 if has_beard else 0.5)
	draw_line(Vector2(head.x - head_w * 0.3, mouth_y), Vector2(head.x + head_w * 0.3, mouth_y), skin.darkened(0.45), maxf(1.0, w * 0.02))
	if goggles:
		for side in [-1, 1]:
			var g = Vector2(head.x + side * head_w * 0.42, head.y - head_h * 0.62)
			_ellipse(g, Vector2(head_w * 0.3, head_h * 0.2), Color(0.25, 0.22, 0.18))
			_ellipse(g, Vector2(head_w * 0.2, head_h * 0.13), Color(0.45, 0.6, 0.62))
		draw_line(Vector2(head.x - head_w, head.y - head_h * 0.62), Vector2(head.x + head_w, head.y - head_h * 0.62), Color(0.2, 0.18, 0.15), maxf(1.0, w * 0.03))
	# Lines of age: crow's feet from 45, a furrowed brow from 55
	if age >= 45:
		var line_color = skin.darkened(0.3)
		for side in [-1, 1]:
			var corner = Vector2(head.x + side * head_w * 0.62, eye_y)
			draw_line(corner, corner + Vector2(side * head_w * 0.12, -head_h * 0.06), line_color, maxf(1.0, w * 0.012))
			draw_line(corner, corner + Vector2(side * head_w * 0.12, head_h * 0.05), line_color, maxf(1.0, w * 0.012))
		if age >= 55:
			draw_line(Vector2(head.x - head_w * 0.35, head.y - head_h * 0.45), Vector2(head.x + head_w * 0.35, head.y - head_h * 0.45), line_color, maxf(1.0, w * 0.012))
	# Marks of the life they've led
	if character.has_trait("scarred"):
		draw_line(head + Vector2(head_w * 0.15, -head_h * 0.4), head + Vector2(head_w * 0.7, head_h * 0.35), Color(0.75, 0.35, 0.35), maxf(1.0, w * 0.025))
	if wounded:
		draw_rect(Rect2(head.x - head_w, head.y - head_h * 0.55, head_w * 2.0, head_h * 0.22), Color(0.92, 0.9, 0.86))
		_ellipse(head + Vector2(head_w * 0.45, -head_h * 0.44), Vector2(head_w * 0.14, head_h * 0.08), Color(0.7, 0.15, 0.15))
	match badge:
		"leader":
			draw_rect(Rect2(0, 0, w, maxf(3.0, h * 0.06)), Color(0.85, 0.7, 0.3))
		"heir":
			draw_circle(Vector2(w - w * 0.12, h * 0.12), maxf(3.0, w * 0.07), Color(0.85, 0.7, 0.3))
		"dead":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.06, 0.55))
			var cx = w - w * 0.14
			var cy = h * 0.16
			var arm = maxf(3.0, w * 0.08)
			draw_line(Vector2(cx, cy - arm), Vector2(cx, cy + arm * 1.4), Color(0.85, 0.85, 0.85), maxf(1.5, w * 0.03))
			draw_line(Vector2(cx - arm * 0.8, cy), Vector2(cx + arm * 0.8, cy), Color(0.85, 0.85, 0.85), maxf(1.5, w * 0.03))
	draw_rect(Rect2(Vector2.ZERO, size), faction_color.darkened(0.2), false, 1.0)

func _ellipse(center: Vector2, radius: Vector2, color: Color):
	var points = PackedVector2Array()
	for i in 20:
		var a = TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)

func _half_ellipse(center: Vector2, radius: Vector2, color: Color):
	var points = PackedVector2Array()
	for i in 11:
		var a = PI + PI * i / 10.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)
