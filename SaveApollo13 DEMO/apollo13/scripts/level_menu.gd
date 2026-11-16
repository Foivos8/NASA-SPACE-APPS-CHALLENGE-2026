extends Control
## Level menu: the Apollo 13 mission map. Ten stations along the flight path
## from Earth, around the Moon and back. Each station has a card, an info sheet
## ("?"), an optional sound, and some have a challenge or a playable level.
##
## Navigation: CONTINUE steps to the next station, and clicking any numbered
## station on the map jumps straight to it.
##
## Built for the game's own 640 x 360 pixel-art screen (no scale switching).
##   Station images (optional): res://img/station_1.png ... station_10.png  (or .jpg / .webp)
##   Station sounds (optional): res://audio/station_1.ogg ... station_10.ogg (or .mp3 / .wav)
##   Radio sound for station 9:  res://audio/radio.ogg, else the game's own "Radio Signal" clip

const SkyBackground := preload("res://scripts/ui/sky_background.gd")
const TypeText := preload("res://scripts/ui/type_text.gd")
const MAIN_MENU := "res://main_menu.tscn"
const ART := "res://assets/levels/"

const C_PANEL := Color(0.06, 0.08, 0.13, 0.96)
const C_CARD := Color(0.14, 0.16, 0.22)
const C_BORDER := Color(0.6, 0.66, 0.74)
const C_GOLD := Color(1, 0.86, 0.3)
const C_OK := Color(0.45, 1, 0.6)
const C_BAD := Color(1, 0.55, 0.5)
const C_DIM := Color(0.75, 0.85, 1)
const C_TEAL := Color(0.23, 0.63, 0.66)
const CARD_X := 150.0          # hover briefing: left edge, width, and where its bottom edge rests
const CARD_W := 340.0
const CARD_BOTTOM := 236.0

