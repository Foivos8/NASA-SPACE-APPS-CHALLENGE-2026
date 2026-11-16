extends "res://scripts/minigames/minigame_base.gd"
## Mini-game 3: Instrument Inspection.
## Five analog gauges with simplified, fictional practice values. Click a gauge,
## report it NORMAL or ABNORMAL, then call Mission Control with the abnormal ones.

const SWEEP := 240.0          # needle travel in degrees; must match tools/gen_minigame_art.py
const GAUGE_W := 118.0
const GAUGE_X0 := 25.0
const DIAL_Y := 84.0


class Needle extends Control:
	var angle := 0.0          # degrees clockwise from 12 o'clock
	var wobble := 0.0

	func _process(delta: float) -> void:
		wobble += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var a := deg_to_rad(angle + sin(wobble * 5.0 + angle) * 1.2)
		var tip := c + Vector2(sin(a), -cos(a)) * (size.x * 0.36)
		draw_line(c, tip, Color(1, 0.62, 0.2), 2.0)
		draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color(0.85, 0.87, 0.9))


var gauges: Array = []        # config entries + runtime keys: value, abnormal, side, reported
var widgets: Array = []       # per gauge: {frame, needle, lamp, status}
var selected := -1
var detail: Label
var btn_normal: Button
var btn_abnormal: Button
var btn_call: Button
var attempts := {}            # gauge id -> wrong reports


func _build() -> void:
	_roll_readings()
	add_panel(Rect2(12, 76, 616, 142), Color(0.17, 0.19, 0.24), C_BORDER)      # the instrument panel
	for p in [Vector2(17, 81), Vector2(617, 81), Vector2(17, 207), Vector2(617, 207)]:
		var rivet := ColorRect.new()
		rivet.color = Color(0.6, 0.64, 0.7)
		rivet.position = p
		rivet.size = Vector2(4, 4)
		rivet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(rivet)
	for i in gauges.size():
		var g: Dictionary = gauges[i]
		var x := GAUGE_X0 + i * GAUGE_W
		var frame := add_panel(Rect2(x, 80, GAUGE_W - 6, 134), Color(0.1, 0.12, 0.17), Color(0.3, 0.33, 0.4))
		add_sprite("gauge_%s.png" % g["id"], Vector2(x + 16, DIAL_Y), 2.0)
		var needle := Needle.new()
		needle.position = Vector2(x + 16, DIAL_Y)
		needle.size = Vector2(80, 80)
		needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		needle.angle = -SWEEP / 2.0          # sweeps up from the stop when the game opens
		root.add_child(needle)
		create_tween().tween_property(needle, "angle", angle_for(g, g["value"]), 0.8 + i * 0.12) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var name_l := add_label(str(g["label"]), 10, Color.WHITE, Vector2(x, 166), GAUGE_W - 6)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var range_l := add_label("Normal %s-%s %s" % [fmt(g, g["normal_min"]), fmt(g, g["normal_max"]), g["unit"]],
				8, C_OK, Vector2(x, 181), GAUGE_W - 6)
		range_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lamp := ColorRect.new()
		lamp.position = Vector2(x + 8, 198)
		lamp.size = Vector2(8, 8)
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lamp)
		var status := add_label("", 8, C_DIM, Vector2(x + 20, 195), GAUGE_W - 28)
		widgets.append({"frame": frame, "needle": needle, "lamp": lamp, "status": status,
				"rect": Rect2(x, 80, GAUGE_W - 6, 134)})
	add_panel(Rect2(12, 224, 616, 84), C_PANEL, C_BORDER)
	detail = add_label("", 10, Color.WHITE, Vector2(22, 230), 596)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_normal = _button("Report NORMAL", Vector2(22, 276), 130, func(): report_selected(false))
	btn_abnormal = _button("Report ABNORMAL", Vector2(160, 276), 140, func(): report_selected(true))
	btn_call = _button("Call Mission Control", Vector2(452, 276), 166, call_mission_control)
	say("Lovell: 'Read each needle against its green band, Jack.'", true)
	_refresh()


