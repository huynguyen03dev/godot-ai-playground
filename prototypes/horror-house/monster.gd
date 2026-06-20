extends CharacterBody3D
## BLACKOUT — the monster (zombie).
##
## Detection model = the game's core polarity:
##   • LIGHT: the player's flashlight is a beacon. If it's on and the monster
##     has line-of-sight, it can spot them from far away.
##   • NOISE: sprinting is loud; crouching is near-silent. Noise is read from
##     the player's `noise_level` (0..1) and only betrays them at close range.
##   • Stillness + darkness + crouch = invisible. That's the survival loop.
##
## Movement: simple steering toward the last-known position. The lobby is a
## single open room, so a full navmesh bake is unnecessary; we steer around
## the central pillar with a lightweight avoid ray. Robust + fully testable.
##
## On catch (within CATCH_RANGE), calls game.trigger_death().

# ── Signals (for audio / HUD reactions) ───────────────────────────
signal state_changed(state: int)
signal spotted_player()                # first sight this chase
signal lost_player()
signal caught_player()

enum State { DORMANT, HUNT, CHASE, RETURN }

# ── Detection tuning ──────────────────────────────────────────────
@export var sight_range_flashlight: float = 18.0   # sees the beam from far
@export var sight_range_dark: float = 4.5          # nearly blind in the dark
@export var noise_hear_range: float = 11.0         # hears loud noise
@export var lose_sight_time: float = 4.0           # grace period after losing LoS

# ── Movement tuning ───────────────────────────────────────────────
@export var hunt_speed: float = 1.6                # roaming
@export var chase_speed: float = 3.4               # pursuing (slower than player sprint 6.5, faster than walk 4.0 → must juke, not outrun)
@export var return_speed: float = 2.2
@export var acceleration: float = 6.0
@export var turn_speed: float = 5.0

# ── Catch ─────────────────────────────────────────────────────────
@export var catch_range: float = 1.1
@export var spawn_delay: float = 6.0               # grace period at game start

# ── Nodes ─────────────────────────────────────────────────────────
@onready var _head: Node3D = $Head
@onready var _eyes: RayCast3D = $Head/Eyes

# ── State ─────────────────────────────────────────────────────────
var state: State = State.DORMANT
var player: CharacterBody3D = null
var _game: Node = null
var _home: Vector3 = Vector3.ZERO
var _last_known_pos: Vector3 = Vector3.ZERO
var _has_los: bool = false
var _los_lost_timer: float = 0.0
var _spawn_timer: float = 0.0
var _spotted_this_chase: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("monster")
	# Defer group lookups so the "player"/"game" groups (populated by the
	# root's _ready, which runs after children) are ready.
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	_game = get_tree().get_first_node_in_group("game")
	_home = global_position
	_last_known_pos = _home
	if _game:
		_game.died.connect(_on_game_over)
		_game.won.connect(_on_game_over)
		if _game.has_signal("game_started"):
			_game.game_started.connect(_on_game_started)
	# Stay DORMANT until the title is dismissed.
	state = State.DORMANT


func _on_game_started() -> void:
	# Begin the spawn-delay grace countdown once play actually begins.
	_spawn_timer = 0.0


func _physics_process(delta: float) -> void:
	if not player or not _game:
		return
	# Hold dormant (frozen) until the game has actually started.
	if "started" in _game and not _game.started:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if _game.game_over:
		# Freeze on game end.
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		return

	if state == State.DORMANT:
		_spawn_timer += delta
		if _spawn_timer >= spawn_delay:
			_set_state(State.HUNT)
		# stand still while dormant
		_apply_gravity_and_slide(delta, Vector3.ZERO)
		return

	_update_perception()
	_update_state_machine(delta)

	var speed := _current_speed()
	var dir := _desired_direction()
	_move_toward(dir, speed, delta)


# ── Perception ────────────────────────────────────────────────────
func _update_perception() -> void:
	_has_los = _has_line_of_sight()
	if _has_los:
		_last_known_pos = player.global_position
		_los_lost_timer = 0.0
	else:
		_los_lost_timer += get_physics_process_delta_time()


