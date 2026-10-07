class_name Art
extends RefCounted
## Tiny-Swords 素材注册表。
## 单位精灵条带 192px/帧；瓦片图集 64px/格（渲染时缩放到 32px）。
## 改素材只改这里。

const TS_BASE := "res://assets/tiny-swords/Tiny Swords (Free Pack)/"
const TS_UPD := "res://assets/tiny-swords/Tiny Swords (Update 010)/"

const UNIT_CELL := 192  # tiny-swords 单位精灵每帧边长

## 瓦片图集源瓦片大小（64px），渲染时缩放到 TILE=32
const SRC_TILE := 64

# ---- 瓦片图集路径（官方宣传图结构：水 + 抬升草岛 + 南向石崖）----
const COLOR1_ATLAS := TS_BASE + "Terrain/Tileset/Tilemap_color1.png"
const FLAT_ATLAS := TS_UPD + "Terrain/Ground/Tilemap_Flat.png"
const ELEV_ATLAS := TS_UPD + "Terrain/Ground/Tilemap_Elevation.png"
const WATER_TEX := TS_UPD + "Terrain/Water/Water.png"
const WATER_FOAM := TS_UPD + "Terrain/Water/Foam/Foam.png"
const FOAM_CELL := 192
const FOAM_FRAMES := 8
const WATER_BG_FREE := TS_BASE + "Terrain/Tileset/Water Background color.png"
const SHADOW_TEX := TS_UPD + "Terrain/Ground/Shadows.png"
const SHADOW_TEX_FREE := TS_BASE + "Terrain/Tileset/Shadow.png"

## 地面填充用 Flat（与官方演示一致）；color1 仅作备用
const TILE_ATLASES := {
	"grass": FLAT_ATLAS,
	"forest": FLAT_ATLAS,
	"ruins": FLAT_ATLAS,
	"deep": FLAT_ATLAS,
}

const DECOR_THEMES := {
	"grassland": ["rock1", "rock2", "bush1", "bush2", "bush4", "tree", "tree"],
	"forest": ["tree", "tree", "tree", "bush1", "bush2", "bush3", "bush4"],
	"ruins": ["rock1", "rock2", "rock3", "rock4", "bone15", "bone09", "bone13"],
	"deep": ["bush3", "bush4", "rock3", "rock4", "tree", "bone15", "bone09"],
}

## Flat 草地（10x4 图集，左 4 列草，右沙土不用）
const GRASS_CENTER := Vector2i(1, 1)
const GRASS_CENTER_ALT := Vector2i(1, 2)
const GRASS_N := Vector2i(1, 0)
const GRASS_S := Vector2i(1, 3)
const GRASS_W := Vector2i(0, 1)
const GRASS_E := Vector2i(2, 1)
const GRASS_NW := Vector2i(0, 0)
const GRASS_NE := Vector2i(2, 0)
const GRASS_SW := Vector2i(0, 3)
const GRASS_SE := Vector2i(2, 3)
const GRASS_W2 := Vector2i(0, 2)
const GRASS_E2 := Vector2i(2, 2)

## 南向石崖：Tilemap_color1 右下圆润石柱（官方演示同款）
## row4 = 带草顶崖面；row5 = 纯石加深。按 5→6→7→8 顺序拼接
const CLIFF_FACE_L := Vector2i(5, 4)
const CLIFF_FACE_C := Vector2i(6, 4)
const CLIFF_FACE_C2 := Vector2i(7, 4)
const CLIFF_FACE_R := Vector2i(8, 4)
const CLIFF_DEEP_L := Vector2i(5, 5)
const CLIFF_DEEP_C := Vector2i(6, 5)
const CLIFF_DEEP_C2 := Vector2i(7, 5)
const CLIFF_DEEP_R := Vector2i(8, 5)
const CLIFF_ATLAS := COLOR1_ATLAS  # 石崖图集（非 Elevation 方砖）

# ---- 单位精灵路径 ----