## Each station: n = title, t = card text, i = info sheet text, f = facts,
## g = challenge ("coas" or "dice"), s = accident (screen shake), end = last station,
## lvl / lvl_name = a playable level that starts from this station,
## card = the briefing shown while the mouse is over the level button:
##        title, intro, rows ([label, text]; a text with several lines becomes a list), fact.
var S: Array = [
	{"n": "1. Launch from Florida",
	 "t": "11 April 1970. The Saturn V lights its engines at Kennedy Space Center with Lovell, Swigert and Haise on board.",
	 "i": "Apollo 13 was the third mission meant to land on the Moon. Jim Lovell was the commander. Jack Swigert took Ken Mattingly's place days before launch, because Mattingly had been exposed to German measles.",
	 "f": ["Commander: Jim Lovell", "Command Module Pilot: Jack Swigert", "Lunar Module Pilot: Fred Haise"],
	 "lvl": "res://main.tscn", "lvl_name": "PLAY LEVEL 1",
	 "card": {
		"title": "LEVEL 1 - COMMUNICATION WITH HOUSTON",
		"intro": "Launch day. Board the Command Module Odyssey, get it ready to fly, and ride the Saturn V into space.",
		"rows": [
			["WHERE", "Launch Complex 39A, Kennedy Space Center, Florida"],
			["WHEN", "11 April 1970"],
			["YOU WILL", "Pass the medical check and suit up\nExplore the cabin and inspect its instruments\nTalk to Mission Control in Houston\nAnswer the calls of the final countdown"],
			["GOAL", "Launch Apollo 13 and reach Earth orbit"]],
		"fact": "Jack Swigert, the pilot you play, joined the crew only days before launch."}},
	{"n": "2. Liftoff and the first two stages",
	 "t": "The first stage burns out and drops away, then the second takes over. Its centre engine shuts down early, but the other four make up for it.",
	 "i": "The Saturn V has three stages. The first two (S-IC and S-II) carry the spacecraft almost to orbit and then fall away. On Apollo 13 the centre engine of the S-II stopped early and the flight went on with the others burning longer.",
	 "f": ["First stage: S-IC", "Second stage: S-II"],
	 "lvl": "res://level2_trajectory.tscn", "lvl_name": "PLAY LEVEL 2",
	 "card": {
		"title": "LEVEL 2 - APOLLO 13 IN SPACE",
		"intro": "Apollo 13 leaves Earth orbit for the Moon. Two days out, an oxygen tank bursts and the landing is called off.",
		"rows": [
			["WHERE", "From Earth orbit to 321,860 km out, on the way to the Moon"],
			["WHEN", "11 to 13 April 1970"],
			["YOU WILL", "Fire the third stage toward the Moon\nSeparate and dock with the Lunar Module\nFollow the flight path on the map\nReport the accident to Houston"],
			["GOAL", "Learn how a free-return path brought the crew home"]],
		"fact": "The Saturn V rocket worked as planned. The accident was in the spacecraft's Service Module."}},
	{"n": "3. Orbit around the Earth",
	 "t": "The spacecraft circles the Earth about one and a half times while every system is checked before the trip to the Moon.",
	 "i": "In this 'parking orbit' the crew checks the spacecraft. Then the third stage (S-IVB) fires again and sends Apollo 13 toward the Moon.",
	 "f": ["The S-IVB relights to leave Earth orbit"]},
	{"n": "4. Leaving the third stage, docking with the lander",
	 "t": "The Command Module 'Odyssey' separates, turns around and docks with the Lunar Module 'Aquarius', pulling it out of the third stage.",
	 "i": "This manoeuvre is called transposition and docking. From here on Odyssey and Aquarius fly joined together toward the Moon.",
	 "f": ["Command Module: Odyssey", "Lunar Module: Aquarius"]},
	{"n": "5. Explosion, and the move to the lander",
	 "t": "About 56 hours after launch, oxygen tank 2 bursts. The crew moves into the Lunar Module, which becomes their lifeboat.",
	 "i": "The blast wrecked the oxygen supply of the Service Module and the fuel cells lost power. Aquarius was built to keep two people alive for two days, not three people for four.",
	 "f": ["The Command Module was left without power and oxygen", "Aquarius became a lifeboat"], "s": true},
	{"n": "6. Around the far side of the Moon",
	 "t": "With no landing, the spacecraft swings around the far side of the Moon and the Moon's gravity sends it back toward Earth.",
	 "i": "The free-return trajectory saved the mission. Aquarius fired its engine shortly after the pass to get the crew home faster. Here they were farther from Earth than any humans had ever been.",
	 "f": ["About 254 km above the far side", "Distance record: about 400,000 km from Earth"]},
	{"n": "7. Lost bearings: aiming with the COAS",
	 "t": "Debris and ice from the leaking spacecraft hide the stars. Line up the edge of Earth's shadow with the centre of the crosshair.",
	 "i": "The COAS was the crew's optical sight. Because they could not pick out stars, they used the Earth's terminator, the line between day and night, to point the spacecraft before a course-correction burn.",
	 "f": ["COAS: Crew Optical Alignment Sight"], "g": "coas"},
	{"n": "8. Dropping the Service Module and the lander",
	 "t": "First the damaged Service Module is cast off, then Aquarius, its job done.",
	 "i": "Only the Command Module has a heat shield for re-entry. When the Service Module drifted away, the crew saw for the first time how bad the damage was.",
	 "f": ["Odyssey is on its own"]},
	{"n": "9. Re-entry at a shallow angle",
	 "t": "The angle is critical: too shallow and the capsule skips off the atmosphere, too steep and it burns up. Roll two dice for a total of 5, 6 or 7.",
	 "i": "During re-entry the radio goes silent because of the hot plasma around the capsule. On Apollo 13 the silence lasted longer than expected and everyone waited to hear the crew.",
	 "f": ["The radio should come back after the blackout"], "g": "dice"},
	{"n": "10. Splashdown, rescue and honours",
	 "t": "17 April 1970. Odyssey comes down under its parachutes in the South Pacific. The crew is home safe.   * * *",
	 "i": "The crew was picked up by the ship USS Iwo Jima. The mission was called a 'successful failure'. The Presidential Medal of Freedom was awarded to the Mission Control team.",
	 "f": ["Duration: about 143 hours", "Splashdown: South Pacific"], "end": true},
]

