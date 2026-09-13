class_name LevelDefs
extends RefCounted
## 多关卡参数定义（不含地图——地图由 MapGenerator 程序化生成）。
## 改关卡配置只改这里；改数值平衡改 .tres。

class LevelDef:
	var name: String
	var quest_target: int = 3
	var round_interval: float = 22.0
	var extract_countdown: float = 75.0
	var spawn_radius: float = 220.0
	var knocker_first_round: int = 3
	## 程序化地图参数
	var seed: int = 0
	var chest_count: int = 10
	var obstacle_count: int = 6
	var spawn_count: int = 10

	func _init(n: String, qt: int, ri: float, ec: float, sr: float, kr: int, sd: int, cc: int, oc: int, sc: int) -> void:
		name = n
		quest_target = qt
		round_interval = ri
		extract_countdown = ec
		spawn_radius = sr
		knocker_first_round = kr
		seed = sd
		chest_count = cc
		obstacle_count = oc
		spawn_count = sc


## 4 个关卡：草原遗迹 → 森林小径 → 城堡废墟 → 鬼域深处
static var LEVELS: Array = [
	LevelDef.new("草原遗迹", 3, 25.0, 80.0, 220.0, 4, 1001, 10, 6, 10),
	LevelDef.new("森林小径", 4, 22.0, 75.0, 220.0, 3, 2002, 12, 8, 11),
	LevelDef.new("城堡废墟", 5, 20.0, 70.0, 240.0, 3, 3003, 14, 10, 12),
	LevelDef.new("鬼域深处", 6, 18.0, 65.0, 260.0, 2, 4004, 16, 12, 14),
]
