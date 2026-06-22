extends Node3D
## BLACKOUT — procedural house level.
##
## Builds a multi-room haunted house from an ASCII floorplan. Each cell is a
## 4×4 m tile. The generator places:
##   • floors + ceilings on every walkable cell (enclosed, dark)
##   • wall meshes + box colliders on every '#' cell
##   • doorway / gate markers
##   • atmosphere props (furniture, blood, grime) in rooms
##   • records spawn points for player / monster / fuses / breaker / exit / key
##
## Floorplan legend (one char per 4 m cell):
##   #  solid wall
##   .  floor (walkable)
##   D  doorway (walkable, open passage — just floor, neighbours form the frame)
##   G  locked gate (blocks until the key puzzle is solved, then opens)
##   P  player spawn
##   M  monster spawn
##   1 2 3   fuse spawn points
##   B  breaker
##   X  exit (front door — walk into it to win, once power is on)
##   K  key (opens the gate G)
##
## The grid is also the monster's navigation graph: walkable cells are nodes,
## orthogonally-adjacent walkable cells are edges. No navmesh bake needed.

const CELL := 4.0          # tile size (matches the Kenney dungeon kit)
const WALL_H := 4.2        # wall + ceiling height
const FLOOR_Y := 0.0
const CEIL_Y := WALL_H

# ── The floorplan ─────────────────────────────────────────────────
# A haunted house: entrance hall (south) → branching corridors → rooms
# holding the fuses, key, and breaker. A locked gate guards a shortcut.
# Edit this string to reshape the house; everything else auto-adapts.
const PLAN := [
	"#################",  # 0  border
	"#......#.#......#",  # 1  NW room (study)  | spine | NE room (bedroom)
	"#..1...#.#...M..#",  # 2  fuse1            |       | monster spawn
	"#......#.#......#",  # 3
	"#......#.#......#",  # 4
	"#......#.#......#",  # 5
	"#......#.#......#",  # 6
	"##.#####.#####.##",  # 7  doorways: col2 (NW→crossbar), col8 (spine), col14 (NE→crossbar)
	"#...B.......2...#",  # 8  horizontal crossbar: breaker (W), fuse2 (E)
	"##.#####.#####G##",  # 9  doorways: col2 (SW), col8 (spine), col14=gate (SE — needs key)
	"#......#.#......#",  # 10 SW room (office)  | spine | SE room (storage, gated)
	"#......#.#......#",  # 11
	"#..K...#.#...3..#",  # 12 key               |       | fuse3
	"#......#.#......#",  # 13
	"#......#P#......#",  # 14 player spawn, south end of spine
	"########X########",  # 15 front door (exit) in the south wall — col 8, aligned with the spine
]

# ── Parsed state ──────────────────────────────────────────────────
var cols: int = 0
var rows: int = 0
var grid: Array[PackedStringArray] = []      # [row] of chars
var walkable: Dictionary = {}                 # Vector2i(cell) -> true if walkable

# Spawn points (cell coords), converted to world by cell_to_world()
var spawn_player: Vector2i
var spawn_monster: Vector2i
var spawn_fuses: Array[Vector2i] = []
var spawn_breaker: Vector2i
var spawn_exit: Vector2i
var spawn_key: Vector2i
var gate_cell: Vector2i = Vector2i(-1, -1)
var gate_node: Node3D = null                  # set when the gate mesh is built

# Reusable materials (used to tint/tone the Kenney tiles for a darker mood)
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_ceil: StandardMaterial3D

# Real Kenney tile scenes (low-poly stylized look)
const SCN_FLOOR := "res://assets/kenney/dungeon/template-floor.glb"
const SCN_WALL := "res://assets/kenney/dungeon/template-wall.glb"
const SCN_WALL_CORNER := "res://assets/kenney/dungeon/template-wall-corner.glb"
const _floor_scene: PackedScene = preload(SCN_FLOOR)
const _wall_scene: PackedScene = preload(SCN_WALL)

