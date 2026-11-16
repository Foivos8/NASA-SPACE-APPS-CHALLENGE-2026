extends "res://scripts/mission/mission_stage.gd"
## Design Your Mission - the launch from Earth.
## Three quick preparation checks, then the LAUNCH button: a countdown, ignition
## and the climb from blue sky to black space.
## Text: data/missions.json -> "launch".

const ASCENT_TIME := 7.5

var phase := "prep"               # prep -> count -> ascent -> done
var tasks: Array = []
var rows := {}                    # id -> {button, fill, time, seconds, done}
var active := ""                  # the check that is running
var count_left := 0.0
var shown_number := -1
var ascent := 0.0

var view: Control
var sky: Control
var ground: Control
var rocket: TextureRect
var flame: TextureRect
var count_label: Label
var status: Label
var launch_btn: Button
var rocket_home := Vector2(134, 22)


func _build() -> void:
	tasks = config["tasks"]
	view = add_view(Rect2(12, 70, 300, 240), 0.0)
	sky = view.get_node("Sky")
	ground = Control.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(ground)
	add_rect(Rect2(0, 206, 300, 10), Color(0.25, 0.47, 0.72), ground)          # sea
	add_rect(Rect2(0, 214, 300, 60), Color(0.36, 0.42, 0.34), ground)          # ground
	add_rect(Rect2(104, 210, 120, 6), Color(0.5, 0.52, 0.56), ground)          # pad
	add_art(ART + "launch_tower.png", Vector2(170, 4), 2.0, ground)
	flame = add_art(ART + "flame.png", rocket_home + Vector2(0, 190), 2.0, view)
	flame.visible = false
	rocket = add_art(ART + "saturn_v.png", rocket_home, 2.0, view)
	count_label = add_label("", 44, C_GOLD, Vector2(0, 80), 300, view)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_constant_override("outline_size", 10)

	add_panel(Rect2(322, 70, 306, 240), C_PANEL, C_BORDER)
	status = add_label("PRE-LAUNCH CHECKS", 11, C_GOLD, Vector2(332, 76), 286)
	for i in tasks.size():
		var t: Dictionary = tasks[i]
		var y := 98.0 + i * 44.0
		var b := add_button(str(t["label"]), Rect2(332, y, 196, 34), 10, press_task.bind(str(t["id"])))
		add_rect(Rect2(536, y + 11, 82, 12), Color(0.1, 0.11, 0.14))
		var fill := add_rect(Rect2(538, y + 13, 0, 8), C_OK)
		rows[t["id"]] = {"button": b, "fill": fill, "time": 0.0, "seconds": float(t["seconds"]), "done": false}
	launch_btn = add_button("LAUNCH", Rect2(332, 236, 286, 62), 22, press_launch)
	launch_btn.modulate = Color(0.6, 0.6, 0.6)
	_refresh()
	say(str(config["instructions"]), true)


func checks_done() -> int:
	var n := 0
	for id in rows:
		if rows[id]["done"]:
			n += 1
	return n


func ready_to_launch() -> bool:
	return checks_done() == rows.size()


func _refresh() -> void:
	progress.text = "Checks %d/%d" % [checks_done(), rows.size()]
	if ready_to_launch() and phase == "prep":
		status.text = "ALL CHECKS COMPLETE - GO FOR LAUNCH"
		status.add_theme_color_override("font_color", C_OK)
		launch_btn.modulate = Color.WHITE


## Starts one preparation check (one at a time).
func press_task(id: String) -> void:
	if phase != "prep" or active != "" or rows[id]["done"]:
		return
	active = id
	rows[id]["button"].disabled = true
	sfx("latch", -10.0)


func press_launch() -> void:
	if phase != "prep":
		return
	if not ready_to_launch():
		sfx("error", -10.0)
		say(str(config["locked_text"]), false)
		return
	phase = "count"
	count_left = float(config["countdown"])
	launch_btn.disabled = true
	for id in rows:
		rows[id]["button"].disabled = true
	status.text = "COUNTDOWN"
	say("The countdown has started.", true)


func _process(delta: float) -> void:
	super._process(delta)
	step(delta)


## Advances the scene; the tests call this directly.
func step(delta: float) -> void:
	match phase:
		"prep":
			if active == "":
				return
			var row: Dictionary = rows[active]
			row["time"] += delta
			row["fill"].size.x = 78.0 * clampf(row["time"] / row["seconds"], 0.0, 1.0)
			if row["time"] >= row["seconds"]:
				row["done"] = true
				row["button"].text = "DONE: " + row["button"].text
				for t in tasks:
					if t["id"] == active:
						say(str(t["info"]), true)
				active = ""
				sfx("confirm", -10.0)
				_refresh()
				if ready_to_launch():
					say(str(config["ready_text"]), true)
		"count":
			count_left -= delta
			var number := int(ceil(count_left))
			if number != shown_number and number > 0:
				shown_number = number
				count_label.text = str(number)
				sfx("tick", -4.0)
			if count_left <= 0.0:
				phase = "ascent"
				count_label.text = "LIFTOFF!"
				status.text = "LIFTOFF"
				flame.visible = true
				sfx("rocket", -3.0, 4.0, 0.0, false)
				say(str(config["liftoff_text"]), true)
		"ascent":
			ascent += delta
			var k := clampf(ascent / ASCENT_TIME, 0.0, 1.0)
			var rise := minf(ascent / 1.6, 1.0)
			var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() if k < 0.9 else Vector2.ZERO
			rocket.position = rocket_home + Vector2(0, -46.0 * rise * rise) + shake
			flame.position = rocket.position + Vector2(0, 190)
			flame.scale.y = 1.0 + 0.25 * sin(ascent * 40.0)
			if ascent > 1.2:                                   # the ground falls away and the sky darkens
				var speed := 30.0 + 220.0 * k
				ground.position.y += speed * delta
				sky.climb(speed * delta * 0.6)
				sky.altitude = clampf((ascent - 1.2) / (ASCENT_TIME - 2.2), 0.0, 1.0)
			if ascent > 2.0:
				count_label.text = ""
			if ascent >= ASCENT_TIME:
				phase = "done"
				flame.visible = false
				rocket.position = rocket_home + Vector2(0, -46)
				sfx_fade("rocket", 1.5)
				status.text = "IN ORBIT"
				complete(str(config["complete_title"]), str(config["complete_text"]))
