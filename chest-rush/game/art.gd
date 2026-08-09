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
