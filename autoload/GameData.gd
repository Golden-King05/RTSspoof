extends Node
## Central data table for civilizations, units and buildings.
## Autoloaded as "GameData".

const RESOURCE_TYPES := ["wood", "food", "gold", "stone"]

const STARTING_RESOURCES := {
	"wood": 200,
	"food": 200,
	"gold": 100,
	"stone": 150,
}

const STARTING_POP_CAP := 5

## Ages gate which buildings (and by extension, the units/upgrades locked
## behind them) a player can construct -- see PlayerState.building_unlocked()
## and GameManager's per-tick research queue. Age I has no advance_cost
## since every match starts there already.
const MAX_AGE := 4
const AGES := {
	1: {"display_name": "Age I: Dark Age", "advance_cost": {}, "advance_time": 0.0},
	2: {"display_name": "Age II: Feudal Age", "advance_cost": {"food": 150, "wood": 80}, "advance_time": 20.0},
	3: {"display_name": "Age III: Castle Age", "advance_cost": {"food": 400, "gold": 150}, "advance_time": 35.0},
	4: {"display_name": "Age IV: Imperial Age", "advance_cost": {"food": 700, "gold": 350}, "advance_time": 45.0},
}

## Civ-wide research, all queued/researched at the Town Center (see
## PlayerState.queue_upgrade/tick_research). `effect` is a flat bonus added
## to every non-villager unit's effective_attack()/effective_armor().
## `forts_to_castles` is a special case (see PlayerState.upgrade_cost() and
## Building.convert_to_castle()): instead of a stat effect, it retroactively
## converts every Fort a player owns into a Castle, and its cost scales with
## how many Forts they already have -- see the module-level note in
## PlayerState.gd for the exact formula.
const UPGRADES := {
	"iron_weapons": {
		"display_name": "Iron Weapons",
		"description": "+1 attack for all military units.",
		"cost": {"food": 120, "gold": 80}, "research_time": 20.0,
		"required_age": 3, "effect": {"attack": 1},
	},
	"reinforced_armor": {
		"display_name": "Reinforced Armor",
		"description": "+1 armor for all military units.",
		"cost": {"gold": 100, "stone": 80}, "research_time": 20.0,
		"required_age": 3, "effect": {"armor": 1},
	},
	"steel_weapons": {
		"display_name": "Steel Weapons",
		"description": "+1 more attack for all military units.",
		"cost": {"food": 200, "gold": 150}, "research_time": 30.0,
		"required_age": 4, "effect": {"attack": 1}, "requires": "iron_weapons",
	},
	"plate_armor": {
		"display_name": "Plate Armor",
		"description": "+1 more armor for all military units.",
		"cost": {"gold": 180, "stone": 150}, "research_time": 30.0,
		"required_age": 4, "effect": {"armor": 1}, "requires": "reinforced_armor",
	},
	"forts_to_castles": {
		"display_name": "Forts -> Castles",
		"description": "Upgrades every Fort into a Castle (more HP and a stronger attack) and switches future construction from Fort to Castle -- stone instead of wood from then on. Costs extra Stone for each Fort already built.",
		"cost": {"gold": 300, "stone": 200}, "research_time": 40.0,
		"required_age": 4, "is_building_upgrade": true,
	},
}

