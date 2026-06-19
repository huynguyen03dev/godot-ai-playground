extends OmniLight3D

@export var min_energy: float = 0.3
@export var max_energy: float = 1.8
@export var flicker_speed: float = 12.0
@export var off_chance: float = 0.015

var _target_energy: float
var _time_off: float = 0.0

func _ready() -> void:
	_target_energy = light_energy

func _process(delta: float) -> void:
	if _time_off > 0.0:
		light_energy = 0.0
		_time_off -= delta
		return

	if randf() < off_chance:
		_time_off = randf_range(0.04, 0.25)
		return

	_target_energy = randf_range(min_energy, max_energy)
	light_energy = lerp(light_energy, _target_energy, flicker_speed * delta)
