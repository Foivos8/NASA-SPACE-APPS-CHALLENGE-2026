extends Node2D
## Apollo 13 - Level 1 prototype.
## Builds the whole level from res://data/level1.json at runtime:
## two TileMapLayers, grid-based four-direction player, "Press E" interaction,
## objective tracking and the launch cutscene.
## Controls: arrows / WASD to move, E / Enter / Space to interact and advance text.
## Mini-games (scripts/minigames/) are full-screen overlays started from here:
## the level's "prologue_minigames" play before the level, and a step with a
## "minigame" key plays one after its text (or before it, with "minigame_first").
## Opened from the main menu as Level 1: a sky backdrop, sound effects, the
## PAUSE / EXIT bar, and a hand-over to Level 2 when the launch is complete.

const LEVEL_PATH := "res://data/level1.json"
const MINIGAME_PATH := "res://data/minigames.json"
const DIRS := {"down": Vector2i(0, 1), "up": Vector2i(0, -1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
const FRAME := {"down": 0, "up": 1, "left": 2, "right": 3}
const MOVE_TIME := 0.14
const TypeText := preload("res://scripts/ui/type_text.gd")
const SKY_SCRIPT := "res://scripts/ui/sky_background.gd"
const TOP_MENU_SCRIPT := "res://scripts/ui/top_menu.gd"
const NEXT_LEVEL := "res://level2_trajectory.tscn"
const FOOTSTEP_GRACE := 0.3       # keeps the footsteps going between two tile steps
const FOOTSTEP_START := 0.28      # the clip opens with 0.28 s of silence: skip it so each step is heard at once
const FOOTSTEP_VOLUME := -2.0

var level_path := LEVEL_PATH     # a scene that reuses this engine sets another file before _ready (see scripts/mission/)
var move_time := MOVE_TIME       # seconds per tile; the same reuse can change the walking speed
var data: Dictionary
var ts := 32
var ground: TileMapLayer
var objects: TileMapLayer
var solid_ids := {}
var blocked := {}                 # extra solid cells (NPCs)
var tile_to_interactable := {}    # Vector2i -> interactable id
var interactables := {}           # id -> Dictionary

var player: Sprite2D
var cell := Vector2i.ZERO
var facing := "down"
var moving := false
var frozen := false

var objective_index := 0
var done_targets := {}            # targets completed for the current objective
var hatch_closed := false
var in_orbit := false
var level_complete := false
var current_zone := ""

# dialog state
var dialog_open := false
var dialog_pages: Array = []
var dialog_page := 0
var dialog_choice = null
var choice_index := 0
var choice_reply := false
var dialog_target := ""
var dialog_counts := false
var dialog_minigame := ""

# mini-games
var minigames_enabled := true     # set false before _ready to skip them (used by the smoke test)
var minigame_data: Dictionary = {}
var minigames_played := {}        # id -> true once finished

# UI nodes
var ui_objective: Label
var ui_prompt: Label
var ui_zone: Label
var ui_box: PanelContainer
var ui_title: Label
var ui_text: RichTextLabel          # TypeText: the dialogue text, typed letter by letter
var choice_typed := false          # the current choice prompt has already been typed out
var ui_clock: Label
var markers: Node2D
var camera: Camera2D
var sky: Control                  # sky behind the spacecraft (null if the script is missing)
var sky_target := 0.0             # 0 = blue sky, 1 = space; follows the launch
var top_menu: CanvasLayer
var idle_time := 0.0              # seconds since the astronaut last moved
var launch_running := false       # the launch text is on screen (E skips ahead)
var launch_skip := false          # E was pressed: stop waiting and show the next launch message


func _ready() -> void:
	_setup_input()
	data = JSON.parse_string(FileAccess.get_file_as_string(level_path))
	ts = int(data["tile_size"])
	_build_sky()
	_build_tilemap()
	_build_actors()
	_build_ui()
	_build_top_menu()
	for it in data["interactables"]:
		interactables[it["id"]] = it
		for t in it["tiles"]:
			tile_to_interactable[Vector2i(int(t[0]), int(t[1]))] = it["id"]
	_refresh_objective()
	sfx_loop("hum", -24.0)                    # quiet fans and electronics inside the Command Module
	if minigames_enabled:
		_run_prologue()


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"interact": [KEY_E, KEY_ENTER, KEY_SPACE],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in map[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- world ----

func _build_tilemap() -> void:
	var atlas: Dictionary = data["atlas"]
	var cols := int(atlas["columns"])
	var tex: Texture2D = load(atlas["image"])
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(ts, ts)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(ts, ts)
	var count := int(atlas["tile_names"].size())
	for id in count:
		src.create_tile(Vector2i(id % cols, id / cols))
	tile_set.add_source(src, 0)
	for id in atlas["solid_ids"]:
		solid_ids[int(id)] = true

	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	add_child(ground)
	objects = TileMapLayer.new()
	objects.name = "Objects"
	objects.tile_set = tile_set
	add_child(objects)
	# "void" tiles (outside the spacecraft) are left empty so the sky shows through
	var void_id := int(atlas["tile_names"].get("void", -1)) if sky != null else -1
	for y in int(data["height"]):
		for x in int(data["width"]):
			var gid := int(data["layers"]["ground"][y][x])
			_set_tile(ground, x, y, -1 if gid == void_id else gid)
			_set_tile(objects, x, y, int(data["layers"]["objects"][y][x]))


func _set_tile(layer: TileMapLayer, x: int, y: int, id: int) -> void:
	if id < 0:
		layer.erase_cell(Vector2i(x, y))
		return
	var cols := int(data["atlas"]["columns"])
	layer.set_cell(Vector2i(x, y), 0, Vector2i(id % cols, id / cols))


func _tile_id(layer_name: String, c: Vector2i) -> int:
	return int(data["layers"][layer_name][c.y][c.x])


func is_solid(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= int(data["width"]) or c.y >= int(data["height"]):
		return true
	if blocked.has(c):
		return true
	var o := _tile_id("objects", c)
	if o >= 0 and solid_ids.has(o):
		return true
	return solid_ids.has(_tile_id("ground", c))


func _build_actors() -> void:
	for npc in data["npcs"]:
		var s := Sprite2D.new()
		s.texture = load("res://assets/" + str(npc["sprite"]))
		s.centered = false
		s.position = Vector2(int(npc["tile"][0]), int(npc["tile"][1])) * ts
		s.name = str(npc["id"])
		add_child(s)
		if not npc.has("size"):
			blocked[Vector2i(int(npc["tile"][0]), int(npc["tile"][1]))] = true

	markers = Node2D.new()
	markers.name = "Markers"
	add_child(markers)

	player = Sprite2D.new()
	player.name = "Player"
	player.texture = load("res://assets/player.png")
	player.centered = false
	player.region_enabled = true
	add_child(player)
	cell = Vector2i(int(data["player_start"][0]), int(data["player_start"][1]))
	player.position = Vector2(cell) * ts
	_face(facing)

	camera = Camera2D.new()
	camera.position = Vector2(ts, ts) / 2.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data["width"]) * ts
	camera.limit_bottom = int(data["height"]) * ts
	player.add_child(camera)
	camera.make_current()


func _face(dir: String) -> void:
	facing = dir
	player.region_rect = Rect2(FRAME[dir] * ts, 0, ts, ts)


# ------------------------------------------------------------------- UI ----

func _label(size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.09))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	ui_objective = _label(11, Color(1, 0.86, 0.3))
	ui_objective.position = Vector2(8, 6)
	layer.add_child(ui_objective)

	ui_zone = _label(10, Color(0.75, 0.85, 1))
	ui_zone.position = Vector2(8, 38)
	layer.add_child(ui_zone)

	ui_clock = _label(14, Color(0.45, 1, 0.6))
	ui_clock.position = Vector2(548, 6)
	layer.add_child(ui_clock)

	ui_prompt = _label(11)
	ui_prompt.position = Vector2(0, 336)
	ui_prompt.size = Vector2(640, 16)
	ui_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(ui_prompt)

	ui_box = PanelContainer.new()
	ui_box.position = Vector2(40, 218)
	ui_box.custom_minimum_size = Vector2(560, 112)
	ui_box.size = Vector2(560, 112)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.13, 0.96)
	style.border_color = Color(0.6, 0.66, 0.74)
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	ui_box.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	ui_box.add_child(vb)
	ui_title = _label(11, Color(1, 0.86, 0.3))
	vb.add_child(ui_title)
	ui_text = TypeText.new()
	ui_text.style(10, Color.WHITE, 540)
	vb.add_child(ui_text)
	ui_box.visible = false
	layer.add_child(ui_box)


func _refresh_objective() -> void:
	for m in markers.get_children():
		m.queue_free()
	if objective_index >= data["objectives"].size():
		ui_objective.text = "Level complete"
		return
	var o: Dictionary = data["objectives"][objective_index]
	ui_objective.text = "Objective %d/%d: %s\n%s" % [objective_index + 1, data["objectives"].size(), o["text"], o["hint"]]
	var tex: Texture2D = load("res://assets/marker.png")
	for i in o["markers"].size():
		var target: String = o["targets"][i] if i < o["targets"].size() else ""
		if done_targets.has(target):
			continue
		if o.get("ordered", false) and target != _next_target():
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.position = (Vector2(int(o["markers"][i][0]), int(o["markers"][i][1])) + Vector2(0.5, 0.1)) * ts
		markers.add_child(s)
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "position:y", s.position.y - 5, 0.4)
		tw.tween_property(s, "position:y", s.position.y, 0.4)