## The flight path on the 640 x 360 screen, and which path points are stations.
var PATH: Array[Vector2] = [Vector2(89, 142), Vector2(136, 105), Vector2(191, 80), Vector2(259, 61), Vector2(334, 52),
		Vector2(456, 38), Vector2(551, 57), Vector2(578, 96), Vector2(551, 135), Vector2(456, 149), Vector2(354, 172),
		Vector2(232, 199), Vector2(116, 207)]
var IDX: Array[int] = [0, 1, 2, 3, 4, 7, 9, 10, 11, 12]

var cur := 0
var hovered := -1              # station under the mouse, or -1
var mouse_pos := Vector2(-100, -100)   # last mouse position over the map
var done := {}
var shake := 0.0
var mode := ""                 # "" | "coas" | "dice"
var clock := 0.0

# COAS challenge
var ter := Vector2.ZERO        # where the terminator sits in the sight
var vel := Vector2.ZERO
var hold := 0.0
# dice challenge
var dice := [0, 0]
var dice_phase := ""           # "" | "good" | "silence"
var dice_timer := 0.0

var backdrop: Control
var board: Control
var pawn: TextureRect
var title_label: Label
var text_label: RichTextLabel   # TypeText: the station text, typed letter by letter
var go: Button
var play_level: Button
var level_card: Panel          # mission briefing shown while the mouse is over the level button
var level_card_title: Label
var _card_tween: Tween
var game_box: Panel
var game_title: Label
var game_msg: Label
var game_area: Control
var game_buttons: Control
var modal: Control
var modal_title: Label
var modal_text: RichTextLabel   # TypeText on the info sheet
var modal_image: TextureRect
var player: AudioStreamPlayer


func _ready() -> void:
	get_tree().paused = false
	get_tree().root.content_scale_size = Vector2i(640, 360)
	size = Vector2(640, 360)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player = AudioStreamPlayer.new()
	add_child(player)

	var sky := SkyBackground.new()
	sky.size = size
	sky.altitude = 1.0                         # space, with stars
	add_child(sky)

	backdrop = Control.new()                   # Earth and Moon, behind the flight path
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_sprite("earth.png", Vector2(41, 128), 2.0, backdrop)
	_sprite("moon.png", Vector2(490, 71), 2.0, backdrop)
	board = Control.new()                      # path, stations and the ship; shakes with the backdrop
	board.size = size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.draw.connect(_draw_board)
	add_child(board)
	_label("Earth", 9, C_DIM, Vector2(28, 212), 0, board)
	_label("Moon", 9, C_DIM, Vector2(497, 114), 0, board)
	pawn = _sprite("ship.png", Vector2.ZERO, 2.0, board)
	pawn.position = _pawn_pos(0)

	_label("MISSION MAP", 12, C_GOLD, Vector2(250, 6), 140).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("Click a number to jump to that station", 8, C_DIM, Vector2(220, 22), 200).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button("< MAIN MENU", Rect2(8, 6, 84, 18), 8, to_main_menu)

	# station card
	_panel(Rect2(12, 240, 566, 112), C_PANEL, C_BORDER)
	title_label = _label("", 12, C_GOLD, Vector2(22, 244), 546)
	text_label = _type_text(9, Vector2(22, 264), 546, self)
	go = _button("", Rect2(22, 322, 130, 22), 9, _go_pressed)
	play_level = _button("", Rect2(160, 322, 130, 22), 9, on_play_level)
	play_level.add_theme_color_override("font_color", C_GOLD)
	play_level.mouse_entered.connect(show_level_card.bind(true))
	play_level.mouse_exited.connect(show_level_card.bind(false))
	# the briefing sits just above the station card, clear of both buttons; its contents are
	# laid out each time it opens (see show_level_card)
	level_card = _panel(Rect2(CARD_X, 60, CARD_W, 176), Color(C_PANEL, 1.0), C_GOLD)
	level_card.visible = false
	_button("?", Rect2(586, 240, 42, 42), 18, show_info.bind(true))
	_label("INFO", 8, C_DIM, Vector2(586, 284), 42).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_build_game_box()
	_build_modal()
	_render()