# ── Lore (story notes) ─────────────────────────────────────────────
const NOTE_WELCOME := "If you're reading this, the power's already out.\n\nThree fuses run the breaker. Find them. Slot them. The front door only opens when the lights come back on.\n\nKeep your flashlight off when you can. And for the love of God — don't run."
const NOTE_THURSDAY := "It started in the walls. A wet sound, like breathing through a crack. Margaret said it was pipes. Margaret doesn't say much anymore.\n\nI keep the fuse in here. If I hold my breath and stay low, the dark doesn't notice me."
const NOTE_KEY := "Installed the gate on the storage room per the client's request. Key left on the desk. Client said he didn't want 'it' getting into the rest of the house. Wouldn't say what 'it' was.\n\n(The key is here. The storage room holds the last fuse.)"
const NOTE_WARNING := "DO NOT RUN.\n\nIt is blind. It hunts by sound and by the light you carry.\n\nWalk. Crouch. Keep the flashlight off unless you absolutely must see. If you hear it breathe, stop moving. Wait. It will pass.\n\nI did not wait. I am writing this in the dark because my hands still remember how."


func _ready() -> void:
	add_to_group("level")
	_build_materials()
	_parse_plan()
	_validate_connectivity()   # assert every objective is reachable from spawn
	_build_geometry()
	_build_props()
	# Defer interactable placement until the whole scene tree is ready (the
	# player/monster/interactables are siblings that finish _ready after us).
	_register_interactables.call_deferred()


# ── Parsing ───────────────────────────────────────────────────────
func _parse_plan() -> void:
	rows = PLAN.size()
	cols = PLAN[0].length()
	for r in range(rows):
		var row_chars := PackedStringArray()
		for c in range(cols):
			var ch: String = PLAN[r][c]
			row_chars.append(ch)
			match ch:
				"#": pass
				"G":
					gate_cell = Vector2i(c, r)
					# Starts CLOSED (not walkable) until the key opens it.
				"P": spawn_player = Vector2i(c, r); walkable[Vector2i(c, r)] = true
				"M": spawn_monster = Vector2i(c, r); walkable[Vector2i(c, r)] = true
				"B": spawn_breaker = Vector2i(c, r); walkable[Vector2i(c, r)] = true
				"X": spawn_exit = Vector2i(c, r); walkable[Vector2i(c, r)] = true
				"K": spawn_key = Vector2i(c, r); walkable[Vector2i(c, r)] = true
				"1","2","3": spawn_fuses.append(Vector2i(c, r)); walkable[Vector2i(c, r)] = true
				_: walkable[Vector2i(c, r)] = true   # '.', 'D'
		grid.append(row_chars)


func cell_to_world(cell: Vector2i) -> Vector3:
	# Centre the grid on the origin.
	return Vector3((cell.x - cols / 2.0) * CELL, 0.0, (cell.y - rows / 2.0) * CELL)


# ── Connectivity validation ───────────────────────────────────────
# BFS from the player spawn across walkable cells. Asserts that every
# objective (fuses, breaker, exit, and the key) sits in a reachable cell.
# Catches disconnected floorplans before they ship — the exact bug that
# trapped the player in the entrance hall.
func _validate_connectivity() -> void:
	# Treat the gate as OPEN for this check — it's an intended puzzle obstacle,
	# not an accidental wall. We're catching real disconnection bugs.
	var reach := walkable.duplicate()
	if gate_cell.x >= 0:
		reach[gate_cell] = true
	var reachable := _flood_fill(spawn_player, reach)
	var objectives: Array = [
		[spawn_breaker, "breaker"],
		[spawn_exit, "exit"],
		[spawn_key, "key"],
	]
	for i in spawn_fuses.size():
		objectives.append([spawn_fuses[i], "fuse%d" % (i + 1)])
	var ok := true
	for obj in objectives:
		var cell: Vector2i = obj[0]
		var label: String = obj[1]
		if not reachable.has(cell):
			push_error("[Level] %s at %s is UNREACHABLE from player spawn — fix the floorplan." % [label, str(cell)])
			ok = false
	if not ok:
		printerr("[Level] FLOORPLAN CONNECTIVITY FAILED — see errors above.")
	else:
		print("[Level] connectivity OK: %d cells reachable, all objectives connected." % reachable.size())


func _flood_fill(start: Vector2i, reach_set: Dictionary = walkable) -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while queue.size() > 0:
		var cell: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = cell + d
			if reach_set.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


@warning_ignore("integer_division")
func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(int(round(pos.x / CELL)) + cols / 2, int(round(pos.z / CELL)) + rows / 2)


func is_walkable(cell: Vector2i) -> bool:
	# A cell is walkable for the monster if it's floor/doorway (not wall, and
	# the gate is treated as open once solved — handled by callers).
	return walkable.has(cell)