# ------------------------------------------------------------ game loop ----

func _process(delta: float) -> void:
	_update_footsteps(delta)
	if sky != null:
		sky.altitude = move_toward(sky.altitude, sky_target, delta * 0.06)
	if level_complete or frozen:
		ui_prompt.text = ""
		return
	if dialog_open:
		ui_prompt.text = ""
		return
	if not moving:
		for dir in DIRS:
			if Input.is_action_pressed("move_" + dir):
				try_move(dir)
				break
	var id := _facing_interactable()
	ui_prompt.text = "Press E - %s" % interactables[id]["name"] if id != "" else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if level_complete:
			continue_to_next_level()
		elif launch_running:
			if ui_text.is_typing():
				ui_text.finish()          # first press: show the whole message
			else:
				launch_skip = true        # next press: on to the next message
		elif dialog_open:
			if ui_text.is_typing():
				ui_text.finish()          # first press: show the whole message
			else:
				_advance_dialog()         # next press: carry on
		elif not frozen and not moving:
			var id := _facing_interactable()
			if id != "":
				interact_with(id)
	elif dialog_open and dialog_choice != null and not choice_reply and dialog_page >= dialog_pages.size() \
			and not ui_text.is_typing():
		if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
			choice_index = (choice_index + 1) % dialog_choice["options"].size()
			_show_dialog()


