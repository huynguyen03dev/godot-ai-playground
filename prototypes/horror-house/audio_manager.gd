extends Node
## BLACKOUT — central audio manager (autoload singleton: AudioManager).
##
## Owns every AudioStreamPlayer and reacts to game / player / monster signals
## so the rest of the codebase never touches audio directly. One-shots share a
## small pool; loops (ambient, breathing, heartbeat) have dedicated players.
##
## Audio map (all assets under res://assets/horror/audio/):
##   ambient  : drone_low_loop + room_tone_basement  (always, low)
##   music    : title_bed                            (title screen only)
##   footsteps: player_step_walk_* / sprint          (movement-driven)
##   sfx      : fuse_pickup / fuse_insert / breaker_engage / door_unlock /
##              flashlight_click / death_sting
##   threat   : breathing_wet_loop + heartbeat_*      (proximity to monster)
##              monster_vocal + scare_sting_general   (on spotted)
##   win      : win_rain                              (escape)

# ── Paths ─────────────────────────────────────────────────────────
const DIR := "res://assets/horror/audio/"
const AMBIENT_DRONE   := DIR + "ambient/drone_low_loop.mp3"
const AMBIENT_ROOM    := DIR + "ambient/room_tone_basement.mp3"
const MUSIC_TITLE     := DIR + "music/title_bed.mp3"
const S_FUSE_PICKUP   := DIR + "sfx/fuse_pickup.mp3"
const S_FUSE_INSERT   := DIR + "sfx/fuse_insert.mp3"
const S_BREAKER       := DIR + "sfx/breaker_engage.mp3"
const S_DOOR          := DIR + "sfx/door_unlock.mp3"
const S_FLASHLIGHT    := DIR + "sfx/flashlight_click.mp3"
const S_DEATH         := DIR + "sfx/death_sting.mp3"
const S_STEP_WALK1    := DIR + "sfx/player_step_walk_01.mp3"
const S_STEP_WALK2    := DIR + "sfx/player_step_walk_02.mp3"
const S_STEP_SPRINT   := DIR + "sfx/player_step_sprint_01.mp3"
const T_BREATHING     := DIR + "threat/breathing_wet_loop.mp3"
const T_HEARTBEAT_60  := DIR + "threat/heartbeat_60.mp3"
const T_HEARTBEAT_75  := DIR + "threat/heartbeat_75.mp3"
const T_VOCAL         := DIR + "threat/monster_vocal.mp3"
const SCARE_STING     := DIR + "scares/scare_sting_general.mp3"
const WIN_RAIN        := DIR + "ambient/win_rain.mp3"

# ── Loop players ──────────────────────────────────────────────────
var _amb_drone: AudioStreamPlayer
var _amb_room: AudioStreamPlayer
var _music: AudioStreamPlayer
var _breathing: AudioStreamPlayer
var _heartbeat: AudioStreamPlayer
var _win_rain: AudioStreamPlayer

# ── One-shot pool ─────────────────────────────────────────────────
var _pool: Array[AudioStreamPlayer] = []
const POOL_SIZE := 6
var _pool_idx := 0

# ── Footstep state ────────────────────────────────────────────────
var _step_timer := 0.0
var _step_idx := 0

# ── Internal ──────────────────────────────────────────────────────
var _game: Node = null
var _player: Node = null
var _monster: Node = null
var _master_muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_loop_players()
	_setup_pool()
	# Begin ambient + title music immediately (title screen is up at start).
	_start_loop(_amb_drone, AMBIENT_DRONE, -14.0)
	_start_loop(_amb_room, AMBIENT_ROOM, -22.0)
	_start_loop(_music, MUSIC_TITLE, -16.0)
	_start_loop(_breathing, T_BREATHING, -40.0)   # silent until threat near
	_start_loop(_heartbeat, T_HEARTBEAT_60, -40.0)
	await get_tree().create_timer(0.2).timeout
	_connect_signals()


func _setup_loop_players() -> void:
	for path in ["_amb_drone", "_amb_room", "_music", "_breathing", "_heartbeat", "_win_rain"]:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		set(path, p)


func _setup_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func _start_loop(p: AudioStreamPlayer, path: String, vol_db: float) -> void:
	var s := load(path)
	if s == null:
		return
	# Mark looping streams (mp3 imports loop off by default).
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	p.stream = s
	p.volume_db = vol_db
	p.play()


