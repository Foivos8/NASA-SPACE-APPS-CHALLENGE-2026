extends "res://scripts/minigames/minigame_base.gd"
## Mini-game 4: Communication with Houston.
## Mission Control calls, the player picks the best of three replies. A wrong
## reply explains why and can be retried. Scenarios come from data/minigames.json.

const TYPE_SPEED := 55.0          # characters per second for incoming calls
const NEXT_DELAY := 1.8           # pause after a correct reply
const BAR_COUNT := 14

var scenarios: Array = []
var index := -1                   # current scenario; scenarios.size() means the closing call
var revealed := false
var answered := false
var typed := 0.0
var wait_next := -1.0
var option_order: Array = []      # button slot -> option index in the scenario

var history: Label
var tag: Label
var incoming: Label
var buttons: Array = []
var bars: Array = []
var lamp_rx: ColorRect
var lamp_tx: ColorRect
var readouts := {}                # id -> {label: Label, text: String}
var alert_id := ""
var tx_time := 0.0
var clock := 0.0


func _build() -> void:
	scenarios = config["scenarios"]
	# --- radio set (left) ---
	add_panel(Rect2(12, 76, 190, 232), Color(0.17, 0.19, 0.24), C_BORDER)
	add_label("S-BAND VOICE", 9, C_DIM, Vector2(22, 82), 170)
	add_panel(Rect2(22, 98, 170, 62), Color(0.04, 0.07, 0.06), Color(0.3, 0.33, 0.4))
	for i in BAR_COUNT:
		var b := ColorRect.new()
		b.color = C_OK
		b.size = Vector2(8, 4)
		b.position = Vector2(28 + i * 11.5, 150)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(b)
		bars.append(b)
	lamp_rx = _lamp(Vector2(26, 168), "RECEIVE")
	lamp_tx = _lamp(Vector2(112, 168), "TRANSMIT")
	add_label("PANEL READOUTS", 9, C_DIM, Vector2(22, 190), 170)
	var y := 206.0
	for r in config["readouts"]:
		add_panel(Rect2(22, y, 170, 28), Color(0.04, 0.07, 0.06), Color(0.3, 0.33, 0.4))
		add_label(str(r["label"]), 9, C_DIM, Vector2(28, y + 6), 90)
		var v := add_label(str(r["value"]), 11, C_OK, Vector2(112, y + 4), 76)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		readouts[r["id"]] = v
		y += 32.0
	# --- conversation (right) ---
	add_panel(Rect2(210, 76, 418, 124), C_PANEL, C_BORDER)
	history = add_label("", 9, Color(0.62, 0.68, 0.78), Vector2(220, 80), 398)
	history.max_lines_visible = 4
	tag = add_label("", 9, C_GOLD, Vector2(220, 136), 398)
	incoming = add_label("", 10, Color.WHITE, Vector2(220, 150), 398)
	for i in 3:
		var btn := Button.new()
		btn.position = Vector2(210, 204 + i * 36)
		btn.size = Vector2(418, 32)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_stylebox_override("normal", make_style(C_CARD, C_BORDER))
		btn.add_theme_stylebox_override("hover", make_style(C_CARD.lightened(0.15), C_GOLD))
		btn.add_theme_stylebox_override("pressed", make_style(C_GOLD.darkened(0.6), C_GOLD))
		btn.add_theme_stylebox_override("disabled", make_style(Color(0.1, 0.11, 0.14), Color(0.25, 0.27, 0.32)))
		btn.pressed.connect(_on_button.bind(i))
		root.add_child(btn)
		buttons.append(btn)
	say("Put on the headset. Mission Control is calling.", true)
	_next()


func _lamp(pos: Vector2, caption: String) -> ColorRect:
	var l := ColorRect.new()
	l.position = pos
	l.size = Vector2(10, 10)
	l.color = Color(0.25, 0.27, 0.32)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	add_label(caption, 8, C_DIM, pos + Vector2(14, -2), 70)
	return l


func is_closing() -> bool:
	return index >= scenarios.size()


func current() -> Dictionary:
	return {} if is_closing() else scenarios[index]


## Starts the next incoming call (or the closing confirmation).
func _next() -> void:
	index += 1
	wait_next = -1.0
	revealed = false
	answered = false
	typed = 0.0
	incoming.visible_characters = 0
	for btn in buttons:
		btn.visible = not is_closing()
		btn.disabled = true
		btn.text = ""
	if is_closing():
		progress.text = "Link confirmed"
		tag.text = "INCOMING - HOUSTON (CAPCOM)"
		incoming.text = str(config["closing"])
		_incoming_sound()
		return
	var s := current()
	progress.text = "Call %d / %d" % [index + 1, scenarios.size()]
	tag.text = "INCOMING - HOUSTON (CAPCOM)   [%s]" % s["tag"]
	incoming.text = str(s["message"])
	for id in s.get("set_readout", {}):
		readouts[id].text = str(s["set_readout"][id])
	alert_id = str(s.get("alert", ""))
	option_order = range(s["options"].size())
	option_order.shuffle()
	for i in buttons.size():
		buttons[i].text = "  " + str(s["options"][option_order[i]]["text"])
	_incoming_sound()


