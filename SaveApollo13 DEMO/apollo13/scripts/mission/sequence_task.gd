extends "res://scripts/mission/mission_stage.gd"
## Design Your Mission - building one part of the Mars research base.
## The player presses the assembly steps in the order that makes sense
## (what must be in place first?). Every correct step raises more of the
## building on its pad, so the progress is seen as well as counted.
## Text: data/missions.json -> minigames.build_*.

const VIEW := Rect2(12, 70, 300, 240)
const PIXEL := 3.0
const GROUND_Y := 198.0

var steps: Array = []
var done := 0                     # steps completed, in order
var shown := 0.0                  # how much of the building is drawn (0..1)
var buttons: Array = []           # index = step number
var clip: Control
var picture: TextureRect
var full := Vector2.ZERO
var origin := Vector2.ZERO
var bar_fill: ColorRect
var count_label: Label
var _finished := false


func _build() -> void:
	steps = config["steps"]
	var view := add_view(VIEW, 1.0)
	add_rect(Rect2(Vector2.ZERO, VIEW.size), Color(0.84, 0.63, 0.47), view)                       # dusty Mars sky
	add_rect(Rect2(0, GROUND_Y, VIEW.size.x, VIEW.size.y - GROUND_Y), Color(0.7, 0.38, 0.24), view)
	add_rect(Rect2(0, GROUND_Y, VIEW.size.x, 3), Color(0.83, 0.52, 0.36), view)
	add_rect(Rect2(40, GROUND_Y + 14, 220, 4), Color(1, 0.86, 0.3, 0.8), view)                    # the marked pad
	var tex: Texture2D = load(str(config["image"]))
	full = tex.get_size() * PIXEL
	origin = Vector2((VIEW.size.x - full.x) / 2.0, GROUND_Y + 22 - full.y).round()
	clip = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(clip)
	picture = add_art(str(config["image"]), Vector2.ZERO, PIXEL, clip)
	_draw_building()

	add_panel(Rect2(322, 70, 306, 240), C_PANEL, C_BORDER)
	count_label = add_label("", 10, C_GOLD, Vector2(332, 76), 286)
	add_rect(Rect2(332, 94, 286, 8), Color(0.1, 0.11, 0.14))
	bar_fill = add_rect(Rect2(333, 95, 0, 6), C_OK)
	buttons.resize(steps.size())
	for slot in steps.size():                           # shown out of order, so the player has to think
		var index := (slot + 1) % steps.size()
		buttons[index] = add_button(str(steps[index]), Rect2(332, 114 + slot * 46.0, 286, 38), 10, press.bind(index))
	_refresh()
	say(str(config["instructions"]), true)


func _refresh() -> void:
	count_label.text = "ASSEMBLY %d/%d" % [done, steps.size()]
	progress.text = "Built %d/%d" % [done, steps.size()]
	bar_fill.size.x = 284.0 * float(done) / steps.size()


## Shows the bottom `shown` part of the building: it grows upwards from the pad.
func _draw_building() -> void:
	var h := roundf(full.y * shown)
	clip.position = origin + Vector2(0, full.y - h)
	clip.size = Vector2(full.x, h)
	picture.position = Vector2(0, h - full.y)


## Step `index` (its position in the correct order) was pressed.
func press(index: int) -> void:
	if _finished or index < done:
		return
	if index != done:
		mistakes += 1
		sfx("error", -8.0)
		say(str(config["wrong_text"]), false)
		return
	done += 1
	var b: Button = buttons[index]
	b.disabled = true
	b.text = "DONE: " + b.text
	sfx("build", -4.0)
	say("Step %d of %d done: %s." % [done, steps.size(), str(steps[index]).to_lower()], true)
	_refresh()


func _process(delta: float) -> void:
	super._process(delta)
	step(delta)


## Raises the building towards the finished steps; the tests call this directly.
func step(delta: float) -> void:
	var target := float(done) / steps.size()
	if shown < target:
		shown = minf(target, shown + delta * 0.6)
		_draw_building()
	elif done == steps.size() and not _finished:
		_finished = true
		complete(str(config["complete_title"]), str(config["complete_text"]))
