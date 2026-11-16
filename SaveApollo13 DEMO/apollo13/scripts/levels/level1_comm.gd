extends "res://scripts/minigames/comm_houston.gd"
## Level 1 - Communication with Houston.
## Reuses the radio exchange logic of the Communication with Houston mini-game
## (typing calls, three replies, retry on a wrong reply) and gives it a level of
## its own: sky scene, astronaut, a nine-step checklist, the PAUSE / EXIT bar,
## sound, and an ending with the final countdown, liftoff and climb to space.
## Text and scenarios: data/levels.json -> "level1".

const LevelUI := preload("res://scripts/ui/level_ui.gd")
const SkyBackground := preload("res://scripts/ui/sky_background.gd")
const Checklist := preload("res://scripts/ui/checklist_panel.gd")
const TopMenu := preload("res://scripts/ui/top_menu.gd")

const VIEW := Rect2(12, 76, 418, 232)      # launch view (and the completion screen)
const COUNT_FROM := 10.0
const IGNITION_AT := 8.9                   # seconds before liftoff, as on the real Saturn V
const TOWER_CLEAR := 3.0                   # seconds after liftoff
const ASCENT_TIME := 13.0
const BAR_BASE := 106.0

var phase := "connect"                     # connect | comm | go | countdown | ascent | done
var sky: Control
var checklist: Control
var top_menu: CanvasLayer
var comm_group: Control
var action_btn: Button

var launch_view: Control
var launch_sky: Control
var ground_group: Control
var rocket: TextureRect
var flame: TextureRect
var smoke: Array = []
var clock_label: Label
var count := COUNT_FROM
var ignited := false
var ascent := 0.0
var shown := {}                            # captions already shown


func _ready() -> void:
	LevelUI.ensure_input()
	setup("level1", LevelUI.config("level1"))
	super._ready()


# ----------------------------------------------------------------- build ----

func _build() -> void:
	scenarios = config["scenarios"]
	progress.visible = false
	sky = SkyBackground.new()
	sky.size = Vector2(W, H)
	root.add_child(sky)
	root.move_child(sky, 1)                # above the plain background, below all text
	var band := _rect(Rect2(0, 0, W, 72), Color(0.03, 0.05, 0.1, 0.5), root)   # keeps the header readable over clouds
	root.move_child(band, 2)

	comm_group = Control.new()
	comm_group.size = Vector2(W, H)
	comm_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(comm_group)

	# --- the astronaut on the pad, the Saturn V in the distance ---
	_rect(Rect2(12, 212, 138, 8), Color(0.5, 0.52, 0.56), comm_group)
	_rect(Rect2(12, 220, 138, 2), Color(0.3, 0.32, 0.38), comm_group)
	add_sprite("launch_tower.png", Vector2(120, 108), 1.0, comm_group)
	add_sprite("saturn_v.png", Vector2(106, 116), 1.0, comm_group)
	for f in ["astronaut_base.png", "layer_suit.png", "layer_gloves.png", "layer_headset.png"]:
		add_sprite(f, Vector2(10, 70), 2.0, comm_group)

	# --- panel readouts ---
	add_panel(Rect2(12, 226, 138, 82), Color(0.17, 0.19, 0.24, 0.96), C_BORDER, comm_group)
	add_label("PANEL READOUTS", 8, C_DIM, Vector2(18, 228), 0, comm_group)
	var y := 242.0
	for r in config["readouts"]:
		add_panel(Rect2(17, y, 128, 19), Color(0.04, 0.07, 0.06), Color(0.3, 0.33, 0.4), comm_group)
		add_label(str(r["label"]), 8, C_DIM, Vector2(22, y + 3), 0, comm_group)
		var v := add_label(str(r["value"]), 10, C_OK, Vector2(84, y + 1), 56, comm_group)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		readouts[r["id"]] = v
		y += 21.0

	# --- radio set ---
	add_panel(Rect2(158, 76, 272, 34), Color(0.17, 0.19, 0.24, 0.96), C_BORDER, comm_group)
	add_label("S-BAND VOICE", 8, C_DIM, Vector2(164, 77), 0, comm_group)
	for i in BAR_COUNT:
		var b := _rect(Rect2(164 + i * 8, BAR_BASE - 3, 6, 3), C_OK, comm_group)
		bars.append(b)
	lamp_rx = _rect(Rect2(290, 82, 8, 8), Color(0.25, 0.27, 0.32), comm_group)
	add_label("RECEIVE", 8, C_DIM, Vector2(302, 79), 0, comm_group)
	lamp_tx = _rect(Rect2(290, 95, 8, 8), Color(0.25, 0.27, 0.32), comm_group)
	add_label("TRANSMIT", 8, C_DIM, Vector2(302, 92), 0, comm_group)

	# --- conversation ---
	add_panel(Rect2(158, 114, 272, 86), C_PANEL, C_BORDER, comm_group)
	history = add_label("", 8, Color(0.66, 0.72, 0.82), Vector2(164, 115), 260, comm_group)
	history.max_lines_visible = 3
	history.add_theme_constant_override("line_spacing", -2)
	tag = add_label("", 8, C_GOLD, Vector2(164, 153), 260, comm_group)
	incoming = add_label("", 9, Color.WHITE, Vector2(164, 165), 260, comm_group)
	incoming.add_theme_constant_override("line_spacing", -1)
	for i in 3:
		var btn := LevelUI.button(self, "", Rect2(158, 204 + i * 36, 272, 32), 9, _on_button.bind(i), comm_group)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.visible = false
		buttons.append(btn)
	action_btn = LevelUI.button(self, "PUSH TO TALK", Rect2(158, 240, 272, 32), 11, _on_action)

	# --- checklist and the pause / exit bar ---
	checklist = Checklist.new()
	checklist.position = Vector2(438, 76)
	root.add_child(checklist)
	checklist.setup("LEVEL 1 CHECKLIST", config["checklist"], Vector2(190, 232), 23.0)
	top_menu = TopMenu.new()
	top_menu.in_progress = func() -> bool: return not completed
	add_child(top_menu)
	say(str(config["connect_prompt"]), true)


