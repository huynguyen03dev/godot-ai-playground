extends CharacterBody3D
## BLACKOUT — the monster (zombie).
##
## Lives in the haunted house. Two layers:
##   1. NAVIGATION — A* pathfinding over the level's 4 m grid. Works in
##      corridors/rooms without a baked navmesh. The monster follows the
##      cell-centre path, recomputing every ~0.4 s or when the path is done.
##   2. DETECTION — the core light/noise polarity:
##        • Flashlight on + line-of-sight  → spotted from far (a beacon).
##        • Sprinting                       → heard at medium range.
##        • Crouch + dark + still           → invisible (the survival state).
##
## It is ACTIVE: even without a fix on you it patrols toward your last-known
## area, so hiding in one room forever is not safe. On catch → game.trigger_death().

signal state_changed(state: int)
signal spotted_player()
signal lost_player()
signal caught_player()

enum State { DORMANT, PATROL, CHASE, RETURN }

# ── Detection tuning ──────────────────────────────────────────────
@export var sight_range_flashlight: float = 22.0
@export var sight_range_dark: float = 5.0
@export var noise_hear_range: float = 12.0
@export var lose_sight_time: float = 5.0

# ── Movement tuning ───────────────────────────────────────────────
@export var patrol_speed: float = 2.6
@export var chase_speed: float = 4.2
@export var return_speed: float = 3.0
@export var acceleration: float = 7.0
@export var turn_speed: float = 6.0

# ── Catch ─────────────────────────────────────────────────────────
@export var catch_range: float = 1.3
@export var spawn_delay: float = 7.0    # grace period once play begins

# ── Pathfinding ───────────────────────────────────────────────────
@export var repath_interval: float = 0.4

# ── Nodes ─────────────────────────────────────────────────────────
@onready var _head: Node3D = $Head
@onready var _eyes: RayCast3D = $Head/Eyes

# ── State ─────────────────────────────────────────────────────────
var state: State = State.DORMANT
var player: CharacterBody3D = null
var _game: Node = null
var _level: Node = null
var _spawn_timer: float = 0.0
var _spotted_this_chase: bool = false
var _has_los: bool = false
var _los_lost_timer: float = 0.0
var _last_known_cell: Vector2i = Vector2i(-1, -1)

# Path
var _path: Array[Vector2i] = []
var _path_idx: int = 0
var _repath_timer: float = 0.0
var _home_cell: Vector2i = Vector2i(-1, -1)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("monster")
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	_game = get_tree().get_first_node_in_group("game")
	_level = get_tree().get_first_node_in_group("level")
	if _game:
		_game.died.connect(_on_game_over)
		_game.won.connect(_on_game_over)
		if _game.has_signal("game_started"):
			_game.game_started.connect(_on_game_started)
	state = State.DORMANT


func _on_game_started() -> void:
	_spawn_timer = 0.0


func _on_game_over() -> void:
	pass  # the per-frame game_over guard freezes us


# ── Main loop ─────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not player or not _game or not _level:
		_apply_gravity_and_slide(delta)
		return

	# Hold dormant (frozen) until the game has actually started.
	if "started" in _game and not _game.started:
		velocity = Vector3.ZERO
		_apply_gravity_and_slide(delta)
		return

	if _game.game_over:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		_apply_gravity_and_slide(delta)
		return

	if state == State.DORMANT:
		_spawn_timer += delta
		if _spawn_timer >= spawn_delay:
			_home_cell = _level.world_to_cell(global_position)
			_last_known_cell = _home_cell
			_set_state(State.PATROL)
		velocity = Vector3.ZERO
		_apply_gravity_and_slide(delta)
		return

	_update_perception()
	_update_state_machine(delta)
	_navigate(delta)
	_apply_gravity_and_slide(delta)


# ── Perception (light + noise) ────────────────────────────────────
func _update_perception() -> void:
	_has_los = _has_line_of_sight()
	if _has_los:
		_last_known_cell = _level.world_to_cell(player.global_position)
		_los_lost_timer = 0.0
	else:
		_los_lost_timer += get_physics_process_delta_time()


func _has_line_of_sight() -> bool:
	if not player:
		return false
	var to_player := player.global_position + Vector3.UP * 0.9 - _head.global_position
	var dist := to_player.length()

	# 1. Hearing — noise betrays the player through walls, at close range.
	var noise: float = float(player.get("noise_level"))
	if noise > 0.05 and dist < noise_hear_range * noise:
		return true

	# 2. Sight — flashlight extends range dramatically.
	var max_sight := sight_range_flashlight if bool(player.get("flashlight_on")) else sight_range_dark
	if dist > max_sight:
		return false

	# 3. Ray test for occlusion (walls).
	_eyes.target_position = _eyes.to_local(player.global_position + Vector3.UP * 0.9)
	_eyes.force_raycast_update()
	if _eyes.is_colliding():
		var col := _eyes.get_collider()
		if col != player and not col.is_ancestor_of(player):
			return false
	return true