# ── Materials ─────────────────────────────────────────────────────
func _build_materials() -> void:
	_mat_floor = StandardMaterial3D.new()
	var ftex := load("res://assets/horror/textures/surfaces/dirt_floor.png")
	if ftex:
		_mat_floor.albedo_texture = ftex
		_mat_floor.uv1_scale = Vector3(2, 2, 2)
	_mat_floor.albedo_color = Color(0.10, 0.09, 0.08)
	_mat_floor.roughness = 0.95
	_mat_floor.metallic = 0.0

	_mat_wall = StandardMaterial3D.new()
	_mat_wall.albedo_color = Color(0.07, 0.07, 0.075)
	_mat_wall.roughness = 1.0
	var grime := load("res://assets/horror/textures/surfaces/grime_overlay.png")
	if grime:
		_mat_wall.albedo_texture = grime
		_mat_wall.uv1_scale = Vector3(2, 1.5, 2)

	_mat_ceil = StandardMaterial3D.new()
	_mat_ceil.albedo_color = Color(0.02, 0.02, 0.02)
	_mat_ceil.roughness = 1.0


# ── Geometry ──────────────────────────────────────────────────────
func _build_geometry() -> void:
	var static_body := StaticBody3D.new()
	static_body.name = "Collision"
	add_child(static_body)

	var tiles := Node3D.new()
	tiles.name = "Tiles"
	add_child(tiles)

	for r in range(rows):
		for c in range(cols):
			var ch: String = grid[r][c]
			var cell := Vector2i(c, r)
			var w := cell_to_world(cell)
			if ch == "#":
				_instance_tile(tiles, _wall_scene, w, _mat_wall)
				_add_box_collider(static_body, Vector3(CELL, WALL_H, CELL), Vector3(w.x, WALL_H / 2.0, w.z))
			else:
				_instance_tile(tiles, _floor_scene, w, _mat_floor)
				_add_box_collider(static_body, Vector3(CELL, 0.2, CELL), Vector3(w.x, -0.1, w.z))
				_add_ceiling(w)
				if ch == "G":
					gate_node = _add_gate(w)


func _instance_tile(parent: Node, scn: PackedScene, pos: Vector3, mat: Material) -> void:
	if scn == null:
		return
	var inst := scn.instantiate()
	inst.position = pos
	# Apply a mood tint via material_override (keeps the low-poly geometry but
	# darkens/tones it for the horror palette).
	if mat:
		for mi in inst.find_children("*", "MeshInstance3D", true, true):
			(mi as MeshInstance3D).material_override = mat
	parent.add_child(inst)