## 全套动画路径（idle/walk/attack）。name 兼容旧调用：skeleton1/vampire/player 等。
static func anims_of(name: String) -> Dictionary:
	match name:
		"player", "enemy", "skeleton1":
			# Blue/Red Warrior（玩家/杂兵/刀鬼共用 Warrior 系列）
			var prefix := "Red Units" if name != "player" else "Blue Units"
			return {
				"idle": TS_BASE + "Units/%s/Warrior/Warrior_Idle.png" % prefix,
				"walk": TS_BASE + "Units/%s/Warrior/Warrior_Run.png" % prefix,
				"attack": TS_BASE + "Units/%s/Warrior/Warrior_Attack1.png" % prefix,
			}
		"vampire":
			# Purple Warrior（精英敲门鬼）
			return {
				"idle": TS_BASE + "Units/Purple Units/Warrior/Warrior_Idle.png",
				"walk": TS_BASE + "Units/Purple Units/Warrior/Warrior_Run.png",
				"attack": TS_BASE + "Units/Purple Units/Warrior/Warrior_Attack1.png",
			}
		"lancer":
			# Black Lancer（重型长枪兵，320px/帧，12帧idle+6帧run+3帧attack）
			return {
				"idle": TS_BASE + "Units/Black Units/Lancer/Lancer_Idle.png",
				"walk": TS_BASE + "Units/Black Units/Lancer/Lancer_Run.png",
				"attack": TS_BASE + "Units/Black Units/Lancer/Lancer_Down_Attack.png",
			}
		"ghost_domain":
			# Blue Monk（域/范围鬼）
			return {
				"idle": TS_BASE + "Units/Blue Units/Monk/Idle.png",
				"walk": TS_BASE + "Units/Blue Units/Monk/Run.png",
			}
		"elite":
			# Red Archer（矢/远程鬼）
			return {
				"idle": TS_BASE + "Units/Red Units/Archer/Archer_Idle.png",
				"walk": TS_BASE + "Units/Red Units/Archer/Archer_Run.png",
				"attack": TS_BASE + "Units/Red Units/Archer/Archer_Shoot.png",
			}
	return {}


## 单个 idle 动画路径（兼容旧 frames_of 调用，返回单元素数组）
static func frames_of(key: String) -> Array[String]:
	var d := anims_of(key)
	if d.has("idle"):
		return [d["idle"]]
	return []


## 取某动画的 spritesheet 路径
static func unit_sheet(key: String, anim: String) -> String:
	var d := anims_of(key)
	return d.get(anim, "")


## 兼容旧接口：FRAMES 列出有效 sprite_key（weapon.gd 检查用）
const FRAMES := {
	"player": true,
	"enemy": true,
	"ghost_domain": true,
	"elite": true,
}


# ---- 装饰 / 道具 / 特效 / UI 路径 ----

const DECOR := {
	"tree": TS_UPD + "Resources/Trees/Tree.png",   # 768×576 = 4×3 grid, row0 = 4帧摇曳动画
	"bush1": TS_BASE + "Terrain/Decorations/Bushes/Bushe1.png",  # 1024×128 = 16帧 64px
	"bush2": TS_BASE + "Terrain/Decorations/Bushes/Bushe2.png",
	"bush3": TS_BASE + "Terrain/Decorations/Bushes/Bushe3.png",
	"bush4": TS_BASE + "Terrain/Decorations/Bushes/Bushe4.png",
	"rock1": TS_BASE + "Terrain/Decorations/Rocks/Rock1.png",
	"rock2": TS_BASE + "Terrain/Decorations/Rocks/Rock2.png",
	"rock3": TS_BASE + "Terrain/Decorations/Rocks/Rock3.png",
	"rock4": TS_BASE + "Terrain/Decorations/Rocks/Rock4.png",
	"bone15": TS_UPD + "Deco/15.png",  # 骨头点缀
	"bone09": TS_UPD + "Deco/09.png",  # 碎骨堆
	"bone13": TS_UPD + "Deco/13.png",  # 残骸
}

## 装饰精灵的 cell 大小
const DECOR_CELL := {
	"tree": 192,
	"bush1": 64, "bush2": 64, "bush3": 64, "bush4": 64,
	"rock1": 64, "rock2": 64, "rock3": 64, "rock4": 64,
	"bone15": 64, "bone09": 64, "bone13": 64,
}

## 网格型精灵的动画帧坐标（col, row 列表）
const TREE_FRAMES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
]

## 火焰特效（域武器光环）
const FIRE_SPRITE := TS_BASE + "Particle FX/Fire_01.png"
const FIRE_CELL := 192  # 1536x192 = 8 frames
const FIRE_FRAMES := 8

## 尘土特效（敌人死亡）
const DUST_SPRITE := TS_BASE + "Particle FX/Dust_01.png"
const DUST_CELL := 64  # 512x64 = 8 frames

