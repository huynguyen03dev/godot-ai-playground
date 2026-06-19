extends ColorRect

func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://prototypes/horror-house/horror_effect.gdshader")
	material = mat
	# Pulse vignette when monster is near
	set_process(true)

func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if not mat:
		return
	var player := get_tree().get_first_node_in_group("player")
	var monster := get_tree().get_first_node_in_group("monster")
	if player and monster:
		var dist: float = (player as Node3D).global_position.distance_to((monster as Node3D).global_position)
		var threat: float = clamp(1.0 - dist / 14.0, 0.0, 1.0)
		mat.set_shader_parameter("vignette_strength", 1.1 + threat * 1.2)
		mat.set_shader_parameter("chroma_offset", 0.004 + threat * 0.012)
		mat.set_shader_parameter("grain_strength", 0.07 + threat * 0.08)
