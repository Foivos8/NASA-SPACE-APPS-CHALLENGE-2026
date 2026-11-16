extends "res://scripts/minigames/minigame_base.gd"
## Mini-game 5: Launch Sequence.
## Six calls from Launch Control. The first ones (tasks marked "prep") are the
## final checks: the clock holds at its starting value while each is answered
## inside its own time window. Then the countdown runs in real time (15 seconds)
## with the remaining calls at fixed moments. A missed window puts the count on
## HOLD and the call is repeated. At zero the rocket lifts off.
## The procedure is simplified for the game (see the "fact" text in minigames.json).

const HOLD_TIME := 2.5
const LIFTOFF_TIME := 6.0
const CONTROLS := [
	["guidance", "GUIDANCE"], ["power", "POWER"], ["life_support", "LIFE SUPPORT"], ["talk", "PUSH TO TALK"],
	["in_range", "IN RANGE"], ["out_of_range", "OUT OF RANGE"], ["ack", "ACKNOWLEDGE"], ["go", "GO FOR LAUNCH"],
]
const LAMPS := [["guidance", "GUIDANCE"], ["power", "POWER"], ["life_support", "LIFE SUP"], ["comm", "COMM"], ["engines", "ENGINES"]]
const C_OFF := Color(0.25, 0.27, 0.32)

var tasks: Array = []
var t := 60.0                 # seconds to liftoff
var task_index := 0
var active := false
var state := "count"          # count | hold | liftoff
var hold_left := 0.0
var holds := 0
var liftoff_clock := 0.0
var switches_on := {}
var reading_bad := false      # true while one reading is out of range (task "range")
var bad_key := ""
var values := {"bus": 28.0, "cabin": 5.0}
var ignited := false
var anim := 0.0
var last_tick := -1            # last whole second that got a countdown pip
var prep_left := 0.0           # seconds left to answer the current "prep" call

var clock_label: Label
var prompt: Label
var bar: ColorRect
var lamps := {}
var value_labels := {}
var buttons := {}
var view: Control
var rocket: TextureRect
var flame: TextureRect
var smoke: Array = []
var banner: Label


func _build() -> void:
	tasks = config["tasks"]
	t = float(config.get("start_seconds", 60))
	# countdown clock
	add_panel(Rect2(12, 76, 112, 56), Color(0.04, 0.07, 0.06), C_BORDER)
	clock_label = add_label("", 22, C_OK, Vector2(12, 87), 112)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.pivot_offset = Vector2(56, 16)
	# Launch Control prompt with the time bar
	add_panel(Rect2(128, 76, 284, 56), C_PANEL, C_BORDER)
	prompt = add_label("", 9, Color.WHITE, Vector2(134, 78), 272)
	bar = ColorRect.new()
	bar.color = C_GOLD
	bar.position = Vector2(130, 127)
	bar.size = Vector2(0, 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	# indicators
	add_panel(Rect2(12, 136, 400, 78), Color(0.17, 0.19, 0.24), C_BORDER)
	add_label("INDICATORS", 9, C_DIM, Vector2(20, 138), 120)
	for i in LAMPS.size():
		var x := 22.0 + i * 78.0
		var l := ColorRect.new()
		l.position = Vector2(x, 156)
		l.size = Vector2(12, 12)
		l.color = C_OFF
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(l)
		lamps[LAMPS[i][0]] = l
		add_label(LAMPS[i][1], 8, Color.WHITE, Vector2(x + 16, 155), 62)
	var keys := ["bus", "cabin"]
	for i in keys.size():
		var c: Dictionary = config[keys[i]]
		var x := 20.0 + i * 198.0
		add_panel(Rect2(x, 174, 190, 34), Color(0.04, 0.07, 0.06), Color(0.3, 0.33, 0.4))
		add_label("%s  (normal %s-%s %s)" % [c["label"], _num(c, c["normal_min"]), _num(c, c["normal_max"]), c["unit"]],
				8, C_DIM, Vector2(x + 6, 176), 180)
		value_labels[keys[i]] = add_label("", 11, C_OK, Vector2(x + 6, 188), 180)
	# controls
	add_panel(Rect2(12, 218, 400, 90), Color(0.17, 0.19, 0.24), C_BORDER)
	add_label("CONTROLS", 9, C_DIM, Vector2(20, 220), 120)
	for i in CONTROLS.size():
		var b := Button.new()
		b.text = CONTROLS[i][1]
		b.clip_text = true                       # lets the button stay narrower than its caption
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 8)
		b.position = Vector2(18 + (i % 4) * 98, 238 + (i / 4) * 34)
		b.size = Vector2(94, 28)
		b.add_theme_stylebox_override("normal", make_style(C_CARD, C_BORDER))
		b.add_theme_stylebox_override("hover", make_style(C_CARD.lightened(0.15), C_GOLD))
		b.add_theme_stylebox_override("pressed", make_style(C_GOLD.darkened(0.6), C_GOLD))
		b.pressed.connect(press.bind(CONTROLS[i][0]))
		root.add_child(b)
		buttons[CONTROLS[i][0]] = b
	_build_view()
	lamps["engines"].color = C_OFF
	say(str(config.get("intro", "Launch Control: 'Apollo 13, this is Launch Control.'")), true)
	_refresh()