func _has_line_of_sight() -> bool:
	if not player:
		return false
	# Aim eyes at the player's torso.
	var to_player := player.global_position + Vector3.UP * 0.8 - _head.global_position
	var dist := to_player.length()

	# 1. Hearing: noise betrays the player at close range, even behind cover.
	var noise: float = player.get("noise_level")
	if noise > 0.05 and dist < noise_hear_range * noise:
		return true

	# 2. Sight: flashlight greatly extends range; dark sight is short.
	var max_sight := sight_range_flashlight if player.get("flashlight_on") else sight_range_dark
	if dist > max_sight:
		return false

	# 3. Ray test for occlusion (central pillar, walls).
	_eyes.global_position = _head.global_position
	_eyes.target_position = _eyes.to_local(player.global_position + Vector3.UP * 0.8)
	_eyes.force_raycast_update()
	if _eyes.is_colliding():
		# Hit something before reaching the player → occluded.
		var col := _eyes.get_collider()
		if col != player and not col.is_ancestor_of(player):
			return false
	return true


# ── State machine ─────────────────────────────────────────────────
func _update_state_machine(_delta: float) -> void:
	match state:
		State.HUNT:
			if _has_los:
				_begin_chase()
		State.CHASE:
			if not _has_los and _los_lost_timer > lose_sight_time:
				lost_player.emit()
				_spotted_this_chase = false
				_set_state(State.RETURN)
			# Catch check.
			if global_position.distance_to(player.global_position) < catch_range:
				_caught()
		State.RETURN:
			if _has_los:
				_begin_chase()
			elif global_position.distance_to(_home) < 0.8:
				_set_state(State.HUNT)


func _begin_chase() -> void:
	if not _spotted_this_chase:
		_spotted_this_chase = true
		spotted_player.emit()
	_set_state(State.CHASE)


func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)


func _current_speed() -> float:
	match state:
		State.CHASE: return chase_speed
		State.RETURN: return return_speed
		_: return hunt_speed


# ── Movement ──────────────────────────────────────────────────────
func _desired_direction() -> Vector3:
	var target: Vector3
	match state:
		State.CHASE:
			target = _last_known_pos
		State.RETURN:
			target = _home
		_: # HUNT — slow wander around home
			var wobble := Vector3(
				sin(Time.get_ticks_msec() * 0.0007),
				0.0,
				cos(Time.get_ticks_msec() * 0.0009)
			)
			target = _home + wobble * 3.0
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return Vector3.ZERO
	return to.normalized()


func _move_toward(dir: Vector3, speed: float, delta: float) -> void:
	# Obstacle avoidance: if heading toward a near collision, bend sideways.
	dir = _avoid(dir)
	var target_vel := dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	# Face travel direction.
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		var angle := atan2(velocity.x, velocity.z)
		var cur := rotation.y
		rotation.y = lerp_angle(cur, angle, turn_speed * delta)
	_apply_gravity_and_slide(delta, dir)


func _avoid(desired: Vector3) -> Vector3:
	# Lightweight whisker avoidance for the central pillar + walls.
	# Cast three short rays (left/center/right of desired heading); if one is
	# clear when center isn't, steer that way.
	var probes := [desired, desired.rotated(Vector3.UP, 0.6), desired.rotated(Vector3.UP, -0.6)]
	for i in range(probes.size()):
		var p: Vector3 = probes[i]
		var test_pos := global_position + Vector3.UP * 0.5
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			test_pos, test_pos + p * 1.4, 1, [self])
		var result := space.intersect_ray(query)
		if result.is_empty():
			# clear path
			if i == 0:
				return desired
			return p
	return desired


func _apply_gravity_and_slide(delta: float, _dir: Vector3) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


# ── Catch / flow ──────────────────────────────────────────────────
func _caught() -> void:
	caught_player.emit()
	if _game and _game.has_method("trigger_death"):
		_game.trigger_death()


func _on_game_over() -> void:
	# Will be frozen next frame by the _game.game_over guard.
	pass