# -------------------------------------------------------------- helpers ----

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_content_margin_all(4)
	return s


func _panel(r: Rect2, bg: Color, border: Color, parent: Control = null) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", _style(bg, border))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(p)
	return p


func _label(text: String, font_size: int, color: Color, pos: Vector2, width := 0.0, parent: Control = null) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.09))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	(parent if parent != null else self).add_child(l)
	l.reset_size()
	return l


func _button(text: String, r: Rect2, font_size: int, action: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE          # arrow keys and Space never trigger a button by accident
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(C_CARD, C_BORDER))
	b.add_theme_stylebox_override("hover", _style(C_CARD.lightened(0.15), C_GOLD))
	b.add_theme_stylebox_override("pressed", _style(C_GOLD.darkened(0.6), C_GOLD))
	b.add_theme_stylebox_override("disabled", _style(Color(0.1, 0.11, 0.14), Color(0.25, 0.27, 0.32)))
	b.position = r.position
	b.size = r.size
	b.pressed.connect(action)
	(parent if parent != null else self).add_child(b)
	return b


func _type_text(font_size: int, pos: Vector2, width: float, parent: Control) -> RichTextLabel:
	var t := TypeText.new()
	t.style(font_size, Color.WHITE, width)
	t.position = pos
	parent.add_child(t)
	return t


func _sprite(file: String, pos: Vector2, pixel_scale: float, parent: Control) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ART + file)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = pos
	t.size = t.texture.get_size() * pixel_scale
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _find(base: String, exts: Array) -> String:
	for e in exts:
		var p: String = base + "." + e
		if ResourceLoader.exists(p):
			return p
	return ""


## Plays an optional sound file. Returns false if there is none.
func _play(base: String) -> bool:
	player.stop()
	var p := _find(base, ["ogg", "mp3", "wav"])
	if p == "":
		return false
	player.stream = load(p)
	player.play()
	return true


## Plays one of the game's sound effects, if the Sfx autoload is present.
func _sfx(key: String, volume_db := 0.0) -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.play(key, volume_db, 0.0, 0.0, true)


func _pawn_pos(station: int) -> Vector2:
	return PATH[IDX[station]] - Vector2(7, 18)          # the ship hovers just above its station


# ----------------------------------------------------------------- board ----

func _draw_board() -> void:
	# dotted flight path
	for i in PATH.size() - 1:
		var a := PATH[i]
		var b := PATH[i + 1]
		var steps := int(a.distance_to(b) / 5.0)
		for k in steps:
			var p := a.lerp(b, float(k) / steps).floor()
			var flown := IDX[cur] > i
			board.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), C_OK if flown else C_TEAL)
	# stations
	var font := ThemeDB.fallback_font
	for n in IDX.size():
		var c := PATH[IDX[n]].floor()
		var here := n == cur
		var half := 8.0 if (here or n == hovered) else 7.0
		var fill := C_OK.darkened(0.55) if n < cur else Color(0.08, 0.1, 0.16)
		var edge := C_GOLD if (here or n == hovered) else (C_OK if n < cur else C_BORDER)
		board.draw_rect(Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), edge)
		board.draw_rect(Rect2(c - Vector2(half - 2, half - 2), Vector2(half - 2, half - 2) * 2.0), fill)
		board.draw_string(font, c + Vector2(-10, 3), str(n + 1), HORIZONTAL_ALIGNMENT_CENTER, 20, 8,
				C_GOLD if here else Color.WHITE)


