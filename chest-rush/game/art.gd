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

# ---- 瓦片图集路径 ----
const FLAT_ATLAS := TS_UPD + "Terrain/Ground/Tilemap_Flat.png"       # 640×256 = 10×4 草地/沙土
const ELEV_ATLAS := TS_UPD + "Terrain/Ground/Tilemap_Elevation.png"   # 256×512 = 4×8 悬崖/墙体

## 每关不同地形色板——统一用 Tilemap_Flat（已知布局），靠氛围色调区分
## Tilemap_color 系列布局不同(9×6 vs 10×4)，直接切片会导致取到错误的过渡瓦片
const TILE_ATLASES := {
	"grass": FLAT_ATLAS,
	"forest": FLAT_ATLAS,
	"ruins": FLAT_ATLAS,
	"deep": FLAT_ATLAS,
}

## 装饰主题：每关用不同装饰组合
const DECOR_THEMES := {
	"grassland": ["rock1", "rock2", "bush1", "bush2", "tree1", "tree2"],
	"forest": ["tree1", "tree2", "tree3", "tree4", "bush1", "bush2", "bush3"],
	"ruins": ["rock1", "rock2", "rock3", "rock4"],
	"deep": ["bush3", "rock3", "rock4", "tree4"],
}

## Tilemap_Flat 中草地瓦片的网格坐标（列 0-3），用于地面随机变体
const GRASS_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
]

## Tilemap_Flat 中沙土/路径瓦片的网格坐标（列 5-8）
const DIRT_TILES: Array[Vector2i] = [
	Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0),
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
]

## Tilemap_Elevation 中悬崖顶部瓦片（草地覆盖的墙顶）
const WALL_TOP_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
]

## Tilemap_Elevation 中悬崖正面瓦片（浅色）
const WALL_FACE_TILES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
]

## Tilemap_Elevation 中深色悬崖正面瓦片
const WALL_DARK_TILES: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
]

## Tilemap_Elevation 中深色阴影/底边瓦片
const WALL_BOTTOM_TILES: Array[Vector2i] = [
	Vector2i(0, 7), Vector2i(2, 7), Vector2i(3, 7),
]

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
	"tree1": TS_BASE + "Terrain/Resources/Wood/Trees/Tree1.png",
	"tree2": TS_BASE + "Terrain/Resources/Wood/Trees/Tree2.png",
	"tree3": TS_BASE + "Terrain/Resources/Wood/Trees/Tree3.png",
	"tree4": TS_BASE + "Terrain/Resources/Wood/Trees/Tree4.png",
	"bush1": TS_BASE + "Terrain/Decorations/Bushes/Bushe1.png",
	"bush2": TS_BASE + "Terrain/Decorations/Bushes/Bushe2.png",
	"bush3": TS_BASE + "Terrain/Decorations/Bushes/Bushe3.png",
	"rock1": TS_BASE + "Terrain/Decorations/Rocks/Rock1.png",
	"rock2": TS_BASE + "Terrain/Decorations/Rocks/Rock2.png",
	"rock3": TS_BASE + "Terrain/Decorations/Rocks/Rock3.png",
	"rock4": TS_BASE + "Terrain/Decorations/Rocks/Rock4.png",
}

## 装饰精灵的 cell 大小（树/灌木是条带，岩石是单帧）
## tiny-swords 树木条带 192px/帧；灌木 128px/帧；岩石 64px 单帧
const DECOR_CELL := {
	"tree1": 192, "tree2": 192, "tree3": 192, "tree4": 192,
	"bush1": 128, "bush2": 128, "bush3": 128,
	"rock1": 64, "rock2": 64, "rock3": 64, "rock4": 64,
}

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
const CHEST_SPRITE := TS_BASE + "Terrain/Resources/Gold/Gold Stones/Gold Stone 1.png"
const CHEST_OPEN_SPRITE := TS_BASE + "Terrain/Resources/Gold/Gold Stones/Gold Stone 2.png"
const OBSTACLE_SPRITE := TS_UPD + "Factions/Goblins/Troops/Barrel/Blue/Barrel_Blue.png"
const OBSTACLE_CELL := 192  # Barrel_Blue is 768x768 = 4x4 grid of 192px

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

## 死亡精灵（通用倒地）
const DEAD_SPRITE := TS_UPD + "Factions/Knights/Troops/Dead/Dead.png"


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
