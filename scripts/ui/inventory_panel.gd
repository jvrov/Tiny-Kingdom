class_name InventoryPanel
extends Control
## Commands use GameState transactions; the panel owns no persistent data.

var player: KingdomPlayer
var selected := -1
var slot_buttons: Array[Button] = []
var equipment_buttons: Dictionary = {}
var stats_label: Label
var detail_label: Label
var message_label: Label
var count_label: Label
var equip_button: Button
var use_button: Button
var discard_button: Button
var discard_dialog: ConfirmationDialog
var discard_quote: Dictionary = {}
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	hide()
	set_process_input(false)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.05, 0.04, 0.88)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 610)
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152c2b")
	style.border_color = Color("bcb584")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label(header, "INVENTÁRIO", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Fechar · I / Esc", close)
	count_label = _label(content, "", 16)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	content.add_child(columns)
	var grid := GridContainer.new()
	grid.columns = 4
	columns.add_child(grid)
	for index in range(InventoryData.CAPACITY):
		var button := _button(grid, "", select.bind(index))
		button.custom_minimum_size = Vector2(126, 76)
		button.add_theme_font_size_override("font_size", 14)
		slot_buttons.append(button)
	var equipped := VBoxContainer.new()
	equipped.custom_minimum_size.x = 260
	equipped.add_theme_constant_override("separation", 10)
	columns.add_child(equipped)
	_label(equipped, "EQUIPAMENTOS", 20)
	for slot in ItemData.SLOTS:
		var button := _button(equipped, "", unequip.bind(slot))
		button.custom_minimum_size = Vector2(260, 62)
		button.add_theme_font_size_override("font_size", 15)
		equipment_buttons[slot] = button
	stats_label = _label(equipped, "", 16)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 238
	details.add_theme_constant_override("separation", 10)
	columns.add_child(details)
	detail_label = _label(details, "", 18)
	detail_label.custom_minimum_size = Vector2(238, 180)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equip_button = _button(details, "Equipar", perform.bind("equip"))
	use_button = _button(details, "Usar poção", perform.bind("use"))
	discard_button = _button(details, "Descartar", confirm_discard)
	message_label = _label(content, "", 16)
	message_label.custom_minimum_size.y = 26
	message_label.add_theme_color_override("font_color", Color("f0bc80"))
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Descartar item"
	discard_dialog.ok_button_text = "Descartar"
	discard_dialog.cancel_button_text = "Cancelar"
	discard_dialog.confirmed.connect(_discard_confirmed)
	add_child(discard_dialog)
	game_state.changed.connect(refresh)


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func bind_player(actor: KingdomPlayer) -> void:
	player = actor
	player.stats_changed.connect(refresh)


func open() -> void:
	if not is_instance_valid(player) or not player.is_alive(): return
	selected = -1
	message_label.text = ""
	show()
	get_tree().paused = true
	set_process_input(true)
	refresh()
	slot_buttons[0].grab_focus()


func close() -> void:
	discard_dialog.hide()
	hide()
	set_process_input(false)
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		if discard_dialog.visible:
			discard_dialog.hide()
		else:
			close()
		get_viewport().set_input_as_handled()


func select(index: int) -> void:
	selected = index
	message_label.text = ""
	refresh()


func refresh() -> void:
	if not visible or not is_instance_valid(player): return
	var used := 0
	for index in range(InventoryData.CAPACITY):
		var entry: Dictionary = game_state.inventory[index]
		var button := slot_buttons[index]
		if entry.is_empty():
			button.text = "%02d\n—" % (index + 1)
			button.tooltip_text = "Espaço vazio"
			button.add_theme_color_override("font_color", Color("78938a"))
		else:
			used += 1
			var item := ItemData.definition(entry.id)
			button.text = "%s · %s\n%s\nx%d" % [item.icon, ItemData.RARITY_NAMES[item.rarity], item.name.left(16), entry.quantity]
			button.tooltip_text = item.name + "\n" + item.description
			button.add_theme_color_override("font_color", ItemData.COLORS[item.rarity])
	count_label.text = "%d / 20 espaços · Itens coletados são mantidos após a morte" % used
	for slot in ItemData.SLOTS:
		var item := ItemData.definition(game_state.equipment[slot])
		var button: Button = equipment_buttons[slot]
		button.text = ItemData.SLOT_NAMES[slot] + "\n" + ("Vazio" if item.is_empty() else item.name + " · retirar")
		button.disabled = item.is_empty()
	var values: Dictionary = game_state.attribute_breakdown()
	stats_label.text = "Dano: %d   Vida: %d / %d\nVelocidade: %d\n\nDano: base %d + nível %d\n+ Ferreiro %d + item %d\nHP: base %d + nível %d\n+ item %d\nVel.: base %d + item %d" % [
		player.damage, player.current_health, player.max_health, player.speed,
		values.base.damage, values.level.damage, values.blacksmith, values.equipment.damage,
		values.base.max_health, values.level.max_health, values.equipment.max_health,
		values.base.speed, values.equipment.speed]
	var item: Dictionary = {}
	if selected >= 0 and not game_state.inventory[selected].is_empty():
		item = ItemData.definition(game_state.inventory[selected].id)
	detail_label.text = "Selecione um item.\n\nClique em um equipamento atual para desequipar." if item.is_empty() else item.name + "\n" + ItemData.RARITY_NAMES[item.rarity] + "\n\n" + item.description
	detail_label.add_theme_color_override("font_color", Color("dce6d6") if item.is_empty() else ItemData.COLORS[item.rarity])
	equip_button.disabled = item.is_empty() or not ItemData.SLOTS.has(item.get("type"))
	use_button.disabled = item.is_empty() or item.get("type") != "consumable" or player.current_health >= player.max_health
	discard_button.disabled = item.is_empty()


func perform(action: String) -> void:
	if game_state.inventory_action(player, action, selected):
		message_label.text = "Item usado." if action == "use" else "Equipamento atualizado."
	else:
		message_label.text = game_state.action_message
	refresh()


func unequip(slot: String) -> void:
	if game_state.inventory_action(player, "unequip", -1, slot):
		message_label.text = "Item devolvido ao inventário."
	else:
		message_label.text = game_state.action_message
	refresh()


func confirm_discard() -> void:
	if selected < 0 or game_state.inventory[selected].is_empty(): return
	discard_quote = {"index": selected, "entry": game_state.inventory[selected].duplicate()}
	discard_dialog.dialog_text = "Descartar %s (x%d)?\nEssa ação remove a pilha inteira." % [
		ItemData.definition(discard_quote.entry.id).name, discard_quote.entry.quantity]
	discard_dialog.popup_centered(Vector2i(520, 180))


func _discard_confirmed() -> void:
	if discard_quote.is_empty() or game_state.inventory[discard_quote.index] != discard_quote.entry:
		message_label.text = "O item mudou. Selecione-o novamente."
	elif game_state.inventory_action(player, "discard", discard_quote.index):
		message_label.text = "Item descartado."
	else:
		message_label.text = game_state.action_message
	discard_quote = {}
	refresh()