## 爆炸特效（宝箱开启）
const EXPLOSION_SPRITE := TS_BASE + "Particle FX/Explosion_01.png"
const EXPLOSION_CELL := 192

## 投射物（矢）
const ARROW_SPRITE := TS_BASE + "Units/Red Units/Archer/Arrow.png"

## 宝箱/障碍物
const CHEST_SPRITE := TS_UPD + "Resources/Gold Mine/GoldMine_Active.png"        # 192×128
const CHEST_OPEN_SPRITE := TS_UPD + "Resources/Gold Mine/GoldMine_Inactive.png"  # 开启后
## 可破坏障碍物：建筑（带 Destroyed 状态）
const OBSTACLE_BUILDINGS: Array = [
	{"tex": TS_UPD + "Factions/Knights/Buildings/House/House_Blue.png", "destroyed": TS_UPD + "Factions/Knights/Buildings/House/House_Destroyed.png"},
	{"tex": TS_UPD + "Factions/Knights/Buildings/House/House_Red.png", "destroyed": TS_UPD + "Factions/Knights/Buildings/House/House_Destroyed.png"},
	{"tex": TS_UPD + "Factions/Goblins/Buildings/Wood_House/Goblin_House.png", "destroyed": TS_UPD + "Factions/Goblins/Buildings/Wood_House/Goblin_House_Destroyed.png"},
	{"tex": TS_UPD + "Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Blue.png", "destroyed": TS_UPD + "Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Destroyed.png"},
]
## 金币拾取物：宝箱掉落用 Gold Stone 3，怪物掉落用 G_Spawn，障碍掉落用 Gold Stone 2/1
const GOLD_CHEST_TEX := TS_BASE + "Terrain/Resources/Gold/Gold Stones/Gold Stone 3.png"
const GOLD_CHEST_HL := TS_BASE + "Terrain/Resources/Gold/Gold Stones/Gold Stone 3_Highlight.png"  # 768×128 = 6帧
const GOLD_MONSTER_TEX := TS_UPD + "Resources/Resources/G_Spawn.png"  # 896×128 = 7帧
const GOLD_OBSTACLE_TEX := TS_BASE + "Terrain/Resources/Gold/Gold Stones/Gold Stone 2.png"
const GOLD_OBSTACLE_TEX2 := TS_BASE + "Terrain/Resources/Gold/Gold Stones/Gold Stone 1.png"

## 拾取物
const GOLD_PICKUP := TS_BASE + "Terrain/Resources/Gold/Gold Stones/Gold Stone 1.png"
const VISION_PICKUP := TS_BASE + "Terrain/Resources/Tools/Tool_01.png"
const QUEST_PICKUP := TS_BASE + "Terrain/Resources/Gold/Gold Resource/Gold_Resource.png"

## 撤离点标记
const EXIT_SPRITE := TS_BASE + "Buildings/Blue Buildings/Tower.png"

## UI 元素（Update 010 系列，9-slice/3-slice 可拉伸）
const UI010_DIR := TS_UPD + "UI/"
const UI_PANEL_9 := UI010_DIR + "Banners/Carved_9Slides.png"       # 192×192 九宫格面板
const UI_BANNER_H := UI010_DIR + "Banners/Banner_Horizontal.png"   # 192×192 横幅
const UI_BTN_BLUE_9 := UI010_DIR + "Buttons/Button_Blue_9Slides.png"
const UI_BTN_RED_9 := UI010_DIR + "Buttons/Button_Red_9Slides.png"
const UI_BTN_HOVER_9 := UI010_DIR + "Buttons/Button_Hover_9Slides.png"
const UI_BTN_DISABLE_9 := UI010_DIR + "Buttons/Button_Disable_9Slides.png"
const UI_RIBBON_BLUE := UI010_DIR + "Ribbons/Ribbon_Blue_3Slides.png"     # 192×64 三宫格
const UI_RIBBON_RED := UI010_DIR + "Ribbons/Ribbon_Red_3Slides.png"
const UI_RIBBON_YELLOW := UI010_DIR + "Ribbons/Ribbon_Yellow_3Slides.png"
## 技能图标（64×64）
const UI_ICONS_DIR := UI010_DIR + "Icons/"