func _render() -> void:
	mode = ""
	dice_phase = ""
	game_box.visible = false
	var s: Dictionary = S[cur]
	title_label.text = s["n"]
	text_label.type(str(s["t"]))
	go.visible = true
	go.text = "PLAY AGAIN" if s.get("end", false) else ("START THE CHALLENGE" if s.has("g") and not done.has(cur) else "CONTINUE")
	play_level.visible = s.has("lvl") and ResourceLoader.exists(str(s.get("lvl", "")))
	play_level.text = str(s.get("lvl_name", "PLAY LEVEL"))
	show_level_card(false)
	create_tween().tween_property(pawn, "position", _pawn_pos(cur), 0.9).set_trans(Tween.TRANS_SINE)
	if s.get("s", false):
		shake = 1.0
	if not _play("res://audio/station_%d" % (cur + 1)) and s.get("s", false):
		_sfx("bang", -6.0)                       # the accident, when the station has no sound of its own
	board.queue_redraw()


## The button itself: a press while the station text is still appearing shows
## the rest of it; the next press does what the button says.
func _go_pressed() -> void:
	if text_label.is_typing():
		text_label.finish()
	else:
		on_go()


## The main button on the card: continue, start the challenge, or play again.
func on_go() -> void:
	_sfx("click", -12.0)
	var s: Dictionary = S[cur]
	if s.get("end", false):
		cur = 0
		done.clear()
		_render()
	elif s.has("g") and not done.has(cur):
		_start_game(str(s["g"]))
	else:
		cur += 1
		_render()


## Shows or hides the mission briefing for the level offered at the current station.
func show_level_card(open: bool) -> void:
	var info: Dictionary = S[cur].get("card", {})
	open = open and play_level.visible and not info.is_empty()
	if _card_tween != null:
		_card_tween.kill()
	if not open:
		level_card.visible = false
		return
	_fill_level_card(info)
	level_card.visible = true
	level_card.modulate.a = 0.0
	_card_tween = create_tween()
	_card_tween.tween_property(level_card, "modulate:a", 1.0, 0.12)


## Height a wrapped label really needs at its width.
func _text_height(l: Label) -> float:
	return l.get_line_count() * (l.get_line_height() + l.get_theme_constant("line_spacing"))


## A label inside the briefing: the usual label with tighter line spacing.
func _card_label(text: String, font_size: int, color: Color, pos: Vector2, width := 0.0) -> Label:
	var l := _label(text, font_size, color, pos, width, level_card)
	l.add_theme_constant_override("line_spacing", -2)
	l.reset_size()
	l.size.y = _text_height(l)                 # exactly as tall as its text, so the rows stack cleanly
	return l


## Lays the briefing out top to bottom: header strip, title, intro, labelled
## rows, and a "did you know" line. The card grows upward to fit its text.
func _fill_level_card(info: Dictionary) -> void:
	for c in level_card.get_children():
		c.queue_free()
	var strip := ColorRect.new()                         # header strip, like the tab of a file card
	strip.color = C_GOLD
	strip.position = Vector2(2, 2)
	strip.size = Vector2(CARD_W - 4, 12)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_card.add_child(strip)
	var head := _card_label("MISSION BRIEFING", 8, Color(0.1, 0.09, 0.03), Vector2(8, 1))
	head.add_theme_constant_override("outline_size", 0)
	var y := 16.0
	level_card_title = _card_label(str(info["title"]), 10, C_GOLD, Vector2(8, y))
	y += 14.0
	var intro := _card_label(str(info["intro"]), 8, C_DIM, Vector2(8, y), CARD_W - 16)
	y += _text_height(intro) + 4.0
	y = _card_rule(y)
	for row in info["rows"]:
		_card_label(str(row[0]), 8, C_GOLD, Vector2(8, y))
		var lines: PackedStringArray = str(row[1]).split("\n")
		var value := ("- " + "\n- ".join(lines)) if lines.size() > 1 else lines[0]
		var v := _card_label(value, 8, Color.WHITE, Vector2(64, y), CARD_W - 72)
		y += _text_height(v) + 2.0
	y = _card_rule(y + 2.0)
	var fact := _card_label("DID YOU KNOW?  " + str(info["fact"]), 8, C_OK, Vector2(8, y), CARD_W - 16)
	y += _text_height(fact) + 8.0
	level_card.size = Vector2(CARD_W, y)
	level_card.position = Vector2(CARD_X, CARD_BOTTOM - y)