## Unit stat table. `civ_only` restricts a unit to a single civilization id.
const UNIT_STATS := {
	"villager": {
		"display_name": "Villager",
		"max_hp": 25, "attack": 3, "armor": 0, "attack_range": 14.0,
		"move_speed": 90.0, "attack_cooldown": 1.5, "is_ranged": false,
		"cost": {"food": 50}, "train_time": 20.0, "pop_cost": 1,
		"radius": 9.0, "vision_range": 180.0,
		"gather_rate": 0.45, "carry_capacity": 10, "civ_only": "",
		"can_build": true, "can_gather": true,
	},
	"militia": {
		"display_name": "Militia",
		"max_hp": 42, "attack": 6, "armor": 1, "attack_range": 16.0,
		"move_speed": 100.0, "attack_cooldown": 1.2, "is_ranged": false,
		"cost": {"food": 60, "gold": 20}, "train_time": 18.0, "pop_cost": 1,
		"radius": 10.0, "vision_range": 150.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "",
		"can_build": false, "can_gather": false,
	},
	"archer": {
		"display_name": "Archer",
		"max_hp": 30, "attack": 5, "armor": 0, "attack_range": 140.0,
		"move_speed": 95.0, "attack_cooldown": 1.6, "is_ranged": true,
		"cost": {"wood": 40, "gold": 30}, "train_time": 22.0, "pop_cost": 1,
		"radius": 9.0, "vision_range": 170.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "",
		"can_build": false, "can_gather": false,
	},
	"war_chariot": {
		"display_name": "War Chariot",
		"max_hp": 55, "attack": 8, "armor": 1, "attack_range": 16.0,
		"move_speed": 140.0, "attack_cooldown": 1.0, "is_ranged": false,
		"cost": {"wood": 60, "gold": 40}, "train_time": 24.0, "pop_cost": 1,
		"radius": 12.0, "vision_range": 160.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "egyptian",
		"can_build": false, "can_gather": false,
	},
	"longbowman": {
		"display_name": "Longbowman",
		"max_hp": 35, "attack": 7, "armor": 0, "attack_range": 180.0,
		"move_speed": 95.0, "attack_cooldown": 1.7, "is_ranged": true,
		"cost": {"wood": 50, "gold": 40}, "train_time": 26.0, "pop_cost": 1,
		"radius": 9.0, "vision_range": 190.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "british",
		"can_build": false, "can_gather": false,
	},
	"immortal": {
		"display_name": "Immortal",
		"max_hp": 60, "attack": 9, "armor": 2, "attack_range": 16.0,
		"move_speed": 100.0, "attack_cooldown": 1.1, "is_ranged": false,
		"cost": {"food": 70, "gold": 35}, "train_time": 24.0, "pop_cost": 1,
		"radius": 11.0, "vision_range": 160.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "achaemenid",
		"can_build": false, "can_gather": false,
	},
	"berserker": {
		"display_name": "Berserker",
		"max_hp": 45, "attack": 10, "armor": 0, "attack_range": 16.0,
		"move_speed": 110.0, "attack_cooldown": 0.9, "is_ranged": false,
		"cost": {"food": 55, "gold": 25}, "train_time": 20.0, "pop_cost": 1,
		"radius": 10.0, "vision_range": 150.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "viking",
		"can_build": false, "can_gather": false,
	},
	"legionary": {
		"display_name": "Legionary",
		"max_hp": 50, "attack": 8, "armor": 3, "attack_range": 16.0,
		"move_speed": 95.0, "attack_cooldown": 1.3, "is_ranged": false,
		"cost": {"food": 60, "gold": 30}, "train_time": 22.0, "pop_cost": 1,
		"radius": 10.0, "vision_range": 150.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "roman",
		"can_build": false, "can_gather": false,
	},
	## The standard-bearer who carried the legion's silver eagle (the
	## Aquila) into battle -- losing it was a catastrophic blow to morale.
	## Trained at the Town Center (see town_center_unique on the Roman civ),
	## not the Barracks. Its aura_* fields are read directly by Unit.gd,
	## not through the normal combat-stat path: any non-villager ally within
	## aura_radius gets aura_buff while it lives; if it dies, everyone who
	## was in range instead gets aura_debuff_on_death for aura_debuff_duration
	## seconds -- the same shape of effect, inverted, as a morale break.
	"aquilifer": {
		"display_name": "Aquilifer",
		"max_hp": 40, "attack": 4, "armor": 2, "attack_range": 16.0,
		"move_speed": 90.0, "attack_cooldown": 1.5, "is_ranged": false,
		"cost": {"food": 80, "gold": 50}, "train_time": 30.0, "pop_cost": 1,
		"radius": 10.0, "vision_range": 150.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "roman",
		"can_build": false, "can_gather": false,
		"aura_radius": 150.0,
		"aura_buff": {"armor": 2, "attack": 3, "attack_speed_mult": 1.25},
		"aura_debuff_on_death": {"armor": -2, "attack": -3, "attack_speed_mult": 0.8},
		"aura_debuff_duration": 600.0,
	},
	## Every civ's starting unit -- one spawns alongside the villagers at the
	## very beginning of the match (see Main.gd's _spawn_start_base) -- and
	## also trainable at the Stable once built. Weak and cheap on purpose:
	## fast enough to scout the map and harass an enemy's villagers early,
	## but not meant to hold its own in a real fight.
	"scout": {
		"display_name": "Scout",
		"max_hp": 35, "attack": 5, "armor": 0, "attack_range": 16.0,
		"move_speed": 165.0, "attack_cooldown": 1.4, "is_ranged": false,
		"cost": {"food": 50, "gold": 15}, "train_time": 16.0, "pop_cost": 1,
		"radius": 10.0, "vision_range": 260.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "",
		"can_build": false, "can_gather": false,
	},
	"cavalry": {
		"display_name": "Cavalry",
		"max_hp": 65, "attack": 9, "armor": 1, "attack_range": 16.0,
		"move_speed": 130.0, "attack_cooldown": 1.1, "is_ranged": false,
		"cost": {"food": 70, "gold": 50}, "train_time": 26.0, "pop_cost": 1,
		"radius": 12.0, "vision_range": 170.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "",
		"can_build": false, "can_gather": false,
	},
	"horse_archer": {
		"display_name": "Horse Archer",
		"max_hp": 40, "attack": 6, "armor": 0, "attack_range": 130.0,
		"move_speed": 135.0, "attack_cooldown": 1.5, "is_ranged": true,
		"cost": {"wood": 30, "gold": 55}, "train_time": 28.0, "pop_cost": 1,
		"radius": 10.0, "vision_range": 180.0,
		"gather_rate": 0.0, "carry_capacity": 0, "civ_only": "",
		"can_build": false, "can_gather": false,
	},
}

