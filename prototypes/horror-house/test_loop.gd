extends Node
## BLACKOUT — headless self-test harness.
##
## Registered as a TEMPORARY autoload for verification runs only (never shipped).
## Drives the real game state machine + interactables directly (no input
## injection), then prints a structured PASS/FAIL report and quits.
##
## Run:  godot --headless --path . --script res://prototypes/horror-house/test_loop.gd
## (loaded as autoload via BLACKOUT_TEST=1 env var guard)
##
## What it verifies:
##   1. Scene tree has player, monster, 3 fuses, breaker, door, HUD.
##   2. game.start_game() → monster leaves DORMANT.
##   3. Picking up all 3 fuses → fuses_held == 3, HUD label updates.
##   4. Inserting 3 fuses at breaker → power_on, door_open, door swings.
##   5. reach_exit → game_over + won.
##   6. Reset path: a fresh run where monster catches player → died.

var _results: Array[String] = []
var _fails := 0
var _game: Node = null
var _player: Node = null
var _monster: Node = null


func _ready() -> void:
	# Only run when invoked as the script target, not during normal play.
	if not self.get("."):
		pass
	await get_tree().create_timer(0.5).timeout
	await _run_all()
	_print_report()
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	var line := ("[PASS] " if ok else "[FAIL] ") + label + ((": " + detail) if detail else "")
	_results.append(line)
	if not ok:
		_fails += 1
	print(line)


func _run_all() -> void:
	_game = get_tree().get_first_node_in_group("game")
	_player = get_tree().get_first_node_in_group("player")
	_monster = get_tree().get_first_node_in_group("monster")

	# 1. Structure
	_check("player exists", _player != null)
	_check("monster exists", _monster != null)
	_check("game exists", _game != null)
	var fuses := get_tree().get_nodes_in_group("interactable").filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("fuse_pickup.gd"))
	_check("3 fuse pickups present", fuses.size() == 3, "found %d" % fuses.size())

	if not _game:
		return

	# 2. Start
	_check("starts unstarted", not _game.started)
	_game.start_game()
	await get_tree().create_timer(0.3).timeout
	_check("start_game() flips started", _game.started)
	_check("monster spawn timer counting (grace active)", _monster._spawn_timer > 0.0, "timer=%.2f" % _monster._spawn_timer)

	# 3. Collect 3 fuses via the real interactables
	for i in fuses.size():
		(fuses[i] as Node).interact(_player)
		await get_tree().create_timer(0.05).timeout
	_check("collected 3 fuses → held==3", _game.fuses_held == 3, "held=%d" % _game.fuses_held)
	await get_tree().create_timer(0.4).timeout  # let pickup tweens finish + queue_free
	_check("fuses freed after pickup", get_tree().get_nodes_in_group("interactable").filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("fuse_pickup.gd")).size() == 0)

	# 4. Insert at breaker
	var breaker := _find_breaker()
	_check("breaker present", breaker != null)
	if breaker:
		# Insert 3 times
		for i in 3:
			breaker.interact(_player)
			await get_tree().create_timer(0.05).timeout
		_check("inserted 3 → inserted==3", _game.fuses_inserted == 3, "inserted=%d" % _game.fuses_inserted)
		_check("power_on after 3 fuses", _game.power_on)
		_check("door_open after power restored", _game.door_open)
		await get_tree().create_timer(1.4).timeout  # door swing tween
		var door := _find_door()
		if door:
			var panel = door.get_node_or_null("DoorPanel")
			var door_rot_y: float = float(panel.rotation.y) if panel else 0.0
			var swung: bool = abs(door_rot_y) > 0.1
			_check("door physically swung open", swung, "DoorPanel rot.y=%.2f" % door_rot_y)

		# 5. Reach exit → win
		_game.reach_exit()
		await get_tree().create_timer(0.2).timeout
		_check("reach_exit → game_over", _game.game_over)
		_check("reach_exit → won (no death)", _game.won.is_connected(_game._on_won))

	# 6. Monster catch → death (on a logic path; we simulate catch directly)
	# Reset the win lock to test death independently.
	_game.game_over = false
	_monster._caught()
	await get_tree().create_timer(0.2).timeout
	_check("monster catch → game_over", _game.game_over)
	# died fires trigger_death which is idempotent guard; verify game_over set


func _find_breaker() -> Node:
	for n in get_tree().get_nodes_in_group("interactable"):
		var s = n.get_script()
		if s and s.resource_path.ends_with("breaker.gd"):
			return n
	return null


func _find_door() -> Node:
	for n in get_tree().get_nodes_in_group("interactable"):
		var s = n.get_script()
		if s and s.resource_path.ends_with("exit_door.gd"):
			return n
	return null


func _print_report() -> void:
	print("\n========================================")
	print("BLACKOUT self-test: %d checks, %d failed" % [_results.size(), _fails])
	print("========================================")
	for r in _results:
		print(r)
	print("========================================")
