extends "res://scripts/mission/mission_stage.gd"
## Design Your Mission - arrivals and departures.
## One screen plays five kinds of scene, chosen by config["kind"]:
##   land     approach a world, then brake down to its surface (Moon, Mars)
##   takeoff  lift off from that surface
##   dock     close in on the damaged satellite and latch on
##   undock   back away from the repaired satellite
##   earth    re-entry, parachutes and splashdown
## The approach plays by itself while the text explains it; the player then
## starts the manoeuvre with the button.
## Text: data/missions.json -> missions.<id>.arrive / depart, and "earth_landing".

const VIEW := Rect2(12, 70, 616, 236)
const LINE_TIME := 3.2
const ACTION_TIME := 4.5
const GROUND_Y := 180.0

var kind := ""
var phase := "approach"           # approach -> wait -> action -> done
var st := 0.0                     # seconds in the current phase
var lines: Array = []
var line_shown := -1
var approach_time := 3.0

var view: Control
var sky: Control
var body: TextureRect             # the Moon, Mars or Earth seen from space
var body_center := Vector2(450, 112)
var body_tex_size := Vector2.ONE
var body_scale := 2.0
var ship: TextureRect
var surface: Control              # ground, lander and dust (land / takeoff)
var lander: TextureRect
var flame: TextureRect
var dust: Array = []
var satellite: TextureRect
var capsule: Control              # capsule + parachute (earth)
var chute: TextureRect
var sea: ColorRect
var glow: ColorRect
var action_btn: Button
var _touched := false


func _build() -> void:
	kind = str(config["kind"])
	lines = config.get("lines", [])
	approach_time = maxf(2.5, LINE_TIME * lines.size())
	view = add_view(VIEW, 1.0)
	sky = view.get_node("Sky")
	match kind:
		"land":
			_build_space_body(str(config["body"]), float(config["body_scale"]))
			_build_ship(Vector2(30, 150), 2.0)
			_build_surface(false)
			surface.visible = false
		"takeoff":
			_build_surface(true)
		"dock", "undock":
			add_art(MISSION_ART + "earth_big.png", Vector2(-90, 110), 3.0, view)
			satellite = add_art(MISSION_ART + ("satellite_broken.png" if kind == "dock" else "satellite_fixed.png"), Vector2(360, 40), 3.0, view)
			_build_ship(Vector2(-110 if kind == "dock" else 252, 86), 3.0)
		"earth":
			_build_space_body("res://assets/levels/earth.png", 2.0)
			glow = add_rect(Rect2(0, 0, 40, 26), Color(1, 0.55, 0.2, 0.0), view)
			_build_ship(Vector2(30, 150), 2.0)
			ship.texture = load(MISSION_ART + "capsule.png")
			ship.size = ship.texture.get_size() * 2.0
			sea = add_rect(Rect2(0, 196, VIEW.size.x, 40), Color(0.2, 0.42, 0.7), view)
			sea.visible = false
			capsule = Control.new()
			capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			capsule.visible = false
			view.add_child(capsule)
			chute = add_art(MISSION_ART + "parachute.png", Vector2(0, 0), 3.0, capsule)
			add_art(MISSION_ART + "capsule.png", Vector2(36, 86), 3.0, capsule)
	action_btn = add_button(str(config["button"]), Rect2(VIEW.position.x + VIEW.size.x / 2.0 - 110, VIEW.end.y - 40, 220, 30), 12, press_action)
	action_btn.visible = false
	progress.text = "Approach"
	if kind == "takeoff" or kind == "undock":
		progress.text = "Ready"
	step(0.0)


func _build_space_body(path: String, pixel_scale: float) -> void:
	body = add_art(path, Vector2.ZERO, pixel_scale, view)
	body_tex_size = body.texture.get_size()
	body_scale = pixel_scale
	_scale_body(pixel_scale)


func _scale_body(pixel_scale: float) -> void:
	body.size = (body_tex_size * pixel_scale).round()
	body.position = (body_center - body.size / 2.0).round()


func _build_ship(pos: Vector2, pixel_scale: float) -> void:
	ship = add_art(MISSION_ART + "rocket_side.png", pos, pixel_scale, view)


func _build_surface(landed: bool) -> void:
	surface = Control.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(surface)
	if config.has("sky"):                                              # Mars has a thin, dusty sky
		add_rect(Rect2(0, 0, VIEW.size.x, GROUND_Y), Color(color_of(config["sky"], Color.BLACK), 0.85), surface)
	var ground_color := color_of(config.get("ground", []), Color(0.6, 0.6, 0.62))
	var dark := color_of(config.get("ground_dark", []), Color(0.45, 0.45, 0.5))
	add_rect(Rect2(0, GROUND_Y, VIEW.size.x, VIEW.size.y - GROUND_Y), ground_color, surface)
	add_rect(Rect2(0, GROUND_Y, VIEW.size.x, 3), ground_color.lightened(0.2), surface)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:                                                       # craters and stones
		var w := rng.randf_range(10, 44)
		add_rect(Rect2(rng.randf_range(0, VIEW.size.x - w), rng.randf_range(GROUND_Y + 8, VIEW.size.y - 6), w, 3), dark, surface)
	flame = add_art(ART + "flame.png", Vector2.ZERO, 2.0, surface)
	flame.visible = false
	lander = add_art(MISSION_ART + "lander.png", Vector2(244, _lander_rest_y() if landed else -140.0), 2.0, surface)
	for i in 8:
		var d := add_rect(Rect2(308, GROUND_Y + 4, 6, 4), Color(ground_color.lightened(0.3), 0.0), surface)
		dust.append({"node": d, "dir": (-1.0 if i % 2 == 0 else 1.0) * (0.5 + i * 0.12)})


