extends Node
## Autoload: permanent progress is persisted; expedition cargo stays in memory.
## Initialization is explicit so tests can select an isolated file before any I/O.

signal changed
signal save_status_changed(message: String)
signal weapon_upgraded

var village_resources: Dictionary = {"wood": 0, "stone": 0, "gold": 0}
var expedition_resources: Dictionary = {"wood": 0, "stone": 0, "gold": 0}
var progression: Dictionary = {"level": 1, "xp": 0, "max_health": 100, "damage": 18}
var defenses_completed := 0
# Runtime coordinator only; battle state is never serialized.
var defense: Node
var expeditions_completed := 0
var expedition_active := false
var initialized := false
var save_status := ""
var storage: SaveSystem
var buildings: Dictionary = BuildingData.default_state()
var weapon_level := 0
var action_message := ""


func initialize(save_path: String = SaveSystem.DEFAULT_PATH) -> void:
	if initialized:
		return
	storage = SaveSystem.new(save_path)
	var data := storage.load_data()
	_apply_permanent(data)
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
		"expeditions_completed": expeditions_completed,
		"defenses_completed": defenses_completed,
		"buildings": buildings.duplicate(true),
		"weapon_level": weapon_level
	}


func _apply_permanent(data: Dictionary) -> void:
	village_resources = data.resources.duplicate()
	progression = data.player.duplicate()
	expeditions_completed = data.expeditions_completed
	defenses_completed = data.defenses_completed
	buildings = data.buildings.duplicate(true)
	weapon_level = data.weapon_level


func building_level(id: String) -> int:
	return int(buildings[id].level) if buildings.has(id) else 0


func can_afford(cost: Dictionary) -> bool:
	if cost.is_empty():
		return false
	for key in cost:
		if not village_resources.has(key) or not cost[key] is int or cost[key] < 0:
			return false
		if village_resources[key] < cost[key]:
			return false
	return true


func spend_resources(cost: Dictionary) -> bool:
	return _commit_economy(cost, snapshot())


func _commit_economy(cost: Dictionary, next: Dictionary) -> bool:
	if defense_busy():
		action_message = "A vila está sob ataque!"
		return false
	if expedition_active:
		action_message = "Retorne à vila para construir."
		return false
	if not can_afford(cost):
		action_message = "Recursos insuficientes"
		return false
	for key in cost:
		next.resources[key] -= cost[key]
	# Stage the complete transaction on a copy. Nothing live changes before commit.
	if not storage.save_data(next):
		_set_status(storage.message)
		action_message = "Não foi possível salvar. Recursos e melhorias foram mantidos."
		return false
	_apply_permanent(next)
	_set_status("")
	changed.emit()
	return true


func building_offer(id: String) -> Dictionary:
	var data := BuildingData.definition(id)
	if data.is_empty():
		return {}
	var level := building_level(id)
	var offer := {
		"id": id, "name": data.name, "description": data.description,
		"level": level, "action": "none", "expected_level": level,
		"cost": {}, "button": "Construído", "reason": "Nível máximo desta construção.",
		"enabled": false
	}
	if level == 0:
		offer.action = "build"
		offer.cost = data.cost
		offer.button = "Construir"
		offer.reason = "Construa a Prefeitura primeiro." if id != "town_hall" and building_level("town_hall") == 0 else ""
	elif id == "blacksmith":
		offer.expected_level = weapon_level
		offer.description += "\nArma Nv. %d / 3 · Bônus total: +%d dano" % [weapon_level, BuildingData.weapon_bonus(weapon_level)]
		if weapon_level < BuildingData.MAX_WEAPON_LEVEL:
			offer.action = "upgrade"
			offer.cost = BuildingData.weapon_cost(weapon_level + 1)
			offer.button = "Melhorar arma · Nv. %d" % (weapon_level + 1)
			offer.description += "\nPróxima melhoria: +%d dano permanente" % (BuildingData.weapon_bonus(weapon_level + 1) - BuildingData.weapon_bonus(weapon_level))
			offer.reason = ""
		else:
			offer.reason = "Arma no nível máximo."
	if offer.action != "none" and offer.reason.is_empty():
		if not can_afford(offer.cost):
			offer.reason = "Recursos insuficientes"
		elif expedition_active:
			offer.reason = "Retorne à vila para construir."
		elif storage != null and storage.write_blocked:
			offer.reason = save_status
		offer.enabled = offer.reason.is_empty()
	if defense_busy():
		offer.enabled = false
		offer.reason = "A vila está sob ataque!"
	return offer


func purchase_building(id: String, action: String, expected_level: int) -> bool:
	var offer := building_offer(id)
	if offer.is_empty() or action == "none" or offer.action != action or offer.expected_level != expected_level:
		action_message = "Essa melhoria já mudou. Abra o painel novamente."
		return false
	if not offer.enabled:
		action_message = offer.reason
		return false
	var next := snapshot()
	if action == "build":
		next.buildings[id].level = 1
	else:
		next.weapon_level = weapon_level + 1
		next.player.damage += BuildingData.weapon_bonus(weapon_level + 1) - BuildingData.weapon_bonus(weapon_level)
	if not _commit_economy(offer.cost, next):
		return false
	if action == "upgrade":
		action_message = "Arma melhorada para nível %d! Bônus total: +%d dano." % [weapon_level, BuildingData.weapon_bonus(weapon_level)]
		weapon_upgraded.emit()
	else:
		action_message = "%s construída!" % offer.name if id != "blacksmith" else "Ferreiro construído!"
	return true


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
	if defense_busy() or expedition_active or has_cargo():
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
	if defense_busy() or expedition_active or not has_cargo():
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
	_apply_permanent(data)
	expedition_resources = {"wood": 0, "stone": 0, "gold": 0}
	expeditions_completed = 0
	expedition_active = false
	persist()
	changed.emit()
	return true


func defense_busy() -> bool:
	return is_instance_valid(defense) and defense.is_running()


func commit_defense_reward() -> bool:
	if not is_instance_valid(defense) or not defense.can_claim_reward():
		return false
	var next := snapshot()
	for key in defense.REWARD:
		next.resources[key] += defense.REWARD[key]
	next.defenses_completed += 1
	if not storage.save_data(next):
		_set_status(storage.message)
		return false
	_apply_permanent(next)
	# Consume eligibility before emitting signals, including reentrant listeners.
	defense.reward_pending = false
	_set_status("")
	changed.emit()
	return true