# ── State machine ─────────────────────────────────────────────────
func _update_state_machine(_delta: float) -> void:
	match state:
		State.PATROL:
			if _has_los:
				_begin_chase()
		State.CHASE:
			if not _has_los and _los_lost_timer > lose_sight_time:
				if not _spotted_this_chase:
					pass
				_spotted_this_chase = false
				lost_player.emit()
				_set_state(State.RETURN)
			if global_position.distance_to(player.global_position) < catch_range:
				_caught()
		State.RETURN:
			if _has_los:
				_begin_chase()
			elif _level.world_to_cell(global_position) == _home_cell:
				_set_state(State.PATROL)


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


# ── Navigation (A* over the level grid) ───────────────────────────
func _navigate(delta: float) -> void:
	# Decide a target cell.
	var target_cell: Vector2i
	match state:
		State.CHASE:
			target_cell = _last_known_cell
		State.RETURN:
			target_cell = _home_cell
		_:  # PATROL — drift toward the player's last-known area, then wander.
			var my_cell: Vector2i = _level.world_to_cell(global_position)
			if _last_known_cell.x >= 0 and my_cell != _last_known_cell:
				target_cell = _last_known_cell
			else:
				target_cell = _random_walkable_cell_near(my_cell, 5)

	# Repath on a timer, when the path is exhausted, or when chasing the player
	# (whose cell keeps moving).
	_repath_timer -= delta
	var need_repath := _repath_timer <= 0.0 or _path.size() == 0 or _path_idx >= _path.size()
	if state == State.CHASE:
		need_repath = need_repath or (_path.size() > 0 and _path[_path.size() - 1] != target_cell)
	if need_repath:
		_repath_timer = repath_interval
		_path = _find_path(_level.world_to_cell(global_position), target_cell)
		_path_idx = 1 if _path.size() > 1 else 0

	# Move toward the current waypoint.
	var speed := patrol_speed if state != State.CHASE else chase_speed
	if state == State.RETURN:
		speed = return_speed
	var dir := Vector3.ZERO
	if _path_idx < _path.size():
		var wp_cell: Vector2i = _path[_path_idx]
		var wp: Vector3 = _level.cell_to_world(wp_cell)
		var to: Vector3 = wp - global_position
		to.y = 0.0
		if to.length() < 0.6:
			_path_idx += 1
		else:
			dir = to.normalized()
	_move_toward(dir, speed, delta)


func _find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# A* over walkable grid cells (4-neighbourhood). Returns cell list including
	# start and goal, or empty if unreachable.
	if not _level.is_walkable(goal):
		goal = _nearest_walkable(goal)
	if not _level.is_walkable(start) or not _level.is_walkable(goal):
		return []
	var open: Array = []  # [f, g, cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	open.append([_h(start, goal), 0, start])
	var closed: Dictionary = {}
	while open.size() > 0:
		# pop lowest f (linear scan — grids are small)
		open.sort_custom(func(a, b): return a[0] < b[0])
		var cur: Array = open.pop_front()
		var cur_cell: Vector2i = cur[2]
		if cur_cell == goal:
			return _reconstruct(came_from, cur_cell, start)
		if closed.has(cur_cell):
			continue
		closed[cur_cell] = true
		for n in _neighbors(cur_cell):
			if closed.has(n) or not _level.is_walkable(n):
				continue
			var tentative: int = g_score[cur_cell] + 1
			if not g_score.has(n) or tentative < g_score[n]:
				g_score[n] = tentative
				came_from[n] = cur_cell
				open.append([tentative + _h(n, goal), tentative, n])
	return []


func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
			cell + Vector2i(0, 1), cell + Vector2i(0, -1)]


func _h(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _reconstruct(came_from: Dictionary, cell: Vector2i, start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [cell]
	var cur: Vector2i = cell
	while cur != start and came_from.has(cur):
		cur = came_from[cur]
		path.push_front(cur)
	return path


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	# Spiral outward to find the nearest walkable cell (goal may sit on a wall).
	if _level.is_walkable(cell):
		return cell
	for radius in range(1, 4):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var c := cell + Vector2i(dx, dy)
				if _level.is_walkable(c):
					return c
	return cell


func _random_walkable_cell_near(cell: Vector2i, radius: int) -> Vector2i:
	for _i in range(12):
		var dx := randi_range(-radius, radius)
		var dy := randi_range(-radius, radius)
		if dx == 0 and dy == 0:
			continue
		var c := cell + Vector2i(dx, dy)
		if _level.is_walkable(c):
			return c
	return cell


# ── Movement ──────────────────────────────────────────────────────
func _move_toward(dir: Vector3, speed: float, delta: float) -> void:
	var target_vel := dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
	if Vector2(velocity.x, velocity.z).length() > 0.15:
		var angle := atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, angle, turn_speed * delta)


func _apply_gravity_and_slide(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


# ── Catch / flow ──────────────────────────────────────────────────
func _caught() -> void:
	caught_player.emit()
	if _game and _game.has_method("trigger_death"):
		_game.trigger_death()