## The outside view: sky, pad, tower and the Saturn V.
func _build_view() -> void:
	view = Control.new()
	view.position = Vector2(420, 76)
	view.size = Vector2(208, 232)
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(view)
	var sky := ColorRect.new()
	sky.color = Color(0.43, 0.67, 0.88)
	sky.size = view.size
	view.add_child(sky)
	var sea := ColorRect.new()
	sea.color = Color(0.25, 0.47, 0.72)
	sea.position = Vector2(0, 196)
	sea.size = Vector2(208, 14)
	view.add_child(sea)
	add_sprite("launch_tower.png", Vector2(112, 6), 2.0, view)
	flame = add_sprite("flame.png", Vector2(60, 206), 2.0, view)
	flame.visible = false
	rocket = add_sprite("saturn_v.png", Vector2(60, 20), 2.0, view)
	for i in 6:
		var puff := ColorRect.new()
		puff.color = Color(0.93, 0.93, 0.9, 0.8)
		puff.size = Vector2(4, 4)
		puff.position = Vector2(74, 208)
		puff.visible = false
		view.add_child(puff)
		smoke.append(puff)
	var ground := ColorRect.new()
	ground.color = Color(0.36, 0.42, 0.34)
	ground.position = Vector2(0, 210)
	ground.size = Vector2(208, 22)
	view.add_child(ground)
	var pad := ColorRect.new()
	pad.color = Color(0.5, 0.52, 0.56)
	pad.position = Vector2(40, 208)
	pad.size = Vector2(130, 6)
	view.add_child(pad)
	add_panel(Rect2(420, 76, 208, 232), Color(0, 0, 0, 0), C_BORDER)
	banner = add_label("", 16, C_GOLD, Vector2(420, 84), 208)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _num(c: Dictionary, v: float) -> String:
	return ("%." + str(int(c["decimals"])) + "f") % v


func current_task() -> Dictionary:
	return tasks[task_index] if task_index < tasks.size() else {}


func _process(delta: float) -> void:
	super._process(delta)
	if not completed:
		step(delta)


## E / Enter / Space fast-forwards: first the text being typed, then the liftoff animation.
func _input(event: InputEvent) -> void:
	var was_done := completed
	super._input(event)
	if was_done or completed or not InputMap.has_action("interact") or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if feedback.is_typing():
		feedback.finish()
	elif state == "liftoff":
		liftoff_clock = LIFTOFF_TIME          # straight to the end of the climb


## Advances the countdown. Called every frame; tests call it directly.
func step(delta: float) -> void:
	anim += delta
	if state == "liftoff":
		liftoff_clock += delta
		_animate_liftoff()
		if liftoff_clock >= LIFTOFF_TIME:
			_finish()
		_refresh()
		return
	if state == "hold":
		hold_left -= delta
		if hold_left <= 0.0:
			state = "count"
			say("Launch Control: 'The count is resuming at T minus %d.'" % int(ceil(t)), true)
		_refresh()
		return
	# Final checks: the clock holds while each one is called and answered.
	var check := current_task()
	if not check.is_empty() and check.get("prep", false):
		if not active:
			_activate(check)
			prep_left = float(check["window"])
		else:
			prep_left -= delta
			if prep_left <= 0.0:
				_hold(check)
		_refresh()
		return
	t -= delta
	# "skip_waiting": the clock jumps straight to the next call instead of counting
	# down the quiet seconds in between. Each call keeps its own time window.
	if config.get("skip_waiting", false) and not active and task_index < tasks.size() \
			and t > float(tasks[task_index]["start"]):
		t = float(tasks[task_index]["start"])
	var second := int(ceil(t))
	if second <= 10 and second >= 1 and second != last_tick:
		last_tick = second
		sfx("tick", -10.0)                      # one pip a second for the last ten seconds
	var task := current_task()
	if not task.is_empty():
		if not active and t <= float(task["start"]):
			_activate(task)
		elif active and t <= float(task["deadline"]):
			_hold(task)
	if t <= 0.0 and task_index >= tasks.size():
		t = 0.0
		state = "liftoff"
		banner.text = "LIFTOFF!"
		say(str(config["liftoff_text"]), true)
	_refresh()