func _rect(r: Rect2, c: Color, parent: Control) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = c
	cr.position = r.position
	cr.size = r.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	return cr


# ----------------------------------------------------------- radio phase ----

func _on_action() -> void:
	if phase == "connect":
		open_channel()
	elif phase == "go":
		start_countdown()


## The player keys the radio for the first time: the link to Houston comes up.
func open_channel() -> void:
	if phase != "connect":
		return
	phase = "comm"
	action_btn.visible = false
	Sfx.play("walkie", 0.0, 0.0, 0.0, true)
	Sfx.play("radio", -8.0, 0.0, 1.5, true)    # the radio establishes the connection
	say("Channel open. Houston is calling.", true)
	_next()


func reveal_now() -> void:
	var first_call := not revealed and index == 0 and phase == "comm"
	super.reveal_now()
	if first_call:
		checklist.complete("first")


func choose(option_index: int) -> bool:
	if phase != "comm" or completed or is_closing() or not revealed or answered:
		return false
	var ok := super.choose(option_index)        # (the radio sounds are played by the mini-game it extends)
	if ok:
		var check := str(current().get("check", ""))
		if check != "":
			checklist.complete(check)
	return ok


## Houston's closing call has arrived in full.
func _finish() -> void:
	checklist.complete("confirm")
	phase = "go"
	for btn in buttons:
		btn.visible = false
	action_btn.text = "APOLLO 13 IS GO - START THE COUNTDOWN"
	action_btn.visible = true
	say(str(config["go_prompt"]), true)
	if config.get("talk_during_poll", false):
		Sfx.play("talk", -10.0, 0.4, 6.0)       # voices in Mission Control during the poll


func _animate() -> void:
	var receiving := phase == "comm" and not revealed
	var noisy: bool = receiving and not is_closing() and current().get("static", false)
	for i in bars.size():
		var h := 3.0
		if receiving or tx_time > 0.0:
			h = randf_range(4.0, 20.0) if noisy else 4.0 + 15.0 * absf(sin(clock * 9.0 + i * 0.9)) * randf_range(0.6, 1.0)
		bars[i].size.y = h
		bars[i].position.y = BAR_BASE - h
		bars[i].color = C_BAD if noisy else (C_GOLD if tx_time > 0.0 else C_OK)
	lamp_rx.color = (C_BAD if noisy and randf() < 0.5 else C_OK) if receiving else Color(0.25, 0.27, 0.32)
	lamp_tx.color = C_GOLD if tx_time > 0.0 else Color(0.25, 0.27, 0.32)
	incoming.position.x = 164.0 + (randf_range(-1.5, 1.5) if noisy else 0.0)
	for id in readouts:
		var hot: bool = id == alert_id and fmod(clock, 0.8) < 0.4
		readouts[id].add_theme_color_override("font_color", C_BAD if hot else (C_GOLD if id == alert_id else C_OK))


# ---------------------------------------------------------- launch phase ----

func start_countdown() -> void:
	if phase != "go":
		return
	phase = "countdown"
	Sfx.stop("talk")
	Sfx.play("walkie", 0.0, 0.0, 0.0, true)
	comm_group.visible = false
	action_btn.visible = false
	_build_launch_view()
	_caption("countdown")


