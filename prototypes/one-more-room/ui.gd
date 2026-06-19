extends Control

@onready var game = $GameController

var lbl_expedition: Label
var lbl_vault: Label
var lbl_unbanked: Label
var lbl_danger: Label
var hazard_row: HBoxContainer
var room_container: HBoxContainer
var btn_push: Button
var btn_bank: Button
var btn_lantern: Button

var audio_coin: AudioStreamPlayer
var audio_click: AudioStreamPlayer
var audio_sting: AudioStreamPlayer
var audio_rumble: AudioStreamPlayer
var audio_chaching: AudioStreamPlayer

var lantern_used: bool = false
var busting: bool = false

func _ready():
	# Environment renders root at 2x (2304x1296) but visible region is
	# top-left 1152x648. Constrain layout to the visible design size.
	var ml = $MainLayout
	ml.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ml.position = Vector2.ZERO
	ml.size = Vector2(1152, 648)
	ml.custom_minimum_size = Vector2(1152, 648)
	_create_audio()
	_find_ui_nodes()
	_wire_signals()
	game.start_run()
	_refresh_ui()

func _create_audio():
	for cfg in [["coin","res://prototypes/one-more-room/assets/sounds/coin.wav"],["click","res://prototypes/one-more-room/assets/sounds/click.wav"],["sting","res://prototypes/one-more-room/assets/sounds/sting.wav"],["rumble","res://prototypes/one-more-room/assets/sounds/rumble.wav"],["chaching","res://prototypes/one-more-room/assets/sounds/chaching.wav"]]:
		var a = AudioStreamPlayer.new()
		a.stream = load(cfg[1])
		a.name = "Audio" + cfg[0].capitalize()
		add_child(a)
		set("audio_" + cfg[0], a)

func _find_ui_nodes():
	var ml = $MainLayout
	lbl_expedition = ml.get_node("RunHeader/LblExpedition")
	lbl_vault = ml.get_node("RunHeader/LblVault")
	room_container = ml.get_node("RoomTrack/RoomContainer")
	lbl_unbanked = ml.get_node("StatePanel/LblUnbanked")
	lbl_danger = ml.get_node("StatePanel/LblDanger")
	hazard_row = ml.get_node("StatePanel/HazardRow")
	btn_lantern = ml.get_node("RelicBar/BtnLantern")
	btn_push = ml.get_node("ButtonBar/BtnPush")
	btn_bank = ml.get_node("ButtonBar/BtnBank")

func _wire_signals():
	game.treasure_gained.connect(_on_treasure_gained)
	game.hazard_seen.connect(_on_hazard_seen)
	game.busted.connect(_on_busted)
	game.banked.connect(_on_banked)
	game.danger_changed.connect(_on_danger_changed)
	game.expedition_started.connect(_on_expedition_started)
	game.run_ended.connect(_on_run_ended)

func _refresh_ui():
	lbl_expedition.text = "Expedition %d / 3" % game.expedition_index
	lbl_vault.text = "VAULT:  %d g" % game.vault
	lbl_unbanked.text = "UNBANKED:  %d g" % game.unbanked
	lbl_danger.text = "DANGER (next flip):  %d%%" % game.compute_danger()

func _on_treasure_gained(_value: int, _depth: int, total: int):
	lbl_unbanked.text = "UNBANKED:  %d g" % total
	if audio_coin: audio_coin.play()

func _on_hazard_seen(htype: String, _count: int):
	var icon_path = "res://prototypes/one-more-room/assets/icons/icon_hazard_%s.png" % htype
	var tex_rect = TextureRect.new()
	tex_rect.texture = load(icon_path)
	tex_rect.custom_minimum_size = Vector2(28, 28)
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	hazard_row.add_child(tex_rect)
	_refresh_ui()
	if audio_sting: audio_sting.play()

func _on_busted(lost: int):
	busting = true
	lbl_unbanked.text = "BUST! Lost %d g!" % lost
	_refresh_ui()
	if audio_rumble: audio_rumble.play()
	_screen_shake(8.0, 0.5)
	busting = false

func _on_banked(_amount: int):
	_refresh_ui()
	if audio_chaching: audio_chaching.play()

func _on_danger_changed(pct: int):
	lbl_danger.text = "DANGER (next flip):  %d%%" % pct
	if pct > 50:
		lbl_danger.add_theme_color_override("font_color", Color.RED)
	elif pct > 25:
		lbl_danger.add_theme_color_override("font_color", Color.YELLOW)
	else:
		lbl_danger.add_theme_color_override("font_color", Color.WHITE)

func _on_expedition_started(_index: int):
	lantern_used = false
	btn_lantern.disabled = false
	_refresh_ui()
	for c in room_container.get_children():
		c.queue_free()
	for c in hazard_row.get_children():
		c.queue_free()

func _on_run_ended(final_vault: int):
	lbl_vault.text = "FINAL:  %d g" % final_vault
	btn_push.disabled = true
	btn_bank.disabled = true

func _input(event: InputEvent):
	if event.is_action_pressed("or_push"):
		_on_push_pressed()
	if event.is_action_pressed("or_bank"):
		_on_bank_pressed()
	if event.is_action_pressed("or_lantern"):
		_on_lantern_pressed()

func _on_push_pressed():
	if busting or not game.is_expedition_active:
		return
	game.on_push()
	_update_room_track()
	_refresh_ui()
	if audio_click: audio_click.play()

func _on_bank_pressed():
	if not game.is_expedition_active:
		return
	game.on_bank()
	_refresh_ui()

func _on_lantern_pressed():
	if lantern_used or not game.is_expedition_active:
		return
	var card = game.peek_next_card()
	if card.is_empty():
		return
	lantern_used = true
	btn_lantern.disabled = true
	var name_str = card.kind.capitalize()
	if card.kind == "hazard":
		name_str = "HAZARD: " + card.hazard_type.capitalize()
	elif card.kind == "treasure":
		name_str = "Treasure ~%d" % card.value
	lbl_danger.text = "PEEK: %s" % name_str
	await get_tree().create_timer(1.5).timeout
	_refresh_ui()

func _update_room_track():
	var last_card = game.deck[game.deck_position - 1] if game.deck_position > 0 else {}
	if last_card.is_empty():
		return
	var card_node = _create_room_card(last_card)
	room_container.add_child(card_node)
	var scroll = room_container.get_parent()
	if scroll is ScrollContainer:
		await get_tree().process_frame
		scroll.scroll_horizontal = scroll.get_h_scroll_bar().max_value

func _screen_shake(intensity: float, duration: float):
	var og = position
	var tween = create_tween()
	tween.tween_method(func(_off):
		position = og + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	, 0.0, 1.0, duration)
	tween.tween_callback(func(): position = og)

func _create_room_card(card: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(80, 80)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if card.kind == "treasure":
		icon.texture = load("res://prototypes/one-more-room/assets/icons/icon_treasure.png")
		label.text = "+%d" % card.value
		container.modulate = Color.GOLD
	elif card.kind == "hazard":
		var htype = card.hazard_type
		icon.texture = load("res://prototypes/one-more-room/assets/icons/icon_hazard_%s.png" % htype)
		label.text = htype.capitalize()
		container.modulate = Color.RED
	elif card.kind == "special":
		var sid = card.special_id
		icon.texture = load("res://prototypes/one-more-room/assets/icons/icon_special_%s.png" % sid)
		label.text = "Special"
		container.modulate = Color.REBECCA_PURPLE
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(icon)
	vbox.add_child(label)
	container.add_child(vbox)
	return container