func _activate(task: Dictionary) -> void:
	active = true
	prompt.text = str(task["prompt"])
	if task["type"] == "range":
		reading_bad = randf() < 0.5
		bad_key = "bus" if randf() < 0.5 else "cabin"
		_roll_values()
	if task.get("ignite", false):
		ignited = true
		sfx("rocket", -3.0, 0.0, 0.0, false)      # engine ignition; the clip carries through liftoff


func _roll_values() -> void:
	for key in ["bus", "cabin"]:
		var c: Dictionary = config[key]
		values[key] = lerpf(float(c["normal_min"]), float(c["normal_max"]), randf_range(0.3, 0.7))
	if reading_bad:
		values[bad_key] = float(config[bad_key]["bad_low"])


## Missed window: the count stops and goes back to just before this call.
func _hold(task: Dictionary) -> void:
	holds += 1
	active = false
	state = "hold"
	hold_left = HOLD_TIME
	if task.get("prep", false):
		t = float(config.get("start_seconds", 60))        # the clock was holding anyway
	else:
		t = minf(float(task["start"]) + 2.0, float(config.get("start_seconds", 60)))
	prompt.text = ""
	last_tick = -1
	sfx("error", -6.0)
	if task["type"] == "switches":
		switches_on.clear()
	if task.get("ignite", false):
		ignited = false
		var manager := get_node_or_null("/root/Sfx")
		if manager != null:
			manager.stop("rocket")            # engines shut down on a hold
	say("%s HOLD! The count stops and recycles. Be ready for the call again." % task["timeout"], false)


func _task_done(task: Dictionary) -> void:
	active = false
	task_index += 1
	prompt.text = ""
	if task["id"] == "comm":
		lamps["comm"].color = C_OK
		sfx("walkie")
	sfx("confirm", -10.0)
	var next_task := current_task()
	if task.get("prep", false) and not next_task.is_empty() and not next_task.get("prep", false) and config.has("resume"):
		say("%s %s" % [task["done"], config["resume"]], true)      # last check done: the clock starts running
	else:
		say(str(task["done"]), true)


func _wrong(text: String, control: String) -> bool:
	mistakes += 1
	sfx("error", -10.0)
	say(text, false)
	var b: Button = buttons[control]
	var x := b.position.x
	var tw := create_tween()
	for dx in [3.0, -3.0, 2.0, 0.0]:
		tw.tween_property(b, "position:x", x + dx, 0.04)
	return false


## The player pressed a control. Returns true when it was the right one at the right time.
func press(control: String) -> bool:
	if completed or state == "liftoff":
		return false
	sfx("click", -10.0)
	if state == "hold" or not active:
		return _wrong(str(config["wrong_idle"]), control)
	var task := current_task()
	match task["type"]:
		"switches":
			if not (control in task["controls"]):
				return _wrong(str(config["wrong_control"]), control)
			switches_on[control] = true
			if switches_on.size() == task["controls"].size():
				_task_done(task)
			else:
				say("%s is ready. Keep going." % buttons[control].text, true)
			return true
		"range":
			if control != "in_range" and control != "out_of_range":
				return _wrong(str(config["wrong_control"]), control)
			if (control == "out_of_range") != reading_bad:
				var c: Dictionary = config[bad_key]
				if reading_bad:
					return _wrong("Look again: %s reads %s %s, below the normal %s to %s." % [c["label"].to_lower(),
							_num(c, values[bad_key]), c["unit"], _num(c, c["normal_min"]), _num(c, c["normal_max"])], control)
				return _wrong("Look again: both values are inside their normal range.", control)
			if reading_bad:
				reading_bad = false
				_roll_values()
				say(str(task["backup"]), true)
				return true
			_task_done(task)
			return true
		_:
			if control != task["control"]:
				return _wrong(str(config["wrong_control"]), control)
			_task_done(task)
			return true
	return false


