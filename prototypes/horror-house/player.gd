extends CharacterBody3D

const SPEED = 4.0
const SPRINT_SPEED = 6.5
const MOUSE_SENSITIVITY = 0.003

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2.0, PI / 2.0)
	if event.is_action_pressed("flashlight"):
		flashlight.visible = !flashlight.visible
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var sprinting := Input.is_action_pressed("sprint")
	var speed := SPRINT_SPEED if sprinting else SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if is_on_floor():
		velocity.x = direction.x * speed if direction else move_toward(velocity.x, 0.0, speed)
		velocity.z = direction.z * speed if direction else move_toward(velocity.z, 0.0, speed)
	else:
		velocity.x = move_toward(velocity.x, direction.x * speed, 0.3)
		velocity.z = move_toward(velocity.z, direction.z * speed, 0.3)

	move_and_slide()
