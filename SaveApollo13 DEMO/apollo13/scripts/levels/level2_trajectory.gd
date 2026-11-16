extends "res://scripts/minigames/minigame_base.gd"
## Level 2 - Launch Sequence: the journey to the Moon.
## Starts where Level 1 ends, already in space. The player carries out each step
## with one button: fire the third stage, separate from the rocket, follow the
## trajectory, answer the master alarm, then learn how a free-return trajectory
## brings the crew home. Ends with the Service Module accident explained.
## Text: data/levels.json -> "level2". Map distances are not to scale.

const LevelUI := preload("res://scripts/ui/level_ui.gd")
const SkyBackground := preload("res://scripts/ui/sky_background.gd")
const Checklist := preload("res://scripts/ui/checklist_panel.gd")
const TopMenu := preload("res://scripts/ui/top_menu.gd")
const LEVEL_ART := "res://assets/levels/"

const VIEW := Rect2(12, 76, 418, 232)
const EARTH := Vector2(60, 120)            # map positions inside the view
const MOON := Vector2(350, 112)
const ACCIDENT_AT := 0.8                   # fraction of the outbound path (321,860 km of about 400,000)
const TLI_TIME := 4.0
const SEPARATE_TIME := 6.0
const COAST_TIME := 10.0
const RETURN_TIME := 7.0


## Draws the dotted trajectories on the map.
class TrajectoryMap extends Control:
	var outbound: PackedVector2Array
	var free_return: PackedVector2Array
	var flown := 0.0           # 0..1 of the outbound path already travelled
	var returned := 0.0        # 0..1 of the free-return path drawn

	func _draw() -> void:
		_dots(outbound, 1.0, Color(0.55, 0.6, 0.7, 0.55), 3)
		_dots(outbound, flown, Color(1, 1, 1), 2)
		_dots(free_return, returned, Color(0.45, 1, 0.6), 2)

	func _dots(points: PackedVector2Array, part: float, color: Color, every: int) -> void:
		var last := int(part * (points.size() - 1))
		for i in range(0, last + 1, every):
			draw_rect(Rect2(points[i].floor() - Vector2(1, 1), Vector2(2, 2)), color)


var text: Dictionary = {}
var stage := "orbit"
var st := 0.0                              # seconds in the current stage
var clock := 0.0
var flags := {}                            # one-off events already fired in this stage

var sky: Control
var checklist: Control
var top_menu: CanvasLayer
var view: Control
var action_btn: Button
var data_time: Label
var data_dist: Label

var close_group: Control                   # close-up of the spacecraft
var earth_big: TextureRect
var sivb: TextureRect
var lm: TextureRect
var csm: TextureRect
var exhaust: Array = []
var flash: ColorRect
var debris: Array = []                     # {node, vel}
var gas: Array = []
var alarm: Label

var map_group: Control
var map: TrajectoryMap
var ship: TextureRect
var ship_label: Label
var return_label: Label
var question: Label
var options: Array = []
var option_order: Array = []
var quiz_done := false
var mission_hours := 0.2
var distance_km := 185.0


func _ready() -> void:
	LevelUI.ensure_input()
	setup("level2", LevelUI.config("level2"))
	super._ready()


# ----------------------------------------------------------------- build ----

func _build() -> void:
	text = config["text"]
	progress.visible = false
	sky = SkyBackground.new()
	sky.size = Vector2(W, H)
	sky.altitude = 0.8                      # picks up where the climb in Level 1 ended
	root.add_child(sky)
	root.move_child(sky, 1)

	view = Control.new()
	view.position = VIEW.position
	view.size = VIEW.size
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(view)
	_build_close_up()
	_build_map()
	add_panel(VIEW, Color(0, 0, 0, 0), C_BORDER)

	checklist = Checklist.new()
	checklist.position = Vector2(438, 76)
	root.add_child(checklist)
	checklist.setup("LEVEL 2 CHECKLIST", config["checklist"], Vector2(190, 152), 22.0)

	add_panel(Rect2(438, 232, 190, 76), C_PANEL, C_BORDER)
	add_label("MISSION TIME", 8, C_DIM, Vector2(444, 234), 0)
	data_time = add_label("", 10, C_OK, Vector2(530, 232), 92)
	data_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_label("FROM EARTH", 8, C_DIM, Vector2(444, 250), 0)
	data_dist = add_label("", 10, C_OK, Vector2(530, 248), 92)
	data_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_btn = LevelUI.button(self, "", Rect2(444, 270, 178, 32), 9, press_action)

	top_menu = TopMenu.new()
	top_menu.in_progress = func() -> bool: return not completed
	add_child(top_menu)
	_enter("orbit")