## Building stat table.
const BUILDING_STATS := {
	"town_center": {
		"display_name": "Town Center",
		"max_hp": 600, "cost": {}, "build_time": 0.0,
		"provides_pop": 5, "can_train": ["villager"],
		"drop_off_types": ["wood", "food", "gold", "stone"], "radius": 54.0, "vision_range": 220.0,
		"raid_resource": "stone",
	},
	"house": {
		"display_name": "House",
		"max_hp": 150, "cost": {"wood": 30}, "build_time": 15.0,
		"provides_pop": 10, "can_train": [],
		"drop_off_types": [], "radius": 26.0, "vision_range": 140.0,
		"raid_resource": "wood",
	},
	"barracks": {
		"display_name": "Barracks",
		"max_hp": 300, "cost": {"wood": 120}, "build_time": 35.0,
		"provides_pop": 0, "can_train": ["militia", "archer"],
		"drop_off_types": [], "radius": 40.0, "vision_range": 160.0,
		"raid_resource": "wood", "required_age": 2,
	},
	"stable": {
		"display_name": "Stable",
		"max_hp": 280, "cost": {"wood": 140}, "build_time": 32.0,
		"provides_pop": 0, "can_train": ["scout", "cavalry", "horse_archer"],
		"drop_off_types": [], "radius": 40.0, "vision_range": 160.0,
		"raid_resource": "wood", "required_age": 2,
	},
	## A defensive building, not trainable from -- it fires on its own at any
	## enemy unit that wanders into attack_range (see Building._process_attack).
	"tower": {
		"display_name": "Watch Tower",
		"max_hp": 250, "cost": {"wood": 50, "stone": 75}, "build_time": 25.0,
		"provides_pop": 0, "can_train": [],
		"drop_off_types": [], "radius": 26.0, "vision_range": 220.0,
		"raid_resource": "stone", "required_age": 2,
		"attack": 6, "attack_range": 160.0, "attack_cooldown": 1.2,
	},
	## Also auto-attacks like the Tower. Trains the basic infantry (Militia)
	## plus this civ's Barracks-trained unique unit if it's melee (e.g. the
	## Roman Legionary, not the ranged British Longbowman) -- see
	## trainable_units_for_building(). Superseded by the Castle once
	## "forts_to_castles" is researched: existing Forts convert in place
	## (Building.convert_to_castle()) and new construction builds a Castle
	## directly instead (obsoleted_by hides this from the build menu; see
	## PlayerState.building_unlocked()).
	"fort": {
		"display_name": "Fort",
		"max_hp": 400, "cost": {"wood": 200}, "build_time": 50.0,
		"provides_pop": 0, "can_train": [],
		"drop_off_types": [], "radius": 46.0, "vision_range": 200.0,
		"raid_resource": "wood", "required_age": 3,
		"attack": 10, "attack_range": 180.0, "attack_cooldown": 1.0,
		"obsoleted_by": "forts_to_castles",
	},
	"castle": {
		"display_name": "Castle",
		"max_hp": 700, "cost": {"stone": 250}, "build_time": 70.0,
		"provides_pop": 0, "can_train": [],
		"drop_off_types": [], "radius": 52.0, "vision_range": 220.0,
		"raid_resource": "stone", "required_age": 4,
		"attack": 16, "attack_range": 200.0, "attack_cooldown": 0.9,
		"requires_tech": "forts_to_castles",
	},
	"farm": {
		"display_name": "Farm",
		"max_hp": 80, "cost": {"wood": 60}, "build_time": 12.0,
		"provides_pop": 0, "can_train": [],
		"drop_off_types": [], "radius": 22.0, "vision_range": 100.0,
		"is_farm": true, "food_amount": 175.0,
		"raid_resource": "wood",
	},
	"lumberjack": {
		"display_name": "Lumberjack Camp",
		"max_hp": 120, "cost": {"wood": 60}, "build_time": 15.0,
		"provides_pop": 0, "can_train": [],
		"drop_off_types": ["wood"], "radius": 28.0, "vision_range": 120.0,
		"raid_resource": "wood",
	},
	"mine_camp": {
		"display_name": "Mine",
		"max_hp": 120, "cost": {"wood": 60}, "build_time": 15.0,
		"provides_pop": 0, "can_train": [],
		"drop_off_types": ["stone", "gold"], "radius": 28.0, "vision_range": 120.0,
		"raid_resource": "wood",
	},
	"windmill": {
		"display_name": "Windmill",
		"max_hp": 120, "cost": {"wood": 60}, "build_time": 15.0,
		"provides_pop": 0, "can_train": [],
		"drop_off_types": ["food"], "radius": 28.0, "vision_range": 120.0,
		"raid_resource": "wood",
	},
}

