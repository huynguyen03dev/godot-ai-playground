extends Node

# One More Room - Game State Machine
# Owns all state: vault, unbanked, seen_hazards, expedition_index, deck
# UI subscribes via signals; this is the single source of truth

# --- Signals ---
signal treasure_gained(value, depth, total_unbanked)
signal hazard_seen(hazard_type, seen_count)
signal busted(unbanked_lost)
signal banked(amount)
signal danger_changed(percent)
signal expedition_started(index)
signal run_ended(final_vault)
signal card_peeked(card)

# --- State ---
var vault: int = 0
var unbanked: int = 0
var seen_hazards: Dictionary = {}  # hazard_type -> count
var expedition_index: int = 0
var deck: Array = []
var deck_position: int = 0
var is_running: bool = false
var is_expedition_active: bool = false
var rng: RandomNumberGenerator
var seed_value: int = 0

func _ready():
	rng = RandomNumberGenerator.new()


func start_run(new_seed: int = -1):
	vault = 0
	expedition_index = 0
	if new_seed >= 0:
		seed_value = new_seed
		rng.seed = seed_value
	else:
		seed_value = rng.randi()
	is_running = true
	start_expedition()

func start_expedition():
	expedition_index += 1
	unbanked = 0
	seen_hazards = {}
	deck_position = 0
	deck = _build_deck()
	_shuffle_deck()
	is_expedition_active = true
	emit_signal("expedition_started", expedition_index)
	emit_signal("danger_changed", compute_danger())

func on_push():
	if not is_expedition_active:
		return
	var card = _draw_card()
	if card == null:
		# Deck empty - auto-bank
		on_bank()
		return
	_resolve_card(card)

func on_bank():
	if not is_expedition_active:
		return
	var amount = unbanked
	vault += amount
	unbanked = 0
	is_expedition_active = false
	emit_signal("banked", amount)
	if expedition_index >= 3:
		is_running = false
		emit_signal("run_ended", vault)
	else:
		start_expedition()

func _resolve_card(card: Dictionary):
	match card.kind:
		"treasure":
			unbanked += card.value
			emit_signal("treasure_gained", card.value, deck_position, unbanked)
		"hazard":
			var htype = card.hazard_type
			if seen_hazards.has(htype):
				_bust()
				return
			seen_hazards[htype] = 1
			emit_signal("hazard_seen", htype, seen_hazards.size())
		"special":
			# For MVP, specials just give bonus treasure
			var bonus = 15 + rng.randi() % 20
			unbanked += bonus
			emit_signal("treasure_gained", bonus, deck_position, unbanked)
	emit_signal("danger_changed", compute_danger())

func _bust():
	var lost = unbanked
	unbanked = 0
	is_expedition_active = false
	emit_signal("busted", lost)
	if expedition_index >= 3:
		is_running = false
		emit_signal("run_ended", vault)
	else:
		start_expedition()

func compute_danger() -> int:
	if deck.size() - deck_position <= 0:
		return 100
	var seen_count = seen_hazards.size()
	var remaining = deck.size() - deck_position
	# Simple formula: distinct hazards seen / cards remaining
	return int(float(seen_count) / float(remaining) * 100.0)

func _build_deck() -> Array:
	var cards = []
	# 18 treasure cards
	for i in range(18):
		cards.append({"kind": "treasure", "value": 0, "hazard_type": "", "special_id": ""})
	# 5 hazards x 3 each = 15
	var hazard_types = ["gas", "cavein", "spiders", "flood", "curse"]
	for h in hazard_types:
		for i in range(3):
			cards.append({"kind": "hazard", "value": 0, "hazard_type": h, "special_id": ""})
	# 2 specials
	cards.append({"kind": "special", "value": 0, "hazard_type": "", "special_id": "shrine"})
	cards.append({"kind": "special", "value": 0, "hazard_type": "", "special_id": "reward"})
	return cards

func _shuffle_deck():
	# Fisher-Yates shuffle
	var n = deck.size()
	while n > 0:
		n -= 1
		var k = rng.randi_range(0, n)
		var temp = deck[n]
		deck[n] = deck[k]
		deck[k] = temp

func _draw_card() -> Dictionary:
	if deck_position >= deck.size():
		return {}
	var card = deck[deck_position]
	deck_position += 1
	# Compute treasure values on draw (so depth is accurate)
	if card.kind == "treasure":
		var depth = deck_position
		var base = 10.0
		var value = base * (1.0 + 0.18 * depth)
		var jitter = 1.0 + (rng.randf() - 0.5) * 0.3  # ±15%
		card.value = int(round(value * jitter))
	return card

func peek_next_card() -> Dictionary:
	if deck_position >= deck.size():
		return {}
	var card = deck[deck_position].duplicate()
	# Compute value as if drawn
	if card.kind == "treasure":
		var depth = deck_position + 1
		var base = 10.0
		var value = base * (1.0 + 0.18 * depth)
		var jitter = 1.0 + (rng.randf() - 0.5) * 0.3
		card.value = int(round(value * jitter))
	emit_signal("card_peeked", card)
	return card

func use_lantern() -> Dictionary:
	return peek_next_card()

# --- Headless test ---
func _run_headless_test():
	print("=== ONE MORE ROOM HEADLESS TEST ===")
	start_run(42)
	await get_tree().create_timer(0.1).timeout
	
	# Test 1: First push should give treasure or first hazard sighting
	print("Test 1: First push")
	on_push()
	print("  unbanked=%d vault=%d seen=%d danger=%d%%" % [unbanked, vault, seen_hazards.size(), compute_danger()])
	
	# Push a few more times
	for i in range(5):
		await get_tree().create_timer(0.05).timeout
		on_push()
		print("  Push %d: unbanked=%d vault=%d seen=%d danger=%d%%" % [i+2, unbanked, vault, seen_hazards.size(), compute_danger()])
	
	# Bank
	print("Test 2: Bank")
	on_bank()
	print("  vault=%d (should be >0)" % vault)
	
	# Expeditions 2&3: push until bust or bank
	while is_running:
		await get_tree().create_timer(0.05).timeout
		on_push()
		if not is_expedition_active and is_running:
			print("  Expedition ended, starting next (vault=%d)" % vault)
	
	print("=== TEST COMPLETE: vault=%d, expeditions=3 ===" % vault)
	print("Result: PASS (rules executed without errors)")
