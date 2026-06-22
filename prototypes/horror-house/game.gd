extends Node
## BLACKOUT — central game-state manager.
## Attached to the scene root. Owns the objective loop, flow (intro/win/death),
## and broadcasts state changes so other systems (HUD, monster, audio, scares)
## can react without holding hard references.
##
## Phase 1 scope: fuse count, breaker/door logic, win trigger.
## Later phases: intro card, death sequence, audio cues, scare triggers.

# ── Signals (decoupled communication) ─────────────────────────────
signal fuse_collected(total: int)       # a fuse was picked up; new total
signal fuse_inserted(total: int)        # a fuse was slotted at the breaker
signal power_restored                   # all 3 fuses inserted
signal door_unlocked                    # breaker engaged → front door opens
signal won                              # player reached the exit
signal died                             # monster caught the player
signal game_started                     # title dismissed, play begins
signal game_reset                       # scene about to reload

# ── State ─────────────────────────────────────────────────────────
const FUSES_REQUIRED := 3

var fuses_held: int = 0       # picked up but not yet inserted
var fuses_inserted: int = 0   # slotted into the breaker
var power_on: bool = false    # breaker fully engaged
var door_open: bool = false   # front door released
var game_over: bool = false   # win or death lock
var started: bool = false     # title dismissed; gameplay active
var has_key: bool = false     # found the rusty key → can open the gate

@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")


func _ready() -> void:
	add_to_group("game")
	power_restored.connect(_on_power_restored)
	door_unlocked.connect(_on_door_unlocked)
	won.connect(_on_won)
	died.connect(_on_died)


# ── Objective loop ────────────────────────────────────────────────
func collect_fuse() -> void:
	if game_over:
		return
	fuses_held += 1
	fuse_collected.emit(fuses_held)


func insert_fuse() -> bool:
	# Called by the breaker interactable. Returns true if a fuse was consumed.
	if game_over or fuses_held <= 0 or fuses_inserted >= FUSES_REQUIRED:
		return false
	fuses_held -= 1
	fuses_inserted += 1
	fuse_inserted.emit(fuses_inserted)
	if fuses_inserted >= FUSES_REQUIRED:
		power_on = true
		power_restored.emit()
	return true


func _on_power_restored() -> void:
	# The breaker is fully engaged → release the front door.
	door_open = true
	door_unlocked.emit()


func reach_exit() -> void:
	# Called by the exit trigger when the (open) door is passed through.
	if game_over or not door_open:
		return
	game_over = true
	won.emit()


func trigger_death() -> void:
	# Called by the monster on catch. Idempotent.
	if game_over:
		return
	game_over = true
	died.emit()


# ── Key + locked gate (puzzle) ─────────────────────────────────
func collect_key() -> void:
	has_key = true
	_open_gate()


func _open_gate() -> void:
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl and lvl.has_method("open_gate"):
		lvl.open_gate()
	print("[BLACKOUT] The key turns. The gate grinds open.")


# ── Flow ─────────────────────────────────────────────────────────
func start_game() -> void:
	# Called by the title overlay when the player begins.
	if started:
		return
	started = true
	# Authoritatively capture the mouse for first-person look. Doing it here (on
	# the root) avoids the child-_ready ordering race where the player would try
	# to wire this up before the root joins the "game" group.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game_started.emit()


func restart() -> void:
	# Reload the current scene fresh (win/death → retry).
	game_reset.emit()
	get_tree().reload_current_scene()


# ── Flow input ─────────────────────────────────────────────────────
# Handled on the root (not the HUD CanvasLayer) so it reliably receives
# keyboard input regardless of GUI focus / mouse-capture state.
func _unhandled_input(event: InputEvent) -> void:
	var pressed := event.is_action_pressed("interact") or event.is_action_pressed("flashlight") or event.is_action_pressed("ui_accept")
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if not (pressed or click):
		return
	if not started:
		start_game()
	elif game_over:
		restart()


# ── Flow stubs (filled in Phase 6) ────────────────────────────────
func _on_won() -> void:
	print("[BLACKOUT] ESCAPE — you made it out.")


func _on_died() -> void:
	print("[BLACKOUT] He found you.")


func _on_door_unlocked() -> void:
	print("[BLACKOUT] The magnetic lock releases. The door is open.")
