extends Area3D
## BLACKOUT — key pickup.
##
## Found in a room; carrying it lets the player open the locked gate (G cell).
## On interact, registers the key with the game and removes itself, then the
## game opens the gate mesh + collision.

var prompt := "RUSTY KEY — press E to take"
var _game: Node = null
var _taken := false


func _game_node() -> Node:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	return _game


func interact(_player: Node) -> void:
	if _taken:
		return
	_taken = true
	var g := _game_node()
	if g and g.has_method("collect_key"):
		g.collect_key()
	# Fade + free.
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(queue_free)
