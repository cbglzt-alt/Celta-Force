class_name WeaponData
extends Resource
## 一只"鬼"（被动武器）的数值定义。改数值在 Inspector 或 .tres 文本里，不改 weapon.gd。

enum Pattern { SLASH, BOLT, AURA }

@export var display_name := "鬼"
@export var pattern: Pattern = Pattern.SLASH
@export var damage := 10.0
@export var cooldown := 0.5        # 两次开火间隔（秒）
@export var attack_range := 95.0   # 索敌/命中半径（像素）
@export var color := Color.WHITE
@export var sprite_key := ""       # Art.FRAMES 里的键：刀=enemy 矢=elite 域=ghost_domain
