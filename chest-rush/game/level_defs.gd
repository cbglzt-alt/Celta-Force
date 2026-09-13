class_name LevelDefs
extends RefCounted
## 多关卡参数定义（不含地图——地图由 MapGenerator 程序化生成）。
## 每关有独特视觉主题：不同地形色板、氛围色调、装饰组合。

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
	var house_count: int = 3  # 地图点缀房屋数量
	var water_count: int = 2  # 池塘数量
	## 视觉主题
	var tile_theme: String = "grass"       # 地形色板 key
	var decor_theme: String = "grassland"   # 装饰组合 key
	var atmosphere: Color = Color(0.95, 0.92, 0.85)  # 氛围色调

	func _init(n: String, qt: int, ri: float, ec: float, sr: float, kr: int, sd: int, cc: int, oc: int, sc: int, hc: int, wc: int, tt: String, dt: String, atmo: Color) -> void:
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
		house_count = hc
		water_count = wc
		tile_theme = tt
		decor_theme = dt
		atmosphere = atmo


## 4 个关卡：草原遗迹 → 森林小径 → 城堡废墟 → 鬼域深处
## 每关有独特的地形色板、氛围色调、装饰组合
static var LEVELS: Array = [
	# Level 1: 草原遗迹 — 亮绿草地，温暖阳光，散布岩石灌木
	LevelDef.new("草原遗迹", 3, 25.0, 80.0, 220.0, 4, 1001, 10, 6, 10, 3, 2,
		"grass", "grassland", Color(0.95, 0.92, 0.82)),

	# Level 2: 森林小径 — 深绿密林，偏绿氛围，树木茂密
	LevelDef.new("森林小径", 4, 22.0, 75.0, 220.0, 3, 2002, 12, 8, 11, 4, 3,
		"forest", "forest", Color(0.72, 0.88, 0.68)),

	# Level 3: 城堡废墟 — 枯黄废墟，灰暗氛围，只有岩石
	LevelDef.new("城堡废墟", 5, 20.0, 70.0, 240.0, 3, 3003, 14, 10, 12, 5, 3,
		"ruins", "ruins", Color(0.82, 0.80, 0.72)),

	# Level 4: 鬼域深处 — 青蓝鬼域，幽暗紫调，稀疏诡异
	LevelDef.new("鬼域深处", 6, 18.0, 65.0, 260.0, 2, 4004, 16, 12, 14, 6, 4,
		"deep", "deep", Color(0.58, 0.52, 0.72)),
]
