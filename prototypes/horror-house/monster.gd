extends CharacterBody3D

enum State { PATROL, CHASE, IDLE }

@export var walk_speed: float = 2.0
@export var run_speed: float = 5.5
@export var detection_range: float = 10.0
@export var lose_range: float = 16.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var state: State = State.IDLE
var player: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _patrol_targets: Array[Vector3] = []
var _patrol_idx: int = 0

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	_patrol_targets = [
		global_position + Vector3(4, 0, 0),
		global_position + Vector3(0, 0, 4),
		global_position + Vector3(-4, 0, 0),
		global_position + Vector3(0, 0, -4),
	]
	state = State.PATROL

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	match state:
		State.PATROL: _patrol(delta)
		State.CHASE: _chase(delta)

	_update_state()
	move_and_slide()

func _update_state() -> void:
	if not player:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < detection_range:
		state = State.CHASE
	elif state == State.CHASE and dist > lose_range:
		state = State.PATROL

func _patrol(_delta: float) -> void:
	if _patrol_targets.is_empty():
		return
	nav_agent.target_position = _patrol_targets[_patrol_idx]
	var next := nav_agent.get_next_path_position()
	var dir := (next - global_position).normalized()
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	if dir.length() > 0.1:
		look_at(global_position + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
	if global_position.distance_to(_patrol_targets[_patrol_idx]) < 1.2:
		_patrol_idx = (_patrol_idx + 1) % _patrol_targets.size()

func _chase(_delta: float) -> void:
	if not player:
		return
	nav_agent.target_position = player.global_position
	var next := nav_agent.get_next_path_position()
	var dir := (next - global_position).normalized()
	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed
	if dir.length() > 0.1:
		look_at(global_position + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
