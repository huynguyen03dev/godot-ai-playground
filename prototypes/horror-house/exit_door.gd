extends Node3D
## BLACKOUT — the front (exit) door.
##
## Locked until game.power_restored. When the door is open, an Area3D trigger
## just past it calls game.reach_exit() → win. The prompt reflects state.
##
## NOTE: the game node is fetched lazily (not @onready) because the root's
## _ready — which adds the "game" group — runs AFTER this child's _ready.

@onready var _trigger: Area3D = $ExitTrigger
@onready var _door_mesh: Node3D = $DoorPanel


func _ready() -> void:
	add_to_group("interactable")
	_trigger.body_entered.connect(_on_trigger_entered)
	# Defer past the root's _ready so the "game" group is populated before we
	# subscribe to its signals (root adds itself to the group AFTER children).
	await get_tree().process_frame
	var g := _game()
	if g:
		g.door_unlocked.connect(_on_unlocked)


func _game() -> Node:
	return get_tree().get_first_node_in_group("game")


var prompt: String:
	get:
		var g := _game()
		if not g:
			return ""
		if g.door_open:
			return "ESCAPE →"
		return "LOCKED — restore power"


func interact(_player: Node) -> void:
	# The door auto-opens on unlock; interaction is just informational here.
	# (Kept in "interactable" group so the prompt shows when looked at.)
	pass


func _on_unlocked() -> void:
	# Swing the door open
	var t := create_tween()
	t.tween_property(_door_mesh, "rotation:y", -PI * 0.6, 1.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _on_trigger_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var g := _game()
		if g and g.has_method("reach_exit"):
			g.reach_exit()
