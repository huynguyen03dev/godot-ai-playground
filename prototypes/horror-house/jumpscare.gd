extends Area3D
## BLACKOUT — jumpscare trigger.
##
## An invisible zone. When the player enters, it fires ONE scripted scare:
##   • FLICKER  — kills the room lights for a beat, then strobes them back
##   • STING    — plays a loud scare sting + a wet inhale right behind the player
##   • LUNGE    — briefly teleports the monster to a nearby "scare node" and
##                makes it lunge toward the player, then retreats (doesn't catch)
##   • WHISPER  — a quiet, unsettling vocal that panics without revealing the monster
##
## Scare type + intensity are @export params so each trigger is tuned in the
## editor viewport by eye — that's the whole point: place these where they
## read best, not in code.

signal scare_fired(kind: String)

@export_enum("FLICKER", "STING", "LUNGE", "WHISPER") var scare_type: int = 1
@export var intensity: float = 1.0          # 0..1 — affects light strobe + sting volume
@export var one_shot: bool = true            # most scares fire once
@export_range(0.0, 3.0) var delay: float = 0.0  # hold, then scare (builds dread)

var prompt := ""  # not an interactable; never shows a prompt

var _fired := false
var _player: Node3D = null
var _game: Node = null
var _monster: Node3D = null


func _ready() -> void:
	add_to_group("jumpscare")
	monitoring = true
	body_entered.connect(_on_body_entered)
	await get_tree().process_frame
	_game = get_tree().get_first_node_in_group("game")
	_monster = get_tree().get_first_node_in_group("monster")


func _on_body_entered(body: Node) -> void:
	if body is not CharacterBody3D:
		return
	if body not in get_tree().get_nodes_in_group("player"):
		return
	# Don't scare during the title or after game over.
	if _game and "started" in _game and not _game.started:
		return
	if _game and "game_over" in _game and _game.game_over:
		return
	if _fired and one_shot:
		return
	_fired = true
	_player = body
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_fire()


func _fire() -> void:
	scare_fired.emit(scare_type_to_name())
	match scare_type:
		0: _do_flicker()
		1: _do_sting()
		2: _do_lunge()
		3: _do_whisper()


func scare_type_to_name() -> String:
	return ["FLICKER", "STING", "LUNGE", "WHISPER"][scare_type]


# ── Scare implementations ─────────────────────────────────────────
func _do_flicker() -> void:
	# Kill nearby lights, strobe, restore. Reads "the house reacted to you".
	var lights := _nearby_lights()
	for l in lights:
		(l as Light3D).light_energy = 0.0
	_play("res://assets/horror/audio/scares/scare_silence_drop.mp3", 0.0)
	await get_tree().create_timer(0.6).timeout
	# Strobe
	for i in 3:
		for l in lights:
			(l as Light3D).light_energy = 2.0 * intensity
		_play("res://assets/horror/audio/scares/scare_sting_general.mp3", -6.0)
		await get_tree().create_timer(0.08).timeout
		for l in lights:
			(l as Light3D).light_energy = 0.0
		await get_tree().create_timer(0.12).timeout
	# Restore to a dim level
	for l in lights:
		(l as Light3D).light_energy = 0.35


func _do_sting() -> void:
	# Loud sting + a wet inhale as if the monster is RIGHT behind you.
	_play("res://assets/horror/audio/scares/scare_sting_general.mp3", 2.0 * intensity)
	await get_tree().create_timer(0.15).timeout
	_play("res://assets/horror/audio/scares/scare_wet_inhale.mp3", -2.0)


func _do_lunge() -> void:
	# The monster briefly appears at a nearby ScareNode and rushes the player,
	# then vanishes — a "false attack" that doesn't catch. Pure dread.
	if _monster == null or _player == null:
		_do_sting()
		return
	var scare_node := _find_scare_node()
	var monster_origin: Vector3 = _monster.global_position
	if scare_node:
		_monster.global_position = scare_node.global_position
	_play("res://assets/horror/audio/scares/scare_body_thud.mp3", 0.0)
	_play("res://assets/horror/audio/threat/monster_vocal.mp3", 2.0 * intensity)
	# Rush for 0.4s toward the player.
	var rush_target: Vector3 = _player.global_position
	var t := 0.0
	while t < 0.4:
		var dt := get_process_delta_time()
		t += dt
		_monster.global_position = _monster.global_position.move_toward(rush_target, 8.0 * dt)
		await get_tree().process_frame
	# Vanish back to origin (it was a projection, not the real hunt).
	_monster.global_position = monster_origin


func _do_whisper() -> void:
	# Quiet, off-putting — the house "speaks". No visual reveal.
	_play("res://assets/horror/audio/scares/scare_breath_glass.mp3", -8.0)
	await get_tree().create_timer(0.5).timeout
	_play("res://assets/horror/audio/scares/scare_glass_knock.mp3", -6.0)


# ── Helpers ───────────────────────────────────────────────────────
func _nearby_lights() -> Array:
	var out: Array = []
	var here := global_position
	for l in get_tree().get_nodes_in_group("room_light"):
		if l is Light3D and here.distance_to(l.global_position) < 12.0:
			out.append(l)
	return out


func _find_scare_node() -> Node3D:
	# A marker node (in group "scare_node") placed near this trigger in the
	# editor — the spot the monster lunges FROM.
	var nearest: Node3D = null
	var best := 999.0
	for n in get_tree().get_nodes_in_group("scare_node"):
		var d: float = global_position.distance_to(n.global_position)
		if d < best and d < 8.0:
			best = d
			nearest = n
	return nearest


func _play(path: String, vol_db: float) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager") \
		if get_tree().get_nodes_in_group("audio_manager").size() > 0 else null
	# AudioManager may not be a group member in all builds; fall back to a
	# transient player so scares always make sound.
	if am and am.has_method("play"):
		am.play(path, vol_db)
	else:
		_transient_play(path, vol_db)


func _transient_play(path: String, vol_db: float) -> void:
	var s := load(path)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