## Civilization data: bonuses and unique units, AoE2-inspired.
const CIV_DATA := {
	"egyptian": {
		"display_name": "Egyptians",
		"color": Color(0.85, 0.68, 0.18),
		"gather_bonus": {},
		"water_gather_bonus": {"food": 1.20},
		"starting_bonus": {"gold": 50},
		"house_pop_bonus": 0,
		"ranged_range_bonus": 1.0,
		"unique_unit": "war_chariot",
		"unique_unit_building": "stable",
		"bonus_text": "Villagers gather Food 20% faster near water. Start with +50 Gold. Unique Unit: War Chariot (Stable).",
	},
	"british": {
		"display_name": "British",
		"color": Color(0.22, 0.42, 0.82),
		"gather_bonus": {},
		"starting_bonus": {},
		"house_pop_bonus": 5,
		"ranged_range_bonus": 1.2,
		"unique_unit": "longbowman",
		"unique_unit_building": "barracks",
		"bonus_text": "Houses support +5 extra Population. Archers fire 20% farther. Unique Unit: Longbowman.",
	},
	"achaemenid": {
		"display_name": "Achaemenids",
		"color": Color(0.55, 0.20, 0.60),
		"gather_bonus": {},
		"starting_bonus": {"gold": 100},
		"house_pop_bonus": 0,
		"ranged_range_bonus": 1.0,
		"move_speed_bonus": 1.15,
		"unique_unit": "immortal",
		"unique_unit_building": "barracks",
		"bonus_text": "All units move 15% faster. Start with +100 Gold. Unique Unit: Immortal.",
	},
	"viking": {
		"display_name": "Vikings",
		"color": Color(0.62, 0.24, 0.14),
		"gather_bonus": {},
		"starting_bonus": {"wood": 40},
		"house_pop_bonus": 0,
		"ranged_range_bonus": 1.0,
		"raid_bonus": {"damage_per_chunk": 10.0, "resource_per_chunk": 1.0, "gold_per_chunk": 0.5},
		"unique_unit": "berserker",
		"unique_unit_building": "barracks",
		"bonus_text": "Raiding: every 10 damage dealt to an enemy building loots 1 Wood/Stone (by building type) + 0.5 Gold. Start with +40 Wood. Unique Unit: Berserker.",
	},
	"roman": {
		"display_name": "Romans",
		"color": Color(0.65, 0.08, 0.10),
		"gather_bonus": {},
		"starting_bonus": {"stone": 30},
		"house_pop_bonus": 0,
		"ranged_range_bonus": 1.0,
		"construction_speed_bonus": 1.3,
		"building_hp_bonus": 1.2,
		"unique_unit": "legionary",
		"unique_unit_building": "barracks",
		"town_center_unique": "aquilifer",
		"bonus_text": "Buildings are constructed 30% faster and have 20% more HP. Start with +30 Stone. Unique Units: Legionary (Barracks), Aquilifer (Town Center).",
	},
}