func _connect_signals() -> void:
	_game = get_tree().get_first_node_in_group("game")
	_player = get_tree().get_first_node_in_group("player")
	_monster = get_tree().get_first_node_in_group("monster")
	if _game:
		_game.fuse_collected.connect(func(_t): play(S_FUSE_PICKUP, -6.0))
		_game.fuse_inserted.connect(func(_t): play(S_FUSE_INSERT, -4.0))
		_game.power_restored.connect(func(): play(S_BREAKER, -3.0))
		_game.door_unlocked.connect(func(): play(S_DOOR, -5.0))
		_game.won.connect(_on_won)
		_game.died.connect(_on_died)
		if _game.has_signal("game_started"):
			_game.game_started.connect(_on_started)
	if _player:
		_player.flashlight_toggled.connect(func(_on): play(S_FLASHLIGHT, -8.0))
	if _monster:
		_monster.spotted_player.connect(_on_spotted)


# ── Public one-shot ───────────────────────────────────────────────
func play(path: String, vol_db: float = -6.0) -> void:
	if _master_muted:
		return
	var s := load(path)
	if s == null:
		return
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = false
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = vol_db
	p.play()


# ── Event reactions ───────────────────────────────────────────────
func _on_started() -> void:
	# Fade title music out; gameplay relies on ambient + threat beds.
	var t := create_tween()
	t.tween_property(_music, "volume_db", -40.0, 1.5)
	t.tween_callback(_music.stop)


func _on_spotted() -> void:
	play(T_VOCAL, -4.0)
	play(SCARE_STING, -8.0)


func _on_won() -> void:
	# Cut the dread beds, let the rain in.
	_breathing.volume_db = -40.0
	_heartbeat.volume_db = -40.0
	_start_loop(_win_rain, WIN_RAIN, -10.0)


func _on_died() -> void:
	play(S_DEATH, 0.0)


# ── Per-frame: footsteps + threat-bed ducking ─────────────────────
func _process(delta: float) -> void:
	if not _player or not _game:
		return
	if "started" in _game and not _game.started:
		return
	_update_footsteps(delta)
	_update_threat_beds()


func _update_footsteps(delta: float) -> void:
	if not ("is_sprinting" in _player and "is_crouched" in _player and "noise_level" in _player):
		return
	var noise: float = float(_player.get("noise_level"))
	var moving := noise > 0.05
	if not moving:
		_step_timer = 0.0
		return
	# Cadence: sprint fast, crouch silent, walk medium. Crouch makes no steps.
	if bool(_player.get("is_crouched")):
		return
	var sprinting := bool(_player.get("is_sprinting"))
	var interval := 0.34 if sprinting else 0.52
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = interval
		if sprinting:
			play(S_STEP_SPRINT, -12.0)
		else:
			play(S_STEP_WALK1 if _step_idx % 2 == 0 else S_STEP_WALK2, -16.0)
			_step_idx += 1


func _update_threat_beds() -> void:
	if not _monster or not _player:
		return
	if not (is_instance_valid(_monster) and is_instance_valid(_player)):
		return
	if not (_monster.is_inside_tree() and _player.is_inside_tree()):
		return
	if not (_monster is Node3D) or not (_player is Node3D):
		return
	if not ("global_position" in _monster) or not ("global_position" in _player):
		return
	var dist: float = (_monster as Node3D).global_position.distance_to((_player as Node3D).global_position)
	# Threat rises as the monster closes within ~12m.
	var threat: float = clamp(1.0 - dist / 12.0, 0.0, 1.0)
	# Breathing: inaudible far, present close.
	_breathing.volume_db = lerp(-40.0, -10.0, threat)
	# Heartbeat: only when very close; switch to the faster loop near death.
	if threat > 0.45:
		_heartbeat.volume_db = lerp(-40.0, -8.0, (threat - 0.45) / 0.55)
		if threat > 0.75 and _heartbeat.stream.resource_path != T_HEARTBEAT_75:
			var s := load(T_HEARTBEAT_75) as AudioStreamMP3
			s.loop = true
			_heartbeat.stream = s
			if not _heartbeat.playing:
				_heartbeat.play()
	else:
		_heartbeat.volume_db = -40.0
