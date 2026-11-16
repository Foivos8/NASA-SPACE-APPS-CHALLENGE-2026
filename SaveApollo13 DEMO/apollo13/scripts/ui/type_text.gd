extends RichTextLabel
## Text that appears one character at a time, with a soft typing sound and
## automatic highlights. Used by the dialogue box in the cabin level, the
## information strip of the mini-games and levels, the completion screens, and
## the station card and info sheet of the level menu.
##
##   type(text)                 start typing `text`
##   type(text, false, tail)    `tail` is shown all at once when the typing ends
##                              (the "[E]" hint, the list of choices)
##   type(text, true)           show everything immediately
##   finish()                   reveal the rest now (the player pressed confirm)
##   is_typing()                true while characters are still appearing
##   plain                      the text as given, without colour tags
##
## Highlights are found in the text itself, so no wording has to be marked up:
##   numbers and readings  (28 V, 321,860 km, T-00:09, 11 April 1970)   light blue
##   mission terms and names (Saturn V, Odyssey, fuel cells, Jim Lovell)  gold
##   words in capitals (control names, headings, status words)            gold
##   warnings (MASTER ALARM, HOLD, out of limits, emergency)              red
##   GO, GO for launch, LIFTOFF, AUTO                                     green

signal typing_finished

const C_NUMBER := "#8ce0ff"
const C_TERM := "#ffdb4d"
const C_WARN := "#ff8c80"
const C_GO := "#73ff99"

## Seconds added after a character, on top of the normal step.
const PAUSE_SENTENCE := 0.26      # . ! ?
const PAUSE_CLAUSE := 0.11        # , ; :
const PAUSE_LINE := 0.12          # line break
const BLIP_EVERY := 3             # one soft sound per this many letters
const BLIP_VOLUME_DB := -20.0
## The typing sound stays silent while any of these is playing.
const QUIET_FOR := ["houston", "talk", "radio", "beeps", "alarm"]

const TERMS := [
	"oxygen tank 2", "Saturn V", "Odyssey", "Aquarius", "Command and Service Module", "Command Module",
	"Service Module", "Lunar Module", "launch escape tower", "escape tower", "Emergency Detection System",
	"Apollo Guidance Computer", "guidance computer", "Unified S-band", "fuel cells", "fuel cell", "S-IVB", "S-II", "S-IC",
	"Instrument Unit", "translunar injection", "free-return trajectory", "free-return", "Free-return", "master alarm",
	"Mission Control", "Launch Control", "Kennedy Space Center", "Launch Complex 39A", "Fra Mauro", "White Room",
	"Jim Lovell", "Jack Swigert", "Fred Haise", "Ken Mattingly", "Guenter Wendt", "Joe Kerwin", "USS Iwo Jima",
	"lithium hydroxide", "boost protective cover", "terminator", "Presidential Medal of Freedom",
]
const UNITS := "V|volts|psi|km/h|km|kg|tonnes|C|degrees|%|g|seconds|minutes|hours|days|feet|foot|bpm|beats per minute|s|h|min"

static var _regex: RegEx

var plain := ""                   # the whole text, as given
var chars_per_second := 48.0
var sound := true
var _typing := false
var _main_chars := 0              # characters that are typed; anything after is the tail
var _wait := 0.0
var _letters := 0


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	# Lay the whole message out first, then reveal it: the box keeps its final
	# size from the first letter and words never jump to the next line mid-word.
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING


## Matches the look of the game's labels: size, colour and dark outline.
func style(font_size: int, color: Color, width: float) -> void:
	add_theme_font_size_override("normal_font_size", font_size)
	add_theme_color_override("default_color", color)
	add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.09))
	add_theme_constant_override("outline_size", 4)
	custom_minimum_size.x = width
	size.x = width


func set_base_color(color: Color) -> void:
	add_theme_color_override("default_color", color)


# ------------------------------------------------------------ highlights ----

