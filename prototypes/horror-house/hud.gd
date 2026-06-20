extends CanvasLayer
## BLACKOUT — HUD controller.
## Reacts to game + player signals to update the minimal diegetic HUD:
## fuse counter, interaction prompt, stamina bar.

@onready var fuse_label: Label = $FuseCounter
@onready var prompt_label: Label = $Prompt
@onready var stamina_bar: ProgressBar = $Stamina
@onready var _title: Control = $Overlays/Title
@onready var _win: Control = $Overlays/Win
@onready var _death: Control = $Overlays/Death
@onready var _subtitle: Label = $Overlays/Death/VBox/Subtitle

var _game: Node = null
var _player: Node = null


func _ready() -> void:
	# Wait a frame so scene-tree groups are populated
	await get_tree().process_frame
	_game = get_tree().get_first_node_in_group("game")
	_player = get_tree().get_first_node_in_group("player")

	if _game:
		_game.fuse_collected.connect(_on_fuse_changed)
		_game.fuse_inserted.connect(_on_fuse_changed)
		_game.won.connect(_on_won)
		_game.died.connect(_on_died)
		if _game.has_signal("game_started"):
			_game.game_started.connect(_on_started)
		_on_fuse_changed(0)
	if _player:
		_player.interaction_prompt.connect(_on_prompt)
		_player.stamina_changed.connect(_on_stamina)
		_on_stamina(1.0)

	# Title is visible at start.
	_win.visible = false
	_death.visible = false


func _on_started() -> void:
	_title.visible = false


func _start() -> void:
	pass  # flow input now handled on the game root


func _restart() -> void:
	pass  # flow input now handled on the game root


func _on_fuse_changed(_total: int) -> void:
	if not _game:
		return
	var held: int = _game.fuses_held
	var ins: int = _game.fuses_inserted
	fuse_label.text = "FUSES  %d/3  ·  carrying %d" % [ins, held]
	# Color shifts as power nears restoration
	if ins >= 3:
		fuse_label.modulate = Color(0.4, 1.0, 0.5)
	elif ins >= 1:
		fuse_label.modulate = Color(0.9, 0.8, 0.4)
	else:
		fuse_label.modulate = Color(0.85, 0.78, 0.6)


func _on_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text.length() > 0


func _on_stamina(ratio: float) -> void:
	stamina_bar.value = ratio
	# Hide the bar when full & not recently used — scarcity of info is horror
	stamina_bar.visible = ratio < 0.999


func _on_won() -> void:
	_win.visible = true
	_release_mouse()


func _on_died() -> void:
	# Vary the death subtitle so repeated runs don't feel identical.
	var lines := [
		"HE FOUND YOU",
		"IT HEARD YOU",
		"THE LIGHT GAVE YOU AWAY",
		"DON'T RUN NEXT TIME",
		"SILENCE WAS YOUR ONLY FRIEND",
	]
	_subtitle.text = lines[randi() % lines.size()]
	_death.visible = true
	_release_mouse()


func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
