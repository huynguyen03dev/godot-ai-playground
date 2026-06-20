extends Area3D
## BLACKOUT — a fuse pickup.
##
## Glowing cylinder the player finds in each room. On [E], it calls
## game.collect_fuse() then frees itself. The visual is a simple emissive
## mesh so it reads as "important" in the dark.

@export var prompt: String = "[E] PICK UP FUSE"

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var glow: OmniLight3D = $Glow
@onready var spin_tween: Tween

var _taken: bool = false


func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	# Slow idle spin + bob so it catches the eye
	var t := create_tween().set_loops()
	t.tween_method(_set_spin, 0.0, TAU, 6.0)
	var b := create_tween().set_loops()
	b.tween_property(mesh, "position:y", 0.15, 1.4).as_relative().set_trans(Tween.TRANS_SINE)
	b.tween_property(mesh, "position:y", -0.15, 1.4).as_relative().set_trans(Tween.TRANS_SINE)


func _set_spin(a: float) -> void:
	rotation.y = a


func interact(_player: Node) -> void:
	if _taken:
		return
	_taken = true
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("collect_fuse"):
		game.collect_fuse()
	# Shrink + fade pickup feedback, then remove
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(glow, "light_energy", 0.0, 0.18)
	t.tween_callback(queue_free)


func _on_body_entered(_b: Node) -> void:
	# Touch-pickup is intentionally NOT enabled — the player must press E.
	# (Keeps the polarity of "decide to grab" meaningful in tense moments.)
	pass
