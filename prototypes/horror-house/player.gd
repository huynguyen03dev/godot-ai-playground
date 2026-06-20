extends CharacterBody3D
## BLACKOUT — first-person player controller.
##
## Movement: walk / sprint (stamina-limited) / crouch.
## Flashlight: F toggles the headlamp — your only light, and the monster's beacon.
## Interaction: E performs a forward raycast; nearby interactables show a prompt.
##
## Exposes state (flashlight_on, is_sprinting, is_crouched, stamina, noise_level)
## so the monster's detection model and the audio system can read it without
## holding a hard reference. The "light vs noise" polarity is the whole game.

# ── Signals ───────────────────────────────────────────────────────
signal flashlight_toggled(on: bool)
signal stamina_changed(ratio: float)        # 0..1
signal interaction_prompt(text: String)     # "" hides the prompt
signal interacted(target: Node)             # E was pressed on a valid target

# ── Movement tuning (DESIGN.md §12) ───────────────────────────────
const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.5
const CROUCH_SPEED := 1.8
const MOUSE_SENSITIVITY := 0.0028
const EYE_HEIGHT := 0.7
const CROUCH_HEIGHT := 0.35
const STAND_HEIGHT := 1.7

# ── Stamina ───────────────────────────────────────────────────────
const MAX_STAMINA := 4.0                    # seconds of sprint
const STAMINA_DRAIN := 1.0                  # per second sprinting
const STAMINA_REGEN := 0.66                 # per second recovering (~1.5s to full)
const STAMINA_REGEN_DELAY := 1.2            # delay after drain before regen

# ── Interaction ───────────────────────────────────────────────────
const INTERACT_RANGE := 2.6

# ── Nodes ─────────────────────────────────────────────────────────
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay

# ── State (read by monster/audio) ─────────────────────────────────
var flashlight_on: bool = false
var is_sprinting: bool = false
var is_crouched: bool = false
var stamina: float = MAX_STAMINA
var noise_level: float = 0.0                # 0..1, derived from movement
var _stamina_regen_timer: float = 0.0
var _target_eye_height: float = EYE_HEIGHT
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not interact_ray:
		interact_ray = _make_interact_ray()
	flashlight.visible = false
	# Release the cursor while the title screen is up; recapture on game start.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var g := get_tree().get_first_node_in_group("game")
	if g and g.has_signal("game_started"):
		g.game_started.connect(_on_started)


func _make_interact_ray() -> RayCast3D:
	var r := RayCast3D.new()
	r.target_position = Vector3.FORWARD * INTERACT_RANGE
	r.enabled = true
	r.collision_mask = 1
	camera.add_child(r)
	return r


func _on_started() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore gameplay input until the title is dismissed.
	var g := get_tree().get_first_node_in_group("game")
	if g and "started" in g and not g.started:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2.0, PI / 2.0)

	if event.is_action_pressed("flashlight"):
		flashlight_on = !flashlight_on
		flashlight.visible = flashlight_on
		flashlight_toggled.emit(flashlight_on)

	if event.is_action_pressed("interact"):
		_try_interact()

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	# Freeze the body while the title screen is showing.
	var g := get_tree().get_first_node_in_group("game")
	if g and "started" in g and not g.started:
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Crouch (hold)
	var want_crouch := Input.is_action_pressed("crouch")
	if want_crouch != is_crouched:
		is_crouched = want_crouch
		_target_eye_height = CROUCH_HEIGHT if is_crouched else EYE_HEIGHT

	# Sprint only when upright, moving, and has stamina
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var moving := input_dir.length_squared() > 0.05
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouched and moving and stamina > 0.0

	var speed: float
	if is_crouched:
		speed = CROUCH_SPEED
	elif is_sprinting:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Stamina
	if is_sprinting:
		stamina = max(0.0, stamina - STAMINA_DRAIN * delta)
		_stamina_regen_timer = STAMINA_REGEN_DELAY
	elif is_on_floor():
		_stamina_regen_timer = max(0.0, _stamina_regen_timer - delta)
		if _stamina_regen_timer <= 0.0:
			stamina = min(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
	stamina_changed.emit(stamina / MAX_STAMINA)

	# Horizontal velocity (smooth accel)
	var direction := (head.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if is_on_floor():
		var accel := 12.0 if moving else 14.0
		velocity.x = velocity.move_toward(direction * speed, accel * delta).x
		velocity.z = velocity.move_toward(direction * speed, accel * delta).z
	else:
		velocity.x = move_toward(velocity.x, direction.x * speed, 1.5 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 1.5 * delta)

	move_and_slide()

	# Smooth crouch eye-height
	head.position.y = lerp(head.position.y, _target_eye_height, 10.0 * delta)

	# Derived noise level for monster detection & audio
	if is_crouched:
		noise_level = 0.1 if moving else 0.0
	elif is_sprinting:
		noise_level = 1.0
	elif moving:
		noise_level = 0.4
	else:
		noise_level = 0.0

	_refresh_interaction_prompt()


# ── Interaction ───────────────────────────────────────────────────
func _try_interact() -> void:
	var t := _current_interactable()
	if t and t.has_method("interact"):
		interacted.emit(t)
		t.interact(self)


func _current_interactable() -> Node:
	# Proximity + facing check. The facing test runs on the HORIZONTAL plane
	# so wall-mounted objects above eye level (breaker box, door panel) can
	# still be targeted when the player looks straight ahead at the wall.
	var best: Node = null
	var best_score: float = -INF
	var fwd := -head.global_transform.basis.z.normalized()
	var fwd_xz := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var here := global_position + Vector3.UP * 0.5
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n is Node3D:
			continue
		var to: Vector3 = (n.global_position - here)
		var dist := to.length()
		if dist > INTERACT_RANGE:
			continue
		var to_xz := Vector3(to.x, 0.0, to.z)
		var facing: float
		if to_xz.length() < 0.05:
			# Directly above/below (player under a wall-mounted object):
			# count as centered enough to interact.
			facing = 0.5
		else:
			facing = fwd_xz.dot(to_xz.normalized())
			if facing < 0.1:  # within ~84° horizontally of view forward
				continue
		# Prefer targets that are both centered and close.
		var score := facing - dist * 0.1
		if score > best_score:
			best_score = score
			best = n
	return best


func _refresh_interaction_prompt() -> void:
	var t := _current_interactable()
	if t and "prompt" in t:
		interaction_prompt.emit(String(t.prompt))
	elif t and t.has_method("get_prompt"):
		interaction_prompt.emit(t.get_prompt())
	else:
		interaction_prompt.emit("")