func _button(text: String, pos: Vector2, width: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(width, 24)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_stylebox_override("normal", make_style(C_CARD, C_BORDER))
	b.add_theme_stylebox_override("hover", make_style(C_CARD.lightened(0.15), C_GOLD))
	b.add_theme_stylebox_override("pressed", make_style(C_GOLD.darkened(0.6), C_GOLD))
	b.add_theme_stylebox_override("disabled", make_style(Color(0.1, 0.11, 0.14), Color(0.25, 0.27, 0.32)))
	b.pressed.connect(action)
	root.add_child(b)
	return b


## Picks which gauges are out of range this time and gives every gauge a value.
func _roll_readings() -> void:
	gauges = []
	for g in config["gauges"]:
		gauges.append(g.duplicate())
	var ids: Array = range(gauges.size())
	ids.shuffle()
	var bad: Array = ids.slice(0, int(config.get("abnormal_count", 2)))
	for i in gauges.size():
		var g: Dictionary = gauges[i]
		var lo := float(g["normal_min"])
		var hi := float(g["normal_max"])
		g["reported"] = false
		g["abnormal"] = i in bad
		g["side"] = ""
		if not g["abnormal"]:
			g["value"] = lerpf(lo, hi, randf_range(0.25, 0.75))
			continue
		var can_low := lo > float(g["min"])
		var can_high := hi < float(g["max"])
		var low := can_low and (not can_high or randf() < 0.5)
		g["side"] = "low" if low else "high"
		if low:
			g["value"] = lerpf(lo, float(g["min"]), randf_range(0.35, 0.8))
		else:
			g["value"] = lerpf(hi, float(g["max"]), randf_range(0.35, 0.8))


func angle_for(g: Dictionary, value: float) -> float:
	return -SWEEP / 2.0 + SWEEP * (value - float(g["min"])) / (float(g["max"]) - float(g["min"]))


func fmt(g: Dictionary, value: float) -> String:
	return ("%." + str(int(g["decimals"])) + "f") % value


func inspected_count() -> int:
	var n := 0
	for g in gauges:
		if g["reported"]:
			n += 1
	return n


func _refresh() -> void:
	progress.text = "Inspected %d / %d" % [inspected_count(), gauges.size()]
	for i in gauges.size():
		var g: Dictionary = gauges[i]
		var w: Dictionary = widgets[i]
		var border := Color(0.3, 0.33, 0.4)
		if g["reported"]:
			w["lamp"].color = C_BAD if g["abnormal"] else C_OK
			w["status"].text = "ABNORMAL" if g["abnormal"] else "NORMAL"
			border = C_BAD if g["abnormal"] else C_OK
		else:
			w["lamp"].color = Color(0.35, 0.37, 0.42)
			w["status"].text = "not inspected"
		if i == selected:
			border = C_GOLD
		w["frame"].add_theme_stylebox_override("panel", make_style(Color(0.1, 0.12, 0.17), border))
	var open: bool = selected >= 0 and not gauges[selected]["reported"]
	btn_normal.disabled = not open
	btn_abnormal.disabled = not open
	btn_call.disabled = inspected_count() < gauges.size()
	if selected < 0:
		detail.text = "Click a gauge to inspect it."
	else:
		var g: Dictionary = gauges[selected]
		detail.text = "%s reads %s %s. Normal range: %s to %s %s.\n%s" % [
				g["label"], fmt(g, g["value"]), g["unit"], fmt(g, g["normal_min"]), fmt(g, g["normal_max"]), g["unit"],
				"Already reported." if g["reported"] else "What do you report?"]
	if inspected_count() == gauges.size() and not completed:
		detail.text = "All five gauges inspected. Call Mission Control to report the abnormal readings."


func select_gauge(i: int) -> void:
	if completed:
		return
	selected = i
	sfx("click", -12.0)
	_refresh()


func report_selected(abnormal: bool) -> void:
	if selected >= 0:
		report(selected, abnormal)


## The player's verdict on one gauge. Returns true when it is right.
func report(i: int, abnormal: bool) -> bool:
	var g: Dictionary = gauges[i]
	if completed or g["reported"]:
		return false
	if abnormal != g["abnormal"]:
		mistakes += 1
		sfx("error", -10.0)
		attempts[g["id"]] = int(attempts.get(g["id"], 0)) + 1
		if g["abnormal"]:
			say("Look again. %s %s is %s the normal range of %s to %s. Try again." % [
					fmt(g, g["value"]), g["unit"], "below" if g["side"] == "low" else "above",
					fmt(g, g["normal_min"]), fmt(g, g["normal_max"])], false)
		else:
			say("Look again. %s %s is inside the normal range of %s to %s. Try again." % [
					fmt(g, g["value"]), g["unit"], fmt(g, g["normal_min"]), fmt(g, g["normal_max"])], false)
		var frame: Panel = widgets[i]["frame"]
		var tw := create_tween()
		for dx in [4.0, -4.0, 2.0, 0.0]:
			tw.tween_property(frame, "position:x", widgets[i]["rect"].position.x + dx, 0.05)
		return false
	g["reported"] = true
	sfx("confirm", -10.0)
	if g["abnormal"]:
		say("Correct. %s is out of limits: %s. Note it for Mission Control." % [
				g["label"], g["low_text"] if g["side"] == "low" else g["high_text"]], true)
	else:
		say("Correct. %s is in the green." % g["label"], true)
	_refresh()
	return true


func call_mission_control() -> void:
	if completed or inspected_count() < gauges.size():
		say("Inspect all five gauges before you call.", false)
		return
	sfx("walkie")                               # keying the radio to report
	sfx("radio", -10.0, 0.0, 1.2)
	var lines := PackedStringArray()
	var found := PackedStringArray()
	for g in gauges:
		var verdict := "normal"
		if g["abnormal"]:
			verdict = "ABNORMAL (%s)" % (g["low_text"] if g["side"] == "low" else g["high_text"])
			found.append(str(g["label"]).to_lower())
		var tries := int(attempts.get(g["id"], 0))
		lines.append("%s: %s %s - %s%s" % [g["label"], fmt(g, g["value"]), g["unit"], verdict,
				"" if tries == 0 else "  (%d wrong %s)" % [tries, "try" if tries == 1 else "tries"]])
	var radio := "You: 'Houston, Odyssey. All other readings normal. Out of limits: %s.'" % " and ".join(found)
	complete(str(config["complete_title"]), "%s\n\n%s\n%s\n\nTime: %s   Wrong reports: %d\n\n%s" % [
			"\n".join(lines), radio, config["houston_reply"], time_text(), mistakes, config["fact"]])
	_refresh()


func _pointer_down(pos: Vector2) -> void:
	for i in widgets.size():
		if widgets[i]["rect"].has_point(pos):
			select_gauge(i)
			return