func _lander_rest_y() -> float:
	return GROUND_Y + 12.0 - 128.0


func press_action() -> void:
	if phase != "wait":
		return
	phase = "action"
	st = 0.0
	action_btn.visible = false
	progress.text = "In progress"
	say(str(config["action_text"]), true)
	match kind:
		"land":
			body.visible = false
			ship.visible = false
			surface.visible = true
			sfx("rocket", -12.0, 4.0, 0.0, false)
		"takeoff":
			sfx("rocket", -8.0, 4.0, 0.0, false)
		"dock", "undock":
			sfx("thruster", -8.0)
		"earth":
			body.visible = false
			ship.visible = false
			glow.visible = false
			sea.visible = true
			capsule.visible = true
			sfx("latch", -6.0)


func _process(delta: float) -> void:
	super._process(delta)
	step(delta)


## Advances the scene; the tests call this directly.
func step(delta: float) -> void:
	st += delta
	match phase:
		"approach":
			var shown := mini(int(st / LINE_TIME), lines.size() - 1)
			if shown != line_shown and shown >= 0:
				line_shown = shown
				say(str(lines[shown]), true)
			_approach(clampf(st / approach_time, 0.0, 1.0))
			if st >= approach_time:
				phase = "wait"
				action_btn.visible = true
				progress.text = "Ready"
				sfx("beeps", -14.0, 0.0, 0.5)
		"wait":
			action_btn.modulate = Color(1, 1, 1, 0.75 + 0.25 * sin(st * 6.0))
		"action":
			_action(clampf(st / ACTION_TIME, 0.0, 1.0), delta)
			if st >= ACTION_TIME:
				phase = "done"
				sfx_fade("rocket", 1.0)
				progress.text = "Complete"
				complete(str(config["complete_title"]), str(config["complete_text"]))


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


func _approach(k: float) -> void:
	var e := _ease(k)
	match kind:
		"land":
			_scale_body(roundf(lerpf(body_scale, body_scale * 2.5, e) * 4.0) / 4.0)
			ship.position = Vector2(lerpf(30, 250, e), 150 - 30 * e).round()
		"dock":
			ship.position = Vector2(lerpf(-110, 150, e), 86).round()
		"earth":
			_scale_body(roundf(lerpf(2.0, 4.5, e) * 4.0) / 4.0)
			ship.position = Vector2(lerpf(30, 300, e), 150 - 34 * e).round()
			glow.position = ship.position + Vector2(-34, 6)
			glow.color.a = clampf((k - 0.55) * 2.0, 0.0, 0.8) * (0.7 + 0.3 * sin(st * 30.0))


func _action(k: float, delta: float) -> void:
	var e := _ease(k)
	match kind:
		"land":
			var down := 1.0 - (1.0 - k) * (1.0 - k)                 # fast at first, gentle at the end
			lander.position.y = roundf(lerpf(-140.0, _lander_rest_y(), down))
			_flame_under_lander(k < 0.97)
			if k > 0.7 and not _touched:
				_blow_dust(delta)
			if k >= 0.97 and not _touched:
				_touched = true
				sfx("latch", -4.0)
				sfx_fade("rocket", 0.8)
			if _touched:
				for d in dust:                                      # the dust settles at once: there is little or no air
					d["node"].color.a = maxf(0.0, d["node"].color.a - delta * 6.0)
		"takeoff":
			lander.position.y = roundf(lerpf(_lander_rest_y(), -200.0, k * k))
			_flame_under_lander(true)
			if k < 0.35:
				_blow_dust(delta)
			else:
				for d in dust:
					d["node"].color.a = maxf(0.0, d["node"].color.a - delta)
		"dock":
			ship.position.x = roundf(lerpf(150, 252, e))
			if k >= 0.97 and not _touched:
				_touched = true
				sfx("latch", -2.0)
		"undock":
			ship.position.x = roundf(lerpf(252, -130, e))
			if not _touched:
				_touched = true
				sfx("latch", -6.0)
		"earth":
			sky.altitude = lerpf(0.75, 0.0, minf(k * 1.6, 1.0))
			capsule.position = Vector2(236, roundf(lerpf(-170.0, 60.0, 1.0 - (1.0 - k) * (1.0 - k))))
			capsule.position.x += roundf(sin(st * 2.0) * 4.0 * (1.0 - k))
			if k >= 0.97 and not _touched:
				_touched = true
				chute.visible = false
				sfx("vent", -8.0, 0.0, 1.2)
				for i in 6:                                         # splash
					add_rect(Rect2(250 + i * 16, 190 - (i % 3) * 5, 5, 8), Color(1, 1, 1, 0.9), view)


func _flame_under_lander(on: bool) -> void:
	flame.visible = on
	flame.position = lander.position + Vector2(48, 108)
	flame.scale.y = 0.8 + 0.25 * sin(st * 40.0)


func _blow_dust(delta: float) -> void:
	for d in dust:
		var n: ColorRect = d["node"]
		n.color.a = minf(0.8, n.color.a + delta * 2.0)
		n.position.x += float(d["dir"]) * 70.0 * delta
		n.size += Vector2(10, 4) * delta
