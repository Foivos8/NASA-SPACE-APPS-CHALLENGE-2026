extends "res://scripts/minigames/minigame_base.gd"
## Mini-game 2: Suit Up!
## Drag five pieces of equipment onto the astronaut (or click the item, then the
## body part). A wrong body part or a wrong order sends the item back.

const FIG_POS := Vector2(248, 86)      # top-left of the astronaut on screen
const FIG_SCALE := 3.0                 # the figure art is 48 x 72
const LAYER_ORDER := ["suit", "connections", "gloves", "headset", "helmet"]
## Body zones in figure pixels. Checked in this order, so small zones win.
const ZONES := [
	["hands", Rect2(4, 37, 13, 14)], ["hands", Rect2(31, 37, 13, 14)],
	["head", Rect2(11, 0, 26, 21)],
	["chest", Rect2(15, 24, 18, 13)],
	["body", Rect2(13, 21, 22, 49)],
]
const ZONE_NAMES := {"head": "head", "hands": "hands", "chest": "chest", "body": "body"}

var items: Array = []
var placed := {}
var selected := ""
var cards := {}           # id -> card
var layers := {}          # id -> TextureRect on the astronaut
var dragging := false
var ghost: TextureRect
var bar_fill: ColorRect
var zone_marks: Array = []


func _build() -> void:
	items = config["items"]
	add_panel(Rect2(226, 78, 188, 232), Color(0.1, 0.12, 0.17), C_BORDER)
	add_sprite("astronaut_base.png", FIG_POS, FIG_SCALE)
	for id in LAYER_ORDER:
		var it := _item(id)
		var t := add_sprite(it["layer"], FIG_POS, FIG_SCALE)
		t.visible = false
		t.pivot_offset = t.size / 2.0
		layers[id] = t
	for z in ZONES:                                   # faint drop targets, shown while holding an item
		var r: Rect2 = z[1]
		var m := add_panel(Rect2(FIG_POS + r.position * FIG_SCALE, r.size * FIG_SCALE),
				Color(1, 0.86, 0.3, 0.05), Color(1, 0.86, 0.3, 0.55))
		m.visible = false
		zone_marks.append(m)
	var slots := [Vector2(12, 82), Vector2(12, 158), Vector2(12, 234), Vector2(428, 82), Vector2(428, 158)]
	var order := items.duplicate()
	order.shuffle()
	for i in order.size():
		var it: Dictionary = order[i]
		cards[it["id"]] = add_card(Rect2(slots[i], Vector2(200, 66)), it["icon"], it["name"])
	add_label("Equipment on", 10, C_DIM, Vector2(428, 240), 200)
	add_panel(Rect2(428, 258, 200, 18), Color(0.1, 0.12, 0.17), C_BORDER)
	bar_fill = ColorRect.new()
	bar_fill.color = C_OK
	bar_fill.position = Vector2(431, 261)
	bar_fill.size = Vector2(0, 12)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_fill)
	ghost = add_sprite("icon_suit.png", Vector2.ZERO, 2.0)
	ghost.visible = false
	say("Suit technician: 'Let's get you dressed. Start with whatever goes on first.'", true)
	_refresh()


func _item(id: String) -> Dictionary:
	for it in items:
		if it["id"] == id:
			return it
	return {}


func _refresh() -> void:
	progress.text = "Equipment %d / %d" % [placed.size(), items.size()]
	create_tween().tween_property(bar_fill, "size:x", 194.0 * placed.size() / items.size(), 0.25)
	for id in cards:
		if placed.has(id):
			paint_card(cards[id], C_OK.darkened(0.7), C_OK)
			cards[id]["icon"].modulate.a = 0.25
		elif id == selected:
			paint_card(cards[id], C_GOLD.darkened(0.7), C_GOLD)
		else:
			paint_card(cards[id], C_CARD, C_BORDER)
	for m in zone_marks:
		m.visible = selected != "" and not completed


func zone_at(pos: Vector2) -> String:
	var p := (pos - FIG_POS) / FIG_SCALE
	for z in ZONES:
		if z[1].has_point(p):
			return z[0]
	return ""


func select(id: String) -> void:
	if placed.has(id):
		return
	selected = id
	sfx("click", -12.0)
	say("%s picked up. Where does it go?" % _item(id)["name"], true)
	_refresh()


## Returns true when the item was put on. `zone` is head, hands, chest, body or "".
func try_place(item_id: String, zone: String) -> bool:
	if completed or placed.has(item_id):
		return false
	var it := _item(item_id)
	var problem := ""
	if zone == "":
		problem = "Drop it on the astronaut."
	elif not (zone in it["zones"]):
		problem = "Not on the %s. %s" % [ZONE_NAMES[zone], it["hint"]]
	else:
		for need in it["requires"]:
			if not placed.has(need):
				problem = str(it["requires_text"])
				break
	if problem != "":
		if zone != "":
			mistakes += 1
			sfx("error", -10.0)
		say(problem, false)
		_return_home(item_id)
		return false
	placed[item_id] = true
	sfx("latch" if not it["requires"].is_empty() else "click", -8.0)     # helmet, gloves and hoses lock onto the suit
	selected = ""
	var t: TextureRect = layers[item_id]
	t.visible = true
	t.modulate.a = 0.0
	t.scale = Vector2(1.25, 1.25)
	var tw := create_tween().set_parallel()
	tw.tween_property(t, "modulate:a", 1.0, 0.2)
	tw.tween_property(t, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	say(str(it["placed"]), true)
	_refresh()
	if placed.size() == items.size():
		complete(str(config["complete_title"]), "%s\n\nTime: %s   Wrong tries: %d\n\n%s" % [
				config["complete_text"], time_text(), mistakes, config["fact"]])
	return true


## Wrong placement: the item slides back to its card and the card shakes.
func _return_home(item_id: String) -> void:
	var card: Dictionary = cards[item_id]
	if ghost.visible:
		var fly := add_sprite(_item(item_id)["icon"], ghost.position, 2.0)
		var tw := create_tween()
		tw.tween_property(fly, "position", card["home"] + Vector2(6, 9), 0.25).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(fly.queue_free)
	flash_card(card, C_BAD, C_GOLD.darkened(0.7) if item_id == selected else C_CARD,
			C_GOLD if item_id == selected else C_BORDER)


func _card_at(pos: Vector2) -> String:
	for id in cards:
		if cards[id]["rect"].has_point(pos):
			return id
	return ""


func _pointer_down(pos: Vector2) -> void:
	var id := _card_at(pos)
	if id != "" and not placed.has(id):
		select(id)
		dragging = true
		ghost.texture = cards[id]["icon"].texture
		ghost.position = pos - ghost.size / 2.0
		return
	if selected != "" and zone_at(pos) != "":
		try_place(selected, zone_at(pos))


func _pointer_move(pos: Vector2) -> void:
	if dragging:
		ghost.visible = true
		ghost.position = pos - ghost.size / 2.0


func _pointer_up(pos: Vector2) -> void:
	if not dragging:
		return
	dragging = false
	var moved := ghost.visible
	if moved and selected != "" and _card_at(pos) == "":
		try_place(selected, zone_at(pos))
	ghost.visible = false
