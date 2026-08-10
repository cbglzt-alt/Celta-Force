class_name Art
extends RefCounted
## 素材注册表：dark 系像素资源（dungeon-assetpuck）路径与瓦片坐标集中管理。
## 16×16 瓦片 / 16×16 单帧角色（4 帧 idle 动画）。改素材只改这里。

const TILESET := "res://assets/dungeon-assetpuck/2D Pixel Dungeon Asset Pack/character and tileset/Dungeon_Tileset.png"
const CHAR_ANIM := "res://assets/dungeon-assetpuck/2D Pixel Dungeon Asset Pack/Character_animation/"

# 角色 sprite 单帧路径（各 4 帧 idle：_1.._4）
const FRAMES := {
	"player": "priests_idle/priest1/v1/priest1_v1_%d.png",
	"enemy": "monsters_idle/skeleton1/v1/skeleton_v1_%d.png",     # 鬼奴杂兵
	"ghost_domain": "monsters_idle/skull/v1/skull_v1_%d.png",     # 域（己方范围鬼）
	"elite": "monsters_idle/vampire/v1/vampire_v1_%d.png",        # 精英/敲门鬼气质
}


static func frame(key: String, i: int) -> String:
	return CHAR_ANIM + FRAMES[key] % clampi(i, 1, 4)


static func frames_of(key: String) -> Array[String]:
	return [frame(key, 1), frame(key, 2), frame(key, 3), frame(key, 4)]


## Enemy_Animations_Set：怪物全套动画 spritesheet 目录（32px/帧）
const ANIM_DIR := "res://assets/dungeon-assetpuck/Enemy_Animations_Set/"


## 某怪物的全套动画表（idle/walk/attack/hurt/death → spritesheet 路径）
## name 形如 "skeleton1" / "skeleton2" / "vampire"；skeleton2 的移动图名缺字母（源文件如此）
static func anims_of(name: String) -> Dictionary:
	var move_file := "enemies-%s_movement.png" % name
	if name == "skeleton2":
		move_file = "enemies-skeleton2_movemen.png"
	return {
		"idle": ANIM_DIR + "enemies-%s_idle.png" % name,
		"walk": ANIM_DIR + move_file,
		"attack": ANIM_DIR + "enemies-%s_attack.png" % name,
		"hurt": ANIM_DIR + "enemies-%s_take_damage.png" % name,
		"death": ANIM_DIR + "enemies-%s_death.png" % name,
	}