func try_move(dir: String) -> bool:
	_face(dir)
	var next: Vector2i = cell + DIRS[dir]
	if is_solid(next):
		return false
	cell = next
	moving = true
	var tw := create_tween()
	tw.tween_property(player, "position", Vector2(cell) * ts, move_time)
	tw.tween_callback(func(): moving = false)
	_entered_cell()
	return true


func _entered_cell() -> void:
	var zone := ""
	for z in data["zones"]:
		var r: Array = z["rect"]
		if cell.x >= int(r[0]) and cell.y >= int(r[1]) and cell.x <= int(r[2]) and cell.y <= int(r[3]):
			zone = z["id"]
			ui_zone.text = z["name"]
	if zone == "":
		ui_zone.text = ""
	if zone != current_zone:
		current_zone = zone
		var o := _objective()
		if not o.is_empty() and o["type"] == "zones" and zone in o["targets"]:
			_complete_target(zone)


func _facing_interactable() -> String:
	var c: Vector2i = cell + DIRS[facing]
	var id: String = tile_to_interactable.get(c, "")
	if id == "hatch" and not hatch_closed:
		return ""
	return id


func _objective() -> Dictionary:
	if objective_index >= data["objectives"].size():
		return {}
	return data["objectives"][objective_index]


func _next_target() -> String:
	var o := _objective()
	if o.is_empty():
		return ""
	for t in o["targets"]:
		if not done_targets.has(t):
			return t
	return ""


func _counts_now(id: String) -> bool:
	var o := _objective()
	if o.is_empty() or o["type"] != "interact" or not (id in o["targets"]) or done_targets.has(id):
		return false
	return not o.get("ordered", false) or _next_target() == id


func interact_with(id: String) -> void:
	var it: Dictionary = interactables[id]
	var steps: Dictionary = it["steps"]
	dialog_counts = _counts_now(id)
	var key := "default"
	if in_orbit and steps.has("orbit"):
		key = "orbit"
	elif dialog_counts and steps.has(_objective()["id"]):
		key = _objective()["id"]
	var step: Dictionary = steps[key]
	if id != "comm_console":
		sfx("click", -12.0, 0.0, 0.0, true)       # opening a panel
	if id == "comm_console":
		sfx("walkie", 0.0, 0.0, 0.0, true)        # the astronaut keys the radio
		if key == "mission_control":
			sfx("beeps", -4.0, 0.0, 0.75, true)   # incoming call from Houston
	var game_id := str(step.get("minigame", "")) if minigames_enabled else ""
	if game_id != "" and step.get("minigame_first", false):
		frozen = true                 # this step's mini-game runs before its text
		await play_minigame(game_id)
		frozen = false
		game_id = ""
	dialog_target = id
	dialog_pages = []
	for p in step["pages"]:
		dialog_pages.append(str(p).replace("{CHECKLIST}", _checklist_text()))
	dialog_choice = step.get("choice")
	dialog_minigame = game_id
	dialog_page = 0
	choice_index = 0
	choice_reply = false
	choice_typed = false
	ui_title.text = step["title"]
	dialog_open = true
	if id == "comm_console" and key == "mission_control":
		sfx("talk", -10.0, 0.4, 8.0)              # Mission Control voices during the Go / No-Go poll
	_show_dialog()


