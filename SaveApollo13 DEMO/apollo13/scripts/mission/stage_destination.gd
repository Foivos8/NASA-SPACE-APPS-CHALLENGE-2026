extends "res://scripts/mission/mission_stage.gd"
## Design Your Mission - choose ONE of three destinations.
## Each card shows the place, the mission, how far it is and what waits on the
## way home. The choice is final for this flight.
## Text: data/missions.json -> "destination" (+ each mission's "briefing").

const CARD_W := 200.0
const CARD_Y := 66.0
const CARD_H := 244.0

var chosen := ""
var cards := {}                   # id -> {panel, button}
var _time := 0.0
var _images: Array = []


func _build() -> void:
	var sky := SkyBackground.new()
	sky.size = Vector2(W, 250)
	sky.position = Vector2(0, 62)
	sky.altitude = 1.0
	root.add_child(sky)
	var options: Array = config["options"]
	for i in options.size():
		var o: Dictionary = options[i]
		var x := 12.0 + i * 208.0
		var p := add_panel(Rect2(x, CARD_Y, CARD_W, CARD_H), Color(C_PANEL, 0.9), C_BORDER)
		var tex: Texture2D = load(str(o["image"]))
		var img_size := tex.get_size() * float(o["scale"])
		var img := add_art(str(o["image"]), Vector2(x + (CARD_W - img_size.x) / 2.0, CARD_Y + 4 + (100 - img_size.y) / 2.0), float(o["scale"]))
		_images.append({"node": img, "y": img.position.y, "phase": i * 1.3})
		var vb := VBoxContainer.new()
		vb.position = Vector2(x + 8, CARD_Y + 104)
		vb.size = Vector2(CARD_W - 16, 100)
		vb.add_theme_constant_override("separation", 1)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(vb)
		add_label(str(o["name"]), 13, C_GOLD, Vector2.ZERO, CARD_W - 16, vb)
		add_label("MISSION: " + str(o["mission"]), 8, C_DIM, Vector2.ZERO, CARD_W - 16, vb)
		add_label(str(o["distance"]), 8, Color(0.55, 0.88, 1), Vector2.ZERO, CARD_W - 16, vb)
		add_label(str(o["text"]), 9, Color.WHITE, Vector2.ZERO, CARD_W - 16, vb)
		add_label(str(o["hazard"]), 8, C_BAD, Vector2.ZERO, CARD_W - 16, vb)
		var b := add_button("CHOOSE " + str(o["name"]), Rect2(x + 10, CARD_Y + CARD_H - 30, CARD_W - 20, 24), 10, choose.bind(str(o["id"])))
		b.mouse_entered.connect(_hover.bind(str(o["id"]), true))
		b.mouse_exited.connect(_hover.bind(str(o["id"]), false))
		cards[o["id"]] = {"panel": p, "button": b}
	progress.text = "Choose 1 of %d" % options.size()
	say("Three destinations, three different missions. Choose carefully: you can fly only one.", true)


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta
	for im in _images:                                  # the three worlds float gently
		im["node"].position.y = im["y"] + roundf(sin(_time * 1.4 + im["phase"]) * 2.0)


func _hover(id: String, on: bool) -> void:
	if chosen != "":
		return
	cards[id]["panel"].add_theme_stylebox_override("panel", make_style(Color(C_PANEL, 0.9), C_GOLD if on else C_BORDER))


## Locks in a destination. Only the first choice counts.
func choose(id: String) -> void:
	if chosen != "" or not cards.has(id):
		return
	chosen = id
	outcome = {"destination": id}
	for key in cards:
		cards[key]["button"].disabled = true
		var mine: bool = key == id
		cards[key]["panel"].add_theme_stylebox_override("panel", make_style(Color(C_PANEL, 0.9), C_OK if mine else Color(0.25, 0.27, 0.32)))
		if not mine:
			cards[key]["panel"].modulate = Color(0.6, 0.6, 0.6)
	var name_text := ""
	for o in config["options"]:
		if o["id"] == id:
			name_text = str(o["mission"])
	progress.text = "Destination chosen"
	complete("MISSION: " + name_text, str(config.get("briefings", {}).get(id, "")))