func _add_box_collider(parent: Node, size: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	parent.add_child(col)


func _add_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide: bool, node_name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		_add_box_collider(parent, size, pos)


func _add_wall(parent: Node, w: Vector3) -> void:
	_add_box(parent, Vector3(CELL, WALL_H, CELL), Vector3(w.x, WALL_H / 2.0, w.z), _mat_wall, true, "Wall")


func _add_floor(w: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	var box := BoxMesh.new()
	box.size = Vector3(CELL, 0.2, CELL)
	mi.mesh = box
	mi.material_override = _mat_floor
	mi.position = Vector3(w.x, -0.1, w.z)
	add_child(mi)
	# Floor collision (so the player stands).
	_add_box_collider(get_node("Collision"), Vector3(CELL, 0.2, CELL), Vector3(w.x, -0.1, w.z))


func _add_ceiling(w: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Ceiling"
	var box := BoxMesh.new()
	box.size = Vector3(CELL, 0.2, CELL)
	mi.mesh = box
	mi.material_override = _mat_ceil
	mi.position = Vector3(w.x, CEIL_Y, w.z)
	add_child(mi)


func _add_gate(w: Vector3) -> Node3D:
	# A gate-door mesh that blocks the cell until opened. Starts solid.
	var gate := Node3D.new()
	gate.name = "Gate"
	gate.position = w
	gate.add_to_group("gate")
	var mi := MeshInstance3D.new()
	mi.name = "GateMesh"
	var box := BoxMesh.new()
	box.size = Vector3(CELL * 0.9, WALL_H * 0.95, 0.4)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.12, 0.08)
	mat.roughness = 0.6
	mat.metallic = 0.4
	mi.material_override = mat
	gate.add_child(mi)
	var col := CollisionShape3D.new()
	col.name = "GateCol"
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL * 0.9, WALL_H * 0.95, 0.4)
	col.shape = shape
	gate.add_child(col)
	add_child(gate)
	return gate


# ── Atmosphere props ──────────────────────────────────────────────
func _build_props() -> void:
	# Scatter furniture in rooms + a few flickering ceiling lights so the
	# player gets landmarks and the flashlight has things to reveal.
	var prop_parent := Node3D.new()
	prop_parent.name = "Props"
	add_child(prop_parent)

	# A light in each major room (sparse — the flashlight should matter).
	_place_room_light(prop_parent, spawn_breaker, Color(0.5, 0.45, 0.3))
	_place_room_light(prop_parent, spawn_fuses[1], Color(0.4, 0.4, 0.5))

	# Furniture: use Kenney house props for a "real house" read.
	_place_prop(prop_parent, "res://assets/kenney/furniture/loungeDesignSofa.glb", spawn_fuses[0], 0.0, Vector3(1.4, 0, 1.4))
	_place_prop(prop_parent, "res://assets/kenney/furniture/desk.glb", spawn_key, 1.5708, Vector3(0.8, 0, 0.8))
	_place_prop(prop_parent, "res://assets/kenney/furniture/books.glb", spawn_key, 0.0, Vector3(-0.8, 0.9, -0.8))
	_place_prop(prop_parent, "res://assets/kenney/furniture/sideTable.glb", spawn_fuses[2], 0.0, Vector3(1.0, 0, -1.0))
	_place_prop(prop_parent, "res://assets/kenney/furniture/pottedPlant.glb", spawn_player, 0.0, Vector3(1.2, 0, 1.2))
	_place_prop(prop_parent, "res://assets/horror/3d/props/bookcase.glb", spawn_breaker, 3.14159, Vector3(1.0, 0, 0))
	_place_prop(prop_parent, "res://assets/horror/3d/props/chair.glb", spawn_fuses[1], 0.785, Vector3(-1.0, 0, 1.0))

	_build_narrative(prop_parent)


func _place_prop(parent: Node, path: String, room_cell: Vector2i, rot_y: float, offset: Vector3) -> void:
	var scn := load(path) as PackedScene
	if scn == null:
		return
	var inst := scn.instantiate()
	var w := cell_to_world(room_cell)
	inst.position = Vector3(w.x + offset.x, offset.y, w.z + offset.z)
	inst.rotation.y = rot_y
	parent.add_child(inst)


# ── Narrative: notes + jumpscare triggers ─────────────────────────
# The story + scares are placed at meaningful room positions with tuned
# defaults. Each note's text tells a fragment of what happened here.
func _build_narrative(parent: Node) -> void:
	# NOTES — lore fragments, one per room the player will explore.
	_spawn_note(parent, spawn_player, "WELCOME TO THE DARK", NOTE_WELCOME)
	_spawn_note(parent, spawn_fuses[0], "THURSDAY", NOTE_THURSDAY)
	_spawn_note(parent, spawn_key, "THE LOCKSMITH'S RECEIPT", NOTE_KEY)
	_spawn_note(parent, spawn_monster, "DO NOT", NOTE_WARNING)

	# JUMPSCARE TRIGGERS — placed at doorway pinch-points where they read best.
	# Types: 0=FLICKER, 1=STING, 2=LUNGE, 3=WHISPER. Tunable in the editor.
	_spawn_scare(parent, Vector2i(2, 7), 0, 0.8)   # NW doorway → lights flicker
	_spawn_scare(parent, Vector2i(8, 9), 3, 0.5)   # spine near SE → whisper
	_spawn_scare(parent, Vector2i(14, 9), 1, 1.0)  # gate area → sting (tense)
	_spawn_scare(parent, Vector2i(8, 4), 2, 0.7)   # spine upper → monster lunge

	# SCARE NODES — empty markers the monster lunges FROM during a LUNGE scare.
	_spawn_scare_node(parent, Vector2i(7, 4))
	_spawn_scare_node(parent, Vector2i(9, 4))


func _spawn_note(parent: Node, cell: Vector2i, title: String, text: String) -> void:
	var note := Area3D.new()
	note.name = "Note_" + title.left(8)
	note.set_script(load("res://prototypes/horror-house/note.gd"))
	note.note_title = title
	note.note_text = text
	var w := cell_to_world(cell)
	note.position = Vector3(w.x + 0.8, 1.0, w.z + 0.8)
	# A small paper-ish mesh so it's findable.
	var mi := MeshInstance3D.new()
	mi.name = "Paper"
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.5, 0.6)
	mi.mesh = plane
	mi.rotation = Vector3(0, 0.3, 0)
	mi.position = Vector3(0, -0.7, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.86, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.25, 0.12)
	mat.emission_energy_multiplier = 0.4  # glows faintly so it's spottable in the dark
	mi.material_override = mat
	note.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.5, 1.0)
	col.shape = shape
	note.add_child(col)
	parent.add_child(note)