func _checklist_text() -> String:
	var lines := PackedStringArray()
	for i in data["objectives"].size():
		var mark := "[x]" if i < objective_index else ("[>]" if i == objective_index else "[ ]")
		lines.append("%s %s" % [mark, data["objectives"][i]["text"]])
	return "\n".join(lines)


func _show_dialog() -> void:
	ui_box.visible = true
	if dialog_page < dialog_pages.size():
		ui_text.type(dialog_pages[dialog_page], false, "\n[E]")
	elif dialog_choice != null and not choice_reply:
		var t := "\n"
		for i in dialog_choice["options"].size():
			t += ("  > " if i == choice_index else "    ") + dialog_choice["options"][i]["label"] + "\n"
		# the question is typed once; moving the cursor redraws it without typing again
		ui_text.type(str(dialog_choice["prompt"]), choice_typed, t + "[Up/Down to choose, E to confirm]")
		choice_typed = true
	else:
		ui_text.type(str(dialog_choice["options"][choice_index]["reply"]), false, "\n[E]")


func _advance_dialog() -> void:
	if dialog_page < dialog_pages.size():
		dialog_page += 1
		if dialog_page < dialog_pages.size() or dialog_choice != null:
			_show_dialog()
			return
	elif dialog_choice != null and not choice_reply:
		choice_reply = true
		var right: bool = dialog_choice["options"][choice_index]["ok"]
		sfx("confirm" if right else "error", -10.0, 0.0, 0.0, true)
		_show_dialog()
		return
	elif dialog_choice != null and not dialog_choice["options"][choice_index]["ok"]:
		choice_reply = false      # wrong answer: ask again
		_show_dialog()
		return
	dialog_open = false
	ui_box.visible = false
	sfx_stop("talk")
	var counts := dialog_counts
	var target := dialog_target
	if dialog_minigame != "":
		frozen = true
		await play_minigame(dialog_minigame)
		frozen = false
	if counts:
		_complete_target(target)


func _complete_target(target: String) -> void:
	done_targets[target] = true
	var o := _objective()
	for t in o["targets"]:
		if not done_targets.has(t):
			_refresh_objective()
			return
	_objective_finished(o["id"])
	objective_index += 1
	done_targets.clear()
	_refresh_objective()
	if not _objective().is_empty() and _objective()["type"] == "cutscene":
		_run_launch()


func _objective_finished(id: String) -> void:
	sfx("confirm", -10.0, 0.0, 0.0, true)         # objective complete
	if id == "explore":
		sfx("latch", -6.0, 0.0, 0.0, true)        # the hatch is closed and locked
		hatch_closed = true
		var closed := int(data["atlas"]["tile_names"]["hatch_closed"])
		for t in data["hatch_tiles"]:
			data["layers"]["ground"][int(t[1])][int(t[0])] = closed
			_set_tile(ground, int(t[0]), int(t[1]), closed)
		ui_zone.text = "The closeout crew seals the hatch behind you."


# ------------------------------------------------------------ mini-games ----

## Opens a mini-game from data/minigames.json as an overlay and waits for it to end.
## Returns {"id", "seconds", "mistakes"}.
func play_minigame(id: String) -> Dictionary:
	if minigame_data.is_empty():
		minigame_data = JSON.parse_string(FileAccess.get_file_as_string(MINIGAME_PATH))
	var cfg: Dictionary = minigame_data[id]
	var game: CanvasLayer = load(cfg["script"]).new()
	game.setup(id, cfg)
	add_child(game)
	if top_menu != null:                          # keep the mini-game's counter clear of PAUSE / EXIT
		game.progress.position.x = 310.0
		game.progress.size.x = 200.0
	if id == "comm_houston":
		sfx("radio", -8.0, 0.0, 1.5)              # the radio link to Houston comes up
	var result: Dictionary = await game.finished
	minigames_played[id] = true
	return result


