extends Node
## Autoload: permanent progress is persisted; expedition cargo stays in memory.
## Initialization is explicit so tests can select an isolated file before any I/O.

signal changed
signal save_status_changed(message: String)

var village_resources: Dictionary = {"wood": 0, "stone": 0, "gold": 0}
var expedition_resources: Dictionary = {"wood": 0, "stone": 0, "gold": 0}
var progression: Dictionary = {"level": 1, "xp": 0, "max_health": 100, "damage": 18}
var expeditions_completed := 0
var expedition_active := false
var initialized := false
var save_status := ""
var storage: SaveSystem


func initialize(save_path: String = SaveSystem.DEFAULT_PATH) -> void:
	if initialized:
		return
	storage = SaveSystem.new(save_path)
	var data := storage.load_data()
	village_resources = data.resources.duplicate()
	progression = data.player.duplicate()
	expeditions_completed = data.expeditions_completed
	initialized = true
	var load_message := storage.message
	if storage.needs_save:
		persist()
	if not load_message.is_empty():
		_set_status(load_message if save_status.is_empty() else load_message + " " + save_status)
	changed.emit()


func snapshot() -> Dictionary:
	return {
		"version": SaveSystem.VERSION,
		"resources": village_resources.duplicate(),
		"player": progression.duplicate(),
		"expeditions_completed": expeditions_completed
	}


func persist() -> bool:
	var success := storage.save_data(snapshot())
	_set_status("" if success else storage.message)
	return success


func _set_status(value: String) -> void:
	save_status = value
	save_status_changed.emit(value)


func sync_player(player: KingdomPlayer) -> void:
	expedition_resources = player.resources.duplicate()
	var progress := {
		"level": player.level, "xp": player.experience,
		"max_health": player.max_health, "damage": player.damage
	}
	if progression != progress:
		progression = progress
		# XP is permanent even if the player dies or quits before depositing.
		persist()
	changed.emit()


func has_cargo() -> bool:
	return expedition_resources.values().any(func(amount): return amount > 0)


func begin_expedition() -> bool:
	if expedition_active or has_cargo():
		return false
	expedition_resources = {"wood": 0, "stone": 0, "gold": 0}
	expedition_active = true
	changed.emit()
	return true


func finish_expedition(survived: bool) -> bool:
	if not expedition_active:
		return false
	expedition_active = false
	if survived:
		expeditions_completed += 1
	else:
		expedition_resources = {"wood": 0, "stone": 0, "gold": 0}
	persist()
	changed.emit()
	return true


func deposit() -> bool:
	if expedition_active or not has_cargo():
		return false
	var previous := village_resources.duplicate()
	for key in village_resources:
		village_resources[key] += expedition_resources[key]
	# Commit first, then clear cargo. Disk errors must never eat carried loot.
	if not persist():
		village_resources = previous
		changed.emit()
		return false
	expedition_resources = {"wood": 0, "stone": 0, "gold": 0}
	changed.emit()
	return true


func reset_progress() -> bool:
	if not storage.erase():
		_set_status(storage.message)
		return false
	var data := SaveSystem.defaults()
	village_resources = data.resources
	progression = data.player
	expedition_resources = {"wood": 0, "stone": 0, "gold": 0}
	expeditions_completed = 0
	expedition_active = false
	persist()
	changed.emit()
	return true