## A thin divider line across the briefing. Returns the y below it.
func _card_rule(y: float) -> float:
	var line := ColorRect.new()
	line.color = Color(C_BORDER, 0.45)
	line.position = Vector2(8, y)
	line.size = Vector2(CARD_W - 16, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_card.add_child(line)
	return y + 4.0


## The station whose square is under `pos`, or -1.
func station_at(pos: Vector2) -> int:
	for n in IDX.size():
		if pos.distance_to(PATH[IDX[n]]) <= 11.0:
			return n
	return -1


## True while the map itself can be clicked (no challenge or info sheet on top).
func _map_is_free() -> bool:
	return mode == "" and not modal.visible and not game_box.visible


## Jumps straight to a station, as if CONTINUE had been pressed all the way there.
func go_to_station(n: int) -> void:
	if n < 0 or n >= S.size() or n == cur or not _map_is_free():
		return
	_sfx("click", -12.0)
	cur = n
	_render()


func on_play_level() -> void:
	_sfx("click", -12.0)
	player.stop()
	get_tree().change_scene_to_file(str(S[cur]["lvl"]))


func to_main_menu() -> void:
	_sfx("click", -12.0)
	player.stop()
	get_tree().change_scene_to_file(MAIN_MENU)


func _finish_game(msg: String) -> void:
	mode = ""
	dice_phase = ""
	done[cur] = true
	_sfx("confirm", -8.0)
	game_box.visible = false
	text_label.type("%s\n%s" % [S[cur]["t"], msg])
	go.visible = true
	go.text = "CONTINUE"


# ------------------------------------------------------------ challenges ----

func _build_game_box() -> void:
	game_box = _panel(Rect2(150, 24, 340, 212), Color(C_PANEL, 1.0), C_GOLD)
	game_box.mouse_filter = Control.MOUSE_FILTER_STOP
	game_title = _label("", 11, C_GOLD, Vector2(0, 5), 340, game_box)
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_area = Control.new()
	game_area.position = Vector2(105, 22)
	game_area.size = Vector2(130, 130)
	game_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_area.draw.connect(_draw_game)
	game_box.add_child(game_area)
	game_buttons = Control.new()
	game_buttons.size = game_box.size
	game_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_box.add_child(game_buttons)
	game_msg = _label("", 9, Color.WHITE, Vector2(10, 183), 320, game_box)
	game_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_box.visible = false


func _start_game(kind: String) -> void:
	go.visible = false
	play_level.visible = false
	show_level_card(false)
	for c in game_buttons.get_children():
		c.queue_free()
	game_box.visible = true
	if kind == "coas":
		game_title.text = "COAS - AIM AT THE EARTH"
		ter = Vector2(34, -30)
		vel = Vector2.ZERO
		hold = 0.0
		var arrows := [["<", Vector2(-1, 0)], ["^", Vector2(0, -1)], ["v", Vector2(0, 1)], [">", Vector2(1, 0)]]
		for i in arrows.size():
			_button(arrows[i][0], Rect2(102 + i * 35, 155, 31, 24), 10, nudge.bind(arrows[i][1]), game_buttons)
		game_msg.text = "Arrow keys or buttons: hold the shadow line on the centre for 2 seconds."
	else:
		game_title.text = "RE-ENTRY ANGLE"
		dice = [0, 0]
		_button("ROLL THE DICE", Rect2(110, 155, 120, 24), 9, roll_dice, game_buttons)
		game_msg.text = "You need a total of 5, 6 or 7."
	mode = kind
	game_area.queue_redraw()


func nudge(dir: Vector2) -> void:
	if mode == "coas":
		ter += dir * 5.0
		_sfx("thruster", -12.0)


## Rolls both dice. The arguments force a result (used by the tests).
func roll_dice(a := 0, b := 0) -> void:
	if mode != "dice" or dice_phase != "":
		return
	dice = [a if a > 0 else randi_range(1, 6), b if b > 0 else randi_range(1, 6)]
	_sfx("dice", -6.0)
	var total: int = dice[0] + dice[1]
	if total >= 5 and total <= 7:
		dice_phase = "good"
		dice_timer = 1.2
		game_msg.text = "Total %d. The angle is right." % total
		for c in game_buttons.get_children():
			c.disabled = true
	elif total < 5:
		game_msg.text = "Total %d: too shallow, the capsule skips off. Roll again." % total
	else:
		game_msg.text = "Total %d: too steep, the capsule burns up. Roll again." % total
	game_area.queue_redraw()


func _draw_game() -> void:
	if mode == "coas":
		_draw_coas()
	elif mode == "dice":
		_draw_dice()


## A filled circle made of 2-pixel rows, to match the pixel art.
func _px_circle(target: Control, c: Vector2, r: float, color: Color, right_half_only := false) -> void:
	var y := -r
	while y < r:
		var w := floorf(sqrt(maxf(0.0, r * r - (y + 1.0) * (y + 1.0))) / 2.0) * 2.0
		if w > 0.0:
			target.draw_rect(Rect2(c.x - (0.0 if right_half_only else w), c.y + y, w if right_half_only else w * 2.0, 2), color)
		y += 2.0


func _draw_coas() -> void:
	var c := Vector2(65, 65)
	_px_circle(game_area, c, 64, C_BORDER)
	_px_circle(game_area, c, 62, Color(0.02, 0.04, 0.07))
	var p := (c + ter).floor()
	_px_circle(game_area, p, 12, Color(0.06, 0.12, 0.18))                 # night side of the Earth
	_px_circle(game_area, p, 12, Color(0.56, 0.78, 1.0), true)            # day side; the edge between is the terminator
	var cross := C_OK if ter.length() < 8.0 else C_TEAL
	game_area.draw_rect(Rect2(64, 3, 2, 124), cross)
	game_area.draw_rect(Rect2(3, 64, 124, 2), cross)
	game_area.draw_rect(Rect2(57, 57, 16, 2), cross)
	game_area.draw_rect(Rect2(57, 71, 16, 2), cross)
	game_area.draw_rect(Rect2(57, 57, 2, 16), cross)
	game_area.draw_rect(Rect2(71, 57, 2, 16), cross)


func _draw_dice() -> void:
	const PIPS := {1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8]}
	for d in 2:
		var o := Vector2(9 + d * 62, 40)
		game_area.draw_rect(Rect2(o, Vector2(50, 50)), C_BORDER)
		game_area.draw_rect(Rect2(o + Vector2(2, 2), Vector2(46, 46)), Color(0.93, 0.93, 0.9))
		if dice[d] == 0:
			game_area.draw_string(ThemeDB.fallback_font, o + Vector2(0, 32), "?", HORIZONTAL_ALIGNMENT_CENTER, 50, 20, Color(0.2, 0.22, 0.3))
		else:
			for cell in PIPS[dice[d]]:
				game_area.draw_rect(Rect2(o + Vector2(9 + (int(cell) % 3) * 13, 9 + (int(cell) / 3) * 13), Vector2(6, 6)), Color(0.1, 0.12, 0.18))
	if dice_phase == "silence":
		var a := 0.45 + 0.55 * absf(sin(clock * 2.6))
		game_area.draw_string(ThemeDB.fallback_font, Vector2(0, 116), "Radio silence...", HORIZONTAL_ALIGNMENT_CENTER, 130, 10,
				Color(C_DIM, a))


