extends Control
## Pixel-art sky: banded blue gradient with drifting clouds. Raising `altitude`
## from 0 to 1 turns it into space: the bands darken, the clouds fall away and
## stars appear. Used by the main menu and both levels.

const BANDS := 9
const CLOUD_FILES := ["cloud_1.png", "cloud_2.png", "cloud_3.png"]
const SKY_TOP := Color(0.30, 0.56, 0.88)
const SKY_LOW := Color(0.66, 0.84, 0.97)
const HIGH_TOP := Color(0.05, 0.10, 0.30)
const HIGH_LOW := Color(0.20, 0.42, 0.78)
const SPACE := Color(0.02, 0.02, 0.06)

var altitude := 0.0            # 0 = ground, 1 = space
var drift := 1.0               # cloud speed multiplier
var cloud_scale := 2.0
var clouds: Array = []         # {tex, pos, speed}
var stars: Array = []          # {pos, size, phase}
var _time := 0.0
var _fall := 0.0               # how far the clouds have dropped as we climb


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var count := int(clampf(size.x / 90.0, 3, 8))
	for i in count:
		var tex: Texture2D = load("res://assets/levels/" + CLOUD_FILES[i % CLOUD_FILES.size()])
		clouds.append({
			"tex": tex,
			"pos": Vector2(rng.randf_range(0, size.x), rng.randf_range(4, size.y * 0.6)),
			"speed": rng.randf_range(3.0, 9.0),
		})
	for i in int(size.x * size.y / 1400.0):
		stars.append({
			"pos": Vector2(rng.randi_range(0, int(size.x)), rng.randi_range(0, int(size.y))),
			"size": 2 if rng.randf() < 0.2 else 1,
			"phase": rng.randf_range(0, TAU),
		})


## Moves the clouds down by `pixels`, as seen from a climbing rocket.
func climb(pixels: float) -> void:
	_fall += pixels


func _process(delta: float) -> void:
	_time += delta
	for c in clouds:
		c["pos"].x += c["speed"] * drift * delta
		var w: float = c["tex"].get_width() * cloud_scale
		if c["pos"].x > size.x + 4:
			c["pos"].x = -w
	queue_redraw()


func _band_color(t: float) -> Color:
	var ground := SKY_TOP.lerp(SKY_LOW, t)
	var high := HIGH_TOP.lerp(HIGH_LOW, t)
	if altitude < 0.5:
		return ground.lerp(high, altitude / 0.5)
	return high.lerp(SPACE, (altitude - 0.5) / 0.5)


func _draw() -> void:
	var band_h := ceilf(size.y / BANDS)
	for i in BANDS:
		draw_rect(Rect2(0, i * band_h, size.x, band_h), _band_color(float(i) / (BANDS - 1)))
	var star_alpha := clampf((altitude - 0.55) / 0.35, 0.0, 1.0)
	if star_alpha > 0.0:
		for s in stars:
			var tw := 0.6 + 0.4 * sin(_time * 2.0 + s["phase"])
			draw_rect(Rect2(s["pos"], Vector2(s["size"], s["size"])), Color(1, 1, 1, star_alpha * tw))
	var cloud_alpha := clampf(1.0 - altitude / 0.6, 0.0, 1.0)
	if cloud_alpha > 0.0:
		for c in clouds:
			var tex: Texture2D = c["tex"]
			var pos: Vector2 = (c["pos"] + Vector2(0, _fall)).floor()
			if pos.y < size.y:
				draw_texture_rect(tex, Rect2(pos, tex.get_size() * cloud_scale), false, Color(1, 1, 1, cloud_alpha))