func _sprite(file: String, pos: Vector2, pixel_scale: float, parent: Control) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(LEVEL_ART + file)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = pos
	t.size = t.texture.get_size() * pixel_scale
	t.pivot_offset = t.size / 2.0
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _rect(r: Rect2, c: Color, parent: Control) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = c
	cr.position = r.position
	cr.size = r.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	return cr


func _build_close_up() -> void:
	close_group = Control.new()
	close_group.size = VIEW.size
	close_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(close_group)
	earth_big = _sprite("earth.png", Vector2(-170, 96), 8.0, close_group)
	for i in 4:
		var e := _rect(Rect2(0, 0, 10, 6), Color(1, 0.8, 0.3) if i % 2 == 0 else Color(1, 0.55, 0.2), close_group)
		e.visible = false
		exhaust.append(e)
	sivb = _sprite("sivb.png", Vector2(46, 52), 3.0, close_group)
	lm = _sprite("lm.png", Vector2(160, 55), 3.0, close_group)
	lm.flip_h = true                        # docking port toward the Command Module
	lm.visible = false
	csm = _sprite("csm.png", Vector2(170, 55), 3.0, close_group)
	flash = _rect(Rect2(Vector2.ZERO, VIEW.size), Color(1, 1, 1, 0), close_group)
	alarm = add_label("MASTER ALARM", 12, C_BAD, Vector2(150, 8), 0, view)
	alarm.visible = false