func _process(delta: float) -> void:
	advance(delta)


## Runs the challenge in progress. Called every frame; the tests call it directly.
func advance(delta: float) -> void:
	clock += delta
	var over := station_at(mouse_pos) if _map_is_free() else -1
	if over != hovered:
		hovered = over
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered >= 0 else Control.CURSOR_ARROW
		board.queue_redraw()
	if shake > 0.0:
		shake = maxf(0.0, shake - delta)
		board.position = Vector2(sin(clock * 50.0) * 4.0 * shake, 0).round()
		backdrop.position = board.position
	if mode == "coas":
		vel += Vector2(randf() - 0.5, randf() - 0.5) * 50.0 * delta
		vel = vel.clamp(Vector2(-13, -13), Vector2(13, 13))
		ter = (ter + vel * delta).clamp(Vector2(-50, -50), Vector2(50, 50))
		if ter.length() < 8.0:
			hold += delta
			game_msg.text = "Steady... %d%%" % int(minf(100.0, hold / 2.0 * 100.0))
		else:
			hold = 0.0
			game_msg.text = "Arrow keys or buttons: hold the shadow line on the centre for 2 seconds."
		game_area.queue_redraw()
		if hold >= 2.0:
			_finish_game("Alignment good. The course-correction burn goes ahead.")
	elif mode == "dice" and dice_phase != "":
		dice_timer -= delta
		game_area.queue_redraw()
		if dice_timer <= 0.0:
			if dice_phase == "good":
				dice_phase = "silence"
				dice_timer = 4.5
				game_msg.text = "Plasma around the capsule blocks the radio."
			else:
				if not _play("res://audio/radio") and has_node("/root/Sfx"):
					get_node("/root/Sfx").play("radio", -4.0, 0.0, 2.0, true)
				_finish_game("The radio crackles back to life. 'Odyssey, Houston, standing by.' The crew answers. They made it.")


