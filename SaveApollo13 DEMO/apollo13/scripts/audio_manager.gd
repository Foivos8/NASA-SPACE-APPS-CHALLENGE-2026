extends Node
## Sound effects for the whole game. Registered as the autoload "Sfx".
##
## Each sound has a short key (see KEYS). The file for a key is found by name in
## res://assets/audio/ (then anywhere under res://assets/), whatever its exact
## spelling or extension: "Rocket Launch.wav", "Rocket_Launch_Sound.mp3" and
## "rocket-launch.ogg" all match the key "rocket". A missing file is not an
## error: play() then simply does nothing.
##
## Godot can import .wav, .ogg and .mp3 only. Other formats (.m4a, .aac, .flac)
## are reported once in the Output panel and skipped.
##
## The node is pausable, so every sound pauses and resumes with the game.
##
## Button presses: every Button in the game clicks when pressed. The manager
## connects itself to each button as it enters the scene tree, so no menu or
## level script has to ask for it. That click has its own player, which keeps
## running while the game is paused (PAUSE, RESUME and the confirmation dialog
## click too) and never interrupts another sound.

## key -> words the file name must contain (compared without spaces, case or punctuation)
const KEYS := {
	"rocket": ["rocketlaunch"],
	"footsteps": ["footstep"],
	"walkie": ["walkietalkie"],
	"radio": ["radiosignal"],
	"beeps": ["beep"],
	"houston": ["houston"],
	"talk": ["mantalking"],
	# original effects made for the game (assets/audio/sfx/, see tools/gen_sfx.py)
	"click": ["uiclick"],
	"confirm": ["confirm"],
	"error": ["error"],
	"latch": ["latch"],
	"tick": ["tick"],
	"alarm": ["masteralarm"],
	"bang": ["bang"],
	"vent": ["venthiss"],
	"hum": ["cabinhum"],
	"dice": ["dice"],
	"thruster": ["thruster"],
	"type": ["typeblip"],
	# Design Your Mission
	"shutter": ["shutter"],
	"collect": ["collect"],
	"build": ["build"],
	"impact": ["impact"],
	"warning": ["warning"],
}
const PLAYABLE := ["wav", "ogg", "mp3"]
const NOT_PLAYABLE := ["m4a", "aac", "flac", "wma", "aiff", "aif"]
const SEARCH_DIRS := ["res://assets/audio", "res://assets"]
const BUTTON_VOLUME_DB := -10.0
const BUTTON_GAP_MS := 80          # two presses closer than this share one click

var streams := {}        # key -> AudioStream
var files := {}          # key -> path, for reference
var players := {}        # key -> AudioStreamPlayer
var stop_at := {}        # key -> seconds of play time left (for clips cut short)
var fades := {}          # key -> dB per second while fading out
var history: Array = []  # every sound actually started: [key, from_second]; used by the tests
var button_player: AudioStreamPlayer     # the button click; runs even while the game is paused
var _last_button_ms := -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for dir in SEARCH_DIRS:
		_scan(dir, 0)
	for key in KEYS:
		var p := AudioStreamPlayer.new()
		p.name = key
		if streams.has(key):
			p.stream = streams[key]
		add_child(p)
		players[key] = p
	button_player = AudioStreamPlayer.new()
	button_player.name = "button"
	button_player.process_mode = Node.PROCESS_MODE_ALWAYS
	button_player.volume_db = BUTTON_VOLUME_DB
	button_player.stream = streams.get("click")
	add_child(button_player)
	get_tree().node_added.connect(_on_node_added)
	# One line in the Output panel, so a sound that never plays can be traced to its file.
	var missing := PackedStringArray()
	for key in KEYS:
		if not streams.has(key):
			missing.append(key)
	print("Sfx: %d of %d sounds found in res://assets/audio%s" % [streams.size(), KEYS.size(),
			"" if missing.is_empty() else " - missing: " + ", ".join(missing)])


## Every button that enters the scene tree gets the click.
func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)


## One short click per press. "pressed" fires once however long the button is held.
func _on_button_pressed() -> void:
	if button_player.stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_button_ms < BUTTON_GAP_MS:
		return                 # this press has already clicked (here, or through play("click"))
	_last_button_ms = now
	button_player.play()
	history.append(["button", 0.0])


func _scan(dir_path: String, depth: int) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		# exported games list "name.mp3.import" instead of "name.mp3"
		var file_name: String = f.trim_suffix(".import").trim_suffix(".remap")
		var ext := file_name.get_extension().to_lower()
		var plain := _plain(file_name.get_basename())
		for key in KEYS:
			if streams.has(key) or not _matches(plain, KEYS[key]):
				continue
			var path := dir_path.path_join(file_name)
			if ext in PLAYABLE:
				var s = load(path)
				if s is AudioStream:
					streams[key] = s
					files[key] = path
			elif ext in NOT_PLAYABLE:
				push_warning("Sfx: '%s' is .%s, which Godot cannot play. Convert it to .mp3, .ogg or .wav." % [path, ext])
	if depth < 3:
		for sub in dir.get_directories():
			_scan(dir_path.path_join(sub), depth + 1)


func _plain(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out


func _matches(plain_name: String, words: Array) -> bool:
	for w in words:
		if not plain_name.contains(w):
			return false
	return true


func has(key: String) -> bool:
	return streams.has(key)


func is_playing(key: String) -> bool:
	return players.has(key) and players[key].playing


## Starts a sound. Does nothing if the file is missing, or if this sound is
## already playing (pass restart = true to start it again from the top).
##   from      start position in seconds
##   duration  stop after this many seconds (0 = play to the end)
func play(key: String, volume_db := 0.0, from := 0.0, duration := 0.0, restart := false) -> void:
	if not players.has(key):
		return
	var p: AudioStreamPlayer = players[key]
	if p.stream == null:
		return
	if p.playing and not restart:
		return
	if key == "click":
		if Time.get_ticks_msec() - _last_button_ms < BUTTON_GAP_MS:
			return             # a button has just clicked for this same press: do not double it
		_last_button_ms = Time.get_ticks_msec()
	fades.erase(key)
	p.volume_db = volume_db
	p.play(from)
	history.append([key, from])
	if duration > 0.0:
		stop_at[key] = duration
	else:
		stop_at.erase(key)


## Starts a sound that repeats until stop() or fade_out(): the cabin hum.
## Does nothing if it is already playing.
func loop(key: String, volume_db := 0.0) -> void:
	if not players.has(key) or players[key].stream == null or players[key].playing:
		return
	var s: AudioStream = players[key].stream
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	elif s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.loop = true
	play(key, volume_db)


func stop(key: String) -> void:
	if players.has(key):
		players[key].stop()
	stop_at.erase(key)
	fades.erase(key)


## Fades a sound out over `seconds`, then stops it.
func fade_out(key: String, seconds := 1.0) -> void:
	if is_playing(key):
		fades[key] = 60.0 / maxf(seconds, 0.05)


func stop_all() -> void:
	for key in players:
		stop(key)


func _process(delta: float) -> void:
	for key in stop_at.keys():
		stop_at[key] -= delta
		if stop_at[key] <= 0.0:
			stop(key)
	for key in fades.keys():
		var p: AudioStreamPlayer = players[key]
		p.volume_db -= fades[key] * delta
		if p.volume_db <= -60.0 or not p.playing:
			stop(key)