## Free Pack 按钮（技能/升级按钮背景，128×128）
const UI_BTN_FREE_DIR := TS_BASE + "UI Elements/UI Elements/Buttons/"
const UI_SKILL_BTN := UI_BTN_FREE_DIR + "SmallBlueRoundButton_Regular.png"
const UI_SKILL_BTN_PRESSED := UI_BTN_FREE_DIR + "SmallBlueRoundButton_Pressed.png"
const UI_UP_BTN_BLUE := UI_BTN_FREE_DIR + "SmallBlueSquareButton_Regular.png"
const UI_UP_BTN_RED := UI_BTN_FREE_DIR + "SmallRedSquareButton_Regular.png"

## 死亡精灵（通用倒地）
const DEAD_SPRITE := TS_UPD + "Factions/Knights/Troops/Dead/Dead.png"

## 水和桥
const WATER_SPRITE := TS_UPD + "Terrain/Water/Water.png"  # 64×64 单帧
const BRIDGE_SPRITE := TS_UPD + "Terrain/Bridge/Bridge_All.png"  # 192×256 = 3×4 grid 64px
const FOAM_SPRITE := TS_UPD + "Terrain/Water/Foam/Foam.png"  # 1536×192 水花条带

## 房屋精灵（128×192，多色多型）
const HOUSE_DIR := TS_UPD + "Factions/Knights/Buildings/House/"
const HOUSE_FREE_DIR := TS_BASE + "Buildings/"
## 所有房屋变体路径（House1/2/3 × 5色 + Update 010 4色 = 19种）
const HOUSE_VARIANTS: Array[String] = [
	TS_BASE + "Buildings/Blue Buildings/House1.png",
	TS_BASE + "Buildings/Blue Buildings/House2.png",
	TS_BASE + "Buildings/Blue Buildings/House3.png",
	TS_BASE + "Buildings/Red Buildings/House1.png",
	TS_BASE + "Buildings/Red Buildings/House2.png",
	TS_BASE + "Buildings/Red Buildings/House3.png",
	TS_BASE + "Buildings/Yellow Buildings/House1.png",
	TS_BASE + "Buildings/Yellow Buildings/House2.png",
	TS_BASE + "Buildings/Yellow Buildings/House3.png",
	TS_BASE + "Buildings/Purple Buildings/House1.png",
	TS_BASE + "Buildings/Purple Buildings/House2.png",
	TS_BASE + "Buildings/Purple Buildings/House3.png",
	TS_BASE + "Buildings/Black Buildings/House1.png",
	TS_BASE + "Buildings/Black Buildings/House2.png",
	TS_BASE + "Buildings/Black Buildings/House3.png",
	HOUSE_DIR + "House_Blue.png",
	HOUSE_DIR + "House_Red.png",
	HOUSE_DIR + "House_Yellow.png",
	HOUSE_DIR + "House_Purple.png",
]


# ---- 旧 TILES 兼容（level_map 等暂用 tile(name) 的地方返回空串即可） ----
static func tile(name: String) -> String:
	return ""


## 从图集中切片为独立 Texture2D
static func slice_atlas(atlas_path: String, grid_x: int, grid_y: int, cell: int) -> Texture2D:
	var tex: Texture2D = load(atlas_path)
	if tex == null:
		return null
	var img := tex.get_image()
	var sub := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
	sub.blit_rect(img, Rect2i(grid_x * cell, grid_y * cell, cell, cell), Vector2i.ZERO)
	return ImageTexture.create_from_image(sub)


## 从网格型精灵图中切第 (col, row) 帧为 Texture2D
static func slice_grid(path: String, cell: int, col: int, row: int) -> Texture2D:
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var img := tex.get_image()
	var sub := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
	sub.blit_rect(img, Rect2i(col * cell, row * cell, cell, cell), Vector2i.ZERO)
	return ImageTexture.create_from_image(sub)


## 从水平条带切片第 i 帧为 Texture2D
static func slice_strip(strip_path: String, cell: int, frame_idx: int) -> Texture2D:
	var tex: Texture2D = load(strip_path)
	if tex == null:
		return null
	var img := tex.get_image()
	var sub := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
	sub.blit_rect(img, Rect2i(frame_idx * cell, 0, cell, cell), Vector2i.ZERO)
	return ImageTexture.create_from_image(sub)


## 条带总帧数
static func strip_frame_count(strip_path: String, cell: int) -> int:
	var tex: Texture2D = load(strip_path)
	if tex == null:
		return 0
	return int(tex.get_width() / cell)