func _bezier(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(p0.bezier_interpolate(c1, c2, p3, float(i) / n))
	return out


func _build_map() -> void:
	map_group = Control.new()
	map_group.size = VIEW.size
	map_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_group.visible = false
	view.add_child(map_group)
	map = TrajectoryMap.new()
	map.size = VIEW.size
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# out to the Moon, crossing the Earth-Moon line and passing below the Moon
	map.outbound = _bezier(EARTH + Vector2(6, -26), Vector2(150, 30), Vector2(270, 170), MOON + Vector2(0, 20), 90)
	# free return: the rest of the way out, around the far side, and back (a figure of eight)
	var fr := PackedVector2Array()
	var first := int(ACCIDENT_AT * 90)
	for i in range(first, 91):
		fr.append(map.outbound[i])
	for i in range(1, 30):
		var a := deg_to_rad(90.0 - 180.0 * i / 30.0)
		fr.append(MOON + Vector2(cos(a), sin(a)) * 20.0)
	fr.append_array(_bezier(MOON + Vector2(0, -20), Vector2(270, 54), Vector2(150, 214), EARTH + Vector2(6, 26), 90))
	map.free_return = fr
	map_group.add_child(map)
	_sprite("earth.png", EARTH - Vector2(24, 24), 1.0, map_group)
	_sprite("moon.png", MOON - Vector2(10, 10), 1.0, map_group)
	add_label("Earth", 9, Color.WHITE, EARTH + Vector2(-16, 28), 0, map_group)
	add_label("Moon", 9, Color.WHITE, MOON + Vector2(-12, -34), 0, map_group)
	add_label("Flight trajectory", 8, Color.WHITE, Vector2(118, 28), 0, map_group)
	return_label = add_label("Free-return trajectory", 8, C_OK, Vector2(150, 180), 0, map_group)
	return_label.visible = false
	ship = _sprite("ship.png", Vector2.ZERO, 2.0, map_group)
	ship_label = add_label("Apollo 13", 8, C_GOLD, Vector2.ZERO, 0, map_group)
	question = add_label("", 9, C_GOLD, Vector2(8, 180), 400, map_group)
	for i in 3:
		var b := LevelUI.button(self, "", Rect2(6 + i * 136, 196, 134, 32), 8, _on_option.bind(i), map_group)
		b.visible = false
		options.append(b)
	_place_ship(map.outbound[0])


func _place_ship(p: Vector2) -> void:
	ship.position = p.floor() - ship.size / 2.0
	ship_label.position = p.floor() + Vector2(8, -16)


# ----------------------------------------------------------------- stages ----

func _enter(new_stage: String) -> void:
	stage = new_stage
	st = 0.0
	flags.clear()
	match stage:
		"orbit":
			checklist.complete("start")
			_button("orbit_button", false)
			say(str(text["orbit"]), true)
		"tli":
			_button("", false)
			Sfx.play("rocket", -9.0, 8.0, TLI_TIME, true)   # the third-stage engine, felt through the hull
			say(str(text["tli"]), true)
		"tli_done":
			Sfx.fade_out("rocket", 0.6)
			checklist.complete("away")
			_button("separate_button", true)
			say(str(text["tli_done"]), true)
		"separate":
			_button("", false)
			say(str(text["separate"]), true)
		"separated":
			_button("coast_button", true)
			say(str(text["separate_done"]), true)
		"coast":
			_button("", false)
			close_group.visible = false
			map_group.visible = true
			say(str(text["coast"]), true)
		"bang":
			checklist.complete("trajectory")
			mission_hours = 55.915
			distance_km = 321860.0
			map_group.visible = false
			_show_damaged_close_up()
			_explode()
			Sfx.play("bang", -1.0, 0.0, 0.0, true)         # the oxygen tank bursts
			Sfx.play("vent", -14.0, 0.0, 0.0, true)        # gas venting from the Service Module
			_button("alarm_button", false)
			say(str(text["bang"]), false)
		"call":
			checklist.complete("explosion")
			_button("incident_button", false)
			Sfx.stop("alarm")
			Sfx.play("walkie", 0.0, 0.0, 0.0, true)
			Sfx.play("houston", 0.0, 0.0, 0.0, true)        # the recording of the report to Mission Control
			say("%s\n%s" % [text["call_1"], text["call_caption"]], true)
		"incident":
			alarm.visible = false
			Sfx.fade_out("houston", 0.8)
			if config.get("talk_after_accident", false):
				Sfx.play("talk", -12.0, 0.4, 9.0)           # Mission Control at work
			_button("home_button", false)
			say(str(text["incident"]), false)
		"freereturn":
			Sfx.fade_out("talk", 0.8)
			_button("", false)
			close_group.visible = false
			map_group.visible = true
			return_label.visible = true
			say(str(text["freereturn"]), true)
		"quiz":
			question.text = str(text["question"])
			option_order = range(text["options"].size())
			option_order.shuffle()
			for i in options.size():
				options[i].text = str(text["options"][option_order[i]]["text"])
				options[i].visible = true
				options[i].disabled = false
			say(str(text["freereturn_2"]), true)
		"end":
			pass


func _button(text_key: String, enabled: bool) -> void:
	action_btn.visible = text_key != ""
	action_btn.disabled = not enabled
	if text_key != "":
		action_btn.text = str(text[text_key])


## The single action button under the mission data. Returns true if it did something.
func press_action() -> bool:
	if completed or not action_btn.visible or action_btn.disabled:
		return false
	Sfx.play("click", -12.0, 0.0, 0.0, true)
	match stage:
		"orbit":
			_enter("tli")
		"tli_done":
			_enter("separate")
		"separated":
			_enter("coast")
		"bang":
			_enter("call")
		"call":
			_enter("incident")
		"incident":
			_enter("freereturn")
		_:
			return false
	return true


func _once(key: String) -> bool:
	if flags.has(key):
		return false
	flags[key] = true
	return true


func _process(delta: float) -> void:
	super._process(delta)
	if not completed:
		advance(delta)


## Runs the current stage. Called every frame; the tests call it directly.
func advance(delta: float) -> void:
	st += delta
	clock += delta
	sky.altitude = minf(1.0, sky.altitude + delta * 0.1)       # the last blue fades out
	match stage:
		"orbit":
			csm.position.y = 55.0 + sin(clock * 1.5) * 1.5
			sivb.position.y = 52.0 + sin(clock * 1.5) * 1.5
			if st >= 1.0:
				action_btn.disabled = false
		"tli":
			var k := clampf(st / TLI_TIME, 0.0, 1.0)
			for i in exhaust.size():
				var e: ColorRect = exhaust[i]
				e.visible = true
				var jet := randf_range(14.0, 34.0) - i * 4.0
				e.size = Vector2(jet, 6)
				e.position = Vector2(sivb.position.x - jet + 2, sivb.position.y + 14 + i * 5)
			# the Earth falls away behind
			earth_big.scale = Vector2.ONE * lerpf(1.0, 0.35, k)
			earth_big.position = Vector2(-170, 96).lerp(Vector2(-210, 150), k)
			mission_hours = lerpf(2.6, 2.7, k)
			distance_km = lerpf(330.0, 9000.0, k * k)
			close_group.position = Vector2(randf_range(-1, 1), randf_range(-1, 1))
			if st >= TLI_TIME:
				for e in exhaust:
					e.visible = false
				close_group.position = Vector2.ZERO
				_enter("tli_done")
		"separate":
			if _once("release"):
				Sfx.play("latch", -8.0, 0.0, 0.0, true)     # the spacecraft lets go of the third stage
			if st >= 4.0 and _once("dock"):
				Sfx.play("latch", -6.0, 0.0, 0.0, true)     # docking latches catch the Lunar Module
			_animate_separation(st)
			mission_hours = lerpf(3.1, 4.0, clampf(st / SEPARATE_TIME, 0.0, 1.0))
			distance_km = lerpf(20000.0, 32000.0, clampf(st / SEPARATE_TIME, 0.0, 1.0))
			if st >= SEPARATE_TIME:
				_enter("separated")
		"coast":
			var s := clampf(st / COAST_TIME, 0.0, 1.0) * ACCIDENT_AT
			map.flown = s
			map.queue_redraw()
			_place_ship(map.outbound[int(s * 90)])
			mission_hours = lerpf(4.0, 55.915, s / ACCIDENT_AT)
			distance_km = lerpf(32000.0, 321860.0, pow(s / ACCIDENT_AT, 0.8))
			if s / ACCIDENT_AT >= 0.5 and _once("mid"):
				say(str(text["coast_mid"]), true)
			if st >= COAST_TIME + 0.8:
				_enter("bang")
		"bang":
			if st >= 0.5 and _once("alarm"):
				Sfx.play("alarm", -8.0, 0.0, 0.0, true)     # master alarm, after the bang
			_animate_damage(delta)
			alarm.visible = fmod(clock, 0.5) < 0.3
			if st >= 1.2:
				action_btn.disabled = false
		"call":
			_animate_damage(delta)
			alarm.visible = fmod(clock, 0.5) < 0.3
			if st >= 4.6 and _once("reply"):
				say("%s\n%s" % [text["call_1"], text["call_2"]], true)
			if st >= 6.5:
				action_btn.disabled = false
		"incident":
			_animate_damage(delta)
			if st >= 6.0 and _once("second"):
				say(str(text["incident_2"]), true)
				action_btn.disabled = false
		"freereturn":
			var k := clampf(st / RETURN_TIME, 0.0, 1.0)
			map.flown = ACCIDENT_AT
			map.returned = k
			map.queue_redraw()
			_place_ship(map.free_return[int(k * (map.free_return.size() - 1))])
			if st >= RETURN_TIME + 1.5:
				_enter("quiz")
		"end":
			if st >= 3.0:
				_finish()
	data_time.text = "%03d:%02d" % [int(mission_hours), int(fmod(mission_hours, 1.0) * 60.0)]
	data_dist.text = "%s km" % _thousands(int(distance_km))


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


# ------------------------------------------------------------- animations ----

## Transposition and docking: the CSM moves off, turns around, docks with the
## Lunar Module and pulls it out of the third stage.
func _animate_separation(t: float) -> void:
	if t < 1.5:
		csm.position.x = lerpf(170.0, 262.0, t / 1.5)
	elif t < 2.7:
		var turn := (t - 1.5) / 1.2                       # 0..1: squash, flip, unsquash
		csm.flip_h = turn >= 0.5
		csm.scale.x = maxf(0.08, absf(cos(turn * PI)))
	elif t < 4.0:
		csm.scale.x = 1.0
		csm.flip_h = true
		lm.visible = true
		csm.position.x = lerpf(262.0, 214.0, (t - 2.7) / 1.3)
	else:
		var pull := clampf((t - 4.0) / 2.0, 0.0, 1.0)
		csm.position.x = 214.0 + 90.0 * pull
		lm.position.x = 160.0 + 90.0 * pull
		sivb.position.x = 46.0 - 110.0 * pull
		sivb.modulate.a = 1.0 - pull * 0.7
	earth_big.position.x = -210.0 - t * 4.0


func _show_damaged_close_up() -> void:
	close_group.visible = true
	earth_big.visible = false
	sivb.visible = false
	lm.visible = true
	lm.position = Vector2(110, 90)
	csm.position = Vector2(164, 90)
	csm.flip_h = true
	csm.scale = Vector2.ONE


## The oxygen tank bursts: flash, a blown-off panel, sparks, debris and venting gas.
func _explode() -> void:
	csm.texture = load(LEVEL_ART + "csm_damaged.png")
	flash.color.a = 0.95
	var origin := csm.position + Vector2(57, 18)          # the bay in the Service Module
	for i in 18:
		var spark := i < 12
		var size_px := 2.0 if spark else randf_range(4.0, 8.0)
		var color := Color(1, randf_range(0.5, 0.9), 0.2) if spark else Color(0.8, 0.82, 0.86)
		var node := _rect(Rect2(origin, Vector2(size_px, size_px)), color, close_group)
		var dir := Vector2.from_angle(randf_range(-PI, 0.0) if not spark else randf_range(0, TAU))
		debris.append({"node": node, "vel": dir * randf_range(30.0, 110.0), "spark": spark})
	for i in 10:
		var g := _rect(Rect2(origin, Vector2(3, 3)), Color(0.8, 0.9, 1.0, 0.8), close_group)
		gas.append({"node": g, "t": i * 0.18})


func _animate_damage(delta: float) -> void:
	flash.color.a = maxf(0.0, 0.95 - st * 2.0) if stage == "bang" else 0.0
	for d in debris:
		var n: ColorRect = d["node"]
		n.position += d["vel"] * delta
		n.color.a = maxf(0.0, n.color.a - delta * (0.9 if d["spark"] else 0.25))
	var origin := csm.position + Vector2(57, 18)
	for g in gas:                                             # oxygen venting into space
		g["t"] = fmod(g["t"] + delta, 1.8)
		var n: ColorRect = g["node"]
		n.position = origin + Vector2(g["t"] * 26.0, -10.0 - g["t"] * 38.0)
		n.color.a = 0.8 * (1.0 - g["t"] / 1.8)
	var wobble := sin(clock * 2.2) * (6.0 if st < 1.0 and stage == "bang" else 1.5)
	csm.position.y = 90.0 + wobble
	lm.position.y = 90.0 + wobble
	close_group.position = Vector2(randf_range(-3, 3), randf_range(-3, 3)) if (stage == "bang" and st < 0.7) else Vector2.ZERO


# ------------------------------------------------------------------- quiz ----

func _on_option(slot: int) -> void:
	answer(option_order[slot])


## Answers the free-return question with option `index` (as listed in levels.json).
func answer(index: int) -> bool:
	if stage != "quiz" or quiz_done or completed:
		return false
	var opt: Dictionary = text["options"][index]
	var slot := option_order.find(index)
	if not opt["ok"]:
		mistakes += 1
		Sfx.play("error", -10.0, 0.0, 0.0, true)
		options[slot].disabled = true
		say("Not quite. %s Try again." % opt["why"], false)
		return false
	quiz_done = true
	for b in options:
		b.disabled = true
	options[slot].add_theme_stylebox_override("disabled", make_style(C_OK.darkened(0.7), C_OK))
	checklist.complete("freereturn")
	say(str(opt["reply"]), true)
	_enter("end")
	return true


func _finish() -> void:
	checklist.complete("complete")
	LevelUI.completion(self, VIEW, str(config["complete_title"]), str(config["complete_text"]),
			"Click or press E to return to the main menu")


func dismiss() -> void:
	Sfx.stop_all()
	get_tree().change_scene_to_file(LevelUI.MENU_SCENE)