func _refresh() -> void:
	# clock
	if state == "liftoff":
		clock_label.text = "T+00:%02d" % int(liftoff_clock)
		clock_label.add_theme_color_override("font_color", C_OK)
	else:
		clock_label.text = "T-00:%02d" % int(ceil(maxf(t, 0.0)))
		var col := C_OK if t > 20.0 else (C_GOLD if t > 10.0 else C_BAD)
		if state == "hold":
			clock_label.text = "HOLD" if fmod(anim, 0.6) < 0.35 else ""
			col = C_BAD
		clock_label.add_theme_color_override("font_color", col)
		clock_label.scale = Vector2.ONE * (1.0 + (0.06 * absf(sin(anim * 6.0)) if t <= 10.0 and state == "count" else 0.0))
	# time bar for the active call
	var task := current_task()
	if active and not task.is_empty():
		var left := 0.0
		if task.get("prep", false):
			left = clampf(prep_left / float(task["window"]), 0.0, 1.0)
		else:
			var span := float(task["start"]) - float(task["deadline"])
			left = clampf((t - float(task["deadline"])) / span, 0.0, 1.0)
		bar.size.x = 280.0 * left
		bar.color = C_GOLD if left > 0.35 else C_BAD
	else:
		bar.size.x = 0.0
	# lamps
	var blink := fmod(anim, 0.5) < 0.25
	for id in ["guidance", "power", "life_support"]:
		var done_before := task_index > 0
		if done_before or switches_on.has(id):
			lamps[id].color = C_OK
		else:
			lamps[id].color = C_GOLD if (active and blink) else C_GOLD.darkened(0.5)
	if lamps["comm"].color != C_OK:
		var calling: bool = active and not task.is_empty() and task["id"] == "comm"
		lamps["comm"].color = C_GOLD if (calling and blink) else C_GOLD.darkened(0.5)
	lamps["engines"].color = C_OK if state == "liftoff" else ((C_GOLD if blink else C_BAD) if ignited else C_OFF)
	# readings
	for key in value_labels:
		var c: Dictionary = config[key]
		var v: float = values[key] + (sin(anim * 3.0 + (1.0 if key == "bus" else 2.0)) * 0.04)
		var out: bool = v < float(c["normal_min"]) or v > float(c["normal_max"])
		value_labels[key].text = "%s %s" % [_num(c, v), c["unit"]]
		value_labels[key].add_theme_color_override("font_color", Color.WHITE if not out else C_GOLD)
	# engines on the pad before liftoff
	if state != "liftoff":
		flame.visible = ignited
		flame.scale = Vector2(1.0, 0.45 + 0.1 * sin(anim * 30.0))
		for i in 2:                                   # first smoke at the base of the pad
			smoke[i].visible = ignited
			smoke[i].size = Vector2(16, 6 + 2 * int(fmod(anim * 8.0 + i, 2.0)))
			smoke[i].position = Vector2(52.0 + i * 32.0, 208.0 - smoke[i].size.y)
		view.position = Vector2(420, 76) + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) if ignited else Vector2.ZERO)


func _animate_liftoff() -> void:
	var k := liftoff_clock / LIFTOFF_TIME
	var rise := 300.0 * k * k                               # slow at first, then faster
	rocket.position.y = 20.0 - rise
	flame.visible = true
	flame.scale = Vector2(1.0, 1.0 + 0.2 * sin(anim * 40.0))
	flame.position.y = 206.0 - rise
	view.position = Vector2(420, 76) + Vector2(randf_range(-2, 2), randf_range(-2, 2)) * (1.0 - k)
	for i in smoke.size():
		var puff: ColorRect = smoke[i]
		puff.visible = true
		var grow := minf(1.0, liftoff_clock / 2.5) * (10.0 + i * 5.0)
		puff.size = Vector2(grow * 1.5, grow)
		var side := -1.0 if i % 2 == 0 else 1.0
		puff.position = Vector2(76.0 + side * (6.0 + i * 8.0) - puff.size.x / 2.0, 212.0 - grow)
	banner.modulate.a = 0.6 + 0.4 * absf(sin(anim * 5.0))


func _finish() -> void:
	view.position = Vector2(420, 76)
	complete(str(config["complete_title"]), "%s\n\nHolds: %d   Wrong presses: %d   Time: %s\n\n%s" % [
			config["complete_text"], holds, mistakes, time_text(), config["fact"]])