## One intercom beep before each call; radio static on a broken transmission.
## The first call has no beep: the channel has only just been opened.
func _incoming_sound() -> void:
	if not is_closing() and current().get("static", false):
		sfx("radio", -6.0, 2.0, 2.2)
	elif is_closing() or index > 0:
		sfx("beeps", -4.0, 0.0, 0.75)


func _process(delta: float) -> void:
	super._process(delta)
	clock += delta
	tx_time = maxf(0.0, tx_time - delta)
	if not revealed:
		typed += delta * TYPE_SPEED
		incoming.visible_characters = int(typed)
		if int(typed) >= incoming.text.length():
			reveal_now()
	if wait_next >= 0.0 and not completed:
		wait_next -= delta
		if wait_next < 0.0:
			skip_wait()
	_animate()


## Radio effects: level bars, RECEIVE / TRANSMIT lamps, static, flashing alert readout.
func _animate() -> void:
	var receiving := not revealed
	var noisy: bool = receiving and not is_closing() and current().get("static", false)
	for i in bars.size():
		var h := 3.0
		if receiving or tx_time > 0.0:
			h = randf_range(6.0, 44.0) if noisy else 8.0 + 30.0 * absf(sin(clock * 9.0 + i * 0.9)) * randf_range(0.6, 1.0)
		bars[i].size.y = h
		bars[i].position.y = 154.0 - h
		bars[i].color = C_BAD if noisy else (C_GOLD if tx_time > 0.0 else C_OK)
	lamp_rx.color = (C_BAD if noisy and randf() < 0.5 else C_OK) if receiving else Color(0.25, 0.27, 0.32)
	lamp_tx.color = C_GOLD if tx_time > 0.0 else Color(0.25, 0.27, 0.32)
	incoming.position.x = 220.0 + (randf_range(-1.5, 1.5) if noisy else 0.0)
	for id in readouts:
		var hot: bool = id == alert_id and fmod(clock, 0.8) < 0.4
		readouts[id].add_theme_color_override("font_color", C_BAD if hot else (C_GOLD if id == alert_id else C_OK))


## Shows the whole incoming call at once and unlocks the replies.
func reveal_now() -> void:
	if revealed:
		return
	revealed = true
	incoming.visible_characters = -1
	if is_closing():
		_finish()
		return
	for btn in buttons:
		btn.disabled = false


func _on_button(slot: int) -> void:
	choose(option_order[slot])


## Picks reply `option_index` (index into the scenario's options). Returns true when it is the right one.
func choose(option_index: int) -> bool:
	if completed or is_closing() or not revealed or answered:
		return false
	var s := current()
	var opt: Dictionary = s["options"][option_index]
	var slot := option_order.find(option_index)
	tx_time = 0.9
	sfx("walkie")                               # the astronaut keys the radio
	if not opt["ok"]:
		mistakes += 1
		sfx("error", -14.0)
		buttons[slot].disabled = true
		say("Not the best reply. %s Try again." % opt["why"], false)
		return false
	answered = true
	for btn in buttons:
		btn.disabled = true
	buttons[slot].add_theme_stylebox_override("disabled", make_style(C_OK.darkened(0.7), C_OK))
	var reply := str(opt.get("reply", ""))
	history.text = "YOU: %s%s" % [opt["text"], "" if reply == "" else "\nHOUSTON: " + reply]
	say("Good reply." if reply == "" else "Houston: '%s'" % reply, true)
	if alert_id != "":
		alert_id = ""
	wait_next = NEXT_DELAY
	return true


## Moves on to the next call without waiting out the pause.
func skip_wait() -> void:
	if completed or not answered:
		return
	for btn in buttons:
		btn.add_theme_stylebox_override("disabled", make_style(Color(0.1, 0.11, 0.14), Color(0.25, 0.27, 0.32)))
	_next()


func _finish() -> void:
	say("Houston: '%s'" % config["closing"], true)
	complete(str(config["complete_title"]), "Houston: '%s'\n\n%s\n\nTime: %s   Wrong replies: %d\n\n%s" % [
			config["closing"], config["complete_text"], time_text(), mistakes, config["fact"]])


func _pointer_down(_pos: Vector2) -> void:
	if not revealed and not is_closing():
		reveal_now()          # click anywhere to skip the typing
