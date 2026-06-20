extends Node3D
## BLACKOUT — the breaker / fuse box.
##
## Wall-mounted. On [E], if the player holds a fuse, slot it. When all 3 are
## inserted, game.power_restored fires → the front door unlocks. The prompt
## reflects current state.
##
## NOTE: the game node is fetched lazily (not @onready) because the root's
## _ready — which adds the "game" group — runs AFTER this child's _ready.

@onready var _slot_lights: Array = [
	$Slots/Slot1/Glow, $Slots/Slot2/Glow, $Slots/Slot3/Glow,
]


func _ready() -> void:
	add_to_group("interactable")
	_refresh_slots()


func _game() -> Node:
	return get_tree().get_first_node_in_group("game")


var prompt: String:
	get:
		var g := _game()
		if not g:
			return ""
		if g.fuses_inserted >= g.FUSES_REQUIRED:
			return "POWER RESTORED"
		if g.fuses_held > 0:
			return "[E] INSERT FUSE  (%d left)" % g.fuses_held
		return "FUSE BOX — find fuses"


func interact(_player: Node) -> void:
	var g := _game()
	if not g or not g.has_method("insert_fuse"):
		return
	if g.insert_fuse():
		_refresh_slots()


func _refresh_slots() -> void:
	var g := _game()
	if not g:
		return
	for i in range(_slot_lights.size()):
		var light: OmniLight3D = _slot_lights[i]
		if light:
			light.visible = i < g.fuses_inserted
