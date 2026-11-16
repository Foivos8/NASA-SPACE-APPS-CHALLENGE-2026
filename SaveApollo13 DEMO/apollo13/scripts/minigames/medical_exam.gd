extends "res://scripts/minigames/minigame_base.gd"
## Mini-game 1: Medical Examination.
## Match three instruments to what they measure. Click an instrument and then a
## checklist line, or drag the instrument onto the line.

var pairs: Array = []
var matched := {}
var selected := ""
var inst_cards := {}      # id -> card
var slot_cards := {}      # id -> card (the checklist lines)
var dragging := false
var ghost: TextureRect


func _build() -> void:
	pairs = config["pairs"]
	# the scene: patient and flight surgeon
	add_panel(Rect2(12, 80, 206, 228), Color(0.1, 0.12, 0.17), C_BORDER)
	add_sprite("astronaut_base.png", Vector2(26, 112), 2.0)
	add_sprite("doctor.png", Vector2(112, 112), 2.0)
	add_label("Astronaut", 9, C_DIM, Vector2(26, 260), 96).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label("Flight surgeon", 9, C_DIM, Vector2(112, 260), 96).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label("Instruments", 11, C_GOLD, Vector2(232, 78), 180)
	add_label("Checklist: what is measured?", 11, C_GOLD, Vector2(430, 78), 200)
	for i in pairs.size():
		var p: Dictionary = pairs[i]
		inst_cards[p["id"]] = add_card(Rect2(232, 98 + i * 70, 182, 60), p["icon"], p["name"])
	var order := pairs.duplicate()
	order.shuffle()
	for i in order.size():
		var p: Dictionary = order[i]
		slot_cards[p["id"]] = add_card(Rect2(430, 98 + i * 70, 198, 60), "", "[  ]  " + p["purpose"])
	ghost = add_sprite("icon_thermometer.png", Vector2.ZERO, 2.0)
	ghost.visible = false
	ghost.modulate.a = 0.85
	say(str(config.get("doctor_line", "")), true)
	_refresh()


func _refresh() -> void:
	progress.text = "Matched %d / %d" % [matched.size(), pairs.size()]
	for id in inst_cards:
		if matched.has(id):
			paint_card(inst_cards[id], C_OK.darkened(0.7), C_OK)
		elif id == selected:
			paint_card(inst_cards[id], C_GOLD.darkened(0.7), C_GOLD)
		else:
			paint_card(inst_cards[id], C_CARD, C_BORDER)


func _pair(id: String) -> Dictionary:
	for p in pairs:
		if p["id"] == id:
			return p
	return {}


func select(id: String) -> void:
	if matched.has(id):
		return
	selected = id
	sfx("click", -12.0)
	say("%s selected. Now click what it measures." % _pair(id)["name"], true)
	_refresh()


## Returns true when the instrument belongs on that checklist line.
func try_match(instrument_id: String, purpose_id: String) -> bool:
	if completed or matched.has(instrument_id) or matched.has(purpose_id):
		return false
	var p := _pair(instrument_id)
	if instrument_id != purpose_id:
		mistakes += 1
		sfx("error", -10.0)
		say("Not quite. %s Try again." % p["hint"], false)
		flash_card(slot_cards[purpose_id], C_BAD)
		return false
	matched[instrument_id] = true
	sfx("confirm", -10.0)
	selected = ""
	var slot: Dictionary = slot_cards[purpose_id]
	slot["label"].text = "[x]  %s\n%s" % [p["purpose"], p["reading"]]
	paint_card(slot, C_OK.darkened(0.7), C_OK)
	say("Correct: %s measures %s. %s" % [p["name"].to_lower(), p["purpose"].to_lower(), p["explain"]], true)
	_refresh()
	if matched.size() == pairs.size():
		complete(str(config["complete_title"]), "%s\n\nTime: %s   Wrong tries: %d\n\n%s" % [
				config["complete_text"], time_text(), mistakes, config["fact"]])
	return true


func _card_at(cards: Dictionary, pos: Vector2) -> String:
	for id in cards:
		if cards[id]["rect"].has_point(pos):
			return id
	return ""


func _pointer_down(pos: Vector2) -> void:
	var inst := _card_at(inst_cards, pos)
	if inst != "" and not matched.has(inst):
		select(inst)
		dragging = true
		ghost.texture = inst_cards[inst]["icon"].texture
		ghost.position = pos - ghost.size / 2.0
		return
	var slot := _card_at(slot_cards, pos)
	if slot != "":
		if selected == "":
			say("Pick an instrument first.", false)
		else:
			try_match(selected, slot)


func _pointer_move(pos: Vector2) -> void:
	if dragging:
		ghost.visible = true
		ghost.position = pos - ghost.size / 2.0


func _pointer_up(pos: Vector2) -> void:
	if not dragging:
		return
	dragging = false
	ghost.visible = false
	var slot := _card_at(slot_cards, pos)
	if slot != "" and selected != "":
		try_match(selected, slot)
