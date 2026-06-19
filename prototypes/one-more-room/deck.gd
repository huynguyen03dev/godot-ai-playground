extends Node

# Deck builder for One More Room
# Builds the depth deck from DESIGN.md §6 tables

var rng: RandomNumberGenerator

func _ready():
	rng = RandomNumberGenerator.new()

func build_deck() -> Array:
	var cards = []
	# 18 treasure cards (value computed on draw)
	for i in range(18):
		cards.append({"kind": "treasure", "value": 0, "hazard_type": "", "special_id": ""})
	# 5 hazard types x 3 each = 15
	var hazard_types = ["gas", "cavein", "spiders", "flood", "curse"]
	for h in hazard_types:
		for i in range(3):
			cards.append({"kind": "hazard", "value": 0, "hazard_type": h, "special_id": ""})
	# 2 specials
	cards.append({"kind": "special", "value": 0, "hazard_type": "", "special_id": "shrine"})
	cards.append({"kind": "special", "value": 0, "hazard_type": "", "special_id": "reward"})
	return cards

func shuffle_deck(deck: Array) -> Array:
	var d = deck.duplicate()
	var n = d.size()
	while n > 0:
		n -= 1
		var k = rng.randi_range(0, n)
		var temp = d[n]
		d[n] = d[k]
		d[k] = temp
	return d

func compute_gold_value(depth: int, jitter: float) -> int:
	var base = 10.0
	var value = base * (1.0 + 0.18 * depth)
	return int(round(value * jitter))
