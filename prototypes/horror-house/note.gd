extends Area3D
## BLACKOUT — readable note (lore).
##
## A piece of paper on the ground/shelf. Interact (E) to read: shows a lore
## card overlay with the note's text, dismiss with E/click. Notes are optional
## — they tell what happened in the house and give the player motivation, but
## aren't required to win. Each note is placed in the editor with its @export
## `note_text` set, so the writing is tuned by hand.

@export var note_title: String = "Untitled"
@export_multiline var note_text: String = "..."
@export var read_color: Color = Color(0.78, 0.74, 0.62)  # aged paper

var prompt := "NOTE — press E to read"
var _game: Node = null
var _reading := false


func _ready() -> void:
	add_to_group("interactable")
	await get_tree().process_frame
	_game = get_tree().get_first_node_in_group("game")


func interact(_player: Node) -> void:
	if _reading:
		return
	_reading = true
	_show_note_overlay()
	_play("res://assets/horror/audio/sfx/note_rustle.mp3", -8.0)


func _show_note_overlay() -> void:
	# Build a simple centered card overlay at runtime. Pauses the game while
	# reading so the monster can't catch you mid-read (fair to the player).
	var canvas := CanvasLayer.new()
	canvas.name = "NoteReader"
	canvas.layer = 50  # above HUD/overlays

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(dim)

	var card := Panel.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(620, 420)
	card.position = Vector2(-310, -210)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.93, 0.90, 0.80)
	bg.border_width_left = 4
	bg.border_width_right = 4
	bg.border_width_top = 4
	bg.border_width_bottom = 4
	bg.border_color = Color(0.35, 0.25, 0.15)
	bg.content_margin_left = 28
	bg.content_margin_right = 28
	bg.content_margin_top = 24
	bg.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", bg)
	dim.add_child(card)

	var title := Label.new()
	title.text = note_title
	title.add_theme_color_override("font_color", Color(0.2, 0.12, 0.08))
	title.add_theme_font_size_override("font_size", 28)
	card.add_child(title)

	var body := Label.new()
	body.text = note_text
	body.add_theme_color_override("font_color", read_color.darkened(0.2))
	body.add_theme_font_size_override("font_size", 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 280)
	body.position = Vector2(0, 50)
	card.add_child(body)

	var hint := Label.new()
	hint.text = "[ press E or click to put away ]"
	hint.add_theme_color_override("font_color", Color(0.4, 0.3, 0.2))
	hint.add_theme_font_size_override("font_size", 14)
	hint.position = Vector2(0, 360)
	card.add_child(hint)

	get_tree().root.add_child(canvas)
	get_tree().paused = true
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS  # stays active while paused

	# Wait for dismiss input (E / click / ESC), then close.
	var dismissed := false
	while not dismissed:
		await get_tree().process_frame
		if Input.is_action_just_pressed("interact") \
				or Input.is_action_just_pressed("ui_cancel") \
				or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			dismissed = true
	get_tree().paused = false
	canvas.queue_free()
	_reading = false


func _play(path: String, vol_db: float) -> void:
	var s := load(path)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