## Mouse on the map itself (anything not on a button or an open panel).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_pos = event.position
		var n := station_at(event.position)
		if n >= 0 and _map_is_free():
			accept_event()
			go_to_station(n)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_ESCAPE:
		if modal.visible:
			show_info(false)
		return
	if mode == "coas" and not modal.visible:
		match event.keycode:
			KEY_LEFT, KEY_A: nudge(Vector2(-1, 0))
			KEY_RIGHT, KEY_D: nudge(Vector2(1, 0))
			KEY_UP, KEY_W: nudge(Vector2(0, -1))
			KEY_DOWN, KEY_S: nudge(Vector2(0, 1))


# ------------------------------------------------------------ info sheet ----

func _build_modal() -> void:
	modal = Control.new()
	modal.size = size
	modal.mouse_filter = Control.MOUSE_FILTER_STOP        # blocks the map underneath
	modal.visible = false
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(shade)
	_panel(Rect2(110, 20, 420, 320), C_PANEL, C_GOLD, modal)
	modal_title = _label("", 12, C_GOLD, Vector2(122, 26), 396, modal)
	modal_image = TextureRect.new()
	modal_image.position = Vector2(122, 62)
	modal_image.size = Vector2(396, 110)
	modal_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	modal_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	modal_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(modal_image)
	modal_text = _type_text(9, Vector2(122, 62), 396, modal)
	modal_text.chars_per_second = 80.0
	_button("CLOSE", Rect2(438, 312, 80, 20), 9, show_info.bind(false), modal)


func show_info(open: bool) -> void:
	_sfx("click", -12.0)
	if open:
		var s: Dictionary = S[cur]
		modal_title.text = s["n"]
		var img := _find("res://img/station_%d" % (cur + 1), ["png", "jpg", "webp"])
		modal_image.visible = img != ""
		if img != "":
			modal_image.texture = load(img)
		modal_text.position.y = 178.0 if img != "" else 62.0
		modal_text.type("%s\n\n- %s" % [s["i"], "\n- ".join(PackedStringArray(s["f"]))])
	modal.visible = open