const RESOURCE_NODE_STATS := {
	"tree": {"resource_type": "wood", "amount": 120, "radius": 14.0, "gather_multiplier": 1.0},
	"gold_mine": {"resource_type": "gold", "amount": 400, "radius": 20.0, "gather_multiplier": 0.8},
	"stone_mine": {"resource_type": "stone", "amount": 350, "radius": 20.0, "gather_multiplier": 0.8},
	"berry_bush": {"resource_type": "food", "amount": 150, "radius": 14.0, "gather_multiplier": 1.0},
}


const RESOURCE_COLORS := {
	"wood": Color(0.20, 0.45, 0.16),
	"gold": Color(0.85, 0.72, 0.15),
	"stone": Color(0.55, 0.55, 0.58),
	"food": Color(0.75, 0.15, 0.20),
}


static func resource_color(res_type: String) -> Color:
	return RESOURCE_COLORS.get(res_type, Color.WHITE)


static func get_unit_stats(unit_type: String) -> Dictionary:
	return UNIT_STATS.get(unit_type, {})


static func get_building_stats(building_type: String) -> Dictionary:
	return BUILDING_STATS.get(building_type, {})


static func get_civ_data(civ_id: String) -> Dictionary:
	return CIV_DATA.get(civ_id, {})


## Picks a random civ other than `civ_id`, for pairing the AI opponent
## against the human's chosen civ (works regardless of how many are added).
static func random_other_civ(civ_id: String) -> String:
	var others: Array = []
	for id in CIV_DATA.keys():
		if id != civ_id:
			others.append(id)
	if others.is_empty():
		return civ_id
	return others[randi() % others.size()]


static func unit_available_for_civ(unit_type: String, civ_id: String) -> bool:
	var stats: Dictionary = get_unit_stats(unit_type)
	var restriction: String = stats.get("civ_only", "")
	return restriction == "" or restriction == civ_id


## `unique_unit`/`unique_unit_building` and `town_center_unique` are two
## independent slots -- a civ can have one regular unique unit (trained at
## whichever building `unique_unit_building` names, e.g. "barracks" or
## "stable") plus a separate Town-Center-trained one, both, or neither.
static func trainable_units_for_building(building_type: String, civ_id: String) -> Array:
	var stats: Dictionary = get_building_stats(building_type)
	var result: Array = []
	for unit_type in stats.get("can_train", []):
		if unit_available_for_civ(unit_type, civ_id):
			result.append(unit_type)
	var civ: Dictionary = get_civ_data(civ_id)
	var unique_unit: String = civ.get("unique_unit", "")
	if unique_unit != "" and civ.get("unique_unit_building", "barracks") == building_type and not result.has(unique_unit):
		result.append(unique_unit)
	if building_type == "town_center":
		var tc_unique: String = civ.get("town_center_unique", "")
		if tc_unique != "" and not result.has(tc_unique):
			result.append(tc_unique)
	## Fort/Castle: the basic melee infantry plus this civ's Barracks-trained
	## unique unit, but only if it's melee too -- a Fort trains foot soldiers,
	## not archers, so a ranged unique like the British Longbowman stays
	## Barracks-only.
	if building_type == "fort" or building_type == "castle":
		if not result.has("militia"):
			result.append("militia")
		if unique_unit != "" and civ.get("unique_unit_building", "barracks") == "barracks" and not result.has(unique_unit):
			if not get_unit_stats(unique_unit).get("is_ranged", false):
				result.append(unique_unit)
	return result
