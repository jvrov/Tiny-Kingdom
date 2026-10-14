class_name BuildingData
extends RefCounted
## Static catalog. Only levels, fixed positions and weapon upgrades need saving.

const IDS := ["town_hall", "blacksmith", "archer_tower"]
const DEFINITIONS := {
	"town_hall": {
		"name": "Prefeitura", "description": "O coração do reino. Eleva a vila ao nível 1 e libera o Ferreiro e a Torre.",
		"max_level": 1, "position": {"x": 640, "y": 320},
		"cost": {"wood": 20, "stone": 15, "gold": 5}
	},
	"blacksmith": {
		"name": "Ferreiro", "description": "Melhora sua arma permanentemente. Três melhorias concedem +3, +4 e +5 de dano adicional.",
		"max_level": 1, "position": {"x": 190, "y": 525},
		"cost": {"wood": 15, "stone": 20, "gold": 8}
	},
	"archer_tower": {
		"name": "Torre de Arqueiros", "description": "Defesa automática: ataca o inimigo mais próximo em 300 px, causando 10 de dano a cada segundo.",
		"max_level": 1, "position": {"x": 1090, "y": 525},
		"cost": {"wood": 25, "stone": 15, "gold": 10}
	}
}
const MAX_WEAPON_LEVEL := 3
const WEAPON_BONUSES := [0, 3, 7, 12]


static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {}).duplicate(true)


static func default_state() -> Dictionary:
	var result := {}
	for id in IDS:
		result[id] = {"level": 0, "position": DEFINITIONS[id].position.duplicate()}
	return result


static func weapon_cost(next_level: int) -> Dictionary:
	if next_level < 1 or next_level > MAX_WEAPON_LEVEL:
		return {}
	return {"wood": 10 * next_level, "stone": 15 * next_level, "gold": 5 * next_level}


static func weapon_bonus(level: int) -> int:
	return WEAPON_BONUSES[clampi(level, 0, MAX_WEAPON_LEVEL)]