func _build_launch_view() -> void:
	launch_view = Control.new()
	launch_view.position = VIEW.position
	launch_view.size = VIEW.size
	launch_view.clip_contents = true
	launch_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(launch_view)
	launch_sky = SkyBackground.new()
	launch_sky.size = VIEW.size
	launch_view.add_child(launch_sky)
	ground_group = Control.new()
	ground_group.size = VIEW.size
	ground_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	launch_view.add_child(ground_group)
	_rect(Rect2(0, 194, 418, 14), Color(0.25, 0.47, 0.72), ground_group)
	add_sprite("launch_tower.png", Vector2(246, -2), 2.0, ground_group)
	flame = add_sprite("flame.png", Vector2(192, 200), 2.0, launch_view)
	flame.visible = false
	rocket = add_sprite("saturn_v.png", Vector2(192, 14), 2.0, launch_view)
	for i in 6:
		var puff := _rect(Rect2(208, 204, 4, 4), Color(0.93, 0.93, 0.9, 0.8), ground_group)
		puff.visible = false
		smoke.append(puff)
	_rect(Rect2(0, 208, 418, 24), Color(0.36, 0.42, 0.34), ground_group)
	_rect(Rect2(150, 204, 160, 6), Color(0.5, 0.52, 0.56), ground_group)
	add_panel(Rect2(6, 6, 112, 36), Color(0.04, 0.07, 0.06, 0.92), C_BORDER, launch_view)
	clock_label = add_label("", 20, C_OK, Vector2(6, 8), 112, launch_view)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_panel(VIEW, Color(0, 0, 0, 0), C_BORDER)


func _caption(key: String) -> void:
	if shown.has(key):
		return
	shown[key] = true
	say(str(config["launch_captions"][key]), true)


func _process(delta: float) -> void:
	super._process(delta)
	if not completed:
		advance(delta)


## Runs the countdown and the climb. Called every frame; the tests call it directly.
func advance(delta: float) -> void:
	if phase == "countdown":
		_tick_countdown(delta)
	elif phase == "ascent":
		_tick_ascent(delta)


func _tick_countdown(delta: float) -> void:
	count -= delta
	clock_label.text = "T-00:%02d" % int(ceil(maxf(count, 0.0)))
	clock_label.add_theme_color_override("font_color", C_GOLD if count > 5.0 else C_BAD)
	if not ignited and count <= IGNITION_AT:
		ignited = true
		Sfx.play("rocket")                      # engines ignite; the same clip carries through liftoff
		_caption("ignition")
	if ignited:
		flame.visible = true
		flame.scale = Vector2(1.0, 0.4 + 0.1 * sin(clock * 30.0))
		launch_view.position = VIEW.position + Vector2(randf_range(-1, 1), randf_range(-1, 1))
		_puff(minf(1.0, (IGNITION_AT - count) / 4.0) * 0.5)
	if count <= 0.0:
		checklist.complete("countdown")
		phase = "ascent"
		ascent = 0.0
		_caption("liftoff")


func _puff(amount: float) -> void:
	for i in smoke.size():
		var p: ColorRect = smoke[i]
		p.visible = true
		var grow := amount * (14.0 + i * 7.0)
		p.size = Vector2(grow * 1.5, grow)
		var side := -1.0 if i % 2 == 0 else 1.0
		p.position = Vector2(208.0 + side * (8.0 + i * 10.0) * amount * 2.0 - p.size.x / 2.0, 208.0 - grow)


func _tick_ascent(delta: float) -> void:
	ascent += delta
	var k := clampf(ascent / ASCENT_TIME, 0.0, 1.0)
	clock_label.text = "T+00:%02d" % int(ascent)
	clock_label.add_theme_color_override("font_color", C_OK)
	# the rocket first rises in the frame, then the "camera" follows it up
	var rise := 40.0 * sin(PI * clampf(ascent / 6.0, 0.0, 1.0))
	rocket.position.y = 14.0 - rise
	flame.visible = true
	flame.position.y = 200.0 - rise
	flame.scale = Vector2(1.0, 1.0 + 0.2 * sin(clock * 40.0))
	ground_group.position.y = maxf(0.0, 30.0 * ascent * ascent - rise)
	_puff(1.0)
	var alt := smoothstep(2.5, ASCENT_TIME - 1.0, ascent)
	launch_sky.altitude = alt
	sky.altitude = alt
	launch_sky.climb(delta * 40.0 * (1.0 + ascent))
	sky.climb(delta * 40.0 * (1.0 + ascent))
	launch_view.position = VIEW.position + Vector2(randf_range(-2, 2), randf_range(-2, 2)) * (1.0 - k)
	if ascent >= TOWER_CLEAR:
		checklist.complete("launch")
		_caption("tower")
	if ascent >= 5.5:
		_caption("climb")
	if ascent >= 9.0:
		_caption("high")
	if ascent >= ASCENT_TIME:
		phase = "done"
		launch_view.position = VIEW.position
		flame.visible = false
		checklist.complete("space")
		_caption("space")
		Sfx.fade_out("rocket", 2.0)
		LevelUI.completion(self, VIEW, str(config["complete_title"]), str(config["complete_text"]),
				"Click or press E to continue to Level 2")


## Leaving the completion screen: straight on to Level 2, already in space.
func dismiss() -> void:
	Sfx.stop_all()
	get_tree().change_scene_to_file(LevelUI.LEVEL2_SCENE)