func _spawn_scare(parent: Node, cell: Vector2i, kind: int, weight: float) -> void:
	var scare := Area3D.new()
	scare.name = "Scare_%d_%d" % [cell.x, cell.y]
	scare.set_script(load("res://prototypes/horror-house/jumpscare.gd"))
	scare.scare_type = kind
	scare.intensity = weight
	var w := cell_to_world(cell)
	scare.position = Vector3(w.x, 1.0, w.z)
	# Trigger volume: a 1-cell box the player walks through.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL * 0.9, 2.5, CELL * 0.9)
	col.shape = shape
	scare.add_child(col)
	parent.add_child(scare)


func _spawn_scare_node(parent: Node, cell: Vector2i) -> void:
	var marker := Node3D.new()
	marker.name = "ScareNode_%d_%d" % [cell.x, cell.y]
	marker.add_to_group("scare_node")
	var w := cell_to_world(cell)
	marker.position = Vector3(w.x, 0.0, w.z)
	parent.add_child(marker)


func _place_room_light(parent: Node, cell: Vector2i, tint: Color) -> void:
	var w := cell_to_world(cell)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 0.35
	light.omni_range = CELL * 3.5
	light.omni_attenuation = 1.4
	light.position = Vector3(w.x, WALL_H - 0.4, w.z)
	light.add_to_group("room_light")
	light.script = load("res://prototypes/horror-house/flicker_light.gd")
	parent.add_child(light)


# ── Interactables ─────────────────────────────────────────────────
func _register_interactables() -> void:
	# The interactable nodes (Breaker, Fuses, ExitDoor, Monster, Player) live
	# in the scene already — reposition them to their generated cells.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = cell_to_world(spawn_player) + Vector3(0, 1.0, 0)

	var monster := get_tree().get_first_node_in_group("monster") as Node3D
	if monster:
		monster.global_position = cell_to_world(spawn_monster)

	var breaker := _find("Breaker")
	if breaker:
		breaker.global_position = cell_to_world(spawn_breaker) + Vector3(0, 1.2, 0)

	var door := _find("ExitDoor")
	if door:
		door.global_position = cell_to_world(spawn_exit)

	# Fuses are named Fuse1..3 in the scene; map them to spawn_fuses[0..2].
	for i in spawn_fuses.size():
		var f := _find("Fuse%d" % (i + 1))
		if f:
			f.global_position = cell_to_world(spawn_fuses[i]) + Vector3(0, 1.0, 0)

	# Key pickup (created fresh — not in the original scene).
	_spawn_key_pickup()


func _find(node_name: String) -> Node3D:
	var n := get_tree().get_nodes_in_group("interactable").filter(func(x): return x.name == node_name)
	return n[0] if n.size() > 0 else null


func _spawn_key_pickup() -> void:
	var key := Area3D.new()
	key.name = "Key"
	key.add_to_group("interactable")
	key.add_to_group("key_pickup")
	key.set_script(load("res://prototypes/horror-house/key_pickup.gd"))
	# A simple key mesh.
	var mi := MeshInstance3D.new()
	mi.name = "KeyMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 0.3
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.8, 0.2)
	mat.metallic = 0.8
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.4, 0.1)
	mat.emission_energy_multiplier = 0.6
	mi.material_override = mat
	key.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.6, 0.6)
	col.shape = shape
	key.add_child(col)
	get_parent().add_child(key)
	# Set global_position AFTER the node is in the tree.
	key.global_position = cell_to_world(spawn_key) + Vector3(0, 1.0, 0)


# ── Gate control (called by game.gd when key puzzle solved) ────────
func open_gate() -> void:
	if gate_node == null:
		return
	if gate_node.has_node("GateCol"):
		gate_node.get_node("GateCol").queue_free()
	# Swing/lift the gate mesh up out of the way.
	var tw := create_tween()
	tw.tween_property(gate_node, "position:y", WALL_H + 1.0, 0.8).set_trans(Tween.TRANS_QUAD)
	# Mark the gate cell fully open for monster pathfinding.
	walkable[gate_cell] = true
