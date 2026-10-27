class_name ItemData
extends RefCounted
## Stable catalog IDs. UI and world placeholders share these definitions.
const SLOTS := ["weapon", "armor", "boots"]
const SLOT_NAMES := {"weapon": "Arma", "armor": "Armadura", "boots": "Botas"}
const RARITIES := ["common", "uncommon", "rare", "epic"]
const RARITY_NAMES := {"common": "Comum", "uncommon": "Incomum", "rare": "Raro", "epic": "Épico"}
const COLORS := {"common": Color("c6cbbb"), "uncommon": Color("83d89b"), "rare": Color("78b9fa"), "epic": Color("ce92f5")}
const CATALOG := {
	"rusty_sword": ["Espada Enferrujada", "weapon", "common", 2],
	"iron_sword": ["Espada de Ferro", "weapon", "uncommon", 5],
	"knight_sword": ["Espada do Cavaleiro", "weapon", "rare", 9],
	"royal_blade": ["Lâmina Real", "weapon", "epic", 15],
	"traveler_clothes": ["Roupa de Viajante", "armor", "common", 10],
	"leather_armor": ["Armadura de Couro", "armor", "uncommon", 20],
	"iron_armor": ["Armadura de Ferro", "armor", "rare", 35],
	"royal_armor": ["Armadura Real", "armor", "epic", 55],
	"worn_boots": ["Botas Gastas", "boots", "common", 5],
	"explorer_boots": ["Botas do Explorador", "boots", "uncommon", 10],
	"hunter_boots": ["Botas do Caçador", "boots", "rare", 15],
	"royal_boots": ["Botas Reais", "boots", "epic", 25],
	"health_potion": ["Poção de Vida", "consumable", "common", 40]
}
const ICONS := {"weapon": "ESP", "armor": "ARM", "boots": "BOT", "consumable": "+"}


static func definition(id: String) -> Dictionary:
	if not CATALOG.has(id):
		return {}
	var row: Array = CATALOG[id]
	var stat: String = {"weapon": "damage", "armor": "max_health", "boots": "speed", "consumable": "heal"}[row[1]]
	var unit: String = {"damage": "dano", "max_health": "HP máximo", "speed": "velocidade", "heal": "HP de cura"}[stat]
	return {"id": id, "name": row[0], "type": row[1], "rarity": row[2], "stat": stat,
		"value": row[3], "max_stack": 5 if row[1] == "consumable" else 1,
		"icon": ICONS[row[1]], "description": "+%d %s" % [row[3], unit]}


static func rarity_for_roll(roll: float) -> String:
	if roll < 0.60: return "common"
	if roll < 0.85: return "uncommon"
	if roll < 0.97: return "rare"
	return "epic"


static func random_equipment(rng: RandomNumberGenerator) -> String:
	var rarity := rarity_for_roll(rng.randf())
	var candidates: Array[String] = []
	for id in CATALOG:
		if CATALOG[id][2] == rarity and CATALOG[id][1] != "consumable":
			candidates.append(id)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func roll_loot(rng: RandomNumberGenerator, equipment_chance: float = 0.25, potion_chance: float = 0.12) -> Array[String]:
	var drops: Array[String] = []
	if rng.randf() < equipment_chance:
		drops.append(random_equipment(rng))
	if rng.randf() < potion_chance:
		drops.append("health_potion")
	return drops