## Mini-games listed under "prologue_minigames" in the level file play before the player gets control.
func _run_prologue() -> void:
	var ids: Array = data.get("prologue_minigames", [])
	if ids.is_empty():
		return
	frozen = true
	for id in ids:
		await play_minigame(str(id))
	frozen = false


# --------------------------------------------------------------- launch ----

func _run_launch() -> void:
	frozen = true
	player.visible = false
	var seat := Sprite2D.new()                       # the player, strapped into the centre couch
	seat.texture = load("res://assets/astronaut_seated.png")
	seat.centered = false
	seat.position = Vector2(11, 10) * ts
	add_child(seat)
	camera.reparent(self)
	camera.position = Vector2(12, 11) * ts
	ui_box.visible = true
	ui_title.text = "Launch Sequence"
	var events: Array = []
	for ev in data["launch_events"]:
		if not minigames_played.has(ev.get("skip_if_played", "")):
			events.append(ev)                     # the rest was already shown inside that mini-game
	for i in events.size():
		var ev: Dictionary = events[i]
		if float(ev["shake"]) > 0.0:
			sfx("rocket", -3.0, 4.0)              # engines; does not restart if already playing
		else:
			sfx_fade("rocket", 2.0)
		if str(ev["clock"]).begins_with("T+"):
			sky_target = clampf(float(i) / maxf(1.0, events.size() - 2.0), 0.0, 1.0)   # the sky darkens as we climb
		ui_clock.text = ev["clock"]
		ui_text.type(str(ev["text"]), false, "\n[E] Next")
		match ev.get("action", ""):
			"uncover_windows":
				sfx("latch", -8.0, 0.0, 0.0, true)        # the escape tower and its cover are thrown clear
				var open_id := int(data["atlas"]["tile_names"]["window_open"])
				for t in data["covered_window_tiles"]:
					_set_tile(ground, int(t[0]), int(t[1]), open_id)
			"orbit":
				in_orbit = true
				sky_target = 1.0
		launch_skip = false
		launch_running = true
		await _shake(float(ev["shake"]), 4.5)     # E cuts the wait short
		launch_running = false
	if sky != null and in_orbit:
		sky.altitude = maxf(sky.altitude, 0.9)    # skipped ahead: the sky is already black
	objective_index = data["objectives"].size()
	level_complete = true
	sfx_fade("rocket", 1.5)
	_refresh_objective()
	if ResourceLoader.exists(NEXT_LEVEL):
		ui_text.type(ui_text.plain, true, "\n\n[E] Continue to Level 2")


func _shake(strength: float, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not launch_skip:
		camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		await get_tree().create_timer(0.05, false).timeout     # false: this timer stops while the game is paused
		t += 0.05
	camera.offset = Vector2.ZERO


# ------------------------------------------------- sky, sound, menu, exit ----

## Blue sky with clouds behind the map. It sits on its own layer, so it stays
## still while the camera follows the astronaut.
func _build_sky() -> void:
	if not ResourceLoader.exists(SKY_SCRIPT):
		return
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	sky = load(SKY_SCRIPT).new()
	sky.size = Vector2(640, 360)
	layer.add_child(sky)


func _build_top_menu() -> void:
	if not ResourceLoader.exists(TOP_MENU_SCRIPT):
		return
	top_menu = load(TOP_MENU_SCRIPT).new()
	top_menu.in_progress = func() -> bool: return not level_complete
	add_child(top_menu)
	ui_clock.position = Vector2(548, 34)          # the mission clock moves below the PAUSE / EXIT buttons


## Plays a sound through the Sfx autoload, if the project has one.
func sfx(key: String, volume_db := 0.0, from := 0.0, duration := 0.0, restart := false) -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.play(key, volume_db, from, duration, restart)


func sfx_loop(key: String, volume_db := 0.0) -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.loop(key, volume_db)


func sfx_stop_all() -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.stop_all()


func sfx_stop(key: String) -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.stop(key)


func sfx_fade(key: String, seconds: float) -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.fade_out(key, seconds)


## Footsteps play only while the astronaut is actually walking.
func _update_footsteps(delta: float) -> void:
	var walking := moving and not frozen and not dialog_open and not level_complete
	if walking:
		idle_time = 0.0
		sfx("footsteps", FOOTSTEP_VOLUME, FOOTSTEP_START)
	else:
		idle_time += delta
		if idle_time >= FOOTSTEP_GRACE:
			sfx_stop("footsteps")


## After the launch: on to Level 2, which starts in space.
func continue_to_next_level() -> void:
	if not level_complete or not ResourceLoader.exists(NEXT_LEVEL):
		return
	sfx_stop_all()
	get_tree().change_scene_to_file(NEXT_LEVEL)