## dungeon 瓦片集（tiles/dungeon/，由 Dungeon_Tileset.png 10x10 切好的独立 PNG）
## 名字 → 文件路径。用 tile(name) 取用。源自 manifest.json（92 个独立瓦片）。
const TILES := {
	"wall_corner_outer_tl": "res://assets/tiles/dungeon/wall_corner_outer_tl.png",
	"wall_top_a": "res://assets/tiles/dungeon/wall_top_a.png",
	"wall_top_b": "res://assets/tiles/dungeon/wall_top_b.png",
	"wall_top_c": "res://assets/tiles/dungeon/wall_top_c.png",
	"wall_corner_outer_tr": "res://assets/tiles/dungeon/wall_corner_outer_tr.png",
	"floor_border_tl": "res://assets/tiles/dungeon/floor_border_tl.png",
	"floor_border_t_a": "res://assets/tiles/dungeon/floor_border_t_a.png",
	"floor_border_t_b": "res://assets/tiles/dungeon/floor_border_t_b.png",
	"floor_border_tr": "res://assets/tiles/dungeon/floor_border_tr.png",
	"wall_side_l": "res://assets/tiles/dungeon/wall_side_l.png",
	"wall_face_a": "res://assets/tiles/dungeon/wall_face_a.png",
	"wall_face_b": "res://assets/tiles/dungeon/wall_face_b.png",
	"wall_face_c": "res://assets/tiles/dungeon/wall_face_c.png",
	"wall_face_d": "res://assets/tiles/dungeon/wall_face_d.png",
	"wall_side_r": "res://assets/tiles/dungeon/wall_side_r.png",
	"floor_border_l_a": "res://assets/tiles/dungeon/floor_border_l_a.png",
	"floor_a": "res://assets/tiles/dungeon/floor_a.png",
	"floor_b": "res://assets/tiles/dungeon/floor_b.png",
	"floor_border_r_a": "res://assets/tiles/dungeon/floor_border_r_a.png",
	"wall_mid_l": "res://assets/tiles/dungeon/wall_mid_l.png",
	"wall_inner_corner_tl": "res://assets/tiles/dungeon/wall_inner_corner_tl.png",
	"wall_inner_corner_tr": "res://assets/tiles/dungeon/wall_inner_corner_tr.png",
	"wall_mid_r": "res://assets/tiles/dungeon/wall_mid_r.png",
	"floor_border_l_b": "res://assets/tiles/dungeon/floor_border_l_b.png",
	"floor_e": "res://assets/tiles/dungeon/floor_e.png",
	"floor_f": "res://assets/tiles/dungeon/floor_f.png",
	"floor_border_r_b": "res://assets/tiles/dungeon/floor_border_r_b.png",
	"wall_inner_corner_bl": "res://assets/tiles/dungeon/wall_inner_corner_bl.png",
	"wall_inner_bottom_a": "res://assets/tiles/dungeon/wall_inner_bottom_a.png",
	"wall_inner_bottom_b": "res://assets/tiles/dungeon/wall_inner_bottom_b.png",
	"wall_inner_corner_br": "res://assets/tiles/dungeon/wall_inner_corner_br.png",
	"door_closed_tl": "res://assets/tiles/dungeon/door_closed_tl.png",
	"door_closed_tr": "res://assets/tiles/dungeon/door_closed_tr.png",
	"floor_g": "res://assets/tiles/dungeon/floor_g.png",
	"ladder": "res://assets/tiles/dungeon/ladder.png",
	"wall_corner_outer_bl": "res://assets/tiles/dungeon/wall_corner_outer_bl.png",
	"wall_bottom_a": "res://assets/tiles/dungeon/wall_bottom_a.png",
	"wall_bottom_b": "res://assets/tiles/dungeon/wall_bottom_b.png",
	"wall_corner_outer_br": "res://assets/tiles/dungeon/wall_corner_outer_br.png",
	"beam_vertical_a": "res://assets/tiles/dungeon/beam_vertical_a.png",
	"beam_vertical_b": "res://assets/tiles/dungeon/beam_vertical_b.png",
	"beam_vertical_c": "res://assets/tiles/dungeon/beam_vertical_c.png",
	"crate_stack": "res://assets/tiles/dungeon/crate_stack.png",
	"wall_ledge_l": "res://assets/tiles/dungeon/wall_ledge_l.png",
	"wall_ledge_a": "res://assets/tiles/dungeon/wall_ledge_a.png",
	"wall_ledge_b": "res://assets/tiles/dungeon/wall_ledge_b.png",
	"wall_ledge_r": "res://assets/tiles/dungeon/wall_ledge_r.png",
	"debris_a": "res://assets/tiles/dungeon/debris_a.png",
	"debris_b": "res://assets/tiles/dungeon/debris_b.png",
	"door_closed_bl": "res://assets/tiles/dungeon/door_closed_bl.png",
	"door_closed_br": "res://assets/tiles/dungeon/door_closed_br.png",
	"beam_stump": "res://assets/tiles/dungeon/beam_stump.png",
	"rubble_stones": "res://assets/tiles/dungeon/rubble_stones.png",
	"floor_room_a": "res://assets/tiles/dungeon/floor_room_a.png",
	"floor_room_b": "res://assets/tiles/dungeon/floor_room_b.png",
	"floor_room_c": "res://assets/tiles/dungeon/floor_room_c.png",
	"floor_room_d": "res://assets/tiles/dungeon/floor_room_d.png",
	"debris_c": "res://assets/tiles/dungeon/debris_c.png",
	"debris_d": "res://assets/tiles/dungeon/debris_d.png",
	"door_open_l": "res://assets/tiles/dungeon/door_open_l.png",
	"door_open_r": "res://assets/tiles/dungeon/door_open_r.png",
	"bone_shards": "res://assets/tiles/dungeon/bone_shards.png",
	"rubble": "res://assets/tiles/dungeon/rubble.png",
	"floor_border_bl": "res://assets/tiles/dungeon/floor_border_bl.png",
	"floor_border_b_a": "res://assets/tiles/dungeon/floor_border_b_a.png",
	"floor_border_b_b": "res://assets/tiles/dungeon/floor_border_b_b.png",
	"floor_border_br": "res://assets/tiles/dungeon/floor_border_br.png",
	"banner": "res://assets/tiles/dungeon/banner.png",
	"bone_b": "res://assets/tiles/dungeon/bone_b.png",
	"bone_c": "res://assets/tiles/dungeon/bone_c.png",
	"skull_and_bone": "res://assets/tiles/dungeon/skull_and_bone.png",
	"void": "res://assets/tiles/dungeon/void.png",
	"chest_wood_closed": "res://assets/tiles/dungeon/chest_wood_closed.png",
	"chest_wood_open": "res://assets/tiles/dungeon/chest_wood_open.png",
	"chest_wood_looted": "res://assets/tiles/dungeon/chest_wood_looted.png",
	"chest_metal_closed": "res://assets/tiles/dungeon/chest_metal_closed.png",
	"chest_metal_open": "res://assets/tiles/dungeon/chest_metal_open.png",
	"chest_metal_looted": "res://assets/tiles/dungeon/chest_metal_looted.png",
	"coin_gold": "res://assets/tiles/dungeon/coin_gold.png",
	"potion_blue_a": "res://assets/tiles/dungeon/potion_blue_a.png",
	"key_silver": "res://assets/tiles/dungeon/key_silver.png",
	"potion_red_a": "res://assets/tiles/dungeon/potion_red_a.png",
	"torch_wall_lit_a": "res://assets/tiles/dungeon/torch_wall_lit_a.png",
	"torch_wall_lit_b": "res://assets/tiles/dungeon/torch_wall_lit_b.png",
	"torch_wall_unlit": "res://assets/tiles/dungeon/torch_wall_unlit.png",
	"candelabra_lit_tall": "res://assets/tiles/dungeon/candelabra_lit_tall.png",
	"candelabra_unlit_tall": "res://assets/tiles/dungeon/candelabra_unlit_tall.png",
	"candelabra_lit_short": "res://assets/tiles/dungeon/candelabra_lit_short.png",
	"candelabra_unlit_short": "res://assets/tiles/dungeon/candelabra_unlit_short.png",
	"potion_blue_b": "res://assets/tiles/dungeon/potion_blue_b.png",
	"potion_red_b": "res://assets/tiles/dungeon/potion_red_b.png",
	"key_gold": "res://assets/tiles/dungeon/key_gold.png",
}


## 按名取瓦片路径；不存在返回空串并告警
static func tile(name: String) -> String:
	if TILES.has(name):
		return TILES[name]
	push_warning("Art.tile: 未知瓦片名 " + name)
	return ""