static func _build_regex() -> void:
	var escaped := PackedStringArray()
	for t in TERMS:
		escaped.append(t.replace("-", "\\-").replace(".", "\\."))
	var pattern := "(?<warn>MASTER ALARM|MISSION INCIDENT|HOLD!?|ABNORMAL|out of limits|[Ee]mergency|[Ee]xplosion|\\babort\\b)" \
		+ "|(?<go>GO for launch|LIFTOFF!?|\\bGO\\b|\\bAUTO\\b)" \
		+ "|(?<plain>Apollo \\d+|Gemini \\d+|Panel \\d|Level \\d|Objective \\d+/\\d+|\\[[^\\]]*\\])" \
		+ "|(?<term>\\b(?:" + "|".join(escaped) + ")\\b)" \
		+ "|(?<num>\\b\\d{1,2} (?:January|February|March|April|May|June|July|August|September|October|November|December) \\d{4}\\b" \
		+ "|T[-+]\\d\\d:\\d\\d|\\b\\d[\\d,.:]*\\d(?: ?(?:" + UNITS + ")\\b)?|\\b\\d(?: ?(?:" + UNITS + ")\\b)?)" \
		+ "|(?<caps>\\b[A-Z]{2,}(?:[ -][A-Z]{2,})*\\b)"
	_regex = RegEx.new()
	_regex.compile(pattern)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


## Returns `text` as BBCode with the important parts coloured.
static func highlight(text: String) -> String:
	if _regex == null:
		_build_regex()
	var out := ""
	var at := 0
	for m in _regex.search_all(text):
		out += _escape(text.substr(at, m.get_start() - at))
		var piece := _escape(m.get_string())
		var color := ""
		if m.get_string("warn") != "":
			color = C_WARN
		elif m.get_string("go") != "":
			color = C_GO
		elif m.get_string("term") != "" or m.get_string("caps") != "":
			color = C_TERM
		elif m.get_string("num") != "":
			color = C_NUMBER
		out += piece if color == "" else "[color=%s]%s[/color]" % [color, piece]
		at = m.get_end()
	return out + _escape(text.substr(at))


# ---------------------------------------------------------------- typing ----

## Starts showing `content` letter by letter. `tail` follows it and appears at
## once when the typing ends. `instant` shows everything immediately.
func type(content: String, instant := false, tail := "") -> void:
	_stop_sound()
	plain = content + tail
	text = highlight(content) + highlight(tail)
	_main_chars = content.length()
	_letters = 0
	_wait = 0.0
	if instant or content == "":
		_typing = false
		visible_characters = -1
	else:
		_typing = true
		visible_characters = 0


func is_typing() -> bool:
	return _typing


## Reveals the rest of the message now.
func finish() -> void:
	if not _typing:
		return
	_typing = false
	visible_characters = -1
	_stop_sound()
	typing_finished.emit()


func _process(delta: float) -> void:
	if not _typing:
		return
	if not is_visible_in_tree():
		return
	_wait -= delta
	var shown := visible_characters
	while _wait <= 0.0 and shown < _main_chars:
		var c := plain[shown]
		shown += 1
		_wait += 1.0 / chars_per_second
		var pace := minf(1.0, 48.0 / chars_per_second)      # faster text takes shorter pauses
		var next := plain[shown] if shown < plain.length() else " "
		if c in ".!?" and (next == " " or next == "\n" or next == "'" or next == "\""):
			_wait += PAUSE_SENTENCE * pace
		elif c in ",;:" and next == " ":
			_wait += PAUSE_CLAUSE * pace
		elif c == "\n":
			_wait += PAUSE_LINE * pace
		elif c != " ":
			_letters += 1
			if _letters % BLIP_EVERY == 1:
				_blip()
	visible_characters = shown
	if shown >= _main_chars:
		finish()


func _blip() -> void:
	if not sound:
		return
	var manager := get_node_or_null("/root/Sfx")
	if manager == null:
		return
	for key in QUIET_FOR:
		if manager.is_playing(key):
			return                # never talk over a radio call or a recording
	manager.play("type", BLIP_VOLUME_DB, 0.0, 0.0, true)


func _stop_sound() -> void:
	var manager := get_node_or_null("/root/Sfx") if is_inside_tree() else null
	if manager != null:
		manager.stop("type")
